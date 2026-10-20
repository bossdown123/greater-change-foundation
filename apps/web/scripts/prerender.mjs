// Public content is built independently of all authenticated/admin data.
import { build } from 'esbuild'
import { mkdir, readFile, writeFile, rm } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { renderToString } from 'react-dom/server'
import React from 'react'
const bundle = '.public-render.mjs'
try {
 await build({stdin:{contents:`export {PublicSite} from './src/public-site/public-site'; export {publicPaths,pageMeta,siteOrigin} from './src/public-site/content'`,resolveDir:process.cwd(),loader:'tsx'},outfile:bundle,bundle:true,platform:'node',format:'esm',packages:'external',loader:{'.css':'empty'}})
 const {PublicSite,publicPaths,pageMeta,siteOrigin} = await import(pathToFileURL(`${process.cwd()}/${bundle}`))
 const shell = await readFile('dist/index.html','utf8')
 const escape = text => text.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
 await mkdir('dist/pages',{recursive:true})
 for (const path of [...publicPaths, '/404']) {
  const meta=pageMeta(path),canonical=siteOrigin+path
  const extra=`<link rel="canonical" href="${canonical}"><meta property="og:type" content="${path.startsWith('/our-work/')?'article':'website'}"><meta property="og:title" content="${escape(meta.title)}"><meta property="og:description" content="${escape(meta.description)}"><meta property="og:url" content="${canonical}"><meta property="og:image" content="${siteOrigin+meta.image}"><meta name="twitter:card" content="summary_large_image">`
  const metadata=path==='/404'?'<meta name="robots" content="noindex,nofollow">':extra
  const html=shell.replace(/<title>.*?<\/title>/,`<title>${escape(meta.title)}</title>`).replace(/<meta name="description"[^>]+>/,`<meta name="description" content="${escape(meta.description)}">`).replace('</head>',metadata+'</head>').replace('<div id="root"></div>',`<div id="root">${renderToString(React.createElement(PublicSite,{path}))}</div>`)
  await writeFile(path==='/'?'dist/index.html':`dist/pages/${path.slice(1).replaceAll('/','--')}.html`,html)
 }
 // Admin must not hydrate public content or inherit public canonical metadata.
 await writeFile('dist/admin.html',shell.replace(/<title>.*?<\/title>/,'<title>GCF member workspace</title>').replace('</head>','<meta name="robots" content="noindex,nofollow"></head>'))
 await writeFile('dist/robots.txt',`User-agent: *\nDisallow: /admin\nDisallow: /api/\nSitemap: ${siteOrigin}/sitemap.xml\n`)
 await writeFile('dist/sitemap.xml',`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${publicPaths.map(p=>`<url><loc>${siteOrigin+p}</loc></url>`).join('')}</urlset>`)
 console.log(`Prerendered ${publicPaths.length} public pages; admin content remains private.`)
} finally { await rm(bundle,{force:true}) }
