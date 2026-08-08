const assert = require('node:assert/strict');
const mapper = require(process.argv[2]);
const correlationId='00000000-0000-4000-8000-000000000001';
const approved=new Set(['DENY_UNAUTHENTICATED','DENY_ACTOR_UNKNOWN','DENY_MEMBERSHIP_INACTIVE','DENY_TENANT_AMBIGUOUS','DENY_TENANT_UNAUTHORIZED','DENY_AUTHORITY_VERSION_CONFLICT','DENY_RESOURCE_TENANT_MISMATCH','DENY_MFA_REQUIRED','DENY_RATE_LIMITED','DENY_IDEMPOTENCY_CONFLICT','DENY_AUDIT_PERSISTENCE','DENY_VALIDATION','DENY_ROLE','DENY_ACTION','DENY_AUTHORITY_UNAVAILABLE']);
const cases=[
  ['POSTGRES_ERROR',Object.assign(new Error('SQLSTATE 23505 detail secret_token=abc'),{code:'POSTGRES_ERROR',status:500})],
  ['RPC_ERROR',{code:'RPC_ERROR',status:500,message:'function provenance_api.private failed'}],
  ['AUTH_PROVIDER_ERROR',{code:'AUTH_PROVIDER_ERROR',status:503,message:'provider body token=secret'}],
  ['NETWORK_ERROR',new Error('fetch ECONNRESET database.internal')],
  ['TIMEOUT',Object.assign(new Error('request timeout /srv/app/private.ts'),{name:'TimeoutError'})],
  ['UNEXPECTED_JAVASCRIPT_ERROR',new TypeError('Cannot read privateKey of undefined')],
  ['STRING_THROW','raw provider secret bearer abc'],
  ['OBJECT_THROW',{detail:'SQL select * from private',hint:'use secret',status:500}],
  ['ERROR_WITH_STACK',Object.assign(new Error('internal module path'),{stack:'Error: internal\n at /srv/app/private.ts:1'})],
  ['ERROR_WITH_SQL_DETAIL_AND_SECRET',{code:'DATABASE_CONSTRAINT',status:500,message:'constraint users_email_key',detail:'password=hunter2',secret:'sk_live_abc'}],
  ['ERROR_WITH_UNAPPROVED_FIELD_DETAILS',{code:'VALIDATION_FAILURE',status:422,message:'invalid',fieldErrors:{password:['password=hunter2'],token:['sk_live_abc']}}],
];
const forbidden=['SQLSTATE','secret_token','provenance_api.private','provider body','token=secret','ECONNRESET','database.internal','/srv/app','privateKey','bearer abc','select *','password=hunter2','sk_live_abc','users_email_key','stack','detail','hint','constraint'];
const results=[];
for(const [name,error] of cases){
  try{
    const mapped=mapper.mapPublicAuthorityError(error,{correlationId,endpoint:'/api/v1/test',timestamp:'2026-07-27T00:00:00.000Z'});
    const serialized=JSON.stringify(mapped.public);
    assert.ok(approved.has(mapped.public.code));
    assert.equal(mapped.public.correlation_id,correlationId);
    assert.equal(typeof mapped.public.message,'string');
    assert.equal(mapped.diagnostic.correlationId,correlationId);
    assert.equal(mapped.diagnostic.endpoint,'/api/v1/test');
    assert.equal(mapped.status >= 400 && mapped.status < 600,true);
    assert.deepEqual(Object.keys(mapped.public).sort(),['code','correlation_id','denied','message','ok','retryable'].sort());
    for(const value of forbidden)assert.equal(serialized.toLowerCase().includes(value.toLowerCase()),false,`leaked ${value}`);
    let recorded=null; mapper.recordServerDiagnostic(mapped.diagnostic,(_event,record)=>{recorded=record}); assert.deepEqual(recorded,mapped.diagnostic);
    results.push({name,pass:true,publicCode:mapped.public.code,category:mapped.diagnostic.category});
  }catch(errorValue){results.push({name,pass:false,error:String(errorValue)});}
}
const failed=results.filter(x=>!x.pass);console.log(JSON.stringify({checks:results.length,passed:results.length-failed.length,failed:failed.length,results},null,2));if(failed.length)process.exit(1);
