package.path='tools/shim/?.lua;'..package.path
local R=require('runtime')
local files={}
-- Host-only fixture collection; app sandbox has no io/package/load.
for line in io.lines('build/scripts.txt') do local f=assert(io.open('app/'..line));files[line]=f:read('a');f:close() end
local c=R.session(files,{sentinel=7});assert(c.alive,c.error);local g=c:draw();assert(c.alive,c.error);assert(g.command_count<=768)
local before=c.save_attempts;c:advance(500);c:event('on_input',{type='key',key='up',phase='up'});c:draw();assert(c.alive,c.error);assert(c.save_attempts==before)
local shown=false;for _,cmd in ipairs(c.last_canvas.commands) do if cmd.method=='text' and cmd.args[3]=='Device information' then shown=true end end;assert(shown)
c:event('on_input',{type='key',key='back',phase='up'});c:draw();assert(c.state.sentinel==7)
local l=R.session(files,{sentinel=7},'lock');l:draw();assert(l.alive,l.error);l:leave();assert(l.save_attempts==0 and l.persisted.sentinel==7)
-- Fatal load and draw failures must be caught, and retry must reconstruct the app.
local original=files['lib/app.lua'];files['lib/app.lua']='error("injected")'
local f=R.session(files,{});assert(f.alive);f:draw();assert(f.alive);files['lib/app.lua']=original
f:event('on_input',{type='key',phase='up',key='up'});f:draw();assert(f.alive,f.error)
print('HOST MOCK shell / lock / fatal retry passed')
