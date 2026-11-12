local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local C=require('lib.core.const')
local U={}
function U.draw(a,g)
 local kind=a.page.kind;W.top(a,g,kind=='menu' and S.menu or S.settings,true)
 local rows={}
 if kind=='menu' then rows={{label=S.new_watch,action='new_watch'},{label=S.settings,action='settings'},{label=S.help,action='help'},{label=S.info,action='info'}}
 else
  local set=a.state.set
  rows={{label=S.flash,value=S.onoff[set.flash+1],action='setting',arg='flash'}}
  if a.ctx.frontlight then rows[#rows+1]={label=S.light,value=S.onoff[set.light+1],action='setting',arg='light'} end
  if not W.count_enabled(a) then rows[#rows].note=S.screen_only end
  if W.pattern_enabled(a) then rows[#rows+1]={label=S.alert,value=C.PATTERNS[set.pat+1],action='setting',arg='pat'} end
  if W.count_enabled(a) then rows[#rows+1]={label=S.count,value=tostring(set.cnt),action='setting',arg='cnt'} end
  rows[#rows+1]={label=S.seconds,value=S.seconds_modes[set.secs+1],action='setting',arg='secs'}
  if a.ctx.device.keep_awake then rows[#rows+1]={label=S.awake,value=S.onoff[set.awake+1],note=S.battery,action='setting',arg='awake'} end
  if a.ctx.lockscreen then rows[#rows+1]={label=S.lockscreen,value=S.onoff[a.lock_default and 2 or 1],action='lockscreen'} end
  rows[#rows+1]={label=S.sync,action='sync'}
 end
 W.rows(a,g,rows)
 if kind=='settings' then W.button(a,g,16,712,448,88,W.count_enabled(a) and S.test_alert or '',W.count_enabled(a) and 'test_alert' or nil);if not W.count_enabled(a) then W.text(a,g,240,722,S.test_alert,26,'center');W.text(a,g,240,754,S.channels_off,22,'center') end end
end
return U
