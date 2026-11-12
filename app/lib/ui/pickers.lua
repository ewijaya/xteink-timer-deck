local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local C=require('lib.core.const')
local P={}
function P.draw(a,g)
 local p=a.page;W.top(a,g,p.title,true)
 if p.kind=='icons' then
  for n=0,C.ICON_COUNT do local x=n%5*96;local y=80+n//5*88
   W.icon(a,g,n,x+20,y+10,56,true);require('lib.ui.nav').hit(a,x,y,96,88,'pick',n)
   if p.value==n then g:rect(x+2,y+2,92,84,{color=a.ink,line_width=4}) end
  end
  W.text(a,g,240,720,C.ICON_NAMES[p.value] or S.none,26,'center')

 else
  for n,label in ipairs(p.options) do local y=88+(n-1)*104
   W.button(a,g,16,y,p.key=='pat' and 312 or 448,96,label,'pick',n-1,nil,nil,p.value==n-1,26)
   if p.key=='pat' then W.button(a,g,336,y,128,96,S.preview,'preview_pattern',n-1,nil,nil,false,22) end
  end
 end
end
return P
