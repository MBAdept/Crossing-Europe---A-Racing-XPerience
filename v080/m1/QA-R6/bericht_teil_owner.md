## 3. Arcade-Identität und Dateibesitz

`git diff 6e48405..c8b18d1 --stat` (gemessen): 18 Dateien, +3366 / −331.

| Datei | im Brief von R6? | Bewertung |
|---|---|---|
| `scripts/race3d/builders/{station,border,city,gantry,radar}.gd` (+ `.uid`) | ja | in Ordnung |
| `tests/unit/race3d/test_structures.gd`, `tests/race3d/render/check_structures.gd` | ja | in Ordnung |
| `tests/race3d/render/check_structures_licht.gd` (neu, 12 Zeilen, erbt) | nein (neue Datei derselben Art) | in Ordnung, gemeldet (Laufzeit > 900 s) |
| `docs/renderer-modern-bauten.md` (neu) | nein | in Ordnung als neue Datei; Verweis in `docs/renderer-modern.md` fehlt (Datei von R4) |
| `tests/race3d/check_minimal_structures.gd` (2 Stellen) | **nein – fremde Datei** | sachlich nötig (die Prüfung zählte `Label3D`, das die Leitung verboten hat), gemeldet; Konfliktgefahr gering |
| `tests/golden/modern_slice.md5`, `.env` | **nein – Spalte W3 „–“** | Konflikt mit R4/R5 sicher; beim Zusammenführen `golden.sh modern-make` einmal auf dem Gesamtstand (Befund B-07) |
| `scripts/race3d/builders/props.gd` | Leitungsausnahme | **nicht geändert** – richtig: `props.gd:109` setzt `_skip_objects`, sobald `renderer.builder("city")` existiert, und `OBJECT_SETS` kennt nur `streetlight` (gelesen) |

Keine eingefrorene Arcade-Datei im Diff (Abgleich gegen die Liste von §2 Regel 1). `layers/lights.gd`, `layers/flares.gd`,
`modern_renderer.gd` unberührt. Kein Builder nennt eine `class_name` eines anderen Pakets dieser Welle; der Renderer wird nur
über `renderer.get("materials"|"track"|"cfg")`, `ctx.services["renderer"].call(&"add_lamps", …)` und `has_method`
angesprochen (gelesen). `Label3D`: kein Vorkommen im Code von R6 außer in Kommentaren (`grep`).

## 4. Code-Durchsicht (gelesen, gefolgert)

- Worker-Thread-Regel eingehalten: `build()` liest nur `ctx`-Schnappschüsse und die Tabellen aus `collect()`; Track-Zugriffe
  (`columns_in_chunk`, `pillars_in_chunk`) laufen in `collect()` auf dem Hauptthread.
- `collect()` von `station`/`border` erzeugt Track-Segmente bis 120 m + `generation_lead_m()` hinter einem Dach vorab. Die
  Simulation bleibt gleich (Regel-3-Lauf über die ganze Testetappe, Abschnitt 2).
- Schrifttafeln: `PanelAtlas` legt die Zellen sofort in `prepare()` an (die UVs stimmen schon, bevor das Bild gelesen ist);
  ein vor dem Lesen gebautes Material bekommt die Texturen in `prepare_pending()` nachgereicht. Headless: Platzhalter.
- Countdown-Lampen und Blitz ändern ihre `add_lamps()`-Einträge je Bild über `update()` der Builder; `flares.gd` liest
  Farbe, Stärke und Größe je Bild aus dem Eintrag (gelesen) – das funktioniert ohne Änderung an R4s Dateien.
  Kleinigkeit: Einträge mit Rolle `"on"` und Stärke 0 (jede Blitzerkamera ohne Blitz, Countdown-Lampen aus) erzeugen
  trotzdem je Bild eine unsichtbare Flare-Instanz (`flares.gd:205` prüft `on`, nicht `energy`).
- Die Lampen der Lichtkegel liegen im Dach-/Platten-Kasten; `flare.gdshader` prüft die Verdeckung mit fünf Tiefen-Taps an
  der Lampe, deshalb bleibt deren warmer Laternenschein unsichtbar (so beabsichtigt, Umweg für eine fehlende Option in
  `flares.gd`).
- `city.gd` holt `props/streetlight` in LOD0 – das Modell hat nur diese eine Stufe (274 Dreiecke, Manifest), also richtig.
