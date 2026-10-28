"""Offline stack guards; uses only an ephemeral loopback HTTP server."""
import http.client
import json
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import isolated32_stack as stack


class StackGuards(unittest.TestCase):
    def tearDown(self):
        stack.select_profile('review')

    def test_only_two_fixed_profiles(self):
        stack.select_profile('site')
        self.assertEqual((stack.CLONE,stack.API_PORT,stack.REST_PORT,stack.AUTH_PORT),('pomosprint_site32_dus',54361,54362,54363))
        for profile in ['production','postgres','http://remote','review;DROP']:
            with self.subTest(profile=profile),self.assertRaises(stack.GuardError):
                stack.select_profile(profile)

    def test_query_fixed_db_readonly_and_no_inherited_pg(self):
        with patch.object(stack, 'command', return_value=Mock(stdout='ok')) as call:
            self.assertEqual(stack.query('SELECT 1'), 'ok')
        args, kwargs = call.call_args
        self.assertIn('dbname=pomosprint_review32_dus', args[0][1])
        self.assertIn('host=127.0.0.1 port=54322', args[0][1])
        self.assertTrue(kwargs['body'].startswith('BEGIN READ ONLY;'))
        self.assertEqual(set(kwargs['env']), {'PATH', 'PGPASSFILE'})

    def test_remote_docker_context_refused(self):
        with patch.object(stack, 'command', side_effect=[Mock(stdout='default\n'), Mock(stdout='tcp://remote:2375\n')]):
            with self.assertRaises(stack.GuardError):
                stack.docker_context()

    def test_fixed_final_facts_and_no31(self):
        good = {'database':stack.CLONE,'migrations':['20261028010000','20261028020000','20261028030000','20261028040000','20261028060000'],'policy':[True,'proportional'],'welcome_disabled':True,'unknown_owners':0}
        with patch.object(stack,'query',return_value=json.dumps(good)):
            self.assertEqual(stack.facts(),good)
        for name,value in [('database','postgres'),('policy',[True,'full']),('welcome_disabled',False),('unknown_owners',1),('migrations',good['migrations']+['20261028050000'])]:
            with self.subTest(name=name), patch.object(stack,'query',return_value=json.dumps({**good,name:value})), self.assertRaises(stack.GuardError):
                stack.facts()

    def test_stop_has_no_database_deletion(self):
        source = Path(stack.__file__).read_text()
        self.assertNotIn('DROP DATABASE', source)
        self.assertNotIn('pg_terminate_backend', source)
        self.assertIn('--pull=never', source)

    def test_path_canonicalization(self):
        for path in ['//evil/x','http://evil/x','/rest/v1/../auth','/rest/v1/%252e%252e/x','/rest/v1/%5cfoo','/rest/v1//foo','/rest/v1/a#fragment']:
            with self.subTest(path=path), self.assertRaises(stack.GuardError):
                stack.safe_path(path)


class GatewayGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=stack.ThreadingHTTPServer(('127.0.0.1',0),stack.Gateway)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join(2)

    def request(self,path,headers=None,method='GET',body=None):
        c=http.client.HTTPConnection('127.0.0.1',self.server.server_address[1],timeout=3)
        try:
            c.request(method,path,headers={'Host':f'127.0.0.1:{stack.API_PORT}','Connection':'close',**(headers or {})},body=body)
            r=c.getresponse();return r.status,json.loads(r.read())
        finally:c.close()

    def test_health_reports_exact_isolated_db(self):
        status,body=self.request('/health');self.assertEqual(status,200);self.assertEqual(body['database'],stack.CLONE)

    def test_foreign_host_origin_rejected(self):
        for h in [{'Host':'evil.test'},{'Origin':'https://evil.test'},{'Origin':'null'},{'Sec-Fetch-Site':'cross-site'}]:
            with self.subTest(h=h):self.assertEqual(self.request('/health',h)[0],403)

    def test_no_arbitrary_sql_or_owner_endpoint(self):
        for path in ['/psql','/qa/v1/verify?owner=someone','/unknown']:
            self.assertEqual(self.request(path)[0],404)

    def test_body_limit_precedes_upstream(self):
        with patch.object(stack,'read_url') as call:
            self.assertEqual(self.request('/auth/v1/signup',{'Content-Length':str(stack.MAX_BODY+1)},'POST')[0],413)
        call.assert_not_called()


if __name__=='__main__':unittest.main()
