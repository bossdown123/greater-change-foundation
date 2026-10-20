// Run only against a disposable, fully migrated database.
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
if(process.env.GCF_TEST_DATABASE!=='1')throw Error('Disposable database required')
const auth=JSON.parse(readFileSync(process.env.GCF_TEST_AUTH_FILE,'utf8')),base=process.env.GCF_TEST_URL||'http://app:4000'
let cookie='',csrf='';const made=[]
async function api(path,method='GET',data){const response=await fetch(`${base}/api/admin${path}`,{method,headers:{cookie,'content-type':'application/json','x-csrf-token':csrf},body:data?JSON.stringify(data):undefined});const cookies=response.headers.getSetCookie();if(cookies.length)cookie=cookies.map(c=>c.split(';')[0]).join('; ');const json=await response.json();if(!response.ok)throw Error(`${response.status}: ${json.error}`);return json}
csrf=(await api('/session')).csrf;csrf=(await api('/session','POST',auth)).csrf
async function draft(kind){const row=await api('/drafts/'+kind,'POST',{draft_id:crypto.randomUUID().replaceAll('-','')});made.push([kind,row.id]);return row}
try{
 const activity=await draft('events'),fundraiser=await draft('campaigns'),campaign=await draft('initiatives')
 const work=await api('/work');for(const row of [activity,fundraiser,campaign])assert.ok(work.items.some(item=>item.id===row.id))
 let article=await draft('articles');assert.equal(article.format,'article');assert.ok(article.created_by)
 article=await api('/articles/'+article.id,'PUT',{...article,title:'Community story',subject:'A new story',introduction:'Opening',body:'Closing',updates:[{kind:'events',id:activity.id},{kind:'campaigns',id:fundraiser.id}]})
 assert.equal(article.updates.length,2);assert.equal(article.body,'Closing');assert.equal(article.updates[0].id,activity.id)
 assert.ok((await api('/articles')).items.some(row=>row.id===article.id));assert.ok(!(await api('/newsletters')).items.some(row=>row.id===article.id))
 const newsletter=await draft('newsletters');assert.equal(newsletter.format,'newsletter')
 await assert.rejects(api('/drafts/articles','POST',{draft_id:newsletter.id}))
 assert.equal((await api('/newsletters/'+newsletter.id)).title,newsletter.title,'other publication formats cannot be overwritten by a draft nonce')
 const updated=await api('/events/'+activity.id,'PUT',{...activity,title:'Shared activity',dates:['2026-10-20'],locations:['Community centre']})
 const current=await api('/articles/'+article.id);assert.equal(current.body,'Closing');assert.equal(current.updates[0].id,updated.id)
 await assert.rejects(api('/articles/'+article.id,'PUT',{...article,title:'Changed once'}).then(async saved=>{await api('/articles/'+article.id,'PUT',{...article,title:'Stale overwrite'});return saved}),/Another editor saved changes/)
 console.log('PASS: shared work list, separate article/newsletter views, source references, ownership, draft collision and stale-save protection')
}finally{for(const [kind,id] of made.reverse())await api('/'+kind+'/'+id,'DELETE');await api('/session','DELETE')}
