"""Use the current Windows User PixelLab key, without exposing it in files/logs."""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import winreg

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
SOURCES={'apple':'orange_oak','peach':'pink_blossom','pear':'golden_aspen','cherry':'purple_blossom'}
DETAILS={
 'apple':'a mature apple tree with a broad rounded rich green canopy, warm brown trunk, and 10-14 clearly visible ripe red apples, each about 3 pixels across',
 'peach':'a mature peach tree with a rounded fresh green canopy, warm brown trunk, and 8-12 ripe orange-pink peaches with visible blush highlights, each 3-4 pixels across; replace the pink blossom mass with leaves',
 'pear':'a mature pear tree with an upright oval green canopy, natural warm brown trunk, and 8-12 ripe yellow-green pears with narrow necks and rounded bottoms, each 4 pixels tall',
 'cherry':'a mature cherry tree with a broad dark green canopy, warm brown trunk, and clusters of shiny ripe dark red cherries in pairs on slender stems; replace the purple blossom mass with green leaves'
}

def call(tool,args):
    env=dict(os.environ)
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER,'Environment') as handle:
        env['PIXELLAB_API_KEY']=winreg.QueryValueEx(handle,'PIXELLAB_API_KEY')[0]
    argfile=OUT/'current_call.json'
    argfile.write_text(json.dumps(args),encoding='utf-8')
    result=subprocess.run(['node',str(ROOT/'.agents/skills/pixellab/scripts/pixellab.mjs'),tool,'@'+str(argfile)],cwd=ROOT,env=env,capture_output=True,text=True,timeout=120,encoding='utf-8')
    if result.returncode:raise RuntimeError(result.stderr[:1000])
    parsed=json.loads(result.stdout)
    payload=parsed.get('result',parsed)
    if payload.get('isError') or parsed.get('error'):
        raise RuntimeError(json.dumps(parsed)[:1500])
    return parsed

def submit(name,state):
    dest=OUT/f'{name}_{state}_submit.json'
    if dest.exists():raise RuntimeError('Job already submitted; retrieve saved job instead.')
    if state=='ready':
        source=ROOT/'assets/Trees/Variants64x80'/f'{SOURCES[name]}.png'
        prompt='Edit this tree into '+DETAILS[name]+'. Keep its silhouette, branches, trunk-root position, 64x80 canvas, native pixels, clustered shading and cozy top-down style. Change only foliage and add fruit among leaves. Whole tree visible. Transparent, no ground shadow, no text, no blur.'
    elif state=='bare_v2':
        source=ROOT/'assets/Trees/Variants64x80'/f'{SOURCES[name]}.png'
        foliage={'apple':'rich medium green broad rounded leaves','peach':'fresh light green rounded leaves','pear':'upright oval yellow-green leaves','cherry':'broad spreading dark green leaves'}[name]
        prompt='Recolour the canopy of this tree to '+foliage+' and its trunk to warm natural brown. A plain leafy '+name+' tree between harvests: only green foliage and brown wood. Preserve the exact original silhouette, trunk, branches, root position, pixel grid, 64x80 size and clustered shading. Transparent background. Replace all flower petals or autumn colours with green leaves. No fruit, flowers, ground shadow, text or blur.'
    else:
        source=OUT/f'{name}_ready.png'
        prompt='Remove ALL fruit from this exact tree and replace only those fruit pixels with matching green foliage. This is the same tree immediately after harvest. Preserve the entire canopy silhouette, every trunk and branch, leaf colours, shading clusters, size and root position. Keep the 64x80 canvas and native pixel style. Transparent background, no ground shadow, no text, no blur. Do not redesign or shrink the tree.'
    assert len(prompt)<=500,(name,len(prompt))
    args={'description':prompt,'image_base64':base64.b64encode(source.read_bytes()).decode(),'width':64,'height':80,'no_background':True,'seed':726100+list(SOURCES).index(name)+(500 if state=='bare_v2' else 0)}
    (OUT/f'{name}_{state}_request.json').write_text(json.dumps({k:v for k,v in args.items() if k!='image_base64'}|{'source':str(source.relative_to(ROOT))},indent=2),encoding='utf-8')
    result=call('edit_image_pixen',args)
    dest.write_text(json.dumps(result,indent=2),encoding='utf-8')
    for content in result.get('result',{}).get('content',[]):
        if content['type']=='text':print(content['text'],flush=True)

def get(name,state):
    result=json.loads((OUT/f'{name}_{state}_submit.json').read_text())
    texts='\n'.join(c['text'] for c in result['result']['content'] if c['type']=='text')
    import re
    match=re.search(r'job[_ ]id["\s:=]+([\w-]+)',texts,re.I)
    if not match:raise RuntimeError('Inspect saved submission for job ID: '+texts[:1200])
    result=call('get_image',{'job_id':match[1]})
    (OUT/f'{name}_{state}_status.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    for content in result.get('result',{}).get('content',[]):
        if content['type']=='text':print(content['text'][:5000],flush=True)
        elif content['type']=='image':
            (OUT/f'{name}_{state}.png').write_bytes(base64.b64decode(content['data']))
            print('Saved inline image',name,state,flush=True)

def run(retry=False):
    for state in (['bare_v2'] if retry else ['ready','bare']):
        for name in SOURCES:
            if (OUT/f'{name}_{state}.png').exists():continue
            if not (OUT/f'{name}_{state}_submit.json').exists():submit(name,state)
            for attempt in range(12):
                call('wait_for_jobs',{'min_finished':1,'timeout_seconds':45})
                get(name,state)
                if (OUT/f'{name}_{state}.png').exists():break
            else:raise RuntimeError('Result still pending; resume saved job later.')
    result=call('get_balance',{})
    (OUT/'balance_after.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    for block in result['result']['content']:
        if block['type']=='text':print(block['text'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['submit','get','balance','run','retry']);parser.add_argument('name',nargs='?',choices=list(SOURCES));parser.add_argument('state',nargs='?',choices=['ready','bare','bare_v2'])
    args=parser.parse_args()
    if args.action in ['run','retry']:run(args.action=='retry')
    elif args.action=='balance':
        result=call('get_balance',{})
        for block in result['result']['content']:
            if block['type']=='text':print(block['text'])
    else:{'submit':submit,'get':get}[args.action](args.name,args.state)
