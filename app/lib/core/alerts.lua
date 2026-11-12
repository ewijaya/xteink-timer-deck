local C=require('lib.core.const')
local H=require('lib.core.chains')
local A={patterns={{300},{900},{300,200,300},{300,200,900}}}
function A.choose(s,now)
 if not now then return end
 local q={}
 for _,i in ipairs(s.items) do
  if i.st==3 and i.sil==0 and i.late==0 and i.att<i.rcnt and (s.set.light==1 or s.set.flash==1 or i.att==0) and now>=i.done and now-i.done<=C.LATE_SEC then q[#q+1]={id=i.id,gen=i.gen,done=i.done,att=i.att,pat=i.rpat} end
 end
 local r=s.ch.run
 if r.st==3 and now>=r.ev and now-r.ev<=60 and r.att<r.cnt and (s.set.light==1 or s.set.flash==1 or r.att==0) then q[#q+1]={chain=true,id=r.id,gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round,done=r.ev,att=r.att,pat=r.pat} end
 if r.st==1 and r.cue==1 and now>=r.ev and now-r.ev<=60 then q[#q+1]={chain=true,cue=true,id=r.id,gen=r.gen,step=r.snap.steps[r.idx].id,round=r.round,done=r.ev,att=0,pat=r.snap.steps[r.idx].pat} end
 table.sort(q,function(a,b) return a.att<b.att or a.att==b.att and (a.done<b.done or a.done==b.done and a.id<b.id) end)
 return q[1]
end
function A.hold(s,now)
 if not now or s.set.awake==0 then return false end
 for _,i in ipairs(s.items) do
  if i.type==0 and (i.st==1 and i.anc-now<=C.AWAKE_HORIZON_SEC or i.st==3 and i.sil==0 and now>=i.done and now-i.done<C.AUTO_RESET_SEC) then return true end
 end
 local r=s.ch.run;return r.st==1 and H.remaining(r,now)<=C.AWAKE_HORIZON_SEC or r.st==3 and r.att<r.cnt and now>=r.ev and now-r.ev<600
end
function A.coverage(s,i,now,awake,lock)
 if i and i.type==0 and i.st==1 and now and s.set.awake==1 and awake and i.anc-now<=C.AWAKE_HORIZON_SEC then return 2 end
 return lock and 3 or 1
end
return A
