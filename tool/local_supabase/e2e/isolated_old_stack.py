#!/usr/bin/env python3
"""Isolated legacy API for A8. Never uses shared Auth or hosted services.

Copies an explicitly checked user-empty legacy baseline into one named database,
then starts cached local Auth/REST images and a fixed-loopback gateway. The JWT
secret below is Supabase's PUBLIC local demo fixture, never a production secret.
No dotenv, container environment, service key or user database content is read.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from uuid import UUID

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/verification_20261028/isolated_old'
SOURCE = 'pomosprint_overnight_baseline'
CLONE = 'pomosprint_verify_old_20261028'
MARKER = 'PomoSprint isolated old QA 20261028; disposable; no copied users'
PUBLIC_DEMO_SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long'
API_PORT, REST_PORT, AUTH_PORT = 54341, 54342, 54343
REST_NAME, AUTH_NAME = 'pomosprint-verify-old-rest-20261028', 'pomosprint-verify-old-auth-20261028'
PUBLIC_TABLES = {'app_config', 'avatars', 'blocked_name_terms', 'league_competition_state', 'marathon_presence_settings'}
AUTH_IMAGE = 'public.ecr.aws/supabase/gotrue:v2.197.0'
REST_IMAGE = 'public.ecr.aws/supabase/postgrest:v16.4'
STATE = OUT / 'state.json'
MAX_BODY = 1024 * 1024


class GuardError(RuntimeError):
    pass


def command(args, *, body=None, allow_failure=False):
    p = subprocess.run(args, input=body, text=True, capture_output=True, timeout=60)
    if p.returncode and not allow_failure:
        raise GuardError(f'{args[0]} failed; inspect local QA log (no credentials logged)')
    return p


def query(db, sql):
    if db not in {'postgres', SOURCE, CLONE}:
        raise GuardError('Database outside fixed local allowlist')
    return command(['psql', f'postgresql://postgres:postgres@127.0.0.1:54322/{db}', '-XqAt', '-v', 'ON_ERROR_STOP=1'], body=sql).stdout.strip()


def quote(s):
    return "'" + s.replace("'", "''") + "'"


def inspect_baseline(db=SOURCE):
    names = query(db, "select schemaname||'.'||tablename from pg_tables where schemaname in('public','auth','net') order by 1").splitlines()
    counts = {}
    for name in names:
        if not re.fullmatch(r'(public|auth|net)\.[a-z_][a-z_0-9]*', name):
            raise GuardError('Unsafe schema identifier')
        counts[name] = int(query(db, f'select count(*) from {name}'))
        allowed = name.startswith('public.') and name.split('.')[1] in PUBLIC_TABLES
        allowed = allowed or name == 'auth.schema_migrations'
        if counts[name] and not allowed:
            raise GuardError('Legacy baseline contains data outside explicit catalog/config allowlist: '+name)
    facts = json.loads(query(db, """select jsonb_build_object(
      'exam_rpc',to_regprocedure('public.get_exam_config()')::text,
      'monthly_rpc',to_regprocedure('public.get_monthly_league_ranking(text,text)')::text,
      'new_migrations',(select count(*) from supabase_migrations.schema_migrations where version in('20261028010000','20261028020000','20261028030000','20261028050000')),
      'welcome_disabled',(select tgenabled='D' from pg_trigger where tgname='after_insert_marketing_subscribers'),
      'segment_constraint',(select pg_get_constraintdef(oid)from pg_constraint where conname='profiles_user_segment_check'),
      'public_function_hash',(select md5(string_agg(oid::regprocedure::text||pg_get_functiondef(oid),E'\\n' order by oid::regprocedure::text))from pg_proc where pronamespace='public'::regnamespace));"""))
    if facts['exam_rpc'] is not None or facts['monthly_rpc'] is not None or facts['new_migrations'] != 0 or facts['welcome_disabled'] is not True or "'tus'" in facts['segment_constraint']:
        raise GuardError('Not the guarded old server schema or outgoing mail is enabled')
    return {'row_counts': counts, 'facts': facts}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


OPENER = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))


def read_url(url, *, data=None, headers=None, method='GET'):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        return OPENER.open(req, timeout=15)
    except urllib.error.HTTPError as error:
        return error


def wait_ready(port, path):
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        try:
            with read_url(f'http://127.0.0.1:{port}{path}') as response:
                if response.status == 200:
                    return
        except OSError:
            pass
        time.sleep(.25)
    raise GuardError('Local isolated service did not become ready')


def token_owner(authorization):
    try:
        scheme, token = authorization.split(' ', 1)
        if scheme.lower() != 'bearer':
            raise ValueError()
        header, payload, signature = token.split('.')
        decode = lambda v: base64.urlsafe_b64decode(v + '=' * (-len(v) % 4))
        if json.loads(decode(header)).get('alg') != 'HS256':
            raise ValueError()
        wanted = hmac.new(PUBLIC_DEMO_SECRET.encode(), f'{header}.{payload}'.encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(wanted, decode(signature)):
            raise ValueError()
        claims = json.loads(decode(payload))
        owner = str(UUID(claims['sub']))
        if claims.get('role') != 'authenticated' or claims.get('exp', 0) <= time.time():
            raise ValueError()
        return owner
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        raise GuardError('Owner-validated local QA token required') from None


def owner_verification(owner):
    owner = str(UUID(owner))
    ok = query(CLONE, f"select count(*) from auth.users where id={quote(owner)}::uuid and email~'^e2e-sim-old-[a-z0-9-]+@pomosprint\\.local$' and created_at>now()-interval '24 hours'")
    if ok != '1':
        raise GuardError('Only fresh isolated old QA owners are accepted')
    return json.loads(query(CLONE, f"""select jsonb_build_object(
      'database',current_database(),
      'profile',(select jsonb_build_object('id',id,'segment',user_segment,'total_minutes',total_minutes,'points',lifetime_points,'coins',coins,'timezone',timezone,'today',((clock_timestamp() at time zone timezone)-interval '4 hours')::date::text,'onboarded',onboarding_completed_at is not null) from public.profiles where id={quote(owner)}::uuid),
      'categories',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'archived',is_archived) order by sort_order,id),'[]') from public.categories where user_id={quote(owner)}::uuid),
      'studies',(select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'client_uuid',s.client_uuid,'minutes',s.duration_minutes,'base_points',s.base_points,'bonus_points',s.bonus_points,'started_at',s.started_at,'completed_at',s.completed_at,'study_day',((s.started_at at time zone p.timezone)-interval '4 hours')::date::text) order by s.started_at),'[]') from public.study_sessions s join public.profiles p on p.id=s.user_id where s.user_id={quote(owner)}::uuid),
      'exam_rpc_missing',to_regprocedure('public.get_exam_config()') is null,
      'monthly_rpc_missing',to_regprocedure('public.get_monthly_league_ranking(text,text)') is null,
      'welcome_disabled',(select tgenabled='D' from pg_trigger where tgname='after_insert_marketing_subscribers'));"""))


def safe_path(raw):
    parsed = urllib.parse.urlsplit(raw)
    path = urllib.parse.unquote(parsed.path)
    if parsed.scheme or parsed.netloc or parsed.fragment or not path.startswith('/') or '\\' in path or '%' in path or '//' in path or '..' in path.split('/') or any(ord(c) < 32 for c in raw + path):
        raise GuardError('Invalid local route')
    return parsed, path


class Gateway(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass  # No token, body, email or query string logging.

    def reply(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def dispatch(self):
        try:
            if self.headers.get('Host') not in {f'127.0.0.1:{API_PORT}', f'localhost:{API_PORT}'}:
                self.reply(403, {'error': 'foreign_host'})
                return
            if self.headers.get('Origin') not in {None, f'http://127.0.0.1:{API_PORT}', f'http://localhost:{API_PORT}'} or self.headers.get('Sec-Fetch-Site') in {'cross-site', 'none'}:
                self.reply(403, {'error': 'foreign_origin'})
                return
            parsed, path = safe_path(self.path)
            if self.command == 'GET' and path == '/health':
                self.reply(200, {'scope': 'isolated old local QA', 'database': CLONE, 'port': API_PORT})
                return
            if self.command == 'GET' and path == '/qa/v1/verify':
                if parsed.query:
                    raise GuardError('No owner or SQL query parameter is accepted')
                self.reply(200, owner_verification(token_owner(self.headers.get('Authorization', ''))))
                return
            if path.startswith('/auth/v1/'):
                upstream_port, upstream_path = AUTH_PORT, path[len('/auth/v1'):]
            elif path.startswith('/rest/v1/'):
                upstream_port, upstream_path = REST_PORT, path[len('/rest/v1'):]
            else:
                self.reply(404, {'error': 'route_not_available'})
                return
            raw_length = self.headers.get('Content-Length', '0')
            if not raw_length.isdigit() or int(raw_length) > MAX_BODY or self.headers.get('Transfer-Encoding'):
                self.reply(413, {'error': 'body_limit'})
                return
            body = self.rfile.read(int(raw_length)) if int(raw_length) else None
            headers = {k: v for k, v in self.headers.items() if k.lower() not in {'host', 'connection', 'content-length', 'transfer-encoding', 'accept-encoding'}}
            suffix = ('?' + parsed.query) if parsed.query else ''
            with read_url(f'http://127.0.0.1:{upstream_port}{upstream_path}{suffix}', data=body, headers=headers, method=self.command) as response:
                if 300 <= response.status < 400:
                    self.reply(502, {'error': 'upstream_redirect_blocked'})
                    return
                data = response.read(MAX_BODY + 1)
                if len(data) > MAX_BODY:
                    self.reply(502, {'error': 'response_limit'})
                    return
                # send_response_only avoids adding a second Date header.
                self.send_response_only(response.status)
                for k, v in response.headers.items():
                    if k.lower() not in {'connection', 'transfer-encoding', 'content-length'}:
                        self.send_header(k, v)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except GuardError:
            self.reply(403, {'error': 'local_qa_guard'})
        except (OSError, ValueError):
            self.reply(502, {'error': 'isolated_service_unavailable'})

    do_GET = do_POST = do_PATCH = do_DELETE = do_OPTIONS = dispatch


def start():
    OUT.mkdir(parents=True, exist_ok=True)
    for port in (API_PORT, REST_PORT, AUTH_PORT):
        with socket.socket() as sock:
            if sock.connect_ex(('127.0.0.1', port)) == 0:
                raise GuardError('Isolated port is already in use')
    if query('postgres', f'select count(*) from pg_database where datname={quote(CLONE)}') != '0':
        raise GuardError('Isolated database already exists; refusing to overwrite')
    for name in (AUTH_NAME, REST_NAME):
        if command(['docker', 'container', 'inspect', '--format', '{{.Id}}', name], allow_failure=True).returncode == 0:
            raise GuardError('Isolated container name already exists')
    baseline = inspect_baseline()
    (OUT/'baseline_before.json').write_text(json.dumps(baseline, indent=2)+'\n')
    query('postgres', f'CREATE DATABASE {CLONE} TEMPLATE {SOURCE}; COMMENT ON DATABASE {CLONE} IS {quote(MARKER)};')
    if inspect_baseline(CLONE) != baseline:
        raise GuardError('The fresh empty clone differs from the baseline')
    state = {'created_by': MARKER, 'database': CLONE, 'containers': [AUTH_NAME, REST_NAME], 'gateway_port': API_PORT, 'auth_autoconfirm': True, 'shared_auth_used': False, 'hosted_access': False}
    STATE.write_text(json.dumps(state, indent=2)+'\n')
    db = f'postgresql://postgres:postgres@host.docker.internal:54322/{CLONE}?sslmode=disable'
    # This public local demo role/password owns the copied Auth schema and its
    # migration search_path; using postgres would read the wrong migration log.
    auth_db = f'postgresql://supabase_auth_admin:postgres@host.docker.internal:54322/{CLONE}?sslmode=disable'
    # Keep an exited owned container until stop() so bootstrap errors retain
    # their log; stop() removes only containers with this exact ownership label.
    common = ['docker', 'run', '-d', '--label', 'com.pomosprint.qa=oldserver-20261028']
    auth_env = {
        'GOTRUE_API_HOST': '0.0.0.0', 'PORT': '9999', 'GOTRUE_API_PORT': '9999',
        'GOTRUE_SITE_URL': f'http://127.0.0.1:{API_PORT}', 'API_EXTERNAL_URL': f'http://127.0.0.1:{API_PORT}/auth/v1',
        'GOTRUE_DB_DRIVER': 'postgres', 'GOTRUE_DB_DATABASE_URL': auth_db, 'GOTRUE_DB_NAMESPACE': 'auth',
        'GOTRUE_JWT_SECRET': PUBLIC_DEMO_SECRET, 'GOTRUE_JWT_EXP': '3600', 'GOTRUE_JWT_AUD': 'authenticated',
        'GOTRUE_JWT_DEFAULT_GROUP_NAME': 'authenticated', 'GOTRUE_JWT_ADMIN_ROLES': 'service_role',
        'GOTRUE_EXTERNAL_EMAIL_ENABLED': 'true', 'GOTRUE_DISABLE_SIGNUP': 'false', 'GOTRUE_MAILER_AUTOCONFIRM': 'true',
    }
    rest_env = {'PGRST_DB_URI': db, 'PGRST_DB_SCHEMAS': 'public', 'PGRST_DB_ANON_ROLE': 'anon', 'PGRST_JWT_SECRET': PUBLIC_DEMO_SECRET}
    for name, port, container_port, image, env in [(AUTH_NAME, AUTH_PORT, 9999, AUTH_IMAGE, auth_env), (REST_NAME, REST_PORT, 3000, REST_IMAGE, rest_env)]:
        args = common + ['--name', name, '-p', f'127.0.0.1:{port}:{container_port}']
        for key, value in env.items():
            args += ['-e', f'{key}={value}']
        args.append(image)
        command(args)
    wait_ready(AUTH_PORT, '/health')
    wait_ready(REST_PORT, '/')
    with (OUT/'gateway.log').open('w') as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'serve'], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    state['gateway_pid'] = process.pid
    STATE.write_text(json.dumps(state, indent=2)+'\n')
    wait_ready(API_PORT, '/health')
    if inspect_baseline() != baseline:
        raise GuardError('Baseline changed unexpectedly')
    print(json.dumps({'ready': True, 'gateway': f'http://127.0.0.1:{API_PORT}', 'database': CLONE, 'auth_isolated': True, 'new_packages_absent': True}))


def stop():
    state = json.loads(STATE.read_text())
    if state.get('created_by') != MARKER or state.get('database') != CLONE:
        raise GuardError('Refusing unknown state')
    comment = query('postgres', f'select shobj_description(oid,\'pg_database\') from pg_database where datname={quote(CLONE)}')
    if comment != MARKER:
        raise GuardError('Refusing database without the owned marker')
    pid = state.get('gateway_pid')
    if pid:
        cmd = command(['ps', '-p', str(pid), '-o', 'command='], allow_failure=True).stdout
        if str(Path(__file__).resolve()) in cmd and 'serve' in cmd:
            import os, signal
            os.kill(pid, signal.SIGTERM)
    for name in (AUTH_NAME, REST_NAME):
        label = command(['docker', 'container', 'inspect', '--format', '{{index .Config.Labels "com.pomosprint.qa"}}', name], allow_failure=True)
        if label.returncode == 0:
            if label.stdout.strip() != 'oldserver-20261028':
                raise GuardError('Refusing unowned container')
            command(['docker', 'rm', '-f', name])
    query('postgres', f"select pg_terminate_backend(pid) from pg_stat_activity where datname={quote(CLONE)} and pid<>pg_backend_pid(); DROP DATABASE {CLONE};")
    state['stopped_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
    STATE.write_text(json.dumps(state, indent=2)+'\n')
    print('Stopped only the owned isolated old stack; shared local services unchanged')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['start', 'serve', 'status', 'stop'])
    action = p.parse_args().action
    if action == 'start': start()
    elif action == 'stop': stop()
    elif action == 'serve':
        if query('postgres', f"select shobj_description(oid,'pg_database') from pg_database where datname={quote(CLONE)}") != MARKER:
            raise GuardError('Gateway requires its own marked clone')
        ThreadingHTTPServer(('127.0.0.1', API_PORT), Gateway).serve_forever()
    else:
        print(STATE.read_text() if STATE.exists() else json.dumps({'ready': False}))


if __name__ == '__main__':
    try:
        main()
    except (GuardError, OSError, ValueError) as error:
        print('Isolated old QA stopped safely: '+str(error), file=sys.stderr)
        raise SystemExit(1) from None
