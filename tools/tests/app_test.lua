package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local M=require('lib.core.model');local App=require('lib.app');local J=require('json')
local c=R.new();local a=App.new(c)
local function draw()
 local before=assert(J:encode(a.state));local fonts=#c.font_requests;local saves=c.save_attempts;local g=R.canvas(c);c:call('on_draw',function(ctx) a:draw(ctx,g) end);assert(c.alive,c.error)
 assert(before==J:encode(a.state) and fonts==#c.font_requests and saves==c.save_attempts)
 assert(g.command_count<=768)
 for n,h in ipairs(a.hits) do assert(h.x>=0 and h.y>=0 and h.x+h.w<=480 and h.y+h.h<=800 and h.w>=56 and h.h>=56)
  for k=1,n-1 do local b=a.hits[k];assert(h.x>=b.x+b.w or b.x>=h.x+h.w or h.y>=b.y+b.h or b.y>=h.y+h.h,'overlapping hits') end
 end
 return g
end
-- TU20 release walk: exercise every replacement route, including confirmations.
do
 local H=require('lib.core.chains')
 local function yes(a,c) local fn=assert(c.overlay).fn;c.overlay=nil;fn(c,true) end
 local function chain(a) assert(a:command('CH_SAVE',nil,{definition=H.template('Tea',0)})) end
 local routes={
  {'create',function(a) a:action({action='new_timer'}) end,function(a) a:action({action='create',arg=true}) end,'detail'},
  {'delete',function(a) a:command('CREATE',nil,{dur=600}) end,function(a) a:action({action='delete',id=1,gen=0}) end,'deck'},
  {'save_form',function(a) a:action({action='new_watch'}) end,function(a) a:action({action='save_form'}) end,'deck'},
  {'erase',function(a) a:action({action='erase'}) end,yes,'deck'},
  {'retry_load',function(a,c) a.mode='recovery';a.page={kind='recovery'};c.state=M.new(a.sec) end,function(a) a:action({action='retry_load'}) end,'deck'},
  {'fresh',function(a) a.mode='recovery';a.page={kind='recovery'};a:action({action='fresh'}) end,yes,'deck'},
  {'ch_save',function(a) a:action({action='ch_template',arg='Tea'}) end,function(a) a:action({action='ch_save'}) end,'chain_overview'},
  {'ch_done',function(a)
   chain(a);a:action({action='ch_start',arg=1});a:action({action='ch_stop'})
   local c=a.ctx;yes(a,c)
  end,function(a) local r=a.state.ch.run;a:action({action='ch_done',arg={gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round}}) end,'chains'},
  {'ch_delete',function(a) chain(a);a:action({action='ch_overview',arg=1});a:action({action='ch_delete'}) end,yes,'chains'}
 }
 for _,route in ipairs(routes) do
  local c=R.new();local a=App.new(c);route[2](a,c);c:advance(500);a:sample()
  a.focus=3;a.peek={};a.banner='stale';a:arm('item',999,0)
  route[3](a,c)
  assert(a.page.kind==route[4] and #a.stack==0,route[1]..' destination')
  assert(a.focus==nil and a.peek==nil and a.banner==nil and a.armed==nil and a.changed_at==a.ms,route[1]..' bookkeeping')
  a:draw(c,R.canvas(c));local page=a.page;local state=J:encode(a.state);local hit=a.hits[#a.hits]
  c:advance(100);a:input(c,{type='pointer',phase='down',x=hit.x+hit.w//2,y=hit.y+hit.h//2})
  a:input(c,{type='pointer',phase='up',gesture='tap',x=hit.x+hit.w//2,y=hit.y+hit.h//2})
  assert(a.page==page and J:encode(a.state)==state and not a.fatal,route[1]..' settle')
 end
 print('HOST MOCK Passed TU20 all nine replacement routes and settle')
end
local function action(s,arg)
 a:sample();a:event();assert(a:action({action=s,arg=arg}));draw()
end
draw();action('new_timer');action('digit','9');action('digit','0');action('create',true);assert(#a.state.items==1 and a.state.items[1].dur==90 and a.state.items[1].st==1)
local i=a.state.items[1];a:action({action='primary',id=i.id,gen=i.gen});assert(a.state.items[1].st==2);a:action({action='primary',id=i.id,gen=i.gen});assert(a.state.items[1].st==1)
a:action({action='reset',id=i.id,gen=i.gen});draw();assert(a.state.items[1].st==0)
action('edit');action('icons');action('pick',1);action('save_form',false);assert(a.state.items[1].icon==1)
a:action({action='delete',id=a.state.items[1].id,gen=a.state.items[1].gen});draw();assert(#a.state.items==0)
a.page={kind='deck'};action('menu');action('settings');assert(a:action({action='setting',arg='app'})==false and not a.preview_setting)
a.page={kind='deck'};action('help');action('back');action('menu');action('info');assert(a.page.kind=='info')
-- Read-only draw, recovery entry, unknown global denial and fresh module scope.
local files={};for line in io.lines('build/scripts.txt') do local f=assert(io.open('app/'..line));files[line]=f:read('a');f:close() end
local fresh=R.session(files,{});fresh:draw();assert(fresh.alive,fresh.error)
local lock=R.session(files,{},'lock');lock:draw();assert(lock.alive and lock.save_attempts==0)
assert(not fresh.loaded['lib.ui.forms'] and not fresh.loaded['lib.ui.info'] and not fresh.loaded['lib.core.importer'])
print('HOST MOCK foreground flow, geometry, draw purity, lazy loading passed')
-- Real pointer/key routes: settle suppression, duplicate key suppression, wrap and activation.
a.page={kind='deck'};a.stack={};draw();a.changed_at=a.ms
local before=#a.stack;a:input(c,{type='pointer',phase='down',x=80,y=750});a:input(c,{type='pointer',phase='up',x=80,y=750,gesture='tap'});assert(#a.stack==before)
c:advance(500);a:input(c,{type='pointer',phase='down',x=80,y=750});a:input(c,{type='pointer',phase='up',x=80,y=750,gesture='tap'});assert(a.page.kind=='keypad');draw()
a:input(c,{type='key',key='down',phase='up'});local focus=a.focus;a:input(c,{type='key',key='down',phase='up'});assert(a.focus==focus)
c:advance(300);a:input(c,{type='key',key='down',phase='up'});assert(a.focus~=focus)
-- Ten mixed items draw within budget and have independent target identities.
a.page={kind='deck'};a.stack={};for n=1,10 do a:event({action='CREATE',type=n%2,dur=100,icon=n}) end;draw();assert(#a.state.items==10)
local id,gen=a.state.items[1].id,a.state.items[1].gen;a:command('DELETE',{id=id,gen=gen});a:command('CREATE',nil,{dur=100});local _,result=M.command(a.state,{action='PRIMARY',id=id,gen=gen},a.sec);assert(result=='STALE')
print('HOST MOCK TU01-TU13 foreground scope passed; alert/appearance extensions remain later gates')
-- TU17: every deck key stop resolves to the highlighted control, including empty.
do
 local Nav=require('lib.ui.nav')
 for _,count in ipairs({0,1,10}) do
  local cc=R.new();local aa=App.new(cc)
  for _=1,count do aa:command('CREATE',nil,{dur=100}) end
  aa:draw(cc,R.canvas(cc))
  for n=1,2*(count+3) do
   aa.ms=aa.ms+300;Nav.input(aa,{type='key',key='down',phase='up'})
   local focus=assert(aa.focus);aa.ms=aa.ms+300
   local h=Nav.input(aa,{type='key',key='up',phase='up'})
   assert(h and h.action,'TU17 nil action at focus '..focus)
   assert(focus<=count and h.id==aa.deck_entries[focus].id or focus>count and h.action==({'new_timer','chains','menu'})[focus-count])
  end
  assert(aa:action({})==false,'TU17 nil action guard')
 end
 print('HOST MOCK Passed TU17')
end
-- N2 cases run independently so the red run records every defect.
do
 local failures={}
 local function case(id,fn) local ok,err=pcall(fn);print('HOST MOCK '..id..' '..(ok and 'Passed' or tostring(err)));if not ok then failures[#failures+1]=id end end
 local function fresh() local c=R.new();return App.new(c),c end
 case('TU19 / BUG-05',function()
  for _,strip in ipairs({'chain','warning','clock','coverage'}) do
   local a,c=fresh();for _=1,10 do a:command('CREATE',nil,{dur=100}) end
   if strip=='chain' then local H=require('lib.core.chains');a:command('CH_SAVE',nil,{definition=H.template('Tea',0)});a:command('CH_START',{id=1},{rev=1})
   elseif strip=='clock' then a.sec=nil elseif strip=='coverage' then a.coverage_warning='coverage' else a.warning='warning' end
   local seen={}
   for _=1,2 do
    a:draw(c,R.canvas(c));local pager
    for n,h in ipairs(a.hits) do
     if h.action=='detail' then seen[h.id]=true end
     if h.action=='page' and h.arg==1 then pager=h end
     for k=1,n-1 do local b=a.hits[k];assert(h.x>=b.x+b.w or b.x>=h.x+h.w or h.y>=b.y+b.h or b.y>=h.y+h.h) end
    end
    assert(pager and pager.h>=56,'missing pager');a:action(pager)
   end
   for id=1,10 do assert(seen[id]) end;assert(a.page.offset==0,'pager wraps')
  end
 end)
 case('TU20 / BUG-08',function()
  local a,c=fresh();a:action({action='new_timer'});a.focus=3;a.peek={};a.banner='stale';a.ms=a.ms+1000
  a:action({action='create',arg=true});assert(a.focus==nil and a.peek==nil and a.banner==nil and a.changed_at==a.ms,'page replacement bookkeeping')
 end)
 case('TU20 / BUG-09',function()
  local a,c=fresh();a:command('CREATE',nil,{dur=100});a:open_form(a.state.items[1]);a:action({action='edit_time'});a:action({action='back'});assert(not c.overlay and a.page.kind=='form','unchanged time prompts')
  a:action({action='edit_time'});a:action({action='digit',arg='2'});a:action({action='back'});assert(c.overlay)
 end)
 case('TU21 / BUG-10',function()
  local a,c=fresh();a.page={kind='coverage'};a:draw(c,R.canvas(c));for _,h in ipairs(a.hits) do assert(h.action~='enable_awake','already enabled') end
 end)
 case('TU21 / BUG-11',function()
  local a,c=fresh();a:action({action='settings'});a:action({action='setting',arg='secs'});assert(a.page.title=='Seconds','picker title')
  a:action({action='back'});a:action({action='chains'});a:action({action='ch_new'});a:action({action='ch_template',arg='Tea'});a:action({action='name'});assert(c.overlay.opts.title=='Chain name')
 end)
 case('TU25 / BUG-14',function()
  local a,c=fresh();a:command('CREATE',nil,{dur=100});a:action({action='arm_delete',id=1,gen=0});a:action({action='ch_arm',arg=2});assert(a.armed and a.armed.kind=='chain' and a.armed.id==2 and not a.delete_arm)
  c:advance(5000);assert(not a.armed);a:action({action='arm_delete',id=1,gen=0});a:draw(c,R.canvas(c));c:advance(500);a:input(c,{type='pointer',phase='up',gesture='tap',x=400,y=750});assert(not a.armed and a.page.kind=='deck')
 end)
 case('TD03 / BUG-15',function()
  local a,c=fresh();a:command('CREATE',nil,{dur=100});a.page={kind='detail',id=1};a:action({action='peek'});assert(not a.peek,'Ready must not peek')
 end)
 case('TU23 / BUG-16',function()
  local a,c=fresh();c.dialog.confirm=function() return nil,'busy' end;a:confirm('Confirm?',function() end);assert(a.page.kind=='confirm' and c.logs[#c.logs][2]=='E-DIALOG','dialog fallback')
  local I=require('lib.core.importer');for _=1,10 do a:command('CREATE',nil,{dur=100}) end
  local _,err=I.propose(a.state,'timer | Tea | 10',123,a.sec);assert(not err:find('FULL',1,true),'raw import code')
 end)
 assert(#failures==0,table.concat(failures,', '))
end
-- POL-06: new stopwatch Start and initial list focus.
do
 local c=R.new();local a=App.new(c);a:action({action='new_watch'});a:action({action='save_form',arg=true});assert(a.page.kind=='detail' and a.state.items[1].type==1 and a.state.items[1].st==1)
 a:go({kind='menu'});a:draw(c,R.canvas(c));a:input(c,{type='key',key='up',phase='up'});assert(a.page.kind=='menu');a:input(c,{type='key',key='down',phase='up'});assert(a.hits[a.focus].action=='new_watch')
end
