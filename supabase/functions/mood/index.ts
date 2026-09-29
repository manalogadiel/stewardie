import { decodeProtectedHeader, importPKCS8, importX509, jwtVerify, SignJWT } from 'https://esm.sh/jose@5.9.6';

const project = Deno.env.get('FIREBASE_PROJECT_ID') || 'stewardie';
const root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
let certs: Record<string, string> = {};
let certExpiry = 0;
let adminToken: { value: string; until: number } | null = null;

function reply(status: number, body: Record<string, unknown>) {
  return Response.json(body, { status, headers: cors });
}

async function identify(request: Request): Promise<string> {
  const bearer = request.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!bearer || bearer.length > 8192) throw new Error('unauthorized');
  const header = decodeProtectedHeader(bearer);
  if (header.alg !== 'RS256' || !header.kid) throw new Error('unauthorized');
  if (Date.now() > certExpiry) {
    const response = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
    if (!response.ok) throw new Error('identity-unavailable');
    certs = await response.json();
    certExpiry = Date.now() + 300000;
  }
  if (!certs[header.kid]) throw new Error('unauthorized');
  const key = await importX509(certs[header.kid], 'RS256');
  const { payload } = await jwtVerify(bearer, key, {
    issuer: `https://securetoken.google.com/${project}`,
    audience: project,
    algorithms: ['RS256'],
  });
  if (!payload.sub || payload.email_verified !== true) throw new Error('unauthorized');
  return payload.sub;
}

async function accessToken(): Promise<string> {
  if (adminToken && adminToken.until > Date.now() + 60000) return adminToken.value;
  const email = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');
  if (!email || !privateKey) throw new Error('server-unavailable');
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
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  });
  if (!response.ok) throw new Error('server-unavailable');
  const value = await response.json();
  adminToken = { value: value.access_token, until: Date.now() + value.expires_in * 1000 };
  return adminToken.value;
}

function localDate(time: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(time);
  const part = (name: string) => parts.find((p) => p.type === name)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function nextMidnight(now: Date, zone: string): Date {
  const today = localDate(now, zone);
  let low = now.getTime();
  let high = low + 30 * 3600000;
  if (localDate(new Date(high), zone) <= today) throw new Error('invalid-time-zone');
  while (high - low > 1000) {
    const middle = Math.floor((low + high) / 2000) * 1000;
    if (localDate(new Date(middle), zone) > today) high = middle;
    else low = middle;
  }
  return new Date(high);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return reply(405, { error: 'Use POST.' });
  try {
    const uid = await identify(request);
    const raw = await request.text();
    if (raw.length > 4096) return reply(413, { error: 'Too large.' });
    const data = JSON.parse(raw);
    const spaceId = data.spaceId;
    if (typeof spaceId !== 'string' || !/^[A-Za-z0-9_-]{1,150}$/.test(spaceId) ||
        !['calm', 'happy', 'excited', 'tired', 'sad', 'overwhelmed'].includes(data.mood) ||
        !['sky', 'butter', 'rose'].includes(data.color) ||
        typeof data.note !== 'string' || data.note.length > 180) {
      return reply(400, { error: 'Invalid check-in.' });
    }
    const authorization = `Bearer ${await accessToken()}`;
    const spaceResponse = await fetch(`${root}/spaces/${spaceId}`, {
      headers: { authorization },
    });
    if (!spaceResponse.ok) return reply(403, { error: 'Space unavailable.' });
    const space = await spaceResponse.json();
    const members = (space.fields?.memberUids?.arrayValue?.values ?? [])
      .map((value: { stringValue?: string }) => value.stringValue);
    if (!members.includes(uid) || space.fields?.deletionStatus?.stringValue === 'pending') {
      return reply(403, { error: 'Space unavailable.' });
    }
    const zone = space.fields?.timeZone?.stringValue || 'UTC';
    const now = new Date();
    const expiresAt = nextMidnight(now, zone);
    const result = await fetch(`${root}/spaces/${spaceId}/checkIns/${uid}`, {
      method: 'PATCH',
      headers: { authorization, 'content-type': 'application/json' },
      body: JSON.stringify({ fields: {
        uid: { stringValue: uid }, mood: { stringValue: data.mood },
        color: { stringValue: data.color }, note: { stringValue: data.note },
        updatedAt: { timestampValue: now.toISOString() },
        expiresAt: { timestampValue: expiresAt.toISOString() },
      } }),
    });
    if (!result.ok) throw new Error(`write-${result.status}`);
    return reply(200, { expiresAt: expiresAt.toISOString() });
  } catch (error) {
    console.error('Mood check-in failed', error);
    if (String(error).includes('unauthorized') || String(error).includes('JWT')) {
      return reply(401, { error: 'Sign in again.' });
    }
    return reply(503, { error: 'Could not save your mood.' });
  }
});
