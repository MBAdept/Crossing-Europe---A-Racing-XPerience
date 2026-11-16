"""Measured tables for bericht.md from the manifests. usage: bericht_tables.py ROOT"""
import json
import os
import sys

ROOT = sys.argv[1]
man = json.load(open(os.path.join(ROOT, "assets/audio/modern/music/manifest.json"), encoding="utf-8"))["sounds"]
ui = json.load(open(os.path.join(ROOT, "assets/audio/modern/ui/manifest.json"), encoding="utf-8"))["sounds"]


def de(v, nd=1):
    return (f"{v:.{nd}f}").replace(".", ",").replace("-", "−")


print("| Datei | Länge | Schleife | Lautheit | True Peak nach Vorbis | Größe |")
print("|---|---|---|---|---|---|")
tot = 0
for sid in ["nachtfahrt", "nachtfahrt_schluss", "rueckenwind", "rueckenwind_schluss", "zwischenspiel"] + \
        [f"{p}_{k}" for p in ("linke_spur", "nachtfahrt", "rueckenwind")
         for k in ("ziel", "schluss_rekord", "schluss_finale", "polizei", "tank")]:
    e = man[sid]
    loop = "–"
    if e.get("loop"):
        a, b = e["loop"]
        loop = f"ab Frame {a:,} ({de(a / 44100, 2)} s), {de((b - a) / 44100, 2)} s".replace(",", "X").replace(".", ",").replace("X", ".")
    print(f"| `{e['file']}` | {de(e['frames'] / 44100, 1)} s | {loop} | {de(e['lufs'], 2)} LUFS | {de(e['true_peak_db'], 2)} dBTP | {de(e['bytes'] / 1e6, 2)} MB |")
for e in man.values():
    tot += e["bytes"]
print()
print(f"Musikordner zusammen (Manifest-Bytes): {de(tot / 1e6, 2)} MB von 25 MB")
print()
print("| UI-Klang | Lautheit (Datei, integriert) | True Peak | Bytes |")
print("|---|---|---|---|")
for sid in ("ui_move", "ui_ok", "ui_back", "ui_tab", "ui_toggle", "ui_error"):
    e = ui[sid]
    by = sum(e["bytes"]) if isinstance(e["bytes"], list) else e["bytes"]
    print(f"| `{sid}` | {de(e['lufs'], 2)} LUFS | {de(e['true_peak_db'], 2)} dBTP | {by:,} |".replace(",", "."))
