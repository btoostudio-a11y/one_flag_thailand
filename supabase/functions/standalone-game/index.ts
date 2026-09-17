// Guest access is intentional. Only claim requires a verified Auth identity.
const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const headers = {"Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods":"POST, OPTIONS", "Cache-Control":"no-store", "Content-Type":"application/json"};
const json = (body: unknown,status=200) => new Response(JSON.stringify(body),{status,headers});
async function hash(value: string) { return [...new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value)))].map(b=>b.toString(16).padStart(2,"0")).join(""); }
function plan() {
 const random=()=>crypto.getRandomValues(new Uint32Array(1))[0]/4294967296;
 const times: {at:number;bonus:boolean}[]=[];
 for(let at=700;at<25000;) { times.push({at,bonus:false}); if(at>=21000)times.push({at,bonus:false}); at+=at<6000?1050:at<12000?880:at<18000?720:at<21000?580:460; }
 for(let n=1;n<=8;n++)times.push({at:25000*n/9,bonus:true});
 times.sort((a,b)=>a.at-b.at);
 return times.map(({at,bonus},id)=>{
  const roll=random()*100, weights=at<8000?[65,80,95]:at<17000?[50,70,90]:[40,62,84];
  return {id,at:Math.round(at),kind:bonus||roll<weights[0]?"thai":roll<weights[1]?"usa":roll<weights[2]?"uae":"bomb",
   x:Math.round(125+random()*830),speed:Math.round((at<6000?350:at<12000?450:at<18000?550:at<21000?700:850)*(.92+random()*.16))};
 });
}
Deno.serve(async(request: Request)=>{
 if(request.method==="OPTIONS")return new Response(null,{status:204,headers});
 if(request.method!=="POST")return json({error:"method_not_allowed"},405);
 try {
  if(request.headers.get("content-type")?.split(";")[0].trim()!=="application/json")return json({error:"json_required"},415);
  const reader=request.body?.getReader(); if(!reader)return json({error:"invalid_body"},400);
  const parts: Uint8Array[]=[]; let size=0;
  while(true){const {done,value}=await reader.read(); if(done)break; size+=value.length; if(size>2048){await reader.cancel();return json({error:"body_too_large"},413);} parts.push(value);}
  const bytes=new Uint8Array(size); let offset=0; for(const part of parts){bytes.set(part,offset);offset+=part.length;}
  let input; try {input=JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(bytes));}catch{return json({error:"invalid_json"},400);}
  if(!input||typeof input!=="object"||Array.isArray(input))return json({error:"invalid_body"},400);
  const {action,token,requestId,objectId}=input;
  if(!["begin","hit","finish","result","claim","leaderboard"].includes(action)||
    Object.keys(input).some(k=>!["action","token","requestId","objectId"].includes(k)))return json({error:"invalid_action"},400);
  if(action!=="leaderboard"&&(typeof token!=="string"||!/^[a-f0-9]{64}$/.test(token)))return json({error:"invalid_token"},401);
  if(action==="hit"&&(!Number.isInteger(objectId)||objectId<0||objectId>127||typeof requestId!=="string"||!/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(requestId)))return json({error:"invalid_hit"},400);
  let userId=null,name="Player";
  if(action==="claim") {
   const auth=request.headers.get("authorization");
   if(!auth?.startsWith("Bearer "))return json({error:"authentication_required"},401);
   const response=await fetch(url+"/auth/v1/user",{headers:{apikey:key,Authorization:auth}});
   if(!response.ok)return json({error:"authentication_required"},401);
   const user=await response.json();
   if(!user.id||!user.email_confirmed_at||user.is_anonymous)return json({error:"email_verification_required"},403);
   userId=user.id;
   name=String(user.user_metadata?.display_name||"Player").trim().slice(0,40)||"Player";
  }
  const args={p_action:action,p_token_hash:token?await hash(token):null,p_request_id:action==="hit"?requestId:null,
   p_object_id:action==="hit"?objectId:null,p_plan:action==="begin"?plan():null,p_user_id:userId,p_name:name,
   p_rate_key:action==="begin"?await hash(key+":"+ (request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()||"unknown")):null};
  const response=await fetch(url+"/rest/v1/rpc/standalone_game",{method:"POST",headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify(args)});
  const result=await response.json();
  if(!response.ok){
   const known: Record<string,number>={invalid_token:401,authentication_required:401,round_not_finished:409,already_claimed:409,request_conflict:409,round_expired:410,claim_expired:410,rate_limit:429,invalid_object:400};
   const status=known[result.message];return json({error:status?result.message:"service_unavailable"},status||503);
  }
  return json(result);
 }catch{return json({error:"service_unavailable"},503);}
});
