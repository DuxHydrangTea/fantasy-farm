from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/tree_2k_unzoom_2026-10-26'
src=Image.open(doc/'sheet_unzoom.png').convert('RGBA').crop((355,132,473,260));w,h=src.size
# Protect the white trunk interior explicitly. Never classify bark by whiteness.
protect=Image.new('1',(w,h));d=ImageDraw.Draw(protect)
d.polygon([(51,96),(60,96),(61,107),(64,110),(64,112),(58,113),(51,112),(50,108)],fill=1)
cell=src.copy();seen=set();q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)])
while q:
 x,y=q.popleft()
 if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
 seen.add((x,y));r,g,b,a=src.getpixel((x,y))
 if protect.getpixel((x,y)):continue
 bg=min(r,g,b)>=238
 shadow=y>=99 and 145<=min(r,g,b) and max(r,g,b)<=205 and max(r,g,b)-min(r,g,b)<=15
 if not(bg or shadow):continue
 cell.putpixel((x,y),(0,0,0,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
# Keep only the connected tree; discard detached matte remnants.
seen=set();components=[]
for y in range(h):
 for x in range(w):
  if (x,y) in seen or not cell.getpixel((x,y))[3]:continue
  todo=[(x,y)];seen.add((x,y));component=[]
  while todo:
   ax,ay=todo.pop();component.append((ax,ay))
   for bx,by in [(ax-1,ay),(ax+1,ay),(ax,ay-1),(ax,ay+1)]:
    if 0<=bx<w and 0<=by<h and (bx,by) not in seen and cell.getpixel((bx,by))[3]:seen.add((bx,by));todo.append((bx,by))
  components.append(component)
for comp in components:
 if len(comp)<20 and all(min(src.getpixel(pt)[:3])>140 and max(src.getpixel(pt)[:3])-min(src.getpixel(pt)[:3])<20 for pt in comp):
  for pt in comp:cell.putpixel(pt,(0,0,0,0))
sprite=cell.crop(cell.getbbox());out=Image.new('RGBA',(sprite.width+4,sprite.height+4));out.paste(sprite,(2,2));out.save(root/'assets/Trees/Extracted2K/green_birch.png')
scale=min(60/sprite.width,74/sprite.height);small=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)),Image.Resampling.NEAREST);frame=Image.new('RGBA',(64,80));frame.paste(small,((64-small.width)//2,76-small.height));frame.save(root/'assets/Trees/Variants64x80/green_birch.png')
review=Image.new('RGBA',(out.width*6,out.height*6),'#3b2c49');review.alpha_composite(out.resize(review.size,Image.Resampling.NEAREST));review.convert('RGB').save(doc/'birch_repaired_preview.png')
