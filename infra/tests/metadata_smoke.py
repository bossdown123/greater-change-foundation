"""Metadata integration fixture; only use a disposable database."""
import http.cookiejar,json,os,subprocess,tempfile,urllib.request,uuid
from pathlib import Path
if os.environ.get('GCF_TEST_DATABASE')!='1':raise SystemExit('Requires a disposable GCF_TEST_DATABASE=1')
env=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
base=os.environ.get('GCF_TEST_URL','http://127.0.0.1:4000')+'/api/admin';app=os.environ.get('GCF_TEST_APP','gcf-app-1')
jar=http.cookiejar.CookieJar();client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar));csrf=''
def call(path,method='GET',data=None,headers=None):
 req=urllib.request.Request(base+path,method=method,data=json.dumps(data).encode() if isinstance(data,dict) else data,headers={'Content-Type':'application/json','X-CSRF-Token':csrf,**(headers or {})})
 with client.open(req) as response:
  content=response.read()
  return json.loads(content) if response.headers.get_content_type()=='application/json' else content
csrf=call('/session')['csrf'];csrf=call('/session','POST',{'email':env['GCF_ADMIN_EMAIL'],'password':Path('.admin-password').read_text().strip()})['csrf']
created=[];token=uuid.uuid4().hex
try:
 with tempfile.TemporaryDirectory() as directory:
  for dated in [True,False]:
   path=Path(directory)/('dated.jpg' if dated else 'undated.jpg');path.write_bytes(Path('apps/web/public/assets/gcf-logo.jpg').read_bytes());remote='/tmp/gcf-metadata-'+token+'.jpg'
   subprocess.run(['docker','cp',str(path),app+':'+remote],check=True,stdout=subprocess.DEVNULL)
   subprocess.run(['docker','exec','-u','root',app,'chown','10001:10001',remote],check=True)
   tags=['-DateTimeOriginal=2024:02:29 09:10:11','-OffsetTimeOriginal=-05:00','-GPSLatitude=18.0179','-GPSLatitudeRef=N','-GPSLongitude=76.8099','-GPSLongitudeRef=W','-City=Kingston'] if dated else ['-all=']
   subprocess.run(['docker','exec',app,'exiftool','-overwrite_original',*tags,remote],check=True,stdout=subprocess.DEVNULL)
   subprocess.run(['docker','cp',app+':'+remote,str(path)],check=True,stdout=subprocess.DEVNULL)
   subprocess.run(['docker','exec',app,'rm',remote],check=True)
   image=path.read_bytes();boundary='gcf-'+token
   body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="metadata-{token}-{dated}.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode()+image+f'\r\n--{boundary}--\r\n'.encode())
   record=call('/media','POST',body,{'Content-Type':'multipart/form-data; boundary='+boundary});created.append(record['id'])
   assert call('/media/'+record['id']+'/file')==image
   if dated:
    meta=record['metadata'];assert meta['local_datetime']=='2024-02-29T09:10:11' and meta['utc_offset_minutes']==-300
    assert abs(meta['latitude']-18.0179)<0.0001 and abs(meta['longitude']+76.8099)<0.0001
    assert meta['places']['city']=='Kingston' and meta['width']==500
   else:assert record['metadata']['local_datetime'] is None
 assert call('/media?query='+token+'&from=2024-02-29&to=2024-02-29')['total']==1
 assert call('/media?query='+token+'&undated=1')['total']==1
 assert call('/media?query='+token+'&from=2024-02-29&to=2024-02-29&include_undated=1')['total']==2
 assert call('/media?query=Kingston')['total']>=1
 assert call('/media/metadata-summary')['first_date']=='2024-02-29'
 before=call('/audit')['total']
 call('/media?page=2');call('/media/metadata-summary');call('/media?query='+token)
 assert call('/audit')['total']==before, 'Read-only pagination must not log mutations'
 call('/media/'+created[0]+'/metadata','POST',{})
 assert any(a['operation']=='media_metadata' for a in call('/audit?resource_id='+created[0])['items'])
 print('PASS: EXIF extraction, local time and offset, GPS signs, named places, preserved originals, date/undated filters and audited refresh')
finally:
 for ident in created:call('/media/'+ident,'DELETE')
call('/session','DELETE')
