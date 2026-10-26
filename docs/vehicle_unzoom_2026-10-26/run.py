import json,re,urllib.request,base64
from pathlib import Path
root=Path('/home/dungnguyen/Projects/test-js')
exec((root/'docs/unzoom_buildings_2026-10-26.py').read_text().split("print('BEFORE'")[0])
out=root/'docs/vehicle_unzoom_2026-10-26'
req=out/'request.json'
if not req.exists():
 import uuid
 url=re.search(r'https://api\.pixellab\.ai/v2/uploads/[^\s]+',text(call('get_upload_url'))).group()
 boundary='upload-'+uuid.uuid4().hex
 body=('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="source.png"\r\nContent-Type: image/png\r\n\r\n').encode()+Path('/tmp/codex-clipboard-813c50e5-2dd4-43f9-bacf-cb1faaddb7f1.png').read_bytes()+('\r\n--'+boundary+'--\r\n').encode()
 with urllib.request.urlopen(urllib.request.Request(url,data=body,headers={'Content-Type':'multipart/form-data; boundary='+boundary}),timeout=40) as r: ref=json.load(r)['ref']
 created=call('unzoom_image',{'image_url':ref,'quantize':-1})
 req.write_text(json.dumps(created,indent=2))
job=re.search(r'job_id:\s*([a-f0-9-]+)',text(json.loads(req.read_text()))).group(1)
result=call('get_image',{'job_id':job})
(out/'result.json').write_text(json.dumps(result,indent=2))
t=text(result)
print(t,flush=True)
if 'status: completed' not in t: raise RuntimeError('Pending; rerun same script')
url=re.search(r'download:\s*(https://[^\s]+)',t).group(1)
urllib.request.urlretrieve(url,out/'sheet_unzoom.png')
print(text(call('get_balance')),flush=True)
