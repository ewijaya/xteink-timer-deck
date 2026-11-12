local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local C=require('lib.core.const')
local U={}
function U.draw(a,g)
 local kind=a.page.kind;W.top(a,g,kind=='menu' and S.menu or kind=='actions' and S.edit or S.settings,true)
 local rows={}
 if kind=='menu' then rows={{label=S.new_watch,action='new_watch'},{label=S.settings,action='settings'},{label=S.help,action='help'}}
 elseif kind=='actions' then rows={{label=S.edit,action='edit'},{label=S.delete,action='delete',id=a.page.id,gen=a.page.gen}}
 else
  local set=a.state.set
  rows={{label=S.appearance,value=S.appearances[set.app+1],action='setting',arg='app'},{label=S.style,value=S.styles[set.style+1],action='setting',arg='style'},{label=S.default_alert,value=C.PATTERNS[set.pat+1],action='setting',arg='pat'},{label=S.default_count,value=tostring(set.cnt),action='setting',arg='cnt'},{label=S.flash,value=S.onoff[set.flash+1],action='setting',arg='flash'}}
  if a.ctx.frontlight then rows[#rows+1]={label=S.light,value=S.onoff[set.light+1],action='setting',arg='light'} end
  rows[#rows+1]={label=S.seconds,value=S.seconds_modes[set.secs+1],action='setting',arg='secs'}
  rows[#rows+1]={label=S.awake,value=S.onoff[set.awake+1]..' - '..S.battery,action='setting',arg='awake'}
  if a.features.lock and a.ctx.lockscreen then rows[#rows+1]={label=S.lockscreen,value=S.onoff[a.lock_default and 2 or 1],action='lockscreen'} end
  if a.features.sync then rows[#rows+1]={label=S.sync,action='sync'} end
  rows[#rows+1]={label=S.erase,action='erase'}
 end
 W.rows(a,g,rows)
end
return U
