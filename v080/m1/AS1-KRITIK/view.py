"""Quick look: crop game-camera tiles around the car and put them side by side (scratch viewing only).
usage: view.py <batch> <out.png> <zoom> <name>...   (names of game-camera tiles)"""
import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image
batch, out, zoom = sys.argv[1], sys.argv[2], float(sys.argv[3])
names = sys.argv[4:]
mt = K.meta(batch)
ims = []
for n in names:
    im = K.tile(n, batch)
    if mt[n]["size"][0] >= 1280 and "rect" in mt[n]:
        c, box = K.crop_rect(im, mt[n]["rect"], margin=0.1)
        im = c
    if zoom != 1:
        im = im.resize((int(im.width * zoom), int(im.height * zoom)), Image.NEAREST)
    ims.append(K.caption(im, n, 13))
cols = int(len(ims) ** 0.5 + 0.999)
K.grid(ims, cols).save(out)
print(out)
