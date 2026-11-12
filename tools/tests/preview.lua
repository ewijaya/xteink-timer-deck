package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local J=require('json');local M=require('lib.core.model');local App=require('lib.app');local C=require('lib.core.const')
local c=R.new();local a=App.new(c)
local function emit(name)
 for _,dark in ipairs({false,true}) do
  c.dark=dark;local g=R.canvas(c);a:draw(c,g);assert(g.command_count<=768)
  print(assert(J:encode({name='HOST-MOCK-'..name..(dark and '-dark' or '-light'),dark=dark,commands=g.commands})))
 end
end
emit('empty')
a:action({action='new_timer'});emit('keypad');a:action({action='more'});emit('form');a:action({action='icons'});emit('icons');a:action({action='pick',arg=1});a:action({action='pattern'});emit('patterns');a:action({action='pick',arg=2});a:action({action='save_form',arg=false})
a.page={kind='deck'};emit('deck-one');a.page={kind='detail',id=a.state.sel};emit('ready')
local i=a.state.items[1];a:action({action='primary',id=i.id,gen=i.gen});emit('running');i=a.state.items[1];a:action({action='primary',id=i.id,gen=i.gen});emit('paused')
a:action({action='edit'});a:action({action='edit_time'});emit('days-keypad')
a.page={kind='deck'};a.stack={};for n=2,10 do a:event({action='CREATE',dur=240*n,type=n%2,icon=n,name='Item '..n}) end;emit('deck-ten')
a:action({action='menu'});emit('menu');a:action({action='settings'});emit('settings');a.page.offset=1;emit('settings-page2');a:help();emit('help');a:diagnose();a.page={kind='info'};emit('information')
a.page={kind='deck'};a.stack={};local s=M.new(a.sec);s=M.command(s,{action='CREATE_START',dur=1,name='Tea',icon=1},a.sec);M.reconcile(s,a.sec+1);a.state=s;c.state=s;a:completion();emit('completion')
local g=R.canvas(c);App.draw_fatal(c,g,'E-DRAW');print(assert(J:encode({name='HOST-MOCK-fatal',commands=g.commands})))

for _,kind in ipairs({'recovery','blocked'}) do a.page={kind=kind};emit(kind) end
a.mode='ok';a.page={kind='deck'};a.state=M.new(a.sec);a.state=M.command(a.state,{action='CREATE_START',dur=18000,name='Slow roast'},a.sec);a:plan();emit('coverage-deck');a.page={kind='coverage'};emit('coverage-help')
a.page={kind='completion'};a.state=s;a.queue=M.completions(s,true);a.queue_pos=1;a.flash=true;emit('flash');a.flash=false
local files={};for path in io.lines('build/scripts.txt') do local f=assert(io.open('app/'..path));files[path]=f:read('a');f:close() end
for _,case in ipairs({'empty','running','finished','paused','watch','invalid'}) do
 local state=M.new(a.sec)
 if case~='empty' and case~='invalid' then state=M.command(state,{action='CREATE',type=case=='watch' and 1 or 0,dur=240,name='Tea'},a.sec);state=M.command(state,{action='PRIMARY',id=1,gen=0},a.sec) end
 if case=='paused' then state=M.command(state,{action='PRIMARY',id=1,gen=1},a.sec) elseif case=='finished' then state.items[1].anc=a.sec-1 elseif case=='invalid' then state={v=2} end
 for _,dark in ipairs({false,true}) do local lock=R.session(files,state,'lock');lock.dark=dark;local canvas=lock:draw();print(assert(J:encode({name='HOST-MOCK-lock-'..case..(dark and '-dark' or '-light'),dark=dark,commands=canvas.commands}))) end
end
a.state=M.new(a.sec);a.mode='ok';a.flash=false;a.page={kind='deck'};a.stack={};a:action({action='chains'});emit('chains-empty');a:action({action='ch_new'});emit('chain-new');a:action({action='ch_template',arg='Pomodoro'});emit('chain-editor');a:action({action='ch_step',arg=1});emit('chain-step');a:action({action='ch_step_save'});a:action({action='ch_save'});emit('chain-overview');a:action({action='ch_start'});emit('chain-run');a:action({action='ch_more'});emit('chain-actions');a:action({action='ch_steps'});emit('chain-steps');a:action({action='chains'});emit('chains-list')
a.page={kind='deck'};for n=1,10 do a:command('CREATE',nil,{dur=600,icon=n,name='Timer '..n}) end;a:plan();emit('chain-deck-ten')
local run=a.state.ch.run;a:command('CH_STOP',nil,{gen=run.gen,step=run.snap.steps[run.idx].id,round=run.round});emit('chain-result')
