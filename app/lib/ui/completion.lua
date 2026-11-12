local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local M=require('lib.core.model');local F=require('lib.core.format');local Digits=require('lib.ui.digits')
local Q={}
function Q.draw(a,g)
 local q=a.queue;local pos=math.min(a.queue_pos or 1,#q);local ref=q[pos];local i=ref and M.find(a.state,ref.id)
 if not i then W.top(a,g,S.states[4],true);return end
 local title=i.late==1 and (#q==1 and S.finished_away or string.format(S.away_queue,pos,#q)) or string.format(S.queue,pos,#q)
 g:rect(0,0,480,80,{color=a.ink,fill=true});W.text(a,g,300,24,W.fit(a,title,328,32),32,'center',a.paper)
 g:rect(2,2,116,76,{color=a.paper,line_width=2,radius=8});W.text(a,g,60,28,S.back,22,'center',a.paper);require('lib.ui.nav').hit(a,0,0,120,80,'back')
 W.icon(a,g,i.icon,192,110,96);W.text(a,g,240,230,W.fit(a,F.label(i),450,40),40,'center')
 Digits.draw(g,'00:00',(480-Digits.width('00:00',96))//2,310,96,a.ink)
 W.text(a,g,240,440,S.states[4],32,'center');W.text(a,g,240,490,S.finished_prefix..F.moment(i.done,a.now),26,'center')
 if #q>1 then W.button(a,g,16,560,120,88,S.prev_glyph,'browse',-1);W.button(a,g,344,560,120,88,S.next_glyph,'browse',1) end
 W.button(a,g,16,676,#q>1 and 292 or 448,112,S.dismiss,'dismiss',nil,i.id,i.gen,true,32)
 if #q>1 then W.button(a,g,324,676,140,112,S.clear_all,'clear_all',nil,nil,nil,false,22) end
end
return Q
