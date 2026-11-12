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
   if a.page.kind=='deck' and #a.state.items>0 then
    local _,selected=require('lib.core.model').find(a.state,a.state.sel)
    a.focus=a.focus and a.focus%#a.state.items+1 or selected or 1
   elseif a.page.kind=='detail' then return {action='next_item',arg=1}
   elseif a.page.kind=='completion' then return {action='browse',arg=1}
   else a.focus=(a.focus or 0)%math.max(1,#a.hits)+1 end
   return 'redraw'
  end
  if ev.key=='up' then
   if a.page.kind=='deck' and a.focus and a.state.items[a.focus] then local i=a.state.items[a.focus];return {action='primary',id=i.id,gen=i.gen} end
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
     if h.id and a.page.kind=='deck' then
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
