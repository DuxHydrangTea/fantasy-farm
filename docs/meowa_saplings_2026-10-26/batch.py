"""Submit and retrieve the remaining sapling edits, one saved job per species."""
import argparse
import json
import urllib.request
import time
from PIL import Image, ImageDraw
from generate import ROOT, OUT, request

SPECIES = {
    'autumn_maple': 'Autumn Maple: orange, golden-red leaves with a few maple leaf tips',
    'blue_conifer': 'Blue Conifer: icy cyan-blue needles, short pointed triangular evergreen crown',
    'brown_palm': 'Brown Palm: a few arched ochre and brown palm fronds around a small central stem',
    'evergreen_spruce': 'Evergreen Spruce: deep green needles in a tiny triangular tiered conifer crown',
    'flowering_cactus': 'Flowering Cactus: tiny upright green cactus with two short side arms and one pink-red blossom, no woody trunk',
    'golden_aspen': 'Golden Aspen: golden yellow leaves, narrow upright leaf crown and slender light stem',
    'golden_birch': 'Golden Birch: yellow-gold delicate leaf clusters and a slender pale cream trunk',
    'magic_blue': 'Magic Blue Tree: vivid azure and cyan star-like leaves with a few violet accents, brown stem',
    'orange_oak': 'Orange Oak: broad rounded lobed orange leaf crown with warm golden highlights, short brown stem',
    'palm': 'Palm: bright green arched palm fronds, tiny slender warm brown stem',
    'pink_blossom': 'Pink Blossom: a tiny rounded crown of soft pink flowers with pale pink highlights and brown stem',
    'purple_blossom': 'Purple Blossom: lilac and purple flower clusters with pale violet highlights and brown stem',
    'red_maple': 'Red Maple: scarlet and crimson pointed maple foliage, deep red shadows, short brown stem',
    'willow': 'Willow: fresh yellow-green leaves in tiny downward drooping clusters around a slender brown stem',
}

def download(result, dest):
    url = result['result']['edited_path']
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://meowa.ai/'})
    with urllib.request.urlopen(req, timeout=45) as response:
        dest.write_bytes(response.read())

def submit():
    template = json.loads((OUT / 'trial2_request.json').read_text())
    active = 0
    for n in SPECIES:
        sf = OUT / (n + '_submit.json')
        st = OUT / (n + '_status.json')
        if sf.exists() and (not st.exists() or json.loads(st.read_text())['status'] not in ('success','failure','cancelled')):
            active += 1
    for name, details in SPECIES.items():
        if name == 'autumn_maple':
            continue
        dest = OUT / (name + '_submit.json')
        if dest.exists():
            continue
        if active >= 2:
            return
        fields = dict(template)
        fields['prompt'] = (
            'Transform the tiny sapling in image 1 into ONE ' + details + '. '
            'Image 2 is only a species shape and colour reference, NOT the target maturity or detail level. '
            'Keep image 1 style: very sparse cozy farming inventory pixel art, warm shading, clean opaque pixel clusters, '
            'same light direction, native pixel density and modest saturation. Image 1 is a 32x32 icon enlarged 4 times '
            'with nearest-neighbour. Every original pixel is a crisp 4x4 block. Keep that grid. '
            'The entire young sapling should occupy about 50-65 pixels width and 80 pixels height on a 128x128 canvas, '
            'centered with the base at y=108. Keep the complete plant visible. Adapt its silhouette to the species, '
            'while keeping it young with few leaves/fronds/branches and readable at 32x32. '
            'Transparent background. No mature tree, no pot, no scene, no ground shadow, no text, no border, '
            'no blur, no smooth gradients, no antialiasing. Exactly one plant.'
        )
        fields['job_name'] = 'Fantasy Farm ' + name + ' sapling icon'
        (OUT / (name + '_request.json')).write_text(json.dumps(fields, indent=2), encoding='utf-8')
        ref = ROOT / 'assets/Trees/Variants64x80' / (('spruce' if name == 'evergreen_spruce' else name) + '.png')
        try:
            result = request('/api/workflows/image_edit/run', fields, [('reference_images', OUT / 'oak_icon_128.png'), ('reference_images', ref)])
        except RuntimeError as exc:
            if 'HTTP 429' in str(exc):
                print('Rate limited; wait for existing jobs before resuming.', flush=True)
                return
            raise
        dest.write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(name, result, flush=True)
        active += 1

def collect():
    for name in SPECIES:
        submit_file = OUT / ('trial2_submit.json' if name == 'autumn_maple' else name + '_submit.json')
        if not submit_file.exists():
            continue
        saved = OUT / (name + '_status.json')
        result = json.loads(saved.read_text()) if saved.exists() else None
        if not result or result['status'] not in ('success', 'failure', 'cancelled'):
            submitted = json.loads(submit_file.read_text())
            result = request('/api/jobs/' + submitted['job_id'])
            saved.write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(name, result['status'], result.get('error'), flush=True)
        if result['status'] == 'success':
            dest = OUT / (name + '_raw128.png')
            if not dest.exists():
                download(result, dest)

def preview():
    board = Image.new('RGBA', (7*144, 2*180), (49,52,58,255))
    draw = ImageDraw.Draw(board)
    for i, name in enumerate(SPECIES):
        path = OUT / (name + '_raw128.png')
        if not path.exists():
            continue
        im = Image.open(path).convert('RGBA')
        im = im.resize((32,32), Image.Resampling.NEAREST)
        board.alpha_composite(im.resize((128,128), Image.Resampling.NEAREST), ((i%7)*144+8,(i//7)*180+5))
        draw.text(((i%7)*144+8,(i//7)*180+143), name, fill='white')
    board.save(OUT / 'contact_preview.png')

def run():
    for _ in range(90):
        collect()
        if all((OUT / (n + '_raw128.png')).exists() for n in SPECIES):
            preview()
            print('All 14 icons downloaded.', flush=True)
            return
        submit()
        time.sleep(10)
    raise RuntimeError('Generation run reached time limit. Resume using saved jobs.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['submit','collect','preview','run'])
    args = parser.parse_args()
    {'submit':submit,'collect':collect,'preview':preview,'run':run}[args.action]()
