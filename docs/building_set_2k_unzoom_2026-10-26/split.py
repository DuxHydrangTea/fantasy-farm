from PIL import Image
from pathlib import Path
from collections import deque
import json,zipfile
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/building_set_2k_unzoom_2026-10-26';out=root/'assets/Buildings/Extracted/VillageSet';out.mkdir(parents=True,exist_ok=True)
im=Image.open(doc/'sheet_unzoom.png').convert('RGBA')
items=[('village_house',(0,0,142,183)),('restaurant_kitchen',(142,0,304,183)),('produce_warehouse',(304,0,520,183)),('seed_shop',(520,0,695,183)),('flower_shop',(0,184,153,386)),('blacksmith',(153,184,306,386)),('carpentry_workshop',(306,184,533,386)),('pet_shop',(533,184,695,386))]
records=[];preview=Image.new('RGBA',(224*4,224*2),'#8d9d8b')
for i,(key,bounds) in enumerate(items):
 cell=im.crop(bounds);w,h=cell.size;q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)]);seen=set()
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
  seen.add((x,y));r,g,b,a=cell.getpixel((x,y))
  if min(r,g,b)<240:continue
  cell.putpixel((x,y),(0,0,0,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 sprite=cell.crop(cell.getbbox());canvas=Image.new('RGBA',(sprite.width+4,sprite.height+4));canvas.paste(sprite,(2,2));canvas.save(out/(key+'.png'));preview.alpha_composite(canvas,((i%4)*224+(224-canvas.width)//2,(i//4)*224+(224-canvas.height)//2));records.append({'name':key,'size':list(canvas.size),'source_bounds':bounds})
preview.resize((896,448),Image.Resampling.NEAREST).save(doc/'preview.png');(doc/'sizes.json').write_text(json.dumps(records,indent=2))
with zipfile.ZipFile(doc/'buildings_8.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.glob('*.png')):z.write(p,p.name)
print(records)
