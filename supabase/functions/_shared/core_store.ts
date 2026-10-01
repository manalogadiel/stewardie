import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';
export const coreEnabled = () => Deno.env.get('STEW_CORE_ENABLED') === 'true';
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {auth:{persistSession:false}});
export async function service(action:string,path:string,data:Record<string,unknown>={}) {
  const result=await db.rpc('stewardie_core_service',{p_action:action,p_path:path,p_data:data});
  if(result.error)throw new Error(`Core storage unavailable (${result.error.code})`);
  return result.data;
}
export async function coreLookup(path:string) {return (await service('get',path)).data;}
export async function coreAction(uid:string,action:string,payload:Record<string,unknown>) {
  const result=await db.rpc('stewardie_core_action',{p_uid:uid,p_action:action,p_payload:payload});
  if(result.error)throw new Error(`Core workflow unavailable (${result.error.code})`);
  return result.data;
}
function pack(value:any):any {
  if(value==null)return {nullValue:null};
  if(typeof value==='string')return {stringValue:value};
  if(typeof value==='boolean')return {booleanValue:value};
  if(typeof value==='number')return {doubleValue:value};
  if(Array.isArray(value))return {arrayValue:{values:value.map(pack)}};
  return {mapValue:{fields:Object.fromEntries(Object.entries(value).map(([k,v])=>[k,pack(v)]))}};
}
export function coreDocument(path:string,data:any,updatedAt?:string) {
  return data==null?null:{name:`projects/stewardie/databases/(default)/documents/${path}`,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,pack(v)])),updateTime:updatedAt??data.updatedAt??data.createdAt};
}
export async function coreGet(path:string) {const row=await service('get',path);return coreDocument(path,row.data,row.updatedAt);}
export async function coreList(path:string,descendants=false) {return (await service('list',path,{descendants})).rows.map((row:any)=>coreDocument(row.path,row.data,row.updatedAt));}
