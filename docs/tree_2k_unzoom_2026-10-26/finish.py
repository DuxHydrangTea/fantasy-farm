from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
import json
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/tree_2k_unzoom_2026-10-26';native=root/'assets/Trees/Extracted2K';standard=root/'assets/Trees/Variants64x80';native.mkdir(exist_ok=True)
im=Image.open(doc/'sheet_unzoom.png').convert('RGBA')
items=[('red_maple',0,0),('golden_aspen',1,0),('orange_oak',3,0),('blue_conifer',0,1),('purple_blossom',1,1),('brown_palm',2,1),('green_birch',3,1)];records=[]
for key,col,row in items:
 x0=round(col*im.width/4);x1=round((col+1)*im.width/4);y0=132 if row else 0;y1=im.height if row else 132
 cell=im.crop((x0,y0,x1,y1));w,h=cell.size;src=cell.copy();q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)]);seen=set()
 def removable(x,y):
  r,g,b,a=src.getpixel((x,y))
  return min(r,g,b)>=238 or (y>=h*.64 and min(r,g,b)>=153 and max(r,g,b)<=207 and max(r,g,b)-min(r,g,b)<=15)
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
  seen.add((x,y))
  if not removable(x,y):continue
  cell.putpixel((x,y),(0,0,0,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 # White background pockets between canopy/branches, enclosed by outlines.
 for y in range(h):
  for x in range(w):
   r,g,b,a=cell.getpixel((x,y))
   if a and min(r,g,b)>=248:cell.putpixel((x,y),(0,0,0,0))
 # Drop detached neutral JPEG/ground-mask specks; keep colored tree pixels.
 visited=set()
 for yy in range(h):
  for xx in range(w):
   if (xx,yy) in visited or not cell.getpixel((xx,yy))[3]:continue
   pending=[(xx,yy)];visited.add((xx,yy));component=[]
   while pending:
    ax,ay=pending.pop();component.append((ax,ay))
    for bx,by in [(ax-1,ay),(ax+1,ay),(ax,ay-1),(ax,ay+1)]:
     if 0<=bx<w and 0<=by<h and (bx,by) not in visited and cell.getpixel((bx,by))[3]:visited.add((bx,by));pending.append((bx,by))
   if len(component)<35 and all(min(cell.getpixel(pt)[:3])>145 and max(cell.getpixel(pt)[:3])-min(cell.getpixel(pt)[:3])<25 for pt in component):
    for pt in component:cell.putpixel(pt,(0,0,0,0))
 sprite=cell.crop(cell.getbbox());out=Image.new('RGBA',(sprite.width+4,sprite.height+4));out.paste(sprite,(2,2));out.save(native/(key+'.png'))
 scale=min(60/sprite.width,74/sprite.height,1);scaled=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)),Image.Resampling.NEAREST);frame=Image.new('RGBA',(64,80));frame.paste(scaled,((64-scaled.width)//2,76-scaled.height));frame.save(standard/(key+'.png'))
 records.append({'key':key,'native_size':list(out.size),'game_canvas':[64,80],'scale_to_game':scale})
# White birch requires a separate exterior-only mask and protected root.
import runpy
runpy.run_path(str(doc/'repair_birch.py'))
# Review native-size cutouts at 3x nearest-neighbor, on colored matte for alpha inspection.
preview=Image.new('RGBA',(4*132,2*144),'#718576')
for i,(key,_,_) in enumerate(items):
 tree=Image.open(native/(key+'.png'));preview.alpha_composite(tree,(i%4*132+(132-tree.width)//2,i//4*144+140-tree.height))
preview.resize((1056,576),Image.Resampling.NEAREST).convert('RGB').save(doc/'preview.png')
# Dedicated sheet for these seven new variants.
sheet=Image.new('RGBA',(256,160))
for i,(key,_,_) in enumerate(items):sheet.paste(Image.open(standard/(key+'.png')),(i%4*64,i//4*80))
sheet.save(standard/'trees_2k_sheet_4x2.png')
for key,_,_ in items:
 for folder in [native,standard]:
  with Image.open(folder/(key+'.png')) as tree:assert tree.mode=='RGBA' and tree.getbbox() and tree.getextrema()[3][0]==0
(doc/'sizes.json').write_text(json.dumps(records,indent=2));print(records)
