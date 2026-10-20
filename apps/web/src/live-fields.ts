import {equalValue} from './collaboration-state.ts'
const RICH='gcf-richtext:'
type Merge={value:unknown;conflict:boolean}
// Merge independent text edits; overlapping replacements keep both versions for review.
function textEdit(base:string,value:string){let start=0,end=base.length,last=value.length;while(start<end&&start<last&&base[start]===value[start])start++;while(end>start&&last>start&&base[end-1]===value[last-1]){end--;last--}return {start,end,text:value.slice(start,last)}}
function mergeText(base:string,local:string,remote:string):Merge{
 const a=textEdit(base,local),b=textEdit(base,remote)
 if(a.start===b.start||(a.start<b.end&&b.start<a.end))return {value:local,conflict:true}
 let value=base;for(const edit of [a,b].sort((x,y)=>y.start-x.start))value=value.slice(0,edit.start)+edit.text+value.slice(edit.end)
 return {value,conflict:false}
}
function mergeNode(base:unknown,local:unknown,remote:unknown):Merge{
 if(equalValue(local,remote)||equalValue(base,remote))return {value:local,conflict:false}
 if(equalValue(base,local))return {value:remote,conflict:false}
 if(typeof base==='string'&&typeof local==='string'&&typeof remote==='string')return mergeText(base,local,remote)
 if(Array.isArray(base)&&Array.isArray(local)&&Array.isArray(remote)&&base.length===local.length&&base.length===remote.length){const values=base.map((v,i)=>mergeNode(v,local[i],remote[i]));return {value:values.map(v=>v.value),conflict:values.some(v=>v.conflict)}}
 if(base&&local&&remote&&typeof base==='object'&&typeof local==='object'&&typeof remote==='object'&&!Array.isArray(base)&&!Array.isArray(local)&&!Array.isArray(remote)){
  const output:Record<string,unknown>={};let conflict=false
  for(const key of new Set([...Object.keys(base),...Object.keys(local),...Object.keys(remote)])){const result=mergeNode((base as Record<string,unknown>)[key],(local as Record<string,unknown>)[key],(remote as Record<string,unknown>)[key]);output[key]=result.value;conflict ||= result.conflict}
  return {value:output,conflict}
 }
 return {value:local,conflict:true}
}
export function mergeLiveField(base:unknown,local:unknown,remote:unknown):Merge{
 if(equalValue(local,remote)||equalValue(base,remote))return {value:local,conflict:false}
 if(equalValue(base,local))return {value:remote,conflict:false}
 if(typeof base==='string'&&typeof local==='string'&&typeof remote==='string'){
  if([base,local,remote].every(v=>v.startsWith(RICH))){try{const result=mergeNode(JSON.parse(base.slice(RICH.length)),JSON.parse(local.slice(RICH.length)),JSON.parse(remote.slice(RICH.length)));return {...result,value:RICH+JSON.stringify(result.value)}}catch{return {value:local,conflict:true}}}
  if(![base,local,remote].some(v=>v.startsWith(RICH)))return mergeText(base,local,remote)
 }
 return {value:local,conflict:true}
}
