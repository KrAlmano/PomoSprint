"""ADB UI helpers for normal-main, obfuscated/R8 release smoke on local QA."""
from pathlib import Path
import subprocess, xml.etree.ElementTree as E, re, time
ADB='/Users/almano/Library/Android/sdk/platform-tools/adb'
PKG='com.pomosprint.app'
SHOT=Path('analiz/ekranlar/20261007_release_qa/android')
def adb(*args):
 r=subprocess.run([ADB,'-s','emulator-5554',*args],capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode(errors='replace'))
 return r.stdout

def nodes():
 adb('shell','uiautomator','dump','/sdcard/pomosprint-release.xml')
 raw=adb('shell','cat','/sdcard/pomosprint-release.xml')
 return list(E.fromstring(raw).iter('node'))

def label(n):return n.get('content-desc') or n.get('text') or ''
def tap_node(n):
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

def tap(s,contains=False):
 choices=[n for n in nodes() if (s in label(n) if contains else label(n)==s)]
 assert choices, f'UI label not found: {s}'
 tap_node(choices[0])

def edit(index,text):
 fields=[n for n in nodes() if n.get('class')=='android.widget.EditText']
 tap_node(fields[index]);adb('shell','input','text',text)

def show():
 for n in nodes():
  if label(n):print(label(n),n.get('bounds'))

def shot(name):
 SHOT.mkdir(parents=True,exist_ok=True)
 (SHOT/name).write_bytes(adb('exec-out','screencap','-p'))
