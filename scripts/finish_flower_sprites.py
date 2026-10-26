"""Normalize actual PixelLab unzoom outputs; preserve native pixel edges and modular anchors."""
from pathlib import Path
from collections import deque
import json,re,hashlib
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/flower_sprites_2026-10-26'
DEST=ROOT/'assets/Flowers/Modular32x48'

def clean(raw,input_path):
 im=Image.open(raw).convert('RGBA');w,h=im.size;p=im.load()
 def background(x,y):
  r,g,b,a=p[x,y];return a==0 or (min(r,g,b)>=238 and max(r,g,b)-min(r,g,b)<=20)
 todo=deque();outside=set()
 for x in range(w):
  for y in [0,h-1]:
   if background(x,y):todo.append((x,y));outside.add((x,y))
 for y in range(h):
  for x in [0,w-1]:
   if background(x,y):todo.append((x,y));outside.add((x,y))
 while todo:
  x,y=todo.popleft()
  for nx,ny in [(x+dx,y+dy) for dx in (-1,0,1) for dy in (-1,0,1) if dx or dy]:
   if 0<=nx<w and 0<=ny<h and (nx,ny) not in outside and background(nx,ny):outside.add((nx,ny));todo.append((nx,ny))
 original_alpha=Image.open(input_path).convert('RGBA').getchannel('A').resize((w,h),Image.Resampling.NEAREST)
 # The source alpha also recovers holes enclosed between stems without deleting white petals.
 allowance=original_alpha
 for y in range(h):
  for x in range(w):
   if (x,y) in outside or (background(x,y) and allowance.getpixel((x,y))==0):p[x,y]=(0,0,0,0)
   else:
    r,g,b,a=p[x,y];p[x,y]=(r,g,b,255)
 bbox=im.getbbox();assert bbox
 return im.crop(bbox),bbox

def plant_frame(sprite):
 w,h=sprite.size;a=sprite.getchannel('A');points=[x for y in range(max(0,h-2),h) for x in range(w) if a.getpixel((x,y))]
 anchor=sum(points)/len(points) if points else w/2
 extent=max(anchor+.5,w-anchor-.5)
 scale=min(30/(2*max(1,extent)),46/h,1)
 nw,nh=max(1,round(w*scale)),max(1,round(h*scale))
 resized=sprite.resize((nw,nh),Image.Resampling.NEAREST)
 x=max(0,min(32-nw,round(16-(anchor+.5)*nw/w)))
 y=48-nh
 frame=Image.new('RGBA',(32,48));frame.alpha_composite(resized,(x,y))
 return frame,{'root_anchor':[16,47],'content_rect':[x,y,nw,nh],'scale':scale}

def run(partial=False):
 rows=json.loads((DOC/'inputs.json').read_text());DEST.mkdir(parents=True,exist_ok=True);entries=[];plants=[];pot=None
 for row in rows:
  stem='soil_pot' if row['kind']=='pot' else f"flower_{row['index']:02}"
  raw=DOC/'unzoom'/f'{stem}.png'
  if not raw.exists():
   if partial:continue
   raise RuntimeError(f'Missing PixelLab result {raw}')
  clean_sprite,box=clean(raw,ROOT/row['input'])
  slug=re.sub(r'[^a-z0-9]+','_',row['flower'].lower()).strip('_')
  if row['kind']=='plant':
   frame,extra=plant_frame(clean_sprite);filename=f"flower_{row['index']:02}_{slug}_mature.png";plants.append(frame)
  else:
   sw,sh=clean_sprite.size;scale=min(30/sw,20/sh,1);size=(max(1,round(sw*scale)),max(1,round(sh*scale)));sprite=clean_sprite.resize(size,Image.Resampling.NEAREST);frame=Image.new('RGBA',(32,20));frame.alpha_composite(sprite,((32-size[0])//2,20-size[1]));filename='terracotta_soil_pot_32x20.png';extra={'plant_anchor':[16,4],'content_size':size,'scale':scale};pot=frame
  path=DEST/filename;frame.save(path)
  job=json.loads((DOC/'jobs'/f'{stem}.json').read_text())
  entries.append({'index':row['index'],'name':row['flower'],'kind':row['kind'],'file':str(path.relative_to(ROOT)),'size':list(frame.size),'unzoom_job':job['job_id'],'unzoom_size':list(Image.open(raw).size),'unzoom_crop':box,**extra,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 if not partial:assert len(plants)==32 and pot is not None
 sheet=Image.new('RGBA',(256,192))
 for i,p in enumerate(plants):sheet.alpha_composite(p,((i%8)*32,(i//8)*48))
 sheet.save(DEST/'flowers_mature_32x48_sheet.png')
 # Contact sheet + assembled examples are only previews, never game sprite sources.
 preview=Image.new('RGB',(1152,1024),(40,48,55));d=ImageDraw.Draw(preview)
 for i,plant in enumerate(plants):
  x=(i%8)*144+8;y=(i//8)*224+8
  tile=Image.new('RGBA',(32,64));
  if pot is not None:tile.alpha_composite(pot,(0,44))
  tile.alpha_composite(plant)
  alone=plant.resize((96,144),Image.Resampling.NEAREST);preview.paste(alone,(x+12,y),alone)
  d.text((x,y+148),f"{i+1:02} {rows[i]['flower']}",fill=(249,229,197))
  thumb=tile.resize((32,64),Image.Resampling.NEAREST);preview.paste(thumb,(x+46,y+165),thumb)
 if pot is not None:
  pbig=pot.resize((128,80),Image.Resampling.NEAREST);preview.paste(pbig,(24,928),pbig)
 d.text((176,944),'Separate soil pot 32x20 | flowers 32x48 | pending jobs are listed in manifest',fill=(249,229,197))
 for row in rows:
  if row['kind']=='plant' and not any(e['index']==row['index'] for e in entries):
   i=row['index']-1;x=(i%8)*144+8;y=(i//8)*224+8
   d.text((x,y+80),f"{row['index']:02} {row['flower']}",fill=(249,229,197))
   d.text((x,y+100),'Pending PixelLab',fill=(169,173,178))
 if pot is None:d.text((24,952),'Pot: pending',fill=(169,173,178))
 preview.save(DOC/'preview-modular-flowers.png')
 (DOC/'manifest.json').write_text(json.dumps({'generator':'Codex image_gen concept, then PixelLab unzoom per sprite','pixellab_key_suffix':'5225','normalization':'White background flood removal with original alpha protection for white petals; crop actual unzoom result; nearest-neighbour proportional fit and transparent padding; no redraw.','plant_canvas':[32,48],'pot_canvas':[32,20],'plant_root':[16,47],'pot_plant_anchor':[16,4],'composition':'Pot at [0,44], flower at [0,0] on 32x64; plant layer above soil pot.','integrated_into_game':False,'pending':[r for r in rows if not any(e['index']==r['index'] for e in entries)],'items':entries},indent=2))
 print(f'Saved {len(plants)} mature flowers; soil pot: {"ready" if pot is not None else "pending"}; output: {DEST}')
if __name__=='__main__':
 import sys
 run(partial='--partial' in sys.argv)
