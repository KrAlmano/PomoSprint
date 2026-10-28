"""Connection-free safety checks for user-empty site bootstrap."""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parent))
import prepare_site32_clone as site


class SiteBootstrapGuards(unittest.TestCase):
    def test_default_plan_is_connection_free(self):
        with patch.object(site.runner,'LocalDatabase') as db,patch.object(site.subprocess,'run') as command,contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(site.main([]),0)
        db.assert_not_called();command.assert_not_called()

    def test_no_generic_database_argument(self):
        with patch.object(site.runner,'LocalDatabase') as db,contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):
            site.main(['--apply','--database','postgres'])
        db.assert_not_called()

    def test_plan_has_fixed_empty_source_and_target(self):
        plan=site.plan()
        self.assertEqual(plan['source'],'pomosprint_overnight_baseline')
        self.assertEqual(plan['target'],'pomosprint_site32_dus')
        self.assertFalse(plan['copy_users'])


if __name__=='__main__':unittest.main()
