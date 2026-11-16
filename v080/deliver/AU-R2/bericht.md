# AU-R2 – Fahrbahnklang: die Befunde der Nachmessung behoben (Klangprofil „Modern“) – Bericht

Zweig `worktree-wf_5dca29a9-6fb-3`, gesichert als `origin/wip/v080-au-r2`, Endstand **`3600eb7`**.
Arbeitsverzeichnis `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-3`,
Basis `3d2e6e1` (Endstand AU-R).

Deine Rückmeldung war: „die Sounds scheinen solide, auf Kopfhörer getestet; auch die Musik ist sehr gut“. Eine
unabhängige Nachmessung (KRITIK-R) hat am Stand von AU-R zwei hohe und fünf mittlere Befunde gemessen. Diese Runde
behebt sie, hält den Klang, den du gehört hast (AU-C1), und misst jeden Befund **mit den Skripten der Nachmessung**
nach. Die Musik ist unverändert (keine Datei, kein Pegel). Die Hörproben liegen weiter in **einem** Ordner:
`<scratch>/v080/deliver/AU-R/` (zwei davon in dieser Runde neu aufgenommen, Abschnitt 4).

**Gehört hat es hier niemand.** Alle Zahlen sind *gemessen* (diese Entwicklungsmaschine, Godot 4.7.2 ohne Bildschirm,
Dummy-Audiotreiber, Limousine auf Kiel – Hamburg; die Maschine war von anderen Paketen stark belastet), sofern nicht
*abgeleitet* dasteht. „AU-C1“ ist der Stand, den du gehört hast – in dieser Runde mit denselben Skripten neu
aufgenommen; „AU-R“ sind die Zahlen der Nachmessung.

## 1. Was sich geändert hat – worauf du achten kannst

| Was | in der Runde davor (AU-R) | jetzt (AU-R2) | worauf du achten kannst |
|---|---|---|---|
| Betonplatten („ta-tock“) | 32 neue, zufällige Fugenschläge; zwischen 110 und 150 km/h klang das Paar der beiden Plattenmuster in der Mitte (300–630 Hz) bis 1,75 dB kräftiger als bei AU-C1 | die 32 Platten bestehen aus genau den 8 Fugenschlägen, die du bei AU-C1 gehört hast – nur in gemischter Folge, damit sich das Muster nicht alle 40 m wiederholt | in `fahrt_kiel_hamburg_vorher_nachher` ab 0:05 und ab 0:53 soll das „ta-tock“ gleich klingen |
| Platten bei hohem Tempo | bei 200 km/h auf Beton griff der neue Begrenzer bis 1 dB ein | über 150 km/h werden die Platten langsamer lauter: bei 170 km/h knapp 1 dB, bei 200 km/h 2 dB leiser als in der Runde davor (bis 150 km/h unverändert) | Beton bei 170 km/h: das „ta-tock“ eine Spur zurückhaltender |
| Pflaster | rechts kamen alle 7 s zwei einzelne Steine 2–3 dB lauter durch (alle vier Räder trafen gleichzeitig) | die rechte Pflasterschleife hat einen anderen Zufallswert, ohne solche Ausreißer | Hamburger Innenstadt (1:25–1:32): kein einzelner „Klack“, der regelmäßig wiederkommt |
| Rechenzeit auf Beton | der Klang wartete in jedem Bild kurz auf den Audio-Mischer (einzelne Bilder bis 17 ms) | nur noch beim Start eines Plattenmusters und zweimal je Sekunde | (nur gemessen) |
| Aufprall | – | unverändert; mit je 60 Unfällen nachgemessen: der Begrenzer nimmt in 95 % der schweren Unfälle höchstens 2,1 dB (Pkw) bzw. 2,4 dB (Lkw) | (nur gemessen) |
| Musik, Motor, alle anderen Klänge | – | unverändert (Dateien bitgleich) | – |

## 2. Die Befunde der Nachmessung – Ergebnis

| Befund | AU-R (Nachmessung) | AU-R2 | Ziel | Ergebnis |
|---|---|---|---|---|
| **H1** Plattenschicht in der Klangfarbe (130 km/h, ohne Zufall) | nur Platten +1,75 dB bei 398 Hz; Beton nur Fahrbahn +1,09 dB | nur Platten +0,55 dB bei 631 Hz (+0,13 LU); Beton nur Fahrbahn +0,32 dB bei 398 Hz (+0,07 LU) | ±1 dB je Terz, ±0,5 LU | **behoben** |
| **H2** Wiederholung auf Beton (130 km/h, 2,5–8 kHz) | 0,642 bei 1,80 s | 0,687 bei 1,80 s (der Takt der Platten); ohne Platten 0,196; mit `slabs.db` 0: 0,518, mit −3: 0,369 | < 0,40 bei 0,3–3 s | **offen – Vertragsfrage** (Abschnitt 5) |
| **M1** Sperre des Audioservers in jedem Bild | `road` 0,37–0,40 ms im Mittel, 95 % 0,59–0,62 ms | 0,27–0,34 ms, 95 % 0,29–0,38 ms; Sperre nur beim Start und alle 0,5 s | keine Sperre im Dauerbetrieb | **behoben** |
| **M2** Begrenzung beim schweren Aufprall an der 3-dB-Grenze | max 2,97 dB (24 Unfälle) | 60 Unfälle: 95 % 2,14 dB, Median 0,27, höchstens 4,05 dB (1 von 60 über 3 dB) | ≤ 3 dB | **hält als 95-%-Wert**, das Maximum nicht – Vertragsfrage (Abschnitt 5) |
| **M3** Begrenzung beim Reisen, 200 km/h Beton | 0,44 dB (AU-R selbst 0,96) | vier Läufe: 0,44 / 0,43 / 0,08 / 0,08 dB | ≤ 0,5 dB | **behoben** (zwei Läufe knapp darunter) |
| **M4** Lkw-Schlag −1 dB ohne Messgrund | mit −10 dB 2,66 dB (16 Unfälle) | 60 Unfälle: mit −10 dB 95 % **3,02 dB**, 4 von 60 über 3 dB; mit −11 dB 95 % 2,42 dB | ≥ 50 Unfälle, 95-%-Wert ≤ 3 dB | **−11 bleibt** (die größere Stichprobe begründet die Senkung, knapp) |
| **M5** einzelne laute Pflastersteine | lautester Stein +1,6 / +3,0 dB über AU-C1, True Peak −6,34 dBTP | +0,12 / +0,21 dB, True Peak −8,59 dBTP (AU-C1 −9,02) | wie AU-C1 | **behoben** |

## 3. Messungen

Skripte der Nachmessung (Kopien in `<scratch>/v080/m1/AU-R2/ktools/`, unverändert bis auf die Pfade und einen
zusätzlichen Schalter `slab_db` je Abschnitt): `kr_capture.gd` mit den Plänen A (wie gespielt) und B (ohne
Pegeldrift, Böen, Vorbeifahrten), `kr_crash.gd`, `kr_perf_conc.gd`, Auswertung `ana_cap.py`, `ana_compare.py`,
`ana_crash.py`, dazu `ana_peaks.py` (Spitzen je Kanal). AU-C1 lief als Kopie von `4209268` mit denselben Skripten.

### 3.1 Klangfarbe (Plan B, ohne Zufall, 20 s, Gesamtlautstärke 1,0; Terzen 25 Hz–12,5 kHz bis 30 dB unter der lautesten)

| Aufnahme | AU-C1 → AU-R (Nachmessung) | AU-C1 → AU-R2 | in den Grenzen |
|---|---|---|---|
| Beton 130, nur Platten | +0,06 LU, +1,75 dB bei 398 Hz | −25,47 → −25,34 LUFS (+0,13 LU), +0,55 dB bei 631 Hz | ja |
| Beton 130, nur Fahrbahn | +0,04 LU, +1,09 dB bei 398 Hz | −22,38 → −22,31 (+0,07 LU), +0,32 dB bei 398 Hz | ja |
| Beton 130, nur Reifen | +0,06 LU, +0,44 dB bei 50 Hz | −25,32 → −25,21 (+0,11 LU), +0,53 dB bei 50 Hz | ja |
| Spielmix Beton 130 | −0,04 LU, +0,78 dB | −14,72 → −14,69 (+0,03 LU), +0,52 dB bei 25 Hz | ja |
| Pflaster 50, nur Fahrbahn | −0,28 LU, −0,77 dB bei 40 Hz | −20,98 → −21,15 (−0,17 LU), −0,56 dB bei 25 Hz | ja |
| Spielmix Pflaster 50 | +0,30 LU, −1,02 dB bei 40 Hz | −17,16 → −16,99 (+0,17 LU), −0,44 dB bei 40 Hz | ja |
| Asphalt 130, nur Fahrbahn (Dateien unverändert) | +0,17 LU, +0,54 dB bei 251 Hz | −27,81 → −27,67 (+0,14 LU), +0,52 dB bei 100 Hz | ja |

Die Plattenmuster im Modell (Dateien, Tonhöhen, Überblendung und Pegel wie im Spiel; 3.2): bei 90, 105, 120, 130,
140, 160, 180, 200 und 230 km/h höchstens 0,43 dB je Terz und 0,14 LU neben AU-C1.
Die rechte Pflasterschleife wurde zweimal erneuert: erst nur der Seed (die 40-Hz-Terz lag dann bei −0,94 dB,
der Spielmix bei −1,31 dB), dann zusätzlich für ihre Tonhöhe angeglichen (oben).

### 3.2 Ursache von H1 – und warum die Angleichung der Nachmessung nicht gereicht hätte

Die Nachmessung vermutete, die neuen Plattenmuster seien nicht an AU-C1 angeglichen. Sie waren es (jedes allein
innerhalb 0,8 dB). Die Abweichung entstand im **Paar**: Zwischen 110 und 150 km/h klingen beide Muster zugleich und
seit AU-R im Gleichschritt; ihre Schläge fallen auf dieselben Zeitpunkte und beginnen ihre Schwingungen bei Phase 0,
darum addieren sie sich teilweise kohärent, und welcher Schlag des einen auf welchen des anderen trifft, formt
200–1000 Hz um bis zu ±2,5 dB. Ein Modell der Schicht aus den Dateien zeigt das (AU-C1 im Gleichschritt gegen AU-C1 mit
zufälligem Versatz: bis −5 dB in einzelnen Terzen) und trifft die Messung der Nachmessung (+1,72 statt +1,75 dB bei
398 Hz; fünf weitere Terzen auf 0,05 dB, 501 und 631 Hz auf 0,7 bzw. 0,3 dB). Von 64 Paaren neuer Zufallsmuster (die
je 8 besten von 40 Seeds je Entwurf) lag keines bei 120–140 km/h innerhalb 1 dB (das beste bei 1,11 dB). Darum
bestehen die Muster jetzt aus den Fugen von AU-C1, paarweise wie bei AU-C1.

### 3.3 Wiederholung R1 (Plan A, wie gespielt, Spielmix, Hüllkurven-Autokorrelation der Monosumme)

| Aufnahme (Band) | AU-C1 (0,3–3 s) | AU-R (Nachmessung) | AU-R2 (0,3–3 s) | AU-R2, Spitzen 3–8 s | < 0,40 |
|---|---|---|---|---|---|
| Asphalt 130 (0,6–1,6 kHz) | 0,626 bei 0,97 s | 0,098 | 0,151 bei 0,40 s | 0,152 bei 5,15 s | ja |
| Beton 130 (2,5–8 kHz) | 0,889 bei 0,97 s | 0,642 | **0,687 bei 1,80 s** | 0,704 bei 7,20; 0,696 bei 3,60 s | **nein** (Takt) |
| Beton 130 (0,6–1,6 kHz) | 0,697 bei 0,97 s | 0,325 | 0,344 bei 1,80 s | 0,341 bei 6,23 s | ja |
| Beton 130 ohne Plattenschicht (2,5–8 kHz) | 0,825 | 0,26 | 0,196 bei 0,48 s | 0,129 bei 3,80 s | ja |
| Beton 130, Platten 0 dB statt 3 (2,5–8 kHz) | – | – | 0,518 bei 2,77 s | 0,551 bei 6,23 s | nein |
| Beton 130, Platten −3 dB (2,5–8 kHz) | – | – | 0,369 bei 0,83 s | 0,378 bei 6,09 s | ja |
| Pflaster 50 (2,5–8 kHz) | 0,987 bei 2,50 s | 0,183 | 0,128 bei 0,36 s | 0,430 bei 5,70; 0,316 bei 6,96 s | ja |
| Pflaster 50, nur Fahrbahn (2,5–8 kHz) | 0,997 bei 1,25 s | – | 0,121 bei 0,38 s | 0,485 bei 5,70; 0,247 bei 6,96 s | ja |

Die Spitzen jenseits von 3 s sind die Längen der beiden Schleifen (jede Seite wiederholt sich exakt mit ihrer Länge;
auf Pflaster trägt die linke Schleife 5,7 s). Auf Beton liegen alle Spitzen auf Vielfachen der Plattenzeit (0,138 s
bei 130 km/h).

### 3.4 Begrenzer beim Reisen (M3) und Spitzen (Plan A, Gesamtlautstärke 1,0)

| Aufnahme | AU-C1 True Peak | AU-R2 True Peak | Spitze vor dem Begrenzer | Begrenzung |
|---|---|---|---|---|
| Beton 130, Spielmix | −4,37 dBTP | −4,38 dBTP | −4,38 dBFS | 0 |
| Beton 170, Spielmix | −1,40 | −2,09 / −2,36 (zwei Läufe) | −2,17 / −2,36 | 0 |
| Beton 200 (57 s), vier Läufe, Stand | −0,71 | −2,00 / −1,86 / −2,14 / −2,64 | −1,56 / −1,57 / −2,11 / −2,58 | **0,44 / 0,43 / 0,08 / 0,08 dB** |
| Beton 200, Zwischenstand 8 dB je Dekade (−1,5 dB) | | −1,72 / −1,86 / −1,98 / −2,12 | −1,35 / −1,70 / −1,90 / −2,15 | 0,65 / 0,30 / 0,10 / 0 dB |
| Beton 200, neue Muster mit dem Pegel von AU-R | | −1,68 / −1,71 | −0,50 / −0,68 | 1,50 / 1,32 dB |
| Pflaster 50, Spielmix | −5,71 | −4,75 | −4,75 | 0 |

Die 0,08 dB der Läufe 3 und 4 sind kein Eingriff: Godots `AudioEffectHardLimiter` lässt nach einem Eingriff 0,05–0,14 dB
Absenkung stehen, bis zum Ende der Aufnahme (gemessen; die Nachmessung sah dasselbe bei `vmax_engine`). Pflaster im
Spielmix liegt mit der Pegeldrift je Seite (±1,5 dB, R1 der Runde davor) höher als bei AU-C1 ohne Drift; ohne Drift
(Plan B) liegt die Schicht bei −8,59 dBTP (AU-C1 −9,02).

### 3.5 Aufprall (M2, M4) – je 60 schwere Unfälle mit 130 km/h Schließgeschwindigkeit

| Partner, Pegel | Begrenzung Median / 90 % / 95 % / höchstens | über 3 dB | True Peak höchstens / Median |
|---|---|---|---|
| Pkw, `hit_heavy` −11,5 (Stand, Seed 777) | 0,27 / 1,68 / 2,14 / 4,05 dB | 1 von 60 | −1,32 / −2,06 dBTP |
| Lkw, `truck.heavy` −11 (Stand, Seed 778) | 0,69 / 2,19 / 2,42 / 3,25 dB | 1 von 60 | −1,63 / −2,00 dBTP |
| Lkw, `truck.heavy` −10 (AU-C1, Seed 778) | 1,24 / 2,81 / 3,02 / 3,41 dB | 4 von 60 | −1,58 / −1,96 dBTP |

Alle True Peaks ≤ −1,0 dBTP (R5). Variante, Pegel (±2 dB) und Einsatz (0–20 ms) jeder Schicht sind zufällig; das
Maximum einzelner Unfälle wächst mit ihrer Zahl, der 95-%-Wert nicht.

### 3.6 Pflaster (M5) – Plan B, 50 km/h, nur Fahrbahn, je Kanal

| | AU-C1 | AU-R (Nachmessung) | AU-R2 |
|---|---|---|---|
| True Peak der Schicht | −9,02 dBTP | −6,34 dBTP | −8,59 dBTP |
| Scheitelfaktor links / rechts | 13,56 / 13,58 dB | 15,2 / 16,6 dB | 13,87 / 13,94 dB |
| lautester Stein gegen AU-C1 links / rechts | – | +1,6 / +3,0 dB | +0,12 / +0,21 dB |
| 99,9-%-Spitzen über dem Effektivwert links / rechts | 11,29 / 11,31 dB | (unverändert) | 11,19 / 11,13 dB |

Ursache: Die rechte Schleife (Seed + 50) hatte zwei Schläge, bei denen alle vier Räder binnen 1–3 ms zusammentrafen;
die Stärke der einzelnen Steine war es nicht (ihr größter Zufallswert lag unter dem von AU-C1). Seed + 64 ist von 40
geprüften der mit den niedrigsten Spitzen.

### 3.7 Rechenzeit auf Beton (M1) – `kr_perf_conc.gd`, km 42, je drei Läufe im Wechsel mit AU-C1

| | Mittel | Median | 95 % | Maximum (einzelne Bilder) |
|---|---|---|---|---|
| AU-C1 | 0,168 / 0,200 / 0,202 ms | 0,152 / 0,155 / 0,138 | 0,215 / 0,230 / 0,193 | 1,3 / 13,2 / 37,2 ms |
| AU-R (Nachmessung) | 0,398 / 0,368 / 0,384 ms | – | 0,59–0,62 | 8,4 / 16,6 / 9,1 ms |
| AU-R2 | 0,288 / 0,269 / 0,341 ms | 0,257 / 0,206 / 0,204 | 0,376 / 0,306 / 0,288 | 4,5 / 30,4 / 46,2 ms |

Sperren: 59–61 in 900 Bildern (das Messskript ruft `update()` zweimal je Bild – also alle 0,25 s statt in jedem
Aufruf). Die Maxima sind die Last der Maschine (AU-C1 ohne jede Sperre bis 37 ms im selben Wechsel). Der Rest von
+0,07–0,14 ms gegenüber AU-C1 sind die eigenen Schleifen und die Pegeldrift je Seite aus der Runde davor (abgeleitet;
auf Asphalt maß die Nachmessung +0,045 ms).

## 4. Hörproben (`<scratch>/v080/deliver/AU-R/`, eine Sammlung)

| Datei | Stand |
|---|---|
| `fahrt_kiel_hamburg_vorher_nachher.mp3` (1:34) | **neu aufgenommen**: AU-C1 – 2 s Stille – AU-R2; Hamburg nachher: Asphalt ab 1:23,7, **Pflaster ab 1:25,8, wieder Asphalt ab 1:32,0** (vorher durchgehend Pflaster ab 0:35,9) |
| `fahrt_kiel_hamburg_spielmix_neu.mp3` (0:46) | **neu aufgenommen** (AU-R2, mit Rennmusik); Hamburg: Pflaster ab 0:37,4, Asphalt ab 0:43,6 |
| `aufprall_abwechslung_neu.mp3` | unverändert (die Aufprall-Klänge und -Pegel sind gleich geblieben) |
| `schnee_neu.mp3`, `koehlbrandbruecke_fugen_vorher_nachher.mp3` | unverändert (nicht betroffen) |

Zu jeder MP3 eine .txt mit Zeitmarken; die beiden neuen nennen oben, was sich in dieser Runde geändert hat.

## 5. Abweichungen und Vertragsfragen

**Abweichungen vom Vorschlag der Nachmessung**
1. **H1** nicht über `match_loop` oder Seeds (beides war schon da bzw. half nicht, 3.2), sondern mit den Fugen von
   AU-C1 in neuer Folge (`slab_strikes`, `slab_order`, `slab_pattern` in `vehicle_loops.py`); die härteste Fuge
   1 dB unter der härtesten von AU-C1 (Spitzen ab 180 km/h 0,4 dB tiefer, Klangfarbe unverändert).
2. **M3** nicht über `slabs.db` 3 → 2 (das hätte auch 130 km/h leiser gemacht), sondern über ein flacheres Gesetz
   oberhalb von 150 km/h (`slabs.high_kmh` 150, `slabs.high_slope_db` 4). `slabs.db` bleibt 3 (Vorgabe).
3. **M5** nicht über eine Obergrenze der Steinstärke (die war nicht die Ursache, 3.6), sondern über einen anderen
   Seed der rechten Seite; dazu deren Angleichung für ihre Tonhöhe (`match_loop(…, pitch)`, nur Pflaster).
4. **M4** keine Änderung: die größere Stichprobe zeigt mit −10 dB einen 95-%-Wert von 3,02 dB.

**Vertragsfragen**
1. **R1 auf Beton (H2, V1)**: Der Grenzwert 0,40 misst exakte Wiederholung, auf Beton aber den gewollten Takt der
   Platten. Entweder gilt er dort ohne Plattenschicht (0,196), oder `slabs.db` sinkt in der nächsten Runde auf −3
   (0,369, hält). Mit dem Pegel 3 (Vorgabe dieser Runde) hält er nicht.
2. **Begrenzer-Kriterien (M2, M3, V3)**: „≤ 3 dB beim schweren Aufprall“ und „≤ 0,5 dB beim Reisen“ sind Maxima von
   Zufallsgrößen. Vorschlag: Aufprall als 95-%-Wert über 60 Unfälle (Stand 2,14 / 2,42 dB), Reisen als höchster
   Wert je Lauf über mindestens vier Läufe von 60 s (Stand höchstens 0,44 dB).

## 6. Für die nächste Runde (nicht in dieser)

- Plattenpegel `slabs.db` 3 → −3 (löst H2, gibt M3 Luft), Pflaster `surface_db` 19 → 12
- jede Seite wiederholt sich weiter exakt mit ihrer Schleifenlänge (Pflaster nur Fahrbahn 0,485 bei 5,7 s, außerhalb
  des Fensters) – Ereignis-Texturen könnten von zufälligen Stellen lesen
- die Angleichung für die Tonhöhe der rechten Seite auch für die übrigen Paare (bisher nur Pflaster nötig)
- aus der Runde davor: Glas in Körnern, mehrere Stimmen beim Quietschen, Leitplanke und Lkw-Schlag kürzer, die Spitze
  des Reifenhohlraums, das Klacken auf kleinen Lautsprechern, die Mischung für Handgeräte, die Vorschläge zur
  Musikmischung (Knopf `low_shelf_db` steht auf 0)

## 7. Gates

| Gate | Ergebnis | Beleg |
|---|---|---|
| `audio_qc.py --folders vehicle,sfx --determinism` | **grün**: „59 Klänge geprüft, 0 mit Fehlern“; Nähte, Pegel, Spitzen, Manifest; `engine_synth3`, `make_placeholders`, `sfx_modern`, `vehicle_loops` je zweimal gleich und gleich den eingecheckten Dateien | `pruefung_qc_determinismus.txt` |
| `audio_qc.py` alle Ordner | **grün**: 98 Klänge, 0 Fehler; Klänge 19,000 von 23 MB, Musik 18,539 von 25 MB | `pruefung_qc_alle.txt` |
| Klangfarbe der geänderten Schichten | **in den Grenzen** (Abschnitt 3.1): höchstens 0,56 dB je Terz, 0,17 LU | |
| eingefrorene Arcade-Dateien = v0.7.0 | **0 geänderte Dateien** (`git diff v0.7.0..HEAD` über die Pfade von Regel 1); diese Runde ändert nur `scripts/audio/modern/road_audio.gd`, `tools/audio/modern/vehicle_loops.py`, drei Dateien in `assets/audio/modern/vehicle/` mit Manifest, `audio.modern.road.slabs` (+ Beschreibung) in `config/game_config.json`, `tests/unit/audio_modern/test_road_audio.gd`, `docs/audio-modern.md` | |
| `check_arcade_lean` | **OK**: „0 von 35 Skripten des Modern-Klangs …“ (im Testlauf) | `pruefung_run_tests.txt` |
| `tools/run_tests.sh` (einmal, am Ende) | **grün**: „653 Tests, 0 fehlgeschlagen“, alle CHECK-Zeilen OK, „Tests bestanden (608 s)“ | `pruefung_run_tests.txt` |
| `tools/golden.sh check` (einmal) | **grün**: „GOLDEN arcade: 20 von 20 identisch (184 s)“ | `pruefung_golden.txt` |

## 8. Ehrliches Urteil

- **Was die Messungen sagen**: Die Plattenschicht hat wieder die Klangfarbe von AU-C1 (+0,55 statt +1,75 dB je
  Terz), die Ausreißer auf dem Pflaster sind weg (lautester Stein +0,2 statt +3 dB), der Klang wartet auf Beton nicht
  mehr in jedem Bild auf den Mischer, und der Begrenzer bleibt beim Reisen mit 200 km/h auf Beton in vier Läufen
  unter 0,5 dB. Die Aufprall-Pegel halten die 3 dB als 95-%-Wert über 60 Unfälle.
- **Was nicht erreicht ist**: Beton wiederholt sich im Takt der Platten (0,687) – das hält der Grenzwert nur ohne
  Plattenschicht oder mit leiseren Platten (Vertragsfrage). Bei 200 km/h auf Beton liegen zwei von vier Läufen mit
  0,43–0,44 dB knapp unter der Grenze; ein einzelner Unfall kann den Begrenzer bis 4 dB treiben (1 von 60).
- **Was ein Ohr prüfen muss**: ob die Platten auf Beton wie in der ersten Hörprobe klingen; ob sie bei 170 km/h mit
  knapp 1 dB weniger noch präsent genug sind; ob auf dem Hamburger Pflaster kein Stein mehr heraussticht.
- **Gehört hat es hier niemand.** Das Urteil liegt bei dir – die Hörproben stehen im Ordner von AU-R.
