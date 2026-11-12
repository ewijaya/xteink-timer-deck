local C=require('lib.core.const')
local F=require('lib.core.format')
local M={}
local function integer(n,lo,hi) return math.type(n)=='integer' and n>=lo and n<=hi end
function M.copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=M.copy(x) end;return t end
function M.add_time(now,duration)
 if not integer(now,1,C.MAX_INT) or not integer(duration,0,C.MAX_SEC) then return nil,'CLOCK' end
 if duration>C.MAX_INT-now then return nil,'OVERFLOW' end
 return now+duration
end
function M.new(now)
 return {v=1,rev=0,next_id=1,sel=0,trusted=now or 0,
 set={app=0,style=0,pat=C.DEFAULT_PATTERN,cnt=C.DEFAULT_COUNT,flash=1,light=1,secs=0,awake=1},
 items={},rc={},ch={last=0,saved={},run={st=0}}}
end
function M.find(s,id) for n,i in ipairs(s.items) do if i.id==id then return i,n end end end
function M.value(i,now)
 if i.st==3 then return 0 end
 if i.st~=1 then return i.val end
 if not now then return nil end
 if i.type==0 then return math.max(0,i.anc-now) end
 local elapsed=math.max(0,now-i.anc)
 if elapsed>=C.MAX_SEC-i.val then return C.MAX_SEC end
 return i.val+elapsed
end
local function ready(i)
 i.st=0;i.val=i.type==0 and i.dur or 0;i.anc=0;i.done=0;i.att=0;i.sil=0;i.late=0;i.lim=0
end
local settings={app={0,2},style={0,3},pat={0,#C.PATTERNS-1},cnt={C.COUNT_MIN,C.COUNT_MAX},flash={0,1},light={0,1},secs={0,2},awake={0,1}}
local function dense(t,max)
 if type(t)~='table' or #t>max then return false end
 local n=0;for k in pairs(t) do if not integer(k,1,#t) then return false end;n=n+1 end;return n==#t
end
local function all_numbers(v,seen)
 if type(v)=='number' then return math.type(v)=='integer' end
 if type(v)=='string' then return true end
 if type(v)~='table' or seen[v] then return false end;seen[v]=true
 for k,x in pairs(v) do if (type(k)~='string' and not integer(k,1,C.MAX_INT)) or (type(k)=='string' and tonumber(k)) or not all_numbers(x,seen) then return false end end
 seen[v]=nil;return true
end
function M.valid(s)
 local function check()
  assert(type(s)=='table' and all_numbers(s,{}),'stored types')
  assert(s.v==1 and integer(s.rev,0,C.MAX_INT) and integer(s.next_id,1,C.MAX_INT) and integer(s.trusted,0,C.MAX_INT),'header')
  assert(type(s.set)=='table');for k,b in pairs(settings) do assert(integer(s.set[k],b[1],b[2]),'setting '..k) end
  assert(dense(s.items,C.CAPACITY),'items');local ids,nums={},{}
  for _,i in ipairs(s.items) do
   assert(integer(i.id,1,s.next_id-1) and not ids[i.id] and integer(i.num,1,C.CAPACITY) and not nums[i.num],'identity');ids[i.id]=true;nums[i.num]=true
   assert(integer(i.gen,0,C.MAX_INT) and integer(i.type,0,1) and integer(i.st,0,3),'status')
   assert(F.name(i.name)==i.name and integer(i.icon,0,C.ICON_COUNT),'name/icon')
   for _,k in ipairs({'pat','rpat'}) do assert(integer(i[k],0,#C.PATTERNS-1)) end
   for _,k in ipairs({'cnt','rcnt'}) do assert(integer(i[k],C.COUNT_MIN,C.COUNT_MAX)) end
   assert(integer(i.att,0,i.rcnt));for _,k in ipairs({'sil','late','lim'}) do assert(integer(i[k],0,1)) end
   assert(integer(i.dur,0,C.MAX_SEC) and integer(i.val,0,C.MAX_SEC) and integer(i.anc,0,C.MAX_INT) and integer(i.done,0,C.MAX_INT))
   assert((i.st==1 and i.anc>0 or i.st~=1 and i.anc==0),'anchor')
   assert(i.st==0 or i.gen>0,'generation')
   assert(i.st==3 or (i.done==0 and i.att==0 and i.sil==0 and i.late==0),'completion')
   if i.type==0 then
    assert(i.dur>=1 and i.val<=i.dur and i.lim==0)
    assert(i.st~=0 or i.val==i.dur)
    assert((i.st~=1 and i.st~=2) or i.val>0)
    assert(i.st~=3 or (i.val==0 and i.done>0))
   else
    assert(i.dur==0 and i.st~=3);assert(i.st~=0 or i.val==0)
    assert(i.lim==0 or (i.st==2 and i.val==C.MAX_SEC))
   end
  end
  assert(s.sel==0 or ids[s.sel],'selection')
  assert(dense(s.rc,C.RECEIPTS));for _,r in ipairs(s.rc) do assert(integer(r.dig,-2147483647-1,C.MAX_INT) and integer(r.len,0,16384) and integer(r.n,1,15)) end
  -- M1 supports only the reserved empty chain container; M6 extends validation.
  assert(s.ch.last==0 and dense(s.ch.saved,0) and s.ch.run.st==0,'chains not implemented')
 end
 local ok,reason=pcall(check);return ok,ok and nil or tostring(reason)
end
local function advance(s,now)
 local changed=false
 for _,i in ipairs(s.items) do
  if i.st==1 then
   local v=M.value(i,now)
   if i.type==0 and v==0 then i.done=i.anc;i.anc=0;i.val=0;i.st=3;i.late=now-i.done>C.LATE_SEC and 1 or 0;changed=true
   elseif i.type==1 and v==C.MAX_SEC then i.val=v;i.anc=0;i.st=2;i.lim=1;changed=true end
  end
 end
 return changed
end
function M.reconcile(s,now)
 if not integer(now,1,C.MAX_INT) then return false end
 local changed,rollback=false,false
 if now<s.trusted then
  advance(s,s.trusted)
  for _,i in ipairs(s.items) do if i.st==1 then
   local v=M.value(i,s.trusted)
   if i.type==0 then i.anc=assert(M.add_time(now,v)) else i.val=v;i.anc=now end
  end end
  changed=true;rollback=true
 end
 changed=advance(s,now) or changed
 for _,i in ipairs(s.items) do
  if i.st==3 and i.gen<C.MAX_INT and (i.sil==1 or (i.late==0 and i.att>0)) and now>=i.done and now-i.done>=C.AUTO_RESET_SEC then i.gen=i.gen+1;ready(i);changed=true end
 end
 s.trusted=now;return changed,rollback
end
function M.completions(s,include_silenced)
 local q={};for _,i in ipairs(s.items) do if i.st==3 and (include_silenced or i.sil==0) then q[#q+1]={id=i.id,gen=i.gen,done=i.done} end end
 table.sort(q,function(a,b) return a.done<b.done or a.done==b.done and a.id<b.id end);return q
end
function M.auto_reset_due(s)
 local due
 for _,i in ipairs(s.items) do if i.st==3 and i.gen<C.MAX_INT and (i.sil==1 or i.late==0 and i.att>0) then
  local at=M.add_time(i.done,C.AUTO_RESET_SEC);if at and (not due or at<due) then due=at end
 end end;return due
end
function M.checkpoint_due(s,now,last)
 if not integer(now,1,C.MAX_INT) or now<last or now-last<C.CHECKPOINT_SEC then return false end
 for _,i in ipairs(s.items) do if i.st==1 then return true end end;return false
end
local function apply(s,c,now)
 local action=c.action
 if action=='ERASE' then return M.new(now),'OK' end
 if action=='SETTINGS' then
  if type(c.values)~='table' then return s,'INVALID' end
  for k,v in pairs(c.values) do local b=settings[k];if not b or not integer(v,b[1],b[2]) then return s,'INVALID' end end
  for k,v in pairs(c.values) do s.set[k]=v end;return s,'OK'
 end
 if action=='CREATE' or action=='CREATE_START' then
  if #s.items>=C.CAPACITY then return s,'FULL' end
  if s.next_id==C.MAX_INT then return s,'OVERFLOW' end
  local typ=c.type or 0;local dur=c.dur or C.DEFAULT_COUNTDOWN;local name=F.name(c.name or '')
  local pat,cnt,icon=c.pat or s.set.pat,c.cnt or s.set.cnt,c.icon or 0
  if not integer(typ,0,1) or not name or not integer(icon,0,C.ICON_COUNT) or not integer(pat,0,#C.PATTERNS-1) or not integer(cnt,C.COUNT_MIN,C.COUNT_MAX) or (typ==0 and not integer(dur,1,C.MAX_SEC)) then return s,'INVALID' end
  if action=='CREATE_START' and typ~=0 then return s,'INVALID' end
  local anc
  if action=='CREATE_START' then local why;anc,why=M.add_time(now,dur);if not anc then return s,why end end
  local used={};for _,i in ipairs(s.items) do used[i.num]=true end
  local num=1;while used[num] do num=num+1 end
  local i={id=s.next_id,gen=0,num=num,type=typ,st=0,name=name,icon=icon,pat=pat,cnt=cnt,rpat=pat,rcnt=cnt,att=0,sil=0,late=0,lim=0,dur=typ==0 and dur or 0,val=0,anc=0,done=0}
  ready(i);if anc then i.st=1;i.gen=1;i.anc=anc end
  s.items[#s.items+1]=i;s.next_id=s.next_id+1;s.sel=i.id;return s,'OK'
 end
 if action=='SILENCE' or action=='DISMISS' then
  if not dense(c.targets,C.CAPACITY) then return s,'INVALID' end
  local seen={};for _,t in ipairs(c.targets) do if type(t)~='table' or not t.id or seen[t.id] then return s,'INVALID' end;seen[t.id]=true end
  for _,t in ipairs(c.targets) do local i=M.find(s,t.id);if not i or i.gen~=t.gen or i.st~=3 then return s,'STALE' end end
  for _,t in ipairs(c.targets) do
   local i=M.find(s,t.id)
   if action=='SILENCE' or i.gen==C.MAX_INT then i.sil=1 else i.gen=i.gen+1;ready(i) end
  end;return s,'OK'
 end
 local i,n=M.find(s,c.id);if not i or i.gen~=c.gen then return s,'STALE' end
 if action=='PRIMARY' then
  if i.st==3 then ready(i)
  elseif i.st==1 then
   if not now then return s,'CLOCK' end;i.val=M.value(i,now);i.anc=0;i.st=2
  else
   if i.lim==1 then return s,'INVALID' end
   if i.st==0 and i.gen==C.MAX_INT then return s,'OVERFLOW' end
   local anc,why=M.add_time(now,i.type==0 and i.val or 0);if not anc then return s,why end
   if i.st==0 then i.gen=i.gen+1 end;i.anc=anc;i.st=1;i.rpat=i.pat;i.rcnt=i.cnt
  end
 elseif action=='RESET' then
  if i.st==0 then return s,'OK' end
  if i.gen==C.MAX_INT then return s,'OVERFLOW' end;i.gen=i.gen+1;ready(i)
 elseif action=='DELETE' then table.remove(s.items,n);if s.sel==i.id then s.sel=#s.items>0 and s.items[math.min(n,#s.items)].id or 0 end
 elseif action=='SELECT' then s.sel=i.id
 elseif action=='RENAME' then local name=F.name(c.name);if not name then return s,'INVALID' end;i.name=name
 elseif action=='ICON' then if not integer(c.icon,0,C.ICON_COUNT) then return s,'INVALID' end;i.icon=c.icon
 elseif action=='EDIT' then
  local v=c.values;if type(v)~='table' then return s,'INVALID' end
  for k,x in pairs(v) do
   if k=='name' then if not F.name(x) then return s,'INVALID' end
   elseif k=='icon' then if not integer(x,0,C.ICON_COUNT) then return s,'INVALID' end
   elseif k=='dur' then if i.type~=0 or i.st~=0 or not integer(x,1,C.MAX_SEC) then return s,'INVALID' end
   elseif k=='pat' or k=='cnt' then if i.type~=0 or (i.st~=0 and i.st~=2) or not integer(x,k=='pat' and 0 or C.COUNT_MIN,k=='pat' and #C.PATTERNS-1 or C.COUNT_MAX) then return s,'INVALID' end
   else return s,'INVALID' end
  end
  for k,x in pairs(v) do i[k]=k=='name' and F.name(x) or x end;if v.dur then i.val=i.dur end
 elseif action=='ATTEMPT' then
  if not now then return s,'CLOCK' end
  if i.st~=3 or i.sil==1 or i.late==1 or i.att>=i.rcnt or now<i.done or now-i.done>C.LATE_SEC then return s,'INVALID' end;i.att=i.att+1
 else return s,'INVALID' end
 return s,'OK'
end
-- Reconcile is explicit: the controller must call it before resolving an intent.
-- Candidate construction is transactional; refusal returns the original table.
function M.command(s,c,now)
 if type(c)~='table' then return s,'INVALID' end
 local candidate,result=apply(M.copy(s),c,now)
 if result~='OK' then return s,result end
 local valid=M.valid(candidate);if not valid then return s,'INVALID' end
 return candidate,'OK'
end
return M
