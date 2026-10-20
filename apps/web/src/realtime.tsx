import { createContext, useContext, useEffect, useRef, useState } from "react"
import { createPortal } from "react-dom"
import { Socket, Presence, type Channel } from "phoenix"
import { api } from "./admin"
export type Activity={name:string;color:string;section:string;resource_id:string|null;title:string|null;editing:boolean;field?:string|null;interacted_at?:number}
export type Collaborator=Activity&{id:string}
export type Change={id:string;actor_id:string;operation:string;resource_type:string;resource_id:string|null}
const RealtimeContext=createContext<{people:Collaborator[];connected:boolean;userId?:string;locate:(activity:Partial<Activity>)=>void}>({people:[],connected:false,locate:()=>{}})
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
   room.on("changed",change=>{window.dispatchEvent(new CustomEvent("gcf:changed",{detail:change}))})
   room.on("revoked",()=>{stopped=true;socket?.disconnect();setConnected(false);setPeople([]);revoke.current()})
   room.onError(fail);localSocket.onClose(fail);localSocket.onError(fail)
   socket.connect();room.join().receive("ok",()=>{setConnected(true);room.push("location",current.current);window.dispatchEvent(new CustomEvent("gcf:changed",{detail:{resource_type:"reconnect"}}))}).receive("error",fail).receive("timeout",fail)
  }catch{retry()}}
  void connect();return()=>{stopped=true;clearTimeout(timer);channel.current=null;socket?.disconnect();setPeople([]);setConnected(false)}
 },[userId])
 return <RealtimeContext.Provider value={{people,connected,userId,locate}}>{children}</RealtimeContext.Provider>
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
 const {people,userId,locate}=useRealtime(),[fields,setFields]=useState<{element:HTMLInputElement|HTMLTextAreaElement;key:string;label:HTMLElement}[]>([]),last=useRef(0)
 useEffect(()=>{
  const root=document.querySelector(".workspace");if(!root)return
  function scan(){const counts=new Map<string,number>();const rows=[...root!.querySelectorAll<HTMLInputElement|HTMLTextAreaElement>(".editor input:not([type=checkbox]):not([type=password]),.editor textarea,.image-inspector textarea,.account-editor input:not([type=password])")].flatMap(element=>{
    if(["file","hidden","submit"].includes(element.type)||element.closest(".password-input"))return []
    const label=element.closest("label");if(!label)return []
    const text=element.getAttribute("aria-label")||element.name||[...label.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join("").trim()||element.placeholder||element.type
    const index=counts.get(text)||0;counts.set(text,index+1);const key=`${text}:${index}`
    element.dataset.collabField=key;if(!element.hasAttribute("aria-label"))element.setAttribute("aria-label",text);label.classList.add("collaborative-label");return [{element,key,label}]
  });setFields(previous=>previous.length===rows.length&&previous.every((p,i)=>p.element===rows[i].element&&p.key===rows[i].key)?previous:rows)}
  scan();const observer=new MutationObserver(scan);observer.observe(root,{childList:true,subtree:true})
  function focus(e:Event){const el=e.target as HTMLInputElement;if(el.dataset.collabField)locate({field:el.dataset.collabField,interacted_at:Date.now(),editing:true})}
  function input(e:Event){if(Date.now()-last.current>250){last.current=Date.now();focus(e)}}
  function blur(e:Event){if((e.target as HTMLElement).dataset.collabField)locate({field:null})}
  root.addEventListener("focusin",focus);root.addEventListener("input",input);root.addEventListener("focusout",blur)
  return()=>{observer.disconnect();root.removeEventListener("focusin",focus);root.removeEventListener("input",input);root.removeEventListener("focusout",blur);locate({field:null});fields.forEach(({element,label})=>{element.style.removeProperty("--editor-color");element.classList.remove("collaborative-input");label.classList.remove("collaborative-label")})}
 },[section,resourceId])
 return <>{fields.map(({element,key,label})=>{
  const unique=new Map<string,Collaborator>();for(const p of people)if(p.id!==userId&&p.section===section&&p.resource_id===(resourceId||null)&&p.field===key){const prior=unique.get(p.id);if(!prior||(prior.interacted_at||0)<(p.interacted_at||0))unique.set(p.id,p)}
  const editors=[...unique.values()].sort((a,b)=>(b.interacted_at||0)-(a.interacted_at||0)),color=editors[0]?.color
  element.classList.toggle("collaborative-input",!!color);if(color)element.setAttribute("aria-describedby",`field-presence-${fields.findIndex(f=>f.element===element)}`);else if(element.getAttribute("aria-describedby")?.startsWith("field-presence-"))element.removeAttribute("aria-describedby");if(color)element.style.setProperty("--editor-color",color);else element.style.removeProperty("--editor-color")
  return color?createPortal(<span className="field-editors" style={{"--editor-color":color} as React.CSSProperties} role="status" id={`field-presence-${fields.findIndex(f=>f.element===element)}`} aria-label={`Editing ${key.split(":")[0]}: ${editors.map(p=>p.name).join(", ")}`}>{editors.map(p=><span key={p.id}><i style={{background:p.color}}/>{p.name}</span>)}</span>,label,key):null
 })}</>
}
