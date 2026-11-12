local Clock={}
local fields={'valid','epoch_sec','revision','hour','minute','second','hour12','offset_minutes','date_order','date_sep','year','month','day'}
function Clock.sample(ctx)
 local t=ctx.clock:now();local s={};for _,k in ipairs(fields) do s[k]=t[k] end
 return s,ctx.clock:millis()
end
return Clock
