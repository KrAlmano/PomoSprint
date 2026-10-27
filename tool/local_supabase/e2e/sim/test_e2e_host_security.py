"""Real ephemeral HTTP server; every SQL/device/mail action stays mocked."""
import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import e2e_host


class HostSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.server = e2e_host.ThreadingHTTPServer(('127.0.0.1', 0), e2e_host.Handler)
        self.server.android_serial = 'emulator-5554'
        self.server.udid = None
        self.server.allow_api_outage = True
        self.server.shot_dir = self.temporary.name
        self.server.psql_log = str(Path(self.temporary.name) / 'psql.log')
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close_server)
        self.run = self.enterContext(patch.object(e2e_host.subprocess, 'run',
            return_value=SimpleNamespace(returncode=0, stdout='1\n', stderr='')))
        self.capture = self.enterContext(patch.object(e2e_host, 'capture_screenshot',
            return_value='test/e2e-security.png'))
        self.confirm = self.enterContext(patch.object(e2e_host, 'confirm_local_email', return_value=True))
        self.recover = self.enterContext(patch.object(e2e_host, 'reset_local_password', return_value=True))
        self.enterContext(patch.object(e2e_host.Handler, 'log_message'))

    def close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, method, path, body=None, *, headers=None, host=True, duplicate_host=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=3)
        self.addCleanup(connection.close)
        payload = b'' if body is None else body.encode()
        connection.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
        if host is not None:
            connection.putheader('Host', f'127.0.0.1:{self.port}' if host is True else host)
        if duplicate_host:
            connection.putheader('Host', duplicate_host)
        for key, value in (headers or {}).items():
            connection.putheader(key, value)
        if body is not None:
            connection.putheader('Content-Length', str(len(payload)))
        connection.endheaders(payload)
        response = connection.getresponse()
        return response.status, response.read().decode()

    def assert_no_action(self):
        # Do not let Mock's failure repr print the captured subprocess env or
        # mail/request payload. Counts are enough to prove the unsafe action.
        self.assertEqual(self.run.call_count, 0)
        self.assertEqual(self.capture.call_count, 0)
        self.assertEqual(self.confirm.call_count, 0)
        self.assertEqual(self.recover.call_count, 0)

    def test_browser_origin_cannot_post_sql(self):
        for origin in ['https://example.invalid', 'null']:
            with self.subTest(origin=origin):
                status, _ = self.request('POST', '/psql', 'SELECT 1',
                    headers={'Origin': origin, 'Content-Type': 'text/plain'})
                self.assertEqual(status, 403)
        self.assert_no_action()

    def test_native_plain_text_sql_remains_accepted_and_read_only(self):
        status, body = self.request('POST', '/psql', 'SELECT 1',
            headers={'Content-Type': 'text/plain; charset=utf-8'})
        self.assertEqual((status, body), (200, '1'))
        args, kwargs = self.run.call_args
        self.assertEqual(args[0][-1], 'SELECT 1')
        self.assertIn('127.0.0.1:54322/postgres', args[0][1])
        self.assertEqual(kwargs['env']['PGOPTIONS'], '-c default_transaction_read_only=on')

    def test_native_health(self):
        self.assertEqual(self.request('GET', '/health'), (200, 'ok'))
        self.assert_no_action()

    def test_native_screenshot_flow(self):
        self.assertEqual(self.request('GET', '/shot?name=e2e-security'),
                         (200, 'test/e2e-security.png'))
        self.capture.assert_called_once_with(self.server, 'e2e-security')
        self.run.assert_not_called()

    def test_native_confirmation_flow(self):
        status, body = self.request('POST', '/confirm-email',
            json.dumps({'email':'e2e-sim-security@pomosprint.local'}),
            headers={'Content-Type':'application/json'})
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {'confirmed':True})
        self.confirm.assert_called_once_with('e2e-sim-security@pomosprint.local')

    def test_native_device_and_local_api_actions(self):
        self.assertEqual(self.request('POST', '/android-notifications')[0], 200)
        self.assertEqual(self.request('POST', '/local-api', 'stop')[0], 200)
        self.assertEqual(self.run.call_count, 2)

    def test_explicit_local_host_aliases(self):
        for host in ['127.0.0.1', 'localhost', '10.0.2.2']:
            with self.subTest(host=host):
                self.assertEqual(self.request('GET', '/health', host=f'{host}:{self.port}'), (200, 'ok'))

    def test_browser_get_screenshot_rejected(self):
        self.assertEqual(self.request('GET', '/shot?name=e2e-security',
            headers={'Origin':'https://example.invalid'})[0], 403)
        self.assert_no_action()

    def test_browser_fetch_metadata_rejected_for_get_and_post(self):
        for method, path, body in [('GET','/health',None), ('POST','/psql','SELECT 1')]:
            for site in ['cross-site', 'same-origin', 'none']:
                with self.subTest(method=method, site=site):
                    self.assertEqual(self.request(method, path, body,
                        headers={'Sec-Fetch-Site':site})[0], 403)
        self.assert_no_action()

    def test_other_browser_fetch_metadata_also_rejected(self):
        self.assertEqual(self.request('GET', '/health',
            headers={'Sec-Fetch-Mode':'no-cors'})[0], 403)
        self.assert_no_action()

    def test_origin_guards_all_privileged_posts(self):
        for path in ['/psql','/android-notifications','/local-api','/confirm-email','/recover-password']:
            with self.subTest(path=path):
                self.assertEqual(self.request('POST', path, 'SELECT 1',
                    headers={'Origin':'null', 'Content-Type':'text/plain'})[0], 403)
        self.assert_no_action()

    def test_origin_rejects_confirmation_before_parsing_json(self):
        self.assertEqual(self.request('POST', '/confirm-email',
            json.dumps({'email':'e2e-sim-security@pomosprint.local'}),
            headers={'Origin':'https://example.invalid','Content-Type':'application/json'})[0],403)
        self.assert_no_action()

    def test_dns_rebinding_host_rejected(self):
        for host in [f'example.invalid:{self.port}', f'localhost.example.invalid:{self.port}',
                     f'127.0.0.1.example.invalid:{self.port}', f'127.0.0.1:{self.port}@example.invalid']:
            with self.subTest(host=host):
                self.assertEqual(self.request('GET', '/health', host=host)[0],403)
        self.assert_no_action()

    def test_wrong_or_omitted_listening_port_rejected(self):
        for host in ['localhost', f'127.0.0.1:{self.port + 1}', '127.0.0.1:0']:
            with self.subTest(host=host):
                self.assertEqual(self.request('POST','/psql','SELECT 1',host=host)[0],403)
        self.assert_no_action()

    def test_missing_and_duplicate_host_rejected(self):
        self.assertEqual(self.request('GET','/health',host=None)[0],403)
        self.assertEqual(self.request('GET','/health',duplicate_host=f'localhost:{self.port}')[0],403)
        self.assert_no_action()

    def test_rebinding_host_cannot_confirm_email(self):
        self.assertEqual(self.request('POST','/confirm-email','{}',
            headers={'Content-Type':'application/json'},host=f'example.invalid:{self.port}')[0],403)
        self.assert_no_action()


if __name__ == '__main__':
    unittest.main()
