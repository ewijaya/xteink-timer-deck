local M=require('lib.core.model');local C=require('lib.core.const');local F=require('lib.core.format');local P=require('lib.core.pulse')
local S=require('lib.ui.strings');local Clock=require('lib.platform.clock');local Store=require('lib.platform.store');local N=require('lib.ui.nav');local W=require('lib.ui.widgets');local Theme=require('lib.ui.theme')
local Deck=require('lib.ui.deck');local Detail=require('lib.ui.detail');local Keypad=require('lib.ui.keypad');local Completion=require('lib.ui.completion')
local Alerts=require('lib.core.alerts');local Signal=require('lib.platform.signal')
local A={};A.__index=A
local function same(a,b) if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end;for k,v in pairs(a) do if not same(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true end
function A.new(ctx)
 local self=setmetatable({ctx=ctx,features={lock=false,sync=false},page={kind='deck'},stack={},hits={},keys={},fonts={},shown={},partials=0,queue={},queue_pos=1,alive=true},A)
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
function A:push(page)
 self.stack[#self.stack+1]=self.page;self.page=page;self.focus=nil;self.peek=nil;self.changed_at=self.ms;self:invalidate(self.partials>=12)
end
function A:pop()
 self.page=table.remove(self.stack) or {kind='deck'};self.focus=nil;self.peek=nil;self.changed_at=self.ms;self:invalidate(self.partials>=12)
end
function A:message(text)
 self:push({kind='message',text=text})
end
function A:callback(fn,...)
 local ok,result=pcall(fn,...)
 if not ok then self.fatal='E-CALLBACK';self.ctx.log:error(self.fatal);self:pause(self.ctx);self:invalidate(true) end
 return ok,result
end
function A:confirm(text,fn)
 if self.ctx.dialog then self.ctx.dialog:confirm({title=text},function(ctx,yes) self:callback(function() self:sample();self:event();if yes then fn() end;self:plan() end) end)
 else self:push({kind='confirm',text=text,accept=fn}) end
end
function A:commit(candidate,time_driven)
 local previous=self.state
 local ok=Store.commit(self.ctx,candidate,previous)
 if ok then self.state=candidate;self.ctx.state=candidate;self.warning=nil;self.last_save=self.sec or self.last_save;if self.backup and not self.checkpoint then self:backup() end;return true end
 if time_driven then self.state=candidate;self.ctx.state=candidate;self.warning=S.not_saved;self.unsaved=true
 else self:message(S.save_error) end
 return false
end
function A:event(command,initial)
 if self.mode=='blocked' or self.mode=='recovery' then return false end
 local working=M.copy(self.state);local changed,rollback=M.reconcile(working,self.sec)
 if changed or self.unsaved then
  if self:commit(working,true) then self.unsaved=false end
 else self.state=working;self.ctx.state=working end
 if rollback then self.warning=S.rollback end
 local success=true
 if command then
  local candidate,result=M.command(self.state,command,self.sec)
  if result~='OK' then success=false;self:message(S[result] or S.INVALID)
  elseif not same(candidate,self.state) then success=self:commit(candidate,false) end
 elseif initial or M.checkpoint_due(self.state,self.sec,self.last_save) then local checkpoint=not initial;self.checkpoint=checkpoint;self:commit(M.copy(self.state),true);self.checkpoint=false end
 self:completion();self:effects();self:plan();return success
end
function A:completion()
 local q=M.completions(self.state,true);local unseen=false
 for _,r in ipairs(q) do local i=M.find(self.state,r.id);if i.sil==0 and not self.shown[r.id..':'..r.gen] then unseen=true;self.shown[r.id..':'..r.gen]=true end end
 self.queue=q
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
 local candidate,result=M.command(self.state,{action='ATTEMPT',id=target.id,gen=target.gen},self.sec)
 if result=='OK' then
  if self:commit(candidate,true) then self.last_attempt=self.ms;Signal.start(self,target.pat) end
 end
end
function A:preview_pattern(pattern) Signal.start(self,pattern,true) end
function A:coverage(i)
 return S.coverage[Alerts.coverage(self.state,i,self.sec,self.ctx.device.keep_awake~=nil,self.lock_default and self.ctx.device.lock_timer)]
end
function A:plan()
 if self.pulse then self.pulse:cancel();self.pulse=nil end
 if not self.alive or self.mode=='blocked' or self.mode=='recovery' then return end
 local extra=self.unsaved and 1000 or nil
 if not self.unsaved and Alerts.choose(self.state,self.sec) then local elapsed=(self.ms-(self.last_attempt or self.started_ms))&0x7fffffff;extra=math.max(self.signal and 100 or 1,(self.last_attempt and 2000 or 1000)-elapsed) end
 local delay=P.plan(self.state,self.sec,self.page.kind,self.last_save,extra,self.page.id)
 self.coverage_warning=nil
 for _,i in ipairs(self.state.items) do if i.type==0 and i.st==1 and self:coverage(i)==S.coverage[1] then self.coverage_warning=S.open_strip end end
 if self.ctx.device.keep_awake then
  if Alerts.hold(self.state,self.sec) then self.ctx.device:keep_awake(math.min(14400000,((delay or 3600000)//1000+120)*1000));self.held=true
  elseif self.held then self.ctx.device:keep_awake(0);self.held=false end
 end
 if delay then self.pulse=self.ctx:after(delay,function(ctx) self:callback(function()
  self.pulse=nil;self:sample();self.peek=nil;self:event();self.tick_frames=(self.tick_frames or 0)+1
  self.ctx:defer_full_refresh(5000);self:invalidate(self.tick_frames%120==0)
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
 if self.page.kind=='form' then return self.page end
 for n=#self.stack,1,-1 do if self.stack[n].kind=='form' then return self.stack[n] end end
end
function A:pick_field(key,value)
 local form=self:form_page();if not form then return end
 if form.live then
  if self:command(key=='name' and 'RENAME' or 'ICON',form,{[key]=value}) then form.draft[key]=value end
 else form.draft[key]=value end
end
function A:help()
 self.help_pages={};local text=S.help_text
 while #text>0 do local _,_,used=self.fonts[26]:layout(text,440,590);assert(used and used>0);self.help_pages[#self.help_pages+1]=text:sub(1,used);text=text:sub(used+1) end
 self:push({kind='help'})
end
function A:action(h)
 local action,arg=h.action,h.arg;local p=self.page
 if action=='back' then
  if p.kind=='deck' then
   local running=false;for _,i in ipairs(self.state.items) do if i.st==1 then running=true end end
   if running and not (self.lock_default and self.ctx.device.lock_timer) and self.ctx.dialog then
    self.ctx.dialog:confirm({title=S.leave_title,message=S.leave_text,ok_text=S.leave,cancel_text=S.stay},function(ctx,yes) self:callback(function() if yes then ctx:quit() end end) end);return true
   end
   return false
  end
  if p.kind=='completion' then return self:action({action='clear_all'}) end
  if p.kind=='picker' and p.preview then self.preview_setting=nil end
  if p.kind=='form' and not p.live and not same(p.draft,p.original) or p.kind=='keypad' and p.digits and p.digits~='' then self:confirm(S.discard,function() self:pop() end) else self:pop() end
 elseif action=='new_timer' then if #self.state.items>=C.CAPACITY then self:message(S.FULL) else self:push({kind='keypad'}) end
 elseif action=='digit' then if p.replace and arg~='back' then p.digits=nil end;p.replace=false;p.digits=F.keypad(p.digits,arg)
 elseif action=='days' then p.days=math.max(0,math.min(999,(p.days or 0)+arg))
 elseif action=='create' or action=='more' then
  local dur=F.keypad_seconds(p.digits);if dur<1 then self:message(S.zero);return true end
  if action=='more' then self:push({kind='form',draft={type=0,name='',icon=0,dur=dur,pat=self.state.set.pat,cnt=self.state.set.cnt,st=0},original={}})
  elseif self:command(arg and 'CREATE_START' or 'CREATE',nil,{type=0,dur=dur}) then self.stack={};self.page=arg and {kind='detail',id=self.state.sel} or {kind='deck'};self.changed_at=self.ms end
 elseif action=='new_watch' then self:open_form()
 elseif action=='detail' then if self:command('SELECT',h) then self:push({kind='detail',id=h.id}) end
 elseif action=='primary' then
  local i=M.find(self.state,h.id)
  if i and i.st==3 and p.kind=='deck' then self:push({kind='completion'}) else self:command('PRIMARY',h) end
 elseif action=='reset' then self:command('RESET',h)
 elseif action=='delete' then if self:command('DELETE',h) then self.page={kind='deck'};self.stack={};self.delete_arm=nil end
 elseif action=='arm_delete' then self.delete_arm={id=h.id,gen=h.gen};if self.settle then self.settle:cancel() end;self.settle=self.ctx:after(5000,function() self:callback(function() self.settle=nil;self.delete_arm=nil;self:invalidate() end) end)
 elseif action=='keep' then self.delete_arm=nil
 elseif action=='actions' then local i=M.find(self.state,p.id);if i then self:push({kind='actions',id=i.id,gen=i.gen}) end
 elseif action=='edit' then local i=M.find(self.state,p.id);if i then self:open_form(i) end
 elseif action=='edit_time' then self:push({kind='keypad',edit=true,replace=true,days=p.draft.dur//86400,digits=string.format('%02d%02d%02d',p.draft.dur//3600%24,p.draft.dur//60%60,p.draft.dur%60)})
 elseif action=='time_done' then local v=(p.days or 0)*86400+F.keypad_seconds(p.digits);if v<1 or v>C.MAX_SEC then self:message(S.INVALID) else self:pick_field('dur',v);self:pop() end
 elseif action=='name' then
  local form=self:form_page();self.ctx.input:text({title=form.draft.type==0 and S.timer_name or S.watch_name,text=form.draft.name,max_bytes=16},function(ctx,value)
   self:callback(function() self:sample();self:event();if value~=nil then local normalized=F.name(value);if normalized then self:pick_field('name',normalized) else self:message(S.name_rule) end end;self:invalidate() end)
  end)
 elseif action=='icons' then self:push({kind='icons',title=S.icon,key='icon',value=p.draft.icon})
 elseif action=='pattern' or action=='count' then self:push({kind='picker',title=action=='pattern' and S.alert or S.count,key=action=='pattern' and 'pat' or 'cnt',value=action=='pattern' and p.draft.pat or p.draft.cnt-1,options=action=='pattern' and C.PATTERNS or {'1','2','3','4','5'}})
 elseif action=='save_form' then
  local d=p.draft;local fields=p.id and {values=p.live and {name=d.name,icon=d.icon} or d.type==0 and {name=d.name,icon=d.icon,pat=d.pat,cnt=d.cnt,dur=d.st==0 and d.dur or nil} or {name=d.name,icon=d.icon}} or d
  if self:command(p.id and 'EDIT' or arg and 'CREATE_START' or 'CREATE',p,fields) then self.stack={};self.page=p.id or arg and {kind='detail',id=p.id or self.state.sel} or {kind='deck'};if type(self.page)~='table' then self.page={kind='detail',id=p.id} end;self.changed_at=self.ms end
 elseif action=='pick' then
  if p.preview then p.value=arg;self.preview_setting={key=p.key,value=arg}
  elseif p.setting then if self:command('SETTINGS',nil,{values={[p.key]=p.key=='cnt' and arg+1 or arg}}) then self:pop() end
  else self:pick_field(p.key,p.key=='cnt' and arg+1 or arg);self:pop() end
 elseif action=='coverage' then self:push({kind='coverage'})
 elseif action=='enable_awake' then self:command('SETTINGS',nil,{values={awake=1}});self:pop()
 elseif action=='lockscreen' then if self.ctx.lockscreen then if self.lock_default then self.ctx.lockscreen:clear_default() else self.ctx.lockscreen:set_default() end;self:sample() end
 elseif action=='use' then if self:command('SETTINGS',nil,{values={[p.key]=p.value}}) then self.preview_setting=nil;self:pop();self:invalidate(true) end
 elseif action=='menu' or action=='settings' then self:push({kind=action})
 elseif action=='setting' then
  local options={app=S.appearances,style=S.styles,secs=S.seconds_modes,pat=C.PATTERNS,cnt={'1','2','3','4','5'}}
  if not options[arg] then self:command('SETTINGS',nil,{values={[arg]=1-self.state.set[arg]}})
  else self:push({kind='picker',title=S[arg] or S.settings,key=arg,value=self.state.set[arg]-(arg=='cnt' and 1 or 0),options=options[arg],setting=true,preview=arg=='app' or arg=='style'}) end
 elseif action=='help' then self:help()
 elseif action=='about_tap' then self.taps=(self.taps or 0)+1;if self.taps>=7 then self.taps=0;self:diagnose();self:push({kind='info'}) end
 elseif action=='page' then p.offset=((p.offset or 0)+arg)%math.max(1,self.page_count or 1);self.focus=nil
 elseif action=='next_item' then local _,n=M.find(self.state,p.id);if n and #self.state.items>0 then p.id=self.state.items[(n-1+arg)%#self.state.items+1].id;self.peek=nil end
 elseif action=='peek' then local i=M.find(self.state,p.id);if i and self.sec then local d,t=F.detail(M.value(i,self.sec),i.type==0,false);self.peek={days=d,time=t,at=F.clock(self.now)} end
 elseif action=='browse' then if #self.queue>0 then self.queue_pos=((self.queue_pos-1+arg)%#self.queue)+1 end
 elseif action=='dismiss' or action=='clear_all' then self:command('DISMISS',nil,{targets=action=='dismiss' and {{id=h.id,gen=h.gen}} or self.queue})
 elseif action=='erase' then self:confirm(S.erase_text,function() if self:command('ERASE') then
   if self.backup_timer then self.backup_timer:cancel();self.backup_timer=nil end;self.backup_pending=false
   local ok=self.ctx.storage:remove('deck.bak');if not ok then self.ctx.log:error('E-BACKUP') end
   self.page={kind='deck'};self.stack={};if self.ctx.device.keep_awake then self.ctx.device:keep_awake(0) end
  end end)
 elseif action=='retry_load' then
  local state,status=Store.load(self.ctx,self.sec);if state then self.state=state;self.ctx.state=state;self.mode=status;self.page={kind='deck'};self.stack={};self:event(nil,status~='ok') end
 elseif action=='fresh' then self:confirm(S.erase_text,function()
  self.mode='new';self.state=M.new(self.sec);if self:commit(M.copy(self.state),false) then self.page={kind='deck'};self.stack={} else self.mode='recovery' end
 end)
 elseif action=='accept' then local fn=p.accept;self:pop();fn()
 elseif action=='ok' then self:pop()
 elseif action=='chains' then self:message(S.no_chains)
 elseif action=='preview_pattern' then if self.preview_pattern then self:preview_pattern(arg) end
 else return false end
 return true
end
function A:diagnose()
 self.diagnostics={'API '..self.ctx.api.major..'.'..self.ctx.api.minor,'Model '..tostring(self.ctx.device.model),'Firmware '..tostring(self.ctx.device.firmware),'Heap '..self.ctx.gc:count()..' bytes','State '..#assert(self.ctx.json:encode(self.state))..' bytes','Partial frames '..self.partials,'Lock timer '..tostring(self.ctx.device.lock_timer),'Keep awake '..tostring(self.ctx.device.keep_awake~=nil),'Last error '..(self.fatal or 'none')}
 for k,v in pairs(self.ctx.capabilities) do self.diagnostics[#self.diagnostics+1]=k..': '..tostring(v) end
end
function A:input(ctx,ev)
 self:sample()
 if self.swallow then if ev.phase=='up' or ev.phase=='cancel' then self.swallow=nil end;return true end
 if self.signal then self.swallow=ev.phase=='down' or ev.phase=='hold';Signal.stop(self);self:event({action='SILENCE',targets=self.queue});self:invalidate(true);return true end
 self:event()
 if self.fatal then return false end
 local h=N.input(self,ev);if h=='consumed' then return true elseif h=='redraw' then self:invalidate();return true elseif not h then return false end
 local handled=self:action(h);self:plan();self:invalidate();return handled
end
function A:draw(ctx,g)
 local appearance=self.preview_setting and self.preview_setting.key=='app' and self.preview_setting.value or self.state.set.app
 self.ink,self.paper=Theme.colors(appearance,ctx.device:display().dark,self.flash)
 self.hits={};g:clear(self.paper);local kind=self.page.kind
 if self.fatal then A.draw_fatal(ctx,g,self.fatal);return end
 if kind=='deck' then Deck.draw(self,g) elseif kind=='detail' then Detail.draw(self,g) elseif kind=='keypad' then Keypad.draw(self,g)
 elseif kind=='form' then require('lib.ui.forms').draw(self,g)
 elseif kind=='icons' or kind=='picker' then require('lib.ui.pickers').draw(self,g)
 elseif kind=='menu' or kind=='settings' or kind=='actions' then require('lib.ui.menus').draw(self,g)
 elseif kind=='help' or kind=='info' then require('lib.ui.info').draw(self,g)
 elseif kind=='completion' then Completion.draw(self,g)
 elseif kind=='coverage' then
  W.top(self,g,S.title,true);g:text_box(20,140,440,300,S.leave_text,{font=self.fonts[26],color=self.ink})
  if ctx.device.keep_awake then W.button(self,g,16,480,448,88,S.enable_awake,'enable_awake') end
  if ctx.lockscreen then W.button(self,g,16,590,448,88,S.use_lock,'lockscreen') end
 elseif kind=='blocked' or kind=='recovery' then
  W.text(self,g,240,80,S.title,32,'center');g:text_box(20,200,440,280,kind=='blocked' and S.blocked or S.recovery,{font=self.fonts[32],color=self.ink})
  if kind=='blocked' then W.button(self,g,16,696,448,88,S.help,'help') else W.button(self,g,16,580,448,96,S.retry,'retry_load');W.button(self,g,16,696,448,88,S.fresh,'fresh') end
 else
  W.top(self,g,kind=='blocked' and S.blocked or kind=='recovery' and S.recovery or S.title,kind~='blocked' and kind~='recovery')
  g:text_box(20,140,440,420,self.page.text or '',{font=self.fonts[26],color=self.ink})
  W.button(self,g,16,696,448,88,kind=='confirm' and S.ok or S.back,kind=='confirm' and 'accept' or 'ok')
 end
 if self.focus and self.hits[self.focus] and kind~='deck' then local h=self.hits[self.focus];g:rect(h.x+2,h.y+2,h.w-4,h.h-4,{color=self.ink,line_width=4}) end
end
function A:pause(ctx) self.paused=true;Signal.stop(self) end
function A:resume(ctx) self.paused=false;self:sample();self:event();self:invalidate() end
function A:leave(ctx)
 self.alive=false;if self.backup_timer then self.backup_timer:cancel();self.backup_timer=nil end;if self.pulse then self.pulse:cancel() end;if self.settle then self.settle:cancel() end
 self:sample();if self.mode~='blocked' and self.mode~='recovery' then M.reconcile(self.state,self.sec);ctx.state=self.state;self:flush_backup() end;self:pause(ctx)
end
function A.draw_fatal(ctx,g,code)
 g:clear(0);g:text(240,260,S.fatal,{font=ctx.fonts.large,align='center'});g:text(240,310,code or 'E-UNKNOWN',{font=ctx.fonts.medium,align='center'})
 g:rect(16,500,448,96,{line_width=2});g:text(240,535,S.retry,{font=ctx.fonts.large,align='center'})
end
return A
