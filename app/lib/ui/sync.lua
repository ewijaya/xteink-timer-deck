local S=require('lib.ui.strings');local W=require('lib.ui.widgets')
local U={}
function U.action(a,h)
 local ctx=a.ctx
 if h.action=='sync' then
  local result=ctx.files:read('timerdeck-import-result.txt',0,16384)
  local pages={};local text=result or '';while #text>0 do local _,_,used=a.fonts[22]:layout(text,440,360);assert(used and used>0);pages[#pages+1]=text:sub(1,used);text=text:sub(used+1) end;a:push({kind='sync',result=result or '',result_pages=pages})
 elseif h.action=='export' then
  local text=require('lib.core.importer').export(a.state)
  if ctx.files:write('timerdeck-export.txt',text) then a:message(S.exported) else a:message(S.file_error) end
 elseif h.action=='import' then
  ctx.budget:extend()
  local text=ctx.files:read('timerdeck-import.txt',0,16385)
  if not text then a:message(S.import_missing);return true end
  local candidate,result=require('lib.core.importer').propose(a.state,text,ctx.hash:crc32(text),a.sec)
  if candidate and not a:commit(candidate,false) then result=S.save_error;candidate=nil end
  local written=ctx.files:write('timerdeck-import-result.txt',result)
  if not written then ctx.log:error('E-IMPORT-RESULT');a:message(candidate and S.import_result_error or S.file_error)
  elseif candidate then a.page.result=result;a:message(S.import_ok)
  else a:message(result=='DUPLICATE' and S.DUPLICATE or S.import_failed) end
  ctx.gc:collect();a:plan()
 else return false end
 return true
end
function U.draw(a,g)
 W.top(a,g,S.sync,true);W.text(a,g,20,112,a.ctx.files.path,26)
 g:text_box(20,180,440,360,a.page.result_pages and a.page.result_pages[(a.page.offset or 0)+1] or a.page.result or '',{font=a.fonts[22],color=a.ink})
 W.pager(a,g,a.page.offset or 0,math.max(1,#(a.page.result_pages or {})))
 W.button(a,g,0,712,240,88,S.export,'export');W.button(a,g,240,712,240,88,S.import,'import')
end
return U
