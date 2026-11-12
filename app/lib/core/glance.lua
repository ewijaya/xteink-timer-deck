local C=require('lib.core.const');local F=require('lib.core.format')
local S=C.COPY
local G={}
-- This is a read-only projection. The full model is deliberately not loaded in a lock VM.
function G.view(s,now)
 local v={title=S.lock_title,lines={},interval=3600}
 if not now or not now.valid or not now.epoch_sec then return v end
 if type(s)~='table' or not next(s) then return v end
 if s.v~=1 or type(s.items)~='table' or #s.items>C.CAPACITY then v.title=S.open_app;return v end
 local at=now.epoch_sec;local done,running,watches,paused={},{},{},{}
 local function collect(i,label,chain)
  assert(type(i)=='table' and math.type(i.st)=='integer' and i.st>=0 and i.st<=3)
  assert(math.type(i.anc)=='integer' and i.anc>=0 and math.type(i.val)=='integer' and i.val>=0)
  if i.st==1 and i.type==0 then
   if i.anc<=at then if at-i.anc<=C.AUTO_RESET_SEC then done[#done+1]={label=label,done=i.anc} end
   else running[#running+1]={label=label,left=i.anc-at,anc=i.anc,chain=chain} end
  elseif i.st==3 and i.sil==0 and i.done<=at and at-i.done<=C.AUTO_RESET_SEC then done[#done+1]={label=label,done=i.done}
  elseif i.st==1 and i.type==1 then watches[#watches+1]={label=label,left=i.val+math.min(C.MAX_SEC-i.val,math.max(0,at-i.anc)),anc=i.anc}
  elseif i.st==2 then paused[#paused+1]={label=label,left=i.val,type=i.type} end
 end
 local chain_interval=3600
 local ok=pcall(function()
  for _,i in ipairs(s.items) do assert(F.name(i.name)==i.name and math.type(i.icon)=='integer' and i.icon>=0 and i.icon<=C.ICON_COUNT);collect(i,F.label(i)) end
  local r=s.ch and s.ch.run
  if r and r.st~=0 then
   local idx,round,anc=r.idx,r.round,r.anc
   assert(r.snap and #r.snap.steps>=2 and #r.snap.steps<=C.CHAIN_STEPS and r.snap.rounds>=1 and r.snap.rounds<=C.CHAIN_ROUNDS)
   if r.st==1 then
    local count=0
    while anc<=at do
     count=count+1;assert(count<=C.CHAIN_STEPS*C.CHAIN_ROUNDS);idx=idx+1
     if idx>#r.snap.steps then idx=1;round=round+1 end
     if round>r.snap.rounds then break end
     anc=assert(C.add_time(anc,r.snap.steps[idx].sec))
    end
    if round>r.snap.rounds then if at-anc<=C.AUTO_RESET_SEC then done[#done+1]={label=r.snap.name,done=anc} end
    else running[#running+1]={label=F.step_label(r.snap.steps[idx],idx),left=anc-at,anc=anc,chain=r.snap.name..' '..idx..'/'..#r.snap.steps};local left=anc-at;chain_interval=left<=150 and 30 or left<=3600 and 60 or left<=21600 and 300 or 900 end
   elseif r.st==2 then paused[#paused+1]={label=r.snap.name,left=r.anc,type=0};chain_interval=900
   elseif r.st==3 and r.sil~=1 and at>=r.ev and at-r.ev<=C.AUTO_RESET_SEC then done[#done+1]={label=r.snap.name,done=r.ev} end
  end
 end)
 if not ok then v.title=S.open_app;return v end
 table.sort(done,function(a,b) return a.done<b.done end);table.sort(running,function(a,b) return a.anc<b.anc end)
 if #done>0 then
  local i=done[1];v.title=S.times_up;v.label=i.label;v.caption=S.finished_lock..F.moment(i.done,now);v.more=#done>1 and '+'..(#done-1)..S.more_suffix or nil
  v.blink=at-i.done<180 and ((at-i.done)//30)%2==0;v.full=at-i.done<180
 elseif #running>0 then
  local i=table.remove(running,1);v.title=i.label;local days,digits=F.detail(i.left,true,true);v.digits=digits;v.days=days;v.caption=S.min_left;v.label=S.ends..F.moment(i.anc,now);v.chain=i.chain
 elseif #watches>0 then local i=table.remove(watches,1);v.title=i.label;v.label='+'..i.left//60 ..S.minutes;v.caption=S.since..F.moment(i.anc,now)
 elseif #paused>0 then local i=table.remove(paused,1);v.title=i.label;v.label=S.paused_lower;v.caption=F.compact(i.left,i.type==0,true)..(i.type==0 and S.left or '')
 else v.title=S.idle end
 local function line(s) if #v.lines<4 then v.lines[#v.lines+1]=s end end
 for _,i in ipairs(running) do line(i.label..' · '..F.compact(i.left,true,true)..' · '..F.moment(i.anc,now)) end
 for _,i in ipairs(watches) do line(i.label..' · +'..i.left//60 ..S.minutes) end
 for _,i in ipairs(paused) do line(i.label..' · '..S.paused_lower) end
 -- Compute intervals from all items, independently of which one made the headline.
 for _,i in ipairs(s.items) do
  if i.type==0 and i.st==1 and i.anc>at then local left=i.anc-at;v.interval=math.min(v.interval,left<=150 and 30 or left<=3600 and 60 or left<=21600 and 300 or 900)
  elseif i.type==1 and i.st==1 then v.interval=math.min(v.interval,300)
  elseif i.st==2 then v.interval=math.min(v.interval,900) end
 end
 v.interval=math.min(v.interval,chain_interval)
 for _,i in ipairs(done) do v.interval=math.min(v.interval,at-i.done<180 and 30 or 60) end
 return v
end
return G
