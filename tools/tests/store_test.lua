package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local M=require('lib.core.model');local Store=require('lib.platform.store');local App=require('lib.app');local J=require('json')
local function check(id,fn) fn();print('HOST MOCK Passed '..id) end
check('TS01-items',function() local s=M.new();for _=1,10 do s=M.command(s,{action='CREATE',name='abcdefghijklmnop',dur=86399999},1000) end;assert(#assert(J:encode(s))<12288);assert(M.valid(s)) end)
check('TS02',function() local c=R.new();local s=M.new(1000);assert(Store.commit(c,s,M.new()));local other=R.new({state=c.persisted});assert(J:encode(Store.load(other,1000))==J:encode(s)) end)
check('TS03',function() local c=R.new();local a=App.new(c);c.save_failure='io_error';assert(not a:command('CREATE',nil,{dur=10}));assert(#a.state.items==0 and #c.persisted.items==0 and a.page.kind=='message') end)
check('TS04',function() local c=R.new();local a=App.new(c);assert(a:command('CREATE_START',nil,{dur=1}));c.save_failure='io_error';c:advance(2000);assert(a.state.items[1].st==3 and a.unsaved and c.persisted.items[1].st==1);c.save_failure=nil;c:advance(1000);assert(not a.unsaved and c.persisted.items[1].st==3) end)
check('TS05',function() local c=R.new();local a=App.new(c);a:command('CREATE',nil,{dur=10});a:command('CREATE',nil,{dur=20});assert(not c.storage:exists('deck.bak'));c:advance(2000);assert(#assert(Store.read_backup(c)).items==2);a:command('CREATE',nil,{dur=30});a:leave(c);assert(#assert(Store.read_backup(c)).items==3) end)
check('TS06',function() local c=R.new();local s=M.new(1000);s=M.command(s,{action='CREATE_START',dur=10},1000);assert(Store.backup(c,s));local restored,status=Store.load(c,1037);assert(status=='restored');M.reconcile(restored,1037);assert(restored.items[1].st==3) end)
check('TS07',function() local c=R.new({state={bad=1}});local a=App.new(c);assert(a.mode=='recovery' and c.save_attempts==0 and c.state.bad==1) end)
check('TS08',function() local c=R.new({state={v=2,secret=1}});local a=App.new(c);a:leave(c);assert(a.mode=='blocked' and c.save_attempts==0 and c.state.secret==1) end)
check('TS09',function()
 local c=R.new();local a=App.new(c);a:command('CREATE_START',nil,{dur=100});c:advance(2000);assert(c.storage:exists('deck.bak'))
 a:action({action='erase'});local f=c.overlay.fn;c.overlay=nil;f(c,false);assert(#a.state.items==1 and c.storage:exists('deck.bak'))
 a:action({action='erase'});f=c.overlay.fn;c.overlay=nil;f(c,true);assert(#a.state.items==0 and not c.storage:exists('deck.bak') and c.awake_calls[#c.awake_calls]==0)
end)
check('TS10',function() local c=R.new();local a=App.new(c);local saved=c.save_attempts;local fonts=#c.font_requests;c:call('on_draw',function(ctx) a:draw(ctx,R.canvas(ctx)) end);assert(c.alive,c.error);assert(c.save_attempts==saved and #c.font_requests==fonts) end)
check('TS11',function() local c=R.new();local a=App.new(c);a:command('CREATE',nil,{dur=10});c:call('crash',function() error('injected') end);local next=R.new({state=c.persisted});assert(#assert(Store.load(next,1000)).items==1) end)

check('TS07-fresh-save-failure',function()
 local c=R.new({state={bad=1}});local a=App.new(c);a:action({action='fresh'});local f=c.overlay.fn;c.overlay=nil;c.save_failure='io_error';f(c,true)
 assert(a.mode=='recovery' and c.state.bad==1 and c.persisted.bad==1);a:leave(c);assert(c.state.bad==1)
end)
check('TU18',function()
 for _,state in ipairs({{bad=1},{v=2}}) do
  local c=R.new({state=state});local a=App.new(c);local kind=a.page.kind
  assert(a:action({action='back'})==false,'TU18 root Back must exit')
  assert(a.page.kind==kind);a:help();a:action({action='back'});assert(a.page.kind==kind)
  a:draw(c,R.canvas(c));assert(not a.fatal)
 end
end)
-- Read the released implementation from this repository, without checking it out.
-- Keep its module cache separate so both validators and stores run in this suite.
local old_modules={}
local old_paths={['lib.core.model']='app/lib/core/model.lua',['lib.core.const']='app/lib/core/const.lua',
 ['lib.core.format']='app/lib/core/format.lua',['lib.core.chains']='app/lib/core/chains.lua',
 ['lib.platform.store']='app/lib/platform/store.lua'}
local function old_require(name)
 if old_modules[name] then return old_modules[name] end
 local path=assert(old_paths[name],'unexpected 0.3.1 dependency')
 local pipe=assert(io.popen('git show 6f6346c:'..path,'r'));local source=pipe:read('a');assert(pipe:close())
 old_modules[name]=assert(load(source,'@0.3.1/'..path,'t',setmetatable({require=old_require},{__index=_G})))()
 return old_modules[name]
end
local Old=old_require('lib.core.model');local OldStore=old_require('lib.platform.store')
local function fixture(model,chains)
 local s=model.new(1000)
 local function command(c) local next,status=model.command(s,c,1000);assert(status=='OK');s=next end
 command({action='CREATE_START',dur=600,name='Compatibility'})
 command({action='CH_SAVE',definition=chains.template('Tea',2)})
 command({action='CH_START',id=1,rev=1})
 s.set.app=2;s.set.style=3;s.ch.run.sil=1;s.ch.run.att=s.ch.run.cnt
 assert(model.valid(s));return s
end
local function cross_load(writer,reader,model,chains)
 local state=fixture(model,chains);local c=R.new();assert(writer.commit(c,state,model.new(1000)))
 local expected=assert(J:encode(state));local loaded,status=reader.load(R.new({state=c.persisted}),1000)
 assert(status=='ok' and J:encode(loaded)==expected,'state changed across versions')
 assert(loaded.v==1 and loaded.set.app==2 and loaded.set.style==3 and loaded.ch.run.st==1 and loaded.ch.run.sil==1)
 assert(writer.backup(c,state));c.state={bad=1};loaded,status=reader.load(c,1000)
 assert(status=='restored' and J:encode(loaded)==expected,'TDB1 changed across versions')
end
check('TS12 / 0.3.1 to 0.3.2',function() cross_load(OldStore,Store,Old,old_require('lib.core.chains')) end)
check('TS13 / 0.3.2 to 0.3.1',function() cross_load(Store,OldStore,M,require('lib.core.chains')) end)
