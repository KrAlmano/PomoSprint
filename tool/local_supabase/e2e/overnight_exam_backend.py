#!/usr/bin/env python3
"""Exam/competition regression, only the disposable local review database.

Historical owner fixtures test boundaries; one-minute local-only catalog fixtures
separately test real server elapsed time. Neither is a 75-minute native run.
No .env, remote connection, or personal account is used.
"""
from __future__ import annotations
import concurrent.futures
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT=Path(__file__).resolve().parents[3]
DB='pomosprint_night_backend'
PG=f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
RESULTS=[]
def uid(): return str(uuid.uuid4())
def literal(value): return "'"+str(value).replace("'","''")+"'"
def sql(body, fail=False):
    p=subprocess.run(['psql',PG,'-XqAt','-v','ON_ERROR_STOP=1'],input=body,text=True,capture_output=True)
    if fail:return p.stderr if p.returncode else ''
    if p.returncode:raise RuntimeError(p.stderr.strip())
    return p.stdout.strip()
def auth(user,body,fail=False):
    return sql("begin;set local request.jwt.claims="+literal(json.dumps({'sub':user,'role':'authenticated'}))+";set local role authenticated;"+body+';commit;',fail)
def rpc(user,name,args=''):
    return json.loads(auth(user,f'select public.{name}({args})'))
def check(name,ok,detail=None):
    RESULTS.append({'name':name,'ok':bool(ok),**({'detail':detail}if detail is not None else{})})
    print(('PASS 'if ok else'FAIL ')+name,flush=True)
def expect(user,body,error):check(error,error in auth(user,body,True))
def user(segment='yks',name='Night'):
    ident=uid();cat=uid()
    sql(f"insert into auth.users(id,email,aud,role,raw_user_meta_data,created_at) values('{ident}','night-{ident}@pomosprint.local','authenticated','authenticated',jsonb_build_object('name',{literal(name)}),now());update public.profiles set user_segment={literal(segment)},timezone='Europe/Istanbul',show_in_social_feed=true where id='{ident}';insert into public.categories(id,user_id,name,color_hex) values('{cat}','{ident}','Matematik','#FF0000');")
    return ident,cat
def start(who,exam='lgs_quantitative',client=None):return rpc(who,'start_exam_attempt',f"'{client or uid()}',{literal(exam)}")
def historical(attempt,seconds=None):
    if seconds is None:seconds=int(sql(f"select (definition->>'duration_seconds')::int from public.exam_attempts where id='{attempt}'"))
    sql(f"update public.exam_attempts set started_at=clock_timestamp()-make_interval(secs=>{seconds})-interval '1 second',ends_at=clock_timestamp()-interval '1 second' where id='{attempt}';")
def complete(who,cat,client=None):return rpc(who,'complete_study_session',f"'{client or uid()}','{cat}',25,false,0,now()-interval '26 minutes'")
def main():
    check('review_database_name_guard',sql('select current_database()')==DB)
    cfg=json.loads(sql('select public.get_exam_config()'))
    check('catalog_available_version',cfg['available'] and cfg['schema_version']==1)
    check('catalog_seven_official_durations',{e['id']:e['duration_seconds'] for e in cfg['exams']}=={'tyt':9900,'ayt':10800,'ydt':7200,'lgs_verbal':4500,'lgs_quantitative':4800,'tus_basic':8100,'tus_clinical':8100})
    check('catalog_subject_totals',all(sum(s['question_count']for s in e['subjects'])==e['total_questions']for e in cfg['exams']))
    check('catalog_net_divisors',all(e['wrong_answer_divisor']==(3 if e['segment']=='lgs'else 4)for e in cfg['exams']))
    check('anon_config_open',json.loads(sql('begin;set local role anon;select public.get_exam_config();rollback;'))['available'])
    check('anon_history_denied','permission denied' in sql('begin;set local role anon;select public.get_my_exam_attempts();rollback;',True))
    a,cat=user(name='Deneme Sahibi');b,_=user(name='Başka Kullanıcı')
    initial=start(a);at=initial['attempt'];aid=at['id'];cid=at['client_uuid']
    check('server_start_full_duration',round((__import__('datetime').datetime.fromisoformat(at['ends_at'])-__import__('datetime').datetime.fromisoformat(at['started_at'])).total_seconds())==4800)
    expect(a,f"select public.complete_exam_attempt('{aid}')",'exam_not_elapsed')
    check('same_uuid_idempotent_start',start(a,client=cid)['attempt']['id']==aid)
    expect(a,f"select public.start_exam_attempt('{cid}','tyt')",'exam_metadata_conflict')
    expect(a,f"select public.start_exam_attempt('{uid()}','tyt')",'exam_overlap')
    expect(b,f"select public.complete_exam_attempt('{aid}')",'exam_not_found')
    check('foreign_attempt_rls',auth(b,f"select count(*) from public.exam_attempts where id='{aid}'")=='0')
    check('private_payload_denied','permission denied' in auth(a,f"select public._exam_payload('{aid}')",True))
    check('direct_wallet_write_denied','permission denied' in auth(a,"insert into public.exam_wallets values(auth.uid(),999,999)",True))
    check('active_in_history',rpc(a,'get_my_exam_attempts','1')['attempts'][0]['id']==aid)
    expect(a,"select public.start_study_session(25,'Matematik')",'exam_overlap')
    # A normal completion overlaps this active exam in a controlled historical fixture.
    sql(f"update public.exam_attempts set started_at=now()-interval '1 hour',ends_at=now()+interval '20 minutes' where id='{aid}'")
    before=sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{a}'")
    expect(a,f"select public.complete_study_session('{uid()}','{cat}',25,false,0,now()-interval '26 minutes')",'exam_overlap')
    check('failed_overlap_rolls_back_economy',before==sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{a}'"))
    cancelled=rpc(a,'abandon_exam_attempt',f"'{aid}'")['attempt']
    check('abandon_kept_without_rewards',cancelled['status']=='abandoned' and cancelled['elapsed_seconds']>0 and cancelled['points_earned']==0 and cancelled['exam_coins_earned']==0)
    check('abandon_zero_study_minutes',sql(f"select total_minutes from public.profiles where id='{a}'")=='0')
    x=start(a)['attempt'];historical(x['id']);done=rpc(a,'complete_exam_attempt',f"'{x['id']}'")
    check('full_completion_server_rewards',done['attempt']['points_earned']==16 and done['attempt']['exam_coins_earned']==3 and done['attempt']['status']=='completed')
    check('exam_only_separate_economy',sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{a}'")=='(80,0,0)')
    check('completion_contributes_streak',sql(f"select current_streak from public.profiles where id='{a}'")=='1')
    check('duplicate_completion_no_second_rewards',rpc(a,'complete_exam_attempt',f"'{x['id']}'")['duplicate'] and sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{a}'")=='(3,16)')
    payload=json.dumps([{'subject_id':'mathematics','correct':0,'wrong':20,'blank':0}])
    net=rpc(a,'save_exam_results',f"'{x['id']}',{literal(payload)}::jsonb")['attempt']['subject_results'][0]['net']
    check('negative_net_allowed',abs(float(net)+20/3)<1e-10)
    payload2=json.dumps([{'subject_id':'mathematics','correct':20,'wrong':0,'blank':0}])
    rpc(a,'save_exam_results',f"'{x['id']}',{literal(payload2)}::jsonb")
    check('net_edit_no_economy_change',sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{a}'")=='(3,16)' and sql(f"select total_minutes from public.profiles where id='{a}'")=='80')
    for val in [[{'subject_id':'mathematics','correct':21,'wrong':0,'blank':0}],[{'subject_id':'mathematics','correct':19,'wrong':0,'blank':0}],[{'subject_id':'unknown','correct':20,'wrong':0,'blank':0}],[{'subject_id':'mathematics','correct':20,'wrong':0,'blank':0,'net':999}]]:
        expect(a,f"select public.save_exam_results('{x['id']}',{literal(json.dumps(val))}::jsonb)",'exam_result_invalid')
    check('foreign_result_rls',auth(b,f"select count(*) from public.exam_subject_results where attempt_id='{x['id']}'")=='0')
    expect(b,f"select public.save_exam_results('{x['id']}','[]'::jsonb)",'exam_not_found')
    # Real one-minute server time, confined to this disposable review DB.
    template=cfg['exams'][0].copy();template.update(id='review_clock',duration_seconds=60,reward_points=1,reward_coins=1)
    sql(f"insert into public.exam_catalog values('review_clock',{literal(json.dumps(template))}::jsonb,true)")
    c,ccat=user();short=start(c,'review_clock')['attempt'];expect(c,f"select public.complete_exam_attempt('{short['id']}')",'exam_not_elapsed');time.sleep(60.2)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as ex:race=list(ex.map(lambda _:rpc(c,'complete_exam_attempt',f"'{short['id']}'"),range(2)))
    check('real_elapsed_one_minute_complete_race',sum(not r['duplicate']for r in race)==1 and sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{c}'")=='(1,1)')
    d,dcat=user();same=uid()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as ex:race=list(ex.map(lambda _:start(d,client=same),range(2)))
    check('concurrent_same_start_one_attempt',len({r['attempt']['id']for r in race})==1 and sum(not r['duplicate']for r in race)==1)
    old=start(b)['attempt'];sql(f"update public.exam_catalog set definition=jsonb_set(definition,'{{duration_seconds}}','1') where id='lgs_quantitative'")
    check('catalog_mutation_does_not_shorten_attempt',rpc(b,'get_my_exam_attempts','1')['attempts'][0]['duration_seconds']==4800)
    sql(f"update public.exam_catalog set definition={literal(json.dumps(next(e for e in cfg['exams']if e['id']=='lgs_quantitative')))}::jsonb where id='lgs_quantitative'")
    # Social delayed normal cancel cannot erase the attempt.
    sql(f"insert into public.friendships(user_id,friend_id,status)values('{a}','{b}','accepted'),('{b}','{a}','accepted')on conflict do nothing")
    auth(b,'select public.cancel_study_session()')
    social=rpc(a,'get_live_friends_with_breaks')
    check('social_exam_after_delayed_normal_cancel',any(r['id']==b and r['status']=='exam'for r in social))
    sql(f"update public.profiles set show_in_social_feed=false where id='{b}'")
    check('social_hidden_exam_omitted',not any(r['id']==b for r in rpc(a,'get_live_friends_with_breaks')))
    sql(f"update public.profiles set show_in_social_feed=true where id='{b}';insert into public.user_blocks(blocker_id,blocked_id)values('{a}','{b}')")
    check('social_blocked_exam_omitted',not any(r['id']==b for r in rpc(a,'get_live_friends_with_breaks')))
    # Temporal boundary independent of the SQL session time zone.
    check('istanbul_month_boundary',sql("select public._competition_month('2026-10-31 20:59:59+00'),public._competition_month('2026-10-31 21:00:00+00')")=='2026-10-01|2026-11-01')
    check('month_00_not_04',sql("select public._competition_month('2026-10-31 22:00:00+00')")=='2026-11-01')
    snapshot=rpc(a,'get_my_exam_league_ranking')
    check('exam_league_own_points_separate',any(r['is_me'] and r['points']==16 for r in snapshot['rows']))
    check('study_league_does_not_count_exam',all(r['points']==0 for r in rpc(a,'get_monthly_league_ranking',"'study','segment'")['rows']))
    target=rpc(a,'set_competition_target',"'tus'")
    check('midmonth_target_deferred',target['current_segment']=='yks' and target['pending_segment']=='tus' and target['effective_at']is not None)
    check('existing_points_after_target_change',rpc(a,'get_my_exam_league_ranking')['segment']=='yks' and any(r['is_me'] and r['points']==16 for r in rpc(a,'get_my_exam_league_ranking')['rows']))
    fresh,_=user();check('preactivity_target_immediate',rpc(fresh,'set_competition_target',"'tus'")['current_segment']=='tus')
    check('private_competition_tables_denied','permission denied' in auth(a,'select * from public.competition_events',True))
    # A brand-new normal user is included in the server-created segment room.
    norm,ncat=user('lgs','Normal Kullanıcı');normal=complete(norm,ncat)
    check('normal_base_reward_unchanged',normal['total_points']==5 and normal['coins_earned']==20)
    check('normal_and_exam_room_kinds_different',sql("select count(*)from public.competition_rooms where kind='study'")!='0' and sql("select count(*)from public.competition_rooms where kind='exam'")!='0')
    rows=json.loads(sql('begin;set local role anon;select coalesce(jsonb_agg(x),\'[]\'::jsonb)from public.get_public_monthly_competition(10)x;rollback;'))
    check('public_global_study_only_masked',any(r['total_points']==5 and r['name']!='Normal Kullanıcı' for r in rows) and all('id'not in r for r in rows))
    # Save an honest machine-readable result without credentials or identities.
    out=ROOT/'build/overnight_backend/exam_backend_results.json';out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps({'checks':RESULTS,'passed':sum(r['ok']for r in RESULTS),'total':len(RESULTS),'real_time_scope':'60-second review catalog only; full standard durations are owner historical fixtures'},indent=2))
    print(f"RESULT {sum(r['ok']for r in RESULTS)}/{len(RESULTS)}",flush=True)
    if not all(r['ok']for r in RESULTS):raise SystemExit(1)
if __name__=='__main__':main()
