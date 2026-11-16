## 1. Zusammenführung (`25be6c7`, `--no-ff`)

Quelle `origin/wip/v080-fix-wasser-r` = `39849f0` (Zwischenstand 1, beim Nutzer) auf M2INT `49f221e`; Basis beider
Seiten `92ece73`. Vorher geprüft mit `git merge-tree`: Konflikte in `scripts/race3d/layers/far_ground.gd`,
`docs/renderer-modern-gelaende.md`, `tests/golden/modern_slice.md5/.env`; automatisch gemischt `props.gd`,
`vehicles.gd`, `test_props.gd`, `renderer-modern.md`, `qa-v080.md`.

| Konflikt | Lösung |
|---|---|
| `layers/far_ground.gd` | **eine Regel – die von FIX-WASSER** (Testbuild, bewacht von `test_far_ground_water` und K1): `target_height()` = min(tiefste Straße des Fensters − 4 m, tiefstes Wasser − 0,3 m), `lowest_water()` über `Track.bridges`, `window_rows()`. M2INTs `b341df8` (Wasserhöhe in `lowest_road(…, track)`, jede vierte Reihe, Scheibe 4 m unter dem Wasser) entfällt. Geprüft, ob `b341df8` mehr abdeckt: **nein** – `water_level` < 0 tragen nur Reihen in `Track.bridges` (`Track._mark_bridge`, eingefroren: einzige Stelle, die es setzt), dieselben Reihen liest FIX-WASSER vollständig (jede statt jeder vierten) und prüft `s.index == k` (eine aus dem Speicher der Strecke gefallene Reihe liefert bei `b341df8` die erste gehaltene Reihe, also eine falsche Höhe); an den Elbbrücken (3,6 m) hätte `b341df8` die Scheibe 7,6 m statt 4,0 m unter die Straße gelegt und das Bild geändert. Übernommen von `b341df8`: der **Unit-Test** `test_far_ground_lies_below_the_water_of_a_bridge` (synthetische Strecke, jetzt mit einer Brücke in `Track.bridges` und auf `target_height()` umgestellt; prüft zusätzlich, dass jede Wasserreihe gelesen wird – die tiefste liegt zwischen zwei Straßenproben) und der **Befund** „46 von 46 Schiffen auf Wassersegmenten“ in der Doku |
| `docs/renderer-modern-gelaende.md` | Text von FIX-WASSER + ein Absatz zur einen Regel + M2INTs Schiffsbefund |
| `tests/golden/modern_slice.*` | im Merge vorläufig M2INTs Liste, neu erzeugt nach dem Ansehen (Abschnitt 5) |

**Inhaltliche Konflikte** (automatisch gemischt, aber rot – `tools/run_tests.sh unit/race3d/` nach dem Mischen: 118
Tests, 2 rot, gemessen):
- `test_procedural_bridge_pylon_stand_in_stays_dark_at_night`: verlangte eine Sprite-Vertretung des Pylons – seit AS4R
  ist `props/bridge_pylon` ein Modell. Jetzt mit einem Test-Manifest ohne das Pylon-Modell (wie `check_vehicles`
  „kasten“): die dunkle Vertretung bleibt der Rückfall; neu `test_bridge_pylon_is_a_model_with_its_aviation_light`.
- `test_procedural_landmarks_without_sprite_or_model_get_their_fallback`: verlangte die Gruppe `l|<Ersatz-Set>|0` einer
  Vertretung – `props/church` und `props/building_tall` sind seit AS4R Modelle, das Ersatzbild steht als Modell da
  (Gruppe `m|…` mit Wahrzeichen-Flag). Der Test nimmt jetzt beide Formen an (Wahrzeichengesetz, nie gespiegelt,
  `fallback_scale`; Tönung nur bei einer Vertretung) und prüft **alle 20 Anfahrten** in die sechs Städte statt einer
  je Stadt.
Danach 119 von 119 race3d-Unit-Tests grün (gemessen).
