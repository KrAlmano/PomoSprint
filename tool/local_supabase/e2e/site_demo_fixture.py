#!/usr/bin/env python3
"""Controlled isolated website data. Never run by import/default plan.

Default `plan` is offline. `setup --apply --allow-historical` creates seven NEW
fictional QA owners; only exact newly-created attempts/gates receive historical
metadata. All awards, streaks and room assignments use public authenticated RPCs.
This script is NOT evidence of natural wall-clock study/exam/Marathon waiting.

Fixed target: API127.0.0.1:54361; Postgres127.0.0.1:54322 database
pomosprint_site32_dus only. Auth must auto-confirm inside that isolated
stack; the shared54321 API, shared Mailpit and /postgres are never fallbacks.
Required schema:27-30 plus32,31 absent, proportional early-AYT policy.
Two completed historical TYTs earn66 exam points and260 separate exam sand.
Names/notes are fictional language-neutral sample values. No setup has been
run by preparing this file; root must explicitly choose the setup command.
"""
import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import json
import os
import tempfile
from pathlib import Path
import re
import sys
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[3]
HELPERS = ROOT / 'tool/local_supabase/e2e'
sys.path.insert(0, str(HELPERS))
from local_fixture_api import ANON, FixtureError, literal, password

# Fixed isolated destinations: the shared54321 API and /postgres database are
# intentionally not accepted, even through environment overrides.
DATABASE = 'pomosprint_site32_dus'
API_PORT = 54361
API = f'http://127.0.0.1:{API_PORT}'
DB = f'postgresql://postgres:postgres@127.0.0.1:54322/{DATABASE}'
MAX_RESPONSE = 2 * 1024 * 1024


def require_local():
    if any(key.startswith('PG') for key in os.environ):
        raise FixtureError('Inherited PG routing/auth/options environment refused')
    if os.environ.get('LOCAL_SUPABASE_URL', API) != API or os.environ.get('LOCAL_DB_URL', DB) != DB:
        raise FixtureError('Only the fixed isolated final32 API/database are permitted')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(method, path, body=None, token=None):
    require_local()
    if method not in {'GET', 'POST', 'PATCH'} or not path.startswith(('/auth/v1/', '/rest/v1/', '/health')):
        raise FixtureError('Invalid isolated API method/path')
    parsed = urllib.parse.urlsplit(path)
    if parsed.scheme or parsed.netloc or parsed.fragment or any(ord(c) < 32 for c in path):
        raise FixtureError('Invalid isolated API path')
    if path.startswith('/health') and (method != 'GET' or path != '/health'):
        raise FixtureError('Health endpoint is exact GET only')
    data = None if body is None else json.dumps(body).encode()
    if data is not None and len(data) > 1024 * 1024:
        raise FixtureError('Fixture request exceeds the local body bound')
    req = urllib.request.Request(API + path, data=data, method=method, headers={
        'apikey': ANON, 'Authorization': 'Bearer ' + (token or ANON),
        'Content-Type': 'application/json',
    })
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=15) as response:
            raw = response.read(MAX_RESPONSE + 1)
            if len(raw) > MAX_RESPONSE:
                raise FixtureError('Fixture response exceeds the local body bound')
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        raise FixtureError(f'Isolated {method} {path.split("?")[0]} failed (HTTP {status}); no response body logged') from None
    except (OSError, ValueError):
        raise FixtureError('Isolated API unavailable or invalid response') from None


def rpc(name, args=None, token=None):
    if not re.fullmatch(r'[a-z_]+', name):
        raise FixtureError('Invalid RPC name')
    return request('POST', '/rest/v1/rpc/' + name, args or {}, token)


def sign_in(email):
    if not re.fullmatch(r'e2e-sim-site-demo-[a-z0-9-]+@pomosprint\.local', email):
        raise FixtureError('Only exact local site fixture emails may sign in')
    return request('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password()})


def sql(body):
    require_local()
    result = subprocess.run(['psql', DB, '-XqAt', '-v', 'ON_ERROR_STOP=1', '-c', body],
                            capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise FixtureError('Isolated fixture SQL failed; no row or token content logged')
    return result.stdout.strip()


def assert_qa_owner(uid, email):
    if str(UUID(uid)) != uid or not re.fullmatch(r'e2e-sim-site-demo-[a-z0-9-]+@pomosprint\.local', email):
        raise FixtureError('Only explicitly named isolated site QA owners are accepted')
    if sql(f"SELECT count(*) FROM auth.users WHERE id={literal(uid)}::uuid AND email={literal(email)} "
           "AND created_at>=clock_timestamp()-interval '24 hours'") != '1':
        raise FixtureError('Isolated QA owner id/email/recent creation check failed')


def guard_manifest_path(path):
    try:
        path.relative_to(ROOT)
    except ValueError:
        raise FixtureError('Manifest outside the current repository refused') from None
    for part in (path, *path.parents):
        if part == ROOT.parent:
            break
        if part.is_symlink():
            raise FixtureError('Symlink manifest or parent refused')


TAG = 'controlled-local-demo-v1'
ROLES = [
    ('observer', 'Deniz', None, 'avatar_16_basic'),
    ('focus1', 'Ece', 'focus', 'avatar_2_glasses'),
    ('focus2', 'Mert', 'focus', 'avatar_3_gentleman'),
    ('break1', 'Ada', 'break', 'avatar_5_flower'),
    ('break2', 'Arda', 'break', 'avatar_6_cool'),
    ('exam1', 'Duru', 'exam', 'avatar_7_scholar'),
    ('exam2', 'Can', 'exam', 'avatar_8_striped'),
]
EXPECTED = dict(minutes=455, study_count=4, completed_exams=2, normal_points=29,
                normal_sand=80, exam_points=66, exam_sand=260, streak=2,
                physics_minutes=75, physics_nets=[1.75, 4.75])
CATALOG = {'tyt': (9900, 120, 33, 130), 'ayt': (10800, 160, 36, 145),
           'ydt': (7200, 80, 24, 95), 'lgs_verbal': (4500, 50, 15, 60),
           'lgs_quantitative': (4800, 40, 16, 70),
           'tus_basic': (8100, 100, 27, 110), 'tus_clinical': (8100, 100, 27, 110),
           'dus': (9000, 120, 30, 120)}


def run_label(run):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,23}', run):
        raise FixtureError('Run id: 1-24 lowercase letters/digits/hyphens only')
    return run


def email_for(run, role):
    run_label(run)
    if role not in {r[0] for r in ROLES}:
        raise FixtureError('Unknown fixed fixture role')
    return f'e2e-sim-site-demo-{run}-{role}@pomosprint.local'


def manifest_path(run):
    return ROOT / 'build/verification_20261028' / f'site_demo_{run_label(run)}.json'


def write_manifest(path, value):
    guard_manifest_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise FixtureError('Symlink manifest refused')
    descriptor, temporary_name = tempfile.mkstemp(prefix=path.name+'.', suffix='.tmp', dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        # Exclusive600 tempfile cannot follow a preexisting .tmp symlink.
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def preflight():
    if any(key.startswith('PG') for key in os.environ):
        raise FixtureError('Inherited PG routing/auth/options environment refused; use a clean local shell')
    require_local()
    health = request('GET', '/health')
    if not isinstance(health, dict) or health.get('database') != DATABASE or health.get('port') != API_PORT:
        raise FixtureError('Gateway is not the fixed isolated final32 stack')
    if sql('SELECT current_database()') != DATABASE:
        raise FixtureError('SQL target is not the isolated final32 database')
    if not (ROOT / 'supabase/proposed/31_marathon_completion_anchor.sql').is_file():
        raise FixtureError('Wrong repository root')
    info = json.loads(sql("""SELECT jsonb_build_object(
      'versions',(SELECT jsonb_agg(version ORDER BY version) FROM supabase_migrations.schema_migrations
        WHERE version IN('20261028010000','20261028020000','20261028030000','20261028040000','20261028050000','20261028060000')),
      'marathon_hash',md5(pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure)),
      'break',(SELECT break_seconds FROM public.marathon_presence_settings WHERE singleton),
      'presence',(SELECT presence_seconds FROM public.marathon_presence_settings WHERE singleton),
      'catalog',(SELECT jsonb_object_agg(id,jsonb_build_array((definition->>'duration_seconds')::int,
        (definition->>'total_questions')::int,(definition->>'reward_points')::int,
        (definition->>'reward_coins')::int)) FROM public.exam_catalog WHERE enabled),
      'physics',(SELECT definition->'subjects' FROM public.exam_catalog WHERE id='tyt'),
      'policy',(SELECT jsonb_build_object('enabled',early_enabled,'coin_mode',early_coin_mode) FROM public.exam_extension_policy WHERE singleton),
      'capabilities',public.get_exam_config()->'capabilities')"""))
    if info['versions'] != ['20261028010000', '20261028020000', '20261028030000', '20261028040000', '20261028060000']:
        raise FixtureError('Packages 27-30 and32 required on isolated final DB; package31 remains user decision')
    if info['marathon_hash'] != '177a238a9aa8a4ffd3738b2865120568' or (info['break'], info['presence']) != (300, 60):
        raise FixtureError('Unexpected Marathon wrapper/durations; no schema/catalog is changed')
    if info['catalog'] != {key: list(value) for key, value in CATALOG.items()}:
        raise FixtureError('Official eight-exam duration/question/reward catalog differs')
    if info['policy'] != {'enabled': True, 'coin_mode': 'proportional'} or info['capabilities'] != {'exam_details': True, 'ayt_modules_version': 1, 'ayt_early_finish': True}:
        raise FixtureError('Final32 capability/reward policy differs')
    physics = [row for row in info['physics'] if row['id'] == 'physics']
    if len(physics) != 1 or physics[0]['question_count'] != 7 or physics[0]['category_keys'] != ['Fizik']:
        raise FixtureError('Expected official TYT Physics category mapping')


def check_account(account, run):
    if account['email'] != email_for(run, account['role']):
        raise FixtureError('Exact fixture email/role guard failed')
    assert_qa_owner(account['id'], account['email'])
    count = sql(f"SELECT count(*) FROM auth.users WHERE id={literal(account['id'])}::uuid "
                f"AND email={literal(account['email'])} AND raw_user_meta_data->>'qa_site_capture'={literal(TAG)} "
                f"AND raw_user_meta_data->>'qa_fixture_run'={literal(run)} "
                f"AND raw_user_meta_data->>'qa_fixture_role'={literal(account['role'])}")
    if count != '1':
        raise FixtureError('Exact fresh fixture metadata guard failed')


def load_manifest(run):
    path = manifest_path(run)
    guard_manifest_path(path)
    if path.is_symlink() or path.stat().st_size > 128 * 1024:
        raise FixtureError('Invalid manifest size/path')
    value = json.loads(path.read_text())
    if value.get('schema_version') != 2 or value.get('database') != DATABASE or value.get('api_url') != API or value.get('fixture') != TAG or value.get('run_id') != run or not value.get('ready'):
        raise FixtureError('Only a completed exact fixture manifest can be refreshed')
    if [a['role'] for a in value['accounts']] != [r[0] for r in ROLES]:
        raise FixtureError('Fixed seven-owner cohort differs')
    for account in value['accounts']:
        check_account(account, run)
    return path, value


def token_for(account):
    response = sign_in(account['email'])
    if response['user']['id'] != account['id']:
        raise FixtureError('Authenticated identity differs from exact manifest')
    return response['access_token']


def normal_call(client, category, minutes, started):
    return f"public.complete_study_session({literal(client)}::uuid,{category},{minutes},false,0,{literal(started.isoformat())}::timestamptz)"


def marathon_call(client, category, started, run, index):
    return f"public.complete_marathon_study_session({literal(client)}::uuid,{category},25,false,0,{literal(started.isoformat())}::timestamptz,{literal(run)}::uuid,2,{index})"


def observer_sql(account, run, now):
    owner = literal(account['id']) + '::uuid'
    second = now - timedelta(minutes=170)
    first = second - timedelta(hours=25)
    times = dict(first=first, second=second, math=second - timedelta(minutes=145),
                 physics=second - timedelta(minutes=90), m1=second - timedelta(minutes=60),
                 m2=second - timedelta(minutes=30))
    if times['math'].astimezone(ZoneInfo('Europe/Istanbul')).date() != now.astimezone(ZoneInfo('Europe/Istanbul')).date() or times['math'].astimezone(ZoneInfo('Europe/Istanbul')).hour < 4:
        raise FixtureError('Plan requires Istanbul local time >=09:15; no workday is silently fabricated')
    keys = {key: str(uuid4()) for key in ['exam1', 'exam2', 'math', 'physics', 'm1', 'm2', 'marathon']}
    cat = lambda name: f"(SELECT id FROM public.categories WHERE user_id={owner} AND name={literal(name)} AND NOT is_archived)"
    chunks = [f"""BEGIN;
SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='15s';
SELECT pg_advisory_xact_lock(hashtextextended('site-demo-'||{literal(account['id'])},0));
DO $guard$ BEGIN
 PERFORM 1 FROM public.profiles WHERE id={owner} FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id={owner} AND email={literal(account['email'])}
  AND created_at>now()-interval '1 hour' AND raw_user_meta_data->>'qa_site_capture'={literal(TAG)}
  AND raw_user_meta_data->>'qa_fixture_run'={literal(run)} AND raw_user_meta_data->>'qa_fixture_role'='observer')
 OR EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id={owner})
 OR EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id={owner})
 OR EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id={owner})
 OR EXISTS(SELECT 1 FROM public.marathon_presence_gates WHERE user_id={owner})
 OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id={owner} AND total_minutes=0 AND lifetime_points=0 AND coins=0 AND current_streak=0)
 OR EXISTS(SELECT 1 FROM public.exam_wallets WHERE user_id={owner} AND (coins<>0 OR lifetime_points<>0))
 THEN RAISE EXCEPTION 'site_demo_fresh_owner_guard'; END IF;
END $guard$;
CREATE TEMP TABLE site_demo_receipts(step text PRIMARY KEY,receipt jsonb) ON COMMIT DROP;
GRANT SELECT,INSERT ON pg_temp.site_demo_receipts TO authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',{literal(account['id'])},'role','authenticated')::text,true);
"""]
    def exam_step(label, client, started, later):
        # ONLY the row just created by its exact UUID/start receipt can change.
        counts = {'turkish': (30, 4) if later else (27, 5), 'mathematics': (26, 5) if later else (21, 6),
                  'physics': (5, 1) if later else (2, 1), 'history': (4, 1) if later else (3, 1),
                  'geography': (4, 0) if later else (3, 1), 'philosophy': (4, 1) if later else (3, 1),
                  'religion': (4, 0), 'chemistry': (5, 1) if later else (4, 1), 'biology': (5, 0) if later else (4, 1)}
        values = ','.join(f"({literal(s)},{c},{w})" for s, (c, w) in counts.items())
        return f"""
SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.site_demo_receipts VALUES({literal(label+'_start')},public.start_exam_attempt({literal(client)}::uuid,'tyt'));
RESET ROLE;
DO $metadata$ DECLARE changed int; aid uuid; BEGIN
 SELECT (receipt->'attempt'->>'id')::uuid INTO STRICT aid FROM pg_temp.site_demo_receipts WHERE step={literal(label+'_start')};
 UPDATE public.exam_attempts SET started_at={literal(started.isoformat())}::timestamptz,
  ends_at={literal((started+timedelta(minutes=165)).isoformat())}::timestamptz
 WHERE id=aid AND user_id={owner} AND client_uuid={literal(client)}::uuid
  AND status='active' AND exam_id='tyt' AND started_at>=now()-interval '1 minute';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'site_demo_new_attempt_only_guard'; END IF;
END $metadata$;
SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.site_demo_receipts VALUES({literal(label+'_complete')},public.complete_exam_attempt(
 (SELECT (receipt->'attempt'->>'id')::uuid FROM pg_temp.site_demo_receipts WHERE step={literal(label+'_start')})));
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $nets$ DECLARE aid uuid; results jsonb; before_money jsonb; after_money jsonb; BEGIN
 SELECT (receipt->'attempt'->>'id')::uuid INTO STRICT aid FROM pg_temp.site_demo_receipts WHERE step={literal(label+'_start')};
 SELECT jsonb_build_array(p.total_minutes,p.lifetime_points,p.coins,p.current_streak,w.lifetime_points,w.coins)
  INTO before_money FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id WHERE p.id={owner};
 SELECT jsonb_agg(jsonb_build_object('subject_id',s->>'id','correct',v.correct,'wrong',v.wrong,
  'blank',(s->>'question_count')::int-v.correct-v.wrong)) INTO results
 FROM public.exam_attempts a CROSS JOIN LATERAL jsonb_array_elements(a.definition->'subjects')s
 JOIN (VALUES {values})v(subject,correct,wrong) ON v.subject=s->>'id' WHERE a.id=aid;
 PERFORM public.save_exam_details(aid,jsonb_build_object('title',{literal('TYT 02' if later else 'TYT 01')},'note',{literal('30/4 · 26/5 · 5/1' if later else '27/5 · 21/6 · 2/1')}),results,0);
 SELECT jsonb_build_array(p.total_minutes,p.lifetime_points,p.coins,p.current_streak,w.lifetime_points,w.coins)
  INTO after_money FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id WHERE p.id={owner};
 IF before_money IS DISTINCT FROM after_money THEN RAISE EXCEPTION 'site_demo_net_economy_changed'; END IF;
END $nets$;
RESET ROLE;
"""
    chunks.append(exam_step('first_tyt', keys['exam1'], first, False))
    chunks.append(f"""SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.site_demo_receipts VALUES('math', {normal_call(keys['math'],cat('Matematik'),50,times['math'])});
INSERT INTO pg_temp.site_demo_receipts VALUES('physics', {normal_call(keys['physics'],cat('Fizik'),25,times['physics'])});
INSERT INTO pg_temp.site_demo_receipts VALUES('m1', {marathon_call(keys['m1'],cat('Fizik'),times['m1'],keys['marathon'],1)});
RESET ROLE;
DO $gate$ DECLARE changed int; BEGIN
 UPDATE public.marathon_presence_gates SET
  break_started_at={literal((times['m1']+timedelta(minutes=25)).isoformat())}::timestamptz,
  break_ends_at={literal(times['m2'].isoformat())}::timestamptz,
  confirmation_deadline={literal((times['m2']+timedelta(minutes=1)).isoformat())}::timestamptz,
  confirmed_at={literal(times['m2'].isoformat())}::timestamptz,next_client_uuid={literal(keys['m2'])}::uuid
 WHERE user_id={owner} AND marathon_uuid={literal(keys['marathon'])}::uuid AND next_session_index=2
  AND previous_client_uuid={literal(keys['m1'])}::uuid AND confirmed_at IS NULL
  AND EXISTS(SELECT 1 FROM public.marathon_run_sessions WHERE user_id={owner}
    AND marathon_uuid={literal(keys['marathon'])}::uuid AND client_uuid={literal(keys['m1'])}::uuid);
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'site_demo_exact_new_gate_guard'; END IF;
END $gate$;
SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.site_demo_receipts VALUES('m2', {marathon_call(keys['m2'],cat('Fizik'),times['m2'],keys['marathon'],2)});
RESET ROLE;
""")
    chunks.append(exam_step('second_tyt', keys['exam2'], second, True))
    chunks.append(f"""DO $verify$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_temp.site_demo_receipts WHERE receipt?'error' OR coalesce((receipt->>'duplicate')::boolean,false))
 OR NOT EXISTS(SELECT 1 FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id WHERE p.id={owner}
  AND p.total_minutes=455 AND p.lifetime_points=29 AND p.coins=80 AND p.current_streak=2
  AND w.lifetime_points=66 AND w.coins=260)
 OR (SELECT count(*) FROM public.study_sessions WHERE user_id={owner})<>4
 OR (SELECT sum(duration_minutes) FROM public.study_sessions WHERE user_id={owner})<>125
 OR (SELECT count(*) FROM public.exam_attempts WHERE user_id={owner} AND status='completed')<>2
 OR NOT EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id={owner} AND client_uuid={literal(keys['marathon'])}::uuid
  AND bonus_awarded=2 AND NOT is_invalid)
 OR (SELECT jsonb_agg(r.net ORDER BY a.started_at) FROM public.exam_attempts a JOIN public.exam_subject_results r ON r.attempt_id=a.id
  WHERE a.user_id={owner} AND r.subject_id='physics')<>'[1.75,4.75]'::jsonb
 THEN RAISE EXCEPTION 'site_demo_final_awards_rows_or_nets'; END IF;
END $verify$;
SELECT jsonb_build_object('keys',{literal(json.dumps(keys))}::jsonb,'times',{literal(json.dumps({k:v.isoformat() for k,v in times.items()}))}::jsonb,
 'receipts',(SELECT jsonb_object_agg(step,receipt) FROM pg_temp.site_demo_receipts));
COMMIT;""")
    return '\n'.join(chunks)


def actor_history(account, now, token, ordinal):
    # Different legitimate RPC receipts populate normal category/global leagues.
    category = sql(f"SELECT id FROM public.categories WHERE user_id={literal(account['id'])}::uuid AND name='Matematik' AND NOT is_archived")
    if not category:
        raise FixtureError('Actor onboarding category missing')
    for i in range(3 if ordinal == 0 else 2 if ordinal == 1 else 1):
        started = now - timedelta(hours=5, minutes=-55*i)
        result = rpc('complete_study_session', dict(p_client_uuid=str(uuid4()), p_category_id=category,
                     p_duration_minutes=50 if ordinal < 2 else 25, p_was_paused=False,
                     p_is_verified=0, p_started_at=started.isoformat()), token)
        if result.get('error') or result.get('duplicate'):
            raise FixtureError('Actor ordinary history rejected')
    if account['expected_status'] == 'break':
        run_uuid, client = str(uuid4()), str(uuid4())
        receipt = rpc('complete_marathon_study_session', dict(p_client_uuid=client, p_category_id=category,
            p_duration_minutes=25, p_was_paused=False, p_is_verified=0,
            p_started_at=(now-timedelta(minutes=26)).isoformat(), p_marathon_uuid=run_uuid,
            p_target_sessions=2, p_session_index=1), token)
        if receipt.get('error') or receipt.get('marathon_invalid'):
            raise FixtureError('Actor initial Marathon focus rejected')
        account['marathon_uuid'] = run_uuid
        account['marathon_focus_uuid'] = client
        account['initial_gate_deadline'] = receipt.get('marathon_confirmation_deadline')


def observer_hash(account):
    uid = literal(account['id']) + '::uuid'
    return sql(f"SELECT md5(jsonb_build_object('profile',(SELECT to_jsonb(p) FROM public.profiles p WHERE id={uid}),"
        f"'studies',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM public.study_sessions s WHERE user_id={uid}),"
        f"'attempts',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.exam_attempts a WHERE user_id={uid}),"
        f"'results',(SELECT jsonb_agg(to_jsonb(r) ORDER BY attempt_id,subject_id) FROM public.exam_subject_results r JOIN public.exam_attempts a ON a.id=r.attempt_id WHERE a.user_id={uid}),"
        f"'wallet',(SELECT to_jsonb(w) FROM public.exam_wallets w WHERE user_id={uid}))::text)")


def set_presence(account, token, server_now, create_exam=False):
    state = account['expected_status']
    if state == 'focus':
        rpc('start_study_session', dict(p_duration_minutes=50, p_category_name='Matematik'), token)
    elif state == 'break':
        # Presence demonstration ONLY: no gate/history/wallet is refreshed.
        rpc('start_study_break', dict(p_ends_at=(server_now+timedelta(minutes=5)).isoformat()), token)
    elif state == 'exam':
        if create_exam:
            client = str(uuid4())
            receipt = rpc('start_exam_attempt', dict(p_client_uuid=client, p_exam_id='tyt'), token)
            if receipt.get('error'):
                raise FixtureError('Actor official TYT could not start')
            account['active_exam_id'] = receipt['attempt']['id']
            account['active_exam_uuid'] = client
            account['active_exam_ends_at'] = receipt['attempt']['ends_at']
        else:
            active = sql(f"SELECT count(*) FROM public.exam_attempts WHERE id={literal(account['active_exam_id'])}::uuid "
                         f"AND user_id={literal(account['id'])}::uuid AND client_uuid={literal(account['active_exam_uuid'])}::uuid "
                         "AND status='active' AND ends_at>clock_timestamp()+interval '10 minutes' AND exam_id='tyt'")
            if active != '1':
                raise FixtureError('Actor TYT expired/nearing expiry; no automatic complete/reward/replacement')


def check_live(value, token):
    expected = {a['id']: a['expected_status'] for a in value['accounts'][1:]}
    rows = rpc('get_live_friends_with_breaks', token=token)
    if {row['id']: row['status'] for row in rows} != expected or len(rows) != 6 or Counter(row['status'] for row in rows) != {'focus':2,'break':2,'exam':2}:
        raise FixtureError('Expected exactly six unique friends: two focus/two break/two exam')
    return [{key: row.get(key) for key in ('id','name','status','ends_at')} for row in rows]


def setup(run, allow_historical):
    if not allow_historical:
        raise FixtureError('setup requires --apply and --allow-historical explicitly')
    path = manifest_path(run)
    guard_manifest_path(path)
    if path.exists():
        raise FixtureError('Manifest already exists; existing owners/data will never be overwritten')
    preflight()
    emails = [email_for(run, r[0]) for r in ROLES]
    if sql('SELECT count(*) FROM auth.users WHERE email IN('+','.join(literal(e) for e in emails)+')') != '0':
        raise FixtureError('At least one exact email exists; choose a NEW run id')
    now = datetime.fromisoformat(sql('SELECT clock_timestamp()'))
    # Check all temporal assumptions BEFORE creating the first owner.
    if now.astimezone(ZoneInfo('Europe/Istanbul')).hour < 10:
        raise FixtureError("Run setup after 10:00 Istanbul to keep all today focus rows after 04:00")
    path.parent.mkdir(parents=True, exist_ok=True)
    reservation = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(reservation)
    value = dict(schema_version=2,database=DATABASE,api_url=API,fixture=TAG, run_id=run, created_at=now.isoformat(), accounts=[], ready=False,
        expected=EXPECTED, scope='Controlled local website sample; historical metadata is synthetic, not natural elapsed-time proof')
    tokens, codes = {}, {}
    for role, name, state, avatar in ROLES:
        email = email_for(run, role)
        response = request('POST','/auth/v1/signup',dict(email=email,password=password(),data=dict(
            name=name,avatar_id=avatar,qa_site_capture=TAG,qa_fixture_run=run,qa_fixture_role=role,
            newsletter=False,marketing_consent=False,terms_version='2026-10-03',privacy_version='2026-10-03',terms_accepted_at=now.isoformat())))
        account = dict(role=role,label=name,email=email,id=(response.get('user') or response)['id'],expected_status=state)
        value['accounts'].append(account)
        write_manifest(path,value)
        check_account(account,run)
        if not response.get('access_token'):
            raise FixtureError('Isolated auto-confirm Auth required; no shared Mailpit fallback')
        token = token_for(account)
        tokens[role] = token
        rpc('setup_onboarding_categories',dict(p_categories=[
            dict(name='Matematik',color_hex='#FF414B',icon_name='book'),
            dict(name='Fizik',color_hex='#1687FF',icon_name='science'),
            dict(name='Türkçe',color_hex='#00B885',icon_name='book')]),token)
        request('PATCH','/rest/v1/profiles?id=eq.'+account['id'],dict(birth_year=2000,user_segment='yks',
            daily_goal_minutes=300,show_in_social_feed=True,timezone='Europe/Istanbul',onboarding_completed_at=now.isoformat()),token)
        profile = request('GET','/rest/v1/profiles?select=id,name,friend_code&id=eq.'+account['id'],token=token)[0]
        if profile['name'] != name:
            raise FixtureError('Expected fictional display name differs')
        codes[role] = profile['friend_code']
        if role == 'observer':
            output = sql(observer_sql(account,run,now))
            value['controlled_observer_history'] = json.loads(output.splitlines()[-1])
        else:
            actor_history(account,now,token,len(value['accounts'])-2)
        write_manifest(path,value)
    observer=value['accounts'][0]
    for account in value['accounts'][1:]:
        if rpc('add_friend_by_code',dict(p_code=codes[account['role']]),tokens['observer']).get('success') is not True:
            raise FixtureError('Friend request failed')
        if rpc('respond_friend_request',dict(p_from_user_id=observer['id'],p_accept=True),tokens[account['role']]).get('success') is not True:
            raise FixtureError('Friend acceptance failed')
        if observer['id'] not in {r['id'] for r in rpc('get_my_friends',token=tokens[account['role']])}:
            raise FixtureError('Reverse friendship missing')
        set_presence(account,tokens[account['role']],datetime.now(timezone.utc),create_exam=True)
        write_manifest(path,value)
    value['live_rows']=check_live(value,tokens['observer'])
    value['observer_hash_after_seed']=observer_hash(observer)
    value['ready']=True
    write_manifest(path,value)
    print(json.dumps(dict(manifest=str(path),observer_email=observer['email'],expected=EXPECTED),ensure_ascii=False))


def refresh(run, apply):
    preflight()
    path,value=load_manifest(run)
    observer=value['accounts'][0]
    before=observer_hash(observer)
    # Validate every active exam before any presence mutation. Reads never call
    # get_my_exam_attempts/start again: expired exams are never auto-completed.
    for account in value['accounts'][1:]:
        if account['expected_status']=='exam':
            set_presence(account,None,datetime.now(timezone.utc))
    if apply:
        for account in value['accounts'][1:]:
            if account['expected_status']!='exam':
                set_presence(account,token_for(account),datetime.fromisoformat(sql('SELECT clock_timestamp()')))
    value['live_rows']=check_live(value,token_for(observer))
    after=observer_hash(observer)
    if before!=after:
        raise FixtureError('Observer changed while refreshing ONLY actors; stop capture and inspect concurrency')
    value['last_presence_checked_at']=datetime.now(timezone.utc).isoformat()
    value['presence_refresh_scope']='Only six API peers; break display is synthetic refreshed presence, not extended Marathon gates'
    if apply:
        write_manifest(path,value)
    print(json.dumps(dict(action='refresh' if apply else 'check',auth_scope='local password sign-in updates Auth audit/session metadata; no study/economy writes',observer_unchanged=True,live_rows=value['live_rows']),ensure_ascii=False))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['plan','setup','check','refresh'],nargs='?',default='plan')
    parser.add_argument('--run-id',default='site-oct28-ui')
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--allow-historical',action='store_true')
    args=parser.parse_args()
    run_label(args.run_id)
    if args.action=='plan':
        print(json.dumps(dict(status='OFFLINE PLAN ONLY; no DB/HTTP',database=DATABASE,api_url=API,fixture=TAG,run_id=args.run_id,
            observer_email=email_for(args.run_id,'observer'),expected=EXPECTED,
            commands=['setup --apply --allow-historical --run-id '+args.run_id,'refresh --apply --run-id '+args.run_id],
            warnings=['Synthetic exact-new attempt/gate metadata, not natural elapsed-time evidence',
                      'Package31 MUST remain absent; requires isolated final DB27–30+32 and official catalog',
                      'Same Deniz owner for TR/EN; six API peers, not six native devices',
                      'Refresh only peers every60–90sec; stop before actor TYT expiry',
                      'No shared main API/Auth/DB, hosted API, real mail, direct economy/streak assignments or existing owner modifications']),ensure_ascii=False,indent=2))
    elif args.action=='setup':
        if not args.apply:
            raise FixtureError('setup is opt-in: --apply --allow-historical required; use default plan for offline preview')
        setup(args.run_id,args.allow_historical)
    elif args.action=='refresh':
        if not args.apply:
            raise FixtureError('refresh mutation requires --apply; use check for read-only live verification')
        refresh(args.run_id,True)
    else:
        if args.apply:
            raise FixtureError('check is read-only; do not pass --apply')
        refresh(args.run_id,False)


if __name__=='__main__':
    try:
        main()
    except (FixtureError,ValueError,KeyError,OSError) as error:
        print('Site fixture stopped safely: '+str(error),file=sys.stderr)
        raise SystemExit(1) from None
