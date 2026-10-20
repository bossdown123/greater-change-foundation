import {useContext,useEffect,useRef,useState} from 'react'
import {Dialog} from 'radix-ui'
import {ArrowDown,ArrowUp,Images,Plus,X} from 'lucide-react'
import {Button} from '@/components/ui/button'
import {api,errorText,usePage,SearchField,LoadMoreBoundary,Message,PreviewContext,useNewDraft,type Media} from './admin'
import {CollectionToolbar,HeaderTools} from './admin-layout'
import {Gallery} from './admin-gallery'
import {useChangeVersion} from './realtime'
import {useAutosave} from './use-autosave'
import {useRemoteDraft} from './remote-draft'
import {mergeDraft} from './merge-draft'
import './image-groups.css'
import {PhotoViewer} from './components/photo-viewer'
export type ImageGroup={id:string;title:string;media_ids:string[];photo_count:number;cover_id?:string;uses?:number;updated_at:string}
function useGroups(ids:string[]){
 const [groups,setGroups]=useState<ImageGroup[]>([]),[error,setError]=useState(''),version=useChangeVersion()
 useEffect(()=>{let active=true;void Promise.all(ids.map(id=>api<ImageGroup>(`/media_groups/${id}`))).then(rows=>{if(active){setGroups(rows);setError('')}}).catch(e=>{if(active)setError(errorText(e))});return()=>{active=false}},[JSON.stringify(ids),version])
 return {groups,error}
}
export function CollectionViewer({groupId,onClose,returnFocus}:{groupId:string;onClose:()=>void;returnFocus?:()=>void}){
 const list=usePage<Media>(`/media?group_id=${encodeURIComponent(groupId)}`),[group,setGroup]=useState<ImageGroup|null>(null),version=useChangeVersion()
 useEffect(()=>{let active=true;void api<ImageGroup>(`/media_groups/${groupId}`).then(row=>{if(active)setGroup(row)}).catch(()=>{});return()=>{active=false}},[groupId,version])
 return <PhotoViewer open onOpenChange={value=>{if(!value)onClose()}} title={group?.title||'Collection'} photos={list.items.map(photo=>({id:photo.id,src:photo.url||photo.thumbnail_url,thumbnail:photo.thumbnail_url,alt:photo.alt||photo.caption||photo.filename,caption:photo.caption}))} total={list.total} loading={list.loadingMore} onLoadMore={()=>list.setPage(list.page+1)} returnFocus={returnFocus}/>
}
export function LinkedCollections({ids}:{ids:string[]}){
 const {groups,error}=useGroups(ids),[open,setOpen]=useState<string|null>(null),opener=useRef<HTMLButtonElement|null>(null)
 if(!ids.length)return null
 return <><Message error={error}/><ul className="linked-collection-output">{groups.map(group=><li key={group.id}><Button type="button" variant="outline" onClick={event=>{opener.current=event.currentTarget;setOpen(group.id)}}><Images size={17}/>{group.title}<span>{group.photo_count} photos</span></Button></li>)}</ul>{open&&<CollectionViewer groupId={open} onClose={()=>setOpen(null)} returnFocus={()=>opener.current?.focus({preventScroll:true})}/>}</>
}
export function CollectionLinks({ids,onChange}:{ids:string[];onChange:(ids:string[])=>void}){
 const opener=useRef<HTMLButtonElement|null>(null)
 const [picking,setPicking]=useState(false),[selection,setSelection]=useState(ids),{groups,error}=useGroups(ids),list=usePage<ImageGroup>('/media_groups')
 function move(index:number,delta:number){const next=[...ids];[next[index],next[index+delta]]=[next[index+delta],next[index]];onChange(next)}
 return <section className="collection-links"><header className="section-heading"><h2>Galleries</h2><Button ref={opener} type="button" variant="outline" onClick={()=>{setSelection(ids);setPicking(true)}}><Images size={16}/>Link collections</Button></header>{ids.length>0&&<p className="collection-link-note">Collection changes appear everywhere it is linked.</p>}<Message error={error}/><ul>{groups.map((group,index)=><li key={group.id}><span>{group.title}<small>{group.photo_count} photos</small></span><Button type="button" variant="ghost" size="icon" disabled={index===0} aria-label={`Move ${group.title} up`} onClick={()=>move(index,-1)}><ArrowUp size={15}/></Button><Button type="button" variant="ghost" size="icon" disabled={index===ids.length-1} aria-label={`Move ${group.title} down`} onClick={()=>move(index,1)}><ArrowDown size={15}/></Button><Button type="button" variant="ghost" size="icon" aria-label={`Remove link to ${group.title}`} onClick={()=>onChange(ids.filter(id=>id!==group.id))}><X size={16}/></Button></li>)}</ul>
 <Dialog.Root open={picking} onOpenChange={setPicking}><Dialog.Portal><Dialog.Overlay className="collection-dialog-overlay"/><Dialog.Content className="collection-picker" aria-describedby={undefined} onCloseAutoFocus={event=>{event.preventDefault();opener.current?.focus()}}><Dialog.Title>Link collections</Dialog.Title><label className="search"><span className="sr-only">Search collections</span><input type="search" placeholder="Search" value={list.query} onChange={e=>list.setQuery(e.target.value)}/></label><div className="collection-picker-scroll"><Message error={list.error}/><ul className="record-list">{list.items.map(group=><li key={group.id}><label className="select-event"><input type="checkbox" checked={selection.includes(group.id)} onChange={()=>setSelection(current=>current.includes(group.id)?current.filter(id=>id!==group.id):[...current,group.id])}/><span><strong>{group.title}</strong><small>{group.photo_count} photos</small></span></label></li>)}</ul><LoadMoreBoundary {...list}/>{!list.loading&&!list.items.length&&<p className="empty">{list.query?'No matches':'No collections yet'}</p>}</div><footer className="form-actions"><span>{selection.length} selected</span><Button type="button" variant="ghost" onClick={()=>setSelection([])}>Clear</Button><Button type="button" disabled={selection.length>100} onClick={()=>{onChange(selection);setPicking(false)}}>Link selected</Button><Dialog.Close asChild><Button type="button" variant="ghost">Cancel</Button></Dialog.Close></footer></Dialog.Content></Dialog.Portal></Dialog.Root></section>
}
export function CollectionManager({onBack,initial}:{onBack:()=>void;initial?:ImageGroup}){
 const list=usePage<ImageGroup>('/media_groups'),[editing,setEditing]=useState<ImageGroup|null>(initial||null),[error,setError]=useState(''),newDraft=useNewDraft<ImageGroup>('media_groups',opened,setError)
 function opened(group:ImageGroup){setEditing(group);history.replaceState(null,'',`/admin?section=media&collection=${group.id}`)}
 useEffect(()=>{const id=new URLSearchParams(location.search).get('collection');if(id&&!initial)void edit(id)},[])
 async function edit(id:string){try{opened(await api<ImageGroup>(`/media_groups/${id}`))}catch(e){setError(errorText(e))}}
 if(editing)return <CollectionEditor key={editing.id} initial={editing} onDone={()=>{setEditing(null);history.replaceState(null,'','/admin?section=media&collections=1');list.reload()}}/>
 return <><SearchField label="Search collections" query={list.query} onChange={list.setQuery}/><HeaderTools><Button variant="ghost" onClick={onBack}>Photos</Button><span className="collection-view-name">Collections</span></HeaderTools><CollectionToolbar><Button aria-label="New collection" title="New collection" size="icon" disabled={newDraft.creating} onClick={()=>void newDraft.create()}><Plus/></Button></CollectionToolbar><Message error={error||list.error}/><ul className="record-list collection-list">{list.items.map(group=><li key={group.id}><button className="record-link" onClick={()=>void edit(group.id)}>{group.cover_id?<img src={`/api/admin/media/${group.cover_id}/thumbnail`} alt=""/>:<Images size={32} aria-hidden="true"/>}<span><strong>{group.title}</strong><small>{group.photo_count} photos</small></span></button></li>)}</ul><LoadMoreBoundary {...list}/>{!list.loading&&!list.items.length&&<p className="empty">{list.query?'No matches':'No collections yet'}</p>}</>
}
function CollectionEditor({initial,onDone}:{initial:ImageGroup;onDone:()=>void}){
 const [draft,setDraft]=useState(initial),[snapshot,setSnapshot]=useState(JSON.stringify(initial)),[picking,setPicking]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),saving=useRef(false),setPreview=useContext(PreviewContext)
 const [memberPage,setMemberPage]=useState(1)
 const remote=useRemoteDraft('media_groups',draft,setDraft,snapshot,setSnapshot,busy)
 const autosave=useAutosave({recordKey:`media_groups/${draft.id}`,dirty:JSON.stringify(draft)!==snapshot,blocked:remote.blocked,busy,save:()=>save(true)})
 useEffect(()=>{setPreview(picking?null:{kind:'media_groups',data:draft,onClose:()=>setPreview(null)});return()=>setPreview(null)},[JSON.stringify(draft),picking,setPreview])
 async function save(automatic=false){if(saving.current||remote.blocked)return;saving.current=true;setBusy(true);const sent=structuredClone(draft);try{const saved=await api<ImageGroup>(`/media_groups/${draft.id}`,'PUT',sent);setDraft(current=>mergeDraft(sent,current,saved).next);setSnapshot(JSON.stringify(saved));autosave.saved();setError('');setNotice(automatic?'Saved automatically.':'Saved')}catch(e){setError(errorText(e))}finally{saving.current=false;setBusy(false)}}
 function back(){if(JSON.stringify(draft)===snapshot||confirm('Leave without saving changes to this collection?'))onDone()}
 async function remove(){if(!confirm('Delete this collection? Its photos will stay in the library.'))return;try{await api(`/media_groups/${draft.id}`,'DELETE');onDone()}catch(e){setError(errorText(e))}}
 function move(index:number,delta:number){const ids=[...draft.media_ids];[ids[index],ids[index+delta]]=[ids[index+delta],ids[index]];setDraft(d=>({...d,media_ids:ids}))}
 if(picking)return <Gallery selected={draft.media_ids} maxSelection={2000} onPick={media_ids=>{setDraft(d=>({...d,media_ids}));setPicking(false)}} onCancel={()=>setPicking(false)}/>
 return <><CollectionToolbar><Button variant="ghost" onClick={back}>Collections</Button></CollectionToolbar><form className="editor collection-editor" onSubmit={e=>{e.preventDefault();void save()}}><label>Name<input value={draft.title} maxLength={200} required onChange={e=>setDraft(d=>({...d,title:e.target.value}))}/></label><header className="section-heading"><h2>{draft.media_ids.length} photos</h2><Button type="button" variant="outline" onClick={()=>setPicking(true)}>Choose images</Button></header><ol className="collection-members">{draft.media_ids.slice(0,memberPage*48).map((id,index)=><li key={id}><img src={`/api/admin/media/${id}/thumbnail`} alt={`Photo ${index+1}`} loading="lazy"/><div><Button type="button" variant="ghost" size="icon" disabled={!index} aria-label={`Move photo ${index+1} up`} onClick={()=>move(index,-1)}><ArrowUp size={16}/></Button><Button type="button" variant="ghost" size="icon" disabled={index===draft.media_ids.length-1} aria-label={`Move photo ${index+1} down`} onClick={()=>move(index,1)}><ArrowDown size={16}/></Button><Button type="button" variant="ghost" size="icon" aria-label={`Remove photo ${index+1} from collection`} onClick={()=>setDraft(d=>({...d,media_ids:d.media_ids.filter(value=>value!==id)}))}><X size={16}/></Button></div></li>)}</ol><LoadMoreBoundary page={memberPage} setPage={setMemberPage} total={draft.media_ids.length} items={draft.media_ids.slice(0,memberPage*48)} loadingMore={false}/>{remote.panel}<Message error={error} notice={notice}/><footer className="form-actions"><Button disabled={busy||remote.blocked} type="submit">{busy?'Saving…':'Save collection'}</Button><Button type="button" variant="ghost" onClick={back}>Back</Button><Button type="button" variant="ghost" className="delete-action" disabled={!!draft.uses} onClick={()=>void remove()}>Delete collection</Button></footer></form></>
}
function DraftGallery({group,onClose,returnFocus}:{group:ImageGroup;onClose:()=>void;returnFocus:()=>void}){
 const [page,setPage]=useState(1),[items,setItems]=useState<Media[]>([]),[error,setError]=useState(''),[loading,setLoading]=useState(false),version=useChangeVersion()
 const key=JSON.stringify(group.media_ids)
 useEffect(()=>{setPage(1);setItems([])},[key])
 useEffect(()=>{let active=true;setLoading(true);void Promise.all(group.media_ids.slice(0,page*48).map(id=>api<Media>(`/media/${id}`))).then(rows=>{if(active){setItems(rows);setError('')}}).catch(e=>{if(active)setError(errorText(e))}).finally(()=>{if(active)setLoading(false)});return()=>{active=false}},[key,page,version])
 return <><Message error={error}/><PhotoViewer open onOpenChange={value=>{if(!value)onClose()}} title={group.title} photos={items.map(photo=>({id:photo.id,src:photo.url||photo.thumbnail_url,thumbnail:photo.thumbnail_url,alt:photo.alt||photo.caption||photo.filename,caption:photo.caption}))} total={group.media_ids.length} loading={loading} onLoadMore={()=>setPage(current=>current+1)} returnFocus={returnFocus}/></>
}
export function CollectionPreview({group,compact=false}:{group:ImageGroup;compact?:boolean}){
 const [open,setOpen]=useState(false),opener=useRef<HTMLButtonElement|null>(null)
 return <>{!compact&&<section className="collection-preview-cover"><h2>{group.title}</h2>{group.media_ids[0]&&<img src={`/api/admin/media/${group.media_ids[0]}/thumbnail`} alt=""/>}</section>}<Button ref={opener} type="button" variant="outline" onClick={()=>setOpen(true)}><Images size={17}/>Open gallery <span>{group.media_ids.length} photos</span></Button>{open&&<DraftGallery group={group} onClose={()=>setOpen(false)} returnFocus={()=>opener.current?.focus({preventScroll:true})}/>}</>
}
