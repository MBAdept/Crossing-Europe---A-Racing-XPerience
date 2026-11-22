#!/usr/bin/env python3
"""AS5aR2: assemble bericht.md from the fragments. usage: assemble.py HEAD MODERNCOMMIT"""
import sys, pathlib
S = pathlib.Path("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2")
D = pathlib.Path("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR2")
head, mcommit = sys.argv[1], sys.argv[2]
parts = ["bericht_kopf.md", "bericht_pruefung.md", "bericht_aenderungen.md", "bericht_mess.md",
         "BUDGET", "bericht_rest.md", "bericht_einordnung.md", "bericht_naechste.md", "bericht_bilder.md"]
out = []
for p in parts:
    if p == "BUDGET":
        out.append("### Budgettabelle (alle 23 Stadthäuser, Endstand, gemessen; Export-Zeit auf dieser VM)\n\n"
                   + (S / "budget_table.md").read_text().strip() + "\n")
        continue
    out.append((S / p).read_text().rstrip() + "\n")
txt = "\n".join(out)
rep = {
    "ZUSAMMENFASSUNG": (S / "bericht_summary.md").read_text().strip(),
    "GEOMRESULT": "86 von 86 identisch, `CHECK sprite_geometry OK` (kein „ANDERS“)",
    "KEYSRESULT": "`CHECK cache_keys OK` (110 Modelle)",
    "TESTSRESULT": "749 Tests, 0 fehlgeschlagen, alle Prüfsuiten `CHECK … OK`, `==> Tests bestanden` (894 s)",
    "GOLDENRESULT": "20 von 20 und 17 von 17 identisch (`arcade-ui`)",
    "MODERNRESULT": ("4 von 6 identisch, GLES-Prüfung OK; `modern_s4_mittel` und `modern_s5_niedrig` (Kiel – Hamburg, "
                     "Einfahrt Hamburg, 12 Uhr) wichen ab, weil dort Charge-1-Häuser stehen (Innenring der Fernstufe "
                     "neu). Beide Bilder **angesehen** (Giebel-, Kontor- und Speicherhäuser bei Tag, keine Löcher, "
                     "kein Flackern, HUD unverändert), dann `tools/golden.sh modern-make`, Commit " + mcommit),
    "HEADCOMMIT": head,
}
for k, v in rep.items():
    txt = txt.replace(k, v)
for k in rep:
    assert k not in txt, k
(D / "bericht.md").write_text(txt)
print("bericht.md", len(txt.splitlines()), "Zeilen")
