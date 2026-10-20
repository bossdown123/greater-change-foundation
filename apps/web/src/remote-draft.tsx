import { useEffect, useLayoutEffect, useRef, useState, type Dispatch, type SetStateAction } from "react"
import { createPortal } from "react-dom"
import { api, errorText } from "./admin"
import { onChange, useRealtime } from "./realtime"
import { Button } from "@/components/ui/button"
import { RichContent, RICH_PREFIX } from "./rich-document"
import { changedFields, equalValue, liveConflicts, type PeerDraft } from "./collaboration-state"
import { mergeDraft, type Conflict } from "./merge-draft"
import { preserveNativeCaret } from "./cursor-position"
import { mergeLiveField } from "./live-fields"
type RecordDraft={id?:string;updated_at?:string}
type NamedConflict=Conflict&{source?:string;connection_id?:string}
function Value({value}:{value:unknown}){return typeof value==="string"&&value.startsWith(RICH_PREFIX)?<RichContent value={value}/>:<pre>{typeof value==="string"?value:JSON.stringify(value,null,2)}</pre>}
export function useRemoteDraft<T extends RecordDraft>(kind:string,draft:T,setDraft:Dispatch<SetStateAction<T>>,snapshot:string,setSnapshot:(s:string)=>void,paused=false){
 const [conflicts,setConflicts]=useState<Conflict[]>([]),[problem,setProblem]=useState(""),[peers,setPeers]=useState<PeerDraft[]>([]),[,changed]=useState(0)
 const {sendDraft,people,connected}=useRealtime(),send=useRef(sendDraft);send.current=sendDraft
 const restoreCaret=useRef<(()=>void)|undefined>(undefined)
 useLayoutEffect(()=>{restoreCaret.current?.();restoreCaret.current=undefined},[draft])
 const broadcastTimer=useRef<ReturnType<typeof setTimeout>|undefined>(undefined)
 const applied=useRef<Record<string,unknown>>({}),previousPeers=useRef(new Map<string,PeerDraft>())
 const sharedBaseline=()=>({...JSON.parse(current.current.snapshot),...applied.current})
 const acknowledged=useRef(new Map<string,string>()),pending=useRef(false),refresh=useRef(()=>{}),current=useRef({draft,snapshot,setDraft,setSnapshot,paused});current.current={draft,snapshot,setDraft,setSnapshot,paused}
 useEffect(()=>{
  let active=true,timer:ReturnType<typeof setTimeout>,generation=0
  function receive(remote:T,request:number){if(!active||request!==generation)return;if(current.current.paused){pending.current=true;return}const state=current.current,base=JSON.parse(state.snapshot) as T,local=state.draft
   const {next,conflicts:found}=mergeDraft(base,local,remote)
   for(const field of Object.keys(applied.current))if(!equalValue((base as Record<string,unknown>)[field],(remote as Record<string,unknown>)[field])||equalValue(applied.current[field],(remote as Record<string,unknown>)[field]))delete applied.current[field]
   setConflicts(existing=>[...existing.filter(c=>!found.some(f=>f.field===c.field)),...found]);state.setDraft(next);state.setSnapshot(JSON.stringify(remote));setProblem("")
  }
  const reload=()=>{if(!current.current.draft.id)return;if(current.current.paused){pending.current=true;return}clearTimeout(timer);const request=++generation;timer=setTimeout(()=>{void api<T>(`/${kind}/${current.current.draft.id}`).then(remote=>receive(remote,request)).catch(e=>{if(active&&request===generation)setProblem(errorText(e))})},180)}
  refresh.current=reload
  const stop=onChange(reload)
  return()=>{active=false;clearTimeout(timer);stop()}
 },[kind,draft.id])
 useEffect(()=>{if(!paused&&pending.current){pending.current=false;refresh.current()}},[paused])
 useEffect(()=>{
  applied.current={};previousPeers.current.clear();setPeers([]);acknowledged.current.clear()
  let composing=false;const queued=new Map<string,PeerDraft>()
  const apply=(peer:PeerDraft)=>{
   if(peer.kind!==kind||peer.id!==current.current.draft.id)return
   const state=current.current,baseline=sharedBaseline(),prior=previousPeers.current.get(peer.connection_id),next={...state.draft} as Record<string,unknown>
   let modified=false
   for(const [field,value] of Object.entries(peer.fields)){
    const provided=peer.base_fields&&field in peer.base_fields?peer.base_fields[field]:baseline[field]
    const base=prior&&field in prior.fields&&(!peer.base_fields||equalValue(prior.base_fields?.[field],provided))?prior.fields[field]:provided
    const result=mergeLiveField(base,next[field],value,["title","summary","introduction","body","alt","caption"].includes(field))
    if(!result.conflict){acknowledged.current.set(`${peer.connection_id}/${field}`,JSON.stringify(value));applied.current[field]=value;if(!equalValue(next[field],result.value)){next[field]=result.value;modified=true}}
   }
   previousPeers.current.set(peer.connection_id,{...peer,fields:{...prior?.fields,...peer.fields},base_fields:{...prior?.base_fields,...peer.base_fields}})
   if(modified){restoreCaret.current=preserveNativeCaret();current.current={...state,draft:next as T};state.setDraft(next as T)}
   setPeers(old=>[...old.filter(p=>p.connection_id!==peer.connection_id),peer])
  }
  const listener=(event:Event)=>{const peer=(event as CustomEvent<PeerDraft>).detail;if(composing)queued.set(peer.connection_id,peer);else apply(peer)}
  const compositionStart=()=>{composing=true}
  const compositionEnd=()=>{composing=false;setTimeout(()=>{for(const peer of queued.values())apply(peer);queued.clear()},0)}
  window.addEventListener("gcf:draft",listener);document.addEventListener("compositionstart",compositionStart);document.addEventListener("compositionend",compositionEnd)
  return()=>{window.removeEventListener("gcf:draft",listener);document.removeEventListener("compositionstart",compositionStart);document.removeEventListener("compositionend",compositionEnd);queued.clear()}
 },[kind,draft.id])
 useEffect(()=>{if(!draft.id||!connected){clearTimeout(broadcastTimer.current);broadcastTimer.current=undefined;return}if(broadcastTimer.current)return;broadcastTimer.current=setTimeout(()=>{broadcastTimer.current=undefined;const baseline=sharedBaseline(),fields=changedFields(current.current.draft,baseline);send.current({kind,id:draft.id!,fields,base_fields:Object.fromEntries(Object.keys(fields).map(field=>[field,baseline[field]]))})},100)},[kind,draft.id,JSON.stringify(draft),snapshot,connected,people.map(p=>p.connection_id).sort().join(",")])
 useEffect(()=>()=>{clearTimeout(broadcastTimer.current);broadcastTimer.current=undefined;if(draft.id)send.current({kind,id:draft.id,fields:{}})},[kind,draft.id])
 useEffect(()=>{const connections=new Set(people.map(p=>p.connection_id));setPeers(old=>old.filter(p=>connections.has(p.connection_id)))},[people])
 const live=liveConflicts(draft,{...JSON.parse(snapshot),...applied.current},peers,acknowledged.current)
 const all:NamedConflict[]=[...conflicts.map(c=>({...c,mine:(draft as Record<string,unknown>)[c.field]})),...live.filter(c=>!conflicts.some(saved=>saved.field===c.field))]
 function resolve(conflict:NamedConflict,mine:boolean){if(!mine){applied.current[conflict.field]=conflict.theirs;}if(!mine)setDraft(d=>({...d,[conflict.field]:conflict.theirs}));if(conflict.connection_id){acknowledged.current.set(`${conflict.connection_id}/${conflict.field}`,JSON.stringify(conflict.theirs));changed(n=>n+1)}else setConflicts(c=>c.filter(row=>row.field!==conflict.field))}
 const blocked=all.length>0||!!problem
 const panel=blocked?<section className="remote-conflicts" aria-label="Conflicting edits">{problem&&<p role="alert">{problem}</p>}{all.map(c=><div key={`${c.connection_id||"saved"}/${c.field}`}><p role="status">{c.source||"Another editor"} also changed {c.field==="summary"?"the story":c.field.replaceAll("_"," ")}.</p><details><summary>Compare changes</summary><strong>Yours</strong><Value value={c.mine}/><strong>Theirs</strong><Value value={c.theirs}/></details><Button type="button" variant="outline" onClick={()=>resolve(c,true)}>Keep mine</Button><Button type="button" variant="outline" onClick={()=>resolve(c,false)}>Use theirs</Button></div>)}</section>:null
 const host=typeof document!=="undefined"?document.querySelector(".configuration-panel"):null
 return {blocked,panel:panel&&host?createPortal(panel,host):panel}
}
