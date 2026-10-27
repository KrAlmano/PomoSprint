import concurrent.futures
import contextlib
import http.client
import io
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from qa_http_proxy import BODY_LIMIT, create_servers


class EchoHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    entered = threading.Event()
    release = threading.Event()
    calls = 0

    def log_message(self, *args):
        pass

    def do_POST(self):
        type(self).calls += 1
        if self.path == "/slow":
            self.entered.set()
            self.release.wait(3)
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        data = json.dumps({"body": body.decode(), "authorization": self.headers.get("Authorization"),
                           "connection_only": self.headers.get("X-Connection-Only"), "path": self.path}).encode()
        try:
            self.send_response(201)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Set-Cookie", "one=1")
            self.send_header("Set-Cookie", "two=2")
            self.end_headers()
            self.wfile.write(data)
        except OSError:
            pass

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", "123")
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        self.wfile.write(b"2\r\nhe\r\n3\r\nllo\r\n0\r\n\r\n")
        self.wfile.flush()


class ProxyTests(unittest.TestCase):
    def setUp(self):
        EchoHandler.entered.clear()
        EchoHandler.release.clear()
        EchoHandler.calls = 0
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), EchoHandler)
        self.upstream.daemon_threads = True
        self.proxy, self.admin = create_servers(0, 0, upstream_port=self.upstream.server_port)
        self.servers = (self.upstream, self.proxy, self.admin)
        for server in self.servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()

    def tearDown(self):
        EchoHandler.release.set()
        self.proxy.state.set_available(False)
        for server in self.servers:
            server.shutdown()
            server.server_close()

    def request(self, method="POST", path="/rest/v1/rpc/test?limit=1", body=b'{}', headers=None, admin=False):
        server = self.admin if admin else self.proxy
        client = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=4)
        try:
            client.request(method, path, body=body, headers=headers or {})
            response = client.getresponse()
            return response.status, response.read(), response.getheaders()
        finally:
            client.close()

    def switch(self, value):
        status, body, _ = self.request(path="/availability", body=json.dumps({"available": value}), headers={"Content-Type": "application/json"}, admin=True)
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["available"], value)

    def test_rest_passthrough_and_no_credential_logging(self):
        output = io.StringIO()
        with contextlib.redirect_stderr(output), contextlib.redirect_stdout(output):
            status, data, headers = self.request(body=b'{"private":"payload"}', headers={
                "Authorization": "Bearer PRIVATE-TOKEN", "Connection": "X-Connection-Only",
                "X-Connection-Only": "must-not-forward",
            })
        self.assertEqual(status, 201)
        payload = json.loads(data)
        self.assertEqual(payload["body"], '{"private":"payload"}')
        self.assertEqual(payload["authorization"], "Bearer PRIVATE-TOKEN")
        self.assertIsNone(payload["connection_only"])
        self.assertEqual(payload["path"], "/rest/v1/rpc/test?limit=1")
        self.assertEqual([value for name, value in headers if name.lower() == "set-cookie"], ["one=1", "two=2"])
        self.assertEqual(output.getvalue(), "")

    def test_offline_blocks_only_proxy_and_recovery_works(self):
        self.switch(False)
        status, body, _ = self.request()
        self.assertEqual(status, 503)
        self.assertEqual(json.loads(body), {"error": "qa_transport_unavailable"})
        self.assertEqual(EchoHandler.calls, 0)
        direct = http.client.HTTPConnection("127.0.0.1", self.upstream.server_port)
        direct.request("POST", "/direct", body=b'{}')
        response = direct.getresponse()
        self.assertEqual(response.status, 201)
        response.read()
        direct.close()
        self.switch(True)
        self.assertEqual(self.request()[0], 201)

    def test_in_flight_request_is_cut_off_without_waiting_for_upstream(self):
        with concurrent.futures.ThreadPoolExecutor() as pool:
            future = pool.submit(self.request, path="/slow")
            self.assertTrue(EchoHandler.entered.wait(1))
            self.switch(False)
            status, body, _ = future.result(timeout=1)
            self.assertEqual(status, 503)
            self.assertEqual(json.loads(body)["error"], "qa_transport_unavailable")

    def test_absolute_url_connect_upgrade_and_large_body_are_rejected(self):
        self.assertEqual(self.request(path="http://example.invalid/private")[0], 400)
        self.assertEqual(self.request(method="CONNECT", path="example.invalid:443")[0], 405)
        self.assertEqual(self.request(headers={"Upgrade": "websocket"})[0], 400)
        self.assertEqual(self.request(body=b"", headers={"Content-Length": str(BODY_LIMIT + 1)})[0], 413)
        self.assertEqual(EchoHandler.calls, 0)

    def test_head_preserves_get_representation_length(self):
        status, body, headers = self.request(method="HEAD", body=None)
        self.assertEqual(status, 200)
        self.assertEqual(body, b"")
        self.assertIn(("Content-Length", "123"), headers)

    def test_chunked_upstream_response_is_reframed_correctly(self):
        status, body, headers = self.request(method="GET", body=None)
        self.assertEqual((status, body), (200, b"hello"))
        self.assertIn(("Content-Length", "5"), headers)
        self.assertNotIn("transfer-encoding", {key.lower() for key, _ in headers})

    def test_unsupported_request_framing_is_rejected(self):
        status, _, _ = self.request(body=b"0\r\n\r\n", headers={"Transfer-Encoding": "chunked"})
        self.assertEqual(status, 400)
        self.assertEqual(EchoHandler.calls, 0)

    def test_admin_has_no_proxy_route_or_private_data(self):
        status, body, _ = self.request(method="GET", path="/health", body=None, admin=True)
        self.assertEqual(status, 200)
        self.assertEqual(set(json.loads(body)), {"available", "requests", "rejected", "active"})
        self.assertEqual(self.request(path="/availability?token=private", admin=True)[0], 404)
        self.assertEqual(self.request(path="/availability", body='{"available":"false"}', headers={"Content-Type": "application/json"}, admin=True)[0], 400)

    def test_browser_origin_and_simple_post_cannot_toggle_admin(self):
        payload = '{"available":false}'
        self.assertEqual(self.request(path="/availability", body=payload, admin=True)[0], 415)
        self.assertEqual(self.request(path="/availability", body=payload, headers={
            "Content-Type": "application/json", "Origin": "https://example.invalid",
        }, admin=True)[0], 403)
        self.assertTrue(self.proxy.state.snapshot()["available"])


if __name__ == "__main__":
    unittest.main()
