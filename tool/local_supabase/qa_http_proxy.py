#!/usr/bin/env python3
"""Loopback-only REST fault proxy; no request, header, body or token logging."""

import argparse
import http.client
import json
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

LOOPBACK = "127.0.0.1"
UPSTREAM_PORT = 54321  # Deliberately not configurable from the CLI/request.
BODY_LIMIT = 4 * 1024 * 1024
RESPONSE_LIMIT = 32 * 1024 * 1024
HOP_HEADERS = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade", "host", "content-length",
    "proxy-connection",
}


class ProxyState:
    def __init__(self, available=True):
        self._lock = threading.Lock()
        self.available = available
        self.generation = 0
        self.requests = 0
        self.rejected = 0
        self._sockets = set()

    def snapshot(self):
        with self._lock:
            return {"available": self.available, "requests": self.requests,
                    "rejected": self.rejected, "active": len(self._sockets)}

    def begin(self):
        with self._lock:
            self.requests += 1
            if not self.available:
                self.rejected += 1
                return None
            return self.generation

    def attach(self, upstream, generation):
        with self._lock:
            if not self.available or generation != self.generation:
                return False
            self._sockets.add(upstream)
            return True

    def detach(self, upstream):
        with self._lock:
            self._sockets.discard(upstream)

    def current(self, generation):
        with self._lock:
            return self.available and generation == self.generation

    def set_available(self, available):
        with self._lock:
            if available == self.available:
                return
            self.available = available
            self.generation += 1
            sockets = list(self._sockets) if not available else []
        for upstream in sockets:
            try:
                upstream.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                upstream.close()
            except OSError:
                pass


class _Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        # BaseServer's traceback can include request data in exception text.
        pass


class _QuietHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "LocalQaProxy"
    sys_version = ""

    def log_message(self, *args):
        pass

    def _reply(self, status, payload):
        data = json.dumps(payload, separators=(",", ":")).encode()
        self.close_connection = True
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(data)
        except OSError:
            pass

    def _body(self, maximum):
        lengths = self.headers.get_all("Content-Length", [])
        if self.headers.get("Transfer-Encoding"):
            # Native REST requests have known lengths. Reject unsupported
            # framing rather than risk request smuggling or an unbounded read.
            raise ValueError("unsupported_framing")
        if len(lengths) > 1 or (lengths and not lengths[0].isdigit()):
            raise ValueError("invalid_length")
        length = int(lengths[0]) if lengths else 0
        if length > maximum:
            raise OverflowError
        self.connection.settimeout(10)
        data = self.rfile.read(length)
        if len(data) != length:
            raise ValueError("incomplete_body")
        return data

    def _origin_path(self):
        if not self.path.startswith("/") or self.path.startswith("//"):
            return False
        try:
            parsed = urlsplit(self.path)
        except ValueError:
            return False
        return not parsed.scheme and not parsed.netloc and not parsed.fragment


class ProxyHandler(_QuietHandler):
    def _proxy(self):
        if not self._origin_path() or self.headers.get("Upgrade"):
            return self._reply(400, {"error": "unsupported_request"})
        generation = self.server.state.begin()
        if generation is None:
            return self._reply(503, {"error": "qa_transport_unavailable"})
        try:
            body = self._body(BODY_LIMIT)
        except OverflowError:
            return self._reply(413, {"error": "request_too_large"})
        except (ValueError, OSError):
            return self._reply(400, {"error": "invalid_request"})

        connection_tokens = {
            token.strip().lower() for token in self.headers.get("Connection", "").split(",")
        }
        blocked = HOP_HEADERS | connection_tokens
        headers = {key: value for key, value in self.headers.items()
                   if key.lower() not in blocked}
        headers["Host"] = f"{LOOPBACK}:{self.server.upstream_port}"
        headers["Connection"] = "close"
        if body or self.command in {"POST", "PUT", "PATCH"}:
            headers["Content-Length"] = str(len(body))
        upstream = http.client.HTTPConnection(LOOPBACK, self.server.upstream_port, timeout=20)
        upstream_socket = None
        try:
            upstream.connect()
            upstream_socket = upstream.sock
            if not self.server.state.attach(upstream_socket, generation):
                return self._reply(503, {"error": "qa_transport_unavailable"})
            upstream.request(self.command, self.path, body=body or None, headers=headers)
            response = upstream.getresponse()
            data = response.read(RESPONSE_LIMIT + 1)
            if len(data) > RESPONSE_LIMIT:
                return self._reply(502, {"error": "upstream_response_too_large"})
            if not self.server.state.current(generation):
                return self._reply(503, {"error": "qa_transport_unavailable"})
            response_connection = {
                token.strip().lower() for token in response.getheader("Connection", "").split(",")
            }
            self.close_connection = True
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in HOP_HEADERS | response_connection:
                    self.send_header(key, value)
            # HEAD's Content-Length describes GET's representation, not the
            # deliberately absent response body. Preserve that metadata.
            length = response.getheader("Content-Length") if self.command == "HEAD" else str(len(data))
            if length and length.isdigit():
                self.send_header("Content-Length", length)
            self.send_header("Connection", "close")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(data)
        except (TimeoutError, socket.timeout):
            self._reply(504 if self.server.state.current(generation) else 503,
                        {"error": "upstream_timeout" if self.server.state.current(generation)
                         else "qa_transport_unavailable"})
        except (OSError, http.client.HTTPException):
            self._reply(502 if self.server.state.current(generation) else 503,
                        {"error": "upstream_unavailable" if self.server.state.current(generation)
                         else "qa_transport_unavailable"})
        finally:
            if upstream_socket is not None:
                self.server.state.detach(upstream_socket)
            upstream.close()

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_HEAD = _proxy

    def do_CONNECT(self):
        self._reply(405, {"error": "unsupported_method"})

    do_TRACE = do_CONNECT


class AdminHandler(_QuietHandler):
    def do_GET(self):
        if self.path not in {"/health", "/availability"}:
            return self._reply(404, {"error": "not_found"})
        self._reply(200, self.server.state.snapshot())

    def do_POST(self):
        if self.path != "/availability":
            return self._reply(404, {"error": "not_found"})
        if self.headers.get("Origin") is not None:
            return self._reply(403, {"error": "browser_origin_forbidden"})
        if self.headers.get_content_type() != "application/json":
            return self._reply(415, {"error": "json_required"})
        try:
            value = json.loads(self._body(1024))
            if not isinstance(value, dict) or set(value) != {"available"} or type(value["available"]) is not bool:
                raise ValueError
        except (ValueError, OverflowError, OSError):
            return self._reply(400, {"error": "invalid_request"})
        self.server.state.set_available(value["available"])
        self._reply(200, self.server.state.snapshot())


def create_servers(port=54325, admin_port=54326, *, upstream_port=UPSTREAM_PORT):
    """The optional numeric port is a loopback-only unit-test seam, never a host."""
    if not 0 < upstream_port <= 65535:
        raise ValueError("invalid upstream port")
    state = ProxyState()
    proxy = _Server((LOOPBACK, port), ProxyHandler)
    try:
        admin = _Server((LOOPBACK, admin_port), AdminHandler)
    except BaseException:
        proxy.server_close()
        raise
    proxy.state = admin.state = state
    proxy.upstream_port = upstream_port
    return proxy, admin


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()  # No configurable external bind or upstream.
    proxy, admin = create_servers()
    threads = [threading.Thread(target=server.serve_forever, daemon=True)
               for server in (proxy, admin)]
    for thread in threads:
        thread.start()
    print("QA REST proxy 127.0.0.1:54325 -> 127.0.0.1:54321; admin 127.0.0.1:54326", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        proxy.state.set_available(False)
        for server in (proxy, admin):
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
