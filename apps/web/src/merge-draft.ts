export type Conflict={field:string;mine:unknown;theirs:unknown}
const same=(a:unknown,b:unknown)=>JSON.stringify(a)===JSON.stringify(b)
export function mergeDraft<T extends object>(base:T,local:T,remote:T){
 const next={...remote},conflicts:Conflict[]=[]
 for(const field of Object.keys(local) as (keyof T)[]){
  if(["updated_at","updated_by","modifier_name"].includes(String(field)))continue
  if(!same(local[field],base[field])){
   next[field]=local[field]
   if(!same(remote[field],base[field])&&!same(remote[field],local[field]))conflicts.push({field:String(field),mine:local[field],theirs:remote[field]})
  }
 }
 return {next,conflicts}
}
