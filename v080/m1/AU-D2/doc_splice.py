"""Rewrites section 14 (Musik) of docs/audio-modern.md: new header, pieces table from the manifest, chain, the new
pieces, extras, interlude, UI sounds, shared mix, director, checks, traps, open points. Keeps 14.3 (title) and the
body of 14.4 (Linke Spur). usage: doc_splice.py ROOT"""
import json
import os
import re
import sys

ROOT = sys.argv[1]
DOC = os.path.join(ROOT, "docs", "audio-modern.md")
MUS = os.path.join(ROOT, "assets", "audio", "modern", "music", "manifest.json")
UI = os.path.join(ROOT, "assets", "audio", "modern", "ui", "manifest.json")
s = open(DOC, encoding="utf-8").read()
man = json.load(open(MUS, encoding="utf-8"))["sounds"]
uim = json.load(open(UI, encoding="utf-8"))["sounds"]


def de(v, nd=1):
    return (f"{v:.{nd}f}").replace(".", ",").replace("-", "−")


def mb(b):
    return de(b / 1e6, 2) + " MB"


def secs(e):
    return de(e["frames"] / 44100.0, 1) + " s"


rows = []
order = ["titel_remaster", "zwischenspiel"]
for p in ("linke_spur", "nachtfahrt", "rueckenwind"):
    order += [p, p + "_schluss", p + "_schluss_rekord", p + "_schluss_finale", p + "_ziel", p + "_polizei", p + "_tank"]
total = 0
for sid in order:
    e = man[sid]
    total += e["bytes"]
    loop = ""
    if e.get("loop"):
        a, b = e["loop"]
        loop = f"ab Frame {a} ({de(a / 44100.0, 2)} s), {e.get('loop_bars', '')} Takte = {de((b - a) / 44100.0, 2)} s"
    rows.append(f"| `{e['file']}` | `{e['role']}` | {e.get('bpm', 0):g} | {secs(e)} | {loop or '–'} | "
                f"{de(e['lufs'], 1)} LUFS / {de(e['true_peak_db'], 1)} dBTP | {mb(e['bytes'])} |")
for sid, e in man.items():
    if sid not in order:
        total += e["bytes"]
table = "\n".join(rows)
ui_rows = []
ui_total = 0
for sid in ("ui_move", "ui_ok", "ui_back", "ui_tab", "ui_toggle", "ui_error"):
    e = uim[sid]
    files = e.get("files") or [e["file"]]
    by = sum(e["bytes"]) if isinstance(e["bytes"], list) else e["bytes"]
    ui_total += by
    ui_rows.append(f"| `{sid}` | {', '.join('`' + f + '`' for f in files)} | {e['note'].split(': ', 1)[1]} | "
                   f"{de(e['lufs'], 1)} LUFS / {de(e['true_peak_db'], 1)} dBTP | {de(by / 1024.0, 0)} kB |")
ui_table = "\n".join(ui_rows)

start = s.index("## 14. Musik (Paket AU-D1)")
sec = s[start:]
title_part = sec[sec.index("### 14.3 Titel-Remaster"):sec.index("### 14.4 Rennstück 1")]
ls_part = sec[sec.index("### 14.4 Rennstück 1"):sec.index("### 14.5 Der `MusicDirector`")]
old_traps = sec[sec.index("### 14.7 Fallen"):sec.index("### 14.8 Offene Punkte")]
old_traps = old_traps.replace("### 14.7 Fallen (gemessen, Godot 4.7.2)", "### 14.13 Fallen (gemessen, Godot 4.7.2)")
old_traps = old_traps.rstrip("\n") + "\n"

new = open(os.path.join(os.path.dirname(__file__), "doc_section14.md"), encoding="utf-8").read()
new = new.replace("{TABLE}", table).replace("{UI_TABLE}", ui_table).replace("{MUSIC_MB}", de(total / 1e6, 2)) \
    .replace("{UI_KB}", de(ui_total / 1024.0, 0)).replace("{TITLE_PART}", title_part.rstrip("\n") + "\n") \
    .replace("{LS_PART}", ls_part.rstrip("\n") + "\n").replace("{OLD_TRAPS}", old_traps)
s = s[:start] + new
open(DOC, "w", encoding="utf-8").write(s)
print("ok", len(s.splitlines()), "Zeilen; Musik", de(total / 1e6, 2), "MB; UI", de(ui_total / 1024.0, 0), "kB")
