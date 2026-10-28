#!/usr/bin/env python3
"""Portable local-only site QA preview. No live API/config/form operation.

Run python3 tool/site_qa/server.py --port 8799. Port0 is for isolated HTTP tests.
This server reads landing assets and injects an observation-only probe in its
responses; it never changes product files or stores browser results.
"""
from __future__ import annotations

import argparse
import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

QA = Path(__file__).resolve().parent
ROOT = (QA.parents[1] / 'landing').resolve()
ALLOWED_PORTS = {0, 8797, 8798, 8799}
CSP = ("default-src 'self'; connect-src 'self'; script-src 'self'; img-src 'self'; "
       "media-src 'self'; font-src 'self'; style-src 'self'; frame-src 'self'; "
       "frame-ancestors 'self'; object-src 'none'; base-uri 'none'; form-action 'none'")
ALLOWED_SUFFIXES = {'.html', '.css', '.js', '.png', '.webp', '.jpg', '.jpeg',
                    '.svg', '.ico', '.mp4', '.woff', '.woff2', '.ttf', '.otf', '.txt', '.xml'}
QA_FILES = {'/__qa': ('qa.html', 'text/html; charset=utf-8'),
            '/__qa/qa.css': ('qa.css', 'text/css; charset=utf-8'),
            '/__qa/qa.js': ('qa.js', 'application/javascript; charset=utf-8'),
            '/__qa/probe.js': ('probe.js', 'application/javascript; charset=utf-8')}

try:
    from . import range_preview as preview
except ImportError:
    import range_preview as preview

if preview.ROOT != ROOT:
    raise RuntimeError('Preview roots differ')


def page_list():
    result = []
    for path in sorted([*ROOT.glob('*.html'), *(ROOT / 'en').glob('*.html')]):
        relative = path.relative_to(ROOT)
        if any(part.startswith(('.', '_')) or part == 'node_modules' for part in relative.parts):
            continue
        if not path.resolve().is_relative_to(ROOT) or not re.fullmatch(r'(?:en/)?[a-z0-9-]+\.html', relative.as_posix()):
            continue
        file = relative.as_posix()
        if file == 'index.html':
            route = '/'
        elif file == 'en/index.html':
            route = '/en/'
        else:
            route = '/' + file[:-5]
        locale = 'en' if file.startswith('en/') else 'tr'
        result.append({'file': file, 'url': route, 'locale': locale})
        if file in {'reset-password.html', 'confirmed.html', 'unsubscribe.html'}:
            # Public no-token query selects UI language, never an auth operation.
            result[-1]['url'] = route + '?lang=tr'
            result.append({'file': file, 'url': route + '?lang=en', 'locale': 'en'})
    if not 1 <= len(result) <= 60:
        raise RuntimeError('Unexpected bounded HTML page inventory')
    return result


class Handler(preview.Handler):
    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=()')
        # Bypass parent's weaker CSP addition; retain its Range implementation.
        SimpleHTTPRequestHandler.end_headers(self)

    def _request_guard(self):
        if not self._valid_host():
            self._empty(403)
            return False
        origins = self.headers.get_all('Origin', [])
        if len(origins) > 1 or (origins and origins[0] != 'http://' + self.headers['Host']):
            self._empty(403)
            return False
        if self.headers.get('Sec-Fetch-Site', '').lower() == 'cross-site':
            self._empty(403)
            return False
        return True

    def _bytes(self, body, content_type, *, head):
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def _serve(self, *, head):
        if not self._request_guard():
            return
        try:
            if len(self.path) > 2048:
                self._empty(414)
                return
            parsed = urlsplit(self.path)
            path = unquote(parsed.path)
            if parsed.scheme or parsed.netloc or parsed.fragment or re.search(r'[\x00-\x1f\x7f\\%]', path):
                self._empty(400)
                return
            if path in QA_FILES:
                file, content_type = QA_FILES[path]
                self._bytes((QA / file).read_bytes(), content_type, head=head)
                return
            if path == '/__qa/pages.json':
                self._bytes(json.dumps(page_list(), separators=(',', ':')).encode(), 'application/json; charset=utf-8', head=head)
                return
            if path.startswith('/__qa') or path.startswith(('/auth/', '/rest/', '/functions/', '/api/', '/storage/')):
                self._empty(404)
                return
            if any(part.startswith(('.', '_')) or part == 'node_modules' for part in path.split('/') if part):
                self._empty(404)
                return
            if path.casefold() == '/js/config.js':
                self._bytes(b'window.PomoSupabase=null;\n', 'application/javascript; charset=utf-8', head=head)
                return
            normal = path
            if normal in ('/', '/en/'):
                normal += 'index.html'
            elif not Path(normal).suffix:
                normal += '.html'
            target = (ROOT / normal.lstrip('/')).resolve()
            if (not target.is_relative_to(ROOT) or not target.is_file() or target.suffix.lower() not in ALLOWED_SUFFIXES
                    or any(part.startswith(('.', '_')) or part == 'node_modules' for part in target.relative_to(ROOT).parts)):
                self._empty(404)
                return
            if target.suffix.lower() == '.html':
                body = target.read_bytes()
                script = b'<script src="/__qa/probe.js"></script>'
                # Served-response instrumentation only; no source file is edited.
                body, count = re.subn(br'(<head\b[^>]*>)', lambda match: match[1] + script, body, count=1, flags=re.I)
                if count != 1:
                    self._empty(422)
                    return
                self._bytes(body, 'text/html; charset=utf-8', head=head)
                return
            # Existing safe streaming/GET Range/HEAD/If-Range behavior.
            super()._serve(head=head)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except (OSError, ValueError):
            self._empty(404)

    def _no_write(self):
        self.close_connection = True
        if self._request_guard():
            self.send_response(405)
            self.send_header('Allow', 'GET, HEAD')
            self.send_header('Content-Length', '0')
            self.end_headers()

    do_POST = _no_write
    do_PUT = _no_write
    do_PATCH = _no_write
    do_DELETE = _no_write
    do_OPTIONS = _no_write


def create_server(port=8799):
    if type(port) is not int or port not in ALLOWED_PORTS:
        raise ValueError('Only ports8797,8798,8799 or0 for isolated tests are allowed')
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.daemon_threads = True
    return server


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, choices=sorted(ALLOWED_PORTS), default=8799)
    args = parser.parse_args(arguments)
    server = create_server(args.port)
    print(f'LOCAL_QA_READY pid={os.getpid()} http://127.0.0.1:{server.server_port}/__qa — GET/HEAD only, live config disabled.', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
