#!/usr/bin/env python3
"""Yalnızca yeni, silinen yerel hesaplar: arkadaş işlemleri, engel ve RLS."""
import datetime,json,os,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
os.environ['LOCAL_TEST_PASSWORD']='SimE2e-Yerel2026'
import local_api as api
results=[];users=[];run=datetime.datetime.now().strftime('%m%d%H%M%S')
def check(name,ok):
 results.append({'name':name,'passed':bool(ok)});print(('PASS ' if ok else 'FAIL ')+name,flush=True);assert ok,name
def rpc(name,a,args=None):return api.rpc(name,args,a['access_token'])
def ids(rows):return {r['id'] for r in rows}
def forbidden(name,method,path,body,token):
 try:api.request(method,path,body,token);check(name,False)
 except api.ApiError as e:check(name,e.status in (401,403))
try:
 for tag in ['a','b','c']:
  a=api.sign_up(f'qa-social-{tag}-{run}@pomosprint.local','QA Social '+tag.upper());users.append(a)
  uid=a['user']['id'];a['id']=uid
  rpc('setup_onboarding_categories',a,{'p_categories':[{'name':'Matematik','color_hex':'#EF4444','icon_name':'book'}]})
  api.request('PATCH',f'/rest/v1/profiles?id=eq.{uid}',{'birth_year':2000,'onboarding_completed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'show_in_social_feed':True},a['access_token'])
  a['code']=api.select('profiles','select=friend_code',a['access_token'])[0]['friend_code']
 A,B,C=users
 check('Başkasının profili RLS ile görünmez',api.select('profiles',f'select=id&id=eq.{A["id"]}',B['access_token'])==[])
 check('Başkasının kategorileri RLS ile görünmez',api.select('categories',f'select=id&user_id=eq.{A["id"]}',B['access_token'])==[])
 for col in ['coins','lifetime_points','current_streak']:
  forbidden('Doğrudan '+col+' değiştirilemez','PATCH',f'/rest/v1/profiles?id=eq.{A["id"]}',{col:999},A['access_token'])
 check('Kendi arkadaş kodu reddedilir',rpc('add_friend_by_code',A,{'p_code':A['code']})['code']=='self_add')
 check('Geçersiz arkadaş kodu reddedilir',rpc('add_friend_by_code',A,{'p_code':'ZZZZZZ'})['success'] is False)
 check('Arkadaş isteği gönderilir',rpc('add_friend_by_code',A,{'p_code':B['code']})['success'] is True)
 check('Giden istek yalnızca gönderende görünür',ids(rpc('get_outgoing_friend_requests',A))=={B['id']})
 check('Gelen istek yalnızca hedefte görünür',ids(rpc('get_incoming_friend_requests',B))=={A['id']} and rpc('get_incoming_friend_requests',C)==[])
 check('Bekleyen istek arkadaş değildir',rpc('get_my_friends',A)==[])
 check('Aynı istek ikinci kez kabul edilmez',rpc('add_friend_by_code',A,{'p_code':B['code']})['success'] is False)
 check('Üçüncü kişi isteği kabul edemez',rpc('respond_friend_request',C,{'p_from_user_id':A['id'],'p_accept':True})['success'] is False)
 check('Giden istek iptal edilir',rpc('cancel_friend_request',A,{'p_to_user_id':B['id']})['success'] is True and rpc('get_incoming_friend_requests',B)==[])
 rpc('add_friend_by_code',A,{'p_code':B['code']})
 check('Alıcı isteği reddedebilir',rpc('respond_friend_request',B,{'p_from_user_id':A['id'],'p_accept':False})['success'] is True and rpc('get_incoming_friend_requests',B)==[])
 check('Reddedilen istek bekleme süresinde tekrar gönderilemez',rpc('add_friend_by_code',A,{'p_code':B['code']})['success'] is False)
 check('Reddeden taraf ters yönde istek gönderebilir',rpc('add_friend_by_code',B,{'p_code':A['code']})['success'] is True)
 check('Alıcı isteği kabul eder',rpc('respond_friend_request',A,{'p_from_user_id':B['id'],'p_accept':True})['success'] is True)
 check('Arkadaşlık iki yönlüdür',ids(rpc('get_my_friends',A))=={B['id']} and ids(rpc('get_my_friends',B))=={A['id']})
 rpc('start_study_session',A,{'p_duration_minutes':25,'p_category_name':'Matematik'})
 check('Odak arkadaşta görünür, üçüncü kişide görünmez',ids(rpc('get_live_friends',B))=={A['id']} and rpc('get_live_friends',C)==[])
 check('Engel arkadaşlığı iki yönlü kaldırır',rpc('block_user',B,{'p_user_id':A['id']})['success'] is True and rpc('get_my_friends',A)==[] and rpc('get_my_friends',B)==[])
 check('Engelleyen canlı odakta diğerini görmez',rpc('get_live_friends',B)==[])
 check('Engellenen yeniden istek gönderemez',rpc('add_friend_by_code',A,{'p_code':B['code']})['success'] is False)
 check('Engel kaldırılır',rpc('unblock_user',B,{'p_user_id':A['id']})['success'] is True)
 check('Engeli kaldırmak arkadaşlığı otomatik geri açmaz',rpc('get_my_friends',A)==[] and rpc('get_my_friends',B)==[])
 rpc('cancel_study_session',A)
 rpc('add_friend_by_code',A,{'p_code':B['code']});rpc('respond_friend_request',B,{'p_from_user_id':A['id'],'p_accept':True})
 check('Arkadaş silme iki yönlüdür',rpc('remove_friend',A,{'p_friend_id':B['id']})['success'] is True and rpc('get_my_friends',A)==[] and rpc('get_my_friends',B)==[])
finally:
 for a in users:rpc('delete_own_account',a)
 p=Path('build/e2e_social_safety.json');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
