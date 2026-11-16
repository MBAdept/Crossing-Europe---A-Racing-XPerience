"""Traffic sheets: close-ups per new type (lod0-2, lamps, wire), sprite camera A/B (4x), silhouettes, paint sets, fleet."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

B = "t"
T = (640, 400)


def t(n, lab, batch=B):
    if not K.has_tile(n, batch):
        return K.caption(Image.new("RGB", T, (40, 0, 0)), "fehlt: " + n, 14)
    return K.caption(K.tile(n, batch).resize(T, Image.LANCZOS), lab, 14)


def close_sheet():
    ims = []
    for car in K.TRAFFIC_NEW:
        ims += [t(f"{car}_lod0_rear34", f"{car}: lod0 Heck schräg"), t(f"{car}_lod0_rearclose", "lod0 Heck nah"),
                t(f"{car}_lod0_taillamp", "Rückleuchte nah (Tag, aus)"), t(f"{car}_lod0_night_brake", "Nacht: Rück+Brems"),
                t(f"{car}_lod0_side", "Seite"), t(f"{car}_lod0_front34", "Front schräg"),
                t(f"{car}_lod0_wheel", "Hinterrad"), t(f"{car}_lod0_night_head", "Nacht: Scheinwerfer"),
                t(f"{car}_lod1_rear34", "lod1 (ab 40 m)"), t(f"{car}_lod2_rear34", "lod2 (ab 120 m)"),
                t(f"{car}_wirelod1_rear34", "lod1 Drahtgitter"), t(f"{car}_wirelod2_rear34", "lod2 Drahtgitter")]
    sheet = K.grid(ims, 4)
    sheet = K.title(sheet, "Neue Verkehrsautos SUV, Transporter, Sportwagen: Nahansichten und Stufen",
                    sub="Spiel-Shader mit Renn-Look, Kontaktbogen-Rig, MSAA 4x; Software-OpenGL")
    print(K.save_jpg(sheet, K.DELIVER + "/11_verkehr_nah_und_stufen.jpg", q=84))


def ortho_sheet():
    """Sprite camera (ortho 9 deg, rear pivot) at 4x sprite resolution: sprite vs lod0/lod1/lod2, 0 and 24 deg."""
    rows = []
    lines = ["Silhouette Sprite (Alpha > 0,9) gegen Modell (Maske), Sprite-Kamera 9°, 2-fache Sprite-Auflösung:"]
    for car in K.TRAFFIC_NEW:
        sid = "traffic/" + K.TRAFFIC_NEW[car][0]
        m = K.sprite_meta(sid)
        cw, ch = m["cell"]
        for yaw, ang in ((0, "c"), (24, "l24")):
            s = K.sprite_cell(sid, ang, "base")
            bgc = tuple(np.asarray(K.tile(f"{car}_ortho_lod0_y{yaw:+d}", B))[3, 3].tolist())
            bg = Image.new("RGBA", s.size, bgc + (255,))
            sp = Image.alpha_composite(bg, s).convert("RGB").resize((cw * 4, ch * 4), Image.LANCZOS)
            row = [K.caption(sp, f"{car} Sprite {ang}", 13)]
            for lod in ("lod0", "lod1", "lod2"):
                n = f"{car}_ortho_{lod}_y{yaw:+d}"
                if K.has_tile(n, B):
                    row.append(K.caption(K.tile(n, B), f"Modern {lod}", 13))
            rows.append(row)
            for lod in ("lod0", "lod2"):
                mm = np.asarray(K.tile(f"{car}_sil_{lod}_y{yaw}", B)).astype(int)
                mm = (mm[..., 0] > 200) & (mm[..., 1] < 80) & (mm[..., 2] < 80)
                sm = np.asarray(s.resize((cw * 2, ch * 2), Image.LANCZOS))[..., 3] > 230
                iou = (sm & mm).sum() / max(1, (sm | mm).sum())
                lines.append(f"  {car:7s} {yaw:+3d}° {lod}: IoU {iou:.3f}, nur Sprite {int((sm & ~mm).sum())} px, nur Modell {int((~sm & mm).sum())} px")
    flat = [im for r in rows for im in r]
    sheet = K.grid(flat, 4)
    sheet = K.title(sheet, "Verkehr in der Sprite-Kamera (orthografisch, 9°, vierfache Sprite-Auflösung): Cycles-Sprite gegen lod0 / lod1 / lod2",
                    sub="Gerade (Zelle c) und 24° gedreht (Zelle l24); das Sprite enthält seinen Bodenschatten")
    print(K.save_jpg(sheet, K.DELIVER + "/12_verkehr_sprite_kamera.jpg", q=86))
    open(K.OUT + "/traffic_silhouette.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


def lampmap_sheet():
    ims = []
    for car in K.TRAFFIC_NEW:
        for lod in ("lod0", "lod1", "lod2"):
            n = f"{car}_ortho_lampmap_{lod}"
            if K.has_tile(n, B):
                im = K.tile(n, B)
                ims.append(K.caption(im.resize((im.width // 2 * 2 // 2, im.height // 2), Image.NEAREST) if im.width > 700 else im, f"{car} {lod} hinten", 12))
        for lod in ("lod0", "lod1", "lod2"):
            n = f"{car}_ortho_lampmapf_{lod}"
            if K.has_tile(n, B):
                im = K.tile(n, B)
                ims.append(K.caption(im.resize((im.width // 2, im.height // 2), Image.NEAREST) if im.width > 700 else im, f"{car} {lod} vorn", 12))
    sheet = K.grid(ims, 6)
    sheet = K.title(sheet, "Lampenkonturen je Stufe (von hinten und vorn, orthografisch)",
                    sub="dunkelrot Rück, rosa Brems, magenta Rück+Brems, orange/gelb Blinker, weiß Scheinwerfer, hellblau Tagfahr, grün Rückfahr, türkis Kennzeichen")
    print(K.save_jpg(sheet, K.DELIVER + "/14_verkehr_lampen_je_stufe.jpg", q=88))


def paint_sheet():
    ims = []
    for car, sets in K.TRAFFIC_NEW.items():
        for s in sets:
            ims.append(t(f"{car}_paint_{s}", f"traffic/{s}"))
    sheet = K.grid([im.resize((480, 300), Image.LANCZOS) for im in ims], 5)
    sheet = K.title(sheet, "Farbsets der neuen Verkehrsautos (lod0, Renn-Look)")
    print(K.save_jpg(sheet, K.DELIVER + "/15_verkehr_farbsets.jpg", q=86))


if __name__ == "__main__":
    close_sheet()
    ortho_sheet()
    lampmap_sheet()
    paint_sheet()
