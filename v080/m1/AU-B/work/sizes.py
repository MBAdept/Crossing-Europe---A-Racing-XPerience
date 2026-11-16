"""Scratch (AU-B): sizes and facts of the final Modern engine assets."""
import glob
import json
import os
import sys

R = sys.argv[1] if len(sys.argv) > 1 else "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2"
d = os.path.join(R, "assets/audio/modern/engines")
tot = 0
for car in ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]:
    s = os.path.getsize(f"{d}/{car}.i16") + os.path.getsize(f"{d}/{car}.json")
    tot += s
    m = json.load(open(f"{d}/{car}.json", encoding="utf-8"))
    pts = sorted({b["rpm"] for b in m["banks"]})
    print(car, round(s / 1e6, 3), "MB", len(pts), "Punkte", round(pts[0]), "bis", round(pts[-1]), "gain", m["mix"]["gain"],
          "clips", {k: len(v) for k, v in m["clips"].items()}, "layers", sorted(m["layers"].keys()))
print("Banken zusammen", round(tot / 1e6, 3), "MB")
own = 0
n = 0
for f in sorted(glob.glob(os.path.join(R, "assets/audio/modern/vehicle/*.wav"))):
    if "platzhalter" in f:
        continue
    own += os.path.getsize(f)
    n += 1
print("Fahrzeugklänge", n, round(own / 1e6, 3), "MB")
old = sum(os.path.getsize(f) for f in glob.glob(os.path.join(R, "assets/audio/engines/*")) if not f.endswith(".import"))
print("Arcade-Banken", round(old / 1e6, 3), "MB")
for sub in ("engines", "vehicle"):
    print("Ordner", sub, round(sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(os.path.join(R, "assets/audio/modern", sub)) for f in fs) / 1e6, 3), "MB")
