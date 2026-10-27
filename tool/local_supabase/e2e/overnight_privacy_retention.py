#!/usr/bin/env python3
"""Reverse blocking, legacy adapters, private helpers and safe rollback refusal."""
import json
import concurrent.futures
import overnight_exam_backend as base
from overnight_exam_backend import sql,auth,rpc,user,uid,check,ROOT,RESULTS
base.PG='postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_night_privacy'
def package(path):return '\n'.join(l for l in (ROOT/path).read_text().splitlines()if not l.startswith('\\'))
def main():
    a,ca=user('university','Privacy Alice');b,cb=user('university','Privacy Bob')
    for u,c in [(a,ca),(b,cb)]:rpc(u,'complete_study_session',f"'{uid()}','{c}',25,false,0,now()-interval '26 minutes'")
    original=rpc(a,'get_monthly_league_ranking',"'study','segment'")['rows']
    sql(f"insert into public.user_blocks(blocker_id,blocked_id)values('{b}','{a}')")
    reverse=rpc(a,'get_monthly_league_ranking',"'study','segment'")['rows']
    check('reverse_block_masks_other_identity',any(r['is_blocked']and r['name']is None and r['id']is None and r['avatar_id']is None for r in reverse))
    sql(f"insert into public.user_blocks(blocker_id,blocked_id)values('{a}','{b}')")
    both=rpc(a,'get_monthly_league_ranking',"'study','segment'")['rows']
    check('two_way_block_no_duplicate_rows',len(original)==len(reverse)==len(both))
    check('global_excludes_blocked_both_directions',not any(r.get('id')==b for r in rpc(a,'get_monthly_league_ranking',"'study','global'")['rows']))
    legacy=json.loads(auth(a,"select coalesce(jsonb_agg(r),'[]'::jsonb)from public.get_my_league_ranking()r"))
    check('legacy_adapter_masks_reverse_block',len(legacy)==len(both)and any(r['is_blocked']and r['id']is None for r in legacy))
    check('legacy_adapter_keeps_fields',all({'name','avatar_id','weekly_points','tier','end_date','is_me','promotion_zone_end','demotion_zone_start','member_count','id','is_blocked'}<=r.keys()for r in legacy))
    check('legacy_foreign_owner_rejected','not authorized'in auth(a,f"select public.get_league_ranking('{b}')",True))
    for expression in ["NULL,'global'","'study',NULL","'unknown','segment'"]:
        check('invalid_scope_refused_'+expression,'competition_invalid_scope'in auth(a,'select public.get_monthly_league_ranking('+expression+')',True))
    config=json.loads(sql('select public.get_league_config()'))
    check('calendar_config_is_explicit',config['period_kind']=='calendar_month'and config['period_timezone']=='Europe/Istanbul'and config['reset_hour']==0 and config['period_end'])
    check('legacy_ensure_helper_not_public',bool(auth(a,f"select public._competition_legacy_ensure_user_in_league('{a}',9999)",True)))
    # Two devices race a normal reservation and an exam reservation. Exactly one wins.
    racing,rcat=user('language','Race Reservation')
    def reserve_normal():
        err=auth(racing,"select public.start_study_session(25,'Matematik')",True)
        return not err
    def reserve_exam():
        err=auth(racing,f"select public.start_exam_attempt('{uid()}','tyt')",True)
        return not err
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
        tasks=[pool.submit(reserve_normal),pool.submit(reserve_exam)]
        won=[task.result()for task in tasks]
    check('cross_mode_start_race_exactly_one_wins',sum(won)==1)
    check('cross_mode_start_no_dual_reservation',sql(f"select not(exists(select 1 from public.exam_attempts where user_id='{racing}'and status='active')and exists(select 1 from public.profiles where id='{racing}'and active_session_ends_at>now()))")=='t')
    # An active server-owned clock cannot be rewritten by normal direct table access.
    clockowner,_=user('lgs','Clock Owner');clock=rpc(clockowner,'start_exam_attempt',f"'{uid()}','lgs_verbal'")['attempt']
    check('direct_clock_mutation_denied','permission denied'in auth(clockowner,f"update public.exam_attempts set ends_at=now()where id='{clock['id']}'",True))
    check('direct_reward_mutation_denied','permission denied'in auth(clockowner,f"update public.exam_attempts set points_earned=999 where id='{clock['id']}'",True))
    check('direct_net_mutation_denied','permission denied'in auth(clockowner,f"insert into public.exam_subject_results values('{clock['id']}','turkish',20,0,0,999,now())",True))
    rpc(clockowner,'abandon_exam_attempt',f"'{clock['id']}'")
    repeated=rpc(clockowner,'start_exam_attempt',f"'{clock['client_uuid']}','lgs_verbal'")
    check('replayed_abandoned_uuid_cannot_restart',repeated['duplicate']and repeated['attempt']['status']=='abandoned')
    check('clock_owner_cannot_read_other_history',not any(r['id']==clock['id']for r in rpc(a,'get_my_exam_attempts')['attempts']))
    # Deferred target selection blocks rollback that would silently discard it.
    rpc(a,'set_competition_target',"'tus'")
    before=sql("select count(*)from public.competition_events")
    error=sql(package('supabase/proposed/29_monthly_competitions_down.sql'),True)
    check('pending_target_prevents_lossy_rollback','competition_rollback_refused_active_or_pending_data'in error)
    check('refused_rollback_keeps_records',sql("select count(*)from public.competition_events")==before)
    who,_=user('tus','Retention');attempt=rpc(who,'start_exam_attempt',f"'{uid()}','lgs_verbal'")['attempt']
    error=sql(package('supabase/proposed/28_exam_core_down.sql'),True)
    check('core_down_requires_dependent_package_removal','exam_rollback_requires_competition_down_first'in error)
    check('attempt_is_retained_after_refusal',rpc(who,'get_my_exam_attempts','1')['attempts'][0]['id']==attempt['id'])
    # Account deletion cascades canonical owner data and scrubs archived JSON IDs.
    sql(f"update public.competition_policy set legacy_snapshot=jsonb_set(legacy_snapshot,'{{members}}',jsonb_build_array(jsonb_build_object('user_id','{who}'))),legacy_decisions=jsonb_build_array(jsonb_build_object('user_id','{who}'))")
    auth(who,'select public.delete_own_account()')
    check('account_delete_cascades_exam_attempts',sql(f"select count(*)from public.exam_attempts where user_id='{who}'")=='0')
    check('account_delete_cascades_targets',sql(f"select count(*)from public.competition_target_history where user_id='{who}'")=='0')
    check('account_delete_scrubs_new_archive_identity',sql(f"select position('{who}'in(legacy_snapshot::text||legacy_decisions::text))=0 from public.competition_policy where singleton")=='t')
    # Rule wrapper guarantees direct anonymous old function cannot add points.
    check('old_ensure_not_authenticated','permission denied'in auth(a,f"select public.ensure_user_in_league('{a}',9999)",True))
    (ROOT/'build/overnight_backend/privacy_retention_results.json').write_text(json.dumps({'checks':RESULTS,'passed':sum(r['ok']for r in RESULTS),'total':len(RESULTS)},indent=2))
    print(f"RESULT {sum(r['ok']for r in RESULTS)}/{len(RESULTS)}")
    if not all(r['ok']for r in RESULTS):raise SystemExit(1)
if __name__=='__main__':main()
