export class DomainError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
  }
}

export function requireText(value, label, maxLength) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > maxLength) {
    throw new DomainError('invalid-argument', `${label} must be 1–${maxLength} characters.`);
  }
  return value.trim();
}

export function requireId(value, label = 'ID') {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{8,80}$/.test(value)) {
    throw new DomainError('invalid-argument', `${label} is invalid.`);
  }
  return value;
}

export function accountLimits(tier) {
  return tier === 'plus'
    ? { ownedSpaces: 20, memberships: 50 }
    : { ownedSpaces: 3, memberships: 3 };
}

export function localCalendarDate(now, timeZone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

export function basicHistoryStart(now, timeZone) {
  const today = localCalendarDate(now, timeZone);
  const [year, month, day] = today.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day - 3)).toISOString().slice(0, 10);
}

export function nextLocalMidnight(now, timeZone) {
  const today = localCalendarDate(now, timeZone);
  let low = now.getTime();
  let high = low + 48 * 60 * 60 * 1000;
  while (low + 1 < high) {
    const middle = Math.floor((low + high) / 2);
    if (localCalendarDate(new Date(middle), timeZone) === today) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return new Date(high);
}

export function transitionTask(task, action, actorUid, completedAt) {
  const next = {
    status: task.status,
    ownerUid: task.ownerUid ?? null,
    requestedUid: task.requestedUid ?? null,
    offeredUid: task.offeredUid ?? null,
    completedAt: task.completedAt ?? null,
  };
  switch (action) {
    case 'accept':
      if (!(
        task.status === 'unclaimed' ||
        (task.status === 'requested' && task.requestedUid === actorUid)
      )) break;
      next.status = 'accepted';
      next.ownerUid = actorUid;
      next.requestedUid = null;
      return next;
    case 'decline':
      if (task.status !== 'requested' || task.requestedUid !== actorUid) break;
      next.status = 'unclaimed';
      next.requestedUid = null;
      return next;
    case 'needHelp':
      if (task.status !== 'accepted' || task.ownerUid !== actorUid) break;
      next.status = 'needsHelp';
      return next;
    case 'offerHelp':
      if (task.status !== 'needsHelp' || task.ownerUid === actorUid || task.offeredUid) break;
      next.offeredUid = actorUid;
      return next;
    case 'confirmHandoff':
      if (task.status !== 'needsHelp' || task.ownerUid !== actorUid || !task.offeredUid) break;
      next.status = 'accepted';
      next.ownerUid = task.offeredUid;
      next.offeredUid = null;
      return next;
    case 'complete':
      if (!['accepted', 'needsHelp'].includes(task.status) || task.ownerUid !== actorUid) break;
      next.status = 'completed';
      next.offeredUid = null;
      next.completedAt = completedAt;
      return next;
    default:
      throw new DomainError('invalid-argument', 'Unknown task action.');
  }
  throw new DomainError('failed-precondition', 'This task action is no longer available.');
}

export function validateFounderTarget(record, expectedEmail) {
  if (!record || typeof expectedEmail !== 'string' || !expectedEmail.trim()) {
    throw new DomainError('invalid-argument', 'A real account and exact email are required.');
  }
  if (record.email?.toLowerCase() !== expectedEmail.trim().toLowerCase()) {
    throw new DomainError('failed-precondition', 'The account email does not match the requested grant.');
  }
  if (record.emailVerified !== true) {
    throw new DomainError('failed-precondition', 'Verify ownership of the email before granting Plus.');
  }
  if (typeof record.uid !== 'string' || !record.uid) {
    throw new DomainError('failed-precondition', 'The account has no stable UID.');
  }
  return record.uid;
}
