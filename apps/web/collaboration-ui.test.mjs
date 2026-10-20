// Isolated DOM unit test: no browser, site connection, real account or network access.
import assert from 'node:assert/strict'
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
import {build} from 'esbuild'
import {JSDOM} from 'jsdom'
import React,{act,useState} from 'react'
const dir=mkdtempSync(new URL('./.collaboration-test-',import.meta.url)),dom=new JSDOM('<!doctype html><html><body><div id="test"></div></body></html>')
Object.assign(globalThis,{window:dom.window,document:dom.window.document,HTMLElement:dom.window.HTMLElement,Node:dom.window.Node,MutationObserver:dom.window.MutationObserver,CustomEvent:dom.window.CustomEvent,IS_REACT_ACT_ENVIRONMENT:true})
globalThis.requestAnimationFrame=callback=>setTimeout(callback,0)
globalThis.cancelAnimationFrame=clearTimeout
globalThis.getComputedStyle=dom.window.getComputedStyle.bind(dom.window)
globalThis.ResizeObserver=class{observe(){}disconnect(){}}
let fieldWidth=400
const originalRect=HTMLElement.prototype.getBoundingClientRect
HTMLElement.prototype.getBoundingClientRect=function(){
 const rect=(left,top,width,height)=>({left,top,width,height,right:left+width,bottom:top+height,x:left,y:top,toJSON(){return this}})
 if(this.matches('input[aria-label="Title"]'))return rect(20,50,fieldWidth,40)
 if(this.matches('label'))return rect(20,20,fieldWidth,70)
 if(this.matches('.field-editors'))return rect(0,0,110,44)
 return originalRect.call(this)
}
const {createRoot}=await import('react-dom/client')
const h=React.createElement,container=document.getElementById('test'),root=createRoot(container)
try{
 writeFileSync(dir+'/entry.ts','export {RealtimeContext,CollaborativeFields} from "../src/realtime"; export {useRemoteDraft} from "../src/remote-draft"; export {default as RichEditor} from "../src/rich-editor";')
 await build({entryPoints:[dir+'/entry.ts'],outfile:dir+'/bundle.mjs',bundle:true,platform:'node',format:'esm',packages:'external',loader:{'.css':'empty'},jsx:'automatic',logLevel:'silent',plugins:[{name:'ignore-css',setup(build){build.onResolve({filter:/\.css$/},args=>({path:args.path,namespace:'empty-css'}));build.onLoad({filter:/.*/,namespace:'empty-css'},()=>({contents:'',loader:'js'}))}}]})
 const {RealtimeContext,CollaborativeFields,useRemoteDraft,RichEditor}=await import(pathToFileURL(dir+'/bundle.mjs'))
 const people=[{id:'a',connection_id:'tab-a',name:'Member A',color:'#2563eb',section:'events',resource_id:'doc',field:'Title:0',interacted_at:1,editing:true},{id:'b',connection_id:'tab-b',name:'Member B',color:'#d97706',section:'events',resource_id:'doc',field:'Title:0',interacted_at:2,editing:true}]
 const located=[]
 await act(async()=>root.render(h(RealtimeContext.Provider,{value:{people,userId:'a',connected:true,locate:value=>located.push(value),sendDraft:()=>{}}},h('div',{className:'workspace'},h('form',{className:'editor'},h('label',null,'Title',h('input',{'aria-label':'Title'}))),h(CollaborativeFields,{section:'events',resourceId:'doc'})))))
 const frame=document.querySelector('.field-presence-frame')
 assert.ok(frame,'the visible field frame is mounted')
 assert.match(frame.textContent,/Member A/);assert.match(frame.textContent,/Member B/)
 assert.equal(frame.style.getPropertyValue('--editor-color'),'#d97706')
 assert.deepEqual([...frame.querySelectorAll('.field-presence-member-fill')].map(row=>row.style.getPropertyValue('--member-color')),['#2563eb','#d97706'],'each member row keeps its own background color')
 assert.equal(frame.style.left,'-4px' ,'the colored frame sits outside the native input')
 assert.equal(frame.style.top,'26px')
 assert.equal(frame.style.width,'408px')
 assert.equal(frame.querySelectorAll('.field-presence-stroke').length,1,'only one path owns the entire border')
 assert.equal(frame.querySelector('.field-presence-stroke').getAttribute('stroke-width'),'2')
 assert.match(frame.querySelector('.field-presence-stroke').getAttribute('d'),/V 53 Q 297 47 291 47/,'the left tab join rounds inward')
 fieldWidth=220
 await act(async()=>window.dispatchEvent(new window.Event('resize')))
 assert.equal(frame.style.width,'228px','the outer stroke tracks responsive field resizing')
 assert.equal(frame.querySelector('svg').getAttribute('height'),'92')
 await act(async()=>{document.querySelector('input').focus();document.querySelector('input').blur()})
 assert.equal(located.at(-1).field,'Title:0','switching window focus must not clear the field indicator')
 await act(async()=>root.render(h('div')))
 function Probe(){const [draft,setDraft]=useState({id:'doc',summary:'Mine',updated_at:'v1'}),[snapshot,setSnapshot]=useState(JSON.stringify({id:'doc',summary:'Before',updated_at:'v1'}));const remote=useRemoteDraft('events',draft,setDraft,snapshot,setSnapshot);return h('div',{className:'configuration-panel'},h('main',null,h('span',{'data-draft':true},draft.summary),h('button',{disabled:remote.blocked},'Save')),remote.panel)}
 await act(async()=>root.render(h(RealtimeContext.Provider,{value:{people,userId:'a',connected:true,locate:()=>{},sendDraft:()=>{}}},h(Probe))))
 const update=fields=>window.dispatchEvent(new CustomEvent('gcf:draft',{detail:{kind:'events',id:'doc',connection_id:'tab-b',actor_id:'b',name:'Member B',fields}}))
 await act(async()=>update({summary:'Theirs'}))
 assert.match(document.querySelector('.configuration-panel>.remote-conflicts').textContent,/Member B/)
 assert.equal(document.querySelector('main button').disabled,true)
 await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Keep mine').click())
 assert.equal(document.querySelector('.remote-conflicts'),null)
 await act(async()=>update({summary:'Changed again'}))
 await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Use theirs').click())
 assert.equal(document.querySelector('[data-draft]').textContent,'Changed again')
 await act(async()=>update({}))
 globalThis.fetch=async()=>({ok:true,json:async()=>({id:'doc',summary:'Saved remotely',updated_at:'v2'})})
 await act(async()=>{window.dispatchEvent(new CustomEvent('gcf:changed',{detail:{resource_type:'events',resource_id:'doc'}}));await new Promise(r=>setTimeout(r,230))})
 assert.match(document.querySelector('.remote-conflicts').textContent,/Another editor/)
 assert.equal(document.querySelector('[data-draft]').textContent,'Changed again')
 await act(async()=>root.render(h(RichEditor,{label:'Story',value:'gcf-richtext:'+JSON.stringify({type:'doc',content:[{type:'gcfFigure',attrs:{mediaId:'a'.repeat(32),alt:'GCF',widthPercent:40},content:[{type:'text',text:'Saved caption'}]},{type:'paragraph'}]}),onChange:()=>{}})))
 assert.ok(document.querySelector('.figure-reference'),'editor renders a compact image reference')
 assert.match(document.querySelector('.figure-reference-caption').textContent,/Saved caption/)
 assert.equal(document.querySelector('.figure-reference-width input').value,'40')
 assert.equal(document.querySelector('.rich-surface img'),null,'full images do not occupy the writing surface')
 await act(async()=>root.unmount())
 console.log('PASS: actual field UI mounts both account names, recent-editor color and persistent activity')
}finally{try{await act(async()=>root.unmount())}catch{}dom.window.close();rmSync(dir,{recursive:true,force:true})}
