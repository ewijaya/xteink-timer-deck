local C=require('lib.core.const')
local N={}
function N.hit(a,x,y,w,h,action,arg,id,gen)
 local hit={x=x,y=y,w=w,h=h,action=action,arg=arg,id=id,gen=gen};a.hits[#a.hits+1]=hit;return hit
end
function N.input(a,ev)
 local ms=a.ms
 if ev.type=='key' then
  if ev.phase~='up' then return nil end
  local last=a.keys[ev.key];if last and ((ms-last)&0x7fffffff)<C.KEY_DEBOUNCE_MS then return 'consumed' end;a.keys[ev.key]=ms
  if ev.key=='back' then return {action='back'} end
  if ev.key=='down' then
   if a.page.kind=='deck' and a.deck_entries then
    local _,selected=require('lib.core.model').find(a.state,a.state.sel)
    a.focus=a.focus and a.focus%(#a.deck_entries+3)+1 or (selected and selected+(a.chain_entry and 1 or 0)) or 1
    if a.focus<=#a.deck_entries then a.page.offset=(a.focus-1)//a.deck_per end
   elseif a.page.kind=='chain_run' then return {action='ch_steps'}
   elseif a.page.kind=='detail' then return {action='next_item',arg=1}
   elseif a.page.kind=='completion' then return {action='browse',arg=1}
   else if not a.focus then for n,h in ipairs(a.hits) do if h.y>=80 then a.focus=n-1;break end end end;if a.focus==#a.hits and (a.page_count or 1)>1 then a.page.offset=((a.page.offset or 0)+1)%a.page_count end;a.focus=(a.focus or 0)%math.max(1,#a.hits)+1 end
   return 'redraw'
  end
  if ev.key=='up' then
   if a.page.kind=='deck' and a.focus and a.deck_entries and a.focus>#a.deck_entries then return {action=({'new_timer','chains','menu'})[a.focus-#a.deck_entries]} end
   if a.page.kind=='deck' and a.focus and a.deck_entries[a.focus] then local i=a.deck_entries[a.focus];local r=a.state.ch.run;return {action=i.chain and 'ch_primary' or 'primary',id=i.id,gen=i.gen,arg=i.chain and {gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round} or nil} end
   if a.page.kind=='chain_run' then return {action='ch_primary',arg=a.page.token} end
   if a.page.kind=='completion' then local t=a.queue[a.queue_pos];if t then return {action='dismiss',id=t.id,gen=t.gen} end end
   if a.page.kind=='detail' then local i=require('lib.core.model').find(a.state,a.page.id);if i then return {action='primary',id=i.id,gen=i.gen} end end
   return a.hits[a.focus or 1]
  end
 elseif ev.type=='pointer' then
  a.focus=nil
  if ev.phase=='down' then a.ignore=((ms-a.changed_at)&0x7fffffff)<C.SETTLE_MS;return 'consumed' end
  if ev.phase=='cancel' then a.ignore=false;return 'consumed' end
  if a.ignore then if ev.phase=='up' then a.ignore=false end;return 'consumed' end
  if ev.phase=='hold' or ev.phase=='up' then
   if ev.phase=='up' and ev.gesture=='long' then return 'consumed' end
   if a.page.kind=='detail' and (ev.gesture=='swipe_left' or ev.gesture=='swipe_right') then return {action='next_item',arg=ev.gesture=='swipe_left' and 1 or -1} end
   if ev.gesture=='swipe_up' or ev.gesture=='swipe_down' then return {action='page',arg=ev.gesture=='swipe_up' and 1 or -1} end
   for _,h in ipairs(a.hits) do
    if ev.x>=h.x and ev.x<h.x+h.w and ev.y>=h.y and ev.y<h.y+h.h then
     if h.action=='chain_run' and a.page.kind=='deck' and ev.gesture=='swipe_left' then return {action='ch_arm',arg=h.id} end
     if h.action=='ch_overview' and ev.gesture=='swipe_left' then return {action='ch_arm',arg=h.arg} end
     if h.id and a.page.kind=='deck' and h.action~='chain_run' and h.action~='ch_primary' then
      if ev.phase=='hold' then return {action='primary',id=h.id,gen=h.gen} end
      if ev.gesture=='swipe_left' then return {action='arm_delete',id=h.id,gen=h.gen} end
     end
     if ev.gesture=='tap' or ev.gesture=='double_tap' or ev.phase=='hold' then return h end
    end
   end
  end
 end
end
return N
