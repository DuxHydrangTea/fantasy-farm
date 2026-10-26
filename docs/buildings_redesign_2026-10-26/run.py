import json, os, re, subprocess, tomllib, urllib.request, uuid
from pathlib import Path
ROOT = Path('/home/dungnguyen/Projects/test-js')
FOLDER = ROOT / 'docs/buildings_redesign_2026-10-26'
cfg = tomllib.loads(Path('/home/dungnguyen/.codex/config.toml').read_text())
env = os.environ.copy()
env['PIXELLAB_API_KEY'] = cfg['mcp_servers']['pixellab']['env']['AUTH_HEADER'].removeprefix('Bearer ')
def call(tool, args=None):
    result = subprocess.run(['node', str(ROOT/'.agents/skills/pixellab/scripts/pixellab.mjs'), tool, json.dumps(args or {})], env=env, capture_output=True, text=True, timeout=75, cwd=ROOT)
    result.check_returncode()
    data = json.loads(result.stdout)
    if 'error' in data: raise RuntimeError(str(data['error']))
    return data.get('result', data)
def words(data):
    return '\n'.join(c.get('text','') for c in data.get('content',[]) if c.get('type')=='text')
records = json.loads((FOLDER/'jobs.json').read_text()) if (FOLDER/'jobs.json').exists() else []
specs = json.loads((FOLDER/'specs.json').read_text())
print('NEW KEY BALANCE:', words(call('get_balance')), flush=True)
for i, spec in enumerate(specs):
    target = ROOT/'assets/Buildings/Redesign'/ (spec['key']+'.png')
    if target.exists():
        print('ALREADY SAVED',spec['key'],flush=True)
        continue
    existing = next((r for r in records if r['key']==spec['key']),None)
    if existing:
        job = existing['job_id']
    else:
        upload_text = words(call('get_upload_url'))
        upload_url = re.search(r'https://api\.pixellab\.ai/v2/uploads/[^\s]+',upload_text).group()
        source = ROOT/spec['source']
        boundary = 'asset-'+uuid.uuid4().hex
        body = ('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="source.png"\r\nContent-Type: image/png\r\n\r\n').encode()+source.read_bytes()+ ('\r\n--'+boundary+'--\r\n').encode()
        req = urllib.request.Request(upload_url,data=body,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=40) as response: uploaded = json.load(response)
        created = call('edit_image_pixen',{'image_url':uploaded['ref'],'description':spec['prompt'],'no_background':True,'seed':261060+i})
        text = words(created)
        if created.get('isError'): raise RuntimeError(text)
        job = re.search(r'job_id:\s*([a-f0-9-]+)',text).group(1)
        records.append(dict(spec, job_id=job))
        (FOLDER/'jobs.json').write_text(json.dumps(records,indent=2))
    print('STARTED',spec['key'],job,flush=True)
    for attempt in range(30):
        call('wait_for_jobs',{'timeout_seconds':40,'min_finished':1})
        result = call('get_image',{'job_id':job})
        text = words(result)
        (FOLDER/(spec['key']+'-result.json')).write_text(json.dumps(result,indent=2))
        if 'status: completed' in text:
            link = re.search(r'download:\s*(https://[^\s]+)',text).group(1)
            urllib.request.urlretrieve(link,target)
            print('SAVED',spec['key'],flush=True)
            break
        if 'status: failed' in text or result.get('isError'): raise RuntimeError(text)
        print('PROCESSING',spec['key'],flush=True)
    else: raise RuntimeError('Generation still pending; resume existing job, do not duplicate.')
print('FINAL BALANCE:',words(call('get_balance')),flush=True)
