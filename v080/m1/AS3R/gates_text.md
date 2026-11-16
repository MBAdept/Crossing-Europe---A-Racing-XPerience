Alle Gates liefen auf **638debc** (Endstand). Jeder schwere Lauf lief mit `nice -n 19` und einem Arbeiter, immer nur
einer zur selben Zeit. `$BPY` = `/home/user/tools/bpyenv/bin/python`.

| Gate | Befehl | Ausgabe | Ergebnis |
|---|---|---|---|
| Sprite-Geometrie | `$BPY tools/blender/check_sprite_geometry.py --only props --jobs 1` | `86 Sprite-Sets gebaut in 196 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen` · `CHECK sprite_geometry OK` · 0 × „ANDERS“ | grün |
| Cache-Schlüssel | `$BPY tools/blender/export_models.py --check-keys` | `CHECK cache_keys OK      46 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel` | grün |
| Determinismus | erzwungener Export aller 27 AS3-Modelle: `$BPY tools/blender/export_models.py --only=<glob> --force --jobs=1` für `props/tree_*`, `props/bush_*`, `props/cover_*`, `props/heather`, `props/rock_*`, `props/cliff` (350 s), dann `godot --headless --path . -s res://tools/models/bake_models.gd -- --only=<glob>` (je 0 Fehler), `godot --headless --path . --import`, `export_models.py --manifest-only`, `git status --porcelain` | `geschrieben: assets/models/manifest.json (46 Modelle, 182 Sets: 51 mit Modell, 131 Platzhalter)` · `git status`: leer bis auf das unversionierte Messwerkzeug `tools/kritik/` (inzwischen gelöscht) | grün, byte-gleich |
| Prüfer | `python3 tools/blender/validate_models.py --report` | `validate_models: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `Netze 5.27 MB von 40 MB, Texturen 25.37 MB im Grafikspeicher von 240 MB, Quellen 22.12 MB von 60 MB` · `CHECK models OK`, exit 0 | grün |
| Budget §4.6.9 | Tabelle 4.6 | Bäume ≤ 2 475 / 890 Dreiecke, ≤ 270 Karten, 2 / 2 / 1 Aufrufe; Büsche und Heide ≤ 396 / 118; Felsen 640 / 960; Klippe 5 799 von 6 000 | grün |
| Rennen A/B | `tools/ab_shot.sh` an fünf Stellen (Abschnitt 5) | alle exit 0; 0 Zeilen `SCRIPT ERROR`/`ERROR` in den Arcade- und Modern-Logs | grün |
| Tests (einmal) | `tools/run_tests.sh` | `298 Skripte geprüft, 0 fehlerhaft` … `692 Tests, 2 fehlgeschlagen` · `Tests FEHLGESCHLAGEN (271 s)` | **rot – nur die zwei bekannten Tests von R2** |
| Arcade-Bilder (einmal) | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (169 s)`, exit 0 | grün |
| Modell-Check (einzeln) | `godot --headless --path . -s res://tests/race3d/check_models.gd` | `CHECK models OK validate_models.py: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `CHECK defekte_dateien OK` · `CHECKS OK (0 fehlgeschlagen, 2 s)` | grün |
| Etappen-Check (einzeln) | `godot --headless --path . -s res://tests/race3d/check_modern_stage.gd -- --only=inhalt` | `CHECK inhalt OK Kiel – Hamburg: Straße (704 Dreiecke in 11 Stücken) …` · `CHECKS OK (0 fehlgeschlagen, 2 s)` | grün |

**Die zwei roten Tests** sind dieselben wie bei AS3 (be866d2): `tests/unit/race3d/test_props.gd ::
test_library_resolves_every_prop_set` („Buche: noch eine Vertretung: erwartet 2, ist 1“) und
`:: test_placement_drops_and_lamps` (`SCRIPT ERROR: Invalid access to property or key 's|props/tree_beech|1'`). Der
Test des Props-Bauers (R2) nimmt die Buche als Beispiel eines Sets ohne Modell, seit AS3 hat sie eins. Die Datei gehört
R2, ich habe sie nicht geändert; einen geprüften Vorschlag gibt es in `deliver/AS3/vorschlag_test_props_fuer_R2.diff`.
Der Klangtest, der bei AS3 unter Last rot war, ist diesmal grün. Weil `run_tests.sh` nach einem roten Unit-Test die
Integrationsszenarien und die Modern-Checks (`tests/race3d/check_*.gd`) überspringt, liefen die beiden Checks, die
Modelle laden, einzeln (Zeilen „einzeln“ oben).

Hinweis zum Ablauf: Der erste Hintergrundlauf der Gates wurde bei 30 Minuten vom Zeitlimit der Sitzung beendet, gleich
nach der Skriptprüfung von `run_tests.sh` (nur die Zeile `298 Skripte geprüft, 0 fehlerhaft`). Der Testlauf oben ist
der zweite und letzte; erst danach lief `golden.sh check`, einmal.
