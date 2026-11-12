local C=require('lib.core.const')
local F={}
function F.ratio(n,d,scale)
 if n<=0 or d<=0 then return 0 end;n=math.min(n,d)
 while d>1048576 do n=n>>1;d=d>>1 end
 return n*scale//d
end
function F.name(s)
 if type(s)~='string' or s:find('[^ -~]') or s:find('[|\\]') then return nil end
 s=s:gsub(' +',' '):match('^ *(.-) *$');if #s>C.NAME_MAX then return nil end;return s
end
function F.step_label(step,n) return step.name~='' and step.name or C.COPY.step..' '..n end
function F.label(i)
 if i.name~='' then return i.name end
 if i.icon>0 then return C.ICON_NAMES[i.icon] end
 return string.format('%s %02d',i.type==0 and C.COPY.timer_label or C.COPY.watch_label,i.num)
end
function F.detail(value,countdown,minutes)
 local v=math.max(0,math.min(C.MAX_SEC,value))
 if minutes then v=(v//60+(countdown and v%60>0 and 1 or 0))*60 end
 local d,h,m,s=v//86400,v//3600%24,v//60%60,v%60
 local days=d>0 and d..'d' or ''
 if minutes then
  return days,(d>0 and string.format('%02d:%02d',h,m) or h>0 and string.format('%d:%02d',h,m) or string.format('%02d',m)),C.COPY.min
 end
 return days,(d>0 and string.format('%02d:%02d:%02d',h,m,s) or h>0 and string.format('%d:%02d:%02d',h,m,s) or string.format('%02d:%02d',m,s)),C.COPY.sec
end
function F.compact(v,countdown,minutes,never)
 if never and countdown and v>0 and v<60 then return '<1 min' end
 if minutes then v=(v//60+(countdown and v%60>0 and 1 or 0))*60 end
 local d,h,m=v//86400,v//3600%24,v//60%60
 local s=d>0 and string.format('%dd %02dh',d,h) or h>0 and string.format('%dh %02dm',h,m) or minutes and string.format('%02d min',m) or string.format('%02d:%02d',m,v%60)
 return (countdown and '' or '+')..s
end
function F.duration(v)
 if v<60 then return v..'s' end
 local d,t=F.detail(v,true,false)
 if d~='' then return d..' '..t end
 return (t:gsub('^0',''))
end
function F.clock(t,other_day)
 if not t or not t.valid then return '--:--' end
 local h=t.hour12 and (t.hour+11)%12+1 or t.hour
 local s=string.format(t.hour12 and '%d:%02d' or '%02d:%02d',h,t.minute)
 if t.hour12 then s=s..(t.hour<12 and ' AM' or ' PM') end
 if other_day then
  local p={y=tostring(t.year),m=string.format('%02d',t.month),d=string.format('%02d',t.day)}
  local order=t.date_order or 'ymd';local sep=t.date_sep or '/'
  s=p[order:sub(1,1)]..sep..p[order:sub(2,2)]..sep..p[order:sub(3,3)]..' '..s
 end
 return s
end
-- Pure keypad draft operations, shared with the later UI.
function F.keypad(draft,key)
 local s=draft or ''
 if key=='back' then return s:sub(1,-2) end
 if not key:match('^%d%d?$') then return s end
 if #s+#key>6 then return s end;return s..key
end
function F.keypad_seconds(s)
 local v=tonumber(s) or C.DEFAULT_COUNTDOWN
 return (v//10000)*3600+(v//100%100)*60+v%100
end
function F.moment(sec,now)
 if not sec or not now or not now.valid or not now.epoch_sec then return '--:--' end
 local offset=(now.offset_minutes or 0)*60
 local days=sec//86400;local clock=sec%86400+offset
 days=days+clock//86400;clock=clock%86400
 local z=days+719468;local era=z//146097;local doe=z-era*146097
 local yoe=(doe-doe//1460+doe//36524-doe//146096)//365
 local year=yoe+era*400;local doy=doe-(365*yoe+yoe//4-yoe//100);local mp=(5*doy+2)//153
 local day=doy-(153*mp+2)//5+1;local month=mp+(mp<10 and 3 or -9);year=year+(month<=2 and 1 or 0)
 local t={valid=true,hour=clock//3600,minute=clock//60%60,year=year,month=month,day=day,hour12=now.hour12,date_order=now.date_order,date_sep=now.date_sep}
 local today=now.epoch_sec//86400+(now.epoch_sec%86400+offset)//86400
 return F.clock(t,days~=today)
end
return F
