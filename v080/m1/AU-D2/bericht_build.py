"""Assembles deliver/AU-D2/bericht.md from the parts in this folder. usage: bericht_build.py OUT"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
PARTS = ["bericht_teil_hoerproben.md", "bericht_teil_gebaut.md", "bericht_teil_messwerte.md",
         "bericht_teil_entscheidungen.md", "bericht_teil_einschaetzung.md", "bericht_teil_rest.md",
         "bericht_teil_dateien.md", "bericht_teil_gates.md"]


def rd(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read().strip("\n") + "\n"


text = "\n".join(rd(p) for p in PARTS)
text = text.replace("{BANDS}", rd("bands.md").strip("\n"))
missing = [t for t in ("{BANDS}", "{GATES}") if t in text]
if missing:
    sys.exit("Platzhalter offen: " + ", ".join(missing))
with open(OUT, "w", encoding="utf-8") as f:
    f.write(text)
print("ok", len(text.splitlines()), "Zeilen")
