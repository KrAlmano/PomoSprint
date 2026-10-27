#!/usr/bin/env python3
"""Independent league launch policy checks, confined to an isolated local DB.

Never connects to production or mutates the main local Supabase database.
The runner creates pomosprint_league_review through proposed_chain_check.sh,
applies the exact migration, executes public RPCs under authenticated role and
concurrent SQL sessions, then records individual checks as JSON evidence.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "analiz/qa_evidence_20261008/league_launch"
DB = "pomosprint_league_review"
PG = f"postgresql://postgres:postgres@127.0.0.1:54322/{DB}"
RESULTS: list[dict] = []
APPLIED_MIGRATION_SHA: str | None = None


def sql(body: str, *, expect_failure: bool = False) -> str:
    proc = subprocess.run(
        ["psql", PG, "-X", "-qAt", "-v", "ON_ERROR_STOP=1"],
        input=body, text=True, capture_output=True,
        env={**os.environ, "PGOPTIONS": "-c client_min_messages=warning"},
    )
    if expect_failure:
        return proc.stderr if proc.returncode else ""
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip())
    return proc.stdout.strip()


def check(name: str, condition: bool, detail=None) -> None:
    item = {"name": name, "ok": bool(condition)}
    if detail is not None:
        item["detail"] = detail
    RESULTS.append(item)
    print(("PASS " if condition else "FAIL ") + name, flush=True)


def qcheck(name: str, expression: str) -> None:
    value = sql(f"select coalesce(({expression}), false);")
    check(name, value == "t", value)


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def uid() -> str:
    return str(uuid.uuid4())


def make_user(tag: str, tier: int = 1) -> tuple[str, str]:
    user, category = uid(), uid()
    sql(f"""
        insert into auth.users(id,email,aud,role,raw_user_meta_data,created_at)
        values ('{user}', {literal('league-review-' + tag + '-' + user[:8] + '@pomosprint.local')},
          'authenticated','authenticated',jsonb_build_object('name',{literal(tag)}),now());
        update public.profiles set league_tier={tier},timezone='Europe/Istanbul' where id='{user}';
        insert into public.categories(id,user_id,name,color_hex)
        values ('{category}','{user}','Review','#FF0000');
    """)
    return user, category


def auth(user: str, body: str) -> str:
    return sql(f"""begin;
      select set_config('request.jwt.claims','{{"sub":"{user}","role":"authenticated"}}',true);
      set local role authenticated;
      {body}
      commit;
    """).splitlines()[-1]


def complete(user: str, category: str, client: str | None = None) -> dict:
    return json.loads(auth(user, f"select public.complete_study_session('{client or uid()}','{category}',25,false,0,now()-interval '26 minutes');"))


def config(key: str, value: int) -> None:
    sql(f"update public.app_config set value='{value}'::jsonb where key={literal(key)};")


def make_room(tier: int, end: str, start: str | None = None) -> str:
    room = uid()
    sql(f"insert into public.leagues(id,tier,start_date,end_date) values ('{room}',{tier},{start or '(' + end + ")-interval '14 days'"},{end});")
    return room


def member(room: str, user: str, points: int, start: str, joined: str | None = None) -> None:
    sql(f"insert into public.league_memberships(league_id,user_id,weekly_points,period_started_at,joined_at) values ('{room}','{user}',{points},{start},{joined or start});")


def history(user: str, category: str, *, days: int = 3, sessions_per_day: int = 2, points: int = 18, end: str = "now()-interval '1 hour'") -> None:
    """Simulate historical accepted 50-minute records, across distinct study days."""
    sql(f"""
      insert into public.study_sessions(user_id,category,category_id,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at,start_verified)
      select '{user}','Review','{category}',50,{points},0,false,1,gen_random_uuid(),
        ({end})-make_interval(days=>d,hours=>h*2)-interval '50 minutes',
        ({end})-make_interval(days=>d,hours=>h*2),true
      from generate_series(1,{days}) d,generate_series(1,{sessions_per_day}) h;
      update public.profiles set total_minutes=total_minutes+{days * sessions_per_day * 50},
         lifetime_points=lifetime_points+{days * sessions_per_day * points} where id='{user}';
    """)


def invariant_snapshot() -> dict:
    return json.loads(sql("""select jsonb_build_object(
      'profiles',(select jsonb_agg(jsonb_build_array(id,total_minutes,lifetime_points,coins,current_streak,longest_streak) order by id) from public.profiles),
      'sessions',(select jsonb_agg(to_jsonb(s) order by id) from public.study_sessions s),
      'avatars',(select jsonb_agg(to_jsonb(a) order by id) from public.avatar_unlocks a)
    );"""))


def role_error(user: str, statement: str) -> str:
    return sql(f"begin; select set_config('request.jwt.claims','{{\"sub\":\"{user}\",\"role\":\"authenticated\"}}',true); set local role authenticated; {statement}; rollback;", expect_failure=True)


def reset_fixtures() -> None:
    # This DB is a disposable independent copy. Public histories are removed
    # only here so global-active-user threshold scenarios are deterministic.
    sql("delete from public.marathon_run_sessions; delete from public.marathon_presence_gates; delete from public.marathon_runs; delete from public.study_sessions; delete from public.league_memberships; delete from public.leagues;")


def main() -> None:
    global APPLIED_MIGRATION_SHA
    parser = argparse.ArgumentParser()
    parser.add_argument("--reuse", action="store_true", help="Use the already-cloned DB and apply the migration there.")
    parser.add_argument("--skip-migration", action="store_true")
    parser.add_argument("--cron", action="store_true", help="Temporarily schedule one real local pg_cron job targeting only this review DB.")
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    if not args.reuse:
        with (EVIDENCE / "independent_clone.log").open("w") as log:
            subprocess.run([str(ROOT / "tool/local_supabase/proposed_chain_check.sh")], cwd=ROOT,
                env={**os.environ,"CHAIN_DB":DB,"UNTIL":"0","NO_DOWN":"1","KEEP_DB":"1"},
                stdout=log,stderr=subprocess.STDOUT,check=True)
        # The public/auth helper predates the live ops display-name support.
        # Copy its exact private dependency too; neither source DB nor schema
        # is modified. A fresh fixture's handle_new_user resolves this schema.
        container = "supabase_db_pomosprint-local"
        dump = f"/tmp/{DB}_ops.dump"
        subprocess.run(["docker","exec",container,"pg_dump","-U","supabase_admin","-d","postgres","-n","ops","-Fc","-f",dump],check=True)
        subprocess.run(["docker","exec",container,"pg_restore","-U","supabase_admin","-d",DB,dump],check=True)
        subprocess.run(["docker","exec",container,"rm","-f",dump],check=True)
    if not args.skip_migration:
        reconstruct_test_baseline()
    before = invariant_snapshot()
    protected_before = protected_functions()
    if not args.skip_migration:
        migration = ROOT / "supabase/migrations/20261008190000_league_launch_policy.sql"
        migration_bytes = migration.read_bytes()
        APPLIED_MIGRATION_SHA = hashlib.sha256(migration_bytes).hexdigest()
        sql(migration_bytes.decode())
        protect_completion_formulas(protected_before,protected_functions())
    check("migration preserves lifetime totals, histories and owned avatars", before == invariant_snapshot())
    run_checks()
    first_delayed_boundary_checks()
    if args.cron:
        cron_smoke()


def run_checks() -> None:
    reset_fixtures()
    # A synced main-local copy can already have scheduled from202 historical
    # QA owners. Start this capacity/threshold race with only its own records,
    # rather than accidentally accepting an already-scheduled global start.
    sql("update public.league_competition_state set start_at=null,initialized=false,period_started_at=null;")
    config("league_launch_min_active_users",25)
    config("league_room_capacity", 25)
    user, category = make_user("first")
    qcheck("registration alone creates no membership", f"not exists(select 1 from public.league_memberships where user_id='{user}')")
    result = complete(user, category)
    check("first scoring session accepted by authenticated completion RPC", "error" not in result and result.get("total_points", 0) > 0, result)
    room = sql(f"select league_id from public.league_memberships where user_id='{user}';")
    # Fill the exact matching existing room via real completion, then force two
    # independent connections to compete for its last vacancy.
    for i in range(23):
        u, c = make_user(f"fill-{i}")
        complete(u, c)
    qcheck("24 scored users share the existing room", f"(select count(*) from public.league_memberships where league_id='{room}')=24 and (select count(*) from public.leagues where is_active)=1")
    concurrent_users = [make_user("concurrent-A"), make_user("concurrent-B")]
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        simultaneous = list(pool.map(lambda pair: complete(*pair), concurrent_users))
    check("both simultaneous first sessions accepted", all("error" not in r for r in simultaneous), {"seconds": round(time.monotonic()-started,3),"results":simultaneous})
    qcheck("25-seat capacity respected after two concurrent insertions", "(select max(n) from (select count(*) n from public.league_memberships lm join public.leagues l on l.id=lm.league_id where l.is_active group by lm.league_id) x)=25 and (select count(*) from public.league_memberships)=26 and (select count(*) from public.leagues where is_active)=2")
    qcheck("all 26 users have exactly one active membership", "not exists(select lm.user_id from public.league_memberships lm join public.leagues l on l.id=lm.league_id where l.is_active group by lm.user_id having count(*)<>1)")
    qcheck("concurrent crossing of25distinct real completions schedules launch", "(select start_at is not null from public.league_competition_state)")
    config("league_room_capacity", 30)
    expansion_user, expansion_category = make_user("expanded")
    complete(expansion_user, expansion_category)
    qcheck("raising capacity to 30 reuses existing oldest eligible room", f"(select league_id from public.league_memberships where user_id='{expansion_user}')='{room}'::uuid and (select count(*) from public.leagues where is_active)=2")
    config("league_room_capacity",25)
    sql("select public.process_weekly_leagues();")
    qcheck("consolidation/rebalance never leaves an oversized active room", "not exists(select lm.league_id from public.league_memberships lm join public.leagues l on l.id=lm.league_id where l.is_active group by lm.league_id having count(*)>25)")
    qcheck("safe public config exposes current room capacity", "(public.get_app_config()->>'league_room_capacity')::int=25")
    check("authenticated user cannot write room capacity", bool(role_error(user,"update public.app_config set value='30'::jsonb where key='league_room_capacity'")))
    check("authenticated user cannot run period maintenance", bool(role_error(user,"select public.process_weekly_leagues()")))
    check("authenticated user cannot call internal scored placement helper", bool(role_error(user,f"select public.ensure_user_in_league('{user}',99999)")))
    check("foreign ranking is blocked", "not authorized" in role_error(user,f"select * from public.get_league_ranking('{expansion_user}')"))
    qcheck("foreign ranking of another user exposes no user email", "not exists(select 1 from pg_proc p where p.proname in ('get_my_league_ranking','get_league_ranking') and pg_get_function_result(p.oid) ilike '%email%')")
    state_checks()


def reconstruct_test_baseline() -> None:
    """Rebuild old prerequisites only in our disposable isolated review DB.

    Production/main-local may already run this package. Reapplying its
    migration directly would fail its exact-old-body precondition. The
    reviewed down file rebuilds that predecessor in this isolated copy only.
    If production-like state has started, clear the copied state synthetically
    here; this is a test gateway, never a permissible production rollback.
    """
    if sql("select current_database();") != DB:
        raise RuntimeError("Refusing baseline reconstruction outside reserved review DB")
    before=invariant_snapshot()
    source=json.loads(sql("""select jsonb_build_object(
      'normal_md5',md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure)),
      'has_state',to_regclass('public.league_competition_state') is not null,
      'has_migration',exists(select 1 from supabase_migrations.schema_migrations where version='20261008190000')
    );"""))
    old='f0f2b9bcc09ae8440a66d889b5f22fcc'
    new='72023f3f4d8636363cf0231f42d4c7e1'
    known_old=source['normal_md5']==old and not source['has_state'] and not source['has_migration']
    known_new=source['normal_md5']==new and source['has_state'] and source['has_migration']
    check("cloned source is an explicitly supported old/new policy baseline",known_old or known_new,source)
    if not (known_old or known_new):
        raise RuntimeError("Unknown source function/schema: inspect current policy, do not bypass fingerprints")
    evidence={'database':DB,'source':source,'mode':'old_baseline_unchanged','synthetic_state_override':False,'main_or_live_rollback':False}
    if known_new:
        state=json.loads(sql("select jsonb_build_object('start_at',start_at,'initialized',initialized,'period_started_at',period_started_at,'rollback_guard_would_block',initialized or coalesce(start_at<=now(),false)) from public.league_competition_state where singleton;"))
        evidence['source_state']=state
        if state['rollback_guard_would_block']:
            # Permitted only because the SQL destination is the fixed local
            # review DB, never main/postgres or production. Keep this explicit
            # in evidence so it cannot be mistaken for a live down procedure.
            sql("update public.league_competition_state set start_at=null,initialized=false,period_started_at=null;")
            evidence['synthetic_state_override']=True
        down=ROOT/'supabase/rollbacks/20261008190000_league_launch_policy_down.sql'
        down_bytes=down.read_bytes()
        evidence['down_sha256']=hashlib.sha256(down_bytes).hexdigest()
        evidence['mode']='reviewed_down_only_in_isolated_test_copy'
        sql(down_bytes.decode())
    after=invariant_snapshot()
    check("isolated baseline reconstruction preserves lifetime/history/avatar ownership",before==after)
    actual=sql("select md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure));")
    check("isolated reconstruction restores exact old normal completion fingerprint",actual==old,actual)
    evidence['reconstructed_normal_md5']=actual
    evidence['economics_unchanged']=before==after
    (EVIDENCE/'independent_baseline_reconstruction.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')


def protected_functions() -> dict:
    return json.loads(sql("""select jsonb_build_object(
      'normal',pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure),
      'marathon',pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure),
      'marathon_before_presence',pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure)
    );"""))


def protect_completion_formulas(before: dict,after: dict) -> None:
    check("normal completion baseline matches reviewed pre-policy fingerprint",hashlib.md5(before['normal'].encode()).hexdigest()=='f0f2b9bcc09ae8440a66d889b5f22fcc')
    for name in ('marathon','marathon_before_presence'):
        check(name+" full function body remains byte-identical",before[name]==after[name])
    marker="        -- league_launch_policy: ilk puanlı"
    tail="        IF v_period_start IS NOT NULL"
    normal=after['normal']
    first=normal.find(marker)
    following=normal.find(tail,first)
    stripped=normal[:first]+normal[following:] if first>=0 and following>first else None
    check("normal completion changed only the targeted first-scored closed-period guard",stripped==before['normal'])
    diff=''.join(difflib.unified_diff(before['normal'].splitlines(True),after['normal'].splitlines(True),fromfile='live-normal-before',tofile='league-policy-normal-after'))
    (EVIDENCE/'independent_normal_function_diff.patch').write_text(diff)


def first_delayed_boundary_checks() -> None:
    """Deterministic real RPC checks around an official first-user boundary.

    Only the test transaction stubs the grid to an hour ago; all normal RPC
    validation, point arithmetic, inserts and role restrictions remain real.
    The function/state/session changes are fully rolled back afterwards.
    """
    late,late_cat=make_user('first-ever-previous-period',2)
    exact,exact_cat=make_user('first-ever-exact-boundary',2)
    late_client,exact_client,current_client=uid(),uid(),uid()
    boundary=sql("select now()-interval '1 hour';")
    original_grid=sql("select pg_get_functiondef('public._league_grid_start(timestamptz)'::regprocedure);")
    output=sql(f"""
      begin;
      create or replace function public._league_grid_start(p_at timestamptz)
      returns timestamptz language sql immutable set search_path=public,pg_temp
      as $qa_grid$ select {literal(boundary)}::timestamptz $qa_grid$;
      update public.league_competition_state set start_at={literal(boundary)}::timestamptz,
        initialized=true,period_started_at={literal(boundary)}::timestamptz;
      select set_config('request.jwt.claims','{{"sub":"{late}","role":"authenticated"}}',true);
      set local role authenticated;
      select jsonb_build_object('stage','late','result',public.complete_study_session(
        '{late_client}','{late_cat}',25,false,0,{literal(boundary)}::timestamptz-interval '30 minutes'));
      reset role;
      select jsonb_build_object('stage','late_raw','membership',(select to_jsonb(m) from public.league_memberships m where user_id='{late}'),
        'profile',(select jsonb_build_object('minutes',total_minutes,'points',lifetime_points,'coins',coins) from public.profiles where id='{late}'),
        'sessions',(select count(*) from public.study_sessions where user_id='{late}'));
      set local role authenticated;
      select jsonb_build_object('stage','late_duplicate','result',public.complete_study_session(
        '{late_client}','{late_cat}',25,false,0,{literal(boundary)}::timestamptz-interval '30 minutes'));
      select jsonb_build_object('stage','late_current','result',public.complete_study_session(
        '{current_client}','{late_cat}',25,false,0,now()-interval '26 minutes'));
      reset role;
      select jsonb_build_object('stage','late_after_current','membership',(select to_jsonb(m) from public.league_memberships m where user_id='{late}'),
        'profile',(select jsonb_build_object('minutes',total_minutes,'points',lifetime_points,'coins',coins) from public.profiles where id='{late}'),
        'sessions',(select count(*) from public.study_sessions where user_id='{late}'));
      select set_config('request.jwt.claims','{{"sub":"{exact}","role":"authenticated"}}',true);
      set local role authenticated;
      select jsonb_build_object('stage','exact','result',public.complete_study_session(
        '{exact_client}','{exact_cat}',25,false,0,{literal(boundary)}::timestamptz-interval '25 minutes'));
      reset role;
      select jsonb_build_object('stage','exact_raw','membership',(select to_jsonb(m) from public.league_memberships m where user_id='{exact}'),
        'profile',(select jsonb_build_object('minutes',total_minutes,'points',lifetime_points,'coins',coins) from public.profiles where id='{exact}'),
        'sessions',(select count(*) from public.study_sessions where user_id='{exact}'));
      rollback;
    """)
    observed={}
    for line in output.splitlines():
        value=json.loads(line)
        if 'stage' in value:observed[value['stage']]=value
    (EVIDENCE/'independent_first_boundary.json').write_text(json.dumps(observed,ensure_ascii=False,indent=2)+'\n')
    late_result=observed['late']['result'];late_raw=observed['late_raw']
    check("first-ever previous-period valid completed session preserves normal reward",'error' not in late_result and late_result['total_points']>0 and late_raw['sessions']==1 and late_raw['profile']['minutes']==25 and late_raw['profile']['points']==late_result['total_points'])
    check("first-ever previous-period completion reports closed league and0league points",late_result.get('league_period_closed') is True and late_result.get('league_points')==0,late_result)
    check("first-ever previous-period scored completion creates eligible-tier membership with0rawpoints",late_raw['membership'] is not None and late_raw['membership']['weekly_points']==0 and late_raw['membership']['carry_points']==0,late_raw['membership'])
    check("first-ever delayed completion duplicate is idempotent",observed['late_duplicate']['result'].get('duplicate') is True)
    current=observed['late_current']['result'];current_raw=observed['late_after_current']
    check("subsequent current-period completion credits only newperiod league points",current.get('league_points')==current['total_points'] and current_raw['membership']['weekly_points']==current['total_points'] and current_raw['membership']['carry_points']==0)
    check("old/current completions stay in reports once each while league excludes old one",current_raw['sessions']==2 and current_raw['profile']['minutes']==50 and current_raw['profile']['points']==late_result['total_points']+current['total_points'])
    exact_result=observed['exact']['result'];exact_raw=observed['exact_raw']
    check("first-ever completion exactlyat officialstart credits valid newperiod points",'error' not in exact_result and exact_result.get('league_period_closed') is False and exact_result.get('league_points')==exact_result['total_points'] and exact_raw['membership']['weekly_points']==exact_result['total_points'],exact_result)
    check("exact-boundary completion stays recorded once with normal lifetime reward",exact_raw['sessions']==1 and exact_raw['profile']['minutes']==25 and exact_raw['profile']['points']==exact_result['total_points'])
    check("deterministic boundary transaction restores exact original grid function",original_grid==sql("select pg_get_functiondef('public._league_grid_start(timestamptz)'::regprocedure);"))
    qcheck("deterministic boundary fixture leaves no session or membership afterrollback",f"not exists(select 1 from public.study_sessions where user_id in ('{late}','{exact}')) and not exists(select 1 from public.league_memberships where user_id in ('{late}','{exact}'))")


def state_checks() -> None:
    config("league_launch_min_active_users",1000000)
    reset_fixtures()
    sql("update public.league_competition_state set start_at=null,initialized=false,period_started_at=null;")
    prep_room=make_room(2,"now()-interval '1 hour'")
    prep=[]
    for i in range(10):
        u,c=make_user(f"prep-{i}",2);prep.append(u)
        member(prep_room,u,1000-i,"now()-interval '14 days'")
        history(u,c)
    sql(f"update public.league_memberships set carry_points=13 where user_id='{prep[0]}';")
    prep_before=invariant_snapshot()
    sql("select public.process_weekly_leagues();")
    check("preparation maintenance preserves all lifetime totals, sessions and avatar ownership",prep_before==invariant_snapshot())
    qcheck("preparation neither promotes nor demotes",f"(select bool_and(league_tier=2) from public.profiles where id=any(array{prep}::uuid[]))")
    qcheck("preparation grants no podium avatar",f"not exists(select 1 from public.avatar_unlocks where user_id=any(array{prep}::uuid[]) and unlock_type='league_award')")
    qcheck("expired preparation rooms roll forward without losing carry",f"(select weekly_points+carry_points=1013 from public.league_memberships where user_id='{prep[0]}') and (select l.end_date>now() from public.league_memberships m join public.leagues l on l.id=m.league_id where m.user_id='{prep[0]}')")
    own=auth(prep[0],"select public.get_my_league_ranking_v2();")
    rows=json.loads(own)
    check("preparation v2 flags all promotion/award/demotion false",all(not r['promotion_eligible'] and not r['award_eligible'] and not r['demotion_eligible'] for r in rows),rows)
    check("authenticated user cannot read private launch snapshot",bool(role_error(prep[0],"select * from public.league_competition_state")))
    qcheck("all internal league helpers deny all API execution roles","not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join (values ('anon'),('authenticated'),('service_role')) roles(name) where n.nspname='public' and p.proname like '\\_league\\_%' escape '\\' and has_function_privilege(roles.name,p.oid,'EXECUTE'))")
    qcheck("safe public launch response contains no rollback/private snapshot","not public.get_league_config() ? 'rollback_snapshot' and not public.get_app_config() ? 'rollback_snapshot'")

    # Distinct recent completed owners, not membership/sign-up/lifetime score.
    reset_fixtures()
    sql("update public.league_competition_state set start_at=null,initialized=false,period_started_at=null;")
    config("league_launch_min_active_users",25)
    active=[]
    for i in range(24):
        u,c=make_user(f"launch-{i}");active.append((u,c));history(u,c,days=1,sessions_per_day=1)
    history(*active[0],days=1,sessions_per_day=1)
    stale,stale_cat=make_user("stale")
    history(stale,stale_cat,days=1,sessions_per_day=1,end="now()-interval '30 days'")
    future,future_cat=make_user("future")
    history(future,future_cat,days=1,sessions_per_day=1,end="now()+interval '3 days'")
    qcheck("24 distinct active users plus duplicate/stale/future rows do not schedule launch","(select start_at is null from public.league_competition_state)")
    zero,zero_cat=make_user("zero-points")
    history(zero,zero_cat,days=1,sessions_per_day=1,points=0)
    qcheck("25th completed-session owner with zero points schedules launch","(select start_at is not null and start_at>now() and not initialized from public.league_competition_state)")
    launch=sql("select start_at from public.league_competition_state;")
    qcheck("launch is next full14-day Monday00:00TR grid boundary","(select start_at=greatest(timestamptz '2026-10-12 00:00:00 Europe/Istanbul',public._league_grid_start(now())+interval '14 days') from public.league_competition_state)")
    sql("select public._league_refresh_start();select public.process_weekly_leagues();")
    check("repeated refresh/maintenance keeps scheduled start unchanged",launch==sql("select start_at from public.league_competition_state;"))
    config("league_launch_min_active_users",1000000)

    # A delayed first launch initializes from accepted current-period sessions,
    # never from historic preparation weekly points/carry amounts.
    reset_fixtures()
    sql("update public.league_competition_state set start_at=public._league_grid_start(now()),initialized=false,period_started_at=null;")
    current_room=make_room(2,"public._league_grid_start(now())+interval '14 days'-interval '1 microsecond'","public._league_grid_start(now())")
    u,c=make_user("first-official",2)
    member(current_room,u,9000,"public._league_grid_start(now())-interval '14 days'")
    history(u,c,days=1,sessions_per_day=1,points=18)
    sql(f"update public.league_memberships set carry_points=777 where user_id='{u}';")
    before_launch=invariant_snapshot()
    sql("select public.process_weekly_leagues();")
    check("first official initialization preserves histories and lifetime stats",before_launch==invariant_snapshot())
    qcheck("first official period drops preparation totals but keeps new session score",f"(select weekly_points=18 and carry_points=0 and period_started_at=public._league_grid_start(now())-interval '1 microsecond' from public.league_memberships where user_id='{u}')")
    qcheck("initializing current period does not retroactively promote",f"(select league_tier=2 from public.profiles where id='{u}')")
    before_again=sql("select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m;")
    sql("select public.process_weekly_leagues();")
    check("repeated official maintenance is idempotent",before_again==sql("select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m;"))
    qualification_checks()


def qualification_checks() -> None:
    reset_fixtures()
    # One official completed period directly precedes the current grid period.
    start="public._league_grid_start(now())-interval '14 days'"
    end="public._league_grid_start(now())"
    sql(f"update public.league_competition_state set start_at={start},initialized=true,period_started_at={start};")
    groups={}
    for tag,count,tier in [('three',3,2),('two',2,2),('days-short',3,2),('minutes-short',3,2),('podium',10,3),('unqualified-first',10,4),('diamond',10,5),('bronze',10,1)]:
        room=make_room(tier,f"{end}-interval '1 microsecond'",start)
        people=[]
        for i in range(count):
            u,c=make_user(f"{tag}-{i}",tier);people.append(u)
            member(room,u,9000-i,start)
            kwargs={'days':3,'sessions_per_day':2,'points':100-i,'end':f"{end}-interval '1 hour'"}
            if tag=='days-short' and i==0:kwargs.update(days=2,sessions_per_day=3)
            if tag=='minutes-short' and i==0:kwargs.update(days=3,sessions_per_day=1,points=300)
            if tag=='unqualified-first' and i==0:kwargs.update(days=1,sessions_per_day=1,points=3000)
            if tag in ('podium','unqualified-first','diamond','bronze') and i>=3:kwargs.update(days=1,sessions_per_day=1)
            history(u,c,**kwargs)
        if tag=='three':
            # Signed-up members do not inflate promotion quota or unlock
            # avatars. Only the three accepted-session owners are active.
            for i in range(20):
                idle,_=make_user(f"three-inactive-{i}",tier)
                member(room,idle,0,start)
        groups[tag]=people
    # Existing first-place reward survives and cannot be duplicated.
    sql(f"insert into public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent) values('{groups['podium'][0]}','league_gold_monthly','league_award',0) on conflict do nothing;")
    before=invariant_snapshot()
    sql("select public.process_weekly_leagues();")
    after=invariant_snapshot()
    check("rollover preserves all profiles' lifetime/coins/streak values and all sessions",before['profiles']==after['profiles'] and before['sessions']==after['sessions'])
    old_avatar={json.dumps(v,sort_keys=True) for v in before['avatars']}
    new_avatar={json.dumps(v,sort_keys=True) for v in after['avatars']}
    check("rollover never removes existing avatar ownership",old_avatar.issubset(new_avatar))
    qcheck("three active competitors promote only one qualified highest scorer",f"(select league_tier=3 from public.profiles where id='{groups['three'][0]}') and (select bool_and(league_tier=2) from public.profiles where id=any(array{groups['three'][1:]}::uuid[]))")
    qcheck("two active competitors cannot promote or demote",f"(select bool_and(league_tier=2) from public.profiles where id=any(array{groups['two']}::uuid[]))")
    qcheck("300minutes but only2study days cannot promote",f"(select league_tier=2 from public.profiles where id='{groups['days-short'][0]}')")
    qcheck("3study days but only150minutes cannot promote",f"(select league_tier=2 from public.profiles where id='{groups['minutes-short'][0]}')")
    qcheck("rooms with3active competitors do not give avatars",f"not exists(select 1 from public.avatar_unlocks where user_id=any(array{groups['three']}::uuid[]) and unlock_type='league_award')")
    qcheck("10active competitors give qualified top3 Gold rewards",f"(select count(*)=3 from public.avatar_unlocks where user_id=any(array{groups['podium'][:3]}::uuid[]) and avatar_id in ('league_gold_monthly','league_gold_weekly') and unlock_type='league_award')")
    qcheck("existing champion reward remains exactly one row",f"(select count(*)=1 from public.avatar_unlocks where user_id='{groups['podium'][0]}' and avatar_id='league_gold_monthly')")
    qcheck("unqualified first place receives no champion avatar",f"not exists(select 1 from public.avatar_unlocks where user_id='{groups['unqualified-first'][0]}' and unlock_type='league_award')")
    qcheck("qualified second/third receive correct podium avatar without replacing unqualified first",f"(select count(*)=2 from public.avatar_unlocks where user_id=any(array{groups['unqualified-first'][1:3]}::uuid[]) and avatar_id='league_sapphire_weekly')")
    qcheck("Diamond top3 cannot promote above tier5",f"(select bool_and(league_tier=5) from public.profiles where id=any(array{groups['diamond'][:3]}::uuid[]))")
    qcheck("Bronze bottom3 cannot demote below tier1",f"(select bool_and(league_tier=1) from public.profiles where id=any(array{groups['bronze'][-3:]}::uuid[]))")
    qcheck("all active users processed once and have one active membership after simultaneous room rollover","not exists(select m.user_id from public.league_memberships m join public.leagues l on l.id=m.league_id where l.is_active group by m.user_id having count(*)<>1)")
    qcheck("same-tier destination rooms consolidated to max25 after rollover","not exists(select m.league_id from public.league_memberships m join public.leagues l on l.id=m.league_id where l.is_active group by m.league_id having count(*)>25)")
    qcheck("newperiod starts from zero when no newperiod sessions exist","(select bool_and(weekly_points=0 and carry_points=0 and period_started_at=public._league_grid_start(now())-interval '1 microsecond') from public.league_memberships m join public.leagues l on l.id=m.league_id where l.is_active)")
    before_repeat=sql("select jsonb_build_object('p',(select jsonb_agg(to_jsonb(p) order by id) from public.profiles p),'m',(select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m),'a',(select jsonb_agg(to_jsonb(a) order by id) from public.avatar_unlocks a));")
    sql("select public.process_weekly_leagues();")
    check("second rollover call duplicates no membership/tier/award",before_repeat==sql("select jsonb_build_object('p',(select jsonb_agg(to_jsonb(p) order by id) from public.profiles p),'m',(select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m),'a',(select jsonb_agg(to_jsonb(a) order by id) from public.avatar_unlocks a));"))
    current_ranking_checks()
    carry_checks()


def current_ranking_checks() -> None:
    reset_fixtures()
    start="public._league_grid_start(now())"
    end=f"{start}+interval '336 hours'"
    sql(f"update public.league_competition_state set start_at={start},initialized=true,period_started_at={start};")
    room=make_room(2,f"{end}-interval '1 microsecond'",start)
    users=[]
    for i in range(3):
        u,c=make_user(f"current-active-{i}",2);users.append((u,c))
        member(room,u,0,f"{start}-interval '1 microsecond'")
        history(u,c,points=100-i)
    for i in range(20):
        u,_=make_user(f"current-inactive-{i}",2)
        member(room,u,0,f"{start}-interval '1 microsecond'")
    rows=json.loads(auth(users[0][0],"select public.get_my_league_ranking_v2();"))
    check("v2 ranking counts3active competitors among23members",len(rows)==23 and all(r['active_member_count']==3 and r['member_count']==23 for r in rows))
    check("v2 promotion quota uses active_count/3, not member_count/3",all(r['promotion_zone_end']==1 for r in rows) and sum(bool(r['promotion_eligible']) for r in rows)==1,rows[:3])
    check("23members but3active cannot unlock podium or demotion",all(not r['award_eligible'] and not r['demotion_eligible'] for r in rows))
    sql(f"insert into public.user_blocks(blocker_id,blocked_id) values('{users[0][0]}','{users[1][0]}');")
    blocked_rows=json.loads(auth(users[0][0],"select public.get_my_league_ranking_v2();"))
    hidden=next(r for r in blocked_rows if r['id']==users[1][0])
    check("blocked peer loses name/avatar in new v2 ranking",hidden['is_blocked'] and hidden['name'] is None and hidden['avatar_id'] is None,hidden)
    old=json.loads(auth(users[0][0],"select jsonb_agg(to_jsonb(r)) from public.get_my_league_ranking() r;"))
    hidden_old=next(r for r in old if r['id']==users[1][0])
    check("legacy ranking wrapper retains block masking",hidden_old['is_blocked'] and hidden_old['name'] is None and hidden_old['avatar_id'] is None)
    check("legacy RPC column shape remains compatible",set(old[0])=={'name','avatar_id','weekly_points','tier','end_date','is_me','promotion_zone_end','demotion_zone_start','member_count','id','is_blocked'})
    before=sql("select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m;")
    sql("select public.process_weekly_leagues();")
    check("active midperiod maintenance does not shuffle opponents or change points",before==sql("select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m;"))
    anon_error=sql("begin;set local role anon;select public.get_my_league_ranking_v2();rollback;",expect_failure=True)
    check("anonymous user cannot call new private ranking RPC",bool(anon_error))
    # Different server/session time zones cannot shift the global absolute
    # boundary or turn a14-day period into335/337hours over DST.
    grid_utc=sql("set timezone='UTC';select public._league_grid_start(now());")
    grid_ny=sql("set timezone='America/New_York';select public._league_grid_start(now()) at time zone 'UTC';")
    check("global grid boundary is independent of SQL session timezone",grid_utc.split('+')[0]==grid_ny)
    qcheck("global period is exactly336hours across DST","extract(epoch from (public._league_grid_start(now())+interval '336 hours'-public._league_grid_start(now())))=1209600")
    boundary,boundary_cat=make_user("exact-period-boundary",2)
    sql(f"""insert into public.study_sessions(user_id,category,category_id,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at,start_verified)
      values ('{boundary}','Review','{boundary_cat}',25,12,0,false,1,gen_random_uuid(),{start}-interval '25 minutes', {start},true),
             ('{boundary}','Review','{boundary_cat}',25,12,0,false,1,gen_random_uuid(),{start}-interval '25 minutes 1 microsecond', {start}-interval '1 microsecond',true);""")
    qcheck("period activity includes exact-start completion and excludes prior microsecond",f"(select focus_minutes=25 and points=12 from public._league_period_activity({start},{end}) where user_id='{boundary}')")
    studyday,studyday_cat=make_user("study-day-boundary",2)
    # Local03:59 and04:00 on the same calendar date belong to two different
    # 04:00 study days. Qualification must use started_at, not completed_at.
    sql(f"""insert into public.study_sessions(user_id,category,category_id,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at,start_verified)
      select '{studyday}','Review','{studyday_cat}',25,12,0,false,1,gen_random_uuid(),
        ((({start} at time zone 'Europe/Istanbul')::date+interval '2 days'+x) at time zone 'Europe/Istanbul'),
        ((({start} at time zone 'Europe/Istanbul')::date+interval '2 days'+x) at time zone 'Europe/Istanbul')+interval '25 minutes',true
      from unnest(array[interval '3 hours 59 minutes',interval '4 hours']) x;""")
    qcheck("personal study-day qualification uses local04:00 and session started_at",f"(select focus_minutes=50 and study_days=2 from public._league_period_activity({start},{end}) where user_id='{studyday}')")


def carry_checks() -> None:
    reset_fixtures()
    start="public._league_grid_start(now())-interval '14 days'"
    sql(f"update public.league_competition_state set start_at={start},initialized=true,period_started_at={start};")
    # Simulate a missed real global rollover, not an arbitrary room end that
    # conflicts with the new globally aligned period state. Both current-day
    # accepted sessions belong to the new period and must survive old closure.
    room=make_room(2,"public._league_grid_start(now())-interval '1 microsecond'",start)
    u,c=make_user("late-marathon",2)
    member(room,u,0,f"{start}-interval '1 microsecond'")
    marathon,client1,client2=uid(),uid(),uid()
    first=json.loads(auth(u,f"select public.complete_marathon_study_session('{client1}','{c}',50,false,0,now()-interval '110 minutes','{marathon}',2,1);"))
    check("first late-Marathon session accepted",'error' not in first,first)
    sql(f"update public.marathon_presence_gates set confirmed_at=now()-interval '50 minutes',next_client_uuid='{client2}',break_started_at=now()-interval '60 minutes',break_ends_at=now()-interval '55 minutes',confirmation_deadline=now()-interval '49 minutes' where user_id='{u}' and marathon_uuid='{marathon}';")
    second=json.loads(auth(u,f"select public.complete_marathon_study_session('{client2}','{c}',50,false,0,now()-interval '50 minutes','{marathon}',2,2);"))
    check("second late-Marathon session accepted with4bonus in carry",'error' not in second and second.get('marathon_bonus_points')==4 and second.get('league_points_next_period') is True,second)
    qcheck("carry has exactly both normal scores plus Maraton bonus",f"(select carry_points={first.get('league_points',-1) + second.get('league_points',-1)} from public.league_memberships where user_id='{u}')")
    expected=sql(f"select sum(base_points+bonus_points) from public.study_sessions where user_id='{u}';")
    totals=invariant_snapshot()
    sql("select public.process_weekly_leagues();")
    check("delayed room maintenance preserves lifetime/session/avatar values",totals==invariant_snapshot())
    qcheck("delayed maintenance reconstructs both current-period sessions and bonus exactly once",f"(select weekly_points={expected} and carry_points=0 from public.league_memberships where user_id='{u}')")
    duplicate=json.loads(auth(u,f"select public.complete_marathon_study_session('{client2}','{c}',50,false,0,now()-interval '50 minutes','{marathon}',2,2);"))
    check("duplicate Maraton completion remains idempotent",duplicate.get('duplicate') is True)
    qcheck("duplicate did not double points/sessions",f"(select count(*)=2 and sum(base_points+bonus_points)={expected} from public.study_sessions where user_id='{u}') and (select weekly_points={expected} and carry_points=0 from public.league_memberships where user_id='{u}')")


def cron_smoke() -> None:
    """Real pg_cron dispatch; app-data callback is strictly the isolated DB.

    The main local postgres DB hosts pg_cron itself. Root explicitly authorized
    this temporary job metadata operation; its callback never targets main.
    No existing jobs are changed. Evidence retains the QA execution details.
    """
    main_pg="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
    def main_sql(body):
        proc=subprocess.run(["psql",main_pg,"-X","-qAt","-v","ON_ERROR_STOP=1"],input=body,text=True,capture_output=True)
        if proc.returncode:raise RuntimeError(proc.stderr.strip())
        return proc.stdout.strip()
    jobname="pomosprint_league_policy_qa_once"
    # Refuse to overwrite somebody else's existing same-name job.
    if main_sql(f"select count(*) from cron.job where jobname='{jobname}';")!='0':
        check("real cron smoke reserved job name unused",False)
        return
    original_jobs=main_sql("select jsonb_agg(to_jsonb(j) order by jobid) from cron.job j;")
    main_hash_sql="""select jsonb_build_object(
      'p',(select md5(coalesce(string_agg(to_jsonb(p)::text,'' order by id),'')) from public.profiles p),
      's',(select md5(coalesce(string_agg(to_jsonb(s)::text,'' order by id),'')) from public.study_sessions s),
      'm',(select md5(coalesce(string_agg(to_jsonb(m)::text,'' order by id),'')) from public.league_memberships m),
      'l',(select md5(coalesce(string_agg(to_jsonb(l)::text,'' order by id),'')) from public.leagues l),
      'a',(select md5(coalesce(string_agg(to_jsonb(a)::text,'' order by id),'')) from public.avatar_unlocks a)
    );"""
    main_before=main_sql(main_hash_sql)
    review_sql="""select jsonb_build_object(
      'profiles',(select jsonb_agg(to_jsonb(p) order by id) from public.profiles p),
      'memberships',(select jsonb_agg(to_jsonb(m) order by id) from public.league_memberships m),
      'leagues',(select jsonb_agg(to_jsonb(l) order by id) from public.leagues l),
      'state',(select to_jsonb(s) from public.league_competition_state s),
      'sessions',(select jsonb_agg(to_jsonb(s) order by id) from public.study_sessions s),
      'avatars',(select jsonb_agg(to_jsonb(a) order by id) from public.avatar_unlocks a));"""
    review_before=sql(review_sql)
    jobid=None
    try:
        # Omit username: pg_cron only lets superusers explicitly supply that
        # argument, even when the requested name equals the current role.
        # The default resolves to the current postgres role and review DB.
        jobid=int(main_sql(f"select cron.schedule_in_database('{jobname}','* * * * *','select public.process_weekly_leagues();','{DB}');"))
        deadline=time.monotonic()+60
        run=None
        while time.monotonic()<deadline:
            row=main_sql(f"select to_jsonb(r) from cron.job_run_details r where jobid={jobid} and end_time is not null order by start_time desc limit 1;")
            if row:
                run=json.loads(row);break
            time.sleep(1)
        check("real pg_cron dispatch executed review DB callback successfully",run is not None and run['status']=='succeeded',run or {'timeout_seconds':60})
        check("real cron callback leaves idempotent review state unchanged",review_before==sql(review_sql))
        main_after=main_sql(main_hash_sql)
        (EVIDENCE/"independent_cron.json").write_text(json.dumps({'database':DB,'job_name':jobname,'job_id':jobid,'run':run,'main_appdata_unchanged':main_before==main_after,'main_appdata_before':json.loads(main_before),'main_appdata_after':json.loads(main_after)},ensure_ascii=False,indent=2)+'\n')
    finally:
        if jobid is not None:
            main_sql(f"select cron.unschedule({jobid});")
        check("temporary real cron job removed and all original jobs unchanged",original_jobs==main_sql("select jsonb_agg(to_jsonb(j) order by jobid) from cron.job j;"))
        check("real cron smoke did not mutate main local app data",main_before==main_sql(main_hash_sql))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        check("harness completion", False, str(exc))
    finally:
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "independent_results.json").write_text(json.dumps({
            "database": DB, "live_writes": False,
            "migration_sha256": APPLIED_MIGRATION_SHA,
            "passed": sum(r["ok"] for r in RESULTS), "total": len(RESULTS),
            "checks": RESULTS,
        }, ensure_ascii=False, indent=2) + "\n")
    raise SystemExit(0 if RESULTS and all(r["ok"] for r in RESULTS) else 1)
