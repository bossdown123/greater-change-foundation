export const POINTER_SURFACES={sidebar:'[data-sidebar=sidebar]',header:'.workspace-header',configuration:'.configuration-panel',preview:'.output-panel',workspace:'.workspace'} as const
export type PointerSurface=keyof typeof POINTER_SURFACES
function anchorKey(element:HTMLElement){if(element.dataset.cursorAnchor)return `item:${element.dataset.cursorAnchor}`;if(element.dataset.mediaId)return `media:${element.dataset.mediaId}`;const label=element.getAttribute('aria-label');return label?`control:${label}`:undefined}
export function pointerSurface(target:EventTarget|null){
 if(!target||typeof (target as Element).closest!=='function')return null
 const node=target as Element
 for(const [surface,selector] of Object.entries(POINTER_SURFACES)){
  const region=node.closest<HTMLElement>(selector);if(!region)continue
  const anchor=node.closest<HTMLElement>('[data-cursor-anchor],[data-media-id],button[aria-label]')
  return {surface:surface as PointerSurface,anchor:anchor&&region.contains(anchor)?anchorKey(anchor):undefined,element:anchor&&region.contains(anchor)?anchor:region}
 }
 return null
}
export function resolvePointerSurface(surface:PointerSurface,anchor?:string){
 const region=document.querySelector<HTMLElement>(POINTER_SURFACES[surface]);if(!region)return null
 if(!anchor)return region
 return [...region.querySelectorAll<HTMLElement>('[data-cursor-anchor],[data-media-id],button[aria-label]')].find(element=>anchorKey(element)===anchor)||null
}
