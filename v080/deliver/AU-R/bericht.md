# AU-R – Fahrbahnklang: nur die gemessenen Fehler behoben (Klangprofil „Modern“) – Bericht

Zweig `worktree-wf_5dca29a9-6fb-1`, gesichert als `origin/wip/v080-au-r`, Endstand **`3d2e6e1`**.
Arbeitsverzeichnis `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1`,
Basis `4209268` (Endstand AU-C1).

Deine Rückmeldung war: „die Sounds scheinen solide, auf Kopfhörer getestet; auch die Musik ist sehr gut“. Darum
behebt diese Runde **nur, was KRITIK-FAHRBAHN gemessen hat**, und hält die Klangfarbe. Die Musik ist unverändert
(kein neues Rendern; nur ein zusätzlicher Knopf `low_shelf_db`, der auf 0 steht und dann nichts tut).

**Gehört hat es hier niemand.** Alle Zahlen sind *gemessen* (diese Entwicklungsmaschine, Godot 4.7.2, ohne
Bildschirm, Dummy-Audiotreiber; die Maschine war von anderen Paketen mit belastet), sofern nicht *abgeleitet*
dabeisteht. „Vorher“ ist immer der Stand von AU-C1, mit denselben Messskripten aufgenommen.

## 0. Nachtrag AU-R2 – was sich danach noch geändert hat (dieser Ordner ist auf dem Stand AU-R2)

Eine unabhängige Nachmessung hat am Stand von AU-R noch Fehler gemessen; die Runde AU-R2 hat sie behoben (Zweig
`wip/v080-au-r2`, ausführlicher Bericht: `<scratch>/v080/deliver/AU-R2/bericht.md`). Stellen in diesem Bericht, die
dadurch überholt sind, tragen den Vermerk **[AU-R2]**.

| Was | in AU-R | jetzt (AU-R2) | worauf du achten kannst |
|---|---|---|---|
| Betonplatten („ta-tock“) | 32 neue Zufallsschläge; zwischen 110 und 150 km/h in der Mitte (300–630 Hz) bis 1,75 dB kräftiger als bei AU-C1 | die 32 Platten bestehen aus genau den 8 Fugenschlägen von AU-C1, nur in gemischter Folge (Klangfarbe höchstens 0,55 dB je Terz neben AU-C1) | `fahrt_kiel_hamburg_vorher_nachher` (neu aufgenommen): Beton ab 0:05 und ab 0:53 |
| Platten bei hohem Tempo | bei 200 km/h auf Beton griff der Begrenzer bis 1 dB ein | über 150 km/h werden die Platten langsamer lauter (170 km/h knapp 1 dB, 200 km/h 2 dB leiser als in AU-R); bis 150 km/h gleich | Beton bei 170 km/h: eine Spur zurückhaltender |
| Pflaster rechts | zwei Steine schlugen alle 7 s 2–3 dB lauter durch | anderer Zufallswert, keine Ausreißer (lautester Stein +0,2 dB gegen AU-C1) | Hamburger Innenstadt ab 1:25,8 |
| Rechenzeit auf Beton | der Klang wartete in jedem Bild auf den Mischer | nur beim Start eines Plattenmusters und zweimal je Sekunde | (nur gemessen) |
| Aufprall | – | unverändert (mit je 60 Unfällen nachgemessen: Begrenzer in 95 % höchstens 2,1 / 2,4 dB) | `aufprall_abwechslung_neu` gilt weiter |

Neu aufgenommen in diesem Ordner: `fahrt_kiel_hamburg_vorher_nachher.mp3` und `fahrt_kiel_hamburg_spielmix_neu.mp3`
(Stand AU-R2). Unverändert gültig: `aufprall_abwechslung_neu`, `schnee_neu`, `koehlbrandbruecke_fugen_vorher_nachher`.

## 1. Was sich geändert hat – worauf du achten kannst

| Was | vorher (AU-C1) | jetzt (AU-R) | worauf du achten kannst |
|---|---|---|---|
| Rollen und Wind | links und rechts dieselbe 2-s-Schleife (rechts nur versetzt gelesen): ein Pochen, das sich jede Sekunde wiederholt | jede Seite eine eigene Schleife von 4–7,6 s, Start an zufälliger Stelle, langsames Schwanken des Pegels je Seite (±1,5 dB), rechts 2 % höher | in `fahrt_kiel_hamburg_vorher_nachher` kein Takt mehr im Rauschen; die Klangfarbe soll dieselbe sein (Terzen höchstens 1 dB anders) |
| Pflaster in den Altstädten | Hamburg ganz gepflastert, Paris gar nicht (der Hash mischte nicht) | jede Altstadt zu 55–64 % gepflastert, Blöcke wechseln mit Asphalt | Hamburger Innenstadt: Asphalt → Pflaster → Asphalt (Zeiten in der .txt) |
| Betonplatten | Akzentmuster alle 8 Platten (40 m) gleich | 32 Platten je Muster; das langsame und das schnelle Muster immer im selben Takt; **[AU-R2]** die 32 Platten sind die 8 Fugen von AU-C1 in gemischter Folge, über 150 km/h langsamer lauter | das „ta-tock“ bleibt, beim Beschleunigen zwischen 110 und 150 km/h kein doppelter Schlag |
| Brückenfugen | alle 24 m, auf jeder Brücke | Stahl: an den Enden und etwa alle 100 m; Beton alle 32 m; Steinbogen keine | `koehlbrandbruecke_fugen_vorher_nachher`: statt 12 nur noch 4 Fugen |
| Tankspur | rechts Rüttelstreifen, obwohl dort eine gestrichelte Linie ist | neben der Tankspur rechts glatt | (nur gemessen) |
| Tunnel | der Fahrtwind fiel um 3 dB | der Fahrtwind bleibt | Tunnel nicht plötzlich leiser |
| Aufprall | immer dieselben Dateien, gleich laut, Glas bei jedem Unfall | Glas, Kleinteile, Lkw-Schlag je 4 Varianten; jede Schicht ±2 dB und bis 20 ms versetzt; Glas ab 80 km/h Schließgeschwindigkeit, darunter in 40 %; der tiefe Schlag schwerer Unfälle 2,5 dB leiser (der neue Begrenzer nimmt sonst bis 4 dB) | `aufprall_abwechslung_neu`: kein Unfall klingt wie der vorige; ob die schweren noch genug Wucht haben, ist deine Entscheidung |
| Vorbeifahrten an Pfosten, Bäumen, Gebäuden | jede gleich laut, Varianten reihum | Variante zufällig, ±2 dB | – |
| Quietschen | immer dieselbe Tonhöhe | jedes Quietschen ±5 % | – |
| Schnee | gedämpftes Schotter-Prasseln | eigene Schleife: weiches Knirschen | `schnee_neu` |
| laute Momente | Unfall und schlimmster Fall bei Gesamtlautstärke 1,0 bis −0,5 dBTP | Begrenzer im Modern-Zweig (−2 dB): alles höchstens −1,6 dBTP | nichts sollte übersteuern |


## 2. Abnahme – Punkt für Punkt

| Punkt | Ergebnis | Beleg |
|---|---|---|
| R1 Wiederholung im Spielmix (20 s, festes Tempo): keine Spitze ≥ 0,40 bei 0,3–3 s | Asphalt 130 (0,6–1,6 kHz) **bestanden**: 0,603 → 0,111 (0,6–1,6 kHz); Pflaster 50 **bestanden**: 0,982 → 0,146 (2,5–8 kHz); Beton 130 (2,5–8 kHz) **nicht bestanden**: 0,887 → 0,647 – das ist der Takt der Platten (eine Fuge alle 5 m), ohne Plattenschicht 0,11 | 3.1 |
| R1 Mittel: eigene Schleife je Seite (zweiter Seed, Längen 4,1–7,6 s, Verhältnis kein kleiner Bruch), zufälliger Start, Pegeldrift ±1,5 dB (τ 0,8 s), rechts × 1,02 (Rüttelstreifen genau), Ogg q5 mit geprüfter Naht | umgesetzt; QC: Nähte ×0,02–1,89 (erlaubt ×2; am rauesten `wind_buffet`, deshalb q8), 59 Klänge 0 Fehler | `pruefung_qc_determinismus.txt` |
| R2 fmix32 auf `key.hash()`; Anteile je Land/Stadt über alle Etappen ±0,05 | Pflaster: 47 von 47 Altstädten (0,55–0,64), gesamt 0,566; Beton: 14 von 18 Ländern, gesamt 0,205 (Soll 0,207); SI, LT, BG, LV können es nicht (1–5 Abschnitte) | 3.2 |
| R3 Plattenmuster nie gegenphasig; `slabs.db` 3; Tunnel-Wind 0 | **bestanden**: 141 s Fahrt 100–160 km/h, größter Abstand 4,5 ms, 0 Nachstellungen | 3.3 |
| R4 Fugen je Deck, belegt im Triggerlog | **bestanden**: Köhlbrandbrücke 12 → 4, Elbbrücken 9 → 3, Damm Venedig 17 → 13, Steinbogen Paris 6 → 0 | 3.4 |
| R5 Begrenzer nur im Modern-Zweig (MMaster hinter dem Kleber, −2,0 dB, 0,12 s) | umgesetzt (`audio.modern.limiter`, `modern_buses.gd`); Test `test_limiter_from_config` | |
| R5 Unfall 130, Höchsttempo, schlimmster Fall ≤ −1,0 dBTP bei Gesamtlautstärke 1,0 | **bestanden**: −1,71 / −2,93 / −1,59 dBTP (Lkw −1,66); vorher −0,62 / −2,77 / −0,47 | 3.5 |
| R5 Reisen 130–200 km/h: Begrenzung ≤ 0,5 dB | 130 und 170 km/h, 200 auf Asphalt: 0 dB; **200 km/h auf Beton nicht**: 12 Eingriffe je Minute, höchstens 1,0 dB (mit dem Pegel von AU-C1 wären es 16 und 1,5 dB) – die Plattenschläge liegen bei −2,7 dBFS. **[AU-R2]** bestanden: vier Läufe höchstens 0,44 / 0,43 / 0,08 / 0,08 dB | 3.5 |
| R5 Unfall: Begrenzung > 3 dB → nur die lauteste schwere Schicht senken | `hit_heavy` (schwer) −9,0 → −11,5 dB, Lkw-Schlag (schwer) −10 → −11 dB: höchstens 2,4 dB (24 Unfälle) bzw. 2,1 dB (16) | 3.5 |
| R5 Plan-Zeile Höchsttempo −15 ± 1 LUFS mit Test | **bestanden**: −14,9 LUFS (Gesamtlautstärke 0,8); `test_top_speed_row_of_the_plan` | |
| R5 Arcade-Busse, -Begrenzer, -Konfiguration unverändert | **bestanden** (3.8) | |
| R6 je ≥ 4 Varianten Glas / Kleinteile / Lkw-Schlag, Spektrum ±1 dB | **bestanden**: höchstens 0,20–0,91 dB gegen die Datei von AU-C1 | 3.6 |
| R6 Zufall ±2 dB / ±10 ms je Schicht (Unfall, Vorbeifahrten), Glas ab 80 km/h oder 40 %, Quietschen ±5 %, keine Rüttellinie neben der Tankspur, eigene Schnee-Schleife | **umgesetzt**, Tests in `test_road_audio.gd` / `test_audio_feed.gd`; Tankspur im Triggerlog 5 → 0 Bilder | 3.4, 3.6 |
| Klangfarbe: Terzen ±1 dB bei den Bezugstempi, Lautheit ±0,5 LU | **bestanden**: im Spiel ohne Zufall höchstens 0,97 dB je Terz (Beton, 398 Hz), Lautheit höchstens 0,27 LU daneben; die Schleifen selbst (gehörter Klang nachgebildet) höchstens 0,71 dB. **[AU-R2]** Die Nachmessung fand die Plattenschicht allein bei +1,75 dB (398 Hz) – jetzt +0,55 dB; Pflaster jetzt höchstens 0,56 dB | 3.7 |
| QC (Nähte, Pegel, Determinismus) | **bestanden**: „59 Klänge geprüft, 0 mit Fehlern“, alle vier Generatoren deterministisch | `pruefung_qc_determinismus.txt` |
| `check_arcade_lean`, eingefrorene Dateien | **bestanden**: 0 von 35 Modern-Skripten geladen; 0 eingefrorene Dateien seit AU-C1 geändert | 3.8 |
| `tools/run_tests.sh` | **bestanden**: „652 Tests, 0 fehlgeschlagen“, alle CHECK-Blöcke OK, „Tests bestanden (708 s)“ – ein Lauf, auf `3d2e6e1` | `pruefung_run_tests.txt` |
| `tools/golden.sh check` | **bestanden**: „GOLDEN arcade: 20 von 20 identisch (253 s)“ – ein Lauf, auf `3d2e6e1` | `pruefung_golden.txt` |

## 3. Messungen vorher → nachher

Aufnahmen am Master des Spiels, Limousine auf Kiel – Hamburg (Beton- und Pflasteranteil für die Messung erzwungen),
„vorher“ = Stand AU-C1 mit denselben Skripten. Skripte und Rohdaten: `<scratch>/v080/m1/AU-R/`.

### 3.1 Wiederholung (R1)

Spielmix (Motor + Fahrbahn + Wind), 20 s bei festem Tempo; Hüllkurve aus 10-ms-RMS der Monosumme im Band,
Autokorrelation ohne Mittelwert; Grenzwert: keine Spitze ≥ 0,40 bei 0,3–3 s. Alle Spitzen bis 8 s:

| Aufnahme | Band | vorher: Spitzen 0,3–3 s | nachher: Spitzen 0,3–3 s | nachher: Spitzen 3–8 s | < 0,40 |
|---|---|---|---|---|---|
| Asphalt 130 km/h | 600–1600 Hz | 0,603 bei 0,97 s, 0,572 bei 2,92 s, 0,452 bei 1,94 s | 0,111 bei 0,39 s, 0,049 bei 0,90 s, 0,027 bei 2,31 s | 0,177 bei 6,39 s, 0,118 bei 5,15 s, 0,098 bei 6,78 s, 0,081 bei 3,60 s | ja |
| Asphalt 130 km/h | 2500–8000 Hz | 0,355 bei 0,97 s, 0,310 bei 2,92 s, 0,257 bei 1,94 s | 0,157 bei 0,42 s, 0,104 bei 2,80 s, 0,052 bei 2,43 s | 0,150 bei 6,39 s, 0,137 bei 5,15 s, 0,081 bei 6,79 s, 0,073 bei 7,29 s | ja |
| Beton 130 km/h | 2500–8000 Hz | 0,887 bei 0,97 s, 0,806 bei 1,94 s, 0,716 bei 2,77 s | 0,647 bei 1,80 s, 0,616 bei 0,83 s, 0,594 bei 2,63 s | 0,635 bei 3,60 s, 0,600 bei 4,43 s, 0,577 bei 6,37 s, 0,564 bei 7,20 s | nein |
| Beton 130 km/h | 600–1600 Hz | 0,685 bei 0,97 s, 0,584 bei 1,94 s, 0,474 bei 2,91 s | 0,313 bei 0,97 s, 0,312 bei 1,52 s, 0,301 bei 1,94 s | 0,344 bei 3,60 s, 0,258 bei 4,43 s, 0,233 bei 7,20 s, 0,232 bei 6,23 s | ja |
| Beton 130 km/h ohne Plattenschicht | 2500–8000 Hz | – | 0,113 bei 1,87 s | 0,125 bei 3,09 s, 0,125 bei 3,37 s, 0,100 bei 4,96 s, 0,086 bei 6,83 s | ja |
| Pflaster 50 km/h | 2500–8000 Hz | 0,982 bei 2,50 s, 0,981 bei 1,25 s, 0,153 bei 0,95 s | 0,146 bei 0,57 s, 0,088 bei 1,56 s, 0,080 bei 1,26 s | 0,471 bei 6,96 s, 0,401 bei 5,70 s, 0,091 bei 4,00 s, 0,090 bei 7,31 s | ja |
| Pflaster 50 km/h | 600–1600 Hz | 0,701 bei 1,25 s, 0,693 bei 2,50 s, 0,098 bei 0,69 s | 0,104 bei 1,51 s, 0,099 bei 0,30 s, 0,083 bei 1,73 s | 0,255 bei 6,96 s, 0,155 bei 5,70 s, 0,087 bei 7,89 s, 0,086 bei 7,32 s | ja |
| Pflaster 50 km/h | breitbandig | 0,113 bei 2,50 s, 0,107 bei 2,06 s, 0,102 bei 1,51 s | 0,154 bei 0,35 s, 0,124 bei 2,03 s, 0,121 bei 1,63 s | 0,077 bei 3,72 s, 0,070 bei 5,68 s, 0,055 bei 4,00 s, 0,055 bei 4,52 s | ja |

Die Spitzen jenseits von 3 s sind die Längen der beiden Schleifen (links und rechts eigene). Auf Beton bleibt der
Takt der Platten: 0,83 s sind 6 Platten bei 130 km/h, 1,80 s sind 13 – ohne die Plattenschicht liegt Beton bei
0,11 (Aufnahme `conc130_noslab_full`, mit dem Zwischenstand der Schleifen vor der Angleichung der Klangfarbe – ein
festes Filter, das die Hüllkurve kaum ändert). Die Platten bleiben laut Vorgabe, wie sie sind (`slabs.db` 3).

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

| Land | Abschnitte | km | Soll | AU-C1 (djb2) | nur fmix32 | AU-R (Schwelle) | in ±0,05 |
|---|---|---|---|---|---|---|---|
| DE | 168 | 4519 | 0,35 | 0,423 | 0,267 | 0,349 | ja |
| FR | 50 | 2155 | 0,10 | 0,116 | 0,104 | 0,104 | ja |
| ES | 36 | 1415 | 0,10 | 0,166 | 0,134 | 0,085 | ja |
| PL | 17 | 820 | 0,25 | 0,360 | 0,177 | 0,238 | ja |
| RS | 14 | 665 | 0,10 | 0,000 | 0,060 | 0,060 | ja |
| HU | 14 | 560 | 0,10 | 0,170 | 0,125 | 0,125 | ja |
| RO | 15 | 530 | 0,10 | 0,000 | 0,000 | 0,094 | ja |
| CZ | 15 | 502 | 0,40 | 0,432 | 0,279 | 0,418 | ja |
| BE | 17 | 490 | 0,30 | 0,469 | 0,255 | 0,296 | ja |
| CH | 13 | 470 | 0,10 | 0,128 | 0,000 | 0,096 | ja |
| IT | 13 | 468 | 0,10 | 0,107 | 0,139 | 0,075 | ja |
| NL | 14 | 435 | 0,10 | 0,034 | 0,103 | 0,103 | ja |
| AT | 15 | 414 | 0,15 | 0,215 | 0,000 | 0,155 | ja |
| HR | 8 | 320 | 0,10 | 0,063 | 0,141 | 0,141 | ja |
| SI | 5 | 210 | 0,10 | 0,000 | 0,000 | 0,190 | nein |
| LT | 3 | 165 | 0,10 | 0,000 | 0,333 | 0,000 | nein |
| BG | 1 | 25 | 0,10 | 0,000 | 0,000 | 0,000 | nein |
| LV | 1 | 20 | 0,10 | 0,000 | 0,000 | 0,000 | nein |

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

Im Spiel aufgenommen, ohne Zufall (Drift, Böen und Vorbeifahrten aus), 20 s, Gesamtlautstärke 1,0; Terzen
25 Hz–12,5 kHz bis 30 dB unter der lautesten:

| Aufnahme | Lautheit vorher → nachher | größte Terz-Abweichung |
|---|---|---|
| Asphalt 130 km/h, nur Fahrbahn | −27,80 → −27,64 LUFS (+0,16 LU) | 0,49 dB bei 251 Hz |
| Beton 130 km/h, nur Fahrbahn | −22,38 → −22,34 (+0,04) | 0,97 dB bei 398 Hz |
| Pflaster 50 km/h, nur Fahrbahn | −20,98 → −21,20 (−0,22) | 0,74 dB bei 40 Hz |
| Wind 130 km/h, nur Wind | −34,77 → −34,75 (+0,03) | 0,38 dB bei 32 Hz |
| Spielmix Asphalt 130 | −14,91 → −14,99 (−0,08) | 0,39 dB |
| Spielmix Beton 130 | −14,85 → −15,11 (−0,27) | 0,68 dB |
| Spielmix Pflaster 50 | −17,09 → −16,93 (+0,15) | 0,50 dB |

Der Weg dahin: Die neuen Schleifen (andere Seeds, 2–3-mal so lang) wichen zuerst in den tiefen Terzen bis 3,5 dB ab
(Pflaster rechts). Sie sind an die Schleifen von AU-C1 angeglichen – und zwar an das, was davon **zu hören** war:
AU-C1 las dieselbe Schleife auf zwei Spielern eine halbe Länge versetzt, dadurch addierten sich ihre Harmonischen
abwechselnd gleich- und gegenphasig (beim Pflaster +1,0 dB bei 126 Hz). Ohne diese Nachbildung lag Pflaster bei
1,00 dB, der Spielmix Pflaster bei 1,05 dB; mit ihr bei 0,74 und 0,50 dB. Nachbildung des Gehörten für alle Schleifen
bei ihrem Bezugstempo: höchstens 0,71 dB (Pflaster bei 10 kHz), Varianten von Glas, Kleinteilen, Lkw-Schlag
höchstens 0,91 dB.

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

## 4. Hörproben (dieser Ordner)

Alle am Master-Bus des Spiels aufgenommen (Gesamtlautstärke 0,8 wie im Spiel voreingestellt), MP3 192 kbit/s; zu
jeder eine .txt mit Zeitmarken.

| Datei | Inhalt |
|---|---|
| `fahrt_kiel_hamburg_vorher_nachher.mp3` (1:34) **[AU-R2: neu aufgenommen, „nachher“ = Stand AU-R2]** | dieselbe Fahrt zweimal, AU-C1 und AU-R2, 2 s Stille dazwischen: Autobahn in den Beton, Köhlbrandbrücke, Rüttelstreifen, Bankett, Leitplanke, Hamburger Innenstadt – dort nachher Asphalt ab 1:23,7, **Pflaster ab 1:25,8, wieder Asphalt ab 1:32,0** (vorher durchgehend Pflaster ab 0:35,9) |
| `fahrt_kiel_hamburg_spielmix_neu.mp3` (0:46) **[AU-R2: neu aufgenommen]** | dieselbe Fahrt nachher mit Rennmusik im Spielmix; Hamburg: Asphalt, Pflaster ab 0:37,4, Asphalt ab 0:43,6 |
| `aufprall_abwechslung_neu.mp3` (0:21) | acht Unfälle (schwer und mittel, einer gegen einen Lkw) mit den gewürfelten Varianten, Pegeln und Einsätzen je Schicht in der .txt |
| `schnee_neu.mp3` (0:17) | Schnee bei 50, 90 und 130 km/h mit der eigenen Knirsch-Schleife |
| `koehlbrandbruecke_fugen_vorher_nachher.mp3` (0:23) | die Brücke mit 120 km/h: vorher 12 Fugen (alle 24 m), nachher 4 (Enden und alle 100 m) |
| `pruefung_qc_determinismus.txt`, `pruefung_run_tests.txt`, `pruefung_golden.txt` | die Prüfläufe |

Die Zeitmarken sind Tonzeit: Unter Last läuft die Aufnahme ohne Bildschirm ein paar Prozent langsamer als das
Skript; die Marken sind darauf umgerechnet.

## 5. Abweichungen und offene Vertragsfragen

**Abweichungen vom Auftrag**
1. **R2 über fmix32 hinaus**: fmix32 allein trifft die Anteile nur im Mittel (Altstädte 0,34–0,90, 8 von 18 Ländern).
   Dazu kamen eine genaue Zuteilung je Altstadt (`cobbled_blocks`) und eine kalibrierte Schwelle je Land
   (`concrete_threshold` + Werkzeug `calibrate_concrete.gd`). Kommen Etappen dazu, muss das Werkzeug neu laufen
   (ein Test meldet einen geänderten Anteil).
2. **Klangfarbe aktiv gehalten**: Die neuen Schleifen (andere Seeds, andere Längen) wichen in den tiefen Terzen bis
   3,5 dB ab; sie sind an den gehörten Klang von AU-C1 angeglichen (`match_loop`, `heard`), die neuen Varianten von
   Glas, Kleinteilen und Lkw-Schlag ebenso (`match_spectrum`).
3. **Zwei Schichten gesenkt statt einer**: bei schweren Unfällen gegen Pkw der tiefe Schlag (−2,5 dB), gegen Lkw der
   Schlag des Aufbaus (−1 dB) – er ersetzt dort den tiefen Schlag und ist die lauteste Schicht.
4. **`tools/audio/qc/audio_qc.py`** geändert (Ogg für Schleifen in `vehicle/` zugelassen) – außerhalb der eigenen
   Dateien, aber nötig für die erlaubten Ogg-Schleifen.
5. **±10 ms** als 0–20 ms später umgesetzt (20 ms Stille vor jeder Schicht): ein früherer Einsatz als „jetzt“ geht
   nicht.
6. **Plattenabgleich**: Schwelle 6 ms statt „exakt“ – Godot meldet die Position in 64-Frame-Schritten.

**Offene Vertragsfragen**
1. **Beton-Wiederholung**: Der Grenzwert 0,40 (R1) passt nicht zu einem gewollten Takt (Platten alle 5 m); mit
   `slabs.db` 3 (Vorgabe: bleibt) misst Beton 0,65. Entweder gilt der Grenzwert dort ohne die Plattenschicht (0,11)
   oder die Platten werden leiser/unregelmäßiger (nächste Runde: `slabs.db` 3 → −3). **[AU-R2]** weiter offen:
   0,687 mit den Platten, 0,196 ohne, 0,369 mit `slabs.db` −3.
2. **Begrenzer bei 200 km/h auf Beton**: Die Plattenschläge liegen dort bei −2,7 dBFS, knapp unter der Obergrenze
   −2 dB; 12 Eingriffe je Minute bis 1,0 dB (R5 will ≤ 0,5 dB beim Reisen). Lösung ist derselbe Plattenpegel.
   **[AU-R2]** behoben über einen flacheren Plattenpegel oberhalb von 150 km/h (vier Läufe ≤ 0,44 dB).
3. **Beton je Land**: Slowenien (5 Abschnitte), Litauen (3), Bulgarien und Lettland (je 1) können ±0,05 nicht
   erreichen – ihr nächster möglicher Anteil ist 0 oder mindestens 0,19.
4. **Unfall-Begrenzung ist eine Statistik**: Mit zufälligen Versätzen wächst die größte Begrenzung mit der Zahl der
   Unfälle; gemessen höchstens 2,4 dB in 24 Unfällen.

## 6. Für die nächste Runde (nicht in dieser)

- Plattenpegel `slabs.db` 3 → −3 (löst auch 5.1 und 5.2), Pflaster `surface_db` 19 → 12
- Glas in Körnern statt eines Rauschens, mehrere Stimmen beim Quietschen
- Leitplanke und Lkw-Schlag kürzer ausschwingen lassen, die Spitze des Reifenhohlraums, das Klacken auf kleinen
  Lautsprechern, die Mischung für Handgeräte
- alle Vorschläge zur Musikmischung (der Knopf `low_shelf_db` steht bereit, auf 0)
- `calibrate_concrete.gd` neu laufen lassen, wenn Etappen dazukommen

## 7. Ehrliches Urteil

- **Was die Messungen sagen**: Die gemessenen Fehler von KRITIK-FAHRBAHN sind behoben, wo es der Vertrag zulässt:
  kein Pochen im Sekundentakt mehr auf Asphalt und Pflaster (0,60 / 0,98 → 0,11 / 0,15), jede Altstadt mit
  Pflaster und Asphalt im Wechsel, Fugen nur dort, wo eine Brücke welche hat, keine Rüttellinie an der Tankspur,
  laute Momente bei voller Lautstärke mindestens 1,6 dB unter 0 dBTP, Unfälle in Varianten. Die Klangfarbe der
  Schleifen ist im Spiel auf 1 dB je Terz und 0,3 LU geblieben.
- **Was nicht erreicht ist**: Beton wiederholt sich weiter im Plattentakt (0,65) – das ist der Takt selbst, nicht
  die Schleife; bei 200 km/h auf Beton greift der Begrenzer etwa 12-mal je Minute um bis 1 dB; vier kleine Länder
  treffen ihren Betonanteil nicht. Alle drei hängen am Pegel der Platten oder an zu wenigen Abschnitten.
- **Was ein Ohr prüfen muss**: ob die schweren Unfälle mit dem 2,5 dB leiseren tiefen Schlag noch genug Wucht haben;
  ob die langsame Pegeldrift je Seite (±1,5 dB) natürlich wirkt oder als Schwanken auffällt; ob Ogg q5 bei den
  Rauschschleifen hörbar ist (gemessen: Nähte sauber, Spektrum gleich).
- **Gehört hat es hier niemand.** Das Urteil liegt bei dir – die Hörproben stehen in diesem Ordner.
