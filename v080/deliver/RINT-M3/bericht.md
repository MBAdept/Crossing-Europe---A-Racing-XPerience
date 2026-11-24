# RINT-M3 – dritter Zusammenbau von M2 (FIX-RINT + FIX-R7a/-R7b/-R7c, Vertrag §11.4)

Zweig `wip/v080-rint-m3`, Basis `3248211` (FIX-RINT). Arbeitsbaum `.claude/worktrees/wf_a71eeb2e-3b7-1`.

Ablauf: Der Montage-Auftrag lief am 23.11. von 14:50 bis 16:05 UTC und wurde von einem Kontolimit gestoppt.
Er hatte die drei Merges, §11.4 und die Leitungsnotizen 1–6, 8 und 10 sowie N-01 und N-02 fertig und gepusht.
Danach ist das Werkzeug für parallele Hilfsabläufe nicht mehr verfügbar. Ab 19:55 UTC führt die Leitung die Montage
selbst zu Ende (Notizen 7, 9, 11, 12, Bilder, Clips, Tore, Bericht). Die Maschine wurde dazwischen neu gestartet:
alle Hintergrundläufe des Vorgängers waren weg und sind neu gelaufen; seine Messungen unter Last 9–10 sind nur dort
zitiert, wo sie als solche gekennzeichnet sind.

## 1. Kurzfassung

Endstand **`720eaf4`** auf `wip/v080-rint-m3` (gepusht). Die drei R7-Pakete sind auf FIX-RINT zusammengebaut, §11.4
steht im Vertrag, die Leitungsnotizen 3–13 sind umgesetzt oder begründet entschieden, N-01 und N-02 behoben.

- **Eine Nacharbeit aus der Montage**: die Waldprüfung des Instanzbudgets war rot (236 > 230), weil die Leitplanken seit
  dem schrittweisen Einhängen je Stück einen eigenen Knoten mit Fahrzeugmaterial anlegten; jetzt Flächen eines Knotens
  (`d6d55b4`), 222 wie vorher, kein Bild verändert.
- **Tore auf dem Endstand alle grün**: 842 Tests / 157 CHECK, 31 von 31 Render-Prüfdateien (107 Prüfungen), Arcade 20/20 und
  17/17, Modern 6/6 + GLES, Sicht und Pfad voll, Ergebnis Arcade = Modern, Modelle, Schlüssel, Determinismus, Klang,
  Builds, Rauchtest Linux / GLES / Windows.
- **Leistung** (Notiz 7): Einhängen je Baustein jetzt höchstens 0,9 ms (Basis 3,4 ms); die höheren Maxima der Messung
  entstehen nur im Zeitraffer 16 (Sichtkorridor-Nachrechnung, auch die einmalige Wahrzeichen-Spitze); im Zeitraffer 4
  keine. Ohne Zeitraffer kostet das Erfassen eines Stücks 0,25 ms mehr als in der Basis.
- **Bilder**: 75 A/B-Bilder in drei Stufen und drei Clips angesehen – nichts schlechter als beim letzten Zusammenbau.
  Besser geworden: Bäume und Felsen an den Kurveninnenseiten (T1–T4) und Arcades Eiche am Start (F-03), Häuser an
  Arcades Stellen (München, Belgrad), der Michel am Horizont, die Tunnelausfahrt im Schnee ohne Blendkante.
- **Offen und gelistet** (keiner neu): Nachtfenster des Hamburger Hansehauses 0,46 × Arcade (AS5b), Lack der Limousine
  in der Dämmerung (AS5b), Schnee-Beobachtungen bei Valík (QA-mid).

## 2. Zusammenbau

| Schritt | Commit | Prüfung danach |
|---|---|---|
| Merge R7a (FIX-R7a `4a43944`), `--no-ff` | `02457f1` | Unit-Tests 183 / 0 fehlgeschlagen (`logs/rt_r7a_unit.log`) |
| Merge R7b (FIX-R7b `c50d58f`); Konflikt nur `docs/renderer-modern.md`: FIX-RINT behält §18, R7b wird §19 | `a5f8b83` | Wahrzeichen-Prüfungen OK (`rt_r7b_landmark.log`) |
| Merge R7c (FIX-R7c `3b3107b`) | `0dbb0b2` | nach allen drei Merges (Notiz 1): `test_props` 26 / 0, `test_chunk_streamer` 9 / 0, Wahrzeichen OK, `check_lod_band` OK, `check_landmarks_render` OK |
| Vertrag §11.4 wörtlich nach §11.3 (Notiz 2) | `79f5eca` | – |

Import nach den Merges sauber; `tests/check_scripts.gd`: 338 bzw. 339 Skripte, 0 fehlerhaft.

## 3. Leitungsnotizen

### Notiz 3 – A-24: das ganze Modell in der Hülle (`a147166`)
FIX-R7a's Patch von Hand auf den zusammengeführten `props.gd` übertragen, mit dem **Modell** statt der
Bibliotheksbreite: `footprint()` nimmt die AABB der Vereinigung aller Varianten, skaliert, gespiegelt und mit dem
Gierwinkel gedreht, mit dem `_place()` das Modell stellt; an der Kante ausgerichtete Häuser reichen quer mindestens bis
Arcades Vorderkante (max(extent, AABB-Seite)), längs die AABB. `push_out()` und `drop_reason()` rechnen mit demselben
Abdruck, angehängte Requisiten (`attach_list`) ebenso. `git mv tests/race3d/props_footprint.gd` →
`check_props_footprint.gd` (Gate von `run_tests.sh`).

- `--full`: **0 von 218.090** gemessenen Requisiten über 0,5 m in der Hülle (128 Etappenrichtungen, 314 s).
- Mutation „nur Fuß“: **FEHLER 474**; Breitenmodell von FIX-R7a: **FEHLER 391** (schnell, 6 Richtungen).
- `city_french_sud`: seine Obergeschosse reichen 2,08 m über `extent_m.left` hinaus. Der Abdruck nimmt
  max(extent, AABB-Seite) (`props.gd footprint()`, Kommentar dort), also zählt die volle Auskragung; `extent_m`
  selbst bleibt (Arcade liest es für die Vorderkante).
- Bilder Arcade | Basis `3248211` | Kopf: `notiz3/` (C1, München, Bern, T4, Belgrad). Angesehen: in München, Belgrad
  und Bern stehen die Häuser jetzt wieder dort, wo Arcade sie zeigt (die Basis hatte links bzw. rechts Lücken), C1 und
  T4 unverändert gegen die Basis.

### Notiz 4 – N-01 und N-02
- **N-01** (`2efac7f`): Ein Stück, das der Streamer im Zustand COMMITTING verwirft, gibt über
  `ModernRenderer.release_chunk()` → `release_under()` seine Reflektoren und Lampen frei; `lights._update_glints()`
  überspringt und vergisst Einträge freigegebener Knoten. Unit-Tests (nie eingehängter Knoten, freigeben,
  Glanzpunkte → kein Fehler, Zähler 0; `release_under()` für lights und flares; Streamer verwirft halb eingehängtes
  Stück). NACH-RINT's Sonde: Zähler 1 → 0, kein SCRIPT ERROR.
- **N-02** (`e240f1e`): In den letzten Metern vor dem Portal steht die Blendfläche jenseits des Autos und damit
  außerhalb der Röhre; dort ist sie jetzt `EXIT_COVER_M` (400 m) breit und hoch (tiefengeprüft: Auto und nahe Röhre
  unberührt), solange sie im Portal steht, wie bisher. Bilder Valík im Schnee (VALS, „Hoch“, 3,60 / 3,90 / 3,97 /
  4,00 / 4,03 s), Basis gegen Kopf (`n02/VALS_0[2-4]_basis_kopf.jpg`, angesehen): bei 4,00 und 4,03 s zeigt die Basis
  die harte senkrechte und waagrechte Kante des Blendvierecks gegen die Landschaft, der Kopf überstrahlt das ganze
  Draußen gleichmäßig wie Arcade; 3,60 bis 3,97 s gleich (Pixelvergleich: Unterschiede nur in Bild 3 und 4).
  **Behoben.** Zwei Beobachtungen in beiden Ständen, nicht von RINT-M3 (für QA-mid): (a) bei 3,60 s, noch in der
  Röhre, erscheint die verschneite Landschaft im Ausfahrtsloch beige-gelb statt weiß wie in Arcade; (b) verschneite
  Fichten wirken in Modern aus der Ferne als dünne weiße Gerippe, Arcade zeigt dunkelgrüne Bäume mit Schnee.

### Notiz 5 – A-26: LOD-Band folgt der Kamerageschwindigkeit (`e9df492`)
`ce_lod_still` (binär) ersetzt durch das globale `ce_lod_band_m` = Geschwindigkeit × 0,4 s; jedes Band verengt sich
zum fernen Ende auf w' = min(w, ce_lod_band_m). NR7c-02: Mutationen N1, N3, N4, N5 und zwei weitere (Shader ignoriert
das Band, binäre Breite) machen `test_props` rot (je 27 Tests, 1 fehlgeschlagen; `logs/rt_mut_*.log`). NR7c-03:
Kommentar beschreibt das ferne Ende. `check_lod_band` OK. Stop-and-go-Clip: Abschnitt 5.

### Notiz 6 – A-25: gezeichneter Wahrzeichen-Knoten ≤ 12 m (`3483001`)
`landmarks.gd` zeichnet über die reine Funktion `place_model()`; `MAX_NODE_SHIFT_M` = 12. Netzprüfung
„drawn_node_stays_near_arcades_anchor_network_wide“: 66 Modelle und Formen, größte Verschiebung **11,89 m** (Kirche vor
Bremen, Bremen – Amsterdam km 36,3, −10,6°); Mutation „Verschiebung × 1,1“ rot. Doku §19.1.

### Notiz 7 – A-28: Streamer und Hauptfaden
Einhängen in Schritten innerhalb eines Bausteins (`48147a2`): road, roadside und terrain teilen ihr Netz ab 2.000 Ecken
in Stücke gleicher Dreieckszahl und hängen je Schritt eines ein; das Stück kommt erst in den Baum, wenn alle Schritte
aller Bausteine hängen. Das Vorwärmen des Sichtkorridors ist der eigene Teil „warm“. Tests: `split_arrays()` erhält
alle Dreiecke (1–4 Teile), Schritte des Straßenbausteins, Verteilung über Bilder.

**Messung** (Xvfb/llvmpipe, `sh/stage_shots.gd`, Kiel–Hamburg ganz, Autopilot, Seed 7, 12 Uhr; Kopf `e240f1e` und
Basis `3248211` abwechselnd in derselben Sitzung, je drei Läufe, A-28: Median der drei; `perf/kh_*`, `sh/perfsum.py`):

| Zeitraffer 16 | render() Ø / max ms | Stück-Commit max | größter Baustein-Commit | collect max | größtes Baustein-collect | Draw Calls |
|---|---|---|---|---|---|---|
| Deck Kopf | 3,16 / 12,90 | 2,07 | **0,89** | 7,99 | 0,44 | 140 |
| Deck Basis | 2,81 / 10,88 | 3,57 | 3,37 | 3,50 | 0,39 | 131 |
| Mittel Kopf | 3,21 / 19,36 | 2,21 | 1,19 | 6,83 | 0,53 | 169 |
| Mittel Basis | 2,70 / 8,61 | 1,98 | 0,85 | 3,66 | 0,37 | 150 |

- **Commit (A-28)**: das schrittweise Einhängen wirkt – größter Baustein-Commit auf dem Deck 0,89 ms gegen 3,37 ms der
  Basis; das Stück als Ganzes bleibt um 2 ms (der letzte Schritt eines Bildes kann die 2 ms knapp überschreiten).
- **collect() je Baustein ≤ 2 ms (A-18)**: höchstens 0,44 / 0,53 ms (Median), im Kopf wie in der Basis.
- **Die höheren Maxima des Kopfes** (collect 6–17 ms, `render()` bis 20 ms, dazu eine Spitze des Hakens `landmarks`
  von 8–14 ms bei km 73,7 in allen sechs Läufen) haben **eine Ursache**: Im Zeitraffer 16 (0,53 s Spielzeit je Bild)
  fällt das Vorrechnen des Sichtkorridors (`warm()`, 250 µs je Bild) zurück, und der erste Leser rechnet die fehlenden
  Zeilen sofort im Hauptfaden nach (`corridor.sync_calls` 255–312 je Lauf, `sync_ms_max` 7,8–13,5 ms). Die Spitze des
  Wahrzeichens ist genau diese Rechnung: `_place()` fragt `TerrainProfile.height()` 1,9 km voraus (Elbphilharmonie);
  ihre Höhe liegt in jedem Lauf 0,3–0,4 ms über dem `sync_ms_max` desselben Laufs. Sonde `probe/lm_spike_probe.gd`:
  das Erzeugen des Wahrzeichens selbst kostet 0,26–0,55 ms (mit Grafik, Zeitraffer 4), `_make()` 0,23 ms.
- **Gegenprobe im Zeitraffer 4** (Spielzeit je Bild ein Viertel, immer noch 8 × schneller als echtes Spiel mit 60
  Bildern/s): Kiel–Hamburg km 0–11 und km 58–78 (mit beiden Wahrzeichen), Prag–Nürnberg km 95–155 (Tunnel, Stadt):
  **`sync_calls` 0** in allen Läufen, Haken `landmarks` höchstens 0,43 ms, keine Spitze ≥ 8 ms aus Sichtkorridor oder
  Wahrzeichen (`perf/kh4*`, `perf/pn4*`; Einzelläufe neben anderer Last, A-11).
- **Was ohne Zeitraffer bleibt** (Sonde `probe/capture_probe.gd`, ohne Grafik, ganze Etappe, Korridor vorgerechnet wie
  im Spiel): das Erfassen eines Stücks (`ChunkContext.capture()`) kostet im Kopf Ø 1,43 ms (max 2,00) gegen 1,18 ms
  (max 2,34) der Basis – +0,25 ms für die Hüllkurve des Sichtkorridors (R7a). Ein einzelner Schritt von `warm()`
  (`probe/warm_step_probe.gd`): Fächer ≤ 0,26 ms, ein Geometrieblock Median 0,94 ms, höchstens 2,9 ms (Einfahrt
  Hamburg); er läuft nur in Bildern ohne andere Streamer-Arbeit. `path.ensure()` bis 7,5 ms auf Prag–Nürnberg steht
  gleich in der Basis (6,7–7,6 ms).
- `render()` im Mittel +12 % (Deck) bzw. +19 % („Mittel“), Draw Calls +9 / +19: Wahrzeichen, Skyline und Fern-LOD
  (R7b, R7c) – gewollt, Bildzeit-Median unverändert (Software-Rendering).

**Entscheidung**: keine Code-Änderung in RINT-M3. Für PERF auf dem Steam Deck vorgemerkt (Abschnitt 6): Geometrieblock
von `warm()` bis 2,9 ms; `path.ensure()` bis 7,5 ms (alt); Sichtkorridor-Nachrechnung nur im Zeitraffer.

### Notiz 8 – Reflektor-Glanzpunkte (`4084ba6`)
`reflector.gdshader` rechnete mit dem vorzeichenbehafteten `PROJECTION_MATRIX[1][1]` und `VIEWPORT_SIZE.y` (im
Compatibility-Renderer negativ bzw. 0): die Mindestgröße griff nie, ein Reflektor bei 400 m war kleiner als ein Pixel.
Jetzt `abs()` und Uniform `viewport_h` (`lights.gd sync_viewport()`). Neue Render-Prüfung `reflektor_punkt`: helle
Spalten bei 30/150/400 m vorher **[8, 2, 0] FEHLER**, jetzt **[8, 2, 2] OK** (Arcade 2–2,5 px); Mutation
„vorzeichenbehafteter Wert“ füllt das Bild → FEHLER.

### Notiz 9 – Nachtfenster der Stadthäuser
Nachgemessen auf dem Kopf („Hoch“, QAs Aufrufe, `shots/ab/hoch/KHH22_*`, `LYON22_*`, `FIX-RINT/sh/warm2.py`: Anteil
warm erleuchteter Fensterpixel):

| Stelle | Arcade | Modern Kopf | Verhältnis |
|---|---|---|---|
| Hamburg Mitte 22 Uhr, nahes Hansehaus rechts (QAs Ausschnitt 1000 160 1280 380), Bild 1 | 0,0153 | 0,0071 | **0,46 ×** |
| Hamburg, ganzes Bild 1 / 2 | 0,0162 / 0,0169 | 0,0115 / 0,0154 | 0,71 × / 0,91 × |
| Lyon 22 Uhr, ganzes Bild 1 / 2 | 0,0160 / 0,0131 | 0,0147 / 0,0094 | 0,92 × / 0,72 × |

Der Wert am Hansehaus ist auf vier Stellen derselbe wie bei QA-RINT-BILD auf `9b02f05` (0,0071): die Merges ändern
nichts daran. Ursache (angesehen, `tmp/hg_both.png`): der Nacht-Atlas (`emit_tex`) des Hansehauses enthält nur etwa 20
der etwa 50 Fenster des Tag-Atlas als erleuchtet, schwarz sind die übrigen. `baked.gdshader` kann nur zeigen, was im
Atlas leuchtet (`window_cover`, `window_ramp`, `emit_energy` skalieren es nur); mehr erleuchtete Fenster heißt neu
backen. Lyon (andere Häuser, andere Atlanten) liegt nahe an Arcade, der Wohnblock rechts sieht im Bild gleichwertig
aus. **Entscheidung**: keine Renderer-Änderung; bleibt für AS5b („die Nachtfenster der Stadthäuser, wo das Backen
entscheidet“, A-29) mit dem Maß von QA-RINT-BILD (warm share je Haus 0,85–1,15 × Arcade).

### Notiz 10 – Doku (`e9df492`)
`renderer-modern-gelaende.md` §8 „Kurveninnenseiten“ mit dem Text von FIX-R7a (und A-24); der Kopf von
`terrain_profile.gd` nennt `in_sight_envelope()` / `bend_intrusion()` (NR7a-04).

### Notiz 11 – Regel 8 und die Sprites
Die 3D-Haken in `tools/blender/cesprites/props_cities.py` (`inner_k`, `bars_k`, `close3d`, `side`) stehen auf
Vorgaben, die den alten Sprite-Weg nehmen. Gegenprobe: `props/city_hanse_gabled` in einer Kopie von `tools/blender`
(Kopf `e240f1e`) mit `render_all.py --only … --force` neu gerendert (3 Zellen, 23 s, Blender 5.2.3):
**bytegleich** mit dem eingecheckten PNG (`cmp`; Pixel: größte Abweichung 0). Arcades Bilder der Stadthäuser bleiben
also unverändert (`logs/sprite_check.log`, Skript `sh/sprite_check.sh`).

### Notiz 12 – Modern-Goldens (`720eaf4`)
Die alte Liste traf nach den Merges 0 von 6 (erwartet). Alle sechs Bilder neben denen von RINT-M2 angesehen
(`goldens/*.jpg`): `start_mittel` – Arcades große Eiche links hinter dem Starttor steht wieder (R7a; F-03 am Start);
`s1_nacht` – ein Busch links mehr; `s4_mittel` – der Michel am Horizont (R7b); `s2`, `s3`, `s5` – kleine Unterschiede
in Fernstufen und Bäumen (R7c). Alles gewollt. Danach einmal `tools/golden.sh modern-make` auf `d6d55b4`: die sechs
Bilder sind **bytegleich** mit den angesehenen (die Leitplanken-Korrektur ändert kein Bild). GLES gegen OpenGL
`modern_s3_hoch`: max. 2/255, PSNR 73,2 dB.

### Befund der Montage – Instanzbudget im Wald (`d6d55b4`)
Die Render-Prüfung `instanzen_wald` (Dortmund – Frankfurt km 40, „Hoch“, 48 eingespeiste Autos) war auf `e240f1e`
**rot**: ganze Szene 236 Geometrie-Instanzen mit Instanz-Uniforms gegen die Grenze 230 (A-19), zweimal nachgestellt
(RINT-M2 216, FIX-RINT 222). Die Fahrzeugebene blieb bei 208; eine Sonde (`probe/wald_hist_probe.gd`, Aufschlüsselung
nach Shader und Besitzer im schlechtesten Bild) fand 28 `vpbr`-Instanzen direkt unter den Stücken: die Leitplanken.
Seit dem schrittweisen Einhängen (A-28, `48147a2`) legte `roadside` je Stück einen eigenen Knoten an, und jeder
belegt mit dem gemeinsamen Fahrzeugmaterial 16 Plätze des globalen Shader-Puffers. **Behoben**: die Schritte hängen
ihre Stücke als weitere Flächen an denselben Knoten „Roadside“ (ein Knoten je Stück Strecke wie vorher, dieselben
Dreiecke, dasselbe Material). `test_road_builder` prüft es, die Mutation „Knoten je Stück“ macht ihn rot. Danach:
`instanzen` 154 → 141, `instanzen_wald` 236 → **222 OK**, `instanzen_stadt` 177 (Stadt ohne Leitplanken). Hinweis:
der Wald liegt damit wieder 8 unter der Grenze – wer Material mit Instanz-Uniforms in Stücke legt, muss das zählen.

### Notiz 13 – Lackflackern
Pausiert (A-21); nichts dafür geändert.

## 4. Tore (`sh/gates.sh`, Ausgaben in `gates/`; nice 10, höchstens zwei schwere Läufe zugleich; Endstand `720eaf4` = `d6d55b4` + Goldens)

| Tor | Ergebnis |
|---|---|
| Import | sauber, 0 Fehlerzeilen |
| `tests/check_scripts.gd` | 339 Skripte, 0 fehlerhaft (die Zusammenfassung zeigt „exit 1“: das ist der Rückgabewert des `grep` in derselben Zeile von `gates.sh`, nicht der Prüfung – Endstand-Lauf unten mit eigenem Rückgabewert) |
| `tools/run_tests.sh` | `e240f1e`: **842 Tests, 0 fehlgeschlagen; 157 CHECK OK, 0 FEHLER** (1.100 s); Endstand `d6d55b4`: **842 Tests (mit dem neuen Leitplanken-Test), 0 fehlgeschlagen; 157 CHECK OK** (1.227 s) |
| Arcade-Goldens | **20 von 20** und UI **17 von 17** identisch |
| Modern-Goldens (alte Liste) | 0 von 6 identisch – erwartet (Notiz 12); GLES gegen OpenGL OK (max. 2/255, PSNR 73,2 dB) |
| `modern_sight --full`, `modern_path_check --full` | 6 OK / 0 FEHLER; 2 OK / 0 FEHLER (F7: 0 von 207.166 Querschnittsseiten mit Gelände im Sichtkorridor) |
| `validate_models.py` | CHECK models OK |
| `export_models.py --check-keys` | CHECK cache_keys OK (110 Modelle) |
| `check_sprite_geometry.py` | CHECK sprite_geometry OK |
| `audio_qc.py` | 98 Klänge, 0 Fehler |
| Determinismus (zweimal exportiert: `city_hanse_kontor`, `city_german_house`) | Cache- und Asset-Hash gleich, `git status assets/models` 0 Dateien |
| Ergebnis Arcade = Modern (`run_stage`, Kiel – Hamburg 12 Uhr, Testetappe 21 Uhr Regen, Saragossa – Pau Schnee) | je 28 Schlüssel, **identisch** außer `gfx` |
| Texturspeicher (`probe/texmem_probe.gd`) | Modern 111,7 / 111,3 MB (Kiel – Hamburg km 2 / Dortmund – Frankfurt km 221; RINT-M2 109,2 / 110,8: +2,5 MB Wahrzeichen und Skyline); Arcade 216,6 / 203,2 MB (streut zwischen Läufen: M2INT 228,5, RINT-M2 202,6 an derselben Stelle) |
| Render-Prüfungen (`tools/run_render_checks.sh all`, Endstand `d6d55b4`) | **31 von 31 Dateien OK, 107 Einzelprüfungen** (u. a. `reflektor_punkt` [8, 2, 2], `wahrzeichen_stelle`, `lod_ueberblenden(_stand)`, `lod_baum(_stand)`, `kuppe`, `nass_kegel` 0,88 ×, Instanzbudget 141 / 177 / 222). Auf `e240f1e` war `instanzen_wald` rot (236) – siehe Befund der Montage |
| Verdeckungssonde A-17 (FIX-M2 `qa_occl.gd`, rotes Testauto in drei Spuren bei 25–270 m, T1–T4, C1, S0, S4; Kopf gegen Basis `3248211`) | 147 Stellen: gleich bis auf T4 200 m rechte Spur 54 statt 127 Pixel (sichtbar; die Fichten auf der Kurveninnenseite, die R7a außerhalb der Hülle zurückbringt, decken einen Teil – `occl_T4_200m_basis_kopf.jpg`) und C1 270 m, wo das Auto im Kopf sichtbarer ist (18 / 19 statt 9 / 0 Pixel); unsichtbar (< 12 px) nur bei 270 m in T3/T4 wie in der Basis; F7 (`modern_sight --full`) 0 Verstöße |
| Modern-Goldens neu (`720eaf4`, Notiz 12) | `modern-make` 6 Bilder, bytegleich mit den angesehenen; `modern-check` Endstand **6 von 6 identisch**, GLES gegen OpenGL OK (max. 2/255, PSNR 73,2 dB); `check_scripts` Endstand 339 Skripte, 0 fehlerhaft (Rückgabewert 0) |
| Builds (`tools/build_linux.sh`, `tools/build_windows.sh`, Endstand `720eaf4`) | beide Rückgabewert 0 |
| Rauchtest (`tools/smoke_modern.sh`) | **Linux OK, Linux OpenGL ES OK, Windows (Wine) OK** – je Arcade und Modern geladen und gefahren, Leistungstest „autobahn“ 5,8–6,3 Bilder/s auf llvmpipe (Vorschlag Arcade/Niedrig wie bisher) |

## 5. Bilder Arcade | Modern

Links Arcade, rechts Modern, gleiche Stelle, gleicher Augenblick (`tools/ab_shot.sh`, Kopf `e240f1e` bzw. ab NUE
`d6d55b4` – die Korrektur der Leitplanken ändert kein Bild: dieselben Dreiecke mit demselben Material, Modern-Goldens
siehe Notiz 12). Jedes Bild angesehen; Ordner `ab_hoch/`, `ab_mittel/`, `ab_deck/`, Übersichten `ab_boegen/`. Die Spalte
„gegen RINT-M2“ vergleicht mit dem Urteil des letzten Zusammenbaus.

| Stelle | Urteil | gegen RINT-M2 | Was |
|---|---|---|---|
| S0 Start Kiel – Hamburg 1,5 s | gleich | besser | Arcades große Eiche links hinter dem Starttor steht wieder (F-03 am Start behoben, R7a); Starttor als Gitterbrücke |
| S1 km 2 | gleich | besser | der Busch links vorne steht wieder; Birken, Windräder, Leitplanken |
| S2 km 13,6 (Tankspur) | besser | gleich | echtes Tankstellendach, Säulen, Shop |
| S3 km 60 | gleich | gleich | offene Autobahn, Baumgruppen, Windräder |
| S4 km 80 (Stadtgrenze Hamburg) | besser | besser | Hansehäuser und Kran in 3D, dazu jetzt der Michel am Horizont (R7b) |
| S5 km 94 (Ziel) | gleich | gleich | Zielbanner, Stadthäuser |
| T1 Kassel – Würzburg km 46,5 | gleich | besser | die große Fichte links vorne steht wieder (R7a) |
| T2 km 61,9 (Kuppe) | gleich | besser | links der Kuppe wieder Eichen und Fichten wie Arcade |
| T3 Saragossa – Pau km 172,8 | gleich (klein schlechter) | besser | Kurveninnenseite: Kiefern auf dem Hügel, ein Felsen weiter oben; Arcades zweiter Felsen nahe der Fahrbahn fehlt |
| T4 km 198,8 | gleich | besser | Fichten rechts auf der Kurveninnenseite wieder da (kleiner als Arcades große vorne) |
| C1 Dortmund – Frankfurt km 221, 19:30 | gleich | gleich | Abendhimmel, Häuser mit Licht, Frankfurter Hochhaus in der Mitte; rechts weiter ein Backsteinbau statt Arcades großem Baum |
| N1 Hamburg – Hannover km 71, Schnee 22 Uhr | gleich | gleich | Schneefall, Abblendkegel, Büsche, Birke links |
| N2 Dortmund – Frankfurt km 121, Regen 16 Uhr | gleich | gleich | Regen, Gischt hinter dem Gran Turismo, nasse Fahrbahn; Laubbäume links und die große Fichte rechts wie Arcade |
| U1 Gotthard km 186 | gleich | gleich | Röhre, Leuchten, Fliesen; die Limousine wirkt im Tunnel dunkler als Arcades Sprite (unverändert) |
| DEV Testetappe km 48, 21 Uhr | gleich | gleich | Portal mit Hügel, Abblendlicht, Tunnelschild; Laubbaum rechts am Hang |
| MUC München Stadteinfahrt 12 Uhr (2 Bilder) | besser | besser | Altbauten in 3D, links und rechts an Arcades Stellen (Notiz 3; die Basis hatte hier Lücken), Gehwege, Skyline |
| BEL Belgrad Stadtrand 12 Uhr | gleich | besser | Häuser, Mauern, Laternen an Arcades Stellen (Basis: Lücken); Baumgruppe rechts etwas kleiner |
| HAN Hannover Mitte 12 Uhr | gleich | gleich | Bürohäuser, Kaufhaus mit Markise, Skyline; nahe Häuser am Bildrand in 3D sichtbar, wo Arcades Sprites schon fehlen |
| LYON Lyon Einfahrt 12 Uhr | gleich | gleich | Wohnblock, Läden, Platanen; nahe Hauswand links in 3D |
| NUE Nürnberg Einfahrt 12 Uhr | besser | gleich | Fachwerk- und Bürgerhäuser in 3D an Arcades Stellen, Baum links; Gehwege, Laternen |
| KHH Hamburg Mitte 12 Uhr | besser | gleich | Backstein-Kontorhäuser, Giebelhäuser, Kaufhaus in 3D; Baum und Laternen wie Arcade |
| KHH195 Hamburg Mitte 19:30 | gleich | gleich | Abendhimmel, Fenster mit Licht, Laternen; der Lack der Limousine wirkt grau-lila statt blau (alt, A-29 an AS5b) |
| KIEL Kiel Stadtrand km 0,6, 12 Uhr | gleich | gleich | Wegweiser Hamburg, Felder, Bäume; Leitplanke, Gras mit Struktur |
| KIEL195 dasselbe 19:30 | gleich | gleich | Dämmerung wie Arcade; Lack wieder grau-lila (alt) |
| KIEL22 dasselbe 22 Uhr | gleich | gleich | Abblendkegel, Wegweiser, Bäume dunkel wie Arcade |
| ROOF Grenze Serbien – Bulgarien 12 Uhr | besser (klein) | gleich | Grenzdach auf Stützen, Häuschen mit Tiefe, Schranken; Schilder wie Arcade |
| HHA Elbbrücken 12 Uhr | besser | gleich | Fachwerkbrücke in 3D mit Schatten auf der Fahrbahn, Elbphilharmonie und Michel am Horizont |
| HHA22 Elbbrücken 22 Uhr | gleich | gleich | Elbphilharmonie mit Fenstern, Brücke, Laternen |
| DOF22 Dortmund Stadtrand 22 Uhr | gleich | gleich | Häuser mit Licht, Laternen, Stadtlichter |
| VAL Tunel Valík 12 Uhr (Einfahrt, Ausfahrt) | besser | gleich | Portal mit Hügel und Bäumen; nach der Ausfahrt gleich |
| VALN Tunel Valík 22 Uhr innen | gleich | gleich | Leuchten, Ausfahrt in die Nacht |
| TS15 Tankstelle Kiel – Hamburg km 14,3, 12 Uhr | gleich | gleich | Anfahrt, Felder, Windräder |
| TS15N dasselbe 21 Uhr | gleich | gleich | Tankstellendach rechts mit Licht, Abblendkegel |

„Mittel“ (alle 15 Bezugsstellen, `sheet_mittel_1/2.jpg`): dieselben Urteile wie „Hoch“ – die Eiche am Start, der Busch
bei S1, die Bäume in T1–T4, der Michel bei S4; etwas weniger Grasstruktur und kürzere Schatten, nichts fehlt gegenüber
„Hoch“. „Deck“ 1280 × 800 (S1, N2, T2, Valík Einfahrt/innen/Ausfahrt, `sheet_deck.jpg`): gleich; Modern füllt den
16:10-Schirm, Arcade hat Balken; Regen mit Gischt, Fichten und Laubbäume an der Kuppe wie „Hoch“.

### Clips (`tools/ab_clip.sh`, 30 Bilder/s, links Arcade, rechts Modern; `clips/`, Einzelbilder angesehen)

| Clip | Urteil | Was |
|---|---|---|
| Kiel – Hamburg km 8 → Tankstopp, „Hoch“, 30 s | gleich (Tankstelle besser) | Autobahn, Abfahrt in die Tankspur, Dach mit Säulen und Zapfsäulen, „Volltanken?“ und Tankanzeige laufen wie Arcade |
| Saragossa – Pau km 170, Bergkurven und Tunnel, „Hoch“, 30 s | gleich / besser | Hügel und Kiefern an den Kurven (R7a), Portal im bewaldeten Hang, Röhre mit Leuchten wie Arcade |
| Anfahren Nürnberg – Fulda, „Mittel“, 12 s, Kopf und Basis (Notiz 5, A-26) | gleich, kein Springen | stehend im Countdown, dann bis 140 km/h: Bäume und Fernstufen ohne sichtbaren Wechsel; gegen die Basis mehr Bäume (Sichtkorridor R7a), sonst gleich (`anfahren_modern_basis_kopf.jpg`) |

## 6. Abweichungen und Vertragsfragen

- **Ablauf**: Der Montage-Auftrag wurde um 16:05 von einem Kontolimit gestoppt; das Werkzeug für parallele Hilfsabläufe
  steht seitdem nicht mehr zur Verfügung. Die Leitung hat den Rest selbst und nacheinander gemacht, mit denselben
  Prüfungen. Zwei Container-Neustarts (23:32, 00:19) haben laufende Aufträge abgebrochen; alles Abgebrochene ist neu
  gelaufen, die Abläufe sind seitdem wiederaufnehmbar (`sh/slotA.sh`, `sh/slotB.sh`, `sh/slotC.sh`).
- **Eine Code-Änderung über die Leitungsnotizen hinaus**: die Leitplanken-Stücke (`d6d55b4`, Befund der Montage). Sie
  folgt A-19 (Instanzbudget) und A-28 (Schritte) zugleich und ändert kein Bild.
- **Notiz 7 ohne Code**: die höheren Maxima entstehen im Zeitraffer 16 der Messung; A-28 („Median von drei neben der
  Basis“) ist für Einhängen und `collect()` je Baustein erfüllt. Der Zeitraffer-Effekt ist kein Befund nach A-11, aber
  die Leistungsmessung mit Zeitraffer 16 überzeichnet seitdem jeden Sichtkorridor-Leser: Vorschlag für den Vertrag,
  die Maxima für Hauptfaden-Haken im Zeitraffer 4 zu beurteilen (Abschnitt 8).
- **`gates.sh`**: die Zeile „check_scripts exit 1“ beim Import zeigt den Rückgabewert eines `grep`, nicht der Prüfung
  (339 Skripte, 0 fehlerhaft); der Endstand-Lauf `scripts2` meldet den echten Wert.
- Keine Vertragsfrage offen.

## 7. Besser / gleich / schlechter als Arcade (alle angesehenen Bilder)

**Besser**
- S2 Tankspur, S4 Stadtgrenze Hamburg (jetzt mit dem Michel am Horizont), München, Nürnberg, Hamburg Mitte bei Tag:
  Häuser in 3D an Arcades Stellen, Gehwege, Laternen.
- Elbbrücken bei Tag (Fachwerkbrücke in 3D, Elbphilharmonie und Michel), Tunnel Valík Einfahrt (Portal im Hang),
  Grenze Bulgarien (Dach auf Stützen, Häuschen mit Tiefe), Tunnelausfahrt im Schnee (jetzt ohne Blendkante, N-02).

**Gleich**
- S0 (mit Arcades Eiche), S1, S3, S5, T1–T4 (die Bäume der Kurveninnenseiten stehen wieder; T3: Arcades zweiter
  Felsen nahe der Fahrbahn fehlt), C1, N1, N2, U1, DEV; Belgrad, Hannover, Lyon, Kiel 12 / 19:30 / 22 Uhr, Hamburg
  19:30 und 22 Uhr, Elbbrücken 22 Uhr, Dortmund 22 Uhr, Valík innen und nachts, Tankstelle 12 und 21 Uhr; alle
  Bezugsstellen bei „Mittel“ und „Deck“; die drei Clips.

**Schlechter (alle schon gelistet, keiner neu durch RINT-M3)**
- Nachtfenster des nahen Hansehauses in Hamburg: 0,46 × Arcades warm erleuchtete Fensterfläche (Notiz 9, AS5b).
- Lack der Limousine in der Dämmerung grau-lila statt blau (A-29, AS5b).
- Im Tunnel wirkt die Limousine dunkler als Arcades Sprite (unverändert seit dem ersten Testbuild).
- Verschneite Fichten aus der Ferne als dünne weiße Gerippe; im Ausfahrtsloch von Valík bei Schnee eine beige statt
  weiße Landschaft (beide in Basis und Kopf gleich – für QA-mid, Notiz 4).

## 8. Hinweise für die Nächsten

1. **R7d „Freie Strecke“** baut auf `720eaf4` auf. Die Bilder S1, S3 und Deck S1 dieses Berichts sind die Ausgangslage.
2. **Instanzbudget**: der Wald liegt bei 222 von 230. Wer ein Material mit Instanz-Uniforms (`vpbr`, `glass`) in
   Stücke oder Stufen legt, muss die Knoten zählen; `probe/wald_hist_probe.gd` schlüsselt sie nach Shader und Besitzer auf.
3. **PERF auf dem Steam Deck**: ein Geometrieblock von `SightCorridor.warm()` dauert bis 2,9 ms (Einfahrt Hamburg,
   ohne Grafik gemessen) – er läuft nur in Bildern ohne andere Streamer-Arbeit, gehört aber auf dem Deck gemessen;
   `path.ensure()` bis 7,5 ms auf Prag – Nürnberg (alt, in der Basis gleich). Die Leistungsmessung im Zeitraffer 16
   zeigt Sichtkorridor-Nachrechnungen (bis 13,5 ms, auch als Spitze des Hakens `landmarks`), die im Zeitraffer 4 nicht
   vorkommen – Maxima für Haken im Zeitraffer 4 beurteilen.
4. **AS5b**: Nachtfenster des Hansehauses (warm share je Haus 0,85–1,15 × Arcade), Lack der Limousine in der
   Dämmerung (beides schon in A-29).
5. **QA-mid**: Valík bei Schnee (beige Landschaft im Ausfahrtsloch, 3,60 s), verschneite Fichten in der Ferne, T3 der
   zweite Felsen Arcades an der Kurveninnenseite.

## 9. Lieferung

`deliver/RINT-M3/`: dieser Bericht; `notiz3/` (Abdruck: München, Belgrad, Bern, C1, T4), `n02/` (Valík Schnee Basis |
Kopf), `goldens/` (die sechs Modern-Bilder neben RINT-M2), `ab_hoch/`, `ab_mittel/`, `ab_deck/`, `ab_boegen/`,
`clips/` (drei Clips mit Einzelbild-Bögen), `occl_T4_200m_basis_kopf.jpg`. Werkzeuge und Rohdaten in `m1/RINT-M3/`
(`sh/`, `probe/`, `perf/`, `gates/`, `occl/`, `logs/`). Commits seit der Basis `3248211`: `02457f1`, `a5f8b83`,
`0dbb0b2`, `79f5eca`, `a147166`, `2efac7f`, `e9df492`, `3483001`, `4084ba6`, `48147a2`, `e240f1e`, `d6d55b4`, `720eaf4`.

