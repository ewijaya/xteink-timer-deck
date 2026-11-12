from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from lint import check
bad=['ctx.data = {}','ctx.clock.now()','ctx:save()','ctx:set_tick(1000)','io.open("x")',"require('lib/x')",'function on_draw(g) end','g = {}']
for s in bad:
 try:check(Path('app/index.lua'),s)
 except AssertionError:pass
 else:raise AssertionError('lint missed '+s)
for p,s in [('app/lib/core/a.lua','local ctx = {}'),('app/lock.lua',"require('lib.core.model')")]:
 try:check(Path(p),s)
 except AssertionError:pass
 else:raise AssertionError('lint missed '+s)
print('HOST MOCK negative lint fixtures passed')
