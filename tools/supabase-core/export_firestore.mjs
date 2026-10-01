import {writeFile,mkdir} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {initializeApp,applicationDefault} from '../../backend/firebase/functions/node_modules/firebase-admin/lib/app/index.js';
import {getFirestore,FieldPath,Firestore} from '../../backend/firebase/functions/node_modules/firebase-admin/lib/firestore/index.js';
import {checksum} from './import_plan.mjs';
import firebaseCliConfig from '../../backend/firebase/functions/node_modules/firebase-tools/lib/configstore.js';
import firebaseCliApi from '../../backend/firebase/functions/node_modules/firebase-tools/lib/api.js';
const args=process.argv.slice(2);
const arg=k=>args[args.indexOf(k)+1];
const project=args.includes('--project')?arg('--project'):null;
const output=args.includes('--output')?resolve(arg('--output')):null;
if(!project || !output)throw new Error('Use --project PROJECT --output .local/migration/export.json');
const local=project.startsWith('demo-');
if(local && !process.env.FIRESTORE_EMULATOR_HOST)throw new Error('Demo exports require Firestore emulator');
if(!local && !args.includes('--live'))throw new Error('Live read-only export requires --live');
const app=initializeApp(local?{projectId:project}:{projectId:project,credential:applicationDefault()});
const refresh=args.includes('--firebase-cli') ? firebaseCliConfig.configstore.get('tokens')?.refresh_token : null;
if(args.includes('--firebase-cli') && !refresh)throw new Error('Firebase CLI login required');
const db=refresh ? new Firestore({projectId:project,credentials:{type:'authorized_user',
  client_id:firebaseCliApi.clientId(),client_secret:firebaseCliApi.clientSecret(),refresh_token:refresh}}) : getFirestore(app);
const max=Number(process.env.MAX_EXPORT_DOCS ?? 5000);
let count=0;
function encode(value) {
  if(value && typeof value.toDate==='function')return value.toDate().toISOString();
  if(value && typeof value.path==='string' && value.firestore)return {$reference:value.path};
  if(Buffer.isBuffer(value))return {$bytes:value.toString('base64')};
  if(Array.isArray(value))return value.map(encode);
  if(value && typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]));
  return value;
}
async function collection(ref,depth=0) {
  if(depth>8)throw new Error('Nested export exceeds depth bound');
  const result=[];
  let cursor;
  for(;;) {
    let query=ref.orderBy(FieldPath.documentId()).limit(Math.min(50,max-count+1));
    if(cursor)query=query.startAfter(cursor);
    const page=await query.get(); // Read-only; no quota bypass or write.
    if(!page.size)break;
    for(const doc of page.docs) {
      if(++count>max)throw new Error('Export limit reached; no complete snapshot written');
      const children={};
      for(const child of await doc.ref.listCollections())children[child.id]=await collection(child,depth+1);
      result.push({id:doc.id,data:encode(doc.data()),collections:children});
    }
    cursor=page.docs.at(-1);
    if(page.size<50)break;
  }
  return result;
}
try {
  const founder=await db.doc('config/founderPlusGrant').get();
  const data={founderUid:founder.data()?.uid ?? null,accounts:await collection(db.collection('accounts')),
    spaces:await collection(db.collection('spaces')),invites:await collection(db.collection('invites'))};
  const bundle={schemaVersion:1,sourceProject:project,exportedAt:new Date().toISOString(),
    writesFrozen:args.includes('--writes-frozen'),documentCount:count,data,checksum:checksum(data)};
  await mkdir(dirname(output),{recursive:true});
  await writeFile(output,JSON.stringify(bundle,null,2),{flag:'wx',mode:0o600});
  console.log(JSON.stringify({documents:count,checksum:bundle.checksum,output}));
} catch(error) {
  console.error(JSON.stringify({error:'Export incomplete. No snapshot produced.',code:error.code ?? null,
    reason:/quota|RESOURCE_EXHAUSTED/i.test(error.message)?'Firestore quota exhausted':/credential|oauth|token|permission|auth/i.test(error.message)?'Operator authentication/access failed':'Export bounds or service error'}));
  process.exitCode=1;
}
await app.delete();
