local C=require('lib.core.const')
local M=require('lib.core.model')
local H=require('lib.core.chains')
local P={}
function P.seconds(setting,detail,i,value)
 if setting==1 then return true elseif setting==2 then return false end
 if detail then return i.type==0 and value<=600 or i.type==1 and value<600 end
 return i.type==0 and value<=60
end
function P.plan(s,now,screen,last,extra,selected)
 if not now then return nil end
 local delay
 local function offer(ms) ms=math.max(1,math.min(3600000,ms));if not delay or ms<delay then delay=ms end end
 local function seconds(sec,slack) offer(math.min(3600,math.max(0,sec))*1000+(slack or 0)) end
 if screen=='deck' or screen=='detail' then seconds(60-now%60) end
 for _,i in ipairs(s.items) do
  if i.st==1 then
   local value=M.value(i,now)
   if i.type==0 then seconds(math.max(0,i.anc-now),150);if i.anc-now>C.AWAKE_HORIZON_SEC then seconds(i.anc-now-C.AWAKE_HORIZON_SEC) end end
   if screen=='deck' or screen=='detail' and i.id==selected then
    if P.seconds(s.set.secs,screen=='detail',i,value) then seconds(1)
    else seconds(i.type==0 and ((math.max(1,value)-1)%60+1) or 60-value%60) end
   end
  end
 end
 for _,i in ipairs(s.items) do if i.st==3 and i.sil==0 and now>=i.done and now-i.done<C.AUTO_RESET_SEC then seconds(C.AUTO_RESET_SEC-(now-i.done)) end end
 local r=s.ch.run
 if r.st==1 then
  local value=H.value(r,now);seconds(value,150);local remaining=H.remaining(r,now);if remaining>C.AWAKE_HORIZON_SEC then seconds(remaining-C.AWAKE_HORIZON_SEC) end
  if screen=='chain_run' or screen=='deck' then
   if P.seconds(s.set.secs,screen=='chain_run',{type=0},value) then seconds(1) else seconds((math.max(1,value)-1)%60+1) end
  end
  seconds(math.max(0,C.CHECKPOINT_SEC-(now-last)))
 end
 if r.st==3 and r.sil~=1 and now>=r.ev and now-r.ev<600 then seconds(600-(now-r.ev)) end
 local reset=M.auto_reset_due(s);if reset then seconds(math.max(0,reset-now)) end
 for _,i in ipairs(s.items) do if i.st==1 then seconds(math.max(0,C.CHECKPOINT_SEC-(now-last)));break end end
 if extra then offer(extra) end
 return delay
end
return P
