local D={}
D.ratio=require('lib.core.format').ratio
function D.ring(g,remaining,duration,state,ink)
 local cx,cy,r=240,296,200
 g:circle(cx,cy,r,{color=ink,line_width=2})
 if state=='Stopwatch' then
  for n=0,11 do local angle=math.rad(n*30);g:line(cx+math.floor(184*math.cos(angle)),cy+math.floor(184*math.sin(angle)),cx+math.floor(198*math.cos(angle)),cy+math.floor(198*math.sin(angle)),{color=ink,line_width=2}) end
  return
 end
 if state=='Finished' then g:circle(cx,cy,r-12,{color=ink,line_width=2});return end
 local deg=math.max(1,D.ratio(remaining,duration,360))
 if remaining>=duration then g:circle(cx,cy,r,{color=ink,line_width=24})
 elseif remaining>0 then
  if state=='Paused' then
   g:arc(cx,cy,r,630-deg,630,{color=ink,line_width=2});g:arc(cx,cy,r-22,630-deg,630,{color=ink,line_width=2})
  else
   g:arc(cx,cy,r,630-deg,630,{color=ink,line_width=24})
   if D.ratio(remaining,duration,100)<=25 then
    local angle=math.rad(630-deg)
    g:circle(cx+math.floor(188*math.cos(angle)),cy+math.floor(188*math.sin(angle)),16,{color=ink,fill=true})
   end
  end
 end
end
return D
