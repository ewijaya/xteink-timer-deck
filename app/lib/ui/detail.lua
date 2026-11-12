local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local M=require('lib.core.model');local F=require('lib.core.format');local P=require('lib.core.pulse');local Digits=require('lib.ui.digits');local Draw=require('lib.ui.draw');local N=require('lib.ui.nav')
local D={}
function D.draw(a,g)
 local i=M.find(a.state,a.page.id);if not i then W.top(a,g,S.STALE,true);return end
 W.top(a,g,F.label(i),true,'actions','...')
 local v=M.value(i,a.sec);local minutes=v and not P.seconds(a.state.set.secs,true,i,v)
 local days,time,unit=F.detail(v or 0,i.type==0,minutes)
 if not v then time='--:--' end
 if a.peek then days,time,unit=a.peek.days,a.peek.time,'at '..a.peek.at end
 Draw.ring(g,v or 0,i.type==0 and i.dur or 1,i.type==1 and 'Stopwatch' or ({'Ready','Running','Paused','Finished'})[i.st+1],a.ink)
 W.icon(a,g,i.icon,212,130,56);W.text(a,g,240,200,days~='' and days or string.format('#%02d',i.num),22,'center')
 local h=days~='' and 56 or #time>5 and 64 or 96;Digits.draw(g,time,(480-Digits.width(time,h))//2,248,h,a.ink)
 N.hit(a,70,235,340,112,'peek')
 W.text(a,g,240,362,unit,22,'center')
 local hint=i.type==0 and i.st==1 and v and F.ratio(v,i.dur,100) or 100
 if hint<=10 then g:rect(150,401,180,36,{color=a.ink,fill=true});W.text(a,g,240,408,S.last10,22,'center',a.paper)
 elseif hint<=25 then W.text(a,g,240,408,S.last25,22,'center')
 else W.text(a,g,240,408,i.lim==1 and S.limit or (i.type==1 and S.count_up..' ' or '')..S.states[i.st+1],22,'center') end
 W.text(a,g,240,522,i.type==0 and S.of..F.duration(i.dur) or S.count_up,26,'center')
 if i.st==1 then W.text(a,g,240,560,(i.type==0 and S.ends or S.started)..F.moment(i.anc,a.now),26,'center') end
 if i.type==0 and i.st==1 then W.text(a,g,240,600,a:coverage(i),22,'center') end
 if a.warning then W.text(a,g,240,640,W.fit(a,a.warning,460,22),22,'center') end
 W.button(a,g,16,676,292,112,S.primary[i.st+1],'primary',nil,i.id,i.gen,true,32)
 W.button(a,g,324,676,140,112,S.reset,'reset',nil,i.id,i.gen)
end
return D
