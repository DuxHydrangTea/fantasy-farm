from PIL import Image
from pathlib import Path
from collections import deque
import json,zipfile
root=Path('/home/dungnguyen/Projects/test-js');out=root/'docs/vehicle_2k_unzoom_2026-10-26/ready';out.mkdir(exist_ok=True);doc=root/'docs/vehicle_2k_unzoom_2026-10-26'
im=Image.open(doc/'sheet_unzoom.png').convert('RGBA')
keys=[['pickup_white_classic','pickup_white_lifted','service_pickup_red','pickup_blue_sport','pickup_black_custom'],['pickup_green','pickup_red','pickup_rusty','pickup_orange_custom','pickup_black_custom_alt'],['pickup_white_classic_alt','pickup_white_lifted_alt','service_pickup_red_alt','pickup_blue_sport_alt','pickup_black_sport'],['pickup_green_alt','pickup_white_offroad','service_pickup_rusty','pickup_gray_sport','pickup_black_sport_alt'],['pickup_yellow','pickup_orange_offroad','service_pickup_red_ladder','pickup_blue_gray','pickup_black_lowered']]
# Bounds lie in empty gutters between silhouettes.
xs=[0,138,277,415,553,691];ys=[0,92,155,234,306,382]
sheet=Image.new('RGBA',(128*5,96*5));records=[]
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
  canvas=Image.new('RGBA',(128,96));canvas.paste(sprite,((128-sw)//2,88-sh));canvas.save(out/(key+'.png'));sheet.paste(canvas,(col*128,row*96))
  records.append({'name':key,'visible_size':[sw,sh],'canvas':[128,96]})
sheet.save(out/'vehicles_sheet_5x5.png');Image.alpha_composite(Image.new('RGBA',sheet.size,'#8d9d8b'),sheet).resize((1280,960),Image.Resampling.NEAREST).save(doc/'preview.png');(doc/'sizes.json').write_text(json.dumps(records,indent=2))
with zipfile.ZipFile(doc/'vehicles_25.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.glob('*.png')):z.write(p,p.name)
print(records)
