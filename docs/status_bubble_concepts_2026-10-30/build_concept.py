"""Compose unmodified PixelLab sprites into a review board; no game integration."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
RAW = BASE / 'raw'
OUT = BASE / 'preview'
OUT.mkdir(exist_ok=True)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)
def sprite(name):
    return Image.open(RAW / f'{name}_16.png').convert('RGBA')

def bubble(names):
    width = 12 + len(names) * 16 + (len(names) - 1) * 4
    im = Image.new('RGBA', (width, 27))
    d = ImageDraw.Draw(im)
    edge, cream = '#55392E', '#FFF1CF'
    mid = width // 2
    d.rounded_rectangle((0, 0, width-1, 22), radius=4, fill=edge)
    d.polygon([(mid-4, 20), (mid+4, 20), (mid, 26)], fill=edge)
    d.rounded_rectangle((1, 1, width-2, 21), radius=3, fill=cream)
    d.line((4, 1, width-5, 1), fill='#FFFBEB')
    d.line((4, 21, width-5, 21), fill='#DEC397')
    d.polygon([(mid-2, 21), (mid+2, 21), (mid, 24)], fill=cream)
    for i, name in enumerate(names):
        im.alpha_composite(sprite(name), (6 + i * 20, 3))
    return im

names = ['weeds', 'worm', 'sick', 'hungry', 'thirsty']
labels = ['CỎ DẠI', 'BỊ SÂU', 'BỊ BỆNH', 'ĐÓI', 'KHÁT']
notes = ['Sprite có sẵn trong game', 'Sâu xanh ăn lá', 'Mặt xanh · nhiệt kế', 'Mong được ăn', 'Lưỡi khô · giọt nước']
W, H = 1280, 1080
board = Image.new('RGBA', (W, H), '#EFE5CE')
d = ImageDraw.Draw(board)
d.rectangle((0,0,W,92), fill='#294739')
d.text((48,22), 'BUBBLE TRẠNG THÁI', font=font(32,True), fill='#FFF3D7')
d.text((1230,37), 'CONCEPT 01', anchor='ra', font=font(17,True), fill='#BED0AA')
d.text((48,111), 'Icon 16×16 + bubble nhỏ, viền nâu và nền kem ấm', font=font(20), fill='#55392E')
for i, (name,label,note) in enumerate(zip(names,labels,notes)):
    cx = 144 + i * 248
    d.text((cx,162),label,anchor='mm',font=font(19,True),fill='#55392E')
    tile = Image.new('RGBA',(16,16),'#E6D8B8')
    td = ImageDraw.Draw(tile)
    for y in range(0,16,2):
        for x in range(0,16,2):
            if (x+y)//2%2:td.rectangle((x,y,x+1,y+1),fill='#F8EED9')
    tile.alpha_composite(sprite(name))
    board.alpha_composite(tile.resize((128,128),Image.Resampling.NEAREST),(cx-64,194))
    d.text((cx,348),note,anchor='mm',font=font(14),fill='#77624B')
    b=bubble([name]);b.save(OUT/f'bubble_{name}.png')
    board.alpha_composite(b.resize((b.width*4,b.height*4),Image.Resampling.NEAREST),(cx-b.width*2,401))
    d.text((cx,533),'Trong bubble · ×4',anchor='mm',font=font(14),fill='#77624B')
    sprite(name).resize((128,128),Image.Resampling.NEAREST).save(OUT/f'{name}_8x.png')
d.line((48,575,1232,575),fill='#CDBB98',width=2)
d.text((48,604),'NHIỀU TRẠNG THÁI TRÊN CÙNG MỘT ĐỐI TƯỢNG',font=font(20,True),fill='#55392E')
plant = Image.open(ROOT/'assets/Crops/Crops.png').convert('RGBA').crop((64,0,80,32))
chicken = Image.open(ROOT/'assets/Animals/Chicken/Chicken_01.png').convert('RGBA').crop((0,224,32,256))
for cx, group, actor, caption in [(326,['weeds','worm'],plant,'Cây: cỏ dại + sâu'),(929,['sick','hungry','thirsty'],chicken,'Vật nuôi: bệnh + đói + khát')]:
    b=bubble(group);b.save(OUT/('bubble_'+'_'.join(group)+'.png'))
    board.alpha_composite(b.resize((b.width*4,b.height*4),Image.Resampling.NEAREST),(cx-b.width*2,700))
    actor=actor.crop(actor.getbbox())
    actor=actor.resize((actor.width*4,actor.height*4),Image.Resampling.NEAREST)
    d.ellipse((cx-45,816+actor.height,cx+45,828+actor.height),fill='#D1C09B')
    board.alpha_composite(actor,(cx-actor.width//2,820))
    d.text((cx,961),caption,anchor='mm',font=font(19,True),fill='#55392E')
d.text((48,1016),'Một bubble / đối tượng · Các trạng thái hiện cùng hàng · Chưa tích hợp vào gameplay',font=font(18),fill='#55392E')
d.text((48,1046),'4 icon PixelLab + sprite cỏ trong game. Bản phóng lớn dùng nearest-neighbor để giữ pixel sắc nét.',font=font(14),fill='#77624B')
board.convert('RGB').save(BASE/'concept_board.png')
print(BASE/'concept_board.png')
