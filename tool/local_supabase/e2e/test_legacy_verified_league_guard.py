#!/usr/bin/env python3
"""Regression on exact reviewed legacy SQL; disposable local PostgreSQL only.

Starts its own temporary Unix-socket cluster, needs PostgreSQL initdb/pg_ctl/psql.
Never reads .env, opens TCP connections, contacts hosted DB, or changes 31.
Historical timestamps are fixtures, not elapsed-time or production evidence.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
FORWARD = ROOT / 'supabase/proposed/34_verified_reward_guard.sql'
DRYRUN = ROOT / 'supabase/proposed/34_verified_reward_guard_dryrun.sql'
ACTIVATION = ROOT / 'supabase/proposed/34_verified_reward_policy_activation_REVIEW_ONLY.sql'
ROLLBACK = ROOT / 'supabase/proposed/34_verified_reward_guard_down.sql'
LEGACY = ROOT / 'supabase/migrations/20261008190000_league_launch_policy.sql'
MONTHLY = ROOT / 'supabase/proposed/29_monthly_competitions.sql'

def extract_function(path, name):
    match = re.search(r'CREATE FUNCTION public\.' + re.escape(name) + r'\([^\n]*\)[\s\S]*?\$\$;', path.read_text(), re.I)
    if not match:
        raise AssertionError('missing function ' + name)
    return match.group()

class LegacyGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix='pomo-league-guard-')
        cls.folder = Path(cls.directory.name)
        cls.pgdata = cls.folder / 'db'
        subprocess.run(['initdb', '-D', str(cls.pgdata), '-A', 'trust', '-U', 'pomoqa', '--no-locale'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        subprocess.run(['pg_ctl', '-D', str(cls.pgdata), '-l', str(cls.folder / 'server.log'), '-o', f"-F -k {cls.folder} -p 55496 -c listen_addresses=''", 'start'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    @classmethod
    def tearDownClass(cls):
        subprocess.run(['pg_ctl', '-D', str(cls.pgdata), '-m', 'immediate', 'stop'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        cls.directory.cleanup()

    def sql(self, body):
        result = subprocess.run(['psql', '-h', str(self.folder), '-p', '55496', '-U', 'pomoqa', '-d', 'postgres', '-XqAt', '-v', 'ON_ERROR_STOP=1'], input=body, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_exact_patch_and_guarded_rollout(self):
        forward = FORWARD.read_text()
        dryrun = DRYRUN.read_text()
        self.assertEqual(forward[forward.index('BEGIN;'):forward.rindex('COMMIT;')], dryrun[dryrun.index('BEGIN;'):dryrun.index('CREATE TEMP TABLE qa_34_checks')])
        activation = ACTIVATION.read_text()
        self.assertIn("RAISE EXCEPTION 'verified_reward_client_rollout_not_verified'", activation)
        self.assertLess(activation.index('INSERT INTO public.verified_reward_legacy_session_anchor_34'), activation.index("SET value='0'::jsonb"))
        rollback = ROLLBACK.read_text()
        for token in ('legacy_activity_before', 'legacy_launch_before', 'legacy_activity_installed', 'legacy_launch_installed', 'verified_reward_legacy_session_anchor_34'):
            self.assertIn(token, rollback)
        start = forward.index(" SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='legacy_activity_before';")
        end = forward.index(" SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='marathon_before';", start)
        patch = 'DO $$ DECLARE original text; marker text; BEGIN\n' + forward[start:end] + '\nEND $$;'
        activity = extract_function(LEGACY, '_league_period_activity')
        launch = extract_function(LEGACY, '_league_refresh_start')
        finalize = extract_function(MONTHLY, '_competition_finalize_legacy')
        fixture = r"""
CREATE TABLE public.profiles(id uuid PRIMARY KEY,timezone text NOT NULL,league_tier integer NOT NULL);
CREATE TABLE public.study_sessions(id uuid PRIMARY KEY,user_id uuid,started_at timestamptz,completed_at timestamptz,duration_minutes integer,base_points integer,bonus_points integer,start_verified boolean);
CREATE TABLE public.leagues(id uuid PRIMARY KEY,tier integer,is_active boolean);
CREATE TABLE public.league_memberships(user_id uuid,league_id uuid,joined_at timestamptz);
CREATE TABLE public.competition_policy(singleton boolean PRIMARY KEY,activates_at timestamptz,legacy_finalized boolean,legacy_snapshot jsonb,legacy_decisions jsonb);
CREATE TABLE public.league_competition_state(singleton boolean PRIMARY KEY,start_at timestamptz,initialized boolean,period_started_at timestamptz);
CREATE TABLE public.competition_profiles(user_id uuid,kind text,tier integer);
CREATE TABLE public.avatar_unlocks(user_id uuid,avatar_id text,unlock_type text,coins_spent integer,UNIQUE(user_id,avatar_id));
CREATE TABLE public.verified_reward_legacy_session_anchor_34(session_id uuid PRIMARY KEY REFERENCES public.study_sessions(id) ON DELETE CASCADE);
CREATE TABLE public.verified_reward_backup_34(key text PRIMARY KEY,value text NOT NULL);
CREATE TABLE public.app_config(key text PRIMARY KEY,value jsonb NOT NULL);
INSERT INTO public.app_config VALUES ('unverified_session_daily_cap','null'::jsonb);
CREATE FUNCTION public.app_config_int(text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT CASE WHEN value='null'::jsonb THEN NULL ELSE (value #>> '{}')::integer END FROM public.app_config WHERE key=$1 $$;
CREATE FUNCTION public._league_policy_int(text,integer,integer,integer) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT 3 $$;
CREATE FUNCTION public._league_grid_start(timestamptz) RETURNS timestamptz LANGUAGE sql STABLE AS $$ SELECT now() $$;
CREATE FUNCTION public.league_award_avatar_id(integer,integer) RETURNS text LANGUAGE sql AS $$ SELECT NULL::text $$;
""" + activity + '\n' + launch + '\n' + finalize + r"""
INSERT INTO public.verified_reward_backup_34 VALUES
 ('legacy_activity_before',pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure)),
 ('legacy_launch_before',pg_get_functiondef('public._league_refresh_start()'::regprocedure));
""" + patch + r"""
INSERT INTO public.profiles VALUES ('00000000-0000-0000-0000-000000000001','Europe/Istanbul',1),('00000000-0000-0000-0000-000000000002','Europe/Istanbul',1),('00000000-0000-0000-0000-000000000003','Europe/Istanbul',1);
INSERT INTO public.leagues VALUES ('10000000-0000-0000-0000-000000000001',1,true);
INSERT INTO public.league_memberships SELECT id,'10000000-0000-0000-0000-000000000001',now()-interval '5 days' FROM public.profiles;
INSERT INTO public.competition_profiles SELECT id,'study',1 FROM public.profiles;
INSERT INTO public.competition_policy VALUES(true,now()-interval '1 minute',false,'{}','[]');
INSERT INTO public.league_competition_state VALUES(true,now()-interval '7 days',true,now()-interval '7 days');
INSERT INTO public.study_sessions SELECT gen_random_uuid(),id,now()-interval '3 days 1 hour',now()-interval '3 days',25,CASE WHEN right(id::text,1)='1' THEN 10 ELSE 5 END,0,true FROM public.profiles;
-- A previously accepted, unverified zero-point session must remain counted.
INSERT INTO public.study_sessions VALUES ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',now()-interval '2 days 2 hours',now()-interval '2 days 1 hour',50,0,0,false);
INSERT INTO public.verified_reward_legacy_session_anchor_34 SELECT id FROM public.study_sessions;
-- New verified zero-point sessions count; new offline unverified zero-point do not.
INSERT INTO public.study_sessions VALUES ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',now()-interval '1 day 2 hours',now()-interval '1 day 1 hour',50,0,0,true);
INSERT INTO public.study_sessions SELECT gen_random_uuid(),'00000000-0000-0000-0000-000000000001',now()-make_interval(days=>d,hours=>h*2),now()-make_interval(days=>d,hours=>h*2)+interval '50 minutes',50,0,0,false FROM generate_series(1,3)d CROSS JOIN generate_series(1,2)h;
DO $$ DECLARE x record; BEGIN
 SELECT * INTO x FROM public._league_period_activity(now()-interval '7 days',now()-interval '1 minute') WHERE user_id='00000000-0000-0000-0000-000000000001';
 IF x.focus_minutes<>425 OR x.study_days<>3 OR x.points<>10 THEN RAISE EXCEPTION 'disabled regression: %',row_to_json(x); END IF;
END $$;
UPDATE public.app_config SET value='0'::jsonb WHERE key='unverified_session_daily_cap';
DO $$ DECLARE x record; BEGIN
 SELECT * INTO x FROM public._league_period_activity(now()-interval '7 days',now()-interval '1 minute') WHERE user_id='00000000-0000-0000-0000-000000000001';
 IF x.focus_minutes<>125 OR x.study_days<>3 OR x.points<>10 THEN RAISE EXCEPTION 'enabled/grandfather regression: %',row_to_json(x); END IF;
END $$;
SELECT public._competition_finalize_legacy();
DO $$ BEGIN IF (SELECT league_tier FROM public.profiles WHERE id='00000000-0000-0000-0000-000000000001')<>1 THEN RAISE EXCEPTION 'unverified offline sessions incorrectly promoted user'; END IF; END $$;
-- Independent legacy start threshold. All sessions here are new offline ones.
TRUNCATE public.verified_reward_legacy_session_anchor_34,public.study_sessions;
UPDATE public.league_competition_state SET start_at=NULL,initialized=false,period_started_at=NULL;
INSERT INTO public.study_sessions SELECT gen_random_uuid(),id,now()-interval '1 hour',now()-interval '30 minutes',25,0,0,false FROM public.profiles;
SELECT public._league_refresh_start();
DO $$ BEGIN IF (SELECT start_at FROM public.league_competition_state) IS NOT NULL THEN RAISE EXCEPTION 'offline sessions started legacy league'; END IF; END $$;
-- One grandparented and two verified zero-point sessions can start it.
INSERT INTO public.verified_reward_legacy_session_anchor_34 SELECT id FROM public.study_sessions WHERE user_id='00000000-0000-0000-0000-000000000001';
UPDATE public.study_sessions SET start_verified=true WHERE user_id IN ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003');
SELECT public._league_refresh_start();
DO $$ BEGIN IF (SELECT start_at FROM public.league_competition_state) IS NULL THEN RAISE EXCEPTION 'grandfathered/verified activity incorrectly ignored'; END IF; END $$;
SELECT 'legacy_guard_behavior_pass';
"""
        self.assertIn('legacy_guard_behavior_pass', self.sql(fixture))

if __name__ == '__main__':
    unittest.main(verbosity=2)
