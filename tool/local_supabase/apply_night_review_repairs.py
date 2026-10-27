#!/usr/bin/env python3
"""Apply only reviewed D03/D04/D05 functions/catalog + proposal30 to LOCAL QA.

No reset, drop, user mutation or remote URL option. Existing attempt snapshots
are intentionally immutable; only the future-attempt catalog is updated.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
PG='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
PROBE='895a47cc-42dd-436a-87bf-31ac08c53cdc'
FUNCTIONS={
 'start_exam_attempt(uuid,text)':('4f91a66230671cf6bbea4e987f2aa7ed','8928a4a7c25c61fe1f92f874935d208d','28_exam_core.sql','CREATE FUNCTION public.start_exam_attempt(','CREATE FUNCTION public.complete_exam_attempt('),
 'process_monthly_competitions()':('c485ffc65139ba4682bb730f47f433c6','d0a0aef21da09cd21c4fa95f96aa518b','29_monthly_competitions.sql','CREATE FUNCTION public.process_monthly_competitions()','-- Keep old cron function/signature.'),
}

def literal(value):return "'"+str(value).replace("'","''")+"'"
def sql(body):
 result=subprocess.run(['psql',PG,'-XqAt','-v','ON_ERROR_STOP=1'],input=body,text=True,capture_output=True,timeout=30)
 if result.returncode:raise RuntimeError('Local review repair stopped: '+result.stderr.strip())
 return result.stdout.strip()
def snapshot():
 tables=['profiles','study_sessions','exam_attempts','exam_wallets','exam_subject_results','competition_events','competition_memberships','competition_results','avatar_unlocks']
 entries=[]
 for table in tables:
  entries += [literal(table),f"(select jsonb_build_object('count',count(*),'hash',md5(coalesce(jsonb_agg(to_jsonb(r)order by to_jsonb(r)::text)::text,'')))from public.{table} r)"]
 entries += ["'probe'",f"(select jsonb_build_object('id',id,'active_session_ends_at',active_session_ends_at,'reservation_start_estimate',active_session_ends_at-interval '25 minutes','minutes',total_minutes,'points',lifetime_points,'coins',coins)from public.profiles where id='{PROBE}')"]
 return 'jsonb_build_object('+','.join(entries)+')'
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
 if not args.apply:raise SystemExit('Explicit --apply required; fixed local QA only')
 if sql('select current_database()')!='postgres':raise RuntimeError('Wrong local database')
 # Unknown start wrappers are not guessed or overwritten.
 checks=["IF EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE '\\_start\\_exam%' ESCAPE '\\')THEN RAISE EXCEPTION 'unknown_exam_wrapper';END IF;"]
 for signature,(old,new,_,_,_) in FUNCTIONS.items():
  checks.append(f"IF md5(pg_get_functiondef('public.{signature}'::regprocedure))NOT IN('{old}','{new}')THEN RAISE EXCEPTION 'unreviewed_function_{signature.split('(')[0]}';END IF;")
 checks.append("IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))NOT IN('9500c7c45503a3e5031e52c879b1dba2','1582a6da3c5e9ff496a8f2c16455b13e')THEN RAISE EXCEPTION 'unreviewed_register_function';END IF;")
 statements=['BEGIN ISOLATION LEVEL REPEATABLE READ;',"SET LOCAL lock_timeout='3s';SET LOCAL statement_timeout='15s';",'DO $$BEGIN '+''.join(checks)+' END$$;',f'CREATE TEMP TABLE qa_repair_before AS SELECT {snapshot()} AS payload;']
 for signature,(_,_,name,start,end)in FUNCTIONS.items():
  source=(ROOT/'supabase/proposed'/name).read_text();fn=start+source.split(start,1)[1].split(end,1)[0]
  statements.append(fn.strip().replace('CREATE FUNCTION','CREATE OR REPLACE FUNCTION',1))
 definitions=json.loads((ROOT/'supabase/proposed/exam_catalog_v1.json').read_text())['exams']
 catalog_ids=','.join(literal(d['id'])for d in sorted(definitions,key=lambda d:d['id']))
 statements.append("DO $$BEGIN IF (SELECT array_agg(id ORDER BY id)FROM public.exam_catalog)IS DISTINCT FROM ARRAY["+catalog_ids+"]::text[] THEN RAISE EXCEPTION 'unreviewed_catalog_shape';END IF;END$$;")
 for definition in definitions:
  statements.append('UPDATE public.exam_catalog SET definition='+literal(json.dumps(definition,ensure_ascii=False))+'::jsonb WHERE id='+literal(definition['id'])+';')
 # Applying the optional30 body inside this same transaction preserves atomicity.
 body=(ROOT/'supabase/proposed/30_session_start_atomic.sql').read_text().split('BEGIN;',1)[1].rsplit('COMMIT;',1)[0]
 if sql("select count(*)from supabase_migrations.schema_migrations where version='20261028040000'")=='0':statements.append(body)
 statements.append(f'DO $$BEGIN IF (SELECT payload FROM qa_repair_before)IS DISTINCT FROM {snapshot()} THEN RAISE EXCEPTION \'qa_repair_changed_user_or_probe_data\';END IF;END$$;')
 for signature,(_,new,_,_,_)in FUNCTIONS.items():
  statements.append(f"DO $$BEGIN IF md5(pg_get_functiondef('public.{signature}'::regprocedure))<>'{new}'THEN RAISE EXCEPTION 'new_hash_mismatch';END IF;END$$;")
 statements.append("DO $$BEGIN IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))<>'1582a6da3c5e9ff496a8f2c16455b13e'THEN RAISE EXCEPTION 'register_hash_mismatch';END IF;END$$;")
 statements+=['SELECT jsonb_build_object(\'preserved\',true,\'before\',(SELECT payload FROM qa_repair_before),\'after\','+snapshot()+');',"NOTIFY pgrst,'reload schema';",'COMMIT;']
 output=sql('\n'.join(statements));payload=json.loads(output.splitlines()[-1])
 payload['scope']='fixed local QA; repeatable-read before/after excludes unrelated concurrent writes; existing snapshots unchanged'
 payload['sources_sha256']={name:hashlib.sha256((ROOT/'supabase/proposed'/name).read_bytes()).hexdigest()for name in ['28_exam_core.sql','29_monthly_competitions.sql','exam_catalog_v1.json','30_session_start_atomic.sql']}
 destination=ROOT/'build/overnight_backend/local_review_repair.json';destination.write_text(json.dumps(payload,indent=2))
 print('PASS local review repair; user tables/probe preserved; evidence:',destination)
 print(json.dumps({'probe':payload['after']['probe'],'preserved':payload['preserved']},ensure_ascii=False))
if __name__=='__main__':main()
