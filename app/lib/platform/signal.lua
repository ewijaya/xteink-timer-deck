local Alerts=require('lib.core.alerts')
local S={}
-- A single sequencer handles both light phases and the 700 ms flash boundary.
function S.stop(a)
 if a.signal_timer then a.signal_timer:cancel();a.signal_timer=nil end
 a.signal=nil
 if a.ctx.frontlight then a.ctx.frontlight:reset() end
 if a.flash then a.flash=false;a:invalidate(true) end
end
function S.start(a,pattern,preview)
 S.stop(a)
 local events={};local elapsed=0
 local light=a.ctx.frontlight and a.state.set.light==1
 if light then
  for n,d in ipairs(Alerts.patterns[pattern+1]) do events[#events+1]={at=elapsed,on=n%2==1};elapsed=elapsed+d end
  events[#events+1]={at=elapsed,on=false}
 end
 if a.state.set.flash==1 then events[#events+1]={at=700,flash=true};a.flash=true;a:invalidate() end
 if #events==0 then return end
 table.sort(events,function(x,y) return x.at<y.at end)
 local signal={events=events,at=0,index=1,preview=preview};a.signal=signal
 local function step()
  while events[signal.index] and events[signal.index].at<=signal.at do
   local e=events[signal.index];signal.index=signal.index+1
   if e.flash then a.flash=false;a:invalidate(true)
   elseif e.on then local bright=a.original_light and a.original_light.on and a.original_light.brightness>=70;a.ctx.frontlight:set(bright and {on=false} or {on=true,brightness=100})
   else a.ctx.frontlight:reset() end
  end
  local next_event=events[signal.index]
  if not next_event then a.signal=nil;a.signal_timer=nil;return end
  local delay=next_event.at-signal.at
  a.signal_timer=a.ctx:after(delay,function() a:callback(function() signal.at=next_event.at;step() end) end)
 end
 step()
end
return S
