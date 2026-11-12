local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local M=require('lib.core.model');local F=require('lib.core.format');local P=require('lib.core.pulse');local N=require('lib.ui.nav')
local D={}
function D.draw(a,g)
 W.text(a,g,20,24,S.title,32);W.text(a,g,460,28,#a.state.items..'/10  '..F.clock(a.now),22,'right');g:line(0,79,479,79,{color=a.ink,line_width=2})
 local strip=a.warning or (not a.sec and S.clock_unset) or a.coverage_warning
 local area=strip and 590 or 630
 local entries={};if a.chain_entry then entries[1]=a.chain_entry end;for _,i in ipairs(a.state.items) do entries[#entries+1]=i end
 local height=math.max(63,math.min(104,area//math.max(#entries,6)));local per=area//height
 local page=a.page.offset or 0;a.page_count=math.max(1,(#entries+per-1)//per)
 for row=1,per do local i=entries[page*per+row];if not i then break end
  local y=80+(row-1)*height;local v=i.chain and i.val or M.value(i,a.sec)
  if a.delete_arm and a.delete_arm.id==i.id then
   W.text(a,g,20,y+5,W.fit(a,'Delete '..F.label(i)..'?',270,22),22)
   W.button(a,g,0,y+height-56,240,56,S.delete,'delete',nil,i.id,i.gen);W.button(a,g,240,y+height-56,240,56,S.keep,'keep')
  else
   if i.icon>0 then W.icon(a,g,i.icon,12,y+(height-44)//2,44) else g:rect(12,y+(height-44)//2,44,44,{color=a.ink,line_width=2,radius=7});W.text(a,g,34,y+(height-26)//2,string.format('%02d',i.num),22,'center') end
   local seconds=v and P.seconds(a.state.set.secs,false,i,v)
   local value=v and F.compact(v,i.type==0,not seconds,a.state.set.secs==2) or '--:--'
   local labelsize=a.fonts[32]:measure(F.label(i))<=185 and 32 or 26
   W.text(a,g,80,y+9,W.fit(a,F.label(i),185,labelsize),labelsize)
   local valuesize=a.fonts[40]:measure(value)<=124 and 40 or a.fonts[26]:measure(value)<=124 and 26 or 22
   W.text(a,g,392,y+9,W.fit(a,value,124,valuesize),valuesize,'right')
   if height>=79 then W.text(a,g,80,y+43,i.lim==1 and S.limit or i.st~=1 and S.states[i.st+1] or '',22) end
   if v and i.type==0 and (i.st==1 or i.st==2) then g:rect(80,y+height-10,F.ratio(v,i.dur,312),4,{color=a.ink,fill=true}) end
   N.hit(a,0,y,400,height,i.chain and 'chain_run' or 'detail',nil,i.id,i.gen)
   W.button(a,g,400,y,80,height,i.st==1 and 'II' or i.st==3 and 'OK' or '>','primary',nil,i.id,i.gen)
  end
  if a.focus==page*per+row then g:rect(2,y+2,476,height-4,{color=a.ink,line_width=4}) end
  g:line(0,y+height-1,479,y+height-1,{color=a.ink})
 end
 if #entries==0 then
  g:circle(240,200,70,{color=a.ink,line_width=6});W.text(a,g,240,310,S.empty,32,'center')
  g:text_box(28,370,424,190,S.notice,{font=a.fonts[26],color=a.ink})
  W.button(a,g,16,580,448,96,S.new_timer,'new_timer',nil,nil,nil,true,32)
 end
 if strip then g:rect(0,670,480,40,{fill=true,color=a.ink});W.text(a,g,240,679,W.fit(a,strip,470,22),22,'center',a.paper) end
 W.button(a,g,0,712,160,88,S.new_timer,'new_timer',nil,nil,nil,false,22)
 W.button(a,g,160,712,160,88,S.chains,'chains',nil,nil,nil,false,22)
 W.button(a,g,320,712,160,88,S.menu,'menu',nil,nil,nil,false,22)
end
return D
