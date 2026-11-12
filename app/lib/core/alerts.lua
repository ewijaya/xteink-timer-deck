local C=require('lib.core.const')
local A={patterns={{300},{900},{300,200,300},{300,200,900}}}
function A.choose(s,now)
 if not now then return end
 local q={}
 for _,i in ipairs(s.items) do
  if i.st==3 and i.sil==0 and i.late==0 and i.att<i.rcnt and (s.set.light==1 or s.set.flash==1 or i.att==0) and now>=i.done and now-i.done<=C.LATE_SEC then q[#q+1]={id=i.id,gen=i.gen,done=i.done,att=i.att,pat=i.rpat} end
 end
 table.sort(q,function(a,b) return a.att<b.att or a.att==b.att and (a.done<b.done or a.done==b.done and a.id<b.id) end)
 return q[1]
end
function A.hold(s,now)
 if not now or s.set.awake==0 then return false end
 for _,i in ipairs(s.items) do
  if i.type==0 and (i.st==1 and i.anc-now<=C.AWAKE_HORIZON_SEC or i.st==3 and i.sil==0 and now>=i.done and now-i.done<C.AUTO_RESET_SEC) then return true end
 end
 return false
end
function A.coverage(s,i,now,awake,lock)
 if i and i.type==0 and i.st==1 and now and s.set.awake==1 and awake and i.anc-now<=C.AWAKE_HORIZON_SEC then return 2 end
 return lock and 3 or 1
end
return A
