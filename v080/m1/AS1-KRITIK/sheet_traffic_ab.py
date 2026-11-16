"""Sheets: traffic cars from the sprite camera (ortho, 9 deg, pivot rear) - Arcade sprite vs Modern lod0/1/2."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image

B = "t"
CARS = (("sedan", "traffic/sedan_red"), ("hatch", "traffic/hatch_red"), ("wagon", "traffic/wagon_green"))
# Modern yaw +a shows the same flank as the sprite angle "l<a>" (checked: out/v_yawsign.png)
ANG = {0: "c", 12: "l12", -12: "r12", 24: "l24", -24: "r24"}


def sprite_on(sid, ang, size, bg):
    s = K.sprite_cell(sid, ang, "base")
    im = Image.new("RGBA", s.size, bg + (255,))
    im.alpha_composite(s)
    return im.convert("RGB").resize(size, Image.LANCZOS)


rows = []
for car, sid in CARS:
    for yaw in (0, 24):
        r = K.tile(f"{car}_ortho_lod0_y{yaw:+d}", B)
        bg = r.getpixel((6, 6))
        cw, ch = K.sprite_meta(sid)["cell"]
        # 4x: what each can show at most (sprite upscaled, Modern rendered at 4x)
        a = sprite_on(sid, ANG[yaw], r.size, bg)
        rows.append(K.caption(a, f"{car} · Arcade-Sprite {ANG[yaw]} (Zelle {cw}x{ch}, 4x hochskaliert)"))
        rows.append(K.caption(r, f"{car} · Modern lod0, Gierwinkel {yaw:+d}° (4x gerendert)"))
sheet = K.grid(rows, 2)
sheet = K.title(sheet, "Verkehrsautos aus der Sprite-Kamera (orthografisch, 9° von oben, Drehpunkt Heck)",
                sub="links Arcade-Sprite (Cycles), rechts Modern lod0 mit Spiel-Shadern; gleicher Maßstab (52 px/m x 4) und Anker")
print(K.save_jpg(sheet, K.DELIVER + "/05_verkehr_sprite_vs_modern.jpg", q=88))

# LOD levels against the sprite at the sprite's own resolution (1x = how big a car is at ~14 m in the game)
rows = []
for car, sid in CARS:
    cw, ch = K.sprite_meta(sid)["cell"]
    for yaw in (0, 24):
        r0 = K.tile(f"{car}_ortho_lod0_y{yaw:+d}", B)
        bg = r0.getpixel((6, 6))
        cells = [sprite_on(sid, ANG[yaw], (cw, ch), bg)]
        for lod in ("lod0", "lod1", "lod2"):
            cells.append(K.tile(f"{car}_ortho_{lod}_y{yaw:+d}", B).resize((cw, ch), Image.LANCZOS))
        z = 2
        cells = [c.resize((cw * z, ch * z), Image.NEAREST) for c in cells]
        labs = ["Sprite", "lod0", "lod1", "lod2"]
        rows.extend(K.caption(c, f"{car} {yaw:+d}° {l}", 12) for c, l in zip(cells, labs))
sheet = K.grid(rows, 4)
sheet = K.title(sheet, "Gleiche Pixelzahl: Sprite-Auflösung (52 px/m, wie ein Auto in ~14 m Abstand), 2x vergrößert",
                sub="Sprite | Modern lod0 | lod1 | lod2 (Modern 4x gerendert und auf Sprite-Größe verkleinert)")
print(K.save_jpg(sheet, K.DELIVER + "/06_verkehr_stufen_sprite_aufloesung.jpg", q=90))
