-- Privileged edge/worker bridge. This RPC is deliberately absent from core-data's
-- client action allowlist; only the service role can invoke it.
create function public.stewardie_core_service(p_action text,p_path text,p_data jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare v jsonb; rows jsonb; parts text[]:=string_to_array(p_path,'/'); changed int; prior stewardie_core.documents%rowtype;
begin
  if p_action='deletedSpaces' then
    select coalesce(jsonb_agg(jsonb_build_object('id',s.id)),'[]') into rows from stewardie_core.spaces s where s.deleted_at is not null and not exists(select 1 from stewardie_core.documents d where d.path='spaceDeletionJobs/'||s.id and d.data->>'status'='done');
    return jsonb_build_object('rows',rows);
  elsif p_action='purgeSpace' then
    perform 1 from stewardie_core.spaces where id=p_path and deleted_at is not null for update;
    if not found then raise exception 'Space deletion not authorized' using errcode='42501'; end if;
    delete from stewardie_core.tasks where space_id=p_path;
    delete from stewardie_core.members where space_id=p_path;
    delete from stewardie_core.events where space_id=p_path;
    delete from stewardie_core.join_requests where space_id=p_path;
    delete from stewardie_core.invites where space_id=p_path;
    delete from stewardie_core.documents where starts_with(path,'spaces/'||p_path||'/') or (path like 'accounts/%/activity/%' and data->>'spaceId'=p_path);
    insert into stewardie_core.documents(path,data) values('spaceDeletionJobs/'||p_path,jsonb_build_object('status','done','completedAt',now())) on conflict(path) do update set data=excluded.data,updated_at=now();
    return jsonb_build_object('ok',true);
  elsif p_action='get' then
    v:=public.stewardie_core_lookup(p_path);
    return jsonb_build_object('data',v,'updatedAt',(select updated_at from stewardie_core.documents where path=p_path));
  elsif p_action='list' then
    if p_path='spaces' then
      select coalesce(jsonb_agg(jsonb_build_object('path','spaces/'||id,'data',public.stewardie_core_lookup('spaces/'||id),'updatedAt',created_at)),'[]') into rows from stewardie_core.spaces where deleted_at is null;
    elsif p_path='accounts' then
      select coalesce(jsonb_agg(jsonb_build_object('path','accounts/'||uid,'data',public.stewardie_core_lookup('accounts/'||uid),'updatedAt',created_at)),'[]') into rows from stewardie_core.accounts;
    elsif parts[1]='spaces' and parts[3]='tasks' then
      select coalesce(jsonb_agg(jsonb_build_object('path',p_path||'/'||id,'data',public.stewardie_core_lookup(p_path||'/'||id),'updatedAt',updated_at)),'[]') into rows from stewardie_core.tasks where space_id=parts[2];
    elsif parts[1]='spaces' and parts[3]='members' then
      select coalesce(jsonb_agg(jsonb_build_object('path',p_path||'/'||uid,'data',public.stewardie_core_lookup(p_path||'/'||uid),'updatedAt',joined_at)),'[]') into rows from stewardie_core.members where space_id=parts[2];
    else
      select coalesce(jsonb_agg(jsonb_build_object('path',d.path,'data',d.data,'updatedAt',d.updated_at)),'[]') into rows from (select * from stewardie_core.documents where starts_with(path,p_path||'/') and (coalesce((p_data->>'descendants')::boolean,false) or array_length(string_to_array(path,'/'),1)=array_length(parts,1)+1) order by updated_at desc limit 1000) d;
    end if;
    return jsonb_build_object('rows',rows);
  elsif p_action='reconcile' then
    perform pg_advisory_xact_lock(hashtextextended(parts[2],0));
    insert into stewardie_core.accounts(uid) values(parts[2]) on conflict do nothing;
    -- The edge function has already verified RevenueCat and test-store policy.
    update stewardie_core.accounts set subscription_expires_at=case when p_data->>'tier'='plus' and p_data->>'entitlementSource'='store' then (p_data->>'subscriptionExpiresAt')::timestamptz else null end where uid=parts[2];
    insert into stewardie_core.documents(path,data) values(p_path,p_data) on conflict(path) do update set data=stewardie_core.documents.data||excluded.data,updated_at=now();
    return jsonb_build_object('ok',true);
  elsif p_action='deliver' then
    perform stewardie_core.deliver_events();
    return jsonb_build_object('ok',true);
  elsif p_action in ('set','merge','create','update','delete') then
    select * into prior from stewardie_core.documents where path=p_path for update;
    if p_action='create' and found then return jsonb_build_object('ok',false); end if;
    if p_data ? '_expectedTime' and (not found or prior.updated_at is distinct from (p_data->>'_expectedTime')::timestamptz) then return jsonb_build_object('ok',false); end if;
    if p_action='delete' then delete from stewardie_core.documents where path=p_path;
    else
      v:=p_data-'_expectedTime';
      if p_action in ('merge','update') then v:=coalesce(prior.data,'{}')||v; end if;
      insert into stewardie_core.documents(path,data) values(p_path,v) on conflict(path) do update set data=excluded.data,updated_at=now();
    end if;
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'Unsupported service action' using errcode='22023';
end;
$$;
revoke all on function public.stewardie_core_service(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.stewardie_core_service(text,text,jsonb) to service_role;
