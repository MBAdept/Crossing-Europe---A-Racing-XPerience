# KRITIK-R3 – Nachprüfung der Fix-Runde AU-R4

**Prüfgegenstand:** AU-R4-Kopf `f2536878c0f426e44caeb522a94ceb3adf234955` (`origin/wip/v080-au-r4`), Basis AU-R3 `b6339ad4`,
Bezug AU-C1 `4209268f` (der Klang, den der Nutzer gehört hat). **Rolle:** nur lesend – keine Commits, kein Zweig, kein
Arbeitsbaum eines anderen Pakets. Geprüft in einer Kopie (`git archive` + `.godot` des Hauptbaums, einmal importiert);
jeder Lauf mit absolutem `XDG_DATA_HOME`, `nice -n 19`, ein schwerer Lauf nach dem anderen.
*gemessen* = auf dieser VM (Godot 4.7.2, ohne Bildschirm bzw. Xvfb/llvmpipe, Dummy-Audiotreiber); *abgeleitet* = aus
Code, Rechnung oder Statistik. Gehört hat hier niemand.

## 0. Ergebnis

**Der AU-R4-Kopf kann zusammengeführt werden.** Alle sieben Befunde sind mit den Werkzeugen der Prüfer nachgestellt
und behoben; kein neuer Fehler im Code; alle Gates grün (Abschnitt 3). Neu: vier niedrige Lücken in den neuen
Wächtern (Abschnitt 4) – keine davon betrifft den Klang des Testbuilds.

| Befund | Repro der Prüfung auf `f253687` (gemessen) | vorher (Prüfung, AU-R3) | Stand |
|---|---|---|---|
| M1-MESS V3 Lkw knapp | `kr_crash.gd`, 60 schwere Lkw-Unfälle, 130 km/h, Konfiguration ohne Override (`truck.heavy` −11,5): Folge 9312 **95 % 2,20 dB**, 1 von 60 > 3 dB, True Peak höchstens −1,26 dBTP; neue Folgen 9314 / 9315: **2,85 / 2,69 dB**, 0 > 3 dB, −1,52 / −1,40 dBTP | 2,66 dB, 3 von 60 > 3 dB, −1,21 dBTP | behoben (Marge in einer Folge nur 0,15 dB, s. 1.3) |
| H1 Quietschen je Ereignis | M01 rot: „348 Wechsel in 612 hörbaren Bildern“; M02 rot | M01 grün | behoben |
| H2 Varianten zufällig | M03 rot, M04 rot | M03 grün | behoben |
| H3 Pegel-/Einsatzzufall je Schicht | M14, M15, M16 rot | alle grün | behoben |
| H4 Nachstellen der Plattenmuster | M11 rot, M12 rot („0-mal nachgestellt … größter Versatz 29,99 ms“) | beide grün | behoben |
| M1-CODE Altstadtanteil | `kc_trigger.gd`, 128 Ankünfte, 1-m-Raster: **wie gehört 3 außerhalb** (Barcelona 2 ×, Ljubljana: 0,549, zugeteilt genau 0,550); genaue Meter 0 von 100 außerhalb (0,550–0,645) | 14 außerhalb wie gehört (0,70–0,78 bzw. 0,549) | behoben unter der Lesart „wie gehört“ (Vertragsfrage) |
| M2 Vorbeifahrt-Zufall | M17 rot, M18 rot | beide grün | behoben |

## 1. Nachgestellt je Befund

### 1.1 Tests (H1–H4, M2) – Mutationen

`mutate.py` der Prüfung (Fassung AU-R4: M22–M24 an den neuen Zeilen als M22b–M24b, dazu M33–M40) auf der Kopie, je
eine Zeile gebrochen, nur die zuständige Testdatei; danach jede Datei wieder bitgleich (sha1 geprüft). Ohne Bruch:
`test_road_audio.gd` 17 / 0, `test_audio_feed.gd` 24 / 0.
**40 von 40 rot** (`res/mutations_r3.json`). Dazu 17 eigene Proben (K01–K17), um zu sehen, ob die neuen Wächter nur
die eine Mutation der Prüfung fangen:

| Probe | Bruch | Ergebnis |
|---|---|---|
| K01 | Quietsch-Tonhöhe springt in 10 % der Bilder | rot |
| **K02** | Zufall je Bild in der **gespielten** Tonhöhe statt in `squeal_factor` | **grün** (L-A) |
| K03 / K04 | Nachfolger nur last+1 oder last+2; Aufprall-Varianten reihum im Aufrufer | rot / rot |
| K05 / K06 / K07 | Schichtpegel nur ±1 dB; nur nach oben; Einsatz nur bis 10 ms | rot / rot / rot |
| **K08 / K09** | Pegel- bzw. Einsatzzufall gewürfelt, aber **nicht an den Spieler** gegeben | **grün / grün** (L-B) |
| K10 | Nachgestellt, aber 0,2 % der Schleife daneben | rot |
| **K11** | immer das schnelle Plattenmuster nachgestellt, auch wenn es das lautere ist | **grün** (L-C) |
| K12 / K13 / K14 | Vorbeifahrt ±1 dB; Varianten im Wechsel; Zufall nicht im gespielten Pegel | rot / rot / rot |
| K15 / K16 / K17 | Steinbrücke nicht vom Ziel abgezogen; nicht in der Basis; Tunnel rückt nie nach | rot / rot / rot |

Die Regeln der Befunde sind damit geschützt; die grünen Proben sind Lücken *neben* den Befunden (Abschnitt 4).

### 1.2 Altstadtpflaster (M1-CODE)

`kc_trigger.gd` + `ana_trigger.py` der Prüfung (alle 64 sichtbaren Etappen × 2 Richtungen, echte `Track`, 1-m-Schritte):
0 Verstöße der Auslösung (Pflaster, Deck, Beton, Fugen, Zonen, Wetter), 122 Brücken ohne Fugenabweichung, Tankspur
0 m Rüttellinie, Beton 13 von 13 beurteilten Ländern im Band, 0 Abschnittsentscheidungen je Richtung verschieden –
alles wie bei AU-R3. Altstädte: wie gehört 3 außerhalb (vorher 14), auf den Straßen allein 26 (vorher 22 – Lesart
gewechselt), keine Stadt mit verschiedenen Mustern je Ankunft. Gegen die Ausgabe der Prüfung auf AU-R3: **114 von 128
Plänen bitgleich**, darunter **Kiel – Hamburg in beiden Richtungen** (Hamburg `P--PP-P-P`, 0,551; aus Hannover mit
330 m Tunnel 0,615 und dasselbe Muster). Anders nur Bordeaux, Dresden, Lyon, Paris, Saragossa (nur ein Block ganz auf
der Steinbrücke), Toulouse, Tours – genau die Liste von AU-R4. Genaue Meter (`cobble_alloc.gd` von AU-R4, auf der
Kopie): 0 von 100 außerhalb, 0,550–0,6447. **16 Ankünfte in 9 Städten (auch Hamburg) liegen genau auf 0,550**, dem
unteren Rand – die drei „Ausreißer“ des 1-m-Rasters sind dieser Rand (±1 m je Blockgrenze), kein Fehler der Zuteilung.

### 1.3 Lkw-Aufprall (M1-MESS)

`kr_crash.gd` / `ana_crash.py` / `crash_p95.py` der Prüfung, je 60 schwere Lkw-Unfälle, Limousine 110 km/h,
Schließgeschwindigkeit 130 km/h, Gesamtlautstärke 1,0, ohne `--truck`-Override (die Kopie liest −11,5 aus der
Konfiguration; im Protokoll bestätigt).

| Lauf | 95 % der Begrenzung | Median / höchstens | > 3 dB | True Peak höchstens |
|---|---|---|---|---|
| 9312 (Repro der Prüfung) | **2,20 dB** (AU-R4: 2,13) | 0,37 / 3,32 dB | 1 von 60 | −1,26 dBTP |
| 9314 (neu) | **2,85 dB** | 0,38 / 2,96 dB | 0 | −1,52 dBTP |
| 9315 (neu) | **2,69 dB** | 0,57 / 2,81 dB | 0 | −1,40 dBTP |
| gepoolt mit AU-R4 (9312, 9313): 300 Unfälle | 2,57 dB | 0,40 / 4,01 dB | 3 von 300 (1,0 %) | −1,26 dBTP |

V3 hält in jedem der fünf 60er-Läufe (95 % 2,13–2,85 dB) und jeder der 300 Unfälle liegt ≤ −1,0 dBTP (gemessen).
Die einzelnen 60er-Läufe streuen stärker, als die zwei Läufe von AU-R4 (2,13 / 2,51 dB) zeigen: Eine neue Folge kam
auf 2,85 dB, 0,15 dB unter der Grenze. Das Risiko, dass eine künftige Abnahme mit 60 Unfällen allein durch Zufall
über 3 dB kommt, bleibt trotzdem klein, etwa 0,3 % (abgeleitet: 95 % > 3 dB braucht 4 der 60 Unfälle über 3 dB,
gemessen sind 1,0 % je Unfall; bei 2 % je Unfall wären es 3 %). Teilstichproben à 60 aus den 300: 95 % im Median 2,42 dB, 95-%-Bereich 1,77–2,92 dB. Vorher (−11) lag
das Risiko laut AU-R4 und Prüfung bei 14–35 %. → behoben; Option (a) der Prüfung (V3 über ≥ 120 Unfälle) bleibt als
Vorschlag sinnvoll.

## 2. Diff `b6339ad..f253687` – neue Fehler?

Geändert sind nur `scripts/audio/modern/audio_feed.gd`, die zwei Testdateien, `config/game_config.json`
(`audio.modern.impact.collision.truck.heavy` −11 → −11,5 und die Beschreibung in `audio._doc_modern`, sonst kein
Schlüssel) und `docs/audio-modern.md`.

- `audio_feed.gd`: `_street_fit` (Straßenmeter je Block, Ziel, Band), `stone_stretches` / `tunnel_stretches` über
  `_plan_stretches`, `_closer` für jede Altstadt, Tunnel als `late` nur bei Verlassen des Bandes. Gelesen und mit dem
  Lauf über alle Etappen belegt: kein Fehler gefunden. Ohne Steinbrücke in der Altstadt ist die Zuteilung unverändert
  (gemessen: alle 93 Ankünfte ohne Steinbrücke bitgleich, auch Hamburg aus Hannover mit 330 m Tunnel; die 14
  geänderten haben alle eine Steinbrücke); `_cobbles` wird je Etappe neu berechnet (`set_track`), die Rechnung läuft
  einmal je Etappe; keine Rückwirkung auf die Simulation (Regel 3), nichts vom Renderer gelesen (Regel 4). Grenzfall
  ohne Auswirkung auf echte Daten: Nähme eine Steinbrücke mehr als 65 % einer Altstadt ein, läge der Anteil über dem
  Band, ohne dass `_closer` etwas tun kann (größter Fall in den Daten: 19 %).
- Tests: deterministisch (feste Seeds 60917 / 51017 / 51018 / 7); keine Flakiness. Spröde ist nur die neue Prüfung
  der Folgeanteile (L-D).
- Doku: stimmt mit Code und Konfiguration; eine Ungenauigkeit: 15.11, Zeile V3, „höchstens −1,39 dBTP“ gilt nur für
  die zwei Lkw-Läufe von AU-R4 (Pkw laut KRITIK-R2-MESS −1,38, Lkw hier −1,26) – alles ≤ −1,0, ohne Folgen.

## 3. Gates auf `f253687` (gemessen)

| Gate | Ergebnis |
|---|---|
| `tools/run_tests.sh` (einmal, vollständig) | „244 Skripte geprüft, 0 fehlerhaft“; **„662 Tests, 0 fehlgeschlagen“**; 83 `CHECK … OK` (+ 9 Summenzeilen = die 92 von AU-R4), 0 FEHLER; „Tests bestanden (621 s)“ – `logs/run_tests_r4.log` |
| `tools/golden.sh check` (einmal) | **„GOLDEN arcade: 20 von 20 identisch (141 s)“** – `logs/golden_r4.log` |
| `check_arcade_lean` (in `test_modern_checks.gd`) | OK: „0 von 35 Skripten des Modern-Klangs, des Modern-Renderers und der Modell-Datenbank geladen“ |
| `test_arcade_identity.gd` | 6 von 6 grün (Motor-Mischer, SfxSynth, Verkehr/Raum, eingefrorene Klänge byte-gleich zu v0.7.0) |
| Regel 1: eingefrorene Pfade `v0.7.0..f253687` (Liste aus §2) | 0 Dateien geändert |
| Motor- und Musikdateien gegen AU-C1 (`assets/audio/modern/{engines,music,ambience,ui,traffic}`, `assets/audio/music`, Motor-/Musikskripte) | byte-gleich (0 Dateien); Konfiguration `music`, `duck`, `engine`, `levels`, `glue`, `snapshots` gleich |
| geänderte Dateien `b6339ad..f253687` | nur `audio_feed.gd`, zwei Testdateien, `config/game_config.json` (zwei Schlüssel), `docs/audio-modern.md` |

## 4. Neue Befunde (alle niedrig, keiner betrifft den Klang des Testbuilds)

| Nr | Befund | Beleg | Vorschlag |
|---|---|---|---|
| L-A | `test_squeal_pitch_per_event` liest nur `squeal_factor`; ein Zufall je Bild in der gespielten Tonhöhe (`road_audio.gd` `_update_squeal`, `var p := …`) bleibt grün | Probe K02 grün | im Test zusätzlich `r.squeal.pitch / (0.9 + 0.22·us + 0.08·v/250)` je hörbarem Bild aufzeichnen und Gleichheit verlangen |
| L-B | Pegel- und Einsatzzufall der Aufprallschichten werden nur beim Würfeln geprüft (`last_layers`), nicht am Spieler: Unit-Tests haben keine Spieler (`_panned` leer) | K08 (`db_to_linear(db)` statt `db + jitter`), K09 (`pl.play(lead_s)`) grün | `ImpactAudio` im Test einen Platzhalter-Spielerpool geben (wie `FakePlayer` der Plattenprobe) und `volume_db` bzw. die Startposition `lead − delay` prüfen |
| L-C | `test_slab_loops_are_put_back_in_step` prüft nur 120 km/h (langsames Muster lauter); zwischen 130 und 150 km/h ist das schnelle lauter – diese Richtung ist ungeschützt | K11 (`var loud := true`) grün | die Driftphase bei 145 km/h wiederholen und verlangen, dass dann das langsame Muster neu gestartet wird |
| L-D | Die neue Prüfung der Folgeanteile in `test_collision_variety` (400 Ziehungen, jeder Anteil 0,20–0,47) liegt je Zelle bei etwa 2,8 σ: ein richtiger Zufallsgenerator fiele mit einem beliebigen Seed in **4,5 %** der Fälle durch (Simulation, 20 000 Durchläufe, `tools/sim_pairs.py`). Mit Seed 7 deterministisch grün – aber jede künftige Änderung an `pick_variant` oder am Seed kann den Test ohne Fehler rot machen | abgeleitet (Simulation) | Band auf 0,15–0,52 (≈ 4 σ) oder 2 000 Ziehungen |

## 5. Vertragsfragen (für §11.2)

1. **Altstadtanteil:** Lesart „wie gehört“ (Steinbrücke = gepflasterte Straße, Brücken ohne Steindeck und Tunnel
   keine Straße) bestätigen und **in genauen Metern der Zuteilung, mit eingeschlossenem Rand** beurteilen. 16 Ankünfte
   (darunter Hamburg) liegen genau auf 0,550; im 1-m-Raster schwankt das um ±0,001 (Barcelona, Ljubljana 0,549). Eine
   Zuteilung „mit Abstand vom Rand“ würde das Muster von Hamburg ändern, also den Klang von Kiel – Hamburg, den der
   Nutzer gehört hat – davon rate ich ab.
2. **V3 über ≥ 120 Unfälle aus zwei Folgen** (Option a) zusätzlich zur Pegelsenkung: Die fünf 60er-Läufe streuen
   2,13–2,85 dB.

## 6. Charakter, Musik

AU-R4 ändert keine Fahrbahnschicht und keine Klangdatei (git: 0 Dateien unter `assets/` seit AU-R3); Motor- und
Musikdateien sind byte-gleich zu AU-C1, die Musik- und Motorkonfiguration (`music`, `duck`, `engine`, `levels`, `glue`,
`snapshots`) ebenfalls. Der Schlag des Lkw-Aufbaus liegt jetzt 1,5 dB unter AU-C1 (−10 → −11 seit AU-R → −11,5),
eine von vier Schichten des schweren Lkw-Unfalls – Entscheid der Leitung zu V3, keine Fahrbahnschicht bei den
Bezugstempi (abgeleitet). `tools/audio/music/{mischung.json, music_lib.py}` unterscheiden sich seit AU-R2 von AU-C1 nur
um einen neutralen 0-dB-Tiefenfilter; AU-R4 ändert sie nicht.

## 7. Werkzeuge und Rohdaten

`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3/`:
`tools/mutate.py` (+ `mutations_aur4.json`, eigene `mutations_kr3.json`, `mk_kr3_muts.py`), `res/mutations_r3.json`,
`logs/mut_r3_*.log`; `tools/kc_trigger.gd`, `ana_trigger.py`, `cmp_trigger.py` → `res/trigger_r4.{log,json,ana.txt}`,
`res/trigger_cmp.txt`; `tools/cobble_alloc.gd` → `res/cobble_alloc_r4.log`; `mess/` (`kr_crash.gd`, `ana_crash.py`,
`crash_p95.py`, `boot.py`, `tail.py`, `run_truck.sh`) → `mess/truck_93{12,14,15}_r4.res.json`, `mess/tail_m11.5.txt`;
`tools/sim_pairs.py`; `tools/identity.sh` → `logs/identity.log`; Gates `logs/run_tests_r4.log`, `logs/golden_r4.log`.
Die Kopie des Kopfs ist nach dem Bericht gelöscht.
