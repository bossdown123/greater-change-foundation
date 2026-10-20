import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from "react"
import { api, errorText } from "./admin"
import { onChange } from "./realtime"
import { Button } from "@/components/ui/button"
type RecordDraft={id?:string;updated_at?:string}
import { mergeDraft, type Conflict } from "./merge-draft"
export function useRemoteDraft<T extends RecordDraft>(kind:string,draft:T,setDraft:Dispatch<SetStateAction<T>>,snapshot:string,setSnapshot:(s:string)=>void,paused=false){
 const [conflicts,setConflicts]=useState<Conflict[]>([]),[problem,setProblem]=useState("")
 const pending=useRef(false),refresh=useRef(()=>{}),current=useRef({draft,snapshot,setDraft,setSnapshot,paused});current.current={draft,snapshot,setDraft,setSnapshot,paused}
 useEffect(()=>{
  let active=true,timer:ReturnType<typeof setTimeout>
  function receive(remote:T){if(!active)return;if(current.current.paused){pending.current=true;return}const state=current.current,base=JSON.parse(state.snapshot) as T,local=state.draft
   const {next,conflicts:found}=mergeDraft(base,local,remote)
   setConflicts(existing=>[...existing.filter(c=>!found.some(f=>f.field===c.field)),...found]);state.setDraft(next);state.setSnapshot(JSON.stringify(remote));setProblem("")
  }
  const reload=()=>{if(!current.current.draft.id)return;if(current.current.paused){pending.current=true;return}clearTimeout(timer);timer=setTimeout(()=>{void api<T>(`/${kind}/${current.current.draft.id}`).then(receive).catch(e=>{if(active)setProblem(errorText(e))})},180)}
  refresh.current=reload
  const stop=onChange(reload)
  return()=>{active=false;clearTimeout(timer);stop()}
 },[kind,draft.id])
 useEffect(()=>{if(!paused&&pending.current){pending.current=false;refresh.current()}},[paused])
 function resolve(conflict:Conflict,mine:boolean){if(!mine)setDraft(d=>({...d,[conflict.field]:conflict.theirs}));setConflicts(c=>c.filter(row=>row.field!==conflict.field))}
 const blocked=conflicts.length>0||!!problem
 return {blocked,panel:(blocked?<section className="remote-conflicts" aria-label="Changes from another editor">{problem&&<p role="alert">{problem}</p>}{conflicts.map(c=><div key={c.field}><p>Another editor changed {c.field.replaceAll("_"," ")}.</p><details><summary>Compare</summary><strong>Yours</strong><pre>{typeof c.mine==="string"?c.mine:JSON.stringify(c.mine,null,2)}</pre><strong>Theirs</strong><pre>{typeof c.theirs==="string"?c.theirs:JSON.stringify(c.theirs,null,2)}</pre></details><Button type="button" variant="outline" onClick={()=>resolve(c,true)}>Keep mine</Button><Button type="button" variant="outline" onClick={()=>resolve(c,false)}>Use theirs</Button></div>)}</section>:null)}
}
