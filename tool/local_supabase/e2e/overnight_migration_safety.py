#!/usr/bin/env python3
"""Exact forward/dry-run/down test in the named empty local baseline clone."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3]
DB='pomosprint_overnight_baseline';PG=f'postgresql://postgres:postgres@127.0.0.1:54322/{DB}'
checks=[]
def sql(body,fail=False):
 p=subprocess.run(['psql',PG,'-XqAt','-v','ON_ERROR_STOP=1'],input=body,text=True,capture_output=True)
 if fail:return p.stderr,p.returncode
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stdout.strip()
def source(path):return '\n'.join(l for l in (ROOT/path).read_text().splitlines()if not l.startswith('\\'))
def check(name,ok):checks.append({'name':name,'ok':bool(ok)});print(('PASS 'if ok else'FAIL ')+name,flush=True)
def snapshot():
 return sql("""select string_agg(x,E'\\n'order by x)from(
 select 'func '||p.oid::regprocedure::text||' '||md5(pg_get_functiondef(p.oid))||' '||coalesce(p.proacl::text,'')x from pg_proc p where p.pronamespace='public'::regnamespace
 union all select 'col '||table_name||'.'||column_name||' '||data_type||' '||coalesce(column_default,'') from information_schema.columns where table_schema='public'
 union all select 'policy '||tablename||'.'||policyname||' '||coalesce(qual,'')||' '||coalesce(with_check,'')from pg_policies where schemaname='public'
 union all select 'constraint '||conrelid::regclass||'.'||conname||' '||pg_get_constraintdef(oid)from pg_constraint where connamespace='public'::regnamespace
 union all select 'trigger '||tgrelid::regclass||'.'||tgname||' '||pg_get_triggerdef(oid)from pg_trigger where not tgisinternal and tgrelid in(select oid from pg_class where relnamespace='public'::regnamespace)
 union all select 'cron '||jobname||' '||schedule||' '||command from cron.job
 )s""")
def main():
 if sql('select current_database()')!=DB:raise RuntimeError('Wrong local DB')
 if sql('select count(*)from auth.users')!='0':raise RuntimeError('Baseline test requires an empty isolated clone')
 for f in ['20261007150000_marathon_break_presence','20261007160000_marathon_rewards','20261007170000_marathon_presence_confirmation','20261007110000_report_submission_lock','20261008190000_league_launch_policy']:
  if sql(f"select count(*)from supabase_migrations.schema_migrations where version='{f.split('_')[0]}'")=='0':sql(source('supabase/migrations/'+f+'.sql'))
 baseline=snapshot();before={};names=['27_tus_segment','28_exam_core','29_monthly_competitions']
 for name in names:
  before[name]=snapshot();main_source=source('supabase/proposed/'+name+'.sql');body=main_source.split('BEGIN;',1)[1].rsplit('COMMIT;',1)[0]
  dry=source('supabase/proposed/'+name+'_dryrun.sql')
  check(name+' exact embedded body',dry.split('-- >>> PROPOSED BODY\n',1)[1].split('-- <<< PROPOSED BODY',1)[0].strip()==body.strip())
  err,code=sql(dry,True)
  result=err.split('DRYRUN_RESULT >> ',1)[-1].split('\n',1)[0]
  check(name+' dryrun all true',code!=0 and 'DRYRUN_RESULT >> 'in err and ': false'not in result)
  check(name+' dryrun rollback exact',snapshot()==before[name])
  sql(main_source);check(name+' migration registered',sql(f"select count(*)from supabase_migrations.schema_migrations where name={json.dumps({'27_tus_segment':'tus_segment','28_exam_core':'exam_core','29_monthly_competitions':'monthly_competitions'}[name]).replace(chr(34),chr(39))}")=='1')
 for name in reversed(names):
  sql(source('supabase/proposed/'+name+'_down.sql'));check(name+' down exact schema',snapshot()==before[name])
 check('all down baseline exact',snapshot()==baseline)
 (ROOT/'build/overnight_backend/migration_safety.json').write_text(json.dumps({'checks':checks,'passed':sum(c['ok']for c in checks),'total':len(checks)},indent=2))
 if not all(c['ok']for c in checks):raise SystemExit(1)
if __name__=='__main__':main()
