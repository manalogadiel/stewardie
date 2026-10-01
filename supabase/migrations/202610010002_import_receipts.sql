-- Import receipts are operator-only; migration emits no historical notifications.
create table stewardie_core.imports (
  checksum text primary key check (checksum ~ '^[0-9a-f]{64}$'),
  counts jsonb not null,
  imported_at timestamptz not null default now()
);
alter table stewardie_core.imports enable row level security;
revoke all on stewardie_core.imports from public,anon,authenticated;
