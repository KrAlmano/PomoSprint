#!/usr/bin/env python3
"""Reproduce the remaining onboarding age-gate gap via real local Supabase RPCs.

Copies only schema and fixed QA config/catalog from a local reviewed clone.
No users are copied; creates one @pomosprint.local owner, rolls RPCs back,
then drops only the newly created fixed-name DB. Never contacts production.
"""
import subprocess,uuid,json
from pathlib import Path
C='supabase_db_pomosprint-local'; source='pomosprint_review32_kpss'; dest='pomosprint_age_scope_20261106'
def run(args,body=None):
 p=subprocess.run(args,input=body,text=True,capture_output=True,timeout=120)
 if p.returncode:raise RuntimeError(args[0]+': '+p.stderr[-1200:])
 return p.stdout
psql=lambda db,sql:run(['docker','exec','-i',C,'psql','-U','supabase_admin','-d',db,'-XqAt','-v','ON_ERROR_STOP=1'],sql)
context=run(['docker','context','show']).strip()
endpoint=run(['docker','context','inspect',context,'--format','{{.Endpoints.docker.Host}}']).strip()
if not endpoint.startswith('unix://'):
 raise RuntimeError('Only a local unix Docker context is permitted')
label=run(['docker','inspect','--format','{{ index .Config.Labels "com.supabase.cli.project" }}',C]).strip()
if label!='pomosprint-local':
 raise RuntimeError('Refusing non-PomoSprint local database container')
assert psql('postgres',"SELECT count(*) FROM pg_database WHERE datname='"+dest+"'").strip()=='0'
assert psql(source,"SELECT count(*) FROM auth.users WHERE email !~ '^(review32-|e2e-sim-|qa-|site-demo-)[a-zA-Z0-9._+-]+@pomosprint[.]local$'").strip()=='0'
assert psql(source,"SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='20261028050000'").strip()=='0'
schema=run(['docker','exec',C,'pg_dump','-U','postgres','-d',source,'--schema-only','--schema=public','--schema=auth','--schema=ops','--schema=supabase_migrations','--schema=cron','--schema=extensions'])
schema='\n'.join(line for line in schema.splitlines() if line not in {'CREATE SCHEMA public;','CREATE SCHEMA extensions;'})+'\n'
tables=['public.avatars','public.app_config','public.exam_catalog','public.competition_policy','public.competition_avatar_rewards','public.marathon_presence_settings','public.league_competition_state','public.exam_extension_policy','supabase_migrations.schema_migrations']
seed=run(['docker','exec',C,'pg_dump','-U','postgres','-d',source,'--data-only']+['--table='+t for t in tables])
psql('postgres','create database '+dest+' owner postgres')
try:
 psql(dest,'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
 psql(dest,schema);psql(dest,seed)
 psql(dest,'alter table auth.users disable trigger on_auth_user_confirmed_newsletter')
 assert psql(dest,'select count(*) from auth.users').strip()=='0'
 psql(dest,Path('supabase/tests/20261106_onboarding_age_35_APPLY_SQL_EDITOR.sql').read_text())
 uid=str(uuid.uuid4()); cid=str(uuid.uuid4());eid=str(uuid.uuid4())
 psql(dest,f"insert into auth.users(id,email,aud,role,raw_user_meta_data,created_at) values('{uid}','qa-{uid}@pomosprint.local','authenticated','authenticated',jsonb_build_object('name','QA Scope'),now());")
 assert psql(dest,f"select birth_year is null and onboarding_completed_at is null from public.profiles where id='{uid}'").strip()=='t'
 claims=json.dumps({'sub':uid,'role':'authenticated'})
 auth=f"begin;set local request.jwt.claims='{claims}';set local role authenticated;"
 a=psql(dest,auth+f"select public.register_session_start('{cid}',25);rollback;")
 assert 'server_started_at' in a;print('CONFIRMED OPEN: age35 allows session start before completing onboarding')
 b=psql(dest,auth+f"select public.start_exam_attempt('{eid}','tyt');rollback;")
 assert 'attempt' in b;print('CONFIRMED OPEN: age35 allows practice-exam start before completing onboarding')
 print('Local clone only; 35 installed locally; production not touched.')
finally:
 psql('postgres','drop database '+dest)
 print('Owned synthetic QA clone removed.')
