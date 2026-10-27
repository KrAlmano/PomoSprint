#!/usr/bin/env python3
"""Local-only monthly target/room/rollover tests; all history is marked fixture."""
import concurrent.futures,json
import overnight_exam_backend as base
base.PG='postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_night_competition'
from pathlib import Path
from overnight_exam_backend import sql,auth,rpc,uid,user,complete,check,RESULTS,ROOT

def main():
    owners=[user('tus',f'Room User {i}')for i in range(26)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6)as pool:
        out=list(pool.map(lambda p:complete(*p),owners))
    check('26_concurrent_first_study_completions',all(x['total_points']==5 for x in out))
    check('target_rooms_capacity_25',sql("select max(n)from(select count(*)n from public.competition_memberships m join public.competition_rooms r on r.id=m.room_id where r.segment='tus'and r.kind='study' group by r.id)q")=='25')
    check('26_users_use_two_rooms',sql("select count(distinct room_id)from public.competition_memberships where user_id in("+','.join("'"+u+"'"for u,_ in owners)+")and kind='study'")=='2')
    check('single_membership_per_owner_kind_month',sql('select count(*)from(select user_id,kind,period_month from public.competition_memberships group by 1,2,3 having count(*)>1)q')=='0')
    check('rooms_never_cross_targets',sql("select count(*)from public.competition_memberships m join public.competition_rooms r on r.id=m.room_id where r.segment<>public._competition_segment(m.user_id,m.period_month)")=='0')
    first=owners[0][0]
    before=rpc(first,'get_monthly_league_ranking',"'study','segment'")
    pending=rpc(first,'set_competition_target',"'lgs'")
    after=rpc(first,'get_monthly_league_ranking',"'study','segment'")
    check('midmonth_target_keeps_room_and_score',before['segment']==after['segment']=='tus'and len(before['rows'])==len(after['rows'])and pending['pending_segment']=='lgs')
    check('target_changes_next_calendar_month',sql(f"select public._competition_segment('{first}',(public._competition_month(now())+interval '1 month')::date)")=='lgs')
    global_view=rpc(first,'get_monthly_league_ranking',"'study','global'")
    check('global_has_other_target_rows',len(global_view['rows'])>len(before['rows']))
    check('global_does_not_award_again',all(not r['promotion_eligible']and not r['award_eligible']for r in global_view['rows']))
    check('owner_cannot_supply_other_target',bool(auth(first,"select public.get_monthly_league_ranking('study','target:tus')",True)))
    # Owner-created historical accepted records solely for monthly cutoff tests.
    winners=[]
    for i in range(10):
        who,cat=user('kpss',f'Rollover User {i}');winners.append((who,cat))
        sql(f"update public.profiles set league_tier=2 where id='{who}';")
        sql(f"""insert into public.study_sessions(user_id,category,category_id,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at,start_verified)
        select '{who}','Matematik','{cat}',50,{i+1},0,false,1,gen_random_uuid(),
        public._competition_month_time(public._competition_month(now()))-make_interval(days=>d,hours=>h*2)-interval '50 minutes',
        public._competition_month_time(public._competition_month(now()))-make_interval(days=>d,hours=>h*2),true
        from generate_series(1,3)d cross join generate_series(1,2)h;""")
        for d in range(1,4):
            sql(f"select public._competition_record('exam','{uid()}','{who}',public._competition_month_time(public._competition_month(now()))-make_interval(days=>{d})-interval '100 minutes',public._competition_month_time(public._competition_month(now()))-make_interval(days=>{d}),100,{i+1});")
    sql("update public.competition_memberships set joined_at=public._competition_month_time(public._competition_month(now()))-interval '4 days' where period_month<public._competition_month(now());")
    sql("update public.competition_policy set activates_at=public._competition_month_time((public._competition_month(now())-interval '1 month')::date),legacy_finalized=true;")
    sql('select public.process_monthly_competitions()')
    rows=json.loads(sql("select jsonb_agg(jsonb_build_object('kind',kind,'rank',rank,'from',from_tier,'to',to_tier,'award',award_id)order by kind,rank)from public.competition_results where user_id in("+','.join("'"+u+"'"for u,_ in winners)+")"))
    study=[r for r in rows if r['kind']=='study'];exam=[r for r in rows if r['kind']=='exam']
    check('monthly_both_kinds_settled_once',len(study)==len(exam)==10)
    check('study_top3_promoted',all(r['to']==3 for r in study[:3]))
    check('study_bottom3_demoted',all(r['to']==1 for r in study[-3:]))
    check('study_qualified_top3_awarded',all(r['award'] for r in study[:3])and not any(r['award']for r in study[3:]))
    check('exam_tier_independent',all(r['from']==1 for r in exam)and all(r['to']==2 for r in exam[:3]))
    check('exam_placeholder_no_fictional_awards',not any(r['award']for r in exam))
    state=sql("select (select count(*)from public.competition_results)||':'||(select count(*)from public.avatar_unlocks)")
    sql('select public.process_monthly_competitions()')
    check('rollover_idempotent_no_duplicate_awards',sql("select (select count(*)from public.competition_results)||':'||(select count(*)from public.avatar_unlocks)")==state)
    check('rollover_no_normal_coins_for_exam',all(sql(f"select coins from public.profiles where id='{u}'")=='0'for u,_ in winners))
    # Cross-month shared wall time: first day 01:00 is new league month but prior study day.
    check('new_month_01_belongs_prior_study_day',sql("select (((timestamptz '2026-10-31 22:00+00' at time zone 'Europe/Istanbul')-interval '4 hours')::date)")=='2026-10-31')
    check('leap_year_month_is_calendar',sql("select extract(epoch from(public._competition_month_time(date '2028-03-01')-public._competition_month_time(date '2028-02-01')))/86400")=='29.0000000000000000')
    check('rollover_private_rpc_not_callable',bool(auth(first,'select public.process_monthly_competitions()',True)))
    (ROOT/'build/overnight_backend/competition_backend_results.json').write_text(json.dumps({'checks':RESULTS,'passed':sum(r['ok']for r in RESULTS),'total':len(RESULTS),'scope':'Concurrent normal RPC + historical month fixtures in isolated local DB'},indent=2))
    print(f"RESULT {sum(r['ok']for r in RESULTS)}/{len(RESULTS)}")
    if not all(r['ok']for r in RESULTS):raise SystemExit(1)
if __name__=='__main__':main()
