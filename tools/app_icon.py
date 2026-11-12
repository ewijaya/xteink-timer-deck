#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]
im=Image.new('1',(88,88),1);d=ImageDraw.Draw(im)
for box in [(23,7,77,67),(16,14,70,74),(9,21,63,81)]:
 d.rounded_rectangle(box,radius=6,fill=1,outline=0,width=3)
d.ellipse((17,29,55,67),outline=0,width=3)
d.line((36,48,36,35),fill=0,width=3);d.line((36,48,47,53),fill=0,width=3)
d.line((30,25,42,25),fill=0,width=3)
im.save(root/'app/assets/app_icon_s.png')
