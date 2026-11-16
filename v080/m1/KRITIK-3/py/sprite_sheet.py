# Montage of the Arcade sprites of the nature sets on a sky-like background (for looking at the designs).
import sys, os
from PIL import Image, ImageDraw
root = sys.argv[1]; out = sys.argv[2]
names = ['tree_oak','tree_birch','tree_beech','tree_poplar','tree_olive','tree_pine','tree_spruce','tree_cypress','tree_palm',
         'bush_round','bush_low','heather','rock_a','rock_b','cliff']
ims = [Image.open(os.path.join(root, 'assets/sprites/props', n + '.png')).convert('RGBA') for n in names]
h = 420
W = sum(im.width for im in ims) + 10 * len(ims) + 10
sheet = Image.new('RGB', (W, h + 30), (150, 175, 200))
x = 10
d = ImageDraw.Draw(sheet)
for n, im in zip(names, ims):
    sheet.paste(im, (x, h - im.height), im)
    d.text((x, h + 8), n, fill=(0, 0, 0))
    x += im.width + 10
sheet.save(out)
print(sheet.size)
