#!/usr/bin/env python3
"""Isolated Postgres-only exam pagination check; never connects to Supabase.

Requires local initdb/pg_ctl/createdb/psql. Creates and removes only a unique
TemporaryDirectory. Uses exact production migration tables/RPCs and stub Auth.
"""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
PROPOSED = ROOT / 'supabase' / 'proposed'
INSTALL = PROPOSED / '20261106_exam_history_keyset_REVIEW_ONLY.sql'
DRYRUN = PROPOSED / '20261106_exam_history_keyset_DRYRUN_REVIEW_ONLY.sql'
DOWN = PROPOSED / '20261106_exam_history_keyset_DOWN_REVIEW_ONLY.sql'

for tool in ('initdb', 'pg_ctl', 'createdb', 'psql'):
    if not shutil.which(tool):
        raise SystemExit(f'Missing local PostgreSQL executable: {tool}')


def run(args, *, input_text=None):
    p = subprocess.run(args, input=input_text, text=True, capture_output=True, check=False)
    if p.returncode:
        raise RuntimeError(f'{args[0]} failed: {p.stderr[-2000:]}')
    return p.stdout.strip()


def reviewed_source(path):
    text = path.read_text()
    if text.splitlines().count('\\quit') != 1:
        raise RuntimeError(f'Missing review-only safety marker: {path.name}')
    return '\n'.join(line for line in text.splitlines() if line != '\\quit') + '\n'


ATOMIC = (ROOT / 'supabase' / 'migrations' / '20261101210000_atomic_exam_release.sql').read_text()


def extract(start_marker, end_marker):
    start = ATOMIC.index(start_marker)
    end = ATOMIC.index(end_marker, start)
    return ATOMIC[start:end]


# Exact table, v32 payload and legacy RPC bodies from the reviewed atomic
# migration. Other Supabase schemas are deliberately replaced by a tiny auth
# shim, so this is a production-shaped subset, not a complete DB clone.
tables = extract('CREATE TABLE public.exam_catalog (', 'CREATE TABLE public.exam_wallets (')
alter = extract('ALTER TABLE public.exam_attempts\n ADD COLUMN title', '\n\nCREATE TABLE public.exam_extension_policy')
modules = extract('CREATE FUNCTION public._exam_ayt_modules32(', '\n\nUPDATE public.exam_catalog SET')
payload = extract('CREATE OR REPLACE FUNCTION public._exam_payload(', '\n\nCREATE OR REPLACE FUNCTION public.get_exam_config')
legacy = extract('CREATE FUNCTION public.get_my_exam_attempts(', '\nCREATE FUNCTION public.get_my_study_sessions_v2')
FIXTURE = """
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE TABLE public.profiles(id uuid primary key);
""" + tables + alter + '\n' + modules + '\n' + payload + '\n' + legacy + """
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_subject_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_attempts,public.exam_subject_results FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.exam_attempts,public.exam_subject_results TO authenticated;
CREATE POLICY exam_owner_read ON public.exam_attempts FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY exam_results_owner_read ON public.exam_subject_results FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.exam_attempts a WHERE a.id=attempt_id AND a.user_id=(SELECT auth.uid())));
REVOKE ALL ON FUNCTION public.get_my_exam_attempts(integer,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_exam_attempts(integer,timestamptz) TO authenticated;
INSERT INTO public.profiles VALUES ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
INSERT INTO public.exam_catalog(id,definition) VALUES ('tyt','{"id":"tyt","name_tr":"TYT","name_en":"TYT","catalog_version":1,"duration_seconds":9900,"total_questions":120,"wrong_answer_divisor":4,"subjects":[]}'::jsonb);
INSERT INTO public.exam_attempts(id,user_id,client_uuid,exam_id,definition,started_at,ends_at,finished_at,status,elapsed_seconds,points_earned,exam_coins_earned)
SELECT md5(i::text)::uuid,'00000000-0000-0000-0000-000000000001',md5(('c-'||i::text))::uuid,'tyt',definition,'2026-11-01 12:00:00+00','2026-11-01 14:45:00+00','2026-11-01 14:45:00+00','completed',9900,33,130 FROM generate_series(1,101) i CROSS JOIN public.exam_catalog WHERE id='tyt';
INSERT INTO public.exam_attempts(id,user_id,client_uuid,exam_id,definition,started_at,ends_at,finished_at,status,elapsed_seconds,points_earned,exam_coins_earned)
SELECT '00000000-0000-0000-0000-000000000099','00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000099','tyt',definition,'2026-11-02 12:00:00+00','2026-11-02 14:45:00+00','2026-11-02 14:45:00+00','completed',9900,33,130 FROM public.exam_catalog WHERE id='tyt';
INSERT INTO public.exam_attempts(id,user_id,client_uuid,exam_id,definition,started_at,ends_at,finished_at,status,elapsed_seconds,points_earned,exam_coins_earned)
SELECT md5(('unique-'||i::text))::uuid,'00000000-0000-0000-0000-000000000003',md5(('uc-'||i::text))::uuid,'tyt',definition,'2026-11-01 12:00:00+00'::timestamptz-(i||' minutes')::interval,'2026-11-01 14:45:00+00'::timestamptz-(i||' minutes')::interval,'2026-11-01 14:45:00+00'::timestamptz-(i||' minutes')::interval,'completed',9900,33,130 FROM generate_series(1,205) i CROSS JOIN public.exam_catalog WHERE id='tyt';
INSERT INTO public.exam_subject_results(attempt_id,subject_id,correct,wrong,blank,net)
SELECT id,'mathematics',29,7,4,27.25 FROM public.exam_attempts WHERE user_id='00000000-0000-0000-0000-000000000003' ORDER BY id LIMIT 1;
"""


# Cursor requests are deliberately made as the authenticated API role.
def page_query(function, owner):
    if function == 'v2':
        name = 'public.get_my_exam_attempts_v2'
        first = f'{name}(100)'
        follow = f"{name}(100,(p->'next_cursor'->>'started_at')::timestamptz,(p->'next_cursor'->>'id')::uuid)"
    else:
        name = 'public.get_my_exam_attempts'
        first = f'{name}(100)'
        follow = f"{name}(100,(p->>'next_cursor')::timestamptz)"
    return f'''SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','{owner}',false);
WITH RECURSIVE pages(p,n) AS (
 SELECT {first},1 UNION ALL SELECT {follow},n+1 FROM pages
 WHERE p->'next_cursor' IS NOT NULL AND p->'next_cursor'<>'null'::jsonb AND n<10
), ids AS (SELECT x->>'id' AS id,x::text AS payload FROM pages CROSS JOIN LATERAL jsonb_array_elements(p->'attempts') x)
SELECT count(*)||':'||count(DISTINCT id)||':'||coalesce(md5(string_agg(payload,',' ORDER BY id)),'') FROM ids;'''


with tempfile.TemporaryDirectory(prefix='pomosprint-history-pg-') as temp:
    root = Path(temp)
    data = root / 'data'
    socket = root / 'socket'
    socket.mkdir()
    run(['initdb', '-D', str(data), '-A', 'trust', '--no-locale', '--encoding=UTF8'])
    pg = ['pg_ctl', '-D', str(data)]
    run(pg + ['-l', str(root / 'postgres.log'), '-o', f"-h '' -p 56477 -k {socket}", '-w', 'start'])
    try:
        common = ['-h', str(socket), '-p', '56477']
        def sql(db, statement):
            return run(['psql', *common, '-d', db, '-X', '-q', '-t', '-A', '-v', 'ON_ERROR_STOP=1'], input_text=statement)
        sql('postgres', 'CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;')
        for db in ('pomo_old', 'pomo_new'):
            run(['createdb', *common, db])
            sql(db, FIXTURE)
        sql('pomo_new', reviewed_source(DRYRUN))
        assert sql('pomo_new', "SELECT to_regprocedure('public.get_my_exam_attempts_v2(integer,timestamptz,uuid)') IS NULL;") == 't'
        sql('pomo_new', reviewed_source(INSTALL))
        assert sql('pomo_new', "SELECT NOT has_function_privilege('anon','public.get_my_exam_attempts_v2(integer,timestamptz,uuid)','EXECUTE') AND has_function_privilege('authenticated','public.get_my_exam_attempts_v2(integer,timestamptz,uuid)','EXECUTE') AND NOT has_function_privilege('service_role','public.get_my_exam_attempts_v2(integer,timestamptz,uuid)','EXECUTE');") == 't'
        same = '00000000-0000-0000-0000-000000000001'
        other = '00000000-0000-0000-0000-000000000002'
        unique = '00000000-0000-0000-0000-000000000003'
        old_collision = sql('pomo_old', page_query('old', same)).splitlines()[-1]
        new_collision = sql('pomo_new', page_query('v2', same)).splitlines()[-1]
        old_unique = sql('pomo_old', page_query('old', unique)).splitlines()[-1]
        new_unique = sql('pomo_new', page_query('v2', unique)).splitlines()[-1]
        other_new = sql('pomo_new', page_query('v2', other)).splitlines()[-1]
        assert old_collision.startswith('100:100:')
        assert new_collision.startswith('101:101:')
        assert old_unique == new_unique and new_unique.startswith('205:205:')
        assert other_new.startswith('1:1:')
        sql('pomo_new', reviewed_source(DOWN))
        assert sql('pomo_new', "SELECT to_regprocedure('public.get_my_exam_attempts_v2(integer,timestamptz,uuid)') IS NULL AND to_regprocedure('public.get_my_exam_attempts(integer,timestamptz)') IS NOT NULL AND (SELECT count(*) FROM public.exam_attempts)=307;") == 't'
        print(json.dumps({'old_collision': old_collision.split(':')[:2], 'v2_collision': new_collision.split(':')[:2], 'unique_payloads_equal': True, 'other_owner_count': 1, 'dryrun_rolled_back': True, 'rollback_preserved_307_rows': True, 'scope': 'synthetic PostgreSQL schemas with exact migration table/RPC/payload bodies; not full Supabase'}))
    finally:
        run(pg + ['-m', 'fast', '-w', 'stop'])
