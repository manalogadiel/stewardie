import { decodeProtectedHeader, importPKCS8, importX509, jwtVerify, SignJWT } from 'https://esm.sh/jose@5.9.6';
import { taskVisible } from './history_policy.mjs';

export const project = Deno.env.get('FIREBASE_PROJECT_ID') || 'stewardie';
export const database = `projects/${project}/databases/(default)`;
export const root = `https://firestore.googleapis.com/v1/${database}/documents`;
export class AccessFailure extends Error {
  constructor(message: string, public status = 403) { super(message); }
}
let certificates: Record<string, string> = {};
let certificateExpiry = 0;
let cachedToken: { value: string; until: number } | null = null;

export async function identify(request: Request): Promise<string> {
  const token = request.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token || token.length > 8192) throw new AccessFailure('Sign in again.', 401);
  try {
    const header = decodeProtectedHeader(token);
    if (header.alg !== 'RS256' || !header.kid) throw new Error('Invalid token');
    if (Date.now() >= certificateExpiry) {
      const response = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
      if (!response.ok) throw new AccessFailure('Authentication unavailable.', 503);
      certificates = await response.json();
      certificateExpiry = Date.now() + 300000;
    }
    if (!certificates[header.kid]) throw new Error('Unknown key');
    const key = await importX509(certificates[header.kid], 'RS256');
    const { payload } = await jwtVerify(token, key, {
      issuer: `https://securetoken.google.com/${project}`, audience: project,
      algorithms: ['RS256'],
    });
    if (!payload.sub || payload.sub.length > 128 || payload.email_verified !== true) throw new Error('Unverified identity');
    return payload.sub;
  } catch (error) {
    if (error instanceof AccessFailure) throw error;
    throw new AccessFailure('Sign in again.', 401);
  }
}

export async function adminToken(): Promise<string> {
  if (cachedToken && cachedToken.until > Date.now() + 60000) return cachedToken.value;
  const email = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');
  if (!email || !privateKey) throw new AccessFailure('Service unavailable.', 503);
  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: email, sub: email, aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore',
  }).setProtectedHeader({ alg: 'RS256' }).setIssuedAt(now).setExpirationTime(now + 3600).sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!response.ok) throw new AccessFailure('Service unavailable.', 503);
  const body = await response.json();
  cachedToken = { value: body.access_token, until: Date.now() + body.expires_in * 1000 };
  return cachedToken.value;
}

export function unpack(value: any): any {
  if (!value || 'nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(unpack);
  if ('mapValue' in value) return fields(value.mapValue);
  return null;
}
export function fields(document: any): Record<string, any> {
  return Object.fromEntries(Object.entries(document?.fields ?? {}).map(([key, value]) => [key, unpack(value)]));
}
export async function getDocument(path: string): Promise<any | null> {
  const response = await fetch(`${root}/${path}`, { headers: { authorization: `Bearer ${await adminToken()}` } });
  if (response.status === 404) return null;
  if (!response.ok) throw new AccessFailure('Service unavailable.', 503);
  return response.json();
}
export async function authorizedSpace(spaceId: string, uid: string): Promise<Record<string, any>> {
  const space = fields(await getDocument(`spaces/${spaceId}`));
  if (!Array.isArray(space.memberUids) || !space.memberUids.includes(uid) || space.deletionStatus === 'pending') {
    throw new AccessFailure('Space access ended.');
  }
  return space;
}

export async function authorizedTask(spaceId: string, taskId: string, uid: string): Promise<Record<string, any>> {
  const space = await authorizedSpace(spaceId, uid);
  const task = await getDocument(`spaces/${spaceId}/tasks/${taskId}`);
  const account = fields(await getDocument(`accounts/${uid}`));
  if (!task || !taskVisible(fields(task), account, space, new Date())) {
    throw new AccessFailure('Task unavailable.', 404);
  }
  return fields(task);
}
