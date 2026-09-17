begin;
insert into auth.users(id) values('def00000-1111-4000-8000-000000000001'),('def00000-1111-4000-8000-000000000002');
set local role service_role;
do $$
declare h text:=repeat('f',64); r jsonb; sid uuid; req uuid:=gen_random_uuid();
begin
 r:=public.standalone_game('begin',h,p_plan=>'[{"id":0,"kind":"thai","at":0,"speed":350},{"id":1,"kind":"bomb","at":0,"speed":350}]',p_rate_key=>'test-rollback');
 sid:=(r->>'id')::uuid;
 assert (public.standalone_game('begin',h)->>'id')=sid::text;
 assert not exists(select 1 from public.standalone_rounds where id=sid and user_id is not null);
 update public.standalone_rounds set starts_at=clock_timestamp()-interval '1 second' where id=sid;
 r:=public.standalone_game('hit',h,req,0);
 assert r->>'score'='100';
 assert r=public.standalone_game('hit',h,req,0);
 assert public.standalone_game('hit',h,gen_random_uuid(),0)->>'accepted'='false';
 update public.standalone_rounds set last_hit_at=clock_timestamp()-interval '1 second' where id=sid;
 r:=public.standalone_game('hit',h,gen_random_uuid(),1);
 assert r->>'score'='0','bomb penalty applies';
 begin
   perform public.standalone_game('finish',h);
   raise exception 'early finish accepted';
 exception when raise_exception then if sqlerrm<>'round_not_finished' then raise; end if; end;
 update public.standalone_rounds set starts_at=clock_timestamp()-interval '26 seconds' where id=sid;
 r:=public.standalone_game('finish',h);
 assert r->>'saved'='true' and r->>'claimed'='false';
 assert r=public.standalone_game('finish',h);
 begin
   perform public.standalone_game('claim',h);
   raise exception 'guest claim accepted';
 exception when raise_exception then if sqlerrm<>'authentication_required' then raise; end if; end;
 r:=public.standalone_game('claim',h,p_user_id=>'def00000-1111-4000-8000-000000000001',p_name=>'Verified test');
 assert r->>'claimed'='true';
 begin
   perform public.standalone_game('claim',h,p_user_id=>'def00000-1111-4000-8000-000000000002');
   raise exception 'score stolen';
 exception when raise_exception then if sqlerrm<>'already_claimed' then raise; end if; end;
 assert not has_table_privilege('authenticated','public.standalone_rounds','UPDATE');
 assert not has_table_privilege('anon','public.standalone_rounds','SELECT');
 assert not has_function_privilege('authenticated','public.standalone_game(text,text,uuid,integer,jsonb,uuid,text,text)','EXECUTE');
end $$;
reset role;
rollback;
select 'PASS: guest, scoring, replay, claim ownership and privileges; rolled back' as result;
