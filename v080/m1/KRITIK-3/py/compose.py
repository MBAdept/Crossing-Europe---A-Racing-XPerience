"""KRITIK-3: comparison sheets for the delivery folder (labelled crops of the review renders)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

K = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3'
DL = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-3'
S = K + '/shots/'
try:
    FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
    FONT_B = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
except Exception:
    FONT = FONT_B = ImageFont.load_default()


def _wrap(d, text, font, width):
    words = text.split(' ')
    lines, cur = [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=font) > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def title(img, text, sub=None):
    probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    tl = _wrap(probe, text, FONT_B, img.width - 20)
    sl = _wrap(probe, sub, FONT, img.width - 20) if sub else []
    h = 12 + 28 * len(tl) + 24 * len(sl) + 6
    out = Image.new('RGB', (img.width, img.height + h), (20, 24, 34))
    out.paste(img, (0, h))
    d = ImageDraw.Draw(out)
    y = 8
    for l in tl:
        d.text((10, y), l, fill=(255, 255, 255), font=FONT_B)
        y += 28
    for l in sl:
        d.text((10, y), l, fill=(200, 205, 215), font=FONT)
        y += 24
    return out


def label(img, text, pos=(6, 6)):
    d = ImageDraw.Draw(img)
    x, y = pos
    w = d.textlength(text, font=FONT)
    d.rectangle((x - 3, y - 2, x + w + 3, y + 22), fill=(0, 0, 0))
    d.text((x, y), text, fill=(255, 255, 0), font=FONT)
    return img


def grid(tiles, cols, pad=6, bg=(255, 255, 255)):
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new('RGB', (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad), bg)
    for i, t in enumerate(tiles):
        out.paste(t, (pad + (i % cols) * (w + pad), pad + (i // cols) * (h + pad)))
    return out


def save(img, name, q=88):
    p = os.path.join(DL, name)
    if name.endswith('.jpg'):
        img.convert('RGB').save(p, quality=q, optimize=True)
    else:
        img.save(p, optimize=True)
    print(p, img.size, os.path.getsize(p) // 1024, 'kB')


def tile(path, box, scale=1.0, resample=Image.NEAREST):
    im = Image.open(path).convert('RGB').crop(box)
    if scale != 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), resample)
    return im
