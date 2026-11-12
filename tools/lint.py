#!/usr/bin/env python3
"""API 2.18 device lint; Lua 5.5 compilation is a separate gate step."""
import re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def check(path,source):
 # Preserve strings for require checks, then mask strings/comments for identifiers.
 code=re.sub(r'--\[\[.*?\]\]|--[^\n]*','',source,flags=re.S)
 assert not re.search(r'''\brequire\s*\(?\s*['"][^'"]*[/\\]''',code),f'{path}: slash require'
 if path.name=='lock.lua':
  allowed={'lib.core.const','lib.core.format','lib.core.glance','lib.ui.digits'}
  for module in re.findall(r'''\brequire\s*\(?\s*['"]([^'"]+)''',code):assert module in allowed,f'{path}: lock module {module}'
 code=re.sub(r'''(['"])(?:\\.|(?!\1).)*?\1''','""',code)
 banned=[r'\b(?:io|os|debug|load|loadfile|dofile|print|collectgarbage)\b',r'\bctx\s*[.:]\s*(?:data|assets|display|layers|net|sys|system|set_tick|set_tick_rate|request_refresh|save)\b',r'\bctx(?:\s*\.\s*\w+)+\s*\(']
 for p in banned:assert not re.search(p,code),f'{path}: banned API {p}'
 if 'core' in path.parts:assert not re.search(r'\bctx\b',code),f'{path}: impure core'
 if re.search(r'\bon_draw\b',code):assert re.search(r'function\s+on_draw\s*\(\s*ctx\s*,\s*g\s*\)',code),f'{path}: draw signature'
 # A top-level g assignment exposes a stale/global canvas.
 assert not re.search(r'^g\s*=',code,re.M),f'{path}: global canvas'
def main():
 files=sorted((ROOT/'app').rglob('*.lua'))
 subprocess.run([sys.executable,str(ROOT/'tools/vendor/lualint55.py'),*map(str,files)],check=True)
 for p in files:check(p,p.read_text())
 print(f'HOST MOCK lint: {len(files)} scripts passed')
if __name__=='__main__':main()
