import { JoinFailure } from './join_space.mjs';

// Called only with verified identity and server-fetched space/session data.
export function visibleLocations(uid, space, sessions, now = new Date()) {
  if (!space || space.deletionStatus === 'pending' || !space.memberUids?.includes(uid)) {
    throw new JoinFailure('You are no longer in this space.', 403);
  }
  return sessions.filter(session =>
    space.memberUids.includes(session.uid) &&
    Array.isArray(session.recipientUids) && session.recipientUids.includes(uid) &&
    Date.parse(session.expiresAt) > now.getTime() &&
    Number.isFinite(session.lat) && session.lat >= -90 && session.lat <= 90 &&
    Number.isFinite(session.lng) && session.lng >= -180 && session.lng <= 180
  );
}
