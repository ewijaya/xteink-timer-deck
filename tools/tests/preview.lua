package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local J=require('json');local Digits=require('lib.ui.digits');local Draw=require('lib.ui.draw')
local function emit(name,c,g) assert(g.command_count<=768);print(assert(J:encode({name=name,commands=g.commands,dark=c.dark or false}))) end
local c=R.new();local a=require('lib.app').new(c)
for _,page in ipairs({'deck','info'}) do for _,dark in ipairs({false,true}) do c.dark=dark;a.page=page;local g=R.canvas(c);a:draw(c,g);emit('HOST-MOCK-'..page..(dark and '-dark' or '-light'),c,g) end end
c.dark=false
local fatal=R.canvas(c);require('lib.app').draw_fatal(c,fatal,'E-DRAW');emit('HOST-MOCK-fatal',c,fatal)
local file=assert(io.open('app/lock.lua'));local source=file:read('a');file:close()
local lock=R.session({['lock.lua']=source},{},'lock');emit('HOST-MOCK-lock',lock,lock:draw())
for _,case in ipairs({{'Ready',100,100,'04:00'},{'Running',50,100,'02:00'},{'Last25',25,100,'01:00'},{'Last10',10,100,'00:24'},{'Paused',50,100,'02:00'},{'Finished',0,100,'00:00'},{'Stopwatch',0,100,'12:34'}}) do
 for _,dark in ipairs({false,true}) do
  local g=R.canvas(c);local ink=dark and 0 or 15;g:clear(dark and 15 or 0)
  Draw.ring(g,case[2],case[3],case[1],ink)
  local h=96;Digits.draw(g,case[4],(480-Digits.width(case[4],h))//2,248,h,ink)
  if case[1]=='Last10' then g:rect(144,374,192,48,{fill=true,color=ink});g:text(240,382,'LAST 10%',{font=c.fonts.large,align='center',color=15-ink})
  else g:text(240,382,case[1],{font=c.fonts.large,align='center',color=ink}) end
  g:text(240,540,'Orbit digits - 96 px',{font=c.fonts.large,align='center',color=ink})
  Digits.draw(g,'1:23:45',(480-Digits.width('1:23:45',64))//2,600,64,ink)
  emit('HOST-MOCK-spike-'..case[1]..(dark and '-dark' or '-light'),c,g)
 end
end

local g=R.canvas(c);g:clear(0)
for n=0,9 do local h=56;Digits.draw(g,tostring(n),20+(n%5)*92,60+(n//5)*100,h,15) end
Digits.draw(g,'12:34',(480-Digits.width('12:34',160))//2,360,160,15)
emit('HOST-MOCK-digit-sizes',c,g)
