package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local M=require('lib.core.model');local App=require('lib.app');local Alerts=require('lib.core.alerts');local P=require('lib.core.pulse');local Theme=require('lib.ui.theme')
local function fresh(count,pattern,n,opts)
 local c=R.new(opts);local now=c.now_value.epoch_sec;local s=M.new(now)
 for k=1,n or 1 do s=assert((M.command(s,{action='CREATE_START',dur=1,cnt=count or 3,pat=pattern or 2},now))) end
 c.state=s;local a=App.new(c);return a,c
end
local function advance(a,c,ms) c:advance(ms);a:sample();a:event();assert(not a.fatal);assert(c:pending()<=4) end
for pat=0,3 do
 local a,c=fresh(1,pat);advance(a,c,1150);assert(a.state.items[1].att==1 and a.signal)
 local phases=Alerts.patterns[pat+1];local before=#c.light_calls
 for n,d in ipairs(phases) do advance(a,c,d);assert(c.light_calls[#c.light_calls][1]==(n%2==1 and 'reset' or 'set')) end
 advance(a,c,700);assert(not a.flash and not a.signal and #c.light_calls>=before)
end
print('HOST MOCK Passed TA01')
for count=1,5 do local a,c=fresh(count);advance(a,c,12000);assert(a.state.items[1].att==count);assert(not a.signal) end
print('HOST MOCK Passed TA02')
local a,c=fresh(3,0,3);local order={};local previous={0,0,0}
for _=1,200 do advance(a,c,100);for k,i in ipairs(a.state.items) do if i.att~=previous[k] then order[#order+1]=k;previous[k]=i.att end end end
assert(table.concat(order,',')=='1,2,3,1,2,3,1,2,3');print('HOST MOCK Passed TA03')
a,c=fresh();advance(a,c,1150);assert(a:input(c,{type='pointer',phase='down',x=1,y=1}));assert(not a.signal and not a.flash and a.state.items[1].sil==1);advance(a,c,10000);assert(a.state.items[1].att==1);print('HOST MOCK Passed TA05')
a,c=fresh();advance(a,c,1150);a:pause(c);assert(not a.signal and c.light_calls[#c.light_calls][1]=='reset');a:resume(c);advance(a,c,10000);assert(a.state.items[1].att==3);a:leave(c);assert(c.light_calls[#c.light_calls][1]=='reset');print('HOST MOCK Passed TA07 / TA10')
a,c=fresh(1,0,1,{light={on=true,brightness=80,warmth=20}});advance(a,c,1150);assert(c.light.on==false and c.light.warmth==20)
a,c=fresh();a:command('SETTINGS',nil,{values={light=0,flash=0}});advance(a,c,20000);assert(a.state.items[1].att==1);print('HOST MOCK Passed TA11')
a,c=fresh();advance(a,c,1150);a:action({action='dismiss',id=1,gen=1});advance(a,c,10000);assert(a.state.items[1].st==0);a:command('PRIMARY',{id=1,gen=2});advance(a,c,1150);assert(a.state.items[1].gen==3 and a.state.items[1].att==1);print('HOST MOCK Passed TA04 / TA06')
a,c=fresh();advance(a,c,1150);local persisted=M.copy(c.persisted);local c2=R.new({state=persisted});c2.now_value.epoch_sec=c.now_value.epoch_sec;local a2=App.new(c2);advance(a2,c2,12000);assert(a2.state.items[1].att==3);print('HOST MOCK Passed TA08')
a,c=fresh();advance(a,c,602000);assert(a.state.items[1].st==0);print('HOST MOCK Passed TA09')
a,c=fresh();assert(c.awake_calls[#c.awake_calls]>=120000);a:command('PRIMARY',{id=1,gen=1});assert(c.awake_calls[#c.awake_calls]==0);local calls=#c.awake_calls;a:plan();assert(#c.awake_calls==calls);print('HOST MOCK Passed TA12')
local s=M.new(100);s=M.command(s,{action='CREATE_START',dur=20000},100);assert(Alerts.coverage(s,s.items[1],100,true,false)==1);assert(Alerts.coverage(s,s.items[1],100,true,true)==3);s.items[1].anc=200;assert(Alerts.coverage(s,s.items[1],100,true,true)==2);s.set.awake=0;assert(Alerts.coverage(s,s.items[1],100,true,false)==1);print('HOST MOCK Passed TA13')
a,c=fresh();assert(a:action({action='back'}) and c.overlay);local f=c.overlay.fn;c.overlay=nil;f(c,false);assert(not c.quitting);a:action({action='back'});c.overlay.fn(c,true);assert(c.quitting);print('HOST MOCK Passed TA14')
for mode=0,2 do for typ=0,1 do for _,v in ipairs({59,60,61,599,600,601}) do for _,detail in ipairs({false,true}) do
 local expected=mode==1 or mode==0 and (detail and (typ==0 and v<=600 or typ==1 and v<600) or not detail and typ==0 and v<=60)
 assert(P.seconds(mode,detail,{type=typ},v)==expected)
end end end end;print('HOST MOCK Passed TD01')
a,c=fresh(1);a:command('SETTINGS',nil,{values={secs=2}});advance(a,c,1150);assert(a.state.items[1].st==3);print('HOST MOCK Passed TD05')
local ink,paper=Theme.colors(false);local x,y=Theme.colors(true);assert(ink==15 and paper==0 and x==paper and y==ink)
print('HOST MOCK Passed TU14')
-- Cadence simulates an hour of a two-hour countdown; no per-second polling in minute modes.
for mode=0,2 do
 local c3=R.new();local a3=App.new(c3);a3:command('SETTINGS',nil,{values={secs=mode}});a3:command('CREATE_START',nil,{dur=7200})
 local frames=a3.tick_frames or 0;c3:advance(3600000);local wakes=(a3.tick_frames or 0)-frames
 assert(wakes<=(mode==1 and 3601 or 120),tostring(wakes));assert(c3:pending()<=4)
end
assert(P.plan(M.new(100),100,'settings',100)==nil);print('HOST MOCK Passed TA15 / TD02')
a,c=fresh();a:command('RESET',{id=1,gen=1});a:command('EDIT',{id=1,gen=2},{values={dur=7200}});a:command('PRIMARY',{id=1,gen=2});a.page={kind='detail',id=1};a:plan();local before=a.pulse.left;a:action({action='peek'});a:plan();assert(a.peek and a.pulse.left==before);advance(a,c,before);assert(not a.peek);print('HOST MOCK Passed TD03')
a,c=fresh(1,0);assert(c.waves[1]=='full');advance(a,c,1150);assert(a.flash);advance(a,c,700);assert(not a.flash and c.waves[#c.waves]=='full');assert(#c.deferred>0);print('HOST MOCK Passed TD04')
-- The save is observable before the first light set, including injected failure.
a,c=fresh(2,0);c.save_failure='io_error';advance(a,c,1150);assert(a.unsaved and not a.signal);for _,v in ipairs(c.light_calls) do assert(v[1]~='set') end
c.save_failure=nil;advance(a,c,4000);assert(not a.unsaved and a.state.items[1].att<=2)
for pat=0,3 do
 local aa,cc=fresh(1,pat);local setter=cc.frontlight.set
 cc.frontlight.set=function(self,v) assert(cc.persisted.items[1].att==1);return setter(self,v) end
 advance(aa,cc,3000);local events={};local first
 for _,event in ipairs(cc.light_calls) do if event[1]=='set' or first then first=first or event.at;events[#events+1]=event end end
 local elapsed=0;assert(first>=1000)
 for n,duration in ipairs(Alerts.patterns[pat+1]) do assert(events[n].at-first==elapsed and events[n][1]==(n%2==1 and 'set' or 'reset'));elapsed=elapsed+duration end
 assert(events[#events][1]=='reset' and events[#events].at-first==elapsed)
end
local aa,cc=fresh(5,0);advance(aa,cc,12000);local last
for _,event in ipairs(cc.light_calls) do if event[1]=='set' then if last then assert(event.at-last==2000) end;last=event.at end end
print('HOST MOCK exact pattern timestamps and save-before-light assertions passed')
-- Failure of ATTEMPT itself must hold the old counter until the retry is durable.
local failed_app,failed_ctx=fresh(2,0);local save=failed_ctx.save_state;local failed_once=false
failed_ctx.save_state=function(self)
 if self.state.items[1].att>0 and not failed_once then failed_once=true;return nil,'io_error' end
 return save(self)
end
failed_ctx:advance(1000);assert(failed_once and failed_app.unsaved and failed_app.state.items[1].att==0 and not failed_app.signal)
advance(failed_app,failed_ctx,8000);local attempts=0;for _,call in ipairs(failed_ctx.light_calls) do if call[1]=='set' then attempts=attempts+1 end end
assert(attempts==2 and failed_app.state.items[1].att==2);print('HOST MOCK failed ATTEMPT save preserves the physical attempt budget')
-- TA16: dismissing a preview cannot consume a real completion's attempts.
do
 local a,c=fresh(5,0);advance(a,c,1800);assert(a.state.items[1].att==1 and not a.signal)
 local before=require('json'):encode(a.state.items);a:preview_pattern(0)
 a:input(c,{type='pointer',phase='down',x=1,y=1})
 assert(require('json'):encode(a.state.items)==before,'TA16 preview silenced completion')
 a:input(c,{type='pointer',phase='up',x=1,y=1});advance(a,c,3000)
 assert(a.state.items[1].att>1 and a.state.items[1].sil==0)
 print('HOST MOCK Passed TA16')
end
-- TA17: three inverted frames, partial restores, one final full refresh (R1 entry excluded).
do
 local a,c=fresh(3,0);a.page={kind='completion'};a.shown['1:1']=true;c.waves={}
 local invalid=a.invalidate;local inverted,restores,last_flash=0,0,false
 a.invalidate=function(self,full)
  if self.flash and not last_flash then inverted=inverted+1 elseif not self.flash and last_flash then assert(not full,'TA17 restore must be partial');restores=restores+1 end
  last_flash=not not self.flash;return invalid(self,full)
 end
 c:advance(7000);local full=0;for _,wave in ipairs(c.waves) do if wave=='full' then full=full+1 end end
 assert(inverted==3 and restores==3 and full==1,'TA17 '..inverted..'/'..restores..'/'..full)
 print('HOST MOCK Passed TA17')
end
