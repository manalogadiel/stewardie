import { decodeProtectedHeader, importPKCS8, importX509, jwtVerify, SignJWT } from 'https://esm.sh/jose@5.9.6';

const project = Deno.env.get('FIREBASE_PROJECT_ID') || 'stewardie';
const database = `projects/${project}/databases/(default)`;
const root = `https://firestore.googleapis.com/v1/${database}/documents`;
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
let certs: Record<string, string> = {};
let certExpiry = 0;
let cached: { token: string; until: number } | null = null;
const idPattern = /^[A-Za-z0-9_-]{1,150}$/;
const json = (status: number, data: Record<string, unknown>) =>
  Response.json(data, { status, headers: cors });

async function userId(req: Request): Promise<string> {
  const raw = req.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!raw || raw.length > 8192) throw new Error('Unauthorized');
  const header = decodeProtectedHeader(raw);
  if (header.alg !== 'RS256' || !header.kid) throw new Error('Unauthorized');
  if (Date.now() > certExpiry) {
    const response = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
    if (!response.ok) throw new Error('Authentication unavailable');
    certs = await response.json();
    certExpiry = Date.now() + 300000;
  }
  if (!certs[header.kid]) throw new Error('Unauthorized');
  const key = await importX509(certs[header.kid], 'RS256');
  const { payload } = await jwtVerify(raw, key, {
    issuer: `https://securetoken.google.com/${project}`, audience: project,
    algorithms: ['RS256'],
  });
  if (!payload.sub || payload.email_verified !== true) throw new Error('Unauthorized');
  return payload.sub;
}

async function accessToken(): Promise<string> {
  if (cached && cached.until > Date.now() + 60000) return cached.token;
  const email = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');
  if (!email || !privateKey) throw new Error('Server credentials missing');
  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: email, sub: email, aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore',
  }).setProtectedHeader({ alg: 'RS256' }).setIssuedAt(now)
    .setExpirationTime(now + 3600).sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!response.ok) throw new Error('Server authentication failed');
  const body = await response.json();
  cached = { token: body.access_token, until: Date.now() + body.expires_in * 1000 };
  return cached.token;
}

async function get(path: string): Promise<any | null> {
  const response = await fetch(`${root}/${path}`, {
    headers: { authorization: `Bearer ${await accessToken()}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Firestore read failed: ${response.status}`);
  return response.json();
}

async function rename(spaceId: string, name: string, uid: string): Promise<Response> {
  const space = await get(`spaces/${spaceId}`);
  if (!space || space.fields?.ownerUid?.stringValue !== uid ||
      space.fields?.deletionStatus?.stringValue === 'pending') {
    return json(403, { error: 'Only the current owner can rename this space.' });
  }
  const members = (space.fields?.memberUids?.arrayValue?.values ?? [])
    .map((item: { stringValue?: string }) => item.stringValue)
    .filter((value: unknown): value is string => typeof value === 'string' && idPattern.test(value));
  const docName = (path: string) => `${database}/documents/${path}`;
  const writes: Record<string, unknown>[] = [{
    update: { name: docName(`spaces/${spaceId}`), fields: { name: { stringValue: name } } },
    updateMask: { fieldPaths: ['name'] },
    currentDocument: { updateTime: space.updateTime },
  }];
  for (const member of members) {
    const ref = await get(`accounts/${member}/spaceRefs/${spaceId}`);
    if (ref) writes.push({
      update: { name: docName(`accounts/${member}/spaceRefs/${spaceId}`), fields: { name: { stringValue: name } } },
      updateMask: { fieldPaths: ['name'] },
      currentDocument: { updateTime: ref.updateTime },
    });
  }
  const eventId = `rename_${crypto.randomUUID().replaceAll('-', '')}`;
  writes.push({ update: { name: docName(`spaces/${spaceId}/events/${eventId}`), fields: {
    type: { stringValue: 'spaceRenamed' }, actorUid: { stringValue: uid },
    entityId: { stringValue: spaceId },
    recipientUids: { arrayValue: { values: members.map((member: string) => ({ stringValue: member })) } },
    createdAt: { timestampValue: new Date().toISOString() },
  } }, currentDocument: { exists: false } });
  const result = await fetch(`https://firestore.googleapis.com/v1/${database}/documents:commit`, {
    method: 'POST',
    headers: { authorization: `Bearer ${await accessToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({ writes }),
  });
  if (result.status === 409) return json(409, { error: 'The space changed. Please retry.' });
  if (!result.ok) throw new Error(`Rename failed: ${result.status}`);
  return json(200, { name });
}

async function drainDeletion(spaceId: string, uid: string): Promise<Response> {
  const job = await get(`spaceDeletionJobs/${spaceId}`);
  if (!job || job.fields?.requestedBy?.stringValue !== uid) return json(403, { error: 'Unavailable.' });
  if (job.fields?.status?.stringValue === 'done') return json(200, { status: 'done' });
  if (!['pending','failed'].includes(job.fields?.status?.stringValue ?? '') &&
      Date.parse(job.fields?.leaseUntil?.timestampValue ?? '') > Date.now()) {
    return json(202, { status: 'queued', retry: 'cron' });
  }
  const secret = Deno.env.get('STEW_WORKER_SECRET');
  const base = Deno.env.get('SUPABASE_URL');
  if (!secret || !base) throw new Error('Cleanup worker unavailable');
  const result = await fetch(`${base}/functions/v1/scheduled-work`, {
    method: 'POST', headers: { 'x-worker-secret': secret },
  });
  if (!result.ok) return json(202, { status: 'queued', retry: 'cron' });
  return json(200, { status: 'processed' });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json(405, { error: 'Use POST.' });
  try {
    const uid = await userId(req);
    const raw = await req.text();
    if (raw.length > 2048) return json(413, { error: 'Too large.' });
    const body = JSON.parse(raw);
    if (typeof body.spaceId !== 'string' || !idPattern.test(body.spaceId)) {
      return json(400, { error: 'Invalid space.' });
    }
    if (body.action === 'rename') {
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      if (!name || name.length > 80) return json(400, { error: 'Enter a shorter space name.' });
      return await rename(body.spaceId, name, uid);
    }
    if (body.action === 'drainDeletion') return await drainDeletion(body.spaceId, uid);
    return json(400, { error: 'Unknown action.' });
  } catch (error) {
    console.error('Space action failed', error);
    if (String(error).includes('Unauthorized') || String(error).includes('JWT')) {
      return json(401, { error: 'Sign in again.' });
    }
    return json(503, { error: 'Space action unavailable. Please retry.' });
  }
});
