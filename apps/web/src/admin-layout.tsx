import { createContext, useContext, useState, type ReactNode } from "react"
import { createPortal } from "react-dom"
import { SidebarTrigger } from "@/components/ui/sidebar"

const Slots = createContext<{search:HTMLElement|null;actions:HTMLElement|null;tools:HTMLElement|null}|null>(null)
export function WorkspaceHeader({children,sidebar=true}:{children:ReactNode;sidebar?:boolean}){
 const [tools,setTools]=useState<HTMLDivElement|null>(null)
 const [search,setSearch]=useState<HTMLDivElement|null>(null),[actions,setActions]=useState<HTMLDivElement|null>(null)
 return <Slots.Provider value={{search,actions,tools}}><header className="workspace-header">{sidebar&&<SidebarTrigger/>}<div className="header-search" ref={setSearch}/><div className="header-tools" ref={setTools}/><div className="header-actions" ref={setActions}/></header>{children}</Slots.Provider>
}
export function HeaderSearch({children}:{children:ReactNode}){const slots=useContext(Slots);return slots?(slots.search?createPortal(children,slots.search):null):children}
export function CollectionToolbar({children}:{children:ReactNode}){const slots=useContext(Slots);return slots?(slots.actions?createPortal(children,slots.actions):null):<header className="collection-toolbar">{children}</header>}

export function HeaderTools({children}:{children:ReactNode}){const slots=useContext(Slots);return slots?(slots.tools?createPortal(children,slots.tools):null):children}
