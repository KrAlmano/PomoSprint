#!/usr/bin/env python3
"""Marathon late-completion evidence in a disposable, user-empty local clone.

No main-QA writes, hosted HTTP, or credentials. Only named review DB schema and
explicit public config/catalog rows are copied. Historical timestamps are SQL
fixtures; an optional real 300-second wait proves the old ACK window accepts.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "pomosprint_night_backend"
CLONE = "pomosprint_night_marathon31"
BASE = "postgresql://postgres:postgres@127.0.0.1:54322/"
CONTAINER = "supabase_db_pomosprint-local"
CATALOGS = (
    "public.avatars", "public.app_config", "public.exam_catalog",
    "public.competition_policy", "public.competition_avatar_rewards",
    "public.marathon_presence_settings", "public.league_competition_state",
)
CHECKS = []
SIGNATURE = 'public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'
OLD_HASH = '177a238a9aa8a4ffd3738b2865120568'
NEW_HASH = '21bcbc553a8accbde9ebb061517c174a'


def command(args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def query(db, body):
    if db not in {SOURCE, CLONE, "postgres"}:
        raise RuntimeError("Database outside the fixed local allowlist")
    return command(["psql", BASE + db, "-XqAt", "-v", "ON_ERROR_STOP=1"], input=body)


def q(value):
    return "'" + str(value).replace("'", "''") + "'"


def uid():
    return str(uuid.uuid4())


def check(name, condition, **details):
    CHECKS.append({"name": name, "ok": bool(condition), **details})
    print(("PASS " if condition else "FAIL ") + name, flush=True)
    if not condition:
        raise AssertionError(name)


def rpc(owner, name, args):
    if name not in {"complete_marathon_study_session", "confirm_marathon_presence", "complete_study_session"}:
        raise RuntimeError("RPC outside this test's allowlist")
    claims = q(json.dumps({"sub": owner, "role": "authenticated"}))
    return json.loads(query(CLONE, f"begin;set local request.jwt.claims={claims};"
                            f"set local role authenticated;select public.{name}({args});commit;"))


def fixture():
    owner, category = uid(), uid()
    query(CLONE, f"""
      insert into auth.users(id,email,aud,role,raw_user_meta_data,created_at)
      values('{owner}','marathon31-{owner}@pomosprint.local','authenticated',
             'authenticated','{{"name":"QA Marathon Anchor"}}',now());
      update public.profiles set user_segment='yks',timezone='Europe/Istanbul' where id='{owner}';
      insert into public.categories(id,user_id,name,color_hex)
      values('{category}','{owner}','Matematik','#FF0000');
    """)
    return owner, category


def before(wait_ack):
    owner, category = fixture()
    run, client = uid(), uid()
    result = rpc(owner, "complete_marathon_study_session",
                 f"'{client}','{category}',25,false,0,now()-interval '32 minutes','{run}',2,1")
    check("historical_first_focus_normal_reward_preserved", result["total_points"] == 5
          and result["coins_earned"] == 20 and not result["marathon_invalid"])
    evidence = json.loads(query(CLONE, f"""select json_build_object(
      'study_completed_at',s.completed_at,'gate_started_at',g.break_started_at,
      'gate_ends_at',g.break_ends_at,'confirmation_deadline',g.confirmation_deadline,
      'start_delay_seconds',extract(epoch from g.break_started_at-s.completed_at),
      'elapsed_after_focus',extract(epoch from clock_timestamp()-s.completed_at))
      from public.study_sessions s join public.marathon_presence_gates g
      on g.user_id=s.user_id and g.previous_client_uuid=s.client_uuid
      where s.user_id='{owner}' and s.client_uuid='{client}'"""))
    check("before_bug_reproduced_new_window_more_than_six_minutes_after_focus",
          evidence["start_delay_seconds"] > 360 and evidence["elapsed_after_focus"] > 360,
          evidence=evidence)
    # Expected product invariant: this deliberately fails against the old body.
    CHECKS.append({"name": "desired_gate_anchor_is_accepted_focus_end",
                   "ok": evidence["start_delay_seconds"] == 0,
                   "expected_before_failure": True})
    print("EXPECTED_FAIL desired_gate_anchor_is_accepted_focus_end", flush=True)
    if wait_ack:
        target = dt.datetime.fromisoformat(evidence["gate_ends_at"])
        remaining = max(0, (target - dt.datetime.now(dt.timezone.utc)).total_seconds() + 0.3)
        print(f"Waiting {remaining:.1f}s for the unchanged old 300-second gate", flush=True)
        while remaining > 0:
            time.sleep(min(remaining, 20))
            remaining = (target - dt.datetime.now(dt.timezone.utc)).total_seconds() + 0.3
        accepted = rpc(owner, "confirm_marathon_presence", f"'{run}',2,'{uid()}'")
        check("before_late_focus_can_still_receive_real_later_ack", accepted["confirmed"] is True)
        evidence["actual_later_ack"] = accepted
    return evidence


def package(suffix=''):
    path = ROOT / f'supabase/proposed/31_marathon_completion_anchor{suffix}.sql'
    return '\n'.join(line for line in path.read_text().splitlines() if not line.startswith('\\'))


def error(body):
    result = subprocess.run(['psql', BASE + CLONE, '-XqAt', '-v', 'ON_ERROR_STOP=1'],
                            input=body, text=True, capture_output=True)
    return result.stderr if result.returncode else ''


def rpc_error(owner, name, args):
    claims = q(json.dumps({'sub': owner, 'role': 'authenticated'}))
    return error(f'begin;set local request.jwt.claims={claims};set local role authenticated;'
                 f'select public.{name}({args});commit;')


def fingerprint():
    return query(CLONE, f"select md5(pg_get_functiondef('{SIGNATURE}'::regprocedure))")


def rows_digest():
    tables = ('profiles', 'study_sessions', 'marathon_runs', 'marathon_run_sessions',
              'marathon_presence_gates', 'competition_events', 'avatar_unlocks')
    return {table: query(CLONE, 'select md5(coalesce(jsonb_agg(to_jsonb(t) order by '
                           f"to_jsonb(t)::text)::text,'[]'))from public.{table} t")
            for table in tables}


def complete(owner, cat, run, *, minutes=25, delay=10, paused=False, client=None,
             target=2, index=1, start=None):
    client = client or uid()
    start = start or f"now()-interval '{minutes} minutes'-interval '{delay} seconds'"
    args = f"'{client}','{cat}',{minutes},{str(paused).lower()},0,{start},'{run}',{target},{index}"
    return client, rpc(owner, 'complete_marathon_study_session', args)


def gate(owner, run):
    return json.loads(query(CLONE, f"select coalesce((select to_jsonb(g) from public.marathon_presence_gates g where user_id='{owner}'and marathon_uuid='{run}'),'null'::jsonb)"))


def acknowledge(owner, run, index, expected_gate, label):
    """Actual authenticated public ACK within the naturally open server window."""
    candidate = uid()
    args = f"'{run}',{index},'{candidate}'"
    receipt = rpc(owner, 'confirm_marathon_presence', args)
    check(label+'_public_ack_success', receipt['confirmed'] is True
          and receipt['next_client_uuid'] == candidate)
    confirmed = dt.datetime.fromisoformat(receipt['confirmed_at'])
    check(label+'_ack_inside_original_window',
          dt.datetime.fromisoformat(expected_gate['break_ends_at']) <= confirmed
          < dt.datetime.fromisoformat(expected_gate['confirmation_deadline'])
          and receipt['break_ends_at'] == expected_gate['break_ends_at']
          and receipt['confirmation_deadline'] == expected_gate['confirmation_deadline'])
    retry = rpc(owner, 'confirm_marathon_presence', args)
    check(label+'_same_candidate_idempotent_ack', retry == receipt)


def full_plan(target, minutes, *, paused_final=False, concurrent_final=False):
    """Prior-focus+ACK metadata is controlled history, not natural elapsed time.

    Prior study rows receive rewards ONLY via the public normal completion RPC.
    All metadata writes are confined to this new owner in the disposable clone.
    """
    owner, cat = fixture()
    run = uid()
    clients = [uid() for _ in range(target)]
    query(CLONE, f"insert into public.marathon_runs(user_id,client_uuid,target_sessions,duration_minutes)values('{owner}','{run}',{target},{minutes})")
    for i in range(target - 1):
        start = f"now()-interval '{minutes + (target-i-1)*(minutes+5)} minutes'"
        result = rpc(owner, 'complete_study_session', f"'{clients[i]}','{cat}',{minutes},false,0,{start}")
        query(CLONE, f"""insert into public.marathon_run_sessions(user_id,marathon_uuid,session_index,client_uuid,study_session_id,result_json)
          select '{owner}','{run}',{i+1},'{clients[i]}',id,{q(json.dumps(result))}::jsonb
          from public.study_sessions where user_id='{owner}'and client_uuid='{clients[i]}';
          insert into public.marathon_presence_gates(user_id,marathon_uuid,next_session_index,previous_client_uuid,
            break_started_at,break_ends_at,confirmation_deadline,confirmed_at,next_client_uuid)
          select '{owner}','{run}',{i+2},'{clients[i]}',completed_at,completed_at+interval '5 minutes',
            completed_at+interval '6 minutes',completed_at+interval '5 minutes','{clients[i+1]}'
          from public.study_sessions where user_id='{owner}'and client_uuid='{clients[i]}';""")
    # Gates are deliberately not SELECT-able by authenticated users. Read only
    # this controlled fixture's timestamp before invoking the public-role RPC.
    start = q(query(CLONE, f"select confirmed_at::text from public.marathon_presence_gates where user_id='{owner}'and marathon_uuid='{run}'and next_session_index={target}"))+'::timestamptz'
    def finish(_):
        return complete(owner, cat, run, minutes=minutes, paused=paused_final,
                        client=clients[-1], target=target, index=target, start=start)[1]
    if concurrent_final:
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(finish, range(2)))
        check('concurrent_final_exactly_one_duplicate', sum(bool(r.get('duplicate'))for r in results) == 1)
    else:
        results = [finish(0)]
    extra = {25: {2: 2, 3: 3, 4: 5}, 50: {2: 4, 3: 6, 4: 10}}[minutes][target]
    base = 5 if minutes == 25 else 12
    last_base = 4 if paused_final and minutes == 25 else base
    expected = base*(target-1)+last_base+extra
    value = json.loads(query(CLONE, f"select json_build_object('points',p.lifetime_points,'coins',p.coins,'minutes',p.total_minutes,'bonus',r.bonus_awarded,'invalid',r.is_invalid,'count',(select count(*)from public.study_sessions where user_id=p.id))from public.profiles p join public.marathon_runs r on r.user_id=p.id where p.id='{owner}'"))
    tag = f'{minutes}x{target}' + ('_paused_final' if paused_final else '')
    check(tag+'_bonus_and_normal_economy', value == {'points': expected, 'coins': 20*target,
          'minutes': minutes*target, 'bonus': extra, 'invalid': False, 'count': target})
    check(tag+'_result_contract', all(r['marathon_completed'] and r['marathon_bonus_points']==extra for r in results))


def after():
    check('old_exact_body_guard', fingerprint() == OLD_HASH)
    # A receipt created by the OLD body must survive migration byte-for-byte.
    old_owner, old_cat = fixture()
    old_run = uid()
    complete(old_owner, old_cat, old_run, delay=420)
    legacy_gate = gate(old_owner, old_run)
    null_owner,null_cat=fixture()
    null_args=f"'{uid()}','{null_cat}',25,null,0,now()-interval '32 minutes','{uid()}',2,1"
    null_before=rpc_error(null_owner,'complete_marathon_study_session',null_args)
    check('old_null_pause_is_not_accepted','violates not-null constraint'in null_before)
    protected = rows_digest()
    normal_hash = query(CLONE, "select md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))")
    dry = error(package('_dryrun'))
    check('dryrun_thirteen_checks', 'DRYRUN_RESULT' in dry and dry.count(': true')==13 and ': false'not in dry)
    check('dryrun_restores_body_and_rows', fingerprint()==OLD_HASH and rows_digest()==protected)
    query(CLONE, package())
    check('new_exact_body', fingerprint()==NEW_HASH)
    check('migration_preserves_existing_rows', rows_digest()==protected)
    check('old_receipt_never_reanchored', gate(old_owner,old_run)==legacy_gate)
    check('duplicate_install_guard', 'marathon_anchor_already_applied' in error(package()))
    for delay in (10, 299, 300, 350, 360, 420):
        owner, cat = fixture(); run=uid()
        client, result = complete(owner, cat, run, delay=delay)
        invalid = delay >= 360
        check(f'delay_{delay}_normal_reward_kept', result['total_points']==5 and result['coins_earned']==20)
        check(f'delay_{delay}_invalidation_boundary', bool(result['marathon_invalid'])==invalid)
        g = gate(owner,run)
        if invalid:
            check(f'delay_{delay}_no_future_gate', g is None and result['marathon_presence_invalid'] is True)
            check(f'delay_{delay}_ack_rejected', bool(rpc_error(owner,'confirm_marathon_presence',f"'{run}',2,'{uid()}'")))
        else:
            anchored = query(CLONE, f"select (g.break_started_at=s.completed_at and g.break_ends_at=s.completed_at+interval '300 seconds'and g.confirmation_deadline=s.completed_at+interval '360 seconds')::text from public.marathon_presence_gates g join public.study_sessions s on s.user_id=g.user_id and s.client_uuid=g.previous_client_uuid where g.user_id='{owner}'")
            check(f'delay_{delay}_exact_accepted_end_anchor', anchored=='true')
            if delay in (300, 350):
                acknowledge(owner, run, 2, g, f'25min_delay{delay}')
                g = gate(owner,run)
        duplicate = complete(owner, cat, run, delay=delay, client=client)[1]
        check(f'delay_{delay}_duplicate_immutable', duplicate['duplicate'] and duplicate['coins_earned']==0 and gate(owner,run)==g and bool(duplicate['marathon_invalid'])==invalid)
    null_after=rpc_error(null_owner,'complete_marathon_study_session',null_args)
    check('null_pause_remains_rejected_without_rewards','violates not-null constraint'in null_after and query(CLONE,f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{null_owner}'")=='(0,0,0)')
    # Controlled prior ACK fixture, then actual public completion of index2.
    # This separately covers an intermediate (not first/final) delayed focus.
    for minutes,delay in ((25,10),(25,420),(50,300),(50,350),(50,420)):
        owner,cat=fixture();run=uid();first=uid();second=uid()
        result=rpc(owner,'complete_study_session',f"'{first}','{cat}',{minutes},false,0,now()-interval '{2*minutes+5} minutes'-interval '{delay} seconds'")
        query(CLONE,f"""insert into public.marathon_runs(user_id,client_uuid,target_sessions,duration_minutes)values('{owner}','{run}',3,{minutes});
          insert into public.marathon_run_sessions(user_id,marathon_uuid,session_index,client_uuid,study_session_id,result_json)
          select '{owner}','{run}',1,'{first}',id,{q(json.dumps(result))}::jsonb from public.study_sessions where user_id='{owner}';
          insert into public.marathon_presence_gates(user_id,marathon_uuid,next_session_index,previous_client_uuid,break_started_at,break_ends_at,confirmation_deadline,confirmed_at,next_client_uuid)
          select '{owner}','{run}',2,'{first}',completed_at,completed_at+interval '5 minutes',completed_at+interval '6 minutes',completed_at+interval '5 minutes','{second}'from public.study_sessions where user_id='{owner}';""")
        start=q(query(CLONE,f"select confirmed_at::text from public.marathon_presence_gates where user_id='{owner}'"))+'::timestamptz'
        _,result=complete(owner,cat,run,minutes=minutes,target=3,index=2,client=second,start=start)
        base = 5 if minutes==25 else 12
        label=f'intermediate_{minutes}min_index2_delay{delay}'
        check(label+'_normal_economy_kept',query(CLONE,f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{owner}'")==f'({2*minutes},{2*base},40)' and result['total_points']==base and result['coins_earned']==20)
        check(label+'_validity',bool(result['marathon_invalid'])==(delay>=360))
        check(label+'_next_gate',query(CLONE,f"select count(*)from public.marathon_presence_gates where user_id='{owner}'and next_session_index=3")==('0'if delay>=360 else'1'))
        if minutes==50 and delay in (300,350):
            next_gate=json.loads(query(CLONE,f"select to_jsonb(g)from public.marathon_presence_gates g where user_id='{owner}'and next_session_index=3"))
            anchored=query(CLONE,f"select (g.break_started_at=s.completed_at and g.break_ends_at=s.completed_at+interval '300 seconds'and g.confirmation_deadline=s.completed_at+interval '360 seconds')::text from public.marathon_presence_gates g join public.study_sessions s on s.user_id=g.user_id and s.client_uuid=g.previous_client_uuid where g.user_id='{owner}'and g.next_session_index=3")
            check(label+'_accepted_end_anchor',anchored=='true')
            acknowledge(owner,run,3,next_gate,label)
    owner, cat=fixture(); run=uid()
    _, paused=complete(owner,cat,run,delay=420,paused=True)
    check('paused_legitimate_late_accept_preserved', paused['total_points']==4 and paused['coins_earned']==20 and not paused['marathon_invalid'])
    g=gate(owner,run)
    check('paused_legacy_window_explicitly_remains', g is not None and (dt.datetime.fromisoformat(g['break_ends_at'])-dt.datetime.now(dt.timezone.utc)).total_seconds()>295)
    for minutes, points in ((25,5),(50,12)):
        owner,cat=fixture()
        result=rpc(owner,'complete_study_session',f"'{uid()}','{cat}',{minutes},false,0,now()-interval '{minutes+1} minutes'")
        check(f'normal_{minutes}_unchanged',result['total_points']==points and result['coins_earned']==20)
    owner,cat=fixture();run=uid();client=uid()
    args=f"'{client}','{cat}',25,false,0,now()-interval '25 minutes','{run}',2,1"
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
        results=list(pool.map(lambda _:rpc(owner,'complete_marathon_study_session',args),range(2)))
    check('concurrent_first_one_duplicate',sum(bool(r.get('duplicate'))for r in results)==1)
    check('concurrent_first_one_row_gate',query(CLONE,f"select row((select count(*)from public.study_sessions where user_id='{owner}'),(select count(*)from public.marathon_presence_gates where user_id='{owner}'))::text")=='(1,1)')
    future=rpc_error(owner,'complete_marathon_study_session',f"'{uid()}','{cat}',25,false,0,now()+interval '1 minute','{uid()}',2,1")
    check('future_start_guard_preserved','started_at cannot be in the future'in future)
    foreign,_=fixture()
    check('foreign_category_guard_preserved','category does not belong to this user' in rpc_error(foreign,'complete_marathon_study_session',f"'{uid()}','{cat}',25,false,0,now()-interval '26 minutes','{uid()}',2,1"))
    check('foreign_category_rejection_has_no_reward',query(CLONE,f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{foreign}'")=='(0,0,0)')
    for minutes in (25,50):
        for target in (2,3,4):
            full_plan(target,minutes,concurrent_final=(minutes==50 and target==4))
    full_plan(2,25,paused_final=True)
    check('normal_body_still_exact',normal_hash==query(CLONE,"select md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))"))
    saved=rows_digest()
    original=query(CLONE,f"select pg_get_functiondef('{SIGNATURE}'::regprocedure)")
    query(CLONE,original.replace(' v_count integer;', ' v_count integer; /* controlled rollback-guard tamper */'))
    check('rollback_rejects_changed_body','marathon_anchor_down_precondition_changed'in error(package('_down')))
    query(CLONE,original)
    query(CLONE,package('_down'))
    check('rollback_exact_old_body',fingerprint()==OLD_HASH)
    check('rollback_preserves_all_rows',rows_digest()==saved)
    check('rollback_only_own_ledger',query(CLONE,"select count(*)from supabase_migrations.schema_migrations where version='20261028050000'")=='0')
    return {'old_md5':OLD_HASH,'new_md5':NEW_HASH,'paused_afk_gap_remains':True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wait-baseline-ack", action="store_true")
    parser.add_argument('--phase', choices=('before','after'), default='before')
    args = parser.parse_args()
    output = ROOT / f"build/overnight_backend/marathon_anchor_{args.phase}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    if query("postgres", f"select count(*)from pg_database where datname={q(CLONE)}") != "0":
        raise RuntimeError("Clone already exists; never replace an existing database")
    check("source_named_review_clone", query(SOURCE, "select current_database()") == SOURCE)
    created = False
    evidence = None
    try:
        with tempfile.TemporaryDirectory(prefix="pomosprint-marathon31-"):
            dump = ["docker", "exec", CONTAINER, "pg_dump", "-U", "postgres", "-d", SOURCE]
            schema = command([*dump, "--schema-only", "--schema=public", "--schema=auth",
                              "--schema=ops", "--schema=supabase_migrations", "--schema=cron",
                              "--schema=extensions"])
            schema = "\n".join(line for line in schema.splitlines()
                               if line not in {"CREATE SCHEMA public;", "CREATE SCHEMA extensions;"})
            catalogs = command([*dump, "--data-only", *["--table=" + t for t in CATALOGS]])
            query("postgres", f'create database "{CLONE}" owner postgres')
            created = True
            restore = ["docker", "exec", "-i", CONTAINER, "psql", "-U", "supabase_admin",
                       "-d", CLONE, "-XqAt", "-v", "ON_ERROR_STOP=1"]
            command(restore, input='CREATE SCHEMA extensions;CREATE EXTENSION pgcrypto WITH SCHEMA extensions;CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
            command(restore, input=schema)
            command(restore, input=catalogs)
            command(restore, input="alter table auth.users disable trigger on_auth_user_confirmed_newsletter")
            check("clone_has_no_copied_users", query(CLONE, "select count(*)from auth.users") == "0")
            check("production_break_lengths", query(CLONE, "select row(break_seconds,presence_seconds)::text from public.marathon_presence_settings") == "(300,60)")
            evidence = before(args.wait_baseline_ack) if args.phase=='before' else after()
    finally:
        if created:
            query("postgres", f'drop database "{CLONE}"')
        output.write_text(json.dumps({"source": SOURCE, "clone": CLONE,
            "copied_user_data": False, "live_access": False,
            "historical_focus_fixture": True, "actual_300_second_ack_wait": args.wait_baseline_ack,
            "checks": CHECKS, "evidence": evidence}, indent=2) + "\n")
    expected_failures=sum(bool(c.get('expected_before_failure'))for c in CHECKS)
    print(f"RESULT {sum(c['ok']for c in CHECKS)}/{len(CHECKS)}; expected before failures={expected_failures}", flush=True)


if __name__ == "__main__":
    main()
