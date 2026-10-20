import assert from 'node:assert/strict'
import {mergeLiveField} from './src/live-fields.ts'
assert.deepEqual(mergeLiveField('Before','Before','Typing live'),{value:'Typing live',conflict:false})
assert.deepEqual(mergeLiveField('A story','New A story','A story today'),{value:'New A story today',conflict:false})
assert.equal(mergeLiveField('Before','Mine','Theirs').conflict,true)
assert.equal(mergeLiveField(3,5,7).conflict,true)
assert.equal(mergeLiveField('USD','AUD','USX',false).conflict,true)
const rich=text=>'gcf-richtext:'+JSON.stringify({type:'doc',content:[{type:'paragraph',content:[{type:'text',text}]}]})
assert.deepEqual(mergeLiveField(rich('A story'),rich('New A story'),rich('A story today')),{value:rich('New A story today'),conflict:false})
assert.equal(mergeLiveField(rich('Before'),rich('Mine'),rich('Theirs')).conflict,true)
console.log('PASS: live text and rich-text updates, independent edits merge and overlapping edits remain conflicts')
