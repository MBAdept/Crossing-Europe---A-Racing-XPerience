"""Assembles deliver/AS1/bericht.md from the three parts: bericht.py <scratch dir> <deliver dir> <commit>"""
import sys

S, D, commit = sys.argv[1], sys.argv[2], sys.argv[3]
text = "".join(open("%s/bericht_teil%d.md" % (S, i), encoding="utf-8").read() for i in (1, 2, 3))
runs = """| Lauf | Ergebnis |
|---|---|
| `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (10 Modelle, 180 Sets) |
| `check_sprite_geometry.py --jobs 2` (alle Sets) | 187 von 187 identisch, 1 davon „REIHENFOLGE“, 0 „ANDERS“, 346 s |
| `export_models.py --check-keys` | `CHECK cache_keys OK` (10 Modelle) |
| erzwungener Neuexport der sechs Fahrzeuge + Bake | Netze Byte für Byte unverändert (`git status` ohne Modelldateien) |
| `tools/run_tests.sh` (vollständig, einmal) | bestanden: 569 Tests, 0 fehlgeschlagen; 64 `CHECK … OK`, 0 `FEHLER`; 549 s |
| `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch` (151 s) |
| `tools/run_render_checks.sh modern check_models` | 1 von 1 Prüfdateien in Ordnung, 6 Prüfungen OK: Blinker Verkehrs-Limousine von hinten 390/389 · 390/390 · 390/390 px (lod0 · lod1 · lod2), von vorn 400/400 · 399/400 · 357/359 px (verlangt ≥ 240); Bremslicht 2,63 × Rücklicht in jeder Stufe |

Die Tests liefen auf dem Stand vor dem letzten Commit; der fügt nur eine Abbruchbedingung im Exporter und Text in
`docs/modelle.md` hinzu (die Modelldateien blieben beim Neuexport danach unverändert, der Prüfer grün).
Alle Läufe mit eigenem `XDG_DATA_HOME` im Arbeitsordner, Software-OpenGL unter Xvfb, höchstens zwei Prozesse.
"""
rep = {
    "@@COMMIT@@": commit,
    "@@TESTS_RESULT@@": "erfüllt",
    "@@TESTS@@": "`tools/run_tests.sh`: 569 Tests, 0 fehlgeschlagen; 64 `CHECK … OK`, 0 `FEHLER`; 549 s",
    "@@GOLDEN_RESULT@@": "erfüllt",
    "@@GOLDEN@@": "`tools/golden.sh check`: 20 von 20 identisch (151 s)",
    "@@RENDER_RESULT@@": "erfüllt",
    "@@RENDER@@": "`tools/run_render_checks.sh modern check_models`: 6 Prüfungen OK (Blinker ≥ 240 px in jeder Stufe, Bremslicht 2,63 × Rücklicht)",
    "@@RUNS@@": runs,
    "8. **Rücklicht bei Nacht** ist am Spielerauto recht dunkel gegen das Bremslicht (Verhältnis 2,6) – Geschmackssache\n   des Renderers (`lamp`-Energien), nicht des Netzes.":
    "8. **Rücklicht bei Nacht** ist am Spielerauto recht dunkel gegen das Bremslicht – eine Frage der Lampenenergien\n   des Renderers, nicht des Netzes.",
}
for k, v in rep.items():
    assert k in text, k[:40]
    text = text.replace(k, v)
assert "@@" not in text
open(D + "/bericht.md", "w", encoding="utf-8").write(text)
print(len(text.split("\n")), "lines")
