"""Meowa Asset Clone fallback for the remaining 23 designs, plus two style controls."""
import argparse
import json
import urllib.request
from PIL import Image
from generate import ROOT,OUT,ITEMS,client

def submit():
    dest=OUT/'sheet_submit.json'
    if dest.exists():raise RuntimeError('Sheet job exists; retrieve instead of resubmitting.')
    items=ITEMS[9:]+ITEMS[:2]
    files=[]
    for i,item in enumerate(items):
        source=OUT/f'{item["index"]:02d}_raw.png' if i>=23 else ROOT/item['file']
        image=Image.open(source).convert('RGBA').resize((48,48),Image.Resampling.NEAREST)
        ref=OUT/f'sheet_ref_{i:02d}.png'; image.save(ref)
        files.append(('reference_images',ref))
    descriptions='; '.join(f'cell {i+1}: {item["flower"]}' for i,item in enumerate(items))
    fields={
        'prompt':'REDESIGN this exact 5 columns by 5 rows grid of 25 FLOWER SEED PACKETS, left to right then top to bottom. '+descriptions+'. Keep each cell species and its reference flower colour. Use cells 24 and 25 as the NEW style anchors for ALL cells: creamy golden kraft paper envelopes with thin brown pixel outlines, folded top and bottom seams, a restrained species-colour ribbon near the top, large readable botanical flower picture, stems and green leaves. Exactly one complete isolated packet per cell, equal scale and centered. Each final icon must have 48x48 NATIVE PIXEL detail: about 40x42 pixel packet and 28x30 pixel flower art. Do not keep the coarse 16x16 grid of the older references. More petal structure, clean limited palette, crisp clusters. Match a cozy farming RPG inventory. No letters, no text, no numbers, no cast shadows, no background, no extra loose flowers, no pot, no smooth gradients, no blur or antialiasing. Preserve strict 5x5 layout for slicing and transparent gutters. Redesign the entire sheet consistently, not just recolour old pixels.',
        'clone_count':'25','mode':'pixel','generation_provider':'image2_5',
        'image2_quality':'low','resolution':'1K','remove_bg_method':'standard',
        'cell_width':'48','cell_height':'48','fit_mode':'pad','skip_prompt_optimization':'true'
    }
    (OUT/'sheet_request.json').write_text(json.dumps(fields,indent=2),encoding='utf-8')
    (OUT/'sheet_mapping.json').write_text(json.dumps(items,indent=2),encoding='utf-8')
    result=client.request('/api/workflows/asset_clone/run',fields,files)
    dest.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))

def status():
    submitted=json.loads((OUT/'sheet_submit.json').read_text())
    result=client.request('/api/jobs/'+submitted['job_id'])
    (OUT/'sheet_status.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['submit','status'])
    {'submit':submit,'status':status}[parser.parse_args().action]()
