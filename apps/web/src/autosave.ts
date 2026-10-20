export const AUTOSAVE_INTERVAL_MS = 5 * 60 * 1000
export type AutosaveState={dirty:boolean;paused:boolean}
/** One deadline per dirty period. Typing never postpones it; confirmed saves do. */
export function createAutosave({state,save,now=Date.now,schedule=(run,delay)=>setTimeout(run,delay),cancel=timer=>clearTimeout(timer)}:{state:()=>AutosaveState;save:()=>void|Promise<void>;now?:()=>number;schedule?:(run:()=>void,delay:number)=>ReturnType<typeof setTimeout>;cancel?:(timer:ReturnType<typeof setTimeout>)=>void}){
 let deadline:number|null=null,timer:ReturnType<typeof setTimeout>|undefined,disposed=false
 function clear(){if(timer!==undefined)cancel(timer);timer=undefined}
 function update(){
  clear();if(disposed)return
  const current=state();if(!current.dirty){deadline=null;return}
  deadline??=now()+AUTOSAVE_INTERVAL_MS
  if(current.paused)return
  timer=schedule(()=>{
   timer=undefined;if(disposed)return
   const latest=state();if(!latest.dirty||latest.paused){update();return}
   deadline=now()+AUTOSAVE_INTERVAL_MS
   // The editor reports failures while retaining its dirty state for the next attempt.
   try{void Promise.resolve(save()).catch(()=>{})}catch{/* editor owns error feedback */}
   update()
  },Math.max(0,deadline-now()))
 }
 return {update,saved(){deadline=state().dirty?now()+AUTOSAVE_INTERVAL_MS:null;update()},dispose(){disposed=true;clear()}}
}
