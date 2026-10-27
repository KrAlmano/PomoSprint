#!/usr/bin/env python3
"""Create ONE new exact local insight fixture; never change an existing owner.

Base setup uses the existing Mailpit-confirmed two-TYT fixture creator. This
adds one ordinary completion RPC and changes this new owner's subject results
through save_exam_results RPC. No production/cross-owner writes or global clock
changes. All changes belong to the newly created owner; the base exam timestamps
are explicitly controlled historical fixtures.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from uuid import uuid4

from local_fixture_api import ROOT, FixtureError, assert_qa_owner, literal, rpc, sign_in, sql


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--email', required=True)
    args = parser.parse_args()
    email = args.email
    if not re.fullmatch(r'e2e-sim-exam-fixture-insight-[a-z0-9-]{1,30}@pomosprint\.local', email):
        raise FixtureError('Only the bounded exam-fixture-insight QA namespace is accepted')
    if sql(f'select count(*) from auth.users where email={literal(email)}') != '0':
        raise FixtureError('Existing email refused; use a new local QA suffix')
    base = subprocess.run([
        sys.executable, str(Path(__file__).with_name('create_exam_qa_fixture_account.py')),
        '--email', email,
    ], text=True, capture_output=True, timeout=90)
    if base.returncode:
        raise FixtureError('Base local fixture creation failed; its evidence is preserved')
    created = json.loads(base.stdout.strip().splitlines()[-1])
    owner = created['id']
    assert_qa_owner(owner, email)
    signed = sign_in(email)
    if signed['user']['id'] != owner:
        raise FixtureError('Local owner mismatch')
    token = signed['access_token']
    exams = json.loads(sql(
        'select jsonb_agg(jsonb_build_object(\'id\',id,\'exam_id\',exam_id,'
        "'started_at',started_at,'ends_at',ends_at,'status',status,'definition',definition) order by started_at) "
        f'from public.exam_attempts where user_id={literal(owner)}::uuid'
    ))
    if len(exams) != 2 or any(e['exam_id'] != 'tyt' or e['status'] != 'completed' for e in exams):
        raise FixtureError('Exactly the new base fixture\'s two completed TYTs are required')
    if sql(f'select count(*) from public.study_sessions where user_id={literal(owner)}::uuid') != '0':
        raise FixtureError('New owner must have no existing study sessions')
    if sql(f'select count(*) from public.profiles where id={literal(owner)}::uuid and active_session_ends_at>now()') != '0':
        raise FixtureError('Active session refused')
    first_end = datetime.fromisoformat(exams[0]['ends_at'])
    second_start = datetime.fromisoformat(exams[1]['started_at'])
    started = second_start - timedelta(minutes=45)
    now = datetime.now(timezone.utc)
    if not (first_end < started and started + timedelta(minutes=25) < second_start
            and now - timedelta(hours=23) < started < now - timedelta(minutes=26)):
        raise FixtureError('No safe historical 25-minute slot inside the ordinary 24-hour RPC limit')
    uid = str(uuid4())
    category = sql(f"select id::text from public.categories where user_id={literal(owner)}::uuid and name='Türkçe' and not is_archived")
    if not category:
        raise FixtureError('New owner Turkish category is missing')
    receipt = rpc('complete_study_session', {
        'p_client_uuid': uid, 'p_category_id': category,
        'p_duration_minutes': 25, 'p_was_paused': False,
        'p_is_verified': 0, 'p_started_at': started.isoformat(),
    }, token)
    if receipt.get('error') or receipt.get('duplicate') is True or receipt.get('total_points') != 5 or receipt.get('coins_earned') != 20:
        raise FixtureError('Ordinary local completion did not produce the expected 5 points/20 sand')
    for exam, correct, wrong in zip(exams, [20, 28], [3, 2]):
        payload = [dict(subject_id=s['id'],
                        correct=correct if s['id']=='turkish' else 0,
                        wrong=wrong if s['id']=='turkish' else 0,
                        blank=s['question_count']-(correct+wrong if s['id']=='turkish' else 0))
                   for s in exam['definition']['subjects']]
        rpc('save_exam_results', {'p_attempt_id': exam['id'], 'p_subject_results': payload}, token)
    result = json.loads(sql(
        "select jsonb_build_object('total_minutes',p.total_minutes,'normal_points',p.lifetime_points,"
        "'normal_coins',p.coins,'exam_points',w.lifetime_points,'exam_coins',w.coins,"
        "'study_count',(select count(*) from public.study_sessions where user_id=p.id),"
        "'nets',(select jsonb_agg(r.net order by a.started_at) from public.exam_attempts a "
        "join public.exam_subject_results r on r.attempt_id=a.id and r.subject_id='turkish' where a.user_id=p.id)) "
        f'from public.profiles p join public.exam_wallets w on w.user_id=p.id where p.id={literal(owner)}::uuid'
    ))
    if result != dict(total_minutes=355, normal_points=5, normal_coins=20,
                      exam_points=66, exam_coins=12, study_count=1, nets=[19.25,27.5]):
        raise FixtureError('Final local insight fixture did not match the expected values')
    report = dict(fixture='controlled-positive-exam-time-insight', owner_id=owner, email=email,
                  base_manifest=created['manifest'], normal_client_uuid=uid,
                  normal_started_at=started.isoformat(), real_wait_minutes=0, result=result,
                  scope='2 controlled historical TYTs plus 1 ordinary historical 25-minute completion RPC; no real-duration test')
    target = ROOT/'build/overnight_backend'/f'exam_insight_fixture_{owner}.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'owner_id':owner,'email':email,'manifest':str(target),'result':result}, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (FixtureError, ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
        print('Local insight fixture stopped safely:', str(error), file=sys.stderr)
        sys.exit(1)
