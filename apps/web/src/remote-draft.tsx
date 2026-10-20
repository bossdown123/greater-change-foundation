import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from "react"
import { createPortal } from "react-dom"
import { api, errorText } from "./admin"
import { onChange, useRealtime } from "./realtime"
import { Button } from "@/components/ui/button"
import { RichContent, RICH_PREFIX } from "./rich-document"
import { changedFields, liveConflicts, type PeerDraft } from "./collaboration-state"
import { mergeDraft, type Conflict } from "./merge-draft"
type RecordDraft={id?:string;updated_at?:string}
type NamedConflict=Conflict&{source?:string;connection_id?:string}
function Value({value}:{value:unknown}){return typeof value==="string"&&value.startsWith(RICH_PREFIX)?<RichContent value={value}/>:<pre>{typeof value==="string"?value:JSON.stringify(value,null,2)}</pre>}
export function useRemoteDraft<T extends RecordDraft>(kind:string,draft:T,setDraft:Dispatch<SetStateAction<T>>,snapshot:string,setSnapshot:(s:string)=>void,paused=false){
 const [conflicts,setConflicts]=useState<Conflict[]>([]),[problem,setProblem]=useState(""),[peers,setPeers]=useState<PeerDraft[]>([]),[,changed]=useState(0)
 const {sendDraft,people,connected}=useRealtime(),send=useRef(sendDraft);send.current=sendDraft
 const acknowledged=useRef(new Map<string,string>()),pending=useRef(false),refresh=useRef(()=>{}),current=useRef({draft,snapshot,setDraft,setSnapshot,paused});current.current={draft,snapshot,setDraft,setSnapshot,paused}
 useEffect(()=>{
  let active=true,timer:ReturnType<typeof setTimeout>,generation=0
  function receive(remote:T,request:number){if(!active||request!==generation)return;if(current.current.paused){pending.current=true;return}const state=current.current,base=JSON.parse(state.snapshot) as T,local=state.draft
   const {next,conflicts:found}=mergeDraft(base,local,remote)
   setConflicts(existing=>[...existing.filter(c=>!found.some(f=>f.field===c.field)),...found]);state.setDraft(next);state.setSnapshot(JSON.stringify(remote));setProblem("")
  }
  const reload=()=>{if(!current.current.draft.id)return;if(current.current.paused){pending.current=true;return}clearTimeout(timer);const request=++generation;timer=setTimeout(()=>{void api<T>(`/${kind}/${current.current.draft.id}`).then(remote=>receive(remote,request)).catch(e=>{if(active&&request===generation)setProblem(errorText(e))})},180)}
  refresh.current=reload
  const stop=onChange(reload)
  return()=>{active=false;clearTimeout(timer);stop()}
 },[kind,draft.id])
 useEffect(()=>{if(!paused&&pending.current){pending.current=false;refresh.current()}},[paused])
 useEffect(()=>{const listener=(event:Event)=>{const peer=(event as CustomEvent<PeerDraft>).detail;if(peer.kind===kind&&peer.id===current.current.draft.id)setPeers(old=>[...old.filter(p=>p.connection_id!==peer.connection_id),peer])};window.addEventListener("gcf:draft",listener);return()=>window.removeEventListener("gcf:draft",listener)},[kind,draft.id])
 useEffect(()=>{if(!draft.id||!connected)return;const timer=setTimeout(()=>send.current({kind,id:draft.id!,fields:changedFields(draft,JSON.parse(snapshot))}),300);return()=>clearTimeout(timer)},[kind,draft.id,JSON.stringify(draft),snapshot,connected])
 useEffect(()=>()=>{if(draft.id)send.current({kind,id:draft.id,fields:{}})},[kind,draft.id])
 useEffect(()=>{const connections=new Set(people.map(p=>p.connection_id));setPeers(old=>old.filter(p=>connections.has(p.connection_id)))},[people])
 const live=liveConflicts(draft,JSON.parse(snapshot),peers,acknowledged.current)
 const all:NamedConflict[]=[...conflicts.map(c=>({...c,mine:(draft as Record<string,unknown>)[c.field]})),...live.filter(c=>!conflicts.some(saved=>saved.field===c.field))]
 function resolve(conflict:NamedConflict,mine:boolean){if(!mine)setDraft(d=>({...d,[conflict.field]:conflict.theirs}));if(conflict.connection_id){acknowledged.current.set(`${conflict.connection_id}/${conflict.field}`,JSON.stringify(conflict.theirs));changed(n=>n+1)}else setConflicts(c=>c.filter(row=>row.field!==conflict.field))}
 const blocked=all.length>0||!!problem
 const panel=blocked?<section className="remote-conflicts" aria-label="Conflicting edits">{problem&&<p role="alert">{problem}</p>}{all.map(c=><div key={`${c.connection_id||"saved"}/${c.field}`}><p role="status">{c.source||"Another editor"} also changed {c.field==="summary"?"the story":c.field.replaceAll("_"," ")}.</p><details><summary>Compare changes</summary><strong>Yours</strong><Value value={c.mine}/><strong>Theirs</strong><Value value={c.theirs}/></details><Button type="button" variant="outline" onClick={()=>resolve(c,true)}>Keep mine</Button><Button type="button" variant="outline" onClick={()=>resolve(c,false)}>Use theirs</Button></div>)}</section>:null
 const host=typeof document!=="undefined"?document.querySelector(".configuration-panel"):null
 return {blocked,panel:panel&&host?createPortal(panel,host):panel}
}
