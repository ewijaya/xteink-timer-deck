local App,app,fatal
local function fail(ctx,code)
 if fatal~=code then ctx.log:error(code) end
 fatal=code;if app then pcall(app.pause,app,ctx) end;if ctx.frontlight then ctx.frontlight:reset() end
 ctx:invalidate('full')
end
local function guard(ctx,code,fn,...)
 local ok,result=pcall(fn,...);if not ok then fail(ctx,code) end;return ok,result
end
function on_load(ctx)
 guard(ctx,'E-LOAD',function() if app then app:leave(ctx) end;App=require('lib.app');app=App.new(ctx);fatal=nil end)
end
function on_draw(ctx,g)
 local ok=pcall(function()
  if app and not fatal then app:draw(ctx,g)
  elseif App then App.draw_fatal(ctx,g,fatal)
  else
   g:clear(0);g:rect(2,2,116,76,{line_width=2});g:text(60,28,'Back',{font=ctx.fonts.medium,align='center'});g:text(240,310,fatal or 'E-LOAD',{font=ctx.fonts.medium,align='center'});g:text(240,260,'Something went wrong',{font=ctx.fonts.large,align='center'})
   g:rect(16,500,448,96,{line_width=2});g:text(240,535,'Try again',{font=ctx.fonts.large,align='center'})
  end
 end)
 if not ok then
  fatal='E-DRAW';if app then pcall(app.pause,app,ctx) end;pcall(function() ctx.log:error(fatal);if ctx.frontlight then ctx.frontlight:reset() end;App.draw_fatal(ctx,g,fatal) end)
 end
end
function on_input(ctx,ev)
 local ok,handled=guard(ctx,'E-INPUT',function()
  if app and app.fatal then fatal=app.fatal end
  if fatal then
   if ev.type=='pointer' and ev.phase=='up' and ev.x<120 and ev.y<80 then ctx:quit();return true end
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
