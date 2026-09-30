// First successful deployment of this notification expansion.
export const notificationRollout = Date.parse('2026-09-30T14:40:38Z');
export function socialEligible(prefs, category, time, joinedAt) {
  const since = Date.parse(String(prefs.updatedAt ?? ''));
  const joined = Date.parse(String(joinedAt ?? ''));
  return prefs[category] !== false && Date.parse(time) >= Math.max(
    Number.isFinite(since) ? since : 0, Number.isFinite(joined) ? joined : 0, notificationRollout,
  );
}
export function pushEnabled(global, space) { return global.enabled !== false && space.enabled !== false; }
