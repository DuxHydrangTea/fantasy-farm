import json,re,urllib.request
from pathlib import Path
from PIL import Image
root=Path('/home/dungnguyen/Projects/test-js')
exec((root/'docs/unzoom_buildings_2026-10-26.py').read_text().split("print('BEFORE'")[0])
folder=root/'docs/tree_variants_64x80_2026-10-26'
records=[]
for key in json.loads((folder/'keys.json').read_text()):
 target=root/'assets/Trees/Variants64x80'/(key+'.png')
 if target.exists():
  print('ALREADY SAVED',key,flush=True);continue
 im=Image.open(folder/'unzoom_raw'/(key+'_unzoom.png')).convert('RGBA');w,h=im.size
 ys=[]
 for y in range(h//2,h):
  for x in range(w//2-4,w//2+5):
   r,g,b,a=im.getpixel((x,y))
   if max(r,g,b)<140 or (max(r,g,b)-min(r,g,b)>35 and min(r,g,b)<160):ys.append(y)
 dx=(64-w)//2;dy=70-max(ys)
 req=json.loads((folder/(key+'-request.json')).read_text());job=re.search(r'job_id:\s*([a-f0-9-]+)',text(req)).group(1)
 bg='#'+''.join(f'{v:02x}' for v in im.getpixel((0,0)))
 changes=[{'operation':'select_mask','layer':'image','frames':[1],'name':'background','selector':{'kind':'color','colors':[bg],'tolerance':12},'reason':'Remove neutral grey sheet background, preserve darker ground shadow.'},{'operation':'brush','layer':'image','frames':[1],'mask':'background','points':[[w//2,31],[w//2,63]],'size':64,'shape':'square','mode':'erase','reason':'Clear selected grey background including canopy gaps.'}]
 if key=='flowering_cactus':changes.append({'operation':'brush','layer':'image','frames':[1],'points':[[49,49]],'size':20,'shape':'square','mode':'erase','region':[42,44,w-1,54],'reason':'Remove decorative sparkle outside cactus silhouette.'})
 cleaned=call('pixelart_workbench',{'argv':['edit','job:'+job,'--changes',json.dumps(changes)],'mode':'low'})
 (folder/(key+'-clean.json')).write_text(json.dumps(cleaned,indent=2))
 cleanid=re.search(r'image_id:\s*([a-f0-9-]+)',text(cleaned)).group(1)
 recipe={'job':{'canvas':[64,80],'frame_count':1,'views':[{'id':'south','offset':[0,0]}],'source_bookends_exact':False,'body_palette_exact':True},'scene':{'layers':[{'id':'body','name':'Body - tree'}],'views':{'south':{'selections':{'all':{}},'nodes':{'tree':{'layer':'body','at':[dx,dy],'draw':[{'op':'copy','part':'all'}]}}}}}}
 result=call('pixelart_workbench',{'argv':['draw','--recipe',json.dumps(recipe),'--sources',json.dumps({'south':cleanid})],'mode':'low'})
 (folder/(key+'-canvas.json')).write_text(json.dumps(result,indent=2))
 t=text(result)
 print(key,t[:2600],flush=True)
 mid=re.search(r'image_id:\s*([a-f0-9-]+)',t)
 if mid:
  url='https://api.pixellab.ai/mcp/pixel-tools/'+mid.group(1)+'/image.png'
 else:
  links=re.findall(r'https://[^\s]+',t)
  url=next((v for v in links if v.endswith('.png')),None)
  if not url:
   drawing=re.search(r'drawing_id:\s*([a-f0-9-]+)',t)
   if not drawing:raise RuntimeError('No final PNG link; inspect saved result.')
   url='https://api.pixellab.ai/mcp/pixel-tools/'+drawing.group(1)+'/assets/south/full.png'
 urllib.request.urlretrieve(url,target)
 records.append({'key':key,'native':[w,h],'offset':[dx,dy],'root_baseline_y':70,'canvas':[64,80]})
 (folder/'placement.json').write_text(json.dumps(records,indent=2))
 print('FINAL SAVED',key,flush=True)
