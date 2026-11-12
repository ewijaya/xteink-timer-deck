local D={}
D.ratio=require('lib.core.format').ratio
function D.ring(g,remaining,duration,state,ink,cx,cy,r)
 cx,cy,r=cx or 240,cy or 296,r or 200
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
 g:circle(cx,cy,r,{color=ink,line_width=2});arc(r,630-deg,630,24)
 if state=='Running' and remaining>0 and D.ratio(remaining,duration,100)<=25 then
  local angle=math.rad(630-deg);g:circle(cx+math.floor((r-12)*math.cos(angle)),cy+math.floor((r-12)*math.sin(angle)),16,{color=ink,fill=true})
 end
end
function D.bar(g,x,y,width,value,total,ink)
 local w=D.ratio(value,total,width);local h=D.ratio(value,total,100)<=25 and 8 or 4
 if w>0 then g:rect(x,y,w,h,{color=ink,fill=true}) end
end
return D
