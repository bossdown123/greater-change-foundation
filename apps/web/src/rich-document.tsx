import { Fragment, type ReactNode } from "react"
export const RICH_PREFIX="gcf-richtext:"
export type RichNode={type:string;text?:string;attrs?:Record<string,unknown>;marks?:{type:string;attrs?:Record<string,unknown>}[];content?:RichNode[]}
export function readDocument(value:string):RichNode{
 if(value.startsWith(RICH_PREFIX)){try{const doc=JSON.parse(value.slice(RICH_PREFIX.length));if(doc?.type==="doc")return doc}catch{/* preserve legacy text */}}
 return {type:"doc",content:value.split(/\r?\n/).map(text=>({type:"paragraph",content:text?[{type:"text",text}]:[]}))}
}
export const writeDocument=(doc:RichNode)=>RICH_PREFIX+JSON.stringify(doc)
export const safeHref=(href:unknown)=>typeof href==="string"&&/^(https?:\/\/|mailto:)/i.test(href)?href:undefined
export function documentText(value:string):string{const visit=(node:RichNode):string=>node.type==="hardBreak"?"\n":node.type==="text"?node.text||"":(node.content||[]).map(visit).join(["paragraph","heading","gcfFigure"].includes(node.type)?"":"\n");return visit(readDocument(value)).trim()}
export function documentHTML(value:string):string{
 const esc=(s:unknown)=>String(s??"").replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));let figure=0
 const visit=(n:RichNode):string=>{let inner=(n.content||[]).map(visit).join("");if(n.type==="text"){inner=esc(n.text);for(const m of n.marks||[]){const tag=({bold:"strong",italic:"em",underline:"u",strike:"s",code:"code"} as Record<string,string>)[m.type];if(tag)inner=`<${tag}>${inner}</${tag}>`;else if(m.type==="link"&&safeHref(m.attrs?.href))inner=`<a href="${esc(m.attrs?.href)}" rel="noopener noreferrer">${inner}</a>`}return inner}
 if(n.type==="gcfFigure"){const id=String(n.attrs?.mediaId||"");if(!/^[a-f0-9]{32}$/.test(id))return "";figure++;return `<figure><img src="${location.origin}/api/admin/media/${id}/file" alt="${esc(n.attrs?.alt)}" style="max-width:100%;height:auto"><figcaption style="font-size:12px;text-align:center;color:#777">Figure ${figure}${inner?` · ${inner}`:""}</figcaption></figure>`}
 const tag=({paragraph:"p",heading:n.attrs?.level===3?"h3":"h2",bulletList:"ul",orderedList:"ol",listItem:"li",blockquote:"blockquote",hardBreak:"br",horizontalRule:"hr"} as Record<string,string>)[n.type];if(!tag)return inner
 const alignment=["left","center","right"].includes(String(n.attrs?.textAlign))?` style="text-align:${n.attrs!.textAlign}"`:"";return `<${tag}${alignment}>${inner}${["br","hr"].includes(tag)?"":`</${tag}>`}`};return visit(readDocument(value))
}
export function RichContent({value,className=""}:{value:string;className?:string}){
 function render(n:RichNode,key:string):ReactNode{const children=(n.content||[]).map((child,i)=>render(child,`${key}-${i}`));if(n.type==="text"){let text:ReactNode=n.text||"";for(const [i,m] of (n.marks||[]).entries()){const k=`${key}-m${i}`;switch(m.type){case"bold":text=<strong key={k}>{text}</strong>;break;case"italic":text=<em key={k}>{text}</em>;break;case"underline":text=<u key={k}>{text}</u>;break;case"strike":text=<s key={k}>{text}</s>;break;case"code":text=<code key={k}>{text}</code>;break;case"link":if(safeHref(m.attrs?.href))text=<a key={k} href={safeHref(m.attrs?.href)} target="_blank" rel="noreferrer">{text}</a>}}return <Fragment key={key}>{text}</Fragment>}
 const style=["left","center","right"].includes(String(n.attrs?.textAlign))?{textAlign:n.attrs!.textAlign as "left"|"center"|"right"}:undefined
 switch(n.type){case"paragraph":return <p key={key} style={style}>{children.length?children:<br/>}</p>;case"heading":return n.attrs?.level===3?<h3 key={key} style={style}>{children}</h3>:<h2 key={key} style={style}>{children}</h2>;case"bulletList":return <ul key={key}>{children}</ul>;case"orderedList":return <ol key={key}>{children}</ol>;case"listItem":return <li key={key}>{children}</li>;case"blockquote":return <blockquote key={key}>{children}</blockquote>;case"hardBreak":return <br key={key}/>;case"horizontalRule":return <hr key={key}/>;case"gcfFigure":{const id=String(n.attrs?.mediaId||"");return /^[a-f0-9]{32}$/.test(id)?<figure key={key}><img src={`/api/admin/media/${id}/file`} alt={String(n.attrs?.alt||"")}/><figcaption>{children}</figcaption></figure>:null}default:return <Fragment key={key}>{children}</Fragment>}}
 return <div className={`rich-document ${className}`}>{render(readDocument(value),"doc")}</div>
}
