import assert from 'node:assert/strict'
import { createAutosave,AUTOSAVE_INTERVAL_MS } from './src/autosave.ts'
function fixture(){let time=0,count=0;const state={dirty:false,paused:false},tasks=new Map();let next=0
 const clock=createAutosave({state:()=>state,save:()=>{count++},now:()=>time,schedule:(run,delay)=>{const id=++next;tasks.set(id,{run,at:time+delay});return id},cancel:id=>tasks.delete(id)})
 function advance(ms){const target=time+ms;while(true){const task=[...tasks].sort((a,b)=>a[1].at-b[1].at)[0];if(!task||task[1].at>target)break;tasks.delete(task[0]);time=task[1].at;task[1].run()}time=target}
 return {clock,state,advance,count:()=>count,tasks}
}
assert.equal(AUTOSAVE_INTERVAL_MS,300000)
let f=fixture();f.clock.update();f.advance(600000);assert.equal(f.count(),0,'clean drafts never create save requests')
f.state.dirty=true;f.clock.update();f.advance(100000);f.clock.update();f.advance(199999);assert.equal(f.count(),0);f.advance(1);assert.equal(f.count(),1,'typing cannot postpone the five-minute deadline')
f.clock.dispose()
f=fixture();f.state.dirty=true;f.clock.update();f.advance(200000);f.clock.saved();f.advance(100000);assert.equal(f.count(),0,'manual saves reset the interval');f.advance(200000);assert.equal(f.count(),1);f.clock.dispose()
f=fixture();f.state.dirty=true;f.clock.update();f.state.paused=true;f.clock.update();f.advance(400000);assert.equal(f.count(),0,'conflicts, in-flight requests and offline state pause writes');f.state.paused=false;f.clock.update();f.advance(0);assert.equal(f.count(),1,'overdue drafts save after resuming');f.clock.dispose()
f=fixture();f.state.dirty=true;f.clock.update();f.clock.dispose();f.advance(600000);assert.equal(f.count(),0,'leaving an editor cancels its timer')
console.log('PASS: five-minute autosave, no debounce starvation, clean drafts, manual saves, paused/resumed deadlines and cleanup')
