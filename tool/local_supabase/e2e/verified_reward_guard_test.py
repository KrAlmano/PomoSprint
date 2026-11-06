#!/usr/bin/env python3
"""Proposal 34 behavioral tests in a disposable fixed local QA clone only.

The tests use synthetic @pomosprint.local accounts and owner-adjusted clock
fixtures, not real 25/50 minute waits. No production credentials or .env.
The target DB is destroyed separately by the owner after the tests.
"""
from concurrent.futures import ThreadPoolExecutor
import datetime
import json
import overnight_exam_backend as base
DB='pomosprint_security_audit_20261101'
base.PG=f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
base.RESULTS=[]

def cap(value):
    if value=='0':
        # A future rollout snapshots existing streaks and enables the flag in
        # one transaction. Never refresh anchors while policy is already on.
        base.sql("""begin;
          do $$ begin
            if (select value='null'::jsonb from public.app_config where key='unverified_session_daily_cap') then
              insert into public.verified_reward_streak_anchor_34(user_id,last_study_day,streak_count)
              select id,least(last_study_date,((clock_timestamp() at time zone timezone)-interval '4 hours')::date),least(greatest(current_streak,0),14)
              from public.profiles where last_study_date is not null and current_streak>0
              on conflict(user_id) do nothing;
              insert into public.verified_reward_legacy_session_anchor_34(session_id)
              select s.id from public.study_sessions s
              where s.completed_at >= least(clock_timestamp()-interval '14 days',coalesce((select coalesce(period_started_at,start_at) from public.league_competition_state where singleton),clock_timestamp()-interval '14 days'))
              on conflict(session_id) do nothing;
              update public.app_config set value=to_jsonb(clock_timestamp()::text) where key='verified_reward_activation_at_34';
            end if;
          end $$;
          update public.app_config set value='0'::jsonb where key='unverified_session_daily_cap';
          commit;""")
    else:
        # Test reset in disposable clone only. Real rollback refuses anchors.
        base.sql("begin; update public.app_config set value='null'::jsonb where key in ('unverified_session_daily_cap','verified_reward_activation_at_34'); delete from public.verified_reward_streak_anchor_34; delete from public.verified_reward_legacy_session_anchor_34; commit;")

def count_event(owner):
    return int(base.sql(f"select count(*) from public.competition_events where user_id='{owner}' and kind='study'"))

def economy(owner):
    return base.sql(f"select row(coalesce(total_minutes,0),lifetime_points,coins,current_streak)::text from public.profiles where id='{owner}'")

def complete(owner,cat,client,started="now()-interval '26 minutes'",duration=25):
    return base.rpc(owner,'complete_study_session',f"'{client}','{cat}',{duration},false,{duration*60},{started}")

def register(owner,client,duration=25,age="interval '26 minutes'"):
    base.rpc(owner,'register_session_start',f"'{client}',{duration}")
    base.sql(f"update public.session_starts set server_started_at=clock_timestamp()-{age} where user_id='{owner}' and client_uuid='{client}'")

def main():
    assert base.sql('select current_database()')==DB
    assert base.sql("select count(*) from public.verified_reward_backup_34")=='10'
    base.check('gate_off_by_default',base.sql("select value='null'::jsonb from public.app_config where key='unverified_session_daily_cap'")=='t')
    old,cat=base.user('yks','QA Policy Off')
    oldid=base.uid(); off=complete(old,cat,oldid)
    base.check('gate_off_preserves_unverified_rewards',off['start_verified'] is False and off['total_points']==5 and off['coins_earned']==20 and count_event(old)==1)
    grace,cat=base.user('yks','QA Legacy Grace')
    gid=base.uid();register(grace,gid,age="interval '24 minutes 30 seconds'")
    g=complete(grace,cat,gid,started="now()-interval '26 minutes'")
    base.check('gate_off_preserves_existing_60_second_grace',g['start_verified'] is True and g['coins_earned']==20)
    misconfigured,miscat=base.user('yks','QA Missing Activation Marker')
    missingid=base.uid();register(misconfigured,missingid,age="interval '25 minutes 2 seconds'")
    base.sql("update public.app_config set value='0'::jsonb where key='unverified_session_daily_cap'")
    missing=base.auth(misconfigured,f"select public.complete_study_session('{missingid}','{miscat}',25,false,1500,now()-interval '26 minutes')",True)
    base.check('configuration_without_atomic_activation_fails_closed','verified_reward_activation_incomplete' in missing and base.sql(f"select count(*) from public.study_sessions where user_id='{misconfigured}'")=='0')
    cap('null')
    cap('0')
    offline,cat=base.user('yks','QA Policy Offline')
    oid=base.uid(); result=complete(offline,cat,oid)
    base.check('offline_zero_points_and_sand',result['start_verified'] is False and result['unverified_limit_reached'] is True and result['total_points']==0 and result['coins_earned']==0)
    base.check('offline_report_duration_and_streak_saved',economy(offline)=='(25,0,0,1)' and base.sql(f"select count(*) from public.study_sessions where user_id='{offline}' and client_uuid='{oid}' and not start_verified")=='1')
    base.check('offline_no_league_activity',count_event(offline)==0)
    base.check('existing_earned_history_not_changed',economy(old)=='(25,5,20,1)' and count_event(old)==1)
    dup=complete(offline,cat,oid)
    base.check('offline_duplicate_one_record_no_award',dup['duplicate'] is True and dup['coins_earned']==0 and base.sql(f"select count(*) from public.study_sessions where user_id='{offline}'")=='1')
    early,cat=base.user('yks','QA Early Start')
    eid=base.uid();register(early,eid,age="interval '24 minutes 30 seconds'")
    er=base.auth(early,f"select public.complete_study_session('{eid}','{cat}',25,false,1500,now()-interval '26 minutes')",True)
    base.check('premature_server_start_is_retryable', 'verified_start_not_elapsed' in er and economy(early)=='(0,0,0,0)' and base.sql(f"select count(*) from public.study_sessions where user_id='{early}'")=='0' and base.sql(f"select count(*) from public.session_starts where user_id='{early}' and client_uuid='{eid}'")=='1' and count_event(early)==0)
    er2=base.auth(early,f"select public.complete_study_session('{eid}','{cat}',25,false,1500,now()-interval '26 minutes')",True)
    base.check('premature_repeat_is_retryable_without_side_effects', 'verified_start_not_elapsed' in er2 and economy(early)=='(0,0,0,0)')
    with ThreadPoolExecutor(max_workers=2) as pool:
        attempts=list(pool.map(lambda _:base.auth(early,f"select public.complete_study_session('{eid}','{cat}',25,false,1500,now()-interval '26 minutes')",True),range(2)))
    base.check('concurrent_premature_retries_remain_pending',all('verified_start_not_elapsed' in attempt for attempt in attempts) and economy(early)=='(0,0,0,0)')
    base.sql(f"update public.session_starts set server_started_at=clock_timestamp()-interval '25 minutes 2 seconds' where user_id='{early}' and client_uuid='{eid}'")
    er3=complete(early,cat,eid)
    er4=complete(early,cat,eid)
    base.check('retry_after_elapsed_is_rewarded_once',er3['start_verified'] is True and er3['total_points']==5 and er3['coins_earned']==20 and er4['duplicate'] is True and er4['coins_earned']==0 and economy(early)=='(25,5,20,1)')
    delayed,cat=base.user('yks','QA Delayed Registration Fifty')
    delayedid=base.uid();register(delayed,delayedid,duration=50,age="interval '49 minutes 59 seconds'")
    delayerr=base.auth(delayed,f"select public.complete_study_session('{delayedid}','{cat}',50,false,3000,now()-interval '51 minutes')",True)
    base.check('delayed_registration_50_minutes_waits', 'verified_start_not_elapsed' in delayerr and economy(delayed)=='(0,0,0,0)')
    base.sql(f"update public.session_starts set server_started_at=clock_timestamp()-interval '50 minutes 2 seconds' where user_id='{delayed}' and client_uuid='{delayedid}'")
    delayok=complete(delayed,cat,delayedid,duration=50,started="now()-interval '51 minutes'")
    base.check('delayed_registration_50_minutes_rewarded_after_wait', delayok['start_verified'] is True and delayok['total_points']==12 and delayok['coins_earned']==20)
    isolated,icat=base.user('yks','QA Independent Start')
    shared=base.uid();register(isolated,shared,age="interval '1 minute'")
    other,ocat=base.user('yks','QA Different Account')
    other_result=complete(other,ocat,shared)
    base.check('different_account_reservation_does_not_block_offline',other_result['start_verified'] is False and other_result['coins_earned']==0)
    other_uuid=complete(isolated,icat,base.uid())
    base.check('different_uuid_reservation_does_not_block_offline',other_uuid['start_verified'] is False and other_uuid['coins_earned']==0)
    mature,cat=base.user('yks','QA Mature Start')
    mid=base.uid();register(mature,mid,age="interval '25 minutes 2 seconds'")
    mr=complete(mature,cat,mid,started="now()-interval '50 minutes'")
    base.check('mature_server_start_earns_normally',mr['start_verified'] is True and mr['total_points']==5 and mr['coins_earned']==20 and count_event(mature)==1)
    base.check('mature_server_start_ignores_client_claim',base.sql(f"select started_at > clock_timestamp()-interval '26 minutes' from public.study_sessions where user_id='{mature}' and client_uuid='{mid}'")=='t')
    fifty,cat=base.user('yks','QA Mature Fifty')
    fid=base.uid();register(fifty,fid,duration=50,age="interval '50 minutes 2 seconds'")
    fr=complete(fifty,cat,fid,started="now()-interval '51 minutes'",duration=50)
    base.check('mature_50_minutes_earns_normally',fr['start_verified'] is True and fr['total_points']==12 and fr['coins_earned']==20 and count_event(fifty)==1)
    mismatch,cat=base.user('yks','QA Duration Mismatch')
    did=base.uid();register(mismatch,did,duration=50,age="interval '1 minute'")
    dr=complete(mismatch,cat,did,started="now()-interval '26 minutes'",duration=25)
    base.check('mismatched_duration_cannot_use_reservation',dr['start_verified'] is False and dr['total_points']==0 and dr['coins_earned']==0 and count_event(mismatch)==0)

    # Controlled past-day fixtures: visible streak continues including offline
    # days, but those zero-reward days cannot raise the verified reward tier.
    def past_two_days(earned, tz='Europe/Istanbul'):
        assert tz in ('Europe/Istanbul','America/New_York')
        cap('null' if earned else '0')
        owner,category=base.user('yks','QA Reward Streak');first=base.uid();second=base.uid()
        base.sql(f"update public.profiles set timezone='{tz}' where id='{owner}'")
        complete(owner,category,first,started="now()-interval '56 minutes'")
        complete(owner,category,second,started="now()-interval '26 minutes'")
        base.sql(f"""update public.study_sessions set
          started_at=(((clock_timestamp() at time zone '{tz}'-interval '4 hours')::date-2)::timestamp+interval '12 hours') at time zone '{tz}',
          completed_at=(((clock_timestamp() at time zone '{tz}'-interval '4 hours')::date-2)::timestamp+interval '12 hours 25 minutes') at time zone '{tz}'
          where user_id='{owner}' and client_uuid='{first}';
          update public.study_sessions set
          started_at=(((clock_timestamp() at time zone '{tz}'-interval '4 hours')::date-1)::timestamp+interval '12 hours') at time zone '{tz}',
          completed_at=(((clock_timestamp() at time zone '{tz}'-interval '4 hours')::date-1)::timestamp+interval '12 hours 25 minutes') at time zone '{tz}'
          where user_id='{owner}' and client_uuid='{second}';
          update public.profiles set current_streak=2,longest_streak=2,
          last_study_date=((clock_timestamp() at time zone '{tz}')-interval '4 hours')::date-1 where id='{owner}';""")
        cap('0')
        current=base.uid();register(owner,current,age="interval '25 minutes 2 seconds'")
        return owner,complete(owner,category,current,started="now()-interval '26 minutes'")
    unverified_streak,sr=past_two_days(False)
    base.check('offline_days_keep_visible_streak_without_raising_reward_bonus',sr['streak']==3 and sr['total_points']==5 and sr['bonus_points']==0 and economy(unverified_streak)=='(75,5,20,3)')
    grandfathered_streak,gr=past_two_days(True)
    base.check('historical_rewarded_days_preserve_reward_bonus',gr['streak']==3 and gr['total_points']==6 and gr['bonus_points']==1 and economy(grandfathered_streak)=='(75,16,60,3)')
    new_york_streak,nr=past_two_days(False,'America/New_York')
    base.check('new_york_timezone_offline_days_do_not_raise_reward',nr['streak']==3 and nr['total_points']==5 and nr['bonus_points']==0 and economy(new_york_streak)=='(75,5,20,3)')
    cap('null')
    anchored,cat=base.user('yks','QA Profile-Only Streak')
    base.sql(f"""update public.profiles set current_streak=13,longest_streak=13,
      last_study_date=((clock_timestamp() at time zone timezone)-interval '4 hours')::date-1 where id='{anchored}'""")
    cap('0')
    anchorid=base.uid();register(anchored,anchorid,age="interval '25 minutes 2 seconds'")
    ar=complete(anchored,cat,anchorid,started="now()-interval '26 minutes'")
    base.check('profile_streak_snapshot_preserves_bonus_without_history',ar['streak']==14 and ar['total_points']==7 and ar['bonus_points']==2 and economy(anchored)=='(25,7,20,14)')
    cap('null')
    exam_bridge,cat=base.user('yks','QA Exam Reward Streak')
    base.sql(f"""update public.profiles set current_streak=1,longest_streak=1,
      last_study_date=((clock_timestamp() at time zone timezone)-interval '4 hours')::date-2 where id='{exam_bridge}'""")
    cap('0')
    base.sql(f"""insert into public.exam_attempts(user_id,client_uuid,exam_id,definition,started_at,ends_at,status,finished_at,elapsed_seconds,points_earned,exam_coins_earned)
      select '{exam_bridge}',gen_random_uuid(),'ayt',c.definition,
        (((clock_timestamp() at time zone 'Europe/Istanbul'-interval '4 hours')::date-1)::timestamp+interval '12 hours') at time zone 'Europe/Istanbul',
        (((clock_timestamp() at time zone 'Europe/Istanbul'-interval '4 hours')::date-1)::timestamp+interval '15 hours') at time zone 'Europe/Istanbul',
        'completed',
        (((clock_timestamp() at time zone 'Europe/Istanbul'-interval '4 hours')::date-1)::timestamp+interval '12 hours 1 minute') at time zone 'Europe/Istanbul',
        60,0,0 from public.exam_catalog c where c.id='ayt';
      update public.profiles set current_streak=2,longest_streak=2,
        last_study_date=((clock_timestamp() at time zone timezone)-interval '4 hours')::date-1 where id='{exam_bridge}'""")
    bridgeid=base.uid();register(exam_bridge,bridgeid,age="interval '25 minutes 2 seconds'")
    br=complete(exam_bridge,cat,bridgeid,started="now()-interval '26 minutes'")
    base.check('server_completed_exam_bridges_reward_streak',br['streak']==3 and br['total_points']==6 and br['bonus_points']==1)
    late,cat=base.user('yks','QA Offline Queue')
    lid=base.uid(); lr=complete(late,cat,lid,started="now()-interval '23 hours'")
    base.check('queued_under_24h_saved_without_reward',lr['start_verified'] is False and lr['total_points']==0 and lr['coins_earned']==0 and base.sql(f"select count(*) from public.study_sessions where user_id='{late}'")=='1')
    too_old,_cat=base.user('yks','QA Offline Too Old')
    fail=base.auth(too_old,f"select public.complete_study_session('{base.uid()}','{_cat}',25,false,1500,now()-interval '24 hours 1 minute')",True)
    base.check('queue_over_24h_retains_existing_rejection','too old' in fail.lower() or '24 hours' in fail.lower() or '24 hour' in fail.lower())
    racing,cat=base.user('yks','QA Policy Race');rid=base.uid()
    with ThreadPoolExecutor(max_workers=2) as pool:
        rs=list(pool.map(lambda _:complete(racing,cat,rid),range(2)))
    base.check('concurrent_offline_duplicate_not_rewarded',sum(not x['duplicate'] for x in rs)==1 and all(x['total_points']==0 and x['coins_earned']==0 for x in rs) and base.sql(f"select count(*) from public.study_sessions where user_id='{racing}'")=='1')

    mar_early,mar_cat=base.user('yks','QA Pending Marathon');mar_uuid=base.uid();mar_run=base.uid()
    register(mar_early,mar_uuid,age="interval '24 minutes 30 seconds'")
    mar_error=base.auth(mar_early,f"select public.complete_marathon_study_session('{mar_uuid}','{mar_cat}',25,false,1500,now()-interval '26 minutes','{mar_run}',2,1)",True)
    base.check('marathon_early_start_is_retryable_without_side_effects','verified_start_not_elapsed' in mar_error and economy(mar_early)=='(0,0,0,0)' and base.sql(f"select count(*) from public.study_sessions where user_id='{mar_early}'")=='0')

    def marathon(mixed):
        owner,c=base.user('yks','QA Marathon Policy'); run=base.uid(); first=base.uid(); second=base.uid()
        if mixed:
            register(owner,first,age="interval '56 minutes'")
        arg1=f"'{first}','{c}',25,false,1500,now()-interval '56 minutes','{run}',2,1"
        r1=base.rpc(owner,'complete_marathon_study_session',arg1)
        base.sql(f"""update public.marathon_presence_gates set
            break_started_at=clock_timestamp()-interval '31 minutes 20 seconds',
            break_ends_at=clock_timestamp()-interval '26 minutes 10 seconds',
            confirmation_deadline=clock_timestamp()-interval '25 minutes 10 seconds',
            confirmed_at=clock_timestamp()-interval '26 minutes',next_client_uuid='{second}'
            where user_id='{owner}' and marathon_uuid='{run}' and next_session_index=2""")
        started=base.sql(f"select confirmed_at::text from public.marathon_presence_gates where user_id='{owner}' and marathon_uuid='{run}' and next_session_index=2")
        arg2=f"'{second}','{c}',25,false,1500,'{started}'::timestamptz,'{run}',2,2"
        r2=base.rpc(owner,'complete_marathon_study_session',arg2)
        return owner,r1,r2
    m,r1,r2=marathon(False)
    base.check('offline_marathon_no_bonus_or_sand',r1['total_points']==0 and r2['total_points']==0 and r2['marathon_bonus_points']==0 and economy(m)=='(50,0,0,1)' and count_event(m)==0)
    m,r1,r2=marathon(True)
    base.check('mixed_marathon_only_verified_base_reward',r1['total_points']==5 and r1['coins_earned']==20 and r2['total_points']==0 and r2['marathon_bonus_points']==0 and economy(m)=='(50,5,20,1)' and count_event(m)==1)

    # A run can cross the policy activation. Legacy unverified rewards must
    # remain recorded, while future bonus eligibility must not trust them.
    cap('null')
    owner,c=base.user('yks','QA Legacy Marathon'); run=base.uid(); first=base.uid(); second=base.uid()
    legacy=base.rpc(owner,'complete_marathon_study_session',f"'{first}','{c}',25,false,1500,now()-interval '56 minutes','{run}',2,1")
    cap('0')
    base.rpc(owner,'register_session_start',f"'{second}',25")
    base.sql(f"""update public.marathon_presence_gates set
        break_started_at=clock_timestamp()-interval '31 minutes 20 seconds',
        break_ends_at=clock_timestamp()-interval '26 minutes 10 seconds',
        confirmation_deadline=clock_timestamp()-interval '25 minutes 10 seconds',
        confirmed_at=clock_timestamp()-interval '26 minutes',next_client_uuid='{second}'
        where user_id='{owner}' and marathon_uuid='{run}' and next_session_index=2""")
    started=base.sql(f"select confirmed_at::text from public.marathon_presence_gates where user_id='{owner}' and marathon_uuid='{run}' and next_session_index=2")
    base.sql(f"update public.session_starts set server_started_at='{started}'::timestamptz where user_id='{owner}' and client_uuid='{second}'")
    last=base.rpc(owner,'complete_marathon_study_session',f"'{second}','{c}',25,false,1500,'{started}'::timestamptz,'{run}',2,2")
    base.check('legacy_unverified_run_no_new_marathon_bonus',legacy['total_points']==5 and legacy['start_verified'] is False and last['start_verified'] is True and last['marathon_bonus_points']==0 and economy(owner)=='(50,10,40,1)')
    print(f"RESULT {sum(r['ok'] for r in base.RESULTS)}/{len(base.RESULTS)}")
    if not all(r['ok'] for r in base.RESULTS): raise SystemExit(1)

if __name__=='__main__':main()
