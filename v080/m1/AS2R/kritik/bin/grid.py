"""AS2R: grid of tiles with their names.  usage: grid.py <out.jpg> <cols> <scale> <png> [<png> ...]"""
import os
import sys

from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

out, cols, scale = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
ims = []
for p in sys.argv[4:]:
    im = Image.open(p).convert("RGB")
    if scale != 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    ims.append(K.caption(im, os.path.basename(p)[:-4], 13))
K.save_jpg(K.grid(ims, cols), out, 88)
print(out)
