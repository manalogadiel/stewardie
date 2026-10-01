create function stewardie_core.validate_task_content(v jsonb) returns void
language plpgsql set search_path='' as $$
declare pin jsonb:=v->'pin'; item jsonb;
begin
  if v ? 'title' and (jsonb_typeof(v->'title') is distinct from 'string' or length(btrim(v->>'title')) not between 1 and 100 or v->>'title' ~* '(.)\1{5,}') then
    raise exception 'Use a clear task name without repeated keys' using errcode='22023';
  end if;
  if (v ? 'notes' and (jsonb_typeof(v->'notes') is distinct from 'string' or length(v->>'notes')>2000))
    or (v ? 'note' and (jsonb_typeof(v->'note') is distinct from 'string' or length(v->>'note')>2000))
    or (v ? 'destination' and (jsonb_typeof(v->'destination') is distinct from 'string' or length(v->>'destination')>300)) then
    raise exception 'Task text is too long or invalid' using errcode='22023';
  end if;
  if pin is not null and pin<>'null'::jsonb then
    if jsonb_typeof(pin)<>'object' or jsonb_typeof(pin->'lat') is distinct from 'number' or jsonb_typeof(pin->'lng') is distinct from 'number'
      or jsonb_typeof(pin->'label') is distinct from 'string' then raise exception 'Invalid place pin' using errcode='22023'; end if;
    if (pin->>'lat')::numeric not between -90 and 90 or (pin->>'lng')::numeric not between -180 and 180
      or length(pin->>'label')>200 or length(coalesce(pin->>'note',''))>500
      or coalesce(pin->>'source','manual') not in ('manual','capture') then raise exception 'Invalid place pin' using errcode='22023'; end if;
    if pin ? 'accuracy' and pin->'accuracy'<>'null'::jsonb then
      if jsonb_typeof(pin->'accuracy')<>'number' then raise exception 'Invalid pin accuracy' using errcode='22023'; end if;
      if (pin->>'accuracy')::numeric<0 then raise exception 'Invalid pin accuracy' using errcode='22023'; end if;
    end if;
    if pin ? 'locatedAt' and pin->'locatedAt'<>'null'::jsonb then perform (pin->>'locatedAt')::timestamptz; end if;
  end if;
  if v ? 'subtasks' then
    if jsonb_typeof(v->'subtasks')<>'array' then raise exception 'Invalid subtasks' using errcode='22023'; end if;
    if jsonb_array_length(v->'subtasks')>30 then raise exception 'Use at most 30 subtasks' using errcode='22023'; end if;
    for item in select value from jsonb_array_elements(v->'subtasks') loop
      if jsonb_typeof(item)<>'object' or jsonb_typeof(item->'title') is distinct from 'string'
        or length(btrim(item->>'title')) not between 1 and 100 or jsonb_typeof(item->'done') is distinct from 'boolean' then
        raise exception 'Invalid subtask title or completion' using errcode='22023';
      end if;
    end loop;
  end if;
end;
$$;
revoke all on function stewardie_core.validate_task_content(jsonb) from public,anon,authenticated,service_role;

alter function public.stewardie_core_action(text,text,jsonb) rename to stewardie_core_space_action;
create function public.stewardie_core_action(p_uid text,p_action text,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  sid text:=p_payload->>'spaceId';
  op text:=p_payload->>'operationId';
  patch jsonb:=p_payload->'patch';
  s stewardie_core.spaces%rowtype;
  t stewardie_core.tasks%rowtype;
  receipt stewardie_core.operations%rowtype;
  plus boolean;
  target text;
  result jsonb;
  audience text[];
  event_type text;
begin
  if p_uid is null or length(p_uid) not between 1 and 128 or jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Invalid request' using errcode='22023'; end if;
  if p_action='createTask' then perform stewardie_core.validate_task_content(p_payload); end if;
  if p_action not in ('getTask','updateTask','deleteTask','setSubtasks') then return public.stewardie_core_space_action(p_uid,p_action,p_payload); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_uid,0));
  select * into s from stewardie_core.spaces where id=sid and deleted_at is null for update;
  if not found or not exists(select 1 from stewardie_core.members where space_id=sid and uid=p_uid) then raise exception 'Space access ended' using errcode='42501'; end if;
  if p_action<>'getTask' then
    if op is null or op !~ '^[A-Za-z0-9_-]{1,150}$' then raise exception 'A stable operation ID is required' using errcode='22023'; end if;
    select * into receipt from stewardie_core.operations where uid=p_uid and operation_id=op;
    if found then
      if receipt.action<>p_action or receipt.payload<>p_payload then raise exception 'Operation ID already used for another request' using errcode='22023'; end if;
      return receipt.result;
    end if;
  end if;
  select * into t from stewardie_core.tasks where space_id=sid and id=p_payload->>'taskId' for update;
  if not found then raise exception 'Task unavailable' using errcode='22023'; end if;
  if p_action='getTask' then
    select founder_grant or coalesce(subscription_expires_at>now(),false) into plus from stewardie_core.accounts where uid=p_uid;
    if t.status='completed' and not plus and t.completed_at < ((now() at time zone s.time_zone)::date-3)::timestamp at time zone s.time_zone then
      raise exception 'Task history unavailable' using errcode='42501';
    end if;
    return jsonb_build_object('task',jsonb_build_object('id',t.id,'spaceId',sid,'title',t.title,'creatorUid',t.creator_uid,
      'ownerUid',t.owner_uid,'requestedUid',t.requested_uid,'offeredUid',t.offered_uid,'status',t.status,
      'scheduledLocalDate',t.scheduled_local_date,'completedAt',t.completed_at,'completedLocalDate',t.completed_local_date,
      'version',t.version,'createdAt',t.created_at,'updatedAt',t.updated_at,'details',t.details));
  end if;
  if p_payload->>'expectedVersion' is null or (p_payload->>'expectedVersion')::integer<>t.version then raise exception 'This task changed. Refresh before retrying'; end if;
  select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid
    and uid=any(array[t.creator_uid,t.owner_uid,t.requested_uid,t.offered_uid]);
  if p_action='deleteTask' then
    -- Preserve current shared deletion behavior; membership is mandatory,
    -- history entitlement is not. Media cleanup is a separate cutover gate.
    delete from stewardie_core.tasks where space_id=sid and id=t.id;
    event_type:='taskCancelled'; result:=jsonb_build_object('removed',true);
  else
    if t.status='completed' then raise exception 'Completed tasks cannot be edited' using errcode='42501'; end if;
    if p_action='setSubtasks' then
      if not p_payload ? 'subtasks' then raise exception 'Subtasks required' using errcode='22023'; end if;
      patch:=jsonb_build_object('subtasks',p_payload->'subtasks');
    end if;
    if jsonb_typeof(patch) is distinct from 'object' or patch='{}'::jsonb then raise exception 'Task changes required' using errcode='22023'; end if;
    if exists(select 1 from jsonb_object_keys(patch) k where k not in ('title','notes','note','destination','pin','subtasks','scheduledLocalDate','requestedUid')) then raise exception 'Unsupported task field' using errcode='22023'; end if;
    perform stewardie_core.validate_task_content(patch);
    if patch ? 'notes' and patch ? 'note' and patch->'notes'<>patch->'note' then raise exception 'Conflicting task notes' using errcode='22023'; end if;
    if patch ? 'notes' then patch:=patch || jsonb_build_object('note',patch->'notes');
    elsif patch ? 'note' then patch:=patch || jsonb_build_object('notes',patch->'note'); end if;
    if patch ? 'requestedUid' then
      target:=nullif(patch->>'requestedUid','');
      if jsonb_typeof(patch->'requestedUid') not in ('string','null') then raise exception 'Invalid recipient' using errcode='22023'; end if;
      if target is distinct from t.requested_uid then
        if t.creator_uid<>p_uid or t.status not in ('requested','unclaimed') then raise exception 'Use a handoff to change who covers this task' using errcode='42501'; end if;
        if target is not null and not exists(select 1 from stewardie_core.members where space_id=sid and uid=target) then raise exception 'Choose a current member' using errcode='42501'; end if;
        t.requested_uid:=target; t.status:=case when target is null then 'unclaimed' else 'requested' end;
        if target is not null then event_type:='taskAssigned'; audience:=array[target]; end if;
      end if;
    end if;
    if patch ? 'title' then t.title:=btrim(patch->>'title'); end if;
    if patch ? 'scheduledLocalDate' then
      if jsonb_typeof(patch->'scheduledLocalDate') is distinct from 'string' or patch->>'scheduledLocalDate' !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Invalid task date' using errcode='22023'; end if;
      t.scheduled_local_date:=(patch->>'scheduledLocalDate')::date;
    end if;
    t.details:=t.details || (patch-'title'-'scheduledLocalDate'-'requestedUid');
    update stewardie_core.tasks set title=t.title,status=t.status,requested_uid=t.requested_uid,
      scheduled_local_date=t.scheduled_local_date,details=t.details,version=version+1,updated_at=now()
      where space_id=sid and id=t.id returning * into t;
    event_type:=coalesce(event_type,'taskEdited');
    result:=jsonb_build_object('ok',true,'version',t.version);
  end if;
  select coalesce(array_agg(uid),'{}') into audience from stewardie_core.members where space_id=sid and uid<>p_uid and uid=any(audience);
  insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids,task_version) values(sid,p_uid,t.id,event_type,audience,t.version);
  insert into stewardie_core.operations(uid,operation_id,action,payload,result) values(p_uid,op,p_action,p_payload,result);
  return result;
end;
$$;
revoke all on function public.stewardie_core_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.stewardie_core_action(text,text,jsonb) to service_role;
revoke all on function public.stewardie_core_space_action(text,text,jsonb) from service_role;
