## 5. Leistung

### 5.1 Methode

Sonde `m1/QA-BILD/probe/qa_drive.gd` unter Xvfb (llvmpipe mit 2 Rasterthreads, `nice -n 10`, Last der VM 4–14 durch
andere Aufträge): Kiel–Hamburg ab km 0 mit dem Autopiloten (12 Uhr, Limousine, Seed 11, Tankstopp bei km 13,9). Je Bild:
Wanduhr-Bildzeit, GDScript-Zeit von `render()` (Differenz von `ModernRenderer._render_us`), ob ein Stück eingehängt wurde;
alle 5 s Speicher und Zähler; am Ende `perf_stats()`. Damit die Läufe fertig werden, lief die Simulation mit
`--timescale=2` – die Sitzung erlaubt dann 8 Physikschritte je Bild, jedes Bild bewegt die Welt also um bis zu 0,13 s
(8 × ein 60-Hz-Bild): die GDScript-Zeiten je Bild sind eher zu hoch, Bildzeiten unter llvmpipe sagen nichts über echte
Grafikkarten. „Hoch“ dauerte so 1 s je Bild: ganz nur km 0–33,7 (Abbruch aus Zeitgründen), dazu km 78–95 (City Limits)
als eigener Lauf. Zusätzlich `probe/qa_spikes.gd`: misst jede Ebene/jeden Builder mit `update()` einzeln über
Stellvertreter in `_updaters` (keine Datei des Spiels geändert).

### 5.2 Ergebnisse (gemessen)

| Kiel–Hamburg, 12 Uhr | Niedrig (ganz) | Mittel (ganz) | Hoch km 0–33,7 | Hoch km 78–95 (Stadt) | Arcade (ganz) |
|---|---|---|---|---|---|
| Laden bis zur ersten Rennszene | 15,1 s | 32,1 s | 37,5 s | 33,1 s | 0,65 s |
| davon Vorbereitung / Aufwärmen / Selbsttest | 14,0 / 12,1 / 0,72 s | 29,8 / 27,4 / 1,19 s | – | 30,5 / 28,0 / 1,39 s | – |
| Renderer-GDScript je Bild, Mittel (Budget §4.10) | 2,10 ms (1,2) | 1,92 ms (1,5) | 2,23 ms (2,0) | 2,67 ms (2,0) | `_draw` 8,96 ms |
| dto. p50 / p95 / p99 / max | 1,60 / 4,40 / 8,9 / 166 | 1,59 / 3,66 / 6,8 / 93 | 1,55 / 5,58 / 10,1 / 61 | 1,68 / 3,96 / 9,3 / 479 | p95 16,8, max 118 |
| Bilder mit Stück-Einhängen: p50 / p95 / max | 2,55 / 5,9 / 13,3 ms | 2,61 / 6,5 / 21,9 ms | 2,58 / 5,5 / 10,7 ms | 2,77 / 8,2 / 8,7 ms | – |
| `chunk_commit_ms_max` der Fahrt (Budget) | 9,5 ms (3) | 20,4 ms (3) | 3,3 ms (4) | 0,9 ms (4); beim Laden 54 ms | – |
| Zeichenaufrufe sichtbarer Durchgang Median / max (Budget inkl. Schatten) | 118 / 145 (400) | 135 / 162 (900) | 154 / 170 (1.500) | 171 / 183 (1.500) | – |
| Dreiecke Median / max (Budget) | 92 k / 128 k (250 k) | 99 k / 148 k (700 k) | 103 k / 132 k (1,5 M) | 119 k / 136 k (1,5 M) | – |
| Texturspeicher max | 155 MB | 174 MB | 188 MB | 187 MB | 207 MB |
| Prozess-RSS max | 937 MB | 981 MB | 1.012 MB | 1.058 MB | 578 MB |
| Bildzeit p50 unter llvmpipe (nur Software) | 223 ms | 670 ms | 1.032 ms | 1.232 ms | 148 ms |
| `ERGEBNIS` gegen Arcade | 28 Schlüssel, nur `gfx` anders | 28, nur `gfx` | – | – | – |

Den Schattendurchgang meldet der Compatibility-Renderer mit 0 Aufrufen; die Zeichenaufrufe oben sind nur der sichtbare
Durchgang. Sie und die Dreiecke liegen weit unter den Budgets. Der Renderer braucht in GDScript ein Viertel bis ein
Drittel von Arcades `_draw` (8,96 ms) – der Rückgewinn, den der Vertrag erwartet. Texturspeicher Modern unter Arcade
(wie RINT-B), RSS +400 MB (llvmpipe hält Texturen und Programme im Hauptspeicher; auf dem Deck geteilt, abgeleitet).

### 5.3 Spitzen

- Stück-Einhängen: unter Xvfb (echter GL-Pfad, Puffer werden synchron hochgeladen) bis 20,4 ms, kopflos in denselben
  Strecken 4,8–5,1 ms (`qa_spikes`, Last 10, `nice 19`); RINT-B prüft das Budget 3 ms nur kopflos und normiert
  (0,42–0,78 ms). Auf der Bildzeit von llvmpipe fallen Einhänge-Bilder nicht auf (p50 640 gegen 671 ms bei Mittel).
- Einzelbilder mit 45–479 ms `render()`: in 7 von 11 Fahrten (Xvfb und kopflos) je 1–2, an wechselnden Stellen
  (km 0,1 / 13,9 Tankstopp / 27,4 / 73,0 / 80,4 / 91,3 / 91,7 / 93,3 / 95,1 Ziel), meist in `vehicles.gd` (die eigene
  Uhr der Fahrzeug-Ebene zeigte 55, 92, 132, 169 und 474 ms), nie auf einem Einhänge-Bild, nie mit einem neuen Set, Bau oder Budget-Rückschnitt im
  selben Bild (`qa_spikes`: Bauten +0, Rückschnitte +0). An derselben Stelle nicht wiederholbar (Start ab km 85: keine
  Spitze). Wahrscheinlichste Ursache: der Prozess bekam bei Last 10–14 und `nice 10/19` zeitweise kaum Rechenzeit –
  eine Code-Ursache ist damit nicht ausgeschlossen. Am Tankstopp (km 13,9) 30–61 ms in 2 von 5 Fahrten.
- GL-Pfad gegen kopflos, Leistungstest-Szene „Stadt bei Nacht im Regen“ (Dortmund–Frankfurt km 216, 22 Uhr, Regen):
  kopflos `render()` im Mittel 1,14 ms (max 12,4), unter Xvfb mit „Mittel“ 1,80 ms (max 4,5); je Haken unter Xvfb
  Fahrzeuge 0,59, Lichter 0,27, Lichtpunkte 0,17, Gelände 0,15, Hintergrund 0,10 ms, Rest (Umgebung, Streamer, Kamera)
  ≈ 0,4 ms (`pruefungen/spikes_city_night*.log`). Der GL-Pfad kostet hier also ≈ +0,65 ms. QA-SYSTEMs Leistungstest
  maß in derselben Szene 7,10 ms (`script_ms` = `render_ms_avg` des Fensters, Voreinstellung Niedrig, Last 13) – das
  konnte ich nicht nachstellen; auf einer ruhigen Maschine nachmessen, bevor man es dem Deck-Ergebnis gegenüberstellt.
  Die Budget-Prüfungen (`kern_zeit`, `renderer_zeit`, `leistung`) laufen alle kopflos.

### 5.4 Speicher über 20 Minuten Fahrt

Lüttich–Paris ganz (395 km der Etappe, 16,2 min Spielzeit – die Etappe war vor den geplanten 20 min zu Ende),
Voreinstellung Mittel, `--timescale=32` (64 Physikschritte je Bild), 356 eingehängte Stücke, Proben alle 10 s
(`pruefungen/mem_modern_medium_samples.jsonl`, gemessen):

| Spielzeit | km | RSS | Skript-/Engine-Heap | Objekte | Knoten | Waisen | Texturen | Video gesamt |
|---|---|---|---|---|---|---|---|---|
| 1 s | 0 | 913 MB | 96,8 MB | 3.682 | 265 | 0 | 137,7 MB | 149,6 MB |
| 211 s | 94 | 937 MB | 102,9 MB | 3.925 | 348 | 0 | 142,0 MB | 152,8 MB |
| 483 s | 211 | 939 MB | 103,7 MB | 3.946 | 332 | 0 | 142,8 MB | 153,2 MB |
| 793 s | 355 | 937 MB | 103,9 MB | 3.938 | 311 | 0 | 142,8 MB | 153,2 MB |
| 971 s (Ziel Paris) | 395 | 939 MB | 100,4 MB | 3.210 | 414 | 0 | 143,8 MB | 154,8 MB |

Nach dem Anlaufen (erste 100 s) steht alles: kein Wachstum bei Speicher, Objekten, Ressourcen (262 konstant), keine
verwaisten Knoten, Texturspeicher +6 MB über die ganze Fahrt (neue Schilder/Ersatzbilder der Stadt), Stücke 9–14,
Fahrzeug-Instanzen am Budget (≤ 128). **Kein Hinweis auf ein Leck.** QA-SYSTEM fand bei 20 min Echtzeit im Rennen
Kiel–Nürnberg dasselbe (RSS +4 %). Bei 64 Physikschritten je Bild gab es wieder Einzelspitzen von 55–178 ms `render()`,
diesmal nicht in der Fahrzeug-Ebene (deren Uhr blieb unter 9 ms) – vermutlich der Pfad-/Streckenaufbau bei 60 m Weg je
Bild; für echte Bildraten nicht aussagekräftig.

### 5.5 Was echte Hardware braucht (abgeleitet)

- **CPU**: Renderer-GDScript hier 1,6 ms Median / 2–2,7 ms Mittel unter Last; das Steam Deck ist laut Vertrag ≈ 1,5 ×
  langsamer als diese VM ohne Last → etwa 1,5–3 ms Renderer, dazu Simulation ≈ 0,5–1 ms, HUD/Sitzung ≈ 1,5 ms und die
  Übergabe von 150–250 Zeichenaufrufen inkl. Schatten (≈ 1 ms) – zusammen etwa 5–7 ms je Bild: für 60 Bilder/s reicht
  es, sofern QA-SYSTEMs 7,1 ms in der Stadt-Nacht-Szene ein Lastartefakt sind (meine Messung dort: 1,8 ms).
- **GPU**: unbekannt. Unter llvmpipe kostet Modern 6–10 × Arcades Rasterzeit (Mittel 681–746, Hoch 1.317 ms gegen
  Arcade 103–132 ms je Bild), getrieben von Pixel-Shadern (Fahrbahn mit vielen Rauschstufen, Gelände, Blattkarten mit
  Alpha-Schnitt, Schatten mit 2–4 Kaskaden, MSAA). Grobe Schätzung: Steam Deck mit „Steam Deck“-Voreinstellung bei
  1280 × 800 etwa 8–14 ms GPU je Bild – 60 Bilder/s knapp, 40/45 Bilder/s sicher; ein Mittelklasse-PC (GTX-1060-Klasse)
  bei 1080p „Mittel“ etwa 4–7 ms. Erst der Leistungstest des Nutzers (Gate 1) misst das.
- **Laden**: hier 15–37 s, fast alles Aufwärmen (8 Bilder in vier Lichtsituationen mit 49 Aufwärm-Knoten); auf einer
  echten GPU sind das Millisekunden je Bild plus die Übersetzung der Shader beim ersten Start – geschätzt 3–8 s beim
  ersten Mal, 1–3 s danach. RINT-Bs 5,2–5,6 s ließen sich hier nicht nachstellen (Last, 2 statt 4 Rasterthreads).
