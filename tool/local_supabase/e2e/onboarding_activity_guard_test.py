#!/usr/bin/env python3
"""Exercise onboarding gate on an empty synthetic schema clone, never production."""
import json
import subprocess
import uuid
from pathlib import Path

CONTAINER = 'supabase_db_pomosprint-local'
SOURCE = 'pomosprint_review32_kpss'
DEST = 'pomosprint_age_activity_20261106'
ROOT = Path(__file__).resolve().parents[3]

def run(args, body=None, expect_ok=True):
    result = subprocess.run(args, input=body, text=True, capture_output=True, timeout=120)
    if (result.returncode == 0) != expect_ok:
        raise RuntimeError(f'{args[0]} unexpected exit: {result.stderr[-1200:]}')
    return result.stdout if expect_ok else result.stderr

def sql(db, body, expect_ok=True):
    return run(['docker','exec','-i',CONTAINER,'psql','-U','supabase_admin',
                '-d',db,'-XqAt','-v','ON_ERROR_STOP=1'], body, expect_ok)

def safe_sql(path):
    lines = (ROOT / path).read_text().splitlines()
    assert lines[1].startswith('\\echo') and lines[2] == '\\quit'
    return '\n'.join(lines[3:]) + '\n'

def expect_error(statement, code):
    error = sql(DEST, statement, False)
    assert code in error, error

context = run(['docker','context','show']).strip()
endpoint = run(['docker','context','inspect',context,'--format','{{.Endpoints.docker.Host}}']).strip()
assert endpoint.startswith('unix://'), 'Only local Docker is allowed'
label = run(['docker','inspect','--format','{{ index .Config.Labels "com.supabase.cli.project" }}',CONTAINER]).strip()
assert label == 'pomosprint-local'
assert sql('postgres',"SELECT count(*) FROM pg_database WHERE datname='"+DEST+"'").strip() == '0'
assert sql(SOURCE,"SELECT count(*) FROM auth.users WHERE email !~ '^(review32-|e2e-sim-|qa-|site-demo-)[a-zA-Z0-9._+-]+@pomosprint[.]local$'").strip() == '0'
assert sql(SOURCE,"SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='20261028050000'").strip() == '0'
schema = run(['docker','exec',CONTAINER,'pg_dump','-U','postgres','-d',SOURCE,'--schema-only',
              '--schema=public','--schema=auth','--schema=ops','--schema=supabase_migrations',
              '--schema=cron','--schema=extensions'])
schema = '\n'.join(x for x in schema.splitlines() if x not in {'CREATE SCHEMA public;','CREATE SCHEMA extensions;'})+'\n'
tables = ['public.avatars','public.app_config','public.exam_catalog','public.competition_policy',
          'public.competition_avatar_rewards','public.marathon_presence_settings',
          'public.league_competition_state','public.exam_extension_policy','supabase_migrations.schema_migrations']
seed = run(['docker','exec',CONTAINER,'pg_dump','-U','postgres','-d',SOURCE,'--data-only']+
           ['--table='+table for table in tables])
sql('postgres','CREATE DATABASE '+DEST+' OWNER postgres')
try:
    sql(DEST,'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
    sql(DEST,schema)
    sql(DEST,seed)
    sql(DEST,'ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_confirmed_newsletter')
    assert sql(DEST,'SELECT count(*) FROM auth.users').strip() == '0'
    ids = {key:str(uuid.uuid4()) for key in ('incomplete','adult','legacy','underage','pending_retry')}
    for label,uid in ids.items():
        sql(DEST, f"INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data,created_at) VALUES('{uid}','qa-{uid}@pomosprint.local','authenticated','authenticated',jsonb_build_object('name','QA'),now())")
    def auth(uid, body):
        claims=json.dumps({'sub':uid,'role':'authenticated'})
        return f"BEGIN; SET LOCAL request.jwt.claims='{claims}'; SET LOCAL ROLE authenticated; {body}; COMMIT;"
    old_session,old_exam=str(uuid.uuid4()),str(uuid.uuid4())
    sql(DEST,auth(ids['pending_retry'],f"SELECT public.register_session_start('{old_session}',25)"))
    sql(DEST,auth(ids['pending_retry'],f"SELECT public.start_exam_attempt('{old_exam}','tyt')"))
    # Preserve an older completed profile with null birth_year before 35.
    sql(DEST,f"UPDATE public.profiles SET onboarding_completed_at=now() WHERE id='{ids['legacy']}'")
    sql(DEST,(ROOT/'supabase/tests/20261106_onboarding_age_35_APPLY_SQL_EDITOR.sql').read_text())
    expect_error(f"UPDATE public.profiles SET onboarding_completed_at=now() WHERE id='{ids['incomplete']}'",'birth_year_required')
    expect_error(f"UPDATE public.profiles SET birth_year=extract(year from current_date)::int-12, onboarding_completed_at=now() WHERE id='{ids['underage']}'",'minimum_age')
    sql(DEST,f"UPDATE public.profiles SET birth_year=1990,onboarding_completed_at=now() WHERE id='{ids['adult']}'")
    install=safe_sql('supabase/proposed/20261106_onboarding_activity_guard_REVIEW_ONLY.sql')
    sql(DEST,'ALTER TABLE public.profiles DISABLE TRIGGER enforce_minimum_age')
    expect_error(install,'onboarding_activity_guard_baseline_changed')
    sql(DEST,'ALTER TABLE public.profiles ENABLE TRIGGER enforce_minimum_age')
    dryrun=safe_sql('supabase/proposed/20261106_onboarding_activity_guard_DRYRUN_REVIEW_ONLY.sql')
    assert dryrun == install.replace('COMMIT;','ROLLBACK;')
    sql(DEST,dryrun)
    assert sql(DEST,"SELECT to_regprocedure('public._onboarding_activity_guard()') IS NULL").strip()=='t'
    sql(DEST,install)
    print('Guard function md5:',sql(DEST,"SELECT md5(pg_get_functiondef('public._onboarding_activity_guard()'::regprocedure))").strip())
    pending=ids['incomplete']
    expect_error(auth(pending,f"SELECT public.register_session_start('{uuid.uuid4()}',25)"),'onboarding_required')
    expect_error(auth(pending,f"SELECT public.start_exam_attempt('{uuid.uuid4()}','tyt')"),'onboarding_required')
    expect_error(f"INSERT INTO public.study_sessions(user_id,category,duration_minutes) VALUES('{pending}','QA',25)",'onboarding_required')
    category=str(uuid.uuid4())
    sql(DEST,f"INSERT INTO public.categories(id,user_id,name,color_hex) VALUES('{category}','{pending}','QA','#FF0000')")
    before=sql(DEST,f"SELECT jsonb_build_object('points',lifetime_points,'coins',coins) FROM public.profiles WHERE id='{pending}'").strip()
    expect_error(auth(pending,f"SELECT public.complete_study_session('{uuid.uuid4()}','{category}',25,false,0,now()-interval '30 minutes')"),'onboarding_required')
    after=sql(DEST,f"SELECT jsonb_build_object('points',lifetime_points,'coins',coins) FROM public.profiles WHERE id='{pending}'").strip()
    assert before==after, 'rejected call must not change rewards'
    assert sql(DEST,f"SELECT count(*) FROM public.session_starts WHERE user_id='{pending}'").strip()=='0'
    assert sql(DEST,f"SELECT count(*) FROM public.exam_attempts WHERE user_id='{pending}'").strip()=='0'
    sql(DEST,f"UPDATE public.profiles SET birth_year=1990 WHERE id='{pending}'")
    expect_error(auth(pending,f"SELECT public.register_session_start('{uuid.uuid4()}',25)"),'onboarding_required')
    assert '"created": false' in sql(DEST,auth(ids['pending_retry'],f"SELECT public.register_session_start('{old_session}',25)"))
    assert '"duplicate": true' in sql(DEST,auth(ids['pending_retry'],f"SELECT public.start_exam_attempt('{old_exam}','tyt')"))
    session=str(uuid.uuid4())
    result=sql(DEST,auth(ids['adult'],f"SELECT public.register_session_start('{session}',25)"))
    assert '"created": true' in result, result
    result=sql(DEST,auth(ids['adult'],f"SELECT public.register_session_start('{session}',25)"))
    assert '"created": false' in result, result
    result=sql(DEST,auth(ids['legacy'],f"SELECT public.start_exam_attempt('{uuid.uuid4()}','tyt')"))
    assert '"attempt"' in result, result
    sql(DEST,f"INSERT INTO public.study_sessions(user_id,category,duration_minutes,started_at) VALUES('{ids['adult']}','QA',25,now()-interval '25 minutes')")
    down=safe_sql('supabase/proposed/20261106_onboarding_activity_guard_DOWN_REVIEW_ONLY.sql')
    sql(DEST,'ALTER TABLE public.session_starts DISABLE TRIGGER onboarding_activity_guard')
    expect_error(down,'onboarding_activity_guard_down_baseline_changed')
    sql(DEST,'ALTER TABLE public.session_starts ENABLE TRIGGER onboarding_activity_guard')
    sql(DEST,down)
    assert sql(DEST,"SELECT to_regprocedure('public._onboarding_activity_guard()') IS NULL").strip()=='t'
    assert sql(DEST,f"SELECT count(*) FROM public.study_sessions WHERE user_id='{ids['adult']}'").strip()=='1'
    result=sql(DEST,auth(pending,f"SELECT public.register_session_start('{uuid.uuid4()}',25)"))
    assert '"created": true' in result
    print('PASS: local dryrun rollback, 35 age checks, incomplete starts/exams/study insert, completed and legacy access, duplicate session, reversible down')
finally:
    sql('postgres','DROP DATABASE '+DEST)
    print('Owned synthetic test database removed; production was not touched.')
