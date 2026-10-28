#!/usr/bin/env python3
"""One exact local w owner: add controlled normal/Marathon/abandoned history.

Default is one transaction ending in ROLLBACK. --apply commits only if every
guard and postcondition passes. Rewards are computed by the public completion
functions as authenticated; only newly created gate/attempt dates are fixtures.
This is NOT evidence of waiting for focus, break, or presence time in the app.
"""
import argparse
from datetime import datetime, timedelta
import json
from uuid import uuid4

from local_fixture_api import ROOT, FixtureError, literal, require_local, sql


OWNER = '71ffd38f-84db-4003-b785-840ea83bb477'
EMAIL = 'e2e-sim-http-normal-night-w-ios18@pomosprint.local'


def build_sql(*, apply, now):
    keys = {name: str(uuid4()) for name in ['normal', 'run', 'first', 'second', 'abandon']}
    times = {
        'normal': now - timedelta(hours=4),
        'first': now - timedelta(hours=3),
        'second': now - timedelta(hours=2, minutes=30),
        'abandon': now - timedelta(hours=1),
    }
    t = {key: literal(value.isoformat()) + '::timestamptz' for key, value in times.items()}
    k = {key: literal(value) + '::uuid' for key, value in keys.items()}
    owner = literal(OWNER) + '::uuid'
    category = '(select category_id from pg_temp.w_fixture_baseline)'
    query = f"""
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='15s';
SELECT pg_advisory_xact_lock(hashtextextended('w-mixed-fixture-'||{literal(OWNER)},0));
DO $guard$
BEGIN
 PERFORM 1 FROM public.profiles WHERE id={owner} FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id={owner} AND email={literal(EMAIL)}
   AND created_at>now()-interval '12 hours') THEN RAISE EXCEPTION 'w_fixture_owner_guard'; END IF;
 IF (SELECT count(*) FROM public.exam_attempts WHERE user_id={owner})<>2
   OR (SELECT count(*) FROM public.exam_attempts WHERE user_id={owner} AND status='completed'
     AND exam_id='tyt' AND (definition->>'duration_seconds')::int=9900)<>2
   OR EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id={owner})
   OR EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id={owner})
   OR EXISTS(SELECT 1 FROM public.marathon_presence_gates WHERE user_id={owner})
   OR EXISTS(SELECT 1 FROM public.profiles WHERE id={owner} AND
       (active_session_ends_at>now() OR active_break_ends_at>now()))
 THEN RAISE EXCEPTION 'w_fixture_expected_two_tyt_no_active_or_study'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id
   WHERE p.id={owner} AND p.total_minutes=330 AND p.lifetime_points=0 AND p.coins=0
   AND w.lifetime_points=66 AND w.coins=12)
 THEN RAISE EXCEPTION 'w_fixture_baseline_economy'; END IF;
END $guard$;
CREATE TEMP TABLE w_fixture_baseline ON COMMIT DROP AS SELECT
 (SELECT id FROM public.categories WHERE user_id={owner} AND NOT is_archived ORDER BY sort_order,id LIMIT 1) AS category_id,
 (SELECT md5(jsonb_agg(to_jsonb(a) ORDER BY a.id)::text) FROM public.exam_attempts a WHERE user_id={owner}) AS attempts_hash,
 (SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY r.attempt_id,r.subject_id)::text)
    FROM public.exam_subject_results r JOIN public.exam_attempts a ON a.id=r.attempt_id WHERE a.user_id={owner}) AS results_hash;
CREATE TEMP TABLE w_fixture_receipts(step text PRIMARY KEY,receipt jsonb) ON COMMIT DROP;
GRANT SELECT ON pg_temp.w_fixture_baseline TO authenticated;
GRANT SELECT,INSERT ON pg_temp.w_fixture_receipts TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',{literal(OWNER)},'role','authenticated')::text,true);
INSERT INTO pg_temp.w_fixture_receipts VALUES('normal',public.complete_study_session(
 {k['normal']},{category},25,false,0,{t['normal']}));
INSERT INTO pg_temp.w_fixture_receipts VALUES('first',public.complete_marathon_study_session(
 {k['first']},{category},25,false,0,{t['first']},{k['run']},2,1));
RESET ROLE;
DO $metadata$
DECLARE changed integer;
BEGIN
 IF EXISTS(SELECT 1 FROM pg_temp.w_fixture_receipts WHERE receipt?'error')
 THEN RAISE EXCEPTION 'w_fixture_first_completion_rejected'; END IF;
 -- Controlled historical check-in metadata for THIS newly created run only.
 -- No economy, catalogue, function, policy, or existing attempt is updated.
 UPDATE public.marathon_presence_gates SET
  break_started_at={t['first']}+interval '25 minutes',
  break_ends_at={t['second']},confirmation_deadline={t['second']}+interval '1 minute',
  confirmed_at={t['second']},next_client_uuid={k['second']}
 WHERE user_id={owner} AND marathon_uuid={k['run']} AND next_session_index=2
  AND previous_client_uuid={k['first']} AND confirmed_at IS NULL;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'w_fixture_new_gate_guard'; END IF;
END $metadata$;
SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.w_fixture_receipts VALUES('second',public.complete_marathon_study_session(
 {k['second']},{category},25,false,0,{t['second']},{k['run']},2,2));
INSERT INTO pg_temp.w_fixture_receipts VALUES('exam_start',public.start_exam_attempt({k['abandon']},'tyt'));
RESET ROLE;
DO $abandon_metadata$
DECLARE changed integer;
BEGIN
 UPDATE public.exam_attempts SET started_at={t['abandon']},ends_at={t['abandon']}+interval '165 minutes'
 WHERE user_id={owner} AND client_uuid={k['abandon']} AND status='active'
  AND id=(SELECT (receipt->'attempt'->>'id')::uuid FROM pg_temp.w_fixture_receipts WHERE step='exam_start');
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'w_fixture_new_abandon_guard'; END IF;
END $abandon_metadata$;
SET LOCAL ROLE authenticated;
INSERT INTO pg_temp.w_fixture_receipts VALUES('abandon',public.abandon_exam_attempt(
 (SELECT (receipt->'attempt'->>'id')::uuid FROM pg_temp.w_fixture_receipts WHERE step='exam_start')));
RESET ROLE;
DO $verify$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_temp.w_fixture_receipts WHERE receipt?'error'
    OR coalesce((receipt->>'duplicate')::boolean,false))
 THEN RAISE EXCEPTION 'w_fixture_rpc_rejected_or_duplicate'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id
   WHERE p.id={owner} AND p.total_minutes=405 AND p.lifetime_points=17 AND p.coins=60
   AND w.lifetime_points=66 AND w.coins=12)
 THEN RAISE EXCEPTION 'w_fixture_final_economy'; END IF;
 IF (SELECT count(*) FROM public.study_sessions WHERE user_id={owner})<>3
   OR (SELECT count(*) FROM public.study_sessions WHERE user_id={owner} AND duration_minutes=25)<>3
   OR (SELECT count(*) FROM public.exam_attempts WHERE user_id={owner})<>3
   OR NOT EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id={owner} AND client_uuid={k['abandon']}
     AND status='abandoned' AND points_earned=0 AND exam_coins_earned=0 AND elapsed_seconds>0)
   OR EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id={owner} AND status='active')
   OR NOT EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id={owner} AND client_uuid={k['run']}
     AND target_sessions=2 AND duration_minutes=25 AND bonus_awarded=2 AND NOT is_invalid)
   OR (SELECT count(*) FROM public.marathon_run_sessions WHERE user_id={owner} AND marathon_uuid={k['run']})<>2
 THEN RAISE EXCEPTION 'w_fixture_final_rows'; END IF;
 IF (SELECT md5(jsonb_agg(to_jsonb(a) ORDER BY a.id)::text) FROM public.exam_attempts a
     WHERE user_id={owner} AND client_uuid<>{k['abandon']})
     IS DISTINCT FROM (SELECT attempts_hash FROM pg_temp.w_fixture_baseline)
   OR (SELECT md5(jsonb_agg(to_jsonb(r) ORDER BY r.attempt_id,r.subject_id)::text)
     FROM public.exam_subject_results r JOIN public.exam_attempts a ON a.id=r.attempt_id
     WHERE a.user_id={owner} AND a.client_uuid<>{k['abandon']})
     IS DISTINCT FROM (SELECT results_hash FROM pg_temp.w_fixture_baseline)
 THEN RAISE EXCEPTION 'w_fixture_existing_tyt_changed'; END IF;
END $verify$;
SELECT jsonb_build_object('fixture','w-controlled-mixed-history','owner_id',{literal(OWNER)},'email',{literal(EMAIL)},
 'applied',{'true' if apply else 'false'},'original_tyt_rows_unchanged',true,
 'minutes',p.total_minutes,'normal_points',p.lifetime_points,'normal_coins',p.coins,
 'exam_points',w.lifetime_points,'exam_coins',w.coins,
 'normal_uuid',{literal(keys['normal'])},'marathon_uuid',{literal(keys['run'])},
 'marathon_focus_uuids',jsonb_build_array({literal(keys['first'])},{literal(keys['second'])}),
 'abandoned_uuid',{literal(keys['abandon'])},
 'rpc_receipts',(SELECT jsonb_object_agg(step,receipt) FROM pg_temp.w_fixture_receipts),
 'historical_gate',(SELECT to_jsonb(g) FROM public.marathon_presence_gates g
   WHERE g.user_id={owner} AND g.marathon_uuid={k['run']}),
 'scope','Historical focus dates and a synthetic historical break/check-in receipt. NOT natural focus/break/presence evidence; no economy columns assigned by fixture.')
FROM public.profiles p JOIN public.exam_wallets w ON w.user_id=p.id WHERE p.id={owner};
{'COMMIT' if apply else 'ROLLBACK'};
"""
    return query


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--allow-historical-presence', action='store_true')
    args = parser.parse_args()
    if not args.allow_historical_presence:
        raise FixtureError('Explicit --allow-historical-presence is required, including for rollback dryrun')
    require_local()
    now = datetime.fromisoformat(sql('select clock_timestamp()'))
    output = sql(build_sql(apply=args.apply, now=now))
    report = json.loads(output.splitlines()[-1])
    if args.apply:
        target = ROOT/'build/overnight_backend'/f'w_mixed_fixture_{OWNER}.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
        print('Controlled mixed fixture committed; manifest:', target)
    print(json.dumps({key: report[key] for key in ['fixture','applied','original_tyt_rows_unchanged',
        'minutes','normal_points','normal_coins','exam_points','exam_coins']}, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (FixtureError, ValueError, KeyError, OSError) as error:
        print('W fixture stopped/rolled back safely:', str(error), flush=True)
        raise SystemExit(1) from None
