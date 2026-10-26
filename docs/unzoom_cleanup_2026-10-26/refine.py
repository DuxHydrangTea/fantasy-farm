from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
import json
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/unzoom_cleanup_2026-10-26';paths=[root/p for p in json.loads((doc/'paths.json').read_text())]
for p in paths:
 im=Image.open(p).convert('RGBA');w,h=im.size;seen=set()
 # Remove disconnected neutral matte fragments, not colored fallen leaves or outlined props.
 for y in range(h):
  for x in range(w):
   if (x,y) in seen or not im.getpixel((x,y))[3]:continue
   q=[(x,y)];comp=[];seen.add((x,y))
   while q:
    xx,yy=q.pop();comp.append((xx,yy))
    for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
     if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and im.getpixel((nx,ny))[3]:seen.add((nx,ny));q.append((nx,ny))
   if min(pt[1] for pt in comp)>=h*.65 and len(comp)<=40 and all(min(im.getpixel(pt)[:3])>125 and max(im.getpixel(pt)[:3])-min(im.getpixel(pt)[:3])<42 for pt in comp):
    for pt in comp:im.putpixel(pt,(0,0,0,0))
 if 'Vehicles' in p.parts:
  for y in range(78,h):
   for x in range(w):
    r,g,b,a=im.getpixel((x,y))
    if a and min(r,g,b)>180 and max(r,g,b)-min(r,g,b)<45:im.putpixel((x,y),(0,0,0,0))
 im.save(p)
canvas=Image.new('RGB',(1200,((len(paths)+5)//6)*210),'#718576');d=ImageDraw.Draw(canvas)
for i,p in enumerate(paths):
 im=Image.open(p).convert('RGBA');im.thumbnail((190,180),Image.Resampling.NEAREST);x=i%6*200;y=i//6*210;canvas.paste(im,(x+(200-im.width)//2,y),im);d.text((x,y+180),str(i)+' '+p.stem[:23],fill='white')
canvas.save(doc/'after.png')
