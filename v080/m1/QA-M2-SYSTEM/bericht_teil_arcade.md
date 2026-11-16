## 1. Arcade-Identität (Regeln 1–3)

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Eingefrorene Dateien (Vertrag §2 Regel 1, alle 29 Pfade/Ordner) gegen `main` | **0 Dateien geändert**, keine fehlt, Arbeitsbaum sauber | `bin/frozen_diff.sh` → `frozen_diff.out` (gemessen) |
| `ERGEBNIS` von `run_stage.gd`: v0.7.0 (`git archive main`, eigener Import) gegen den Kopf mit `--graphics=arcade` | **identisch auf drei Etappen** (je 27 Schlüssel; der Kopf hat nur `gfx: "arcade"` dazu): Kiel – Hamburg ganz (12 Uhr, trocken, Seed 7, 95 km, 346,07 s), Bern – Mailand ab km 150 (22 Uhr, Schnee, Kompakt, Seed 3), Dortmund – Frankfurt ab km 170 (19:30, Regen, Gran Turismo, Seed 5) – andere Etappen als die Prüfung von M1 | `bin/ergebnis.sh` → `ergebnis/{ref,cur}_{kh,bm,df}.json` (gemessen) |
| Regel 3: dieselbe Etappe in Modern | Kiel – Hamburg: identisch bis auf `gfx: "modern"` | `ergebnis/curmodern_kh.json` (gemessen) |
| Arcade-Klang (Motor-Mischer je Auto mit Seed, `SfxSynth`, Verkehr, Busse mit Effekten, 40 eingefrorene Dateien) | Fingerabdruck aus v0.7.0 **selbst neu erzeugt** = eingecheckter Fingerabdruck = Kopf (172 Werte, ohne Bildschirm); `test_arcade_identity`, `check_modern_audio` (`arcade_after`: Mischer-SHA-256 wie v0.7.0) und `check_arcade_lean` im Testlauf grün | `audio_golden/{ref,cur}_headless.json` (gemessen) |
| Arcade-Bilder `tools/golden.sh check` | siehe Abschnitt 6 (einmal, zum Schluss) | |
