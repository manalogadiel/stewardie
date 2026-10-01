import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.57.4';
import {identify, AccessFailure} from '../_shared/firebase.ts';
import {parseCoreRequest, coreError,featureActions} from './request_policy.mjs';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers});
  if (request.method !== 'POST') return Response.json({error:'Method not allowed'}, {status:405,headers});
  // Cutover stays off until imported data and all dependent readers agree.
  if (Deno.env.get('STEW_CORE_ENABLED') !== 'true') {
    return Response.json({error:'Shared data migration is not enabled yet.'}, {status:503,headers});
  }
  try {
    const uid = await identify(request); // Firebase JWT verification; NO Firestore lookup.
    const raw = await request.text();
    const {action,payload} = parseCoreRequest(raw);
    const url = Deno.env.get('SUPABASE_URL');
    const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) throw new AccessFailure('Service unavailable.',503);
    const sb=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await sb.rpc(action.startsWith('doc')?'stewardie_core_documents':featureActions.has(action)?'stewardie_core_features':'stewardie_core_action', {
      p_uid:uid, p_action:action, p_payload:payload,
    });
    if(error) {
      const failure=coreError(error);
      return Response.json({error:failure.message},{status:failure.status,headers});
    }
    return Response.json(data,{headers});
  } catch(error) {
    const status=error instanceof AccessFailure ? error.status : 400;
    return Response.json({error: error instanceof AccessFailure ? error.message : 'Check your request.'}, {status,headers});
  }
});
