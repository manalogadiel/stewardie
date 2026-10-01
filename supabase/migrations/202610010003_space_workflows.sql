-- Additive workflow layer. Deployment remains gated with the core endpoint.
alter table stewardie_core.spaces add column pending_owner_uid text;
create table stewardie_core.join_requests (
  space_id text not null references stewardie_core.spaces(id),
  uid text not null references stewardie_core.accounts(uid),
  code text not null references stewardie_core.invites(code),
  name text not null check(length(name) between 1 and 60),
  status text not null check(status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  primary key(space_id,uid)
);
alter table stewardie_core.join_requests enable row level security;
revoke all on stewardie_core.join_requests from public, anon, authenticated;

alter function public.stewardie_core_action(text,text,jsonb) rename to stewardie_core_base_action;
create function public.stewardie_core_action(p_uid text,p_action text,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  sid text := p_payload->>'spaceId';
  target text := p_payload->>'memberUid';
  op text := p_payload->>'operationId';
  s stewardie_core.spaces%rowtype;
  inv stewardie_core.invites%rowtype;
  req stewardie_core.join_requests%rowtype;
  receipt stewardie_core.operations%rowtype;
  result jsonb;
  audience text[];
  role_name text;
  plus boolean;
  total integer;
  event_type text;
begin
  if p_uid is null or length(p_uid) not between 1 and 128 or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Invalid request' using errcode='22023';
  end if;
  if p_action not in ('getSpace','previewInvite','setJoinApprovalPolicy','renameSpace','revokeInvite','requestJoin','resolveJoin',
    'leaveSpace','removeMember','offerOwnership','cancelOwnership','acceptOwnership','deleteSpace') then
    return public.stewardie_core_base_action(p_uid,p_action,p_payload);
  end if;
  -- Acquire account locks before the space lock; approval affects both accounts.
  if p_action='resolveJoin' and target is not null and target<>p_uid then
    perform pg_advisory_xact_lock(hashtextextended(least(p_uid,target),0));
    perform pg_advisory_xact_lock(hashtextextended(greatest(p_uid,target),0));
  else
    perform pg_advisory_xact_lock(hashtextextended(p_uid,0));
  end if;
  insert into stewardie_core.accounts(uid) values(p_uid) on conflict do nothing;
  if p_action in ('requestJoin','previewInvite') then
    select * into inv from stewardie_core.invites where code=btrim(p_payload->>'code') or code=upper(btrim(p_payload->>'code'))
      order by (code=btrim(p_payload->>'code')) desc limit 1;
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    sid:=inv.space_id;
  end if;
  if sid is null then raise exception 'Space required' using errcode='22023'; end if;
  select * into s from stewardie_core.spaces where id=sid and deleted_at is null for update;
  if not found then
    -- A deleted space exposes only its actor's exact successful deletion receipt.
    if p_action='deleteSpace' then
      select * into receipt from stewardie_core.operations where uid=p_uid and operation_id=op and action=p_action and payload=p_payload;
      if found then return receipt.result; end if;
    end if;
    raise exception 'Space access ended' using errcode='42501';
  end if;
  if p_action='previewInvite' then
    if inv.revoked or inv.expires_at<=now() or (inv.redeemed_uid is not null and inv.redeemed_uid<>p_uid) then raise exception 'Invitation expired or already used'; end if;
    return jsonb_build_object('spaceId',sid,'name',s.name,'kind',s.kind,'requireApproval',s.require_approval or inv.require_approval);
  end if;
  select role into role_name from stewardie_core.members where space_id=sid and uid=p_uid;
  if role_name is null and p_action not in ('requestJoin','leaveSpace') then
    raise exception 'Space access ended' using errcode='42501';
  end if;
  if p_action='getSpace' then
    select jsonb_build_object('spaceId',s.id,'name',s.name,'kind',s.kind,'timeZone',s.time_zone,
      'ownerUid',s.owner_uid,'pendingOwnerUid',s.pending_owner_uid,'requireApproval',s.require_approval,
      'members',coalesce((select jsonb_agg(jsonb_build_object('uid',m.uid,'name',m.name,'role',m.role) order by m.joined_at,m.uid)
        from stewardie_core.members m where m.space_id=sid),'[]'),
      'pendingJoins',case when role_name in ('owner','admin') then coalesce((select jsonb_agg(jsonb_build_object('uid',r.uid,'name',r.name,'createdAt',r.created_at))
        from stewardie_core.join_requests r where r.space_id=sid and status='pending'),'[]') else '[]'::jsonb end) into result;
    return result;
  end if;
  if op is null or op !~ '^[A-Za-z0-9_-]{1,150}$' then raise exception 'A stable operation ID is required' using errcode='22023'; end if;
  select * into receipt from stewardie_core.operations where uid=p_uid and operation_id=op;
  if found then
    if receipt.action<>p_action or receipt.payload<>p_payload then raise exception 'Operation ID already used for another request' using errcode='22023'; end if;
    return receipt.result;
  end if;
  if role_name is null and p_action='leaveSpace' then raise exception 'Space access ended' using errcode='42501'; end if;
  if p_action in ('renameSpace','revokeInvite','resolveJoin','removeMember') and role_name not in ('owner','admin') then
    raise exception 'Only space managers can perform this action' using errcode='42501';
  end if;
  if p_action in ('offerOwnership','cancelOwnership','deleteSpace','setJoinApprovalPolicy') and s.owner_uid<>p_uid then
    raise exception 'Only the owner can perform this action' using errcode='42501';
  end if;

  if p_action='setJoinApprovalPolicy' then
    if jsonb_typeof(p_payload->'requireApproval') is distinct from 'boolean' then raise exception 'Choose an approval policy' using errcode='22023'; end if;
    update stewardie_core.spaces set require_approval=(p_payload->>'requireApproval')::boolean where id=sid;
    update stewardie_core.invites set require_approval=(p_payload->>'requireApproval')::boolean where space_id=sid and not revoked and redeemed_uid is null;
    result:=jsonb_build_object('ok',true);
  elsif p_action='renameSpace' then
    if length(btrim(p_payload->>'name')) not between 1 and 60 or p_payload->>'name' is null then raise exception 'Use a space name of 1 to 60 characters' using errcode='22023'; end if;
    update stewardie_core.spaces set name=btrim(p_payload->>'name') where id=sid;
    result:=jsonb_build_object('spaceId',sid,'name',btrim(p_payload->>'name'));
  elsif p_action='revokeInvite' then
    update stewardie_core.invites set revoked=true where space_id=sid and code=p_payload->>'code';
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    update stewardie_core.join_requests set status='rejected' where space_id=sid and code=p_payload->>'code' and status='pending';
    result:=jsonb_build_object('ok',true);
  elsif p_action='requestJoin' then
    if role_name is not null then return jsonb_build_object('spaceId',sid,'alreadyJoined',true); end if;
    select * into inv from stewardie_core.invites where code=inv.code for update;
    if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
    if inv.revoked or inv.expires_at<=now() or (inv.redeemed_uid is not null and inv.redeemed_uid<>p_uid) then raise exception 'Invitation expired or already used'; end if;
    if not (inv.require_approval or s.require_approval) then raise exception 'This invitation does not require approval' using errcode='22023'; end if;
    select * into req from stewardie_core.join_requests where space_id=sid and uid=p_uid;
    if found and req.status='pending' and req.code=inv.code then
      result:=jsonb_build_object('spaceId',sid,'pending',true);
    else
      if inv.redeemed_uid is not null then raise exception 'Invitation expired or already used'; end if;
      select founder_grant or coalesce(subscription_expires_at>now(),false) into plus from stewardie_core.accounts where uid=p_uid;
      select count(*) into total from stewardie_core.members m join stewardie_core.spaces sp on sp.id=m.space_id where m.uid=p_uid and sp.deleted_at is null;
      if total >= (case when plus then 50 else 3 end) then raise exception 'Your account has reached its space limit'; end if;
      insert into stewardie_core.join_requests(space_id,uid,code,name,status) values(sid,p_uid,inv.code,left(coalesce(nullif(btrim(p_payload->>'displayName'),''),'Member'),60),'pending')
        on conflict(space_id,uid) do update set code=excluded.code,name=excluded.name,status='pending',created_at=now();
      update stewardie_core.invites set redeemed_uid=p_uid where code=inv.code;
      select array_agg(uid) into audience from stewardie_core.members where space_id=sid and role in ('owner','admin') and uid<>p_uid;
      event_type:='joinRequested'; target:=p_uid;
      result:=jsonb_build_object('spaceId',sid,'pending',true);
    end if;
  elsif p_action='resolveJoin' then
    select * into req from stewardie_core.join_requests where space_id=sid and uid=target and status='pending' for update;
    if not found then raise exception 'Join request unavailable' using errcode='22023'; end if;
    select * into inv from stewardie_core.invites where code=req.code for update;
    if p_payload->>'decision'='approve' then
      if inv.revoked or inv.expires_at<=now() or inv.redeemed_uid is distinct from target then raise exception 'Invitation expired or already used'; end if;
      select founder_grant or coalesce(subscription_expires_at>now(),false) into plus from stewardie_core.accounts where uid=target;
      select count(*) into total from stewardie_core.members m join stewardie_core.spaces sp on sp.id=m.space_id where m.uid=target and sp.deleted_at is null;
      if total >= (case when plus then 50 else 3 end) then raise exception 'The account has reached its space limit'; end if;
      select count(*) into total from stewardie_core.members where space_id=sid;
      if total>=20 then raise exception 'This space has reached its member limit'; end if;
      insert into stewardie_core.members(space_id,uid,name,role) values(sid,target,req.name,'member');
      update stewardie_core.join_requests set status='approved' where space_id=sid and uid=target;
      event_type:='joined';
      select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
    elsif p_payload->>'decision'='reject' then
      update stewardie_core.join_requests set status='rejected' where space_id=sid and uid=target;
      update stewardie_core.invites set revoked=true where code=req.code;
    else raise exception 'Choose approve or reject' using errcode='22023'; end if;
    result:=jsonb_build_object('ok',true,'spaceId',sid);
  elsif p_action in ('leaveSpace','removeMember') then
    if p_action='leaveSpace' then target:=p_uid; end if;
    if target is null or target=s.owner_uid then raise exception 'Transfer ownership before leaving or removing the owner'; end if;
    if not exists(select 1 from stewardie_core.members where space_id=sid and uid=target) then raise exception 'Member unavailable' using errcode='22023'; end if;
    -- Admins cannot remove other managers.
    if p_action='removeMember' and role_name='admin' and exists(select 1 from stewardie_core.members where space_id=sid and uid=target and role<>'member') then raise exception 'Only the owner can remove a manager' using errcode='42501'; end if;
    delete from stewardie_core.members where space_id=sid and uid=target;
    update stewardie_core.tasks set status='unclaimed',owner_uid=null,requested_uid=null,offered_uid=null,version=version+1,updated_at=now()
      where space_id=sid and status<>'completed' and (owner_uid=target or requested_uid=target);
    update stewardie_core.tasks set offered_uid=null,version=version+1,updated_at=now()
      where space_id=sid and status<>'completed' and offered_uid=target;
    update stewardie_core.spaces set pending_owner_uid=null where id=sid and pending_owner_uid=target;
    select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
    event_type:=case when p_action='leaveSpace' then 'left' else 'removed' end;
    result:=jsonb_build_object('ok',true);
  elsif p_action='offerOwnership' then
    if target is null or target=p_uid or not exists(select 1 from stewardie_core.members where space_id=sid and uid=target) then raise exception 'Choose a current member' using errcode='22023'; end if;
    update stewardie_core.spaces set pending_owner_uid=target where id=sid;
    event_type:='ownershipOffered'; audience:=array[target]; result:=jsonb_build_object('ok',true);
  elsif p_action='cancelOwnership' then
    if s.pending_owner_uid is not null and exists(select 1 from stewardie_core.members where space_id=sid and uid=s.pending_owner_uid) then
      target:=s.pending_owner_uid; audience:=array[target]; event_type:='ownershipCancelled';
    end if;
    update stewardie_core.spaces set pending_owner_uid=null where id=sid;
    result:=jsonb_build_object('ok',true);
  elsif p_action='acceptOwnership' then
    if s.pending_owner_uid is distinct from p_uid then raise exception 'This ownership offer is not for you' using errcode='42501'; end if;
    select founder_grant or coalesce(subscription_expires_at>now(),false) into plus from stewardie_core.accounts where uid=p_uid;
    select count(*) into total from stewardie_core.spaces where owner_uid=p_uid and deleted_at is null;
    if total >= (case when plus then 20 else 3 end) then raise exception 'Your account has reached its owned-space limit'; end if;
    update stewardie_core.members set role='member' where space_id=sid and uid=s.owner_uid;
    update stewardie_core.members set role='owner' where space_id=sid and uid=p_uid;
    update stewardie_core.spaces set owner_uid=p_uid,pending_owner_uid=null where id=sid;
    target:=p_uid; event_type:='ownershipAccepted';
    select array_agg(uid) into audience from stewardie_core.members where space_id=sid and uid<>p_uid;
    result:=jsonb_build_object('ok',true);
  elsif p_action='deleteSpace' then
    update stewardie_core.spaces set deleted_at=now(),pending_owner_uid=null where id=sid;
    update stewardie_core.invites set revoked=true where space_id=sid;
    update stewardie_core.join_requests set status='rejected' where space_id=sid and status='pending';
    result:=jsonb_build_object('ok',true);
  end if;
  if event_type is not null then
    insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids) values(sid,p_uid,target,event_type,coalesce(audience,'{}'));
  end if;
  insert into stewardie_core.operations(uid,operation_id,action,payload,result) values(p_uid,op,p_action,p_payload,result);
  return result;
end;
$$;
revoke all on function public.stewardie_core_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.stewardie_core_action(text,text,jsonb) to service_role;
-- Only the wrapper is exposed to the service gateway.
revoke all on function public.stewardie_core_base_action(text,text,jsonb) from service_role;
