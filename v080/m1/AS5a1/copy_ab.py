"""AS5a1 scratch: copy the A/B pictures to the delivery with German names and write the A/B table rows.
   python3 copy_ab.py"""
import glob
import os
import re
import shutil

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a1/"
ORT = {"kh": "hamburg", "hh": "hannover", "kw": "wuerzburg"}
ORT_T = {"kh": "Hamburg (Kiel–Hamburg km 87,6)", "hh": "Hannover (Hamburg–Hannover km 141,7)",
         "kw": "Würzburg (Kassel–Würzburg km 201,7)"}
PRE = {"high": "hoch", "medium": "mittel"}
PRE_T = {"high": "Hoch", "medium": "Mittel"}
ZEIT = {"12": "mittag", "19.5": "daemmerung", "22": "nacht"}
ZEIT_T = {"12": "12 Uhr", "19.5": "19:30", "22": "22 Uhr"}
rows = []
n = 0
for f in sorted(glob.glob(S + "ab/*_ab_00.jpg")):
    m = re.match(r"(kh|hh|kw)_(high|medium)_h([\d.]+)_ab_00\.jpg", os.path.basename(f))
    if not m:
        continue
    o, p, h = m.groups()
    name = "ab_%s_%s_%s.jpg" % (ORT[o], PRE[p], ZEIT[h])
    shutil.copyfile(f, D + name)
    logs = ""
    for mode in ("arcade", "modern"):
        lp = S + "ab/%s_%s_h%s_%s.log" % (o, p, h, mode)
        if os.path.exists(lp):
            logs += open(lp, errors="replace").read()
    errs = len(re.findall(r"SCRIPT ERROR|Parse Error|^ERROR:", logs, re.M))
    rows.append("| `%s` | %s | %s | %s | beide Bilder da, %d Skriptfehler |" % (name, ORT_T[o], PRE_T[p], ZEIT_T[h], errs))
    n += 1
open(S + "tab_ab.md", "w").write("\n".join(rows) + "\n")
print("\n".join(rows))
print(n, "A/B-Bilder")
