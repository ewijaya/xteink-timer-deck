local C=require('lib.core.const')
local S=require('lib.ui.strings')
local A={};A.__index=A
function A.new(ctx)
 local self=setmetatable({page='deck',hits={},last_keys={}},A)
 self.font=ctx.fonts:size(26);self.title=ctx.fonts:size(32);self.caption=ctx.fonts:size(22)
 self:sample(ctx);ctx:invalidate('full');return self
end
function A:sample(ctx)
 self.now=ctx.clock:now();self.changed_at=ctx.clock:millis()
 self.info={'API '..ctx.api.major..'.'..ctx.api.minor,'Model '..tostring(ctx.device.model),'Firmware '..tostring(ctx.device.firmware),'Heap '..ctx.gc:count()..' bytes'}
 for k,v in pairs(ctx.capabilities) do self.info[#self.info+1]=k..': '..tostring(v) end
 table.sort(self.info)
end
function A:draw(ctx,g)
 ctx.device:display() -- Auto follows the system presentation inversion.
 self.hits={};g:clear(0)
 local function label(x,y,s,font) g:text(x,y,s,{font=font or self.font}) end
 local function button(y,s,action)
  g:rect(16,y,448,88,{line_width=2,radius=8});g:text(240,y+44,s,{font=self.font,align='center',valign='middle'})
  self.hits[#self.hits+1]={x=16,y=y,w=448,h=88,action=action}
 end
 if self.page=='deck' then
  label(20,24,S.title,self.title);g:line(0,80,479,80,{line_width=2})
  g:circle(240,210,70,{line_width=6});g:line(240,210,240,165,{line_width=5});g:line(240,210,275,225,{line_width=5})
  g:text(240,320,S.empty,{font=self.title,align='center'})
  g:text_box(28,382,424,190,S.notice,{font=self.font})
  g:text(240,600,S.foundation,{font=self.caption,align='center'})
  g:text(240,636,S.pending,{font=self.caption,align='center'})
  button(696,S.info,'info')
 else
  label(20,20,S.info,self.title)
  for i,line in ipairs(self.info) do label(20,76+(i-1)*36,line,self.caption) end
  button(696,S.back,'deck')
 end
end
function A:input(ctx,ev)
 local action
 if ev.type=='key' then
  if ev.phase~='up' then return false end
  local ms=ctx.clock:millis();local previous=self.last_keys[ev.key]
  if previous and ((ms-previous)&0x7fffffff)<C.KEY_DEBOUNCE_MS then return true end
  self.last_keys[ev.key]=ms
  if ev.key=='back' then if self.page=='deck' then return false end;action='deck'
  elseif ev.key=='up' then action=self.page=='deck' and 'info' or 'deck' end
 elseif ev.type=='pointer' then
  if ev.phase=='down' then self.ignore=((ctx.clock:millis()-self.changed_at)&0x7fffffff)<C.SETTLE_MS;return true end
  if ev.phase=='cancel' then self.ignore=false;return true end
  if ev.phase=='up' then
   if self.ignore then self.ignore=false;return true end
   if ev.gesture=='tap' or ev.gesture=='double_tap' then
    for _,h in ipairs(self.hits) do if ev.x>=h.x and ev.x<h.x+h.w and ev.y>=h.y and ev.y<h.y+h.h then action=h.action;break end end
   end
  end
 end
 if action then self.page=action;self:sample(ctx);ctx:invalidate();return true end
 return false
end
function A:pause(ctx) if ctx.frontlight then ctx.frontlight:reset() end end
function A:resume(ctx) self:sample(ctx);ctx:invalidate() end
function A:leave(ctx) self:pause(ctx) end
function A.draw_fatal(ctx,g,code)
 g:clear(0);g:text(240,260,S.fatal,{font=ctx.fonts.large,align='center'})
 g:text(240,310,code or 'E-UNKNOWN',{font=ctx.fonts.medium,align='center'})
 g:rect(16,500,448,96,{line_width=2});g:text(240,535,S.retry,{font=ctx.fonts.large,align='center'})
end
return A
