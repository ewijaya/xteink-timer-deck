package.path='app/?.lua;tools/shim/?.lua;'..package.path
local M=require('lib.core.model');local F=require('lib.core.format');local C=require('lib.core.const');local J=require('json');local R=require('runtime')
assert(math.maxinteger==2147483647 and string.packsize('n')==4)
local passed={}
local function valid(s) local ok,why=M.valid(s);assert(ok,why) end
local function run(id,fn) fn();passed[#passed+1]=id;print('HOST MOCK Passed '..id) end
local function event(s,c,now)
 M.reconcile(s,now);valid(s);local before=assert(J:encode(s));local out,result=M.command(s,c,now)
 assert(J:encode(s)==before,'command mutated source');valid(out);if result~='OK' then assert(out==s) end;return out,result
end
local function create(s,dur,typ,now)
 local out,r=event(s,{action='CREATE',dur=dur,type=typ},now or 1000);assert(r=='OK',r);return out
end
local function act(s,n,action,now,fields)
 local i=s.items[n];local c={action=action,id=i.id,gen=i.gen};for k,v in pairs(fields or {}) do c[k]=v end
 return event(s,c,now)
end
local function one(dur) return create(M.new(1000),dur or 100,0) end
run('TC01',function() local s=M.new();valid(s);assert(#s.items==0 and s.set.pat==2 and s.set.cnt==3 and s.set.awake==1) end)
run('TC02',function() local s=create(M.new(),nil);assert(s.items[1].val==10 and s.items[1].st==0) end)
run('TC03',function() local s=M.new();local out,r=event(s,{action='CREATE',dur=0},1000);assert(r=='INVALID' and #out.items==0) end)
run('TC04',function() local s=one(1);s=act(s,1,'PRIMARY',1000);M.reconcile(s,1000);assert(s.items[1].st==1);M.reconcile(s,1001);valid(s);assert(s.items[1].st==3 and s.items[1].done==1001) end)
run('TC05',function() local s=one(C.MAX_SEC);s=act(s,1,'PRIMARY',1000);assert(s.items[1].anc==86400999);assert(M.value(s.items[1],1001)==C.MAX_SEC-1);assert(F.duration(C.MAX_SEC)=='999d 23:59:59') end)
run('TC06',function() local s=F.keypad(nil,'9');s=F.keypad(s,'0');assert(F.keypad_seconds(s)==90);assert(F.keypad_seconds('')==10);assert(F.keypad('123456','7')=='123456');assert(F.keypad('123','back')=='12') end)
run('TC07',function() local s=M.new();for _=1,10 do s=create(s,1) end;local out,r=event(s,{action='CREATE',dur=1},1000);assert(r=='FULL' and out==s) end)
run('TC08',function() local s=M.new();for _=1,4 do s=create(s,10) end;s=act(s,2,'DELETE',1000);s=create(s,10);assert(s.items[2].num==3 and s.items[4].num==2 and s.items[4].id==5) end)
run('TC09',function() local s=M.new();for n=1,10 do s=create(s,100,n%2);s=act(s,n,'PRIMARY',1000) end;for _,i in ipairs(s.items) do assert(M.value(i,1010)==(i.type==0 and 90 or 10)) end end)
run('TC10',function() local s=one();s=create(s,100);s=act(s,1,'PRIMARY',1000);s=act(s,2,'PRIMARY',1000);s=act(s,1,'PRIMARY',1010);assert(M.value(s.items[1],1020)==90 and M.value(s.items[2],1020)==80) end)
run('TC11',function() local s=one();s=act(s,1,'PRIMARY',1000);s=act(s,1,'PRIMARY',1010);s=act(s,1,'PRIMARY',1100);assert(s.items[1].gen==1 and M.value(s.items[1],1105)==85) end)
local seed=9137
local function rnd(n) seed=(seed*1103515245+12345)&0x7fffffff;return seed%n end
run('TC12',function()
 local total_error=0
 for _=1,1000 do
  local s=one(10000);local actual_ms=1000000+rnd(1000);local exact_elapsed=0
  s=act(s,1,'PRIMARY',actual_ms//1000)
  for _=1,100 do
   local start=actual_ms;local before=M.value(s.items[1],start//1000);actual_ms=actual_ms+1000+rnd(1000)
   s=act(s,1,'PRIMARY',actual_ms//1000);local segment=actual_ms-start;exact_elapsed=exact_elapsed+segment
   assert(math.abs((before-s.items[1].val)*1000-segment)<1000)
   actual_ms=actual_ms+1000+rnd(1000);s=act(s,1,'PRIMARY',actual_ms//1000)
  end
  local error_ms=(10000-M.value(s.items[1],actual_ms//1000))*1000-exact_elapsed
  assert(math.abs(error_ms)<100000);total_error=total_error+error_ms
 end
 assert(math.abs(total_error//1000)<1000,'mean must be under one second across seeded runs')
end)
run('TC13',function()
 for _,st in ipairs({0,1,2,3}) do
  local s=one(10);if st>0 then s=act(s,1,'PRIMARY',1000) end;if st==2 then s=act(s,1,'PRIMARY',1001) elseif st==3 then M.reconcile(s,1010) end
  local gen=s.items[1].gen;s=act(s,1,'RESET',s.trusted);assert(s.items[1].st==0 and s.items[1].val==10 and s.items[1].att==0);assert(s.items[1].gen==gen+(st==0 and 0 or 1))
 end
end)
run('TC14',function()
 local s=one();s=act(s,1,'EDIT',1000,{values={dur=120,pat=0}});assert(s.items[1].val==120)
 s=act(s,1,'PRIMARY',1000);local out,r=act(s,1,'EDIT',1001,{values={dur=150}});assert(r=='INVALID');s=out
 s=act(s,1,'PRIMARY',1010);local frozen=s.items[1].val;s=act(s,1,'EDIT',1010,{values={pat=1,cnt=5}});assert(s.items[1].val==frozen and s.items[1].rpat==0)
 s=act(s,1,'PRIMARY',1020);assert(s.items[1].rpat==1 and s.items[1].rcnt==5)
end)
run('TC15',function() local s=one();s=act(s,1,'PRIMARY',1000);s=act(s,1,'RENAME',1001,{name='Tea'});s=act(s,1,'ICON',1002,{icon=1});assert(s.items[1].anc==1100 and s.items[1].gen==1) end)
run('TC16',function() local s=one(1);s=act(s,1,'PRIMARY',1000);M.reconcile(s,1001);assert(#M.completions(s)==1);s=act(s,1,'PRIMARY',1001);assert(s.items[1].st==0) end)
run('TC17',function() local s=one(1);s=act(s,1,'PRIMARY',1000);s=act(s,1,'PRIMARY',1001);s=act(s,1,'PRIMARY',1001);local _,r=event(s,{action='PRIMARY',id=1,gen=1},1001);assert(r=='STALE') end)
run('TC18',function() local s=create(M.new(),0,1);s=act(s,1,'PRIMARY',1000);s=act(s,1,'PRIMARY',1020);s=act(s,1,'PRIMARY',1100);assert(M.value(s.items[1],1110)==30);M.reconcile(s,1100+C.MAX_SEC);valid(s);assert(s.items[1].lim==1 and s.items[1].st==2 and #M.completions(s)==0) end)
run('TC19',function() assert(F.name('  Tea   time  ')=='Tea time');for _,n in ipairs({'abcdefghijklmnopq','a|b','a\\b','é'}) do assert(F.name(n)==nil) end;local s=one();assert(F.label(s.items[1])=='TIMER 01');s.items[1].icon=1;assert(F.label(s.items[1])=='Coffee') end)
run('TC20',function()
 local cases={{3599,'','59:59','1:00'},{3600,'','1:00:00','1:00'},{86399,'','23:59:59','00:00'},{86400,'1d','00:00:00','00:00'},{C.MAX_SEC,'999d','23:59:59','00:00'}}
 for _,v in ipairs(cases) do local d,t=F.detail(v[1],true,false);assert(d==v[2] and t==v[3]);local _,minute=F.detail(v[1],true,true);assert(minute==v[4]) end
 assert(F.compact(59,true,true)=='01 min' and F.compact(59,false,true)=='+00 min');assert(F.compact(59,true,true,true)=='<1 min')
 local t={valid=true,hour=14,minute=5,year=2026,month=11,day=12,date_order='dmy',date_sep='/'}
 assert(F.clock(t)=='14:05');t.hour12=true;assert(F.clock(t,true)=='12/11/2026 2:05 PM')
end)
run('TC21',function() assert(F.ratio(C.MAX_SEC,C.MAX_SEC,360)==360);assert(F.ratio(0,C.MAX_SEC,360)==0);assert(math.abs(F.ratio(C.MAX_SEC//4,C.MAX_SEC,360)-90)<=1) end)
run('TC22',function()
 local s=M.new(1000);local now=1000
 for _=1,10000 do
  now=now+rnd(20);local action=rnd(10)
  if action<2 or #s.items==0 then s=event(s,{action='CREATE',dur=1+rnd(500),type=rnd(2)},now)
  else local n=1+rnd(#s.items);local actions={'PRIMARY','RESET','DELETE','ATTEMPT','SELECT','RENAME','ICON','EDIT'}
   s=act(s,n,actions[action-1],now,{name='Tea',icon=rnd(32),values={dur=1+rnd(1000)}})
  end
  valid(s)
 end
end)
run('TR01',function() local s=one();s=act(s,1,'PRIMARY',1000);local copy=M.copy(s);for n=1,7 do M.reconcile(copy,1000+n) end;M.reconcile(s,1007);assert(J:encode(s)==J:encode(copy)) end)
local model_sources={}
for _,name in ipairs({'model','const','format','chains'}) do local f=assert(io.open('app/lib/core/'..name..'.lua'));model_sources['lib/core/'..name..'.lua']=f:read('a');f:close() end
local function relaunch(s,now)
 local files=M.copy(model_sources);files['index.lua']=[[local M=require('lib.core.model');function on_load(ctx) M.reconcile(ctx.state,ctx.clock:now().epoch_sec) end]]
 local c=R.session(files,s,'main',{now={valid=true,epoch_sec=now}});assert(c.alive,c.error);valid(c.state);return c.state
end
run('TR02',function() local s=one();s=act(s,1,'PRIMARY',1000);s=relaunch(s,1037);assert(M.value(s.items[1],1037)==63) end)
run('TR03',function() local s=one();s=act(s,1,'PRIMARY',1000);s=act(s,1,'PRIMARY',1010);s=create(s,0,1,1010);s=act(s,2,'PRIMARY',1010);s=relaunch(s,1047);assert(s.items[1].val==90 and M.value(s.items[2],1047)==37) end)
run('TR04',function() local s=M.new();for _,d in ipairs({3,1,1}) do s=create(s,d);s=act(s,#s.items,'PRIMARY',1000) end;s=relaunch(s,1010);local q=M.completions(s);assert(#q==3 and q[1].id==2 and q[2].id==3 and q[3].id==1) end)
run('TR05',function() local s=one();s=act(s,1,'PRIMARY',1000);assert(M.reconcile(s,1100));assert(not M.reconcile(s,1100));assert(#M.completions(s)==1) end)
run('TR06',function() local s=one();s=act(s,1,'PRIMARY',1000);M.reconcile(s,1020);local changed,rollback=M.reconcile(s,900);valid(s);assert(changed and rollback and s.items[1].anc==980);local _,again=M.reconcile(s,900);assert(not again) end)
run('TR07',function() local s=one();s=act(s,1,'PRIMARY',1000);local before=J:encode(s);M.reconcile(s,1000);assert(J:encode(s)==before);local t={valid=true,hour=14,minute=5,revision=1};local a=F.clock(t);t.hour12=true;t.revision=2;assert(F.clock(t)~=a) end)
run('TR08',function() local s=one(1);s=act(s,1,'PRIMARY',1000);M.reconcile(s,1062);assert(s.items[1].late==1);local _,r=act(s,1,'ATTEMPT',1062);assert(r=='INVALID');M.reconcile(s,5000);assert(s.items[1].st==3) end)
run('TR09',function() local s=one();local _,r=act(s,1,'PRIMARY',nil);assert(r=='CLOCK');s=act(s,1,'RENAME',nil,{name='Tea'});s=act(s,1,'PRIMARY',1000);local raw=J:encode(s);assert(not M.reconcile(s,nil));assert(J:encode(s)==raw and M.value(s.items[1],nil)==nil) end)
run('TR10',function() local s=one();local out,r=act(s,1,'PRIMARY',C.MAX_INT-50);assert(r=='OVERFLOW' and out.items[1].st==0);assert(M.add_time(C.MAX_INT-100,100)==C.MAX_INT);assert(M.add_time(C.MAX_INT,1)==nil);assert(M.add_time(nil,1)==nil) end)
run('TR11',function() local early=2147483500;local late=100;local dt=(late-early)&0x7fffffff;assert(dt==248 and dt<C.KEY_DEBOUNCE_MS and dt<C.SETTLE_MS);assert(((600-early)&0x7fffffff)>=C.SETTLE_MS) end)
run('TR12',function() local s=one(2000);s=act(s,1,'PRIMARY',1000);local last,saves=1000,0;for now=1000,2000 do M.reconcile(s,now);if M.checkpoint_due(s,now,last) then last=now;saves=saves+1 end end;assert(saves==3);s=act(s,1,'RESET',2000);assert(not M.checkpoint_due(s,2500,last)) end)
run('AUTO-RESET',function()
 for sil=0,1 do for late=0,1 do for att=0,3 do
  local s=one(1);s=act(s,1,'PRIMARY',1000);M.reconcile(s,1001);local i=s.items[1];i.sil=sil;i.late=late;i.att=att
  local eligible=sil==1 or late==0 and att>0
  assert(M.auto_reset_due(s)==(eligible and 1601 or nil));M.reconcile(s,1600);assert(i.st==3);M.reconcile(s,1601);valid(s);assert(i.st==(eligible and 0 or 3))
 end end end
 local s=one(1);s=act(s,1,'PRIMARY',1000);M.reconcile(s,1001);s.items[1].gen=C.MAX_INT;s.items[1].att=1;M.reconcile(s,1700);assert(s.items[1].st==3);s=event(s,{action='DISMISS',targets=M.completions(s,true)},1700);assert(s.items[1].sil==1)
end)
print('HOST MOCK core/clock: '..#passed..' cases passed')
