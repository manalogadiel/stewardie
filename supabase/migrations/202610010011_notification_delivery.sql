-- Correct notification destinations, private account notices and efficient delivery.
create or replace function stewardie_core.notice_visible(p_uid text,v jsonb) returns boolean language sql set search_path='' as $$
  select coalesce(v->>'accountNotice'='true',false) or exists(select 1 from stewardie_core.spaces s join stewardie_core.members m on m.space_id=s.id
    where s.id=v->>'spaceId' and s.deleted_at is null and m.uid=p_uid
    and (v->>'taskId' is null or exists(select 1 from stewardie_core.tasks t where t.space_id=s.id and t.id=v->>'taskId'
      and (t.status<>'completed' or t.completed_at>=((now() at time zone s.time_zone)::date-3)::timestamp at time zone s.time_zone
        or exists(select 1 from stewardie_core.accounts a where a.uid=p_uid and (a.founder_grant or a.subscription_expires_at>now()))))));
$$;
create or replace function stewardie_core.deliver_events() returns void language plpgsql set search_path='' as $$
begin
  insert into stewardie_core.documents(path,data)
  select 'accounts/'||m.uid||'/activity/core_'||e.id,
    jsonb_build_object('kind',e.event_type,'spaceId',s.id,'spaceName',s.name,'actorUid',e.actor_uid,'entityId',e.entity_id,
      'taskId',case when e.event_type in ('taskAssigned','helpRequested','helpOffered','covered','completed','taskEdited','taskDeclined','taskArrival') then e.entity_id else null end,
      'planId',case when e.event_type in ('planAdded','planChanged','planCancelled','planArrival') then e.entity_id else null end,'taskVersion',e.task_version,'readAt',null,
      'createdAt',e.created_at,'pushState','pending','pushId','core_'||e.id,'title',
        case e.event_type when 'joined' then 'Someone joined your space' when 'left' then 'A member left your space'
          when 'removed' then 'Your space members changed' when 'ownershipOffered' then 'An ownership offer for you'
          when 'ownershipAccepted' then 'Your space has a new owner' when 'taskAssigned' then 'A task request for you'
          when 'helpRequested' then 'A member needs a hand' when 'covered' then 'A task is covered'
          when 'completed' then 'A task is done' when 'mood' then 'Mood check-in' when 'locationStarted' then 'Location sharing started'
          when 'locationEnded' then 'Location sharing ended' when 'planAdded' then 'A new calendar plan' when 'planChanged' then 'A calendar plan changed' when 'planCancelled' then 'A calendar plan was removed' else 'An update in your space' end,
      'body',coalesce(t.title,s.name))
  from stewardie_core.events e join stewardie_core.spaces s on s.id=e.space_id and s.deleted_at is null
    join stewardie_core.members m on m.space_id=s.id and m.uid=any(e.recipient_uids) and m.uid<>e.actor_uid
    left join stewardie_core.tasks t on t.space_id=s.id and t.id=e.entity_id
  where e.created_at>now()-interval '30 days' and not exists(select 1 from stewardie_core.documents d where d.path='accounts/'||m.uid||'/activity/core_'||e.id) and (t.id is null or t.status<>'completed'
    or exists(select 1 from stewardie_core.accounts a where a.uid=m.uid and (a.founder_grant or a.subscription_expires_at>now()))
    or t.completed_at>=((now() at time zone s.time_zone)::date-3)::timestamp at time zone s.time_zone)
  on conflict(path) do nothing;
end;
$$;