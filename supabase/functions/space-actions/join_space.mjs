import { hasPlus } from '../_shared/history_policy.mjs';

export class JoinFailure extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}

// Trusted identity is supplied by the gateway, never taken from the request.
export function joinPlan({ uid, token, invite, space, account = {}, pending, name = 'Member', now = new Date() }) {
  if (!invite || !space || space.deletionStatus === 'pending') throw new JoinFailure('This invitation is unavailable. Ask the owner for a new code.', 404);
  const members = space.memberUids ?? [];
  if (invite.redeemedUid === uid && members.includes(uid)) return { alreadyJoined: true };
  if (invite.revoked || invite.redeemedUid || !Number.isFinite(Date.parse(invite.expiresAt)) || Date.parse(invite.expiresAt) <= now.getTime()) {
    throw new JoinFailure('This invitation has expired or was already used. Ask for a new code.');
  }
  if (members.includes(uid)) return { alreadyJoined: true };
  if (members.length >= 20) throw new JoinFailure('This space has reached its 20-member limit.');
  if ((invite.requireApproval || space.requireApproval) && (pending?.status !== 'approved' || pending?.token !== token)) {
    throw new JoinFailure('The owner has not approved this request yet.', 403);
  }
  const spaces = [...new Set(account.spaceIds ?? [])];
  if (!spaces.includes(invite.spaceId) && spaces.length >= (hasPlus(account, now) ? 50 : 3)) {
    throw new JoinFailure('Your account has reached its space limit. Leave a space before joining another.');
  }
  return {
    alreadyJoined: false,
    memberUids: [...members, uid],
    spaceIds: [...new Set([...spaces, invite.spaceId])],
    member: { uid, name: [...name.trim()].slice(0, 60).join('') || 'Member', role: 'member', status: 'active', joinedAt: now.toISOString(), joinToken: token },
    event: { type: 'joined', actorUid: uid, entityId: uid, targetUid: uid, recipientUids: [...members, uid], createdAt: now.toISOString() },
  };
}

