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
local function action(s,arg)
 a:sample();a:event();assert(a:action({action=s,arg=arg}));draw()
end
draw();action('new_timer');action('digit','9');action('digit','0');action('create',true);assert(#a.state.items==1 and a.state.items[1].dur==90 and a.state.items[1].st==1)
local i=a.state.items[1];a:action({action='primary',id=i.id,gen=i.gen});assert(a.state.items[1].st==2);a:action({action='primary',id=i.id,gen=i.gen});assert(a.state.items[1].st==1)
a:action({action='reset',id=i.id,gen=i.gen});draw();assert(a.state.items[1].st==0)
a:action({action='actions'});action('edit');action('icons');action('pick',1);action('save_form',false);assert(a.state.items[1].icon==1)
a:action({action='delete',id=a.state.items[1].id,gen=a.state.items[1].gen});draw();assert(#a.state.items==0)
a.page={kind='deck'};action('menu');action('settings');action('setting','app');action('pick',2);assert(a.preview_setting.value==2);action('back');assert(a.state.set.app==0 and not a.preview_setting)
a.page={kind='deck'};action('help');for _=1,7 do action('about_tap') end;assert(a.page.kind=='info')
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
