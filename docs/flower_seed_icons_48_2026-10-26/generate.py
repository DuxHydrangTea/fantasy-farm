"""Meowa flower packet redesign; resume saved jobs instead of resubmitting."""
import argparse
import importlib.util
import json
from pathlib import Path
import time
import urllib.request
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('meowa_client',ROOT/'docs/meowa_saplings_2026-10-26/generate.py')
client = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)
ITEMS = json.loads((ROOT/'docs/flower_seed_icons_16x16_2026-10-26/manifest.json').read_text())['items']

def submit(limit=32):
    active = 0
    for item in ITEMS:
        n = item['index']
        status = OUT/f'{n:02d}_status.json'
        if (OUT/f'{n:02d}_submit.json').exists() and (not status.exists() or json.loads(status.read_text())['status'] not in ('success','failure','cancelled')):
            active += 1
    for item in ITEMS[:limit]:
        n = item['index']
        dest = OUT/f'{n:02d}_submit.json'
        if dest.exists():
            continue
        if active >= 2:
            return
        ref = OUT/f'{n:02d}_reference.png'
        Image.open(ROOT/item['file']).convert('RGBA').resize((192,192),Image.Resampling.NEAREST).save(ref)
        fields = {
            'prompt': 'Completely REDESIGN this flower seed packet inventory icon with MORE native pixel detail, for a cozy farming RPG. Species: '+item['flower']+'. Preserve the flower species and recognizable flower colour shown in the reference. Draw a single upright nearly-square kraft paper seed envelope, viewed straight from the front, creamy golden paper, tidy folded top seam and bottom seam, subtle warm brown side shading, thin dark brown pixel outline. The packet should occupy 40x42 native pixels centered on a 48x48 transparent canvas, with a clean 3 pixel margin. The large central botanical flower illustration should fill about 28x30 pixels: clearly recognizable petals, green leaves, one or two stems, readable flower silhouette. Add a restrained species-colour ribbon stripe near the top. No lettering, no symbols, no numbers, no watermark. IMPORTANT: reference is an OLD 16x16 design enlarged for visibility. Do NOT retain its coarse 16x16 pixel grid. This must be NEW art at 48x48 native pixel density with richer but disciplined shading, clear petal structure and crisp one-pixel edges. Work at 4x enlargement on a 192x192 canvas: each native pixel is exactly a 4x4 square block. Hard-edged opaque pixel clusters only, no antialiasing, no blur, no dithering, no painterly gradients, no 3D rendering. Isolate exactly one complete packet on transparent background. Do not crop the envelope. Match warm friendly RPG item art, not a flat UI tile.',
            'mode':'pixel','strict':'true','pixelation_method':'whole',
            'generation_provider':'image2_5','image2_quality':'medium','resolution':'1K',
            'remove_bg_method':'standard','job_name':f'Fantasy Farm 48px {item["flower"]} seed packet'
        }
        (OUT/f'{n:02d}_request.json').write_text(json.dumps(fields,indent=2),encoding='utf-8')
        try:
            result = client.request('/api/workflows/image_edit/run',fields,[('reference_images',ref)])
        except RuntimeError as exc:
            if 'HTTP 429' in str(exc):
                print('Service busy: waiting before new submissions.',flush=True)
                return
            raise
        dest.write_text(json.dumps(result,indent=2),encoding='utf-8')
        print('SUBMITTED',n,item['flower'],result['job_id'],flush=True)
        active += 1

def collect():
    complete = 0
    for item in ITEMS:
        n=item['index']
        submitted=OUT/f'{n:02d}_submit.json'
        if not submitted.exists():
            continue
        saved=OUT/f'{n:02d}_status.json'
        result=json.loads(saved.read_text()) if saved.exists() else None
        if not result or result['status'] not in ('success','failure','cancelled'):
            result=client.request('/api/jobs/'+json.loads(submitted.read_text())['job_id'])
            saved.write_text(json.dumps(result,indent=2),encoding='utf-8')
        if result['status'] in ('failure','cancelled'):
            raise RuntimeError(f'Job {n} failed: {result.get("error")}; do not resubmit automatically.')
        if result['status']=='success':
            dest=OUT/f'{n:02d}_raw.png'
            if not dest.exists():
                req=urllib.request.Request(result['result']['edited_path'],headers={'User-Agent':'Mozilla/5.0','Referer':'https://meowa.ai/'})
                with urllib.request.urlopen(req,timeout=45) as response:
                    dest.write_bytes(response.read())
                print('DOWNLOADED',n,item['flower'],result['result']['metadata'].get('actual_credit_cost'),flush=True)
            complete += 1
    return complete

def preview():
    board=Image.new('RGBA',(8*176,4*190),(43,49,55,255))
    draw=ImageDraw.Draw(board)
    for item in ITEMS:
        n=item['index']; path=OUT/f'{n:02d}_raw.png'
        if not path.exists(): continue
        im=Image.open(path).convert('RGBA').resize((48,48),Image.Resampling.NEAREST)
        x,y=((n-1)%8)*176,((n-1)//8)*190
        board.alpha_composite(im.resize((144,144),Image.Resampling.NEAREST),(x+16,y+3))
        draw.text((x+8,y+151),item['flower'],fill='white')
    board.save(OUT/'design_preview.png')

def run():
    for tick in range(150):
        done=collect()
        print('COMPLETE',done,'/32',flush=True)
        if done==32:
            preview(); return
        submit()
        time.sleep(12)
    raise RuntimeError('Time limit reached; resume with saved jobs.')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['sample','collect','run','preview'])
    action=parser.parse_args().action
    {'sample':lambda:submit(1),'collect':collect,'run':run,'preview':preview}[action]()
