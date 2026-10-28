"""Real ephemeral HTTP endpoint; verifier execution is mocked and bounded."""
import http.client
import json
import subprocess
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import e2e_host

OWNER='11111111-1111-4111-8111-111111111111'


class ReportHostTests(unittest.TestCase):
    def setUp(self):
        self.server=e2e_host.ThreadingHTTPServer(('127.0.0.1',0),e2e_host.Handler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.addCleanup(self.close_server)
        self.enterContext(patch.object(e2e_host.Handler,'log_message'))
        self.payload={'schema_version':1,'status':'PASS','owner_id':OWNER,
                      'expected':{'reports':{'daily':{'total_minutes':25}}}}
        self.code=0;self.raw=None
        self.run=self.enterContext(patch.object(e2e_host.subprocess,'run',side_effect=self.child))

    def close_server(self):
        self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)

    def child(self,args,**kwargs):
        data=self.raw if self.raw is not None else json.dumps(self.payload).encode()
        kwargs['stdout'].write(data)
        return SimpleNamespace(returncode=self.code)

    def request(self,path=None,headers=None,method='GET',host=None):
        conn=http.client.HTTPConnection('127.0.0.1',self.server.server_address[1],timeout=3)
        self.addCleanup(conn.close)
        conn.request(method,path or '/verify-reports?owner='+OWNER,headers=headers or {} if host is None else {'Host':host,**(headers or {})})
        response=conn.getresponse();return response.status,dict(response.getheaders()),response.read().decode()

    def test_valid_native_get_returns_json_and_no_store(self):
        status,headers,body=self.request()
        self.assertEqual(status,200);self.assertEqual(json.loads(body),self.payload)
        self.assertEqual(headers['Cache-Control'],'no-store')
        args,kwargs=self.run.call_args
        self.assertEqual(args[0][-2:],['--owner',OWNER])
        self.assertTrue(args[0][1].endswith('/tool/local_supabase/e2e/verify_reports_and_exams.py'))
        self.assertNotIn('shell',kwargs);self.assertEqual(kwargs['timeout'],25)
        self.assertEqual(kwargs['stdin'],subprocess.DEVNULL);self.assertEqual(kwargs['stderr'],subprocess.DEVNULL)

    def test_verification_failure_is_data_not_transport_success(self):
        self.payload['status']='FAIL';self.code=1
        status,_,body=self.request();self.assertEqual(status,200)
        self.assertEqual(json.loads(body)['status'],'FAIL')

    def test_only_public_error_codes_are_returned(self):
        self.payload={'schema_version':1,'status':'ERROR','error':'owner_is_not_named_local_qa','extra':'sensitive'};self.code=2
        status,_,body=self.request();self.assertEqual(status,422)
        self.assertNotIn('sensitive',body);self.assertNotIn('extra',json.loads(body))
        self.payload['error']='email@example.com'
        status,_,body=self.request();self.assertEqual(status,503);self.assertNotIn('email@example.com',body)

    def test_invalid_owner_or_duplicate_or_extra_queries_never_execute(self):
        for query in ['', 'owner=', 'owner=../x', 'owner='+OWNER+'&owner='+OWNER,
                      'owner='+OWNER+'&path=/etc/passwd', 'owner='+OWNER+'%00',
                      'owner='+OWNER+'&as_of=2020-01-01']:
            with self.subTest(query=query):self.assertEqual(self.request('/verify-reports?'+query)[0],400)
        self.run.assert_not_called()

    def test_browser_origin_and_fetch_metadata_are_rejected_before_child(self):
        for headers in [{'Origin':'null'},{'Origin':'http://127.0.0.1'},
                        {'Sec-Fetch-Site':'same-origin'},{'Sec-Fetch-Mode':'navigate'}]:
            with self.subTest(headers=headers):self.assertEqual(self.request(headers=headers)[0],403)
        self.run.assert_not_called()

    def test_rebinding_host_is_rejected_before_child(self):
        self.assertEqual(self.request(host='example.invalid:54399')[0],403)
        self.run.assert_not_called()

    def test_post_cannot_invoke_verifier(self):
        self.assertEqual(self.request(method='POST')[0],404);self.run.assert_not_called()

    def test_timeout_is_public_and_does_not_disclose_command(self):
        self.run.side_effect=subprocess.TimeoutExpired(['secret-sentinel'],25)
        status,_,body=self.request();self.assertEqual(status,503)
        self.assertEqual(json.loads(body)['error'],'verification_timeout');self.assertNotIn('secret-sentinel',body)

    def test_child_output_is_bounded(self):
        self.raw=b'x'*(e2e_host.VERIFY_REPORTS_LIMIT+1)
        status,_,body=self.request();self.assertEqual(status,503)
        self.assertLess(len(body),200)

    def test_invalid_or_wrong_owner_child_response_is_rejected(self):
        for raw in [b'not-json',b'[]',b'{}',json.dumps({**self.payload,'owner_id':'different'}).encode(),
                    json.dumps({**self.payload,'status':{}}).encode(),
                    json.dumps({**self.payload,'expected':[]}).encode()]:
            with self.subTest(raw=raw):
                self.raw=raw;self.assertEqual(self.request()[0],503)

    def test_mismatched_exit_code_and_status_is_rejected(self):
        self.code=1;self.assertEqual(self.request()[0],503)


if __name__=='__main__':unittest.main()
