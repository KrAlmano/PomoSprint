#!/usr/bin/env python3
"""D03 idle-lock / D05 expired-attempt recovery in a disposable local clone."""
import concurrent.futures
import json
import subprocess
import time

import overnight_exam_backend as base
from overnight_exam_backend import ROOT, auth, rpc, sql, uid, user, historical

DB='pomosprint_night_d03_d05'
base.PG=f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
CHECKS=[]
ORIGINAL_DB='postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_night_backend'
def check(name,ok):
    CHECKS.append({'name':name,'ok':bool(ok)})
    print(('PASS 'if ok else'FAIL ')+name,flush=True)
def source(relative,start,end):
    text=(ROOT/relative).read_text();chunk=text.split(start,1)[1].split(end,1)[0]
    return (start+chunk).strip().replace('CREATE FUNCTION','CREATE OR REPLACE FUNCTION',1)
def install_start():
    sql(source('supabase/proposed/28_exam_core.sql','CREATE FUNCTION public.start_exam_attempt(', 'CREATE FUNCTION public.complete_exam_attempt('))
def install_monthly():
    sql(source('supabase/proposed/29_monthly_competitions.sql','CREATE FUNCTION public.process_monthly_competitions()', '-- Keep old cron function/signature.'))
def start(owner,client=None,exam='lgs_verbal'):
    return rpc(owner,'start_exam_attempt',f"'{client or uid()}','{exam}'")
def held_profile(owner):
    process=subprocess.Popen(['psql',base.PG,'-XqAt','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    process.stdin.write(f"BEGIN;DO $$BEGIN PERFORM 1 FROM public.profiles WHERE id='{owner}' FOR UPDATE;END$$;SELECT 'locked';\n");process.stdin.flush()
    if process.stdout.readline().strip()!='locked':raise RuntimeError('Lock holder did not start')
    return process
def release(process):
    process.stdin.write('ROLLBACK;\n\\q\n');process.stdin.flush();process.wait(timeout=10)
def monthly_short():
    before=time.monotonic();out=sql("set statement_timeout='300ms';select public.process_monthly_competitions();",True)
    return out,time.monotonic()-before

def main():
    check('isolated_clone',sql('select current_database()')==DB)
    # Reset only this disposable clone's two function definitions so that the
    # before/after probes remain repeatable. Read no source user rows.
    for signature in ['start_exam_attempt(uuid,text)','process_monthly_competitions()']:
        result=subprocess.run(['psql',ORIGINAL_DB,'-XqAt','-v','ON_ERROR_STOP=1','-c',
            f"select pg_get_functiondef('public.{signature}'::regprocedure)"],text=True,capture_output=True,check=True)
        original=result.stdout.strip()
        if 'D-03:' in original or 'D-05:' in original:
            raise RuntimeError('Original review clone is no longer the before-fix baseline')
        sql(original)
    # D05 old rejection is captured before installing only the new function.
    owner,_=user(name='QA D05 New Start');expired=start(owner)['attempt'];historical(expired['id'])
    check('old_expired_active_block_reproduced','exam_overlap'in auth(owner,f"select public.start_exam_attempt('{uid()}','lgs_verbal')",True))
    install_start()
    new=start(owner)
    check('expired_active_completed_before_new_start',new['attempt']['status']=='active'and rpc(owner,'get_my_exam_attempts')['attempts'][1]['status']=='completed')
    check('recovery_exact_old_reward',sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{owner}'")=='(3,15)')
    check('recovery_adds_duration_once',sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{owner}'")=='(75,0,0)')
    check('recovery_preserves_original_deadline',sql(f"select finished_at=ends_at and elapsed_seconds=4500 from public.exam_attempts where id='{expired['id']}'")=='t')
    check('unexpired_other_uuid_still_rejected','exam_overlap'in auth(owner,f"select public.start_exam_attempt('{uid()}','lgs_verbal')",True))
    check('new_active_same_uuid_is_idempotent',start(owner,new['attempt']['client_uuid'])['duplicate'])
    same,_=user(name='QA D05 Same UUID');same_attempt=start(same)['attempt'];historical(same_attempt['id'])
    resumed=start(same,same_attempt['client_uuid'])
    check('expired_same_uuid_returns_completed_duplicate',resumed['duplicate']and resumed['attempt']['status']=='completed'and resumed['attempt']['id']==same_attempt['id'])
    again=start(same,same_attempt['client_uuid'])
    check('repeated_same_uuid_does_not_repeat_reward',again['duplicate']and sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{same}'")=='(3,15)')
    foreign,_=user(name='QA D05 Other Owner');foreign_at=start(foreign)['attempt'];historical(foreign_at['id'])
    start(same)
    check('recovery_never_settles_other_owner',sql(f"select status from public.exam_attempts where id='{foreign_at['id']}'")=='active')
    race,_=user(name='QA D05 Race');race_at=start(race)['attempt'];historical(race_at['id']);client=uid()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:responses=list(pool.map(lambda _:start(race,client),range(2)))
    check('concurrent_recovery_one_new_attempt',len({r['attempt']['id']for r in responses})==1 and sum(not r['duplicate']for r in responses)==1)
    check('concurrent_recovery_one_reward',sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{race}'")=='(3,15)')
    race2,_=user(name='QA D05 Different Race');ra=start(race2)['attempt'];historical(ra['id'])
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:errors=list(pool.map(lambda _:auth(race2,f"select public.start_exam_attempt('{uid()}','lgs_verbal')",True),range(2)))
    check('different_uuid_recovery_allows_only_one',sum('exam_overlap'in err for err in errors)==1 and sql(f"select count(*)from public.exam_attempts where user_id='{race2}'and status='active'")=='1')
    invalid,_=user(name='QA D05 Invalid Metadata');ia=start(invalid)['attempt'];historical(ia['id'])
    check('invalid_same_uuid_does_not_mutate_expired','exam_metadata_conflict'in auth(invalid,f"select public.start_exam_attempt('{ia['client_uuid']}','tyt')",True)and sql(f"select status from public.exam_attempts where id='{ia['id']}'")=='active')
    check('invalid_catalog_request_rolls_back_recovery','exam_unavailable'in auth(invalid,f"select public.start_exam_attempt('{uid()}','does_not_exist')",True)and sql(f"select status from public.exam_attempts where id='{ia['id']}'")=='active')
    old_month,_=user(name='QA D05 Previous Month');old_at=start(old_month)['attempt']
    sql(f"update public.exam_attempts set started_at=public._competition_month_time(public._competition_month(now()))-interval '2 hours',ends_at=public._competition_month_time(public._competition_month(now()))-interval '45 minutes'where id='{old_at['id']}'")
    start(old_month)
    check('late_recovery_retains_original_league_month',sql(f"select period_month=(public._competition_month(now())-interval '1 month')::date and completed_at=(select ends_at from public.exam_attempts where id='{old_at['id']}')from public.competition_events where kind='exam'and source_id='{old_at['id']}'")=='t')
    # D03: profile lock proves an idle call does not wait for any profile.
    blocker,_=user(name='QA D03 Lock Owner')
    sql("update public.competition_policy set activates_at=public._competition_month_time((public._competition_month(now())+interval '1 month')::date),legacy_finalized=false")
    holder=held_profile(blocker)
    try:
        error,_=monthly_short();check('old_idle_lock_reproduced','statement timeout'in error)
        install_monthly()
        error,_=monthly_short();check('idle_before_activation_has_no_profile_lock',not error)
    finally:release(holder)
    sql("update public.competition_policy set activates_at=public._competition_month_time(public._competition_month(now())),legacy_finalized=true")
    holder=held_profile(blocker)
    try:
        error,_=monthly_short();check('idle_current_month_has_no_profile_lock',not error)
    finally:release(holder)
    # Work pending: retain profile lock order, then recheck after another worker.
    sql("update public.competition_policy set activates_at=public._competition_month_time((public._competition_month(now())-interval '1 month')::date),legacy_finalized=true;delete from public.competition_periods where period_month=(public._competition_month(now())-interval '1 month')::date")
    repack=sql("select pg_get_functiondef('public._competition_repack_current()'::regprocedure)")
    sql('create table public.qa_d03_calls(kind text)')
    sql(repack.replace('BEGIN\n',"BEGIN\n INSERT INTO public.qa_d03_calls VALUES('repack');\n",1))
    holder=held_profile(blocker)
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
            futures=[pool.submit(sql,"set statement_timeout='8s';select public.process_monthly_competitions();")for _ in range(2)]
            until=time.monotonic()+2
            waiting=0
            while time.monotonic()<until:
                waiting=int(sql("select count(*)from pg_stat_activity where datname=current_database()and wait_event_type='Lock'and query like '%process_monthly_competitions%'")or'0')
                if waiting>=2:break
                time.sleep(.02)
            check('real_work_keeps_profile_lock_order',waiting>=2)
            release(holder);holder=None
            for future in futures:future.result()
        check('locked_recheck_skips_duplicate_processor',sql('select count(*)from public.qa_d03_calls')=='1')
        check('concurrent_month_finalized_once',sql("select count(*)from public.competition_periods where period_month=(public._competition_month(now())-interval '1 month')::date")=='1')
        before=sql('select count(*)from public.competition_results')
        sql('select public.process_monthly_competitions()')
        check('repeated_finalization_has_no_duplicate_results',sql('select count(*)from public.competition_results')==before and sql('select count(*)from public.qa_d03_calls')=='1')
    finally:
        if holder is not None:release(holder)
        sql(repack);sql('drop table public.qa_d03_calls')
    # An actual legacy cutover alone is also due work, even with no past month.
    sql("update public.competition_policy set activates_at=public._competition_month_time(public._competition_month(now())),legacy_finalized=false")
    sql('select public.process_monthly_competitions()')
    check('legacy_cutover_still_finalized',sql('select legacy_finalized from public.competition_policy where singleton')=='t')
    report={'database':DB,'checks':CHECKS,'passed':sum(x['ok']for x in CHECKS),'total':len(CHECKS),'scope':'isolated exact RPC functions; historical expired-attempt and month fixtures; controlled row locks; no real deadline or native claim'}
    (ROOT/'build/overnight_backend/d03_d05_results.json').write_text(json.dumps(report,indent=2))
    print(f"RESULT {report['passed']}/{report['total']}")
    if report['passed']!=report['total']:raise SystemExit(1)

if __name__=='__main__':main()
