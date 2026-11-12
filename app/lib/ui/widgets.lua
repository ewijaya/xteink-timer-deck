local Nav=require('lib.ui.nav');local S=require('lib.ui.strings');local Glyph=require('lib.ui.glyphs')
local W={}
function W.colors(flash) return flash and 0 or 15,flash and 15 or 0 end
function W.pattern_enabled(a) return a.ctx.frontlight~=nil and a.state.set.light==1 end
function W.count_enabled(a) return a.state.set.flash==1 or W.pattern_enabled(a) end
function W.text(a,g,x,y,text,size,align,color,bold)
 g:text(x,y,tostring(text),{font=a.fonts[size or 26],align=align or 'left',color=color or a.ink,tabular=true,bold=bold or false})
end
function W.fit(a,text,width,size,bold)
 local f=a.fonts[size or 26];text=tostring(text)
 if f:measure(text,{bold=bold or false,tabular=true})<=width then return text end
 while #text>0 and f:measure(text..'...',{bold=bold or false,tabular=true})>width do text=text:sub(1,assert(utf8.offset(text,-1))-1) end
 return text..'...'
end
function W.button(a,g,x,y,w,h,label,action,arg,id,gen,filled,size,bold)
 local fill=filled or false
 g:rect(x+2,y+2,w-4,h-4,{color=a.ink,line_width=2,radius=8,fill=fill})
 local glyph=type(label)=='table' and label.glyph;local caption=label;if type(label)=='table' then caption=label.text end
 local ink=fill and a.paper or a.ink;local weight=bold==nil and fill or bold
 if glyph then Glyph.draw(g,glyph,caption and x+8 or x+(w-32)//2,y+(h-32)//2,32,ink) end
 if caption then local f=a.fonts[size or 26];g:text(x+w//2+(glyph and 12 or 0),y+(h-f.line_height)//2,W.fit(a,caption,w-(glyph and 44 or 12),size,weight),{font=f,align='center',color=ink,tabular=true,bold=weight or false}) end
 if action then Nav.hit(a,x,y,w,h,action,arg,id,gen) end
end
function W.top(a,g,title,back,action,label)
 if back then W.button(a,g,0,0,120,80,S.back,'back',nil,nil,nil,false,22) end
 local size=back and a.fonts[32]:measure(title,{bold=true,tabular=true})>190 and 26 or 32
 W.text(a,g,back and 240 or 20,24,W.fit(a,title,back and 208 or 440,size,true),size,back and 'center' or 'left',nil,true)
 if action then W.button(a,g,360,0,120,80,label,action,nil,nil,nil,false,22) end
 g:line(0,79,479,79,{color=a.ink,line_width=2})
end
function W.pager(a,g,page,count,bottom)
 a.page_count=count;if count<=1 then return end
 local y=(bottom or 712)-56
 W.text(a,g,240,y+17,string.format(S.pager,page+1,count),22,'center')
 Glyph.draw(g,'chevron-left',12,y+12,32,a.ink);Glyph.draw(g,'chevron-right',436,y+12,32,a.ink)
 Nav.hit(a,0,y,240,56,'page',-1);Nav.hit(a,240,y,240,56,'page',1)
end
function W.rows(a,g,rows)
 local area=632;local count=1;local per=#rows
 if #rows*72>area then area=area-56;per=area//72;count=(#rows+per-1)//per end
 per=math.max(1,per);local height=math.max(72,math.min(96,area//per));local page=math.min(a.page.offset or 0,count-1)
 for n=1,per do
  local row=rows[page*per+n];if not row then break end
  local y=80+(n-1)*height
  if row.armed then
   W.text(a,g,20,y+3,W.fit(a,string.format(a.state.ch.run.id==row.arg and a.state.ch.run.st~=0 and S.stop_delete_label or S.delete_label,row.delete_label or row.label),440,22),22)
   W.button(a,g,0,y+height-56,240,56,S.delete,row.item and 'delete' or 'ch_delete_inline',row.arg,row.id,row.gen);W.button(a,g,240,y+height-56,240,56,S.keep,'ch_keep')
  else
   local right=row.play and 340 or row.stepper and 280 or 444
   local value=row.value and W.fit(a,row.value,math.min(200,right-200),26)
   local value_width=value and a.fonts[26]:measure(value,{bold=false,tabular=true}) or 0
   local available=right-20-(value and value_width+32 or 0)
   local size=a.fonts[32]:measure(row.label,{bold=true,tabular=true})<=available and 32 or 26
   local text_y=y+(row.note and 8 or (height-32)//2)
   W.text(a,g,20,text_y,W.fit(a,row.label,available,size,true),size,nil,nil,true)
   if value then W.text(a,g,right,text_y+3,value,26,'right') end
   if row.note then W.text(a,g,20,y+height-27,W.fit(a,row.note,440,22),22) end
   g:line(16,y+height-1,464,y+height-1,{color=a.ink})
   if row.stepper then
    W.button(a,g,312,y,80,height,S.minus,'ch_rounds',-1);W.button(a,g,400,y,80,height,{glyph='plus'},'ch_rounds',1)
   elseif row.action then
    Nav.hit(a,0,y,row.play and 360 or 480,height,row.action,row.arg,row.id,row.gen)
    if not row.play and row.action~='ch_select' and not (row.action=='setting' and (row.arg=='flash' or row.arg=='light' or row.arg=='awake')) and row.action~='lockscreen' then Glyph.draw(g,'chevron-right',450,y+(height-24)//2,24,a.ink) end
   end
   if row.play then W.button(a,g,360,y,120,height,{glyph='play'},'ch_start',row.arg) end
  end
 end
 W.pager(a,g,page,count)
end
local cache,order={},{}
function W.icon(a,g,index,x,y,size,nocache)
 if index==0 then g:circle(x+size//2,y+size//2,size//2-2,{color=a.ink,line_width=2});return end
 local key=index..':'..size..':'..x..':'..y;local lines=not nocache and cache[key]
 if not lines then
  lines={};for _,s in ipairs(require('lib.gen.icons')[index]) do
   local points={};for k=1,#s do points[k]=(s:byte(k)-32)*size//94+(k%2==1 and x or y) end;lines[#lines+1]=points
  end
  if not nocache then
   if #order==12 then cache[table.remove(order,1)]=nil end;order[#order+1]=key;cache[key]=lines
  end
 end
 for _,line in ipairs(lines) do g:polyline(line,{color=a.ink,line_width=size>=96 and 6 or size>=56 and 4 or 3}) end
end
return W
