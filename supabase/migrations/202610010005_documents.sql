-- Private ancillary records; all client paths are validated by the RPC.
create table stewardie_core.documents(path text primary key,data jsonb not null,updated_at timestamptz not null default now());
alter table stewardie_core.documents enable row level security;
revoke all on stewardie_core.documents from public,anon,authenticated;

create function public.stewardie_core_lookup(p_path text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare parts text[]:=string_to_array(p_path,'/'); s stewardie_core.spaces%rowtype; a stewardie_core.accounts%rowtype; t stewardie_core.tasks%rowtype; v jsonb;
begin
  if parts[1]='accounts' and array_length(parts,1)=2 then
    select * into a from stewardie_core.accounts where uid=parts[2];
    if not found then return null; end if;
    select data into v from stewardie_core.documents where path=p_path;
    return coalesce(v,'{}') || jsonb_build_object('uid',a.uid,'tier',case when a.founder_grant or a.subscription_expires_at>now() then 'plus' else 'basic' end,
      'founderGrant',a.founder_grant,'subscriptionExpiresAt',a.subscription_expires_at,
      'spaceIds',coalesce((select jsonb_agg(m.space_id) from stewardie_core.members m join stewardie_core.spaces sp on sp.id=m.space_id where m.uid=a.uid and sp.deleted_at is null),'[]'),
      'ownedSpaceIds',coalesce((select jsonb_agg(id) from stewardie_core.spaces where owner_uid=a.uid and deleted_at is null),'[]'));
  elsif parts[1]='spaces' then
    select * into s from stewardie_core.spaces where id=parts[2] and deleted_at is null;
    if not found then return null; end if;
    if array_length(parts,1)=2 then
      return jsonb_build_object('name',s.name,'kind',s.kind,'timeZone',s.time_zone,'ownerUid',s.owner_uid,'pendingOwnerUid',s.pending_owner_uid,
        'requireApproval',s.require_approval,'createdAt',s.created_at,
        'memberUids',coalesce((select jsonb_agg(uid) from stewardie_core.members where space_id=s.id),'[]'),
        'memberCount',(select count(*) from stewardie_core.members where space_id=s.id),
        'activeTaskCount',(select count(*) from stewardie_core.tasks where space_id=s.id and status<>'completed'));
    elsif parts[3]='members' and array_length(parts,1)=4 then
      select jsonb_build_object('uid',m.uid,'name',m.name,'role',m.role,'status','active','joinedAt',m.joined_at,
        'photoUrl',(select data->'photoUrl' from stewardie_core.documents where path='accounts/'||m.uid)) into v from stewardie_core.members m where space_id=s.id and uid=parts[4];
      return v;
    elsif parts[3]='tasks' and array_length(parts,1)=4 then
      select * into t from stewardie_core.tasks where space_id=s.id and id=parts[4];
      if not found then return null; end if;
      return t.details || jsonb_build_object('id',t.id,'title',t.title,'creatorUid',t.creator_uid,'ownerUid',t.owner_uid,'requestedUid',t.requested_uid,
        'offeredUid',t.offered_uid,'status',t.status,'version',t.version,'scheduledLocalDate',t.scheduled_local_date,
        'completedAt',t.completed_at,'completedLocalDate',t.completed_local_date,'createdAt',t.created_at,'updatedAt',t.updated_at);
    elsif parts[3]='taskCompletions' then
      select jsonb_build_object('title',title,'completedAt',completed_at,'completedLocalDate',completed_local_date,'ownerUid',owner_uid,'version',version) into v from stewardie_core.tasks where space_id=s.id and id=parts[4] and status='completed';
      return v;
    elsif parts[3]='pendingJoins' then
      select jsonb_build_object('uid',r.uid,'name',r.name,'token',r.code,'status',case when r.status='rejected' then 'declined' else r.status end,'requestedAt',r.created_at) into v from stewardie_core.join_requests r where space_id=s.id and uid=parts[4];
      return v;
    end if;
  end if;
  select data into v from stewardie_core.documents where path=p_path;
  if parts[3]='checkIns' and v->>'localDate' is distinct from (select (now() at time zone time_zone)::date::text from stewardie_core.spaces where id=parts[2]) then return null; end if;
  if parts[3]='locationSessions' and (v->>'expiresAt')::timestamptz<=now() then return null; end if;
  return v;
end;
$$;
revoke all on function public.stewardie_core_lookup(text) from public,anon,authenticated;
grant execute on function public.stewardie_core_lookup(text) to service_role;

create function stewardie_core.notice_visible(p_uid text,v jsonb) returns boolean language sql set search_path='' as $$
  select coalesce(v->>'accountNotice'='true',false) or exists(select 1 from stewardie_core.spaces s join stewardie_core.members m on m.space_id=s.id
    where s.id=v->>'spaceId' and s.deleted_at is null and m.uid=p_uid
    and (v->>'taskId' is null or exists(select 1 from stewardie_core.tasks t where t.space_id=s.id and t.id=v->>'taskId'
      and (t.status<>'completed' or t.completed_at>=((now() at time zone s.time_zone)::date-3)::timestamp at time zone s.time_zone
        or exists(select 1 from stewardie_core.accounts a where a.uid=p_uid and (a.founder_grant or a.subscription_expires_at>now()))))));
$$;
revoke all on function stewardie_core.notice_visible(text,jsonb) from public,anon,authenticated,service_role;

create function stewardie_core.deliver_events() returns void language plpgsql set search_path='' as $$
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
revoke all on function stewardie_core.deliver_events() from public,anon,authenticated,service_role;

create function public.stewardie_core_documents(p_uid text,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare record_path text:=p_payload->>'path'; parts text[]; v jsonb; row_data jsonb; rows jsonb; item jsonb; existing jsonb; sid text; mode text:=coalesce(p_payload->>'mode','set'); field_name text;
begin
  if p_uid is null or length(p_uid) not between 1 and 128 or jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Invalid request' using errcode='22023'; end if;
  if p_action='docReadBatch' then
    if jsonb_typeof(p_payload->'reads') is distinct from 'array' or jsonb_array_length(p_payload->'reads') not between 1 and 100 then raise exception 'Invalid read batch' using errcode='22023'; end if;
    rows:='[]';
    for item in select value from jsonb_array_elements(p_payload->'reads') loop
      begin
        if item->>'action' not in ('docRead','docList') or item->>'action' is null then raise exception 'Invalid read action' using errcode='22023'; end if;
        v:=public.stewardie_core_documents(p_uid,item->>'action',item->'payload');
        rows:=rows||jsonb_build_array(jsonb_build_object('data',v));
      exception when insufficient_privilege then rows:=rows||jsonb_build_array(jsonb_build_object('error','Space or account access ended.','status',403));
        when others then rows:=rows||jsonb_build_array(jsonb_build_object('error','Could not load shared data.','status',503));
      end;
    end loop;
    return jsonb_build_object('results',rows);
  end if;
  if p_action='docBatch' then
    if jsonb_typeof(p_payload->'writes') is distinct from 'array' or jsonb_array_length(p_payload->'writes')>100 then raise exception 'Invalid batch' using errcode='22023'; end if;
    for item in select value from jsonb_array_elements(p_payload->'writes') loop perform public.stewardie_core_documents(p_uid,'docWrite',item); end loop;
    return jsonb_build_object('ok',true);
  end if;
  if record_path is null or record_path !~ '^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+){0,6}$' then raise exception 'Invalid record path' using errcode='22023'; end if;
  parts:=string_to_array(record_path,'/');
  perform pg_advisory_xact_lock(hashtextextended(p_uid,0));
  insert into stewardie_core.accounts(uid) values(p_uid) on conflict do nothing;
  if parts[1]='accounts' then
    if parts[2] is distinct from p_uid then raise exception 'Account access denied' using errcode='42501'; end if;
  elsif parts[1]='profiles' then
    if parts[2]<>p_uid and (p_action<>'docRead' or not exists(select 1 from stewardie_core.members a join stewardie_core.members b on b.space_id=a.space_id join stewardie_core.spaces s on s.id=a.space_id where a.uid=p_uid and b.uid=parts[2] and s.deleted_at is null)) then raise exception 'Profile access denied' using errcode='42501'; end if;
  elsif parts[1]='spaces' then
    sid:=parts[2];
    if not exists(select 1 from stewardie_core.spaces s join stewardie_core.members m on m.space_id=s.id where s.id=sid and s.deleted_at is null and m.uid=p_uid) then raise exception 'Space access ended' using errcode='42501'; end if;
    perform 1 from stewardie_core.spaces where id=sid for update;
    if parts[3]='pendingJoins' and not exists(select 1 from stewardie_core.members where space_id=sid and uid=p_uid and role in ('owner','admin')) then raise exception 'Manager access required' using errcode='42501'; end if;
  elsif parts[1]='spaceDeletionJobs' and p_action='docRead' then
    if not exists(select 1 from stewardie_core.spaces where id=parts[2] and owner_uid=p_uid and deleted_at is not null) then raise exception 'Access denied' using errcode='42501'; end if;
    return jsonb_build_object('data',coalesce(public.stewardie_core_lookup(record_path),jsonb_build_object('status','pending')));
  elsif parts[1]='deletionRequests' and parts[2]=p_uid then null;
  elsif parts[1]='safetyReports' and p_action='docWrite' then null;
  else raise exception 'Record access denied' using errcode='42501'; end if;
  if p_action='docRead' then
    if parts[1]='spaces' and parts[3]='tasks' and array_length(parts,1)=4 then
      perform public.stewardie_core_action(p_uid,'getTask',jsonb_build_object('spaceId',sid,'taskId',parts[4]));
    end if;
    row_data:=public.stewardie_core_lookup(record_path);
    if parts[3]='locationSessions' and (not coalesce(row_data->'recipientUids' ? p_uid,false) or not exists(select 1 from stewardie_core.members where space_id=sid and uid=row_data->>'uid')) then row_data:=null; end if;
    if parts[1]='accounts' and parts[3]='activity' and not stewardie_core.notice_visible(p_uid,row_data) then row_data:=null; end if;
    return jsonb_build_object('data',row_data);
  elsif p_action='docList' then
    if parts[1]='accounts' and parts[3]='spaceRefs' then
      select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'data',public.stewardie_core_lookup('spaces/'||s.id))),'[]') into rows
        from stewardie_core.spaces s join stewardie_core.members m on m.space_id=s.id where m.uid=p_uid and s.deleted_at is null;
    elsif parts[1]='spaces' and parts[3]='members' then
      select coalesce(jsonb_agg(jsonb_build_object('id',m.uid,'data',public.stewardie_core_lookup(record_path||'/'||m.uid))),'[]') into rows from stewardie_core.members m where m.space_id=sid;
    elsif parts[1]='spaces' and parts[3]='tasks' then
      select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'data',public.stewardie_core_lookup(record_path||'/'||t.id)) order by t.updated_at desc),'[]') into rows
      from stewardie_core.tasks t where t.space_id=sid and (not coalesce((p_payload->>'activeOnly')::boolean,false) or t.status<>'completed') and (t.status<>'completed' or exists(select 1 from stewardie_core.accounts a where a.uid=p_uid and (a.founder_grant or a.subscription_expires_at>now()))
        or t.completed_at>=((now() at time zone (select time_zone from stewardie_core.spaces where id=sid))::date-3)::timestamp at time zone (select time_zone from stewardie_core.spaces where id=sid));
    elsif parts[1]='spaces' and parts[3]='pendingJoins' then
      select coalesce(jsonb_agg(jsonb_build_object('id',r.uid,'data',public.stewardie_core_lookup(record_path||'/'||r.uid))),'[]') into rows from stewardie_core.join_requests r where r.space_id=sid;
    else
      if parts[1]='accounts' and parts[3]='activity' then perform stewardie_core.deliver_events(); end if;
      select coalesce(jsonb_agg(jsonb_build_object('id',split_part(d.path,'/',array_length(parts,1)+1),'data',public.stewardie_core_lookup(d.path)) order by d.updated_at desc),'[]') into rows from
        (select * from stewardie_core.documents where starts_with(documents.path,record_path||'/') and array_length(string_to_array(documents.path,'/'),1)=array_length(parts,1)+1 order by updated_at desc limit 500) d
      where public.stewardie_core_lookup(d.path) is not null and (parts[3] is distinct from 'activity' or stewardie_core.notice_visible(p_uid,d.data))
        and (parts[3] is distinct from 'locationSessions' or (d.data->'recipientUids' ? p_uid and exists(select 1 from stewardie_core.members where space_id=sid and uid=d.data->>'uid')));
    end if;
    return jsonb_build_object('rows',rows);
  elsif p_action<>'docWrite' then raise exception 'Unsupported record action' using errcode='22023'; end if;

  v:=coalesce(p_payload->'data','{}'); existing:=public.stewardie_core_lookup(record_path);
  if mode='createIfAbsent' then
    if parts[1]<>'accounts' or parts[3] is distinct from 'notificationPrefs' or array_length(parts,1)<>4 then raise exception 'Unsupported conditional creation' using errcode='22023'; end if;
    if existing is not null then return jsonb_build_object('ok',true); end if;
  end if;
  if jsonb_typeof(v)<>'object' then raise exception 'Invalid record' using errcode='22023'; end if;
  if parts[1]='accounts' then
    if array_length(parts,1)=2 then
      if mode='delete' or exists(select 1 from jsonb_object_keys(v) k where k not in ('name','email','photoUrl','onboarding','onboardingComplete','onboardingCompleted','onboardingCompletedAt','onboardingVersion','tourComplete','tourCompleted','tourCompletedAt','tourVersion','updatedAt')) then raise exception 'Protected account field' using errcode='42501'; end if;
    elsif parts[3]='activity' then
      if existing is null or exists(select 1 from jsonb_object_keys(v) k where k not in ('readAt')) or mode='delete' then raise exception 'Inbox items are server generated' using errcode='42501'; end if;
      v:=jsonb_build_object('readAt',now());
    elsif parts[3] not in ('notificationPrefs','pushDevices','hidden','blocks','tutorial') then raise exception 'Unsupported account record' using errcode='42501'; end if;
  elsif parts[1]='profiles' then
    if exists(select 1 from jsonb_object_keys(v) k where k not in ('imageBase64','photoUrl','updatedAt')) or length(coalesce(v->>'imageBase64',''))>160000 then raise exception 'Invalid profile image' using errcode='22023'; end if;
  elsif parts[1]='spaces' then
    if parts[3]='checkIns' and parts[4]=p_uid then
      v:=v || jsonb_build_object('uid',p_uid,'updatedAt',now(),'localDate',(now() at time zone (select time_zone from stewardie_core.spaces where id=sid))::date,
        'expiresAt',((now() at time zone (select time_zone from stewardie_core.spaces where id=sid))::date+1)::timestamp at time zone (select time_zone from stewardie_core.spaces where id=sid));
      if mode<>'delete' and (v->>'mood' is null or length(coalesce(v->>'note',''))>500) then raise exception 'Invalid mood' using errcode='22023'; end if;
    elsif parts[3]='plans' and array_length(parts,1)=4 then
      if existing is not null and existing->>'ownerUid'<>p_uid then raise exception 'Only the plan creator can edit' using errcode='42501'; end if;
      if mode<>'delete' then
        if length(btrim(v->>'title')) not between 1 and 100 or v->>'title' is null or jsonb_typeof(v->'startMillis') is distinct from 'number' or jsonb_typeof(v->'endMillis') is distinct from 'number' or (v->>'endMillis')::bigint<(v->>'startMillis')::bigint then raise exception 'Invalid calendar plan' using errcode='22023'; end if;
        v:=v||jsonb_build_object('ownerUid',p_uid,'updatedAt',now(),'revision',coalesce((existing->>'revision')::int,0)+1);
      end if;
    elsif parts[3]='routines' and array_length(parts,1)=4 then
      if not exists(select 1 from stewardie_core.members where space_id=sid and uid=p_uid and role in ('owner','admin')) then raise exception 'Manager access required' using errcode='42501'; end if;
      if mode<>'delete' and (v->>'cadence' not in ('daily','weekdays','weekly') or length(btrim(v->>'title')) not between 1 and 100 or v->>'title' is null) then raise exception 'Invalid routine' using errcode='22023'; end if;
      if mode<>'delete' and existing is null and (select count(*) from stewardie_core.documents where starts_with(documents.path,'spaces/'||sid||'/routines/'))>=5 then raise exception 'This space has five routines already'; end if;
      v:=v||jsonb_build_object('creatorUid',p_uid,'updatedAt',now());
    elsif parts[3] in ('plans','tasks') and parts[5]='arrivals' and parts[6]=p_uid then
      if parts[3]='tasks' then perform public.stewardie_core_action(p_uid,'getTask',jsonb_build_object('spaceId',sid,'taskId',parts[4])); end if;
      if public.stewardie_core_lookup('spaces/'||sid||'/'||parts[3]||'/'||parts[4]) is null then raise exception 'Activity unavailable' using errcode='22023'; end if;
      v:=jsonb_build_object('uid',p_uid,'checkedInAt',now());
    else raise exception 'Use the protected workflow for this record' using errcode='42501'; end if;
  elsif parts[1]='safetyReports' then v:=v||jsonb_build_object('reporterUid',p_uid,'createdAt',now());
  elsif parts[1]='deletionRequests' then v:=jsonb_build_object('uid',p_uid,'createdAt',now(),'status','pending'); end if;
  if mode='delete' then delete from stewardie_core.documents where documents.path=record_path;
  else
    if mode='update' and existing is null then raise exception 'Record unavailable' using errcode='22023'; end if;
    if mode in ('merge','update') then v:=coalesce((select data from stewardie_core.documents where documents.path=record_path),'{}')||v; end if;
    v:=v||jsonb_build_object('updatedAt',now());
    for field_name in select key from jsonb_each(v) where value='{"_serverTime":true}'::jsonb loop v:=jsonb_set(v,array[field_name],to_jsonb(now())); end loop;
    insert into stewardie_core.documents(path,data) values(record_path,v) on conflict on constraint documents_pkey do update set data=excluded.data,updated_at=now();
    if parts[1]='spaces' and parts[3]='checkIns' and existing->>'localDate' is distinct from v->>'localDate' then
      insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids)
        select sid,p_uid,p_uid,'mood',coalesce(array_agg(uid),'{}') from stewardie_core.members where space_id=sid and uid<>p_uid;
    end if;
  end if;
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.stewardie_core_documents(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.stewardie_core_documents(text,text,jsonb) to service_role;
