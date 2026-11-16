"""Sheet: showroom A/B - Cycles showroom sprite vs the real-time `show` level from the same camera, three rigs;
silhouette overlap sprite vs model (measured)."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

B = "s"
lines = ["Showroom: Silhouette Cycles-Sprite (Alpha > 0,9) gegen Echtzeit-show (Maske), gleiche Kamera 768x480"]
rows = []
T = (512, 320)
for car in K.PLAYERS:
    spr = Image.open(K.WT + "/assets/sprites/showroom/" + car + ".png").convert("RGBA")
    rt = K.tile(f"{car}_sr_studio_race", B)
    bg = Image.new("RGBA", spr.size, (24, 27, 44, 255))
    a = Image.alpha_composite(bg, spr).convert("RGB")
    mask = np.asarray(K.tile(f"{car}_sr_mask", B)).astype(int)
    mm = (mask[..., 0] > 200) & (mask[..., 1] < 80) & (mask[..., 2] < 80)
    sm = np.asarray(spr)[..., 3] > 230
    iou = (sm & mm).sum() / max(1, (sm | mm).sum())
    only_s = int((sm & ~mm).sum())
    only_m = int((~sm & mm).sum())
    lines.append(f"  {car:13s} IoU {iou:.3f}  nur Sprite {only_s} px  nur Modell {only_m} px")
    ov = np.zeros(sm.shape + (3,), np.uint8)
    ov[sm & mm] = (150, 150, 150)
    ov[sm & ~mm] = (255, 60, 60)
    ov[~sm & mm] = (60, 160, 255)
    imgs = [K.caption(a.resize(T, Image.LANCZOS), f"{car}: Cycles-Sprite (Arcade-Showroom)", 13),
            K.caption((K.tile(f"{car}_sr_sheet_agx_b", "x") if K.has_tile(f"{car}_sr_sheet_agx_b", "x") else K.tile(f"{car}_sr_sheet_agx", B)).resize(T, Image.LANCZOS), "Echtzeit show: Kontaktbogen-Licht + Renn-Look, AgX (Rig des AS2a-A/B)", 13),
            K.caption(rt.resize(T, Image.LANCZOS), "Echtzeit show: Studio von UI1 + Renn-Look (R3)", 13),
            K.caption(K.tile(f"{car}_sr_studio_neutral", B).resize(T, Image.LANCZOS), "Studio von UI1, Shader neutral (so heute im Menü)", 13),
            K.caption(Image.fromarray(ov).resize(T, Image.NEAREST), f"Silhouette: IoU {iou:.3f} (rot nur Sprite, blau nur Modell)", 13)]
    rows += imgs
sheet = K.grid(rows, 5)
sheet = K.title(sheet, "Showroom-A/B: Cycles-Sprite gegen Echtzeit-Stufe show, gleiche Kamera (142°, 56 mm, 11°)",
                sub="Software-OpenGL (llvmpipe); Studio = Licht von UI1 (showroom_3d.gd: Key 1,05 mit Schatten, Fill, zwei Randlichter, AgX); Renn-Look = LOOK von layers/vehicles.gd")
print(K.save_jpg(sheet, K.DELIVER + "/08_showroom_ab.jpg", q=88))
open(K.OUT + "/showroom_silhouette.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
