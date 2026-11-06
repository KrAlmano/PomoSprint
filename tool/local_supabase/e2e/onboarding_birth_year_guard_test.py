#!/usr/bin/env python3
"""Test proposed/35 in a brand-new Unix-socket-only PostgreSQL cluster.

No existing database, Docker volume, credentials, network service, or user data
is used. PostgreSQL 16 binaries must be installed; override with PG_BIN.
"""
from __future__ import annotations

import os
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
PG_BIN = Path(os.environ.get('PG_BIN', '/Users/almano/.brew/opt/postgresql@16/bin'))
PROPOSED = ROOT / 'supabase/proposed'
TESTS = ROOT / 'supabase/tests'
VERSION = '20261106220000'
BASELINE = '03080f9bcaf3550a6c005fe3bd640f35'
PATCHED = '9db6b98a4cff323ae9a02f02256a53f2'


def load_sql(path: Path) -> str:
    text = path.read_text()
    return '\n'.join(line for line in text.splitlines() if not line.startswith('\\')) + '\n'


def run(args: list[str], *, text: str | None = None) -> str:
    p = subprocess.run(args, input=text, text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError(f'{Path(args[0]).name} returned {p.returncode}: {p.stderr.strip()}')
    return p.stdout.strip()


def main() -> None:
    forward = load_sql(PROPOSED / '35_onboarding_birth_year_guard.sql')
    dryrun = load_sql(PROPOSED / '35_onboarding_birth_year_guard_dryrun.sql')
    down = load_sql(PROPOSED / '35_onboarding_birth_year_guard_down.sql')
    # The SQL Editor packages are byte-identical apart from their first comment.
    for kind, expected in [('APPLY', forward), ('DRYRUN', dryrun), ('DOWN', down)]:
        editor = (TESTS / f'20261106_onboarding_age_35_{kind}_SQL_EDITOR.sql').read_text().split('\n', 1)[1]
        assert editor == expected, kind
    # The complete migration body, including all guards, must be the dryrun body.
    forward_body = forward[forward.index('BEGIN;'):forward.rindex('COMMIT;')]
    assert forward_body in dryrun
    with tempfile.TemporaryDirectory(prefix='pomosprint-age35-', dir='/tmp') as directory:
        data = Path(directory) / 'db'
        logfile = Path(directory) / 'postgres.log'
        port = '55481'  # Isolated Unix socket; listen_addresses is empty.
        pgctl = str(PG_BIN / 'pg_ctl')
        run([str(PG_BIN / 'initdb'), '-A', 'trust', '-U', 'postgres', '-D', str(data), '--no-instructions'])
        try:
            run([pgctl, '-D', str(data), '-l', str(logfile), '-o', f"-F -c listen_addresses='' -k {directory} -p {port}", '-w', 'start'])
            psql = [str(PG_BIN / 'psql'), '-h', directory, '-p', port, '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-X', '-q', '-A', '-t']
            def sql(source: str) -> str:
                return run(psql, text=source)
            def assert_state(hash_expected: str, version_expected: bool) -> None:
                output = sql("SELECT md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)), EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='" + VERSION + "');")
                assert output.splitlines()[-1] == hash_expected + ('|t' if version_expected else '|f'), output
            sql((TESTS / '35_onboarding_birth_year_synthetic_setup.sql').read_text())
            assert_state(BASELINE, False)
            preflight = json.loads(sql((TESTS / '20261106_onboarding_age_35_PREFLIGHT_READ_ONLY.sql').read_text()).splitlines()[-1])
            assert all(preflight[name] is True for name in ['function_hash_matches', 'trigger_matches', 'function_acl_matches', 'profile_rls_enabled', 'marker_absent'])
            assert preflight['completed_missing_birth_year_count'] == 1
            # NULL proacl means PUBLIC's default privilege; guard must reject it.
            inject_acl = "BEGIN; UPDATE pg_catalog.pg_proc SET proacl=NULL WHERE oid='public.enforce_minimum_age()'::regprocedure;\n"
            tampered = subprocess.run(psql, input=inject_acl + forward, text=True, capture_output=True)
            assert tampered.returncode != 0 and 'birth_year_guard_baseline_changed' in tampered.stderr
            assert_state(BASELINE, False)
            bypass = """SET ROLE authenticated;
              SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
              UPDATE public.profiles SET birth_year=NULL,onboarding_completed_at=now() WHERE id='00000000-0000-0000-0000-000000000001';
              SELECT birth_year IS NULL AND onboarding_completed_at IS NOT NULL FROM public.profiles WHERE id='00000000-0000-0000-0000-000000000001'; RESET ROLE;"""
            assert sql(bypass).splitlines()[-1] == 't', 'Baseline bypass did not reproduce'
            sql("UPDATE public.profiles SET onboarding_completed_at=NULL WHERE id='00000000-0000-0000-0000-000000000001';")
            assert 'DRYRUN passed' in sql((TESTS / '20261106_onboarding_age_35_DRYRUN_SQL_EDITOR.sql').read_text())
            assert_state(BASELINE, False)
            sql((TESTS / '20261106_onboarding_age_35_APPLY_SQL_EDITOR.sql').read_text())
            assert_state(PATCHED, True)
            postflight = json.loads(sql((TESTS / '20261106_onboarding_age_35_POSTFLIGHT_READ_ONLY.sql').read_text()).splitlines()[-1])
            assert all(postflight[name] is True for name in ['function_hash_matches', 'trigger_matches', 'function_acl_matches', 'profile_rls_enabled', 'marker_present'])
            assert postflight['completed_missing_birth_year_count'] == 1
            tampered_down = subprocess.run(psql, input=inject_acl + down, text=True, capture_output=True)
            assert tampered_down.returncode != 0 and 'birth_year_guard_down_baseline_changed' in tampered_down.stderr
            assert_state(PATCHED, True)
            assert '10 meaningful synthetic age/RLS cases passed' in sql((TESTS / '35_onboarding_birth_year_synthetic_cases.sql').read_text())
            # Realistic rollback retains every user row and restores the exact previous definition.
            sql((TESTS / '20261106_onboarding_age_35_DOWN_SQL_EDITOR.sql').read_text())
            assert_state(BASELINE, False)
            assert sql("SELECT count(*) FROM public.profiles;").splitlines()[-1] == '3'
            # Reapplying an already removed rollback must fail closed.
            attempt = subprocess.run(psql, input=down, text=True, capture_output=True)
            assert attempt.returncode != 0 and 'birth_year_guard_down_baseline_changed' in attempt.stderr
            print('PASS: baseline bypass reproduced; DRYRUN rolled back; guard and 10 age/RLS cases; rollback and fail-closed checks passed.')
        finally:
            subprocess.run([pgctl, '-D', str(data), '-m', 'fast', '-w', 'stop'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
