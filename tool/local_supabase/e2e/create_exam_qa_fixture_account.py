#!/usr/bin/env python3
"""Create one NEW explicit local QA account, confirm Mailpit, seed TYT history.

This is a controlled historical fixture, not a 330-minute native test. No
existing account/attempt is changed. All network/database endpoints are fixed
loopback helpers; no environment file or persisted token is used.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys

from local_fixture_api import ROOT, FixtureError, literal, password, request, rpc, sign_in, sql
from create_exam_history_fixture import create
sys.path.insert(0, str(ROOT/'tool/local_supabase/e2e/sim'))
from local_mailpit import confirm_local_email


def validate_fixture_email(email):
    """Accept only the two bounded local QA namespaces used by o/x and w."""
    if not isinstance(email, str) or not re.fullmatch(
        r'e2e-sim-(?:exam-fixture|http-normal)-[a-z0-9-]{1,40}@pomosprint\.local', email
    ):
        raise FixtureError('Use a bounded local exam-fixture or http-normal QA email')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--email', required=True)
    args = parser.parse_args()
    email = args.email
    validate_fixture_email(email)
    if sql(f'select count(*)from auth.users where email={literal(email)}') != '0':
        raise FixtureError('Account already exists; no existing user is modified')
    now = datetime.now(timezone.utc).isoformat()
    response = request('POST', '/auth/v1/signup', {
        'email': email, 'password': password(), 'data': {
            'name': 'QA Deneme Gecmisi', 'avatar_id': 'avatar_16_basic',
            'qa_fixture_run': email.split('@')[0], 'newsletter': False,
            'marketing_consent': False, 'terms_version': '2026-10-03',
            'privacy_version': '2026-10-03', 'terms_accepted_at': now,
        },
    })
    owner = (response.get('user') or response)['id']
    if response.get('access_token'):
        raise FixtureError('Expected local email confirmation')
    confirm_local_email(email)
    signed = sign_in(email)
    if signed['user']['id'] != owner:
        raise FixtureError('Confirmed login owner mismatch')
    token = signed['access_token']
    rpc('setup_onboarding_categories', {'p_categories': [
        {'name': 'Türkçe', 'color_hex': '#E53935', 'icon_name': 'book'},
        {'name': 'Matematik', 'color_hex': '#1565C0', 'icon_name': 'book'},
    ]}, token)
    request('PATCH', '/rest/v1/profiles?id=eq.'+owner, {
        'birth_year': 2000, 'user_segment': 'yks', 'daily_goal_minutes': 120,
        'show_in_social_feed': True, 'onboarding_completed_at': now,
    }, token)
    allow = Path('/tmp')/f'pomosprint_exam_fixture_{owner}.json'
    allow.write_text(json.dumps({'owners': [{'id': owner, 'email': email}]}))
    report = create(owner, email, allow)
    totals = json.loads(sql(
        "select jsonb_build_object('minutes',p.total_minutes,'normal_points',p.lifetime_points,"
        "'normal_coins',p.coins,'exam_points',w.lifetime_points,'exam_coins',w.coins)"
        f'from public.profiles p join public.exam_wallets w on w.user_id=p.id where p.id={literal(owner)}::uuid'
    ))
    if totals != {'minutes': 330, 'normal_points': 0, 'normal_coins': 0,
                  'exam_points': 66, 'exam_coins': 12}:
        raise FixtureError('Unexpected fixture totals')
    if [row['turkish_net'] for row in report['attempts']] != [19, 27]:
        raise FixtureError('Unexpected fixture nets')
    report.update({'totals': totals, 'allowlist': str(allow),
                   'setup': 'real local signup + Mailpit confirmation + onboarding API',
                   'reuse_policy': 'rerun refuses an existing email; use a new explicit QA suffix'})
    target = ROOT/'build/overnight_backend'/f'exam_qa_account_{owner}.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'id': owner, 'email': email, 'totals': totals, 'manifest': str(target)}, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (FixtureError, ValueError, OSError, KeyError) as error:
        print('Local exam fixture stopped safely:', str(error), file=sys.stderr)
        sys.exit(1)
