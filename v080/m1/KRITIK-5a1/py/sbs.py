"""sbs.py <dirA> <labelA> <dirB> <labelB> <outdir> <n>: side-by-side frames (960x540 each) with labels."""
import sys, os
from PIL import Image, ImageDraw, ImageFont
a, la, b, lb, out, n = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
os.makedirs(out, exist_ok=True)
try:
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    f = ImageFont.load_default()
for i in range(n):
    c = Image.new("RGB", (1920, 580), (20, 22, 28))
    for k, (d, lab) in enumerate(((a, la), (b, lb))):
        p = os.path.join(d, "f_%03d.png" % i)
        if os.path.exists(p):
            c.paste(Image.open(p).convert("RGB").resize((960, 540), Image.LANCZOS), (k * 960, 40))
        ImageDraw.Draw(c).text((k * 960 + 12, 8), lab, fill=(240, 240, 240), font=f)
    c.save(os.path.join(out, "s_%03d.png" % i))
