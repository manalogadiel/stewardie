import { importPKCS8, SignJWT } from 'https://esm.sh/jose@5.9.6';

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
    scope: 'https://www.googleapis.com/auth/datastore',
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

async function list(path: string): Promise<Doc[]> {
  const docs: Doc[] = [];
  let page: string | undefined;
  do {
    const qs = new URLSearchParams({ pageSize: '100' });
    if (page) qs.set('pageToken', page);
    const result = await request(`${path}?${qs}`);
    if (!result.ok) throw new Error(`Firestore list ${path}: ${result.status}`);
    const body = await result.json();
    docs.push(...(body.documents ?? []));
    page = body.nextPageToken;
  } while (page);
  return docs;
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
  const eventId = event.name.split('/').pop()!;
  const type = String(e.type ?? '');
  const actor = String(e.actorUid ?? '');
  const entityId = String(e.entityId ?? '');
  const current = new Set((space.memberUids as string[] ?? []));
  const original = (e.recipientUids as string[] ?? []);
  const target = typeof e.targetUid === 'string' ? e.targetUid : null;
  const task = ['taskAssigned', 'helpRequested', 'covered', 'completed'].includes(type)
    ? fields(await get(`spaces/${spaceId}/tasks/${entityId}`) ?? { name: '', fields: {} }) : {};
  const recipients = original.filter((uid) => current.has(uid) && uid !== actor && (
    type === 'ownershipOffered' || type === 'taskAssigned' ? uid === target
    : type === 'covered' || type === 'completed' ?
      uid === task.creatorUid || uid === task.ownerUid || uid === task.requestedUid || uid === task.offeredUid
    : true
  ));
  const labels: Record<string, [string, string]> = {
    joined: ['A member joined', 'Someone joined your space.'],
    left: ['A member left', 'Someone left your space.'],
    removed: ['A member was removed', 'Your space membership changed.'],
    ownershipOffered: ['Ownership offer', 'Review the offer in your space.'],
    ownershipAccepted: ['Ownership transferred', 'Your space has a new owner.'],
    taskAssigned: ['Task assigned', 'A task needs your response.'],
    helpRequested: ['Help requested', 'A member asked for help with a task.'],
    covered: ['Task covered', 'Someone is covering a task.'],
    completed: ['Task done', 'A shared task was completed.'],
  };
  const copy = labels[type];
  if (!copy) return;
  for (const uid of recipients) {
    await create(`accounts/${uid}/activity/event_${spaceId}_${eventId}`, {
      spaceId, kind: type, eventId, entityId,
      ...(type.startsWith('task') || ['helpRequested', 'covered', 'completed'].includes(type) ? { taskId: entityId } : {}),
      title: copy[0], body: copy[1],
      createdAt: typeof e.createdAt === 'string' ? new Date(e.createdAt) : now,
      readAt: null, pushState: 'none',
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
  const space = await get(`spaces/${spaceId}`);
  if (!space || !(fields(space).memberUids as string[] ?? []).includes(uid)) {
    await cancel();
    return;
  }
  if (data.taskId) {
    const task = await get(`spaces/${spaceId}/tasks/${data.taskId}`);
    const t: Fields = task ? fields(task) : {};
    const invalidDue = data.kind === 'due' &&
      (String(t.scheduledLocalDate ?? '') !== String(data.dueDate) ||
       String(data.dueDate) > local(now, String(fields(space).timeZone ?? 'UTC')).date);
    const invalidAction = data.kind === 'action' &&
      t.status !== 'requested' && !t.offeredUid;
    if (!task || t.status === 'completed' || invalidDue || invalidAction ||
        Number(t.version) !== Number(data.taskVersion)) {
      await cancel();
      return;
    }
  }
  if (data.planId) {
    const plan = await get(`spaces/${spaceId}/plans/${data.planId}`);
    const p: Fields = plan ? fields(plan) : {};
    const recipients = [p.ownerUid, ...((p.participants as string[]) ?? [])];
    if (!plan || !recipients.includes(uid) || Number(p.startMillis) !== Number(data.planStartMillis) ||
        p.reminder !== data.planReminder || p.source === 'google' ||
        Number(p.revision ?? 0) !== Number(data.planRevision)) {
      await cancel();
      return;
    }
    if (p.allDay !== true && now.getTime() >= Number(p.endMillis)) {
      // A missed push must not erase a valid in-app reminder.
      await update(path, { pushState: 'missed', pushLeaseUntil: null }, item.updateTime!);
      return;
    }
  }
  const global = fields((await get(`accounts/${uid}/notificationPrefs/global`)) ?? { name: '' });
  const perSpace = fields((await get(`accounts/${uid}/notificationPrefs/${spaceId}`)) ?? { name: '' });
  if (global.enabled !== true || perSpace.enabled === false) {
    // Notification preferences only mute push, not the in-app activity inbox.
    await update(path, { pushState: 'muted', pushLeaseUntil: null }, item.updateTime!);
    return;
  }
  const zone = String(global.timeZone ?? 'UTC');
  if (quiet(local(now, zone).minute, Number(global.quietStart ?? 1320), Number(global.quietEnd ?? 420))) return;
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !apiKey) {
    // Never send a backlog of old alerts when push is configured later.
    await update(path, { pushState: 'unavailable', pushLeaseUntil: null }, item.updateTime!);
    return;
  }
  if (!await update(path, {
    pushLeaseUntil: new Date(now.getTime() + 120000),
  }, item.updateTime!)) return;
  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: { authorization: `Key ${apiKey}`, 'content-type': 'application/json' },
    body: JSON.stringify({ app_id: appId, include_aliases: { external_id: [uid] },
      target_channel: 'push', headings: { en: 'Stewardie' },
      contents: { en: 'You have a reminder in your space.' },
      idempotency_key: data.pushId,
    }),
  });
  if (!response.ok) throw new Error(`OneSignal delivery failed: ${response.status}`);
  const leased = await get(path);
  if (leased?.updateTime) await update(path, {
    pushState: 'sent', pushedAt: new Date(),
    pushLeaseUntil: null,
  }, leased.updateTime);
}

async function run(): Promise<{ spaces: number; errors: number }> {
  const now = new Date();
  let errors = 0;
  const spaces = await list('spaces');
  for (const space of spaces) {
    try {
      const s = fields(space);
      const id = space.name.split('/').pop()!;
      const today = local(now, String(s.timeZone ?? 'UTC'));
      const routines = await list(`spaces/${id}/routines`);
      for (const session of await list(`spaces/${id}/locationSessions`)) {
        const expiry = Date.parse(String(fields(session).expiresAt ?? ''));
        if (expiry <= now.getTime() && session.updateTime) {
          await remove(docPath(session), session.updateTime);
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
            await generatedTask((await get(`spaces/${id}`))!, routine, today.date, now);
          }
        }
      }
      for (const task of await list(`spaces/${id}/tasks`)) {
        await activityForTask(id, s, task, today.date, now, today.minute >= 540);
      }
      for (const event of await list(`spaces/${id}/events`)) {
        await activityForSpaceEvent(id, s, event, now);
      }
      for (const plan of await list(`spaces/${id}/plans`)) {
        await activityForPlan(id, s, plan, now);
      }
    } catch (error) {
      console.error('Space work failed', space.name, error);
      errors++;
    }
  }
  // Delivery is a separate pass so a push failure never rolls back task creation.
  const accounts = await list('accounts');
  for (const account of accounts) {
    const uid = account.name.split('/').pop()!;
    try {
      for (const item of await list(`accounts/${uid}/activity`)) {
        if (await cancelStalePlanActivity(uid, item)) continue;
        await deliverPush(uid, item, now);
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
