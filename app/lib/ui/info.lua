local W=require('lib.ui.widgets');local S=require('lib.ui.strings')
local I={}
function I.draw(a,g)
 local p=a.page
 if p.kind=='help' then
  W.top(a,g,p.title or S.help_title,true)
  if a.help_topics and not p.pages then for _,topic in ipairs(a.help_topics[(p.offset or 0)+1] or {}) do W.text(a,g,20,topic.y,topic.heading,26,nil,nil,true);g:text_box(20,topic.y+34,420,topic.height,topic.body,{font=a.fonts[26],color=a.ink}) end
  else local text=(p.pages or a.help_pages)[(p.offset or 0)+1] or '';g:text_box(20,100,440,540,text,{font=a.fonts[26],color=a.ink}) end
  W.pager(a,g,p.offset or 0,#(p.pages or a.help_pages))
 else W.top(a,g,S.info,true);local rows={};for _,line in ipairs(a.diagnostics) do rows[#rows+1]={label=line} end;W.rows(a,g,rows) end
end
return I
