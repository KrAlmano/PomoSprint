#!/usr/bin/env python3
"""Legacy transition + real RPC metadata and 04:00 accounting in local clone."""
import json
import overnight_exam_backend as base
from overnight_exam_backend import sql,auth,rpc,user,uid,check,ROOT,RESULTS
base.PG='postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_night_transition'

def main():
    # Old full-duration period, settled at the next monthly activation boundary.
    current=sql('select public._competition_month_time(public._competition_month(now()))')
    room=uid();people=[]
    sql(f"insert into public.leagues(id,tier,start_date,end_date)values('{room}',2,{base.literal(current)}::timestamptz-interval '1 month',{base.literal(current)}::timestamptz+interval '8 days')")
    for i in range(10):
        who,cat=user('work',f'Legacy User {i}');people.append((who,cat))
        sql(f"update public.profiles set league_tier=2 where id='{who}';insert into public.league_memberships(league_id,user_id,weekly_points,joined_at,period_started_at)values('{room}','{who}',{6*(i+1)},{base.literal(current)}::timestamptz-interval '10 days',{base.literal(current)}::timestamptz-interval '1 month');")
        sql(f"""insert into public.study_sessions(user_id,category,category_id,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at,start_verified)
        select '{who}','Matematik','{cat}',50,{i+1},0,false,1,gen_random_uuid(),{base.literal(current)}::timestamptz-make_interval(days=>d,hours=>h*2)-interval '50 minutes',{base.literal(current)}::timestamptz-make_interval(days=>d,hours=>h*2),true from generate_series(1,3)d cross join generate_series(1,2)h;""")
        # Current month first activity can arrive before the 00:01 cron.
        sql(f"select public._competition_record('study','{uid()}','{who}',now()-interval '2 hours',now()-interval '70 minutes',50,5)")
    inherited=people[-1][0]
    sql(f"insert into public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)values('{inherited}','league_bronze_monthly','league_award',0)on conflict do nothing")
    profile_before=sql("select md5(jsonb_agg(jsonb_build_array(id,total_minutes,lifetime_points,coins,current_streak,longest_streak)order by id)::text)from public.profiles")
    sql(f"update public.league_competition_state set start_at={base.literal(current)}::timestamptz-interval '1 month',initialized=true,period_started_at={base.literal(current)}::timestamptz-interval '1 month'where singleton;update public.competition_policy set activates_at={base.literal(current)}::timestamptz,legacy_finalized=false;")
    sql('select public.process_monthly_competitions()')
    check('legacy_activation_finalized',sql('select legacy_finalized from public.competition_policy where singleton')=='t')
    check('legacy_decisions_archived',sql("select jsonb_array_length(legacy_decisions)>=10 and legacy_snapshot?'final_members'from public.competition_policy where singleton")=='t')
    check('legacy_qualified_first_promoted',sql(f"select league_tier from public.profiles where id='{inherited}'")=='3')
    check('legacy_qualified_first_awarded',sql(f"select count(*)from public.avatar_unlocks where user_id='{inherited}'and avatar_id='league_silver_monthly'")=='1')
    check('inherited_award_never_removed',sql(f"select count(*)from public.avatar_unlocks where user_id='{inherited}'and avatar_id='league_bronze_monthly'")=='1')
    check('legacy_transition_no_economy_reset',profile_before==sql("select md5(jsonb_agg(jsonb_build_array(id,total_minutes,lifetime_points,coins,current_streak,longest_streak)order by id)::text)from public.profiles"))
    check('cutover_early_member_repacked_to_new_tier',sql(f"select r.tier from public.competition_memberships m join public.competition_rooms r on r.id=m.room_id where m.user_id='{inherited}'and m.kind='study'and m.period_month=public._competition_month(now())")=='3')
    check('legacy_room_history_preserved',sql(f"select count(*)from public.league_memberships where league_id='{room}'")=='10')
    first=sql('select legacy_decisions::text from public.competition_policy where singleton');sql('select public.process_monthly_competitions()')
    check('legacy_settlement_exactly_once',first==sql('select legacy_decisions::text from public.competition_policy where singleton'))
    # Current monthly normal writes cannot add future rewards into legacy rooms.
    who,cat=user('language','Metadata User')
    for start in ["now()-interval '90 minutes'","now()-interval '60 minutes'","now()-interval '30 minutes'"]:
        rpc(who,'complete_study_session',f"'{uid()}','{cat}',25,false,0,{start}")
    ids=sql(f"select id from public.study_sessions where user_id='{who}'order by started_at").splitlines();run=uid()
    sql(f"insert into public.marathon_runs(user_id,client_uuid,target_sessions,duration_minutes)values('{who}','{run}',2,25)")
    for n,ident in enumerate(ids[1:],1):
        sql(f"insert into public.marathon_run_sessions(user_id,marathon_uuid,session_index,client_uuid,study_session_id,result_json)select '{who}','{run}',{n},client_uuid,id,'{{}}'::jsonb from public.study_sessions where id='{ident}'")
    rows=rpc(who,'get_my_study_sessions_v2','NULL,1000,0')
    check('metadata_normal_and_marathon_counts',sum(r['session_kind']=='normal'for r in rows)==1 and sum(r['session_kind']=='marathon'for r in rows)==2)
    check('metadata_completed_marathon_same_final_stamp',len({r['marathon_completed_at']for r in rows if r['session_kind']=='marathon'})==1 and all(r['marathon_completed_at']for r in rows if r['session_kind']=='marathon'))
    check('metadata_duration_no_duplication',sum(r['duration_minutes']for r in rows)==75)
    stranger,_=user();check('metadata_owner_only',rpc(stranger,'get_my_study_sessions_v2','NULL,1000,0')==[])
    check('metadata_anon_denied',bool(sql('begin;set local role anon;select public.get_my_study_sessions_v2();rollback;',True)))
    sql(f"update public.marathon_runs set is_invalid=true where user_id='{who}'and client_uuid='{run}'")
    check('invalid_marathon_keeps_focus_without_completed_plan',all(r['marathon_completed_at']is None for r in rpc(who,'get_my_study_sessions_v2')if r['session_kind']=='marathon'))
    # Standard 80-minute exam spanning the 04:00 work-day boundary.
    day_user,daycat=user('lgs','Day Boundary')
    exam=rpc(day_user,'start_exam_attempt',f"'{uid()}','lgs_quantitative'")['attempt']
    sql(f"update public.exam_attempts set started_at=((now()at time zone'Europe/Istanbul')::date+time '02:30')at time zone'Europe/Istanbul',ends_at=((now()at time zone'Europe/Istanbul')::date+time '03:50')at time zone'Europe/Istanbul'where id='{exam['id']}'")
    rpc(day_user,'complete_exam_attempt',f"'{exam['id']}'")
    check('exam_workday_before04_is_yesterday',sql(f"select last_study_date=((now()at time zone'Europe/Istanbul')::date-1)from public.profiles where id='{day_user}'")=='t')
    rpc(day_user,'complete_study_session',f"'{uid()}','{daycat}',25,false,0,(((now()at time zone'Europe/Istanbul')::date+time '05:00')at time zone'Europe/Istanbul')")
    check('exam_then_pomodoro_shared_two_day_streak',sql(f"select current_streak from public.profiles where id='{day_user}'")=='2')
    check('shared_minutes_separate_wallets',sql(f"select row(total_minutes,lifetime_points,coins)::text from public.profiles where id='{day_user}'")=='(105,5,20)'and sql(f"select row(coins,lifetime_points)::text from public.exam_wallets where user_id='{day_user}'")=='(3,16)')
    check('legacy_membership_not_created_after_activation',sql(f"select count(*)from public.league_memberships where user_id='{day_user}'")=='0')
    check('new_monthly_memberships_both_domains',sql(f"select count(*)from public.competition_memberships where user_id='{day_user}'")=='2')
    out=ROOT/'build/overnight_backend/transition_metadata_results.json';out.write_text(json.dumps({'checks':RESULTS,'passed':sum(r['ok']for r in RESULTS),'total':len(RESULTS),'scope':'Historical controlled legacy/month fixtures; real normal/exam completion RPCs, no production calls'},indent=2));print(f"RESULT {sum(r['ok']for r in RESULTS)}/{len(RESULTS)}")
    if not all(r['ok']for r in RESULTS):raise SystemExit(1)
if __name__=='__main__':main()
