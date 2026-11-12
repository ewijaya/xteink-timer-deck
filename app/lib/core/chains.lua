local C=require('lib.core.const');local F=require('lib.core.format')
local H={}
local function int(n,a,b) return math.type(n)=='integer' and n>=a and n<=b end
function H.find(s,id) for n,d in ipairs(s.ch.saved) do if d.id==id then return d,n end end end
function H.total(d)
 local sum=0
 for _,step in ipairs(d.steps or {}) do if not int(step.sec,1,C.MAX_SEC) or step.sec>C.MAX_SEC-sum then return nil end;sum=sum+step.sec end
 if not int(d.rounds,1,9) or sum>C.MAX_SEC//d.rounds then return nil end
 return sum*d.rounds
end
local function definition(d)
 assert(int(d.id,1,C.MAX_INT) and int(d.rev,1,C.MAX_INT) and int(d.next_step,1,C.MAX_INT))
 assert(F.name(d.name)==d.name and int(d.icon,0,30) and #d.steps>=2 and #d.steps<=10 and H.total(d))
 local seen={};for _,v in ipairs(d.steps) do assert(int(v.id,1,d.next_step-1) and not seen[v.id] and F.name(v.name)==v.name and int(v.icon,0,30) and int(v.pat,0,3));seen[v.id]=true end
end
function H.valid(ch)
 assert(type(ch)=='table' and int(ch.last,0,C.MAX_INT) and #ch.saved<=5)
 local ids={};for _,d in ipairs(ch.saved) do definition(d);assert(d.id<=ch.last and not ids[d.id]);ids[d.id]=true end
 local r=ch.run;assert(type(r)=='table' and int(r.st,0,4))
 if r.st==0 then assert(r.gen==nil or int(r.gen,0,C.MAX_INT));return end
 definition(r.snap);assert(r.id==r.snap.id and int(r.gen,1,C.MAX_INT) and int(r.idx,1,#r.snap.steps) and int(r.round,1,r.snap.rounds))
 assert(int(r.anc,0,C.MAX_INT) and int(r.ev,0,C.MAX_INT) and int(r.skipped,0,90) and int(r.away,0,90) and int(r.pat,0,3) and int(r.cnt,1,5) and int(r.att,0,r.cnt) and int(r.cue,0,1))
 assert(r.st~=1 or r.anc>0);assert(r.st~=2 or r.anc>=1 and r.anc<=r.snap.steps[r.idx].sec);assert(r.st<3 or r.anc==0)
end
function H.value(r,now) if r.st==1 then return now and math.max(0,r.anc-now) or nil elseif r.st==2 then return r.anc else return 0 end end
function H.remaining(r,now)
 local v=H.value(r,now);if not v then return nil end
 for idx=r.idx+1,#r.snap.steps do v=v+r.snap.steps[idx].sec end
 local pass=H.total(r.snap)//r.snap.rounds
 return v+pass*(r.snap.rounds-r.round)
end
local function next_step(r,at,paused,api)
 r.ev=at;r.idx=r.idx+1
 if r.idx>#r.snap.steps then r.idx=1;r.round=r.round+1 end
 if r.round>r.snap.rounds then r.round=r.snap.rounds;r.idx=#r.snap.steps;r.st=3;r.anc=0;r.cue=0;return end
 r.anc=paused and r.snap.steps[r.idx].sec or assert(api.add_time(at,r.snap.steps[r.idx].sec));r.cue=1
end
function H.advance(s,now,api)
 local r=s.ch.run;if r.st~=1 then return false end
 local count=0
 while r.st==1 and r.anc<=now do local boundary=r.anc;next_step(r,boundary,false,api);count=count+1;assert(count<=90) end
 if count>0 then r.away=count>1 and count or 0;if count>1 or now-r.ev>C.LATE_SEC then r.cue=0 end;return true end
 return false
end
function H.rebase(s,old,now,api)
 local r=s.ch.run
 if r.st==1 then r.anc=assert(api.add_time(now,H.value(r,old))) end
 if r.st~=0 and r.ev>0 then r.ev=math.max(1,now-math.max(0,old-r.ev)) end
end
function H.template(name,pat)
 local d={name=name,icon=0,rounds=1,steps={},next_step=1}
 local specs
 if name=='Pomodoro' then d.icon=9;d.rounds=4;specs={{'Focus',1500,9},{'Break',300,1}}
 elseif name=='Plank' then d.icon=6;d.rounds=3;specs={{'Plank',30,6},{'Rest',30,0}}
 elseif name=='Tea' then d.icon=1;specs={{'Boil',240,16},{'Steep',180,1}}
 else specs={} end
 for n,v in ipairs(specs) do d.steps[n]={id=n,name=v[1],sec=v[2],icon=v[3],pat=pat};d.next_step=n+1 end
 return d
end
function H.command(s,c,now,api)
 local action=c.action;local r=s.ch.run;local d,n=H.find(s,c.id)
 if action=='CH_SAVE' then
  local value=api.copy(c.definition);if type(value)~='table' then return 'INVALID' end
  if c.id then if not d or d.rev~=c.rev then return 'STALE' end;if r.id==d.id and (r.st==1 or r.st==2) then return 'ACTIVE' end;if d.rev==C.MAX_INT then return 'OVERFLOW' end;value.id=d.id;value.rev=d.rev+1
  else if #s.ch.saved>=5 then return 'CHAIN_FULL' end;if s.ch.last==C.MAX_INT then return 'OVERFLOW' end;s.ch.last=s.ch.last+1;value.id=s.ch.last;value.rev=1 end
  if not pcall(definition,value) then return 'INVALID' end
  s.ch.saved[n or #s.ch.saved+1]=value;return 'OK'
 elseif action=='CH_DUPLICATE' then
  if not d or d.rev~=c.rev then return 'STALE' end
  return H.command(s,{action='CH_SAVE',definition=d},now,api)
 elseif action=='CH_MOVE' or action=='CH_DELETE' then
  if not d or d.rev~=c.rev then return 'STALE' end
  if action=='CH_DELETE' then table.remove(s.ch.saved,n);if r.id==d.id then s.ch.run={st=0,gen=r.gen} end
  else local to=n+(c.direction==1 and 1 or -1);if to>=1 and to<=#s.ch.saved then s.ch.saved[n],s.ch.saved[to]=s.ch.saved[to],s.ch.saved[n] end end
  return 'OK'
 elseif action=='CH_START' then
  if not d or d.rev~=c.rev then return 'STALE' end
  if r.st==1 or r.st==2 then return 'ACTIVE' end
  if (r.gen or 0)==C.MAX_INT then return 'OVERFLOW' end
  local finish,why=api.add_time(now,H.total(d));if not finish then return why end
  s.ch.run={st=1,id=d.id,gen=(r.gen or 0)+1,snap=api.copy(d),idx=1,round=1,anc=assert(api.add_time(now,d.steps[1].sec)),ev=now,skipped=0,away=0,pat=s.set.pat,cnt=s.set.cnt,att=0,cue=0};return 'OK'
 end
 if r.st==0 or c.gen~=r.gen or c.step~=r.snap.steps[r.idx].id or c.round~=r.round then return 'STALE' end
 if action=='CH_DONE' then if r.st<3 then return 'INVALID' end;s.ch.run={st=0,gen=r.gen};return 'OK' end
 if action=='CH_ATTEMPT' then if r.st~=3 or not now or now<r.ev or now-r.ev>60 or r.att>=r.cnt then return 'INVALID' end;r.att=r.att+1;return 'OK' end
 if action=='CH_CUE' then if r.st~=1 or r.cue~=1 then return 'INVALID' end;r.cue=0;return 'OK' end
 if action=='CH_SILENCE' then r.cue=0;r.att=r.cnt;return 'OK' end
 if r.st~=1 and r.st~=2 then return 'INVALID' end
 if r.gen==C.MAX_INT then return 'OVERFLOW' end
 local paused=r.st==2
 if action=='CH_PRIMARY' then
  if paused then local finish,why=api.add_time(now,H.remaining(r,now));if not finish then return why end;r.anc=assert(api.add_time(now,r.anc));r.st=1
  else if not now then return 'CLOCK' end;r.anc=H.value(r,now);r.st=2 end
 elseif action=='CH_SKIP' then
  if not now then return 'CLOCK' end
  if not paused then local finish,why=api.add_time(now,H.remaining(r,now));if not finish then return why end end
  r.skipped=r.skipped+1;next_step(r,now,paused,api)
 elseif action=='CH_RESTART' then
  if paused then r.anc=r.snap.steps[r.idx].sec else
   local value=r.snap.steps[r.idx].sec;local rest=H.remaining(r,now)-H.value(r,now);local finish,why=api.add_time(now,rest+value);if not finish then return why end;r.anc=assert(api.add_time(now,value)) end
 elseif action=='CH_STOP' then if not now then return 'CLOCK' end;r.st=4;r.anc=0;r.ev=now;r.cue=0
 else return 'INVALID' end
 r.gen=r.gen+1;return 'OK'
end
return H
