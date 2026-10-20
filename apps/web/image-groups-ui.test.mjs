// Isolated DOM test of collection selection and gallery opening; no server/browser connection.
import assert from 'node:assert/strict'
import {build} from 'esbuild'
import {JSDOM} from 'jsdom'
import {mkdtempSync,rmSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const dir=mkdtempSync(new URL('./.image-groups-test-',import.meta.url)),dom=new JSDOM('<!doctype html><body><div id="root"></div></body>',{url:'http://localhost/admin'})
Object.assign(globalThis,{window:dom.window,document:dom.window.document,HTMLElement:dom.window.HTMLElement,HTMLInputElement:dom.window.HTMLInputElement,Node:dom.window.Node,NodeFilter:dom.window.NodeFilter,MutationObserver:dom.window.MutationObserver,CustomEvent:dom.window.CustomEvent,Event:dom.window.Event,IS_REACT_ACT_ENVIRONMENT:true})
globalThis.getComputedStyle=dom.window.getComputedStyle.bind(dom.window)
globalThis.requestAnimationFrame=fn=>setTimeout(fn,0);globalThis.cancelAnimationFrame=clearTimeout
globalThis.IntersectionObserver=class{observe(){}disconnect(){}}
const groups=[{id:'a',title:'Christmas',photo_count:2,media_ids:['p1','p2']},{id:'b',title:'Child’s Month',photo_count:1,media_ids:['p2']}]
globalThis.fetch=async path=>{
 const url=new URL(path,'http://localhost'),id=url.pathname.split('/').at(-1)
 const data=url.pathname.endsWith('/media_groups')?{items:groups,total:2,page_size:24}:url.pathname.includes('/media_groups/')?groups.find(g=>g.id===id):url.pathname.endsWith('/media')?{items:[{id:'p1',filename:'photo.jpg',alt:'GCF team',caption:'Together',thumbnail_url:'/test.jpg',metadata:{width:800,height:600}}],total:1,page_size:48}:{id,filename:'photo.jpg',alt:'GCF team',caption:'Together',thumbnail_url:'/test.jpg',metadata:{width:800,height:600}}
 return {ok:true,json:async()=>data}
}
const React=await import('react'),{act}=React,{createRoot}=await import('react-dom/client'),root=createRoot(document.getElementById('root'))
const settle=async()=>act(async()=>new Promise(resolve=>setTimeout(resolve,220)))
try{
 await build({stdin:{contents:"export {CollectionLinks,LinkedCollections,CollectionPreview} from './src/image-groups'",resolveDir:process.cwd(),loader:'tsx'},outfile:dir+'/bundle.mjs',bundle:true,platform:'node',format:'esm',packages:'external',loader:{'.css':'empty'},jsx:'automatic',plugins:[{name:'css',setup(b){b.onResolve({filter:/\.css$/},a=>({path:a.path,namespace:'empty-css'}));b.onLoad({filter:/.*/,namespace:'empty-css'},()=>({contents:'',loader:'js'}))}}]})
 const {CollectionLinks,LinkedCollections,CollectionPreview}=await import(pathToFileURL(dir+'/bundle.mjs'))
 let chosen
 await act(async()=>root.render(React.createElement(CollectionLinks,{ids:['a'],onChange:ids=>{chosen=ids}})));await settle()
 const opener=[...document.querySelectorAll('button')].find(b=>b.textContent.includes('Link collections'));opener.focus();await act(async()=>opener.click());await settle()
 assert.equal(document.querySelectorAll('[type=checkbox]').length,2)
 assert.ok(document.querySelectorAll('[type=checkbox]')[0].checked)
 await act(async()=>document.querySelectorAll('[type=checkbox]')[1].click())
 await act(async()=>[...document.querySelectorAll('button')].find(b=>b.textContent==='Link selected').click());await settle()
 assert.deepEqual(chosen,['a','b']);assert.equal(document.querySelector('[role=dialog]'),null);assert.ok(document.activeElement===opener)
 await act(async()=>root.render(React.createElement(LinkedCollections,{ids:['a']})));await settle()
 assert.equal(document.querySelectorAll('figure').length,0,'linked collection does not dump its photos inline')
 const open=[...document.querySelectorAll('button')].find(b=>b.textContent.includes('Christmas'));open.focus();await act(async()=>open.click());await settle()
 assert.ok(document.querySelector('[role=dialog].photo-viewer'))
 assert.equal(document.querySelector('.photo-viewer-image').alt,'GCF team')
 await act(async()=>document.querySelector('button[aria-label="Close gallery"]').click());await settle();assert.ok(document.activeElement===open)
 await act(async()=>root.render(React.createElement(CollectionPreview,{group:groups[0],compact:true})))
 assert.ok(document.querySelector('button').textContent.includes('Open gallery'))
 assert.equal(document.querySelectorAll('figure').length,0)
 console.log('PASS: collection multiselect, focus restoration, linked gallery opener, scroll view and compact individual-photo preview')
}finally{await act(async()=>root.unmount());dom.window.close();rmSync(dir,{recursive:true,force:true})}
