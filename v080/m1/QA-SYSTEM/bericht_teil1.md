## 1. Arcade-Identität (Regeln 1–3)

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Eingefrorene Dateien (Vertrag §2 Regel 1, alle 29 Pfade/Ordner) gegen `main` | **0 Dateien geändert**, keine fehlt, Arbeitsbaum sauber | `bin/frozen_diff.sh` (gemessen) |
| `ERGEBNIS` von `run_stage.gd`, v0.7.0 (`git archive v0.7.0`, eigener Import) gegen diesen Baum mit `--graphics=arcade` | **identisch** auf drei Etappen: Kiel–Hamburg 12 Uhr trocken, dev_testetappe 21 Uhr Regen, Hamburg–Hannover 22 Uhr Schnee (je 27 Schlüssel; dazu nur `gfx: "arcade"`) | `ergebnis/ref_*.json`, `ergebnis/cur_*.json` (gemessen) |
| Regel 3: dieselbe Etappe in Modern | dev_testetappe Regen/Nacht: identisch bis auf `gfx: "modern"` | `ergebnis/curmodern_dev.json` (gemessen) |
| Klang-Fingerabdruck Arcade (Motor-Mischer je Auto mit Seed, `SfxSynth`, Verkehr, Busse mit Effekten, 40 eingefrorene Dateien) | aus v0.7.0 **selbst neu erzeugt** = eingecheckter Fingerabdruck = dieser Baum (ohne Bildschirm) | `audio_golden/ref_headless.json`, `cur_headless.json` (gemessen) |
| Arcade-Bilder `tools/golden.sh check` | **20 von 20 identisch** (Abschnitt 8) | `golden.log` (gemessen) |
| Herkunft der Hash-Liste, unabhängig nachgerechnet | race_s1 von v0.7.0 selbst gerendert = Eintrag der Liste (00b9c70a…) = dieser Baum **ohne** `--shot-fast` (volle Renderschleife wie beim Spieler); race_n1 dieser Baum ohne `--shot-fast` = Liste (c62695c8…) | `golden_spot/` (gemessen) |
| Arcade bei 1280×800 (Steam-Deck-Fenster, Balken) | v0.7.0 = dieser Baum (d516d6bc…) | `golden_spot/*_1280x800_00.png` (gemessen) |
| Menübilder Arcade v0.7.0 gegen diesen Baum (Beispieldaten, 1280×720, 2 Zeitpunkte je Bildschirm) | siehe Abschnitt 1.1 | `menus/1280x720/` |

### 1.1 Menüs in Arcade gegen v0.7.0

Zwölf Bildschirme mit `--screen=<name>` (Beispieldaten), je zwei Bilder bei 1,0 s und 3,0 s, `--fixed-fps 60`, einmal mit
v0.7.0 und einmal mit diesem Baum (`--graphics=arcade`), `bin/menu_shots.sh` + `bin/menu_compare.sh` (gemessen):

- **bildgleich (md5)**: Titel, Rennwahl, Etappenwahl, Routenwahl, Etappenbildschirm, Etappenergebnis, Rennergebnis,
  Bestenlisten, Fähre – 9 von 12, beide Zeitpunkte.
- **Optionen**: anders, so gewollt (zwei Seiten, „Klang“, „Musik im Rennen“; „Vollbild“ steht jetzt auf GRAFIK) –
  Bild `menus/options_ref_cur.png`.
- **Fahrzeugwahl, Startzeit**: 424–966 bzw. 896 Pixel anders, ausschließlich im Band der ◀▶-Pfeile. Die Pfeile pulsieren
  mit `Time.get_ticks_msec()` (Wanduhr, `vehicle_screen.gd:162`, `start_time_screen.gd:126`); beide Dateien sind gegen
  `main` unverändert. Kein Unterschied des Spiels, sondern einer der Uhr (abgeleitet aus Code und Lage der Pixel).
- **Ladebild** „Etappe wird geladen …“ so, wie die Menüs es zeigen (ohne `set_progress`): v0.7.0 = dieser Baum, md5
  9387c10d… (`gd/qa_loading_overlay.gd`, Ordner `loading/`, gemessen).
- **Pausemenü** über einem Arcade-Rennen (S1, 150 Bilder, dann `_pause_now()`, Bild nach 30 weiteren Bildern,
  `--fixed-fps 60`): v0.7.0 = dieser Baum, md5 c951403f… (`gd/qa_pause_shot.gd`, Ordner `pause/`, gemessen).
- Nicht verglichen: die Menüs bei 1280×800 (A-6 sieht dafür eine zweite Liste von QA1 vor; dafür brauchen die Pfeile
  von Fahrzeugwahl und Startzeit eine Spieluhr statt der Wanduhr).
