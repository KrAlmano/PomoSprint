"""Offline rejection checks for the separate32 reference."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parent))
import parity_check_exam32 as parity


class ParityGuards(unittest.TestCase):
    def setUp(self):
        self.reference=json.loads(parity.REFERENCE.read_text())

    def tearDown(self):
        parity.DATABASE=parity.PROFILE_DATABASES['review']

    def test_site_uses_same_reference_and_fixed_database(self):
        with patch.object(parity,'observe',return_value=self.reference['expected']):
            self.assertEqual(parity.main(['--profile','site']),0)
        self.assertEqual(parity.DATABASE,'pomosprint_site32_dus')


    def test_sources_match(self):
        self.assertEqual(parity.verify_sources(self.reference),[])

    def test_changed_source_rejected(self):
        r=copy.deepcopy(self.reference);key=next(iter(r['sources_sha256']));r['sources_sha256'][key]='0'*64
        self.assertEqual(parity.verify_sources(r),[key])

    def test_no_database_override_or_capture(self):
        for args in [['postgres'],['--database','postgres'],['--capture'],['--with-marathon-anchor']]:
            with self.subTest(args=args),patch.object(parity,'sql') as sql,self.assertRaises(ValueError):parity.main(args)
            sql.assert_not_called()

    def test31_is_an_actual_mismatch(self):
        observed=copy.deepcopy(self.reference['expected']);observed['migrations'].append('20261028050000|marathon_completion_anchor')
        self.assertEqual(parity.differences(self.reference['expected'],observed),['migrations'])

    def test_policy_or_catalog_mismatch_rejected(self):
        for key,value in [('policy',[True,'full']),('catalog',{})]:
            observed=copy.deepcopy(self.reference['expected']);observed[key]=value
            self.assertEqual(parity.differences(self.reference['expected'],observed),[key])


if __name__=='__main__':unittest.main()
