#!/usr/bin/env python3
"""Namespace and existing-account guards; no database/network is contacted."""
import unittest
from unittest.mock import patch

import create_exam_qa_fixture_account as fixture
from local_fixture_api import FixtureError


class ExamQaFixtureAccountTests(unittest.TestCase):
    def test_only_bounded_exam_fixture_and_http_normal_namespaces_are_accepted(self):
        for namespace in ['exam-fixture', 'http-normal']:
            for suffix in ['a', 'night-w-ios18', 'a' * 40]:
                with self.subTest(namespace=namespace, suffix=suffix):
                    fixture.validate_fixture_email(
                        f'e2e-sim-{namespace}-{suffix}@pomosprint.local')

    def test_foreign_ambiguous_or_unbounded_email_is_rejected(self):
        invalid = [
            None, 42, '',
            'e2e-sim-http-normal-@pomosprint.local',
            'e2e-sim-http-normal-' + 'a' * 41 + '@pomosprint.local',
            'e2e-sim-exam-fixture-@pomosprint.local',
            'e2e-sim-exam-fixture-' + 'a' * 41 + '@pomosprint.local',
            'e2e-sim-other-a@pomosprint.local',
            'e2e-sim-http-normal-a@example.com',
            'e2e-sim-http-normal-a@pomosprint.local.example.com',
            'personal@pomosprint.local',
            'prefix-e2e-sim-http-normal-a@pomosprint.local',
            'e2e-sim-http-normal-A@pomosprint.local',
            'e2e-sim-http-normal-a.b@pomosprint.local',
            'e2e-sim-http-normal-a+b@pomosprint.local',
            'e2e-sim-http-normal-a@pomosprint.local\n',
            'e2e-sim-http-normal-a@pomosprint.local\r\nOther: value',
            "e2e-sim-http-normal-a';select-1@pomosprint.local",
        ]
        for email in invalid:
            with self.subTest(email=email):
                with self.assertRaises(FixtureError):
                    fixture.validate_fixture_email(email)

    def test_invalid_namespace_is_rejected_before_database_or_signup(self):
        with patch('sys.argv', ['fixture', '--email', 'personal@example.com']), \
                patch.object(fixture, 'sql') as query, \
                patch.object(fixture, 'request') as request:
            with self.assertRaises(FixtureError):
                fixture.main()
            query.assert_not_called()
            request.assert_not_called()

    def test_existing_accounts_in_either_namespace_are_never_modified(self):
        for namespace in ['exam-fixture', 'http-normal']:
            email = f'e2e-sim-{namespace}-existing@pomosprint.local'
            with self.subTest(namespace=namespace), \
                    patch('sys.argv', ['fixture', '--email', email]), \
                    patch.object(fixture, 'sql', return_value='1') as query, \
                    patch.object(fixture, 'request') as request, \
                    patch.object(fixture, 'rpc') as rpc, \
                    patch.object(fixture, 'create') as create:
                with self.assertRaisesRegex(FixtureError, 'Account already exists'):
                    fixture.main()
                self.assertEqual(query.call_count, 1)
                self.assertTrue(query.call_args.args[0].startswith('select count(*)'))
                request.assert_not_called()
                rpc.assert_not_called()
                create.assert_not_called()


if __name__ == '__main__':
    unittest.main(verbosity=2)
