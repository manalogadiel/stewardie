create function public.stewardie_core_features(p_uid text,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sid text:=p_payload->>'spaceId'; record_path text; v jsonb; previous jsonb; result jsonb; op text:=p_payload->>'operationId'; receipt stewardie_core.operations%rowtype; minutes int; audience text[]; event_type text; entity text; t stewardie_core.tasks%rowtype;
begin
  if p_uid is null or length(p_uid) not between 1 and 128 or jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Invalid request' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_uid,0));
  insert into stewardie_core.accounts(uid) values(p_uid) on conflict do nothing;
  if p_action='profileName' then
    if p_payload->>'name' is null or length(btrim(p_payload->>'name')) not between 1 and 60 then raise exception 'Invalid name' using errcode='22023'; end if;
    update stewardie_core.members set name=btrim(p_payload->>'name') where uid=p_uid;
    perform public.stewardie_core_documents(p_uid,'docWrite',jsonb_build_object('path','accounts/'||p_uid,'mode','merge','data',jsonb_build_object('name',btrim(p_payload->>'name'))));
    return jsonb_build_object('ok',true);
  end if;
  if p_action='stopLocationSession' then
    delete from stewardie_core.documents where documents.path='spaces/'||sid||'/locationSessions/'||p_uid;
    return jsonb_build_object('ok',true);
  end if;
  if not exists(select 1 from stewardie_core.spaces s join stewardie_core.members m on m.space_id=s.id where s.id=sid and s.deleted_at is null and m.uid=p_uid) then raise exception 'Space access ended' using errcode='42501'; end if;
  perform 1 from stewardie_core.spaces where id=sid for update;
  if p_action='readLocations' then
    select coalesce(jsonb_agg(d.data),'[]') into result from stewardie_core.documents d
      where starts_with(d.path,'spaces/'||sid||'/locationSessions/') and (d.data->>'expiresAt')::timestamptz>now()
      and d.data->'recipientUids' ? p_uid and exists(select 1 from stewardie_core.members where space_id=sid and uid=d.data->>'uid');
    return jsonb_build_object('sessions',result);
  end if;
  if op is null or op !~ '^[A-Za-z0-9_-]{1,150}$' then raise exception 'A stable operation ID is required' using errcode='22023'; end if;
  select * into receipt from stewardie_core.operations where uid=p_uid and operation_id=op;
  if found then
    if receipt.action<>p_action or receipt.payload<>p_payload then raise exception 'Operation ID already used for another request' using errcode='22023'; end if;
    return receipt.result;
  end if;
  if p_action in ('startLocationSession','updateLocation') then
    if jsonb_typeof(p_payload->'lat') is distinct from 'number' or jsonb_typeof(p_payload->'lng') is distinct from 'number' or jsonb_typeof(p_payload->'accuracy') is distinct from 'number' then raise exception 'Invalid location fix' using errcode='22023'; end if;
    if (p_payload->>'lat')::numeric not between -90 and 90 or (p_payload->>'lng')::numeric not between -180 and 180 or (p_payload->>'accuracy')::numeric not between 0 and 10000 then raise exception 'Invalid location fix' using errcode='22023'; end if;
    record_path:='spaces/'||sid||'/locationSessions/'||p_uid;
    if p_action='startLocationSession' then
      minutes:=(p_payload->>'durationMinutes')::int;
      if minutes is null or minutes not in (15,30,60) then raise exception 'Choose 15, 30, or 60 minutes' using errcode='22023'; end if;
      select array_agg(uid) into audience from stewardie_core.members where space_id=sid;
      v:=jsonb_build_object('uid',p_uid,'name',coalesce(p_payload->>'displayName','Member'),'lat',p_payload->'lat','lng',p_payload->'lng','accuracy',p_payload->'accuracy',
        'recipientUids',audience,'durationMinutes',minutes,'startedAt',now(),'updatedAt',now(),'expiresAt',now()+make_interval(mins=>minutes));
    else
      select data into v from stewardie_core.documents where documents.path=record_path;
      if v is null or (v->>'expiresAt')::timestamptz<=now() then raise exception 'Sharing session ended'; end if;
      v:=v||jsonb_build_object('lat',p_payload->'lat','lng',p_payload->'lng','accuracy',p_payload->'accuracy','updatedAt',now());
    end if;
    insert into stewardie_core.documents(path,data) values(record_path,v) on conflict on constraint documents_pkey do update set data=excluded.data,updated_at=now();
    result:=jsonb_build_object('ok',true,'expiresAt',v->'expiresAt');
    if p_action='startLocationSession' then entity:=p_uid;event_type:='locationStarted'; end if;
  elsif p_action in ('savePlan','removePlan','createRoutine','deleteRoutine','checkInPlanArrival','checkInArrival') then
    entity:=coalesce(p_payload->>'planId',p_payload->>'routineId',p_payload->>'taskId',op);
    if entity !~ '^[A-Za-z0-9_-]{1,150}$' then raise exception 'Invalid record ID' using errcode='22023'; end if;
    record_path:='spaces/'||sid||'/'||case when p_action in ('createRoutine','deleteRoutine') then 'routines' when p_action='checkInArrival' then 'tasks' else 'plans' end||'/'||entity;
    previous:=public.stewardie_core_lookup(record_path);
    if p_action in ('savePlan','removePlan') and p_payload ? 'expectedRevision' and coalesce((previous->>'revision')::int,0)<>(p_payload->>'expectedRevision')::int then raise exception 'This plan changed. Refresh before retrying'; end if;
    if p_action in ('checkInPlanArrival','checkInArrival') then
      record_path:=record_path||'/arrivals/'||p_uid;
      perform public.stewardie_core_documents(p_uid,'docWrite',jsonb_build_object('path',record_path,'data','{}'::jsonb));
      event_type:=case when p_action='checkInArrival' then 'taskArrival' else 'planArrival' end;
    elsif p_action in ('removePlan','deleteRoutine') then
      perform public.stewardie_core_documents(p_uid,'docWrite',jsonb_build_object('path',record_path,'mode','delete'));
      event_type:=case when p_action='removePlan' then 'planCancelled' else null end;
    else
      v:=p_payload-'spaceId'-'operationId'-'planId'-'routineId'-'expectedRevision';
      perform public.stewardie_core_documents(p_uid,'docWrite',jsonb_build_object('path',record_path,'data',v));
      event_type:=case when p_action='savePlan' then case when previous is null then 'planAdded' else 'planChanged' end else null end;
    end if;
    select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
    result:=jsonb_build_object('ok',true,'removed',p_action in ('removePlan','deleteRoutine'),'planId',entity,'routineId',entity);
  elsif p_action in ('requestHelp','takeOverTask') then
    select * into t from stewardie_core.tasks where space_id=sid and id=p_payload->>'taskId' for update;
    if not found or t.status not in ('accepted','needsHelp') then raise exception 'Task unavailable' using errcode='22023'; end if;
    if p_payload ? 'expectedVersion' and (p_payload->>'expectedVersion')::int<>t.version then raise exception 'This task changed. Refresh before retrying'; end if;
    entity:=t.id;
    if p_action='requestHelp' then
      if t.owner_uid<>p_uid then raise exception 'Only the responsible member can request help' using errcode='42501'; end if;
      update stewardie_core.tasks set status='needsHelp',details=details||'{"helpNeeded":true}',version=version+1,updated_at=now() where space_id=sid and id=t.id;
      event_type:='helpRequested';
    else
      if t.status<>'needsHelp' or coalesce((t.details->>'helpNeeded')::boolean,false)=false then raise exception 'This task is not open for takeover' using errcode='42501'; end if;
      update stewardie_core.tasks set status='accepted',owner_uid=p_uid,requested_uid=null,offered_uid=null,details=details||'{"helpNeeded":false}',version=version+1,updated_at=now() where space_id=sid and id=t.id;
      event_type:='covered';
    end if;
    select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
    result:=jsonb_build_object('ok',true,'version',t.version+1);
  else raise exception 'Unsupported feature action' using errcode='22023'; end if;
  if event_type is not null then insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids,task_version) values(sid,p_uid,entity,event_type,coalesce(audience,'{}'),case when p_action in ('requestHelp','takeOverTask') then t.version+1 else null end); end if;
  insert into stewardie_core.operations(uid,operation_id,action,payload,result) values(p_uid,op,p_action,p_payload,result);
  return result;
end;
$$;
revoke all on function public.stewardie_core_features(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.stewardie_core_features(text,text,jsonb) to service_role;
