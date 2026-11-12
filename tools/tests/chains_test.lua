package.path='tools/shim/?.lua;app/?.lua;'..package.path
local M=require('lib.core.model');local H=require('lib.core.chains');local C=require('lib.core.const');local J=require('json');local Alerts=require('lib.core.alerts');local G=require('lib.core.glance')
local function cmd(s,c,now,result) local next,status=M.command(s,c,now);assert(status==(result or 'OK'),c.action..': '..status);assert(M.valid(next));if status~='OK' then assert(next==s) end;return next end
local function target(s,action) local r=s.ch.run;return {action=action,gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round} end
local function base(a,b,rounds)
 local s=M.new(1000);local d=H.template('Tea',2);d.steps[1].sec=a or 60;d.steps[2].sec=b or 120;d.rounds=rounds or 1;s=cmd(s,{action='CH_SAVE',definition=d},1000);return s
end
local s=base();assert(s.ch.saved[1].id==1);s=cmd(s,{action='CH_DUPLICATE',id=1,rev=1},1000);s=cmd(s,{action='CH_MOVE',id=2,rev=1,direction=-1},1000);assert(s.ch.saved[1].id==2)
s=cmd(s,{action='CH_DELETE',id=2,rev=1},1000);local d=M.copy(s.ch.saved[1]);d.name='Practice';s=cmd(s,{action='CH_SAVE',id=1,rev=1,definition=d},1000);assert(s.ch.saved[1].rev==2);cmd(s,{action='CH_SAVE',id=1,rev=1,definition=d},1000,'STALE');print('HOST MOCK Passed TH01')
for _,v in ipairs({{'Pomodoro',1500,300,4,9},{'Plank',30,30,3,6},{'Tea',240,180,1,1}}) do d=H.template(v[1],3);assert(d.steps[1].sec==v[2] and d.steps[2].sec==v[3] and d.rounds==v[4] and d.icon==v[5] and d.steps[2].pat==3) end;print('HOST MOCK Passed TH02')
s=base();s=cmd(s,{action='CH_START',id=1,rev=1},1000);assert(M.reconcile(s,1062));assert(s.ch.run.idx==2 and s.ch.run.anc==1180);assert(M.valid(s));M.reconcile(s,1180);assert(s.ch.run.st==3 and s.ch.run.ev==1180);print('HOST MOCK Passed TH04')
s=base(60,120,4);s=cmd(s,{action='CH_START',id=1,rev=1},1000);M.reconcile(s,1720);assert(s.ch.run.st==3 and s.ch.run.ev==1720);assert(M.valid(s));print('HOST MOCK Passed TH05')
s=base();s=cmd(s,{action='CH_START',id=1,rev=1},1000);local old=target(s,'CH_PRIMARY');M.reconcile(s,1060);cmd(s,old,1060,'STALE');s=cmd(s,target(s,'CH_PRIMARY'),1060);assert(s.ch.run.st==2 and s.ch.run.anc==120)
s=cmd(s,target(s,'CH_RESTART'),1070);s=cmd(s,target(s,'CH_PRIMARY'),1080);assert(s.ch.run.anc==1200);s=cmd(s,target(s,'CH_SKIP'),1080);assert(s.ch.run.st==3 and s.ch.run.skipped==1);print('HOST MOCK Passed TH06')
s=base();s=cmd(s,{action='CH_START',id=1,rev=1},1000);s=cmd(s,target(s,'CH_STOP'),1010);assert(s.ch.run.st==4);s=cmd(s,{action='CH_START',id=1,rev=1},1020);s=cmd(s,{action='CH_DELETE',id=1,rev=1},1020);assert(s.ch.run.st==0 and #s.ch.saved==0);print('HOST MOCK Passed TH07')
s=base(10,10,2);s=cmd(s,{action='CH_START',id=1,rev=1},1000);M.reconcile(s,1022);assert(s.ch.run.away==2 and s.ch.run.cue==0);s=base();s=cmd(s,{action='CH_START',id=1,rev=1},1000);M.reconcile(s,1062);assert(s.ch.run.cue==1);print('HOST MOCK Passed TH08')
s=base(1,1);s=cmd(s,{action='CH_START',id=1,rev=1},1000);for _=1,10 do s=cmd(s,{action='CREATE_START',dur=2,cnt=1},1000) end;M.reconcile(s,1002)
local seen={};for _=1,11 do local t=assert(Alerts.choose(s,1002));assert(t.att==0);if t.chain then seen.chain=true;t.action='CH_ATTEMPT' else assert(not seen[t.id]);seen[t.id]=true;t.action='ATTEMPT' end;s=cmd(s,t,1002) end;assert(seen.chain);print('HOST MOCK Passed TH09')
s=base(C.MAX_SEC-1,1);assert(H.total(s.ch.saved[1])==C.MAX_SEC);cmd(s,{action='CH_START',id=1,rev=1},C.MAX_INT-10,'OVERFLOW');d=M.copy(s.ch.saved[1]);d.rounds=2;cmd(s,{action='CH_SAVE',definition=d},1000,'INVALID');print('HOST MOCK Passed TH10')
-- Fullest legal state, including ten 16-character names, all steps and a snapshot.
s=M.new(1000);for _=1,10 do s=cmd(s,{action='CREATE',name=string.rep('T',16),dur=1000,icon=30,cnt=5},1000) end
for _=1,5 do d=H.template('Tea',3);d.name=string.rep('C',16);d.steps={};d.next_step=11;for n=1,10 do d.steps[n]={id=n,name=string.rep('S',16),sec=1000,icon=30,pat=3} end;d.rounds=9;s=cmd(s,{action='CH_SAVE',definition=d},1000) end
s=cmd(s,{action='CH_START',id=1,rev=1},1000);for n=1,4 do s.rc[n]={dig=2147483647,len=16384,n=15} end
assert(M.valid(s));local encoded=assert(J:encode(s));assert(#encoded<=12288,#encoded);print('HOST MOCK Passed TS01 full state '..#encoded..' bytes')
-- Rollback preserves current remainder and shifts all future boundaries together.
M.reconcile(s,1040);local remaining=H.remaining(s.ch.run,1040);M.reconcile(s,900);assert(H.remaining(s.ch.run,900)==remaining and M.valid(s))
local view=G.view(s,{valid=true,epoch_sec=900,hour=0,minute=15,year=1970,month=1,day=1});assert(view.chain and view.interval==60)
local R=require('runtime');local App=require('lib.app');local c=R.new();local a=App.new(c)
local function act(action,arg) assert(a:action({action=action,arg=arg}));local g=R.canvas(c);a:draw(c,g);assert(g.command_count<=768);for n,h in ipairs(a.hits) do for k=1,n-1 do local b=a.hits[k];assert(h.x>=b.x+b.w or b.x>=h.x+h.w or h.y>=b.y+b.h or b.y>=h.y+h.h,'overlap '..a.page.kind) end end end
act('chains');act('ch_new');act('ch_template','Tea');act('ch_save');act('ch_start');assert(a.state.ch.run.st==1);a:draw(c,R.canvas(c));act('ch_primary',a.page.token);assert(a.state.ch.run.st==2);act('ch_primary',a.page.token);act('ch_more');act('ch_stop');local f=c.overlay.fn;c.overlay=nil;f(c,true);assert(a.state.ch.run.st==4)
act('ch_done',{gen=a.state.ch.run.gen,step=a.state.ch.run.snap.steps[1].id,round=1})
a:command('CREATE_START',nil,{dur=240,name='Tea',icon=1});local original=assert(J:encode(a.state.items))
act('ch_new');act('ch_from_new');act('ch_select',1);act('ch_add_selected');assert(a.page.draft.steps[1].sec==240 and J:encode(a.state.items)==original);act('ch_add');act('ch_new_step');act('ch_time');act('time_done');act('ch_step_save');act('ch_save');assert(#a.state.ch.saved==2);print('HOST MOCK Passed TH03 / chain UI walk')
-- Maximal encoded field widths, quote escaping, ids and snapshot depth.
s=M.new(1000)
for _=1,10 do s=M.command(s,{action='CREATE_START',dur=C.MAX_SEC,name=string.rep('"',16),icon=30,cnt=5},1000) end
s.next_id=C.MAX_INT;s.rev=C.MAX_INT;s.trusted=C.MAX_INT;s.sel=C.MAX_INT-99
for idx,i in ipairs(s.items) do i.id=C.MAX_INT-100+idx;i.gen=C.MAX_INT;i.anc=C.MAX_INT end
for k=1,5 do
 local d=H.template('Tea',3);d.id=C.MAX_INT-5+k;d.rev=C.MAX_INT;d.next_step=C.MAX_INT;d.name=string.rep('"',16);d.rounds=9;d.steps={}
 for n=1,10 do d.steps[n]={id=C.MAX_INT-11+n,name=string.rep('"',16),sec=959999,icon=30,pat=3} end;s.ch.saved[k]=d
end
s.ch.last=C.MAX_INT;s.ch.run={st=1,id=s.ch.saved[5].id,gen=C.MAX_INT,snap=M.copy(s.ch.saved[5]),idx=10,round=9,anc=C.MAX_INT,ev=C.MAX_INT-100000,skipped=89,away=89,pat=3,cnt=5,att=0,cue=1,sil=0}
for n=1,4 do s.rc[n]={dig=-2147483647-1,len=16384,n=15} end
assert(M.valid(s));local bytes=#assert(J:encode(s));assert(bytes<=12288,bytes)
local function depth(t,n) local max=n;for _,v in pairs(t) do if type(v)=='table' then max=math.max(max,depth(v,n+1)) end end;return max end
assert(depth(s,0)<=5);local store=R.new({state=s});assert(store:save_state());assert(J:encode(s)==J:encode(store.persisted));print('HOST MOCK TS01 maximal widths '..bytes..' bytes, depth '..depth(s,0))
-- TH11: acknowledging the step cue leaves the final alert budget intact.
do
 local c=R.new();local a=App.new(c);local d=H.template('Tea',0);d.steps[1].sec=2;d.steps[2].sec=3
 a:command('CH_SAVE',nil,{definition=d});a:command('CH_START',{id=1},{rev=1});c:advance(2000)
 assert(a.signal and a.state.ch.run.idx==2)
 a:input(c,{type='pointer',phase='down',x=1,y=1});a:input(c,{type='pointer',phase='up',x=1,y=1})
 assert(a.state.ch.run.sil==0 and a.state.ch.run.att==0,'TH11 step cue silenced result')
 local lights=#c.light_calls;c:advance(10000)
 assert(a.state.ch.run.st==3 and a.state.ch.run.att==a.state.ch.run.cnt and a.state.ch.run.sil==0 and #c.light_calls>lights)
 a:sample();a:command('CH_START',{id=1},{rev=1});c:advance(5300);assert(a.state.ch.run.st==3 and a.signal)
 a:input(c,{type='pointer',phase='down',x=1,y=1});assert(a.state.ch.run.sil==1)
 print('HOST MOCK Passed TH11')
end
do
 local failures={};local function case(id,fn) local ok,err=pcall(fn);print('HOST MOCK '..id..' '..(ok and 'Passed' or tostring(err)));if not ok then failures[#failures+1]=id end end
 case('TH12 / BUG-06',function()
  local c=R.new();local a=App.new(c);local d=H.template('Tea',0);d.steps[1].sec=1;d.steps[2].sec=1
  a:command('CH_SAVE',nil,{definition=d});a:action({action='chains'});a:action({action='ch_overview',arg=1});a:action({action='ch_start'});local depth=#a.stack
  for _=1,3 do c:advance(2500);a:sample();a:event();assert(a.page.kind=='chain_result');for _,p in ipairs(a.stack) do assert(p.kind~='chain_run','stale Run') end;a:action({action='ch_start'});assert(#a.stack==depth,'stack growth') end
 end)
 case('TH12 / BUG-07',function()
  local c=R.new();local a=App.new(c);a:command('CH_SAVE',nil,{definition=H.template('Tea',0)});a:action({action='ch_start',arg=1});a:action({action='ch_more'});a:action({action='chains'});a:action({action='ch_delete_inline',arg=1});a:action({action='back'});a:action({action='back'});a:draw(c,R.canvas(c));assert(not a.fatal)
  a.page={kind='chain_run'};a:draw(c,R.canvas(c))
 end)
 case('TH13 / BUG-12',function()
  local c=R.new();local a=App.new(c);local d=H.template('Tea',0);d.steps[1].name='';d.steps[2].name='';a:command('CH_SAVE',nil,{definition=d});a:action({action='ch_start',arg=1});local g=R.canvas(c);a:draw(c,g);local found=false
  for _,v in ipairs(g.commands) do if v.method=='text' and v.args[3]=='STEP 1 OF 2' then found=true end;assert(v.args[3]~='Rounds 1 / 1') end;assert(found,'step label')
  local function has(text)
   local canvas=R.canvas(c);a:draw(c,canvas)
   for _,v in ipairs(canvas.commands) do if v.method=='text' and v.args[3]==text then return true end end
   return false
  end
  assert(has('Step 1') and has('Next: Step 2 3:00'))
  assert(G.view(a.state,a.now).title=='Step 1')
  local r=a.state.ch.run;a.banner={text='Starting now: Step 1',gen=r.gen,step=r.idx,round=r.round}
  assert(has(a.banner.text));a.banner.step=2;assert(not has(a.banner.text));a.banner.step=1
  a.banner.gen=r.gen+1;assert(not has(a.banner.text));a.banner.gen=r.gen;a.banner.round=2;assert(not has(a.banner.text))
  a:action({action='ch_steps'});assert(has('> 1. Step 1') and has('2. Step 2'))
  a:action({action='ch_template',arg='Tea'});a.page.draft.steps[1].name='';assert(has('1. Step 1'))
 end)
 assert(#failures==0,table.concat(failures,', '))
end
