#!/usr/bin/env python3
"""Yalnızca yerel Supabase/Mailpit: gerçek onay ve parola sıfırlama bağlantısı.
Canlıya bağlanmaz, test hesabı dışında değişiklik yapmaz; belirteçleri yazdırmaz.
"""
import datetime
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ['LOCAL_TEST_PASSWORD'] = 'SimE2e-Yerel2026'
import local_api as api

RESULTS = []
def check(name, condition):
    RESULTS.append({'name': name, 'passed': bool(condition)})
    print(('PASS ' if condition else 'FAIL ') + name, flush=True)
    assert condition, name

def mailbox():
    return json.load(urllib.request.urlopen('http://127.0.0.1:54324/api/v1/messages'))['messages']

def token_for(email, kind, after):
    for _ in range(20):
        for m in mailbox():
            if m['ID'] in after or not any(x['Address'] == email for x in m['To']):
                continue
            detail = json.load(urllib.request.urlopen('http://127.0.0.1:54324/api/v1/message/' + m['ID']))
            content = html.unescape(detail.get('HTML', '') + detail.get('Text', ''))
            for link in re.findall(r'https?://[^\s"<>]+', content):
                u = urllib.parse.urlparse(link)
                q = urllib.parse.parse_qs(u.query)
                if u.hostname in {'127.0.0.1', 'localhost'} and u.port == 54321 and q.get('type') == [kind] and q.get('token'):
                    return q['token'][0]
        time.sleep(.25)
    raise AssertionError('Yerel posta kutusunda bağlantı yok: ' + kind)

def expect_auth_error(name, body, code):
    try:
        api.request('POST', '/auth/v1/token?grant_type=password', body)
        check(name, False)
    except api.ApiError as e:
        check(name, e.body.get('error_code') == code)

email = 'qa-auth-mail-' + datetime.datetime.now().strftime('%m%d%H%M%S') + '@pomosprint.local'
try:
    a = api.sign_up(email, 'QA Mail')
    uid = a['user']['id']
    # Yalnızca bu yeni yerel hesapta onay beklenmesini hazırla.
    subprocess.run(['psql', 'postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-Xq', '-v', 'ON_ERROR_STOP=1',
                    '-c', "update auth.users set email_confirmed_at=null where id='"+uid+"'"], check=True, capture_output=True)
    expect_auth_error('Onaysız e-posta ile giriş engellenir', {'email':email,'password':api.TEST_PASSWORD}, 'email_not_confirmed')
    before = {m['ID'] for m in mailbox()}
    api.request('POST', '/auth/v1/resend', {'type':'signup','email':email})
    token = token_for(email, 'signup', before)
    verified = api.request('POST', '/auth/v1/verify', {'type':'signup','token_hash':token})
    check('Gerçek yeniden gönderilen onay maili bağlantısı doğrulanır', verified['user']['email_confirmed_at'] is not None)
    signed = api.sign_in(email)
    check('Onaydan sonra normal parola ile giriş yapılır', signed['user']['id'] == uid)
    before = {m['ID'] for m in mailbox()}
    api.request('POST', '/auth/v1/recover', {'email':email})
    token = token_for(email, 'recovery', before)
    recovery = api.request('POST', '/auth/v1/verify', {'type':'recovery','token_hash':token})
    check('Gerçek parola sıfırlama mailinin bağlantısı oturum açar', recovery['user']['id'] == uid)
    new_password='QaReset-Yerel2026'
    api.request('PUT', '/auth/v1/user', {'password':new_password}, token=recovery['access_token'])
    expect_auth_error('Eski parola artık giriş yapamaz', {'email':email,'password':api.TEST_PASSWORD}, 'invalid_credentials')
    changed=api.request('POST','/auth/v1/token?grant_type=password',{'email':email,'password':new_password})
    check('Yeni parola ile giriş yapılır', changed['user']['id']==uid)
    try:
        api.request('POST','/auth/v1/verify',{'type':'recovery','token_hash':token})
        check('Sıfırlama bağlantısı ikinci kez kullanılamaz', False)
    except api.ApiError as e:
        check('Sıfırlama bağlantısı ikinci kez kullanılamaz', e.status>=400)
    response=api.request('POST','/auth/v1/recover',{'email':'does-not-exist-'+uid+'@pomosprint.local'})
    check('Olmayan e-posta sıfırlamada hesap varlığını açığa çıkarmaz', response=={})
    api.rpc('delete_own_account', token=changed['access_token'])
    check('Yerel test hesabı temizlendi', subprocess.check_output(['psql','postgresql://postgres:postgres@127.0.0.1:54322/postgres','-XAtq','-c',"select count(*) from auth.users where id='"+uid+"'"],text=True).strip()=='0')
finally:
    target=Path('build/e2e_auth_mail.json')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(RESULTS,ensure_ascii=False,indent=2)+'\n')
