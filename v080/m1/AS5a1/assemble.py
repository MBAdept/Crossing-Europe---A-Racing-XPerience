"""AS5a1 scratch: assemble deliver/AS5a1/bericht.md from the parts and the measured tables.
   python3 assemble.py <HEAD sha>"""
import re
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a1/"
head = sys.argv[1] if len(sys.argv) > 1 else "HEAD"


def rd(name):
    try:
        return open(S + name).read()
    except OSError:
        return "(fehlt: %s)\n" % name


def umriss():
    rows = []
    for l in open(S + "meas_outline.log"):
        if not l.startswith("UMRISS"):
            continue
        mid = l.split()[1].split("/")[1]
        v = re.findall(r"(lod\d) ([\d.]+) % außerhalb, Sprite zu ([\d.]+) % gedeckt \(IoU ([\d.]+)\)", l)
        d = {x[0]: x for x in v}
        c = lambda s: s.replace(".", ",")
        rows.append("| `%s` | %s %% | %s %% | %s | %s |" % (mid, c(d["lod0"][1]), c(d["lod0"][2]), c(d["lod0"][3]),
                                                           c(d["lod1"][3])))
    return "\n".join(rows)


def stufen():
    rows = []
    for fn in ("meas_lods_ger.log", "meas_lods_old.log", "meas_lods_han.log"):
        out = {}
        for l in open(S + fn):
            if not l.startswith("UMSCHALT"):
                continue
            mid = l.split()[1].split("/")[1]
            g = re.search(r"lod0>lod1 @60 m: ([\d.]+) % der Pixel / ([\d.]+) % der 3x3-Blöcke geändert, "
                          r"Helligkeit ([+-][\d.]+) %", l)
            out.setdefault(mid, []).append("%s / %s %%, Helligkeit %s %%" % (
                g.group(1).replace(".", ","), g.group(2).replace(".", ","), g.group(3).replace(".", ",")))
        for mid, v in out.items():
            rows.append("| `%s` | %s | %s |" % (mid, v[0], v[1] if len(v) > 1 else "–"))
    return "\n".join(rows)


def flimmer():
    m, sp = {}, {}
    for l in open(S + "meas_spark.log"):
        if not l.startswith("FLIMMER"):
            continue
        parts = l.split()
        mid = parts[1].split("/")[1]
        vals = [v.replace(".", ",") for v in re.findall(r"\d+ m \w+: ([\d.]+) %", l)]
        (sp if parts[2] == "sprite" else m)[mid] = vals
    rows = []
    for mid, v in m.items():
        s = sp.get(mid, ["–"] * 4)
        rows.append("| `%s` | %s %% | %s %% | %s %% | %s %% | %s %% |" % (mid, v[0], v[1], v[2], v[3], " / ".join(s)))
    return "\n".join(rows)


kopf = rd("bericht_kopf.md").replace("{{HEAD}}", head).replace("{{BUDGET}}", rd("budget_table.md").strip())
kopf = kopf.replace("{{ARCHIV}}", rd("archiv.txt").strip())
mess = rd("bericht_teil_mess.md").replace("{{UMRISS}}", umriss()).replace("{{STUFEN}}", stufen())
mess = mess.replace("{{FLIMMER}}", flimmer())
parts = [kopf, rd("bericht_gates.md"), mess, rd("bericht_ab.md"), rd("runden_final.md"), rd("bericht_teil_einordnung.md"),
         rd("bericht_dateien.md"), rd("bericht_lieferung.md")]
open(D + "bericht.md", "w").write("\n".join(p.rstrip() + "\n" for p in parts))
print("geschrieben:", D + "bericht.md")
