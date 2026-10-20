import assert from 'node:assert/strict'
import { mergeDraft } from './src/merge-draft.ts'
const base={title:'Food drive',summary:'Original',dates:['2026-10-20'],updated_at:'a',modifier_name:'One'}
const local={...base,title:'My title'}
const remote={...base,summary:'Their story',updated_at:'b',modifier_name:'Two'}
let merged=mergeDraft(base,local,remote)
assert.equal(merged.next.title,'My title')
assert.equal(merged.next.summary,'Their story')
assert.equal(merged.next.updated_at,'b')
assert.equal(merged.conflicts.length,0)
merged=mergeDraft(base,local,{...remote,title:'Their title'})
assert.equal(merged.next.title,'My title')
assert.deepEqual(merged.conflicts,[{field:'title',mine:'My title',theirs:'Their title'}])
assert.equal(mergeDraft(base,local,{...remote,title:'My title'}).conflicts.length,0)
assert.equal(mergeDraft(base,{...local,dates:[]},{...remote,dates:['2027-01-01']}).conflicts[0].field,'dates')
console.log('PASS: non-overlapping merge, local typing preserved, conflict detection, matching saves, repeating dates')
