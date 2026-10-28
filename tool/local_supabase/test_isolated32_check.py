"""No-network safety checks for the isolated proposed32 runner."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

PATH = Path(__file__).with_name('isolated32_check.py')
SPEC = importlib.util.spec_from_file_location('isolated32_under_test', PATH)
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


class GuardTests(unittest.TestCase):
    def tearDown(self):
        runner.select_target(False)

    def test_twenty_central_rewards_and_policy_version(self):
        path=runner.ROOT/'supabase/proposed/exam_catalog_32.json'
        rows=json.loads(path.read_text())['exams']
        expected={'lgs_verbal':60,'lgs_quantitative':70,'ydt':95,'tus_basic':110,'tus_clinical':110,'dus':120,'tyt':130,'ayt':145}
        expected.update({key:105 for key in runner.KPSS_GENERAL_IDS})
        expected.update({key:50 if key.endswith('_statistics') else 40 for key in runner.KPSS_FIELD_IDS})
        self.assertEqual({r['id']:r['reward_coins'] for r in rows},expected)
        self.assertTrue(all(r['reward_policy_version']==2 and r['catalog_version']==1 for r in rows))

    def test_kpss_official_tests_are_separate_and_totals_are_exact(self):
        rows=json.loads((runner.ROOT/'supabase/proposed/exam_catalog_32.json').read_text())['exams']
        kpss={row['id']:row for row in rows if row['segment']=='kpss'}
        self.assertEqual(set(kpss),set(runner.KPSS_GENERAL_IDS+runner.KPSS_FIELD_IDS))
        for name,row in kpss.items():
            self.assertEqual(row['wrong_answer_divisor'],4)
            self.assertEqual(sum(s['question_count'] for s in row['subjects']),row['total_questions'])
            self.assertEqual(row['reward_points'],row['duration_seconds']//300)
            self.assertNotIn('modules',row)
            if name in runner.KPSS_GENERAL_IDS:
                self.assertEqual((row['duration_seconds'],row['total_questions']),(7800,120))
                self.assertEqual([(s['id'],s['question_count']) for s in row['subjects']],
                                 [('general_ability',60),('general_knowledge',60)])
            else:
                self.assertEqual((row['duration_seconds'],row['total_questions']),
                                 (3600 if name.endswith('_statistics') else 3000,40))
                self.assertEqual(len(row['subjects']),1)

    def test_kpss_flag_is_fixed_and_default_plan_remains_connection_free(self):
        with patch.object(runner.subprocess,'run') as call, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--kpss']),0)
        call.assert_not_called()
        self.assertEqual(runner.CLONE_DB,'pomosprint_review32_kpss')
        self.assertEqual(runner.OUTPUT.name,'isolated32_kpss')
        self.assertNotIn('pomosprint_review32_dus',runner.CREATE_CLONE)
        with self.assertRaises(ValueError):
            runner.select_target('production')

    def test_dus_official_standard_distribution_and_separate_categories(self):
        rows=json.loads((runner.ROOT/'supabase/proposed/exam_catalog_32.json').read_text())['exams']
        dus=next(r for r in rows if r['id']=='dus')
        self.assertEqual((dus['duration_seconds'],dus['total_questions'],dus['reward_points'],dus['segment']),(9000,120,30,'dus'))
        self.assertEqual([s['question_count'] for s in dus['subjects']],[6,4,6,6,6,4,4,4]+[10]*8)
        self.assertEqual(len({s['id'] for s in dus['subjects']}),16)
        by_id={s['id']:s for s in dus['subjects']}
        self.assertEqual(by_id['histology_embryology']['category_keys'],['Histoloji ve Embriyoloji'])
        self.assertEqual(by_id['physiology']['category_keys'],['Fizyoloji'])

    def test_all_changed_prerequisite_dryruns_copy_the_forward_body(self):
        base=runner.ROOT/'supabase/proposed'
        for name in ['27_tus_segment','28_exam_core','29_monthly_competitions']:
            with self.subTest(name=name):
                source=runner.strip_psql_guards((base/(name+'.sql')).read_text())
                dry=(base/(name+'_dryrun.sql')).read_text()
                copied=dry.split('-- >>> PROPOSED BODY',1)[1].split('-- <<< PROPOSED BODY',1)[0]
                self.assertEqual(runner.transaction_body(source).strip(),copied.strip())

    def test_default_plan_never_connects(self):
        with patch.object(runner.subprocess, 'run') as call, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main([]), 0)
        call.assert_not_called()

    def test_unfinished_package_refuses_before_evidence_or_database(self):
        with patch.object(runner, 'PACKAGE', None), patch.object(runner, 'Evidence') as evidence, patch.object(runner, 'LocalDatabase') as database, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--apply-tests']), 2)
        evidence.assert_not_called()
        database.assert_not_called()

    def test_only_leading_psql_guards_removed(self):
        sql = '-- comment\n\\echo read\n\\quit\nBEGIN;\nSELECT 1;\nCOMMIT;'
        value = runner.strip_psql_guards(sql)
        self.assertNotIn('\\echo', value)
        self.assertIn('SELECT 1', value)

    def test_mid_statement_psql_command_rejected(self):
        for sql in ['BEGIN;\nSELECT 1; \\! touch nope\nCOMMIT;', 'BEGIN;\n\\connect remote\nCOMMIT;', 'BEGIN;\nSELECT 1;\n\\i arbitrary.sql\nCOMMIT;']:
            with self.subTest(sql=sql), self.assertRaises(ValueError):
                runner.strip_psql_guards(sql)

    def test_backslash_inside_function_literal_is_not_a_command(self):
        sql = "BEGIN;\nDO $$ BEGIN PERFORM E'\\n'; END $$;\nCOMMIT;"
        self.assertEqual(runner.strip_psql_guards(sql), sql)

    def test_transaction_required(self):
        with self.assertRaises(ValueError):
            runner.strip_psql_guards('SELECT 1;')

    def test_identifier_injection_rejected(self):
        for name in ['public.users;DELETE', 'users', 'public.users.extra', 'public."users"']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                runner.identifier(name)

    def test_explicit_enable_required(self):
        with patch.object(runner.shutil, 'which') as which, self.assertRaises(ValueError):
            runner.LocalDatabase(Mock(), explicitly_enabled=False)
        which.assert_not_called()

    def database(self):
        with patch.object(runner.shutil, 'which', return_value='/usr/bin/psql'):
            return runner.LocalDatabase(Mock(), explicitly_enabled=True)

    def test_unknown_database_rejected(self):
        db = self.database()
        with patch.object(runner.subprocess, 'run') as call, self.assertRaises(ValueError):
            db.readonly('production', 'SELECT 1')
        call.assert_not_called()

    def test_clone_write_requires_own_creation(self):
        db = self.database()
        with patch.object(runner.subprocess, 'run') as call, self.assertRaises(ValueError):
            db.clone('SELECT 1')
        call.assert_not_called()

    def test_read_only_uses_fixed_host_minimal_environment(self):
        db = self.database()
        result = Mock(returncode=0, stdout='1', stderr='')
        with patch.dict('os.environ', {'PGHOST': 'production', 'PGDATABASE': 'live', 'PGSERVICE': 'remote'}), patch.object(runner.subprocess, 'run', return_value=result) as call:
            self.assertEqual(db.readonly(runner.SOURCE_DB, 'SELECT 1'), '1')
        args, kwargs = call.call_args
        self.assertIn('host=127.0.0.1 port=54322', args[0][1])
        self.assertIn('READ ONLY', kwargs['input'])
        self.assertNotIn('PGHOST', kwargs['env'])
        self.assertEqual(kwargs['env']['PGPASSFILE'], '/dev/null')
        self.assertNotIn('shell', kwargs)

    def test_existing_clone_fails_without_create(self):
        db = self.database()
        db.readonly = Mock(return_value='f')
        db.evidence.check = Mock(side_effect=AssertionError('existing clone'))
        with patch.object(db, '_execute') as call, self.assertRaises(AssertionError):
            db.create_clone()
        call.assert_not_called()
        self.assertFalse(db.created)

    def test_source_with_user_is_rejected(self):
        db = self.database()
        db.tables = Mock(return_value=['auth.users', 'public.profiles'])
        db.json = Mock(return_value={'auth.users': 1, 'public.profiles': 1})
        def check(name, passed, detail=None):
            if not passed:
                raise AssertionError(name)
        db.evidence.check = check
        with self.assertRaises(AssertionError):
            db.empty_gate(runner.SOURCE_DB)

    def test_dryrun_contains_exact_forward_body(self):
        base = runner.ROOT / 'supabase/proposed'
        forward = runner.strip_psql_guards((base / '32_exam_details_early_finish.sql').read_text())
        dry = (base / '32_exam_details_early_finish_dryrun.sql').read_text()
        copied = dry.split('-- >>> PROPOSED BODY\n', 1)[1].split('-- <<< PROPOSED BODY', 1)[0]
        self.assertEqual(runner.transaction_body(forward).strip(), copied.strip())


if __name__ == '__main__':
    unittest.main()
