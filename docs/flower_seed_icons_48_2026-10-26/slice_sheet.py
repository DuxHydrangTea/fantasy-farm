"""Extract the 25 disconnected packets by alpha bounds, not an approximate grid."""
from collections import deque
import json
from PIL import Image
from generate import OUT

image=Image.open(OUT/'sheet_variant_2.png').convert('RGBA')
width,height=image.size
pixels=image.load();seen=set();components=[]
for y in range(height):
    for x in range(width):
        if (x,y) in seen or pixels[x,y][3]<128:continue
        queue=deque([(x,y)]);seen.add((x,y));points=[]
        while queue:
            a,b=queue.popleft();points.append((a,b))
            for xx,yy in ((a-1,b),(a+1,b),(a,b-1),(a,b+1)):
                if 0<=xx<width and 0<=yy<height and (xx,yy) not in seen and pixels[xx,yy][3]>=128:
                    seen.add((xx,yy));queue.append((xx,yy))
        if len(points)>100:
            components.append((min(a for a,b in points),min(b for a,b in points),max(a for a,b in points)+1,max(b for a,b in points)+1))
assert len(components)==25,components
components.sort(key=lambda b:(round(b[1]/55),b[0]))
mapping=json.loads((OUT/'sheet_mapping.json').read_text())
sheet_job=json.loads((OUT/'sheet_status.json').read_text())
report=[]
for box,item in zip(components,mapping):
    if item['index']<=9:continue
    crop=image.crop(box)
    factor=min(160/crop.width,168/crop.height)
    crop=crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.NEAREST)
    working=Image.new('RGBA',(192,192))
    working.alpha_composite(crop,((192-crop.width)//2,180-crop.height))
    n=item['index'];working.save(OUT/f'{n:02d}_raw.png')
    status={'status':'success','job_id':sheet_job['job_id'],'source':'sheet_variant_2.png','source_box':box,'result':{'metadata':{'actual_credit_cost':0,'shared_sheet_credit_cost':5,'species':item['flower']}}}
    (OUT/f'{n:02d}_status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
    report.append({'index':n,'flower':item['flower'],'box':box})
assert len(report)==23
(OUT/'sheet_slices.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Extracted 23 complete packets from Meowa sheet variant 2; two duplicate style controls excluded.')
