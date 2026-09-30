export function localDate(instant, zone = 'UTC') {
  let formatter;
  try { formatter = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }); }
  catch { formatter = new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC', year: 'numeric', month: '2-digit', day: '2-digit' }); }
  const parts = formatter.formatToParts(instant);
  const value = (type) => parts.find((part) => part.type === type).value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}

export function historyStart(now, zone = 'UTC') {
  const today = localDate(now, zone);
  const calendarDate = new Date(`${today}T00:00:00Z`);
  calendarDate.setUTCDate(calendarDate.getUTCDate() - 3);
  const oldestDate = calendarDate.toISOString().slice(0, 10);
  let low = calendarDate.getTime() - 36 * 3600000;
  let high = calendarDate.getTime() + 36 * 3600000;
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (localDate(new Date(middle), zone) < oldestDate) low = middle;
    else high = middle;
  }
  return new Date(high);
}

export function hasPlus(account, now) {
  return account.tier === 'plus' && (account.founderGrant === true ||
    account.entitlementSource === 'founder' || Date.parse(account.subscriptionExpiresAt ?? '') > now.getTime());
}

export function taskVisible(task, account, space, now) {
  if (task.status !== 'completed') return true;
  if (hasPlus(account, now)) return true;
  const completed = Date.parse(task.completedAt ?? '');
  return Number.isFinite(completed) && completed >= historyStart(now, space.timeZone).getTime();
}
