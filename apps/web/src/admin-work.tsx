import {useEffect,useState} from 'react'
import {DropdownMenu} from 'radix-ui'
import {Plus,CalendarDays,FolderHeart,HandCoins,LoaderCircle} from 'lucide-react'
import {Button} from '@/components/ui/button'
import {HeaderTools,CollectionToolbar} from './admin-layout'
import {api,errorText,usePage,useNewDraft,SearchField,LoadMoreBoundary,Message,EventEditor,ProgramEditor,type Kind,type EventData,type Program} from './admin'
import {documentText} from './rich-document'
import {PresenceDots} from './realtime'
type Item={id:string;title:string;summary:string;kind:Kind}
type Editing={kind:Kind;record:EventData|Program}
export const workLabel={events:'Activity',campaigns:'Fundraiser',initiatives:'Campaign / programme'}
export function Work(){
 const [filter,setFilter]=useState('all'),[editing,setEditing]=useState<Editing|null>(null),[error,setError]=useState(''),list=usePage<Item>(`/work?kind=${filter}`)
 const opened=(kind:Kind)=>(record:EventData|Program)=>{setEditing({kind,record});history.replaceState(null,'',`/admin?section=work&kind=${kind}&id=${record.id}`)}
 const activity=useNewDraft<EventData>('events',opened('events'),setError),fundraiser=useNewDraft<Program>('campaigns',opened('campaigns'),setError),campaign=useNewDraft<Program>('initiatives',opened('initiatives'),setError)
 async function edit(kind:Kind,id:string){try{opened(kind)(await api<EventData|Program>(`/${kind}/${id}`));setError('')}catch(e){setError(errorText(e))}}
 useEffect(()=>{const query=new URLSearchParams(location.search),kind=query.get('kind'),id=query.get('id');if(id&&['events','campaigns','initiatives'].includes(kind||''))void edit(kind as Kind,id)},[])
 function done(){setEditing(null);history.replaceState(null,'','/admin?section=work');list.reload()}
 if(editing)return editing.kind==='events'?<EventEditor initial={editing.record as EventData} onDone={done}/>:<ProgramEditor kind={editing.kind} initial={editing.record as Program} onDone={done}/>
 return <><SearchField label="Search work" query={list.query} onChange={list.setQuery}/><HeaderTools><label className="work-filter"><span className="sr-only">Type of work</span><select value={filter} onChange={e=>setFilter(e.target.value)}><option value="all">All work</option>{Object.entries(workLabel).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label></HeaderTools><CollectionToolbar><DropdownMenu.Root><DropdownMenu.Trigger asChild><Button size="icon" aria-label="Add work" disabled={activity.creating||fundraiser.creating||campaign.creating}>{activity.creating||fundraiser.creating||campaign.creating?<LoaderCircle className="animate-spin"/>:<Plus/>}</Button></DropdownMenu.Trigger><DropdownMenu.Portal><DropdownMenu.Content className="work-create-menu" align="end" sideOffset={6}><DropdownMenu.Item onSelect={()=>void activity.create()}><CalendarDays size={16}/>Activity</DropdownMenu.Item><DropdownMenu.Item onSelect={()=>void fundraiser.create()}><HandCoins size={16}/>Fundraiser</DropdownMenu.Item><DropdownMenu.Item onSelect={()=>void campaign.create()}><FolderHeart size={16}/>Campaign / programme</DropdownMenu.Item></DropdownMenu.Content></DropdownMenu.Portal></DropdownMenu.Root></CollectionToolbar><Message error={error||list.error}/><ul className="record-list">{list.items.map(item=><li key={`${item.kind}/${item.id}`}><button className="record-link" data-cursor-anchor={`${item.kind}:${item.id}`} onClick={()=>void edit(item.kind,item.id)}><strong>{item.title}</strong><span>{documentText(item.summary)}</span><small>{workLabel[item.kind]}</small><PresenceDots section="work" resourceId={item.id}/></button></li>)}</ul>{!list.loading&&!list.items.length&&<p className="empty">{list.query?'No matches':'No work yet'}</p>}<LoadMoreBoundary {...list}/></>
}
