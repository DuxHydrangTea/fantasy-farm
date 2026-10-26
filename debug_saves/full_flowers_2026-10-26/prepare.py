import collections,copy,hashlib,json,re
from pathlib import Path

root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
source=Path('C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json')
raw=source.read_bytes();envelope=json.loads(raw)
assert hashlib.sha256(envelope['payload'].encode()).hexdigest()==envelope['sha256']
original=json.loads(envelope['payload']);data=copy.deepcopy(original)
definitions={}
for file in sorted((root/'flowers/definitions').glob('*.tres')):
    text=file.read_text();definitions[file.stem]=float(re.search(r'^growth_seconds = ([\d.]+)',text,re.M)[1])
ids=sorted(definitions);counts=collections.Counter()
for garden in data['flower_gardens']:
    rows=[]
    for y in range(10):
        for x in range(18):
            if data['honey_garden']['migrated'] and (x,y) in ((1,2),(4,2),(7,2)):continue
            name=ids[len(rows)%len(ids)];mature=data['saved_at']-1;planted=mature-definitions[name]
            rows.append({'cell':[x,y],'flower':name,'planted_at':planted,'growth_started_at':planted,'matures_at':mature,'progress':1.0})
            counts[name]+=1
    garden['flowers']=rows;garden['starter_flowers_added']=True
assert sum(counts.values())==177 and len(counts)==10
data['revision']=int(data['revision'])+1
assert all(data[k]==original[k] for k in original if k not in ('flower_gardens','revision'))
payload=json.dumps(data,separators=(',',':'),ensure_ascii=False)
candidate={'format':'fantasy_farm_save','payload':payload,'sha256':hashlib.sha256(payload.encode()).hexdigest()}
(out/'before_profile_local.json').write_bytes(raw)
(out/'profile_local.json').write_text(json.dumps(candidate,indent=2,ensure_ascii=False),encoding='utf-8')
(out/'source.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(raw).hexdigest(),'counts':dict(counts)},indent=2),encoding='utf-8')
print('Prepared 177 mature flowers; all non-flower save fields preserved.')
