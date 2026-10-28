#!/usr/bin/env python3
"""Create only a NEW, user-empty site32 DB from the guarded empty baseline.

Default is connection-free. --apply installs reviewed source SQL, never copies
review/native users, never drops a database, and never touches main or review32.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import isolated32_check as runner

SITE_DB = 'pomosprint_site32_dus'
SITE_OUTPUT = runner.ROOT / 'build' / 'site32_dus_bootstrap'


def plan():
    paths = (*runner.PREREQUISITES, runner.PACKAGE.forward)
    return {
        'mode': 'plan_only_no_connections',
        'source': runner.SOURCE_DB, 'target': SITE_DB,
        'endpoint': '127.0.0.1:54322', 'copy_users': False,
        'sources_sha256': {str(p.relative_to(runner.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
    }


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--verify-existing', action='store_true', help='Read-only verification of the fixed site clone; no creation or writes')
    args = parser.parse_args(arguments)
    manifest = plan()
    if not args.apply and not args.verify_existing:
        print(json.dumps(manifest, indent=2))
        return 0
    # The reused primitives remain closed over exactly this one fixed target.
    # No user-supplied URL, database identifier or source can enter them.
    runner.CLONE_DB = SITE_DB
    runner.CREATE_CLONE = 'CREATE DATABASE "pomosprint_site32_dus" WITH TEMPLATE "pomosprint_overnight_baseline";'
    runner.OUTPUT = SITE_OUTPUT
    evidence = runner.Evidence(manifest)
    db = runner.LocalDatabase(evidence, explicitly_enabled=True)
    error = None
    try:
        before = db.empty_gate(runner.SOURCE_DB)
        if args.apply:
            db.create_clone()
            evidence.check('site_clone_empty_before_install', db.empty_gate(SITE_DB) == before)
            for path in runner.PREREQUISITES:
                if path.name == '20261009233000_remove_unowned_ronin.sql':
                    db.clone("UPDATE public.avatars SET created_at='2026-10-09T19:25:05.402775+00:00' WHERE id LIKE 'special_%';")
                db.clone(runner.strip_psql_guards(path.read_text()))
                evidence.check('installed:' + path.name, True)
            db.clone(runner.strip_psql_guards(runner.PACKAGE.forward.read_text()))
        evidence.check('site_has_zero_users', db.readonly(SITE_DB, 'SELECT count(*) FROM auth.users') == '0')
        evidence.check('site_has_zero_profiles', db.readonly(SITE_DB, 'SELECT count(*) FROM public.profiles') == '0')
        evidence.check('site_has_zero_attempts', db.readonly(SITE_DB, 'SELECT count(*) FROM public.exam_attempts') == '0')
        evidence.check('site_has_zero_study_sessions', db.readonly(SITE_DB, 'SELECT count(*) FROM public.study_sessions') == '0')
        evidence.check('source_remains_empty', db.empty_gate(runner.SOURCE_DB) == before)
        check = subprocess.run([sys.executable, str(runner.ROOT / 'tool/local_supabase/parity_check_exam32.py'), '--profile', 'site'], text=True, capture_output=True, timeout=30)
        evidence.check('site_exact_reviewed32_parity', check.returncode == 0, check.stdout + check.stderr)
        db.snapshot('site_final_empty')
    except Exception as exc:
        error = str(exc)
        print('STOP: ' + error, flush=True)
    finally:
        evidence.write('results.json', {
            'database': SITE_DB, 'created': db.created, 'retained': True, 'mode': 'read_only_verify' if args.verify_existing else 'create',
            'error': error, 'checks': evidence.checks,
            'passed': sum(c['ok'] for c in evidence.checks), 'total': len(evidence.checks),
            'users_copied': False, 'main_or_review_modified': False,
        })
        print('Evidence: ' + str(evidence.directory))
    return 1 if error else 0


if __name__ == '__main__':
    raise SystemExit(main())
