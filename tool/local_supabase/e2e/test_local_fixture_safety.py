#!/usr/bin/env python3
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from uuid import uuid4

import create_exam_history_fixture as history
import i08_multiuser_fixture as multi
import local_fixture_api as local


class FixtureSafetyTests(unittest.TestCase):
    def test_remote_environment_rejected(self):
        for key in ['LOCAL_SUPABASE_URL', 'LOCAL_DB_URL']:
            with patch.dict(os.environ, {key: 'https://remote.invalid'}):
                with self.assertRaises(local.FixtureError):
                    local.require_local()

    def test_foreign_path_rejected_without_network(self):
        with patch.object(local.urllib.request, 'build_opener') as opener:
            with self.assertRaises(local.FixtureError):
                local.request('GET', 'https://remote.invalid/auth/v1/user')
            opener.assert_not_called()

    def test_nonqa_owner_rejected_before_database(self):
        with patch.object(local, 'sql') as query:
            with self.assertRaises(local.FixtureError):
                local.assert_qa_owner(str(uuid4()), 'personal@example.com')
            query.assert_not_called()

    def test_exact_allowlisted_owner_required(self):
        owner = str(uuid4())
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory)/'allow.json'
            file.write_text(json.dumps({'owners': [{'id': owner, 'email': 'e2e-sim-exam-test@pomosprint.local'}]}))
            with patch.object(history, 'assert_qa_owner') as validate:
                with self.assertRaises(local.FixtureError):
                    history.allow_owner(file, owner, 'e2e-sim-other@pomosprint.local')
                validate.assert_not_called()

    def test_existing_history_cannot_be_overwritten(self):
        with patch.object(history, 'allow_owner'), patch.object(history, 'sql', return_value='1') as query:
            with self.assertRaises(local.FixtureError):
                history.create(str(uuid4()), 'e2e-sim-exam-test@pomosprint.local', '/tmp/not-read.json')
            self.assertEqual(query.call_count, 1)
            self.assertTrue(query.call_args.args[0].startswith('select count(*)'))

    def test_wrong_fixture_marker_blocks_cleanup_manifest(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(multi, 'ROOT', Path(directory)):
            path = multi.manifest_path('test')
            multi.write_manifest(path, {'fixture': 'i08-local-only', 'run_id': 'test', 'accounts': [{
                'id': str(uuid4()), 'email': 'qa-i08-test-observer@pomosprint.local', 'role': 'observer',
            }]})
            with patch.object(multi, 'assert_qa_owner'), patch.object(multi, 'sql', return_value='another-run'):
                with self.assertRaises(local.FixtureError):
                    multi.load_manifest('test')

    def test_http_redirects_never_followed(self):
        self.assertIsNone(local.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://remote.invalid'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
