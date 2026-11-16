"""AS1R: deliverable sheet of the LOD swaps (game camera, day): per car lodA | lodB | difference x4, at 40 m and 120 m."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R/out"
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1R/07_stufenwechsel.jpg"
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
FONTB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
rows = []
for tag, a, b, dist in (("p40c", "lod0", "lod1", 40), ("p120c", "lod1", "lod2", 120)):
    for m in ("sedan", "hatch", "wagon"):
        ia = np.asarray(Image.open("%s/pop_%s_%s_%s.png" % (S, tag, m, a)).convert("RGB"), dtype=np.int32)[:270, :480]
        ib = np.asarray(Image.open("%s/pop_%s_%s_%s.png" % (S, tag, m, b)).convert("RGB"), dtype=np.int32)[:270, :480]
        d = np.clip(np.abs(ia - ib).max(axis=2) * 4, 0, 255).astype(np.uint8)
        row = np.concatenate([ia.astype(np.uint8), ib.astype(np.uint8), np.stack([d, d, d], axis=2)], axis=1)
        im = Image.fromarray(row)
        dr = ImageDraw.Draw(im)
        for i, t in enumerate(("%s %d m %s" % (m, dist, a), "%s %d m %s" % (m, dist, b), "Differenz x4")):
            dr.text((8 + 480 * i, 248), t, font=FONT, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
        rows.append(np.asarray(im))
sheet = np.concatenate(rows, axis=0)
head = Image.new("RGB", (sheet.shape[1], 56), (16, 16, 18))
dr = ImageDraw.Draw(head)
dr.text((10, 6), "Stufenwechsel der Verkehrsautos aus der Spielkamera (Tag): links feinere, Mitte gröbere Stufe, rechts Differenz",
        font=FONTB, fill=(255, 255, 255))
dr.text((10, 32), "gemessen (Anteil der Autopixel > 24 Stufen): 40 m 6,6-9,8 %, 120 m 22-34 % - Software-OpenGL, Kontaktbogen-Licht",
        font=FONT, fill=(200, 200, 200))
Image.fromarray(np.concatenate([np.asarray(head), sheet], axis=0)).save(OUT, quality=88)
print(OUT)
