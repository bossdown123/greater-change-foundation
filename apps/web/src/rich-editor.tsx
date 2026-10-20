import { useEffect, useId, useRef, useState } from "react"
import { EditorContent, useEditor, ReactNodeViewRenderer } from "@tiptap/react"
import { Node, mergeAttributes, type JSONContent } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import TextAlign from "@tiptap/extension-text-align"
import { Dialog } from "radix-ui"
import { Bold, Italic, List, ListOrdered, Link, ImagePlus, Undo2, Redo2, AlignLeft, AlignCenter, Heading2, Trash2, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Gallery } from "./admin-gallery"
import { api, PreviewContext, type Media } from "./admin"
import { WorkspaceHeader } from "./admin-layout"
import { readDocument, writeDocument, safeHref, figureWidth, type RichNode } from "./rich-document"
import { registerRichSelection } from "./cursor-position"
import { FigureReference } from "./figure-reference"
const Figure=Node.create({name:"gcfFigure",group:"block",content:"inline*",draggable:true,isolating:true,
 addKeyboardShortcuts(){return {Enter:()=>{const {state}=this.editor;if(state.selection.$from.parent.type.name!==this.name)return false;const after=state.selection.$from.after();return this.editor.chain().insertContentAt(after,{type:"paragraph"}).setTextSelection(after+1).run()}}},
 addAttributes(){return{mediaId:{default:null},alt:{default:""},widthPercent:{default:100}}},
 parseHTML(){return[{tag:"figure[data-media-id]",contentElement:"figcaption",getAttrs:element=>({mediaId:(element as HTMLElement).dataset.mediaId,alt:(element as HTMLElement).querySelector("img")?.alt||"",widthPercent:figureWidth(Number((element as HTMLElement).dataset.widthPercent||100))})}]},
 renderHTML({node,HTMLAttributes}){return ["figure",mergeAttributes(HTMLAttributes,{"data-media-id":node.attrs.mediaId,"data-width-percent":figureWidth(node.attrs.widthPercent),style:`width:${figureWidth(node.attrs.widthPercent)}%;margin-inline:auto`}),["img",{src:`/api/admin/media/${node.attrs.mediaId}/file`,alt:node.attrs.alt,style:"width:100%;height:auto",contenteditable:"false"}],["figcaption",0]]},
 addNodeView(){return ReactNodeViewRenderer(FigureReference,{contentDOMElementTag:"span",selectedOnTextSelection:true})}
})
export default function RichEditor({label,value,onChange,plain=false}:{label:string;value:string;onChange:(value:string)=>void;plain?:boolean}){
 const labelId=useId(),latest=useRef(value),changed=useRef(onChange),position=useRef({from:0,to:0}),[picking,setPicking]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(""),[,render]=useState(0)
 changed.current=onChange
 const editor=useEditor({extensions:[StarterKit.configure({heading:plain?false:{levels:[2,3]},bulletList:plain?false:undefined,orderedList:plain?false:undefined,blockquote:plain?false:undefined,bold:plain?false:undefined,italic:plain?false:undefined,strike:plain?false:undefined,underline:plain?false:undefined,codeBlock:false,code:false,link:plain?false:{openOnClick:false}}),TextAlign.configure({types:["heading","paragraph"]}),Figure],content:readDocument(value) as JSONContent,immediatelyRender:true,
 editorProps:{attributes:{role:"textbox","aria-multiline":"true","aria-labelledby":labelId,"aria-label":label,"data-rich-label":label,class:"rich-surface"}},
 onUpdate:({editor})=>{latest.current=plain?editor.getText({blockSeparator:"\n"}):writeDocument(editor.getJSON() as RichNode);changed.current(latest.current);render(n=>n+1)},onSelectionUpdate:()=>render(n=>n+1)})
 useEffect(()=>{if(editor&&value!==latest.current){
  const before=editor.state.doc,next=editor.schema.nodeFromJSON(readDocument(value)),selection=editor.state.selection,start=before.content.findDiffStart(next.content),end=before.content.findDiffEnd(next.content)
  const map=(position:number)=>start===null||!end?position:position<=start?position:position>=end.a?position+end.b-end.a:start+Math.min(position-start,Math.max(0,end.b-start))
  const clamp=(position:number)=>Math.max(1,Math.min(position,Math.max(1,next.content.size-1)))
  latest.current=value;editor.chain().setContent(next.toJSON() as JSONContent,{emitUpdate:false}).setTextSelection({from:clamp(map(selection.anchor)),to:clamp(map(selection.head))}).run()
 }},[editor,value])
 useEffect(()=>{if(!editor)return;return registerRichSelection(editor.view.dom,{read:()=>({anchor:editor.state.selection.anchor,head:editor.state.selection.head,type:'rich'}),rect:position=>editor.view.coordsAtPos(Math.max(0,Math.min(position,editor.state.doc.content.size)))})},[editor])
 if(!editor)return null
 const act=(name:string,icon:React.ReactNode,run:()=>void,active=false,disabled=false)=><Button key={name} type="button" variant="ghost" size="icon" aria-label={name} title={name} aria-pressed={active} disabled={disabled} onMouseDown={e=>e.preventDefault()} onClick={run}>{icon}</Button>
 function chooseImages(){position.current={from:editor!.state.selection.from,to:editor!.state.selection.to};setPicking(true)}
 async function insert(ids:string[]){setBusy(true);try{const images=await Promise.all(ids.map(id=>api<Media>(`/media/${id}`)));editor!.chain().focus().insertContentAt(position.current,images.flatMap(image=>[{type:"gcfFigure",attrs:{mediaId:image.id,alt:image.alt,widthPercent:100},content:image.caption?[{type:"text",text:image.caption}]:[]},{type:"paragraph"}])).run();setPicking(false);setError("")}catch{setError("Could not open the selected images.")}finally{setBusy(false)}}
 const inFigure=editor.isActive("gcfFigure")
 return <section className="rich-field"><span id={labelId} className="rich-label">{label}</span>{!plain&&<div className="rich-toolbar" role="toolbar" aria-label={`${label} formatting`}>
 {act("Heading",<Heading2 size={16}/>,()=>editor.chain().focus().toggleHeading({level:2}).run(),editor.isActive("heading"))}
 {act("Bold",<Bold size={16}/>,()=>editor.chain().focus().toggleBold().run(),editor.isActive("bold"))}{act("Italic",<Italic size={16}/>,()=>editor.chain().focus().toggleItalic().run(),editor.isActive("italic"))}
 {act("Bullet list",<List size={16}/>,()=>editor.chain().focus().toggleBulletList().run(),editor.isActive("bulletList"))}{act("Numbered list",<ListOrdered size={16}/>,()=>editor.chain().focus().toggleOrderedList().run(),editor.isActive("orderedList"))}
 {act("Align left",<AlignLeft size={16}/>,()=>editor.chain().focus().setTextAlign("left").run())}{act("Center",<AlignCenter size={16}/>,()=>editor.chain().focus().setTextAlign("center").run())}
 {act("Link",<Link size={16}/>,()=>{const href=prompt("Link address",editor.getAttributes("link").href||"https://");if(href===null)return;if(!href)editor.chain().focus().unsetLink().run();else if(safeHref(href))editor.chain().focus().extendMarkRange("link").setLink({href}).run();else setError("Use an https, http or email link.")},editor.isActive("link"))}
 {act("Insert library image",<ImagePlus size={16}/>,chooseImages)}
 {act("Undo",<Undo2 size={16}/>,()=>editor.chain().focus().undo().run(),false,!editor.can().undo())}{act("Redo",<Redo2 size={16}/>,()=>editor.chain().focus().redo().run(),false,!editor.can().redo())}
 {inFigure&&act("Remove figure",<Trash2 size={16}/>,()=>editor.chain().focus().deleteNode("gcfFigure").run())}</div>}
 {inFigure&&<label className="figure-alt">Image description<input aria-label="Image description" value={String(editor.getAttributes("gcfFigure").alt||"")} maxLength={1000} onChange={e=>{editor.commands.updateAttributes("gcfFigure",{alt:e.target.value});render(n=>n+1)}}/></label>}
 <EditorContent editor={editor}/>{error&&<p className="error" role="alert">{error}</p>}
 <Dialog.Root open={picking} onOpenChange={setPicking}><Dialog.Portal><Dialog.Overlay className="image-picker-overlay"/><Dialog.Content className="image-picker admin-app" aria-describedby={undefined} onCloseAutoFocus={e=>{e.preventDefault();editor.commands.focus()}}><Dialog.Title className="sr-only">Choose library images</Dialog.Title><Dialog.Close asChild><Button type="button" variant="ghost" size="icon" className="image-picker-close" aria-label="Close image picker"><X/></Button></Dialog.Close><PreviewContext.Provider value={()=>{}}><WorkspaceHeader sidebar={false}><div className="admin-main"><Gallery selected={[]} onPick={ids=>{if(!busy)void insert(ids)}}/></div></WorkspaceHeader></PreviewContext.Provider></Dialog.Content></Dialog.Portal></Dialog.Root></section>
}
