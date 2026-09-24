-- Add non-destructive framing persistence to media_items
begin;

alter table public.media_items
  add column if not exists framing jsonb not null default '{"x":0,"y":0,"width":1,"height":1,"ratioName":"original"}'::jsonb;

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
 insert into media_items(id,space_id,uploader_uid,task_id,caption,digest,byte_count,width,height,source,framing)
 values(p->>'id',p->>'space',p->>'uid',nullif(p->>'task',''),p->>'caption',p->>'digest',(p->>'bytes')::bigint,(p->>'width')::int,(p->>'height')::int,p->>'source',coalesce(p->'framing','{"x":0,"y":0,"width":1,"height":1,"ratioName":"original"}'::jsonb)) returning * into r;
 return to_jsonb(r);
end $$;

commit;
