import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
from generate import ROOT,OUT,SOURCES

target=ROOT/'assets/Trees/Fruit64x80'
target.mkdir(parents=True,exist_ok=True)
board=Image.new('RGBA',(4*200,3*220),(43,49,55,255))
draw=ImageDraw.Draw(board);records=[]
for column,(species,source) in enumerate(SOURCES.items()):
    for row,state in enumerate(['source','ready','bare']):
        path=ROOT/'assets/Trees/Variants64x80'/f'{source}.png' if state=='source' else OUT/f'{species}_{"bare_v2" if state=="bare" else state}.png'
        image=Image.open(path).convert('RGBA')
        assert image.size==(64,80),(path,image.size)
        if state!='source':
            alpha=image.getchannel('A');assert alpha.getextrema()==(0,255)
            assert image.getbbox() is not None
            name=f'{species}_{"mature" if state=="bare" else "ready"}.png'
            dest=target/name
            image.save(dest)
            records.append({'species':species,'state':state,'source':source+'.png','file':dest.relative_to(ROOT).as_posix(),'size':[64,80],'bounds':image.getbbox(),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
        x,y=column*200,row*220
        board.alpha_composite(image.resize((128,160),Image.Resampling.NEAREST),(x+36,y+16))
        draw.text((x+10,y+185),f'{species} - {source if state=="source" else state}',fill='white')
assert len(records)==8 and len({r['sha256'] for r in records})==8
board.save(OUT/'comparison.png')
(OUT/'manifest.json').write_text(json.dumps({'provider':'PixelLab Pixen Edit','generations':12,'rejected_edits':4,'images':records},indent=2),encoding='utf-8')
print('Prepared 8 unique native 64x80 transparent PNGs.')
