## 3. Messungen vorher → nachher

Aufnahmen am Master des Spiels, Limousine auf Kiel – Hamburg (Beton- und Pflasteranteil für die Messung erzwungen),
„vorher“ = Stand AU-C1 mit denselben Skripten. Skripte und Rohdaten: `<scratch>/v080/m1/AU-R/`.

### 3.1 Wiederholung (R1)

Spielmix (Motor + Fahrbahn + Wind), 20 s bei festem Tempo; Hüllkurve aus 10-ms-RMS der Monosumme im Band,
Autokorrelation ohne Mittelwert; Grenzwert: keine Spitze ≥ 0,40 bei 0,3–3 s. Alle Spitzen bis 8 s:

{R1_TABLE}

Die Spitzen jenseits von 3 s sind die Längen der beiden Schleifen (links und rechts eigene). Auf Beton bleibt der
Takt der Platten: 0,83 s sind 6 Platten bei 130 km/h, 1,80 s sind 13 – ohne die Plattenschicht liegt Beton bei
0,11 (Aufnahme `conc130_noslab_full`). Die Platten bleiben laut Vorgabe, wie sie sind (`slabs.db` 3).

### 3.2 Hash und Anteile (R2)

Über alle sichtbaren Etappen (jeder Autobahnabschnitt einmal, beide Richtungen gleich; jede Altstadt einmal):

| | AU-C1 (djb2, untere 24 Bit) | nur fmix32 | AU-R |
|---|---|---|---|
| Pflaster gesamt (Soll 0,6) | 0,623 | 0,609 | 0,566 |
| Altstädte ganz / gar nicht gepflastert | 29 / 18 von 47 | 0 / 0 | 0 / 0 |
| Altstädte im Anteil ±0,05 | 0 | 11 (Spanne 0,34–0,90) | **47** (0,55–0,64) |
| Beton gesamt (Soll 0,207) | 0,244 | 0,166 | 0,205 |
| Länder im Anteil ±0,05 | 5 von 18 | 8 | **14** |

fmix32 allein mischt (keine Stadt mehr ganz oder gar nicht), trifft aber je Stadt und Land nur im Mittel. Darum
zusätzlich: je Altstadt eine genaue Zuteilung (`AudioFeed.cobbled_blocks`: in der Reihenfolge der Hashes wird
gepflastert, solange das näher an 60 % bringt) und je Land eine Hash-Schwelle (`concrete_threshold`, gerechnet von
`tools/audio/modern/calibrate_concrete.gd` über alle Etappen; gilt nur für den Anteil, mit dem sie gerechnet wurde).

{COUNTRY_TABLE}

Hamburg (800 m Altstadt, Blöcke vom Ziel aus): `P--PP-P-P` – vorher `PPPPPPPPP`.

### 3.3 Plattentakt (R3)

`slab_sync.gd`: Fahrt 100 → 130 → 160 → 125 → 95 → 140 km/h, 141 s; beide Muster zugleich hörbar in 660 Proben:
größter Abstand der beiden Schleifen 4,5 ms, kein Nachstellen nötig (Schwelle `slabs.align_ms` 6 ms – Godot meldet
die Abspielposition in Schritten von 64 Frames: zwei Schleifen im Gleichschritt lesen sich als 0, 2 oder 4 ms). Ein
Muster, das neu startet, beginnt an der Stelle des laufenden. `slabs.db` 3 unverändert; Wind im Tunnel 0 statt −3 dB.

### 3.4 Brückenfugen und Tankspur (R4, R6)

`trigger_log2.gd` (Autopilot über die ganze Etappe, Zeitraffer 8, Ereignisse des Feeds):

| Brücke | Deck, Länge | vorher | nachher (Lage ab Brückenanfang) |
|---|---|---|---|
| Köhlbrandbrücke (Kiel – Hamburg, km 78) | Stahl, 261 m | 12 (alle 24 m) | 4 (0, 100, 200, 261 m) |
| Elbbrücken (Kiel – Hamburg, km 84) | Stahl, 201 m | 9 | 3 (0, 100, 201 m) |
| Damm nach Venedig (Mailand – Venedig, km 268) | Beton, 378 m | 17 | 13 (alle 32 m) |
| Steinbogen vor Paris (Lüttich – Paris, km 387) | Stein, 129 m | 6 | 0 |

Rüttellinie rechts neben der Tankspur (Kiel – Hamburg, km 13,78–13,81): vorher 5 Bilder, nachher 0.

### 3.5 Begrenzer (R5)

True Peak des Masters bei Gesamtlautstärke 1,0 (4-fach überabgetastet); Begrenzung = Spitze vor dem Begrenzer
(hinter dem Kleber auf `MMaster`) minus Obergrenze. „Vorher“ hatte keinen Modern-Begrenzer (nur den Arcade-Begrenzer
auf `Master` bei −0,8 dB).

| Szene | vorher | nachher | Begrenzung nachher |
|---|---|---|---|
| schwerer Aufprall, 130 km/h Schließgeschwindigkeit, Pkw (24 Unfälle) | −0,62 dBTP | **−1,71 dBTP** | höchstens 2,36 dB, Median 0,2 |
| dasselbe gegen einen Lkw (16 Unfälle) | −0,63 | **−1,66** | höchstens 2,08 dB |
| Höchsttempo, Motor + Fahrbahn + Wind (Asphalt) | −2,77 | **−2,93** | 0 |
| schlimmster Fall von AU-C1 (Tunnel, Lkw, Martinshorn, Musik, zwei Unfälle, Leitplanke) | −0,47 | **−1,59** | bis 8,0 dB (die Szene liegt fast durchgehend darüber; ihre Lautheit −8,1 → −9,3 LUFS) |
| Reisen 130 km/h Asphalt und Beton, 170 Beton, 200 Asphalt | – | – | 0 |
| Reisen 200 km/h auf Beton, eine Minute | (15 Überschreitungen in 57 s, höchstens 1,47 dB) | – | 11 Eingriffe in 56 s, höchstens 0,96 dB, 2,4 % der Zeit |

Der schwere Schlag: mit `hit_heavy` −9,0 (AU-C1) nahm der Begrenzer bis 4,0 dB, mit −10,5 noch 3,7, mit −11,0
3,4, mit −11,5 höchstens 2,4 dB (dieselben 24 Zufallsfolgen). Die zufälligen Versätze (±2 dB, 0–20 ms je Schicht)
treffen manchmal genauer zusammen als die feste Anordnung von AU-C1. Höchsttempo: −14,9 LUFS bei Gesamtlautstärke
0,8 (Plan −15 ± 1).

### 3.6 Abwechslung (R6)

Varianten gegen die Datei von AU-C1 (Terzen bis 30 dB unter der lautesten, bei gleicher Spitze): Glas 0,20 / 0,84 /
0,31 dB, Kleinteile 0,89 / 0,91 / 0,76, Lkw-Schlag 0,42 / 0,32 / 0,62; Variante a ist nach 20 ms Vorlauf die alte
Datei, bitgleich. Auswahl zufällig ohne direkte Wiederholung; jede Schicht ±2 dB und 0–20 ms später (Mitte 10 ms,
also ±10 ms); Glas ab 80 km/h Schließgeschwindigkeit, darunter in 40 % der Unfälle; Vorbeifahrten: Variante zufällig,
±2 dB; Quietschen ±5 % Tonhöhe je Ereignis; Schnee: eigene Schleife (`tyre_snow`).

### 3.7 Klangfarbe

{CHAR_TEXT}

### 3.8 Arcade unverändert

1. **Keine eingefrorene Datei berührt**: `git diff --name-only 4209268..HEAD` über die Pfade von Regel 1
   (`scripts/race/`, `scripts/gameplay/`, `scripts/data/`, `scripts/audio/{engine_audio,engine_bank,engine_gearbox,
   room_audio,sfx_synth,traffic_audio}.gd`, `assets/sprites/`, `assets/audio/{engines,traffic,music}/`,
   `tools/audio/{engine,traffic,music}_synth.py`, `data/`), dazu `audio_manager.gd` und `scripts/ui/`: **0 Dateien**.
   Geändert sind nur `scripts/audio/modern`, `assets/audio/modern`, `tools/audio/modern`, `tests/unit/audio_modern`,
   `docs/audio-modern.md`, in `config/game_config.json` nur `audio.modern.*` und `audio._doc_modern`, dazu
   `tools/audio/music/{music_lib.py,mischung.json}` (Knopf `low_shelf_db`, bei 0 kein Filter) und
   `tools/audio/qc/audio_qc.py` (Ogg-Schleifen in `vehicle/`).
2. **Der Begrenzer sitzt nur auf `MMaster`** (dem Modern-Zweig): `test_arcade_identity.gd` (Motor-Mischer, SfxSynth,
   eingefrorene Klänge byte-gleich zu v0.7.0) und `check_modern_audio` („nach allem: Profil Arcade, 12 Busse mit
   Sends, Pegeln und Effekten wie in v0.7.0“) grün.
3. **`check_arcade_lean`**: ein Start mit Arcade lädt 0 von 35 Skripten des Modern-Klangs.
4. **Golden-Bilder**: siehe Abnahme.
