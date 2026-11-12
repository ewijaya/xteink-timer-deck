#!/usr/bin/env python3
import json, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 report={'evidence':'HOST MOCK','device_tests_run':False,'steps':[],'milestone':'M7','status':'Failed'}
 (ROOT/'build').mkdir(exist_ok=True)
 (ROOT/'build/scripts.txt').write_text(''.join(str(p.relative_to(ROOT/'app'))+'\n' for p in sorted((ROOT/'app').rglob('*.lua'))))
 steps=[('toolchain',[sys.executable,'tools/setup_lua55.py']),('lint',[sys.executable,'tools/lint.py']),('icons',[sys.executable,'tools/icons.py','--check'])]
 lua='build/toolchain/lua-5.5.0/src/lua';luac='build/toolchain/lua-5.5.0/src/luac'
 steps += [('compile '+str(p),[luac,'-p',str(p)]) for p in sorted((ROOT/'app').rglob('*.lua'))]
 steps += [(p.stem,[lua,str(p)]) for p in sorted((ROOT/'tools/tests').glob('*_test.lua'))]
 steps += [('lint-negative-fixtures',[sys.executable,'tools/tests/lint_test.py'])]
 steps += [('previews',[sys.executable,'tools/preview.py'])]
 try:
  for name,cmd in steps:
   start=time.monotonic();p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
   report['steps'].append({'name':name,'status':'Passed' if p.returncode==0 else 'Failed','duration_sec':round(time.monotonic()-start,3),'output':p.stdout+p.stderr})
   print(name+': '+report['steps'][-1]['status'])
   if p.returncode:print(p.stdout+p.stderr);raise SystemExit(p.returncode)
  report['status']='Passed'
 finally:(ROOT/'build/gate-results.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
