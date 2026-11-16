Alle Läufe mit `nice -n 19`, ein Prozess, `XDG_DATA_HOME` absolut im Scratch.

| Gate | Befehl | Ausgabe | Ergebnis |
|---|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `validate_models: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `Netze 5.23 MB von 40 MB, Texturen 37.37 MB im Grafikspeicher von 240 MB, Quellen 37.10 MB von 60 MB` · `CHECK models OK`, exit 0 | grün |
| Budget | Tabelle Abschnitt 3 | alle 27 AS3-Modelle im Budget (Bäume ≤ 2 475 / 889 Dreiecke, ≤ 270 Karten; Büsche/Heide ≤ 396 / 118; Felsen 640 / 960; Klippe 4 341) | grün |
| Sprite-Geometrie | `/home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1` | `86 Sprite-Sets gebaut in 279 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen` · `CHECK sprite_geometry OK` · 0 × „ANDERS“ (auch direkt nach der letzten cesprites-Änderung f67ade1: 86/86, 273 s) | grün |
| Cache-Schlüssel | `… export_models.py --check-keys` | `CHECK cache_keys OK 46 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel` | grün |
| Determinismus | erzwungener zweiter Export aller 27 AS3-Modelle: `export_models.py --only=<glob> --force --jobs=1` für `props/tree_*`, `props/bush_*`, `props/cover_*`, `props/heather`, `props/rock_*`, `props/cliff` (381 s), `bake_models.gd --only=<glob>` (12 s, 0 Fehler), `godot --import`, `--manifest-only`, dann `git status --porcelain` | leer – alle Dateien byte-gleich zu 791853f (seither keine Modell- oder Pipeline-Änderung) | grün |
| Rennen Modern | `tools/ab_shot.sh` an vier Zensus-Stellen (4.7) | alle exit 0, 0 Zeilen `ERROR`/`SCRIPT ERROR` in Arcade- und Modern-Log | grün |
| Tests (einmal) | `tools/run_tests.sh` | `298 Skripte geprüft, 0 fehlerhaft` … `692 Tests, 3 fehlgeschlagen` · `Tests FEHLGESCHLAGEN (300 s)` | **rot** – siehe unten |
| Arcade-Bilder (einmal) | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (229 s)` | grün |

**Die drei roten Tests:**
1. `tests/unit/race3d/test_props.gd :: test_library_resolves_every_prop_set` („Buche: noch eine Vertretung: erwartet
   2, ist 1“) und `:: test_placement_drops_and_lamps` (`SCRIPT ERROR: Invalid access to property or key
   's|props/tree_beech|1'`): der Test des Props-Bauers (R2) nimmt die Buche als Beispiel eines Sets **ohne** Modell
   – AS3 liefert genau dieses Modell. Die Datei gehört nicht zu AS3, ich habe sie nicht geändert. Geprüfter
   Vorschlag für R2: `vorschlag_test_props_fuer_R2.diff` (die Kirche statt der Buche als Vertretung; lokal
   angewendet: `tools/run_tests.sh test_props` → `7 Tests, 0 fehlgeschlagen`, danach zurückgesetzt).
2. `tests/unit/audio_modern/test_modern_checks.gd :: test_profiles_in_a_running_game_with_playback`
   (`CHECK race FEHLER`, Klang, läuft mit `--graphics=arcade` – lädt keine Modelle): hängt an der Last der Maschine.
   Einzeln gestartet (`godot --headless … -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade
   --live`) meldet derselbe Check `CHECK race OK … Sitzung in 211 von 212 Bildern da`; im Testlauf unter Last 101
   von 113 bzw. 102 von 106 Bildern. Nicht von AS3 verursacht (kein AS3-Code im Arcade-Lauf).
