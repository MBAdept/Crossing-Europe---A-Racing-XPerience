from PIL import Image, ImageDraw, ImageFont

base = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/'
shots = base + 'w0/GEO/shots/'
out = base + 'deliver/GEO/GEO_kamera_seitenverhaeltnisse.png'
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 22)
panels = [
    ('t4_sp198_chase.png', 'T4 Saragossa – Pau km 198,8 bei 1280×720 (16:9), Horizont Zeile 324'),
    ('t4_sp198_1610_chase.png', 'T4 bei 1280×800 (16:10), Horizont Zeile 360 – oben und unten mehr Bild'),
    ('t4_sp198_219_chase.png', 'T4 bei 1680×720 (21:9), Horizont Zeile 324 – links und rechts mehr Bild'),
]
pad = 6
cap_h = 40
imgs = [Image.open(shots + f).convert('RGB') for f, _ in panels]
w = max(i.width for i in imgs) + 2 * pad
h = sum(i.height + cap_h + pad for i in imgs) + pad
sheet = Image.new('RGB', (w, h), (30, 30, 34))
d = ImageDraw.Draw(sheet)
y = pad
for im, (_, cap) in zip(imgs, panels):
    sheet.paste(im, (pad, y))
    y += im.height
    tw = d.textlength(cap, font=font)
    d.text((pad + (im.width - tw) / 2, y + 7), cap, fill=(240, 240, 240), font=font)
    y += cap_h + pad
sheet.save(out)
print(out, sheet.size)
