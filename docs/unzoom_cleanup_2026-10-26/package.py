from pathlib import Path
from PIL import Image
import json,zipfile,shutil,io
root=Path('/home/dungnguyen/Projects/test-js');doc=root/'docs/unzoom_cleanup_2026-10-26';paths=[root/p for p in json.loads((doc/'paths.json').read_text())]
def archive(dst,files,relative=root):
 with zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(files):z.write(p,p.relative_to(relative))
def preview(files,dst,cols=4,cell=(224,224)):
 cw,ch=cell;sheet=Image.new('RGBA',(cols*cw,((len(files)+cols-1)//cols)*ch),'#718576')
 for i,p in enumerate(files):
  im=Image.open(p).convert('RGBA');im.thumbnail((cw-8,ch-8),Image.Resampling.NEAREST);sheet.alpha_composite(im,(i%cols*cw+(cw-im.width)//2,i//cols*ch+(ch-im.height)//2))
 sheet.convert('RGB').save(dst)
# Rebuild both shared atlases without changing canvas sizes or frame positions.
tree=root/'assets/Trees/Variants64x80';keys=json.loads((root/'docs/tree_variants_64x80_2026-10-26/keys.json').read_text());sheet=Image.new('RGBA',(256,160))
for i,key in enumerate(keys):sheet.paste(Image.open(tree/(key+'.png')),(i%4*64,i//4*80))
sheet.save(tree/'trees_sheet_4x2.png')
vehicle=root/'assets/Vehicles/Unzoom';vdoc=root/'docs/vehicle_2k_unzoom_2026-10-26';records=json.loads((vdoc/'sizes.json').read_text());sheet=Image.new('RGBA',(640,480))
for i,r in enumerate(records):sheet.paste(Image.open(vehicle/(r['name']+'.png')),(i%5*128,i//5*96))
sheet.save(vehicle/'vehicles_sheet_5x5.png')
for p in vehicle.glob('*.png'):shutil.copy2(p,vdoc/'ready'/p.name)
preview([vehicle/(r['name']+'.png') for r in records],vdoc/'preview.png',5,(256,192))
preview([tree/(key+'.png') for key in keys],root/'docs/tree_variants_64x80_2026-10-26/preview.png',4,(128,160))
village=root/'assets/Buildings/Extracted/VillageSet';bdoc=root/'docs/building_set_2k_unzoom_2026-10-26'
for p in village.glob('*.png'):shutil.copy2(p,bdoc/'buildings_8'/p.name)
preview(sorted(village.glob('*.png')),bdoc/'preview.png')
for sub,df in [('StreetShops','street_shops_extract_2026-10-26'),('FarmStreetShops','farm_street_shops_extract_2026-10-26')]:preview(sorted((root/'assets/Buildings/Extracted'/sub).glob('*unzoom.png')),root/'docs'/df/'preview.png',5,(340,360))
archive(vdoc/'vehicles_25.zip',list(vehicle.glob('*.png')),vehicle)
archive(bdoc/'buildings_8.zip',list(village.glob('*.png')),village)
archive(root/'docs/tree_variants_64x80_2026-10-26/trees_64x80.zip',list(tree.glob('*.png')),tree)
archive(root/'docs/trees_and_vehicles_saved_2026-10-26.zip',list(tree.glob('*.png'))+list(vehicle.glob('*.png')))
# Refresh matching entries in older building archive, preserving unrelated buildings.
old=root/'docs/buildings_saved_2026-10-26.zip';tmp=old.with_suffix('.tmp.zip')
with zipfile.ZipFile(old) as src,zipfile.ZipFile(tmp,'w',zipfile.ZIP_DEFLATED) as dst:
 for name in src.namelist():
  candidate=root/name
  dst.writestr(name,candidate.read_bytes() if candidate in paths else src.read(name))
tmp.replace(old)
# Superseded low-resolution village export now points to current cleaned buildings.
archive(root/'docs/building_set_unzoom_2026-10-26/buildings_8.zip',list(village.glob('*.png')),village)
shutil.copy2(bdoc/'preview.png',root/'docs/building_set_unzoom_2026-10-26/preview.png')
archive(doc/'all_unzoom_cleaned.zip',paths+[tree/'trees_sheet_4x2.png',vehicle/'vehicles_sheet_5x5.png'])
with zipfile.ZipFile(doc/'before_cleanup.zip') as z:
 checks=[]
 for p in paths:
  before=Image.open(io.BytesIO(z.read(str(p.relative_to(root))))).convert('RGBA');after=Image.open(p).convert('RGBA');assert before.size==after.size
  assert after.getextrema()[3][0]==0 and after.getbbox()
  a=list(before.getdata());b=list(after.getdata());assert all(y==x or y[3]==0 for x,y in zip(a,b))
  checks.append({'path':str(p.relative_to(root)),'removed_pixels':sum(x[3]>0 and y[3]==0 for x,y in zip(a,b)),'dimensions':list(after.size)})
(doc/'verification.json').write_text(json.dumps(checks,indent=2))
(doc/'report.md').write_text('''# Cleanup of all delivered Unzoom sprites

53 sprites updated: 20 buildings, 8 trees, 25 vehicles. Removed exterior matte backgrounds and neutral ground shadows with region-limited, exterior-connected masks; removed isolated neutral matte specks. Internal shading, source colors, canvas sizes and sprite positions preserved. Colored props and leaves retained.

All 53 verified: RGBA with transparency, nonempty silhouettes, original dimensions, retained pixels exactly equal to original RGB/alpha (only deletion, no redraw). Visually reviewed overview and close views of tree trunk, building base and wheels. JPEG fringe pixels may still vary along object edges; no artificial detail reconstruction.

Refreshed tree/vehicle atlases, current downloadable ZIPs, shared tree-and-vehicle archive, and relevant entries in the saved building archive. Source images and raw API outputs remain diagnostic originals. before_cleanup.zip is a recovery copy, not a deliverable.

No API calls or generation credits used for cleanup. Balance last checked: 31.60.
''')
print('Verified 53 sprites; rebuilt atlases, previews and ZIP deliverables.')
