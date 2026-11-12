local clock_text='--:--'
function on_load(ctx)
 local ok=pcall(function()
  local now=ctx.clock:now()
  if now.valid then clock_text=string.format('%02d:%02d',now.hour,now.minute) end
 end)
 if not ok then pcall(function() ctx.log:error('E-LOCK-LOAD') end) end
end
function on_draw(ctx,g)
 local ok=pcall(function()
  g:clear(0);g:text(240,260,'Timer Deck',{font=ctx.fonts.large,align='center'})
  g:text(240,330,clock_text,{font=ctx.fonts.large,align='center',tabular=true})
 end)
 if not ok then pcall(function() ctx.log:error('E-LOCK-DRAW');g:clear(0);g:text(20,260,'Timer Deck',{font=ctx.fonts.large}) end) end
end
