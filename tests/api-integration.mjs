import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID,createHash} from 'node:crypto';
const config=readFileSync(new URL('../data/supabase_config.gd',import.meta.url),'utf8');
const url=/SUPABASE_URL := "([^"]+)"/.exec(config)[1];
const publicKey=/SUPABASE_ANON_KEY := "([^"]+)"/.exec(config)[1];
const secret=process.env.SUPABASE_SECRET_KEY;
assert.ok(secret,'Set SUPABASE_SECRET_KEY for temporary test-account creation and cleanup. Never include it in the game.');
const token=randomBytes(32).toString('hex'), hash=createHash('sha256').update(token).digest('hex');
let userId;
const adminHeaders={apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'};
async function api(action,extra={},jwt='') {
 const response=await fetch(url+'/functions/v1/standalone-game',{method:'POST',headers:{apikey:publicKey,'Content-Type':'application/json',...(jwt?{Authorization:'Bearer '+jwt}:{})},body:JSON.stringify({action,...(action==='leaderboard'?{}:{token}),...extra}),signal:AbortSignal.timeout(20000)});
 return {status:response.status,body:await response.json()};
}
try{
 assert.equal((await api('begin',{score:999999})).status,400);
 const begun=await api('begin');assert.equal(begun.status,200,JSON.stringify(begun.body));
 assert.equal((await api('begin')).body.id,begun.body.id);
 assert.equal((await api('claim')).status,401);
 const start=Date.now()+begun.body.startsAt-begun.body.serverNow;
 const target=begun.body.plan.find(o=>o.kind==='thai');
 await new Promise(r=>setTimeout(r,Math.max(0,start+target.at+300-Date.now())));
 const requestId=randomUUID();
 const tap=await api('hit',{objectId:target.id,requestId});assert.equal(tap.body.score,100);assert.equal(tap.body.accepted,true);
 assert.deepEqual((await api('hit',{objectId:target.id,requestId})).body,tap.body);
 assert.equal((await api('finish')).status,409);
 await new Promise(r=>setTimeout(r,Math.max(0,start+25500-Date.now())));
 const saved=await api('finish');assert.equal(saved.body.saved,true);assert.equal(saved.body.score,100);assert.equal(saved.body.claimed,false);
 assert.deepEqual((await api('finish')).body,saved.body);
 const stored=await fetch(url+'/rest/v1/standalone_rounds?token_hash=eq.'+hash,{headers:adminHeaders}).then(r=>r.json());
 assert.equal(stored.length,1);assert.equal(stored[0].score,100);assert.equal(stored[0].user_id,null);assert.ok(stored[0].finished_at);
 console.log('PASS: guest plays without login; server persists 100 points once.');
 const publicRead=await fetch(url+'/rest/v1/standalone_rounds?select=id',{headers:{apikey:publicKey}});
 assert.ok(publicRead.status===401||publicRead.status===403);
 const email='game-test-'+randomUUID()+'@example.invalid',password=randomBytes(24).toString('hex');
 const userResponse=await fetch(url+'/auth/v1/admin/users',{method:'POST',headers:adminHeaders,body:JSON.stringify({email,password,email_confirm:true,user_metadata:{display_name:'Integration Test'}})});
 const user=await userResponse.json();assert.equal(userResponse.status,200);userId=user.id;
 const auth=await fetch(url+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:publicKey,'Content-Type':'application/json'},body:JSON.stringify({email,password})}).then(r=>r.json());
 assert.ok(auth.access_token);
 const claim=await api('claim',{},auth.access_token);assert.equal(claim.body.claimed,true,JSON.stringify(claim));
 assert.equal((await api('claim',{},auth.access_token)).body.claimed,true);
 const row=await fetch(url+'/rest/v1/standalone_rounds?token_hash=eq.'+hash,{headers:adminHeaders}).then(r=>r.json());
 assert.equal(row[0].user_id,userId);
 const board=await api('leaderboard');assert.ok(board.body.some(r=>r.name==='Integration Test'&&r.score===100));
 await fetch(url+'/auth/v1/logout',{method:'POST',headers:{apikey:publicKey,Authorization:'Bearer '+auth.access_token}});
 console.log('PASS: verified account login claims existing guest score and appears on leaderboard.');
 if(process.env.GODOT_BIN) {
  await new Promise((resolve,reject)=>{
   const child=spawn(process.env.GODOT_BIN,['--headless','--path','.','res://tests/LiveGuest.tscn'],{stdio:'inherit',env:{...process.env,ONEFLAG_TEST_STORAGE:'1',ONEFLAG_TEST_EMAIL:email,ONEFLAG_TEST_PASSWORD:password}});
   const timer=setTimeout(()=>{child.kill();reject(new Error('Godot integration timed out'));},180000);
   child.once('error',reject);child.once('exit',code=>{clearTimeout(timer);code===0?resolve():reject(new Error('Godot integration failed'));});
  });
 }

}finally{
 const removed=await fetch(url+'/rest/v1/standalone_rounds?token_hash=eq.'+hash,{method:'DELETE',headers:adminHeaders});
 assert.ok(removed.ok,'test round cleanup failed');
 if(userId){const rounds=await fetch(url+'/rest/v1/standalone_rounds?user_id=eq.'+userId,{method:'DELETE',headers:adminHeaders});assert.ok(rounds.ok);const deleted=await fetch(url+'/auth/v1/admin/users/'+userId,{method:'DELETE',headers:adminHeaders});assert.ok(deleted.ok,'test user cleanup failed');}
 console.log('Temporary test round and account removed; no email sent.');
}
