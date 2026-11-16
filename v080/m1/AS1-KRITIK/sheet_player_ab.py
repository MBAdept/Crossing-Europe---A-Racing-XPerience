"""Sheet: player car from the game camera at 9 m - Arcade sprite vs Modern (same camera, same screen region)."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image

B = "p"


def sprite_frame(sid, angle, ss, layers=("base",), night=False, bg=None):
    """The sprite cell as Arcade places it on a 1280x720 screen (scaled by ss), on a background image."""
    m = K.sprite_meta(sid)
    cw, ch = m["cell"]
    sup = m["supersample"]
    ax, ay = m["anchor"]
    # car centre 9 m ahead on the road, camera 3.4 m high: anchor point on the screen
    s = 711.0 / 9.0
    px, py = 640.0 * ss, (324.0 + 3.4 * s) * ss
    scale = ss / sup
    base = K.sprite_cell(sid, angle, "base")
    if night:
        # Arcade darkens the base at night (modulate); approximation for the comparison only
        r, g, b, a = base.split()
        base = Image.merge("RGBA", (r.point(lambda v: int(v * 0.22)), g.point(lambda v: int(v * 0.22)), b.point(lambda v: int(v * 0.26)), a))
    cell = base
    for lay in layers:
        if lay == "base":
            continue
        over = K.sprite_cell(sid, angle, lay)
        cell = Image.alpha_composite(cell, over)
    w, h = max(1, round(cw * scale)), max(1, round(ch * scale))
    cell = cell.resize((w, h), Image.LANCZOS) if scale != 1.0 else cell
    x0, y0 = round(px - ax * w), round(py - ay * h)
    frame = bg.copy().convert("RGBA")
    frame.alpha_composite(cell, (x0, y0))
    return frame.convert("RGB"), (x0, y0, x0 + w, y0 + h)


def ground_only(img, box):
    """Background of the Modern frame without the car: fill the box with the ground colour above/below it."""
    g = img.copy()
    x0, y0, x1, y1 = box
    col = img.getpixel((max(0, x0 - 40), min(img.height - 1, (y0 + y1) // 2)))
    g.paste(col, (x0 - 60, y0 - 40, x1 + 120, min(img.height, y1 + 40)))
    return g


if __name__ == "__main__":
    rows = []
    for car in ("limousine", "kompakt"):
        sid = "player/" + car
        # native sprite resolution (supersampled cell) against the Modern frame rendered 1.65x
        mod_ss = K.tile(f"{car}_g9_day_ss", B)
        spr_ss, box_ss = sprite_frame(sid, "c", 1.65, bg=ground_only(mod_ss, (700, 700, 1450, 1188)))
        a = spr_ss.crop(box_ss)
        b = mod_ss.crop(box_ss)
        rows.append([K.caption(a, f"Arcade-Sprite {car} (Zelle c, volle Auflösung 1,65x)"),
                     K.caption(b, f"Modern lod0, gleiche Kamera, 1,65x, MSAA 4x")])
        # game resolution 1280x720 (what the player sees), shown 2x nearest
        mod = K.tile(f"{car}_g9_day", B)
        spr, box = sprite_frame(sid, "c", 1.0, bg=ground_only(mod, (440, 440, 880, 720)))
        a = spr.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.NEAREST)
        b = mod.crop(box).resize(a.size, Image.NEAREST)
        low = K.tile(f"{car}_g9_low", B)
        # low preset: 3D at 75 % (960x540), upscaled bilinear to 1280x720 like scaling_3d_scale
        low = low.resize((1280, 720), Image.BILINEAR).crop(box).resize(a.size, Image.NEAREST)
        rows.append([K.caption(a, "Arcade im Spiel (1280x720), 2x vergrößert"),
                     K.caption(b, "Modern im Spiel (MSAA 2x), 2x vergrößert")])
        rows.append([K.caption(low, "Modern Voreinstellung „Niedrig“ (75 %, ohne MSAA)"),
                     K.caption(K.tile(f"{car}_g9_day_backlit", B).crop(box).resize(a.size, Image.NEAREST), "Modern, Sonne von vorn (Heck im Schatten)")])
    flat = []
    for r in rows:
        w = max(i.width for i in r)
        flat.extend(r)
    sheet = K.grid([im.resize((694, int(im.height * 694 / im.width)), Image.LANCZOS) if im.width != 694 else im for im in flat], 2)
    sheet = K.title(sheet, "Spielerautos aus der Spielkamera (9 m): Arcade-Sprite gegen Modern",
                    sub="gleiche Kamera (Höhe 3,4 m, Brennweite 711 px), gleicher Bildausschnitt; Software-OpenGL, Kontaktbogen-Licht")
    print(K.save_jpg(sheet, K.DELIVER + "/01_spieler_9m_sprite_vs_modern.jpg"))
