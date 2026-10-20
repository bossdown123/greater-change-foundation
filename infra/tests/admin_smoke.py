"""Real HTTP + Turso + S3 integration checks. Creates temporary records and removes them."""
import http.cookiejar
import json
import os
from pathlib import Path
import urllib.error
import urllib.request
import uuid
import struct
import zlib

base = os.environ.get('GCF_TEST_URL', 'http://127.0.0.1:4000')
env_values=dict(line.split('=',1) for line in Path('.env').read_text().splitlines() if '=' in line and not line.startswith('#')) if Path('.env').exists() else {}
email=os.environ.get('GCF_TEST_ADMIN_EMAIL',env_values.get('GCF_ADMIN_EMAIL','admin@example.test'))
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
call('/session', 'POST', {'email': email, 'password': password}, expected=403, headers={'X-CSRF-Token': 'invalid'})
csrf = call('/session', 'POST', {'email': email, 'password': password})['csrf']
session=call('/session')
assert session['authenticated']
actor_id=session['user']['id']
def high_resolution_png():
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    compressor=zlib.compressobj()
    row=b'\x00'+b'\x80\xb0\x90'*6000
    content=b''.join(compressor.compress(row) for _ in range(4000))+compressor.flush()
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',6000,4000,8,2,0,0,0))+chunk(b'IDAT',content)+chunk(b'IEND',b'')

media = event = newsletter = initiative = campaign = large = None
paging_records = []
try:
    boundary = 'gcf-' + uuid.uuid4().hex
    image = Path('apps/web/public/assets/gcf-logo.jpg').read_bytes()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="smoke-logo.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode() + image + f'\r\n--{boundary}--\r\n'.encode())
    media = call('/media', 'POST', body, headers={'Content-Type': 'multipart/form-data; boundary=' + boundary})
    assert call('/media/' + media['id'] + '/file') == image
    assert call('/media/' + media['id'] + '/thumbnail')[:4] == b'RIFF'
    high_res=high_resolution_png()
    large_body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="high-resolution.png"\r\nContent-Type: image/png\r\n\r\n'.encode()+high_res+f'\r\n--{boundary}--\r\n'.encode())
    large=call('/media','POST',large_body,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
    assert call('/media/'+large['id']+'/thumbnail')[:4]==b'RIFF'
    call('/media/'+large['id'],'DELETE')
    large=None
    media = call('/media/' + media['id'], 'PATCH', {'alt':'GCF logo for integration test','caption':'Temporary test image'})
    event_data = {'title':'Integration test — remove me','summary':'A community event.', 'dates':['2026-11-01','2026-11-02'],'locations':['Community centre','Town hall'],'participants':0,'funds_raised':123.45,'currency':'JMD','media_ids':[media['id']], 'custom_fields':[{'label':'Volunteers','type':'number','value':12},{'label':'Partner','type':'text','value':'Local community'},{'label':'Review date','type':'date','value':'2026-11-03'},{'label':'Project URL','type':'link','value':'https://example.org'}]}
    event = call('/events','POST',event_data)
    assert event['created_by']==event['updated_by']==actor_id
    for key,value in event_data.items():
        assert event[key] == value, (key,event[key],value)
    call('/media/' + media['id'], 'DELETE', expected=422)
    assert call('/media/' + media['id'])['events'][0]['id'] == event['id']
    assert 'date' in call('/events','POST',{**event_data,'dates':['not-a-date']},expected=422)['error'].lower()
    call('/events','POST',{**event_data,'media_ids':['0'*32]},expected=422)
    event_data['locations']=['Town hall']
    event_data['created_by']='forged-actor'
    event_data['updated_by']='forged-actor'
    event = call('/events/'+event['id'],'PUT',event_data)
    assert event['locations']==['Town hall']
    assert event['created_by']==event['updated_by']==actor_id
    history=call('/audit?resource_id='+event['id'])['items']
    assert all(a['actor_id']==actor_id for a in history)
    assert {'create','update'}.issubset({a['operation'] for a in history})
    detail=call('/audit/'+next(a['id'] for a in history if a['operation']=='create'))
    assert any(c['column_name']=='title' and c['new_value']==event_data['title'] for c in detail['changes'])
    assert all(c['column_name']!='password_hash' for c in detail['changes'])
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
    # Counts follow the filter on every collection, including out-of-range pages.
    for path in ['/events', '/initiatives', '/campaigns', '/newsletters', '/updates', '/media']:
        result = call(path)
        assert isinstance(result['total'], int) and result['total'] >= 1, (path, result)
        assert result['page_size'] == (48 if path == '/media' else 24)
        absent = call(path + '?query=nonexistent-' + uuid.uuid4().hex)
        assert absent['total'] == 0 and absent['items'] == [] and not absent['more']
        distant = call(path + '?page=99999')
        assert distant['total'] == result['total'] and distant['items'] == []
        assert all('result_count' not in item for item in result['items'])
    prefix = 'Pagination-' + uuid.uuid4().hex
    for index in range(27):
        record = call('/events', 'POST', {**event_data, 'title':f'{prefix}-{index:02}', 'media_ids':[]})
        paging_records.append(record['id'])
    first = call('/events?query=' + prefix)
    second = call('/events?query=' + prefix + '&page=2')
    assert first['total'] == second['total'] == 27
    assert len(first['items']) == 24 and first['more']
    assert len(second['items']) == 3 and not second['more']
    assert {r['id'] for r in first['items']}.isdisjoint(r['id'] for r in second['items'])
    assert call('/updates?kind=events&query=' + prefix)['total'] == 27
    print('PASS: filtered totals, page sizes, disjoint numbered pages, and out-of-range results')
    print('PASS: authentication, CSRF, private original/thumbnail uploads, normalized event round-trip, reuse protection, validation, newsletter generation and persistence')
finally:
    for record_id in paging_records: call('/events/' + record_id, 'DELETE')
    if newsletter: call('/newsletters/'+newsletter['id'],'DELETE')
    if campaign: call('/campaigns/'+campaign['id'],'DELETE')
    if initiative: call('/initiatives/'+initiative['id'],'DELETE')
    if event: call('/events/'+event['id'],'DELETE')
    if large: call('/media/'+large['id'],'DELETE')
    if media: call('/media/'+media['id'],'DELETE')
call('/session','DELETE')
call('/events',expected=401)
print('PASS: cleanup and logout')
