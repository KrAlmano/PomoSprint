"""Redacted secret check; print filenames/rules, never matched values.
Public anon JWTs and Supabase CLI local demo JWTs are not private credentials.
Includes selected QA logs even though *.log is ignored by Git.
"""
from pathlib import Path
import subprocess,re,json,base64
names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z']).decode().split('\0')
paths={Path(n) for n in names if n}
paths.update(Path('analiz/qa_evidence_20261007').rglob('*.log'))
findings=[];count=0
patterns={
 'resend_private_key':r'(?<![A-Za-z0-9_])re_[A-Za-z0-9]{30,}',
 'github_private_token':r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})',
 'stripe_secret_key':r'\bsk_(?:live|test)_[A-Za-z0-9]{20,}',
 'openai_private_key':r'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{45,}',
 'embedded_private_key':r'-----BEGIN (?:EC |RSA )?PRIVATE KEY-----\s+[A-Za-z0-9+/=]{64,}',
}
for p in sorted(paths):
 if not p.is_file() or p.stat().st_size>2_000_000:continue
 try:s=p.read_text()
 except (UnicodeError,OSError):continue
 count+=1
 for rule,pattern in patterns.items():
  if re.search(pattern,s):findings.append({'path':str(p),'rule':rule})
 for m in re.finditer(r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',s):
  try:
   body=m[0].split('.')[1];payload=json.loads(base64.urlsafe_b64decode(body+'='*(-len(body)%4)))
  except Exception:continue
  if payload.get('iss')=='supabase-demo' or payload.get('role')=='anon':continue
  if payload.get('role') in ('service_role','authenticated'):
   findings.append({'path':str(p),'rule':'nonpublic_supabase_jwt'})
   break
result={'date':'2026-10-07','text_files_scanned':count,'findings':findings,'values_logged':False,'scope':'tracked/nonignored text plus QA logs <=2MB; anon/local demo JWTs distinguished'}
Path('analiz/qa_evidence_20261007/repo_secret_scan.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
raise SystemExit(bool(findings))
