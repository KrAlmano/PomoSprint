#!/usr/bin/env python3
"""Target scheduling and finalized-month fixtures in one disposable local clone."""
import json
from datetime import datetime

import overnight_exam_backend as base
from overnight_exam_backend import ROOT, RESULTS, auth, check, rpc, sql, uid, user

base.PG = 'postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_night_target'


def room_segment(who, kind, month='public._competition_month(now())'):
    return sql(f"select r.segment from public.competition_memberships m join public.competition_rooms r on r.id=m.room_id where m.user_id='{who}' and m.kind='{kind}' and m.period_month={month}")


def main():
    check('target_review_clone_only', sql('select current_database()') == 'pomosprint_night_target')
    next_start = sql("select public._competition_month_time((public._competition_month(now())+interval '1 month')::date)")

    empty, _ = user('yks', 'Target Empty')
    target = rpc(empty, 'set_competition_target', "'tus'")
    check('no_activity_changes_target_immediately', target['current_segment'] == 'tus' and target['pending_segment'] is None)

    active, category = user('yks', 'Target Normal')
    auth(active, "select public.start_study_session(25,'Matematik')")
    target = rpc(active, 'set_competition_target', "'tus'")
    check('first_active_normal_defers_target', target['current_segment'] == 'yks' and target['pending_segment'] == 'tus')
    check('normal_target_effective_at_next_midnight', datetime.fromisoformat(target['effective_at']) == datetime.fromisoformat(next_start))
    # Standard duration is a historical fixture, not a real 25-minute wait.
    auth(active, 'select public.cancel_study_session()')
    rpc(active, 'complete_study_session', f"'{uid()}','{category}',25,false,0,now()-interval '26 minutes'")
    check('normal_finish_stays_in_original_target', room_segment(active, 'study') == 'yks')
    before = sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{active}'")
    room_before = sql(f"select room_id from public.competition_memberships where user_id='{active}' and kind='study' and period_month=public._competition_month(now())")
    target = rpc(active, 'set_competition_target', "'kpss'")
    check('midmonth_points_defers_latest_target', target['current_segment'] == 'yks' and target['pending_segment'] == 'kpss')
    check('target_edit_keeps_points_and_room', before == sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{active}'") and room_before == sql(f"select room_id from public.competition_memberships where user_id='{active}' and kind='study' and period_month=public._competition_month(now())"))

    exam_owner, _ = user('yks', 'Target Exam')
    attempt = rpc(exam_owner, 'start_exam_attempt', f"'{uid()}','lgs_verbal'")['attempt']
    target = rpc(exam_owner, 'set_competition_target', "'tus'")
    check('first_active_exam_defers_target', target['current_segment'] == 'yks' and target['pending_segment'] == 'tus')
    base.historical(attempt['id'])
    rpc(exam_owner, 'complete_exam_attempt', f"'{attempt['id']}'")
    check('exam_finish_stays_in_original_target', room_segment(exam_owner, 'exam') == 'yks')
    check('both_kind_rankings_read_same_current_target', rpc(exam_owner, 'get_monthly_league_ranking', "'study','segment'")['segment'] == rpc(exam_owner, 'get_my_exam_league_ranking')['segment'] == 'yks')

    expired, _ = user('yks', 'Target Expired')
    auth(expired, "select public.start_study_session(25,'Matematik')")
    sql(f"update public.profiles set active_session_ends_at=now()-interval '1 second' where id='{expired}'")
    target = rpc(expired, 'set_competition_target', "'tus'")
    check('expired_reservation_does_not_lock_unused_target', target['current_segment'] == 'tus' and target['pending_segment'] is None)

    for kind in ['study', 'exam']:
        sql(f"select public._competition_record('{kind}','{uid()}','{exam_owner}',{base.literal(next_start)}::timestamptz,{base.literal(next_start)}::timestamptz+interval '25 minutes',25,5)")
    next_month = "(public._competition_month(now())+interval '1 month')::date"
    check('both_modes_move_together_next_month', room_segment(exam_owner, 'study', next_month) == room_segment(exam_owner, 'exam', next_month) == 'tus')

    # Finalized periods are immutable; a late historical event stays historical
    # and does not mint a second award or rewrite the recorded final ranks.
    late, _ = user('work', 'Target Late Event')
    sql("update public.competition_policy set activates_at=public._competition_month_time((public._competition_month(now())-interval '1 month')::date),legacy_finalized=true")
    previous_end = "public._competition_month_time(public._competition_month(now()))-interval '1 minute'"
    sql(f"select public._competition_record('study','{uid()}','{late}',{previous_end}-interval '25 minutes',{previous_end},25,5)")
    sql('select public.process_monthly_competitions()')
    finals = sql("select md5(coalesce(jsonb_agg(to_jsonb(r)order by user_id,kind,period_month)::text,''))from public.competition_results r")
    awards = sql("select count(*)from public.avatar_unlocks")
    sql(f"select public._competition_record('study','{uid()}','{late}',{previous_end}-interval '55 minutes',{previous_end}-interval '30 minutes',25,5)")
    sql('select public.process_monthly_competitions()')
    check('late_event_stays_in_finished_month', sql(f"select count(*)from public.competition_events where user_id='{late}'and period_month=(public._competition_month(now())-interval '1 month')::date") == '2')
    check('late_event_does_not_rewrite_final_results', finals == sql("select md5(coalesce(jsonb_agg(to_jsonb(r)order by user_id,kind,period_month)::text,''))from public.competition_results r"))
    check('late_event_does_not_repeat_awards', awards == sql("select count(*)from public.avatar_unlocks"))

    output = {'checks': RESULTS, 'passed': sum(row['ok'] for row in RESULTS), 'total': len(RESULTS),
              'scope': 'Real local RPCs with historical standard-duration and month-boundary fixtures; no full-duration wall-clock claim'}
    (ROOT/'build/overnight_backend/target_reservation_results.json').write_text(json.dumps(output, indent=2))
    print(f"RESULT {output['passed']}/{output['total']}")
    if output['passed'] != output['total']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
