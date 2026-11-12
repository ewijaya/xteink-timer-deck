package.path='tools/shim/?.lua;app/?.lua;'..package.path
local I=require('lib.core.importer');local M=require('lib.core.model');local H=require('lib.core.chains');local R=require('runtime');local App=require('lib.app');local J=require('json')
for _,pair in ipairs({{'90',90},{'01:30',90},{'1:02:03',3723},{'1d 2h 3m 4s',93784},{'999d23h59m59s',86399999},{'1m',60}}) do assert(I.duration(pair[1])==pair[2],pair[1]) end
for _,value in ipairs({'0','1:60','1:60:00','1h 1d','-1','1000d','999999999999999999999','1m garbage','1s 1s','0:00','1.5','abc'}) do assert(not I.duration(value),value) end
local c=R.new();local s=M.new();local input='# example\ntimer | Tea | 4:00 | coffee | SHORT + SHORT | 3\nstopwatch | Run | run\nchain | Practice | 1 | Music\nstep | Scales | 5:00 | Music | Short\nstep | Piece | 20:00\n'
local n,result=I.propose(s,input,c.hash:crc32(input),nil);assert(n,result);assert(#n.items==2 and n.items[1].st==0 and #n.ch.saved==1 and n.ch.saved[1].steps[2].sec==1200);assert(M.valid(n))
for _,bad in ipairs({'timer | x | 10 | 99','timer | x | 10 | | | 9','chain | x | 0\nstep | x | 1\nstep | y | 1','step | x | 1','timer | x | 10\nBAD','timer | é | 10'}) do local parsed,errors=I.parse(bad,s.set);assert(not parsed and errors[1]:find('Line '),bad) end
print('HOST MOCK Passed TI01')
local before=J:encode(n);local nope=I.propose(n,'timer | bad | 0',123,nil);assert(not nope and before==J:encode(n))
local full=M.new();for _=1,10 do full=M.command(full,{action='CREATE',dur=10},nil) end;assert(not I.propose(full,'timer | Tea | 4:00',12,nil));print('HOST MOCK Passed TI02 core')
local duplicate,why=I.propose(n,input,c.hash:crc32(input),nil);assert(not duplicate and why=='DUPLICATE')
s=M.new();for k=1,5 do local text='timer | T'..k..' | 10';s=assert(I.propose(s,text,c.hash:crc32(text),nil)) end;assert(#s.rc==4 and s.rc[1].dig==c.hash:crc32('timer | T5 | 10') and s.rc[4].dig==c.hash:crc32('timer | T2 | 10'));print('HOST MOCK Passed TI03')
local exported=I.export(n);local restored=assert(I.propose(M.new(),exported,c.hash:crc32(exported),nil));assert(I.export(restored)==exported);print('HOST MOCK Passed TI04')
-- Fullest export fits the documented 80-line correction and round-trips all definitions.
s=full;for k=1,5 do local d=H.template('Tea',2);d.steps={};for j=1,10 do d.steps[j]={id=j,name='Step '..j,sec=10,icon=1,pat=2} end;d.next_step=11;s=M.command(s,{action='CH_SAVE',definition=d},nil) end
exported=I.export(s);restored=assert(I.propose(M.new(),exported,c.hash:crc32(exported),nil));assert(I.export(restored)==exported)
-- File effects and persistence are exercised through the actual controller.
c=R.new();local a=App.new(c);assert(not c.files.created);a:action({action='sync'});assert(c.files.created)
c.files:write('timerdeck-import.txt','timer | Good | 10\ntimer | Bad | 0');a:action({action='import'});assert(#a.state.items==0 and c.files:read('timerdeck-import-result.txt'):find('Line 2'))
a.page={kind='sync'};c.files:write('timerdeck-import.txt','timer | Good | 10');c.save_failure='io_error';a:action({action='import'});assert(#a.state.items==0 and #a.state.rc==0)
c.save_failure=nil;a.page={kind='sync'};a:action({action='import'});assert(#a.state.items==1 and #a.state.rc==1);a:action({action='export'});assert(c.files:read('timerdeck-export.txt'):find('Good'));print('HOST MOCK Passed TI02 file effects / atomic save')
