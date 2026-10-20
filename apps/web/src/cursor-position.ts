import getCaretCoordinates from 'textarea-caret'
export type Selection={anchor:number;head:number;type:'text'|'rich'}
type RichSelection={read:()=>Selection;rect:(position:number)=>{left:number;top:number;bottom:number}}
const richEditors=new WeakMap<HTMLElement,RichSelection>()
export function registerRichSelection(element:HTMLElement,selection:RichSelection){richEditors.set(element,selection);return()=>{richEditors.delete(element)}}
export function readSelection(element:HTMLElement):Selection|null{
 const rich=richEditors.get(element);if(rich)return rich.read()
 if(element instanceof HTMLInputElement||element instanceof HTMLTextAreaElement){if(element.selectionStart===null||element.selectionEnd===null)return null;return {anchor:element.selectionStart,head:element.selectionEnd,type:'text'}}
 return null
}
export function cursorRect(element:HTMLElement,selection:Selection){
 const box=element.getBoundingClientRect(),rich=richEditors.get(element)
 if(selection.type==='rich'&&rich){try{const rect=rich.rect(selection.head);return {left:rect.left-box.left,top:rect.top-box.top,height:rect.bottom-rect.top}}catch{return null}}
 if(selection.type==='text'&&(element instanceof HTMLInputElement||element instanceof HTMLTextAreaElement)){
  const caret=getCaretCoordinates(element,Math.min(selection.head,element.value.length));return {left:caret.left-element.scrollLeft,top:caret.top-element.scrollTop,height:caret.height||Number.parseFloat(getComputedStyle(element).lineHeight)||18}
 }
 return null
}

export function mapTextPosition(before:string,after:string,position:number){
 let start=0,end=before.length,last=after.length
 while(start<end&&start<last&&before[start]===after[start])start++
 while(end>start&&last>start&&before[end-1]===after[last-1]){end--;last--}
 return position<=start?position:position>=end?position+last-end:start+Math.min(position-start,last-start)
}
export function preserveNativeCaret(){
 const input=document.activeElement
 if(!(input instanceof HTMLInputElement||input instanceof HTMLTextAreaElement)||input.selectionStart===null)return ()=>{}
 const before=input.value,start=input.selectionStart,end=input.selectionEnd??start,direction=input.selectionDirection||'none'
 return ()=>{if(document.activeElement===input&&input.value!==before){input.setSelectionRange(mapTextPosition(before,input.value,start),mapTextPosition(before,input.value,end),direction)}}
}
