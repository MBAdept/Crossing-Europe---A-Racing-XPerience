"""AS4R scratch: comparison picture with label bars.
python3 vn.py <out.jpg> <h|v> <max_w> <title> [--crop=x0,y0,x1,y1] [--zoom=k] <img> <label> [<img> <label> ...]
h = side by side, v = one above the other; max_w = width of the whole picture (scaled down if wider)."""
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def label(img, text, size):
    bar = max(28, size + 12)
    out = Image.new("RGB", (img.width, img.height + bar), (24, 28, 40))
    out.paste(img, (0, bar))
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype(FONT, size)
    w = d.textlength(text, font=f)
    d.text(((img.width - w) / 2, (bar - size) / 2 - 1), text, font=f, fill=(235, 235, 235))
    return out


def main():
    out, mode, max_w, title = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    rest = sys.argv[5:]
    crop, zoom = None, 1
    while rest and rest[0].startswith("--"):
        k, v = rest.pop(0)[2:].split("=")
        if k == "crop":
            crop = tuple(int(c) for c in v.split(","))
        elif k == "zoom":
            zoom = int(v)
    imgs = []
    for i in range(0, len(rest), 2):
        im = Image.open(rest[i]).convert("RGB")
        if crop:
            im = im.crop(crop)
        if zoom > 1:
            im = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
        imgs.append((im, rest[i + 1]))
    size = max(14, imgs[0][0].width // 45)
    tiles = [label(im, lb, size) for im, lb in imgs]
    if mode == "h":
        img = Image.new("RGB", (sum(t.width for t in tiles) + 6 * (len(tiles) - 1), max(t.height for t in tiles)),
                        (24, 28, 40))
        x = 0
        for t in tiles:
            img.paste(t, (x, 0))
            x += t.width + 6
    else:
        img = Image.new("RGB", (max(t.width for t in tiles), sum(t.height for t in tiles) + 6 * (len(tiles) - 1)),
                        (24, 28, 40))
        y = 0
        for t in tiles:
            img.paste(t, (0, y))
            y += t.height + 6
    img = label(img, title, size + 2)
    if img.width > max_w:
        img = img.resize((max_w, round(img.height * max_w / img.width)), Image.LANCZOS)
    img.save(out, quality=90)
    print(out, img.size)


main()
