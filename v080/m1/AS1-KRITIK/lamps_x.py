"""Lamp checks from batch x: (1) lamp outlines from straight behind per level (masks per channel colour of the
lampmap mode, IoU against lod0); (2) indicator alone by day / at night at 30 and 80 m: amber pixels and contrast."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import numpy as np
from PIL import Image

import kritik_lib as K

# lampmap colours (unshaded, weight scales 0.35..1): tail (0.6,0,0), brake (1,.25,.25), tail+brake (1,0,.5),
# ind l (1,.6,0), ind r (1,.85,0), reverse (.3,1,.3), plate (0,.7,.7)
CH = {"Blinker l": lambda r, g, b: (r > 120) & (g > 0.45 * r) & (g < 0.72 * r) & (b < 40),
      "Blinker r": lambda r, g, b: (r > 120) & (g >= 0.72 * r) & (b < 40),
      "Rück+Brems": lambda r, g, b: (r > 120) & (b > 0.3 * r) & (g < 60),
      "Brems": lambda r, g, b: (r > 150) & (g > 0.15 * r) & (g < 0.4 * r) & (b > 0.15 * r) & (b < 0.4 * r),
      "Rückfahr": lambda r, g, b: (g > 150) & (r < 0.6 * g) & (b < 0.6 * g)}
lines = ["Lampenkonturen von hinten (orthografisch, 4x Sprite-Auflösung): Fläche in px und Überdeckung (IoU) mit lod0"]
ims = []
for car in ("sedan", "hatch", "wagon"):
    masks = {}
    for lod in ("lod0", "lod1", "lod2"):
        a = np.asarray(Image.open(K.OUT + f"/tiles/x/{car}_ortho_lampmap_{lod}.png").convert("RGB")).astype(int)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        masks[lod] = {k: f(r, g, b) for k, f in CH.items()}
        ims.append(K.caption(Image.fromarray(a.astype(np.uint8)), f"{car} {lod}: Lampenkanäle von hinten", 13))
    for k in CH:
        m0 = masks["lod0"][k]
        parts = []
        for lod in ("lod0", "lod1", "lod2"):
            m = masks[lod][k]
            iou = (m & m0).sum() / max(1, (m | m0).sum())
            parts.append(f"{lod} {m.sum():5d} px IoU {iou:.2f}")
        lines.append(f"  {car:6s} {k:11s} " + " | ".join(parts))
sheet = K.grid(ims, 3)
sheet = K.title(sheet, "Lampenkonturen der Verkehrsautos je Stufe, gerade von hinten (Falschfarben je Kanal)",
                sub="rot = Rücklicht, rosa = Bremslicht, magenta = Rück+Brems, orange/gelb = Blinker l/r, grün = Rückfahrlicht, türkis = Kennzeichen")
print(K.save_jpg(sheet, K.DELIVER + "/15_verkehr_lampen_je_stufe.jpg", q=90))


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


lines.append("")
lines.append("Blinker allein (links), Spielkamera 1280x720, MSAA 2x: Pixel die sich ändern (> 12 Stufen), Helligkeit aus -> an, Farbe an")
for car in ("sedan", "hatch", "wagon", "truck"):
    for d, lod in ((30, "lod0"), (80, "lod1")):
        off = np.asarray(Image.open(K.OUT + f"/tiles/x/{car}_g{d}_{lod}_dayoff.png").convert("RGB")).astype(float)
        on = np.asarray(Image.open(K.OUT + f"/tiles/x/{car}_g{d}_{lod}_dayind.png").convert("RGB")).astype(float)
        m = np.abs(on - off).max(axis=2) > 12
        if m.sum() == 0:
            lines.append(f"  {car:6s} {d:3d} m Tag: keine Änderung")
            continue
        lo, ln = lum(off[m]).mean(), lum(on[m]).mean()
        col = on[m].mean(axis=0).astype(int).tolist()
        lines.append(f"  {car:6s} {d:3d} m {lod} Tag:   {int(m.sum()):4d} px, {lo:5.1f} -> {ln:5.1f} (x{ln / max(lo, 1):.2f}), an {col}, aus {off[m].mean(axis=0).astype(int).tolist()}")
        tail = np.asarray(Image.open(K.OUT + f"/tiles/x/{car}_g{d}_{lod}_nighttailonly.png").convert("RGB")).astype(float)
        ind = np.asarray(Image.open(K.OUT + f"/tiles/x/{car}_g{d}_{lod}_nightind.png").convert("RGB")).astype(float)
        m = np.abs(ind - tail).max(axis=2) > 12
        if m.sum():
            lines.append(f"  {car:6s} {d:3d} m {lod} Nacht: {int(m.sum()):4d} px, {lum(tail[m]).mean():5.1f} -> {lum(ind[m]).mean():5.1f}, an {ind[m].mean(axis=0).astype(int).tolist()}")
open(K.OUT + "/lamps_x.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
