// Isolated rendering/interaction checks. No browser, remote site, or private account.
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,readdirSync,existsSync,rmSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
import {build} from 'esbuild'
import {JSDOM} from 'jsdom'
const dir=mkdtempSync(new URL('./.public-test-',import.meta.url))
const dom=new JSDOM('<!doctype html><html><body><div id="test"></div></body></html>',{url:'http://localhost/'})
Object.assign(globalThis,{window:dom.window,document:dom.window.document,HTMLElement:dom.window.HTMLElement,HTMLInputElement:dom.window.HTMLInputElement,Node:dom.window.Node,NodeFilter:dom.window.NodeFilter,MutationObserver:dom.window.MutationObserver,CustomEvent:dom.window.CustomEvent,Event:dom.window.Event,IS_REACT_ACT_ENVIRONMENT:true})
globalThis.getComputedStyle=dom.window.getComputedStyle.bind(dom.window)
globalThis.requestAnimationFrame=fn=>setTimeout(fn,0);globalThis.cancelAnimationFrame=clearTimeout
const React=await import('react'),{act}=React,{createRoot}=await import('react-dom/client')
const container=document.getElementById('test'),root=createRoot(container)
try {
 await build({stdin:{contents:`export {PublicSite} from './src/public-site/public-site'; export * from './src/public-site/content';`,resolveDir:process.cwd(),loader:'tsx'},outfile:dir+'/bundle.mjs',bundle:true,platform:'node',format:'esm',packages:'external',loader:{'.css':'empty'},jsx:'automatic'})
 const {PublicSite,publicPaths,stories,storyPath}=await import(pathToFileURL(dir+'/bundle.mjs'))
 const show=async path=>act(async()=>root.render(React.createElement(PublicSite,{path})))
 for(const path of publicPaths){
  await show(path)
  assert.equal(document.querySelectorAll('h1').length,1,path+' has one h1')
  assert.ok(document.querySelector('main#main-content'))
  assert.equal(document.querySelectorAll('form').length,0,'no pretend form submission')
  for(const link of document.querySelectorAll('a[href^="/"]')) assert.ok(publicPaths.includes(link.getAttribute('href').split('#')[0]) || link.getAttribute('href')==='/admin','known internal destination '+link.href)
  for(const image of document.images){assert.ok(image.hasAttribute('alt'));assert.ok(existsSync('public'+image.getAttribute('src')))}
 }
 await show('/our-work')
 const category=[...document.querySelectorAll('.gcf-filters button')].find(b=>b.textContent==='Health')
 await act(async()=>category.click())
 assert.equal(document.querySelectorAll('.gcf-work-story').length,1)
 assert.match(document.querySelector('.gcf-work-story').textContent,/Showing up for one another/)
 await act(async()=>document.querySelector('.gcf-filters button').click())
 assert.equal(document.querySelectorAll('.gcf-work-story').length,stories.length)
 const search=document.querySelector('input[type=search]')
 await act(async()=>{Object.getOwnPropertyDescriptor(dom.window.HTMLInputElement.prototype,'value').set.call(search,'no matching story');search.dispatchEvent(new dom.window.Event('input',{bubbles:true}))})
 assert.ok(document.querySelector('.gcf-no-results'),'search provides a clear empty result')
 await act(async()=>document.querySelector('.gcf-no-results button').click())
 assert.equal(document.querySelectorAll('.gcf-work-story').length,stories.length)
 const menu=document.querySelector('.gcf-menu-toggle')
 await act(async()=>menu.click());assert.equal(menu.getAttribute('aria-expanded'),'true')
 await act(async()=>menu.click());assert.equal(menu.getAttribute('aria-expanded'),'false')
 await show(storyPath(stories[0]))
 const opener=document.querySelector('.gcf-photo-open');opener.focus();await act(async()=>opener.click())
 assert.ok(document.querySelector('[role=dialog]'))
 assert.equal(document.querySelector('[role=dialog] img').alt,stories[0].photos[1].alt)
 await act(async()=>document.querySelector('.gcf-lightbox-close').click());await act(async()=>new Promise(r=>setTimeout(r,20)))
 assert.equal(document.querySelector('[role=dialog]'),null)
 assert.ok(document.activeElement===opener,'lightbox restores focus to the photograph')
 for(const path of publicPaths){
  const file=path==='/'?'dist/index.html':`dist/pages/${path.slice(1).replaceAll('/','--')}.html`,html=readFileSync(file,'utf8'),page=new JSDOM(html)
  assert.ok(page.window.document.querySelector('h1'),'prerendered content '+path)
  assert.equal(page.window.document.querySelector('[rel=canonical]').href,'https://greaterchangefoundation.org'+path)
  assert.ok(page.window.document.querySelector('meta[property="og:image"]'))
  assert.ok(!html.includes('/api/admin/') && !html.includes('UNDER DEVELOPMENT'),'public pages contain no private API assets or old placeholder')
 }
 const admin=readFileSync('dist/admin.html','utf8');assert.match(admin,/noindex,nofollow/);assert.ok(!admin.includes('Small acts.'))
 const files=readdirSync('public/assets/stories');for(const file of files) assert.ok(/\.webp$/.test(file))
 console.log('PASS: all public routes, source assets, category/search/reset, mobile menu, image dialog/focus, prerendered SEO, and private/public separation')
} finally {await act(async()=>root.unmount());dom.window.close();rmSync(dir,{recursive:true,force:true})}
