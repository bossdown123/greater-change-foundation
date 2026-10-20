import { useEffect, useRef } from "react"
import { createAutosave } from "./autosave"
import { useRealtime } from "./realtime"
export function useAutosave({recordKey,dirty,blocked,busy,save}:{recordKey?:string;dirty:boolean;blocked:boolean;busy:boolean;save:()=>Promise<void>}){
 const {connected}=useRealtime(),latest=useRef({dirty,blocked,busy,connected,save,recordKey}),clock=useRef<ReturnType<typeof createAutosave>|null>(null)
 latest.current={dirty,blocked,busy,connected,save,recordKey}
 useEffect(()=>{
  const instance=createAutosave({state:()=>({dirty:!!latest.current.recordKey&&latest.current.dirty,paused:latest.current.blocked||latest.current.busy||!latest.current.connected||!navigator.onLine}),save:()=>latest.current.save()})
  clock.current=instance
  const resume=()=>instance.update()
  const leaving=(event:BeforeUnloadEvent)=>{if(latest.current.dirty){event.preventDefault();event.returnValue=""}}
  window.addEventListener("beforeunload",leaving);window.addEventListener("online",resume);window.addEventListener("offline",resume);window.addEventListener("focus",resume);document.addEventListener("visibilitychange",resume)
  instance.update()
  return()=>{instance.dispose();clock.current=null;window.removeEventListener("beforeunload",leaving);window.removeEventListener("online",resume);window.removeEventListener("offline",resume);window.removeEventListener("focus",resume);document.removeEventListener("visibilitychange",resume)}
 },[recordKey])
 useEffect(()=>clock.current?.update(),[dirty,blocked,busy,connected])
 return {saved:()=>clock.current?.saved()}
}
