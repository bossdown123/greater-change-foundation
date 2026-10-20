import { useEffect, useId, useRef, useState } from "react"
import { NodeViewContent, NodeViewWrapper, type NodeViewProps } from "@tiptap/react"
import { Popover } from "radix-ui"
import { Image as ImageIcon, X } from "lucide-react"
import { api, type Media } from "./admin"
import { figureWidth } from "./rich-document"
const filenames=new Map<string,Promise<string>>()
function filename(id:string){let result=filenames.get(id);if(!result){result=api<Media>(`/media/${id}`).then(image=>image.filename).catch(()=>{filenames.delete(id);return "Image"});filenames.set(id,result)}return result}
export function FigureReference({node,updateAttributes,editor,getPos,selected}:NodeViewProps){
 const id=String(node.attrs.mediaId||""),caption=node.textContent.trim(),width=figureWidth(node.attrs.widthPercent),previewId=useId(),errorId=useId()
 const [name,setName]=useState("Image"),[open,setOpen]=useState(false),[input,setInput]=useState(String(width)),[error,setError]=useState(false),timer=useRef<ReturnType<typeof setTimeout>|undefined>(undefined),focusedWidth=useRef(false)
 useEffect(()=>{let active=true;if(!caption)void filename(id).then(value=>{if(active)setName(value)});return()=>{active=false}},[id,!!caption])
 useEffect(()=>{if(!focusedWidth.current)setInput(String(width))},[width])
 useEffect(()=>()=>clearTimeout(timer.current),[])
 const title=caption||name
 function show(){clearTimeout(timer.current);setOpen(true)}
 function hide(){clearTimeout(timer.current);timer.current=setTimeout(()=>setOpen(false),150)}
 function hover(e:React.PointerEvent){if(e.pointerType!=="mouse"||e.currentTarget.contains(document.activeElement))return;clearTimeout(timer.current);timer.current=setTimeout(()=>setOpen(true),200)}
 function setWidth(value:string,commit=false){setInput(value);const parsed=Number(value);if(/^\d+$/.test(value)&&Number.isInteger(parsed)&&parsed>=1&&parsed<=100){setError(false);if(parsed!==width)updateAttributes({widthPercent:parsed})}else if(commit)setError(true)}
 return <NodeViewWrapper className="figure-reference" data-selected={selected} data-media-id={id} onPointerEnter={hover} onPointerLeave={hide}>
  <Popover.Root open={open} onOpenChange={setOpen}>
   <Popover.Anchor asChild><button type="button" className="figure-reference-preview" contentEditable={false} data-drag-handle aria-label={`Preview ${title}`} aria-expanded={open} aria-controls={previewId} title={`Preview ${title}`} onFocus={show} onMouseDown={e=>e.preventDefault()} onClick={()=>{const pos=getPos();if(typeof pos==="number")editor.commands.setNodeSelection(pos);show()}}><ImageIcon size={15}/></button></Popover.Anchor>
   <Popover.Portal><Popover.Content id={previewId} className="figure-hover-preview" side="bottom" align="start" sideOffset={10} collisionPadding={12} onOpenAutoFocus={e=>e.preventDefault()} onCloseAutoFocus={e=>e.preventDefault()} onPointerEnter={()=>{clearTimeout(timer.current)}} onPointerLeave={hide}>
    <img src={`/api/admin/media/${id}/thumbnail`} alt={String(node.attrs.alt||title)}/><span>{title}</span><Popover.Close className="figure-hover-close" aria-label="Close image preview"><X size={15}/></Popover.Close>
   </Popover.Content></Popover.Portal>
  </Popover.Root>
  <NodeViewContent<"span"> as="span" className="figure-reference-caption" data-empty={!node.content.size} data-placeholder={name} aria-label="Image caption" onFocus={()=>{clearTimeout(timer.current);setOpen(false)}}/>
  <label className="figure-reference-width" contentEditable={false} title="Image width in the output"><span className="sr-only">Width of {title}</span><input type="number" inputMode="numeric" min={1} max={100} step={1} value={input} aria-label={`Width percent for ${title}`} aria-invalid={error||undefined} aria-describedby={error?errorId:undefined} onFocus={()=>{focusedWidth.current=true;clearTimeout(timer.current);setOpen(false)}} onChange={e=>setWidth(e.target.value)} onBlur={()=>{focusedWidth.current=false;setWidth(input,true)}} onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();e.stopPropagation();setWidth(input,true)}if(e.key==="Escape"){e.preventDefault();setInput(String(width));setError(false)}}}/><span aria-hidden="true">%</span></label>
  {error&&<span id={errorId} className="figure-width-error" role="alert" contentEditable={false}>Use 1–100%.</span>}
 </NodeViewWrapper>
}
