// Pure Firestore REST query builders shared with regression tests.
export function timestampBatch(collection, field, since, cursor, descendants = false) {
  const query = {
    from: [{ collectionId: collection, allDescendants: descendants }],
    where: { fieldFilter: { field: { fieldPath: field }, op: 'GREATER_THAN_OR_EQUAL', value: { timestampValue: since } } },
    orderBy: [{ field: { fieldPath: field }, direction: 'ASCENDING' }, { field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
    limit: 100,
  };
  if (cursor) query.startAt = { before: false, values: [{ timestampValue: cursor.time }, { referenceValue: cursor.name }] };
  return query;
}
export function pendingPushes(cursor) {
  const query = { from: [{ collectionId: 'activity' }], where: { fieldFilter: {
    field: { fieldPath: 'pushState' }, op: 'EQUAL', value: { stringValue: 'pending' },
  } }, orderBy: [{ field: {fieldPath: '__name__'}, direction: 'ASCENDING' }], limit: 100 };
  if (cursor) query.startAt = {before: false, values: [{referenceValue: cursor}]};
  return query;
}
