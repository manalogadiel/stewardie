import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";
import { decodeProtectedHeader, importX509, jwtVerify } from "https://esm.sh/jose@5.9.6";
import { AccessFailure, authorizedTask, authorizedSpace, adminToken, root, fields } from '../_shared/firebase.ts';
import { reactionTypes, assertReactionAccess, ReactionFailure } from './reaction_policy.mjs';

async function reactionRequest(path:string, init:RequestInit={}) {
 const response=await fetch(`${root}/${path}`, {...init,headers:{authorization:`Bearer ${await adminToken()}`,'content-type':'application/json'}});
 if(response.status===404)return null;
 if(!response.ok)throw new Failure('Could not save reactions. Try again.',503);
 return response.status===204?null:response.json();
}
async function reactions(space:string,id:string,memberUids:string[]) {
 const result:any[]=[];let page='';
 do {
  const body=await reactionRequest(`spaces/${space}/moments/${id}/reactions?pageSize=100${page?`&pageToken=${encodeURIComponent(page)}`:''}`);
  for(const doc of body?.documents??[]) {const row=fields(doc);if(memberUids.includes(row.uid)&&reactionTypes.has(row.type))result.push(row);}
  page=body?.nextPageToken??'';
 }while(page);
 return result;
}
async function clearReactions(space:string,id:string) {
 while(true) {
  const rows=await reactionRequest(`spaces/${space}/moments/${id}/reactions?pageSize=100`);
  if(!rows?.documents?.length)return;
  for(const doc of rows.documents)await reactionRequest(doc.name.split('/documents/')[1],{method:'DELETE'});
 }
}

const project = "stewardie";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {auth:{persistSession:false,autoRefreshToken:false}});
const bucket = sb.storage.from("moments");
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, content-type, apikey","Access-Control-Allow-Methods":"POST, OPTIONS","Cache-Control":"no-store"};
class Failure extends Error { constructor(message:string, public status=400) {super(message);} }
let certs: Record<string,string> = {}; let certExpiry=0;
async function identify(req:Request) {
 const token=req.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
 if(!token || token.length>8192) throw new Failure("Sign in again to share photos.",401);
 let header; try {header=decodeProtectedHeader(token);} catch (_) {throw new Failure("Invalid sign-in.",401);}
 const {kid,alg}=header;
 if(alg!=="RS256" || !kid) throw new Failure("Invalid sign-in.",401);
 if(Date.now()>certExpiry) {
  const res=await fetch("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com");
  if(!res.ok) throw new Failure("Authentication is temporarily unavailable.",503);
  certs=await res.json(); certExpiry=Date.now()+Math.min(3600,Number(res.headers.get("cache-control")?.match(/max-age=(\d+)/)?.[1] ?? 300))*1000;
 }
 if(!certs[kid]) throw new Failure("Sign in again.",401);
 const key=await importX509(certs[kid],"RS256");
 let verified; try {verified=await jwtVerify(token,key,{issuer:`https://securetoken.google.com/${project}`,audience:project,algorithms:["RS256"]});} catch (_) {throw new Failure("Sign in again.",401);}
 const {payload}=verified;
 if(!payload.sub || payload.sub.length>128 || payload.email_verified!==true || typeof payload.auth_time!=="number" || payload.auth_time>Date.now()/1000+60) throw new Failure("Verify your email first.",403);
 return {uid:payload.sub,token};
}
const validId=(s:unknown):s is string=>typeof s==="string"&&/^[A-Za-z0-9_-]{1,150}$/.test(s);
function unpack(v:any):any {
 if(v===undefined)return null;
 if("stringValue" in v)return v.stringValue;
 if("booleanValue" in v)return v.booleanValue;
 if("timestampValue" in v)return v.timestampValue;
 if("integerValue" in v)return Number(v.integerValue);
 if("arrayValue" in v)return (v.arrayValue.values??[]).map(unpack);
 return null;
}
async function firestore(path:string,token:string,optional=false) {
 const res=await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}`,{headers:{Authorization:`Bearer ${token}`}});
 if(res.status===404 && optional)return {};
 if(!res.ok) {
  const detail=await res.json().catch(()=>({}));
  const code=detail.error?.status ?? `HTTP_${res.status}`;
  console.error('Media Firestore access failed',res.status,code);
  if(code==='RESOURCE_EXHAUSTED')throw new Failure('Firestore quota reached. Shared photos will be available when the quota resets.',503);
  if(code==='UNAUTHENTICATED')throw new Failure('Sign in again to load shared photos.',401);
  throw new Failure(code==='PERMISSION_DENIED'?"You no longer have access to this space or task.":`Could not verify space access (${code}). Try again.`,code==='PERMISSION_DENIED'?403:503);
 }
 const body=await res.json();return Object.fromEntries(Object.entries(body.fields??{}).map(([k,v])=>[k,unpack(v)]));
}
const spaceMemberCache = new Map<string, { memberUids: string[]; expiresAt: number }>();
async function member(space:string,auth:{uid:string,token:string}) {
 if(!validId(space))throw new Failure("Invalid space.");
 const cached=spaceMemberCache.get(space);
 if(cached && cached.expiresAt > Date.now()) {
  if(!cached.memberUids.includes(auth.uid))throw new Failure("You are no longer in this space.",403);
  return;
 }
 const parent=await firestore(`spaces/${space}`,auth.token);
 if(!Array.isArray(parent.memberUids)||!parent.memberUids.includes(auth.uid))throw new Failure("You are no longer in this space.",403);
 spaceMemberCache.set(space,{memberUids:parent.memberUids,expiresAt:Date.now()+60000});
}
function check(result:any) {if(result.error)throw new Failure(result.error.message,400);return result.data;}
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});}
async function bounded(req:Request,max:number) {
 if(Number(req.headers.get("content-length"))>max)throw new Failure("Photo request is too large.",413);
 const reader=req.body?.getReader();if(!reader)throw new Failure("Missing request.");
 let length=0;const chunks:Uint8Array[]=[];
 while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>max){await reader.cancel();throw new Failure("Photo request is too large.",413);}chunks.push(value);}
 const result=new Uint8Array(length);let offset=0;for(const c of chunks){result.set(c,offset);offset+=c.length;}return result;
}
// Only baseline JPEG generated by the app. Reject EXIF and arbitrary payloads.
function jpeg(bytes:Uint8Array,max:number,maxEdge:number){
 if(bytes.length<16||bytes.length>max||bytes[0]!==255||bytes[1]!==216||bytes.at(-2)!==255||bytes.at(-1)!==217)throw new Failure("Choose a valid JPEG photo.");
 let at=2;let size:{width:number,height:number}|null=null;
 while(at+4<bytes.length){
  if(bytes[at++]!==255)throw new Failure("Invalid photo encoding.");
  const marker=bytes[at++]; if(marker===218)break;
  const len=(bytes[at]<<8)|bytes[at+1];if(len<2||at+len>bytes.length)throw new Failure("Invalid photo encoding.");
  if(marker===225||marker===237)throw new Failure("Remove photo metadata before sharing.");
  if(marker===192){size={height:(bytes[at+3]<<8)|bytes[at+4],width:(bytes[at+5]<<8)|bytes[at+6]};}
  at+=len;
 }
 if(!size||size.width<1||size.height<1||size.width>maxEdge||size.height>maxEdge)throw new Failure("Photo dimensions are too large.");
 return size;
}
async function getItem(id:string,space:string){
 if(!validId(id))throw new Failure("Invalid photo.");
 const row=check(await sb.from("media_items").select("*").eq("id",id).eq("space_id",space).maybeSingle());
 if(!row)throw new Failure("Photo is unavailable.",404);return row;
}
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return json({error:"Use POST."},405);
 try{
  const auth=await identify(req);
  const isUpload=new URL(req.url).searchParams.get("action")==="upload";
  const raw=await bounded(req,isUpload?2250000:16384);
  if(isUpload){
   const form=await new Response(raw,{headers:{"Content-Type":req.headers.get("content-type")??""}}).formData();
   const id=form.get("id"),space=form.get("space"),taskId=form.get("task")||null,caption=form.get("caption")??"";
   const pinRaw=form.get("pin"),photoSource=form.get("photoSource");
   let pin:null|{lat:number,lng:number,label:string,note:string,source:string,accuracy?:number,locatedAt?:string}=null;
   if(pinRaw!==null){
    if(typeof pinRaw!=="string"||pinRaw.length>700)throw new Failure("Invalid photo place.");
    let p:any;try{p=JSON.parse(pinRaw);}catch(_){throw new Failure("Invalid photo place.");}
    if(!p||typeof p!=="object"||typeof p.lat!=="number"||!Number.isFinite(p.lat)||p.lat<-90||p.lat>90
      ||typeof p.lng!=="number"||!Number.isFinite(p.lng)||p.lng<-180||p.lng>180
      ||typeof p.label!=="string"||p.label.length<1||p.label.length>80
      ||typeof p.note!=="string"||p.note.length>180
      ||!["manual","capture"].includes(p.source)
      ||(p.source==="capture"&&photoSource!=="camera"))throw new Failure("Invalid photo place.");
    pin={lat:p.lat,lng:p.lng,label:p.label,note:p.note,source:p.source};
    if(p.source==="capture"){
     if(typeof p.accuracy!=="number"||!Number.isFinite(p.accuracy)||p.accuracy<0||p.accuracy>10000
       ||typeof p.locatedAt!=="string"||!Number.isFinite(Date.parse(p.locatedAt)))throw new Failure("Invalid capture location.");
     pin.accuracy=p.accuracy;pin.locatedAt=p.locatedAt;
    }
   }
   const photo=form.get("photo"),thumb=form.get("thumbnail"),framingRaw=form.get("framing");
   if(!validId(id)||!validId(space)||(taskId!==null&&!validId(taskId))||typeof caption!=="string"||caption.length>300||!(photo instanceof File)||!(thumb instanceof File))throw new Failure("Invalid photo request.");
   let framing={x:0,y:0,width:1,height:1,ratioName:"original"};
   if(typeof framingRaw==="string"&&framingRaw.length>0&&framingRaw.length<500){
    try{
     const p=JSON.parse(framingRaw);
     if(typeof p==="object"&&p!==null){
      const rx=Number(p.x??0),ry=Number(p.y??0),rw=Number(p.width??1),rh=Number(p.height??1);
      if(Number.isFinite(rx)&&Number.isFinite(ry)&&Number.isFinite(rw)&&Number.isFinite(rh)){
       const x=Math.min(Math.max(rx,0),0.99),y=Math.min(Math.max(ry,0),0.99);
       const maxW=Math.max(0.01,1-x),maxH=Math.max(0.01,1-y);
       const width=Math.min(Math.max(rw,0.01),maxW),height=Math.min(Math.max(rh,0.01),maxH);
       const ratioName=typeof p.ratioName==="string"?p.ratioName.slice(0,32):"custom";
       framing={x,y,width,height,ratioName};
      }
     }
    }catch(_){}
   }
   await member(space,auth);
   const account=await firestore(`accounts/${auth.uid}`,auth.token,true);
   const plus=account.tier==="plus"&&(account.founderGrant===true||account.entitlementSource==="founder"||(account.subscriptionExpiresAt&&new Date(account.subscriptionExpiresAt).getTime()>Date.now()));
   const task=taskId?await authorizedTask(space,taskId,auth.uid):null;
   if(task&&task.creatorUid!==auth.uid&&task.ownerUid!==auth.uid)throw new Failure("Only the task creator or responsible person can attach a photo.",403);
   const bytes=new Uint8Array(await photo.arrayBuffer()),thumbnail=new Uint8Array(await thumb.arrayBuffer());
   const dimensions=jpeg(bytes,2000000,1600);jpeg(thumbnail,200000,320);
   const hashInput=new Uint8Array(bytes.length+thumbnail.length);hashInput.set(bytes);hashInput.set(thumbnail,bytes.length);
   const digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",hashInput))).map(b=>b.toString(16).padStart(2,"0")).join("");
   const row=check(await sb.rpc("reserve_media",{p:{id,uid:auth.uid,space,task:taskId,caption,digest,bytes:bytes.length+thumbnail.length,...dimensions,source:"shared",plus,framing}}));
   if(row.state==="ready")return json({item:row});
   check(await sb.from("media_items").update({pin}).eq("id",id).eq("uploader_uid",auth.uid).eq("state","reserved"));
   const prefix=`${space}/${auth.uid}/${id}`;
   check(await bucket.upload(`${prefix}/photo.jpg`,bytes,{contentType:"image/jpeg",upsert:true}));
   check(await bucket.upload(`${prefix}/thumb.jpg`,thumbnail,{contentType:"image/jpeg",upsert:true}));
   // Recheck authorization after upload; a concurrent removal must not publish.
   await member(space,auth);
   const current=taskId?await authorizedTask(space,taskId,auth.uid):null;
   const item=check(await sb.rpc("finish_media",{p_id:id,p_uid:auth.uid,p_published:!current||current.status==="completed"?new Date().toISOString():null,p_title:current?.status==="completed"?current.title:null,p_completed:current?.status==="completed"?current.ownerUid:null,p_plus:plus}));
   return json({item});
  }
  const body=JSON.parse(new TextDecoder().decode(raw));const space=body.space;
  await member(space,auth);
  if(body.action==="list"){
   const offset=Number(body.offset??0);if(!Number.isInteger(offset)||offset<0||offset>10000)throw new Failure("Invalid page.");
   const rows=check(await sb.from("media_items").select("*").eq("space_id",space).eq("state","ready").order("created_at",{ascending:false}).order("id").range(offset,offset+49));
   for(const taskId of new Set(rows.filter((r:any)=>r.task_id && !r.published_at).map((r:any)=>r.task_id))) {
    const completion=await firestore(`spaces/${space}/taskCompletions/${taskId}`,auth.token,true);
    if(completion.completedAt) {
     check(await sb.from("media_items").update({published_at:completion.completedAt,task_title:completion.title,completed_by:completion.ownerUid}).eq("space_id",space).eq("task_id",taskId).eq("state","ready").is("published_at",null));
     for(const row of rows) if(row.task_id===taskId && !row.published_at) Object.assign(row,{published_at:completion.completedAt,task_title:completion.title,completed_by:completion.ownerUid});
    }
   }
   return json({items:rows,nextOffset:rows.length===50?offset+50:null});
  }
  if(body.action==="publishTask"){
   if(!validId(body.task))throw new Failure("Invalid task.");
   const task=await authorizedTask(space,body.task,auth.uid);
   if(task.status!=="completed")throw new Failure("Finish the task first.");
   check(await sb.from("media_items").update({published_at:task.completedAt??new Date().toISOString(),task_title:task.title,completed_by:task.ownerUid}).eq("space_id",space).eq("task_id",body.task).eq("state","ready").is("published_at",null));
   return json({ok:true});
  }
  let row;
  try {row=await getItem(body.id,space);} catch(e) {
   if(body.action==='delete' && e instanceof Failure && e.status===404)return json({ok:true});
   throw e;
  }
  if(body.action==="delete"){
   if(row.uploader_uid!==auth.uid)throw new Failure("Only the uploader can remove this photo.",403);
   if(row.state==="deleted"){await clearReactions(space,row.id);return json({ok:true});}
   check(await sb.from("media_items").update({state:"deleting"}).eq("id",row.id));
   const prefix=`${space}/${auth.uid}/${row.id}`;
   check(await bucket.remove([`${prefix}/photo.jpg`,`${prefix}/thumb.jpg`]));
   check(await sb.from("media_items").update({state:"deleted"}).eq("id",row.id));
   await clearReactions(space,row.id);
   return json({ok:true});
  }
  if(body.action==='reactions'||body.action==='react') {
   if(row.state!=='ready'||!row.published_at)throw new Failure('This photo is unavailable.',404);
   const parent=await authorizedSpace(space,auth.uid);
   const members=parent.memberUids as string[];
   assertReactionAccess({photo:row,photoId:body.id,spaceId:space,uid:auth.uid,members,type:body.type,change:body.action==='react'});
   // Both participants' account blocks apply to new social interactions.
   if(auth.uid!==row.uploader_uid && body.action==='react' && body.type!==null) {
    const blocked=await reactionRequest(`accounts/${row.uploader_uid}/blocks/${auth.uid}`);
    const reverse=await reactionRequest(`accounts/${auth.uid}/blocks/${row.uploader_uid}`);
    if(blocked||reverse)throw new Failure('Reactions are unavailable for this photo.',403);
   }
   if(body.action==='react') {
    if(body.type!==null&&!reactionTypes.has(body.type))throw new Failure('Choose a valid reaction.');
    const path=`spaces/${space}/moments/${row.id}/reactions/${auth.uid}`;
    if(body.type===null)await reactionRequest(path,{method:'DELETE'});
    else {
     const previous=fields(await reactionRequest(path));
     if(previous.type!==body.type)await reactionRequest(path,{method:'PATCH',body:JSON.stringify({fields:{
      uid:{stringValue:auth.uid},type:{stringValue:body.type},createdAt:{timestampValue:new Date().toISOString()},
     }})});
    }
    // Removal or deletion racing the mutation must never leave a usable reaction.
    try {const current=await getItem(row.id,space);await authorizedSpace(space,auth.uid);if(current.state!=='ready'||!current.published_at)throw new Failure('Photo unavailable.',404);}
    catch(error){await reactionRequest(`spaces/${space}/moments/${row.id}/reactions/${auth.uid}`,{method:'DELETE'});throw error;}
   }
   return json({reactions:await reactions(space,row.id,members)});
  }
  if(body.action==="download"){
   if(row.state!=="ready")throw new Failure("Photo is unavailable.",404);
   const kind=body.thumbnail===true?"thumb":"photo";
   const blob=check(await bucket.download(`${space}/${row.uploader_uid}/${row.id}/${kind}.jpg`));
   return new Response(blob,{headers:{...cors,"Content-Type":"image/jpeg","X-Content-Type-Options":"nosniff"}});
  }
  throw new Failure("Unknown photo action.");
 }catch(error){
  if(error instanceof ReactionFailure)return json({error:error.message},error.status);
  if(error instanceof AccessFailure)return json({error:error.message},error.status);
  if(error instanceof Failure)return json({error:error.message},error.status);
  // Never expose tokens, database details or stack traces to the client/log.
  if(error instanceof SyntaxError)return json({error:"Invalid request."},400);
  return json({error:"Could not finish this photo request. Sign in again or retry shortly."},503);
 }
});
