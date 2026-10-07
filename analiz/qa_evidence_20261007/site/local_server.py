from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import json, re

ROOT = Path(__file__).resolve().parents[3] / 'landing'
LOG = Path(__file__).with_name('local_requests.jsonl')

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self' data:; media-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'")
        self.send_header('X-Content-Type-Options', 'nosniff')
        if urlsplit(self.path).path in ('/reset-password', '/confirmed', '/unsubscribe'):
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('X-Robots-Tag', 'noindex, nofollow')
        super().end_headers()

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/js/config.js':
            data = (ROOT / 'js/config.js').read_text()
            data = re.sub(r'var SUPABASE_URL = "[^"]+";', 'var SUPABASE_URL = window.location.origin;', data)
            data = re.sub(r'var SUPABASE_ANON_KEY = "[^"]+";', 'var SUPABASE_ANON_KEY = "qa-mock-anon";', data)
            blob = data.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/javascript')
            self.send_header('Content-Length', str(len(blob)))
            self.end_headers()
            self.wfile.write(blob)
            return
        if path == '/':
            self.path = '/index.html'
        elif not Path(path).suffix and (ROOT / (path.lstrip('/') + '.html')).exists():
            self.path = path + '.html'
        super().do_GET()

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', 0))).decode()
        path = urlsplit(self.path).path
        with LOG.open('a') as log:
            log.write(json.dumps({'method': 'POST', 'path': path, 'body': json.loads(body or '{}')}) + '\n')
        if path == '/rest/v1/rpc/get_public_monthly_leaderboard':
            data = [{'name': 'QA Ada', 'avatar_id': 'avatar_16_basic', 'total_points': 25}, {'name': 'QA Ece', 'avatar_id': 'avatar_16_basic', 'total_points': 12}, {'name': 'QA Can', 'avatar_id': 'avatar_16_basic', 'total_points': 5}]
            status = 200
        elif path == '/rest/v1/waitlist':
            data, status = None, 201
        elif path == '/functions/v1/unsubscribe' or path == '/auth/v1/logout':
            data, status = {}, 200
        else:
            data, status = {'error_code': 'qa_unexpected_endpoint'}, 400
        blob = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(blob)))
        self.end_headers()
        self.wfile.write(blob)

print('QA mock HTTP server on http://127.0.0.1:8187; production requests disabled', flush=True)
ThreadingHTTPServer(('127.0.0.1', 8187), Handler).serve_forever()
