package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local J=require('json');collectgarbage('collect');local harness=collectgarbage('count')*1024
local M=require('lib.core.model');local App=require('lib.app')
local c=R.new();local a=App.new(c);local peak,commands=0,0
local function clean_logs() c.waves={};c.awake_calls={};c.light_calls={};c.deferred={};c.saved=0;c.save_attempts=0 end
local function draw()
 collectgarbage('collect');local before=assert(J:encode(a.state));local g=R.canvas(c);a:draw(c,g);assert(g.command_count<=768);commands=math.max(commands,g.command_count)
 assert(before==J:encode(a.state));peak=math.max(peak,collectgarbage('count')*1024)
 for n,h in ipairs(a.hits) do assert(h.x>=0 and h.y>=0 and h.x+h.w<=480 and h.y+h.h<=800 and h.w>=56 and h.h>=56)
  for k=1,n-1 do local b=a.hits[k];assert(h.x>=b.x+b.w or b.x>=h.x+h.w or h.y>=b.y+b.h or b.y>=h.y+h.h,'overlap '..a.page.kind) end
 end
end
for _,kind in ipairs({'deck','menu','settings','help','info','recovery','blocked','coverage','sync','chains','chain_new'}) do
 if kind=='help' then a:help() elseif kind=='info' then a:diagnose() else a.page={kind=kind} end;draw()
end
a.page={kind='deck'};a.stack={};a:action({action='new_timer'});draw();a:action({action='more'});draw();a:action({action='icons'});draw();a:action({action='pick',arg=1});a:action({action='save_form'});a.page={kind='detail',id=1};draw()
a.page={kind='deck'};for n=2,10 do a:command('CREATE',nil,{dur=100,name='Timer '..n,icon=n}) end
for n=10,0,-1 do draw();if n>0 then a:command('DELETE',{id=n,gen=0}) end end
a.page={kind='deck'};a.stack={};a:action({action='chains'});a:action({action='ch_new'});a:action({action='ch_template',arg='Tea'});draw();a:action({action='ch_step',arg=1});draw();a:action({action='ch_step_save'});a:action({action='ch_save'});draw();a:action({action='ch_start'});draw();a:action({action='ch_more'});draw();a:action({action='ch_steps'});draw()
a.page={kind='sync'};c.files:write('timerdeck-import.txt','timer | Tea | 10');a:action({action='import'});draw();a:command('ERASE')
-- Older saves keep their settings and timers; all render using the default appearance.
local legacy_frame
for style=0,3 do
 a:command('SETTINGS',nil,{values={style=style}})
 assert(M.valid(a.state));a.page={kind='settings'};draw()
 for _,hit in ipairs(a.hits) do assert(hit.arg~='style') end
 a:action({action='setting',arg='style'});assert(a.page.kind=='settings' and a.state.set.style==style)
 a.page.offset=1;draw();for _,hit in ipairs(a.hits) do assert(hit.arg~='style') end
 a:command('CREATE',nil,{dur=100});local item=a.state.items[1];a.page={kind='detail',id=item.id}
 local canvas=R.canvas(c);a:draw(c,canvas);local frame=assert(J:encode(canvas.commands))
 if legacy_frame then assert(frame==legacy_frame) else legacy_frame=frame end
 a:command('DELETE',{id=item.id,gen=item.gen})
end
print('HOST MOCK legacy style compatibility and retired settings navigation passed')
a.page={kind='settings'};a:action({action='setting',arg='app'});draw();a:action({action='back'})
-- Warm lazy modules and cache, then measure retained growth without host evidence logs.
a.page={kind='deck'};a.stack={};clean_logs();collectgarbage('collect');local start=collectgarbage('count')*1024
for _=1,100 do a:command('CREATE',nil,{dur=10});local i=a.state.items[1];a:command('DELETE',{id=i.id,gen=i.gen});a:push({kind='settings'});a:pop();c:advance(2000);clean_logs() end
collectgarbage('collect');local growth=collectgarbage('count')*1024-start;assert(growth<=4096,growth)
assert(peak-harness<=524288,peak-harness)
local report={evidence='HOST MOCK',device_tests_run=false,heap_peak_bytes=math.floor(peak-harness),host_total_peak_bytes=math.floor(peak),harness_baseline_bytes=math.floor(harness),retained_growth_bytes=math.floor(growth),max_draw_commands=commands,device_callback_times='Not run'}
print('HOST MOCK Passed TM01 peak '..math.floor(peak-harness)..' app-attributable bytes;  retained growth '..math.floor(growth)..' bytes')
-- Fresh entry VM, real overlays and a recoverable injected draw failure.
local files={};for path in io.lines('build/scripts.txt') do local f=assert(io.open('app/'..path));files[path]=f:read('a');f:close() end
local state=M.new(c.now_value.epoch_sec);state=M.command(state,{action='CREATE_START',dur=100},c.now_value.epoch_sec)
local session=R.session(files,state);session:draw();session:advance(500);session:event('on_input',{type='pointer',phase='up',gesture='tap',x=150,y=100});session:draw()
local g=R.canvas(session);g.circle=function() error('injected draw failure') end;session:event('on_draw',g);assert(session.alive and session.logs[#session.logs][2]=='E-DRAW');local logs=#session.logs;session:draw();assert(#session.logs==logs)
session:event('on_input',{type='key',key='up',phase='up'});session:draw();assert(session.alive and session.state.items[1].st==1);print('HOST MOCK Passed TU15')
session:advance(61000);session:leave()
local lock=R.session(files,state,'lock');lock:draw();report.lock_instructions=lock.budgets
assert((lock.budgets.on_load or 0)+(lock.budgets.on_draw or 0)<100000)
report.instructions=session.budgets
local source=assert(io.open('tools/tests/instruction-baseline.json'));local baseline=assert(J:decode(source:read('a')));source:close()
for name,count in pairs(lock.budgets) do assert(count<=baseline.lock[name]*2+1000) end
for name,count in pairs(session.budgets) do assert(count<=baseline.main[name]*2+1000,name..' instruction proxy exceeded');print('HOST MOCK instructions '..name..' '..count) end
local f=assert(io.open('build/validation-results.json','w'));f:write(assert(J:encode(report)));f:close()
-- Key-only access to creation and menu remains possible when the deck is nonempty.
a.state=M.new(c.now_value.epoch_sec);a.ctx.state=a.state;a.page={kind='deck'};a.stack={};a.focus=nil;a:command('CREATE',nil,{dur=10});draw()
local function key(name) c:advance(300);a:input(c,{type='key',key=name,phase='up'});draw() end
key('down');assert(a.focus==1);key('down');assert(a.focus==2);key('up');assert(a.page.kind=='keypad')
-- Optional capabilities must not be required by ordinary timers or fallback confirmation.
local optional=R.new({keep_awake=false,lockscreen=false,capabilities={frontlight=false,dialog=false}});local fallback=App.new(optional);fallback:command('CREATE_START',nil,{dur=1});optional:advance(8000);assert(not fallback.fatal and fallback.state.items[1].att==3)
fallback:action({action='erase'});assert(fallback.page.kind=='confirm');fallback:action({action='back'});assert(#fallback.state.items==1)
print('HOST MOCK key-only deck access and absent-capability paths passed')
-- A native name overlay that crosses a deadline preserves the interrupted form.
local overlay_ctx=R.new();local overlay_app=App.new(overlay_ctx);overlay_app:command('CREATE_START',nil,{dur=1});overlay_app:open_form(overlay_app.state.items[1]);local draft=overlay_app.page
assert(overlay_app:action({action='name'}));overlay_app:pause(overlay_ctx);overlay_ctx.paused=true;overlay_ctx:advance(2000);local completion=overlay_ctx.overlay.fn;overlay_ctx.overlay=nil;overlay_ctx.paused=false;overlay_app:resume(overlay_ctx);completion(overlay_ctx,'  My Tea  ')
assert(overlay_app.state.items[1].name=='My Tea' and overlay_app.page.kind=='completion');local kept=false;for _,page in ipairs(overlay_app.stack) do if page==draft then kept=true end end;assert(kept)
overlay_app:action({action='clear_all'});assert(overlay_app.page==draft);print('HOST MOCK TU09 / TU10 overlay interruption and draft restoration passed')
local lock_ctx=R.new();local lock_app=App.new(lock_ctx);lock_app:action({action='lockscreen'});assert(lock_ctx.overlay and not lock_app.lock_default);lock_ctx.overlay=nil;lock_ctx.lock_default=true;lock_app:resume(lock_ctx);assert(lock_app.lock_default);lock_app:action({action='lockscreen'});assert(not lock_app.lock_default);print('HOST MOCK TU11 lock selection and resume recheck passed')
-- TU22: legacy appearance/style are validated, preserved and ignored; controls follow capabilities.
do
 local frame
 for appearance=0,2 do for style=0,3 do
  local state=M.new();state.set.app=appearance;state.set.style=style
  local cc=R.new({state=state});local aa=App.new(cc);local canvas=R.canvas(cc);aa:draw(cc,canvas)
  local encoded=J:encode(canvas.commands);if frame then assert(frame==encoded) else frame=encoded end
  assert(aa.state.set.app==appearance and aa.state.set.style==style and M.valid(aa.state))
 end end
 for _,light in ipairs({false,true}) do for _,awake in ipairs({false,true}) do for flash=0,1 do for pulse=0,1 do
  local cc=R.new({keep_awake=awake,capabilities={frontlight=light}});local aa=App.new(cc);aa.state.set.flash=flash;aa.state.set.light=pulse;aa.page={kind='settings'};local seen={}
  for page=0,1 do aa.page.offset=page;aa:draw(cc,R.canvas(cc));assert(aa.page_count==1,'Settings must fit one page');for _,h in ipairs(aa.hits) do if h.arg then seen[h.arg]=true;assert(h.arg~='app' and h.arg~='style') end end end
  assert(not not seen.pat==(light and pulse==1));assert(not not seen.cnt==(flash==1 or light and pulse==1));assert(not not seen.awake==awake)
 end end end end
 print('HOST MOCK Passed TU22')
end
-- TU24: a physical tap runs one planner and at most two state copies; idle Settings stays still.
do
 local cc=R.new();local aa=App.new(cc);aa:command('CREATE',nil,{dur=7200});aa:draw(cc,R.canvas(cc));cc:advance(500)
 local original,plan=M.copy,App.plan;local copies,depth,plans=0,0,0
 M.copy=function(v) if depth==0 then copies=copies+1 end;depth=depth+1;local out=original(v);depth=depth-1;return out end
 App.plan=function(self) if not self.in_callback then plans=plans+1 end;return plan(self) end
 for _,phase in ipairs({'down','move','move','move','move','move','up'}) do aa:input(cc,{type='pointer',phase=phase,gesture='tap',x=440,y=100}) end
 M.copy=original;App.plan=plan
 assert(copies<=2 and plans==1,'TU24 copies/plans '..copies..'/'..plans);assert(aa.state.items[1].st==1)
 aa:push({kind='settings'});aa:plan();local waves=#cc.waves;local awake=#cc.awake_calls;cc:advance(300000)
 assert(#cc.waves==waves,'TU24 Settings pulse redrew');assert(#cc.awake_calls-awake<10,'awake renewal churn')
 local root=aa.state;local before=J:encode(root);assert(not M.due(root,aa.sec));assert(J:encode(root)==before)
 collectgarbage('collect');collectgarbage('stop');local base=collectgarbage('count');for _=1,100 do local copy=M.copy(root);M.reconcile(copy,aa.sec) end;local old=(collectgarbage('count')-base)*1024
 collectgarbage('restart');collectgarbage('collect');collectgarbage('stop');base=collectgarbage('count');for _=1,100 do aa:event() end;local current=(collectgarbage('count')-base)*1024;collectgarbage('restart')
 assert(current<old,'idle heap churn did not improve');print('HOST MOCK Passed TU24 copies '..copies..' plans '..plans..'; idle allocation '..math.floor(current)..' vs copying '..math.floor(old))
end
-- TU23: every toast/confirmation payload fits API byte limits, including fallback.
do
 local S=require('lib.core.const').COPY
 for _,key in ipairs({'exported','import_ok','zero','name_rule','FULL','CHAIN_FULL','ACTIVE','chain_min','chain_max','STALE','saved','INVALID','OVERFLOW','CLOCK','DUPLICATE'}) do assert(#S[key]<=95,key) end
 for _,opts in pairs(S.dialogs) do assert(#opts.title<=95 and #(opts.message or '')<=191 and #opts.ok_text<=63 and #opts.cancel_text<=63) end
 local cc=R.new();local aa=App.new(cc);aa:toast(S.exported);assert(cc.toast==S.exported and aa.page.kind=='deck')
 cc.dialog.toast=function() return nil,'limit_exceeded' end;aa:toast(S.exported);assert(aa.page.kind=='message')
 print('HOST MOCK Passed TU23')
end
-- TU26: the notice remains exact, visible on Help page 1 and the empty deck, with no other channel claims.
do
 local S=require('lib.core.const').COPY;local notice='This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.'
 assert(S.notice==notice);local cc=R.new();local aa=App.new(cc);aa:help();assert(aa.help_pages[1]:find(notice,1,true))
 aa:go({kind='deck'});local g=R.canvas(cc);aa:draw(cc,g);local found=false;for _,cmd in ipairs(g.commands) do if cmd.method=='text_box' and cmd.args[5]==notice then found=true end end;assert(found)
 local f=assert(io.open('app/manifest.json'));local manifest=assert(J:decode(f:read('a')));f:close();assert(manifest.description==notice)
 local function strip(text,literal) local at=text:find(literal,1,true);while at do text=text:sub(1,at-1)..text:sub(at+#literal);at=text:find(literal,1,true) end;return text end
 local function walk(v)
  if type(v)=='table' then for _,x in pairs(v) do walk(x) end
  elseif type(v)=='string' then v=strip(strip(v,notice),'No sound'):lower();for _,word in ipairs({'beep','buzz','ring','vibrate','sound','alarm','vibration'}) do assert(not v:find('%f[%a]'..word..'%f[%A]'),'banned copy '..word..': '..v) end end
 end
 walk(S);walk(manifest.description);print('HOST MOCK Passed TU26')
end
