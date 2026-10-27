import io
import json
from datetime import datetime, timezone, timedelta
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch
import unittest
import urllib.parse
import urllib.error
from unittest.mock import MagicMock

import local_recovery as recovery

EMAIL = 'e2e-sim-recovery-unit@pomosprint.local'
TOKEN = 'a' * 64
JWT = 'header.payload.signature'
KEY = 'local-anon-key-only-for-test'
LINK = ('http://127.0.0.1:54321/auth/v1/verify?type=recovery&token=' + TOKEN +
        '&redirect_to=https%3A%2F%2Fpomosprint.app%2Freset-password.html')
USER = {'id': '11111111-2222-3333-4444-555555555555', 'email': EMAIL,
        'created_at': datetime.now(timezone.utc).isoformat()}


def message(email=EMAIL, link=LINK):
    return {'To': [{'Address': email}], 'HTML': '<a href="' + link + '">Reset</a>'}


class RecoveryTests(unittest.TestCase):
    def test_link_canonicalizes_to_literal_local_origin_and_local_return(self):
        link = recovery.recovery_link(message(), EMAIL)
        parsed = urllib.parse.urlsplit(link)
        self.assertEqual(parsed.netloc, '127.0.0.1:54321')
        self.assertEqual(parsed.path, '/auth/v1/verify')
        self.assertEqual(urllib.parse.parse_qs(parsed.query)['redirect_to'], ['http://127.0.0.1:3000'])

    def test_only_bounded_new_recovery_namespace_allowed(self):
        for value in ('user@example.com', 'e2e-sim-other-unit@pomosprint.local',
                      'e2e-sim-recovery-@pomosprint.local',
                      'e2e-sim-recovery-' + 'x' * 41 + '@pomosprint.local', None):
            with self.subTest(value=value), self.assertRaises(recovery.RecoveryError):
                recovery.recipient(value)

    def test_recipient_host_path_type_and_duplicates_rejected(self):
        cases = [message('e2e-sim-recovery-other@pomosprint.local')]
        for link in (LINK.replace('127.0.0.1', 'example.com', 1),
                     LINK.replace('/auth/v1/verify', '/auth/v1/user'),
                     LINK.replace('type=recovery', 'type=signup'),
                     LINK + '&token=' + TOKEN,
                     LINK.replace('pomosprint.app%2Freset-password.html', 'example.com')):
            cases.append(message(link=link))
        for value in cases:
            with self.subTest(value=value), self.assertRaises(recovery.RecoveryError):
                recovery.recovery_link(value, EMAIL)

    def test_redirect_never_accepts_external_or_signup_token(self):
        good = 'http://127.0.0.1:3000/#access_token=' + JWT + '&type=recovery'
        self.assertEqual(recovery.session_from_redirect(good), JWT)
        for value in (good.replace('127.0.0.1:3000', 'example.com'),
                      good.replace('type=recovery', 'type=signup'),
                      good.replace(JWT, 'not-a-jwt'), good + '&error=failed'):
            with self.assertRaises(recovery.RecoveryError):
                recovery.session_from_redirect(value)

    def _run(self, user):
        calls = []

        def auth(method, token, key, timeout, payload=None):
            calls.append((method, token, key, payload))
            return user

        with patch.object(recovery.mail, '_open_json', side_effect=[
                {'messages': [{'ID': 'safe-id', 'To': [{'Address': EMAIL}]}]}, message()]), \
                patch.object(recovery, '_verify', return_value=JWT), \
                patch.object(recovery, '_auth', side_effect=auth):
            try:
                result = recovery.reset_local_password(EMAIL, 'New-Password2026', KEY)
            except recovery.RecoveryError:
                return False, calls
        return result, calls

    def test_fresh_exact_owner_gets_one_password_update_without_logs(self):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            result, calls = self._run(USER)
        self.assertTrue(result)
        self.assertEqual([call[0] for call in calls], ['GET', 'PUT'])
        self.assertEqual(calls[-1][-1], {'password': 'New-Password2026'})
        self.assertEqual(output.getvalue(), '')

    def test_other_owner_never_receives_a_write(self):
        result, calls = self._run(dict(USER, email='e2e-sim-recovery-other@pomosprint.local'))
        self.assertFalse(result)
        self.assertEqual([call[0] for call in calls], ['GET'])

    def test_old_owner_never_receives_a_write(self):
        created = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
        result, calls = self._run(dict(USER, created_at=created))
        self.assertFalse(result)
        self.assertEqual([call[0] for call in calls], ['GET'])

    def test_invalid_request_never_touches_network(self):
        with patch.object(recovery.mail, '_open_json') as network:
            for password, key in [('weak', KEY), ('Good-Password1', '\n' + KEY), ('Good-Password1', None)]:
                with self.assertRaises(recovery.RecoveryError):
                    recovery.reset_local_password(EMAIL, password, key)
            network.assert_not_called()

    def test_verify_captures_redirect_without_requesting_it(self):
        location = 'http://127.0.0.1:3000/#access_token=' + JWT + '&type=recovery'
        opener = MagicMock()
        opener.open.side_effect = urllib.error.HTTPError(
            'local', 302, 'redirect', {'Location': location}, io.BytesIO())
        canonical = recovery.recovery_link(message(), EMAIL)
        with patch.object(recovery.urllib.request, 'build_opener', return_value=opener):
            self.assertEqual(recovery._verify(canonical, 1), JWT)
        opener.open.assert_called_once_with(canonical, timeout=1)

    def test_auth_request_is_literal_loopback_with_no_redirect_handler(self):
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value.read.return_value = json.dumps(USER).encode()
        with patch.object(recovery.urllib.request, 'build_opener', return_value=opener):
            self.assertEqual(recovery._auth('GET', JWT, KEY, 1), USER)
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, 'http://127.0.0.1:54321/auth/v1/user')
        self.assertEqual(request.get_method(), 'GET')


if __name__ == '__main__':
    unittest.main()
