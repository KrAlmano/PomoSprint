#!/usr/bin/env python3
"""Mock capture/resize processes only; generated PNGs are unit fixtures."""
import io
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import zlib
from contextlib import redirect_stderr
from unittest.mock import patch

import e2e_host


def png(width=1, height=1):
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
    return (e2e_host.PNG_SIGNATURE
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\x00\xff\x00\x00\xff'))
            + chunk(b'IEND', b''))


class ScreenshotHostTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.server = e2e_host.ThreadingHTTPServer(('127.0.0.1', 0), e2e_host.Handler)
        self.server.shot_dir = self.directory.name
        self.server.android_serial = 'emulator-5554'
        self.server.udid = None
        self.thread = threading.Thread(
            target=lambda: self.server.serve_forever(poll_interval=.01), daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}/shot?name=e2e-unit-shot'
        self.target = Path(self.directory.name)/'e2e-unit-shot.png'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def get(self, url=None):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with opener.open(url or self.url, timeout=2) as response:
                return response.status, response.read().decode()
        except urllib.error.HTTPError as response:
            return response.code, response.read().decode()

    def assert_no_partial_capture(self):
        self.assertEqual(list(Path(self.directory.name).glob('.capture-*')), [])

    def test_android_valid_capture_and_resize_are_required_before_publish(self):
        content = png()
        with patch.object(e2e_host.subprocess, 'run', side_effect=[
            subprocess.CompletedProcess([], 0, content, b''),
            subprocess.CompletedProcess([], 0, b'', b''),
        ]) as run:
            status, body = self.get()
        self.assertEqual(status, 200)
        self.assertTrue(body.endswith('e2e-unit-shot.png'))
        self.assertEqual(self.target.read_bytes(), content)
        self.assertEqual(e2e_host.png_dimensions(self.target), (1, 1))
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[0].kwargs['timeout'], 30)
        self.assertEqual(run.call_args_list[1].kwargs['timeout'], 60)
        self.assert_no_partial_capture()

    def test_ios_success_requires_the_new_capture_file(self):
        self.server.android_serial = None
        self.server.udid = '00000000-0000-0000-0000-000000000000'

        def execute(args, **kwargs):
            if args[0] == 'xcrun':
                Path(args[-1]).write_bytes(png())
            return subprocess.CompletedProcess(args, 0, b'', b'')

        with patch.object(e2e_host.subprocess, 'run', side_effect=execute):
            self.assertEqual(self.get()[0], 200)
        self.assertEqual(e2e_host.png_dimensions(self.target), (1, 1))
        self.assert_no_partial_capture()

    def test_rc_zero_empty_android_output_is_failure(self):
        with patch.object(e2e_host.subprocess, 'run', return_value=
                          subprocess.CompletedProcess([], 0, b'', b'')) as run:
            self.assertEqual(self.get(), (500, 'screenshot_invalid_png'))
        self.assertEqual(run.call_count, 1)
        self.assertFalse(self.target.exists())
        self.assert_no_partial_capture()

    def test_invalid_signature_dimensions_truncation_and_crc_are_failures(self):
        corrupt_crc = bytearray(png())
        corrupt_crc[20] ^= 1
        for content in [b'not a png', png(0, 1), png(1, 0), png(20000, 1),
                        png()[:33], png()[:-1], bytes(corrupt_crc)]:
            with self.subTest(size=len(content)), \
                    patch.object(e2e_host.subprocess, 'run', return_value=
                                 subprocess.CompletedProcess([], 0, content, b'')) as run:
                self.assertEqual(self.get(), (500, 'screenshot_invalid_png'))
                self.assertEqual(run.call_count, 1)
                self.assertFalse(self.target.exists())
                self.assert_no_partial_capture()

    def test_ios_rc_zero_without_file_cannot_reuse_previous_evidence(self):
        self.server.android_serial = None
        self.server.udid = '00000000-0000-0000-0000-000000000000'
        previous = png()
        self.target.write_bytes(previous)
        with patch.object(e2e_host.subprocess, 'run', return_value=
                          subprocess.CompletedProcess([], 0, b'', b'')):
            self.assertEqual(self.get(), (500, 'screenshot_invalid_png'))
        self.assertEqual(self.target.read_bytes(), previous)
        self.assert_no_partial_capture()

    def test_capture_nonzero_is_sanitized_and_does_not_run_resize(self):
        private = b'private-device-path Bearer secret-token'
        with redirect_stderr(io.StringIO()) as output, \
                patch.object(e2e_host.subprocess, 'run', return_value=
                             subprocess.CompletedProcess([], 1, b'', private)) as run:
            status, body = self.get()
        self.assertEqual((status, body), (500, 'screenshot_capture_failed'))
        self.assertNotIn('secret-token', body + output.getvalue())
        self.assertEqual(run.call_count, 1)
        self.assert_no_partial_capture()

    def test_capture_timeout_is_sanitized_for_both_devices(self):
        for serial in ['emulator-5554', None]:
            self.server.android_serial = serial
            self.server.udid = '00000000-0000-0000-0000-000000000000'
            with self.subTest(android=serial is not None), \
                    patch.object(e2e_host.subprocess, 'run', side_effect=
                                 subprocess.TimeoutExpired(['secret-path'], 30,
                                                           stderr=b'secret-token')):
                self.assertEqual(self.get(), (500, 'screenshot_capture_timeout'))
                self.assert_no_partial_capture()

    def test_resize_nonzero_does_not_publish_new_evidence(self):
        previous = png()
        self.target.write_bytes(previous)
        with patch.object(e2e_host.subprocess, 'run', side_effect=[
            subprocess.CompletedProcess([], 0, png(), b''),
            subprocess.CompletedProcess([], 1, b'', b'secret-token'),
        ]):
            self.assertEqual(self.get(), (500, 'screenshot_resize_failed'))
        self.assertEqual(self.target.read_bytes(), previous)
        self.assert_no_partial_capture()

    def test_resize_timeout_does_not_publish(self):
        with patch.object(e2e_host.subprocess, 'run', side_effect=[
            subprocess.CompletedProcess([], 0, png(), b''),
            subprocess.TimeoutExpired(['sips', 'secret-path'], 60,
                                      stderr=b'secret-token'),
        ]):
            self.assertEqual(self.get(), (500, 'screenshot_resize_timeout'))
        self.assertFalse(self.target.exists())
        self.assert_no_partial_capture()

    def test_rc_zero_resize_with_corrupt_file_is_failure(self):
        def execute(args, **kwargs):
            if args[0] == 'sips':
                Path(args[-1]).write_bytes(b'')
                return subprocess.CompletedProcess(args, 0, b'', b'')
            return subprocess.CompletedProcess(args, 0, png(), b'')

        with patch.object(e2e_host.subprocess, 'run', side_effect=execute):
            self.assertEqual(self.get(), (500, 'screenshot_invalid_png'))
        self.assertFalse(self.target.exists())
        self.assert_no_partial_capture()

    def test_process_launch_error_returns_fixed_code(self):
        with patch.object(e2e_host.subprocess, 'run', side_effect=OSError('secret-path')):
            self.assertEqual(self.get(), (500, 'screenshot_io_error'))
        self.assert_no_partial_capture()

    def test_invalid_name_is_rejected_before_any_command(self):
        with patch.object(e2e_host.subprocess, 'run') as run:
            self.assertEqual(self.get(self.url + '%0A')[0], 400)
            self.assertEqual(self.get(self.url.replace('e2e-unit-shot', '../elsewhere'))[0], 400)
        run.assert_not_called()


if __name__ == '__main__':
    unittest.main(verbosity=2)
