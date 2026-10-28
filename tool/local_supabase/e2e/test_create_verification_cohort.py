"""Cohort guards and interval/manifest contract; every external action mocked."""
from datetime import datetime,timezone
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import create_verification_cohort as cohort
from local_fixture_api import FixtureError


class CohortTests(unittest.TestCase):
    def test_four_bounded_fresh_names_and_expected_domains(self):
        rows=cohort.plan('verify-1028')
        self.assertEqual([x['role'] for x in rows],['lgs-a','lgs-b','tus-a','tus-b'])
        self.assertEqual([x['normal_count'] for x in rows],[4,3,5,2])
        self.assertTrue(all(x['email']=='e2e-sim-cohort-verify-1028-'+x['role']+'@pomosprint.local' for x in rows))
        self.assertEqual([x['exam_points'] for x in rows],[15,15,27,27])

    def test_paths_sql_and_unbounded_ids_rejected(self):
        for run in ['../x','',"x';select1--",'-bad','bad-', 'A','a'*33,'with space']:
            with self.subTest(run=run):
                with self.assertRaises(FixtureError):cohort.plan(run)

    def test_historical_intervals_are_full_duration_and_nonoverlapping(self):
        anchor=datetime(2026,10,28,8,tzinfo=timezone.utc)
        for row in cohort.plan('verify-1028'):
            starts,exam_start,exam_end=cohort.history_times(anchor,row['normal_count'],row['duration_seconds'])
            self.assertEqual((exam_end-exam_start).total_seconds(),row['duration_seconds'])
            self.assertGreater((exam_start-starts[-1]).total_seconds(),25*60)
            self.assertLess(exam_end,anchor)
            self.assertEqual([int((b-a).total_seconds()) for a,b in zip(starts,starts[1:])],[1800]*(len(starts)-1))

    def test_fixture_sql_only_changes_new_attempt_date_fields(self):
        start=datetime(2026,10,28,3,tzinfo=timezone.utc)
        text=cohort.date_fixture_sql('owner','e2e-sim-cohort-test-lgs-a@pomosprint.local','test','lgs-a',
            'attempt','client',start,start,4500)
        self.assertIn('BEGIN;',text);self.assertIn('COMMIT;',text)
        self.assertIn('qa_verification_cohort',text);self.assertIn('qa_verification_role',text)
        self.assertIn("status='active' AND finished_at IS NULL",text)
        self.assertIn('GET DIAGNOSTICS changed=ROW_COUNT',text)
        self.assertNotIn('UPDATE public.profiles',text)
        self.assertNotIn('SET points_earned',text);self.assertNotIn('SET coins',text)
        self.assertEqual(text.count('UPDATE public.'),1)

    def test_official_preflight_refuses_short_catalog_before_auth(self):
        catalog={k:list(v) for k,v in cohort.OFFICIAL.items()};catalog['lgs_verbal'][0]=60
        with patch.object(cohort,'require_local'),patch.object(cohort.subprocess,'run',return_value=SimpleNamespace(returncode=0)),patch.object(cohort,'sql',return_value=json.dumps(catalog)):
            with self.assertRaisesRegex(FixtureError,'Exact official'):cohort.official_preflight(cohort.plan('test'))

    def test_official_preflight_refuses_changed_parity_and_existing_accounts(self):
        with patch.object(cohort,'require_local'),patch.object(cohort.subprocess,'run',return_value=SimpleNamespace(returncode=1)),patch.object(cohort,'sql') as sql:
            with self.assertRaisesRegex(FixtureError,'27-30'):cohort.official_preflight(cohort.plan('test'))
            sql.assert_not_called()
        responses=[json.dumps({k:list(v) for k,v in cohort.OFFICIAL.items()}),'1']
        with patch.object(cohort,'require_local'),patch.object(cohort.subprocess,'run',return_value=SimpleNamespace(returncode=0)),patch.object(cohort,'sql',side_effect=responses):
            with self.assertRaisesRegex(FixtureError,'exists'):cohort.official_preflight(cohort.plan('test'))

    def test_inherited_libpq_routing_cannot_redirect_cohort(self):
        with patch.dict('os.environ',{'PGHOSTADDR':'example.invalid'}),patch.object(cohort.subprocess,'run') as run:
            with self.assertRaisesRegex(FixtureError,'libpq'):cohort.official_preflight(cohort.plan('test'))
            run.assert_not_called()

    def test_default_cli_is_plan_only_and_apply_needs_explicit_history_flag(self):
        with patch('sys.argv',['cohort','--run','test']),patch.object(cohort,'official_preflight'),patch.object(cohort,'create_account') as create,patch('builtins.print') as output:
            self.assertEqual(cohort.main(),0);create.assert_not_called()
            self.assertFalse(json.loads(output.call_args.args[0])['applied'])
        with patch('sys.argv',['cohort','--run','test','--apply']):
            with self.assertRaisesRegex(FixtureError,'allow-historical'):cohort.main()

    def test_failure_keeps_tagged_partial_manifest_instead_of_deleting(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            def fail(row,run,anchor,report,target):
                report['accounts'].append({'id':'created','email':row['email'],'stage':'created'})
                raise FixtureError('expected mock failure')
            with patch.object(cohort,'ROOT',root),patch('sys.argv',['cohort','--run','test','--apply','--allow-historical-metadata']),patch.object(cohort,'official_preflight'),patch.object(cohort,'sql',return_value='2026-10-28T08:00:00+00:00'),patch.object(cohort,'create_account',side_effect=fail):
                with self.assertRaises(FixtureError):cohort.main()
            report=json.loads((root/'build/verification_20261028/cohort_test.json').read_text())
            self.assertEqual(report['status'],'failed_partial_preserved')
            self.assertEqual(report['accounts'][0]['id'],'created')
            self.assertEqual(len(report['planned_accounts']),4)
            self.assertFalse(report['tokens_persisted'])
            self.assertNotIn('access_token',json.dumps(report))

    def test_room_mismatch_is_rejected_without_forcing_memberships(self):
        accounts=[{'id':'one','segment':'lgs'},{'id':'two','segment':'lgs'},
                  {'id':'three','segment':'tus'},{'id':'four','segment':'tus'}]
        memberships=[{'user_id':a['id'],'kind':kind,'segment':a['segment'],'room_id':a['segment']+kind}
                     for a in accounts for kind in ('study','exam')]
        with patch.object(cohort,'sql',return_value=json.dumps(memberships)) as sql:
            self.assertEqual(len(cohort.same_room_check(accounts)),8)
            self.assertTrue(sql.call_args.args[0].startswith('select'))
        memberships[0]['room_id']='different'
        with patch.object(cohort,'sql',return_value=json.dumps(memberships)):
            with self.assertRaisesRegex(FixtureError,'different rooms'):cohort.same_room_check(accounts)


if __name__=='__main__':unittest.main()
