#!/usr/bin/env python3
"""Disposable Docker Auth + Mailpit integration; no production services/data."""
import html, http.client as http_client, json, re, secrets, subprocess, time, urllib.parse

def sh(*args, check=True):
    return subprocess.run(args, check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=45)

ctx = sh('docker', 'context', 'show').stdout.strip()
endpoint = sh('docker', 'context', 'inspect', ctx, '--format', '{{.Endpoints.docker.Host}}').stdout.strip()
if not endpoint.startswith('unix://'):
    raise RuntimeError('Docker context must be local unix socket')

tag = secrets.token_hex(5)
network = 'pomo-mail-qa-' + tag
db = 'pomo-mail-db-' + tag
auth = 'pomo-mail-auth-' + tag
mail = 'pomo-mail-box-' + tag
created = []

secret = 'local-only-fake-jwt-key-not-for-production-2026'
db_password = 'local-only-fake-db-password-2026'
email = 'isolated-' + tag + '@example.com'
old_password = 'LocalOnly-Start123!'
new_password = 'LocalOnly-Next456!'

def http(base, path, method='GET', body=None, token=None, include_location=False):
    host, port = base.split(':')
    hdrs = {'Host': host, 'Content-Type': 'application/json', 'Connection': 'close'}
    if token: hdrs['Authorization'] = 'Bearer ' + token
    data = None if body is None else json.dumps(body).encode()
    data = data or b''
    hdrs['Content-Length'] = str(len(data))
    request = (method+' '+path+' HTTP/1.1\r\n' + ''.join(f'{k}: {v}\r\n' for k,v in hdrs.items())+'\r\n').encode()+data
    process = subprocess.Popen(['docker','--context',ctx,'exec','-i',db,'nc','-w','15',host,port], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    process.stdin.write(request)
    process.stdin.flush()
    class MemorySocket:
        def makefile(self, *args, **kwargs): return process.stdout
    response = http_client.HTTPResponse(MemorySocket())
    try:
        response.begin()
        raw, status, location = response.read(), response.status, response.getheader('Location')
    finally:
        process.stdin.close()
        try: process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    try: result = json.loads(raw) if raw else None
    except (ValueError, UnicodeDecodeError): result = None
    return (status, result, location) if include_location else (status, result)

def ready(base, path):
    for _ in range(160):
        try:
            if http(base, path)[0] == 200: return
        except (OSError, subprocess.TimeoutExpired): pass
        time.sleep(.25)
    raise RuntimeError('Service failed to become ready: ' + path)

def assertion(name, condition):
    if not condition: raise AssertionError(name)
    print('PASS ' + name, flush=True)

def message_token(kind, seen):
    for _ in range(80):
        status, payload = http(mail_base, '/api/v1/messages')
        for item in (payload or {}).get('messages') or []:
            if item['ID'] in seen or not any(to.get('Address','').lower() == email for to in item.get('To', [])): continue
            status, details = http(mail_base, '/api/v1/message/' + item['ID'])
            content = html.unescape((details or {}).get('HTML', '') + (details or {}).get('Text', ''))
            for candidate in re.findall(r'https?://[^\s"<>]+', content):
                parsed = urllib.parse.urlparse(candidate)
                params = urllib.parse.parse_qs(parsed.query)
                if parsed.hostname == 'auth' and parsed.port == 9999 and parsed.path == '/verify' and params.get('type') == [kind] and len(params.get('token',[])) == 1:
                    return params['token'][0], (params.get('redirect_to') or [None])[0]
        time.sleep(.25)
    raise RuntimeError('No matching test message: ' + kind)

def mailbox_ids():
    _, payload = http(mail_base, '/api/v1/messages')
    return {m['ID'] for m in ((payload or {}).get('messages') or [])}

try:
    sh('docker','--context',ctx,'network','create','--internal',network)
    created.append(('network',network))
    sh('docker','--context',ctx,'run','-d','--pull=never','--name',db,'--network',network,'--network-alias','pg', '-e','POSTGRES_PASSWORD='+db_password, 'postgres:17-alpine')
    created.append(('container',db))
    for _ in range(100):
        if sh('docker','--context',ctx,'exec',db,'pg_isready','-U','postgres',check=False).returncode == 0: break
        time.sleep(.25)
    else: raise RuntimeError('Postgres failed to start')
    for _ in range(100):
        prep = sh('docker','--context',ctx,'exec','-e','PGPASSWORD='+db_password,db,'psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-c', 'CREATE SCHEMA IF NOT EXISTS auth; ALTER ROLE postgres SET search_path = auth, public;',check=False)
        if prep.returncode == 0: break
        time.sleep(.25)
    else: raise RuntimeError('Postgres schema preparation failed')
    sh('docker','--context',ctx,'run','-d','--pull=never','--name',mail,'--network',network,'--network-alias','mailpit','public.ecr.aws/supabase/mailpit:v1.31.3')
    created.append(('container',mail))
    env = {
      'GOTRUE_API_HOST':'0.0.0.0','GOTRUE_API_PORT':'9999',
      'API_EXTERNAL_URL':'http://auth:9999',
      'GOTRUE_DB_DRIVER':'postgres',
      'GOTRUE_DB_DATABASE_URL':f'postgres://postgres:{db_password}@pg:5432/postgres?sslmode=disable',
      'GOTRUE_SITE_URL':'https://pomosprint.app',
      'GOTRUE_URI_ALLOW_LIST':'https://pomosprint.app/*,https://pomosprint.app/confirmed.html',
      'GOTRUE_JWT_SECRET':secret,'GOTRUE_JWT_AUD':'authenticated','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated','GOTRUE_JWT_EXP':'3600',
      'GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_MAILER_AUTOCONFIRM':'false',
      'GOTRUE_SMTP_HOST':'mailpit','GOTRUE_SMTP_PORT':'1025','GOTRUE_SMTP_ADMIN_EMAIL':'sender@example.invalid','GOTRUE_SMTP_SENDER_NAME':'Pomo QA',
      'GOTRUE_RATE_LIMIT_EMAIL_SENT':'100','GOTRUE_MAILER_URLPATHS_CONFIRMATION':'/verify','GOTRUE_MAILER_URLPATHS_RECOVERY':'/verify',
    }
    cmd=['docker','--context',ctx,'run','-d','--pull=never','--name',auth,'--network',network,'--network-alias','auth']
    for k,v in env.items(): cmd += ['-e',k+'='+v]
    cmd += ['public.ecr.aws/supabase/gotrue:v2.197.0']
    sh(*cmd); created.append(('container',auth))
    auth_base='auth:9999'; mail_base='mailpit:8025'
    ready(auth_base,'/health'); ready(mail_base,'/api/v1/info')
    print('PASS Empty isolated Auth and Mailpit ready; outbound Docker network disabled', flush=True)
    before=mailbox_ids()
    confirmed_url='https://pomosprint.app/confirmed.html'
    status, signup=http(auth_base,'/signup?'+urllib.parse.urlencode({'redirect_to':confirmed_url}),'POST',{'email':email,'password':old_password})
    if not (status in (200,201) and signup is not None and not signup.get('access_token')):
        print('Signup HTTP status / error code:', status, (signup or {}).get('error_code'), flush=True)
    assertion('Registration accepted without authenticated session', status in (200,201) and signup is not None and not signup.get('access_token'))
    uid=signup.get('id') or (signup.get('user') or {}).get('id')
    assertion('Unconfirmed email cannot sign in', http(auth_base,'/token?grant_type=password','POST',{'email':email,'password':old_password})[0] >= 400)
    signup_token,signup_redirect=message_token('signup',before)
    print('Exact confirmation URL preserved:', signup_redirect==confirmed_url, flush=True)
    signup_query=urllib.parse.urlencode({'type':'signup','token':signup_token,'redirect_to':signup_redirect})
    status, _, signup_location=http(auth_base,'/verify?'+signup_query,include_location=True)
    signup_target=urllib.parse.urlsplit(signup_location or '')
    print('Actual signup target is confirmed html:', signup_target.scheme=='https' and signup_target.netloc=='pomosprint.app' and signup_target.path=='/confirmed.html', flush=True)
    assertion('Signup email link confirms the intended account', status in (302,303) and bool(signup_location))
    status, signed=http(auth_base,'/token?grant_type=password','POST',{'email':email,'password':old_password})
    assertion('Confirmed user can sign in', status==200 and signed.get('user',{}).get('id')==uid)
    before=mailbox_ids()
    reset_url='https://pomosprint.app/reset-password.html'
    assertion('Password recovery request accepted', http(auth_base,'/recover?'+urllib.parse.urlencode({'redirect_to':reset_url}),'POST',{'email':email})[0]==200)
    recovery_token,reset_redirect=message_token('recovery',before)
    print('Recovery email link requests html URL:', reset_redirect==reset_url, flush=True)
    recovery_query=urllib.parse.urlencode({'type':'recovery','token':recovery_token,'redirect_to':reset_redirect})
    status, _, recovery_location=http(auth_base,'/verify?'+recovery_query,include_location=True)
    target=urllib.parse.urlsplit(recovery_location or '')
    print('Actual recovery target is reset html:', target.scheme=='https' and target.netloc=='pomosprint.app' and target.path=='/reset-password.html', flush=True)
    access=(urllib.parse.parse_qs(target.fragment).get('access_token') or [None])[0]
    status, recovery_user=http(auth_base,'/user',token=access) if access else (0,None)
    assertion('Recovery email link identifies intended account', status==200 and recovery_user.get('id')==uid)
    status,updated=http(auth_base,'/user','PUT',{'password':new_password},token=access)
    assertion('Recovery session can set a new password', status==200 and updated.get('id')==uid)
    assertion('Previous password rejected', http(auth_base,'/token?grant_type=password','POST',{'email':email,'password':old_password})[0]>=400)
    status, signed=http(auth_base,'/token?grant_type=password','POST',{'email':email,'password':new_password})
    assertion('New password can sign in to same account', status==200 and signed.get('user',{}).get('id')==uid)
    assertion('Recovery link cannot be reused', http(auth_base,'/verify','POST',{'type':'recovery','token_hash':recovery_token})[0]>=400)
    status, unknown=http(auth_base,'/recover','POST',{'email':'absent-'+tag+'@example.invalid'})
    assertion('Recovery request for missing account also accepted', status==200)
except Exception:
    if ('container',auth) in created:
        logs=sh('docker','--context',ctx,'logs','--tail','25',auth,check=False)
        for line in (logs.stdout+'\n'+logs.stderr).splitlines():
            try:
                entry=json.loads(line)
                if entry.get('level') in ('error','fatal'):
                    print('Auth local error:',entry.get('msg'),entry.get('error'),flush=True)
            except (ValueError,TypeError): pass
    raise
finally:
    for typ,name in reversed(created):
        if typ == 'container': sh('docker','--context',ctx,'rm','-f',name,check=False)
        else: sh('docker','--context',ctx,'network','rm',name,check=False)
    print('Cleanup attempted for this test’s isolated containers and network', flush=True)
