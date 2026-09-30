import { JoinFailure } from './join_space.mjs';

// The gateway supplies UID and time; neither comes from the caller's payload.
export function locationSession({ uid, space, name, lat, lng, accuracy, durationMinutes, now = new Date() }) {
  if (!space || space.deletionStatus === 'pending' || !space.memberUids?.includes(uid)) {
    throw new JoinFailure('You are no longer in this space.', 403);
  }
  if (![15, 30, 60].includes(durationMinutes) ||
      !Number.isFinite(lat) || lat < -90 || lat > 90 ||
      !Number.isFinite(lng) || lng < -180 || lng > 180 ||
      !Number.isFinite(accuracy) || accuracy < 0 || accuracy > 10000) {
    throw new JoinFailure('Choose a sharing duration and obtain a valid location fix.');
  }
  return {
    uid, name: [...(typeof name === 'string' ? name.trim() : '')].slice(0, 60).join('') || 'Member',
    lat, lng, accuracy, recipientUids: [...space.memberUids], durationMinutes,
    startedAt: now.toISOString(), updatedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + durationMinutes * 60000).toISOString(),
  };
}
