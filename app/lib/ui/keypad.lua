local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local F=require('lib.core.format');local Digits=require('lib.ui.digits')
local K={}
function K.draw(a,g)
 local p=a.page;W.top(a,g,p.edit and S.time or S.new_timer,true)
 local v=(p.days or 0)*86400+F.keypad_seconds(p.digits)
 local days,time=F.detail(v,true,false);local h=56
 Digits.draw(g,time,(480-Digits.width(time,h))//2,p.edit and 150 or 110,h,a.ink)
 if p.edit then
  W.text(a,g,240,88,(p.days or 0)..' '..S.days,26,'center')
  for n,step in ipairs({-10,-1,1,10}) do W.button(a,g,(n-1)*120,214,120,56,step>0 and '+'..step or tostring(step),'days',step) end
 else W.text(a,g,240,174,days~='' and days or S.keypad_hint,22,'center') end
 local y0=p.edit and 276 or 200;local cell=p.edit and 84 or 92
 for n,key in ipairs({'1','2','3','4','5','6','7','8','9','00','0',S.backspace_glyph}) do W.button(a,g,(n-1)%3*160,y0+(n-1)//3*cell,160,cell,key,'digit',key==S.backspace_glyph and 'back' or key,nil,nil,false,32) end
 if p.edit then W.button(a,g,16,688,448,96,S.done,'time_done',nil,nil,nil,true,32)
 else
  W.button(a,g,16,580,448,96,S.start_timer,'create',true,nil,nil,true,32)
  W.button(a,g,16,688,216,88,S.save,'create',false);W.button(a,g,248,688,216,88,S.more,'more')
 end
end
return K
