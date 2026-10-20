// A single outside perimeter avoids doubled strokes at the attached editor tab.
export function fieldPresenceShape(width:number,height:number,tabWidth:number,tabHeight:number){
 if(width<20||height<4)return {outline:"",tab:""}
 const l=1,t=1,r=width-1,b=height-1,bottom=b+tabHeight
 const radius=Math.min(8,(height-2)/2),join=Math.min(6,tabHeight/2)
 if(tabWidth<1||tabHeight<1)return {outline:`M ${l+radius} ${t} H ${r-radius} Q ${r} ${t} ${r} ${t+radius} V ${b-radius} Q ${r} ${b} ${r-radius} ${b} H ${l+radius} Q ${l} ${b} ${l} ${b-radius} V ${t+radius} Q ${l} ${t} ${l+radius} ${t} Z`,tab:""}
 const x=Math.max(l+radius+join,r-tabWidth)
 const tab=`M ${x-join} ${b} Q ${x} ${b} ${x} ${b+join} V ${bottom-join} Q ${x} ${bottom} ${x+join} ${bottom} H ${r-join} Q ${r} ${bottom} ${r} ${bottom-join} V ${b} Z`
 const outline=`M ${l+radius} ${t} H ${r-radius} Q ${r} ${t} ${r} ${t+radius} V ${bottom-join} Q ${r} ${bottom} ${r-join} ${bottom} H ${x+join} Q ${x} ${bottom} ${x} ${bottom-join} V ${b+join} Q ${x} ${b} ${x-join} ${b} H ${l+radius} Q ${l} ${b} ${l} ${b-radius} V ${t+radius} Q ${l} ${t} ${l+radius} ${t} Z`
 return {outline,tab}
}
