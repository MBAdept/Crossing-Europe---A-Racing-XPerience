import json, sys
from PIL import Image
root = sys.argv[1]
out = sys.argv[2]
sm = json.load(open(root + '/assets/sprites/manifest.json'))
sets = sm['sets']
tiles = []
for sid in ['traffic/sports_red', 'traffic/van_white', 'police/de', 'player/kombi']:
    s = sets[sid]
    im = Image.open(root + '/assets/sprites/' + s['file']).convert('RGBA')
    cw, ch = s['cell']
    n = len(s['angles'])
    g = s['grid_cols']
    for layer in range(len(s['layers'])):
        for ai in [0, n // 2, n - 1]:
            i = layer * n + ai
            x, y = (i % g) * cw, (i // g) * ch
            c = im.crop((x, y, x + cw, y + ch))
            bg = Image.new('RGBA', c.size, (90, 140, 90, 255))
            bg.alpha_composite(c)
            tiles.append(bg.convert('RGB').resize((int(cw * 160 / ch), 160)))
    print(sid, im.size, 'alpha bottom rows:', [c.getpixel((cw // 2, ch - 1 - k))[3] for k in range(0, 8)])
W = 1600
rows = []
x = y = 0
canvas = Image.new('RGB', (W, 2600), (30, 30, 30))
rh = 0
for t in tiles:
    if x + t.width > W:
        x = 0
        y += rh + 4
        rh = 0
    canvas.paste(t, (x, y))
    x += t.width + 4
    rh = max(rh, t.height)
canvas = canvas.crop((0, 0, W, y + rh))
canvas.save(out)
# box sheet
s = sets['traffic/bus_blue']
im = Image.open(root + '/assets/sprites/' + s['file']).convert('RGBA')
print('bus sheet', im.size)
im2 = Image.new('RGBA', im.size, (90, 140, 90, 255))
im2.alpha_composite(im)
im2.convert('RGB').resize((im.size[0] // 2, im.size[1] // 2)).save(out.replace('.png', '_bus.png'))
s = sets['traffic/truck_blue']
im = Image.open(root + '/assets/sprites/' + s['file']).convert('RGBA')
print('truck sheet', im.size)
im2 = Image.new('RGBA', im.size, (90, 140, 90, 255))
im2.alpha_composite(im)
im2.convert('RGB').resize((im.size[0] // 2, im.size[1] // 2)).save(out.replace('.png', '_truck.png'))
