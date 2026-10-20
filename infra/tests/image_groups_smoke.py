"""Disposable-database HTTP check using private local credentials."""
from pathlib import Path
import json,os,subprocess,tempfile
if os.environ.get('GCF_TEST_DATABASE')!='1':raise SystemExit('Requires GCF_TEST_DATABASE=1')
values=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
with tempfile.NamedTemporaryFile(mode='w') as auth:
 json.dump({'email':values['GCF_ADMIN_EMAIL'],'password':Path('.admin-password').read_text().strip()},auth);auth.flush()
 # A separate client address keeps this independent suite within the real sign-in
 # rate limit after the account/collaboration suites. Production limits stay intact.
 network=os.environ.get('GCF_SMOKE_NETWORK')
 if network:
  subprocess.run(['docker','run','--rm','--network',network,'-v',str(Path.cwd()/'apps/web')+':/web:ro','-v',auth.name+':/auth.json:ro','-w','/web','-e','GCF_TEST_AUTH_FILE=/auth.json','-e','GCF_TEST_DATABASE=1','-e','GCF_TEST_URL=http://app:4000','node:22-bookworm-slim','node','image-groups-smoke.mjs'],check=True)
 else:
  subprocess.run(['node','apps/web/image-groups-smoke.mjs'],env={**os.environ,'GCF_TEST_AUTH_FILE':auth.name,'GCF_TEST_URL':os.environ.get('GCF_TEST_URL','http://127.0.0.1:4000')},check=True)
