"""Launch the publication test with credentials from local private files, never stdout."""
from pathlib import Path
import json,os,subprocess,tempfile
if os.environ.get('GCF_TEST_DATABASE')!='1':raise SystemExit('Requires GCF_TEST_DATABASE=1 and a disposable database')
values=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
with tempfile.NamedTemporaryFile(mode='w') as auth:
 json.dump({'email':values['GCF_ADMIN_EMAIL'],'password':Path('.admin-password').read_text().strip()},auth);auth.flush()
 subprocess.run(['node','apps/web/publication-smoke.mjs'],env={**os.environ,'GCF_TEST_AUTH_FILE':auth.name,'GCF_TEST_URL':os.environ.get('GCF_TEST_URL','http://127.0.0.1:4000')},check=True)
