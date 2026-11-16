"""AS3 scratch: put the generated tables into the report (placeholders ⟨NAME⟩ -> file contents).
   python3 fill_report.py NAME=<file> [NAME=<file> ...]   (a value that is no file is put in as text)"""
import os
import sys

S = os.path.dirname(os.path.abspath(__file__))
REPORT = os.path.join(os.path.dirname(os.path.dirname(S)), "deliver", "AS3", "bericht.md")
txt = open(REPORT, encoding="utf-8").read()
for arg in sys.argv[1:]:
    name, val = arg.split("=", 1)
    key = "⟨%s⟩" % name
    if key not in txt:
        print("fehlt im Bericht:", key)
        continue
    path = val if os.path.isabs(val) else os.path.join(S, val)
    rep = open(path, encoding="utf-8").read().rstrip("\n") if os.path.isfile(path) else val
    txt = txt.replace(key, rep)
    print("eingesetzt:", key)
open(REPORT, "w", encoding="utf-8").write(txt)
left = [w for w in ("⟨HEAD⟩", "⟨GATES⟩", "⟨BILDER⟩", "⟨BUDGET⟩", "⟨TAGFARBE⟩", "⟨UMRISS⟩", "⟨STUFEN⟩", "⟨OVERDRAW⟩")
        if w in txt]
print("offen:", " ".join(left) if left else "nichts")
