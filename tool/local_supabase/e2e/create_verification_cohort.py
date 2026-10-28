#!/usr/bin/env python3
"""Four NEW fixed-loopback QA accounts for category/Global league checks.

Default is a read-only plan. --apply --allow-historical-metadata explicitly
creates accounts via local Auth/Mailpit and seeds public completion RPCs.
Only the newly started attempt's two date fields are controlled fixtures.
No economy column, existing account, catalog, function or policy is assigned.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from uuid import uuid4

from local_fixture_api import ROOT, FixtureError, literal, password, request, require_local, rpc, sign_in, sql
from verify_reports_and_exams import verify_owner

sys.path.insert(0,str(ROOT/'tool/local_supabase/e2e/sim'))
from local_mailpit import confirm_local_email

ROLES=(('lgs-a','lgs',4,'lgs_verbal',4500,15,3),
       ('lgs-b','lgs',3,'lgs_verbal',4500,15,3),
       ('tus-a','tus',5,'tus_basic',8100,27,5),
       ('tus-b','tus',2,'tus_basic',8100,27,5))
OFFICIAL={'tyt':(9900,120),'ayt':(10800,160),'ydt':(7200,80),
          'lgs_verbal':(4500,50),'lgs_quantitative':(4800,40),
          'tus_basic':(8100,100),'tus_clinical':(8100,100)}


def plan(run):
    if not isinstance(run,str) or not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?',run):
        raise FixtureError('Use a lowercase, bounded QA cohort run id')
    return [{'role':role,'segment':segment,'normal_count':count,'exam_id':exam,
             'duration_seconds':duration,'exam_points':points,'exam_coins':coins,
             'email':f'e2e-sim-cohort-{run}-{role}@pomosprint.local',
             'name':{'lgs-a':'Deniz LGS','lgs-b':'Ece LGS','tus-a':'Arda TUS','tus-b':'Selin TUS'}[role]}
            for role,segment,count,exam,duration,points,coins in ROLES]


def official_preflight(rows):
    require_local()
    if any(value for key,value in os.environ.items() if key.startswith('PG')):
        raise FixtureError('Inherited libpq routing or credential-file overrides are forbidden')
    process=subprocess.run(['bash','tool/local_supabase/parity_check.sh',
                            '--reviewed-night-20261028-with-start-atomic'],
                           cwd=ROOT,capture_output=True,text=True,timeout=60)
    if process.returncode:
        raise FixtureError('Reviewed 27-30 local parity required; catalog must be restored;31 must remain absent')
    actual=json.loads(sql("select jsonb_object_agg(id,jsonb_build_array((definition->>'duration_seconds')::int,(definition->>'total_questions')::int)) from public.exam_catalog where enabled"))
    if actual!={k:list(v) for k,v in OFFICIAL.items()}:
        raise FixtureError('Exact official exam catalog is required before creating cohort')
    for row in rows:
        if sql(f"select count(*) from auth.users where email={literal(row['email'])}")!='0':
            raise FixtureError('Cohort email exists; no account will be reused or reset')


def history_times(anchor,count,duration):
    if count not in range(1,9) or duration not in (4500,8100):
        raise FixtureError('Cohort supports bounded normal counts and official LGS/TUS durations')
    normal=[anchor-timedelta(hours=9)+timedelta(minutes=30*i) for i in range(count)]
    exam_start=anchor-timedelta(hours=5);exam_end=exam_start+timedelta(seconds=duration)
    if normal[-1]+timedelta(minutes=25)>exam_start or exam_end>=anchor-timedelta(minutes=30):
        raise FixtureError('Historical cohort intervals overlap or are not safely elapsed')
    return normal,exam_start,exam_end


def date_fixture_sql(owner,email,run,role,attempt_id,client_uuid,start,end,duration):
    # Every interpolated string is SQL-quoted. The exact newly created Auth
    # identity, metadata, attempt/client UUID and full frozen duration guard
    # precede the only UPDATE (new attempt dates, never economic fields).
    return f"""BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='15s';
DO $cohort$
DECLARE changed integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id={literal(owner)}::uuid AND email={literal(email)}
  AND created_at>clock_timestamp()-interval '30 minutes'
  AND raw_user_meta_data->>'qa_verification_cohort'={literal(run)}
  AND raw_user_meta_data->>'qa_verification_role'={literal(role)})
 THEN RAISE EXCEPTION 'cohort_new_owner_guard'; END IF;
 IF (SELECT count(*) FROM public.exam_attempts WHERE user_id={literal(owner)}::uuid)<>1
 THEN RAISE EXCEPTION 'cohort_expected_one_new_attempt'; END IF;
 UPDATE public.exam_attempts SET started_at={literal(start.isoformat())}::timestamptz,
 ends_at={literal(end.isoformat())}::timestamptz
 WHERE id={literal(attempt_id)}::uuid AND user_id={literal(owner)}::uuid
 AND client_uuid={literal(client_uuid)}::uuid AND status='active' AND finished_at IS NULL
 AND started_at>clock_timestamp()-interval '10 minutes'
 AND (definition->>'duration_seconds')::int={int(duration)};
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'cohort_new_attempt_date_guard'; END IF;
END $cohort$;
SELECT jsonb_build_object('new_attempt_dates_fixture',true,'economic_columns_assigned',false);
COMMIT;"""


def _save(target,report):
    target.parent.mkdir(parents=True,exist_ok=True)
    temporary=target.with_suffix('.tmp')
    temporary.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    temporary.replace(target)


def create_account(row,run,anchor,report,target):
    current=datetime.now(timezone.utc).isoformat()
    response=request('POST','/auth/v1/signup',{'email':row['email'],'password':password(),'data':{
        'name':row['name'],'avatar_id':'avatar_16_basic','qa_verification_cohort':run,
        'qa_verification_role':row['role'],'newsletter':False,'marketing_consent':False,
        'terms_version':'2026-10-03','privacy_version':'2026-10-03','terms_accepted_at':current}})
    owner=(response.get('user') or response)['id']
    item={**row,'id':owner,'stage':'signup_created','normal_client_uuids':[]}
    report['accounts'].append(item);_save(target,report)
    if response.get('access_token'):
        raise FixtureError('Expected local Mailpit confirmation before login')
    confirm_local_email(row['email']);signed=sign_in(row['email'])
    if signed['user']['id']!=owner:raise FixtureError('Confirmed cohort owner differs')
    token=signed['access_token']  # Memory only; never serialize Auth responses.
    rpc('setup_onboarding_categories',{'p_categories':[{'name':'Matematik','color_hex':'#1565C0','icon_name':'book'}]},token)
    request('PATCH','/rest/v1/profiles?id=eq.'+owner,{'birth_year':2000,'user_segment':row['segment'],
        'daily_goal_minutes':120,'timezone':'Europe/Istanbul','show_in_social_feed':True,'onboarding_completed_at':current},token)
    category=sql(f"select id from public.categories where user_id={literal(owner)}::uuid and not is_archived order by sort_order,id limit 1")
    normal_starts,start,end=history_times(anchor,row['normal_count'],row['duration_seconds'])
    for at in normal_starts:
        client=str(uuid4());receipt=rpc('complete_study_session',{'p_client_uuid':client,'p_category_id':category,
            'p_duration_minutes':25,'p_was_paused':False,'p_is_verified':0,'p_started_at':at.isoformat()},token)
        if receipt.get('error') or receipt.get('duplicate') or receipt.get('total_points')!=5 or receipt.get('coins_earned')!=20:
            raise FixtureError('Historical normal completion was not one fresh standard reward')
        item['normal_client_uuids'].append(client)
    client=str(uuid4());attempt=rpc('start_exam_attempt',{'p_client_uuid':client,'p_exam_id':row['exam_id']},token)['attempt']
    if attempt['definition']['duration_seconds']!=row['duration_seconds']:
        raise FixtureError('Exam definition changed during cohort creation')
    item.update(stage='exam_started',attempt_id=attempt['id'],exam_client_uuid=client);_save(target,report)
    sql(date_fixture_sql(owner,row['email'],run,row['role'],attempt['id'],client,start,end,row['duration_seconds']))
    completed=rpc('complete_exam_attempt',{'p_attempt_id':attempt['id']},token)['attempt']
    if (completed['status'],completed['points_earned'],completed['exam_coins_earned'])!=('completed',row['exam_points'],row['exam_coins']):
        raise FixtureError('Historical exam completion accounting mismatch')
    subject=completed['definition']['subjects'][0];questions=subject['question_count']
    correct=min(questions-4,12);wrong=3;blank=questions-correct-wrong
    before=json.loads(sql(f"select jsonb_build_array(p.total_minutes,p.lifetime_points,p.coins,w.lifetime_points,w.coins) from public.profiles p join public.exam_wallets w on w.user_id=p.id where p.id={literal(owner)}::uuid"))
    rpc('save_exam_results',{'p_attempt_id':attempt['id'],'p_subject_results':[{'subject_id':subject['id'],
        'correct':correct,'wrong':wrong,'blank':blank}]},token)
    after=json.loads(sql(f"select jsonb_build_array(p.total_minutes,p.lifetime_points,p.coins,w.lifetime_points,w.coins) from public.profiles p join public.exam_wallets w on w.user_id=p.id where p.id={literal(owner)}::uuid"))
    expected=[row['normal_count']*25+row['duration_seconds']//60,row['normal_count']*5,row['normal_count']*20,row['exam_points'],row['exam_coins']]
    if before!=after or after!=expected:raise FixtureError('Cohort net changed economy or totals differ')
    verification=verify_owner(owner)
    if verification['status']!='PASS' or verification['warnings']:
        raise FixtureError('Independent cohort accounting verification requires review')
    item.update(stage='completed',economy={'total_minutes':after[0],'normal_points':after[1],
        'normal_coins':after[2],'exam_points':after[3],'exam_coins':after[4]},
        verification_checks=verification['total_checks'],historical_exam_started_at=start.isoformat(),
        historical_exam_ends_at=end.isoformat())
    _save(target,report)


def same_room_check(accounts):
    owners=','.join(literal(a['id'])+'::uuid' for a in accounts)
    memberships=json.loads(sql(f"select coalesce(jsonb_agg(to_jsonb(x)),'[]') from (select m.user_id,m.kind,m.room_id,r.segment from public.competition_memberships m join public.competition_rooms r on r.id=m.room_id where m.user_id in({owners}) and m.period_month=public._competition_month(clock_timestamp()) order by m.user_id,m.kind)x"))
    by_owner_kind={(m['user_id'],m['kind']):m for m in memberships}
    for segment in ('lgs','tus'):
        peers=[a for a in accounts if a['segment']==segment]
        for kind in ('study','exam'):
            selected=[by_owner_kind.get((a['id'],kind)) for a in peers]
            if (len(peers)!=2 or any(m is None or m['segment']!=segment for m in selected)
                    or len({m['room_id'] for m in selected if m})!=1):
                raise FixtureError('Cohort peers allocated to different rooms; preserve them and choose a new run, never force-move members')
    return memberships


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',required=True)
    parser.add_argument('--apply',action='store_true');parser.add_argument('--allow-historical-metadata',action='store_true')
    args=parser.parse_args();rows=plan(args.run)
    if args.apply and not args.allow_historical_metadata:
        raise FixtureError('Explicit --allow-historical-metadata is required with --apply')
    official_preflight(rows)
    if not args.apply:
        print(json.dumps({'applied':False,'run':args.run,'accounts':rows,
            'scope':'read-only plan; no Auth or data mutation'},ensure_ascii=False));return 0
    target=ROOT/'build/verification_20261028'/f'cohort_{args.run}.json'
    if target.exists():raise FixtureError('Manifest exists; no cohort overwrite/reuse is permitted')
    report={'run':args.run,'status':'creating','local_only':True,'uses_historical_fixture':True,
            'natural_elapsed_test':False,'tokens_persisted':False,'accounts':[],'planned_accounts':rows,
            'scope':'Real local Auth/Mailpit/onboarding and public completion/net RPCs; controlled normal starts and newly-created exam date metadata, never direct economic writes'}
    _save(target,report)
    try:
        anchor=datetime.fromisoformat(sql('select clock_timestamp()'))
        for row in rows:create_account(row,args.run,anchor,report,target)
        report['memberships']=same_room_check(report['accounts'])
        report.update(status='ready',completed_at=datetime.now(timezone.utc).isoformat());_save(target,report)
    except Exception:
        report['status']='failed_partial_preserved';_save(target,report)
        # Auth/API operations span transactions. Do not disguise this as an
        # all-or-nothing rollback or delete forensic evidence on failure.
        raise
    print(json.dumps({'status':'ready','run':args.run,'manifest':str(target),'owners':[a['id'] for a in report['accounts']],
                      'natural_elapsed_test':False,'tokens_persisted':False}));return 0


if __name__=='__main__':
    try:raise SystemExit(main())
    except FixtureError as error:
        print('Local cohort stopped safely: '+str(error)+'. Partial QA accounts are preserved.',file=sys.stderr)
        raise SystemExit(1) from None
    except (ValueError,KeyError,OSError,subprocess.TimeoutExpired):
        print('Local cohort stopped safely; partial QA accounts (if any) are preserved in the manifest.',file=sys.stderr)
        raise SystemExit(1) from None
