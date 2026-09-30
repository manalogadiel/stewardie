export const reactionTypes = new Set(['like', 'cheer', 'haha', 'sad', 'heart', 'mad']);
export class ReactionFailure extends Error {
  constructor(message, status = 403) { super(message); this.status = status; }
}
export function assertReactionAccess({ photo, photoId, spaceId, uid, members, type, change, blocked = false }) {
  if (!photo || photo.id !== photoId || photo.space_id !== spaceId || photo.state !== 'ready' || !photo.published_at) {
    throw new ReactionFailure('This photo is unavailable.', 404);
  }
  if (!members.includes(uid) || blocked) throw new ReactionFailure('Reactions are unavailable for this photo.');
  if (change && type !== null && !reactionTypes.has(type)) throw new ReactionFailure('Choose a valid reaction.', 400);
}
