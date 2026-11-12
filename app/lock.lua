local view,now,fonts,digits,clock_text,copy
function on_load(ctx)
 local ok=pcall(function()
  copy=require('lib.core.const').COPY;local F=require('lib.core.format');local G=require('lib.core.glance');digits=require('lib.ui.digits')
  now=ctx.clock:now();clock_text=F.clock(now,true);fonts={small=ctx.fonts:size(22),medium=ctx.fonts:size(32),large=ctx.fonts:size(40)}
  view=G.view(ctx.state,now);ctx.lock:set_interval(view.interval)
  if view.full then ctx:invalidate('full') end
 end)
 if not ok then view=nil;pcall(function() ctx.log:error('E-LOCK-LOAD') end) end
end
function on_draw(ctx,g)
 local ok=pcall(function()
  local ink,paper=15,0
  if view and view.blink then ink,paper=paper,ink end
  g:clear(paper)
  g:text(20,25,clock_text or '--:--',{font=fonts and fonts.small or ctx.fonts.small,color=ink})
  local battery=ctx.device:battery();if battery.percent>=0 then g:text(460,25,battery.percent..'%',{font=fonts and fonts.small or ctx.fonts.small,color=ink,align='right'}) end
  g:text(240,135,view and view.title or copy and copy.lock_title or 'Timer Deck',{font=fonts and fonts.large or ctx.fonts.large,color=ink,align='center'})
  if not view then return end
  if view.digits then
   local height=160;while digits.width(view.digits,height)>440 do height=height-8 end
   digits.draw(g,view.digits,(480-digits.width(view.digits,height))//2,235,height,ink)
   if view.days~='' then g:text(240,195,view.days,{font=fonts.medium,color=ink,align='center'}) end
  end
  if view.label then g:text(240,view.digits and 475 or 420,view.label,{font=fonts.medium,color=ink,align='center'}) end
  if view.caption then g:text(240,view.digits and 420 or 475,view.caption,{font=fonts.small,color=ink,align='center'}) end
  if view.chain then g:text(240,525,view.chain,{font=fonts.small,color=ink,align='center'}) end
  if view.more then g:text(240,525,view.more,{font=fonts.small,color=ink,align='center'}) end
  for n,line in ipairs(view.lines) do g:text(20,565+(n-1)*48,line,{font=fonts.small,color=ink}) end
 end)
 if not ok then pcall(function() ctx.log:error('E-LOCK-DRAW');g:clear(0);g:text(20,260,'Timer Deck',{font=ctx.fonts.large}) end) end
end
