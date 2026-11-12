package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local J=require('json');local Digits=require('lib.ui.digits');local Draw=require('lib.ui.draw')
local function emit(name,c,g) assert(g.command_count<=768);print(assert(J:encode({name=name,commands=g.commands}))) end
local c=R.new();local a=require('lib.app').new(c)
for _,page in ipairs({'deck','info'}) do a.page=page;local g=R.canvas(c);a:draw(c,g);emit('HOST-MOCK-'..page,c,g) end
for _,case in ipairs({{'Ready',100,100,'04:00'},{'Running',50,100,'02:00'},{'Last25',25,100,'01:00'},{'Last10',10,100,'00:24'},{'Paused',50,100,'02:00'},{'Finished',0,100,'00:00'}}) do
 for _,dark in ipairs({false,true}) do
  local g=R.canvas(c);local ink=dark and 0 or 15;g:clear(dark and 15 or 0)
  Draw.ring(g,case[2],case[3],case[1],ink)
  local h=96;Digits.draw(g,case[4],(480-Digits.width(case[4],h))//2,248,h,ink)
  g:text(240,382,case[1],{font=c.fonts.large,align='center',color=ink})
  g:text(240,540,'Orbit digits - 96 px',{font=c.fonts.large,align='center',color=ink})
  Digits.draw(g,'1:23:45',(480-Digits.width('1:23:45',64))//2,600,64,ink)
  emit('HOST-MOCK-spike-'..case[1]..(dark and '-dark' or '-light'),c,g)
 end
end
