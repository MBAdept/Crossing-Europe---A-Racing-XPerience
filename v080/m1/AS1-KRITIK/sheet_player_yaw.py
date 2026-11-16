import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from sheet_player_ab import sprite_frame, ground_only
from PIL import Image
B = "p"
rows = []
for car in ("limousine", "kompakt"):
    sid = "player/" + car
    for yaw in (-20, -10, 10, 20):
        mod = K.tile(f"{car}_g9_yaw{yaw:+d}_ss", B)
        for ang in (f"l{abs(yaw)}", f"r{abs(yaw)}"):
            pass
        ang = ("l" if yaw > 0 else "r") + str(abs(yaw))
        spr, box = sprite_frame(sid, ang, 1.65, bg=ground_only(mod, (650, 700, 1500, 1188)))
        a = spr.crop(box)
        b = mod.crop(box)
        rows.append(K.caption(a, f"{car} Sprite {ang}", 13))
        rows.append(K.caption(b, f"{car} Modern Gier {yaw:+d}°", 13))
sheet = K.grid([r.resize((r.width * 2 // 3, r.height * 2 // 3), Image.LANCZOS) for r in rows], 4)
sheet = K.title(sheet, "Spielerautos 9 m, gedreht (Kurvenfahrt): Sprite-Zelle gegen Modern, gleiche Kamera, 1,65x",
                sub="Arcade schaltet in 2°-Schritten zwischen 21 Zellen; Modern dreht stufenlos")
print(K.save_jpg(sheet, K.DELIVER + "/02_spieler_9m_gedreht.jpg", q=88))
