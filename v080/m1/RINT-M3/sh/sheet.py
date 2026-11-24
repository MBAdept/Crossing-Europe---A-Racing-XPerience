"""sheet.py <out.jpg> <ab jpg>... : stacks A/B pictures vertically at 3/4 size."""
import sys
from PIL import Image
ims = [Image.open(p) for p in sys.argv[2:]]
w, h = ims[0].size
sh = Image.new('RGB', (w, h * len(ims)))
for i, im in enumerate(ims):
    sh.paste(im, (0, i * h))
sh.resize((w * 3 // 4, h * len(ims) * 3 // 4)).save(sys.argv[1], quality=85)
