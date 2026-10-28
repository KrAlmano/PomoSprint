"""Offline checks for fixed, explicitly selected final32 parity references."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'exam32_parity_under_test', Path(__file__).resolve().parents[1] / 'parity_check_exam32.py')
parity = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(parity)


class Exam32ParityTests(unittest.TestCase):
    def test_kpss_reference_is_explicit_and_separate_from_historical_dus(self):
        self.assertEqual(parity.PROFILE_DATABASES['kpss'], 'pomosprint_review32_kpss')
        self.assertEqual(parity.PROFILE_DATABASES['review'], 'pomosprint_review32_dus')
        self.assertEqual(parity.PROFILE_DATABASES['site'], 'pomosprint_site32_dus')
        self.assertNotEqual(parity.PROFILE_REFERENCES['kpss'][0], parity.PROFILE_REFERENCES['review'][0])
        with patch.object(parity, 'observe') as observe, self.assertRaises(ValueError):
            parity.main(['--profile', 'postgres'])
        observe.assert_not_called()

    def test_current_kpss_source_hashes_match_and_tampering_is_rejected(self):
        reference = json.loads(parity.PROFILE_REFERENCES['kpss'][0].read_text())
        self.assertEqual(parity.verify_sources(reference), [])
        changed = copy.deepcopy(reference)
        key = 'supabase/proposed/exam_catalog_32.json'
        changed['sources_sha256'][key] = '0' * 64
        self.assertEqual(parity.verify_sources(changed), [key])

    def test_wrong_reference_identity_cannot_query_database(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'reference.json'
            file.write_text(json.dumps({'reference_id': 'wrong', 'database': 'postgres'}))
            with patch.dict(parity.PROFILE_REFERENCES, {'kpss': (file, 'expected', 'pomosprint_review32_kpss')}), \
                 patch.object(parity, 'observe') as observe, self.assertRaises(ValueError):
                parity.main(['--profile', 'kpss'])
            observe.assert_not_called()

    def test_changed_observed_catalog_fails_instead_of_recapturing(self):
        reference = json.loads(parity.PROFILE_REFERENCES['kpss'][0].read_text())
        changed = copy.deepcopy(reference['expected'])
        changed['catalog']['exam_catalog'] = '20|changed'
        with patch.object(parity, 'observe', return_value=changed), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(parity.main(['--profile', 'kpss']), 1)


if __name__ == '__main__':
    unittest.main()
