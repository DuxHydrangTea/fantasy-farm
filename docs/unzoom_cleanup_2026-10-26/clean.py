from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
import json,zipfile
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/unzoom_cleanup_2026-10-26'
paths=[root/p for p in json.loads((doc/'paths.json').read_text())]
backup=doc/'before_cleanup.zip'
if not backup.exists():
 with zipfile.ZipFile(backup,'w',zipfile.ZIP_DEFLATED) as z:
  for p in paths:z.write(p,p.relative_to(root))
records=[]
for p in paths:
 im=Image.open(p).convert('RGBA');w,h=im.size;orig=im.copy();vehicle='Vehicles' in p.parts;tree='Trees' in p.parts
 # Flood from outside through transparent and exterior background/shadow colors.
 def removable(x,y):
  r,g,b,a=orig.getpixel((x,y))
  if a==0:return True
  if vehicle:
   return y>=h*.52 and abs(r-134)<=19 and abs(g-141)<=19 and abs(b-160)<=19 and 8<=b-r<=39
  if tree:
   return y>=h*.66 and 132<=min(r,g,b) and max(r,g,b)<=193 and max(r,g,b)-min(r,g,b)<=23
  # White matte at any height; neutral cast shadow restricted below building body.
  return min(r,g,b)>=230 or (y>=h*.65 and 118<=min(r,g,b) and max(r,g,b)<=235 and max(r,g,b)-min(r,g,b)<=12)
 q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)]);seen=set();removed=0
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
  seen.add((x,y))
  if not removable(x,y):continue
  if orig.getpixel((x,y))[3]:removed+=1
  im.putpixel((x,y),(0,0,0,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 im.save(p)
 records.append({'path':str(p.relative_to(root)),'size':[w,h],'removed_pixels':removed})
(doc/'changes.json').write_text(json.dumps(records,indent=2))
canvas=Image.new('RGB',(1200,((len(paths)+5)//6)*210),'#718576');d=ImageDraw.Draw(canvas)
for i,p in enumerate(paths):
 im=Image.open(p).convert('RGBA');im.thumbnail((190,180),Image.Resampling.NEAREST);x=i%6*200;y=i//6*210;canvas.paste(im,(x+(200-im.width)//2,y),im);d.text((x,y+180),str(i)+' '+p.stem[:23],fill='white')
canvas.save(doc/'after.png');print('Cleaned',len(paths),'sprites;',sum(r['removed_pixels'] for r in records),'pixels cleared')
