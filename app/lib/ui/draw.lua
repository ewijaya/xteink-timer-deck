local D={}
D.ratio=require('lib.core.format').ratio
function D.ring(g,remaining,duration,state,ink,style,cx,cy,r)
 cx,cy,r=cx or 240,cy or 296,r or 200;style=style or 0
 local deg=remaining>0 and math.max(1,D.ratio(remaining,duration,360)) or 0
 local function arc(radius,start,finish,width)
  if finish-start>=360 then g:circle(cx,cy,radius,{color=ink,line_width=width})
  elseif finish>start then g:arc(cx,cy,radius,start,finish,{color=ink,line_width=width}) end
 end
 if state=='Finished' then g:circle(cx,cy,r,{color=ink,line_width=2});g:circle(cx,cy,r-12,{color=ink,line_width=2});return end
 if state=='Paused' then g:circle(cx,cy,r,{color=ink,line_width=2});arc(r,630-deg,630,2);arc(r-22,630-deg,630,2);return end
 if state=='Stopwatch' then
  g:circle(cx,cy,r,{color=ink,line_width=2})
  for n=0,11 do local angle=math.rad(n*30);g:line(cx+math.floor((r-16)*math.cos(angle)),cy+math.floor((r-16)*math.sin(angle)),cx+math.floor((r-2)*math.cos(angle)),cy+math.floor((r-2)*math.sin(angle)),{color=ink,line_width=2}) end;return
 end
 if style==1 then
  for n=0,59 do local angle=270+n*6;local active=angle+4>=630-deg;arc(r,angle,angle+4,active and 24 or 3) end
 elseif style==3 then
  for n=0,11 do local start=270+n*30+1;local finish=start+28;arc(r,start,finish,2);arc(r,math.max(start,630-deg),finish,24) end
 else
  g:circle(cx,cy,r,{color=ink,line_width=2});arc(r,630-deg,630,style==2 and 12 or 24)
  if style==2 then arc(r-16,630-deg,630,4) end
 end
 if state=='Running' and remaining>0 and D.ratio(remaining,duration,100)<=25 then
  local angle=math.rad(630-deg);g:circle(cx+math.floor((r-12)*math.cos(angle)),cy+math.floor((r-12)*math.sin(angle)),16,{color=ink,fill=true})
 end
end
function D.bar(g,x,y,width,value,total,ink,style)
 local w=D.ratio(value,total,width);local h=D.ratio(value,total,100)<=25 and 8 or 4
 if style==1 then for n=0,11 do local start=n*width//12;local finish=math.min(w,(n+1)*width//12-3);if finish>start then g:rect(x+start,y,finish-start,h,{color=ink,fill=true}) end end
 elseif style==2 then if w>0 then g:rect(x,y,w,2,{color=ink,fill=true});g:rect(x,y+5,w,2,{color=ink,fill=true}) end
 else if w>0 then g:rect(x,y,w,h,{color=ink,fill=true});if style==3 then g:rect(x+w-3,y-3,3,h+6,{color=ink,fill=true}) end end end
end
return D
