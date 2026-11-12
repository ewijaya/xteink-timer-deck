local W=require('lib.ui.widgets');local S=require('lib.ui.strings')
local I={}
function I.draw(a,g)
 local p=a.page
 if p.kind=='help' then
  W.top(a,g,'Timer Deck '..require('lib.gen.version'),true)
  require('lib.ui.nav').hit(a,120,0,360,80,'about_tap')
  local text=a.help_pages[(p.offset or 0)+1] or '';g:text_box(20,100,440,590,text,{font=a.fonts[26],color=a.ink})
  W.button(a,g,0,712,240,88,'<','page',-1);W.button(a,g,240,712,240,88,((p.offset or 0)+1)..' / '..#a.help_pages..' >','page',1);a.page_count=#a.help_pages
 else W.top(a,g,S.info,true);local rows={};for _,line in ipairs(a.diagnostics) do rows[#rows+1]={label=line} end;W.rows(a,g,rows) end
end
return I
