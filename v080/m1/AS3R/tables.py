"""AS3R scratch: before/after tables from the logs (markdown).  tables.py <hour> [tag]
tag "f" = final_batch on 4fb8187 merged with r7 (final code, 10 models); tag "z" = everything on the final head."""
import re
import sys

M1 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1"
K = M1 + "/KRITIK-3/logs"
S = M1 + "/AS3R/logs"
AS3 = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3/bericht.md"
R7 = {"props/tree_oak", "props/tree_oak_b", "props/tree_birch", "props/tree_birch_b", "props/tree_beech",
      "props/tree_beech_b", "props/tree_olive", "props/tree_olive_b", "props/tree_pine", "props/tree_pine_b"}


def sprung(path):
    out = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return out
    for line in lines:
        if not line.startswith("SPRUNG"):
            continue
        mid = line.split()[1]
        parts = {}
        for seg in line.split("  ", 1)[1].split("|"):
            seg = seg.strip()
            m = re.match(r"(\S+): Helligkeit ([-+\d.]+) %, Sättigung ([-+\d.]+) %, Kontrast ([-+\d.]+) %, Farbton ([-+\d]+)°", seg)
            if m:
                parts[m.group(1)] = tuple(float(m.group(i)) for i in range(2, 6))
        out[mid] = parts
    return out


def umschalt(path):
    out = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return out
    for line in lines:
        if not line.startswith("UMSCHALT"):
            continue
        mid = line.split()[1]
        vals = re.findall(r"@(\d+) m: ([\d.]+) % der Pixel.*?Helligkeit ([-+\d.]+) %", line)
        out[mid] = [(float(p), float(h)) for (_d, p, h) in vals[:2]]
    return out


def umschalt_as3():
    """noon rows of the AS3 report table 4.3 (same tool, be866d2): model -> (lod0>lod1 %, lod1>impostor %)"""
    out = {}
    for line in open(AS3, encoding="utf-8"):
        m = re.match(r"\| (\S+) \| Mittag \| (\d+) % / [^|]+\| (\d+) % / ", line)
        if m:
            out["props/" + m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return out


def flimmer(path):
    out = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return out
    for line in lines:
        if not line.startswith("FLIMMER"):
            continue
        toks = line.split()
        key = toks[1] + (" sprite" if toks[2] == "sprite" else "")
        out[key] = [float(x) for x in re.findall(r"([\d.]+) % Pixel kippen", line)]
    return out


def main():
    hour = sys.argv[1] if len(sys.argv) > 1 else "12"
    tag = sys.argv[2] if len(sys.argv) > 2 else "f"
    before = sprung(K + "/levels_h%s.log" % hour)
    after = sprung(S + "/%s_levels_h%s.log" % (tag, hour))
    after7 = sprung(S + "/r7_levels_h12.log") if (hour == "12" and tag == "f") else {}
    print("| Modell | lod0→lod1 Helligkeit vorher / nachher | lod1→Fernbild Helligkeit | Sättigung | Kontrast | Fernbild→Sprite Kontrast |")
    print("|---|---|---|---|---|---|")
    for mid in after:
        a = after7.get(mid, after[mid]) if mid in R7 else after[mid]
        b = before.get(mid, {})

        def f(d, k, i):
            v = d.get(k)
            return "%+.1f" % v[i] if v else "–"
        print("| %s | %s / %s | %s / %s | %s / %s | %s / %s | %s / %s |" % (
            mid.split("/")[1], f(b, "lod0>lod1", 0), f(a, "lod0>lod1", 0), f(b, "lod1>fern", 0), f(a, "lod1>fern", 0),
            f(b, "lod1>fern", 1), f(a, "lod1>fern", 1), f(b, "lod1>fern", 2), f(a, "lod1>fern", 2),
            f(b, "fern>sprite", 2), f(a, "fern>sprite", 2)))
    if hour != "12":
        return
    print()
    ub = umschalt_as3()
    ua = umschalt(S + "/%s_lods_h12.txt" % tag)
    ua7 = umschalt(S + "/r7_lods_h12.txt") if tag == "f" else {}
    print("| Modell | lod0→lod1 geänderte Pixel vorher / nachher | lod1→Fernbild geänderte Pixel vorher / nachher |")
    print("|---|---|---|")
    for mid in ua:
        a = ua[mid]
        if mid in R7 and mid in ua7:
            a = [ua7[mid][0], ua[mid][1]]
        b = ub.get(mid)
        print("| %s | %s / %.1f %% | %s / %.1f %% |" % (mid.split("/")[1], ("%.0f" % b[0]) if b else "–", a[0][0],
                                                    ("%.0f" % b[1]) if b else "–", a[1][0]))
    print()
    fb = flimmer(K + "/sparkle.log")
    fa = flimmer(S + "/%s_sparkle.log" % tag)
    if tag == "f":
        fa.update(flimmer(S + "/r7_sparkle.log"))
    print("| Modell | 40 / 80 / 150 m vorher | nachher | Arcade-Sprite |")
    print("|---|---|---|---|")
    for key in fa:
        if key.endswith("sprite"):
            continue
        print("| %s | %s | %s | %s |" % (key.split("/")[1], " / ".join("%.1f" % v for v in fb.get(key, [])),
                                         " / ".join("%.1f" % v for v in fa[key]),
                                         " / ".join("%.1f" % v for v in fa.get(key + " sprite", []))))


main()
