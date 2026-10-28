"""15 bounded local HTTP/Range guards; no browser or product/API action."""
import hashlib
import http.client
import json
from pathlib import Path
import threading
import unittest

from tool.site_qa import server as qa


class PreviewGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        #8798 belongs to the existing QA process and is deliberately untouched.
        cls.server=qa.create_server(8799)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()
        cls.video=qa.ROOT/'videos/20261028/timer-en.mp4'
        cls.video_bytes=cls.video.read_bytes()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join(2)

    def request(self,path,method='GET',headers=None,body=None):
        c=http.client.HTTPConnection('127.0.0.1',8799,timeout=5)
        try:
            c.request(method,path,body=body,headers={'Host':'127.0.0.1:8799','Connection':'close',**(headers or {})})
            r=c.getresponse();return r.status,dict(r.getheaders()),r.read()
        finally:c.close()

    def test01_local_qa_and_strict_headers(self):
        status,headers,body=self.request('/__qa')
        self.assertEqual(status,200);self.assertIn(b'qa-run',body)
        csp=headers['Content-Security-Policy']
        self.assertIn("connect-src 'self'",csp);self.assertIn("form-action 'none'",csp)
        self.assertNotIn('unsafe-inline',csp);self.assertEqual(headers['Cache-Control'],'no-store')

    def test02_bounded_actual_page_inventory(self):
        status,_,body=self.request('/__qa/pages.json');rows=json.loads(body)
        self.assertEqual(status,200);self.assertTrue(1<=len(rows)<=60)
        self.assertTrue(all(r['url'].startswith('/') and '://' not in r['url'] for r in rows))
        self.assertTrue({'tr','en'}<={r['locale'] for r in rows})

    def test03_probe_is_response_only(self):
        p=qa.ROOT/'index.html';before=hashlib.sha256(p.read_bytes()).hexdigest()
        status,_,body=self.request('/')
        self.assertEqual(status,200);self.assertIn(b'<script src="/__qa/probe.js"></script>',body)
        self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),before)

    def test04_config_is_always_null(self):
        for path in ['/js/config.js','/JS/CONFIG.JS?anything=1','/js%2fconfig.js']:
            with self.subTest(path=path):
                status,_,body=self.request(path);self.assertEqual(status,200)
                self.assertEqual(body,b'window.PomoSupabase=null;\n')

    def test05_private_and_api_routes_denied(self):
        for path in ['/.env','/_partials/head.html','/node_modules/x.js','/auth/v1/user','/rest/v1/profiles','/functions/v1/send','/api/example','/storage/file','/__qa/unknown']:
            with self.subTest(path=path):self.assertEqual(self.request(path)[0],404)

    def test06_traversal_and_noncanonical_target_denied(self):
        for path in ['/../AGENTS.md','/%2e%2e/AGENTS.md','/%252e%252e/AGENTS.md','/js/%00x.js','/js/%5cx.js','http://invalid.test/index.html','/index.html#frag','/'+('x'*2050)]:
            with self.subTest(path=path):self.assertIn(self.request(path)[0],(400,404,414))

    def test07_foreign_and_duplicate_host_denied(self):
        self.assertEqual(self.request('/__qa',headers={'Host':'invalid.test'})[0],403)
        c=http.client.HTTPConnection('127.0.0.1',8799,timeout=5)
        try:
            c.putrequest('GET','/__qa',skip_host=True);c.putheader('Host','127.0.0.1:8799');c.putheader('Host','invalid.test');c.endheaders()
            r=c.getresponse();self.assertEqual(r.status,403);r.read()
        finally:c.close()

    def test08_origin_and_cross_site_denied(self):
        for h in [{'Origin':'https://invalid.test'},{'Origin':'null'},{'Origin':'http://127.0.0.1:8798'},{'Sec-Fetch-Site':'cross-site'}]:
            with self.subTest(h=h):self.assertEqual(self.request('/__qa',headers=h)[0],403)

    def test09_only_read_methods(self):
        for method in ['POST','PUT','PATCH','DELETE','OPTIONS']:
            with self.subTest(method=method):
                status,headers,body=self.request('/__qa',method=method,body=b'x')
                self.assertEqual(status,405);self.assertEqual(headers['Allow'],'GET, HEAD');self.assertEqual(body,b'')

    def test10_only_fixed_ports_or_ephemeral(self):
        for port in [80,8080,9000,-1,True]:
            with self.subTest(port=port),self.assertRaises(ValueError):qa.create_server(port)
        server=qa.create_server(0)
        try:self.assertEqual(server.server_address[0],'127.0.0.1');self.assertGreater(server.server_port,0)
        finally:server.server_close()

    def test11_full_video_is_byte_identical(self):
        status,headers,body=self.request('/videos/20261028/timer-en.mp4')
        self.assertEqual(status,200);self.assertEqual(body,self.video_bytes)
        self.assertEqual(int(headers['Content-Length']),len(body));self.assertEqual(headers['Accept-Ranges'],'bytes')

    def test12_ranges_are_exact_and_bounded(self):
        n=len(self.video_bytes)
        for value,expected in [('bytes=0-31',self.video_bytes[:32]),('bytes=-17',self.video_bytes[-17:]),('bytes=19-',self.video_bytes[19:]),(f'bytes={n-4}-{n+100}',self.video_bytes[-4:])]:
            with self.subTest(value=value):
                status,headers,body=self.request('/videos/20261028/timer-en.mp4',headers={'Range':value})
                self.assertEqual(status,206);self.assertEqual(body,expected);self.assertEqual(int(headers['Content-Length']),len(body))

    def test13_unsatisfiable_range_is_empty416(self):
        status,headers,body=self.request('/videos/20261028/timer-en.mp4',headers={'Range':'bytes=999999999-'})
        self.assertEqual(status,416);self.assertEqual(body,b'');self.assertEqual(headers['Content-Range'],f'bytes */{len(self.video_bytes)}')

    def test14_head_ignores_range_and_has_no_body(self):
        status,headers,body=self.request('/videos/20261028/timer-en.mp4',method='HEAD',headers={'Range':'bytes=0-4'})
        self.assertEqual(status,200);self.assertEqual(body,b'');self.assertEqual(int(headers['Content-Length']),len(self.video_bytes));self.assertNotIn('Content-Range',headers)

    def test15_if_range_and_malformed_range_fallback(self):
        _,headers,_=self.request('/videos/20261028/timer-en.mp4',method='HEAD');etag=headers['ETag']
        status,_,body=self.request('/videos/20261028/timer-en.mp4',headers={'Range':'bytes=0-4','If-Range':etag})
        self.assertEqual(status,206);self.assertEqual(body,self.video_bytes[:5])
        for h in [{'Range':'bytes=0-4','If-Range':'"old"'},{'Range':'bytes=0-1,3-4'},{'Range':'bytes=6-4'},{'Range':'bytes=99999999999999999999999-'}]:
            with self.subTest(h=h):
                status,_,body=self.request('/videos/20261028/timer-en.mp4',headers=h)
                self.assertEqual(status,200);self.assertEqual(body,self.video_bytes)


if __name__=='__main__':unittest.main()
