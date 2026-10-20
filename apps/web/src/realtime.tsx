import { createContext, useContext, useEffect, useId, useLayoutEffect, useRef, useState } from "react"
import { createPortal } from "react-dom"
import { Socket, Presence, type Channel } from "phoenix"
import { api } from "./admin"
import type { PeerDraft } from "./collaboration-state"
import { fieldPresenceShape } from "./field-presence-shape"
export type Activity={name:string;color:string;section:string;resource_id:string|null;title:string|null;editing:boolean;field?:string|null;interacted_at?:number;connection_id?:string}
export type Collaborator=Activity&{id:string}
export type Change={id:string;actor_id:string;operation:string;resource_type:string;resource_id:string|null}
export const RealtimeContext=createContext<{people:Collaborator[];connected:boolean;userId?:string;locate:(activity:Partial<Activity>)=>void;sendDraft:(draft:{kind:string;id:string;fields:Record<string,unknown>})=>void}>({people:[],connected:false,locate:()=>{},sendDraft:()=>{}})
export const useRealtime=()=>useContext(RealtimeContext)
export function onChange(handler:(change:Change)=>void){const listener=(e:Event)=>handler((e as CustomEvent<Change>).detail);window.addEventListener("gcf:changed",listener);return()=>window.removeEventListener("gcf:changed",listener)}
export function useChangeVersion(){const [version,setVersion]=useState(0);useEffect(()=>onChange(()=>setVersion(v=>v+1)),[]);return version}
export function RealtimeProvider({userId,activity,onRevoked,children}:{userId?:string;activity:Partial<Activity>;onRevoked:()=>void;children:React.ReactNode}){
 const [people,setPeople]=useState<Collaborator[]>([]),[connected,setConnected]=useState(false),channel=useRef<Channel|null>(null),current=useRef(activity),revoke=useRef(onRevoked)
 revoke.current=onRevoked
 const locate=(next:Partial<Activity>)=>{current.current={...current.current,...next};channel.current?.push("location",current.current)}
 useEffect(()=>{locate(activity)},[activity.section,activity.resource_id,activity.title,activity.editing])
 useEffect(()=>{locate({field:null})},[activity.section,activity.resource_id])
 useEffect(()=>{
  if(!userId)return
  let stopped=false,socket:Socket|undefined,timer:ReturnType<typeof setTimeout>|undefined
  function retry(){if(stopped)return;setConnected(false);setPeople([]);channel.current=null;socket?.disconnect();clearTimeout(timer);timer=setTimeout(()=>void connect(),2000)}
  async function connect(){try{
   const {token}=await api<{token:string}>("/realtime-token");if(stopped)return
   socket=new Socket("/live",{params:{token}});const localSocket=socket;let failed=false;const fail=()=>{if(failed||stopped)return;failed=true;retry()};const room=socket.channel("admin:workspace",{}),presence=new Presence(room);channel.current=room
   presence.onSync(()=>setPeople(presence.list((id,{metas})=>metas.map((meta:unknown)=>({...meta as Activity,id} as Collaborator))).flat()))
   room.on("draft",draft=>{window.dispatchEvent(new CustomEvent<PeerDraft>("gcf:draft",{detail:draft}))})
   room.on("changed",change=>{window.dispatchEvent(new CustomEvent("gcf:changed",{detail:change}))})
   room.on("revoked",()=>{stopped=true;socket?.disconnect();setConnected(false);setPeople([]);revoke.current()})
   room.onError(fail);localSocket.onClose(fail);localSocket.onError(fail)
   socket.connect();room.join().receive("ok",()=>{setConnected(true);room.push("location",current.current);window.dispatchEvent(new CustomEvent("gcf:changed",{detail:{resource_type:"reconnect"}}))}).receive("error",fail).receive("timeout",fail)
  }catch{retry()}}
  void connect();return()=>{stopped=true;clearTimeout(timer);channel.current=null;socket?.disconnect();setPeople([]);setConnected(false)}
 },[userId])
 return <RealtimeContext.Provider value={{people,connected,userId,locate,sendDraft:draft=>{channel.current?.push("draft",draft)}}}>{children}</RealtimeContext.Provider>
}
export function PresenceDots({section,resourceId}:{section:string;resourceId?:string}){
 const {people}=useRealtime(),unique=new Map<string,Collaborator>()
 for(const person of people)if(person.section===section&&(!resourceId||person.resource_id===resourceId))unique.set(person.id,person)
 if(!unique.size)return null
 const members=[...unique.values()].sort((a,b)=>a.id.localeCompare(b.id)),label=members.map(p=>`${p.name}${p.editing?` editing ${p.title||section}`:` viewing ${section}`}`).join("; ")
 return <span className="presence-dots" role="img" aria-label={label} title={label}>{members.map(p=><i key={p.id} style={{backgroundColor:p.color}}/>)}</span>
}
export function ConnectionStatus(){const {connected}=useRealtime();return connected?null:<span className="connection-status" role="status">Reconnecting…</span>}
// Attach field decoration directly to existing labels; no extra nested input containers.
export function CollaborativeFields({section,resourceId}:{section:string;resourceId?:string}){
 const {people,locate}=useRealtime(),[fields,setFields]=useState<{element:HTMLInputElement|HTMLTextAreaElement|HTMLDivElement;key:string;label:HTMLElement}[]>([]),last=useRef(0)
 useEffect(()=>{
  const root=document.querySelector(".workspace");if(!root)return
  let idle:ReturnType<typeof setTimeout>
  function scan(){const counts=new Map<string,number>();const rows=[...root!.querySelectorAll<HTMLInputElement|HTMLTextAreaElement|HTMLDivElement>(".editor input:not([type=checkbox]):not([type=password]),.editor textarea,.image-inspector textarea,.account-editor input:not([type=password]), .rich-field [contenteditable=true]")].flatMap(element=>{
    if(["file","hidden","submit"].includes((element as HTMLInputElement).type)||element.closest(".password-input"))return []
    const label=element.closest<HTMLElement>("label,.rich-field");if(!label)return []
    const text=element.getAttribute("aria-label")||(element as HTMLInputElement).name||[...label.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join("").trim()||(element as HTMLInputElement).placeholder||(element as HTMLInputElement).type
    const index=counts.get(text)||0;counts.set(text,index+1);const key=`${text}:${index}`
    element.dataset.collabField=key;if(!element.hasAttribute("aria-label"))element.setAttribute("aria-label",text);label.classList.add("collaborative-label");return [{element,key,label}]
  });setFields(previous=>previous.length===rows.length&&previous.every((p,i)=>p.element===rows[i].element&&p.key===rows[i].key)?previous:rows)}
  scan();const observer=new MutationObserver(scan);observer.observe(root,{childList:true,subtree:true})
  function focus(e:Event){clearTimeout(idle);idle=setTimeout(()=>locate({field:null}),300000);const el=(e.target as HTMLElement).closest<HTMLElement>("[data-collab-field]");if(el?.dataset.collabField){const form=el.closest<HTMLFormElement>("form");locate({field:el.dataset.collabField,interacted_at:Date.now(),editing:true,...(form?.dataset.collabId?{resource_id:form.dataset.collabId,title:form.dataset.collabTitle}: {})})}}
  function input(e:Event){if(Date.now()-last.current>250){last.current=Date.now();focus(e)}}
  root.addEventListener("focusin",focus);root.addEventListener("input",input)
  return()=>{observer.disconnect();root.removeEventListener("focusin",focus);root.removeEventListener("input",input);clearTimeout(idle);locate({field:null});fields.forEach(({element,label})=>{element.style.removeProperty("--editor-color");element.classList.remove("collaborative-input");label.classList.remove("collaborative-label")})}
 },[section,resourceId])
 return <>{fields.map(({element,key,label})=>{
  const unique=new Map<string,Collaborator>();for(const p of people)if(p.section===section&&p.resource_id===(element.closest<HTMLFormElement>("form")?.dataset.collabId||resourceId||null)&&p.field===key){const prior=unique.get(p.id);if(!prior||(prior.interacted_at||0)<(p.interacted_at||0))unique.set(p.id,p)}
  const latest=[...unique.values()].sort((a,b)=>(b.interacted_at||0)-(a.interacted_at||0)),color=latest[0]?.color,editors=[...unique.values()].sort((a,b)=>a.name.localeCompare(b.name))
  element.classList.toggle("collaborative-input",!!color);if(color)element.setAttribute("aria-describedby",`field-presence-${key.replace(/[^a-z0-9]/gi,"-")}`);else if(element.getAttribute("aria-describedby")?.startsWith("field-presence-"))element.removeAttribute("aria-describedby");if(color)element.style.setProperty("--editor-color",color);else element.style.removeProperty("--editor-color")
  return color?createPortal(<FieldPresenceFrame element={element} label={label} field={key} editors={editors} color={color}/>,label,key):null
 })}</>
}

function FieldPresenceFrame({element,label,field,editors,color}:{element:HTMLElement;label:HTMLElement;field:string;editors:Collaborator[];color:string}){
 const clipId=useId(),badge=useRef<HTMLSpanElement>(null)
 const [box,setBox]=useState({left:0,top:0,width:0,height:0}),[tab,setTab]=useState({width:0,height:0})
 useLayoutEffect(()=>{
  const measure=()=>{
   const rect=element.getBoundingClientRect(),parent=label.getBoundingClientRect()
   // Leave a 2px gap between the native field and the outer 2px presence stroke.
   const next={left:rect.left-parent.left+label.scrollLeft-4,top:rect.top-parent.top+label.scrollTop-4,width:rect.width+8,height:rect.height+8}
   setBox(old=>JSON.stringify(old)===JSON.stringify(next)?old:next)
   if(badge.current){const rect=badge.current.getBoundingClientRect();setTab(old=>old.width===rect.width&&old.height===rect.height?old:{width:rect.width,height:rect.height})}
  }
  measure();const resize=new ResizeObserver(measure);resize.observe(element);resize.observe(label);if(badge.current)resize.observe(badge.current)
  window.addEventListener("resize",measure);return()=>{resize.disconnect();window.removeEventListener("resize",measure)}
 },[element,label])
 const shape=fieldPresenceShape(box.width,box.height,tab.width,tab.height)
 return <span className="field-presence-frame" style={{...box,"--editor-color":color} as React.CSSProperties}>
  <svg className="field-presence-outline" width={box.width} height={box.height+tab.height} aria-hidden="true">
   <defs><clipPath id={clipId}><path d={shape.tab}/></clipPath></defs>
   <g clipPath={`url(#${clipId})`}>{editors.map((person,index)=><rect key={person.id} className="field-presence-member-fill" x="0" y={box.height-1+index*tab.height/editors.length} width={box.width} height={tab.height/editors.length} style={{"--member-color":person.color} as React.CSSProperties}/>)}</g>
   <path className="field-presence-stroke" d={shape.outline} fill="none" strokeWidth="2"/>
  </svg>
  <span ref={badge} className="field-editors" role="status" id={`field-presence-${field.replace(/[^a-z0-9]/gi,'-')}`} aria-label={`Editing ${field.split(":")[0]}: ${editors.map(p=>p.name).join(", ")}`}>{editors.map(p=><span key={p.id} title={p.name}><i style={{background:p.color}}/>{p.name}</span>)}</span>
 </span>
}
