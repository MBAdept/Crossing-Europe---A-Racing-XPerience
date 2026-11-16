"""Per player car: close-ups (rear first - what the player sees all the time), night lamps, interior, and the mesh
diagnostics sheet of all five."""
import sys

from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/bin")
import klib as K

B = "p"
T = (640, 400)


def t(n, lab):
    if not K.has_tile(n, B):
        im = Image.new("RGB", T, (40, 0, 0))
        return K.caption(im, "fehlt: " + n, 14)
    return K.caption(K.tile(n, B).resize(T, Image.LANCZOS), lab, 14)


def car_sheet(car, num):
    ims = [t(f"{car}_lod0_rear34", "Heck schräg (lod0, Renn-Look)"), t(f"{car}_lod0_rearclose", "Heck nah"),
           t(f"{car}_lod0_taillamp", "Rückleuchte nah, Tag (unbeleuchtet)"), t(f"{car}_night_taillamp", "Rückleuchte nah, Nacht, Rücklicht"),
           t(f"{car}_night_tail", "Nacht: Rücklicht + Kennzeichen"), t(f"{car}_night_brake", "Nacht: Rück + Brems (+ 3. Bremsleuchte)"),
           t(f"{car}_night_indl", "Nacht: Blinker links"), t(f"{car}_night_reverse", "Nacht: Rückfahrlicht"),
           t(f"{car}_lod0_cabin", "Kabine durch die Heckscheibe (Blick der Spielkamera)"), t(f"{car}_noglass_rear34", "Glas ausgeblendet: Innenraum"),
           t(f"{car}_lod0_wheel", "Hinterrad"), t(f"{car}_lod0_wheelf", "Vorderrad"),
           t(f"{car}_lod0_wheelf_low", "Vorderrad von unten (Radhaus)"), t(f"{car}_lod0_side", "Seite"),
           t(f"{car}_lod0_front34", "Front schräg"), t(f"{car}_lod0_frontclose", "Front nah"),
           t(f"{car}_lod0_headlamp", "Scheinwerfer nah"), t(f"{car}_night_head", "Nacht: Scheinwerfer"),
           t(f"{car}_show_rear34", "Showroom-Stufe show: Heck schräg"), t(f"{car}_show_wheel", "show: Hinterrad")]
    sheet = K.grid(ims, 4)
    sheet = K.title(sheet, f"player/{car}: Nahansichten (Spiel-Shader mit Renn-Look, Kontaktbogen-Rig, MSAA 4x)",
                    sub="Software-OpenGL (llvmpipe). Form, Lampen und Innenraum kommen vom Modell; Lackhelligkeit und Spiegelung vom Renderer (R3/R4).")
    print(K.save_jpg(sheet, K.DELIVER + f"/{num}_nah_{car}.jpg", q=85))


def net_sheet():
    ims = []
    for car in K.PLAYERS:
        ims += [t(f"{car}_clay_rear34", f"{car}: Ton"), t(f"{car}_facets_rearclose", "Facetten (flach)"),
                t(f"{car}_wire_rearclose", "Drahtgitter"), t(f"{car}_check_rear34", "Prüfung: rot = Rückseite, magenta = Normale gegen Wicklung"),
                t(f"{car}_lampmap_rearclose", "Lampenkanäle"), t(f"{car}_caster_side", "Schattenwerfer: rot = ragt aus der Haut"),
                t(f"{car}_sec_driver", "Schnitt durch den Fahrersitz (x = -0,36 m)"), t(f"{car}_sec_rearaxle", "Schnitt an der Hinterachse")]
    sheet = K.grid(ims, 8)
    sheet = K.title(sheet, "Spielerautos: das Netz selbst (Ton, Facetten, Drahtgitter, Prüfungen, Lampenkanäle, Werfer, Schnitte)",
                    sub="Lampenkanäle: dunkelrot Rück, rosa Brems, magenta Rück+Brems, orange/gelb Blinker, weiß Scheinwerfer, hellblau Tagfahr, grün Rückfahr, türkis Kennzeichen, violett Umriss/Kennzeichenleuchte.\nSchnitt: Innenseite rot, Lackteile hellgrau, feste Farben wie gebaut.")
    print(K.save_jpg(sheet, K.DELIVER + "/09_spieler_netz.jpg", q=84))


if __name__ == "__main__":
    for i, car in enumerate(K.PLAYERS):
        car_sheet(car, "0%d" % (3 + i))
    net_sheet()
