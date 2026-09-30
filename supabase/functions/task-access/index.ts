import { AccessFailure, adminToken, authorizedSpace, database, fields, getDocument, identify, root } from '../_shared/firebase.ts';
import { hasPlus, historyStart, localDate, taskVisible } from '../_shared/history_policy.mjs';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type, apikey', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Cache-Control': 'no-store' };
const validId = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,150}$/.test(value);
const reply = (status: number, data: unknown) => Response.json(data, { status, headers: cors });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return reply(405, { error: 'Use POST.' });
  try {
    const uid = await identify(request);
    const raw = await request.text();
    if (raw.length > 2048) return reply(413, { error: 'Request too large.' });
    const body = JSON.parse(raw);
    if (!validId(body.spaceId)) return reply(400, { error: 'Invalid space.' });
    const space = await authorizedSpace(body.spaceId, uid);
    const account = fields(await getDocument(`accounts/${uid}`));
    const now = new Date();
    const path = `spaces/${body.spaceId}/tasks`;
    if (body.action === 'delete') {
      if (!validId(body.taskId)) return reply(400, { error: 'Invalid task.' });
      const document = await getDocument(`${path}/${body.taskId}`);
      if (!document) return reply(200, { removed: true });
      // Deleting content never requires Plus or exposes expired task details.
      const parent = await getDocument(`spaces/${body.spaceId}`);
      const currentSpace = fields(parent);
      if (!currentSpace.memberUids?.includes(uid) || currentSpace.deletionStatus === 'pending') throw new AccessFailure('Space access ended.');
      const task = fields(document);
      const eventId = `cancel_${crypto.randomUUID().replaceAll('-', '')}`;
      const parentFields: any = { changedTaskId: { stringValue: body.taskId } };
      if (task.status !== 'completed') parentFields.activeTaskCount = { integerValue: String(Math.max(0, Number(currentSpace.activeTaskCount ?? 0) - 1)) };
      const audience = [...new Set([task.creatorUid, task.ownerUid, task.requestedUid, task.offeredUid].filter((value) => typeof value === 'string'))];
      const writes = [
        { delete: document.name, currentDocument: { updateTime: document.updateTime } },
        { update: { name: parent.name, fields: parentFields }, updateMask: { fieldPaths: Object.keys(parentFields) }, currentDocument: { updateTime: parent.updateTime } },
        { update: { name: `${database}/documents/spaces/${body.spaceId}/events/${eventId}`, fields: {
          type: { stringValue: 'taskCancelled' }, actorUid: { stringValue: uid }, entityId: { stringValue: body.taskId },
          recipientUids: { arrayValue: { values: currentSpace.memberUids.map((value: string) => ({ stringValue: value })) } },
          affectedUids: { arrayValue: { values: audience.map((value) => ({ stringValue: value })) } },
          createdAt: { timestampValue: now.toISOString() },
        } }, currentDocument: { exists: false } },
      ];
      const response = await fetch(`https://firestore.googleapis.com/v1/${database}/documents:commit`, {
        method: 'POST', headers: { authorization: `Bearer ${await adminToken()}`, 'content-type': 'application/json' }, body: JSON.stringify({ writes }),
      });
      if (response.status === 409 || response.status === 412) return reply(409, { error: 'The task changed. Please retry.' });
      if (!response.ok) throw new AccessFailure('Could not remove task.', 503);
      return reply(200, { removed: true });
    }
    if (body.action === 'get') {
      if (!validId(body.taskId)) return reply(400, { error: 'Invalid task.' });
      const document = await getDocument(`${path}/${body.taskId}`);
      if (!document || !taskVisible(fields(document), account, space, now)) return reply(404, { error: 'Task unavailable.' });
      const currentSpace = await authorizedSpace(body.spaceId, uid);
      const currentAccount = fields(await getDocument(`accounts/${uid}`));
      if (!taskVisible(fields(document), currentAccount, currentSpace, new Date())) return reply(404, { error: 'Task unavailable.' });
      return reply(200, { task: { ...fields(document), id: body.taskId } });
    }
    if (body.action !== 'list') return reply(400, { error: 'Unknown action.' });
    const filters: any[] = [{ fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: { stringValue: 'completed' } } }];
    if (!hasPlus(account, now)) filters.push({ fieldFilter: { field: { fieldPath: 'completedAt' }, op: 'GREATER_THAN_OR_EQUAL', value: { timestampValue: historyStart(now, space.timeZone).toISOString() } } });
    if (body.personUid != null) {
      if (!validId(body.personUid) || !space.memberUids.includes(body.personUid)) return reply(400, { error: 'Invalid member.' });
      filters.push({ fieldFilter: { field: { fieldPath: 'ownerUid' }, op: 'EQUAL', value: { stringValue: body.personUid } } });
    }
    const query: any = {
      from: [{ collectionId: 'tasks' }],
      where: filters.length === 1 ? filters[0] : { compositeFilter: { op: 'AND', filters } },
      orderBy: [{ field: { fieldPath: 'completedAt' }, direction: 'DESCENDING' }, { field: { fieldPath: '__name__' }, direction: 'DESCENDING' }],
      limit: 50,
    };
    if (body.cursorId != null) {
      if (!validId(body.cursorId)) return reply(400, { error: 'Invalid page.' });
      const cursor = await getDocument(`${path}/${body.cursorId}`);
      const task = fields(cursor);
      if (!cursor || task.status !== 'completed' || !taskVisible(task, account, space, now) ||
          (body.personUid != null && task.ownerUid !== body.personUid)) return reply(409, { error: 'History changed. Refresh the list.' });
      query.startAt = { before: false, values: [cursor.fields.completedAt, { referenceValue: cursor.name }] };
    }
    const response = await fetch(`${root}/spaces/${body.spaceId}:runQuery`, {
      method: 'POST', headers: { authorization: `Bearer ${await adminToken()}`, 'content-type': 'application/json' },
      body: JSON.stringify({ structuredQuery: query }),
    });
    if (!response.ok) throw new AccessFailure('Could not load history. Try again.', 503);
    const result = await response.json();
    const documents = result.filter((item: any) => item.document).map((item: any) => item.document);
    // Membership and the entitlement may change while the query is running.
    const currentSpace = await authorizedSpace(body.spaceId, uid);
    const currentAccount = fields(await getDocument(`accounts/${uid}`));
    const tasks = documents.filter((document: any) => taskVisible(fields(document), currentAccount, currentSpace, new Date()))
      .map((document: any) => ({ ...fields(document), id: document.name.split('/').pop() }));
    return reply(200, { tasks, todayLocalDate: localDate(now, currentSpace.timeZone), nextCursorId: documents.length === 50 ? documents.at(-1).name.split('/').pop() : null });
  } catch (error) {
    if (error instanceof AccessFailure) return reply(error.status, { error: error.message });
    if (error instanceof SyntaxError) return reply(400, { error: 'Invalid request.' });
    return reply(503, { error: 'Could not load tasks. Try again.' });
  }
});
