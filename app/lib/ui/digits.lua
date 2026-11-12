local D={}
local segments={'1110111','0010010','1011101','1011011','0111010','1101011','1101111','1010010','1111111','1111011'}
local cache,order={},{}
function D.width(s,h)
 local n=0;for i=1,#s do n=n+(s:sub(i,i)==':' and 22*h//100 or 55*h//100)+14*h//100 end
 return n-14*h//100
end
local function rect(g,x,y,w,h,color,radius) g:rect(x,y,w,h,{color=color,fill=true,radius=radius}) end
function D.draw(g,s,x,y,h,color)
 local w,gap,t=55*h//100,14*h//100,math.max(4,11*h//100)
 local boxes=cache[h]
 if not boxes then
  local half=(h-t)//2;boxes={{0,0,w,t},{0,0,t,half},{w-t,0,t,half},{0,half,w,t},{0,half,t,h-half},{w-t,half,t,h-half},{0,h-t,w,t}}
  if #order==12 then cache[table.remove(order,1)]=nil end;order[#order+1]=h;cache[h]=boxes
 end
 for i=1,#s do
  local ch=s:sub(i,i)
  if ch==':' then rect(g,x,y+h//3,t,t,color,t//2);rect(g,x,y+2*h//3,t,t,color,t//2);x=x+22*h//100+gap
  elseif ch=='-' then rect(g,x,y+(h-t)//2,w,t,color,t//2);x=x+w+gap
  else
   local bits=assert(segments[tonumber(ch)+1])
   for k,b in ipairs(boxes) do if bits:sub(k,k)=='1' then rect(g,x+b[1],y+b[2],b[3],b[4],color,t//2) end end;x=x+w+gap
  end
 end
end
return D
