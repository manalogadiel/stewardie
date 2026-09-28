import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createClient } from '@supabase/supabase-js';

import { processDeletion } from '../lib/account-deletion.mjs';

const argument = (name) => {
  const at = process.argv.indexOf(name);
  return at < 0 ? null : process.argv[at + 1];
};
const uid = argument('--uid');
const projectId = argument('--project');
const apply = process.argv.includes('--apply');
const confirmedUid = argument('--confirm-uid');
const local = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST &&
  process.env.FIRESTORE_EMULATOR_HOST);

if (!uid || !projectId || !['stewardie', 'demo-stewardie-spark'].includes(projectId)) {
  throw new Error('Use --uid <Firebase UID> --project <stewardie|demo-stewardie-spark>.');
}
if (apply && (confirmedUid !== uid || (projectId === 'stewardie' &&
    !process.argv.includes('--live')))) {
  throw new Error('Applying cleanup requires --confirm-uid <same UID>; live cleanup also requires --live.');
}
if (projectId.startsWith('demo-') !== local) {
  throw new Error('Demo cleanup needs both Firebase emulators; live cleanup must not use emulator hosts.');
}
const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceKey || !/^https:\/\/[^/]+\.supabase\.co$/.test(supabaseUrl)) {
  throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY privately in this terminal.');
}
if (projectId === 'stewardie' &&
    supabaseUrl !== 'https://ulexhxfxatzlobabitpr.supabase.co') {
  throw new Error('Supabase URL does not match the Stewardie project.');
}
if (projectId.startsWith('demo-') &&
    supabaseUrl === 'https://ulexhxfxatzlobabitpr.supabase.co') {
  throw new Error('An emulator run must not use Stewardie production media.');
}
const app = initializeApp(local ? { projectId } :
  { credential: applicationDefault(), projectId });
const db = getFirestore(app);
const auth = getAuth(app);
const sb = createClient(supabaseUrl, serviceKey,
  { auth: { persistSession: false, autoRefreshToken: false } });

const result = await processDeletion({ db, auth, sb, uid, apply });
console.log(`${apply ? 'Cleanup verified' : 'Dry run'}: ${JSON.stringify(result)}`);
