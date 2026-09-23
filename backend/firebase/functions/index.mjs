import { createHash, randomBytes } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

import {
  accountLimits,
  basicHistoryStart,
  DomainError,
  localCalendarDate,
  requireId,
  requireText,
  transitionTask,
} from './lib/domain.mjs';

initializeApp();
const db = getFirestore();

function verifiedUid(request) {
  const uid = request.auth?.uid;
  if (!uid || request.auth.token.email_verified !== true) {
    throw new HttpsError('unauthenticated', 'Sign in with a verified email.');
  }
  return uid;
}

function memberName(request) {
  const name = request.auth?.token?.name;
  return typeof name === 'string' && name.trim()
    ? name.trim().slice(0, 60)
    : 'Member';
}

function inviteHash(token) {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{32}$/.test(token)) {
    throw new DomainError('invalid-argument', 'Invitation code is invalid.');
  }
  return createHash('sha256').update(token).digest('hex');
}

function checked(handler) {
  return onCall({ maxInstances: 5 }, async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof DomainError) {
        throw new HttpsError(error.code, error.message);
      }
      if (error instanceof HttpsError) throw error;
      console.error('Callable failed', error);
      throw new HttpsError('internal', 'Could not complete the request.');
    }
  });
}

async function activeMember(transaction, spaceId, uid) {
  const member = await transaction.get(
    db.doc(`spaces/${spaceId}/members/${uid}`),
  );
  if (!member.exists || member.get('status') !== 'active') {
    throw new DomainError('permission-denied', 'You are not a member of this space.');
  }
}

const spaceKinds = new Set(['family', 'housemates', 'friends', 'crew', 'custom']);

export const createSpace = checked(async (request) => {
  const uid = verifiedUid(request);
  const name = requireText(request.data?.name, 'Space name', 80);
  const kind = request.data?.kind;
  if (!spaceKinds.has(kind)) {
    throw new DomainError('invalid-argument', 'Choose a valid space type.');
  }
  const timeZone = requireText(request.data?.timeZone, 'Time zone', 64);
  try {
    new Intl.DateTimeFormat('en', { timeZone });
  } catch (_) {
    throw new DomainError('invalid-argument', 'Choose a valid IANA time zone.');
  }
  const accountRef = db.doc(`accounts/${uid}`);
  const spaceRef = db.collection('spaces').doc();
  await db.runTransaction(async (tx) => {
    const account = await tx.get(accountRef);
    const tier = account.exists && account.get('tier') === 'plus' ? 'plus' : 'basic';
    const owned = account.exists ? account.get('ownedSpaceCount') ?? 0 : 0;
    const memberships = account.exists ? account.get('membershipCount') ?? 0 : 0;
    const limits = accountLimits(tier);
    if (owned >= limits.ownedSpaces || memberships >= limits.memberships) {
      throw new DomainError('resource-exhausted', 'Your space limit has been reached.');
    }
    tx.set(accountRef, {
      tier,
      ownedSpaceCount: owned + 1,
      membershipCount: memberships + 1,
    }, { merge: true });
    tx.create(spaceRef, {
      name, kind, timeZone, ownerUid: uid,
      memberCount: 1, activeTaskCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(spaceRef.collection('members').doc(uid), {
      uid, name: memberName(request), role: 'owner', status: 'active',
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.create(accountRef.collection('spaceRefs').doc(spaceRef.id), {
      spaceId: spaceRef.id, name, kind,
      joinedAt: FieldValue.serverTimestamp(),
    });
  });
  return { spaceId: spaceRef.id };
});

export const createInvite = checked(async (request) => {
  const uid = verifiedUid(request);
  const spaceId = requireId(request.data?.spaceId, 'Space ID');
  const token = randomBytes(24).toString('base64url');
  const inviteRef = db.doc(`inviteDirectory/${inviteHash(token)}`);
  const spaceRef = db.doc(`spaces/${spaceId}`);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  await db.runTransaction(async (tx) => {
    const [space, member] = await Promise.all([
      tx.get(spaceRef),
      tx.get(spaceRef.collection('members').doc(uid)),
    ]);
    if (!space.exists || !member.exists || member.get('status') !== 'active' ||
        !['owner', 'admin'].includes(member.get('role'))) {
      throw new DomainError('permission-denied', 'Only space managers can invite people.');
    }
    tx.create(inviteRef, {
      spaceId, spaceName: space.get('name'), kind: space.get('kind'),
      creatorUid: uid, uses: 0, maxUses: 20, revoked: false,
      createdAt: FieldValue.serverTimestamp(), expiresAt,
    });
  });
  return { token, expiresAt: expiresAt.toISOString() };
});

export const previewInvite = checked(async (request) => {
  const hash = inviteHash(request.data?.token);
  const invite = await db.doc(`inviteDirectory/${hash}`).get();
  if (!invite.exists || invite.get('revoked') ||
      invite.get('expiresAt').toMillis() <= Date.now() ||
      invite.get('uses') >= invite.get('maxUses')) {
    throw new DomainError('not-found', 'Invitation is no longer available.');
  }
  return { spaceName: invite.get('spaceName'), kind: invite.get('kind') };
});

export const redeemInvite = checked(async (request) => {
  const uid = verifiedUid(request);
  const hash = inviteHash(request.data?.token);
  const inviteRef = db.doc(`inviteDirectory/${hash}`);
  return db.runTransaction(async (tx) => {
    const invite = await tx.get(inviteRef);
    if (!invite.exists || invite.get('revoked') ||
        invite.get('expiresAt').toMillis() <= Date.now() ||
        invite.get('uses') >= invite.get('maxUses')) {
      throw new DomainError('not-found', 'Invitation is no longer available.');
    }
    const spaceId = invite.get('spaceId');
    const spaceRef = db.doc(`spaces/${spaceId}`);
    const accountRef = db.doc(`accounts/${uid}`);
    const memberRef = spaceRef.collection('members').doc(uid);
    const [space, account, member] = await Promise.all([
      tx.get(spaceRef), tx.get(accountRef), tx.get(memberRef),
    ]);
    if (!space.exists) throw new DomainError('not-found', 'Space not found.');
    if (member.exists && member.get('status') === 'active') {
      return { spaceId, alreadyMember: true };
    }
    if ((space.get('memberCount') ?? 0) >= 20) {
      throw new DomainError('resource-exhausted', 'This space is full.');
    }
    const tier = account.exists && account.get('tier') === 'plus' ? 'plus' : 'basic';
    const memberships = account.exists ? account.get('membershipCount') ?? 0 : 0;
    if (memberships >= accountLimits(tier).memberships) {
      throw new DomainError('resource-exhausted', 'Your space limit has been reached.');
    }
    tx.set(memberRef, {
      uid, name: memberName(request), role: 'member', status: 'active',
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.set(accountRef, { tier, membershipCount: memberships + 1 }, { merge: true });
    tx.set(accountRef.collection('spaceRefs').doc(spaceId), {
      spaceId, name: space.get('name'), kind: space.get('kind'),
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.update(spaceRef, { memberCount: FieldValue.increment(1) });
    tx.update(inviteRef, { uses: FieldValue.increment(1) });
    return { spaceId, alreadyMember: false };
  });
});

export const revokeInvite = checked(async (request) => {
  const uid = verifiedUid(request);
  const inviteRef = db.doc(`inviteDirectory/${inviteHash(request.data?.token)}`);
  await db.runTransaction(async (tx) => {
    const invite = await tx.get(inviteRef);
    if (!invite.exists) throw new DomainError('not-found', 'Invitation not found.');
    const memberRef = db.doc(`spaces/${invite.get('spaceId')}/members/${uid}`);
    const member = await tx.get(memberRef);
    if (!member.exists || member.get('status') !== 'active' ||
        !['owner', 'admin'].includes(member.get('role'))) {
      throw new DomainError('permission-denied', 'Only space managers can revoke invitations.');
    }
    tx.update(inviteRef, { revoked: true });
  });
  return { revoked: true };
});

export const createTask = checked(async (request) => {
  const uid = verifiedUid(request);
  const spaceId = requireId(request.data?.spaceId, 'Space ID');
  const title = requireText(request.data?.title, 'Task name', 120);
  const requestedUid = request.data?.requestedUid ?? null;
  if (requestedUid !== null) requireId(requestedUid, 'Requested member ID');
  const spaceRef = db.doc(`spaces/${spaceId}`);
  const taskRef = spaceRef.collection('tasks').doc();
  await db.runTransaction(async (tx) => {
    const space = await tx.get(spaceRef);
    if (!space.exists) throw new DomainError('not-found', 'Space not found.');
    await activeMember(tx, spaceId, uid);
    if (requestedUid !== null) await activeMember(tx, spaceId, requestedUid);
    if ((space.get('activeTaskCount') ?? 0) >= 300) {
      throw new DomainError('resource-exhausted', 'This space has reached its active task limit.');
    }
    tx.create(taskRef, {
      title, creatorUid: uid, requestedUid,
      ownerUid: null, offeredUid: null,
      status: requestedUid === null ? 'unclaimed' : 'requested',
      completedAt: null, version: 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(spaceRef, { activeTaskCount: FieldValue.increment(1) });
  });
  return { taskId: taskRef.id };
});

export const actOnTask = checked(async (request) => {
  const uid = verifiedUid(request);
  const spaceId = requireId(request.data?.spaceId, 'Space ID');
  const taskId = requireId(request.data?.taskId, 'Task ID');
  const operationId = requireId(request.data?.operationId, 'Operation ID');
  const action = requireText(request.data?.action, 'Action', 32);
  const spaceRef = db.doc(`spaces/${spaceId}`);
  const taskRef = spaceRef.collection('tasks').doc(taskId);
  const operationRef = taskRef.collection('operations').doc(`${uid}_${operationId}`);
  return db.runTransaction(async (tx) => {
    const space = await tx.get(spaceRef);
    if (!space.exists) throw new DomainError('not-found', 'Space not found.');
    await activeMember(tx, spaceId, uid);
    const task = await tx.get(taskRef);
    if (!task.exists) throw new DomainError('not-found', 'Task not found.');
    const previous = await tx.get(operationRef);
    if (previous.exists) {
      if (previous.get('action') !== action) {
        throw new DomainError('already-exists', 'That operation ID was used for a different action.');
      }
      return { taskId, version: previous.get('resultVersion'), alreadyApplied: true };
    }
    const current = task.data();
    const now = new Date();
    const result = transitionTask(current, action, uid, now.toISOString());
    if (action === 'confirmHandoff') {
      await activeMember(tx, spaceId, current.offeredUid);
    }
    const version = (current.version ?? 0) + 1;
    tx.update(taskRef, {
      ...result,
      ...(action === 'complete'
        ? { completedLocalDate: localCalendarDate(now, space.get('timeZone')) }
        : {}),
      version, updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(operationRef, {
      actorUid: uid, action, resultVersion: version,
      appliedAt: FieldValue.serverTimestamp(),
    });
    if (action === 'complete') {
      tx.update(spaceRef, {
        activeTaskCount: Math.max(0, (space.get('activeTaskCount') ?? 1) - 1),
      });
    }
    return { taskId, version, alreadyApplied: false };
  });
});

export const listCompletedTasks = checked(async (request) => {
  const uid = verifiedUid(request);
  const spaceId = requireId(request.data?.spaceId, 'Space ID');
  const cursorId = request.data?.cursorId ?? null;
  const personUid = request.data?.personUid ?? null;
  if (cursorId !== null) requireId(cursorId, 'Cursor ID');
  if (personUid !== null) requireId(personUid, 'Person ID');
  const spaceRef = db.doc(`spaces/${spaceId}`);
  const [space, member, account] = await Promise.all([
    spaceRef.get(),
    spaceRef.collection('members').doc(uid).get(),
    db.doc(`accounts/${uid}`).get(),
  ]);
  if (!space.exists) throw new DomainError('not-found', 'Space not found.');
  if (!member.exists || member.get('status') !== 'active') {
    throw new DomainError('permission-denied', 'You are not a member of this space.');
  }
  const plus = account.exists && account.get('tier') === 'plus';
  const tasks = spaceRef.collection('tasks');
  let query = tasks.where('status', '==', 'completed');
  if (personUid !== null) query = query.where('ownerUid', '==', personUid);
  if (plus) {
    query = query.orderBy('completedAt', 'desc');
  } else {
    query = query
      .where('completedLocalDate', '>=', basicHistoryStart(new Date(), space.get('timeZone')))
      .orderBy('completedLocalDate', 'desc')
      .orderBy('completedAt', 'desc');
  }
  // Count before paging so the Today summary remains accurate.
  const count = await query.count().get();
  if (cursorId !== null) {
    const cursor = await tasks.doc(cursorId).get();
    if (!cursor.exists || cursor.get('status') !== 'completed') {
      throw new DomainError('invalid-argument', 'History cursor is invalid.');
    }
    query = query.startAfter(cursor);
  }
  const page = await query.limit(41).get();
  const visible = page.docs.slice(0, 40);
  return {
    tasks: visible.map((doc) => ({ id: doc.id, ...doc.data() })),
    totalCount: count.data().count,
    nextCursorId: page.docs.length > 40 ? visible.at(-1).id : null,
  };
});
