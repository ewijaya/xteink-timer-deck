local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local F=require('lib.core.format');local C=require('lib.core.const')
local Form={}
function Form.draw(a,g)
 local d=a.page.draft;W.top(a,g,a.page.id and S.edit or d.type==1 and S.new_watch or S.more,true)
 local rows={}
 if d.type==0 and not a.page.live then rows[#rows+1]={label=S.time,value=d.st==2 and S.reset_duration or F.duration(d.dur),action=d.st~=2 and 'edit_time' or nil} end
 rows[#rows+1]={label=S.name,value=d.name=='' and S.none or d.name,action='name'}
 rows[#rows+1]={label=S.icon,value=C.ICON_NAMES[d.icon] or S.none,action='icons'}
 if d.type==0 and not a.page.live then rows[#rows+1]={label=S.alert,value=C.PATTERNS[d.pat+1],action='pattern'};rows[#rows+1]={label=S.count,value=tostring(d.cnt),action='count'} end
 W.rows(a,g,rows)
 if not a.page.live then
  if not a.page.id and d.type==0 then W.button(a,g,0,712,240,88,S.start_timer,'save_form',true,nil,nil,true);W.button(a,g,240,712,240,88,S.save,'save_form',false)
  else W.button(a,g,0,712,480,88,S.save,'save_form',false,nil,nil,true) end
 end
end
return Form
