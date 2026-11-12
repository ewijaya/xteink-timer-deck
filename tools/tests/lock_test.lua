package.path='tools/shim/?.lua;app/?.lua;'..package.path
local R=require('runtime');local M=require('lib.core.model');local G=require('lib.core.glance');local J=require('json')
local c=R.new();local now=c.now_value;local at=now.epoch_sec
local function timer(dur) return (M.command(M.new(at),{action='CREATE_START',dur=dur,name='Tea'},at)) end
local files={};for path in io.lines('build/scripts.txt') do local f=assert(io.open('app/'..path));files[path]=f:read('a');f:close() end
local allowed={['lib.core.const']=true,['lib.core.format']=true,['lib.core.glance']=true,['lib.ui.digits']=true}
local s=timer(60);local before=assert(J:encode(s));local lock=R.session(files,s,'lock');lock:draw();assert(lock.alive and #lock.logs==0,lock.logs[1]);for name in pairs(lock.loaded) do assert(allowed[name],name) end
assert(lock.save_attempts==0 and J:encode(lock.state)==before);print('HOST MOCK Passed TL01 / TL03')
assert(G.view(s,now).title=='Tea');assert(G.view(M.new(at),now).title=='No timers running');assert(G.view({v=2},now).title=='Open Timer Deck')
s=M.command(s,{action='PRIMARY',id=1,gen=1},at);assert(G.view(s,now).label=='paused')
s=M.command(M.new(at),{action='CREATE',type=1,name='Work'},at);s=M.command(s,{action='PRIMARY',id=1,gen=0},at);assert(G.view(s,now).label=='+0 min');print('HOST MOCK Passed TL02')
s=timer(1)
for _,age in ipairs({0,29,30,59,60,179,180,600,601}) do local n=M.copy(now);n.epoch_sec=at+1+age;local v=G.view(s,n);assert((v.title=="TIME'S UP")== (age<=600));assert(not not v.blink==(age<180 and age//30%2==0)) end
print('HOST MOCK Passed TL04')
for _,pair in ipairs({{150,30},{151,60},{3600,60},{3601,300},{21600,300},{21601,900}}) do assert(G.view(timer(pair[1]),now).interval==pair[2]) end
assert(G.view(M.new(at),now).interval==3600);print('HOST MOCK Passed TL05')
for _,state in ipairs({{}, {v=2},{v=1,items={{}}}}) do local t=R.session(files,state,'lock');t:draw();assert(t.alive and t.save_attempts==0) end
local invalid=M.copy(now);invalid.valid=false;local t=R.session(files,s,'lock',{now=invalid});t:draw();assert(t.alive and t.save_attempts==0)
local broken=M.copy(files);broken['lib/core/glance.lua']='error("injected")';t=R.session(broken,s,'lock');t:draw();assert(t.alive and #t.logs==1);print('HOST MOCK Passed TL06')
