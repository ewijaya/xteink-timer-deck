-- HOST MOCK. Adapted from Daily Mass; contract api-2.18.2 §§2,6,7,9,10,12,13,15,23,24,28,29.
local J=require('json')
local R={}
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function int(x,lo,hi) return type(x)=='number' and x%1==0 and x>=lo and x<=hi end
local function text(s,n) return type(s)=='string' and #s<=n and utf8.len(s)~=nil end
local function readonly(v) return setmetatable({},{__index=v,__newindex=function() error('read-only snapshot') end,__pairs=function() return pairs(v) end}) end
local function font(px,system)
  local f={line_height=px,ascent=px-4,name='HOST MOCK',px=not system and px or nil}
  function f:measure(s,o)
    if not text(s,8192) then return nil,'invalid_argument' end
    local n=utf8.len((s:gsub('[%z\1-\31]','')));return n*(px//2)+(o and o.bold and n>0 and 1 or 0)
  end
  function f:layout(s,w,h,o)
    if not text(s,65536) or not int(w,1,32767) or not int(h,0,32767) then return nil,'invalid_argument' end
    o=o or {};local gap=o.line_gap or 0;local cap=math.max(1,(w-(o.bold and 1 or 0))//(px//2));local max=(h+gap)//(px+gap)
    local lines,pos,col=0,0,0
    for at,ch in utf8.codes(s) do
      if col==0 then if lines>=max then break end;lines=lines+1 end
      pos=at+#utf8.char(ch)-1;col=col+1
      if ch==10 or (o.wrap~='none' and col>=cap) then col=0 end
    end
    return lines,lines>0 and lines*px+(lines-1)*gap or 0,pos
  end
  return f
end
local function state_copy(v,depth)
  local t=type(v)
  if t=='string' then if not utf8.len(v) or v:find('%z') then return nil end;return v end
  if t=='number' then if v~=v or v==math.huge or v==-math.huge then return nil end;return math.tointeger(v) or v end
  if t=='boolean' then return v end
  if t~='table' or depth>6 then return nil end
  local out={}
  for k,x in pairs(v) do
    if type(k)=='string' or (type(k)=='number' and math.type(k)=='integer') then
      out[tonumber(k) and math.tointeger(tonumber(k)) or k]=state_copy(x,depth+1)
    end
  end
  return out
end
local function state_json(v)
  -- State supports mixed integer/string keys whereas ctx.json does not.
  local function names(t)
    if type(t)~='table' then return t end
    local n=0;for _ in pairs(t) do n=n+1 end
    local array=n==#t;for i=1,n do if t[i]==nil then array=false end end
    local o={};for k,x in pairs(t) do o[array and k or tostring(k)]=names(x) end;return o
  end
  return J:encode(names(v))
end
function R.new(options)
  local o=options or {};local c={state=copy(o.state or {}),kind=o.kind or 'main',timers={},elapsed=0,millis_start=o.millis or 0,
    now_value=copy(o.now or {valid=true,epoch_sec=1794452400,hour=12,minute=0,second=0,year=2026,month=11,day=12,weekday=4,hour12=false,date_order='ymd',date_sep='/',offset_minutes=540,revision=1}),
    logs={},waves={},deferred={},light_calls={},awake_calls={},budgets={},saved=0,save_attempts=0,font_requests={},alive=true,
    screen={width=480,height=800,gray_levels=2},api=copy(o.api or {major=2,minor=18}),device={model=o.model or 'x4_pro',firmware=o.firmware or 'HOST MOCK',lock_timer=o.lock_timer~=false},
    capabilities=copy(o.capabilities or {pattern=false,image_transform=false,ttf=false,ui=false,reader=false,dialog=true,frontlight=true,image_decode=false,nn=true}),
    clock={},fonts={},log={},gc={},perf={},budget={},json=J,hash={},input={keys={up=true,down=true,back=true},pointer=true}}
  c.persisted=state_copy(c.state,0);c.last_encoded=assert(state_json(c.persisted))
  function c.clock:now()
    if not c.snapshot then
      local v=copy(c.now_value)
      if not v.valid then for _,k in ipairs({'epoch_sec','local_sec','hour','minute','second','year','month','day','weekday'}) do v[k]=nil end end
      c.snapshot=readonly(v)
    end
    return c.snapshot
  end
  function c.clock:millis() return (c.millis_start+c.elapsed)&0x7fffffff end
  function c.fonts:size(px)
    assert(c.callback~='on_draw','font opening during draw');if not int(px,8,96) then return nil,'invalid_argument' end
    c.font_requests[#c.font_requests+1]=px;c.ttf=c.ttf or {};local n=0;for _ in pairs(c.ttf) do n=n+1 end
    if not c.ttf[px] and n>=(o.ttf_limit or 4) then local best=20;for _,v in ipairs({24,30}) do if math.abs(v-px)<math.abs(best-px) then best=v end end;return font(best,true) end
    c.ttf[px]=true;return font(px)
  end
  c.fonts.small=font(20,true);c.fonts.medium=font(24,true);c.fonts.large=font(30,true)
  function c:save_state()
    assert(self.callback~='on_draw','save during draw');self.save_attempts=self.save_attempts+1
    if type(self.state)~='table' then return nil,'invalid_argument' end
    local saved=state_copy(self.state,0);local raw=state_json(saved)
    if not raw or #raw>16384 then return nil,'limit_exceeded' end
    if self.save_failure then return nil,self.save_failure end
    if raw~=self.last_encoded then self.saved=self.saved+1;self.last_encoded=raw;self.persisted=saved end
    return true
  end
  function c:pending() local n=0;for _,t in ipairs(self.timers) do if not t.cancelled then n=n+1 end end;return n end
  function c:after(ms,fn)
    if self.kind=='lock' then return end
    if not int(ms,1,2147483647) then return nil,'invalid_argument' end
    assert(type(fn)=='function');if self:pending()>=32 then return nil,'limit_exceeded' end
    -- Remaining delays avoid absolute int32 overflow near millis wrap.
    local t={left=ms,fn=fn};function t:cancel() self.cancelled=true end
    self.timers[#self.timers+1]=t;return t
  end
  function c:advance(ms)
    assert(int(ms,0,2147483647))
    while ms>0 do
      local step=ms
      if not self.paused then for _,t in ipairs(self.timers) do if not t.cancelled then step=math.min(step,math.max(0,t.left)) end end end
      self.elapsed=(self.elapsed+step)&0x7fffffff
      self.fraction=(self.fraction or 0)+step%1000;local sec=step//1000+self.fraction//1000;self.fraction=self.fraction%1000
      if self.now_value.epoch_sec then
        local n=self.now_value.epoch_sec;self.now_value.epoch_sec=sec<=2147483647-n and n+sec or nil
      end
      local wall=self.now_value
      if wall.hour and wall.minute and wall.second then
        local time=wall.hour*3600+wall.minute*60+wall.second+sec;local days=time//86400
        wall.hour=time//3600%24;wall.minute=time//60%60;wall.second=time%60
        if wall.day and wall.month and wall.year then
          for _=1,days do
            local leap=wall.year%4==0 and (wall.year%100~=0 or wall.year%400==0)
            local lengths={31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31}
            wall.day=wall.day+1;if wall.day>lengths[wall.month] then wall.day=1;wall.month=wall.month+1;if wall.month>12 then wall.month=1;wall.year=wall.year+1 end end
          end
          if wall.weekday then wall.weekday=(wall.weekday+days)%7 end
        end
      end
      for _,t in ipairs(self.timers) do if not t.cancelled then t.left=math.max(0,t.left-step) end end
      ms=ms-step
      if not self.paused then self:due() end
    end
    self.snapshot=nil
  end
  function c:due()
    if self.paused or not self.alive then return end
    local pending=self.timers;self.timers={}
    for _,t in ipairs(pending) do
      if not t.cancelled then if t.left<=0 then t.cancelled=true;self:call('timer',t.fn) else self.timers[#self.timers+1]=t end end
    end
  end
  function c:call(name,fn,...)
    if not self.alive then return false,'inactive' end
    self.callback=name;self.snapshot=nil;local count=0
    debug.sethook(function() count=count+100 end,'',100)
    local ok,result=pcall(fn,self,...)
    debug.sethook();self.budgets[name]=math.max(self.budgets[name] or 0,count);self.callback=nil
    if not ok then self.error=result;self.alive=false;self.timers={};if self.frontlight then self.frontlight:reset() end end
    return ok,result
  end
  function c:invalidate(wave) assert(wave==nil or wave=='full');self.waves[#self.waves+1]=wave or 'partial' end
  function c:defer_full_refresh(ms) if not int(ms,1,60000) then return nil,'invalid_argument' end;self.deferred[#self.deferred+1]=ms end
  function c.budget:extend() if c.kind=='lock' or not c.callback or c.callback=='on_leave' then return nil,'inactive' end;return true end
  function c.device:display() return {dark=c.dark or false} end
  function c.device:battery() return copy(o.battery or {percent=80,charging=false}) end
  if o.keep_awake~=false then function c.device:keep_awake(ms)
    if c.kind=='lock' then return nil,'inactive' end
    if not int(ms,0,14400000) then return nil,'invalid_argument' end;c.awake_calls[#c.awake_calls+1]=ms
  end end
  function c.gc:count() return math.floor(collectgarbage('count')*1024) end
  function c.gc:collect() collectgarbage('collect') end
  function c.perf:info() return {cmd_count=c.last_canvas and c.last_canvas.command_count or 0,draw_us=0} end
  for _,level in ipairs({'info','warn','error'}) do c.log[level]=function(_,s) assert(type(s)=='string');c.logs[#c.logs+1]={level,s} end end
  function c.hash:crc32(s)
    if #s>1048576 then return nil,'limit_exceeded' end
    local crc=~0
    for i=1,#s do crc=crc~s:byte(i);for _=1,8 do crc=(crc>>1)~((crc&1)~=0 and 0xEDB88320 or 0) end end
    return ~crc
  end
  if c.kind=='main' and c.capabilities.frontlight then
    c.frontlight={};c.user_light=copy(o.light or {on=false,brightness=50,warmth=20});c.light=copy(c.user_light)
    function c.frontlight:get() return copy(c.light) end
    function c.frontlight:set(v)
      if (v.on~=nil and type(v.on)~='boolean') or (v.brightness~=nil and not int(v.brightness,0,100)) or (v.warmth~=nil and not int(v.warmth,0,100)) then return nil,'invalid_argument' end
      for k,x in pairs(v) do c.light[k]=x end;c.light_calls[#c.light_calls+1]={'set',copy(v),at=c.elapsed}
    end
    function c.frontlight:reset() c.light=copy(c.user_light);c.light_calls[#c.light_calls+1]={'reset',at=c.elapsed} end
  end
  if c.kind=='lock' then
    c.capabilities.nn=false;c.lock={reason=o.reason or 'first',elapsed_sec=o.elapsed_sec or 0,interval_sec=60}
    function c.lock:set_interval(s) if not int(s,30,3600) then return nil,'invalid_argument' end;self.interval_sec=s end
  end
  local function overlay(opts,fn)
    if c.kind=='lock' then return nil,'inactive' end
    if c.overlay then return nil,'busy' end
    c.overlay={opts=opts,fn=fn}
  end
  function c.input:text(opts,fn) return overlay(opts,fn) end
  if c.capabilities.dialog then
    c.dialog={}
    function c.dialog:confirm(opts,fn) if not text(opts.title or '',95) or not text(opts.message or '',191) then return nil,'limit_exceeded' end;return overlay(opts,fn) end
    function c.dialog:choose(opts,fn) if not opts.items or #opts.items<1 or #opts.items>7 then return nil,'invalid_argument' end;return overlay(opts,fn) end
    function c.dialog:toast(s) if not text(s,95) then return nil,'limit_exceeded' end;if c.kind=='lock' then return nil,'inactive' end;c.toast=s end
  end
  function c:quit() self.quitting=true end
  if c.kind=='main' and o.lockscreen~=false then
    c.lockscreen={}
    function c.lockscreen:is_default() return c.lock_default or false end
    function c.lockscreen:clear_default() c.lock_default=false end
    function c.lockscreen:set_default()
      if c.lock_default then return end
      return overlay({lock_default=true},function() end)
    end
  end
  c.storage=R.files(c,true,o.storage);c.files=R.files(c,false,o.files)
  -- Enforce receiver identity: a dot call must not silently shift arguments.
  for _,ns in ipairs({'clock','fonts','device','input','log','gc','perf','budget','hash','frontlight','dialog','lock','lockscreen','storage','files'}) do
    local object=c[ns]
    if object then
      for k,fn in pairs(object) do if type(fn)=='function' then
        object[k]=function(receiver,...) assert(receiver==object,'colon required: '..ns..':'..k);return fn(receiver,...) end
      end end
    end
  end
  return c
end
function R.files(c,private,backing)
  local data=backing or {};local f={path=not private and '/AppFiles/timerdeck' or nil}
  local function key(n)
    if type(n)~='string' or #n<1 or #n>(private and 64 or 128) or not utf8.len(n) or n:sub(1,1)=='.' or n:sub(-1)=='.' then return nil end
    if private then if n:find('[^a-z0-9._-]') then return nil end;return n end
    if n:find('[%z\1-\31\127/\\:*?"<>|~]') or n:sub(-1)==' ' then return nil end
    local stem=n:match('^[^.]+'):upper()
    if stem=='CON' or stem=='PRN' or stem=='AUX' or stem=='NUL' or stem:match('^COM[1-9]$') or stem:match('^LPT[1-9]$') then return nil end
    return n:lower()
  end
  local function check(n)
    assert(c.callback~='on_draw','file I/O during draw');f.created=true
    local k=key(n);if not k then return nil,'invalid_argument' end
    if f.failure then return nil,f.failure end;return k
  end
  function f:read(n,offset,len)
    local k,e=check(n);if not k then return nil,e end
    if not data[k] then return nil,'not_found' end
    if private then return data[k].value end
    offset=offset or 0;len=len or 65536
    if type(len)=='number' and len>65536 then return nil,'limit_exceeded' end
    if not int(offset,0,2147483647) or not int(len,1,65536) then return nil,'invalid_argument' end
    return data[k].value:sub(offset+1,offset+len)
  end
  local function write(n,s,append)
    local k,e=check(n);if not k then return nil,e end;assert(type(s)=='string')
    if #s>262144 then return nil,'limit_exceeded' end
    local count=0;for _ in pairs(data) do count=count+1 end
    if not data[k] and count>=512 then return nil,'limit_exceeded' end
    local v=(append and data[k] and data[k].value or '')..s
    data[k]={name=n,value=v};return true
  end
  function f:write(n,s) return write(n,s,false) end
  if not private then function f:append(n,s) return write(n,s,true) end end
  function f:exists(n) local k=check(n);return k~=nil and data[k]~=nil end
  function f:remove(n) local k,e=check(n);if not k then return nil,e end;data[k]=nil;return true end
  function f:size(n) local k,e=check(n);if not k then return nil,e end;return data[k] and #data[k].value or nil,data[k] and nil or 'not_found' end
  function f:list()
    assert(c.callback~='on_draw');f.created=true;if f.failure then return nil,f.failure end
    local out={};for _,v in pairs(data) do out[#out+1]=private and v.name or {name=v.name,size=#v.value} end
    table.sort(out,function(a,b) return (private and a or a.name)<(private and b or b.name) end);return out
  end
  function f:usage() local n,b=0,0;for _,v in pairs(data) do n=n+1;b=b+#v.value end;return {files=n,bytes=b,max_files=512,max_bytes=134217728} end
  return f
end
function R.canvas(c)
  local g={active=true,commands={},command_count=0,bytes=0}
  local argc={line=4,rect=4,circle=3,arc=5,text=2,text_box=4}
  for _,method in ipairs({'clear','line','rect','circle','arc','polyline','polygon','text','text_box'}) do
    g[method]=function(self,...)
      if not self.active then return nil,'inactive' end
      local a={...};local n=argc[method] or 0;local opts=a[#a];if type(opts)~='table' or method=='polyline' and #a==1 then opts={} end
      for i=1,n do assert(int(a[i],-32768,32767),'integer coordinate required') end
      for k,v in pairs(opts) do
        if k=='color' then assert(int(v,0,15)) elseif k=='line_width' then assert(int(v,1,255)) elseif k=='radius' then assert(int(v,0,255)) elseif k=='fill' then assert(type(v)=='boolean') end
      end
      if method=='clear' then assert(a[1]==nil or int(a[1],0,15)) end
      if method=='circle' or method=='arc' then assert(int(a[3],0,32767)) end
      if method=='arc' and (a[5]-a[4])%360==0 then return end
      if method=='polyline' or method=='polygon' then
        assert(#a[1]%2==0 and #a[1]>=(method=='polygon' and 6 or 4) and #a[1]<=256)
        for _,v in ipairs(a[1]) do assert(int(v,-32768,32767)) end
      end
      local count=1
      if method=='text' or method=='text_box' then
        local s=a[method=='text' and 3 or 5];assert(text(s,8192),'text limit/UTF-8');self.bytes=self.bytes+#s;assert(self.bytes<=65536)
        if method=='text_box' then count=assert((opts.font or c.fonts.medium):layout(s,a[3],a[4],opts)) end
      end
      self.command_count=self.command_count+count;assert(self.command_count<=1024,'command limit')
      -- Strip font functions from recorded JSON.
      local args={};for i,v in ipairs(a) do
        if type(v)=='table' and v.font then local t={};for k,x in pairs(v) do t[k]=k=='font' and {line_height=x.line_height,ascent=x.ascent} or x end;args[i]=t else args[i]=v end
      end
      self.commands[#self.commands+1]={method=method,args=args}
    end
  end
  function g:size() if not self.active then return nil,'inactive' end;return 480,800 end
  return setmetatable(g,{__index=function(_,k) error('unknown canvas method '..k) end})
end
function R.session(files,state,kind,options)
  options=options or {};options.state=state;options.kind=kind or 'main'
  local c=R.new(options)
  local env={};for _,k in ipairs({'assert','error','ipairs','pairs','next','pcall','xpcall','select','tonumber','tostring','type','setmetatable','getmetatable','rawget','rawset','rawequal','math','string','table','utf8','coroutine'}) do env[k]=type(_G[k])=='table' and copy(_G[k]) or _G[k] end
  local loaded={};c.loaded=loaded
  env.require=function(name)
    assert(not name:find('[/\\]'),'module names use dots');if loaded[name] then return loaded[name] end
    local path=name:gsub('%.','/')..'.lua';local source=assert(files[path],'missing script '..path)
    loaded[name]=assert(load(source,'@'..path,'t',env))() or true;return loaded[name]
  end
  c.env=env
  function c:event(name,...)
    local fn=self.env[name];local ok,result=true,nil
    if fn then ok,result=self:call(name,fn,...) end
    if self.overlay and not self.paused then self.paused=true;self:event('on_pause') end
    if self.quitting and self.alive then self:leave() end
    return ok,result
  end
  function c:draw()
    local g=R.canvas(self);self.last_canvas=g;self:event('on_draw',g);g.active=false;return g
  end
  function c:answer(answer)
    assert(self.overlay);local overlay=self.overlay;self.overlay=nil
    if overlay.opts.lock_default then self.lock_default=answer==true end
    self:event('on_resume');self:draw();self.paused=false;self:due()
    if self.alive then self:call('completion',overlay.fn,answer) end
  end
  function c:leave()
    if not self.alive then return end
    self.quitting=false;self.timers={};self.overlay=nil
    if self.kind=='main' then self:event('on_leave');self:save_state() end
    self.alive=false;if self.frontlight then self.frontlight:reset() end
  end
  c:call('top',function() assert(load(assert(files[c.kind=='lock' and 'lock.lua' or 'index.lua']),'@entry','t',env))() end)
  if c.alive then c:event('on_load') end
  return c
end
return R
