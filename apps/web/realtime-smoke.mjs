// API/transport integration only; no browser automation or UI rendering.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import WebSocket from 'ws'
const config=JSON.parse(readFileSync(process.env.GCF_TEST_AUTH_FILE,'utf8'))
const base=process.env.GCF_TEST_URL||'http://127.0.0.1:4000'
let cookie='',csrf='',user
async function api(path,method='GET',data){const response=await fetch(`${base}/api/admin${path}`,{method,headers:{cookie,'content-type':'application/json','x-csrf-token':csrf},body:data?JSON.stringify(data):undefined});const cookies=response.headers.getSetCookie();if(cookies.length)cookie=cookies.map(c=>c.split(';')[0]).join('; ');const json=await response.json();if(!response.ok)throw Error(`${response.status}: ${json.error}`);return json}
csrf=(await api('/session')).csrf;const login=await api('/session','POST',config);csrf=login.csrf;user=login.user
assert.match(user.color,/^#[0-9a-f]{6}$/)
const before=await api('/audit')
async function connection(){const {token}=await api('/realtime-token'),ws=new WebSocket(base.replace(/^http/,'ws')+`/live/websocket?vsn=2.0.0&token=${encodeURIComponent(token)}`,{origin:"http://127.0.0.1:4173"});const queue=[];let seq=0;ws.on('message',data=>queue.push(JSON.parse(data)));await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject)});const send=(event,payload)=>{const ref=String(++seq);ws.send(JSON.stringify(['1',ref,'admin:workspace',event,payload]));return ref};async function wait(event,predicate=()=>true){const end=Date.now()+6000;while(Date.now()<end){const i=queue.findIndex(m=>m[3]===event&&predicate(m[4]));if(i>=0)return queue.splice(i,1)[0][4];await new Promise(r=>setTimeout(r,20))}throw Error(`No ${event}`)}send('phx_join',{});const joined=await wait('phx_reply');assert.equal(joined.status,'ok');assert.ok(joined.response.connection_id);await wait('presence_state');return{ws,send,wait,connectionId:joined.response.connection_id}}
async function rejected(url,origin){await new Promise((resolve,reject)=>{const ws=new WebSocket(url,{origin});const timer=setTimeout(()=>{ws.terminate();reject(Error('Handshake did not reject'))},3000);ws.once('open',()=>{clearTimeout(timer);ws.close();reject(Error('Unauthorized socket opened'))});ws.once('unexpected-response',(_request,response)=>{clearTimeout(timer);response.resume();assert.equal(response.statusCode,403);ws.terminate();resolve()});ws.once('error',()=>{clearTimeout(timer);resolve()})})}
await rejected(base.replace(/^http/,'ws')+'/live/websocket?vsn=2.0.0','http://127.0.0.1:4173')
const {token:originToken}=await api('/realtime-token')
await rejected(base.replace(/^http/,'ws')+`/live/websocket?vsn=2.0.0&token=${encodeURIComponent(originToken)}`,'https://untrusted.example')
const first=await connection(),second=await connection();assert.notEqual(first.connectionId,second.connectionId)
try{
 first.send('location',{section:'events',resource_id:'transport-check',title:'Transport check',editing:true,field_active:true,field:'Event title:0',name:'Forged name',color:'#ffffff'})
 const diff=await second.wait('presence_diff',p=>p.joins?.[user.id]?.metas?.some(m=>m.field==='Event title:0'))
 const meta=diff.joins[user.id].metas.find(m=>m.field==='Event title:0')
 assert.equal(meta.name,user.name);assert.equal(meta.color,user.color);assert.equal(meta.section,'events');assert.equal(meta.field_active,true)
 first.send('location',{section:'events',resource_id:'transport-check',field:'Event title:0',field_active:false})
 const inactive=await second.wait('presence_diff',p=>p.joins?.[user.id]?.metas?.some(m=>m.field==='Event title:0'&&m.field_active===false))
 assert.ok(inactive.joins[user.id].metas.some(m=>m.field==='Event title:0'&&m.field_active===false),'leaving retains recent field presence as inactive')
 first.send('location',{section:'not-a-section'});const reply=await first.wait('phx_reply',p=>p.status==='error');assert.equal(reply.status,'error')
 assert.equal((await api('/audit')).total,before.total,'presence and reads must not enter audit')
 if(process.env.GCF_TEST_DATABASE==='1'){
  let record
  try{
   record=await api('/events','POST',{title:'Transport fixture',summary:'',dates:[],locations:[],participants:null,funds_raised:null,currency:'USD',custom_fields:[],media_ids:[],initiative_ids:[],campaign_ids:[]})
   await second.wait('changed',p=>p.resource_id===record.id)
   const stale={...record};record=await api(`/events/${record.id}`,'PUT',{...record,title:'Transport updated'})
   const beforeStale=(await api('/audit')).total
   await assert.rejects(api(`/events/${record.id}`,'PUT',{...stale,title:'Stale overwrite'}),/Another editor saved changes/)
   assert.equal((await api(`/events/${record.id}`)).title,'Transport updated')
   assert.equal((await api('/audit')).total,beforeStale,'rejected saves must not create committed audit rows')
   const adminCookie=cookie,adminCsrf=csrf,password='test-'+crypto.randomUUID()
   const member=await api('/users','POST',{email:`realtime-${crypto.randomUUID()}@example.test`,name:'Second editor',role:'editor',password})
   let other
   try{
    const signedIn=await api('/session','POST',{email:member.email,password});csrf=signedIn.csrf
    other=await connection();cookie=adminCookie;csrf=adminCsrf
    const historyBefore=(await api('/audit')).total
    first.send('draft',{kind:'events',id:record.id,fields:{summary:'First editor typing'},name:'Forged author'})
    const live=await other.wait('draft',p=>p.id===record.id&&p.fields.summary==='First editor typing')
    assert.equal(live.actor_id,user.id);assert.equal(live.name,user.name);assert.equal(live.connection_id,first.connectionId)
    other.send('draft',{kind:'events',id:record.id,fields:{summary:'Second editor typing'}})
    const back=await first.wait('draft',p=>p.id===record.id&&p.actor_id===member.id)
    assert.equal(back.fields.summary,'Second editor typing')
    assert.equal((await api('/audit')).total,historyBefore,'unsaved draft signals must not create audit rows')
    first.send('draft',{kind:'events',id:record.id,fields:{password:'must not broadcast'}})
    await first.wait('phx_reply',p=>p.status==='error')
   }finally{
    cookie=adminCookie;csrf=adminCsrf;other?.ws.close()
    await api('/users/'+member.id,'PUT',{...member,active:0})
   }

  }finally{if(record)await api(`/events/${record.id}`,'DELETE')}
 }
 console.log('PASS: authenticated WebSockets, server-owned identity/color, field presence, read-only audit, and optional committed-change/stale-write checks')
}finally{first.ws.close();second.ws.close();await api('/session','DELETE')}
