// Run only on a disposable database. Never seed the charity's real workspace.
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
if(process.env.GCF_TEST_DATABASE!=='1')throw Error('Disposable database required')
const auth=JSON.parse(readFileSync(process.env.GCF_TEST_AUTH_FILE,'utf8')),base=process.env.GCF_TEST_URL||'http://app:4000'
let cookie='',csrf='';const records=[],photos=[]
async function request(path,method='GET',data){const response=await fetch(base+'/api/admin'+path,{method,headers:{cookie,'x-csrf-token':csrf,...(data instanceof FormData?{}:{'content-type':'application/json'})},body:data instanceof FormData?data:data?JSON.stringify(data):undefined});const cookies=response.headers.getSetCookie();if(cookies.length)cookie=cookies.map(c=>c.split(';')[0]).join('; ');const json=await response.json();if(!response.ok)throw Error(response.status+': '+json.error);return json}
csrf=(await request('/session')).csrf;csrf=(await request('/session','POST',auth)).csrf
async function draft(kind){const row=await request('/drafts/'+kind,'POST',{draft_id:crypto.randomUUID().replaceAll('-','')});records.push([kind,row.id]);return row}
try {
 const jpeg=readFileSync('public/assets/gcf-logo.jpg')
 for(let i=0;i<3;i++){const data=new FormData();data.append('file',new Blob([jpeg],{type:'image/jpeg'}),`collection-${i}.jpg`);const row=await request('/media','POST',data);photos.push(row.id)}
 let group=await draft('media_groups');assert.ok(group.created_by);assert.equal(group.photo_count,0)
 group=await request('/media_groups/'+group.id,'PUT',{...group,title:'Shared gallery',media_ids:[photos[2],photos[0],photos[1]]})
 assert.equal(group.photo_count,3);assert.deepEqual(group.media_ids,[photos[2],photos[0],photos[1]])
 let page=await request('/media?group_id='+group.id);assert.deepEqual(page.items.map(p=>p.id),group.media_ids);assert.equal(page.total,3)
 for(const kind of ['events','initiatives','campaigns','articles','newsletters']){
  let record=await draft(kind);record=await request('/'+kind+'/'+record.id,'PUT',{...record,group_ids:[group.id]});assert.deepEqual(record.group_ids,[group.id])
  await assert.rejects(request('/media_groups/'+group.id,'DELETE'))
  const updated=await request('/'+kind+'/'+record.id);assert.deepEqual(updated.group_ids,[group.id])
 }
 const stale={...group};group=await request('/media_groups/'+group.id,'PUT',{...group,media_ids:[photos[1],photos[2]]})
 await assert.rejects(request('/media_groups/'+group.id,'PUT',{...stale,title:'Stale overwrite'}))
 page=await request('/media?group_id='+group.id);assert.equal(page.total,2);assert.deepEqual(page.items.map(p=>p.id),group.media_ids)
 await assert.rejects(request('/media/'+photos[1],'DELETE'))
 const other=await draft('media_groups');assert.equal((await request('/drafts/media_groups','POST',{draft_id:group.id})).id,group.id)
 assert.ok((await request('/media_groups?query=Shared')).items.some(item=>item.id===group.id))
 await request('/media_groups/'+other.id,'PUT',{...other,media_ids:[photos[0],photos[0]]}).then(()=>assert.fail('Duplicate photo accepted'),()=>{})
 console.log('PASS: collection drafts, attribution, shared typed links, ordered membership, filters, live source updates, deletion protection and stale-write rejection')
} finally {
 for(const [kind,id] of records.reverse()){try{await request('/'+kind+'/'+id,'DELETE')}catch{}}
 for(const id of photos){try{await request('/media/'+id,'DELETE')}catch{}}
 await request('/session','DELETE')
}
