#!/usr/bin/env python3
"""Yerel QA RPC: 5/10 gerçek saniye → 25/50 rapor dakikası.

Normal RPC aynen kalır. Puan, seri, limit, lig, idempotency ve kategoriler
yerel normal RPC'nin aynı gövdesinden gelir; yalnızca zaman ölçeği değişir.
Canlı bağlantı almaz: yalnızca adı sabit yerel Docker konteynerinde çalışır.
Kaldırma: python3 tool/local_supabase/quick_recording.py --remove
"""
import subprocess
import sys

CMD = ['docker', 'exec', '-i', 'supabase_db_pomosprint-local', 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-v', 'ON_ERROR_STOP=1']
SIGNATURE = '(uuid,uuid,integer,boolean,integer,timestamptz)'

if '--remove' in sys.argv:
    sql = 'DROP FUNCTION IF EXISTS public.complete_qa_study_session' + SIGNATURE + ';'
else:
    sql = subprocess.check_output(CMD + ['-Atc', "select pg_get_functiondef('public.complete_study_session" + SIGNATURE + "'::regprocedure)"], text=True)
    assert 'session_not_finished' in sql and "IF v_ends_at > now() + interval '5 minutes' THEN" in sql
    sql = sql.replace('public.complete_study_session(', 'public.complete_qa_study_session(', 1)
    sql = sql.replace('make_interval(mins => p_duration_minutes)', 'make_interval(secs => CASE WHEN p_duration_minutes = 25 THEN 5 ELSE 10 END)')
    sql = sql.replace("interval '60 seconds'", "interval '0 seconds'")
    sql = sql.replace("IF v_ends_at > now() + interval '5 minutes' THEN", "IF v_ends_at > clock_timestamp() + interval '1 second' THEN")
    sql += ';\nREVOKE ALL ON FUNCTION public.complete_qa_study_session' + SIGNATURE + ' FROM PUBLIC, anon;\n'
    sql += 'GRANT EXECUTE ON FUNCTION public.complete_qa_study_session' + SIGNATURE + ' TO authenticated;\n'
    sql += "COMMENT ON FUNCTION public.complete_qa_study_session" + SIGNATURE + " IS 'LOCAL QA ONLY: 5/10 seconds recorded as 25/50 minutes';\n"
sql += "NOTIFY pgrst, 'reload schema';\n"
subprocess.run(CMD, input=sql, text=True, check=True)
print('Yerel kayıtlı hızlı sayaç RPC hazır.' if '--remove' not in sys.argv else 'Yerel QA RPC kaldırıldı.')
