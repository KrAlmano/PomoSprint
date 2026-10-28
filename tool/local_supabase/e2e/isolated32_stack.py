#!/usr/bin/env python3
"""Fixed-loopback Auth/REST for already-reviewed final32 DB. Never clones/drops DB.

Uses cached local images and the public Supabase demo JWT fixture only.
No dotenv/container secrets or hosted service is read. stop removes only owned
containers/gateway; the reviewed database and all evidence stay intact.
"""
from __future__ import annotations
import argparse
import datetime as dt
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/verification_20261028/isolated32_stack'
CLONE = 'pomosprint_review32_dus'
API_PORT, REST_PORT, AUTH_PORT = 54351, 54352, 54353
AUTH_NAME, REST_NAME = 'pomosprint-verify32-dus-auth-20261028', 'pomosprint-verify32-dus-rest-20261028'
LABEL = 'exam32-dus-20261028-final'
PUBLIC_DEMO_SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long'
AUTH_IMAGE = 'public.ecr.aws/supabase/gotrue:v2.197.0'
REST_IMAGE = 'public.ecr.aws/supabase/postgrest:v16.4'
STATE = OUT / 'state.json'
MAX_BODY = 1024 * 1024

class GuardError(RuntimeError):
    pass

PROFILE = 'review'
PROFILES = {
    'review': ('pomosprint_review32_dus',54351,54352,54353,'exam32-dus-20261028-final','isolated32_dus_stack','pomosprint-verify32-dus'),
    'site': ('pomosprint_site32_dus',54361,54362,54363,'site32-dus-20261028-final','site32_dus_stack','pomosprint-site32-dus'),
}

def select_profile(profile):
    global PROFILE,CLONE,API_PORT,REST_PORT,AUTH_PORT,LABEL,OUT,STATE,AUTH_NAME,REST_NAME
    if profile not in PROFILES:
        raise GuardError('Only review/site profiles are accepted')
    PROFILE = profile
    CLONE,API_PORT,REST_PORT,AUTH_PORT,LABEL,out,prefix = PROFILES[profile]
    OUT = ROOT / 'build/verification_20261028' / out
    STATE = OUT / 'state.json'
    AUTH_NAME,REST_NAME = prefix+'-auth-20261028',prefix+'-rest-20261028'


def command(args, *, body=None, allow_failure=False, env=None):
    p = subprocess.run(args, input=body, text=True, capture_output=True, timeout=60, env=env)
    if p.returncode and not allow_failure:
        raise GuardError(f'{args[0]} failed; inspect local stack evidence')
    return p

def query(sql):
    env = {'PATH': os.environ.get('PATH','/usr/bin:/bin'), 'PGPASSFILE':'/dev/null'}
    return command(['psql',f'host=127.0.0.1 port=54322 user=postgres password=postgres dbname={CLONE} connect_timeout=5 sslmode=disable','-XqAt','-v','ON_ERROR_STOP=1'],body='BEGIN READ ONLY; '+sql+'; COMMIT;',env=env).stdout.strip()

def docker_context():
    env = {k:v for k,v in os.environ.items() if not k.startswith('DOCKER_')}
    context = command(['docker','context','show'],env=env).stdout.strip()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+',context):
        raise GuardError('Invalid Docker context')
    endpoint = command(['docker','context','inspect',context,'--format','{{.Endpoints.docker.Host}}'],env=env).stdout.strip()
    if not endpoint.startswith('unix://'):
        raise GuardError('Only local unix Docker context is accepted')
    return context,env

def docker(args, *, allow_failure=False):
    context,env = docker_context()
    return command(['docker','--context',context,*args],allow_failure=allow_failure,env=env)

def facts():
    data=json.loads(query("SELECT jsonb_build_object('database',current_database(),'migrations',(SELECT jsonb_agg(version ORDER BY version) FROM supabase_migrations.schema_migrations WHERE version LIKE '20261028%'),'policy',(SELECT jsonb_build_array(early_enabled,early_coin_mode) FROM public.exam_extension_policy WHERE singleton),'welcome_disabled',(SELECT tgenabled='D' FROM pg_trigger WHERE tgname='after_insert_marketing_subscribers'),'unknown_owners',(SELECT count(*) FROM auth.users WHERE email !~ '^(review32-|e2e-sim-|qa-|site-demo-)[a-zA-Z0-9._+-]+@pomosprint[.]local$'))"))
    if data['database']!=CLONE or data['migrations']!=['20261028010000','20261028020000','20261028030000','20261028040000','20261028060000'] or data['policy']!=[True,'proportional'] or data['welcome_disabled'] is not True or data['unknown_owners']!=0:
        raise GuardError('Final32 database guard failed')
    return data

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
                self.reply(200, {'scope': 'isolated32 local QA', 'database': CLONE, 'port': API_PORT})
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

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = dispatch


def start():
    OUT.mkdir(parents=True,exist_ok=True)
    for port in (API_PORT,REST_PORT,AUTH_PORT):
        with socket.socket() as sock:
            if sock.connect_ex(('127.0.0.1',port))==0:
                raise GuardError('Isolated32 port already occupied')
    for name in (AUTH_NAME,REST_NAME):
        if docker(['container','inspect','--format','{{.Id}}',name],allow_failure=True).returncode==0:
            raise GuardError('Isolated32 container name already exists')
    before=facts()
    command([sys.executable,str(ROOT/'tool/local_supabase/parity_check_exam32.py'),'--profile',PROFILE])
    state={'profile':PROFILE,'created_by':LABEL,'database':CLONE,'containers':[AUTH_NAME,REST_NAME],'ports':{'api':API_PORT,'rest':REST_PORT,'auth':AUTH_PORT},'before':before,'created_containers':[],'gateway_pid':None,'main_modified':False}
    STATE.write_text(json.dumps(state,indent=2)+'\n')
    auth_db=f'postgresql://supabase_auth_admin:postgres@host.docker.internal:54322/{CLONE}?sslmode=disable'
    rest_db=f'postgresql://postgres:postgres@host.docker.internal:54322/{CLONE}?sslmode=disable'
    auth_env={'GOTRUE_API_HOST':'0.0.0.0','PORT':'9999','GOTRUE_API_PORT':'9999','GOTRUE_SITE_URL':f'http://127.0.0.1:{API_PORT}','API_EXTERNAL_URL':f'http://127.0.0.1:{API_PORT}/auth/v1','GOTRUE_DB_DRIVER':'postgres','GOTRUE_DB_DATABASE_URL':auth_db,'GOTRUE_DB_NAMESPACE':'auth','GOTRUE_JWT_SECRET':PUBLIC_DEMO_SECRET,'GOTRUE_JWT_EXP':'3600','GOTRUE_JWT_AUD':'authenticated','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated','GOTRUE_JWT_ADMIN_ROLES':'service_role','GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_DISABLE_SIGNUP':'false','GOTRUE_MAILER_AUTOCONFIRM':'true'}
    rest_env={'PGRST_DB_URI':rest_db,'PGRST_DB_SCHEMAS':'public','PGRST_DB_ANON_ROLE':'anon','PGRST_JWT_SECRET':PUBLIC_DEMO_SECRET}
    for name,port,inside,image,variables in [(AUTH_NAME,AUTH_PORT,9999,AUTH_IMAGE,auth_env),(REST_NAME,REST_PORT,3000,REST_IMAGE,rest_env)]:
        args=['run','--pull=never','-d','--label','com.pomosprint.qa='+LABEL,'--name',name,'-p',f'127.0.0.1:{port}:{inside}']
        for key,value in variables.items():args+=['-e',key+'='+value]
        args.append(image)
        docker(args)
        state['created_containers'].append(name)
        STATE.write_text(json.dumps(state,indent=2)+'\n')
    wait_ready(AUTH_PORT,'/health')
    wait_ready(REST_PORT,'/')
    with (OUT/'gateway.log').open('a') as log:
        process=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'serve','--profile',PROFILE],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    state['gateway_pid']=process.pid
    STATE.write_text(json.dumps(state,indent=2)+'\n')
    wait_ready(API_PORT,'/health')
    state['ready']=True;state['after']=facts()
    STATE.write_text(json.dumps(state,indent=2)+'\n')
    print(json.dumps({'ready':True,'api':f'http://127.0.0.1:{API_PORT}','rest_port':REST_PORT,'auth_port':AUTH_PORT,'database':CLONE,'gateway_pid':process.pid,'auto_confirm':True,'main_modified':False}))

def stop():
    state=json.loads(STATE.read_text())
    if state.get('created_by')!=LABEL or state.get('database')!=CLONE or state.get('containers')!=[AUTH_NAME,REST_NAME]:
        raise GuardError('Unknown stack state')
    pid=state.get('gateway_pid')
    if pid:
        process=command(['ps','-p',str(int(pid)),'-o','command='],allow_failure=True).stdout.strip()
        if process:
            suffixes = (' serve --profile '+PROFILE,) + ((' serve',) if PROFILE=='review' else ())
            if str(Path(__file__).resolve()) not in process or not any(process.endswith(suffix) for suffix in suffixes):
                raise GuardError('Gateway pid belongs to another process')
            os.kill(int(pid),signal.SIGTERM)
    for name in (AUTH_NAME,REST_NAME):
        label=docker(['container','inspect','--format','{{index .Config.Labels "com.pomosprint.qa"}}',name],allow_failure=True)
        if label.returncode==0:
            if label.stdout.strip()!=LABEL:raise GuardError('Refusing unowned container')
            docker(['rm','-f',name])
    state['ready']=False;state['stopped_at']=dt.datetime.now(dt.timezone.utc).isoformat()
    STATE.write_text(json.dumps(state,indent=2)+'\n')
    print('Stopped only owned32 gateway and containers; database retained')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','serve','status','stop'])
    parser.add_argument('--profile',choices=sorted(PROFILES),default='review')
    args=parser.parse_args()
    select_profile(args.profile)
    action=args.action
    if action=='start':start()
    elif action=='stop':stop()
    elif action=='serve':
        state=json.loads(STATE.read_text())
        if state.get('created_by')!=LABEL or state.get('database')!=CLONE:raise GuardError('Unknown gateway state')
        facts()
        ThreadingHTTPServer(('127.0.0.1',API_PORT),Gateway).serve_forever()
    else:print(STATE.read_text() if STATE.exists() else json.dumps({'ready':False}))

if __name__=='__main__':
    try:main()
    except (GuardError,OSError,ValueError,subprocess.TimeoutExpired) as exc:
        print('Isolated32 stopped safely: '+str(exc),file=sys.stderr)
        raise SystemExit(1) from None
