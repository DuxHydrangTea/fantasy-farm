from PIL import Image
from pathlib import Path
from collections import deque
import json,zipfile
root=Path('/home/dungnguyen/Projects/test-js');out=root/'assets/Vehicles/Unzoom';doc=root/'docs/vehicle_unzoom_2026-10-26'
im=Image.open(doc/'sheet_unzoom.png').convert('RGBA')
keys=[['pickup_white','pickup_blue','pickup_red','pickup_gray','utility_pickup_white'],['sedan_green','sedan_red','sedan_blue','sedan_orange','sedan_purple'],['box_truck_yellow','box_truck_blue','box_truck_orange','box_truck_white','box_truck_green'],['police_sedan','police_suv','police_van','sedan_dark','police_sedan_alt'],['suv_black','suv_white','suv_gray','suv_red','suv_blue']]
# Bounds lie in empty gutters between silhouettes.
xs=[0,68,137,206,275,344];ys=[0,46,78,120,157,197]
sheet=Image.new('RGBA',(96*5,64*5));records=[]
for row in range(5):
 for col in range(5):
  key=keys[row][col];cell=im.crop((xs[col],ys[row],xs[col+1],ys[row+1]));w,h=cell.size
  # Border-connected light neutral background only; darker cast shadows stay.
  q=deque([(x,y) for y in range(h) for x in range(w) if x in (0,w-1) or y in (0,h-1)]);seen=set()
  while q:
   x,y=q.popleft()
   if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
   seen.add((x,y));r,g,b,a=cell.getpixel((x,y))
   if r<188 or g<198 or b<202 or max(r,g,b)-min(r,g,b)>30:continue
   cell.putpixel((x,y),(r,g,b,0));q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
  bbox=cell.getbbox();sprite=cell.crop(bbox);sw,sh=sprite.size
  canvas=Image.new('RGBA',(96,64));canvas.paste(sprite,((96-sw)//2,56-sh));canvas.save(out/(key+'.png'));sheet.paste(canvas,(col*96,row*64))
  records.append({'name':key,'visible_size':[sw,sh],'canvas':[96,64]})
sheet.save(out/'vehicles_sheet_5x5.png');Image.alpha_composite(Image.new('RGBA',sheet.size,'#8d9d8b'),sheet).resize((960,640),Image.Resampling.NEAREST).save(doc/'preview.png');(doc/'sizes.json').write_text(json.dumps(records,indent=2))
with zipfile.ZipFile(doc/'vehicles_25.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.glob('*.png')):z.write(p,p.name)
print(records)
