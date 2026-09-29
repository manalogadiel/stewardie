import { FieldValue } from 'firebase-admin/firestore';

const deletedMember = 'deleted-account';
const uidPattern = /^[A-Za-z0-9_-]{1,128}$/;

function assertOk(result, action) {
  if (result.error) throw new Error(`${action}: ${result.error.message}`);
  return result.data;
}

export function anonymizeTask(data, uid) {
  const patch = {};
  for (const field of ['creatorUid', 'ownerUid', 'requestedUid', 'offeredUid', 'handoffToUid']) {
    if (data[field] === uid) patch[field] = field === 'creatorUid' ? deletedMember : null;
  }
  if (data.ownerUid === uid || data.requestedUid === uid) {
    if (data.status !== 'completed') {
      patch.status = 'unclaimed';
      patch.ownerUid = null;
      patch.requestedUid = null;
      patch.offeredUid = null;
    }
  }
  if (Array.isArray(data.activity)) {
    const activity = data.activity.map((item) => item?.uid === uid
      ? { ...item, uid: null, name: 'Former member' } : item);
    if (activity.some((item, index) => item !== data.activity[index])) patch.activity = activity;
  }
  if (Object.keys(patch).length && data.status !== 'completed') {
    patch.version = Number(data.version ?? 0) + 1;
    patch.updatedAt = FieldValue.serverTimestamp();
  }
  return patch;
}

async function rows(query, label) {
  const result = await query;
  return assertOk(result, label) ?? [];
}

async function mediaRows(sb, column, value) {
  const found = [];
  for (let offset = 0; offset < 10000; offset += 100) {
    const page = await rows(sb.from('media_items')
      .select('id,space_id,uploader_uid').eq(column, value)
      .order('id').range(offset, offset + 99), 'List media');
    found.push(...page);
    if (page.length < 100) return found;
  }
  throw new Error('Media inventory exceeded the pilot limit; review manually.');
}

async function deleteMediaRow(sb, row) {
  const prefix = `${row.space_id}/${row.uploader_uid}/${row.id}`;
  assertOk(await sb.storage.from('moments').remove([
    `${prefix}/photo.jpg`, `${prefix}/thumb.jpg`,
  ]), 'Remove photo objects');
  assertOk(await sb.from('media_items').delete().eq('id', row.id), 'Remove media metadata');
}

async function storageFolders(sb, prefix) {
  const folders = [];
  for (let offset = 0; offset < 10000; offset += 100) {
    const page = await rows(sb.storage.from('moments').list(prefix, {
      limit: 100, offset, sortBy: { column: 'name', order: 'asc' },
    }), 'List photo storage');
    folders.push(...page);
    if (page.length < 100) return folders;
  }
  throw new Error('Photo storage inventory exceeded the pilot limit; review manually.');
}

async function clearMedia(sb, uid, spaces, soloSpaceIds) {
  const byId = new Map();
  for (const row of await mediaRows(sb, 'uploader_uid', uid)) byId.set(row.id, row);
  for (const spaceId of soloSpaceIds) {
    for (const row of await mediaRows(sb, 'space_id', spaceId)) byId.set(row.id, row);
  }
  for (const row of byId.values()) await deleteMediaRow(sb, row);

  // A reserved upload always has a row. If files are left without metadata,
  // stop for operator review rather than claiming cleanup is complete.
  for (const spaceId of spaces) {
    const prefix = soloSpaceIds.has(spaceId) ? spaceId : `${spaceId}/${uid}`;
    if ((await storageFolders(sb, prefix)).length) {
      throw new Error(`Photo objects remain under ${prefix}; review storage manually.`);
    }
  }
  assertOk(await sb.from('media_items').update({ completed_by: null })
    .eq('completed_by', uid), 'Clear completion attribution');
  assertOk(await sb.from('media_daily').delete().eq('uid', uid), 'Clear daily photo quota');
  if ((await mediaRows(sb, 'uploader_uid', uid)).length) {
    throw new Error('Media metadata still references this account.');
  }
}

async function scrubSharedSpace(db, space, uid) {
  const ref = space.ref;
  for (const event of (await ref.collection('events').get()).docs) {
    if ([event.get('actorUid'), event.get('targetUid')].includes(uid)) {
      await event.ref.delete();
    } else if (event.get('recipientUids')?.includes(uid)) {
      await event.ref.update({ recipientUids: FieldValue.arrayRemove(uid) });
    }
  }
  for (const task of (await ref.collection('tasks').get()).docs) {
    const patch = anonymizeTask(task.data(), uid);
    if (Object.keys(patch).length) await task.ref.update(patch);
    await task.ref.collection('arrivals').doc(uid).delete();
    for (const op of (await task.ref.collection('operations').get()).docs) {
      if (op.get('actorUid') === uid) await op.ref.delete();
    }
  }
  for (const completion of (await ref.collection('taskCompletions').get()).docs) {
    if (completion.get('ownerUid') === uid) {
      await completion.ref.update({ ownerUid: null });
    }
  }
  for (const plan of (await ref.collection('plans').get()).docs) {
    const data = plan.data();
    if (data.ownerUid === uid) {
      await db.recursiveDelete(plan.ref);
    } else {
      if (Array.isArray(data.participants) && data.participants.includes(uid)) {
        await plan.ref.update({ participants: FieldValue.arrayRemove(uid),
          revision: Number(data.revision ?? 0) + 1, updatedAt: FieldValue.serverTimestamp() });
      }
      await plan.ref.collection('arrivals').doc(uid).delete();
    }
  }
  for (const routine of (await ref.collection('routines').get()).docs) {
    if (routine.get('creatorUid') === uid) await routine.ref.delete();
    else if (routine.get('assignedUid') === uid) await routine.ref.update({ assignedUid: null });
  }
  for (const moment of (await ref.collection('moments').get()).docs) {
    const data = moment.data();
    if ([data.uid, data.creatorUid, data.uploaderUid].includes(uid)) {
      await db.recursiveDelete(moment.ref);
    } else {
      await moment.ref.collection('reactions').doc(uid).delete();
    }
  }
  await Promise.all([
    ref.collection('checkIns').doc(uid).delete(),
    ref.collection('pendingJoins').doc(uid).delete(),
    ref.collection('members').doc(uid).delete(),
  ]);
  for (const session of (await ref.collection('locationSessions').get()).docs) {
    if (session.id === uid) await session.ref.delete();
    else if (session.get('recipientUids')?.includes(uid)) {
      await session.ref.update({ recipientUids: FieldValue.arrayRemove(uid) });
    }
  }
  await ref.update({ routineCount: (await ref.collection('routines').get()).size });
}

async function revokeSpaceAccess(db, space, uid, soloSpaceIds) {
  if (soloSpaceIds.has(space.id)) {
    await space.ref.update({ memberUids: [], memberCount: 0,
      removedUid: FieldValue.delete() });
    await db.recursiveDelete(space.ref.collection('routines'));
    await space.ref.update({ routineCount: 0 });
    return;
  }
  await space.ref.collection('locationSessions').doc(uid).delete();
  await db.runTransaction(async (tx) => {
    const current = await tx.get(space.ref);
    const data = current.data();
    if (!data?.memberUids?.includes(uid)) {
      if (data?.removedUid === uid || data?.pendingOwnerUid === uid) {
        tx.update(space.ref, {
          ...(data.removedUid === uid ? { removedUid: FieldValue.delete() } : {}),
          ...(data.pendingOwnerUid === uid ? { pendingOwnerUid: null } : {}),
        });
      }
      return;
    }
    const remaining = data.memberUids.filter((memberUid) => memberUid !== uid);
    tx.update(space.ref, { memberUids: remaining, memberCount: remaining.length,
      removedUid: FieldValue.delete(),
      ...(data.pendingOwnerUid === uid ? { pendingOwnerUid: null } : {}) });
  });
}

async function hasHistoricalData(space, uid) {
  const ref = space.ref;
  if (space.get('removedUid') === uid || space.get('pendingOwnerUid') === uid) return true;
  for (const collection of ['checkIns', 'locationSessions', 'pendingJoins', 'members']) {
    if ((await ref.collection(collection).doc(uid).get()).exists) return true;
  }
  for (const session of (await ref.collection('locationSessions').get()).docs) {
    if (session.get('recipientUids')?.includes(uid)) return true;
  }
  for (const task of (await ref.collection('tasks').get()).docs) {
    const data = task.data();
    if ([data.creatorUid, data.ownerUid, data.requestedUid, data.offeredUid,
      data.handoffToUid].includes(uid) ||
      data.activity?.some?.((item) => item?.uid === uid) ||
      (await task.ref.collection('arrivals').doc(uid).get()).exists ||
      (await task.ref.collection('operations').where('actorUid', '==', uid).limit(1).get()).size) {
      return true;
    }
  }
  for (const plan of (await ref.collection('plans').get()).docs) {
    if (plan.get('ownerUid') === uid || plan.get('participants')?.includes(uid) ||
      (await plan.ref.collection('arrivals').doc(uid).get()).exists) return true;
  }
  for (const completion of (await ref.collection('taskCompletions').get()).docs) {
    if (completion.get('ownerUid') === uid) return true;
  }
  for (const routine of (await ref.collection('routines').get()).docs) {
    if ([routine.get('creatorUid'), routine.get('assignedUid')].includes(uid)) return true;
  }
  for (const event of (await ref.collection('events').get()).docs) {
    if ([event.get('actorUid'), event.get('targetUid')].includes(uid) ||
        event.get('recipientUids')?.includes(uid)) return true;
  }
  for (const moment of (await ref.collection('moments').get()).docs) {
    const data = moment.data();
    if ([data.uid, data.creatorUid, data.uploaderUid].includes(uid) ||
      (await moment.ref.collection('reactions').doc(uid).get()).exists) return true;
  }
  return false;
}

export async function prepareDeletion({ db, auth, sb, uid }) {
  if (!uidPattern.test(uid)) throw new Error('Use an exact Firebase UID.');
  const request = await db.doc(`deletionRequests/${uid}`).get();
  if (!request.exists || request.get('uid') !== uid ||
      !['pending', 'processing', 'needsAttention'].includes(request.get('status'))) {
    throw new Error('A valid open deletion request for this UID is required.');
  }
  const founder = await db.doc('config/founderPlusGrant').get();
  if (founder.get('uid') === uid) {
    throw new Error('Founder/operator account needs a separate operator handover.');
  }
  let user = null;
  try { user = await auth.getUser(uid); }
  catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
  if (user && user.email?.toLowerCase() !== String(request.get('email')).toLowerCase()) {
    throw new Error('Deletion request email does not match Firebase Auth.');
  }
  if (!user && request.get('status') === 'pending') {
    throw new Error('Auth user is missing for an unprocessed request.');
  }
  const allSpaces = (await db.collection('spaces').get()).docs;
  const deletionJobs = (await db.collection('spaceDeletionJobs')
    .where('requestedBy', '==', uid).get()).docs;
  if (deletionJobs.some((job) => job.get('status') !== 'done')) {
    throw new Error('Finish pending space deletion before deleting this account.');
  }
  const account = await db.doc(`accounts/${uid}`).get();
  const listedSpaceIds = new Set(account.get('spaceIds') ?? []);
  const previousSpaceIds = new Set(request.get('spaceIds') ?? []);
  const previousSoloIds = new Set(request.get('soloSpaceIds') ?? []);
  const spaces = [];
  for (const space of allSpaces) {
    if (space.get('memberUids')?.includes(uid) || space.get('ownerUid') === uid ||
        previousSpaceIds.has(space.id) || listedSpaceIds.has(space.id) ||
        await hasHistoricalData(space, uid)) spaces.push(space);
  }
  if (spaces.some((space) => previousSoloIds.has(space.id) &&
      space.get('ownerUid') !== uid)) {
    throw new Error('A solo space changed ownership during cleanup; review manually.');
  }
  const blocked = spaces.filter((space) => space.get('ownerUid') === uid &&
    (space.get('memberUids') ?? []).some((memberUid) => memberUid !== uid));
  if (blocked.length) throw new Error(
    `Transfer ownership before deletion in ${blocked.map((space) => space.id).join(', ')}.`);
  const soloSpaceIds = new Set([...previousSoloIds,
    ...spaces.filter((space) => space.get('ownerUid') === uid).map((space) => space.id)]);
  const uploaded = await mediaRows(sb, 'uploader_uid', uid);
  const soloMedia = [];
  for (const spaceId of soloSpaceIds) soloMedia.push(...await mediaRows(sb, 'space_id', spaceId));
  const mediaSpaceIds = new Set([...uploaded, ...soloMedia].map((row) => row.space_id));
  return { request, user, spaces, soloSpaceIds, mediaSpaceIds, deletionJobs,
    summary: { sharedSpaces: spaces.filter((space) => !soloSpaceIds.has(space.id)).length,
      soloSpaces: soloSpaceIds.size,
      photos: new Set([...uploaded, ...soloMedia].map((row) => row.id)).size } };
}

export async function processDeletion({ db, auth, sb, uid, apply = false }) {
  const inventory = await prepareDeletion({ db, auth, sb, uid });
  if (!apply) return { applied: false, ...inventory.summary };
  const { request, user, spaces, soloSpaceIds, mediaSpaceIds, deletionJobs } = inventory;
  try {
    await request.ref.set({ status: 'processing', processingAt: FieldValue.serverTimestamp(),
      spaceIds: spaces.map((space) => space.id), soloSpaceIds: [...soloSpaceIds],
      lastError: FieldValue.delete() }, { merge: true });
    if (user) {
      await auth.updateUser(uid, { disabled: true });
      await auth.revokeRefreshTokens(uid);
    }
    // Client rules and the media gateway consult membership. Revoke it before
    // storage cleanup so a still-cached Firebase token loses space access.
    for (const space of spaces) await revokeSpaceAccess(db, space, uid, soloSpaceIds);
    for (const space of spaces) {
      if (!soloSpaceIds.has(space.id)) await scrubSharedSpace(db, space, uid);
    }
    await clearMedia(sb, uid,
      new Set([...spaces.map((space) => space.id), ...mediaSpaceIds,
        ...soloSpaceIds]), soloSpaceIds);
    for (const space of spaces) {
      if (soloSpaceIds.has(space.id)) await db.recursiveDelete(space.ref);
    }
    for (const job of deletionJobs) await job.ref.delete();
    for (const invite of (await db.collection('invites').get()).docs) {
      const data = invite.data();
      if (data.creatorUid === uid || soloSpaceIds.has(data.spaceId)) {
        await invite.ref.delete();
      } else if (data.redeemedUid === uid) {
        await invite.ref.update({ redeemedUid: null, revoked: true });
      }
    }
    for (const report of (await db.collection('safetyReports').get()).docs) {
      if ([report.get('reporterUid'), report.get('targetUid')].includes(uid)) {
        await report.ref.delete();
      }
    }
    for (const account of (await db.collection('accounts').get()).docs) {
      if (account.id === uid) continue;
      await account.ref.collection('blocks').doc(uid).delete();
      for (const item of (await account.ref.collection('activity').get()).docs) {
        const activitySpaceId = item.get('spaceId');
        const planId = item.get('planId');
        const eventId = item.get('eventId');
        const affected = spaces.some((space) => space.id === activitySpaceId) ||
          soloSpaceIds.has(activitySpaceId);
        if (soloSpaceIds.has(activitySpaceId) ||
            (affected && typeof eventId === 'string' &&
              !(await db.doc(`spaces/${activitySpaceId}/events/${eventId}`).get()).exists) ||
            (affected && item.get('kind') === 'plan' &&
              typeof planId === 'string' &&
              !(await db.doc(`spaces/${activitySpaceId}/plans/${planId}`).get()).exists)) {
          await item.ref.delete();
        }
      }
    }
    await db.recursiveDelete(db.doc(`accounts/${uid}`));
    await db.doc(`profiles/${uid}`).delete();
    if (user) await auth.deleteUser(uid);
    if ((await db.collection('spaces').get()).docs.some((space) =>
      space.get('memberUids')?.includes(uid) || space.get('ownerUid') === uid)) {
      throw new Error('A space still references the deleted account.');
    }
    if ((await mediaRows(sb, 'uploader_uid', uid)).length) {
      throw new Error('A photo still references the deleted account.');
    }
    await request.ref.delete();
    return { applied: true, ...inventory.summary };
  } catch (error) {
    await request.ref.set({ status: 'needsAttention', lastError: String(error.message).slice(0, 180),
      updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    throw error;
  }
}
