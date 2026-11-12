local M=require('lib.core.model');local C=require('lib.core.const');local F=require('lib.core.format');local P=require('lib.core.pulse')
local S=require('lib.ui.strings');local Clock=require('lib.platform.clock');local Store=require('lib.platform.store');local N=require('lib.ui.nav');local W=require('lib.ui.widgets');local Theme=require('lib.ui.theme')
local Deck=require('lib.ui.deck');local Detail=require('lib.ui.detail');local Keypad=require('lib.ui.keypad');local Completion=require('lib.ui.completion')
local H=require('lib.core.chains')
local Alerts=require('lib.core.alerts');local Signal=require('lib.platform.signal')
local A={};A.__index=A
local function same(a,b) if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end;for k,v in pairs(a) do if not same(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true end
function A.new(ctx)
 local self=setmetatable({ctx=ctx,page={kind='deck'},stack={},hits={},keys={},fonts={},shown={},partials=0,queue={},queue_pos=1,alive=true},A)
 for _,px in ipairs({22,26,32,40}) do self.fonts[px]=ctx.fonts:size(px) end
 self:sample();self.started_ms=self.ms;self.original_light=ctx.frontlight and ctx.frontlight:get();self.last_save=self.sec or 0;self.changed_at=self.ms
 local state,status=Store.load(ctx,self.sec);self.state=state or M.new();self.mode=status
 if not state then self.page={kind=status} else self.ctx.state=state;self:event(nil,status=='new' or status=='restored');if status=='restored' then self:message(S.restored) end end
 self:invalidate(true);return self
end
function A:sample()
 self.now,self.ms=Clock.sample(self.ctx);self.sec=self.now.valid and self.now.epoch_sec or nil
 self.lock_default=self.ctx.lockscreen and self.ctx.lockscreen:is_default() or false
end
function A:invalidate(full)
 if full then self.partials=0;self.ctx:invalidate('full') else self.partials=self.partials+1;self.ctx:invalidate() end
end
function A:disarm()
 if self.arm_timer then self.arm_timer:cancel();self.arm_timer=nil end;self.armed=nil
end
function A:arm(kind,id,gen)
 self:disarm();self.armed={kind=kind,id=id,gen=gen}
 self.arm_timer=self.ctx:after(5000,function() self:callback(function() self.arm_timer=nil;self.armed=nil;self:invalidate() end) end)
end
function A:go(page)
 self.stack={};self.page=page;self.focus=nil;self.peek=nil;self.banner=nil;self:disarm();self.changed_at=self.ms;self:invalidate(self.partials>=12)
end
function A:prune()
 local r=self.state.ch.run
 local function stale(p) return (r.st~=1 and r.st~=2) and (p.kind=='chain_run' or (p.kind=='chain_more' or p.kind=='chain_steps') and p.run) end
 for n=#self.stack,1,-1 do if stale(self.stack[n]) then table.remove(self.stack,n) end end
 while stale(self.page) do self:pop() end
end
function A:push(page)
 self:disarm();self.stack[#self.stack+1]=self.page;self.page=page;self.focus=nil;self.peek=nil;self.changed_at=self.ms;self:invalidate(self.partials>=12)
end
function A:pop()
 local old=self.page.kind;self:disarm()
 self.page=table.remove(self.stack) or {kind=(self.mode=='recovery' or self.mode=='blocked') and self.mode or 'deck'};self.focus=nil;self.peek=nil;self.changed_at=self.ms;self:invalidate(self.partials>=12)
 if old~='deck' and old~='detail' then self.ctx.gc:collect() end
end
function A:message(text)
 self:push({kind='message',text=text})
end
function A:toast(text)
 if self.ctx.dialog then local _,err=self.ctx.dialog:toast(text);if not err then return end;self.ctx.log:error('E-DIALOG') end
 self:message(text)
end
function A:callback(fn,...)
 local outer=self.in_callback;self.in_callback=true
 local args=table.pack(...)
 local ok,result=pcall(function() local result=fn(table.unpack(args,1,args.n));if not outer and self.plan_dirty then self.in_callback=false;self.plan_dirty=nil;self:plan() end;return result end)
 self.in_callback=outer
 if not ok then self.fatal='E-CALLBACK';self.ctx.log:error(self.fatal);self:pause(self.ctx);self:invalidate(true) end
 return ok,result
end
function A:confirm(text,fn)
 local opts=type(text)=='table' and text or S.dialogs[text] or {title=text,ok_text=S.delete,cancel_text=S.keep}
 if self.ctx.dialog then
  local _,err=self.ctx.dialog:confirm(opts,function(ctx,yes) self:callback(function() self:sample();self:event();if yes then fn() end;self:plan() end) end)
  if not err then return end;self.ctx.log:error('E-DIALOG')
 end
 self:push({kind='confirm',text=opts.title,options=opts,accept=fn})
end
function A:commit(candidate,time_driven)
 local previous=self.state
 local ok=Store.commit(self.ctx,candidate,previous)
 if ok then self.state=candidate;self.ctx.state=candidate;self.warning=nil;self.last_save=self.sec or self.last_save;if not self.checkpoint then self:backup() end;return true end
 if time_driven then self.state=candidate;self.ctx.state=candidate;self.warning=S.not_saved;self.unsaved=true
 else self:message(S.save_error) end
 return false
end
function A:event(command,initial)
 if self.mode=='blocked' or self.mode=='recovery' then return false end
 local working=self.state;local changed,rollback=false,false
 if M.due(working,self.sec) then working=M.copy(working);changed,rollback=M.reconcile(working,self.sec) elseif self.sec then working.trusted=self.sec end
 if changed or self.unsaved then
  if self:commit(working,true) then if self.unsaved then self:toast(S.saved) end;self.unsaved=false end
 else self.state=working;self.ctx.state=working end
 if rollback then self.warning=S.rollback end
 local success=true
 if command then
  local candidate,result=M.command(self.state,command,self.sec)
  if result~='OK' then success=false;self:toast(S[result] or S.INVALID)
  elseif not same(candidate,self.state) then success=self:commit(candidate,false) end
 elseif initial or M.checkpoint_due(self.state,self.sec,self.last_save) then local checkpoint=not initial;self.checkpoint=checkpoint;self:commit(M.copy(self.state),true);self.checkpoint=false end
 self.event_changed=changed;self:prune();self:completion();self:effects();self:plan();return success
end
function A:completion()
 local q=M.completions(self.state,true);local unseen=false;local active={}
 for _,ref in ipairs(q) do active[ref.id..':'..ref.gen]=true end
 local r=self.state.ch.run;if r.st>=3 then active['chain:'..r.gen..':'..r.st]=true end
 for key in pairs(self.shown) do if not active[key] then self.shown[key]=nil end end
 for _,r in ipairs(q) do local i=M.find(self.state,r.id);if i.sil==0 and not self.shown[r.id..':'..r.gen] then unseen=true;self.shown[r.id..':'..r.gen]=true end end
 self.queue=q
 local run=self.state.ch.run
 if run.st>=3 and not self.shown['chain:'..run.gen..':'..run.st] then self.shown['chain:'..run.gen..':'..run.st]=true;self:push({kind='chain_result'}) end
 if unseen and self.page.kind~='completion' then self:push({kind='completion'});self:invalidate(true) end
 if self.page.kind=='completion' and #q==0 then self:pop();self:invalidate(true) end
 self.queue_pos=math.max(1,math.min(self.queue_pos,#q))
end
function A:backup()
 self.backup_pending=true
 if self.backup_timer then self.backup_timer:cancel() end
 self.backup_timer=self.ctx:after(2000,function() self:callback(function() self.backup_timer=nil;self:flush_backup() end) end)
end
function A:flush_backup()
 if not self.backup_pending or self.unsaved then return end
 local ok=Store.backup(self.ctx,self.state)
 if ok then self.backup_pending=false else self.ctx.log:error('E-BACKUP') end
end
function A:effects()
 if self.paused or self.unsaved or self.signal or not self.sec then return end
 local target=Alerts.choose(self.state,self.sec);if not target then return end
 local elapsed=(self.ms-(self.last_attempt or self.started_ms))&0x7fffffff
 if elapsed<(self.last_attempt and C.ATTEMPT_INTERVAL_MS or 1000) then return end
 local candidate,result=M.command(self.state,{action=target.chain and (target.cue and 'CH_CUE' or 'CH_ATTEMPT') or 'ATTEMPT',id=target.id,gen=target.gen,step=target.step,round=target.round},self.sec)
 if result=='OK' then
  local previous=self.state
  if self:commit(candidate,true) then self.last_attempt=self.ms;if target.cue then local r=self.state.ch.run;self.banner={text=S.starting..F.step_label(r.snap.steps[r.idx],r.idx),gen=r.gen,step=r.idx,round=r.round} end;Signal.start(self,target.pat) else self.state=previous;self.ctx.state=previous end
 end
end
function A:preview_pattern(pattern) Signal.start(self,pattern,true) end
function A:coverage(i)
 return S.coverage[Alerts.coverage(self.state,i,self.sec,self.ctx.device.keep_awake~=nil,self.lock_default and self.ctx.device.lock_timer)]
end
function A:plan()
 if self.in_callback then self.plan_dirty=true;return end
 if self.pulse then self.pulse:cancel();self.pulse=nil end
 if not self.alive or self.mode=='blocked' or self.mode=='recovery' then return end
 local extra=self.unsaved and 1000 or nil
 if not self.unsaved and Alerts.choose(self.state,self.sec) then local elapsed=(self.ms-(self.last_attempt or self.started_ms))&0x7fffffff;extra=math.max(self.signal and 100 or 1,(self.last_attempt and C.ATTEMPT_INTERVAL_MS or 1000)-elapsed) end
 local delay=P.plan(self.state,self.sec,self.page.kind,self.last_save,extra,self.page.id)
 local old_coverage=self.coverage_warning
 self.coverage_warning=nil;self.chain_entry=nil
 local run=self.state.ch.run
 if run.st==1 or run.st==2 then local step=run.snap.steps[run.idx];self.chain_entry={chain=true,id=run.id,gen=run.gen,num=0,name=(run.snap.name~='' and run.snap.name or S.chains)..' '..run.idx..'/'..#run.snap.steps,icon=step.icon,type=0,st=run.st,dur=step.sec,val=H.value(run,self.sec),anc=run.anc,lim=0} end
 if run.st==1 and not (self.lock_default and self.ctx.device.lock_timer) and not (self.state.set.awake==1 and self.ctx.device.keep_awake and self.sec and H.remaining(run,self.sec)<=C.AWAKE_HORIZON_SEC) then self.coverage_warning=S.open_strip end
 for _,i in ipairs(self.state.items) do if i.type==0 and i.st==1 and self:coverage(i)==S.coverage[1] then self.coverage_warning=S.open_strip end end
 if old_coverage~=self.coverage_warning then self:invalidate() end
 if self.ctx.device.keep_awake then
  if Alerts.hold(self.state,self.sec) then
   local needed=math.min(14400000,((delay or 3600000)//1000+120)*1000)
   local remaining=self.held and self.awake_duration-((self.ms-self.awake_at)&0x7fffffff) or 0
   if not self.held or needed>remaining+60000 then self.ctx.device:keep_awake(needed);self.awake_at=self.ms;self.awake_duration=needed;self.held=true end
  elseif self.held then self.ctx.device:keep_awake(0);self.held=false end
 end
 if delay then self.pulse=self.ctx:after(delay,function(ctx) self:callback(function()
  self.pulse=nil;local strip=self.warning or self.coverage_warning;self:sample();self.peek=nil;self:event()
  local kind=self.page.kind
  if kind=='deck' or kind=='detail' or kind=='chain_run' or kind=='completion' or self.event_changed or strip~=(self.warning or self.coverage_warning) then
   self.tick_frames=(self.tick_frames or 0)+1;self.ctx:defer_full_refresh(5000);self:invalidate(self.tick_frames%120==0)
  end
 end) end) end
end
function A:command(action,h,fields)
 local c={action=action,id=h and h.id,gen=h and h.gen};for k,v in pairs(fields or {}) do c[k]=v end
 return self:event(c)
end
function A:open_form(i)
 local d=i and M.copy(i) or {type=1,name='',icon=0,dur=0,pat=self.state.set.pat,cnt=self.state.set.cnt,st=0}
 self:push({kind='form',id=i and i.id,gen=i and i.gen,draft=d,original=M.copy(d),live=i and i.st~=0 and i.st~=2})
end
function A:form_page()
 if self.page.kind=='form' or self.page.kind=='chain_edit' or self.page.kind=='chain_step' then return self.page end
 for n=#self.stack,1,-1 do if self.stack[n].kind=='form' or self.stack[n].kind=='chain_edit' or self.stack[n].kind=='chain_step' then return self.stack[n] end end
end
function A:pick_field(key,value)
 local form=self:form_page();if not form then return end
 if form.chain_draft then form.draft[key=='dur' and 'sec' or key]=value
 elseif form.live then
  if self:command(key=='name' and 'RENAME' or 'ICON',form,{[key]=value}) then form.draft[key]=value end
 else form.draft[key]=value end
end
function A:help()
 self.help_pages={};self.help_topics={};local page={};local used=0
 for topic_heading,topic_body in (S.help_text..'\n'):gmatch('([^\n]+)\n([^\n]+)\n') do
  local _,height,consumed=self.fonts[26]:layout(topic_body,420,500)
  assert(consumed==#topic_body,'help topic exceeds one page');height=height+26
  local size=height+46
  if used+size>540 and #page>0 then self.help_topics[#self.help_topics+1]=page;page={};used=0 end
  page[#page+1]={heading=topic_heading,body=topic_body,y=100+used,height=height};used=used+size
 end
 if #page>0 then self.help_topics[#self.help_topics+1]=page end
 for n,topics in ipairs(self.help_topics) do local text={};for _,topic in ipairs(topics) do text[#text+1]=topic.heading..'\n'..topic.body end;self.help_pages[n]=table.concat(text,'\n') end
 self:push({kind='help'})
end
function A:action(h)
 local action,arg=h.action,h.arg;local p=self.page;if not action then return false end
 if action=='sync' or action=='import' or action=='export' or action=='import_results' then return require('lib.ui.sync').action(self,h) end
 if action:sub(1,3)=='ch_' or action=='chains' or action=='chain_run' then return require('lib.ui.chains').action(self,h) end
 if action=='back' then
  if (self.mode=='recovery' or self.mode=='blocked') and p.kind==self.mode and #self.stack==0 then return false end
  if p.kind=='deck' then
   local running=self.state.ch.run.st==1;for _,i in ipairs(self.state.items) do if i.st==1 then running=true end end
   if running and not (self.lock_default and self.ctx.device.lock_timer) and self.ctx.dialog then
    self:confirm({title=S.leave_title,message=S.leave_text,ok_text=S.leave,cancel_text=S.stay},function() self.ctx:quit() end);return true
   end
   return false
  end
  if p.kind=='completion' then return self:action({action='clear_all'}) end
  if (p.kind=='form' or p.kind=='chain_edit' or p.kind=='chain_step') and not p.live and not same(p.draft,p.original) or p.kind=='keypad' and p.dirty then self:confirm((p.kind=='keypad' and not p.edit or p.kind=='form' and not p.id) and S.discard_new or S.discard,function() self:pop() end) else self:pop() end
 elseif action=='new_timer' then if #self.state.items>=C.CAPACITY then self:toast(S.FULL) else self:push({kind='keypad'}) end
 elseif action=='digit' then p.dirty=true;if p.replace and arg~='back' then p.digits=nil end;p.replace=false;p.digits=F.keypad(p.digits,arg)
 elseif action=='days' then p.dirty=true;p.days=math.max(0,math.min(999,(p.days or 0)+arg))
 elseif action=='create' or action=='more' then
  local dur=F.keypad_seconds(p.digits);if dur<1 then self:toast(S.zero);return true end
  if action=='more' then self:push({kind='form',draft={type=0,name='',icon=0,dur=dur,pat=self.state.set.pat,cnt=self.state.set.cnt,st=0},original={}})
  elseif self:command(arg and 'CREATE_START' or 'CREATE',nil,{type=0,dur=dur}) then self:go(arg and {kind='detail',id=self.state.sel} or {kind='deck'}) end
 elseif action=='new_watch' then self:open_form()
 elseif action=='detail' then if self:command('SELECT',h) then self:push({kind='detail',id=h.id}) end
 elseif action=='primary' then
  local i=M.find(self.state,h.id)
  if i and i.st==3 and p.kind=='deck' then self:push({kind='completion'}) else self:command('PRIMARY',h) end
 elseif action=='reset' then self:command('RESET',h)
 elseif action=='delete' then if self:command('DELETE',h) then self:go({kind='deck'}) end
 elseif action=='arm_delete' then self:arm('item',h.id,h.gen)
 elseif action=='keep' then self:disarm()
 elseif action=='edit' then local i=M.find(self.state,p.id);if i then self:open_form(i) end
 elseif action=='edit_time' then self:push({kind='keypad',edit=true,replace=true,days=p.draft.dur//86400,digits=string.format('%02d%02d%02d',p.draft.dur//3600%24,p.draft.dur//60%60,p.draft.dur%60)})
 elseif action=='time_done' then local v=(p.days or 0)*86400+F.keypad_seconds(p.digits);if v<1 or v>C.MAX_SEC then self:message(S.INVALID) else self:pick_field('dur',v);self:pop() end
 elseif action=='name' then
  local form=self:form_page();self.ctx.input:text({title=form.kind=='chain_edit' and S.chain_name or form.kind=='chain_step' and S.step_name or form.draft.type==0 and S.timer_name or S.watch_name,text=form.draft.name,max_bytes=C.NAME_MAX},function(ctx,value)
   self:callback(function() self:sample();self:event();if value~=nil then local normalized=F.name(value);if normalized then self:pick_field('name',normalized) else self:toast(S.name_rule) end end;self:invalidate() end)
  end)
 elseif action=='icons' then self:push({kind='icons',title=S.icon,key='icon',value=p.draft.icon})
 elseif action=='pattern' or action=='count' then self:push({kind='picker',title=action=='pattern' and S.alert or S.count,key=action=='pattern' and 'pat' or 'cnt',value=action=='pattern' and p.draft.pat or p.draft.cnt-1,options=action=='pattern' and C.PATTERNS or C.COUNTS})
 elseif action=='save_form' then
  local d=p.draft;local fields=p.id and {values=p.live and {name=d.name,icon=d.icon} or d.type==0 and {name=d.name,icon=d.icon,pat=d.pat,cnt=d.cnt,dur=d.st==0 and d.dur or nil} or {name=d.name,icon=d.icon}} or d
  if self:command(p.id and 'EDIT' or arg and d.type==0 and 'CREATE_START' or 'CREATE',p,fields) then if not p.id and arg and d.type==1 then local i=M.find(self.state,self.state.sel);if not self:command('PRIMARY',i) then return true end end;self:go((p.id or arg) and {kind='detail',id=p.id or self.state.sel} or {kind='deck'}) end
 elseif action=='pick' then
  if p.setting then if self:command('SETTINGS',nil,{values={[p.key]=p.key=='cnt' and arg+1 or arg}}) then self:pop() end
  else self:pick_field(p.key,p.key=='cnt' and arg+1 or arg);self:pop() end
 elseif action=='coverage' then self:push({kind='coverage'})
 elseif action=='enable_awake' then self:command('SETTINGS',nil,{values={awake=1}});self:pop()
 elseif action=='lockscreen' then if self.ctx.lockscreen then if self.lock_default then self.ctx.lockscreen:clear_default() else self.ctx.lockscreen:set_default() end;self.lock_default=self.ctx.lockscreen:is_default() end
 elseif action=='menu' or action=='settings' then self:push({kind=action})
 elseif action=='setting' then
  local options={secs=S.seconds_modes,pat=C.PATTERNS,cnt=C.COUNTS}
  if not options[arg] and arg~='flash' and arg~='light' and arg~='awake' then return false end
  if not options[arg] then self:command('SETTINGS',nil,{values={[arg]=1-self.state.set[arg]}})
  else self:push({kind='picker',title=({secs=S.seconds,pat=S.alert,cnt=S.count})[arg] or S.settings,key=arg,value=self.state.set[arg]-(arg=='cnt' and 1 or 0),options=options[arg],setting=true}) end
 elseif action=='help' then self:help()
 elseif action=='info' then self:diagnose();self:push({kind='info'})
 elseif action=='page' then local count=math.max(1,self.page_count or 1);p.offset=((p.offset or 0)+arg)%count;self.focus=nil
 elseif action=='next_item' then local _,n=M.find(self.state,p.id);if n and #self.state.items>0 then p.id=self.state.items[(n-1+arg)%#self.state.items+1].id;self.peek=nil end
 elseif action=='peek' then local i=M.find(self.state,p.id);if i and i.st==1 and self.sec and not P.seconds(self.state.set.secs,true,i,M.value(i,self.sec)) then local d,t=F.detail(M.value(i,self.sec),i.type==0,false);local value=M.value(i,self.sec);if value<86400 then t=string.format('%d:%02d:%02d',value//3600,value//60%60,value%60) end;self.peek={days=d,time=t,at=(F.clock(self.now):gsub('(%d+:%d%d)','%1:'..string.format('%02d',self.now.second or 0)))} end
 elseif action=='browse' then if #self.queue>0 then self.queue_pos=((self.queue_pos-1+arg)%#self.queue)+1 end
 elseif action=='dismiss' or action=='clear_all' then self:command('DISMISS',nil,{targets=action=='dismiss' and {{id=h.id,gen=h.gen}} or self.queue})
 elseif action=='erase' then self:confirm(S.erase_text,function() if self:command('ERASE') then
   if self.backup_timer then self.backup_timer:cancel();self.backup_timer=nil end;self.backup_pending=false
   local ok=self.ctx.storage:remove('deck.bak');if not ok then self.ctx.log:error('E-BACKUP') end
   self:go({kind='deck'});if self.ctx.device.keep_awake then self.ctx.device:keep_awake(0) end
  end end)
 elseif action=='retry_load' then
  local state,status=Store.load(self.ctx,self.sec);if state then self.state=state;self.ctx.state=state;self.mode=status;self:go({kind='deck'});self:event(nil,status~='ok') end
 elseif action=='fresh' then self:confirm(S.fresh_question,function()
  local original=self.ctx.state;local previous=self.state
  self.mode='new';self.state=M.new(self.sec);if self:commit(M.copy(self.state),false) then self:go({kind='deck'}) else self.ctx.state=original;self.state=previous;self.mode='recovery' end
 end)
 elseif action=='accept' then local fn=p.accept;self:pop();fn()
 elseif action=='ok' then self:pop()
 elseif action=='test_alert' then if W.count_enabled(self) then Signal.start(self,self.state.set.pat,true,true) end
 elseif action=='preview_pattern' then self:preview_pattern(arg)
 else return false end
 return true
end
function A:diagnose()
 self.diagnostics={'Timer Deck '..require('lib.gen.version'),'API '..self.ctx.api.major..'.'..self.ctx.api.minor,'Model '..tostring(self.ctx.device.model),'Firmware '..tostring(self.ctx.device.firmware),'Heap '..self.ctx.gc:count()..' bytes','State '..#assert(self.ctx.json:encode(self.state))..' bytes','Pending timers '..((self.pulse and 1 or 0)+(self.signal_timer and 1 or 0)+(self.backup_timer and 1 or 0)+(self.arm_timer and 1 or 0)),'Draw us '..self.ctx.perf:info().draw_us,'Longest input ms '..(self.longest_input_ms or 0),'Front light '..tostring(self.ctx.frontlight~=nil),'Partial frames '..self.partials,'Lock timer '..tostring(self.ctx.device.lock_timer),'Keep awake '..tostring(self.ctx.device.keep_awake~=nil),'Last error '..(self.fatal or 'none')}
 for k,v in pairs(self.ctx.capabilities) do self.diagnostics[#self.diagnostics+1]=k..': '..tostring(v) end
end
function A:input(ctx,ev)
 local ok,result=self:callback(function() return self:input_event(ctx,ev) end);return ok and result or false
end
function A:input_event(ctx,ev)
 if ev.type=='pointer' and ev.phase=='move' then return true end
 if ev.type=='key' and ev.phase~='up' then return false end
 local began=ctx.clock:millis()
 if ev.type=='pointer' and not self.signal and (ev.phase=='down' or ev.phase=='cancel') then self.ms=began;N.input(self,ev);return true end
 self:sample()
 if self.swallow then if ev.phase=='up' or ev.phase=='cancel' then self.swallow=nil end;return true end
 if self.signal then self.swallow=ev.phase=='down' or ev.phase=='hold';local preview=self.signal.preview;Signal.stop(self,true);if preview then self:invalidate(true);return true end;self:event({action='SILENCE',targets=self.queue});local r=self.state.ch.run;if r.st==3 or r.st==1 and r.cue==1 then self:command('CH_SILENCE',nil,{gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round}) end;self:invalidate(true);return true end
 self:event()
 if self.fatal then return false end
 local h=N.input(self,ev);if h=='consumed' then return true elseif h=='redraw' then self:invalidate();return true elseif not h then return false end
 if self.armed and h.action~='delete' and h.action~='ch_delete_inline' then self:disarm();self:invalidate();return true end
 local handled=self:action(h);self:plan();self:invalidate();self.longest_input_ms=math.max(self.longest_input_ms or 0,(ctx.clock:millis()-began)&0x7fffffff);return handled
end
function A:draw(ctx,g)
 self.ink,self.paper=Theme.colors(self.flash)
 self.hits={};g:clear(self.paper);local kind=self.page.kind
 if self.fatal then A.draw_fatal(ctx,g,self.fatal);return end
 if kind=='deck' then Deck.draw(self,g) elseif kind=='detail' then Detail.draw(self,g) elseif kind=='keypad' then Keypad.draw(self,g)
 elseif kind=='form' then require('lib.ui.forms').draw(self,g)
 elseif kind=='icons' or kind=='picker' then require('lib.ui.pickers').draw(self,g)
 elseif kind=='menu' or kind=='settings' then require('lib.ui.menus').draw(self,g)
 elseif kind=='help' or kind=='info' then require('lib.ui.info').draw(self,g)
 elseif kind=='sync' then require('lib.ui.sync').draw(self,g)
 elseif kind=='completion' then Completion.draw(self,g)
 elseif kind:sub(1,6)=='chain_' or kind=='chains' then require('lib.ui.chains').draw(self,g)
 elseif kind=='coverage' then
  W.top(self,g,S.title,true);g:text_box(20,140,440,300,S.coverage_text..(self.state.set.awake==1 and self.coverage_warning and S.coverage_later or ''),{font=self.fonts[26],color=self.ink})
  if ctx.device.keep_awake and self.state.set.awake==0 then W.button(self,g,16,480,448,88,S.enable_awake,'enable_awake') end
  if ctx.lockscreen and not self.lock_default then W.button(self,g,16,590,448,88,S.use_lock,'lockscreen') end
 elseif kind=='blocked' or kind=='recovery' then
  W.text(self,g,240,80,S.title,32,'center');g:text_box(20,200,440,280,kind=='blocked' and S.blocked or S.recovery,{font=self.fonts[32],color=self.ink})
  if kind=='blocked' then W.button(self,g,16,696,448,88,S.help,'help') else W.button(self,g,16,580,448,96,S.retry,'retry_load');W.button(self,g,16,696,448,88,S.fresh,'fresh') end
 else
  W.top(self,g,S.title,true)
  g:text_box(20,140,440,420,(self.page.text or '')..(self.page.options and self.page.options.message and '\n'..self.page.options.message or ''),{font=self.fonts[26],color=self.ink})
  if kind=='confirm' then W.button(self,g,0,712,240,88,self.page.options and self.page.options.ok_text or S.ok,'accept');W.button(self,g,240,712,240,88,self.page.options and self.page.options.cancel_text or S.keep,'back') else W.button(self,g,16,696,448,88,S.back,'ok') end
 end
 if self.focus and self.hits[self.focus] and kind~='deck' then local h=self.hits[self.focus];g:rect(h.x+2,h.y+2,h.w-4,h.h-4,{color=self.ink,line_width=4}) end
end
function A:pause(ctx) self.paused=true;if self.pulse then self.pulse:cancel();self.pulse=nil end;Signal.stop(self) end
function A:resume(ctx) self.paused=false;self:sample();self:event();self:invalidate() end
function A:leave(ctx)
 self.alive=false;if self.backup_timer then self.backup_timer:cancel();self.backup_timer=nil end;if self.pulse then self.pulse:cancel() end;if self.arm_timer then self.arm_timer:cancel() end
 self:sample();if self.mode~='blocked' and self.mode~='recovery' then if M.reconcile(self.state,self.sec) then self.backup_pending=true end;ctx.state=self.state;self:flush_backup() end;self:pause(ctx)
end
function A.draw_fatal(ctx,g,code)
 g:clear(0);g:rect(2,2,116,76,{line_width=2});g:text(60,28,S.back,{font=ctx.fonts.medium,align='center'});g:text(240,260,S.fatal,{font=ctx.fonts.large,align='center'});g:text(240,310,code or 'E-UNKNOWN',{font=ctx.fonts.medium,align='center'})
 g:rect(16,500,448,96,{line_width=2});g:text(240,535,S.retry,{font=ctx.fonts.large,align='center'})
end
return A
