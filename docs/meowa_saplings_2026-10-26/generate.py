"""Meowa icon trial; secrets only read from the Windows user environment."""
import argparse
import json
from pathlib import Path
import urllib.request
import urllib.error
import uuid
import winreg
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BASE = 'https://api.meowa.ai'

def key():
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as env:
        return winreg.QueryValueEx(env, 'MEOWA_API_KEY')[0]

def request(route, fields=None, files=None):
    headers = {'Authorization': 'Bearer ' + key()}
    data = None
    if fields is not None:
        boundary = 'meowa-' + uuid.uuid4().hex
        parts = []
        for name, value in fields.items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        for name, file in files or []:
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{file.name}"\r\nContent-Type: image/png\r\n\r\n'.encode() + file.read_bytes() + b'\r\n')
        parts.append(f'--{boundary}--\r\n'.encode())
        data = b''.join(parts)
        headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary
    req = urllib.request.Request(BASE + route, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f'HTTP {exc.code}: {exc.read().decode()[:1500]}') from None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['sample', 'status', 'trial2', 'status2'])
    args = parser.parse_args()
    if args.action in ['sample', 'trial2']:
        second = args.action == 'trial2'
        dest = OUT / ('trial2_submit.json' if second else 'sample_submit.json')
        if dest.exists():
            raise RuntimeError('Sample already submitted; inspect its saved job before retrying.')
        Image.open(ROOT / 'assets/Trees/Small_Oak_Tree.png').crop((32,24,64,56)).save(OUT / 'oak_icon_32.png')
        fields = {
            'prompt': 'Edit image 1 into ONE tiny Autumn Maple sapling inventory icon. Image 2 shows the mature species and is only a foliage colour and species reference. Preserve image 1 pixel-art style exactly: same sparse native pixel density, tiny readable silhouette, brown stem/root, warm shaded compact leaf clusters, same light direction and outline treatment. Change the foliage to autumn maple orange and golden red, with a few distinctive maple leaf tips. Keep the sapling young and small. Do not copy the mature tree size or detailed canopy. Exactly one isolated sapling centered, complete silhouette, transparent background. No text, no pot, no border, no UI, no ground, no cast shadow, no blur, no antialiasing. Keep the canvas 32x32 pixels.',
            'mode': 'pixel', 'strict': 'true', 'pixelation_method': 'whole',
            'generation_provider': 'image2_5', 'image2_quality': 'medium',
            'resolution': '1K', 'remove_bg_method': 'standard',
            'job_name': 'Fantasy Farm Autumn Maple sapling style trial',
        }
        primary = OUT / 'oak_icon_32.png'
        if second:
            primary = OUT / 'oak_icon_128.png'
            Image.open(OUT / 'oak_icon_32.png').resize((128,128), Image.Resampling.NEAREST).save(primary)
            fields['prompt'] = 'Recolour and reshape ONLY the leaf crown of image 1 into an Autumn Maple sapling with orange, red and golden maple leaves, using image 2 for species colours. Preserve the original stem, roots, plant position, scale, pixel grid, hard opaque pixel clusters, shading style and sparse detail. Image 1 is a 32x32 pixel icon enlarged 4 times with nearest-neighbour; every pixel is a crisp 4x4 block. Keep that exact pixel density and the same total sapling height (about 80 pixels of the 128x128 canvas). Do not shrink or make the plant more distant. No mature tree, no blur, no gradients, no pot, no shadow, no text. Transparent background, only one small sapling.'
            fields['job_name'] = 'Fantasy Farm Autumn Maple sapling enlarged reference trial'
        (OUT / ('trial2_request.json' if second else 'sample_request.json')).write_text(json.dumps(fields, indent=2), encoding='utf-8')
        result = request('/api/workflows/image_edit/run', fields, [('reference_images', primary), ('reference_images', ROOT / 'assets/Trees/Variants64x80/autumn_maple.png')])
        dest.write_text(json.dumps(result, indent=2), encoding='utf-8')
    else:
        second = args.action == 'status2'
        submitted = json.loads((OUT / ('trial2_submit.json' if second else 'sample_submit.json')).read_text())
        result = request('/api/jobs/' + submitted['job_id'])
        (OUT / ('trial2_status.json' if second else 'sample_status.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
