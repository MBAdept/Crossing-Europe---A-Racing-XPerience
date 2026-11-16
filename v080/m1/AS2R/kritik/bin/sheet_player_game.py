"""Sheets 01/02: player cars from the game camera - Arcade sprite vs Modern (same camera, same screen region), and
the night/brake states. Also measures paint colour (sprite vs modern), lamp pixels and the silhouette overlap."""
import colorsys
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

B = "p"


def ground_fill(img):
    """A frame of the ground colour (sampled left of the car, lower part) with the sky above the horizon row."""
    a = np.asarray(img).copy()
    h, w = a.shape[:2]
    col = a[int(h * 0.9), int(w * 0.05)]
    hor = int(h * 0.45) + 1
    a[hor:] = col
    return Image.fromarray(a)


def car_box(img, bg):
    """Bounding box of pixels that differ from the background frame."""
    d = np.abs(np.asarray(img).astype(int) - np.asarray(bg).astype(int)).max(axis=2) > 10
    ys, xs = np.nonzero(d)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def paint_stats(img, mask):
    a = np.asarray(img)[mask].astype(float) / 255.0
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in a[:: max(1, len(a) // 4000)]])
    clip = float((a.max(axis=1) >= 0.995).mean())
    return hsv[:, 0].mean() * 360, hsv[:, 1].mean(), hsv[:, 2].mean(), clip


def main():
    lines = []
    rows = []
    sil = []
    for car in K.PLAYERS:
        sid = "player/" + car
        sup = K.sprite_meta(sid)["supersample"]
        mod_ss = K.tile(f"{car}_g9_ss", B)
        bg = ground_fill(mod_ss)
        spr, box = K.player_sprite_frame(sid, "c", sup, bg)
        x0, y0, x1, y1 = box
        # common crop: union of sprite cell and model box
        mk = np.asarray(K.tile(f"{car}_g9_mask_ss", B)).astype(int)
        mkm = (mk[..., 0] > 200) & (mk[..., 1] < 80) & (mk[..., 2] < 80)
        ys_, xs_ = np.nonzero(mkm)
        mb = (xs_.min(), ys_.min(), xs_.max() + 1, ys_.max() + 1)
        al_ = np.asarray(K.sprite_cell(sid, "c", "base"))[..., 3] > 30
        ys2, xs2 = np.nonzero(al_)
        sb = (x0 + xs2.min(), y0 + ys2.min(), x0 + xs2.max() + 1, y0 + ys2.max() + 1)
        cx0, cy0, cx1, cy1 = min(sb[0], mb[0]) - 16, min(sb[1], mb[1]) - 16, max(sb[2], mb[2]) + 16, max(sb[3], mb[3]) + 16
        a = spr.crop((cx0, cy0, cx1, cy1))
        b = mod_ss.crop((cx0, cy0, cx1, cy1))
        n = K.tile(f"{car}_g9_ss_neutral", B).crop((cx0, cy0, cx1, cy1))
        # silhouette: sprite alpha > 0.9 vs model mask
        mask = np.asarray(K.tile(f"{car}_g9_mask_ss", B)).astype(int)
        mm = (mask[..., 0] > 200) & (mask[..., 1] < 80) & (mask[..., 2] < 80)
        m = K.sprite_meta(sid)
        cw, ch = m["cell"]
        scale = sup * m["camera"]["distance_m"] / 9.0 / sup
        cell = K.sprite_cell(sid, "c", "base")
        cell = cell.resize((round(cw * scale), round(ch * scale)), Image.LANCZOS)
        sm = np.zeros(mm.shape, bool)
        al = np.asarray(cell)[..., 3] > 230
        sm[y0:y0 + al.shape[0], x0:x0 + al.shape[1]] = al[: max(0, min(al.shape[0], sm.shape[0] - y0)), : max(0, min(al.shape[1], sm.shape[1] - x0))]
        iou = (sm & mm).sum() / max(1, (sm | mm).sum())
        sil.append((car, iou, int((sm & ~mm).sum()), int((~sm & mm).sum())))
        ov = np.zeros(mm.shape + (3,), np.uint8)
        ov[sm & mm] = (150, 150, 150)
        ov[sm & ~mm] = (255, 60, 60)
        ov[~sm & mm] = (60, 160, 255)
        ovi = Image.fromarray(ov).crop((cx0, cy0, cx1, cy1))
        # paint: pixels of the paint mask region - use the sprite alpha & model mask intersection, upper body rows
        # (roof / tailgate) where both show paint: hue/sat/val of pixels whose hue is near the paint hue
        ph = K.set_paint(sid).get("paint", "#808080")
        pr = np.array([int(ph[1:3], 16), int(ph[3:5], 16), int(ph[5:7], 16)]) / 255.0
        p_h, p_s, p_v = colorsys.rgb_to_hsv(*pr)
        both = sm & mm

        def stats(img):
            arr = np.asarray(img).astype(float) / 255.0
            sel = arr[both]
            hsv = np.array([colorsys.rgb_to_hsv(*p) for p in sel[:: max(1, len(sel) // 6000)]])
            if p_s > 0.25:
                dh = np.minimum(np.abs(hsv[:, 0] - p_h), 1 - np.abs(hsv[:, 0] - p_h))
                keep = (dh < 0.08) & (hsv[:, 1] > 0.25)
            else:
                keep = (hsv[:, 1] < 0.2) & (hsv[:, 2] > 0.35)
            k = hsv[keep]
            sel2 = sel[:: max(1, len(sel) // 6000)][keep]
            clip = float((sel2.max(axis=1) >= 0.995).mean()) if len(sel2) else 0.0
            return ((np.degrees(np.arctan2(np.sin(k[:, 0] * 2 * np.pi).mean(), np.cos(k[:, 0] * 2 * np.pi).mean())) % 360) if len(k) else 0, k[:, 1].mean() if len(k) else 0, k[:, 2].mean() if len(k) else 0, clip, int(keep.sum()))
        ss_ = stats(spr)
        sm_ = stats(mod_ss)
        sn_ = stats(K.tile(f"{car}_g9_ss_neutral", B))
        lines.append(f"{car:13s} Lack {ph}: Sprite H {ss_[0]:.0f}° S {ss_[1]:.2f} V {ss_[2]:.2f} geclippt {100*ss_[3]:.0f} % | "
                     f"Modern Renn-Look H {sm_[0]:.0f}° S {sm_[1]:.2f} V {sm_[2]:.2f} geclippt {100*sm_[3]:.0f} % | "
                     f"Modern neutral H {sn_[0]:.0f}° S {sn_[1]:.2f} V {sn_[2]:.2f} geclippt {100*sn_[3]:.0f} %  (n {ss_[4]}/{sm_[4]}/{sn_[4]})")
        th = 300
        def fit(im):
            return im.resize((int(im.width * th / im.height), th), Image.LANCZOS)
        mt = K.meta(B)
        g8 = K.tile(f"{car}_g8_day", B)
        r8 = mt[f"{car}_g8_day"]["rect"]
        b8 = (int(r8[0]), int(r8[1]), int(r8[2]) + 1, int(r8[3]) + 1)
        c8 = g8.crop((b8[0] - 12, b8[1] - 12, b8[2] + 12, b8[3] + 12))
        c8 = c8.resize((c8.width * 2, c8.height * 2), Image.NEAREST)
        g30 = K.tile(f"{car}_g30_day", B)
        r30 = mt[f"{car}_g30_day"]["rect"]
        b30 = (int(r30[0]), int(r30[1]), int(r30[2]) + 1, int(r30[3]) + 1)
        c30 = g30.crop((b30[0] - 6, b30[1] - 6, b30[2] + 6, b30[3] + 6))
        c30 = c30.resize((c30.width * 6, c30.height * 6), Image.NEAREST)
        low = K.tile(f"{car}_g8_low", B).resize((1280, 720), Image.BILINEAR)
        cl = low.crop((b8[0] - 12, b8[1] - 12, b8[2] + 12, b8[3] + 12))
        cl = cl.resize((cl.width * 2, cl.height * 2), Image.NEAREST)
        rows.append([K.caption(fit(a), f"{car}: Arcade-Sprite (Zelle c, {sup}x)", 13),
                     K.caption(fit(b), "Modern lod0, Renn-Look, gleiche Kamera", 13),
                     K.caption(fit(n), "Modern, Shader neutral", 13),
                     K.caption(fit(ovi), f"Silhouette IoU {iou:.3f}", 13),
                     K.caption(fit(c8), "8 m im Spielbild, 2x", 13),
                     K.caption(fit(cl), "8 m, Voreinst. Niedrig (75 %, ohne MSAA), 2x", 13),
                     K.caption(fit(c30), "30 m im Spielbild, 6x", 13)])
    flat = [im for r in rows for im in r]
    widths = [max(r[i].width for r in rows) for i in range(len(rows[0]))]
    sheet_w = sum(widths) + 4 * (len(widths) + 1)
    sheet = Image.new("RGB", (sheet_w, len(rows) * 304 + 4), (24, 24, 26))
    y = 4
    for r in rows:
        x = 4
        for i, im in enumerate(r):
            sheet.paste(im, (x, y))
            x += widths[i] + 4
        y += 304
    sheet = K.title(sheet, "Spielerautos aus der Spielkamera: Arcade-Sprite gegen Modern (gleiche Kamera, 3,4 m hoch, Brennweite 711 px)",
                    sub="Spalten 1-4: 9 m in der Auflösung der Sprite-Zelle (1,65-1,9x, MSAA 4x); 5-7: was der Spieler sieht (1280x720, MSAA 2x wie „Mittel“/„Steam Deck“), vergrößert.\nLicht: Kontaktbogen-Rig (eine Sonne mit Schatten), Renn-Look von R3 (Klarlack, Füll-Licht 0,7), Kontaktschatten. Software-OpenGL.")
    print(K.save_jpg(sheet, K.DELIVER + "/01_spieler_spielkamera_sprite_gegen_modern.jpg", q=88))
    lines.append("")
    lines.append("Silhouette 9 m (Sprite-Alpha > 0,9 gegen Modell-Maske):")
    for car, iou, a_, b_ in sil:
        lines.append(f"  {car:13s} IoU {iou:.3f} nur Sprite {a_} px, nur Modell {b_} px")
    open(K.OUT + "/player_game.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
