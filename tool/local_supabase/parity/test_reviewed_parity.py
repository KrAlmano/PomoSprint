#!/usr/bin/env python3
"""Negative checks for the explicit, fail-closed local review reference."""
import copy
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / "parity_check_reviewed.py"
SPEC = importlib.util.spec_from_file_location("reviewed_parity", PATH)
parity = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(parity)


class ReviewedParityTests(unittest.TestCase):
    def setUp(self):
        self.reference = json.loads(parity.REFERENCE.read_text())

    def test_reviewed_sources_still_match(self):
        self.assertEqual(parity.verify_sources(self.reference), [])

    def test_changed_source_hash_is_rejected(self):
        reference = copy.deepcopy(self.reference)
        first = next(iter(reference["sources_sha256"]))
        reference["sources_sha256"][first] = "0" * 64
        self.assertEqual(parity.verify_sources(reference), [first])

    def test_schema_or_acl_change_is_rejected(self):
        observed = copy.deepcopy(self.reference["expected"])
        observed["schema"]["func"] = ["113", "different"]
        self.assertEqual(parity.differences(self.reference["expected"], observed), ["schema"])

    def test_missing_or_extra_migration_is_rejected(self):
        for mutate in (lambda rows: rows[:-1], lambda rows: rows + ["20990101000000|unexpected"]):
            observed = copy.deepcopy(self.reference["expected"])
            observed["migrations"] = mutate(observed["migrations"])
            self.assertEqual(parity.differences(self.reference["expected"], observed), ["migrations"])

    def test_changed_catalog_or_enabled_mail_is_rejected(self):
        for key, value in (("catalog", {}), ("mail_trigger", "O")):
            observed = copy.deepcopy(self.reference["expected"])
            observed[key] = value
            self.assertEqual(parity.differences(self.reference["expected"], observed), [key])

    def test_noncanonical_database_url_is_rejected_before_request(self):
        for url in ("postgresql://postgres:postgres@remote.invalid:54322/postgres",
                    parity.LOCAL_URL + "?host=remote.invalid",
                    parity.LOCAL_URL.replace("54322", "54323"),
                    parity.LOCAL_URL.replace("127.0.0.1", "localhost")):
            with self.subTest(url=url), patch.dict(os.environ, {"LOCAL_DB_URL": url}):
                with self.assertRaises(ValueError):
                    parity.local_url()

    def test_atomic_reference_requires_explicit_mode(self):
        self.assertEqual(parity.reference_for([])[0], parity.REFERENCE)
        self.assertEqual(parity.reference_for(["--with-session-start-atomic"])[0], parity.ATOMIC_REFERENCE)
        for arguments in (["--auto"], ["--with-session-start-atomic", "--extra"]):
            with self.assertRaises(ValueError):
                parity.reference_for(arguments)

    def test_atomic_reference_changes_only_reviewed_function_and_migration(self):
        atomic = json.loads(parity.ATOMIC_REFERENCE.read_text())
        self.assertEqual(parity.verify_sources(atomic), [])
        self.assertEqual(parity.differences(self.reference["expected"], atomic["expected"]), ["migrations", "schema"])
        self.assertEqual(parity.differences(self.reference["expected"]["schema"], atomic["expected"]["schema"]), ["func"])
        self.assertEqual(set(atomic["expected"]["migrations"]) - set(self.reference["expected"]["migrations"]), {"20261028040000|session_start_atomic"})

    def test_marathon_reference_requires_its_exact_explicit_mode(self):
        self.assertEqual(parity.reference_for(["--with-marathon-anchor"])[0], parity.MARATHON_REFERENCE)
        self.assertEqual(parity.reference_for([])[0], parity.REFERENCE)
        for arguments in (["--with-marathon-anchor", "--extra"],
                          ["--with-session-start-atomic", "--with-marathon-anchor"],
                          ["--with-marathon-anchor=auto"]):
            with self.subTest(arguments=arguments), self.assertRaises(ValueError):
                parity.reference_for(arguments)

    def test_marathon_reference_only_adds_three_reviewed_source_hashes(self):
        atomic = json.loads(parity.ATOMIC_REFERENCE.read_text())
        marathon = json.loads(parity.MARATHON_REFERENCE.read_text())
        self.assertEqual(parity.verify_sources(marathon), [])
        self.assertEqual({key: marathon['sources_sha256'][key]
                          for key in atomic['sources_sha256']}, atomic['sources_sha256'])
        self.assertEqual(set(marathon['sources_sha256'])-set(atomic['sources_sha256']), {
            'supabase/proposed/31_marathon_completion_anchor.sql',
            'supabase/proposed/31_marathon_completion_anchor_down.sql',
            'supabase/proposed/31_marathon_completion_anchor_dryrun.sql',
        })

    def test_marathon_reference_only_changes_function_digest_and_own_migration(self):
        atomic = json.loads(parity.ATOMIC_REFERENCE.read_text())['expected']
        marathon = json.loads(parity.MARATHON_REFERENCE.read_text())['expected']
        self.assertEqual(parity.differences(atomic, marathon), ['migrations', 'schema'])
        self.assertEqual(parity.differences(atomic['schema'], marathon['schema']), ['func'])
        self.assertEqual(atomic['schema']['func'][0], marathon['schema']['func'][0])
        self.assertEqual(set(marathon['migrations'])-set(atomic['migrations']),
                         {'20261028050000|marathon_completion_anchor'})
        self.assertTrue(set(atomic['migrations']).issubset(marathon['migrations']))

    def test_each_changed_marathon_sql_hash_is_rejected(self):
        original = json.loads(parity.MARATHON_REFERENCE.read_text())
        for name in original['sources_sha256']:
            if '/31_' not in name:
                continue
            with self.subTest(name=name):
                changed = copy.deepcopy(original)
                changed['sources_sha256'][name] = '0'*64
                self.assertEqual(parity.verify_sources(changed), [name])

    def test_wrong_marathon_reference_id_is_rejected_before_sql(self):
        reference = json.loads(parity.MARATHON_REFERENCE.read_text())
        reference['reference_id'] = 'captured-unreviewed-reference'
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'reference.json'
            path.write_text(json.dumps(reference))
            with patch.object(parity, 'MARATHON_REFERENCE', path), \
                 patch.object(parity.sys, 'argv', ['parity', '--with-marathon-anchor']), \
                 patch.object(parity, 'observe') as observe:
                with self.assertRaises(ValueError):
                    parity.main()
                observe.assert_not_called()

    def test_new_schema_never_silently_selects_new_reference(self):
        observed = json.loads(parity.MARATHON_REFERENCE.read_text())['expected']
        with patch.object(parity, 'observe', return_value=observed), \
             contextlib.redirect_stdout(io.StringIO()):
            with patch.object(parity.sys, 'argv', ['parity', '--with-session-start-atomic']):
                self.assertEqual(parity.main(), 1)
            with patch.object(parity.sys, 'argv', ['parity', '--with-marathon-anchor']):
                self.assertEqual(parity.main(), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
