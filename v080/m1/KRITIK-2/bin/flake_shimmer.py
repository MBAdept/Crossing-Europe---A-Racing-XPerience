"""Flake sparkle of metallic paint at race distance (8 m): frames of a small yaw sweep (0.2 deg steps) rendered with
the race look (flakes 0.6) and without flakes; sparkle pixels = brighter by > 24 levels than without flakes; blinking =
sparkle pixels that switch on or off from one frame to the next (measured)."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import klib as K

lines = ["Metallic-Flocken im Spielbild (8 m, 1280x720, MSAA 2x), Gierschritte 0,2°:"]
tiles = []
for car in K.PLAYERS:
    on = [np.asarray(K.tile(f"{car}_sweep_{k}", "x")).astype(int) for k in range(7)]
    off = [np.asarray(K.tile(f"{car}_sweepnf_{k}", "x")).astype(int) for k in range(7)]
    sp = [(a - b).max(axis=2) > 24 for a, b in zip(on, off)]
    n = [int(s.sum()) for s in sp]
    blink = [int((sp[k] ^ sp[k + 1]).sum()) for k in range(6)]
    car_px = int(((np.abs(on[3] - np.asarray(K.tile("empty_day", "t_neutral")).astype(int)).max(axis=2)) > 10).sum())
    lines.append(f"  {car:13s} Glitzerpixel je Bild {min(n)}–{max(n)} (Mittel {np.mean(n):.0f}) von ~{car_px} Autopixeln; "
                 f"je Schritt an/aus {min(blink)}–{max(blink)} (Mittel {np.mean(blink):.0f})")
    # evidence tile: frame 3 with flakes, without, sparkle map (zoomed on the rear)
    ys, xs = np.nonzero(np.abs(on[3] - off[3]).max(axis=2) > 0)
    a = Image.fromarray(on[3].astype(np.uint8))
    b = Image.fromarray(off[3].astype(np.uint8))
    m = np.zeros(on[3].shape, np.uint8)
    m[sp[3]] = (255, 255, 0)
    m[sp[2] & ~sp[3]] = (255, 0, 255)
    mi = Image.fromarray(m)
    box = (470, 520, 810, 720)
    for im, lab in ((a, f"{car}: Flocken an (Renn-Look)"), (b, "Flocken aus"), (mi, "gelb: Glitzern jetzt, magenta: im Bild davor")):
        c = im.crop(box).resize((680, 400), Image.NEAREST)
        tiles.append(K.caption(c, lab, 13))
sheet = K.grid(tiles, 6)
sheet = K.title(sheet, "Metallic-Flocken des Lack-Shaders in 8 m (Spielbild, 2-fach): einzelne Pixel blinken bei jeder Bewegung",
                sub="flake_scale 260 Zellen/m: eine Zelle ist in 8 m kleiner als ein Drittel Pixel; MSAA glättet keine Schattierung")
print(K.save_jpg(sheet, K.DELIVER + "/19_lack_flocken_flimmern.jpg", q=88))
open(K.OUT + "/flake_shimmer.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
