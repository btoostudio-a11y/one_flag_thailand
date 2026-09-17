-- Standalone game: guest rounds are saved before optional account login.
create table public.standalone_rounds (
 id uuid primary key default gen_random_uuid(),
 token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
 user_id uuid references auth.users(id) on delete set null,
 display_name text not null default 'Player' check (length(display_name) between 1 and 40),
 starts_at timestamptz not null default clock_timestamp() + interval '4 seconds',
 created_at timestamptz not null default clock_timestamp(),
 finished_at timestamptz,
 plan jsonb not null check (jsonb_typeof(plan)='array' and jsonb_array_length(plan) between 1 and 128),
 hits integer[] not null default '{}',
 score integer not null default 0 check (score>=0),
 combo integer not null default 0,
 flags integer not null default 0,
 best_combo integer not null default 0,
 last_hit_at timestamptz,
 request_count integer not null default 0
);
create index standalone_rounds_owner_idx on public.standalone_rounds(user_id,score desc,finished_at);
create table public.standalone_requests (
 round_id uuid not null references public.standalone_rounds(id) on delete cascade,
 request_id uuid not null,
 object_id integer not null,
 response jsonb not null,
 primary key(round_id,request_id)
);
create table public.standalone_limits (
 key_hash text primary key,
 bucket timestamptz not null,
 count integer not null
);
alter table public.standalone_rounds enable row level security;
alter table public.standalone_requests enable row level security;
alter table public.standalone_limits enable row level security;
revoke all on public.standalone_rounds,public.standalone_requests,public.standalone_limits from public,anon,authenticated;
grant select,insert,update,delete on public.standalone_rounds,public.standalone_requests,public.standalone_limits to service_role;

create function public.standalone_game(p_action text,p_token_hash text default null,
 p_request_id uuid default null,p_object_id integer default null,p_plan jsonb default null,
 p_user_id uuid default null,p_name text default 'Player',p_rate_key text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.standalone_rounds%rowtype; prev public.standalone_requests%rowtype;
 item jsonb; ts timestamptz := clock_timestamp(); ms double precision; y double precision;
 accepted boolean := false; output jsonb; attempts integer;
begin
 if p_action='leaderboard' then
   select coalesce(jsonb_agg(t),'[]'::jsonb) into output from (
     select display_name as name,score,finished_at as achieved_at from (
       select distinct on(user_id) user_id,display_name,score,finished_at,id
       from public.standalone_rounds where user_id is not null and finished_at is not null
       order by user_id,score desc,finished_at,id
     ) best order by score desc,finished_at,user_id limit 10
   ) t;
   return output;
 end if;
 if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'invalid_token'; end if;
 if p_action='begin' then
   -- Retry-safe guest capability; serialize concurrent retries of the same token.
   perform pg_advisory_xact_lock(hashtextextended(p_token_hash,0));
   select * into r from public.standalone_rounds where token_hash=p_token_hash for update;
   if not found then
     if p_plan is null or p_rate_key is null then raise exception 'invalid_request'; end if;
     insert into public.standalone_limits(key_hash,bucket,count) values(p_rate_key,date_trunc('hour',ts),1)
       on conflict(key_hash) do update set
         count=case when standalone_limits.bucket=excluded.bucket then standalone_limits.count+1 else 1 end,
         bucket=excluded.bucket returning count into attempts;
     if attempts>120 then raise exception 'rate_limit'; end if;
     insert into public.standalone_rounds(token_hash,plan) values(p_token_hash,p_plan) returning * into r;
   end if;
   if r.finished_at is not null or ts>r.starts_at+interval '2 minutes' then raise exception 'round_expired'; end if;
   return jsonb_build_object('id',r.id,'plan',r.plan,'startsAt',extract(epoch from r.starts_at)*1000,'serverNow',extract(epoch from ts)*1000);
 end if;
 select * into r from public.standalone_rounds where token_hash=p_token_hash for update;
 if not found then raise exception 'invalid_token'; end if;
 if p_action='result' then
   return jsonb_build_object('id',r.id,'saved',r.finished_at is not null,'score',r.score,'flags',r.flags,'bestCombo',r.best_combo,'claimed',r.user_id is not null);
 end if;
 if p_action='claim' then
   -- Only trusted Edge code supplies an identity after Auth verification.
   if p_user_id is null then raise exception 'authentication_required'; end if;
   if r.finished_at is null then raise exception 'round_not_finished'; end if;
   if r.created_at<ts-interval '30 days' then raise exception 'claim_expired'; end if;
   if r.user_id is not null and r.user_id<>p_user_id then raise exception 'already_claimed'; end if;
   update public.standalone_rounds set user_id=p_user_id,display_name=left(coalesce(nullif(trim(p_name),''),'Player'),40) where id=r.id;
   return jsonb_build_object('claimed',true,'score',r.score);
 end if;
 ms:=extract(epoch from(ts-r.starts_at))*1000;
 if p_action='finish' then
   if ms<25000 then raise exception 'round_not_finished'; end if;
   if r.finished_at is null then
     if ms>120000 then raise exception 'round_expired'; end if;
     update public.standalone_rounds set finished_at=ts where id=r.id;
   end if;
   return jsonb_build_object('id',r.id,'saved',true,'score',r.score,'flags',r.flags,'bestCombo',r.best_combo,'claimed',r.user_id is not null);
 end if;
 if p_action<>'hit' or p_action is null or p_object_id is null or p_request_id is null then raise exception 'invalid_action'; end if;
 select * into prev from public.standalone_requests where round_id=r.id and request_id=p_request_id;
 if found then
   if prev.object_id<>p_object_id then raise exception 'request_conflict'; end if;
   return prev.response;
 end if;
 if r.finished_at is not null or ms<0 or ms>=25000 then return jsonb_build_object('accepted',false,'score',r.score); end if;
 if r.request_count>=256 then raise exception 'rate_limit'; end if;
 select o into item from jsonb_array_elements(r.plan) o where (o->>'id')::integer=p_object_id;
 if item is null then raise exception 'invalid_object'; end if;
 y:=2050-(item->>'speed')::double precision*(ms-(item->>'at')::double precision)/1000;
 if ms>=(item->>'at')::double precision and y between 70 and 2050 and not p_object_id=any(r.hits)
   and (r.last_hit_at is null or ts-r.last_hit_at>=interval '40 milliseconds') then
   accepted:=true;
   if item->>'kind'='thai' then
     r.score:=r.score+100*least(r.combo+1,5); r.combo:=r.combo+1; r.flags:=r.flags+1; r.best_combo:=greatest(r.best_combo,least(r.combo,5));
   elsif item->>'kind'='bomb' then r.score:=greatest(0,r.score-300); r.combo:=0;
   else r.combo:=0; end if;
   update public.standalone_rounds set score=r.score,combo=r.combo,flags=r.flags,best_combo=r.best_combo,
     hits=array_append(r.hits,p_object_id),last_hit_at=ts where id=r.id;
 end if;
 update public.standalone_rounds set request_count=request_count+1 where id=r.id;
 output:=jsonb_build_object('accepted',accepted,'score',r.score);
 insert into public.standalone_requests values(r.id,p_request_id,p_object_id,output);
 return output;
end $$;
revoke all on function public.standalone_game(text,text,uuid,integer,jsonb,uuid,text,text) from public,anon,authenticated;
grant execute on function public.standalone_game(text,text,uuid,integer,jsonb,uuid,text,text) to service_role;
