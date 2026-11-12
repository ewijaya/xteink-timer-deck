local M=require('lib.core.model')
local Store={}
function Store.read_backup(ctx)
 local raw,err=ctx.storage:read('deck.bak')
 if not raw then return nil,err end
 local crc,json=raw:match('^TDB1\n(-?%d+)\n(.*)$')
 if not json or tonumber(crc)~=ctx.hash:crc32(json) then return nil,'invalid' end
 local state=ctx.json:decode(json)
 if type(state)~='table' or state.v~=1 or not M.valid(state) then return nil,'invalid' end
 return state
end
function Store.load(ctx,sec)
 local state=ctx.state
 if type(state)=='table' and type(state.v)=='number' and state.v>1 then return nil,'blocked' end
 if M.valid(state) then return state,'ok' end
 local backup,err=Store.read_backup(ctx)
 if backup then return backup,'restored' end
 if type(state)=='table' and next(state)==nil and err=='not_found' then return M.new(sec),'new' end
 return nil,'recovery'
end
function Store.commit(ctx,candidate,previous)
 if not M.valid(candidate) then return nil,'invalid' end
 if previous.rev==2147483647 then return nil,'overflow' end
 candidate.rev=previous.rev+1;ctx.state=candidate
 local ok,err=ctx:save_state();if not ok then ctx.state=previous;return nil,err end
 return true
end
function Store.backup(ctx,state)
 local raw,err=ctx.json:encode(state);if not raw then return nil,err end
 return ctx.storage:write('deck.bak','TDB1\n'..ctx.hash:crc32(raw)..'\n'..raw)
end
return Store
