import json, os, re, subprocess, tomllib, urllib.request, uuid
from pathlib import Path
root=Path('/home/dungnguyen/Projects/test-js')
out=root/'docs/street_shops_extract_2026-10-26'
out.mkdir(exist_ok=True)
env=os.environ.copy()
env['PIXELLAB_API_KEY']=tomllib.loads(Path('/home/dungnguyen/.codex/config.toml').read_text())['mcp_servers']['pixellab']['env']['AUTH_HEADER'].removeprefix('Bearer ')
def call(name,args=None):
    r=subprocess.run(['node',str(root/'.agents/skills/pixellab/scripts/pixellab.mjs'),name,json.dumps(args or {})],env=env,cwd=root,capture_output=True,text=True,timeout=70)
    r.check_returncode()
    d=json.loads(r.stdout)
    if 'error' in d: raise RuntimeError(d['error'])
    d=d.get('result',d)
    if d.get('isError'): raise RuntimeError(d)
    return d
def text(d): return '\n'.join(c.get('text','') for c in d.get('content',[]) if c.get('type')=='text')
print('BEFORE',text(call('get_balance')),flush=True)
for key in ['internet_cafe','grocery','restaurant','mini_market','laptop_repair']:
    path=root/'assets/Buildings/Extracted/StreetShops'/(key+'_cutout.png')
    url=re.search(r'https://api\.pixellab\.ai/v2/uploads/[^\s]+',text(call('get_upload_url'))).group()
    boundary='upload-'+uuid.uuid4().hex
    body=('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="source.png"\r\nContent-Type: image/png\r\n\r\n').encode()+path.read_bytes()+('\r\n--'+boundary+'--\r\n').encode()
    with urllib.request.urlopen(urllib.request.Request(url,data=body,headers={'Content-Type':'multipart/form-data; boundary='+boundary}),timeout=40) as r: ref=json.load(r)['ref']
    created=call('unzoom_image',{'image_url':ref,'quantize':-1})
    (out/(key+'-request.json')).write_text(json.dumps(created,indent=2))
    print(key,text(created),flush=True)
    job=re.search(r'(?:job_id|id):\s*([a-f0-9-]+)',text(created)).group(1)
    for attempt in range(4):
        result=call('get_image',{'job_id':job})
        (out/(key+'-result.json')).write_text(json.dumps(result,indent=2))
        t=text(result)
        if 'status: completed' in t:
            url=re.search(r'download:\s*(https://[^\s]+)',t).group(1)
            urllib.request.urlretrieve(url,root/'assets/Buildings/Extracted/StreetShops'/(key+'_unzoom.png'))
            print('SAVED',key,t,flush=True)
            break
        call('wait_for_jobs',{'timeout_seconds':20,'min_finished':1})
    else: raise RuntimeError('Job pending; do not regenerate: '+job)
print('AFTER',text(call('get_balance')),flush=True)
