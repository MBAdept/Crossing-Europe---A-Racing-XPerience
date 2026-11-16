"""AS3 scratch: table of the STUFEN / UMSCHALT lines of prop_scene (colours vs sprite, swaps).
   python3 stufen.py <log>"""
import colorsys
import re
import sys


def hv(c):
    h, s, v = colorsys.rgb_to_hsv(*[x / 255 for x in c])
    return round(h * 360), round(s, 2), round(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2], 1)


for line in open(sys.argv[1]):
    if line.startswith("STUFEN"):
        m = re.findall(r'(\w+)@(\d+)m rgb\((\d+),(\d+),(\d+)\)', line)
        name = line.split()[1]
        d = {"%s@%s" % (x[0], x[1]): (int(x[2]), int(x[3]), int(x[4])) for x in m}
        l0, l1a, l1, im, sp = d.get("lod0@60"), d.get("lod1@60"), d.get("lod1@200"), d.get("impostor@200"), d.get("sprite@200")
        if not l0:
            l0 = next(v for k, v in d.items() if k.startswith("lod0"))
            l1a = next(v for k, v in d.items() if k.startswith("lod1"))
        out = "%-24s lod0 %s %s" % (name, l0, hv(l0))
        if sp:
            out += "  sprite %s %s  luma sprite/lod0 %.3f" % (sp, hv(sp), hv(sp)[2] / max(1, hv(l0)[2]))
        if l1 and im:
            out += "  | lod1@far %s imp %s  imp/lod1 %.3f" % (hv(l1), hv(im), hv(im)[2] / max(1, hv(l1)[2]))
        print(out)
    elif line.startswith("UMSCHALT"):
        print("   " + line.strip()[:400])
