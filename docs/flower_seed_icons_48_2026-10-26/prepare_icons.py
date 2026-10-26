"""Finalize the Meowa redesigns on a true 48x48 grid, with no smoothing."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw
from generate import ROOT,OUT,ITEMS

target=ROOT/'assets/Icons/seeds/flowers48'
target.mkdir(parents=True,exist_ok=True)
sheet=Image.new('RGBA',(8*48,4*48))
preview=Image.new('RGBA',(8*176,4*190),(43,49,55,255))
draw=ImageDraw.Draw(preview)
records=[]
for item in ITEMS:
    n=item['index']
    source=OUT/f'{n:02d}_raw.png'
    image=Image.open(source).convert('RGBA')
    assert image.size==(192,192),(n,image.size)
    image=image.resize((48,48),Image.Resampling.NEAREST)
    alpha=image.getchannel('A').point(lambda a:255 if a>=128 else 0)
    # Limit accidental generated gradient/noise colours without dithering.
    image=image.convert('RGB').quantize(colors=64,dither=Image.Dither.NONE).convert('RGBA')
    image.putalpha(alpha)
    bounds=image.getbbox()
    assert bounds and bounds[0]>0 and bounds[1]>=0 and bounds[2]<48 and bounds[3]<=48,(n,bounds)
    # Shared baseline and margin; a nearly full-height packet stays large in shop slots.
    packet=image.crop(bounds)
    scale=min(40/packet.width,42/packet.height)
    packet=packet.resize((max(1,round(packet.width*scale)),max(1,round(packet.height*scale))),Image.Resampling.NEAREST)
    icon=Image.new('RGBA',(48,48))
    icon.alpha_composite(packet,((48-packet.width)//2,45-packet.height))
    dest=target/Path(item['file']).name
    icon.save(dest)
    assert set(icon.getchannel('A').get_flattened_data())=={0,255}
    assert len({rgb[:3] for rgb in icon.get_flattened_data() if rgb[3]})<=64
    sheet.alpha_composite(icon,(((n-1)%8)*48,((n-1)//8)*48))
    x,y=((n-1)%8)*176,((n-1)//8)*190
    preview.alpha_composite(icon.resize((144,144),Image.Resampling.NEAREST),(x+16,y+3))
    draw.text((x+8,y+152),item['flower'],fill='white')
    preview.alpha_composite(icon,(x+120,y+140))
    status=json.loads((OUT/f'{n:02d}_status.json').read_text())
    records.append({'index':n,'flower':item['flower'],'file':dest.relative_to(ROOT).as_posix(),'size':[48,48], 'bounds':icon.getbbox(),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'job_id':status['job_id'],'credits':status['result']['metadata']['actual_credit_cost'],'in_game':n<=10})
assert len(records)==32 and len({r['sha256'] for r in records})==32
sheet.save(target/'flower_seed_icons_48x48_sheet.png')
preview.save(OUT/'final_icons_preview.png')
total=sum(r['credits'] for r in records)+json.loads((OUT/'sheet_status.json').read_text())['result']['metadata']['actual_credit_cost']
(OUT/'manifest.json').write_text(json.dumps({'provider':'Meowa','palette_max':64,'native_size':[48,48],'actual_credits':total,'shared_sheet_credits':5,'items':records},indent=2),encoding='utf-8')
print('Prepared 32 distinct 48x48 transparent icons; credits:',total)
