from PIL import Image
from pathlib import Path
from collections import deque
import json,zipfile
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/building_set_unzoom_2026-10-26';out=root/'assets/Buildings/Extracted/VillageSet';out.mkdir(parents=True,exist_ok=True)
im=Image.open(doc/'sheet_unzoom.png').convert('RGBA')
items=[('village_house',(0,0,70,90)),('restaurant_kitchen',(70,0,150,90)),('produce_warehouse',(150,0,257,90)),('seed_shop',(257,0,344,90)),('flower_shop',(0,91,76,194)),('blacksmith',(76,91,151,194)),('carpentry_workshop',(151,91,264,194)),('pet_shop',(264,91,344,194))]
records=[];preview=Image.new('RGBA',(112*4,112*2),'#8d9d8b')
for i,(key,bounds) in enumerate(items):
 cell=im.crop(bounds);w,h=cell.size;q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)]);seen=set()
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
  seen.add((x,y));r,g,b,a=cell.getpixel((x,y))
  if min(r,g,b)<240:continue
  cell.putpixel((x,y),(0,0,0,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 sprite=cell.crop(cell.getbbox());canvas=Image.new('RGBA',(sprite.width+4,sprite.height+4));canvas.paste(sprite,(2,2));canvas.save(out/(key+'.png'));preview.alpha_composite(canvas,((i%4)*112+(112-canvas.width)//2,(i//4)*112+(112-canvas.height)//2));records.append({'name':key,'size':list(canvas.size),'source_bounds':bounds})
preview.resize((896,448),Image.Resampling.NEAREST).save(doc/'preview.png');(doc/'sizes.json').write_text(json.dumps(records,indent=2))
with zipfile.ZipFile(doc/'buildings_8.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.glob('*.png')):z.write(p,p.name)
print(records)
