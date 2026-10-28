#!/usr/bin/env python3
"""Read-only, fixed-loopback accounting oracle for a named local QA account.

No dotenv, hosted request, mutable SQL, or Flutter calculation is used. The
snapshot comes from one repeatable-read transaction. Report arithmetic uses
Python calendar/Decimal primitives and the stored exam definition snapshot.
"""
from __future__ import annotations

import argparse
import calendar
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ROOT = Path(__file__).resolve().parents[3]
DB = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
PROFILES = {
    'main': (DB, 'http://127.0.0.1:54321', 'postgres'),
    'review': ('postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_review32_dus', 'http://127.0.0.1:54351', 'pomosprint_review32_dus'),
    'site': ('postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_site32_dus', 'http://127.0.0.1:54361', 'pomosprint_site32_dus'),
    'kpss': ('postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_review32_kpss', 'http://127.0.0.1:54401', 'pomosprint_review32_kpss'),
}
MAX_ROWS = 10000
EXAM_CATEGORY = 'pomosprint:exam'
QA_EMAIL = re.compile(r'^(?:e2e-sim-|qa-)[a-z0-9._+-]+@pomosprint\.local$')


class VerificationError(Exception):
    """Public, credential-free failure; database output is never echoed."""


def owner_uuid(value):
    try:
        if str(UUID(value)) != value:
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise VerificationError('invalid_qa_owner') from None
    return value


def instant(value):
    if isinstance(value, datetime):
        result = value
    else:
        result = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise VerificationError('timestamp_requires_offset')
    return result.astimezone(timezone.utc)


def workday(value, zone):
    local = instant(value).astimezone(ZoneInfo(zone))
    return local.date() - timedelta(days=local.hour < 4)


def month_of(value):
    local = instant(value).astimezone(ZoneInfo('Europe/Istanbul'))
    return date(local.year, local.month, 1).isoformat()


def _profile(value):
    if value not in PROFILES:
        raise VerificationError('unknown_fixed_database_profile')
    return PROFILES[value]


def _qa_email(email, owner, profile):
    return bool(QA_EMAIL.fullmatch(email or '')) or (
        profile in {'review', 'kpss'} and email == f'review32-{owner}@pomosprint.local')


def _local_guard(profile='main'):
    db, api, _ = _profile(profile)
    if os.environ.get('LOCAL_DB_URL', db) != db:
        raise VerificationError('only_fixed_loopback_database_allowed')
    if os.environ.get('LOCAL_SUPABASE_URL', api) != api:
        raise VerificationError('only_fixed_loopback_api_allowed')


def _psql(body, profile='main'):
    _local_guard(profile)
    # A PGHOSTADDR/PGSERVICE inherited from another project must not redirect
    # libpq despite the fixed host in the URI. Do not inherit any PG routing,
    # password-file, service-file or option variables.
    env = {key:value for key,value in os.environ.items() if not key.startswith('PG')}
    env.update(PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000',
               PGCONNECT_TIMEOUT='5')
    try:
        process = subprocess.run(['psql', _profile(profile)[0], '-XqAt', '-v', 'ON_ERROR_STOP=1'],
                                 input=body, capture_output=True, text=True, timeout=20, env=env)
    except (OSError, subprocess.TimeoutExpired):
        raise VerificationError('local_database_unavailable') from None
    if process.returncode:
        raise VerificationError('local_readonly_snapshot_failed')
    if len(process.stdout) > 16 * 1024 * 1024:
        raise VerificationError('snapshot_too_large')
    try:
        return json.loads(process.stdout, parse_float=Decimal)
    except (ValueError, TypeError):
        raise VerificationError('invalid_local_snapshot') from None


def read_snapshot(owner, profile='main'):
    owner = owner_uuid(owner)
    # Only a canonical UUID is interpolated. Every subquery is owner-scoped;
    # no password, token, friend code or unrelated account data is projected.
    return _psql(f"""
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT jsonb_build_object(
 'captured_at',clock_timestamp(),
 'database',current_database(),
 'schema_versions',(SELECT coalesce(jsonb_agg(version ORDER BY version),'[]')
   FROM supabase_migrations.schema_migrations WHERE version>='20261028010000'),
 'marathon_function_md5',md5(pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure)),
 'qa_email',(SELECT email FROM auth.users WHERE id='{owner}'),
 'profile',(SELECT jsonb_build_object('id',id,'total_minutes',total_minutes,
   'lifetime_points',lifetime_points,'coins',coins,'current_streak',current_streak,
   'longest_streak',longest_streak,'last_study_date',last_study_date,
   'timezone',timezone,'daily_goal_minutes',daily_goal_minutes) FROM public.profiles WHERE id='{owner}'),
 'studies',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT s.*,coalesce(c.name,s.category) AS category_name FROM public.study_sessions s
   LEFT JOIN public.categories c ON c.id=s.category_id AND c.user_id=s.user_id
   WHERE s.user_id='{owner}' ORDER BY s.started_at,s.id LIMIT {MAX_ROWS+1})x),
 'attempts',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT * FROM public.exam_attempts WHERE user_id='{owner}' ORDER BY started_at,id LIMIT {MAX_ROWS+1})x),
 'attempt_payloads',(SELECT coalesce(jsonb_agg(public._exam_payload(x.id)),'[]') FROM (
   SELECT id FROM public.exam_attempts WHERE user_id='{owner}' ORDER BY started_at,id LIMIT {MAX_ROWS+1})x),
 'results',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT r.* FROM public.exam_subject_results r JOIN public.exam_attempts a ON a.id=r.attempt_id
   WHERE a.user_id='{owner}' ORDER BY r.attempt_id,r.subject_id LIMIT {MAX_ROWS+1})x),
 'wallet',(SELECT jsonb_build_object('coins',coins,'lifetime_points',lifetime_points)
   FROM public.exam_wallets WHERE user_id='{owner}'),
 'runs',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT * FROM public.marathon_runs WHERE user_id='{owner}' ORDER BY client_uuid LIMIT {MAX_ROWS+1})x),
 'mappings',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT * FROM public.marathon_run_sessions WHERE user_id='{owner}' ORDER BY marathon_uuid,session_index LIMIT {MAX_ROWS+1})x),
 'events',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT * FROM public.competition_events WHERE user_id='{owner}' ORDER BY kind,source_id LIMIT {MAX_ROWS+1})x),
 'unlocks',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
   SELECT avatar_id,coins_spent FROM public.avatar_unlocks WHERE user_id='{owner}' ORDER BY avatar_id LIMIT {MAX_ROWS+1})x));
ROLLBACK;
""", profile=profile)


def check_peer_rls(owner, peer, profile='main'):
    owner, peer = owner_uuid(owner), owner_uuid(peer)
    if owner == peer:
        raise VerificationError('rls_peer_must_differ')
    # Check both owners before switching role; both must be explicit local QA.
    pair = _psql(f"""BEGIN READ ONLY; SELECT jsonb_build_object(
      'emails',(SELECT jsonb_agg(email) FROM auth.users WHERE id IN('{owner}','{peer}')),
      'attempt_count',(SELECT count(*) FROM public.exam_attempts WHERE user_id='{owner}'),
      'result_count',(SELECT count(*) FROM public.exam_subject_results r JOIN public.exam_attempts a
       ON a.id=r.attempt_id WHERE a.user_id='{owner}')); ROLLBACK;""", profile=profile)
    emails = pair.get('emails') if isinstance(pair, dict) else None
    if not isinstance(emails, list) or len(emails) != 2 or not all(_qa_email(x,owner,profile) or _qa_email(x,peer,profile) for x in emails):
        raise VerificationError('rls_requires_two_local_qa_owners')
    if pair.get('attempt_count',0)<1 or pair.get('result_count',0)<1:
        raise VerificationError('rls_source_needs_exam_and_subject_rows')
    return _psql(f"""BEGIN READ ONLY;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims='{{"sub":"{peer}","role":"authenticated"}}';
SELECT jsonb_build_object('peer_exam_attempts_visible',
 (SELECT count(*) FROM public.exam_attempts WHERE user_id='{owner}'),
 'peer_subject_results_visible',(SELECT count(*) FROM public.exam_subject_results r
 JOIN public.exam_attempts a ON a.id=r.attempt_id WHERE a.user_id='{owner}'),
 'peer_wallets_visible',(SELECT count(*) FROM public.exam_wallets WHERE user_id='{owner}'));
ROLLBACK;""", profile=profile)


def _rounded_percentages(rows):
    total = sum(r['minutes'] for r in rows)
    if not total:
        return [0] * len(rows)
    values = [r['minutes'] * 100 // total for r in rows]
    order = sorted(range(len(rows)), key=lambda i: (-(rows[i]['minutes'] * 100 % total), i))
    for i in order[:100-sum(values)]:
        values[i] += 1
    return values


def _rounded_change(current, previous):
    if previous <= 0:
        return None
    raw = Decimal(current-previous) * 100 / previous
    # Dart rounds midpoint away from zero; Decimal's default is half-even.
    from decimal import ROUND_HALF_UP
    return int(raw.quantize(Decimal('1'), rounding=ROUND_HALF_UP))


def _report(records, completed_runs, start, end, goal, today):
    ranged = [r for r in records if start <= r['day'] <= end]
    minutes = sum(r['minutes'] for r in ranged)
    groups = {}
    for record in ranged:
        key = record['category_id'] or 'name:' + record['category_name']
        group = groups.setdefault(key, {'category_id': record['category_id'], 'name': record['category_name'],
                                        'minutes': 0, 'sessions': 0, 'focus_equivalents': 0})
        group['minutes'] += record['minutes']; group['sessions'] += 1
        group['focus_equivalents'] += record['minutes']//25 if record['kind'] != 'exam' else 0
    categories = sorted(groups.values(), key=lambda r: (-r['minutes'], r['name']))
    for row, percent in zip(categories, _rounded_percentages(categories)):
        row['percentage'] = percent
    counts = Counter(r['kind'] for r in ranged)
    days = []
    current = start
    while current <= end:
        chosen = [r for r in ranged if r['day'] == current]
        days.append({'day': current.isoformat(), 'minutes': sum(r['minutes'] for r in chosen),
                     'focus_equivalents': sum(r['minutes']//25 for r in chosen if r['kind'] != 'exam')})
        current += timedelta(days=1)
    busiest = max(days, key=lambda x:x['minutes']) if days else None
    if busiest and not busiest['minutes']:
        busiest = None
    return {'start': start.isoformat(), 'end': end.isoformat(), 'total_minutes': minutes,
            'focus_equivalents': sum(r['minutes']//25 for r in ranged if r['kind'] != 'exam'),
            'counts': {'normal_sessions': counts['normal'], 'marathon_focus_sessions': counts['marathon'],
                       'completed_marathons': sum(start <= d <= end for d in completed_runs.values()),
                       'completed_exams': counts['exam'], 'unknown_sessions': 0, 'pending_sessions': 0},
            'categories': categories,
            'category_minutes': {r['category_id'] or 'name:'+r['name']:r['minutes'] for r in categories},
            'category_percentages': {r['category_id'] or 'name:'+r['name']:r['percentage'] for r in categories},
            'days': days, 'busiest_day': busiest,
            'active_days': sum(d['minutes'] > 0 for d in days), 'goal_minutes': goal,
            'goal_percentage': min(100, minutes*100//goal) if goal > 0 else 0,
            'goal_progress_percentage': minutes*100//goal if goal > 0 else 0}


def analyze_snapshot(snapshot, as_of=None, rls=None, profile='main'):
    if not isinstance(snapshot, dict) or snapshot.get('database') != _profile(profile)[2]:
        raise VerificationError('unexpected_database')
    if not snapshot.get('profile') or not _qa_email(snapshot.get('qa_email'),snapshot['profile'].get('id'),profile):
        raise VerificationError('owner_is_not_named_local_qa')
    arrays = ('studies','attempts','results','runs','mappings','events','unlocks')
    if any(not isinstance(snapshot.get(k), list) or len(snapshot[k]) > MAX_ROWS for k in arrays):
        raise VerificationError('snapshot_row_limit_or_shape')
    profile_name = profile
    profile = snapshot['profile']; owner = owner_uuid(profile['id'])
    zone = profile.get('timezone') or 'Europe/Istanbul'
    try:
        ZoneInfo(zone)
    except (ValueError, ZoneInfoNotFoundError):
        raise VerificationError('invalid_profile_timezone') from None
    observed = instant(snapshot['captured_at']); now = instant(as_of) if as_of else observed
    today = workday(now, zone); checks=[]; warnings=[]
    def check(name, expected, actual):
        checks.append({'control':name,'expected':expected,'actual':actual,'passed':expected==actual})
    check('schema.required_27_30',True,{'20261028010000','20261028020000','20261028030000','20261028040000'}<=set(snapshot.get('schema_versions',[])))
    check('schema.package31_not_installed',False,'20261028050000' in snapshot.get('schema_versions',[]))
    check('schema.marathon_before31','177a238a9aa8a4ffd3738b2865120568',snapshot.get('marathon_function_md5'))
    is32='20261028060000' in snapshot.get('schema_versions',[])
    payloads=snapshot.get('attempt_payloads')
    if payloads is not None and (not isinstance(payloads,list) or len(payloads)>MAX_ROWS):
        raise VerificationError('attempt_payload_limit_or_shape')
    studies=snapshot['studies']; attempts=snapshot['attempts']; results=snapshot['results']
    mappings=snapshot['mappings']; runs=snapshot['runs']; events=snapshot['events']
    for key, rows, fields in [('study_client_uuid',studies,('client_uuid',)),
                              ('exam_client_uuid',attempts,('client_uuid',)),
                              ('subject_result',results,('attempt_id','subject_id')),
                              ('competition_event',events,('kind','source_id')),
                              ('marathon_mapping',mappings,('marathon_uuid','session_index'))]:
        identifiers=[tuple(r.get(k) for k in fields) for r in rows]
        check(key+'_unique',len(identifiers),len(set(identifiers)))
    check('at_most_one_active_exam',True,sum(a['status']=='active' for a in attempts)<=1)
    by_study={s['id']:s for s in studies}; by_attempt={a['id']:a for a in attempts}
    by_mapping={m['study_session_id']:m for m in mappings}; by_run={r['client_uuid']:r for r in runs}
    per_day=Counter(workday(s.get('started_at') or s['completed_at'],zone) for s in studies)
    records=[]; completed_runs={}; completed=[]; completed_accounting={}
    for index, study in enumerate(studies):
        label=f'study[{index}]'; start=instant(study.get('started_at') or study['completed_at'])
        duration=int(study['duration_minutes']);end=instant(study['completed_at'])
        check(label+'.duration_allowed',True,duration in (25,50))
        standard=5 if duration==25 else 12
        if study.get('was_paused'):
            standard-=int((Decimal(standard)*Decimal('.2')).to_integral_value(rounding='ROUND_CEILING'))
        if study['base_points']:
            check(label+'.base_points_rule',standard,study['base_points'])
        else:
            check(label+'.zero_base_requires_daily_ceiling',True,per_day[workday(start,zone)]>16)
        check(label+'.nonnegative_reward',True,study['base_points']>=0 and study['bonus_points']>=0)
        if study.get('started_at'):
            check(label+'.exact_interval_seconds',duration*60,int((end-start).total_seconds()))
        else:
            warnings.append('legacy_study_missing_started_at')
        mapping=by_mapping.get(study['id'])
        if mapping:
            check(label+'.mapping_client_uuid',study['client_uuid'],mapping['client_uuid'])
            check(label+'.run_exists',True,mapping['marathon_uuid'] in by_run)
        records.append({'id':study['id'],'kind':'marathon' if mapping else 'normal','day':workday(start,zone),
                        'minutes':duration,'category_id':study.get('category_id'),
                        'category_name':study.get('category_name') or study.get('category') or ''})
    for index, attempt in enumerate(attempts):
        label=f'exam[{index}]'; definition=attempt['definition'];start=instant(attempt['started_at'])
        end=instant(attempt['ends_at']);duration=int(definition['duration_seconds']);status=attempt['status']
        check(label+'.definition_id',attempt['exam_id'],definition['id'])
        check(label+'.positive_planned_duration',True,duration>0)
        check(label+'.exact_interval_seconds',duration,(end-start).total_seconds())
        check(label+'.status',True,status in {'active','completed','abandoned'})
        policy_version=definition.get('reward_policy_version',1)
        check(label+'.known_snapshot_policy',True,type(policy_version) is int and policy_version in (1,2))
        if status=='completed':
            finished=instant(attempt['finished_at']);early=finished<end
            check(label+'.finished_range',True,start<=finished<=end)
            check(label+'.completion_not_future',True,finished<=observed)
            if early:
                check(label+'.early_requires32',True,is32)
                check(label+'.early_ayt_only','ayt',attempt['exam_id'])
                elapsed=int((finished-start).total_seconds())
                check(label+'.early_minimum_one_second',True,elapsed>=1)
                expected_points=min(int(definition['reward_points']),elapsed//300)
                expected_coins=min(int(definition['reward_coins']),int(definition['reward_coins'])*elapsed//duration)
            else:
                check(label+'.finished_at',end.isoformat(),finished.isoformat())
                elapsed=duration
                expected_points=int(definition['reward_points']);expected_coins=int(definition['reward_coins'])
                check(label+'.not_early',True,end<=observed)
            check(label+'.elapsed_seconds',elapsed,attempt['elapsed_seconds'])
            check(label+'.points',expected_points,attempt['points_earned'])
            check(label+'.coins',expected_coins,attempt['exam_coins_earned'])
            completed.append(attempt)
            completed_accounting[attempt['id']]={'elapsed':elapsed,'minutes':elapsed//60,'points':expected_points,
                'coins':expected_coins,'finished':finished,'kind':'early' if early else 'full'}
            records.append({'id':attempt['id'],'kind':'exam','day':workday(start,zone),'minutes':elapsed//60,
                            'category_id':EXAM_CATEGORY,'category_name':''})
        else:
            check(label+'.uncompleted_points',0,attempt['points_earned'])
            check(label+'.uncompleted_coins',0,attempt['exam_coins_earned'])
            if status=='active':
                check(label+'.active_finished_at',None,attempt['finished_at'])
                check(label+'.active_elapsed',0,attempt['elapsed_seconds'])
            else:
                finished=instant(attempt['finished_at'])
                check(label+'.abandoned_before_end',True,start<=finished<end)
                check(label+'.abandoned_elapsed',int((finished-start).total_seconds()),attempt['elapsed_seconds'])
    if payloads is not None:
        projected={p['id']:p for p in payloads}
        check('attempt_payloads.exact_ids',sorted(by_attempt),sorted(projected))
        check('attempt_payloads.unique',len(payloads),len(projected))
        for ident,a in by_attempt.items():
            if ident not in projected:continue
            p=projected[ident];label='payload['+ident+']';planned=int(a['definition']['duration_seconds'])
            accounting=completed_accounting.get(ident)
            check(label+'.duration_seconds',accounting['elapsed'] if accounting and is32 else planned,p.get('duration_seconds'))
            check(label+'.elapsed_seconds',a['elapsed_seconds'],p.get('elapsed_seconds'))
            check(label+'.snapshot_coins',a['definition']['reward_coins'],p.get('definition',{}).get('reward_coins'))
            check(label+'.snapshot_points',a['definition']['reward_points'],p.get('definition',{}).get('reward_points'))
            if is32:
                check(label+'.planned_duration_seconds',planned,p.get('planned_duration_seconds'))
                check(label+'.credited_minutes',accounting['minutes'] if accounting else 0,p.get('credited_minutes'))
                check(label+'.completion_kind',accounting['kind'] if accounting else None,p.get('completion_kind'))
                check(label+'.details_revision',a.get('details_revision',0),p.get('details_revision'))
                # Do not expose private free text as expected/actual diagnostics.
                check(label+'.private_metadata_preserved',True,all(p.get(k)==a.get(k) for k in ('title','note','selected_module_ids')))
    for index,result in enumerate(results):
        label=f'result[{index}]';attempt=by_attempt.get(result['attempt_id'])
        check(label+'.attempt_exists',True,attempt is not None)
        if not attempt: continue
        check(label+'.completed_attempt', 'completed',attempt['status'])
        subjects={s['id']:s for s in attempt['definition']['subjects']};subject=subjects.get(result['subject_id'])
        check(label+'.subject_known',True,subject is not None)
        if not subject:continue
        c,w,b=(result[k] for k in ('correct','wrong','blank'))
        check(label+'.nonnegative_integers',True,all(isinstance(v,int) and not isinstance(v,bool) and v>=0 for v in (c,w,b)))
        check(label+'.question_total',subject['question_count'],c+w+b)
        divisor=Decimal(str(attempt['definition']['wrong_answer_divisor']))
        expected=Decimal(c)-Decimal(w)/divisor;actual=Decimal(str(result['net']))
        # PostgreSQL numeric division fixes a decimal scale. Reproduce that
        # scale rather than compare lossy JSON float approximations.
        # Never let a corrupt integer/low-scale stored net choose a coarse
        # rounding scale (for example -1/3 must not pass as zero). PostgreSQL
        # numeric division retains at least16 fractional places at these
        # bounded exam counts; terminating values compare numerically equal.
        expected=expected.quantize(Decimal(1).scaleb(min(-16,actual.as_tuple().exponent)))
        check(label+'.net_formula',expected,actual)
        check(label+'.updated_at_present',True,bool(result.get('updated_at')))
        if result.get('updated_at'):
            check(label+'.updated_not_future',True,instant(result['updated_at'])<=observed)
    for index,run in enumerate(runs):
        mapped=[m for m in mappings if m['marathon_uuid']==run['client_uuid']]
        check(f'run[{index}].valid_indices',True,all(1<=m['session_index']<=run['target_sessions'] for m in mapped))
        if not run['is_invalid'] and len(mapped)==run['target_sessions'] and all(m['study_session_id'] in by_study for m in mapped):
            completed_runs[run['client_uuid']]=workday(max(instant(by_study[m['study_session_id']]['completed_at']) for m in mapped),zone)
        eligible=run['client_uuid'] in completed_runs and all(by_study[m['study_session_id']]['base_points']>0 for m in mapped)
        bonus={25:{2:2,3:3,4:5},50:{2:4,3:6,4:10}}.get(run['duration_minutes'],{}).get(run['target_sessions'])
        check(f'run[{index}].bonus_rule',bonus if eligible else 0,run['bonus_awarded'])
    for index,mapping in enumerate(mappings):
        check(f'mapping[{index}].study_exists',True,mapping['study_session_id'] in by_study)
        check(f'mapping[{index}].run_exists',True,mapping['marathon_uuid'] in by_run)
    expected_minutes=sum(s['duration_minutes'] for s in studies)+sum(a['minutes'] for a in completed_accounting.values())
    normal_points=sum(s['base_points']+s['bonus_points'] for s in studies)
    normal_coins=sum(20 for s in studies if s['base_points']>0)-sum(u['coins_spent'] for u in snapshot['unlocks'])
    exam_points=sum(a['points'] for a in completed_accounting.values())
    exam_coins=sum(a['coins'] for a in completed_accounting.values())
    wallet=snapshot['wallet'] or {'coins':0,'lifetime_points':0}
    check('profile.total_minutes',expected_minutes,profile['total_minutes'])
    check('profile.lifetime_points',normal_points,profile['lifetime_points'])
    check('profile.coins_after_avatar_spending',normal_coins,profile['coins'])
    check('exam_wallet.lifetime_points',exam_points,wallet['lifetime_points'])
    check('exam_wallet.coins',exam_coins,wallet['coins'])
    activity_days=sorted({r['day'] for r in records if r['minutes']>0});longest=0;current=0;previous=None
    for day in activity_days:
        current=current+1 if previous and day==previous+timedelta(days=1) else 1
        longest=max(longest,current);previous=day
    last=activity_days[-1].isoformat() if activity_days else None
    check('profile.last_study_date',last,profile['last_study_date'])
    # Past queue arrivals deliberately do not rebuild earlier streak gaps;
    # compare exact consecutive counts for chronological fixtures, and expose
    # discrepancies as a policy warning rather than silently rewriting data.
    if profile['current_streak']!=current or profile['longest_streak']!=longest:
        warnings.append('stored_streak_differs_from_reconstructed_days_late_or_timezone_policy_requires_review')
    check('profile.streak_bounds',True,0<=profile['current_streak']<=profile['longest_streak'])
    check('profile.completed_day_has_streak',True,not activity_days or profile['current_streak']>0)
    expected_events={}
    for study in studies:
        expected_events[('study',study['id'])]={'points':study['base_points']+study['bonus_points'],
         'minutes':study['duration_minutes'],'completed_at':instant(study['completed_at']).isoformat(),
         'period_month':month_of(study['completed_at']),'study_day':workday(study.get('started_at') or study['completed_at'],zone).isoformat()}
    for attempt in completed:
        accepted=completed_accounting[attempt['id']]
        if accepted['minutes']<=0:
            continue  #32 zero-minute completion counts once, but has no league event.
        expected_events[('exam',attempt['id'])]={'points':accepted['points'],'minutes':accepted['minutes'],
         'completed_at':accepted['finished'].isoformat(),'period_month':month_of(accepted['finished']),
         'study_day':workday(attempt['started_at'],zone).isoformat()}
    actual_events={(e['kind'],e['source_id']):{k:instant(e[k]).isoformat() if k=='completed_at' else e[k] for k in ('points','minutes','completed_at','period_month','study_day')} for e in events}
    check('competition_events.exact_sources_and_accounting',expected_events,actual_events)
    if rls is not None:
        for name,count in rls.items():check('rls.'+name,0,count)
    daily_goal=profile.get('daily_goal_minutes') or 200
    if daily_goal<=0:daily_goal=200
    monday=today-timedelta(days=today.weekday());month_start=today.replace(day=1)
    month_end=today.replace(day=calendar.monthrange(today.year,today.month)[1])
    daily=_report(records,completed_runs,today,today,daily_goal,today)
    weekly=_report(records,completed_runs,monday,monday+timedelta(days=6),daily_goal*7,today)
    weekly['efficiency_percentage']=weekly['goal_percentage']
    weekly['elapsed_pace_percentage']=min(100,weekly['total_minutes']*100//(daily_goal*(today.weekday()+1)))
    weekly['efficiency_label_key']='statsWeekNotStarted' if not weekly['total_minutes'] else ('eff_very_high' if weekly['elapsed_pace_percentage']>=80 else 'eff_high' if weekly['elapsed_pace_percentage']>=50 else 'eff_normal')
    monthly=_report(records,completed_runs,month_start,month_end,daily_goal*(month_end.day),today)
    previous_month_end=month_start-timedelta(days=1);previous_to=previous_month_end.replace(day=min(today.day,previous_month_end.day))
    current_mtd=sum(r['minutes'] for r in records if month_start<=r['day']<=today)
    previous_mtd=sum(r['minutes'] for r in records if previous_month_end.replace(day=1)<=r['day']<=previous_to)
    monthly['month_to_date_minutes']=current_mtd;monthly['previous_month_to_date_minutes']=previous_mtd
    monthly['month_to_date_growth_percentage']=_rounded_change(current_mtd,previous_mtd)
    daily['efficiency_percentage']=daily['goal_progress_percentage']
    for report in (daily,weekly,monthly):
        report['efficiency']=report.get('efficiency_percentage',report['goal_percentage'])
    return {'schema_version':1,'status':'PASS' if all(c['passed'] for c in checks) else 'FAIL',
     'owner_id':owner,'captured_at':observed.isoformat(),'as_of':now.isoformat(),'profile_time_zone':zone,
     'study_day':today.isoformat(),'scope':'fixed loopback read-only QA snapshot; accepted records only; pending device outbox is not in DB',
     'database_profile':profile_name,'server_contract':'exam32' if is32 else 'exam28',
     'expected':{'economy':{'total_minutes':expected_minutes,'normal_points':normal_points,'normal_coins':normal_coins,
       'exam_points':exam_points,'exam_coins':exam_coins},'reconstructed_streak':{'current_streak':current,'longest_streak':longest,'last_study_date':last},
       'reports':{'daily':daily,'weekly':weekly,'monthly':monthly}},
     'actual':{'profile':profile,'exam_wallet':wallet,'row_counts':{k:len(snapshot[k]) for k in arrays}},
     'checks':checks,'passed_checks':sum(c['passed'] for c in checks),'total_checks':len(checks),'warnings':sorted(set(warnings))}


def json_safe(value):
    if isinstance(value, Decimal):return float(value)
    if isinstance(value, dict):return {str(k):json_safe(v) for k,v in value.items()}
    if isinstance(value, (list,tuple)):return [json_safe(v) for v in value]
    return value


def verify_owner(owner, as_of=None, peer=None, profile='main'):
    _profile(profile)
    snapshot=read_snapshot(owner,profile=profile)
    rls=check_peer_rls(owner,peer,profile=profile) if peer else None
    return json_safe(analyze_snapshot(snapshot,as_of=as_of,rls=rls,profile=profile))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,help='Canonical UUID of an e2e-sim-/qa- @pomosprint.local owner')
    parser.add_argument('--as-of',help='Offset-qualified instant used only to choose report calendar windows')
    parser.add_argument('--peer-owner',help='A second named local QA owner for authenticated read-isolation checks')
    parser.add_argument('--profile',choices=PROFILES,default='main',help='Fixed main/review/site database only; no URL override')
    args=parser.parse_args()
    try:
        result=verify_owner(args.owner,args.as_of,args.peer_owner,profile=args.profile)
    except (VerificationError,ValueError,KeyError,TypeError,OverflowError) as error:
        code=str(error) if isinstance(error,VerificationError) else 'invalid_snapshot_accounting_data'
        print(json.dumps({'schema_version':1,'status':'ERROR','error':code}))
        return 2
    print(json.dumps(result,ensure_ascii=False,separators=(',',':')))
    return 0 if result['status']=='PASS' else 1


if __name__=='__main__':
    raise SystemExit(main())
