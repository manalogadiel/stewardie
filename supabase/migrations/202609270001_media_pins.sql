begin;
alter table public.media_items add column if not exists pin jsonb;
commit;
