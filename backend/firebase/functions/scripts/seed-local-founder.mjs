import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const email = process.env.FOUNDER_EMAIL?.trim();
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const localHost = (host) => /^(127\.0\.0\.1|localhost):\d+$/.test(host ?? '');
if (projectId !== 'demo-stewardie' || !localHost(authHost) || !localHost(firestoreHost)) {
  throw new Error('Only the local demo-stewardie Auth and Firestore emulators may be seeded.');
}
if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
  throw new Error('Set FOUNDER_EMAIL to the local trial account address.');
}

const app = initializeApp({ projectId });
const auth = getAuth(app);
const accessFile = process.env.LOCAL_ACCESS_FILE || join(tmpdir(), 'stewardie-local-access.txt');
let account;
try {
  account = await auth.getUserByEmail(email);
} catch (error) {
  if (error.code !== 'auth/user-not-found') throw error;
}
if (!account) {
  const password = randomBytes(24).toString('base64url');
  account = await auth.createUser({
    email, password, emailVerified: true,
    displayName: process.env.FOUNDER_DISPLAY_NAME?.trim() || 'Member',
  });
  writeFileSync(accessFile,
    `Stewardie local Firebase emulator only\nEmail: ${email}\nPassword: ${password}\n`);
  console.log(`Local login details saved to ${accessFile}`);
} else if (!account.emailVerified) {
  throw new Error('This existing local account is unverified; verify it before granting Plus.');
} else {
  console.log('Local account already exists; its password was not changed.');
}

const grantScript = fileURLToPath(new URL('grant-founder-plus.mjs', import.meta.url));
execFileSync(process.execPath, [grantScript, '--apply'], {
  env: { ...process.env, GCLOUD_PROJECT: projectId, FOUNDER_EMAIL: email },
  stdio: 'inherit',
});
