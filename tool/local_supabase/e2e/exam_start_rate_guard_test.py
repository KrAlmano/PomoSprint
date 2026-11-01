#!/usr/bin/env python3
"""Exercise proposed 33 solely in a disposable fixed local QA clone.

Requires the clone pomosprint_security_audit_20261101, proposal 33 applied,
port 54322, and local Docker. Creates synthetic @pomosprint.local accounts
only in that disposable DB. Never reads .env or connects to production.
"""
from concurrent.futures import ThreadPoolExecutor
import json
import uuid
import overnight_exam_backend as base

DB='pomosprint_security_audit_20261101'
base.PG=f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
base.RESULTS=[]

def seed(owner,count,age="interval '1 minute'"):
    base.sql(f"""INSERT INTO public.exam_attempts(user_id,client_uuid,exam_id,definition,started_at,ends_at,status,finished_at,elapsed_seconds)
SELECT '{owner}',gen_random_uuid(),'tyt',c.definition,clock_timestamp()-{age},clock_timestamp()-{age}+interval '165 minutes','abandoned',clock_timestamp()-{age}+interval '1 second',1
FROM public.exam_catalog c CROSS JOIN generate_series(1,{count}) WHERE c.id='tyt';""")

def main():
    assert base.sql('select current_database()')==DB
    assert base.sql("select count(*) from public.exam_start_rate_backup_33")=='2'
    rapid,_=base.user('yks','QA Rate Rapid')
    for _ in range(12):
        attempt=base.start(rapid,exam='tyt')['attempt']
        base.rpc(rapid,'abandon_exam_attempt',f"'{attempt['id']}'")
    base.check('twelve_starts_and_fast_abandons_allowed',base.sql(f"select count(*) from public.exam_attempts where user_id='{rapid}'")=='12')
    owner,_=base.user('yks','QA Rate Cap')
    seed(owner,100)
    original=json.loads(base.sql(f"select jsonb_build_object('id',id,'uuid',client_uuid) from public.exam_attempts where user_id='{owner}' limit 1"))
    duplicate=base.rpc(owner,'start_exam_attempt',f"'{original['uuid']}','tyt'")
    base.check('idempotent_retry_allowed_at_cap',duplicate['duplicate'] is True and duplicate['attempt']['id']==original['id'])
    conflict=base.auth(owner,f"select public.start_exam_attempt('{original['uuid']}','ayt')",True)
    base.check('existing_uuid_metadata_conflict_retained_at_cap','exam_metadata_conflict' in conflict)
    failure=base.auth(owner,f"select public.start_exam_attempt('{base.uid()}','tyt')",True)
    base.check('101st_start_rejected', 'exam_start_rate_limited' in failure)
    base.check('rejected_start_mints_no_attempt',base.sql(f"select count(*) from public.exam_attempts where user_id='{owner}'")=='100')
    other,_=base.user('yks','QA Rate Other')
    independent=base.start(other,exam='tyt')['attempt']
    base.check('other_owner_not_affected',independent['status']=='active')
    old,_=base.user('yks','QA Rate Expired')
    seed(old,100,"interval '24 hours 2 seconds'")
    fresh=base.start(old,exam='tyt')['attempt']
    base.check('records_older_than_24h_do_not_count',fresh['status']=='active')
    recent,_=base.user('yks','QA Rate Recent')
    seed(recent,100,"interval '23 hours 59 minutes 30 seconds'")
    blocked=base.auth(recent,f"select public.start_exam_attempt('{base.uid()}','tyt')",True)
    base.check('records_just_under_24h_still_count','exam_start_rate_limited' in blocked)
    race,_=base.user('yks','QA Rate Race')
    seed(race,99)
    ids=[base.uid(),base.uid()]
    def call(client):
        try:
            return ('success',base.start(race,exam='tyt',client=client))
        except RuntimeError as e:
            return ('error',str(e))
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcome=list(pool.map(call,ids))
    base.check('concurrent_99_boundary_has_one_success',sum(x[0]=='success' for x in outcome)==1)
    base.check('concurrent_99_boundary_loser_rate_limited',sum(x[0]=='error' and 'exam_start_rate_limited' in x[1] for x in outcome)==1)
    base.check('concurrent_99_boundary_no_extra_rows',base.sql(f"select count(*) from public.exam_attempts where user_id='{race}'")=='100')
    winner=next(value for kind,value in outcome if kind=='success')
    retry=base.start(race,exam='tyt',client=winner['attempt']['client_uuid'])
    base.check('active_winner_retry_allowed_at_cap',retry['duplicate'] is True and retry['attempt']['id']==winner['attempt']['id'])
    print(f"RESULT {sum(r['ok'] for r in base.RESULTS)}/{len(base.RESULTS)}")
    if not all(r['ok'] for r in base.RESULTS): raise SystemExit(1)

if __name__=='__main__': main()
