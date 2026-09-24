-- Private media metadata. Firebase remains authoritative for identity/space roles.
begin;
create table if not exists public.media_items (
 id text primary key, space_id text not null, uploader_uid text not null,
 task_id text, caption text not null default '', task_title text, completed_by text,
 state text not null default 'reserved' check(state in ('reserved','ready','deleting','deleted')),
 digest text not null, byte_count bigint not null check(byte_count > 0 and byte_count <= 2200000),
 width int not null, height int not null, source text not null,
 created_at timestamptz not null default now(), published_at timestamptz,
 reserved_at timestamptz not null default now(), quota_day date not null default (now() at time zone 'utc')::date
);
create index if not exists media_space_created on public.media_items(space_id,created_at desc,id);
create index if not exists media_task on public.media_items(space_id,task_id);
create table if not exists public.media_daily(uid text not null, day date not null, count int not null default 0, primary key(uid,day));
alter table public.media_items enable row level security;
alter table public.media_daily enable row level security;
revoke all on public.media_items,public.media_daily from anon,authenticated;
grant all on public.media_items,public.media_daily to service_role;
-- No direct-client policies: only the Firebase-verifying gateway can use these.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('moments','moments',false,2000000,array['image/jpeg']) on conflict(id) do nothing;

create or replace function public.reserve_media(p jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r media_items; used bigint; n int; d date := (now() at time zone 'utc')::date;
begin
 perform pg_advisory_xact_lock(71924001); -- Small pilot: serialize quota reservations.
 select * into r from media_items where id=p->>'id' for update;
 if found then
  if r.uploader_uid<>p->>'uid' or r.space_id<>p->>'space' or r.digest<>p->>'digest'
     or r.caption<>p->>'caption' or r.task_id is distinct from nullif(p->>'task','')
     or r.state in ('deleted','deleting') then raise exception 'This upload ID cannot be reused.'; end if;
  return to_jsonb(r);
 end if;
 select coalesce(sum(byte_count),0) into used from media_items where state<>'deleted';
 if used+(p->>'bytes')::bigint>900000000 then raise exception 'Shared photo pilot storage is full. You can still complete tasks.'; end if;
 select coalesce(sum(byte_count),0) into used from media_items where uploader_uid=p->>'uid' and state<>'deleted';
 if used+(p->>'bytes')::bigint>(case when (p->>'plus')::boolean then 5000000000 else 100000000 end) then raise exception 'Your photo storage is full.'; end if;
 select coalesce((select count from media_daily where uid=p->>'uid' and day=d),0)
  +(select count(*) from media_items where uploader_uid=p->>'uid' and state='reserved') into n;
 if n>=(case when (p->>'plus')::boolean then 100 else 10 end) then raise exception 'Daily photo limit reached. Resets at 00:00 UTC.'; end if;
 if nullif(p->>'task','') is not null then
  select count(*) into n from media_items where space_id=p->>'space' and task_id=p->>'task' and state<>'deleted';
  if n>=(case when (p->>'plus')::boolean then 5 else 1 end) then raise exception 'This task has reached its photo limit.'; end if;
 end if;
 insert into media_items(id,space_id,uploader_uid,task_id,caption,digest,byte_count,width,height,source)
 values(p->>'id',p->>'space',p->>'uid',nullif(p->>'task',''),p->>'caption',p->>'digest',(p->>'bytes')::bigint,(p->>'width')::int,(p->>'height')::int,p->>'source') returning * into r;
 return to_jsonb(r);
end $$;
create or replace function public.finish_media(p_id text,p_uid text,p_published timestamptz,p_title text,p_completed text,p_plus boolean) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r media_items; d date := (now() at time zone 'utc')::date; n int;
begin
 perform pg_advisory_xact_lock(71924001);
 select * into r from media_items where id=p_id and uploader_uid=p_uid for update;
 if not found or r.state not in ('reserved','ready') then raise exception 'Upload unavailable.'; end if;
 if r.state='ready' then return to_jsonb(r); end if;
 select coalesce((select count from media_daily where uid=p_uid and day=d),0) into n;
 if n>=(case when p_plus then 100 else 10 end) then raise exception 'Daily photo limit reached. Retry after 00:00 UTC.'; end if;
 insert into media_daily(uid,day,count) values(p_uid,d,1) on conflict(uid,day) do update set count=media_daily.count+1;
 update media_items set state='ready',published_at=p_published,task_title=p_title,completed_by=p_completed,quota_day=d where id=p_id returning * into r;
 return to_jsonb(r);
end $$;
revoke all on function public.reserve_media(jsonb),public.finish_media(text,text,timestamptz,text,text,boolean) from public,anon,authenticated;
grant execute on function public.reserve_media(jsonb),public.finish_media(text,text,timestamptz,text,text,boolean) to service_role;
commit;
