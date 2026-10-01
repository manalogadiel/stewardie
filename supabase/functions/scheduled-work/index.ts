import { importPKCS8, SignJWT } from 'https://esm.sh/jose@5.9.6';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';
import { eventInboxId, eventRecipients } from './event_delivery.mjs';
import { socialEligible, pushEnabled, notificationRollout } from './notification_policy.mjs';
import { timestampBatch, pendingPushes } from './query_plan.mjs';

// Invoked by Supabase Cron with a private shared secret. Firebase Admin REST
// bypasses client rules; never expose this endpoint to an app or browser.
const project = Deno.env.get('FIREBASE_PROJECT_ID') || 'stewardie';
const nameRoot = `projects/${project}/databases/(default)/documents`;
const root = `https://firestore.googleapis.com/v1/${nameRoot}`;
let cachedToken: { value: string; until: number } | null = null;

type Fields = Record<string, unknown>;
type Doc = { name: string; fields?: Record<string, unknown>; updateTime?: string };

function decode(value: unknown): unknown {
  const v = value as Record<string, unknown>;
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return ((v.arrayValue as { values?: unknown[] }).values ?? []).map(decode);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(
    (v.mapValue as { fields?: Record<string, unknown> }).fields ?? {},
  ).map(([k, item]) => [k, decode(item)]));
  return null;
}

function encode(value: unknown): unknown {
  if (value == null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return Number.isInteger(value)
    ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  return { mapValue: { fields: Object.fromEntries(
    Object.entries(value as Fields).map(([k, item]) => [k, encode(item)]),
  ) } };
}

function fields(doc: Doc): Fields {
  return Object.fromEntries(Object.entries(doc.fields ?? {}).map(([k, value]) => [k, decode(value)]));
}

function packed(data: Fields): Record<string, unknown> {
  return Object.fromEntries(Object.entries(data).map(([k, value]) => [k, encode(value)]));
}

function docPath(doc: Doc): string {
  return doc.name.split('/documents/')[1] ?? '';
}

async function token(): Promise<string> {
  if (cachedToken && cachedToken.until > Date.now() + 60000) return cachedToken.value;
  const email = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');
  if (!email || !privateKey) throw new Error('Firebase server credentials are missing');
  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: email, sub: email, aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
  }).setProtectedHeader({ alg: 'RS256' }).setIssuedAt(now)
    .setExpirationTime(now + 3600).sign(key);
  const result = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  });
  if (!result.ok) throw new Error(`Firebase auth failed: ${result.status}`);
  const body = await result.json();
  cachedToken = { value: body.access_token, until: Date.now() + body.expires_in * 1000 };
  return cachedToken.value;
}

async function request(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${root}/${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${await token()}`,
      'content-type': 'application/json',
      ...init.headers,
    },
  });
}

async function get(path: string): Promise<Doc | null> {
  const result = await request(path);
  if (result.status === 404) return null;
  if (!result.ok) throw new Error(`Firestore read ${path}: ${result.status}`);
  return result.json();
}

async function list(path: string, showMissing = false): Promise<Doc[]> {
  const docs: Doc[] = [];
  let page: string | undefined;
  do {
    const qs = new URLSearchParams({ pageSize: '100', ...(showMissing ? { showMissing: 'true' } : {}) });
    if (page) qs.set('pageToken', page);
    const result = await request(`${path}?${qs}`);
    if (!result.ok) throw new Error(`Firestore list ${path}: ${result.status}`);
    const body = await result.json();
    docs.push(...(body.documents ?? []));
    page = body.nextPageToken;
  } while (page);
  return docs;
}

async function queryDocs(parent: string, structuredQuery: unknown): Promise<Doc[]> {
  const result = await fetch(`${root}${parent ? `/${parent}` : ''}:runQuery`, {
    method: 'POST', headers: { authorization: `Bearer ${await token()}`, 'content-type': 'application/json' },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!result.ok) throw new Error(`Worker query failed: ${result.status}`);
  return (await result.json()).filter((row: { document?: Doc }) => row.document).map((row: { document: Doc }) => row.document);
}

async function changedBatch(parent: string, collection: string, field: string,
  consume: (doc: Doc) => Promise<void>, descendants = false): Promise<void> {
  const key = `${parent}_${collection}_${field}`.replaceAll('/', '_');
  const path = `workerProgress/${key}`;
  const state = await get(path);
  const saved = state ? fields(state) : {};
  const cursor = typeof saved.time === 'string' && typeof saved.name === 'string'
    ? { time: saved.time, name: saved.name } : undefined;
  const rows = await queryDocs(parent, timestampBatch(collection, field,
    new Date(notificationRollout).toISOString(), cursor, descendants));
  if (!rows.length) return;
  // Never advance past a failed notification. Deterministic inbox IDs make replay safe.
  for (const row of rows) await consume(row);
  const last = rows[rows.length - 1];
  // Preserve server timestamp precision so the cursor cannot replay its tail.
  const data = { time: String(fields(last)[field]), name: last.name };
  const savedOK = state ? await update(path, data, state.updateTime!) : await create(path, data);
  if (!savedOK) throw new Error('Worker progress changed; retry safely.');
}

async function create(path: string, data: Fields): Promise<boolean> {
  const result = await request(`${path}?currentDocument.exists=false`, {
    method: 'PATCH', body: JSON.stringify({ fields: packed(data) }),
  });
  if (result.status === 409 || result.status === 412) return false;
  if (!result.ok) throw new Error(`Firestore create ${path}: ${result.status}`);
  return true;
}

async function update(path: string, data: Fields, updateTime: string): Promise<boolean> {
  const qs = new URLSearchParams({ 'currentDocument.updateTime': updateTime });
  for (const key of Object.keys(data)) qs.append('updateMask.fieldPaths', key);
  const result = await request(`${path}?${qs}`, {
    method: 'PATCH', body: JSON.stringify({ fields: packed(data) }),
  });
  if (result.status === 409 || result.status === 412) return false;
  if (!result.ok) throw new Error(`Firestore update ${path}: ${result.status}`);
  return true;
}

async function remove(path: string, updateTime: string): Promise<void> {
  const qs = new URLSearchParams({ 'currentDocument.updateTime': updateTime });
  const result = await request(`${path}?${qs}`, { method: 'DELETE' });
  if (![200, 204, 404, 409, 412].includes(result.status)) {
    throw new Error(`Firestore delete ${path}: ${result.status}`);
  }
}

async function collectionIds(path: string): Promise<string[]> {
  const ids: string[] = [];
  let page: string | undefined;
  do {
    const result = await request(`${path}:listCollectionIds`, {
      method: 'POST',
      body: JSON.stringify({ pageSize: 100, ...(page ? { pageToken: page } : {}) }),
    });
    if (!result.ok) throw new Error(`Firestore collection listing failed: ${result.status}`);
    const body = await result.json();
    ids.push(...(body.collectionIds ?? []));
    page = body.nextPageToken;
  } while (page);
  return ids;
}

async function deleteTree(path: string): Promise<void> {
  for (const collection of await collectionIds(path)) {
    for (const child of await list(`${path}/${collection}`, true)) {
      await deleteTree(docPath(child));
    }
  }
  const doc = await get(path);
  if (doc?.updateTime) await remove(path, doc.updateTime);
  if (await get(path)) throw new Error(`Firestore document changed during deletion: ${path}`);
}

async function cleanupSpace(job: Doc): Promise<void> {
  const spaceId = job.name.split('/').pop()!;
  const rootDoc = await get(`spaces/${spaceId}`);
  if (rootDoc && (fields(rootDoc).deletionStatus !== 'pending' ||
      (fields(rootDoc).memberUids as string[] ?? []).length !== 0)) {
    throw new Error('Space deletion was not confirmed by its owner');
  }
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Media cleanup credentials are missing');
  const sb = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  while (true) {
    const { data: rows, error } = await sb.from('media_items')
      .select('id,uploader_uid').eq('space_id', spaceId).limit(100);
    if (error) throw error;
    if (!rows?.length) break;
    for (const row of rows) {
      const prefix = `${spaceId}/${row.uploader_uid}/${row.id}`;
      const removed = await sb.storage.from('moments').remove([
        `${prefix}/photo.jpg`, `${prefix}/thumb.jpg`,
      ]);
      if (removed.error) throw removed.error;
      const deleted = await sb.from('media_items').delete().eq('id', row.id);
      if (deleted.error) throw deleted.error;
    }
  }
  const leftover = await sb.storage.from('moments').list(spaceId, { limit: 1 });
  if (leftover.error || (leftover.data?.length ?? 0) > 0) {
    throw new Error('Space media objects remain; operator review required');
  }
  // Former members can still have old activity after leaving a space.
  for (const account of await list('accounts')) {
    const uid = account.name.split('/').pop()!;
    for (const item of await list(`accounts/${uid}/activity`)) {
      if (fields(item).spaceId === spaceId) await deleteTree(docPath(item));
    }
    await deleteTree(`accounts/${uid}/spaceRefs/${spaceId}`);
  }
  if (await get(`spaces/${spaceId}`)) await deleteTree(`spaces/${spaceId}`);
  for (const key of [`due_${spaceId}`, `photos_${spaceId}`,
    ...[['tasks','updatedAt'],['events','createdAt'],['checkIns','updatedAt'],['reactions','createdAt']]
      .map(([collection, field]) => `spaces_${spaceId}_${collection}_${field}`)]) {
    await deleteTree(`workerProgress/${key}`);
  }
}

async function cleanupRequestedSpaces(now: Date): Promise<number> {
  let errors = 0;
  for (const job of await queryDocs('', { from: [{collectionId: 'spaceDeletionJobs'}],
    where: { fieldFilter: { field: {fieldPath: 'status'}, op: 'IN', value: packed({v: ['pending','failed','processing']}).v } }, limit: 100 })) {
    const data = fields(job);
    if (data.status === 'done' ||
        (data.status === 'processing' && Date.parse(String(data.leaseUntil ?? '')) > now.getTime())) continue;
    if (!job.updateTime) continue;
    const path = docPath(job);
    const acquired = await update(path, {
      status: 'processing', leaseUntil: new Date(now.getTime() + 30 * 60000),
      attempts: Number(data.attempts ?? 0) + 1,
    }, job.updateTime);
    if (!acquired) continue;
    try {
      await cleanupSpace(job);
      const failedNotice = await get(`accounts/${data.requestedBy}/activity/cleanup_${path.split('/').pop()}`);
      if (failedNotice?.updateTime) await update(docPath(failedNotice), {
        title: 'Cloud cleanup complete', body: 'The deleted space has been cleaned up.', cleanupSpaceId: null,
      }, failedNotice.updateTime);
      for (const uid of (data.memberUids as string[] ?? [])) {
        if (uid !== data.requestedBy) await accountNotice(uid, `space_deleted_${path.split('/').pop()}`, 'Space deleted', 'A space you belonged to was deleted.', now);
      }
      const current = await get(path);
      if (current?.updateTime) await update(path, {
        status: 'done', completedAt: new Date(), leaseUntil: null,
        lastError: null,
      }, current.updateTime);
    } catch (error) {
      console.error('Space cleanup failed', path, error);
      errors++;
      if (typeof data.requestedBy === 'string') await accountNotice(data.requestedBy, `cleanup_${path.split('/').pop()}`, 'Cleanup needs attention', 'Your space is hidden. Cloud cleanup will retry automatically. Tap to retry now.', now, { cleanupSpaceId: path.split('/').pop() });
      const current = await get(path);
      if (current?.updateTime) await update(path, {
        status: 'failed', leaseUntil: null,
        lastError: 'Cleanup failed; automatic retry scheduled.',
      }, current.updateTime);
    }
  }
  return errors;
}

async function accountNotice(uid: string, id: string, title: string, body: string, now: Date, extra: Fields = {}): Promise<void> {
  if (!await get(`accounts/${uid}`)) return;
  await create(`accounts/${uid}/activity/${id}`, {
    accountNotice: true, kind: 'accountNotice', title, body,
    createdAt: now, readAt: null, pushState: 'pending', pushId: id, ...extra,
  });
}

async function activityForJoin(spaceId: string, space: Fields, join: Doc, now: Date): Promise<void> {
  const j = fields(join);
  const requested = Date.parse(String(j.requestedAt ?? ''));
  // Do not manufacture historical notices for requests predating this rollout.
  if (!Number.isFinite(requested) || requested < notificationRollout) return;
  const uid = String(j.uid ?? '');
  const key = `${spaceId}_${uid}_${requested}`;
  if (j.status === 'pending' && typeof space.ownerUid === 'string' && space.ownerUid !== uid) {
    await create(`accounts/${space.ownerUid}/activity/join_${key}`, {
      spaceId, kind: 'joinRequested', entityId: uid,
      title: 'Join request', body: 'Someone is waiting to join your space.',
      createdAt: new Date(requested), readAt: null, pushState: 'pending', pushId: `join_${key}`,
    });
  } else if (j.status === 'approved' || j.status === 'declined') {
    await accountNotice(uid, `join_${j.status}_${key}`, j.status === 'approved' ? 'Join request approved' : 'Join request declined',
      j.status === 'approved' ? 'Your request was approved. Open your saved invitation to join.' : 'Your request to join a space was declined.', now);
  }
}

function local(now: Date, zone: string): { date: string; weekday: string; minute: number } {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat('en-US', {
      timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit',
      weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(now);
  } catch (_) {
    parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'UTC', year: 'numeric', month: '2-digit', day: '2-digit',
      weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(now);
  }
  const part = (name: string) => parts.find((p) => p.type === name)?.value ?? '';
  return {
    date: `${part('year')}-${part('month')}-${part('day')}`,
    weekday: part('weekday'),
    minute: Number(part('hour')) * 60 + Number(part('minute')),
  };
}

function quiet(minute: number, start: number, end: number): boolean {
  if (start === end) return false;
  return start < end ? minute >= start && minute < end
    : minute >= start || minute < end;
}

async function socialActivity(spaceId: string, space: Fields, now: Date): Promise<void> {
  const members = space.memberUids as string[] ?? [];
  const prefs = new Map<string, Fields>();
  const joined = new Map<string, unknown>();
  for (const uid of members) joined.set(uid, fields(await get(`spaces/${spaceId}/members/${uid}`) ?? { name: '' }).joinedAt);
  for (const uid of members) prefs.set(uid, fields(await get(`accounts/${uid}/notificationPrefs/${spaceId}`) ?? { name: '' }));
  const eligible = (uid: string, category: string, time: string) => {
    const p = prefs.get(uid) ?? {};
    return socialEligible(p, category, time, joined.get(uid));
  };
  if ([...prefs.values()].some((p) => p.moods !== false)) {
    await changedBatch(`spaces/${spaceId}`, 'checkIns', 'updatedAt', async (mood) => {
      const m = fields(mood), author = String(m.uid ?? '');
      const at = String(m.updatedAt ?? '');
      if (!members.includes(author) || Date.parse(String(m.expiresAt)) <= now.getTime()) return;
      for (const uid of members) {
        if (uid === author || !eligible(uid, 'moods', at)) continue;
        await create(`accounts/${uid}/activity/mood_${spaceId}_${author}_${local(now, String(space.timeZone ?? 'UTC')).date}`, {
          spaceId, kind: 'mood', actorUid: author, title: 'Mood check-in', body: 'A member checked in today.',
          createdAt: new Date(at), readAt: null, pushState: 'pending', pushId: `mood_${spaceId}_${author}_${local(now, String(space.timeZone ?? 'UTC')).date}`,
        });
      }
    });
  }
  if (![...prefs.values()].some((p) => p.photos !== false || p.reactions !== false)) return;
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const photoStatePath = `workerProgress/photos_${spaceId}`;
  const photoState = await get(photoStatePath);
  const photoCursor = photoState ? fields(photoState) : {};
  {
    let photoQuery = sb.from('media_items').select('id,uploader_uid,published_at')
      .eq('space_id', spaceId).eq('state', 'ready').not('published_at', 'is', null)
      .gte('published_at', new Date(notificationRollout).toISOString());
    if (typeof photoCursor.time === 'string' && typeof photoCursor.name === 'string') {
      photoQuery = photoQuery.or(`published_at.gt.${photoCursor.time},and(published_at.eq.${photoCursor.time},id.gt.${photoCursor.name})`);
    }
    const { data, error } = await photoQuery.order('published_at').order('id').limit(100);
    if (error) throw error;
    for (const photo of data ?? []) {
    if (!members.includes(photo.uploader_uid)) continue;
    for (const uid of members) {
      if (uid === photo.uploader_uid || !eligible(uid, 'photos', photo.published_at)) continue;
      await create(`accounts/${uid}/activity/photo_${spaceId}_${photo.id}`, {
        spaceId, kind: 'photo', entityId: photo.id, actorUid: photo.uploader_uid,
        title: 'New moment', body: 'A member shared a photo.', createdAt: new Date(photo.published_at),
        readAt: null, pushState: 'pending', pushId: `photo_${spaceId}_${photo.id}`,
      });
    }
    }
    if (data?.length) {
      const last = data[data.length - 1];
      const progress = { time: last.published_at, name: last.id };
      const ok = photoState ? await update(photoStatePath, progress, photoState.updateTime!) : await create(photoStatePath, progress);
      if (!ok) throw new Error('Photo progress changed; retry safely.');
    }
  }
  // New reactions on old photos must remain eligible without rereading every photo.
  await changedBatch(`spaces/${spaceId}`, 'reactions', 'createdAt', async (reaction) => {
      const photoId = reaction.name.split('/').at(-3)!;
      const { data: photo, error } = await sb.from('media_items').select('id,uploader_uid,state').eq('space_id', spaceId).eq('id', photoId).maybeSingle();
      if (error) throw error;
      if (!photo || photo.state !== 'ready') return;
      const r = fields(reaction), actor = String(r.uid ?? ''), at = String(r.createdAt ?? '');
      if (!members.includes(actor) || await get(`accounts/${actor}/blocks/${photo.uploader_uid}`) || await get(`accounts/${photo.uploader_uid}/blocks/${actor}`)) {
        if (reaction.updateTime) await remove(reaction.name.replace(`${nameRoot}/`, ''), reaction.updateTime);
        return;
      }
      if (!members.includes(photo.uploader_uid) || actor === photo.uploader_uid || !eligible(photo.uploader_uid, 'reactions', at)) return;
      const day = local(new Date(at), String(space.timeZone ?? 'UTC')).date;
      await create(`accounts/${photo.uploader_uid}/activity/reactions_${spaceId}_${photo.id}_${day}`, {
        spaceId, kind: 'reaction', entityId: photo.id, title: 'Photo reactions', body: 'Your photo received new reactions.',
        createdAt: new Date(at), readAt: null, pushState: 'pending', pushId: `reactions_${spaceId}_${photo.id}_${day}`,
      });
  }, true);
}

async function generatedTask(space: Doc, routine: Doc, today: string, now: Date): Promise<void> {
  const s = fields(space), r = fields(routine);
  const spaceId = space.name.split('/').pop()!;
  const routineId = routine.name.split('/').pop()!;
  const id = `routine_${routineId}_${today}`;
  const taskPath = `spaces/${spaceId}/tasks/${id}`;
  if (await get(taskPath)) return;
  const memberUids = s.memberUids as string[] ?? [];
  const creator = memberUids.includes(String(r.creatorUid ?? ''))
    ? String(r.creatorUid) : String(s.ownerUid ?? '');
  const recipient = typeof r.assignedUid === 'string' &&
    memberUids.includes(r.assignedUid) ? r.assignedUid : null;
  const count = Number(s.activeTaskCount ?? 0);
  if (count >= 300) {
    await create(`accounts/${creator}/activity/blocked_${spaceId}_${id}`, {
      spaceId, kind: 'routineBlocked', title: 'Routine needs attention',
      body: 'This space has reached its active task limit.',
      createdAt: now, readAt: null, pushState: 'none',
    });
    return;
  }
  const taskName = `${nameRoot}/${taskPath}`;
  const spaceName = `${nameRoot}/spaces/${spaceId}`;
  const result = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`, {
    method: 'POST',
    headers: { authorization: `Bearer ${await token()}`, 'content-type': 'application/json' },
    body: JSON.stringify({ writes: [
      { update: { name: taskName, fields: packed({
        title: String(r.title ?? 'Routine').slice(0, 120), creatorUid: creator,
        requestedUid: recipient, ownerUid: null, offeredUid: null,
        status: recipient ? 'requested' : 'unclaimed',
        scheduledLocalDate: today, routineId, version: 1,
        completedAt: null, createdAt: now, updatedAt: now,
      }) }, currentDocument: { exists: false } },
      { update: { name: spaceName, fields: packed({
        activeTaskCount: count + 1, changedTaskId: id,
      }) }, updateMask: { fieldPaths: ['activeTaskCount', 'changedTaskId'] },
        currentDocument: { updateTime: space.updateTime } },
    ] }),
  });
  // A competing worker or a member's task write wins. The next cron run retries.
  if (result.status === 409 || result.status === 412) return;
  if (!result.ok) throw new Error(`Routine commit ${spaceId}: ${result.status}`);
}

async function activityForTask(
  spaceId: string, space: Fields, task: Doc, today: string, now: Date, dueReady: boolean,
): Promise<void> {
  const t = fields(task);
  if (t.status === 'completed') return;
  const members = space.memberUids as string[] ?? [];
  const id = task.name.split('/').pop()!;
  const version = Number(t.version ?? 1);
  const attentionUid = t.status === 'requested' ? t.requestedUid
    : t.offeredUid ? t.ownerUid : null;
  if (typeof attentionUid === 'string' && members.includes(attentionUid)) {
    await create(`accounts/${attentionUid}/activity/action_${spaceId}_${id}_${version}`, {
      spaceId, taskId: id, taskVersion: version, kind: 'action',
      title: 'A task needs your response', body: 'Open the task in your space.',
      createdAt: now, readAt: null, pushState: 'pending',
      pushId: crypto.randomUUID(),
    });
  }
  if (!dueReady || String(t.scheduledLocalDate ?? '') > today || t.status === 'requested') return;
  const recipient = String(t.ownerUid ?? t.creatorUid ?? '');
  if (!members.includes(recipient)) return;
  const dueDate = String(t.scheduledLocalDate ?? today);
  await create(`accounts/${recipient}/activity/due_${spaceId}_${id}_${version}_${dueDate}`, {
    spaceId, taskId: id, taskVersion: version, dueDate, kind: 'due',
    title: 'A task needs your attention', body: 'Open the task in your space.',
    createdAt: now, readAt: null, pushState: 'pending',
    pushId: crypto.randomUUID(),
  });
}

async function activityForSpaceEvent(spaceId: string, space: Fields, event: Doc, now: Date): Promise<void> {
  const e = fields(event);
  const at = Date.parse(String(e.createdAt ?? ''));
  if (!Number.isFinite(at) || at < notificationRollout) return;
  const eventId = event.name.split('/').pop()!;
  const type = String(e.type ?? '');
  const actor = String(e.actorUid ?? '');
  const entityId = String(e.entityId ?? '');
  const taskKinds = ['taskAssigned', 'helpRequested', 'helpOffered', 'taskDeclined', 'taskEdited', 'taskCancelled', 'taskArrival', 'covered', 'completed'];
  const planKinds = ['planAdded', 'planChanged', 'planCancelled', 'planArrival'];
  const task = taskKinds.includes(type)
    ? fields(await get(`spaces/${spaceId}/tasks/${entityId}`) ?? { name: '', fields: {} }) : {};
  const recipients = eventRecipients(e, (space.memberUids as string[] ?? []),
    [task.creatorUid, task.ownerUid, task.requestedUid, task.offeredUid]) as string[];
  const labels: Record<string, [string, string]> = {
    joined: ['A member joined', 'Someone joined your space.'],
    left: ['A member left', 'Someone left your space.'],
    removed: ['A member was removed', 'Your space membership changed.'],
    ownershipOffered: ['Ownership offer', 'Review the offer in your space.'],
    ownershipAccepted: ['Ownership transferred', 'Your space has a new owner.'],
    ownershipCancelled: ['Ownership offer ended', 'An ownership offer was cancelled.'],
    locationStarted: ['Location sharing started', 'A member is sharing with this space.'],
    locationEnded: ['Location sharing ended', 'A member stopped sharing with this space.'],
    spaceRenamed: ['Space renamed', 'Your space has a new name.'],
    taskAssigned: ['Task assigned', 'A task needs your response.'],
    helpRequested: ['Help requested', 'A member asked for help with a task.'],
    covered: ['Task covered', 'Someone is covering a task.'],
    completed: ['Task done', 'A shared task was completed.'],
    helpOffered: ['Help offered', 'A member offered to cover your task.'],
    taskDeclined: ['Task request declined', 'A member declined a task request.'],
    taskEdited: ['Task updated', 'Details of a shared task changed.'],
    taskCancelled: ['Task removed', 'A shared task was removed.'],
    taskArrival: ['Arrival check-in', 'A member reported arriving at a task destination.'],
    planAdded: ['A plan was shared', 'You are included in a calendar plan.'],
    planChanged: ['Plan updated', 'A calendar plan changed.'],
    planCancelled: ['Plan removed', 'A calendar plan was removed.'],
    planArrival: ['Arrival check-in', 'A member reported arriving for a plan.'],
  };
  const copy = labels[type];
  if (!copy) return;
  if (type === 'removed' && typeof e.targetUid === 'string' && e.targetUid !== actor) {
    await accountNotice(e.targetUid, `access_ended_${spaceId}_${eventId}`, 'Space access ended', 'Your membership in a space was removed.', now);
  }
  for (const uid of recipients) {
    await create(`accounts/${uid}/activity/${eventInboxId(spaceId, eventId)}`, {
      spaceId, kind: type, eventId, entityId, actorUid: actor,
      ...(typeof e.taskVersion === 'number' ? { taskVersion: e.taskVersion } : {}),
      ...(taskKinds.includes(type) && type !== 'taskCancelled' ? { taskId: entityId } : {}),
      ...(planKinds.includes(type) && type !== 'planCancelled' ? { planId: entityId } : {}),
      ...(typeof e.planRevision === 'number' ? { planRevision: e.planRevision } : {}),
      title: copy[0], body: copy[1],
      createdAt: typeof e.createdAt === 'string' ? new Date(e.createdAt) : now,
      readAt: null, pushState: Date.parse(String(e.createdAt)) > now.getTime() - 86400000 ? 'pending' : 'none',
      pushId: eventInboxId(spaceId, eventId),
    });
  }
}

async function activityForPlan(spaceId: string, space: Fields, plan: Doc, now: Date): Promise<void> {
  const p = fields(plan);
  const reminder = String(p.reminder ?? 'none');
  if (reminder === 'none' || p.source === 'google') return;
  const start = Number(p.startMillis);
  const end = Number(p.endMillis);
  const revision = Number(p.revision ?? 0);
  if (!Number.isFinite(start) || !Number.isFinite(end)) return;
  const zone = String(space.timeZone ?? 'UTC');
  let due = false;
  if (p.allDay === true) {
    if (reminder !== 'morningOf' && reminder !== 'morningBefore') return;
    const date = new Date(start + (reminder === 'morningBefore' ? -86400000 : 0))
      .toISOString().substring(0, 10);
    const today = local(now, zone);
    due = today.date === date && today.minute >= 540;
  } else {
    const offsets: Record<string, number> = { atStart: 0, tenMinutes: 600000,
      oneHour: 3600000, oneDay: 86400000 };
    const offset = offsets[reminder];
    if (offset == null) return;
    due = now.getTime() >= start - offset && now.getTime() < start + 300000;
  }
  if (!due) return;
  const members = new Set(space.memberUids as string[] ?? []);
  const recipients = new Set([String(p.ownerUid ?? ''), ...((p.participants as string[]) ?? [])]);
  const id = plan.name.split('/').pop()!;
  for (const uid of recipients) {
    if (!members.has(uid)) continue;
    await create(`accounts/${uid}/activity/plan_${spaceId}_${id}_${revision}_${start}_${reminder}`, {
      spaceId, planId: id, planRevision: revision,
      planStartMillis: start, planReminder: reminder,
      kind: 'plan', title: 'Plan coming up', body: 'Open your space calendar.',
      createdAt: now, readAt: null, pushState: 'pending', pushId: crypto.randomUUID(),
    });
  }
}

async function cancelStalePlanActivity(uid: string, item: Doc): Promise<boolean> {
  const data = fields(item);
  if (data.kind !== 'plan' || data.pushState === 'cancelled') return false;
  const spaceId = String(data.spaceId ?? '');
  const space = await get(`spaces/${spaceId}`);
  const memberUids = space ? fields(space).memberUids as string[] ?? [] : [];
  const plan = memberUids.includes(uid) ? await get(`spaces/${spaceId}/plans/${data.planId}`) : null;
  const p = plan ? fields(plan) : {};
  const recipients = [p.ownerUid, ...((p.participants as string[]) ?? [])];
  const invalid = !plan || !recipients.includes(uid) || p.source === 'google' ||
    Number(p.revision ?? 0) !== Number(data.planRevision) ||
    Number(p.startMillis) !== Number(data.planStartMillis) || p.reminder !== data.planReminder;
  if (invalid) {
    await update(docPath(item), { pushState: 'cancelled', pushLeaseUntil: null }, item.updateTime!);
  }
  return invalid;
}

async function deliverPush(uid: string, item: Doc, now: Date): Promise<void> {
  const data = fields(item);
  if (data.pushState !== 'pending') return;
  if (Date.parse(String(data.pushLeaseUntil ?? '')) > now.getTime()) return;
  const path = docPath(item);
  const cancel = async () => {
    await update(path, { pushState: 'cancelled', pushLeaseUntil: null }, item.updateTime!);
  };
  const spaceId = String(data.spaceId ?? '');
  const space = spaceId ? await get(`spaces/${spaceId}`) : null;
  const currentSpace = space ? fields(space) : {};
  if (data.accountNotice !== true && (!space || !(fields(space).memberUids as string[] ?? []).includes(uid))) {
    await cancel();
    return;
  }
  if ((data.kind === 'ownershipOffered' && currentSpace.pendingOwnerUid !== uid) ||
      (data.kind === 'joinRequested' && currentSpace.ownerUid !== uid)) {
    await cancel(); return;
  }
  if (data.kind === 'joinRequested') {
    const join = await get(`spaces/${spaceId}/pendingJoins/${data.entityId}`);
    if (!join || fields(join).status !== 'pending') { await cancel(); return; }
  }
  if (data.taskId) {
    const task = await get(`spaces/${spaceId}/tasks/${data.taskId}`);
    const t: Fields = task ? fields(task) : {};
    const invalidDue = data.kind === 'due' &&
      (String(t.scheduledLocalDate ?? '') !== String(data.dueDate) ||
       String(data.dueDate) > local(now, String(currentSpace.timeZone ?? 'UTC')).date);
    const invalidAction = data.kind === 'action' &&
      t.status !== 'requested' && !t.offeredUid;
    const reminder = ['due', 'action', 'taskAssigned'].includes(String(data.kind));
    if (!task || (reminder && t.status === 'completed') || invalidDue || invalidAction ||
        (typeof data.taskVersion === 'number' && Number(t.version) !== data.taskVersion) ||
        (data.kind === 'helpOffered' && (t.ownerUid !== uid || !t.offeredUid))) {
      await cancel();
      return;
    }
  }
  if (data.planId) {
    const plan = await get(`spaces/${spaceId}/plans/${data.planId}`);
    const p: Fields = plan ? fields(plan) : {};
    const recipients = [p.ownerUid, ...((p.participants as string[]) ?? [])];
    const planReminder = data.kind === 'plan';
    if (!plan || !recipients.includes(uid) ||
        (planReminder && (Number(p.startMillis) !== Number(data.planStartMillis) || p.reminder !== data.planReminder || p.source === 'google')) ||
        (typeof data.planRevision === 'number' && Number(p.revision ?? 0) !== data.planRevision)) {
      await cancel();
      return;
    }
    if (planReminder && p.allDay !== true && now.getTime() >= Number(p.endMillis)) {
      // A missed push must not erase a valid in-app reminder.
      await update(path, { pushState: 'missed', pushLeaseUntil: null }, item.updateTime!);
      return;
    }
  }
  const global = fields((await get(`accounts/${uid}/notificationPrefs/global`)) ?? { name: '' });
  const perSpace = spaceId ? fields((await get(`accounts/${uid}/notificationPrefs/${spaceId}`)) ?? { name: '' }) : {};
  if (data.kind === 'mood') {
    const checkin = fields(await get(`spaces/${spaceId}/checkIns/${data.actorUid}`) ?? { name: '' });
    if (perSpace.moods === false || !checkin.expiresAt || Date.parse(String(checkin.expiresAt)) <= now.getTime()) { await cancel(); return; }
  }
  if (data.kind === 'locationStarted') {
    const session = fields(await get(`spaces/${spaceId}/locationSessions/${data.actorUid}`) ?? { name: '' });
    if (!Array.isArray(session.recipientUids) || !session.recipientUids.includes(uid) ||
        Date.parse(String(session.expiresAt)) <= now.getTime() || session.startedAt !== data.createdAt) { await cancel(); return; }
  }
  if (['photo','reaction'].includes(String(data.kind))) {
    const category = data.kind === 'photo' ? 'photos' : 'reactions';
    const url = Deno.env.get('SUPABASE_URL'), key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) throw new Error('Media access unavailable');
    const sb = createClient(url, key, { auth: { persistSession: false } });
    const { data: photo, error } = await sb.from('media_items').select('state,published_at,uploader_uid').eq('space_id', spaceId).eq('id', data.entityId).maybeSingle();
    if (error) throw error;
    if (perSpace[category] === false || !photo || photo.state !== 'ready' || !photo.published_at ||
        (data.kind === 'reaction' && photo.uploader_uid !== uid)) { await cancel(); return; }
  }
  if (!pushEnabled(global, perSpace)) {
    // Notification preferences only mute push, not the in-app activity inbox.
    await update(path, { pushState: 'muted', pushLeaseUntil: null }, item.updateTime!);
    return;
  }
  const zone = String(global.timeZone ?? 'Asia/Manila');
  if (quiet(local(now, zone).minute, Number(global.quietStart ?? 1320), Number(global.quietEnd ?? 420))) return;
  const devices = await list(`accounts/${uid}/pushDevices`);
  if (devices.length === 0) {
    // Never send a backlog of old alerts when the account enables push later.
    await update(path, { pushState: 'unavailable', pushLeaseUntil: null }, item.updateTime!);
    return;
  }
  if (!await update(path, {
    pushLeaseUntil: new Date(now.getTime() + 120000),
  }, item.updateTime!)) return;
  let sent = 0;
  for (const device of devices) {
    const devicePath = docPath(device);
    const deviceToken = fields(device).token;
    if (typeof deviceToken !== 'string' || !deviceToken) continue;
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${await token()}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: {
        token: deviceToken,
        notification: { title: 'Stewardie', body: 'You have an update in your space.' },
        data: { activityId: path.split('/').pop()!, spaceId },
        android: { collapse_key: String(data.pushId ?? path).slice(0, 64), notification: { channel_id: 'stewardie_updates_clay', sound: 'notification', tag: `stewardie_${path.split('/').pop()}` } },
        apns: { headers: { 'apns-collapse-id': String(data.pushId ?? path).slice(0, 64) }, payload: { aps: { sound: 'notification.wav' } } },
      } }),
    });
    if (response.ok) {
      sent++;
      continue;
    }
    const failure = await response.text();
    let fcmError: string | undefined;
    try {
      const parsed = JSON.parse(failure);
      fcmError = parsed.error?.details?.find(
        (detail: { '@type'?: string }) =>
          detail['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
      )?.errorCode;
    } catch { /* Preserve the HTTP error below. */ }
    // An HTTP 404 can mean a wrong Firebase project/API, and a generic 400
    // can mean a malformed payload. Neither proves this device token is bad.
    if (fcmError === 'UNREGISTERED' || fcmError === 'INVALID_ARGUMENT') {
      if (device.updateTime) await remove(devicePath, device.updateTime);
      continue;
    }
    throw new Error(`FCM delivery failed: ${response.status}`);
  }
  const leased = await get(path);
  if (leased?.updateTime) await update(path, {
    pushState: sent > 0 ? 'sent' : 'unavailable', pushedAt: sent > 0 ? new Date() : null,
    pushLeaseUntil: null,
  }, leased.updateTime);
}

async function run(): Promise<{ spaces: number; errors: number }> {
  const now = new Date();
  let errors = await cleanupRequestedSpaces(now);
  const spaces = await list('spaces');
  for (const space of spaces) {
    try {
      const s = fields(space);
      if (s.deletionStatus === 'pending') continue;
      const id = space.name.split('/').pop()!;
      const today = local(now, String(s.timeZone ?? 'UTC'));
      const routines = await list(`spaces/${id}/routines`);
      for (const session of await queryDocs(`spaces/${id}`, { from: [{collectionId: 'locationSessions'}],
        where: {fieldFilter: {field: {fieldPath: 'expiresAt'}, op: 'LESS_THAN_OR_EQUAL', value: {timestampValue: now.toISOString()}}}, limit: 100 })) {
        const expiry = Date.parse(String(fields(session).expiresAt ?? ''));
        if (expiry <= now.getTime() && session.updateTime) {
          const data = fields(session), uid = String(data.uid ?? '');
          const eventPath = `spaces/${id}/events/locationEnded_${uid}_${Date.parse(String(data.startedAt))}`;
          const exists = await get(eventPath);
          const result = await fetch(`${root}:commit`, {
            method: 'POST', headers: { authorization: `Bearer ${await token()}`, 'content-type': 'application/json' },
            body: JSON.stringify({ writes: [
              { delete: session.name, currentDocument: { updateTime: session.updateTime } },
              ...(!exists ? [{ update: { name: `${nameRoot}/${eventPath}`, fields: packed({
                type: 'locationEnded', actorUid: uid, entityId: uid, recipientUids: data.recipientUids ?? [], createdAt: now,
              }) }, currentDocument: { exists: false } }] : []),
            ] }),
          });
          if (![200,409,412].includes(result.status)) throw new Error('Could not expire location session.');
        }
      }
      if (s.routineCount == null) {
        await update(`spaces/${id}`, { routineCount: routines.length }, space.updateTime!);
      }
      if (today.minute >= 5) {
        for (const routine of routines) {
          const r = fields(routine);
          const cadence = String(r.cadence ?? 'daily');
          if (cadence === 'daily' ||
              (cadence === 'weekdays' && !['Sat', 'Sun'].includes(today.weekday)) ||
              (cadence === 'weekly' && today.weekday === 'Mon')) {
            try {
              await generatedTask((await get(`spaces/${id}`))!, routine, today.date, now);
            } catch (error) {
              errors++;
              console.error('Routine generation failed', routine.name, error);
              const manager = String(r.creatorUid ?? s.ownerUid ?? '');
              if ((s.memberUids as string[] ?? []).includes(manager)) {
                await accountNotice(manager, `routine_failed_${id}_${routine.name.split('/').pop()}_${today.date}`,
                  'Routine needs attention', 'A routine could not create its task. It will retry automatically.', now);
              }
            }
          }
        }
      }
      await changedBatch(`spaces/${id}`, 'tasks', 'updatedAt',
        (task) => activityForTask(id, s, task, today.date, now, today.minute >= 540));
      // Revisit unchanged unfinished tasks once after 9am, not every five minutes.
      const duePath = `workerProgress/due_${id}`;
      const dueState = today.minute >= 540 ? await get(duePath) : null;
      if (today.minute >= 540 && fields(dueState ?? {name: ''}).day !== today.date) {
        const active = await queryDocs(`spaces/${id}`, {from: [{collectionId: 'tasks'}],
          where: {fieldFilter: {field: {fieldPath: 'status'}, op: 'IN', value: packed({v: ['unclaimed','requested','accepted','needsHelp']}).v}}, limit: 300});
        for (const task of active) await activityForTask(id, s, task, today.date, now, true);
        const ok = dueState ? await update(duePath, {day: today.date}, dueState.updateTime!) : await create(duePath, {day: today.date});
        if (!ok) throw new Error('Daily progress changed; retry safely.');
      }
      await changedBatch(`spaces/${id}`, 'events', 'createdAt',
        (event) => activityForSpaceEvent(id, s, event, now));
      for (const join of await queryDocs(`spaces/${id}`, {from: [{collectionId: 'pendingJoins'}],
        where: {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: {stringValue: 'pending'}}}, limit: 100})) {
        await activityForJoin(id, s, join, now);
      }
      try {
        await socialActivity(id, s, now);
      } catch (error) {
        // Optional photo/mood activity must not hold up calendar reminders.
        errors++;
        console.error('Optional activity failed', id, error);
      }
      // Reminder windows never require scanning all historical/far-future plans.
      for (const plan of await queryDocs(`spaces/${id}`, {from: [{collectionId: 'plans'}],
        where: {compositeFilter: {op: 'AND', filters: [
          {fieldFilter: {field: {fieldPath: 'startMillis'}, op: 'GREATER_THAN_OR_EQUAL', value: {integerValue: String(now.getTime() - 2 * 86400000)}}},
          {fieldFilter: {field: {fieldPath: 'startMillis'}, op: 'LESS_THAN_OR_EQUAL', value: {integerValue: String(now.getTime() + 2 * 86400000)}}},
        ]}}})) {
        await activityForPlan(id, s, plan, now);
      }
    } catch (error) {
      console.error('Space work failed', space.name, error);
      errors++;
    }
  }
  // Delivery is a separate pass so a push failure never rolls back task creation.
  const accounts = await list('accounts');
  // Private review notices never reach reported people or ordinary members.
  const operatorUid = fields(await get('config/founderPlusGrant') ?? { name: '' }).uid;
  const operators = accounts.filter((account) => account.name.split('/').pop() === operatorUid);
  for (const report of await queryDocs('', {from: [{collectionId: 'safetyReports'}],
    where: {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: {stringValue: 'open'}}}, limit: 100})) {
    const r = fields(report), at = Date.parse(String(r.createdAt ?? ''));
    if (r.status !== 'open' || at < notificationRollout || !Number.isFinite(at)) continue;
    for (const operator of operators) await accountNotice(operator.name.split('/').pop()!, `review_${report.name.split('/').pop()}`,
      'Private review needed', 'A report is waiting in your private review queue.', new Date(at), { reportId: report.name.split('/').pop() });
  }
  for (const deletion of await queryDocs('', {from: [{collectionId: 'deletionRequests'}],
    where: {fieldFilter: {field: {fieldPath: 'status'}, op: 'IN', value: packed({v: ['pending','needsAttention']}).v}}, limit: 100})) {
    const r = fields(deletion), at = Date.parse(String(r.createdAt ?? ''));
    if (!['pending','needsAttention'].includes(String(r.status)) || !Number.isFinite(at) || at < notificationRollout) continue;
    for (const operator of operators) await accountNotice(operator.name.split('/').pop()!, `deletion_review_${deletion.name.split('/').pop()}`,
      'Account deletion requested', 'An account deletion is waiting for private review.', new Date(at), { deletionReview: true });
  }
  for (const account of accounts) {
    const uid = account.name.split('/').pop()!;
    try {
      const progressPath = `workerProgress/push_${uid}`;
      const progress = await get(progressPath);
      const cursor = progress ? fields(progress).name as string | undefined : undefined;
      let pending = await queryDocs(`accounts/${uid}`, pendingPushes(cursor));
      if (!pending.length && cursor) pending = await queryDocs(`accounts/${uid}`, pendingPushes());
      for (const item of pending) {
        try {
          if (await cancelStalePlanActivity(uid, item)) continue;
          await deliverPush(uid, item, now);
        } catch (error) {
          errors++;
          console.error('Push remains pending for retry', error);
        }
      }
      // Rotate pending work so a quiet-hours or failing item cannot starve others.
      if (pending.length) {
        const data = {name: pending[pending.length - 1].name};
        if (progress) await update(progressPath, data, progress.updateTime!);
        else await create(progressPath, data);
      }
    } catch (error) {
      console.error('Delivery failed for account', uid, error);
      errors++;
    }
  }
  return { spaces: spaces.length, errors };
}

Deno.serve(async (request) => {
  const expected = Deno.env.get('STEW_WORKER_SECRET');
  if (!expected || request.method !== 'POST' ||
      request.headers.get('x-worker-secret') !== expected) {
    return new Response('Unauthorized', { status: 401 });
  }
  try {
    const result = await run();
    return Response.json(result, { status: result.errors ? 503 : 200 });
  } catch (error) {
    console.error('Scheduled work failed', error);
    return Response.json({ error: 'Scheduled work failed' }, { status: 503 });
  }
});
