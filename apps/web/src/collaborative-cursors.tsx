import {useEffect,useLayoutEffect,useState} from 'react'
import {createPortal} from 'react-dom'
import {cursorRect,readSelection,type Selection} from './cursor-position'
import {pointerSurface,resolvePointerSurface,type PointerSurface} from './cursor-surface'
import type {Collaborator} from './realtime'
import {MacPointer} from './mac-pointer'
export type CursorSignal={kind:'pointer'|'caret';section:string;resource_id:string|null;field:string;surface?:PointerSurface|'field';anchor?:string;hidden?:boolean;x?:number;y?:number;selection?:Selection;connection_id?:string;actor_id?:string;name?:string;color?:string;at?:number}
type Field={element:HTMLElement;label:HTMLElement;key:string}
type Cursor=CursorSignal&{connection_id:string;actor_id:string;name:string;color:string;at:number}
const clamp=(value:number)=>Math.min(1,Math.max(0,value))
export function CollaborativeCursors({fields,section,resourceId,people,userId}:{fields:Field[];section:string;resourceId?:string;people:Collaborator[];userId?:string}){
 const [cursors,setCursors]=useState<Cursor[]>([]),[hover,setHover]=useState({x:-10000,y:-10000}),[tick,setTick]=useState(0)
 const color=people.find(p=>p.id===userId)?.color
 useEffect(()=>{
  const receive=(event:Event)=>{const cursor=(event as CustomEvent<Cursor>).detail;if(cursor.section!==section)return;setCursors(old=>[...old.filter(c=>c.connection_id!==cursor.connection_id||c.kind!==cursor.kind),...(cursor.hidden?[]:[cursor])])}
  window.addEventListener('gcf:cursor',receive);const timer=setInterval(()=>{setCursors(old=>old.filter(c=>c.kind==='caret'||Date.now()-c.at<3500))},1000)
  return()=>{window.removeEventListener('gcf:cursor',receive);clearInterval(timer)}
 },[section,resourceId])
 useEffect(()=>{const ids=new Set(people.map(p=>p.connection_id));setCursors(old=>old.filter(c=>ids.has(c.connection_id)&& (c.kind!=='caret'||people.some(p=>p.connection_id===c.connection_id&&p.field===c.field&&p.field_active))))},[people])
 useEffect(()=>{
  let pointerAt=0,caretAt=0,lastPointer:CursorSignal|undefined,lastCaret:CursorSignal|undefined,touchTimer:ReturnType<typeof setTimeout>
  const fieldFor=(target:EventTarget|null)=>target instanceof Node?fields.find(f=>f.element===target||f.element.contains(target)||f.label.classList.contains('rich-field')&&f.label.contains(target)):undefined
  const record=(field:Field)=>field.element.closest<HTMLFormElement>('form')?.dataset.collabId||resourceId
  const send=(signal:CursorSignal)=>window.dispatchEvent(new CustomEvent('gcf:local-cursor',{detail:signal}))
  function caret(){const field=fieldFor(document.activeElement);if(!field){if(lastCaret){send({...lastCaret,hidden:true});lastCaret=undefined}return}const selection=readSelection(field.element),id=record(field);if(!selection||!id||Date.now()-caretAt<60)return;caretAt=Date.now();lastCaret={kind:'caret',section,resource_id:id,field:field.key,selection};send(lastCaret)}
  function pointer(event:PointerEvent){
   setHover({x:event.clientX,y:event.clientY});const field=fieldFor(event.target),surface=field?null:pointerSurface(event.target)
   if(!field&&!surface){if(lastPointer){send({...lastPointer,hidden:true});lastPointer=undefined}return}
   const target=field?.element||surface!.element,box=target.getBoundingClientRect()
   if(box.width<=0||box.height<=0||Date.now()-pointerAt<70)return
   pointerAt=Date.now();lastPointer={kind:'pointer',section,resource_id:field?record(field)||null:resourceId||null,field:field?.key||'',surface:field?'field':surface!.surface,anchor:surface?.anchor,x:clamp((event.clientX-box.left)/box.width),y:clamp((event.clientY-box.top)/box.height)};send(lastPointer)
  }
  function down(event:PointerEvent){pointer(event);clearTimeout(touchTimer);if(event.pointerType==='touch')touchTimer=setTimeout(()=>setHover({x:-10000,y:-10000}),3000)}
  function hidden(){if(document.visibilityState==='hidden'){if(lastCaret)send({...lastCaret,hidden:true});if(lastPointer)send({...lastPointer,hidden:true})}}
  function changed(){requestAnimationFrame(()=>{caret();setTick(n=>n+1)})}
  document.addEventListener('pointermove',pointer);document.addEventListener('pointerdown',down);document.addEventListener('selectionchange',caret);document.addEventListener('input',changed);document.addEventListener('focusin',changed);document.addEventListener('focusout',changed);document.addEventListener('visibilitychange',hidden)
  window.addEventListener('gcf:draft',changed);window.addEventListener('scroll',changed,true);window.addEventListener('resize',changed)
  return()=>{document.removeEventListener('pointermove',pointer);document.removeEventListener('pointerdown',down);document.removeEventListener('selectionchange',caret);document.removeEventListener('input',changed);document.removeEventListener('focusin',changed);document.removeEventListener('focusout',changed);document.removeEventListener('visibilitychange',hidden);window.removeEventListener('gcf:draft',changed);window.removeEventListener('scroll',changed,true);window.removeEventListener('resize',changed);clearTimeout(touchTimer)}
 },[fields,section,resourceId])
 useEffect(()=>{if(!color)return;for(const {element} of fields)element.style.caretColor=color;return()=>{for(const {element} of fields)element.style.removeProperty('caret-color')}},[fields,color])
 return <>{cursors.map(cursor=>{
  if(cursor.kind==='pointer'&&cursor.surface&&cursor.surface!=='field'){
   if(cursor.surface!=='sidebar'&&(cursor.resource_id||null)!==(resourceId||null))return null
   const element=resolvePointerSurface(cursor.surface,cursor.anchor)
   return element?createPortal(<CursorMarker cursor={cursor} field={{element,label:document.body,key:cursor.surface}} hover={hover} tick={tick} fixed/>,document.body,`${cursor.connection_id}/pointer`):null
  }
  const field=fields.find(f=>f.key===cursor.field&&(f.element.closest<HTMLFormElement>('form')?.dataset.collabId||resourceId)===cursor.resource_id)
  return field?createPortal(<CursorMarker cursor={cursor} field={field} hover={hover} tick={tick}/>,field.label,`${cursor.connection_id}/${cursor.kind}`):null
 })}</>
}
function CursorMarker({cursor,field,hover,tick,fixed=false}:{cursor:Cursor;field:Field;hover:{x:number;y:number};tick:number;fixed?:boolean}){
 const [point,setPoint]=useState<{left:number;top:number;height:number;screenX:number;screenY:number;flip:boolean}|null>(null)
 useLayoutEffect(()=>{
  const box=field.element.getBoundingClientRect(),parent=field.label.getBoundingClientRect(),position=cursor.kind==='caret'&&cursor.selection?cursorRect(field.element,cursor.selection):{left:(cursor.x||0)*box.width,top:(cursor.y||0)*box.height,height:18}
  if(box.width<=0||box.height<=0||!position||position.left<0||position.top<0||position.left>box.width||position.top>box.height){setPoint(null);return}
  const next={left:box.left+(fixed?0:-parent.left+field.label.scrollLeft)+position.left,top:box.top+(fixed?0:-parent.top+field.label.scrollTop)+position.top,height:Math.max(14,position.height),screenX:box.left+position.left,screenY:box.top+position.top,flip:position.left>box.width-140}
  setPoint(old=>JSON.stringify(old)===JSON.stringify(next)?old:next)
 },[cursor,field,tick,fixed])
 if(!point)return null
 const show=Math.abs(hover.x-point.screenX)<18&&hover.y>=point.screenY-8&&hover.y<=point.screenY+point.height+8
 return <span className={`collaboration-cursor ${cursor.kind}${show?' show-name':''}${point.flip?' flip-name':''}`} style={{position:fixed?'fixed':'absolute',zIndex:fixed?65:12,left:point.left,top:point.top,height:point.height,'--cursor-color':cursor.color} as React.CSSProperties} aria-hidden="true">
  {cursor.kind==='pointer'?<MacPointer/>:<i/>}
  <span className="collaboration-cursor-name">{cursor.name}</span>
 </span>
}
