import { useContext, useEffect, useState } from "react"
import { MasonryPhotoAlbum, type Photo } from "react-photo-album"
import { Check, Expand, ExternalLink, ImageOff, Upload } from "lucide-react"
import { Button } from "@/components/ui/button"
import { CollectionToolbar } from "./admin-layout"
import { api, errorText, Message, usePage, Pager, SearchField, PreviewContext, type Media } from "./admin"
import "react-photo-album/masonry.css"

type MeasuredPhoto=Photo&{media:Media;unavailable?:boolean}
const dimensions=new Map<string,Promise<{width:number;height:number;unavailable?:boolean}>>()
function measure(src:string){
 let promise=dimensions.get(src)
 if(!promise){promise=new Promise(resolve=>{const image=new window.Image();const timer=setTimeout(()=>finish({width:1,height:1,unavailable:true}),15000);function finish(size:{width:number;height:number;unavailable?:boolean}){clearTimeout(timer);image.onload=null;image.onerror=null;if(size.unavailable)dimensions.delete(src);resolve(size)}image.onload=()=>finish({width:Math.max(1,image.naturalWidth),height:Math.max(1,image.naturalHeight)});image.onerror=()=>finish({width:1,height:1,unavailable:true});image.src=src});dimensions.set(src,promise)}
 return promise
}
function MasonryLibrary({items,selected,onToggle,onOpen}:{items:Media[];selected?:string[];onToggle:(id:string)=>void;onOpen:(id:string)=>void}){
 const [photos,setPhotos]=useState<MeasuredPhoto[]>([]),[loading,setLoading]=useState(true)
 useEffect(()=>{let active=true;setLoading(true);Promise.all(items.map(async media=>({...await measure(media.thumbnail_url),src:media.thumbnail_url,key:media.id,alt:media.alt||"",label:media.caption?`${media.caption} — ${media.filename}`:media.filename,media}))).then(result=>{if(active){setPhotos(result);setLoading(false)}});return()=>{active=false}},[items])
 if(loading)return <div className="masonry-loading" role="status" aria-label="Loading images">{Array.from({length:12},(_,i)=><span key={i} style={{aspectRatio:["4/3","3/4","1/1"][i%3]}}/>)}</div>
 return <MasonryPhotoAlbum photos={photos} columns={width=>width<320?1:width<620?2:width<1000?3:4} spacing={10} padding={0} render={{photo:(_,{photo,width,height})=>{
  const chosen=selected?.includes(photo.media.id)||false
  return <div className="masonry-photo" data-selected={chosen} style={{aspectRatio:`${width}/${height}`}}><button type="button" className="masonry-open" data-media-id={photo.media.id} aria-label={`${selected?"Select":"Open"} ${photo.label}`} aria-pressed={selected?chosen:undefined} onClick={()=>selected?onToggle(photo.media.id):onOpen(photo.media.id)}>{photo.unavailable?<ImageOff aria-label="Image unavailable"/>:<img src={photo.src} width={photo.width} height={photo.height} alt={photo.alt} decoding="async"/>}</button>{selected&&<><label className="masonry-check" title={chosen?"Deselect image":"Select image"}><input type="checkbox" aria-label={`Select ${photo.label}`} checked={chosen} onChange={()=>onToggle(photo.media.id)}/>{chosen&&<Check size={16} aria-hidden="true"/>}</label><button type="button" className="masonry-inspect" title="Image details" aria-label={`Details for ${photo.label}`} onClick={()=>onOpen(photo.media.id)}><Expand size={16}/></button></>}</div>
 }}}/>
}
export function Gallery({selected,onPick,onCancel}:{selected?:string[];onPick?:(ids:string[])=>void;onCancel?:()=>void}){
 const list=usePage<Media>("/media"),[selection,setSelection]=useState<string[]>(selected||[]),[editing,setEditing]=useState<Media|null>(null),[uploading,setUploading]=useState(false),[error,setError]=useState(""),[notice,setNotice]=useState("")
 const setPreview=useContext(PreviewContext)
 function close(){const id=editing?.id;setEditing(null);requestAnimationFrame(()=>requestAnimationFrame(()=>{if(id)document.querySelector<HTMLButtonElement>(`[data-media-id="${CSS.escape(id)}"]`)?.focus({preventScroll:true})}))}
 useEffect(()=>{setPreview(editing?{kind:"media",data:editing,reveal:true,onClose:close,onSaved:list.reload}:null)},[editing])
 useEffect(()=>()=>setPreview(null),[setPreview])
 async function upload(files:FileList|null){if(!files?.length)return;setUploading(true);setError("");let success=0;const failures:string[]=[];for(const file of Array.from(files)){setNotice(`Uploading ${success+failures.length+1} of ${files.length}…`);try{if(file.size>32*1024*1024)throw new Error("Larger than 32 MB");const body=new FormData();body.append("file",file);await api<Media>("/media","POST",body);success++}catch(e){failures.push(`${file.name}: ${errorText(e)}`)}}setNotice(`${success} image${success===1?"":"s"} uploaded.`);setError(failures.join("\n"));setUploading(false);list.setPage(1);list.reload()}
 async function detail(id:string){try{setEditing(await api<Media>(`/media/${id}`));setError("")}catch(e){setError(errorText(e))}}
 function toggle(id:string){setSelection(current=>current.includes(id)?current.filter(value=>value!==id):[...current,id])}
 return <>{onCancel&&<Button variant="ghost" onClick={onCancel}>← Event</Button>}<CollectionToolbar><SearchField label="Search images" query={list.query} onChange={list.setQuery}/><label className={`upload-control icon-upload ${uploading?"disabled":""}`} title="Upload images"><Upload aria-hidden="true"/><span className="sr-only">Upload images</span><input className="sr-only" type="file" multiple accept="image/jpeg,image/png,image/webp" disabled={uploading} onChange={e=>{void upload(e.target.files);e.target.value=""}}/></label></CollectionToolbar><Message error={error||list.error} notice={notice}/>{list.loading?<div className="masonry-loading" role="status" aria-label="Loading images"/>:!list.items.length?<p className="empty">{list.query?"No matches":"No images yet"}</p>:<MasonryLibrary items={list.items} selected={onPick?selection:undefined} onToggle={toggle} onOpen={id=>void detail(id)}/>}<Pager {...list}/>{onPick&&<footer className="form-actions"><strong aria-live="polite">{selection.length} selected</strong><Button disabled={selection.length>100} onClick={()=>onPick(selection)}>Add photos</Button><Button variant="ghost" onClick={onCancel}>Cancel</Button></footer>}</>
}
export function ImageInspector({image,onClose,onSaved}:{image:Media;onClose:()=>void;onSaved?:()=>void}){
 const [alt,setAlt]=useState(image.alt),[caption,setCaption]=useState(image.caption),[error,setError]=useState(""),[notice,setNotice]=useState(""),[busy,setBusy]=useState(false)
 async function save(e:React.FormEvent){e.preventDefault();setBusy(true);try{await api(`/media/${image.id}`,"PATCH",{alt,caption});setNotice("Saved");setError("");onSaved?.()}catch(e){setError(errorText(e))}finally{setBusy(false)}}
 async function remove(){if(!confirm("Permanently delete this image from the library?"))return;try{await api(`/media/${image.id}`,"DELETE");onSaved?.();onClose()}catch(e){setError(errorText(e))}}
 return <section className="preview-scroll image-inspector"><img className="inspector-image" src={image.url} alt={alt}/><form onSubmit={save}><label>Caption<textarea rows={3} value={caption} maxLength={2000} onChange={e=>setCaption(e.target.value)}/></label><label>Accessibility description<textarea rows={4} value={alt} maxLength={1000} onChange={e=>setAlt(e.target.value)}/></label><Message error={error} notice={notice}/><Button type="submit" disabled={busy}>{busy?"Saving…":"Save"}</Button><details className="image-file-details"><summary>{image.filename}</summary><p>{(image.size_bytes/1024/1024).toFixed(2)} MB</p><ul>{image.events?.map(event=><li key={event.id}>{event.title}</li>)}</ul><a href={image.url} target="_blank" rel="noreferrer">Original <ExternalLink size={12}/></a><Button type="button" variant="ghost" disabled={!!image.events?.length} onClick={()=>void remove()}>Delete image</Button></details></form></section>
}
