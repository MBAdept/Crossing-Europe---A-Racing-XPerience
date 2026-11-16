## 9. Läufe

| Lauf | Ergebnis |
|---|---|
| `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (10 Modelle, 180 Sets, 25 mit Modell); Netze 4,09 MB von 40 MB, Texturen 4,59 MB von 240 MB, Quellen 1,43 MB von 60 MB; dazu `CHECK models OK` im Testlauf |
| `check_sprite_geometry.py --jobs 2` (alle Sets, nach der letzten Änderung an `cesprites`) | 187 von 187 identisch, davon 1 „REIHENFOLGE“ (UV-Kugel des Fernsehturms, wie in v0.7.0), 0 „ANDERS“, 353 s |
| `export_models.py --check-keys` | `CHECK cache_keys OK` (10 Modelle) |
| erzwungener Neuexport (`--force`) und zweiter Bake aller sechs Fahrzeuge | `git status` danach leer: alle Modelldateien byte-gleich |
| `tools/run_tests.sh` (vollständig, einmal) | `==> Tests bestanden (552 s)`, Exit 0: 228 Skripte geprüft, 0 fehlerhaft; 576 Unit-Tests, 0 fehlgeschlagen; 89 `CHECK … OK` (darunter `CHECK models OK`, `arcade_lean`, `gfx_fallback`, `modern_sight_*`), 0 fehlgeschlagen |
| `tools/golden.sh check` (einmal, am Ende) | `GOLDEN arcade: 20 von 20 identisch (151 s)`, Exit 0 |
| `tools/run_render_checks.sh modern check_models` | `RENDER-CHECKS OK (0 fehlgeschlagen)`: klassen, lampen, lackcodes, blinker (≥ 240 px je Seite in jeder Stufe), bremslicht (Verkehrs-Limousine 2,63 × Rücklicht in `lod0`/`lod1`/`lod2`), multimesh |

Alle Läufe mit eigenem `XDG_DATA_HOME` im Arbeitsordner, schwere Läufe nacheinander mit `nice -n 10` und höchstens
zwei Prozessen.

## 10. Geänderte gemeinsame Dateien (für die Zusammenführung mit AS1b)

Nur additiv und rückwärtsverträglich:
- `tools/blender/ce3d/decalgeo.py`: `Tris.split_z(z, where=None)`; `pocket()` liefert zusätzlich `area`;
  `car_surfaces(..., far_plate=None, glass_look=None, far_sill=False)`.
- `tools/blender/ce3d/lod.py`: nur die Fahrzeugtabellen `PLAYER_DETAIL` (lod0/show: `seam` 1,8, `bumper_clamp`,
  `plate_bold`, `bumper_end_r`) und `TRAFFIC_DETAIL` (lod0: `bumper_clamp`, `bumper_end_r`, `tyre_lite`; lod1:
  `bumper_clamp`; shadow: `arch_n` 6). `lod.py` steht in `COMMON_CODE`: Alle Cache-Schlüssel ändern sich, die
  Requisiten wurden nicht neu exportiert (ihre Dateien sind unverändert).
- `tools/blender/ce3d/catalog3d.py`: im Fahrzeugblock beim Schrägheck `far_sill=False`.
- `tools/blender/validate_models.py`: Lichtanker von Fahrzeugen (`kind` vehicle/heavy) ohne `dir` sind ein Fehler.
- `docs/modelle.md`: Abschnitte 1 (Kontaktbogen-Optionen), 8 (neue Hooks), 11 (Messwerte der sechs Fahrzeuge),
  13 (Fahrzeugmodelle, neuer Unterabschnitt „Nacharbeit nach der Kunstkritik (AS1R)“).
- `assets/models/manifest.json`: neu erzeugt (nur Fahrzeugeinträge geändert) – bei der Zusammenführung neu erzeugen.
- Eigene Dateien: `ce3d/{vehicles3d,traffic3d,truck3d,interior3d,extras3d}.py`, `cesprites/{carbody,cardetail,vehicles}.py`
  (nur Hooks mit Voreinstellung „wie im Sprite“), `tools/models/contact_sheet.gd`, `assets/models/{player,traffic}/**`.
  `vpbr.gdshader`, `glass.gdshader`, `model_factory.gd`, `modern_materials.gd` sind unverändert.
