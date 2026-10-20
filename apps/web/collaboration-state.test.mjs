import assert from 'node:assert/strict'
import {changedFields,liveConflicts} from './src/collaboration-state.ts'
const base={title:'Title',summary:'Before',updated_at:'v1',created_by:'private'},local={...base,summary:'Mine'}
const peer={kind:'events',id:'event',actor_id:'second-account',connection_id:'tab2',name:'Another member',fields:{summary:'Theirs'}}
assert.deepEqual(changedFields(local,base),{summary:'Mine'})
const acknowledged=new Map()
assert.equal(liveConflicts(local,base,[peer],acknowledged).length,1)
assert.equal(liveConflicts(local,base,[{...peer,actor_id:'same-account'}],acknowledged).length,1)
assert.equal(liveConflicts(local,base,[{...peer,fields:{title:'Other field'}}],acknowledged).length,0)
assert.equal(liveConflicts(local,base,[{...peer,fields:{summary:'Mine'}}],acknowledged).length,0)
acknowledged.set('tab2/summary',JSON.stringify('Theirs'))
assert.equal(liveConflicts(local,base,[peer],acknowledged).length,0)
assert.equal(liveConflicts(local,base,[{...peer,fields:{summary:'Changed again'}}],acknowledged).length,1)
assert.equal(liveConflicts(local,base,[{...peer,fields:{}}],acknowledged).length,0)
console.log('PASS: live unsaved conflicts across accounts/tabs, matching and separate fields, explicit resolution and renewed edits')
