package.path='tools/shim/?.lua;'..package.path
assert(_VERSION=='Lua 5.5' and math.maxinteger==2147483647 and string.packsize('n')==4)
local R=require('runtime');local J=require('json');local n=0
local function test(name,fn) fn();n=n+1;print('HOST MOCK Passed '..name) end
local function err(v,e,want) assert(v==nil and e==want) end
test('JSON / signed CRC32',function()
 local c=R.new();assert(c.hash:crc32('123456789')==0xCBF43926)
 local s=assert(J:encode({a={1,true,'é\n'},z=J.null}));assert(assert(J:decode(s)).a[3]=='é\n')
 for _,s in ipairs({'[1,]','{"a":01}','"\\uD800"','true x'}) do assert(J:decode(s)==nil) end
end)
test('clock snapshots / invalid / wrap',function()
 local c=R.new({millis=2147483640});c:call('test',function(ctx)
 local a=ctx.clock:now();ctx.now_value.hour=9;assert(a==ctx.clock:now() and a.hour==12);assert(not pcall(function() a.hour=3 end)) end)
 c:advance(20);assert(c.clock:millis()==12);c.now_value.valid=false;c.snapshot=nil;assert(c.clock:now().epoch_sec==nil)
end)
test('timers bounds / order / cancel / pause',function()
 local c=R.new();local order={};local t=c:after(1,function() error('cancelled') end);t:cancel()
 c:after(20,function() order[#order+1]=2 end);c:after(10,function() order[#order+1]=1 end)
 c:advance(30);assert(table.concat(order)== '12');err(c:after(0,function() end),'invalid_argument','invalid_argument')
 for i=1,32 do assert(c:after(i,function() end)) end
 local v,e=c:after(1,function() end);err(v,e,'limit_exceeded');c.paused=true;c:advance(100);assert(c:pending()==32);c.paused=false;c:due();assert(c:pending()==0)
end)
test('state atomic saves / filtering / depth / limits',function()
 local c=R.new();c.state={a=1,['12']=2,fn=function() end};assert(c:save_state());assert(c.persisted[12]==2 and not c.persisted.fn)
 assert(c:save_state());assert(c.saved==1);c.state.a=3;c.save_failure='io_error';local v,e=c:save_state();err(v,e,'io_error');assert(c.persisted.a==1)
 c.save_failure=nil;c.state={s=string.rep('x',16384)};v,e=c:save_state();err(v,e,'limit_exceeded')
 local root={};local t=root;for _=1,8 do t.child={};t=t.child end;c.state=root;assert(c:save_state());t=c.persisted;for _=1,6 do t=t.child end;assert(t.child==nil)
end)
test('files atomic / private and user names',function()
 local c=R.new();local f=R.files(c,true);assert(f:write('deck.bak','old'));f.failure='io_error';assert(not f:write('deck.bak','new'));f.failure=nil;assert(f:read('deck.bak')=='old');assert(not f:write('../x','x'));assert(not f:write('Upper','x'))
 f=R.files(c,false);assert(f:write('Tea.txt','abcd'));assert(f:read('tea.TXT',1,2)=='bc');assert(not f:write('CON.txt','x'));assert(not f:write('bad.','x'));assert(not f:write('x',string.rep('x',262145)))
end)
test('canvas limits / lifetime / geometry / font fallback',function()
 local c=R.new({ttf_limit=1});assert(c.fonts:size(22).px==22);assert(c.fonts:size(40).px==nil)
 assert(c.fonts.large:layout('x',100,-1)==nil)
 local g=R.canvas(c);g:arc(0,0,20,0,360);assert(g.command_count==0)
 assert(not pcall(function() g:rect(0.1,0,2,2) end));assert(not pcall(function() g:polygon({1,2,3,4}) end))
 assert(not pcall(function() g:text(0,0,'\255') end));assert(not pcall(function() g:clear(16) end))
 for _=1,1024 do g:line(0,0,1,1) end;assert(not pcall(function() g:line(0,0,1,1) end))
 g.active=false;local v,e=g:clear();err(v,e,'inactive');assert(not pcall(function() g:unknown() end))
end)
test('device / frontlight / lock',function()
 local c=R.new();assert(c.frontlight);c.frontlight:set({on=true,brightness=100});assert(c.frontlight:get().on);c.frontlight:reset();assert(not c.frontlight:get().on)
 assert(select(2,c.device:keep_awake(14400001))=='invalid_argument')
 local l=R.new({kind='lock'});assert(not l.frontlight);assert(l:after(1,function() end)==nil);assert(select(2,l.budget:extend())=='inactive');assert(select(2,l.device:keep_awake(1))=='inactive');assert(select(2,l.lock:set_interval(29))=='invalid_argument')
end)
test('fresh sessions / overlay ordering / uncaught errors',function()
 local files={['index.lua']=[[local count=0
 function on_load(ctx) count=count+1;ctx.state.count=count end
 function on_pause(ctx) ctx.state.order='P' end
 function on_resume(ctx) ctx.state.order=ctx.state.order..'R' end
 function on_draw(ctx,g) ctx.state.order=(ctx.state.order or '')..'D' end
 function on_input(ctx) ctx.input:text({},function(ctx) ctx.state.order=ctx.state.order..'C' end);ctx:after(1,function(ctx) ctx.state.order=ctx.state.order..'T' end) end
 function on_leave(ctx) ctx.state.left=true end]]}
 local c=R.session(files,{});c:event('on_input');assert(c.paused);assert(select(2,c.input:text({},function() end))=='busy');c:advance(10);c:answer('yes');assert(c.state.order=='PRDTC');c:leave();assert(c.persisted.left)
 local fresh=R.session(files,c.persisted);assert(fresh.state.count==1)
 fresh:call('failure',function(ctx) ctx.state.count=99;error('injected') end);fresh:leave();assert(fresh.persisted.count==1)
end)
print('HOST MOCK runtime self-tests: '..n..' passed')
test('method receivers and optional capabilities',function()
 local c=R.new({keep_awake=false,capabilities={frontlight=false,dialog=false}})
 assert(not c.frontlight and not c.dialog and not c.device.keep_awake)
 assert(not pcall(function() c.clock.now() end));assert(not pcall(function() c.fonts.size(22) end))
 local files={['index.lua']=[[function on_load(ctx) ctx:quit() end function on_leave(ctx) ctx.state.left=1 end]]}
 local q=R.session(files,{});assert(not q.alive and q.persisted.left==1)
end)
