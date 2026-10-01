const actions=new Set(['listSpaces','listTasks','createSpace','createInvite','joinSpace','createTask','actOnTask',
  'getSpace','previewInvite','setJoinApprovalPolicy','renameSpace','revokeInvite','requestJoin','resolveJoin','leaveSpace','removeMember',
  'offerOwnership','cancelOwnership','acceptOwnership','deleteSpace','getTask','updateTask','deleteTask','setSubtasks',
  'docRead','docList','docWrite','docBatch','docReadBatch']);
export const featureActions=new Set(['profileName','readLocations','startLocationSession','updateLocation','stopLocationSession',
  'savePlan','removePlan','createRoutine','deleteRoutine','checkInArrival','checkInPlanArrival','requestHelp','takeOverTask']);
for(const action of featureActions)actions.add(action);
export function parseCoreRequest(raw) {
  const size=new TextEncoder().encode(raw).length;
  if(size>262144) throw new Error('Request too large');
  const body=JSON.parse(raw);
  if(!body || typeof body!=='object' || Array.isArray(body) || !actions.has(body.action)) throw new Error('Unsupported action');
  const payload=body.payload ?? {};
  if(size>65536 && !(body.action==='docWrite' && /^profiles\/[A-Za-z0-9_-]+$/.test(payload?.path ?? '')))throw new Error('Request too large');
  if(!payload || typeof payload!=='object' || Array.isArray(payload)) throw new Error('Invalid payload');
  // The only account identity used by SQL comes from verified JWT claims.
  if('uid' in payload || 'userId' in payload || 'p_uid' in payload || 'uid' in body || 'userId' in body) throw new Error('Identity must come from authentication');
  return {action:body.action,payload};
}
export function coreError(error) {
  if(error.code==='42501') return {status:403,message:'You no longer have access, or this action is not allowed.'};
  if(error.code==='P0001') return {status:409,message:error.message};
  if(['22023','22007','22008','22P02','23502','23514'].includes(error.code)) return {status:400,message:'Check the entered information.'};
  return {status:503,message:'Could not save right now. Retry with the same operation.'};
}
