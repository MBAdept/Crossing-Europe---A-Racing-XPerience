import sys, os
from PIL import Image, ImageDraw, ImageFont
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
def sheet(out, names, src, cols=3, tile=(960, 640)):
    rows = (len(names) + cols - 1) // cols
    im = Image.new("RGB", (cols * tile[0], rows * tile[1]), (20, 20, 20))
    for i, n in enumerate(names):
        t = Image.open(os.path.join(src, n + ".png")).convert("RGB")
        t.thumbnail(tile, Image.LANCZOS)
        d = ImageDraw.Draw(t)
        d.rectangle((0, 0, t.width, 24), fill=(0, 0, 0))
        d.text((6, 2), n, fill=(255, 255, 255), font=FONT)
        im.paste(t, ((i % cols) * tile[0], (i // cols) * tile[1]))
    im.save(out)
    print(out, im.size)
if __name__ == "__main__":
    out, src, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
    sheet(out, sys.argv[4:], src, cols)
