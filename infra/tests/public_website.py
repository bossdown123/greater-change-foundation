"""Read-only public release smoke check. Requires a running built application."""
import os
from urllib.request import urlopen, Request
from urllib.error import HTTPError
from html.parser import HTMLParser

base=os.environ.get('GCF_TEST_URL','http://127.0.0.1:4000')
paths=['/','/our-work','/updates','/about','/support','/privacy','/our-work/childs-month-2025','/our-work/blood-drive-2024','/our-work/christmas-2023','/our-work/anniversary-celebration','/our-work/christmas-2022']
class Page(HTMLParser):
 def __init__(self): super().__init__();self.headings=0;self.canonical=None;self.images=[]
 def handle_starttag(self,tag,attrs):
  attrs=dict(attrs)
  if tag=='h1':self.headings+=1
  if tag=='link' and attrs.get('rel')=='canonical':self.canonical=attrs.get('href')
  if tag=='img':self.images.append(attrs.get('src'))
assets=set()
for path in paths:
 with urlopen(base+path) as response:
  assert response.status==200,path
  assert response.headers.get_content_type()=='text/html',path
  assert "frame-ancestors 'none'" in response.headers['content-security-policy']
  html=response.read().decode();page=Page();page.feed(html)
  assert page.headings==1,path
  assert page.canonical=='https://greaterchangefoundation.org'+path,path
  assert '/api/admin/' not in html and 'UNDER DEVELOPMENT' not in html,path
  assets.update(page.images)
for asset in assets:
 assert asset.startswith('/assets/'),asset
 with urlopen(base+asset) as response:assert response.status==200 and response.headers.get_content_type().startswith('image/')
with urlopen(base+'/admin') as response:
 html=response.read().decode();assert 'no-store' in response.headers['cache-control'];assert 'noindex,nofollow' in html;assert 'Small acts.' not in html
for path in ['/api/admin/media','/our-work/private-draft','/pages/about.html']:
 try:urlopen(base+path);raise AssertionError('Unexpected public response: '+path)
 except HTTPError as error:assert error.code in [401,404],(path,error.code)
try:urlopen(base+'/missing-page');raise AssertionError('Missing page returned success')
except HTTPError as error:
 assert error.code==404 and error.headers['x-robots-tag']=='noindex'
 assert b'A different path.' in error.read()
with urlopen(base+'/sitemap.xml') as response:
 text=response.read().decode();assert '<loc>https://greaterchangefoundation.org/our-work</loc>' in text;assert '/admin' not in text
print(f'PASS: {len(paths)} built public routes, {len(assets)} images, security headers, sitemap and private workspace boundary')
