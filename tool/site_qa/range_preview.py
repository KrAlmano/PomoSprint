#!/usr/bin/env python3
"""Internal bounded GET/HEAD Range handler for the local site QA preview."""
from __future__ import annotations

import hashlib
import mimetypes
import os
from pathlib import Path
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

ROOT = (Path(__file__).resolve().parents[2] / 'landing').resolve()
CSP = "default-src 'self'; connect-src 'self'; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self'; font-src 'self'; form-action 'self'"
CONFIG = b'window.PomoSupabase=null;'
MAX_SAFE_INTEGER = 9007199254740991


def single_range(value: str | None, size: int):
    """None means ignore malformed/unsupported Range; tuple may be unsatisfiable."""
    if value is None or len(value) > 100:
        return None
    match = re.fullmatch(r'bytes=(\d*)-(\d*)', value.strip(), re.I)
    if not match or not any(match.groups()):
        return None
    first, last = (int(v) if v else None for v in match.groups())
    if any(v is not None and v > MAX_SAFE_INTEGER for v in (first, last)):
        return None
    if first is not None and last is not None and last < first:
        return None
    start = max(0, size - last) if first is None else first
    end = size - 1 if first is None or last is None else min(last, size - 1)
    return start, end


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, *_args):
        pass

    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def _empty(self, status):
        self.send_response(status)
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _valid_host(self):
        hosts = self.headers.get_all('Host', [])
        port = self.server.server_port
        return len(hosts) == 1 and hosts[0].lower() in {
            f'127.0.0.1:{port}', f'localhost:{port}',
        }

    def do_GET(self):
        self._serve(head=False)

    def do_HEAD(self):
        self._serve(head=True)

    def _serve(self, *, head):
        if not self._valid_host():
            self._empty(403)
            return
        try:
            parsed = urlsplit(self.path)
            if parsed.scheme or parsed.netloc:
                self._empty(400)
                return
            path = unquote(parsed.path)
            if '\x00' in path or '\\' in path:
                self._empty(404)
                return
            if path == '/js/config.js':
                self.send_response(200)
                self.send_header('Content-Type', 'application/javascript; charset=utf-8')
                self.send_header('Content-Length', str(len(CONFIG)))
                self.end_headers()
                if not head:
                    self.wfile.write(CONFIG)
                return
            if any(part.startswith('.') for part in path.split('/') if part):
                self._empty(404)
                return
            if path in ('/', '/en/'):
                path += 'index.html'
            elif not Path(path).suffix:
                path += '.html'
            target = (ROOT / path.lstrip('/')).resolve()
            if not target.is_relative_to(ROOT) or not target.is_file():
                self._empty(404)
                return
            with target.open('rb') as stream:
                stat = os.fstat(stream.fileno())
                size = stat.st_size
                media = target.suffix.lower() == '.mp4'
                etag = None
                if media:
                    etag = '"' + hashlib.file_digest(stream, 'sha256').hexdigest() + '"'
                    stream.seek(0)
                selected = None
                if media and not head:
                    if_range = self.headers.get('If-Range')
                    if if_range is None or if_range == etag:
                        selected = single_range(self.headers.get('Range'), size)
                if selected is not None:
                    start, end = selected
                    if start >= size or end < start:
                        self.send_response(416)
                        self.send_header('Accept-Ranges', 'bytes')
                        self.send_header('Content-Range', f'bytes */{size}')
                        self.send_header('Content-Length', '0')
                        self.send_header('ETag', etag)
                        self.end_headers()
                        return
                    status, length = 206, end - start + 1
                else:
                    start, end, status, length = 0, size - 1, 200, size
                self.send_response(status)
                self.send_header('Content-Type', 'video/mp4' if media else
                                 (mimetypes.guess_type(target.name)[0] or 'application/octet-stream'))
                self.send_header('Content-Length', str(length))
                self.send_header('Last-Modified', self.date_time_string(stat.st_mtime))
                if media:
                    self.send_header('Accept-Ranges', 'bytes')
                    self.send_header('ETag', etag)
                if status == 206:
                    self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
                self.end_headers()
                if head:
                    return
                stream.seek(start)
                remaining = length
                while remaining:
                    chunk = stream.read(min(65536, remaining))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    remaining -= len(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except OSError:
            self._empty(404)
