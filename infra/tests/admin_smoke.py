"""Real HTTP + Turso + S3 integration checks. Creates temporary records and removes them."""
import http.cookiejar
import json
import os
from pathlib import Path
import urllib.error
import urllib.request
import uuid

base = os.environ.get('GCF_TEST_URL', 'http://127.0.0.1:4000')
password = Path(os.environ.get('GCF_ADMIN_PASSWORD_FILE', '.admin-password')).read_text().strip()
jar = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
csrf = ''

def call(path, method='GET', data=None, expected=200, headers=None):
    extra = {'X-CSRF-Token': csrf, **(headers or {})}
    if isinstance(data, dict):
        data = json.dumps(data).encode()
        extra['Content-Type'] = 'application/json'
    request = urllib.request.Request(base + '/api/admin' + path, data=data, method=method, headers=extra)
    try:
        response = client.open(request)
    except urllib.error.HTTPError as error:
        response = error
    body = response.read()
    assert response.code == expected, (path, response.code, body[:500])
    if response.headers.get_content_type() == 'application/json':
        return json.loads(body)
    return body

call('/events', expected=401)
csrf = call('/session')['csrf']
call('/session', 'POST', {'password': password}, expected=403, headers={'X-CSRF-Token': 'invalid'})
csrf = call('/session', 'POST', {'password': password})['csrf']
assert call('/session')['authenticated']
media = event = newsletter = initiative = campaign = None
try:
    boundary = 'gcf-' + uuid.uuid4().hex
    image = Path('apps/web/public/assets/gcf-logo.jpg').read_bytes()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="smoke-logo.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode() + image + f'\r\n--{boundary}--\r\n'.encode())
    media = call('/media', 'POST', body, headers={'Content-Type': 'multipart/form-data; boundary=' + boundary})
    assert call('/media/' + media['id'] + '/file') == image
    assert call('/media/' + media['id'] + '/thumbnail')[:4] == b'RIFF'
    media = call('/media/' + media['id'], 'PATCH', {'alt':'GCF logo for integration test','caption':'Temporary test image'})
    event_data = {'title':'Integration test — remove me','summary':'A community event.', 'dates':['2026-11-01','2026-11-02'],'locations':['Community centre','Town hall'],'participants':0,'funds_raised':123.45,'currency':'JMD','media_ids':[media['id']], 'custom_fields':[{'label':'Volunteers','type':'number','value':12},{'label':'Partner','type':'text','value':'Local community'},{'label':'Review date','type':'date','value':'2026-11-03'},{'label':'Project URL','type':'link','value':'https://example.org'}]}
    event = call('/events','POST',event_data)
    for key,value in event_data.items():
        assert event[key] == value, (key,event[key],value)
    call('/media/' + media['id'], 'DELETE', expected=422)
    assert call('/media/' + media['id'])['events'][0]['id'] == event['id']
    assert 'date' in call('/events','POST',{**event_data,'dates':['not-a-date']},expected=422)['error'].lower()
    call('/events','POST',{**event_data,'media_ids':['0'*32]},expected=422)
    event_data['locations']=['Town hall']
    event = call('/events/'+event['id'],'PUT',event_data)
    assert event['locations']==['Town hall']
    initiative = call('/initiatives','POST',{'title':'Test initiative','summary':'Initiative story','event_ids':[event['id']]})
    campaign = call('/campaigns','POST',{'title':'Test campaign','summary':'Campaign story','event_ids':[event['id']],'initiative_ids':[initiative['id']],'target':2000,'raised':750.25,'currency':'JMD','starts_on':'2026-10-01','ends_on':'2026-12-31'})
    linked_event = call('/events/'+event['id'])
    assert linked_event['initiative_ids']==[initiative['id']] and linked_event['campaign_ids']==[campaign['id']]
    assert call('/initiatives/'+initiative['id'])['campaign_ids']==[campaign['id']]
    # Editing a relationship from either end updates one shared join relation.
    linked_event['campaign_ids']=[]
    call('/events/'+event['id'],'PUT',linked_event)
    assert call('/campaigns/'+campaign['id'])['event_ids']==[]
    updates=[{'kind':'campaigns','id':campaign['id']},{'kind':'initiatives','id':initiative['id']},{'kind':'events','id':event['id']}]
    generated = call('/newsletters/generate','POST',{'updates':updates})
    assert '123.45' in generated['body'] and 'Volunteers: 12' in generated['body']
    assert '750.25' in generated['body'] and generated['body'].index('Test campaign')<generated['body'].index('Test initiative')
    newsletter = call('/newsletters','POST',generated)
    assert call('/newsletters/'+newsletter['id'])['updates']==updates
    assert any(e['id']==event['id'] for e in call('/events')['items'])
    print('PASS: authentication, CSRF, private original/thumbnail uploads, normalized event round-trip, reuse protection, validation, newsletter generation and persistence')
finally:
    if newsletter: call('/newsletters/'+newsletter['id'],'DELETE')
    if campaign: call('/campaigns/'+campaign['id'],'DELETE')
    if initiative: call('/initiatives/'+initiative['id'],'DELETE')
    if event: call('/events/'+event['id'],'DELETE')
    if media: call('/media/'+media['id'],'DELETE')
call('/session','DELETE')
call('/events',expected=401)
print('PASS: cleanup and logout')
