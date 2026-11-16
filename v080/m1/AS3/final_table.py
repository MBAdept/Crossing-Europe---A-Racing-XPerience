"""AS3 scratch: markdown tables from the final STUFEN / UMSCHALT logs of prop_scene (three hours).
   python3 final_table.py <group> (baeume | varianten | niedrig)"""
import colorsys
import os
import re
import sys

S = os.path.dirname(os.path.abspath(__file__))
HOURS = [("12", "Mittag"), ("19.5", "Dämmerung"), ("23", "Nacht")]
SW = re.compile(r'(\S+)>(\S+) @(\d+) m: ([\d.]+) % der Pixel / ([\d.]+) % der 3x3-Blöcke geändert, '
                r'Helligkeit ([+-]?[\d.]+) %, Farbton ([+-]?[\d.]+)°')


def luma(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def hue(c):
    return colorsys.rgb_to_hsv(*[x / 255 for x in c])[0] * 360


def parse(path):
    st, sw = {}, {}
    if not os.path.exists(path):
        return st, sw
    for line in open(path):
        if line.startswith("STUFEN"):
            name = line.split()[1]
            m = re.findall(r'(\w+)@(\d+)m rgb\((\d+),(\d+),(\d+)\)', line)
            st[name] = {"%s@%s" % (x[0], x[1]): (int(x[2]), int(x[3]), int(x[4])) for x in m}
        elif line.startswith("UMSCHALT"):
            name = line.split()[1]
            sw[name] = {"%s>%s" % (x[0], x[1]): dict(d=int(x[2]), px=float(x[3]), blk=float(x[4]), lum=float(x[5]),
                                                     hue=float(x[6])) for x in SW.findall(line)}
    return st, sw


def main():
    grp = sys.argv[1]
    data = {h: parse(os.path.join(S, "logs", "f_stufen_%s_%s.txt" % (grp, h))) for h, _ in HOURS}
    names = list(data["12"][0].keys())
    print("Tagfarbe (12 Uhr): lod0 in 60 m gegen das Arcade-Sprite in 200 m (gleiches Licht, Mittel der Innenpixel"
          " je Bild; gemessen)\n")
    print("| Modell | lod0 RGB | Sprite RGB | Helligkeit lod0 / Sprite | Farbton-Abstand |")
    print("|---|---|---|---|---|")
    for n in names:
        d = data["12"][0][n]
        l0 = next((v for k, v in d.items() if k.startswith("lod0")), None)
        sp = next((v for k, v in d.items() if k.startswith("sprite")), None)
        if l0 and sp:
            dh = (hue(l0) - hue(sp) + 180) % 360 - 180
            print("| %s | %s | %s | %+.1f %% | %+.0f° |" % (n.split("/")[1], l0, sp, (luma(l0) / max(1, luma(sp)) - 1) * 100, dh))
    print("\nUmschalten (UMSCHALT, Innenpixel; geänderte Pixel = Anteil der Pixel, die sich um mehr als die Schwelle"
          " ändern; gemessen)\n")
    print("| Modell | Stunde | lod0→lod1: Pixel / Helligkeit / Farbton | lod1→Fernbild: Pixel / Helligkeit / Farbton |"
          " Fernbild→Sprite: Helligkeit |")
    print("|---|---|---|---|---|")
    for n in names:
        for h, hn in HOURS:
            sw = data[h][1].get(n, {})
            a = sw.get("lod0>lod1")
            b = next((v for k, v in sw.items() if k.startswith("lod1>") and k != "lod1>Sprite"), None)
            c = next((v for k, v in sw.items() if k.endswith(">Sprite")), None)
            fa = "%.0f %% / %+.1f %% / %+.0f°" % (a["px"], a["lum"], a["hue"]) if a else "–"
            fb = "%.0f %% / %+.1f %% / %+.0f°" % (b["px"], b["lum"], b["hue"]) if b else "–"
            fc = "%+.1f %%" % c["lum"] if c else "–"
            print("| %s | %s | %s | %s | %s |" % (n.split("/")[1], hn, fa, fb, fc))


main()
