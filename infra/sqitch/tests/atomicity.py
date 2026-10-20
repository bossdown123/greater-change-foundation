"""Run only against a disposable local/CI database."""
import json
import os
import subprocess
import tempfile
import urllib.request
from pathlib import Path

if os.environ.get('GCF_TEST_DATABASE') != '1':
    raise SystemExit('This check requires GCF_TEST_DATABASE=1 and a disposable database')

with tempfile.TemporaryDirectory() as directory:
    script = Path(directory) / 'failure.sql'
    script.write_text('BEGIN; CREATE TABLE gcf_atomicity_probe(id INTEGER); SELECT * FROM gcf_missing_probe; COMMIT;')
    result = subprocess.run(['/usr/local/bin/turso-sqlite', '-batch', '/state/gcf.db', f'.read {script}'], capture_output=True)
    assert result.returncode != 0, 'A failing migration must return a failure'

body = {'requests': [{'type': 'execute', 'stmt': {'sql': "SELECT count(*) FROM sqlite_master WHERE name='gcf_atomicity_probe'"}}, {'type': 'close'}]}
url = os.environ['TURSO_DATABASE_URL'].rstrip('/') + '/v2/pipeline'
request = urllib.request.Request(url, data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=10) as response:
    payload = json.load(response)
assert payload['results'][0]['response']['result']['rows'][0][0]['value'] == '0', 'Failed migration leaked a partial table'
print('Failed migration rolled back without committing partial schema')
