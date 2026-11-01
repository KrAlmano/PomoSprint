#!/usr/bin/env python3
"""Generate review-only atomic SQL; never connects to any database.

The resulting files have a psql guard and must not be run on production until
independently reviewed.  The SQL bodies remain byte-for-byte identical to the
reviewed proposal files except for their outer transaction/psql wrappers.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROPOSED = ROOT / 'supabase/proposed'
PARTS = ['27_tus_segment', '28_exam_core', '29_monthly_competitions',
         '30_session_start_atomic', '32_exam_details_early_finish']
PREFIX = '20261101_atomic_exam_release_REVIEW_ONLY'


def body(name: str) -> str:
    text = (PROPOSED / name).read_text()
    lines = text.splitlines(keepends=True)
    assert sum(line.strip() == 'BEGIN;' for line in lines) == 1, name
    assert sum(line.strip() == 'COMMIT;' for line in lines) == 1, name
    assert sum(line.strip() == r'\quit' for line in lines) == 1, name
    return ''.join(line for line in lines if not (
        line.strip() in ('BEGIN;', 'COMMIT;', r'\quit') or
        line.lstrip().startswith(r'\echo ')))


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


hashes = {
    'get_league_config()': 'bbcb4673dfa311b076789764207e49b5',
    'get_my_league_ranking()': 'a6e5ec04783800080c36b03704c4e320',
    'get_league_ranking(uuid)': 'f90981ef879bcfbe3e456190c0929263',
    'process_weekly_leagues()': 'f6d02ce7217264dcf44e45056b8fd5b6',
    'get_my_league_ranking_v2()': '154eebf5aea8060d104b58d5208807b7',
    'get_live_friends_with_breaks()': '342b58cfe59ef5766d85ec66f4aee2ce',
    'start_study_session(integer,text)': '56a13ce596649189df480f5e39454f95',
    'ensure_user_in_league(uuid,integer)': '65faa90deaf3f8e988a801d1628aabce',
    'register_session_start(uuid,integer)': '9500c7c45503a3e5031e52c879b1dba2',
    'get_public_monthly_leaderboard(integer)': 'bc8655aa7e7189efdb4a42e60a90ae55',
    'league_award_avatar_id(integer,integer)': 'f6ed7f1c88a233f1a08bc67713b886e6',
    'complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)':
        '72023f3f4d8636363cf0231f42d4c7e1',
}
values = ',\n'.join(f'  ({literal("public." + k)}, {literal(v)})' for k, v in sorted(hashes.items()))
catalog = json.loads((PROPOSED / 'exam_catalog_32.json').read_text())['exams']
assert len(catalog) == 20
catalog_sql = literal(json.dumps(catalog, ensure_ascii=False, separators=(',', ':')))
lock = '''SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '120s';
-- NOWAIT: if an application transaction is using these tables, abort this
-- transaction instead of waiting while holding a subset of table locks.
LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE NOWAIT;
LOCK TABLE public.study_sessions, public.leagues, public.league_memberships,
  public.session_starts, public.avatar_unlocks IN SHARE ROW EXCLUSIVE MODE NOWAIT;
'''
month_guard = '''DO $$ DECLARE n timestamptz:=clock_timestamp(); start_month timestamptz;
BEGIN
 start_month := date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
 IF date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') <>
    date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') OR
    n < start_month + interval '5 minutes' OR
    n >= ((start_month AT TIME ZONE 'Europe/Istanbul' + interval '1 month') AT TIME ZONE 'Europe/Istanbul') - interval '5 minutes'
 THEN RAISE EXCEPTION 'release_month_boundary_unsafe'; END IF;
END $$;
'''
fingerprint = f'''DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT * FROM (VALUES
{values}
 ) AS expected(signature,digest) LOOP
  IF to_regprocedure(r.signature) IS NULL OR
     md5(pg_get_functiondef(to_regprocedure(r.signature))) IS DISTINCT FROM r.digest
  THEN RAISE EXCEPTION 'release_live_function_changed: %', r.signature; END IF;
 END LOOP;
END $$;
'''
snapshot_queries = {
    'profiles': 'public.profiles',
    'sessions': 'public.study_sessions',
    'leagues': 'public.leagues',
    'memberships': 'public.league_memberships',
    'starts': 'public.session_starts',
    'unlocks': 'public.avatar_unlocks',
}
snapshot_values = ',\n'.join(
    f" ({literal(key)}, (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM {table} t))"
    for key, table in snapshot_queries.items())
snapshot_check = ',\n'.join(
    f" ({literal('unchanged_' + key)}, (SELECT digest FROM release_before WHERE name={literal(key)}) = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM {table} t))"
    for key, table in snapshot_queries.items())
pre = f'''BEGIN;
{lock}{month_guard}{fingerprint}
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'release_requires_bypassrls'; END IF;
 IF (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job' AND active AND database=current_database() AND username=current_user AND schedule='1 21 * * 0' AND command='SELECT public.process_weekly_leagues()') <> 1
 OR (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job') <> 1
 THEN RAISE EXCEPTION 'release_legacy_cron_changed'; END IF;
 IF EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101210000')
 THEN RAISE EXCEPTION 'release_atomic_marker_exists'; END IF;
END $$;
CREATE TEMP TABLE release_cron_before(snapshot jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO release_cron_before SELECT to_jsonb(j) FROM cron.job j WHERE jobname='weekly_leagues_job';
CREATE TEMP TABLE release_before(name text PRIMARY KEY,digest text NOT NULL) ON COMMIT DROP;
INSERT INTO release_before VALUES
{snapshot_values};
'''
post = f'''{month_guard}
CREATE TEMP TABLE release_checks(name text PRIMARY KEY, passed boolean NOT NULL) ON COMMIT DROP;
INSERT INTO release_checks VALUES
{snapshot_check},
 ('twenty_exact_catalog_definitions',
  (SELECT count(*)=20 AND bool_and(enabled) FROM public.exam_catalog) AND
  (SELECT jsonb_object_agg(id,definition) FROM public.exam_catalog) =
  (SELECT jsonb_object_agg(value->>'id',value) FROM jsonb_array_elements({catalog_sql}::jsonb))),
 ('exam_available_and_details_enabled',
  coalesce((public.get_exam_config()->>'available')::boolean,false) AND
  coalesce((public.get_exam_config()->'capabilities'->>'exam_details')::boolean,false) AND
  coalesce((public.get_exam_config()->'capabilities'->>'ayt_early_finish')::boolean,false)),
 ('all_five_versions_and_no_31',
  (SELECT count(*)=5 FROM supabase_migrations.schema_migrations WHERE version IN
    ('20261028010000','20261028020000','20261028030000','20261028040000','20261028060000')) AND
  NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028050000')),
 ('next_month_activation',
  (SELECT activates_at=public._competition_month_time((public._competition_month(now())+interval '1 month')::date)
          AND NOT legacy_finalized FROM public.competition_policy WHERE singleton)),
 ('monthly_backfill_count',
  (SELECT count(*) FROM public.competition_events WHERE kind='study') =
  (SELECT count(*) FROM public.study_sessions WHERE completed_at>=public._competition_month_time(public._competition_month(now())))),
 ('new_cron_daily',
  (SELECT count(*)=1 AND bool_and(active AND schedule='1 21 * * *' AND command='SELECT public.process_weekly_leagues();' AND database=current_database() AND username=current_user) FROM cron.job WHERE jobname='weekly_leagues_job') AND
  (SELECT to_jsonb(j)-'schedule'-'command' FROM cron.job j WHERE jobname='weekly_leagues_job') =
  (SELECT snapshot-'schedule'-'command' FROM release_cron_before)),
 ('private_attempts_and_wallets',
  (SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.exam_attempts'::regclass,'public.exam_subject_results'::regclass,'public.exam_wallets'::regclass)) AND
  NOT has_table_privilege('authenticated','public.exam_attempts','INSERT,UPDATE,DELETE') AND
  NOT has_function_privilege('anon','public.finish_ayt_early(uuid)','EXECUTE')),
 ('no_existing_exam_data',NOT EXISTS(SELECT 1 FROM public.exam_attempts) AND NOT EXISTS(SELECT 1 FROM public.exam_wallets));
DO $$ DECLARE failures text; BEGIN
 SELECT string_agg(name, ', ' ORDER BY name) INTO failures FROM release_checks WHERE NOT passed;
 IF failures IS NOT NULL THEN RAISE EXCEPTION 'release_postconditions_failed: %',failures; END IF;
END $$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101210000','atomic_exam_release');
SELECT name,passed FROM release_checks ORDER BY name;
'''
header = '''-- REVIEW ONLY. DO NOT RUN ON PRODUCTION. Independent review and user action required.
-- Generated from 27,28,29,30,32; 31 is intentionally absent.
\\echo 'REVIEW ONLY: do not execute until independently reviewed.'
\\quit
'''
for part in PARTS:
    p = PROPOSED / f'{part}.sql'
    header += f'-- source {p.name} sha256 {hashlib.sha256(p.read_bytes()).hexdigest()}\n'
forward = ''.join(f'\n-- START {p}\n{body(p + ".sql")}-- END {p}\n' for p in PARTS)
down = ''.join(f'\n-- START {p} DOWN\n{body(p + "_down.sql")}-- END {p} DOWN\n' for p in reversed(PARTS))
rollback = f'''BEGIN;
{lock}{month_guard}
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'release_requires_bypassrls'; END IF;
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101210000' AND name='atomic_exam_release')
 THEN RAISE EXCEPTION 'release_marker_not_found'; END IF;
END $$;
CREATE TEMP TABLE release_down_cron_before(snapshot jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO release_down_cron_before
 SELECT value FROM public.competition_policy p CROSS JOIN LATERAL jsonb_array_elements(p.legacy_snapshot->'cron')
 WHERE value->>'jobname'='weekly_leagues_job';
DO $$ BEGIN
 IF (SELECT count(*) FROM release_down_cron_before)<>1 OR
    NOT EXISTS(SELECT 1 FROM release_down_cron_before WHERE snapshot->>'database'=current_database() AND snapshot->>'username'=current_user)
 THEN RAISE EXCEPTION 'release_legacy_cron_snapshot_invalid'; END IF;
END $$;
{down}
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101210000' AND name='atomic_exam_release';
{fingerprint}
DO $$ BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job')<>1 OR
    (SELECT to_jsonb(j) FROM cron.job j WHERE jobname='weekly_leagues_job') IS DISTINCT FROM
    (SELECT snapshot FROM release_down_cron_before)
 THEN RAISE EXCEPTION 'release_legacy_cron_restore_failed'; END IF;
END $$;
COMMIT;
'''
for filename, content in [
    (PREFIX + '_install.sql', header + pre + forward + post + 'COMMIT;\n'),
    (PREFIX + '_dryrun.sql', header + pre + forward + post + 'ROLLBACK;\n'),
    (PREFIX + '_down.sql', header + rollback),
]:
    (PROPOSED / filename).write_text(content)
    print(filename, hashlib.sha256(content.encode()).hexdigest())
