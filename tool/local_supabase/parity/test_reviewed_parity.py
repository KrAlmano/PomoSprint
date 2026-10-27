#!/usr/bin/env python3
"""Negative checks for the explicit, fail-closed local review reference."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import unittest
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
