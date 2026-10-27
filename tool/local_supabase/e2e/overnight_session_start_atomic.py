#!/usr/bin/env python3
"""Proposal 30 checks in a fixed disposable LOCAL review clone only.

The original function is restored at the end. No main QA database or hosted
service is read/written. Seed rows and delays below are explicit race fixtures.
"""
import concurrent.futures
import json
import re

import overnight_exam_backend as base
from overnight_exam_backend import ROOT, auth, rpc, sql, uid, user

DB = 'pomosprint_night_start30'
base.PG = f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
RESULTS = []
OLD_HASH = '9500c7c45503a3e5031e52c879b1dba2'
NEW_HASH = '1582a6da3c5e9ff496a8f2c16455b13e'


def package(name):
    return '\n'.join(line for line in (ROOT/'supabase/proposed'/name).read_text().splitlines()
                     if not line.startswith('\\'))


def check(name, value):
    RESULTS.append({'name': name, 'ok': bool(value)})
    print(('PASS ' if value else 'FAIL ')+name, flush=True)


def fingerprint():
    return sql("select md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))")


def starts(who, minutes=25, client=None):
    return rpc(who, 'register_session_start', f"'{client or uid()}',{minutes}")


def main():
    check('disposable_database_guard', sql('select current_database()') == DB)
    check('old_reviewed_function_guard', fingerprint() == OLD_HASH)
    before = sql('select row((select count(*)from public.profiles),(select count(*)from public.study_sessions),(select count(*)from public.session_starts),(select count(*)from public.avatar_unlocks))::text')
    dry = sql(package('30_session_start_atomic_dryrun.sql'), True)
    check('dryrun_ten_checks_true', 'DRYRUN_RESULT' in dry and len(re.findall(r'T\d+ [^|\n]+: true', dry)) == 10 and ': false' not in dry)
    check('dryrun_rolls_back_definition', fingerprint() == OLD_HASH)
    check('dryrun_preserves_all_row_counts', before == sql('select row((select count(*)from public.profiles),(select count(*)from public.study_sessions),(select count(*)from public.session_starts),(select count(*)from public.avatar_unlocks))::text'))
    sql(package('30_session_start_atomic.sql'))
    try:
        check('installed_exact_function', fingerprint() == NEW_HASH)
        check('repeat_install_rejected', 'session_start_atomic_already_applied' in sql(package('30_session_start_atomic.sql'), True))
        check('anon_execute_denied', 'permission denied' in sql(f"begin;set local role anon;select public.register_session_start('{uid()}',25);rollback;", True))
        owner, cat = user(name='QA Atomic Start Owner')
        check('invalid_duration_rejected', 'invalid duration' in auth(owner,f"select public.register_session_start('{uid()}',30)",True))
        check('null_uuid_rejected', 'invalid client_uuid' in auth(owner,'select public.register_session_start(null,25)',True))
        check('missing_profile_rejected', 'not authenticated: profile_not_found' in auth(uid(),f"select public.register_session_start('{uid()}',25)",True))
        key = uid(); first = starts(owner,client=key); repeated = starts(owner,client=key)
        check('sequential_retry_same_timestamp', first['created'] and not repeated['created'] and first['server_started_at'] == repeated['server_started_at'])
        check('duration_conflict_classifiable', 'invalid duration: session_start_metadata_conflict' in auth(owner,f"select public.register_session_start('{key}',50)",True))
        check('rejected_metadata_keeps_original',sql(f"select duration_minutes from public.session_starts where user_id='{owner}'and client_uuid='{key}'")=='25')
        check('timestamp_is_not_a_request_parameter', sql("select pg_get_function_arguments('public.register_session_start(uuid,integer)'::regprocedure)") == 'p_client_uuid uuid, p_duration_minutes integer')
        r,_=user(name='QA Atomic Quota'); r2,_=user(name='QA Atomic Duplicate')
        sql(f"insert into public.session_starts(user_id,client_uuid,duration_minutes,server_started_at)select '{r}',gen_random_uuid(),25,now()-interval '1 hour'from generate_series(1,99)")
        sql(f"create function public.qa30_delay()returns trigger language plpgsql as $$begin if new.user_id in('{r}','{r2}')then perform pg_sleep(0.5);end if;return new;end$$;create trigger qa30_delay before insert on public.session_starts for each row execute function public.qa30_delay();")
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
                race=list(pool.map(lambda _:auth(r,f"select public.register_session_start('{uid()}',25)",True),range(2)))
            check('quota_99_plus_2_stays_at_100',sql(f"select count(*)from public.session_starts where user_id='{r}'")=='100')
            check('quota_race_one_explicit_rejection',sum('too_many_session_starts' in result for result in race)==1)
            existing=sql(f"select client_uuid from public.session_starts where user_id='{r}'order by client_uuid limit 1")
            check('full_quota_existing_uuid_can_retry',starts(r,client=existing)['created'] is False)
            same=uid()
            with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
                race=list(pool.map(lambda _:starts(r2,client=same),range(2)))
            check('same_uuid_concurrent_one_created',sum(result['created'] for result in race)==1)
            check('same_uuid_concurrent_one_timestamp',len({result['server_started_at']for result in race})==1)
            check('same_uuid_concurrent_one_row',sql(f"select count(*)from public.session_starts where user_id='{r2}'and client_uuid='{same}'")=='1')
        finally:
            sql('drop trigger qa30_delay on public.session_starts;drop function public.qa30_delay()')
        window,_=user(name='QA Atomic Window')
        sql(f"insert into public.session_starts values('{window}','{uid()}',25,now()-interval '49 hours'),('{window}','{uid()}',25,now()-interval '25 hours');insert into public.session_starts select '{window}',gen_random_uuid(),25,now()-interval '1 hour'from generate_series(1,99)")
        check('window_24_hours_not_total_history', starts(window)['created'] is True and sql(f"select count(*)from public.session_starts where user_id='{window}'and server_started_at>now()-interval '24 hours'")=='100')
        check('cleanup_48_hours_preserved',sql(f"select count(*)from public.session_starts where user_id='{window}'and server_started_at<now()-interval '48 hours'")=='0')
        check('window_25_hour_history_retained',sql(f"select count(*)from public.session_starts where user_id='{window}'")=='101')
        check('owners_have_independent_quotas', starts(owner)['created'] is True)
        check('start_does_not_award_economy',sql(f"select row(coins,lifetime_points,total_minutes)::text from public.profiles where id='{owner}'")=='(0,0,0)')
        # A genuine normal completion still accepts its previous arguments; the
        # new start RPC does not reinterpret clock-corrected p_started_at.
        proof=rpc(owner,'complete_study_session',f"'{uid()}','{cat}',25,false,0,now()-interval '26 minutes'")
        check('normal_queue_contract_unchanged',proof['total_points']==5 and proof['coins_earned']==20)
        saved=sql(f"select md5(coalesce(jsonb_agg(to_jsonb(s)order by user_id,client_uuid)::text,''))from public.session_starts s")
        # Hash guard refuses to undo any later function edit.
        changed=sql("select pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure)").replace('    v_recent integer;','    v_recent integer; -- local tamper test')
        sql(changed)
        check('down_rejects_changed_function','session_start_atomic_down_precondition_changed'in sql(package('30_session_start_atomic_down.sql'),True))
        sql(changed.replace('    v_recent integer; -- local tamper test','    v_recent integer;'))
        sql(package('30_session_start_atomic_down.sql'))
        check('down_restores_exact_old_function',fingerprint()==OLD_HASH)
        check('down_keeps_all_start_rows',saved==sql("select md5(coalesce(jsonb_agg(to_jsonb(s)order by user_id,client_uuid)::text,''))from public.session_starts s"))
        check('down_removes_only_own_migration',sql("select count(*)from supabase_migrations.schema_migrations where version='20261028040000'")=='0')
    finally:
        if fingerprint() == NEW_HASH:
            sql(package('30_session_start_atomic_down.sql'))
    report={'database':DB,'checks':RESULTS,'passed':sum(row['ok']for row in RESULTS),'total':len(RESULTS),'old_md5':OLD_HASH,'new_md5':NEW_HASH,'scope':'local SQL roles, concurrency delay fixtures; no production request or full-duration claim'}
    (ROOT/'build/overnight_backend/session_start_atomic_results.json').write_text(json.dumps(report,indent=2))
    print(f"RESULT {report['passed']}/{report['total']}")
    if report['passed']!=report['total']:raise SystemExit(1)


if __name__=='__main__':
    main()
