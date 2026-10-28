"""No native, SQL or network upstream actions: fixed adapter safety guards."""
import http.client
from pathlib import Path
import tempfile
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import exam32_host as adapter


class Exam32HostTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.server = adapter.host.ThreadingHTTPServer(('127.0.0.1', 0), adapter.Handler)
        self.server.psql_log = str(Path(self.directory.name) / 'sql.log')
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close)
        self.run = self.enterContext(patch.object(adapter.host.subprocess, 'run',
            return_value=SimpleNamespace(returncode=0, stdout='1', stderr='')))
        self.enterContext(patch.object(adapter.host.Handler, 'log_message'))
        self.enterContext(patch.object(adapter.host, 'DB_URL',
            'postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_review32_dus'))

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, method, path, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=3)
        self.addCleanup(connection.close)
        connection.request(method, path, body='SELECT 1' if method == 'POST' else None,
                           headers=headers or {})
        response = connection.getresponse()
        return response.status, response.read().decode()

    def test_only_named_fixed_profiles_and_devices(self):
        self.assertEqual(adapter.DATABASES, {
            'review': 'pomosprint_review32_dus', 'site': 'pomosprint_site32_dus',
            'kpss': 'pomosprint_review32_kpss'})
        self.assertEqual(adapter.PORTS['site'], {'ios': 54379})
        self.assertEqual(adapter.PORTS['kpss'], {'ios': 54409})

    def test_main_database_or_mail_routes_cannot_be_called(self):
        for method, path in [('GET', '/verify-reports?owner=anything'),
                             ('POST', '/confirm-email'), ('POST', '/reset-password'),
                             ('POST', '/local-api'), ('POST', '/android-notifications')]:
            with self.subTest(path=path):
                self.assertEqual(self.request(method, path)[0], 403)
        self.run.assert_not_called()

    def test_browser_sql_is_rejected(self):
        self.assertEqual(self.request('POST', '/psql', {'Origin': 'null'})[0], 403)
        self.run.assert_not_called()

    def test_native_sql_is_read_only_and_fixed_to_review_database(self):
        self.assertEqual(self.request('POST', '/psql'), (200, '1'))
        args, kwargs = self.run.call_args
        self.assertTrue(args[0][1].endswith('/pomosprint_review32_dus'))
        self.assertEqual(kwargs['env']['PGOPTIONS'], '-c default_transaction_read_only=on')

    def test_output_traversal_and_external_paths_are_rejected(self):
        for path in [adapter.ROOT / 'build/../../outside', '/tmp/external-shots']:
            with self.subTest(path=str(path)):
                with self.assertRaises(ValueError):
                    adapter.output_directory(path)

    def test_output_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=adapter.ROOT / 'build') as directory:
            link = Path(directory) / 'redirect'
            link.symlink_to('/tmp', target_is_directory=True)
            with self.assertRaises(ValueError):
                adapter.output_directory(link / 'shots')


if __name__ == '__main__':
    unittest.main()
