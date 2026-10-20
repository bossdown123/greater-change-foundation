import {useEffect,useRef,useState} from 'react'
import {Dialog} from 'radix-ui'
import {ChevronLeft,ChevronRight,X,ImageOff} from 'lucide-react'
import './photo-viewer.css'
export type ViewerPhoto={id:string;src:string;thumbnail:string;alt:string;caption?:string}
type Props={open:boolean;onOpenChange:(open:boolean)=>void;photos:ViewerPhoto[];title:string;initialIndex?:number;total?:number;loading?:boolean;onLoadMore?:()=>void;returnFocus?:()=>void}
export function PhotoViewer({open,onOpenChange,photos,title,initialIndex=0,total=photos.length,loading=false,onLoadMore,returnFocus}:Props){
 const [index,setIndex]=useState(initialIndex),[visible,setVisible]=useState(48),[failed,setFailed]=useState(false)
 const activeThumb=useRef<HTMLButtonElement|null>(null),pendingAdvance=useRef(false),previousLength=useRef(photos.length),strip=useRef<HTMLDivElement|null>(null)
 useEffect(()=>{if(open){setIndex(initialIndex);setVisible(Math.max(48,initialIndex+1));pendingAdvance.current=false}},[open,initialIndex])
 useEffect(()=>{setFailed(false);activeThumb.current?.scrollIntoView?.({block:'nearest',inline:'nearest'});setVisible(current=>Math.max(current,index+12))},[index,open,photos[index]?.id])
 useEffect(()=>{if(pendingAdvance.current&&photos.length>previousLength.current){pendingAdvance.current=false;setIndex(current=>current+1)}previousLength.current=photos.length},[photos.length])
 useEffect(()=>{if(open&&onLoadMore&&!loading&&photos.length>0&&index>=photos.length-3&&photos.length<total)onLoadMore()},[index,photos.length,total,loading,open])
 useEffect(()=>{if(photos.length&&index>=photos.length)setIndex(photos.length-1)},[photos.length,index])
 function next(){if(index+1<photos.length)setIndex(index+1);else if(photos.length<total&&onLoadMore){pendingAdvance.current=true;if(!loading)onLoadMore()}}
 function moveThumb(event:React.KeyboardEvent<HTMLButtonElement>,target:number){event.preventDefault();setIndex(target);requestAnimationFrame(()=>strip.current?.querySelector<HTMLButtonElement>(`[data-photo-index="${target}"]`)?.focus())}
 const photo=photos[index]
 return <Dialog.Root open={open} onOpenChange={onOpenChange}><Dialog.Portal><Dialog.Overlay className="photo-viewer-shade"/><Dialog.Content className="photo-viewer" aria-describedby={undefined} onCloseAutoFocus={event=>{if(returnFocus){event.preventDefault();returnFocus()}}} onKeyDown={event=>{if(event.target instanceof HTMLElement&&event.target.closest('.photo-viewer-thumbs'))return;if(event.key==='ArrowLeft'){event.preventDefault();setIndex(current=>Math.max(0,current-1))}if(event.key==='ArrowRight'){event.preventDefault();next()}}}>
 <header><Dialog.Title>{title}</Dialog.Title><Dialog.Close className="photo-viewer-close" aria-label="Close gallery"><X size={22}/></Dialog.Close></header>
 <div className="photo-viewer-stage"><button type="button" className="photo-viewer-arrow previous" aria-label="Previous photo" disabled={index===0||!photo} onClick={()=>setIndex(index-1)}><ChevronLeft/></button>{photo&&!failed?<img key={photo.id} className="photo-viewer-image" src={photo.src} alt={photo.alt} onError={()=>setFailed(true)}/>:<div className="photo-viewer-unavailable" role="status">{loading&&!photo?'Loading photographs…':<><ImageOff size={28}/><span>{photo?'Image unavailable':'No photographs'}</span></>}</div>}<button type="button" className="photo-viewer-arrow next" aria-label="Next photo" disabled={!photo||index>=total-1} onClick={next}><ChevronRight/></button></div>
 <div className="photo-viewer-caption" aria-live="polite" aria-atomic="true"><span>{photo?`${index+1} of ${total}`:'—'}</span>{photo?.caption&&<p>{photo.caption}</p>}</div>
 <div className="photo-viewer-thumbs" ref={strip} role="toolbar" aria-label="Photographs" onScroll={event=>{const element=event.currentTarget;if(element.scrollLeft+element.clientWidth>=element.scrollWidth-250){setVisible(current=>Math.min(photos.length,current+48));if(!loading&&photos.length<total)onLoadMore?.()}}}>{photos.slice(0,visible).map((item,i)=><button type="button" data-photo-index={i} key={item.id} ref={i===index?activeThumb:undefined} aria-label={`Photo ${i+1}: ${item.alt}`} aria-pressed={i===index} tabIndex={i===index?0:-1} onClick={()=>setIndex(i)} onKeyDown={event=>{if(event.key==='ArrowRight')moveThumb(event,Math.min(photos.length-1,i+1));if(event.key==='ArrowLeft')moveThumb(event,Math.max(0,i-1));if(event.key==='Home')moveThumb(event,0);if(event.key==='End'){setVisible(photos.length);moveThumb(event,photos.length-1)}}}><img src={item.thumbnail} alt="" loading="lazy"/></button>)}</div>
 </Dialog.Content></Dialog.Portal></Dialog.Root>
}
