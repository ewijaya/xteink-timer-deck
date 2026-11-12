local C=require('lib.core.const');local F=require('lib.core.format');local M=require('lib.core.model');local H=require('lib.core.chains')
local S=C.COPY;local E=S.import_errors
local I={}
local function trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
local function number(s,lo,hi)
 if not s or not s:match('^%d+$') or #s>10 then return nil end
 local n=tonumber(s);if math.type(n)~='integer' or n<lo or n>hi then return nil end;return n
end
function I.duration(s)
 s=trim(s):lower();local n=number(s,1,C.MAX_SEC);if n then return n end
 if s:find(':',1,true) then
  local parts={};for v in (s..':'):gmatch('(.-):') do parts[#parts+1]=v end
  if #parts~=2 and #parts~=3 then return nil end
  local total=0
  for idx,v in ipairs(parts) do local value=number(v,0,idx==1 and C.MAX_SEC or 59);if not value or total>(C.MAX_SEC-value)//60 then return nil end;total=total*60+value end
  return total>0 and total or nil
 end
 local units={d={1,86400},h={2,3600},m={3,60},s={4,1}};local last,total,pos=0,0,1
 while pos<=#s do
  local first,finish,digits,unit=s:find('(%d+)([dhms])',pos)
  if not first or trim(s:sub(pos,first-1))~='' then return nil end
  local spec=units[unit];local value=number(digits,0,C.MAX_SEC)
  if not value or spec[1]<=last or value>(C.MAX_SEC-total)//spec[2] then return nil end
  total=total+value*spec[2];last=spec[1];pos=finish+1
  if trim(s:sub(pos))=='' then break end
 end
 return total>0 and total or nil
end
local function optional_number(s,lo,hi,default) if not s or s=='' then return default end;return number(s,lo,hi) end
local function named(s,names,default,lo)
 if s==nil or s=='' then return default end
 local n=number(s,lo,#names-1+lo);if n then return n end
 for idx,name in ipairs(names) do if s:lower()==name:lower() then return idx-1+lo end end
end
local function icon(s)
 if s==nil or s=='' then return 0 end
 local n=number(s,0,C.ICON_COUNT);if n then return n end
 return named(s,C.ICON_NAMES,0,1)
end
function I.parse(text,settings)
 if type(text)~='string' or #text>16384 then return nil,{E.size} end
 if not utf8.len(text) then return nil,{E.utf8} end
 local records,errors={},{};local active;local count=0
 local function error_line(line,why) errors[#errors+1]=S.line..line..': '..why end
 local function close()
  if active and (#active.definition.steps<2 or not H.total(active.definition)) then error_line(active.line,E.chain) end;active=nil
 end
 local input=text:gsub('\r\n','\n');if input:sub(-1)=='\n' then input=input:sub(1,-2) end
 for raw in (input..'\n'):gmatch('(.-)\n') do
  count=count+1;if count>C.IMPORT_LINES then error_line(count,'File exceeds '..C.IMPORT_LINES..' lines');break end
  local line=trim(raw)
  if line~='' and line:sub(1,1)~='#' then
   local f={};for v in (line..'|'):gmatch('(.-)|') do f[#f+1]=trim(v) end
   local kind=f[1]:lower();local name=F.name(f[2] or '')
   if kind~='step' then close() end
   if not name then error_line(count,'Invalid name')
   elseif kind=='timer' or kind=='step' then
    local dur=f[3] and I.duration(f[3]);local ic=icon(f[4]);local pat=named(f[5],C.PATTERNS,settings.pat,0);local cnt=optional_number(f[6],C.COUNT_MIN,C.COUNT_MAX,settings.cnt)
    if not dur or not ic or not pat or not cnt or #f>(kind=='timer' and 6 or 5) then error_line(count,E.fields)
    elseif kind=='timer' then records[#records+1]={line=count,action='CREATE',type=0,name=name,dur=dur,icon=ic,pat=pat,cnt=cnt}
    elseif not active then error_line(count,E.orphan)
    elseif #active.definition.steps>=C.CHAIN_STEPS then error_line(count,S.chain_max)
    else local d=active.definition;local id=d.next_step;d.steps[#d.steps+1]={id=id,name=name,sec=dur,icon=ic,pat=pat};d.next_step=id+1 end
   elseif kind=='stopwatch' then
    local ic=icon(f[3]);if not ic or #f>3 then error_line(count,E.watch) else records[#records+1]={line=count,action='CREATE',type=1,name=name,icon=ic} end
   elseif kind=='chain' then
    local rounds=optional_number(f[3],1,C.CHAIN_ROUNDS,1);local ic=icon(f[4])
    if not rounds or not ic or #f>4 then error_line(count,E.definition) else active={line=count,action='CH_SAVE',definition={name=name,icon=ic,rounds=rounds,next_step=1,steps={}}};records[#records+1]=active end
   else error_line(count,E.kind) end
  end
 end
 close();if #records==0 and #errors==0 then errors[1]=E.empty end
 if #errors>0 then return nil,errors end;return records
end
function I.propose(s,text,digest,now)
 for _,r in ipairs(s.rc) do if r.dig==digest and r.len==#text then return nil,'DUPLICATE' end end
 local records,errors=I.parse(text,s.set);if not records then return nil,table.concat(errors,'\n') end
 local candidate=M.copy(s);local result={}
 for _,record in ipairs(records) do
  local next_state,status=M.command(candidate,record,now)
  if status~='OK' then return nil,S.line..record.line..': '..(S[status] or S.INVALID) end
  candidate=next_state;result[#result+1]=S.line..record.line..': OK'
 end
 table.insert(candidate.rc,1,{dig=digest,len=#text,n=#records});if #candidate.rc>C.RECEIPTS then table.remove(candidate.rc) end
 assert(M.valid(candidate));return candidate,table.concat(result,'\n')
end
function I.export(s)
 local lines={'# Timer Deck definitions; importing adds Ready items.'}
 local keys={};for key in pairs(s.set) do keys[#keys+1]=key end;table.sort(keys);for _,key in ipairs(keys) do lines[#lines+1]='# '..key..' = '..s.set[key] end
 for _,v in ipairs(s.items) do
  if v.type==0 then lines[#lines+1]=table.concat({'timer',v.name,v.dur,v.icon,v.pat,v.cnt},' | ')
  else lines[#lines+1]=table.concat({'stopwatch',v.name,v.icon},' | ') end
 end
 for _,d in ipairs(s.ch.saved) do
  lines[#lines+1]=table.concat({'chain',d.name,d.rounds,d.icon},' | ')
  for _,v in ipairs(d.steps) do lines[#lines+1]=table.concat({'step',v.name,v.sec,v.icon,v.pat},' | ') end
 end
 return table.concat(lines,'\n')..'\n'
end
return I
