import assert from 'node:assert/strict'
import { mkdtempSync,readFileSync,writeFileSync,rmSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import ts from 'typescript'
import { renderToStaticMarkup } from 'react-dom/server'
const temp=mkdtempSync(new URL('./.rich-test-',import.meta.url))
try{
 const file=temp+'/document.mjs';writeFileSync(file,ts.transpileModule(readFileSync(new URL('./src/rich-document.tsx',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.ESNext,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText)
 const {readDocument,writeDocument,documentText,RichContent,documentHTML}=await import(pathToFileURL(file))
 const value=writeDocument({type:'doc',content:[{type:'paragraph',content:[{type:'text',text:'<script>literal prose</script>',marks:[{type:'bold'}]}]},{type:'gcfFigure',attrs:{mediaId:'a'.repeat(32),alt:'GCF'},content:[{type:'text',text:'Our community'}]}]})
 assert.equal(readDocument('Old prose').content[0].content[0].text,'Old prose')
 const html=renderToStaticMarkup(RichContent({value}))
 assert.match(html,/<strong>&lt;script&gt;/)
 assert.match(html,/<figure>/);assert.match(html,/<figcaption>Our community<\/figcaption>/)
 assert.ok(!html.includes('<script>'))
 globalThis.location={origin:'https://example.test'}
 const exported=documentHTML(value)
 assert.match(exported,/Figure 1/);assert.match(exported,/Our community/)
 assert.match(documentText(value),/literal prose/)
 const hostile=writeDocument({type:'doc',content:[{type:'paragraph',content:[{type:'text',text:'link',marks:[{type:'link',attrs:{href:'javascript:bad'}}]}]}]})
 assert.ok(!renderToStaticMarkup(RichContent({value:hostile})).includes('javascript:'))
 console.log('PASS: legacy text, rich formatting, figure captions, safe React rendering and HTML export')
}finally{rmSync(temp,{recursive:true,force:true})}
