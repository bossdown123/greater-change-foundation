"""Named-account and audit behavior. Run only on a disposable test database."""
import http.cookiejar,json,os,secrets,urllib.request,urllib.error
from pathlib import Path
if os.environ.get('GCF_TEST_IDENTITY')!='1': raise SystemExit('Requires GCF_TEST_IDENTITY=1 and a disposable database')
base=os.environ.get('GCF_TEST_URL','http://127.0.0.1:4100')+'/api/admin'
env=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
class Client:
 def __init__(self):
  self.opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));self.csrf=''
 def call(self,path,method='GET',data=None,status=200):
  req=urllib.request.Request(base+path,method=method,data=json.dumps(data).encode() if data is not None else None,headers={'Content-Type':'application/json','X-CSRF-Token':self.csrf})
  try:r=self.opener.open(req)
  except urllib.error.HTTPError as e:r=e
  body=json.load(r)
  assert r.code==status,(path,r.code,body)
  return body
 def login(self,email,password):
  self.csrf=self.call('/session')['csrf'];res=self.call('/session','POST',{'email':email,'password':password});self.csrf=res['csrf'];return res['user']
admin=Client();owner=admin.login(env['GCF_ADMIN_EMAIL'],Path('.admin-password').read_text().strip())
password=secrets.token_urlsafe(24);new_password=secrets.token_urlsafe(24)
email='editor-'+secrets.token_hex(6)+'@example.test'
user=admin.call('/users','POST',{'email':email,'name':'Integration editor','role':'editor','password':password})
assert 'password_hash' not in user
editor=Client();actor=editor.login(email.upper(),password)
editor.call('/users',status=403)
event=editor.call('/events','POST',{'title':'Account audit test','created_by':owner['id'],'updated_by':owner['id']})
assert event['created_by']==event['updated_by']==actor['id']
changed=admin.call('/events/'+event['id'],'PUT',{'title':'Owner edited test','created_by':'spoof'})
assert changed['created_by']==actor['id'] and changed['updated_by']==owner['id']
history=admin.call('/audit?resource_id='+event['id'])['items']
assert {entry['actor_id'] for entry in history}=={actor['id'],owner['id']}
# Sessions are invalidated when credentials change, even in another browser.
second=Client();second.login(email,password)
editor.call('/password','PUT',{'current_password':password,'password':new_password})
second.call('/events',status=401)
editor.login(email,new_password)
admin.call('/users/'+actor['id'],'PUT',{'email':email,'name':'Integration editor','role':'editor','active':0})
editor.call('/events',status=401)
admin.call('/events/'+event['id'],'DELETE')
assert admin.call('/audit?resource_id='+event['id'])['total']==3
for entry in admin.call('/audit?type=users')['items']:
 detail=admin.call('/audit/'+entry['id'])
 serialized=json.dumps(detail)
 assert password not in serialized and new_password not in serialized and 'password_hash' not in serialized
admin.call('/users/'+owner['id'],'PUT',{'email':owner['email'],'name':owner['name'],'role':'editor','active':0},status=422)
print('PASS: named sign-in, role authorization, creator/modifier identity, forged actor rejection, session revocation, disabled accounts, immutable retained audit, and secret exclusion')
