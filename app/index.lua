local App,app,fatal
local function fail(ctx,code)
 if fatal~=code then ctx.log:error(code) end
 fatal=code;if ctx.frontlight then ctx.frontlight:reset() end
 ctx:invalidate('full')
end
local function guard(ctx,code,fn,...)
 local ok,result=pcall(fn,...);if not ok then fail(ctx,code) end;return ok,result
end
function on_load(ctx)
 guard(ctx,'E-LOAD',function() App=require('lib.app');app=App.new(ctx);fatal=nil end)
end
function on_draw(ctx,g)
 local ok=pcall(function()
  if app and not fatal then app:draw(ctx,g)
  elseif App then App.draw_fatal(ctx,g,fatal)
  else g:clear(0);g:text(20,260,'Something went wrong - Try again',{font=ctx.fonts.large}) end
 end)
 if not ok then
  fatal='E-DRAW';pcall(function() ctx.log:error(fatal);if ctx.frontlight then ctx.frontlight:reset() end;App.draw_fatal(ctx,g,fatal) end)
 end
end
function on_input(ctx,ev)
 local ok,handled=guard(ctx,'E-INPUT',function()
  if fatal then
   if ev.type=='key' and ev.phase=='up' and ev.key=='back' then return false end
   if (ev.type=='pointer' and ev.phase=='up' and ev.y>=500 and ev.y<596) or (ev.type=='key' and ev.phase=='up' and ev.key=='up') then on_load(ctx);return true end
   return false
  end
  return app and app:input(ctx,ev) or false
 end)
 return ok and handled or false
end
function on_pause(ctx) guard(ctx,'E-PAUSE',function() if app then app:pause(ctx) end end) end
function on_resume(ctx) guard(ctx,'E-RESUME',function() if app then app:resume(ctx) end end) end
function on_leave(ctx) guard(ctx,'E-LEAVE',function() if app then app:leave(ctx) end end) end
