// Read-only unless --apply is supplied. Uses the existing Firebase CLI login.
// Never prints tokens, passwords, or document contents. Backups stay ignored.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const cli = path.join(root, 'backend/firebase/functions/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
const project = 'stewardie';
const base = `projects/${project}/databases/(default)/documents`;
const api = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1'});
const apply = process.argv.includes('--apply');
function decode(v) {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k,x])=>[k,decode(x)]));
  return null;
}
function encode(v) {
  if (v === null) return {nullValue:null};
  if (v instanceof Date) return {timestampValue:v.toISOString()};
  if (Array.isArray(v)) return {arrayValue:{values:v.map(encode)}};
  if (typeof v === 'string') return {stringValue:v};
  if (typeof v === 'boolean') return {booleanValue:v};
  if (typeof v === 'number') return {integerValue:String(v)};
  return {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}};
}
const data = d => Object.fromEntries(Object.entries(d.fields || {}).map(([k,v])=>[k,decode(v)]));
async function list(collection) {
  let token, docs=[];
  do {
    const result=await api.get(`/${base}/${collection}`,{queryParams:{pageSize:300,...(token?{pageToken:token}:{})},skipLog:{resBody:true}});
    docs.push(...result.body.documents || []);token=result.body.nextPageToken;
  } while(token);
  return docs;
}
async function main() {
  await requireAuth({project,...getGlobalDefaultAccount()});
  const spaces=await list('spaces'), accounts=await list('accounts');
  const backups=[...spaces,...accounts];
  const writes=[]; const memberships=new Map(), ownership=new Map();
  function patch(doc, changes) {
    const before=data(doc);
    const changed=Object.fromEntries(Object.entries(changes).filter(([key,v])=>JSON.stringify(before[key])!==JSON.stringify(v)));
    if(!Object.keys(changed).length)return;
    writes.push({update:{name:doc.name,fields:Object.fromEntries(Object.entries(changed).map(([k,v])=>[k,encode(v)]))},updateMask:{fieldPaths:Object.keys(changed)},...(doc.updateTime?{currentDocument:{updateTime:doc.updateTime}}:{currentDocument:{exists:false}})});
  }
  for(const doc of spaces) {
    const id=doc.name.split('/').at(-1), s=data(doc);
    const members=await list(`spaces/${id}/members`), tasks=await list(`spaces/${id}/tasks`), moods=await list(`spaces/${id}/checkIns`);
    backups.push(...members,...tasks,...moods);
    const ids=members.filter(m=>data(m).status==='active').map(m=>m.name.split('/').at(-1));
    if(!ids.includes(s.ownerUid)) throw new Error(`Owner membership needs manual reconciliation for space ${id}. No migration applied.`);
    patch(doc,{memberUids:ids,memberCount:ids.length,activeTaskCount:tasks.filter(t=>!['completed','cancelled'].includes(data(t).status)).length});
    for(const uid of ids) memberships.set(uid,[...memberships.get(uid)||[],id]);
    ownership.set(s.ownerUid,[...ownership.get(s.ownerUid)||[],id]);
    for(const t of tasks) {
      const value=data(t);const changes={};
      for(const field of ['ownerUid','requestedUid','offeredUid','completedAt']) if(!(field in value))changes[field]=null;
      if(value.version==null)changes.version=1;
      if(value.status==='completed' && typeof value.completedAt==='string')changes.completedAt=new Date(value.completedAt);
      patch(t,changes);
    }
    for(const m of moods) {
      const value=data(m);
      if(!value.expiresAt && value.updatedAt instanceof Date) {
        const expiry=new Date(value.updatedAt);expiry.setUTCHours(24,0,0,0);
        patch(m,{expiresAt:expiry});
      }
    }
  }
  // Match only the explicitly authorized founder identity; never trust a client
  // email string or give Plus to another member in the same space.
  const authApi=new Client({urlPrefix:'https://identitytoolkit.googleapis.com'});
  const lookup=await authApi.post(`/v1/projects/${project}/accounts:lookup`,{email:['gadielmanalo19@gmail.com']},{skipLog:{body:true,resBody:true}});
  const founder=(lookup.body.users || []).find(u=>u.email?.toLowerCase()==='gadielmanalo19@gmail.com' && u.emailVerified===true);
  const accountMap=new Map(accounts.map(a=>[a.name.split('/').at(-1),a]));
  if(founder && !accountMap.has(founder.localId))accountMap.set(founder.localId,{name:`${base}/accounts/${founder.localId}`});
  for(const uid of memberships.keys())if(!accountMap.has(uid))accountMap.set(uid,{name:`${base}/accounts/${uid}`});
  for(const [uid,a] of accountMap) {
    patch(a,{spaceIds:memberships.get(uid)||[],ownedSpaceIds:ownership.get(uid)||[],
      tier:founder?.localId===uid?'plus':'basic',
      ...(founder?.localId===uid?{entitlementSource:'founder'}:{}),
    });
  }
  const folder=path.join(root,'.local');fs.mkdirSync(folder,{recursive:true});
  const backup=path.join(folder,`spark-migration-${Date.now()}.json`);
  fs.writeFileSync(backup,JSON.stringify({project,backups,writes},null,2));
  console.log(JSON.stringify({mode:apply?'apply':'dry-run',spaces:spaces.length,accounts:accountMap.size,updates:writes.length,verifiedFounderFound:!!founder,backup:path.relative(root,backup)}));
  if(apply) {
    if(writes.length>450)throw new Error('Migration exceeds a single atomic batch; split and review before applying.');
    if(writes.length)await api.post(`/${base}:commit`,{writes},{skipLog:{body:true,resBody:true}});
    console.log('Migration committed atomically. No records deleted.');
  }
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
