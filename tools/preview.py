#!/usr/bin/env python3
"""Render HOST MOCK draw-command JSON. Fonts are approximations, not device evidence."""
import json, subprocess, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/previews'
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def render(frame):
 im=Image.new('RGB',(480,800),'white');d=ImageDraw.Draw(im)
 def color(v):return 'black' if v else 'white'
 for cmd in frame['commands']:
  m,a=cmd['method'],cmd['args'];o=a[-1] if a and isinstance(a[-1],dict) else {};fill=color(o.get('color',15));w=o.get('line_width',1)
  if m=='clear':d.rectangle((0,0,479,799),fill=color(a[0] if a else 0))
  elif m=='rect':
   x,y,ww,hh=a[:4];d.rounded_rectangle((x,y,x+ww-1,y+hh-1),radius=min(o.get('radius',0),ww//2,hh//2),fill=fill if o.get('fill') else None,outline=fill,width=w)
  elif m in ('circle','arc'):
   x,y,r=a[:3];box=(x-r,y-r,x+r-1,y+r-1)
   if m=='circle':d.ellipse(box,fill=fill if o.get('fill') else None,outline=fill,width=w)
   else:d.arc(box,start=a[3],end=a[4],fill=fill,width=w)
  elif m=='line':d.line(tuple(a[:4]),fill=fill,width=w)
  elif m in ('polyline','polygon'):
   points=list(zip(a[0][::2],a[0][1::2]));d.line(points+([points[0]] if m=='polygon' else []),fill=fill,width=w)
  elif m in ('text','text_box'):
   px=o.get('font',{}).get('line_height',24);font=ImageFont.truetype(FONT,px);x,y=a[:2];s=a[2] if m=='text' else a[4]
   if m=='text':
    width=d.textlength(s,font=font)
    x-=width/2 if o.get('align')=='center' else width if o.get('align')=='right' else 0
    y-=px/2 if o.get('valign')=='middle' else px if o.get('valign')=='bottom' else 0
    d.text((round(x),round(y)),s,font=font,fill=fill,anchor='lt')
   else:
    line='';lines=[]
    for word in s.split():
     if d.textlength((line+' '+word).strip(),font=font)>a[2] and line:lines.append(line);line=word
     else:line=(line+' '+word).strip()
    lines.append(line)
    for i,line in enumerate(lines[:a[3]//px]):d.text((x,y+i*px),line,font=font,fill=fill,anchor='lt')
 if frame.get('dark'):
  im=ImageOps.invert(im);d=ImageDraw.Draw(im)
 d.rectangle((0,784,479,799),fill='white');d.text((240,786),'HOST MOCK · NOT DEVICE EVIDENCE',font=ImageFont.truetype(FONT,11),fill='black',anchor='mt')
 return im
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 for old in OUT.glob('HOST-MOCK-*.png'):old.unlink()
 raw=subprocess.check_output([str(ROOT/'build/toolchain/lua-5.5.0/src/lua'),'tools/tests/preview.lua'],cwd=ROOT,text=True)
 (OUT/'commands.jsonl').write_text(raw)
 images=[]
 for line in raw.splitlines():
  frame=json.loads(line);im=render(frame);im.save(OUT/(frame['name']+'.png'));images.append(im)
 sheet=Image.new('RGB',(240*4,400*math.ceil(len(images)/4)),'#ddd')
 for i,im in enumerate(images):sheet.paste(im.resize((240,400)),((i%4)*240,(i//4)*400))
 sheet.save(OUT/'HOST-MOCK-contact-sheet.png')
 for start in range(0,len(images),12):
  group=images[start:start+12];page=Image.new('RGB',(960,400*math.ceil(len(group)/4)),'#ddd')
  for i,im in enumerate(group):page.paste(im.resize((240,400)),((i%4)*240,(i//4)*400))
  page.save(OUT/f'HOST-MOCK-contact-{start//12+1:02d}.png')
 print(f'HOST MOCK: {len(images)} previews')
if __name__=='__main__':main()
