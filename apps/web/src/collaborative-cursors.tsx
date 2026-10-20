import {useEffect,useLayoutEffect,useState} from 'react'
import {createPortal} from 'react-dom'
import {cursorRect,readSelection,type Selection} from './cursor-position'
import type {Collaborator} from './realtime'
export type CursorSignal={kind:'pointer'|'caret';section:string;resource_id:string;field:string;hidden?:boolean;x?:number;y?:number;selection?:Selection;connection_id?:string;actor_id?:string;name?:string;color?:string;at?:number}
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
  const fieldFor=(target:EventTarget|null)=>target instanceof HTMLElement?fields.find(f=>f.element===target||f.element.contains(target)||f.label.classList.contains('rich-field')&&f.label.contains(target)):undefined
  const record=(field:Field)=>field.element.closest<HTMLFormElement>('form')?.dataset.collabId||resourceId
  const send=(signal:CursorSignal)=>window.dispatchEvent(new CustomEvent('gcf:local-cursor',{detail:signal}))
  function caret(){const field=fieldFor(document.activeElement);if(!field){if(lastCaret){send({...lastCaret,hidden:true});lastCaret=undefined}return}const selection=readSelection(field.element),id=record(field);if(!selection||!id||Date.now()-caretAt<60)return;caretAt=Date.now();lastCaret={kind:'caret',section,resource_id:id,field:field.key,selection};send(lastCaret)}
  function pointer(event:PointerEvent){setHover({x:event.clientX,y:event.clientY});const field=fieldFor(event.target);if(!field){if(lastPointer){send({...lastPointer,hidden:true});lastPointer=undefined}return}if(Date.now()-pointerAt<70)return;const id=record(field),box=field.element.getBoundingClientRect();if(!id||box.width<=0||box.height<=0)return;pointerAt=Date.now();lastPointer={kind:'pointer',section,resource_id:id,field:field.key,x:clamp((event.clientX-box.left)/box.width),y:clamp((event.clientY-box.top)/box.height)};send(lastPointer)}
  function down(event:PointerEvent){pointer(event);clearTimeout(touchTimer);if(event.pointerType==='touch')touchTimer=setTimeout(()=>setHover({x:-10000,y:-10000}),3000)}
  function hidden(){if(document.visibilityState==='hidden'){if(lastCaret)send({...lastCaret,hidden:true});if(lastPointer)send({...lastPointer,hidden:true})}}
  function changed(){requestAnimationFrame(()=>{caret();setTick(n=>n+1)})}
  document.addEventListener('pointermove',pointer);document.addEventListener('pointerdown',down);document.addEventListener('selectionchange',caret);document.addEventListener('input',changed);document.addEventListener('focusin',changed);document.addEventListener('focusout',changed);document.addEventListener('visibilitychange',hidden)
  window.addEventListener('gcf:draft',changed);window.addEventListener('scroll',changed,true);window.addEventListener('resize',changed)
  return()=>{document.removeEventListener('pointermove',pointer);document.removeEventListener('pointerdown',down);document.removeEventListener('selectionchange',caret);document.removeEventListener('input',changed);document.removeEventListener('focusin',changed);document.removeEventListener('focusout',changed);document.removeEventListener('visibilitychange',hidden);window.removeEventListener('gcf:draft',changed);window.removeEventListener('scroll',changed,true);window.removeEventListener('resize',changed);clearTimeout(touchTimer)}
 },[fields,section,resourceId])
 useEffect(()=>{if(!color)return;for(const {element} of fields)element.style.caretColor=color;return()=>{for(const {element} of fields)element.style.removeProperty('caret-color')}},[fields,color])
 return <>{cursors.map(cursor=>{const field=fields.find(f=>f.key===cursor.field&&(f.element.closest<HTMLFormElement>('form')?.dataset.collabId||resourceId)===cursor.resource_id);return field?createPortal(<CursorMarker cursor={cursor} field={field} hover={hover} tick={tick}/>,field.label,`${cursor.connection_id}/${cursor.kind}`):null})}</>
}
function CursorMarker({cursor,field,hover,tick}:{cursor:Cursor;field:Field;hover:{x:number;y:number};tick:number}){
 const [point,setPoint]=useState<{left:number;top:number;height:number;screenX:number;screenY:number;flip:boolean}|null>(null)
 useLayoutEffect(()=>{
  const box=field.element.getBoundingClientRect(),parent=field.label.getBoundingClientRect(),position=cursor.kind==='caret'&&cursor.selection?cursorRect(field.element,cursor.selection):{left:(cursor.x||0)*box.width,top:(cursor.y||0)*box.height,height:18}
  if(!position||position.left<0||position.top<0||position.left>box.width||position.top>box.height){setPoint(null);return}
  const next={left:box.left-parent.left+field.label.scrollLeft+position.left,top:box.top-parent.top+field.label.scrollTop+position.top,height:Math.max(14,position.height),screenX:box.left+position.left,screenY:box.top+position.top,flip:position.left>box.width-140}
  setPoint(old=>JSON.stringify(old)===JSON.stringify(next)?old:next)
 },[cursor,field,tick])
 if(!point)return null
 const show=Math.abs(hover.x-point.screenX)<18&&hover.y>=point.screenY-8&&hover.y<=point.screenY+point.height+8
 return <span className={`collaboration-cursor ${cursor.kind}${show?' show-name':''}${point.flip?' flip-name':''}`} style={{left:point.left,top:point.top,height:point.height,'--cursor-color':cursor.color} as React.CSSProperties} aria-hidden="true">
  {cursor.kind==='pointer'?<svg width="14" height="18" viewBox="0 0 14 18"><path d="M1 1v14l4-4 3 6 3-1-3-6h5z"/></svg>:<i/>}
  <span className="collaboration-cursor-name">{cursor.name}</span>
 </span>
}
