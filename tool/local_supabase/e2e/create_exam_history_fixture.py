#!/usr/bin/env python3
"""OPT-IN: two historical TYT results for an explicitly allowlisted NEW QA owner.

These 165-minute histories are controlled fixtures. They do not prove that a
real device or user stayed in an exam for 165 minutes. Catalog durations and
production API behavior are unchanged.
"""
import argparse
import json
from pathlib import Path
import sys

from local_fixture_api import ROOT, FixtureError, assert_qa_owner, literal, require_local, sql


def allow_owner(path, owner, email):
    data = json.loads(Path(path).read_text())
    if not isinstance(data, dict) or not isinstance(data.get('owners'), list):
        raise FixtureError('Allowlist must contain an owners array')
    matches = [row for row in data['owners'] if isinstance(row, dict) and row.get('id') == owner and row.get('email') == email]
    if len(matches) != 1:
        raise FixtureError('Exact owner id/email must appear once in the explicit allowlist')
    assert_qa_owner(owner, email)


def create(owner, email, allowlist):
    require_local()
    allow_owner(allowlist, owner, email)
    target = ROOT/'build/overnight_backend'/f'exam_history_fixture_{owner}.json'
    if target.exists() or sql(f"select count(*) from public.exam_attempts where user_id={literal(owner)}::uuid") != '0':
        raise FixtureError('Owner already has exam history; no existing attempts are changed')
    if sql(f"select count(*) from public.profiles where id={literal(owner)}::uuid and active_session_ends_at>now()") != '0':
        raise FixtureError('An active normal session prevents history fixture creation')
    # The transaction only updates the two rows that it just creates. No
    # current attempt, existing result, catalog or policy is modified.
    query = f"""
BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',{literal(owner)},'role','authenticated')::text,true);
DO $fixture$
DECLARE response jsonb; attempt_id uuid; days_ago integer; correct_count integer; results jsonb; started timestamptz;
BEGIN
 FOREACH days_ago IN ARRAY ARRAY[3,1] LOOP
  response:=public.start_exam_attempt(gen_random_uuid(),'tyt');
  attempt_id:=(response->'attempt'->>'id')::uuid;
  started:=(((now() AT TIME ZONE 'Europe/Istanbul')::date-days_ago)+time '10:00')AT TIME ZONE 'Europe/Istanbul';
  UPDATE public.exam_attempts SET started_at=started,ends_at=started+interval '165 minutes'
   WHERE id=attempt_id AND user_id={literal(owner)}::uuid AND status='active';
  PERFORM public.complete_exam_attempt(attempt_id);
  correct_count:=CASE WHEN days_ago=3 THEN 20 ELSE 28 END;
  SELECT jsonb_agg(jsonb_build_object('subject_id',s->>'id',
   'correct',CASE WHEN s->>'id'='turkish' THEN correct_count ELSE 0 END,
   'wrong',CASE WHEN s->>'id'='turkish' THEN 4 ELSE 0 END,
   'blank',(s->>'question_count')::integer-CASE WHEN s->>'id'='turkish' THEN correct_count+4 ELSE 0 END))
   INTO results FROM public.exam_attempts a CROSS JOIN LATERAL jsonb_array_elements(a.definition->'subjects')s WHERE a.id=attempt_id;
  PERFORM public.save_exam_results(attempt_id,results);
 END LOOP;
END $fixture$;
COMMIT;
SELECT jsonb_agg(jsonb_build_object('id',a.id,'client_uuid',a.client_uuid,'exam_id',a.exam_id,
 'started_at',a.started_at,'ends_at',a.ends_at,'duration_seconds',a.definition->'duration_seconds',
 'status',a.status,'points_earned',a.points_earned,'exam_coins_earned',a.exam_coins_earned,
 'turkish_net',(SELECT r.net FROM public.exam_subject_results r WHERE r.attempt_id=a.id AND r.subject_id='turkish')) ORDER BY a.started_at)
 FROM public.exam_attempts a WHERE a.user_id={literal(owner)}::uuid;
"""
    output = sql(query).splitlines()
    attempts = json.loads(output[-1])
    if len(attempts) != 2 or any(row['status'] != 'completed' or row['duration_seconds'] != 9900 for row in attempts):
        raise FixtureError('Unexpected history fixture result')
    report = {'fixture': 'controlled-historical-tyt-results', 'owner_id': owner, 'email': email,
              'scope': '2 historical 165-minute fixtures; NOT natural full-duration native test', 'attempts': attempts}
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print('Created 2 explicitly labelled local TYT history fixtures:', target)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner-id', required=True)
    parser.add_argument('--email', required=True)
    parser.add_argument('--allowlist', required=True)
    args = parser.parse_args()
    create(args.owner_id, args.email, args.allowlist)


if __name__ == '__main__':
    try:
        main()
    except (FixtureError, ValueError, KeyError, OSError) as error:
        print('History fixture stopped safely:', str(error), file=sys.stderr)
        sys.exit(1)
