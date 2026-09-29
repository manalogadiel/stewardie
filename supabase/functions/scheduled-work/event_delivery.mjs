export function eventRecipients(event, currentMemberUids, fallbackAffectedUids = []) {
  const current = new Set(currentMemberUids);
  const original = Array.isArray(event.recipientUids) ? event.recipientUids : [];
  const affected = new Set(Array.isArray(event.affectedUids)
    ? event.affectedUids : fallbackAffectedUids);
  const type = String(event.type ?? '');
  const target = typeof event.targetUid === 'string' ? event.targetUid : null;
  return [...new Set(original.filter((uid) =>
    typeof uid === 'string' && current.has(uid) && uid !== event.actorUid && (
      type === 'ownershipOffered' || type === 'taskAssigned' ? uid === target
        : type === 'covered' || type === 'completed' ? affected.has(uid)
          : true
    ),
  ))];
}

export function eventInboxId(spaceId, eventId) {
  return `event_${spaceId}_${eventId}`;
}
