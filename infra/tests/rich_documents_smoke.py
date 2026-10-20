"""Rich documents and immediate shared drafts against a disposable database only."""
import http.cookiejar,json,os,secrets,urllib.request,urllib.error
from pathlib import Path
if os.environ.get('GCF_TEST_DATABASE')!='1':raise SystemExit('Requires GCF_TEST_DATABASE=1 and a disposable database')
base=os.environ.get('GCF_TEST_URL','http://127.0.0.1:4000')+'/api/admin';values=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));csrf=''
def call(path,method='GET',data=None,status=200):
 req=urllib.request.Request(base+path,method=method,data=json.dumps(data).encode() if data is not None else None,headers={'Content-Type':'application/json','X-CSRF-Token':csrf})
 try:response=client.open(req)
 except urllib.error.HTTPError as e:response=e
 body=json.load(response);assert response.code==status,(path,response.code,body);return body
csrf=call('/session')['csrf'];login=call('/session','POST',{'email':values['GCF_ADMIN_EMAIL'],'password':Path('.admin-password').read_text().strip()});csrf=login['csrf']
image=None;records=[]
try:
 boundary='gcf-'+secrets.token_hex(12);content=Path('apps/web/public/assets/gcf-logo.jpg').read_bytes()
 body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="rich-test.jpg"\r\nContent-Type: image/jpeg\r\n\r\n').encode()+content+f'\r\n--{boundary}--\r\n'.encode()
 image=json.load(client.open(urllib.request.Request(base+'/media',data=body,headers={'Content-Type':'multipart/form-data; boundary='+boundary,'X-CSRF-Token':csrf})))
 doc='gcf-richtext:'+json.dumps({'type':'doc','content':[{'type':'heading','attrs':{'level':2},'content':[{'type':'text','text':'Our community'}]},{'type':'gcfFigure','attrs':{'mediaId':image['id'],'alt':'GCF emblem'},'content':[{'type':'text','text':'Community support'}]}]})
 for kind in ['events','initiatives','campaigns','newsletters']:
  nonce=secrets.token_hex(16);draft=call('/drafts/'+kind,'POST',{'draft_id':nonce});records.append((kind,draft['id']))
  assert draft['id']==nonce and draft['created_by']==login['user']['id']
  assert draft['title'].startswith('Untitled')
  assert call('/drafts/'+kind,'POST',{'draft_id':nonce})['id']==nonce
  data={**draft,'title':'Rich document fixture'}
  if kind=='newsletters':data.update(introduction=doc,body=doc)
  else:data['summary']=doc
  saved=call('/'+kind+'/'+nonce,'PUT',data)
  assert saved['body' if kind=='newsletters' else 'summary']==doc
  before=call('/audit')['total']
  assert call('/drafts/'+kind,'POST',{'draft_id':nonce})['title']=='Rich document fixture'
  assert call('/audit')['total']==before,'idempotent draft lookup must not log a second creation'
  bad={**saved,('body' if kind=='newsletters' else 'summary'):'gcf-richtext:'+json.dumps({'type':'doc','content':[{'type':'image','attrs':{'src':'javascript:bad'}}]})}
  call('/'+kind+'/'+nonce,'PUT',bad,status=422)
 assert call('/media/'+image['id'])['uses']==5
 call('/media/'+image['id'],'DELETE',status=422)
 print('PASS: persistent attributed drafts, idempotent creation, rich document round trips, image references, deletion protection and invalid format rejection')
finally:
 for kind,ident in reversed(records):call('/'+kind+'/'+ident,'DELETE')
 if image:call('/media/'+image['id'],'DELETE')
