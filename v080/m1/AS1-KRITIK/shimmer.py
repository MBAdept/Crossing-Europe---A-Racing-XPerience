"""Shimmer of fine detail on the player car in motion (yaw sweep -2..+2 deg in 0.2 deg steps at 9 m):
aliasing error of each MSAA-2x frame against a 3x3-supersampled reference, and its change from frame to frame.
Arcade comparison: the jump between two neighbouring sprite cells (c -> l2), which Arcade shows every 2 deg."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import numpy as np
from PIL import Image

import kritik_lib as K
from sheet_player_ab import ground_only, sprite_frame


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


out = []
lines = []
for car in ("limousine", "kompakt"):
    mt = K.meta("p")
    rect = mt[f"{car}_sweep_10"]["rect"]
    x0, y0, x1, y1 = [int(round(v)) for v in rect]
    x0, y0, x1, y1 = max(0, x0 - 4), max(0, y0 - 4), min(1280, x1 + 4), min(720, y1 + 4)
    errs = []
    frames = []
    for k in range(21):
        f = np.asarray(K.tile(f"{car}_sweep_{k:02d}", "p")).astype(float)
        r = Image.open(K.OUT + f"/tiles/x/{car}_sweepref_{k:02d}.png").convert("RGB").resize((1280, 720), Image.BOX)
        r = np.asarray(r).astype(float)
        errs.append(lum(f) - lum(r))
        frames.append(lum(f))
    E = np.stack(errs)[:, y0:y1, x0:x1]
    F = np.stack(frames)[:, y0:y1, x0:x1]
    car_mask = np.abs(F[10] - F[10][0, 0]) > 6
    absmean = np.abs(E).mean(axis=0)
    tstd = E.std(axis=0)
    shimmer = (tstd > 8) & car_mask
    # Arcade: jump between the sprite cells c and l2 at game resolution
    base = K.tile(f"{car}_sweep_10", "p")
    a_c, box = sprite_frame("player/" + car, "c", 1.0, bg=ground_only(base, (440, 440, 880, 720)))
    a_l, _ = sprite_frame("player/" + car, "l2", 1.0, bg=ground_only(base, (440, 440, 880, 720)))
    J = np.abs(lum(np.asarray(a_c).astype(float)) - lum(np.asarray(a_l).astype(float)))[y0:y1, x0:x1]
    jump = (J > 24) & car_mask
    lines.append(f"{car}: Autofläche {car_mask.sum()} px; Modern MSAA 2x: mittlerer Treppenfehler {absmean[car_mask].mean():.1f} Stufen, "
                 f"zeitliche Schwankung des Fehlers > 8 Stufen an {shimmer.sum()} px ({100 * shimmer.sum() / car_mask.sum():.1f} %); "
                 f"Arcade: Zellwechsel c->l2 ändert {jump.sum()} px um > 24 Stufen ({100 * jump.sum() / car_mask.sum():.1f} %) auf einen Schlag")
    # pictures: frame, reference, |error| x4, temporal std heat map
    zoom = 2
    def big(a):
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        return im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
    f10 = Image.fromarray(np.asarray(K.tile(f"{car}_sweep_10", "p"))[y0:y1, x0:x1])
    heat = np.zeros(tstd.shape + (3,))
    heat[..., 0] = np.clip(tstd * 12, 0, 255)
    heat[..., 1] = np.clip(tstd * 4, 0, 255)
    heat += (F[10] * 0.25)[..., None]
    out.append(K.caption(f10.resize((f10.width * zoom, f10.height * zoom), Image.NEAREST), f"{car}: Modern MSAA 2x, 9 m", 13))
    out.append(K.caption(big(heat), "Flimmern: zeitliche Schwankung des Treppenfehlers (rot/gelb)", 13))
    out.append(K.caption(big(np.stack([J * 3] * 3, axis=-1)), "Arcade: Sprung beim Zellwechsel c -> l2 (alle 2°)", 13))
sheet = K.grid(out, 3)
sheet = K.title(sheet, "Bewegung: Spielerauto dreht sich um ±2° (0,2°-Schritte) – Flimmern feiner Details gegen den Zellsprung von Arcade",
                sub=" | ".join(l.split(":")[0] + ": " + l.split(";")[1].strip() for l in lines))
print(K.save_jpg(sheet, K.DELIVER + "/14_spieler_bewegung_flimmern.jpg", q=88))
open(K.OUT + "/shimmer.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
