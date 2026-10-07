import datetime, json, os, pathlib, plistlib, re, subprocess, sys, time, xml.etree.ElementTree as ET
root=pathlib.Path.cwd()
platform=sys.argv[1]
base=root/'analiz/qa_evidence_20261007/mobile'
device='BEA55019-D5C3-420F-90F2-0B0CBD5690CF' if platform=='ios' else 'emulator-5554'
account=(base/f'{platform}_process_account.txt').read_text().split()
email, uid=account
pub=(root/'tool/local_supabase/e2e/sim/run_sim_e2e.sh').read_text()
anon=re.search(r'ANON_KEY="([^"]+)"',pub)[1]
env=os.environ.copy(); env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'; env['GRADLE_OPTS']='-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false'
adb='/Users/almano/Library/Android/sdk/platform-tools/adb'
def run(cmd):
    return subprocess.run(cmd,check=True,env=env,capture_output=True,text=True).stdout.strip()
flags=['--dart-define=SUPABASE_URL=http://'+('127.0.0.1' if platform=='ios' else '10.0.2.2')+':54321','--dart-define=SUPABASE_ANON_KEY='+anon,'--dart-define=LOCAL_QA_PROCESS_SECONDS=30','--dart-define=QUICK_TIMER=true','--dart-define=QUICK_TIMER_SAVE=true','--dart-define=LOCAL_QA_EMAIL='+email,'--dart-define=LOCAL_QA_PASSWORD=SimE2e-Yerel2026','--dart-define=LOCAL_QA_PROCESS_RUN=1007os'+platform+uid[:8]]
cmd=['flutter','build','ios','--debug','--simulator'] if platform=='ios' else ['flutter','build','apk','--debug','--target-platform=android-arm64']
with (base/f'{platform}_process_build.log').open('w') as log:
    subprocess.run(cmd+['-t','lib/dev/process_death_qa.dart']+flags,check=True,env=env,stdout=log,stderr=subprocess.STDOUT)
if platform=='ios':
    run(['xcrun','simctl','install',device,'build/ios/iphonesimulator/Runner.app'])
else:
    run([adb,'-s',device,'install','-r','build/app/outputs/flutter-apk/app-debug.apk'])
procs=[]
def stop():
    cmd=['xcrun','simctl','terminate',device,'com.pomosprint.app'] if platform=='ios' else [adb,'-s',device,'shell','am','force-stop','com.pomosprint.app']
    subprocess.run(cmd,env=env,capture_output=True)
def launch(index):
    path=base/f'{platform}_process_launch{index}.log'
    log=path.open('w')
    if platform=='ios':
        p=subprocess.Popen(['xcrun','simctl','launch','--console',device,'com.pomosprint.app'],env=env,stdout=log,stderr=subprocess.STDOUT)
    else:
        run([adb,'-s',device,'logcat','-c'])
        p=subprocess.Popen([adb,'-s',device,'logcat','-v','brief','flutter:I','*:S'],env=env,stdout=log,stderr=subprocess.STDOUT)
        run([adb,'-s',device,'shell','am','start','-n','com.pomosprint.app/.MainActivity'])
    procs.append((p,log))
    return path
stop(); first=launch(1)
end=time.monotonic()+45; seeded=None
if platform=='ios':
    data=run(['xcrun','simctl','get_app_container',device,'com.pomosprint.app','data'])
    prefs=pathlib.Path(data)/'Library/Preferences/com.pomosprint.app.plist'
while time.monotonic()<end:
    try:
        if platform=='ios':
            values=plistlib.loads(prefs.read_bytes())
        else:
            xml=run([adb,'-s',device,'shell','run-as','com.pomosprint.app','cat','shared_prefs/FlutterSharedPreferences.xml'])
            values={n.attrib['name']:(n.text if n.tag=='string' else n.attrib.get('value')) for n in ET.fromstring(xml)}
        active=json.loads(values.get('flutter.active_session_uid_'+uid,'null'))
        if active and values.get('flutter.qa_process_seed_1007os'+platform+uid[:8]) in (True, 'true'):
            seeded=active['client_uuid']; assert time.time()<datetime.datetime.fromisoformat(active['ends_at'].replace('Z','+00:00')).timestamp(), 'Already elapsed before termination'; stop(); (base/f'{platform}_process_checkpoint.json').write_text(json.dumps({'client_uuid':seeded,'active':active,'terminated_at':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n'); break
    except (OSError,ValueError,ET.ParseError,subprocess.CalledProcessError):
        pass
    time.sleep(.1)
assert seeded,'Seeding not observed; do not claim process test passed'
time.sleep(max(1,datetime.datetime.fromisoformat(active['ends_at'].replace('Z','+00:00')).timestamp()-time.time()+1))
second=launch(2)
def stats():
    sql=f"select json_build_object('sessions',(select count(*) from study_sessions where user_id='{uid}'),'minutes',(select coalesce(sum(duration_minutes),0) from study_sessions where user_id='{uid}'),'client_uuid',(select client_uuid::text from study_sessions where user_id='{uid}' limit 1),'points',lifetime_points,'coins',coins)::text from profiles where id='{uid}';"
    return json.loads(run(['docker','exec','supabase_db_pomosprint-local','psql','-U','postgres','-d','postgres','-At','-c',sql]))
end=time.monotonic()+45
while time.monotonic()<end:
    row=stats()
    if row['sessions']==1: break
    time.sleep(.5)
assert row=={'sessions':1,'minutes':50,'points':12,'coins':20,'client_uuid':seeded},row
# Native CLI does not receive Dart VM debugPrint on iOS; verify persistence and DB.
time.sleep(2); stop(); third=launch(3); time.sleep(8)
assert stats()==row,'Second relaunch duplicated session'
shot=pathlib.Path('/tmp/pomosprint-20261007')/platform/'process.png'; shot.parent.mkdir(parents=True,exist_ok=True)
if platform=='ios': run(['xcrun','simctl','io',device,'screenshot',str(shot)])
else:
    with shot.open('wb') as f: subprocess.run([adb,'-s',device,'exec-out','screencap','-p'],check=True,stdout=f)
stop()
for p,log in procs:
    if p.poll() is None: p.terminate()
    log.close()
result={'platform':platform,'date':'2026-10-07','real_os_process_termination':True,'client_uuid':seeded,'after_resume':row,'after_second_resume':stats(),'passed':True,'screenshot':str(shot)}
(base/f'{platform}_process_result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
