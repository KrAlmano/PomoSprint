#!/usr/bin/env python3
"""Guarded local-clone harness for proposal 32 (AYT early finish/details).

Default: print a plan, read local sources only, make no database connections.
--apply-tests: reserved for the finalized package after coordinated approval.
Only a NEW fixed review database may receive package/fixture writes.
--kpss selects a separate pomosprint_review32_kpss clone; existing DUS/site
databases are never changed by that run.
The source is read-only, existing databases are never replaced, and the clone
is retained on success or failure. No .env, native tool or schema 31 is used.

User-approved final policy: proportional elapsed-time coins, capped at the
frozen full reward. The obsolete reward-only /tmp package is
never an input. Controlled SQL timestamps are not natural-duration evidence.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import uuid
import threading
from concurrent.futures import ThreadPoolExecutor


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build' / 'isolated32_dus'
SOURCE_DB = 'pomosprint_overnight_baseline'
CLONE_DB = 'pomosprint_review32_dus'
CREATE_CLONE = f'CREATE DATABASE "{CLONE_DB}" WITH TEMPLATE "{SOURCE_DB}";'
HISTORICAL_AVATARS = (
    ROOT / 'supabase/migrations/20261009190000_special_avatar_catalog.sql',
    ROOT / 'supabase/migrations/20261009233000_remove_unowned_ronin.sql',
)
PREREQUISITES = HISTORICAL_AVATARS + tuple(ROOT / 'supabase' / 'proposed' / name for name in (
    '27_tus_segment.sql', '28_exam_core.sql', '29_monthly_competitions.sql',
    '30_session_start_atomic.sql',
))
FORBIDDEN_31 = '20261028050000'
EXPECTED_FULL_COINS = {
    'lgs_verbal': 60, 'lgs_quantitative': 70, 'ydt': 95,
    'tus_basic': 110, 'tus_clinical': 110, 'dus': 120, 'tyt': 130, 'ayt': 145,
}
EXPECTED_FULL_POINTS = {
    'lgs_verbal': 15, 'tyt': 33, 'ayt': 36,
    'ydt': 24, 'lgs_quantitative': 16, 'tus_basic': 27, 'tus_clinical': 27, 'dus': 30,
}
KPSS_GENERAL_IDS = ('kpss_bachelor_gygk', 'kpss_associate_gygk', 'kpss_secondary_gygk')
KPSS_FIELD_IDS = tuple('kpss_field_' + name for name in (
    'business', 'accounting', 'law', 'public_administration', 'economics',
    'finance', 'international_relations', 'labour_economics', 'statistics',
))
EXPECTED_FULL_COINS.update({key: 105 for key in KPSS_GENERAL_IDS})
EXPECTED_FULL_COINS.update({key: 50 if key.endswith('_statistics') else 40 for key in KPSS_FIELD_IDS})
EXPECTED_FULL_POINTS.update({key: 26 for key in KPSS_GENERAL_IDS})
EXPECTED_FULL_POINTS.update({key: 12 if key.endswith('_statistics') else 10 for key in KPSS_FIELD_IDS})


def select_target(kpss: bool = False) -> None:
    """Select one fixed, explicitly named clone; no arbitrary DB override."""
    global CLONE_DB, CREATE_CLONE, OUTPUT
    if type(kpss) is not bool:
        raise ValueError('Only the fixed KPSS target flag is accepted')
    CLONE_DB = 'pomosprint_review32_kpss' if kpss else 'pomosprint_review32_dus'
    OUTPUT = ROOT / 'build' / ('isolated32_kpss' if kpss else 'isolated32_dus')
    CREATE_CLONE = f'CREATE DATABASE "{CLONE_DB}" WITH TEMPLATE "{SOURCE_DB}";'
BASELINE_NONEMPTY = {
    'public.avatars', 'public.app_config', 'public.blocked_name_terms',
    'public.league_competition_state', 'public.marathon_presence_settings',
    'auth.schema_migrations', 'storage.migrations',
}
DATA_SCHEMAS = ('public', 'auth', 'storage', 'ops', 'net', 'supabase_migrations')
RPC_NAMES = {
    'complete_study_session', 'start_study_session', 'register_session_start',
    'start_exam_attempt', 'complete_exam_attempt', 'abandon_exam_attempt',
    'finish_ayt_early', 'save_exam_results', 'save_exam_details',
    'get_my_exam_attempts', 'get_exam_config', 'get_live_friends_with_breaks',
    'get_monthly_league_ranking', 'get_my_exam_league_ranking', 'set_competition_target', 'get_competition_target',
}


@dataclass(frozen=True)
class PackageSpec:
    forward: Path
    dryrun: Path
    down: Path
    migration: str
    # Deliberately no default: an unanswered currency policy is not a test oracle.
    early_coin_policy: str
    dryrun_check_count: int
    rollback_data_error: str


# Set only when the new SQL/API and all scenarios have been reviewed together.
# In particular, never point this at /tmp/proposed32_pkg (obsolete formula).
PACKAGE: PackageSpec | None = PackageSpec(
    forward=ROOT / 'supabase/proposed/32_exam_details_early_finish.sql',
    dryrun=ROOT / 'supabase/proposed/32_exam_details_early_finish_dryrun.sql',
    down=ROOT / 'supabase/proposed/32_exam_details_early_finish_down.sql',
    migration='20261028060000', early_coin_policy='proportional',
    dryrun_check_count=17, rollback_data_error='exam32_rollback_would_lose_data',
)
SCENARIOS_READY = True


def literal(value: object) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def identifier(value: str) -> str:
    parts = value.split('.')
    if len(parts) != 2 or any(not re.fullmatch(r'[a-zA-Z_][a-zA-Z0-9_]*', p) for p in parts):
        raise ValueError('Unexpected schema/table identifier')
    return '.'.join('"' + p + '"' for p in parts)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _unquoted_backslash(text: str) -> bool:
    """Detect psql commands even after SQL on a line, ignoring SQL literals."""
    i, block_depth = 0, 0
    quote = None
    dollar = None
    while i < len(text):
        if block_depth:
            if text.startswith('/*', i):
                block_depth += 1
                i += 2
            elif text.startswith('*/', i):
                block_depth -= 1
                i += 2
            else:
                i += 1
            continue
        if dollar:
            if text.startswith(dollar, i):
                i += len(dollar)
                dollar = None
            else:
                i += 1
            continue
        if quote:
            if text[i] == quote:
                if i + 1 < len(text) and text[i + 1] == quote:
                    i += 2
                else:
                    quote = None
                    i += 1
            elif quote == "'" and text[i] == '\\':
                # PostgreSQL E strings and the existing ESCAPE literals.
                # Do not skip a closing quote for a plain one-backslash literal.
                i += 1
            else:
                i += 1
            continue
        if text.startswith('--', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end + 1
        elif text.startswith('/*', i):
            block_depth = 1
            i += 2
        elif text[i] in "'\"":
            quote = text[i]
            i += 1
        elif text[i] == '$' and (match := re.match(r'\$(?:[a-zA-Z_][a-zA-Z0-9_]*)?\$', text[i:])):
            dollar = match.group(0)
            i += len(dollar)
        elif text[i] == '\\':
            return True
        else:
            i += 1
    return False


def strip_psql_guards(text: str) -> str:
    """Remove only leading echo/quit lines; never remove arbitrary commands."""
    lines = text.splitlines()
    start = 0
    while start < len(lines):
        stripped = lines[start].lstrip()
        if not stripped or stripped.startswith('--'):
            start += 1
        elif re.fullmatch(r'\\echo(?:\s+.*)?|\\quit\s*', stripped):
            lines[start] = ''
            start += 1
        else:
            break
    result = '\n'.join(lines)
    if _unquoted_backslash(result):
        raise ValueError('Unexpected psql meta-command; only leading echo/quit may be removed')
    if not re.search(r'^\s*BEGIN;\s*$', result, re.M):
        raise ValueError('Reviewed SQL must have an explicit transaction')
    return result


def transaction_body(text: str) -> str:
    start = re.search(r'^\s*BEGIN;\s*$', text, re.M)
    endings = list(re.finditer(r'^\s*(?:COMMIT|ROLLBACK);\s*$', text, re.M))
    if not start or not endings or endings[-1].start() <= start.end():
        raise ValueError('Unexpected transaction wrapper')
    end = endings[-1]
    if text[end.end():].strip():
        raise ValueError('Unexpected trailing SQL after transaction')
    return text[start.end():end.start()]


def source_paths(package: PackageSpec | None = PACKAGE) -> tuple[Path, ...]:
    return PREREQUISITES + (() if package is None else (package.forward, package.dryrun, package.down))


def plan(package: PackageSpec | None = PACKAGE) -> dict:
    sources = {}
    for path in source_paths(package):
        if path.is_file():
            strip_psql_guards(path.read_text())
            sources[str(path)] = sha256(path)
        else:
            sources[str(path)] = None
    return {
        'mode': 'plan_only_no_connections', 'endpoint': '127.0.0.1:54322',
        'source_database': SOURCE_DB, 'new_database': CLONE_DB,
        'clone_command': CREATE_CLONE, 'retention': 'keep clone and evidence; never drop/replace',
        'ready': package is not None and package.early_coin_policy != 'pending' and SCENARIOS_READY and all(sources.values()),
        'pending': ([] if package is not None else ['finalized new32 SQL paths and early-coin policy'])
                   + ([] if SCENARIOS_READY else ['reviewed new32 scenario implementation'])
                   + (['user decision on early coins'] if package is not None and package.early_coin_policy == 'pending' else []),
        'sources_sha256': sources,
        'full_coins': EXPECTED_FULL_COINS,
        'early_coins': None if package is None else package.early_coin_policy,
        'phases': [
            'Read-only source/empty-table gate; refuse existing review32.',
            'CREATE DATABASE TEMPLATE; empty-clone recheck; apply27 ->28 ->29 ->30.',
            'Pre-data dryrun and exact down/schema/ACL roundtrip.',
            'Seed only synthetic owners and v1 completed/active attempts in clone.',
            'Install32; full20 rewards, old snapshots, early time/points/coins.',
            'Duplicate/concurrent terminal calls, real-end overlap, partial scope/details/revision.',
            'Private metadata/ACL/public payload checks and data-protecting rollback guards.',
            'Keep clone and report row/schema hashes; source remains untouched.',
        ],
        'limits': 'No main DB, live service, .env, native or31. Historical SQL timestamps are fixtures.',
    }


class SqlError(RuntimeError):
    pass


class Evidence:
    def __init__(self, manifest: dict):
        suffix = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
        self.directory = OUTPUT / suffix
        self.directory.mkdir(parents=True, exist_ok=False)
        self.checks: list[dict] = []
        self.snapshots: dict = {}
        self.write('plan.json', manifest)

    def write(self, name: str, data: object) -> None:
        if not re.fullmatch(r'[a-zA-Z0-9_-]+\.json', name):
            raise ValueError('Invalid evidence filename')
        (self.directory / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')

    def check(self, name: str, passed: bool, detail: object = None) -> None:
        self.checks.append({'name': name, 'ok': bool(passed), 'detail': detail})
        self.write('checks.json', self.checks)
        print(('PASS ' if passed else 'FAIL ') + name, flush=True)
        if not passed:
            raise AssertionError(name)


class LocalDatabase:
    """Every destination/connection option is fixed; no DSN override is accepted."""
    def __init__(self, evidence: Evidence, *, explicitly_enabled: bool):
        if explicitly_enabled is not True:
            raise ValueError('Database access needs explicit --apply-tests')
        self.psql = shutil.which('psql')
        if not self.psql:
            raise SqlError('psql unavailable')
        self.evidence = evidence
        self.created = False
        self.calls = 0
        self.call_lock = threading.Lock()

    def _execute(self, database: str, sql: str, *, error: str | None = None,
                 sqlstate: str | None = None) -> str:
        if database not in {'postgres', SOURCE_DB, CLONE_DB}:
            raise ValueError('Database outside fixed allowlist')
        dsn = ('host=127.0.0.1 port=54322 user=postgres password=postgres '
               f'dbname={database} connect_timeout=5 sslmode=disable '
               'application_name=isolated_proposed32')
        env = {'PATH': str(Path(self.psql).parent) + ':/usr/bin:/bin',
               'PGPASSFILE': '/dev/null', 'LC_ALL': 'C'}
        result = subprocess.run([self.psql, dsn, '-XqAt', '-v', 'ON_ERROR_STOP=1',
                                 '-v', 'VERBOSITY=verbose'], input=sql, env=env,
                                text=True, capture_output=True, timeout=60)
        with self.call_lock:
            self.calls += 1
            call_id = self.calls
        self.evidence.write(f'sql-{call_id:04d}.json', {
            'database': database, 'sql_sha256': hashlib.sha256(sql.encode()).hexdigest(),
            'returncode': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
            'expected_error': error, 'expected_sqlstate': sqlstate,
        })
        if error is not None or sqlstate is not None:
            match = re.search(r'ERROR:\s+(?:([A-Z0-9]{5}):\s+)?([^\n]+)', result.stderr)
            passed = result.returncode != 0 and match is not None
            if passed and error is not None:
                passed = match.group(2) == error or match.group(2).startswith(error + ' ')
            if passed and sqlstate is not None:
                passed = match.group(1) == sqlstate
            self.evidence.check('expected_rejection:' + (error or sqlstate or ''), passed)
        elif result.returncode:
            raise SqlError(f'{database}: {result.stderr.strip()}')
        return result.stderr if error is not None or sqlstate is not None else result.stdout.strip()

    def readonly(self, database: str, sql: str) -> str:
        if database not in {'postgres', SOURCE_DB, CLONE_DB}:
            raise ValueError('Read outside fixed allowlist')
        # A read-only transaction provides server enforcement, not a keyword guess.
        return self._execute(database, "BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; "
                             "SET LOCAL statement_timeout='30s'; " + sql + '; COMMIT;')

    def clone(self, sql: str, *, error: str | None = None, sqlstate: str | None = None) -> str:
        if not self.created:
            raise ValueError('Only this run may write its newly created clone')
        guarded = ("SET statement_timeout='30s'; DO $identity$ BEGIN IF current_database()<>"
                   + literal(CLONE_DB) + " THEN RAISE EXCEPTION 'wrong_review32_database'; "
                   'END IF; END $identity$;\n' + sql)
        return self._execute(CLONE_DB, guarded, error=error, sqlstate=sqlstate)

    def create_clone(self) -> None:
        if self.created:
            raise ValueError('Clone was already created by this run')
        absent = self.readonly('postgres', "SELECT NOT EXISTS(SELECT 1 FROM pg_database WHERE datname="
                               + literal(CLONE_DB) + ')')
        self.evidence.check('new_clone_name_unused', absent == 't')
        self._execute('postgres', CREATE_CLONE)
        self.created = True

    def json(self, sql: str, database: str | None = None) -> object:
        return json.loads(self.readonly(CLONE_DB if database is None else database, sql))

    def tables(self, database: str) -> list[str]:
        return self.json("SELECT coalesce(jsonb_agg(n.nspname||'.'||c.relname ORDER BY n.nspname,c.relname),'[]') "
                         'FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace '
                         'WHERE c.relkind IN(\'r\',\'p\') AND n.nspname IN('
                         + ','.join(literal(s) for s in DATA_SCHEMAS) + ')', database)

    def empty_gate(self, database: str) -> dict:
        if database not in {SOURCE_DB, CLONE_DB}:
            raise ValueError('Unexpected baseline database')
        tables = self.tables(database)
        queries = [f'SELECT {literal(t)} name,count(*) n FROM {identifier(t)}'
                   for t in tables if not t.startswith('supabase_migrations.')]
        counts = self.json('SELECT jsonb_object_agg(name,n) FROM (' + ' UNION ALL '.join(queries) + ') q', database)
        self.evidence.check(database + ':required_owner_tables',
                            {'auth.users', 'public.profiles'} <= counts.keys())
        unexpected = {t: n for t, n in counts.items() if n and t not in BASELINE_NONEMPTY}
        self.evidence.check(database + ':zero_users_and_user_tables', not unexpected, unexpected)
        proposed = self.readonly(database, "SELECT count(*) FROM supabase_migrations.schema_migrations "
                                 "WHERE version IN('20261028010000','20261028020000','20261028030000',"
                                 "'20261028040000','20261028050000','20261028060000')")
        self.evidence.check(database + ':no_proposed27_to32', proposed == '0')
        return counts

    def snapshot(self, label: str) -> dict:
        queries = [f'SELECT {literal(t)} name,jsonb_build_object(\'count\',count(*),\'md5\','
                   "md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]'))) value "
                   f'FROM {identifier(t)} r' for t in self.tables(CLONE_DB)]
        rows = self.json('SELECT jsonb_object_agg(name,value) FROM (' + ' UNION ALL '.join(queries) + ') q')
        # User tables are hash-only; schema/function text contains no fixture values.
        schema = self.json("""SELECT jsonb_agg(value ORDER BY value::text) FROM (
          SELECT jsonb_build_object('kind','function','name',p.oid::regprocedure::text,
            'definition',md5(pg_get_functiondef(p.oid)),'acl',p.proacl::text) value
          FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f'
          UNION ALL SELECT jsonb_build_object('kind','column','table',table_name,'name',column_name,
            'type',udt_name,'nullable',is_nullable,'default',column_default)
          FROM information_schema.columns WHERE table_schema='public'
          UNION ALL SELECT jsonb_build_object('kind','table','name',c.relname,
            'acl',c.relacl::text,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity)
          FROM pg_class c WHERE c.relnamespace='public'::regnamespace AND c.relkind IN('r','p')
          UNION ALL SELECT jsonb_build_object('kind','constraint','table',conrelid::regclass::text,
            'name',conname,'definition',pg_get_constraintdef(oid))
          FROM pg_constraint WHERE connamespace='public'::regnamespace
          UNION ALL SELECT jsonb_build_object('kind','policy','table',tablename,'name',policyname,
            'roles',roles,'command',cmd,'qual',qual,'check',with_check)
          FROM pg_policies WHERE schemaname='public'
          UNION ALL SELECT jsonb_build_object('kind','trigger','table',tgrelid::regclass::text,
            'name',tgname,'definition',pg_get_triggerdef(oid)) FROM pg_trigger
          WHERE NOT tgisinternal AND tgrelid IN(SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace)
          UNION ALL SELECT jsonb_build_object('kind','index','table',tablename,'name',indexname,'definition',indexdef)
          FROM pg_indexes WHERE schemaname='public'
        ) objects""")
        result = {'rows': rows, 'schema': schema}
        self.evidence.snapshots[label] = result
        self.evidence.write('snapshots.json', self.evidence.snapshots)
        return result

    def rpc(self, owner: str, name: str, args: str = '', *, error: str | None = None) -> dict | str:
        uuid.UUID(owner)
        if name not in RPC_NAMES:
            raise ValueError('RPC outside fixture allowlist')
        claims = literal(json.dumps({'sub': owner, 'role': 'authenticated'}))
        sql = ('BEGIN; SET LOCAL request.jwt.claims=' + claims
               + '; SET LOCAL ROLE authenticated; SELECT public.' + name + '(' + args + '); COMMIT;')
        result = self.clone(sql, error=error)
        return result if error else (json.loads(result) if result else {})


def require_ready(manifest: dict) -> None:
    if not manifest['ready']:
        raise ValueError('New proposal32 is not executable yet: ' + '; '.join(manifest['pending']))


def run_scenarios(database: LocalDatabase, package: PackageSpec, manifest: dict) -> None:
    db, ev = database, database.evidence
    before_source = db.empty_gate(SOURCE_DB)
    db.create_clone()
    ev.check('clone_matches_empty_source', db.empty_gate(CLONE_DB) == before_source)
    base_before27 = None
    for path in PREREQUISITES:
        if path.name == '20261009233000_remove_unowned_ronin.sql':
            db.clone("UPDATE public.avatars SET created_at='2026-10-09T19:25:05.402775+00:00' WHERE id LIKE 'special_%';")
        if path.name == '27_tus_segment.sql':
            base_before27 = db.snapshot('base_before27')
        if path.name[:2] in {'27','28','29','30'}:
            dry_path = path.with_name(path.stem+'_dryrun.sql')
            before_dry = db.snapshot('before_'+path.stem+'_dryrun')
            output = db.clone(strip_psql_guards(dry_path.read_text()), error='DRYRUN_RESULT')
            values = re.findall(r'T[0-9]+[^:]*: (true|false)', output)
            expected_count = {'27':6,'28':20,'29':15,'30':10}[path.name[:2]]
            ev.check('prerequisite_dryrun:'+path.name, len(values)==expected_count and all(v=='true' for v in values), {'count':len(values),'expected':expected_count})
            ev.check('prerequisite_dryrun_rollback:'+path.name, before_dry==db.snapshot('after_'+path.stem+'_dryrun'))
        db.clone(strip_psql_guards(path.read_text()))
        ev.check('installed:' + path.name, True)
    ev.check('31_absent', db.readonly(CLONE_DB, "SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='20261028050000'") == '0')
    up = strip_psql_guards(package.forward.read_text())
    down = strip_psql_guards(package.down.read_text())
    baseline = db.snapshot('before32_empty')
    dry = db.clone(strip_psql_guards(package.dryrun.read_text()), error='DRYRUN_RESULT')
    match = re.search(r'DRYRUN_RESULT >> (\{[^\n]+\})', dry)
    checks = json.loads(match.group(1)) if match else {}
    ev.check('dryrun_all_true', len(checks) == package.dryrun_check_count and all(checks.values()), checks)
    ev.check('dryrun_no_changes', baseline == db.snapshot('after_dryrun'))
    db.clone(up)
    db.clone(down)
    ev.check('empty_install_down_exact', baseline == db.snapshot('after_empty_down'))
    for down_name in ['30_session_start_atomic_down.sql','29_monthly_competitions_down.sql','28_exam_core_down.sql','27_tus_segment_down.sql']:
        db.clone(strip_psql_guards((ROOT/'supabase/proposed'/down_name).read_text()))
        ev.check('empty_down:'+down_name,True)
    ev.check('all27through32_down_exact',base_before27==db.snapshot('after_all_down'))
    for path in PREREQUISITES[2:]:
        db.clone(strip_psql_guards(path.read_text()))

    def owner(label: str, timezone_name: str = 'Europe/Istanbul') -> str:
        uid = str(uuid.uuid4())
        db.clone("INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data,created_at) VALUES("
                 + literal(uid) + ',' + literal('review32-' + uid + '@pomosprint.local')
                 + ",'authenticated','authenticated',jsonb_build_object('name',"
                 + literal('Review32 ' + label) + "),now()); UPDATE public.profiles SET "
                 + "user_segment='yks',timezone=" + literal(timezone_name)
                 + ',show_in_social_feed=false WHERE id=' + literal(uid) + ';')
        return uid

    def start(uid: str, exam: str = 'ayt') -> dict:
        return db.rpc(uid, 'start_exam_attempt', literal(uuid.uuid4()) + ',' + literal(exam))['attempt']

    def shift(uid: str, attempt: dict, elapsed: float, *, expired: bool = False) -> None:
        seconds = int(attempt['definition']['duration_seconds'])
        offset = seconds + 1 if expired else elapsed
        db.clone("WITH anchor AS (SELECT clock_timestamp()-make_interval(secs=>"
                 + str(float(offset)) + ") t) UPDATE public.exam_attempts SET started_at=anchor.t,"
                 + 'ends_at=anchor.t+make_interval(secs=>' + str(seconds) + ') FROM anchor WHERE id='
                 + literal(attempt['id']) + ' AND user_id=' + literal(uid) + " AND status='active';")

    def full(uid: str, attempt: dict) -> dict:
        shift(uid, attempt, 0, expired=True)
        return db.rpc(uid, 'complete_exam_attempt', literal(attempt['id']))['attempt']

    def ledger(uid: str) -> dict:
        return db.json("SELECT jsonb_build_object('profile',(SELECT jsonb_build_array(coins,lifetime_points,total_minutes,current_streak,longest_streak,last_study_date) FROM public.profiles WHERE id="
                       + literal(uid) + "),'wallet',(SELECT to_jsonb(w) FROM public.exam_wallets w WHERE user_id="
                       + literal(uid) + "),'events',(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY kind,source_id),'[]') FROM public.competition_events e WHERE user_id="
                       + literal(uid) + '))')

    def rejection(uid: str, name: str, args: str, code: str) -> None:
        before = db.snapshot('reject_before_' + str(db.calls))
        db.rpc(uid, name, args, error=code)
        ev.check('rejected_without_mutation:' + code, before == db.snapshot('reject_after_' + str(db.calls)))

    def details(uid: str, attempt: dict, patch: dict, results=None, revision=None) -> dict:
        args = literal(attempt['id']) + ',' + literal(json.dumps(patch, ensure_ascii=False)) + '::jsonb,'
        args += 'NULL' if results is None else literal(json.dumps(results)) + '::jsonb'
        args += ',NULL' if revision is None else ',' + str(revision)
        return db.rpc(uid, 'save_exam_details', args)

    old_uid = owner('old active')
    old_active = start(old_uid)
    old_snapshot = db.json('SELECT definition FROM public.exam_attempts WHERE id=' + literal(old_active['id']))
    old175_uid = owner('previous175 active')
    saved_ayt_definition = db.json("SELECT definition FROM public.exam_catalog WHERE id='ayt'")
    db.clone("UPDATE public.exam_catalog SET definition=definition||'{\"reward_coins\":175,\"reward_policy_version\":2}'::jsonb WHERE id='ayt';")
    old175_active = start(old175_uid)
    db.clone("UPDATE public.exam_catalog SET definition="+literal(json.dumps(saved_ayt_definition))+"::jsonb WHERE id='ayt';")
    old_done_uid = owner('old completed')
    old_done = full(old_done_uid, start(old_done_uid))
    before_old_done = ledger(old_done_uid)
    old_kpss_uid = owner('pre32 kpss active')
    db.rpc(old_kpss_uid, 'set_competition_target', "'kpss'")
    old_kpss_active = start(old_kpss_uid, 'kpss_bachelor_gygk')
    old_kpss_snapshot = db.json('SELECT definition FROM public.exam_attempts WHERE id=' + literal(old_kpss_active['id']))
    db.clone(up)
    ev.check('old_active_raw_snapshot_unchanged', old_snapshot == db.json('SELECT definition FROM public.exam_attempts WHERE id=' + literal(old_active['id'])))
    ev.check('old_completed_ledger_unchanged', before_old_done == ledger(old_done_uid))
    ev.check('old_completed_full_reward7', old_done['exam_coins_earned'] == 7)
    ev.check('pre32_kpss_raw_snapshot_unchanged', old_kpss_snapshot == db.json('SELECT definition FROM public.exam_attempts WHERE id=' + literal(old_kpss_active['id'])))
    old_kpss_done = full(old_kpss_uid, old_kpss_active)
    ev.check('pre32_kpss_reward5_not_rewritten_to105', old_kpss_done['exam_coins_earned'] == 5 and old_kpss_done['points_earned'] == 26)
    expected_catalog = json.loads((ROOT / 'supabase/proposed/exam_catalog_32.json').read_text())['exams']
    actual_catalog = db.json('SELECT jsonb_agg(definition ORDER BY id) FROM public.exam_catalog')
    ev.check('exact_new_catalog', actual_catalog == sorted(expected_catalog, key=lambda row: row['id']))
    config = db.rpc(old_uid, 'get_exam_config')
    ev.check('final_capabilities_enabled', config['capabilities'] == {'exam_details': True, 'ayt_modules_version': 1, 'ayt_early_finish': True})
    normal_before = db.json("SELECT jsonb_object_agg(id::text,jsonb_build_array(coins,lifetime_points)) FROM public.profiles")
    normal_rows_before = {key: value for key, value in db.snapshot('normal_before')['rows'].items() if key in {
        'public.study_sessions', 'public.session_starts', 'public.marathon_runs', 'public.marathon_run_sessions'}}

    existing_owner_list = ','.join(literal(uid) + '::uuid' for uid in normal_before)
    avatar_before = db.json("SELECT jsonb_agg(to_jsonb(a) ORDER BY user_id,avatar_id) FROM public.avatar_unlocks a WHERE user_id IN(" + existing_owner_list + ')')

    completed_by_exam = {}
    for exam, coins in EXPECTED_FULL_COINS.items():
        uid = owner('full ' + exam)
        if exam == 'dus':
            target=db.rpc(uid,'set_competition_target',"'dus'")
            ev.check('dus_target_before_first_session',target['current_segment']=='dus')
        if exam.startswith('kpss_'):
            target = db.rpc(uid, 'set_competition_target', "'kpss'")
            ev.check('kpss_target:' + exam, target['current_segment'] == 'kpss')
        attempt = start(uid, exam)
        if exam.startswith('kpss_'):
            rejection(uid, 'finish_ayt_early', literal(attempt['id']), 'exam_early_finish_not_supported')
        done = full(uid, attempt)
        completed_by_exam[exam]=(uid,done)
        ev.check('full_reward:' + exam, done['status'] == 'completed' and done['exam_coins_earned'] == coins
                 and done['points_earned'] == EXPECTED_FULL_POINTS[exam] and done['catalog_version'] == 1
                 and done['completion_kind'] == 'full' and done['duration_seconds'] == attempt['duration_seconds'])
        before = ledger(uid)
        duplicate = db.rpc(uid, 'complete_exam_attempt', literal(done['id']))
        ev.check('full_duplicate:' + exam, duplicate['duplicate'] and duplicate['attempt'] == done and before == ledger(uid))
        if exam.startswith('kpss_'):
            subject = done['subjects'][0]
            result = {'subject_id': subject['id'], 'correct': subject['question_count'] - 5,
                      'wrong': 4, 'blank': 1}
            saved = details(uid, done, {'title': 'KPSS denemem', 'note': 'Özel sonuç notu'}, [result], 0)['attempt']
            ev.check('kpss_net_and_details:' + exam,
                     len(saved['subject_results']) == 1
                     and float(saved['subject_results'][0]['net']) == subject['question_count'] - 6
                     and saved['title'] == 'KPSS denemem' and saved['details_revision'] == 1
                     and ledger(uid) == before)
            invalid = [dict(result, correct=subject['question_count'])]
            rejection(uid, 'save_exam_results', literal(done['id']) + ',' + literal(json.dumps(invalid)) + '::jsonb', 'exam_result_invalid')
            claims = literal(json.dumps({'sub': old_uid, 'role': 'authenticated'}))
            hidden = db.clone('BEGIN; SET LOCAL request.jwt.claims=' + claims
                              + '; SET LOCAL ROLE authenticated; SELECT count(*) FROM public.exam_subject_results WHERE attempt_id='
                              + literal(done['id']) + '; COMMIT;')
            ev.check('kpss_result_owner_rls:' + exam, hidden == '0')

    kpss_uid, _ = completed_by_exam['kpss_bachelor_gygk']
    kpss_rank = db.rpc(kpss_uid, 'get_my_exam_league_ranking', "'segment'")
    kpss_owners = {uid for exam, (uid, _) in completed_by_exam.items() if exam.startswith('kpss_')}
    kpss_owners.add(old_kpss_uid)
    member_ids = db.json("SELECT jsonb_agg(m.user_id ORDER BY m.user_id) FROM public.competition_memberships m JOIN public.competition_rooms r ON r.id=m.room_id WHERE r.segment='kpss' AND r.kind='exam' AND r.period_month=public._competition_month(now())")
    ev.check('kpss_category_room_has_only_kpss_owners',
             kpss_rank['segment'] == 'kpss' and kpss_rank['room_capacity'] == 25
             and set(member_ids) == kpss_owners)
    ev.check('kpss_private_peers_are_masked_in_ranking',
             len(kpss_rank['rows']) == len(kpss_owners)
             and {row['id'] for row in kpss_rank['rows']} == {kpss_uid, None})
    # Explicitly opt only these synthetic owners into visibility, then verify
    # the public projection independently of private membership storage.
    visible_owners = kpss_owners | {completed_by_exam['dus'][0]}
    db.clone('UPDATE public.profiles SET show_in_social_feed=true WHERE id IN ('
             + ','.join(literal(uid) + '::uuid' for uid in sorted(visible_owners)) + ');')
    global_rank = db.rpc(kpss_uid, 'get_my_exam_league_ranking', "'global'")
    ev.check('kpss_global_ranking_keeps_other_targets',
             global_rank['scope'] == 'global' and kpss_owners <= {row['id'] for row in global_rank['rows']}
             and completed_by_exam['dus'][0] in {row['id'] for row in global_rank['rows']})
    kpss_before = ledger(kpss_uid)
    kpss_target = db.rpc(kpss_uid, 'set_competition_target', "'yks'")
    ev.check('kpss_mid_month_change_preserves_current_segment_and_wallet',
             kpss_target['current_segment'] == 'kpss' and kpss_target['pending_segment'] == 'yks'
             and ledger(kpss_uid) == kpss_before)

    dus_uid,dus_done=completed_by_exam['dus']
    dus_before=ledger(dus_uid)
    target=db.rpc(dus_uid,'set_competition_target',"'yks'")
    ev.check('dus_target_change_next_month_preserves_wallet',target['current_segment']=='dus' and target['pending_segment']=='yks' and dus_before==ledger(dus_uid))
    early_uid = owner('early90')
    early = start(early_uid)
    rejection(early_uid, 'complete_exam_attempt', literal(early['id']), 'exam_not_elapsed')
    shift(early_uid, early, 5400)
    done = db.rpc(early_uid, 'finish_ayt_early', literal(early['id']))['attempt']
    elapsed = done['elapsed_seconds']
    expected_coins = min(145,145 * elapsed // 10800)
    ev.check('early90_actual_time_reward', 5400 <= elapsed < 5410 and done['duration_seconds'] == elapsed
             and done['planned_duration_seconds'] == 10800 and done['credited_minutes'] == 90
             and done['completion_kind'] == 'early' and done['points_earned'] == 18 and done['exam_coins_earned'] == expected_coins)
    current_ledger = ledger(early_uid)
    ev.check('early90_profile_minutes_streak', current_ledger['profile'][2:4] == [90, 1])
    event = current_ledger['events'][0]
    ev.check('early90_event_uses_actual_finish', len(current_ledger['events']) == 1 and event['minutes'] == 90 and event['points'] == 18
             and event['completed_at'] == done['completed_at'])
    for rpc in ('finish_ayt_early', 'complete_exam_attempt', 'abandon_exam_attempt'):
        response = db.rpc(early_uid, rpc, literal(done['id']))
        ev.check('early_terminal_duplicate:' + rpc, response['duplicate'] and response['attempt'] == done and ledger(early_uid) == current_ledger)
    db.rpc(early_uid, 'start_study_session', "25,'Matematik'")
    ev.check('normal_start_after_actual_finish', db.readonly(CLONE_DB, 'SELECT active_session_ends_at>clock_timestamp() FROM public.profiles WHERE id=' + literal(early_uid)) == 't')
    db.rpc(early_uid, 'start_study_session', "0,'Matematik'")

    shift(old_uid, old_active, 5400)
    old_early = db.rpc(old_uid, 'finish_ayt_early', literal(old_active['id']))['attempt']
    old_expected = 7 if package.early_coin_policy == 'full' else 7 * old_early['elapsed_seconds'] // 10800
    ev.check('old_active_early_uses_frozen_reward', old_early['exam_coins_earned'] == old_expected and old_early['definition']['reward_coins'] == 7)
    shift(old175_uid,old175_active,5400)
    old175_done=db.rpc(old175_uid,'finish_ayt_early',literal(old175_active['id']))['attempt']
    ev.check('previous175_snapshot_stays175',old175_done['definition']['reward_coins']==175 and old175_done['exam_coins_earned']==175*old175_done['elapsed_seconds']//10800)
    zero_uid = owner('zero minute')
    zero = start(zero_uid)
    shift(zero_uid, zero, -1)
    rejection(zero_uid, 'finish_ayt_early', literal(zero['id']), 'exam_early_finish_too_soon')
    shift(zero_uid, zero, 1)
    zero_before = ledger(zero_uid)
    zero_done = db.rpc(zero_uid, 'finish_ayt_early', literal(zero['id']))['attempt']
    zero_after = ledger(zero_uid)
    ev.check('one_second_zero_minutes', 1 <= zero_done['duration_seconds'] < 59 and zero_done['credited_minutes'] == 0
             and zero_done['points_earned'] == 0 and zero_after['profile'] == zero_before['profile'] and zero_after['events'] == [])
    other_uid = owner('not ayt')
    other = start(other_uid, 'tyt')
    rejection(other_uid, 'finish_ayt_early', literal(other['id']), 'exam_early_finish_not_supported')
    abandoned_uid = owner('abandoned')
    abandoned = start(abandoned_uid)
    abandoned_done = db.rpc(abandoned_uid, 'abandon_exam_attempt', literal(abandoned['id']))['attempt']
    rejection(abandoned_uid, 'finish_ayt_early', literal(abandoned['id']), 'exam_not_active')
    ev.check('abandoned_no_wallet_or_event', abandoned_done['exam_coins_earned'] == 0 and ledger(abandoned_uid)['wallet'] is None and ledger(abandoned_uid)['events'] == [])
    expired_uid = owner('expired early route')
    expired = start(expired_uid)
    shift(expired_uid, expired, 0, expired=True)
    expired_done = db.rpc(expired_uid, 'finish_ayt_early', literal(expired['id']))['attempt']
    ev.check('expired_early_delegates_full', expired_done['completion_kind'] == 'full' and expired_done['exam_coins_earned'] == 145 and expired_done['duration_seconds'] == 10800)

    maths = {'subject_id': 'mathematics', 'correct': 35, 'wrong': 4, 'blank': 1}
    physics = {'subject_id': 'physics', 'correct': 10, 'wrong': 2, 'blank': 2}
    before_details = ledger(early_uid)
    save = details(early_uid, done, {'title': '  AYT denemem  ', 'note': 'Satır1\n\tSatır2', 'selected_module_ids': ['science', 'mathematics']}, [maths, physics], 0)
    saved = save['attempt']
    ev.check('atomic_details_and_nets', not save['duplicate'] and saved['title'] == 'AYT denemem' and saved['note'] == 'Satır1\n\tSatır2'
             and saved['selected_module_ids'] == ['mathematics', 'science'] and saved['details_revision'] == 1 and len(saved['subject_results']) == 2)
    ev.check('details_no_economy', before_details == ledger(early_uid))
    duplicate = details(early_uid, done, {'title': 'AYT denemem', 'note': 'Satır1\n\tSatır2', 'selected_module_ids': ['mathematics', 'science']}, [maths, physics], 0)
    ev.check('stale_identical_patch_duplicate', duplicate['duplicate'] and duplicate['attempt'] == saved)
    raw_before = db.json('SELECT jsonb_agg(to_jsonb(r) ORDER BY subject_id) FROM public.exam_subject_results r WHERE attempt_id=' + literal(done['id']))
    edit = dict(maths, correct=36, wrong=4, blank=0)
    edited = details(early_uid, done, {}, [edit], 1)['attempt']
    raw_after = db.json('SELECT jsonb_agg(to_jsonb(r) ORDER BY subject_id) FROM public.exam_subject_results r WHERE attempt_id=' + literal(done['id']))
    ev.check('partial_edit_preserves_omitted', edited['details_revision'] == 2 and raw_before[1] == raw_after[1]
             and float(edited['subject_results'][0]['net']) == 35.0)
    for patch, code in [({'note': 'stale'}, 'exam_details_conflict'), ({'selected_module_ids': ['mathematics']}, 'exam_scope_conflict'),
                        ({'selected_module_ids': None}, 'exam_details_invalid'), ({'selected_module_ids': ['science', 'science']}, 'exam_details_invalid'),
                        ({'title': 'line\nbreak'}, 'exam_details_invalid'), ({'title': 'x'*121}, 'exam_details_invalid'),
                        ({'note': 'x'*2001}, 'exam_details_invalid'), ({'note': 'carriage\rreturn'}, 'exam_details_invalid')]:
        args = literal(done['id']) + ',' + literal(json.dumps(patch)) + '::jsonb,NULL,0'
        rejection(early_uid, 'save_exam_details', args, code)
    invalid_scope = [{'subject_id':'literature','correct':24,'wrong':0,'blank':0}]
    rejection(early_uid, 'save_exam_results', literal(done['id']) + ',' + literal(json.dumps(invalid_scope)) + '::jsonb', 'exam_scope_conflict')
    unicode_save = details(early_uid, done, {'title':'😀'*120}, revision=2)['attempt']
    ev.check('unicode_scalar_120_allowed', unicode_save['title'] == '😀'*120 and unicode_save['details_revision'] == 3)
    cleared = details(early_uid, done, {'title':None, 'note':None}, revision=3)['attempt']
    ev.check('metadata_only_clear_preserves_nets', cleared['title'] is None and cleared['note'] is None and len(cleared['subject_results']) == 2)
    noop = details(early_uid, done, {})
    ev.check('empty_patch_noop', noop['duplicate'] and noop['attempt'] == cleared)
    rejection(other_uid, 'save_exam_details', literal(done['id']) + ",'{\"title\":\"foreign\"}'::jsonb,NULL,NULL", 'exam_not_found')
    claims = literal(json.dumps({'sub': other_uid, 'role': 'authenticated'}))
    hidden = db.clone('BEGIN; SET LOCAL request.jwt.claims=' + claims + '; SET LOCAL ROLE authenticated; SELECT count(*) FROM public.exam_attempts WHERE id=' + literal(done['id']) + '; COMMIT;')
    ev.check('other_owner_RLS_hidden', hidden == '0')
    db.clone('BEGIN; SET LOCAL ROLE anon; SELECT public.finish_ayt_early(' + literal(done['id']) + '); ROLLBACK;', error='permission denied for function finish_ayt_early')
    db.clone('BEGIN; SET LOCAL ROLE authenticated; SELECT * FROM public.exam_extension_32_backup; ROLLBACK;', error='permission denied for table exam_extension_32_backup')
    db.clone('BEGIN; SET LOCAL ROLE authenticated; UPDATE public.exam_attempts SET title=\'forged\'; ROLLBACK;', error='permission denied for table exam_attempts')

    invalid_net = [{'subject_id':'mathematics','correct':40,'wrong':1,'blank':0}]
    rejection(early_uid, 'save_exam_results', literal(done['id']) + ',' + literal(json.dumps(invalid_net)) + '::jsonb', 'exam_result_invalid')
    ev.check('all_details_preserve_economy', ledger(early_uid) == before_details)
    concurrency_uid = owner('concurrent early')
    concurrency_attempt = start(concurrency_uid)
    shift(concurrency_uid, concurrency_attempt, 600)
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(db.rpc, concurrency_uid, 'finish_ayt_early', literal(concurrency_attempt['id'])) for _ in range(2)]
        responses = [f.result() for f in futures]
    ev.check('two_clients_one_early_reward', sorted(r['duplicate'] for r in responses) == [False,True]
             and responses[0]['attempt'] == responses[1]['attempt']
             and len(ledger(concurrency_uid)['events']) == 1)
    def concurrent_detail(title):
        try:
            return ('ok', details(concurrency_uid, responses[0]['attempt'], {'title':title}, revision=0))
        except SqlError as exc:
            return ('error', str(exc))
    with ThreadPoolExecutor(max_workers=2) as pool:
        edits = list(pool.map(concurrent_detail, ['Device A','Device B']))
    ev.check('two_clients_revision_conflict_no_lost_update', sum(kind=='ok' for kind,_ in edits)==1
             and sum(kind=='error' and 'exam_details_conflict' in value for kind,value in edits)==1)
    # Independent boundary probe: temporary event uses the public monthly engine,
    # rolls back, and does not pretend that wall-clock time naturally crossed a month.
    probe_source = str(uuid.uuid4())
    boundary = db.clone('BEGIN; SELECT public._competition_record(\'exam\',' + literal(probe_source) + ',' + literal(early_uid)
                       + ", '2026-10-31 23:30+03', '2026-11-01 00:30+03', 60, 12); SELECT jsonb_build_array(period_month,study_day,minutes,points) FROM public.competition_events WHERE source_id="
                       + literal(probe_source) + '; ROLLBACK;')
    ev.check('month_and_04day_boundary_controlled_SQL', json.loads(boundary.splitlines()[-1]) == ['2026-11-01','2026-10-31',60,12])
    normal_after = db.json("SELECT jsonb_object_agg(id::text,jsonb_build_array(coins,lifetime_points)) FROM public.profiles")
    ev.check('normal_wallets_unchanged', all(normal_after[key] == value for key, value in normal_before.items())
             and all(value == [0, 0] for key, value in normal_after.items() if key not in normal_before))
    normal_rows_after = {key: value for key, value in db.snapshot('normal_after')['rows'].items() if key in normal_rows_before}
    ev.check('normal_rows_unchanged', normal_rows_after == normal_rows_before)
    ev.check('existing_avatar_grants_unchanged', avatar_before == db.json("SELECT jsonb_agg(to_jsonb(a) ORDER BY user_id,avatar_id) FROM public.avatar_unlocks a WHERE user_id IN(" + existing_owner_list + ')'))
    ev.check('new_owner_avatar_grants_default_only', db.readonly(CLONE_DB, "SELECT count(*) FROM public.avatar_unlocks WHERE user_id NOT IN(" + existing_owner_list + ") AND (unlock_type<>'default' OR coins_spent<>0)") == '0')
    before_down = db.snapshot('protected_down_before')
    db.clone(down, error=package.rollback_data_error)
    ev.check('data_protected_down_no_change', before_down == db.snapshot('protected_down_after'))
    ev.check('31_absent_at_end', db.readonly(CLONE_DB, "SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='20261028050000'") == '0')
    ev.check('source_remained_empty', db.empty_gate(SOURCE_DB) == before_source)
    db.rpc(other_uid, 'abandon_exam_attempt', literal(other['id']))
    ev.check('all_fixture_attempts_terminal', db.readonly(CLONE_DB, "SELECT count(*) FROM public.exam_attempts WHERE status='active'") == '0')
    ev.write('completed_fixture_summary.json', {'early_owner': early_uid, 'early_attempt': done['id'], 'early_seconds': elapsed,
             'early_coins': expected_coins, 'one_second_attempt': zero_done['id'], 'old_active_reward': old_expected,
             'policy': package.early_coin_policy, 'policy_status': 'user_approved_final', 'notice': 'Synthetic local timestamps; no native or natural-duration claim.'})


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply-tests', action='store_true',
                        help='After coordinated approval only: create local clone and execute final scenarios.')
    parser.add_argument('--kpss', action='store_true',
                        help='Use only the new fixed KPSS clone; preserve all existing DUS/site databases.')
    args = parser.parse_args(argv)
    select_target(args.kpss)
    selected_package = PACKAGE
    manifest = plan(selected_package)
    if not args.apply_tests:
        print(json.dumps(manifest, indent=2))
        return 0
    try:
        require_ready(manifest)  # Before evidence directory, psql lookup or connection.
    except ValueError as error:
        print(str(error))
        return 2
    evidence = Evidence(manifest)
    database = LocalDatabase(evidence, explicitly_enabled=True)
    error = None
    try:
        assert selected_package is not None
        run_scenarios(database, selected_package, manifest)
    except Exception as exc:
        error = str(exc)
        print('STOP: ' + error, flush=True)
    finally:
        evidence.write('results.json', {
            'database': CLONE_DB, 'clone_created': database.created,
            'clone_retained': database.created, 'error': error,
            'passed': sum(item['ok'] for item in evidence.checks),
            'total': len(evidence.checks), 'checks': evidence.checks,
            'scope': 'Synthetic isolated SQL fixtures, not natural duration or native verification.',
        })
    return 1 if error else 0


if __name__ == '__main__':
    raise SystemExit(main())
