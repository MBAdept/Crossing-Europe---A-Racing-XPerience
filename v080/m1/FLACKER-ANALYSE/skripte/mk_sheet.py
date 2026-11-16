import sys
from PIL import Image, ImageDraw, ImageFont
srcs = sys.argv[2:]
out = sys.argv[1]
labels = ["lod0 (Kaskade 2)", "lod1 (Kaskade 2)", "lod2", "lod0 in Kaskade 1", "lod0 ABGELEHNT", "lod1 ABGELEHNT", "lod0 abgelehnt, Dither-Globals aus"]
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    fontb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
except Exception:
    font = fontb = ImageFont.load_default()
rows = []
for s in srcs:
    im = Image.open(s).convert("RGB")
    n = 7
    tw = im.size[0] // n
    scale = max(1, 260 // tw) if tw < 260 else 1
    tiles = [im.crop((i * tw, 0, (i + 1) * tw, im.size[1])) for i in range(n)]
    if tw * scale != tw:
        tiles = [t.resize((tw * scale, im.size[1] * scale), Image.NEAREST) for t in tiles]
    rows.append((s.split("/")[-1].replace(".png", ""), tiles))
TW = max(t[0].size[0] for _, t in rows)
TH = max(t[0].size[1] for _, t in rows)
W = TW * 7 + 8 * 8
H = 40 + len(rows) * (TH + 46) + 10
sheet = Image.new("RGB", (W, H), (28, 30, 34))
d = ImageDraw.Draw(sheet)
d.text((8, 8), "ZS1, weisser Verkehrs-Pkw ~40 m vor der Kamera, Spielkamera (3,4 m, 711 px), Preset Mittel (2 Kaskaden, Grenze 36 m), llvmpipe - gemessen", fill=(230, 230, 230), font=fontb)
y = 40
for name, tiles in rows:
    d.text((8, y), name, fill=(200, 200, 120), font=font)
    y += 20
    for i, t in enumerate(tiles):
        x = 8 + i * (TW + 8)
        sheet.paste(t, (x, y))
        d.text((x, y + t.size[1] + 3), labels[i], fill=(255, 140, 120) if "ABGELEHNT" in labels[i] or "abgelehnt" in labels[i] else (220, 220, 220), font=font)
    y += TH + 26
sheet.save(out)
print(out, sheet.size)
