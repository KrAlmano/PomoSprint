#!/usr/bin/env python3
"""Nine real local accounts: one native observer and eight API-driven friends.

No token/password is persisted. Presence fixtures do not claim eight native
devices, full Marathon runs, or completed wall-clock exam sessions.
"""
import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import json
import re
import sys

from local_fixture_api import ROOT, FixtureError, assert_qa_owner, literal, password, request, rpc, sign_in, sql
sys.path.insert(0, str(ROOT/'tool/local_supabase/e2e/sim'))
from local_mailpit import confirm_local_email

ROLES = [('observer', 'QA Gozlemci', None)] + [
    (f'focus{i}', f'QA Odak {i}', 'focus') for i in range(1, 5)
] + [(f'break{i}', f'QA Mola {i}', 'break') for i in range(1, 3)] + [
    (f'exam{i}', f'QA Deneme {i}', 'exam') for i in range(1, 3)
]


def manifest_path(run):
    if not re.fullmatch(r'[a-z0-9-]{1,32}', run):
        raise FixtureError('Run id must be a short lowercase QA label')
    return ROOT/'build/overnight_backend'/f'i08_multiuser_{run}.json'


def write_manifest(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def load_manifest(run):
    path = manifest_path(run)
    value = json.loads(path.read_text())
    if value.get('fixture') != 'i08-local-only' or value.get('run_id') != run:
        raise FixtureError('Wrong local fixture manifest')
    for account in value['accounts']:
        assert_qa_owner(account['id'], account['email'])
        if account['email'] != f"qa-i08-{run}-{account['role']}@pomosprint.local":
            raise FixtureError('Manifest owner does not match this run')
        marker = sql(f"select raw_user_meta_data->>'qa_fixture_run' from auth.users where id={literal(account['id'])}::uuid")
        if marker != run:
            raise FixtureError('Missing fixture owner marker')
    return path, value


def account_token(account):
    signed = sign_in(account['email'])
    if signed['user']['id'] != account['id']:
        raise FixtureError('Login did not match the manifest owner')
    return signed['access_token']


def set_presence(account, token):
    state = account['expected_status']
    if state is None:
        return
    if state == 'focus':
        rpc('start_study_session', {'p_duration_minutes': 25, 'p_category_name': 'Matematik'}, token)
    elif state == 'break':
        # Server-clock timestamp and real 5-minute limit, no clock shortening.
        server = rpc('get_exam_config')['server_time']
        end = datetime.fromisoformat(server.replace('Z', '+00:00')) + timedelta(minutes=5)
        rpc('start_study_break', {'p_ends_at': end.isoformat()}, token)
    elif state == 'exam':
        history = rpc('get_my_exam_attempts', {'p_limit': 100}, token)['attempts']
        active = next((row for row in history if row['status'] == 'active'), None)
        if active is None:
            from uuid import uuid4
            rpc('start_exam_attempt', {
                'p_client_uuid': str(uuid4()),
                'p_exam_id': 'lgs_verbal' if account['role'] == 'exam1' else 'tus_basic',
            }, token)


def check_rows(value, observer_token):
    rows = rpc('get_live_friends_with_breaks', token=observer_token)
    expected = {a['id']: a['expected_status'] for a in value['accounts'] if a['role'] != 'observer'}
    if len(rows) != 8 or len({row['id'] for row in rows}) != 8:
        raise FixtureError('Expected exactly eight distinct live friends')
    if {row['id']: row['status'] for row in rows} != expected:
        raise FixtureError('Live statuses differ from the eight-account fixture')
    if Counter(row['status'] for row in rows) != {'focus': 4, 'break': 2, 'exam': 2}:
        raise FixtureError('Expected four focus, two break and two exam rows')
    friends = rpc('get_my_friends', token=observer_token)
    if {row['id'] for row in friends} != set(expected):
        raise FixtureError('Accepted friend list differs from the fixture')
    return [{'id': row['id'], 'name': row['name'], 'status': row['status'], 'ends_at': row['ends_at']} for row in rows]


def setup(run):
    path = manifest_path(run)
    if path.exists():
        raise FixtureError('Manifest exists; use check/refresh/cleanup or a new run id')
    value = {'fixture': 'i08-local-only', 'run_id': run, 'created_at': datetime.now(timezone.utc).isoformat(),
             'scope': '9 local email-confirmed API accounts; native observer is run separately; presence is not completed study time',
             'accounts': [], 'ready': False}
    tokens = {}
    codes = {}
    for role, label, state in ROLES:
        email = f'qa-i08-{run}-{role}@pomosprint.local'
        response = request('POST', '/auth/v1/signup', {'email': email, 'password': password(), 'data': {
            'name': label, 'avatar_id': 'avatar_16_basic', 'qa_fixture_run': run,
            'newsletter': False, 'marketing_consent': False, 'terms_version': '2026-10-03',
            'privacy_version': '2026-10-03', 'terms_accepted_at': datetime.now(timezone.utc).isoformat(),
        }})
        who = (response.get('user') or response)['id']
        account = {'role': role, 'label': label, 'email': email, 'id': who, 'expected_status': state}
        value['accounts'].append(account)
        write_manifest(path, value)
        if response.get('access_token'):
            raise FixtureError('Expected email confirmation to be enabled')
        confirm_local_email(email)
        token = account_token(account)
        tokens[role] = token
        rpc('setup_onboarding_categories', {'p_categories': [
            {'name': 'Matematik', 'color_hex': '#E53935', 'icon_name': 'book'},
        ]}, token)
        request('PATCH', '/rest/v1/profiles?id=eq.'+who, {
            'birth_year': 2000, 'user_segment': 'yks', 'daily_goal_minutes': 120,
            'show_in_social_feed': True, 'onboarding_completed_at': datetime.now(timezone.utc).isoformat(),
        }, token)
        profile = request('GET', '/rest/v1/profiles?select=id,name,friend_code&id=eq.'+who, token=token)[0]
        codes[role] = profile['friend_code']
        account['label'] = profile['name']
        print('Created and email-confirmed local QA role:', role, flush=True)
    observer = value['accounts'][0]
    for account in value['accounts'][1:]:
        added = rpc('add_friend_by_code', {'p_code': codes[account['role']]}, tokens['observer'])
        if added.get('success') is not True:
            raise FixtureError('Friend request was not accepted by the server')
        accepted = rpc('respond_friend_request', {'p_from_user_id': observer['id'], 'p_accept': True}, tokens[account['role']])
        if accepted.get('success') is not True:
            raise FixtureError('Friend acceptance failed')
        reverse = rpc('get_my_friends', token=tokens[account['role']])
        if observer['id'] not in {r['id'] for r in reverse}:
            raise FixtureError('Reverse accepted friendship missing')
        set_presence(account, tokens[account['role']])
    value['proof_rows'] = check_rows(value, tokens['observer'])
    value['ready'] = True
    value['checked_at'] = datetime.now(timezone.utc).isoformat()
    write_manifest(path, value)
    print('PASS: 8 accepted friends, 4 focus + 2 break + 2 exam; manifest:', path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['setup', 'check', 'refresh', 'cleanup'])
    parser.add_argument('--run-id', required=True)
    args = parser.parse_args()
    if args.action == 'setup':
        setup(args.run_id)
        return
    path, value = load_manifest(args.run_id)
    if args.action == 'cleanup':
        # Explicit exact UID + email + fixture marker; never broad QA deletion.
        for account in value['accounts']:
            sql(f"delete from auth.users where id={literal(account['id'])}::uuid and email={literal(account['email'])} and raw_user_meta_data->>'qa_fixture_run'={literal(args.run_id)}")
        value['cleaned_at'] = datetime.now(timezone.utc).isoformat()
        write_manifest(path, value)
        print('Cleaned only the explicitly listed local fixture owners')
        return
    if args.action == 'refresh':
        for account in value['accounts'][1:]:
            set_presence(account, account_token(account))
    value['proof_rows'] = check_rows(value, account_token(value['accounts'][0]))
    value['checked_at'] = datetime.now(timezone.utc).isoformat()
    write_manifest(path, value)
    print('PASS: all eight friend identities and expected live statuses')


if __name__ == '__main__':
    try:
        main()
    except (FixtureError, ValueError, KeyError) as error:
        print('Fixture stopped safely:', str(error), file=sys.stderr)
        sys.exit(1)
