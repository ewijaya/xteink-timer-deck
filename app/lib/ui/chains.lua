local M=require('lib.core.model');local H=require('lib.core.chains');local F=require('lib.core.format');local C=require('lib.core.const');local P=require('lib.core.pulse')
local W=require('lib.ui.widgets');local S=require('lib.ui.strings');local Draw=require('lib.ui.draw');local Digits=require('lib.ui.digits')
local U={}
local function token(r) return {gen=r.gen,step=r.snap and r.snap.steps[r.idx].id,round=r.round} end
local function definition(a) return H.find(a.state,a.page.id) end
local function editor(a)
 if a.page.kind=='chain_edit' then return a.page end
 for n=#a.stack,1,-1 do if a.stack[n].kind=='chain_edit' then return a.stack[n] end end
end
local function open(a,d,id,rev)
 a:push({kind='chain_edit',draft=M.copy(d),original=M.copy(d),id=id,rev=rev,chain_draft=true})
end
local function step(a,idx)
 local e=editor(a);local d=e.draft;local v=idx and d.steps[idx] or {id=d.next_step,name='',icon=0,sec=#d.steps>0 and d.steps[#d.steps].sec or C.DEFAULT_COUNTDOWN,pat=a.state.set.pat}
 a:push({kind='chain_step',draft=M.copy(v),original=M.copy(v),index=idx,chain_draft=true})
end
function U.action(a,h)
 local action,arg=h.action,h.arg;local p=a.page;local r=a.state.ch.run
 if action=='chains' then a:push({kind='chains'})
 elseif action=='chain_run' then if r.st~=0 then a:push({kind=r.st>=3 and 'chain_result' or 'chain_run',token=token(r)}) end
 elseif action=='ch_arm' then a:arm('chain',arg,r.gen)
 elseif action=='ch_keep' then a:disarm()
 elseif action=='ch_delete_inline' then local def=H.find(a.state,arg);if def and a:command('CH_DELETE',nil,{id=def.id,rev=def.rev}) then a:disarm() end
 elseif action=='ch_new' then if #a.state.ch.saved>=C.CHAIN_CAPACITY then a:toast(S.CHAIN_FULL) else a:push({kind='chain_new'}) end
 elseif action=='ch_template' then open(a,H.template(arg,a.state.set.pat))
 elseif action=='ch_from_new' then open(a,H.template('',a.state.set.pat));a:push({kind='chain_from',selected={}})
 elseif action=='ch_overview' then a:push({kind='chain_overview',id=arg})
 elseif action=='ch_edit' then
  local d=definition(a);if d then if r.id==d.id and (r.st==1 or r.st==2) then a:toast(S.ACTIVE) else open(a,d,d.id,d.rev) end end
 elseif action=='ch_save' then
  if #p.draft.steps<2 then a:toast(S.chain_min)
  elseif a:command('CH_SAVE',nil,{id=p.id,rev=p.rev,definition=p.draft}) then local id=p.id or a.state.ch.last;a:go({kind='chain_overview',id=id}) end
 elseif action=='ch_rounds' then p.draft.rounds=math.max(1,math.min(C.CHAIN_ROUNDS,p.draft.rounds+(arg or 1)))
 elseif action=='ch_add' then if #p.draft.steps>=C.CHAIN_STEPS then a:toast(S.chain_max) else a:push({kind='chain_add'}) end
 elseif action=='ch_new_step' then step(a)
 elseif action=='ch_step' then step(a,arg)
 elseif action=='ch_step_save' then
  local e=editor(a);local d=e.draft;d.steps[p.index or #d.steps+1]=M.copy(p.draft);if not p.index then d.next_step=d.next_step+1 end
  while a.page~=e do a:pop() end
 elseif action=='ch_step_move' then
  local e=editor(a);local idx=p.index;if idx then local to=idx+arg;if to>=1 and to<=#e.draft.steps then e.draft.steps[idx],e.draft.steps[to]=e.draft.steps[to],e.draft.steps[idx];p.index=to end end
 elseif action=='ch_step_remove' then local e=editor(a);if p.index then table.remove(e.draft.steps,p.index) end;while a.page~=e do a:pop() end
 elseif action=='ch_time' then local v=p.draft.sec;a:push({kind='keypad',edit=true,replace=true,days=v//86400,digits=string.format('%02d%02d%02d',v//3600%24,v//60%60,v%60)})
 elseif action=='ch_from' then a:push({kind='chain_from',selected={}})
 elseif action=='ch_select' then
  local found;for n,id in ipairs(p.selected) do if id==arg then found=n end end
  if found then table.remove(p.selected,found) else p.selected[#p.selected+1]=arg end
 elseif action=='ch_add_selected' then
  local e=editor(a);if #p.selected+#e.draft.steps>C.CHAIN_STEPS then a:toast(S.chain_max) else
   for _,id in ipairs(p.selected) do local i=M.find(a.state,id);if i and i.type==0 then local d=e.draft;d.steps[#d.steps+1]={id=d.next_step,name=i.name,icon=i.icon,sec=i.dur,pat=i.pat};d.next_step=d.next_step+1 end end
   while a.page~=e do a:pop() end
  end
 elseif action=='ch_start' then
  local d=H.find(a.state,arg or p.id or r.id)
  if r.st==1 or r.st==2 then a:push({kind='chain_busy'})
  elseif d and a:command('CH_START',nil,{id=d.id,rev=d.rev}) then if p.kind=='chain_result' then a:pop() end;a:push({kind='chain_run',token=token(a.state.ch.run)}) end
 elseif action=='ch_primary' or action=='ch_skip' or action=='ch_restart' or action=='ch_done' then
  local t=type(arg)=='table' and arg or p.token or {gen=h.gen};local commands={ch_primary='CH_PRIMARY',ch_skip='CH_SKIP',ch_restart='CH_RESTART',ch_done='CH_DONE'}
  if a:command(commands[action],nil,t) and action=='ch_done' then a:go({kind='chains'}) end
 elseif action=='ch_stop' then local t=M.copy(p.token or token(r));a:confirm(S.stop_question,function() a:command('CH_STOP',nil,t) end)
 elseif action=='ch_more' then a:push({kind='chain_more',run=p.kind=='chain_run',id=p.id or r.id,token=p.token or token(r)})
 elseif action=='ch_delete' then
  local d=definition(a);if d then local id,rev=d.id,d.rev;a:confirm(r.id==id and (r.st==1 or r.st==2) and S.stop_delete or S.delete..'?',function() if a:command('CH_DELETE',nil,{id=id,rev=rev}) then a:go({kind='chains'}) end end) end
 elseif action=='ch_duplicate' or action=='ch_move' then
  local d=definition(a);if d and a:command(action=='ch_duplicate' and 'CH_DUPLICATE' or 'CH_MOVE',nil,{id=d.id,rev=d.rev,direction=arg}) then a:pop() end
 elseif action=='ch_steps' then a:push({kind='chain_steps',id=p.id,run=p.kind=='chain_run' or p.kind=='chain_more' and r.id==p.id})
 else return false end
 return true
end
function U.draw(a,g)
 local p=a.page;local kind=p.kind;local r=a.state.ch.run;local d=definition(a);local rows={};local bottom
 if (kind=='chain_run' or kind=='chain_result') and r.st==0 then W.top(a,g,S.chains,true);W.rows(a,g,{});return end
 W.top(a,g,kind=='chains' and S.chains or kind=='chain_run' and r.snap.name or kind=='chain_result' and (r.st==4 and S.chain_stopped or S.chain_complete) or kind=='chain_edit' and (p.id and S.edit_chain or S.new_chain) or kind=='chain_step' and S.step or kind=='chain_add' and S.add_step or kind=='chain_from' and S.from_deck or S.chains,true,kind=='chain_run' and 'ch_more' or nil,{glyph='more'})
 if kind=='chains' then
  if r.st~=0 then rows[#rows+1]={label=r.snap.name,value=S.active_chain,action='chain_run'} end
  for _,def in ipairs(a.state.ch.saved) do rows[#rows+1]={label=def.name~='' and def.name or S.new_chain,value=#def.steps..' '..S.steps..' · '..F.duration(H.total(def)),action='ch_overview',arg=def.id,play=true,armed=a.armed and a.armed.kind=='chain' and a.armed.id==def.id} end
  if #rows==0 then W.text(a,g,240,240,S.no_chains,32,'center') end
  bottom={{glyph='plus',text=S.new_chain},'ch_new'}
 elseif kind=='chain_new' then
  rows={{label=S.empty_chain,action='ch_template',arg=''},{label=S.from_deck,action='ch_from_new'}}
  for _,name in ipairs({'Pomodoro','Plank','Tea'}) do rows[#rows+1]={label=name,action='ch_template',arg=name} end
 elseif kind=='chain_overview' and d then
  rows={{label=d.name~='' and d.name or S.new_chain,value=#d.steps..' '..S.steps..' · '..F.duration(H.total(d))..' · '..S.times..d.rounds},{label=S.start,action='ch_start'},{label=S.steps,action='ch_steps'},{label=S.edit,action='ch_edit'},{label=S.more,action='ch_more'}}
 elseif kind=='chain_edit' then
  d=p.draft;rows={{label=S.name,value=d.name,action='name'},{label=S.icon,value=d.icon==0 and S.none or C.ICON_NAMES[d.icon],action='icons'},{label=S.rounds,value=S.times..d.rounds,stepper=true}}
  for n,v in ipairs(d.steps) do rows[#rows+1]={label=n..'. '..F.step_label(v,n),value=F.duration(v.sec),action='ch_step',arg=n} end
  rows[#rows+1]={label=S.add_step,action='ch_add'};bottom={S.save,'ch_save'}
 elseif kind=='chain_step' then
  d=p.draft;rows={{label=S.name,value=d.name,action='name'},{label=S.icon,value=d.icon==0 and S.none or C.ICON_NAMES[d.icon],action='icons'},{label=S.time,value=F.duration(d.sec),action='ch_time'}}
  if W.pattern_enabled(a) then rows[#rows+1]={label=S.alert,value=C.PATTERNS[d.pat+1],action='pattern'} end
  if p.index then rows[#rows+1]={label=S.move_up,action='ch_step_move',arg=-1};rows[#rows+1]={label=S.move_down,action='ch_step_move',arg=1};rows[#rows+1]={label=S.remove,action='ch_step_remove'} end
  bottom={S.done,'ch_step_save'}
 elseif kind=='chain_add' then rows={{label=S.new_timer,action='ch_new_step'},{label=S.from_deck,action='ch_from'}}
 elseif kind=='chain_from' then
  for _,i in ipairs(a.state.items) do if i.type==0 then local mark='';for n,id in ipairs(p.selected) do if id==i.id then mark='['..n..'] ' end end;rows[#rows+1]={label=mark..F.label(i),value=F.duration(i.dur),action='ch_select',arg=i.id} end end
  bottom={S.add,'ch_add_selected'}
 elseif kind=='chain_more' then
  if r.id==p.id and (r.st==1 or r.st==2) then rows={{label=S.skip,action='ch_skip',arg=p.token},{label=S.stop,action='ch_stop'},{label=S.steps,action='ch_steps'}} end
  rows[#rows+1]={label=S.duplicate,action='ch_duplicate'};rows[#rows+1]={label=S.move_up,action='ch_move',arg=-1};rows[#rows+1]={label=S.move_down,action='ch_move',arg=1};rows[#rows+1]={label=S.delete,action='ch_delete'};rows[#rows+1]={label=S.all_chains,action='chains'}
 elseif kind=='chain_steps' then
  d=p.run and r.snap or d;if d then for n,v in ipairs(d.steps) do rows[#rows+1]={label=(p.run and n==r.idx and '> ' or '')..n..'. '..F.step_label(v,n),value=F.duration(v.sec)} end end
 elseif kind=='chain_busy' then rows={{label=S.ACTIVE},{label=S.active_chain,action='chain_run'}}
 elseif kind=='chain_run' and r.st~=0 then
  local step=r.snap.steps[r.idx];local value=H.value(r,a.sec);local days,time=F.detail(value or 0,true,not P.seconds(a.state.set.secs,true,{type=0},value or 0));local t=token(r);p.token=t
  local width=440//#r.snap.steps;for n=1,#r.snap.steps do local x=20+(n-1)*width;g:rect(x,84,width-4,8,{color=a.ink,fill=n<r.idx,line_width=2});if n==r.idx then local half=(width-4)//2;g:polygon({x,84,x+half,84,x+half,92,x,92},{color=a.ink,fill=true}) end end
  Draw.ring(g,value or 0,step.sec,r.st==1 and 'Running' or 'Paused',a.ink)
  W.text(a,g,240,180,string.format(S.step_of,r.idx,#r.snap.steps),26,'center');W.text(a,g,240,218,W.fit(a,F.step_label(step,r.idx),330,26),26,'center')
  local height=#time>5 and 64 or 96;Digits.draw(g,time,(480-Digits.width(time,height))//2,270,height,a.ink)
  W.text(a,g,240,375,P.seconds(a.state.set.secs,true,{type=0},value or 0) and S.sec or S.min,22,'center');if r.snap.rounds>1 then W.text(a,g,240,410,string.format(S.round_of,r.round,r.snap.rounds),22,'center') end;W.text(a,g,240,440,days,22,'center')
  local next_step=r.snap.steps[r.idx%#r.snap.steps+1];W.text(a,g,240,540,W.fit(a,r.idx==#r.snap.steps and r.round==r.snap.rounds and S.last_step or S.next..F.step_label(next_step,r.idx%#r.snap.steps+1)..' '..F.duration(next_step.sec),440,26),26,'center')
  if r.away>0 then W.text(a,g,240,590,r.away..S.elapsed_away,22,'center') elseif a.banner and a.banner.gen==r.gen and a.banner.step==r.idx and a.banner.round==r.round then W.text(a,g,240,590,W.fit(a,a.banner.text,440,22),22,'center') end
  W.button(a,g,16,676,160,112,r.st==1 and S.pause or S.resume,'ch_primary',t,nil,nil,true)
  W.button(a,g,184,676,180,112,S.restart,'ch_restart',t,nil,nil,false,22);W.button(a,g,372,676,92,112,S.skip_short,'ch_skip',t,nil,nil,false,22);return
 elseif kind=='chain_result' and r.st~=0 then
  W.text(a,g,240,200,r.snap.name,40,'center');W.text(a,g,240,300,#r.snap.steps*r.snap.rounds..' '..S.steps,32,'center');W.text(a,g,240,370,r.skipped..S.skipped,26,'center')
  W.button(a,g,16,580,448,88,S.again,'ch_start',r.id);W.button(a,g,16,696,448,88,S.done,'ch_done',token(r));return
 end
 W.rows(a,g,rows,bottom and 5 or 6)
 if bottom then W.button(a,g,16,712,448,88,bottom[1],bottom[2]) end
end
return U
