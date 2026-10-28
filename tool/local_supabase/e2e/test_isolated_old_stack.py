"""Offline guard tests; no Docker, SQL, hosted services or actual credentials."""
import base64
import hashlib
import hmac
import http.client
import json
from pathlib import Path
import sys
import threading
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import isolated_old_stack as old


def token(**changes):
    encode = lambda x: base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
    a = encode({'alg': 'HS256', 'typ': 'JWT'})
    b = encode({'sub': '00000000-0000-4000-8000-000000000008', 'role': 'authenticated', 'exp': int(time.time())+120, **changes})
    c = base64.urlsafe_b64encode(hmac.new(old.PUBLIC_DEMO_SECRET.encode(), f'{a}.{b}'.encode(), hashlib.sha256).digest()).decode().rstrip('=')
    return f'{a}.{b}.{c}'


class Guards(unittest.TestCase):
    def test_database_allowlist_precedes_execution(self):
        with patch.object(old, 'command') as run:
            for name in ['postgres.evil', 'hosted', old.CLONE+';', '../../postgres']:
                with self.assertRaises(old.GuardError):
                    old.query(name, 'select 1')
            run.assert_not_called()

    def test_route_canonicalization(self):
        for route in ['https://example.test/auth/v1/', '//example.test/a', '/rest/v1/../auth', '/rest/v1/%2e%2e/foo', '/rest/v1/%252e%252e/foo', '/rest/v1/%5cfoo', '/rest/v1/%0afoo', '/rest/v1//evil', '/rest/v1/foo#fragment']:
            with self.subTest(route=route), self.assertRaises(old.GuardError):
                old.safe_path(route)
        self.assertEqual(old.safe_path('/rest/v1/profiles?id=eq.test')[1], '/rest/v1/profiles')

    def test_owner_signature_expiry_and_role(self):
        self.assertEqual(old.token_owner('Bearer '+token()), '00000000-0000-4000-8000-000000000008')
        for value in ['Bearer '+token(role='anon'), 'Bearer '+token(exp=0), 'Bearer '+token(sub='not-uuid'), 'Bearer '+token()+'x', '', 'Basic '+token()]:
            with self.subTest(value=value[:20]), self.assertRaises(old.GuardError):
                old.token_owner(value)

    def test_owner_verification_requires_fresh_named_qa(self):
        with patch.object(old, 'query', return_value='0') as sql:
            with self.assertRaises(old.GuardError):
                old.owner_verification('00000000-0000-4000-8000-000000000008')
            self.assertEqual(sql.call_count, 1)
            self.assertIn('e2e-sim-old-', sql.call_args.args[1])
            self.assertEqual(sql.call_args.args[0], old.CLONE)


class GatewayGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = old.ThreadingHTTPServer(('127.0.0.1', 0), old.Gateway)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(2)

    def request(self, method, route, headers=None, body=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_address[1], timeout=3)
        try:
            connection.request(method, route, body=body, headers={'Host': f'127.0.0.1:{old.API_PORT}', 'Connection': 'close', **(headers or {})})
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def test_health_is_local_scope_only(self):
        status, body = self.request('GET', '/health')
        self.assertEqual(status, 200)
        self.assertEqual(body['database'], old.CLONE)

    def test_foreign_host_origin_fetch_are_rejected(self):
        for headers in [{'Host': 'attacker.test'}, {'Origin': 'https://attacker.test'}, {'Origin': 'null'}, {'Sec-Fetch-Site': 'cross-site'}]:
            with self.subTest(headers=headers):
                self.assertEqual(self.request('GET', '/health', headers)[0], 403)

    def test_body_limit_before_upstream_read(self):
        with patch.object(old, 'read_url') as request:
            status, _ = self.request('POST', '/auth/v1/signup', {'Content-Length': str(old.MAX_BODY+1)})
            self.assertEqual(status, 413)
            request.assert_not_called()

    def test_no_arbitrary_sql_or_owner_query_route(self):
        with patch.object(old, 'owner_verification') as verify:
            self.assertEqual(self.request('POST', '/psql', body='delete from profiles')[0], 404)
            self.assertEqual(self.request('GET', '/qa/v1/verify?owner=someone')[0], 403)
            verify.assert_not_called()

    def test_readonly_owner_comes_only_from_validated_token(self):
        with patch.object(old, 'owner_verification', return_value={'owner': 'fixture'}) as verify:
            status, body = self.request('GET', '/qa/v1/verify', {'Authorization': 'Bearer '+token()})
            self.assertEqual(status, 200)
            self.assertEqual(body['owner'], 'fixture')
            verify.assert_called_once_with('00000000-0000-4000-8000-000000000008')
        self.assertEqual(self.request('GET', '/qa/v1/verify')[0], 403)


if __name__ == '__main__':
    unittest.main()
