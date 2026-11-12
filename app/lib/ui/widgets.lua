local Nav=require('lib.ui.nav')
local W={}
function W.text(a,g,x,y,text,size,align,color)
 g:text(x,y,tostring(text),{font=a.fonts[size or 26],align=align or 'left',color=color or a.ink,tabular=true})
end
function W.fit(a,text,width,size)
 local f=a.fonts[size or 26];text=tostring(text)
 if f:measure(text)<=width then return text end
 while #text>0 and f:measure(text..'...')>width do text=text:sub(1,-2) end
 return text..'...'
end
function W.button(a,g,x,y,w,h,label,action,arg,id,gen,filled,size)
 g:rect(x+2,y+2,w-4,h-4,{color=a.ink,line_width=2,radius=8,fill=filled or false})
 local f=a.fonts[size or 26];g:text(x+w//2,y+(h-f.line_height)//2,W.fit(a,label,w-12,size),{font=f,align='center',color=filled and a.paper or a.ink})
 if action then Nav.hit(a,x,y,w,h,action,arg,id,gen) end
end
function W.top(a,g,title,back,action,label)
 if back then W.button(a,g,0,0,120,80,require('lib.ui.strings').back,'back',nil,nil,nil,false,22) end
 W.text(a,g,back and 240 or 20,24,W.fit(a,title,action and 220 or back and 320 or 440,32),32,back and 'center' or 'left')
 if action then W.button(a,g,360,0,120,80,label,action,nil,nil,nil,false,22) end
 g:line(0,79,479,79,{color=a.ink,line_width=2})
end
function W.rows(a,g,rows)
 local page=a.page.offset or 0;local per=6;local count=math.max(1,(#rows+per-1)//per);page=math.min(page,count-1)
 for n=1,per do
  local row=rows[page*per+n];if not row then break end
  local y=80+(n-1)*96
  W.text(a,g,20,y+16,W.fit(a,row.label,440,row.value and 26 or 32),row.value and 26 or 32)
  if row.value then W.text(a,g,20,y+53,W.fit(a,row.value,440,22),22) end
  g:line(16,y+95,464,y+95,{color=a.ink})
  if row.action then Nav.hit(a,0,y,480,96,row.action,row.arg,row.id,row.gen) end
 end
 if count>1 then W.button(a,g,0,712,240,88,'<','page',-1);W.button(a,g,240,712,240,88,(page+1)..' / '..count..' >','page',1) end
 a.page_count=count
end
local cache,order={},{}
function W.icon(a,g,index,x,y,size,nocache)
 if index==0 then g:circle(x+size//2,y+size//2,size//2-2,{color=a.ink,line_width=2});return end
 local key=index..':'..size;local lines=not nocache and cache[key]
 if not lines then
  lines={};for _,s in ipairs(require('lib.gen.icons')[index]) do
   local points={};for k=1,#s do points[k]=(s:byte(k)-32)*size//94 end;lines[#lines+1]=points
  end
  if not nocache then
   if #order==12 then cache[table.remove(order,1)]=nil end;order[#order+1]=key;cache[key]=lines
  end
 end
 for _,line in ipairs(lines) do local p={};for k,v in ipairs(line) do p[k]=v+(k%2==1 and x or y) end;g:polyline(p,{color=a.ink,line_width=size>=96 and 6 or size>=56 and 4 or 3}) end
end
return W
