import sys
sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK")
import kritik_lib as K
from PIL import Image
B = "p"
T = (640, 400)
def t(n, lab):
    return K.caption(K.tile(n, B).resize(T, Image.LANCZOS), lab, 14)
for car in ("limousine", "kompakt"):
    ims = [t(f"{car}_lod0_rear34", "Heck schräg (lod0)"), t(f"{car}_lod0_rearclose", "Heck nah"), t(f"{car}_lod0_taillamp", "Rückleuchte nah, Tag"),
           t(f"{car}_night_taillamp", "Rückleuchte nah, Nacht, Rücklicht"), t(f"{car}_night_brake", "Nacht: Rück + Brems"), t(f"{car}_night_indl", "Nacht: Blinker links"),
           t(f"{car}_lod0_wheel", "Hinterrad"), t(f"{car}_lod0_wheelf", "Vorderrad"), t(f"{car}_lod0_cabin", "Innenraum durch die Heckscheibe"),
           t(f"{car}_lod0_front34", "Front schräg"), t(f"{car}_lod0_frontclose", "Front nah"), t(f"{car}_lod0_headlamp", "Scheinwerfer nah"),
           t(f"{car}_show_rear34", "Showroom-Stufe: Heck schräg"), t(f"{car}_show_wheel", "Showroom-Stufe: Rad"), t(f"{car}_lod0_side", "Seite"),
           t(f"{car}_night_head", "Nacht: Scheinwerfer")]
    sheet = K.grid(ims, 4)
    sheet = K.title(sheet, f"player/{car}: Nahansichten (Spiel-Shader, Kontaktbogen-Licht, MSAA 4x)",
                    sub="Software-OpenGL; Lack/Licht hängen vom Renderer ab (R1/R3), Form und Lampen vom Modell")
    print(K.save_jpg(sheet, K.DELIVER + f"/03_{car}_nah.jpg", q=86))
ims = []
for car in ("limousine", "kompakt"):
    ims += [t(f"{car}_clay_rear34", f"{car}: Ton (Form ohne Lack)"), t(f"{car}_facets_rearclose", "Facetten (flach schattiert)"),
            t(f"{car}_wire_rearclose", "Drahtgitter"), t(f"{car}_normals_rearclose", "Normalen (Weltrichtung als Farbe)"),
            t(f"{car}_clay_front34", "Ton: Front"), t(f"{car}_checkng_rear34", "Prüfung: rot = Rückseite sichtbar (Verkleidung = Außenhaut)"),
            t(f"{car}_lampmap_rearclose", "Lampenkanäle (rot Rück, rosa Brems, magenta Rück+Brems, orange/gelb Blinker, grün Rückfahr, türkis Kennz.)"),
            t(f"{car}_caster_frontclose", "Schattenwerfer rot, wo er aus der Haut ragt")]
sheet = K.grid(ims, 4)
sheet = K.title(sheet, "Spielerautos: das Netz selbst (Ton, Facetten, Drahtgitter, Normalen, Prüfungen)")
print(K.save_jpg(sheet, K.DELIVER + "/04_spieler_netz.jpg", q=86))
