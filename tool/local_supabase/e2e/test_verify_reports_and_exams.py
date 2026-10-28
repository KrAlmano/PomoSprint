"""Independent accounting oracle regressions; synthetic records, no DB writes."""
from copy import deepcopy
from decimal import Decimal
import json
import os
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import verify_reports_and_exams as verifier

OWNER='11111111-1111-4111-8111-111111111111'


def fixture():
    def study(ident,start,end,bonus=0):
        return {'id':ident,'client_uuid':'client-'+ident,'started_at':start,'completed_at':end,
                'duration_minutes':25,'base_points':5,'bonus_points':bonus,
                'category_id':'math','category_name':'Matematik'}
    studies=[study('s1','2026-10-27T21:00:00Z','2026-10-27T21:25:00Z'),
             study('s2','2026-10-28T05:00:00Z','2026-10-28T05:25:00Z'),
             study('s3','2026-10-28T05:30:00Z','2026-10-28T05:55:00Z',2)]
    definition={'id':'lgs_verbal','duration_seconds':4500,'reward_points':15,'reward_coins':3,
                'wrong_answer_divisor':3,'subjects':[{'id':'turkish','question_count':20}]}
    completed={'id':'a1','client_uuid':'exam1','exam_id':'lgs_verbal','definition':definition,
               'started_at':'2026-10-28T00:30:00Z','ends_at':'2026-10-28T01:45:00Z',
               'finished_at':'2026-10-28T01:45:00Z','status':'completed','elapsed_seconds':4500,
               'points_earned':15,'exam_coins_earned':3}
    abandoned=deepcopy(completed);abandoned.update(id='a2',client_uuid='exam2',status='abandoned',
        started_at='2026-10-28T06:00:00Z',ends_at='2026-10-28T07:15:00Z',
        finished_at='2026-10-28T06:00:12Z',elapsed_seconds=12,points_earned=0,exam_coins_earned=0)
    events=[]
    for row in studies:
        events.append({'kind':'study','source_id':row['id'],'points':row['base_points']+row['bonus_points'],
                       'minutes':25,'completed_at':row['completed_at'],'period_month':'2026-10-01',
                       'study_day':verifier.workday(row['started_at'],'Europe/Istanbul').isoformat()})
    events.append({'kind':'exam','source_id':'a1','points':15,'minutes':75,
                   'completed_at':completed['ends_at'],'period_month':'2026-10-01','study_day':'2026-10-27'})
    return {'captured_at':'2026-10-28T12:00:00Z','database':'postgres',
     'schema_versions':['20261028010000','20261028020000','20261028030000','20261028040000'],
     'marathon_function_md5':'177a238a9aa8a4ffd3738b2865120568',
     'qa_email':'e2e-sim-oracle@pomosprint.local',
     'profile':{'id':OWNER,'total_minutes':150,'lifetime_points':17,'coins':60,'current_streak':2,
                'longest_streak':2,'last_study_date':'2026-10-28','timezone':'Europe/Istanbul','daily_goal_minutes':100},
     'studies':studies,'attempts':[completed,abandoned],
     'results':[{'attempt_id':'a1','subject_id':'turkish','correct':10,'wrong':3,'blank':7,
                 'net':Decimal('9.00000000000000000000'),'updated_at':'2026-10-28T07:00:00Z'}],
     'wallet':{'coins':3,'lifetime_points':15},
     'runs':[{'client_uuid':'run1','target_sessions':2,'duration_minutes':25,'bonus_awarded':2,'is_invalid':False}],
     'mappings':[{'marathon_uuid':'run1','session_index':1,'client_uuid':'client-s2','study_session_id':'s2'},
                 {'marathon_uuid':'run1','session_index':2,'client_uuid':'client-s3','study_session_id':'s3'}],
     'events':events,'unlocks':[]}


class ReportOracleTests(unittest.TestCase):
    def verify(self,data=None,**kwargs):
        return verifier.analyze_snapshot(data or fixture(),**kwargs)

    def failures(self,result):
        return [x['control'] for x in result['checks'] if not x['passed']]

    def test_mixed_normal_marathon_completed_and_abandoned_exam(self):
        x=self.verify();self.assertEqual(x['status'],'PASS',self.failures(x))
        day=x['expected']['reports']['daily'];week=x['expected']['reports']['weekly']
        self.assertEqual(day['total_minutes'],50)
        self.assertEqual(day['counts'],{'normal_sessions':0,'marathon_focus_sessions':2,
            'completed_marathons':1,'completed_exams':0,'unknown_sessions':0,'pending_sessions':0})
        self.assertEqual(day['efficiency'],50)
        self.assertEqual(week['total_minutes'],150)
        self.assertEqual(week['category_minutes'],{'math':75,'pomosprint:exam':75})
        self.assertEqual(week['category_percentages'],{'math':50,'pomosprint:exam':50})
        self.assertEqual(week['focus_equivalents'],3)
        self.assertEqual(week['counts']['completed_exams'],1)
        self.assertEqual(x['expected']['economy'],{'total_minutes':150,'normal_points':17,
            'normal_coins':60,'exam_points':15,'exam_coins':3})

    def test_detects_every_economy_mismatch_and_duplicate_source(self):
        for table,key in [('profile','total_minutes'),('profile','lifetime_points'),
                          ('profile','coins'),('wallet','coins'),('wallet','lifetime_points')]:
            with self.subTest(table=table,key=key):
                s=fixture();s[table][key]+=1;self.assertEqual(self.verify(s)['status'],'FAIL')
        s=fixture();s['events'].append(deepcopy(s['events'][0]))
        self.assertIn('competition_event_unique',self.failures(self.verify(s)))
        s=fixture();s['attempts'][1]['client_uuid']=s['attempts'][0]['client_uuid']
        self.assertIn('exam_client_uuid_unique',self.failures(self.verify(s)))

    def test_abandoned_attempt_never_counts_or_receives_reward(self):
        s=fixture();s['attempts'][1]['points_earned']=1
        x=self.verify(s);self.assertIn('exam[1].uncompleted_points',self.failures(x))
        self.assertEqual(x['expected']['reports']['weekly']['total_minutes'],150)

    def test_active_exam_has_no_completion_or_reward(self):
        s=fixture();s['attempts'][1].update(status='active',finished_at=None,elapsed_seconds=0)
        x=self.verify(s);self.assertEqual(x['status'],'PASS',self.failures(x))
        self.assertEqual(x['expected']['reports']['weekly']['counts']['completed_exams'],1)

    def test_completed_zero_reward_short_exam_still_has_time_and_zero_point_event(self):
        s=fixture();attempt=s['attempts'][0]
        attempt['definition'].update(duration_seconds=60,reward_points=0,reward_coins=0)
        attempt.update(ends_at='2026-10-28T00:31:00Z',finished_at='2026-10-28T00:31:00Z',
                       elapsed_seconds=60,points_earned=0,exam_coins_earned=0)
        s['profile']['total_minutes']=76;s['wallet']={'coins':0,'lifetime_points':0}
        s['events'][-1].update(points=0,minutes=1,completed_at='2026-10-28T00:31:00Z')
        result=self.verify(s)
        self.assertEqual(result['status'],'PASS',self.failures(result))
        self.assertEqual(result['expected']['reports']['weekly']['total_minutes'],76)
        self.assertEqual(result['expected']['reports']['weekly']['counts']['completed_exams'],1)
        # Zero points suppress room placement, not the accepted event ledger.
        s['events'].pop()
        self.assertIn('competition_events.exact_sources_and_accounting',self.failures(self.verify(s)))

    def test_net_formula_negative_thirds_and_updated_timestamp(self):
        s=fixture();r=s['results'][0];r.update(correct=0,wrong=1,blank=19,
            net=Decimal('-0.33333333333333333333'))
        self.assertEqual(self.verify(s)['status'],'PASS')
        r['net']=0;self.assertIn('result[0].net_formula',self.failures(self.verify(s)))
        r['net']=Decimal('-0.25');self.assertIn('result[0].net_formula',self.failures(self.verify(s)))
        r['correct']=-1;self.assertIn('result[0].nonnegative_integers',self.failures(self.verify(s)))
        r['updated_at']='2026-10-29T00:00:00Z'
        self.assertIn('result[0].updated_not_future',self.failures(self.verify(s)))

    def test_partial_results_are_allowed_and_nets_do_not_create_economy(self):
        s=fixture();s['results']=[]
        self.assertEqual(self.verify(s)['status'],'PASS')
        self.assertEqual(self.verify(s)['expected']['economy'],self.verify()['expected']['economy'])

    def test_avatar_spending_subtracts_only_normal_wallet(self):
        s=fixture();s['unlocks']=[{'avatar_id':'special','coins_spent':40}];s['profile']['coins']=20
        self.assertEqual(self.verify(s)['status'],'PASS')
        self.assertEqual(self.verify(s)['expected']['economy']['exam_coins'],3)

    def test_invalid_marathon_keeps_focus_without_completed_plan(self):
        s=fixture();s['runs'][0]['is_invalid']=True;s['runs'][0]['bonus_awarded']=0
        x=self.verify(s);self.assertEqual(x['expected']['reports']['daily']['counts']['completed_marathons'],0)
        self.assertEqual(x['expected']['reports']['daily']['total_minutes'],50)

    def test_wrong_normal_base_and_marathon_bonus_are_not_hidden_by_matching_totals(self):
        s=fixture();s['studies'][0]['base_points']=6;s['profile']['lifetime_points']=18
        s['events'][0]['points']=6
        self.assertIn('study[0].base_points_rule',self.failures(self.verify(s)))
        s=fixture();s['runs'][0]['bonus_awarded']=4
        self.assertIn('run[0].bonus_rule',self.failures(self.verify(s)))

    def test_actual_04_boundary_and_month_distinction(self):
        self.assertEqual(verifier.workday('2026-11-01T00:59:59Z','Europe/Istanbul').isoformat(),'2026-10-31')
        self.assertEqual(verifier.workday('2026-11-01T01:00:00Z','Europe/Istanbul').isoformat(),'2026-11-01')
        self.assertEqual(verifier.month_of('2026-10-31T21:00:00Z'),'2026-11-01')
        # A completed exam crossing04 stays on its start day.
        s=fixture();self.assertEqual(self.verify(s)['expected']['reports']['daily']['counts']['completed_exams'],0)

    def test_dst_uses_wall_date_not_duration_subtraction(self):
        for instant,expected in [('2026-11-01T05:30:00Z','2026-10-31'),
                                 ('2026-11-01T06:30:00Z','2026-10-31'),
                                 ('2026-11-01T09:00:00Z','2026-11-01')]:
            self.assertEqual(verifier.workday(instant,'America/New_York').isoformat(),expected)

    def test_month_end_comparison_is_clamped_and_no_false_growth(self):
        x=self.verify(as_of='2026-11-30T12:00:00Z')
        month=x['expected']['reports']['monthly']
        self.assertEqual(month['start'],'2026-11-01');self.assertEqual(month['end'],'2026-11-30')
        self.assertEqual(month['month_to_date_growth_percentage'],-100)
        self.assertIsNone(verifier._rounded_change(50,0))

    def test_late_arrival_streak_disagreement_is_explicit_policy_warning(self):
        s=fixture();s['profile'].update(current_streak=1,longest_streak=1)
        x=self.verify(s);self.assertEqual(x['expected']['reconstructed_streak']['current_streak'],2)
        self.assertIn('stored_streak_differs_from_reconstructed_days_late_or_timezone_policy_requires_review',x['warnings'])

    def test_percentages_sum_to100_and_stable_largest_remainder(self):
        self.assertEqual(verifier._rounded_percentages([{'minutes':1}]*3),[34,33,33])
        self.assertEqual(verifier._rounded_percentages([{'minutes':0}]*2),[0,0])

    def test_package31_and_missing_required_migration_are_rejected(self):
        s=fixture();s['schema_versions'].append('20261028050000')
        self.assertIn('schema.package31_not_installed',self.failures(self.verify(s)))
        s=fixture();s['schema_versions'].remove('20261028040000')
        self.assertIn('schema.required_27_30',self.failures(self.verify(s)))

    def test_rls_peer_visible_rows_are_a_failure(self):
        self.assertEqual(self.verify(rls={'peer_exam_attempts_visible':0,'peer_subject_results_visible':0})['status'],'PASS')
        self.assertIn('rls.peer_exam_attempts_visible',self.failures(self.verify(rls={'peer_exam_attempts_visible':1})))

    def test_nonlocal_nonqa_malformed_and_oversized_inputs_fail_closed(self):
        for value in ['../bad',OWNER.upper(),"';DROP TABLE profiles;--"]:
            if value==OWNER:continue
            with self.assertRaises(verifier.VerificationError):verifier.owner_uuid(value)
        s=fixture();s['qa_email']='real@example.com'
        with self.assertRaises(verifier.VerificationError):self.verify(s)
        with patch.dict(os.environ,{'LOCAL_DB_URL':'postgresql://example.invalid/db'}):
            with self.assertRaises(verifier.VerificationError):verifier._local_guard()
        s=fixture();s['events']=[{}]*(verifier.MAX_ROWS+1)
        with self.assertRaises(verifier.VerificationError):self.verify(s)

    def test_psql_is_fixed_readonly_and_errors_never_echo_credentials(self):
        snapshot=fixture();raw=json.dumps(verifier.json_safe(snapshot))
        with patch.object(verifier.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout=raw)) as run:
            with patch.dict(os.environ,{'PGHOSTADDR':'example.invalid','PGSERVICEFILE':'/do-not-read','PGOPTIONS':'unsafe'}):
                verifier.read_snapshot(OWNER)
            args,kwargs=run.call_args
            self.assertEqual(args[0][1],verifier.DB)
            self.assertIn('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;',kwargs['input'])
            self.assertIn('default_transaction_read_only=on',kwargs['env']['PGOPTIONS'])
            self.assertNotIn('PGHOSTADDR',kwargs['env']);self.assertNotIn('PGSERVICEFILE',kwargs['env'])
            self.assertNotIn('password',kwargs['input'])
        with patch.object(verifier.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='',stderr='TOKEN-SENTINEL')):
            with self.assertRaisesRegex(verifier.VerificationError,'local_readonly_snapshot_failed') as error:
                verifier.read_snapshot(OWNER)
            self.assertNotIn('TOKEN-SENTINEL',str(error.exception))


if __name__=='__main__':unittest.main()
