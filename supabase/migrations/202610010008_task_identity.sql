-- Keep durable client task IDs identical to server IDs across retries.
create or replace function public.stewardie_core_base_action(p_uid text, p_action text, p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s stewardie_core.spaces%rowtype;
  t stewardie_core.tasks%rowtype;
  a stewardie_core.accounts%rowtype;
  inv stewardie_core.invites%rowtype;
  receipt stewardie_core.operations%rowtype;
  sid text := p_payload->>'spaceId';
  op text := p_payload->>'operationId';
  target text := nullif(p_payload->>'requestedUid','');
  task_id text;
  result jsonb;
  plus boolean;
  total integer;
  act text;
  audience text[];
  event_type text;
  affected text[];
  zone text;
  task_title text;
  feed_limit integer;
  invite_attempt integer := 0;
begin
  if p_uid is null or length(p_uid) not between 1 and 128 or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Invalid request' using errcode = '22023';
  end if;
  if p_action not in ('listSpaces','listTasks','createSpace','createInvite','joinSpace','createTask','actOnTask') then
    raise exception 'Unsupported core action' using errcode = '22023';
  end if;
  -- Serialize account quota changes, then space changes. A duplicate request
  -- waits for the first commit and receives the same receipt, never a second write.
  perform pg_advisory_xact_lock(hashtextextended(p_uid,0));
  insert into stewardie_core.accounts(uid) values(p_uid) on conflict do nothing;
  select * into a from stewardie_core.accounts where uid = p_uid;
  plus := a.founder_grant or coalesce(a.subscription_expires_at > now(),false);

  if sid is not null then
    select * into s from stewardie_core.spaces where id = sid and deleted_at is null for update;
    if not found or not exists(select 1 from stewardie_core.members where space_id = sid and uid = p_uid) then
      raise exception 'Space access ended' using errcode = '42501';
    end if;
  end if;
  if p_action = 'listSpaces' then
    select coalesce(jsonb_agg(jsonb_build_object('spaceId',x.id,'name',x.name,
      'kind',x.kind,'timeZone',x.time_zone,'ownerUid',x.owner_uid,'role',x.role) order by x.created_at,x.id),'[]') into result
    from (select sp.*,m.role from stewardie_core.spaces sp join stewardie_core.members m on m.space_id = sp.id
      where m.uid = p_uid and sp.deleted_at is null) x;
    return jsonb_build_object('spaces',result,'isPlus',plus);
  elsif p_action = 'listTasks' then
    if sid is null then raise exception 'Space required' using errcode = '22023'; end if;
    if (p_payload->>'beforeTime' is null) <> (p_payload->>'beforeId' is null) then
      raise exception 'A complete pagination cursor is required' using errcode='22023';
    end if;
    feed_limit := least(greatest(coalesce((p_payload->>'limit')::integer,50),1),100);
    select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'spaceId',x.space_id,'title',x.title,
      'creatorUid',x.creator_uid,'ownerUid',x.owner_uid,'requestedUid',x.requested_uid,
      'offeredUid',x.offered_uid,'status',x.status,'scheduledLocalDate',x.scheduled_local_date,
      'completedAt',x.completed_at,'completedLocalDate',x.completed_local_date,
      'version',x.version,'createdAt',x.created_at,'updatedAt',x.updated_at,'details',x.details)
      order by x.updated_at desc,x.id desc),'[]') into result
    from (select feed.* from stewardie_core.tasks feed where space_id = sid
      and (status <> 'completed' or plus or completed_at >= ((now() at time zone s.time_zone)::date - 3)::timestamp at time zone s.time_zone)
      and (p_payload->>'beforeTime' is null or (updated_at,id) < ((p_payload->>'beforeTime')::timestamptz,p_payload->>'beforeId'))
      order by updated_at desc,id desc limit feed_limit) x;
    return jsonb_build_object('tasks',result);
  end if;
  if op is null or op !~ '^[A-Za-z0-9_-]{1,150}$' then
    raise exception 'A stable operation ID is required' using errcode = '22023';
  end if;
  select * into receipt from stewardie_core.operations where uid = p_uid and operation_id = op;
  if found then
    if receipt.action <> p_action or receipt.payload <> p_payload then
      raise exception 'Operation ID already used for another request' using errcode = '22023';
    end if;
    return receipt.result;
  end if;

  if p_action = 'createSpace' then
    select count(*) into total from stewardie_core.members m join stewardie_core.spaces x on x.id=m.space_id where uid=p_uid and x.deleted_at is null;
    if total >= (case when plus then 50 else 3 end) then raise exception 'Your account has reached its space limit'; end if;
    select count(*) into total from stewardie_core.spaces where owner_uid=p_uid and deleted_at is null;
    if total >= (case when plus then 20 else 3 end) then raise exception 'Your account has reached its owned-space limit'; end if;
    zone := coalesce(p_payload->>'timeZone','Asia/Manila');
    if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid time zone' using errcode='22023'; end if;
    insert into stewardie_core.spaces(name,kind,time_zone,owner_uid)
      values(btrim(p_payload->>'name'),coalesce(p_payload->>'kind','other'),zone,p_uid) returning * into s;
    sid := s.id;
    insert into stewardie_core.members(space_id,uid,name,role) values(sid,p_uid,left(coalesce(nullif(btrim(p_payload->>'displayName'),''),'Member'),60),'owner');
    result := jsonb_build_object('spaceId',sid);
  elsif p_action = 'joinSpace' then
    select * into inv from stewardie_core.invites where code = btrim(p_payload->>'code') or code = upper(btrim(p_payload->>'code'))
      order by (code = btrim(p_payload->>'code')) desc limit 1;
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    sid := inv.space_id;
    select * into s from stewardie_core.spaces where id=sid and deleted_at is null for update;
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    -- All invite mutations lock the space before the invite, including revoke.
    select * into inv from stewardie_core.invites where code=inv.code for update;
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    if exists(select 1 from stewardie_core.members where space_id=sid and uid=p_uid) then
      result := jsonb_build_object('spaceId',sid,'alreadyJoined',true);
    else
      if inv.revoked or inv.redeemed_uid is not null or inv.expires_at <= now() then raise exception 'Invitation expired or already used'; end if;
      if inv.require_approval or s.require_approval then raise exception 'Owner approval is required'; end if;
      select count(*) into total from stewardie_core.members where space_id=sid;
      if total >= 20 then raise exception 'This space has reached its member limit'; end if;
      select count(*) into total from stewardie_core.members m join stewardie_core.spaces x on x.id=m.space_id where uid=p_uid and x.deleted_at is null;
      if total >= (case when plus then 50 else 3 end) then raise exception 'Your account has reached its space limit'; end if;
      insert into stewardie_core.members(space_id,uid,name,role) values(sid,p_uid,left(coalesce(nullif(btrim(p_payload->>'displayName'),''),'Member'),60),'member');
      update stewardie_core.invites set redeemed_uid=p_uid where code=inv.code;
      select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
      insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids) values(sid,p_uid,p_uid,'joined',coalesce(audience,'{}'));
      result := jsonb_build_object('spaceId',sid,'alreadyJoined',false);
    end if;
  elsif p_action = 'createInvite' then
    if sid is null or not exists(select 1 from stewardie_core.members where space_id=sid and uid=p_uid and role in ('owner','admin')) then raise exception 'Only space managers can invite' using errcode='42501'; end if;
    -- Match the existing 10-letter QR/code UI, using cryptographically random
    -- UUID bits and retrying the extremely unlikely unique-code collision.
    loop
      invite_attempt := invite_attempt+1;
      begin
        insert into stewardie_core.invites(code,space_id,created_by,expires_at,require_approval)
          values(translate(upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
            '0123456789ABCDEF','ABCDEFGHJKLMNPQR'),sid,p_uid,now()+interval '7 days',s.require_approval) returning * into inv;
        exit;
      exception when unique_violation then
        if invite_attempt>=5 then raise exception 'Invitation unavailable. Please retry'; end if;
      end;
    end loop;
    result := jsonb_build_object('code',inv.code,'spaceId',sid,'expiresAt',inv.expires_at);
  elsif p_action = 'createTask' then
    if sid is null then raise exception 'Space required' using errcode='22023'; end if;
    task_title := btrim(p_payload->>'title');
    if task_title is null or length(task_title) not between 1 and 100 or task_title ~* '(.)\1{5,}' then raise exception 'Use a clear task name without repeated keys' using errcode='22023'; end if;
    if target is not null and not exists(select 1 from stewardie_core.members where space_id=sid and uid=target) then raise exception 'Choose a current space member' using errcode='42501'; end if;
    select count(*) into total from stewardie_core.tasks where space_id=sid and status<>'completed';
    if total >= 300 then raise exception 'This space has reached its active task limit'; end if;
    insert into stewardie_core.tasks(id,space_id,title,creator_uid,requested_uid,status,scheduled_local_date,details)
      values(op,sid,task_title,p_uid,target,case when target is null then 'unclaimed' else 'requested' end,
        coalesce((p_payload->>'scheduledLocalDate')::date,(now() at time zone s.time_zone)::date),
        jsonb_build_object('notes',coalesce(p_payload->>'notes',''),'pin',p_payload->'pin')) returning * into t;
    if target is not null and target<>p_uid then
      insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids,task_version)
        values(sid,p_uid,t.id,'taskAssigned',array[target],t.version);
    end if;
    result := jsonb_build_object('taskId',t.id,'version',t.version);
  elsif p_action = 'actOnTask' then
    if sid is null then raise exception 'Space required' using errcode='22023'; end if;
    select * into t from stewardie_core.tasks where space_id=sid and id=p_payload->>'taskId' for update;
    if not found then raise exception 'Task unavailable' using errcode='22023'; end if;
    affected := array[t.creator_uid,t.owner_uid,t.requested_uid,t.offered_uid];
    if p_payload->>'expectedVersion' is null or (p_payload->>'expectedVersion')::integer<>t.version then raise exception 'This task changed. Refresh before retrying'; end if;
    act := p_payload->>'action';
    if act='accept' and (t.status='unclaimed' or (t.status='requested' and t.requested_uid=p_uid)) then
      t.status:='accepted'; t.owner_uid:=p_uid; t.requested_uid:=null; t.offered_uid:=null; event_type:='covered';
    elsif act='decline' and t.status='requested' and t.requested_uid=p_uid then
      t.status:='unclaimed'; t.requested_uid:=null; event_type:='taskDeclined';
    elsif act='needHelp' and t.status='accepted' and t.owner_uid=p_uid then
      t.status:='needsHelp'; event_type:='helpRequested';
    elsif act='offerHelp' and t.status='needsHelp' and t.owner_uid<>p_uid and t.offered_uid is null then
      t.offered_uid:=p_uid; event_type:='helpOffered';
    elsif act='confirmHandoff' and t.status='needsHelp' and t.owner_uid=p_uid and t.offered_uid is not null
      and exists(select 1 from stewardie_core.members where space_id=sid and uid=t.offered_uid) then
      t.owner_uid:=t.offered_uid; t.offered_uid:=null; t.status:='accepted'; event_type:='covered';
    elsif act='complete' and t.status in ('accepted','needsHelp') and t.owner_uid=p_uid then
      t.status:='completed'; t.offered_uid:=null; t.completed_at:=now(); t.completed_local_date:=(now() at time zone s.time_zone)::date; event_type:='completed';
    else raise exception 'You cannot perform this task action' using errcode='42501'; end if;
    update stewardie_core.tasks set status=t.status,owner_uid=t.owner_uid,requested_uid=t.requested_uid,
      offered_uid=t.offered_uid,completed_at=t.completed_at,completed_local_date=t.completed_local_date,
      version=version+1,updated_at=now() where space_id=sid and id=t.id returning * into t;
    select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid
      and (event_type='helpRequested' or uid = any(affected || array[t.owner_uid,t.requested_uid,t.offered_uid]));
    insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids,task_version)
      values(sid,p_uid,t.id,event_type,coalesce(audience,'{}'),t.version);
    result := jsonb_build_object('ok',true,'version',t.version);
  end if;
  insert into stewardie_core.operations(uid,operation_id,action,payload,result) values(p_uid,op,p_action,p_payload,result);
  return result;
end;
$$;