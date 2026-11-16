# KRITIK-R – Nachmessung der Klang-Überarbeitung AU-R (Klangprofil „Modern“)

**Prüfgegenstand:** AU-R-Kopf `3d2e6e1` (`origin/wip/v080-au-r`) gegen den Stand von AU-C1 `4209268` („vorher“).
**Rolle:** unabhängige Nachmessung, nur lesend – keine Commits, kein Zweig; der Arbeitsbaum von AU-R blieb unberührt
(`git status` leer, Kopf `3d2e6e1`). Gemessen in zwei Kopien im Arbeitsordner (`after` = Kopie des AU-R-Arbeitsbaums,
`before` = `git archive 4209268`), beide mit dem `.godot` des Hauptbaums einmal importiert; jeder Lauf mit absolutem
`XDG_DATA_HOME`, `nice -n 19`, ein schwerer Lauf nach dem anderen. **Beide Stände mit denselben Skripten**: die
Werkzeuge der ersten Prüfungen (KRITIK-FAHRBAHN `trigger_log.gd`, `perf_auc1.gd`, `dsp.py`, `ana_trigger.py`; AU-C1
`worst_case.gd`) und eigene, die auf beiden Ständen laufen (Abschnitt 9).

**Gehört hat hier niemand.** *gemessen* = Zahl aus einer Aufnahme des laufenden Spiels (Godot 4.7.2 ohne Bildschirm,
Dummy-Audiotreiber, Limousine, belastete Entwicklungsmaschine) oder aus den Dateien. *abgeleitet* = aus Code,
Konfiguration oder einem Modell geschlossen – dazu gehört **jede** Aussage darüber, wie etwas klingt, ob man es hört
und wie es sich auf dem Steam Deck verhält. Ob der Klang gut ist, entscheidet der Nutzer.

---------------------------------------------------------------------------------------------------------------------

## 0. Kurzfassung

1. **Die gemessenen Fehler sind behoben** (gemessen, eigene Aufnahmen): kein exaktes Wiederholen der Rauschschleifen
   mehr (Asphalt 130: Hüllkurven-Korrelation 0,635 → 0,098; Pflaster 50: 0,985 → 0,183), jede Altstadt zu 55–64 %
   gepflastert (vorher 29 ganz, 18 nie), 14 von 17 Ländern im Betonanteil (vorher 5), Plattenmuster im Gleichschritt
   (Versatz im Ton 45 ms → 0–4 ms), Fugen je Deck (Köhlbrandbrücke 12 → 4, Steinbogen 6 → 0), keine Rüttellinie neben
   der Tankspur (8 → 0 Bilder), Wind im Tunnel nicht mehr leiser, alle True-Peak-Ziele bei Gesamtlautstärke 1,0
   erreicht (schwerer Aufprall −0,66 → −1,75 dBTP, schlimmster Fall −0,25 → −1,43), je vier Varianten für Glas,
   Kleinteile und Lkw-Schlag in der Klangfarbe der alten Datei (≤ 0,63 dB je Terz), zufällige Auswahl, Glas-,
   Quietsch- und Schnee-Regeln wie bestellt. Motor- und Musikdateien byte-gleich, Arcade unberührt, alle 26
   Ogg-Schleifen spielen im Spiel abtastgenau.
2. **Klangfarbe gehalten – mit einer Ausnahme:** Reifen, Wind, Nässe, Schotter, Gras, Deck, Rüttelstreifen und die
   Spielmixe liegen in den Grenzen (größte Terz-Abweichung 0,77 dB, Lautheit ≤ 0,30 LU). **Die neue Plattenschicht
   (32 Platten) ist im Mittenbereich lauter: +1,8 dB bei 400 Hz, +1,7 bei 500, +1,2 bei 630 Hz** (Grenze ±1 dB) – im
   Beton-Fahrbahnklang noch +1,1 dB bei 400 Hz (Befund H1).
3. **Ein Ziel verfehlt, wie AU-R selbst meldet:** Beton 130 km/h hat weiter eine Hüllkurven-Korrelation von **0,642**
   (Ziel < 0,40). Das ist der gewollte Takt der Platten (eine Fuge alle 5 m), nicht mehr eine Schleife – ohne
   Plattenschicht 0,26. Ziel und „`slabs.db` bleibt 3“ widersprechen sich (Vertragsfrage V1, Befund H2).
4. **Neu und nicht bestellt (gemessen):** Auf Beton nimmt der Klang jetzt **jedes Bild** die Sperre des Audioservers
   (`AudioServer.lock()`): Die GDScript-Zeit von `road` steigt dort von 0,17–0,20 auf 0,37–0,40 ms im Mittel,
   95 %-Wert 0,22–0,26 → 0,59–0,62 ms, einzelne Bilder 8–17 ms (vorher 0,7–6 ms; je 3 Läufe). Abhilfe ist einfach
   (Sperre nur beim Starten einer Plattenschleife, Befund M1).
5. **Knapp an den Grenzen (gemessen, Zufallsgrößen):** Begrenzung bei schweren Unfällen höchstens **2,97 / 3,00 dB**
   (Pkw / Lkw, Grenze 3 dB); beim Reisen mit 200 km/h auf Beton **0,44 dB** (Grenze 0,5 – AU-R maß in seinem Lauf
   0,96). Die Senkung des Lkw-Schlags um 1 dB ist durch meine Messung **nicht** gedeckt (mit dem alten Pegel 2,66 dB
   Begrenzung, also unter 3 dB; Befund M4). Pflaster: einzelne lauteste Steine +1,6 / +3,0 dB über dem bisherigen
   Höchstwert, sie kehren mit der Schleifenlänge (5,7 / 7,0 s) wieder (Befund M5).
6. **Gates:** `audio_qc.py` grün (98 Klänge, 0 Fehler, Größen 19,0 von 23 MB; Determinismus der vier
   Klang-Generatoren und von `linke_spur.py` gleich), `check_arcade_lean` OK, eingefrorene Dateien gleich v0.7.0,
   `tools/run_tests.sh` grün (652 Tests, 0 fehlgeschlagen, alle CHECK-Blöcke OK, 645 s), `tools/golden.sh check`:
   „GOLDEN arcade: 20 von 20 identisch“.
7. **Urteil:** Der Auftrag ist bis auf H1 (Plattenschicht in der Klangfarbe), den Takt auf Beton (H2, Vertragsfrage)
   und die Sperre je Bild (M1) erfüllt; nichts davon ist nach meinen Messungen ein hörbarer Fehler im Sinne eines
   Knackens oder Pumpens – ob man die +1,5 dB im Plattenklang oder die lautesten Pflastersteine hört, ist **abgeleitet
   unsicher** und muss der Nutzer entscheiden.

---------------------------------------------------------------------------------------------------------------------

## 1. Messaufbau und Lesart

- **Messpunkt (gemessen, eigene Probe `vol_probe.gd`):** Ein `AudioEffectRecord` am Ende von `Master` nimmt **vor** der
  Lautstärke von `Master` auf (Sinus: gleicher Pegel bei 0 dB und bei −20 dB Master-Lautstärke). Jede Master-Aufnahme
  ist also der Klang bei **Gesamtlautstärke 1,0**; bei der Voreinstellung 0,8 ist er 1,94 dB leiser. True Peak
  4-fach überabgetastet (`qc_lib.true_peak_db`), Lautheit nach BS.1770 (`qc_lib`), Schreibweise „@0,8“ / „@1,0“.
- **Begrenzung:** zwei `AudioEffectCapture` auf `MMaster` – direkt hinter dem Summenkompressor (vor dem neuen
  Begrenzer) und am Busende; Begrenzung = Spitze davor / Spitze danach je 10-ms-Block, nach Ausgleich der
  Verzögerung des Begrenzers (90 Frames, gemessen). Rauschgrund des Verfahrens ≈ 0,15 dB.
- **Fahrten (`kr_capture.gd`, Fahrmodell wie KRITIK-FAHRBAHN `const_capture.gd`):** feste Tempi auf der echten Strecke
  Kiel – Hamburg mit Feed; Belag auf beiden Ständen gleich erzwungen (Anteil 0 bzw. 1): Asphalt km 15, Beton km 42,
  Pflaster km 87,3 (Hamburg), je 20 s. **Plan A** „wie gespielt“ (Drift, Böen, Vorbeifahrten an), **Plan B**
  „Klangfarbe“ (Drift, Böen, Vorbeifahrten aus – sonst würfelt jeder Lauf andere Pegel), dazu Schnee, Tunnel.
- **Streuung (gemessen):** Der Motor ist byte-gleich und lag zwischen zwei 20-s-Läufen trotzdem 0,3–0,4 LU auseinander
  (130 km/h: −16,88 / −17,26 LUFS@0,8). Unterschiede im ganzen Spielmix unter ±0,4 LU sind Rauschen. Mit Drift und
  Böen schwankt das 20-s-Mittel einer Schicht um ±0,3–0,5 dB (abgeleitet; gemessen: Asphalt nur Fahrbahn +0,50,
  Wind +1,03 LU in Plan A, +0,17 / +0,04 LU in Plan B) – Klangfarbe deshalb aus Plan B.
- **Wiederholung:** Hüllkurven-Autokorrelation wie KRITIK-FAHRBAHN (`dsp.env_autocorr`: 10-ms-RMS der Monosumme im
  Band, logarithmisch, ohne Mittelwert), jede lokale Spitze 0,3–8 s.

---------------------------------------------------------------------------------------------------------------------

## 2. Die Ziele des Auftrags – vorher → nachher (gemessen)

### 2.1 R1 Wiederholung (Spielmix, Limousine, Kiel – Hamburg, 20 s festes Tempo)

Ziel: keine Spitze ≥ 0,40 bei 0,3–3 s; berichtet: alle Spitzen ≥ 0,10 bis 8 s.

| Aufnahme (Band) | vorher: Spitzen 0,3–3 s | nachher: Spitzen 0,3–3 s | nachher: Spitzen 3–8 s | Ziel |
|---|---|---|---|---|
| **Asphalt 130** (0,6–1,6 kHz) | 0,635 bei 0,97 s; 0,595 bei 2,92; 0,473 bei 1,94 | keine ≥ 0,10 (größter Wert 0,098) | 0,142 bei 5,15; 0,139 bei 6,39 (die zwei Schleifen) | **erfüllt** |
| Asphalt 130 (2,5–8 kHz) | 0,370 bei 0,97 | 0,150 bei 0,42 | 0,154 bei 6,39; 0,147 bei 5,15 | erfüllt |
| **Beton 130** (2,5–8 kHz) | 0,889 bei 0,97; 0,800 bei 1,94; 0,748 bei 0,83 | **0,642 bei 1,80**; 0,639 bei 2,63; 0,604 bei 2,77; 0,591 bei 1,94; 0,580 bei 0,83 | 0,678 bei 4,43 (= 32 Platten); 0,648 bei 4,57; 0,611 bei 6,23; 0,608 bei 6,37; 0,594 bei 3,60 | **verfehlt** |
| Beton 130 (0,6–1,6 kHz) | 0,705 bei 0,97 | 0,325 bei 2,63 | 0,343 bei 4,43 | erfüllt |
| Beton 130 **ohne Plattenschicht** (2,5–8 kHz) | 0,833 bei 0,97 | 0,26 bei 1,40 (Leitpfosten alle 50 m = 1,38 s) | 0,122 bei 3,03 | erfüllt |
| **Pflaster 50** (2,5–8 kHz) | 0,985 bei 2,50; 0,984 bei 1,25 | 0,183 bei 0,54; 0,166 bei 0,35 | 0,328 bei 5,70; 0,294 bei 6,96 | **erfüllt** |
| Pflaster 50 (0,6–1,6 kHz / breitbandig) | 0,721 / 0,238 | 0,198 / 0,131 | 0,160 / 0,101 | erfüllt |
| Asphalt 200 (0,6–1,6 kHz) | 0,577 bei 2,51 | 0,107 bei 1,20 | 0,134 bei 5,49 | erfüllt |
| nur Fahrbahn: Asphalt 130 / Beton 130 / Pflaster 50 | 0,814 / 0,913 / 0,999 | 0,181 / 0,679 / 0,103 | 0,202 / 0,706 / **0,478 bei 5,70**, 0,339 bei 6,96 | – |
| nur Wind 130 (2,5–8 kHz) | 0,716 | 0,243 | 0,158 bei 4,54 | – |

Je Kanal (Kopfhörer), Asphalt 130, 0,6–1,6 kHz nachher: L 0,213, R 0,123. AU-R maß 0,603 → 0,111 / 0,887 → 0,647 /
0,982 → 0,146 – meine Werte bestätigen das auf ±0,04.
Lesart (gemessen): Die **exakte Wiederholung der Rauschschleifen ist weg** – vorher bestand das Modulationsspektrum
der Hüllkurve aus Linien 29–40 dB über dem Grund (die Spur einer exakt periodischen Hüllkurve), nachher ist es
durchgehend (Linien ≤ 12 dB). Auf **Beton** liegen alle Spitzen auf Vielfachen der Plattenzeit (0,138 s bei
130 km/h: 0,83 s = 6, 1,80 s = 13, 4,43 s = 32 Platten). Das ist der Takt der Plattenschläge, nicht eine Schleife –
ohne sie 0,26. Auf **Pflaster** bleibt eine exakte Wiederholung jenseits des Zielbereichs (0,478 bei 5,70 s, nur
Fahrbahn), getragen von einzelnen lauten Steinen (Befund M5).

### 2.2 R2 Hash und Anteile

`kr_shares.gd`: Der **Feed selbst** entscheidet (seine `_concrete_section()` / `_cobbled()` mit der Konfiguration
des Standes), entlang jeder sichtbaren Etappe alle 50 m (Beton: Autobahn außerhalb der Stadtgrenzen, nicht im
Tunnel, nicht auf Stahl- oder Steindeck – so, wie der Spieler es hört) und in der Altstadt alle 5 m; jede Etappe
einmal. Gegenrichtung: `kr_dirs.gd` – auf beiden Ständen in 64 Etappen dieselben Abschnitts-Schlüssel und 0
abweichende Entscheidungen.

| | vorher | nachher | Ziel |
|---|---|---|---|
| Altstädte im Anteil 0,6 ± 0,05 | 0 von 47 (29 immer, 18 nie gepflastert) | **47 von 47** (0,55–0,64; keine immer, keine nie) | ±0,05 |
| Pflaster im Mittel der Altstädte | 0,61 | 0,563 | 0,6 |
| Hamburg / Paris (Blöcke ab Altstadtbeginn, P = Pflaster) | `PPPPPPPPP` / `------------` | `P--PP-P-P` (0,55) / `P--PPPPP-P-P` (0,64) | – |
| Länder im Betonanteil ± 0,05 | 5 von 17 | **14 von 17** | ±0,05 |
| Beton gesamt, km-gewichtet | 0,242 | 0,200 | 0,205 |

| Land | DE | FR | ES | PL | RS | HU | RO | CZ | BE | CH | IT | NL | AT | HR | SI | LT | BG |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Autobahn-km | 3951 | 1992 | 1315 | 760 | 645 | 520 | 490 | 481 | 450 | 439 | 428 | 413 | 374 | 300 | 190 | 145 | 5 |
| Soll | 0,35 | 0,10 | 0,10 | 0,25 | 0,10 | 0,10 | 0,10 | 0,40 | 0,30 | 0,10 | 0,10 | 0,10 | 0,15 | 0,10 | 0,10 | 0,10 | 0,10 |
| vorher | 0,427 | 0,114 | 0,163 | 0,336 | 0 | 0,183 | 0 | 0,450 | 0,511 | 0,137 | 0,117 | 0,036 | 0,131 | 0,067 | 0 | 0 | 0 |
| nachher | 0,347 | 0,103 | 0,091 | 0,230 | 0,062 | 0,135 | 0,102 | 0,395 | 0,322 | 0,057 | 0,082 | 0,061 | 0,118 | 0,150 | **0,211** | **0** | **0** |

SI, LT, BG verfehlen ±0,05 – mit 1–5 Abschnitten geht es nicht genauer (Vertragsfrage V2); LV liegt in Richtung
Riga ganz in der Stadtgrenze (zählt hier nicht, 1 Abschnitt). CH 0,057 und NL 0,061 liegen tiefer als AU-Rs
Kalibrierung (0,096 / 0,103), weil die Kalibrierung Tunnel und Stadtgrenzen mitzählt, in denen der Feed immer Asphalt
spielt – beide noch in ±0,05. Die Lösung geht über „`fmix32` auf `key.hash()`“ hinaus (Schwelle je Land, genaue
Zuteilung je Altstadt) – Abweichung A1 in Abschnitt 7.

### 2.3 R3 Plattentakt und Tunnelwind

`kr_slab.gd`: Beton erzwungen; Reifen, Wind, Vorbeifahrten, Fugen stumm; das langsame Muster bleibt auf `MRoad`, das
schnelle wird auf `MWind` gelegt – beide getrennt aufgenommen, in denselben Mischblöcken. Tempoprofil 90–160 km/h mit
Rampen und zwei Sprüngen über 110 bzw. 150 km/h, 90 s.

| | vorher | nachher |
|---|---|---|
| Versatz der Schläge im Ton (Kreuzkorrelation der Einsatz-Hüllkurven, 0,4-s-Fenster, beide hörbar) | Median **45 ms**, 85 % der Fenster > 10 ms (Suche auf ±60 ms begrenzt) | Median **0 ms**, höchstens **4 ms**, kein Fenster > 10 ms (236 Fenster) |
| Versatz der Abspielpositionen (≈ 4 000 Bilder mit beiden Mustern) | Median 215 ms, bis 438 ms | Median 1,9 ms, 95 % ≤ 3,9 ms, 2 einzelne Bilder 10–11 ms |
| Nachstellungen (`slab_realigned`) | – | 0 |

Vorher Doppelschläge (gemessen: zwei Muster bis 60 ms auseinander), nachher nicht (4 ms Restversatz – abgeleitet: als
ein Schlag hörbar). `slabs.db` 3 unverändert.
**Tunnelwind:** `zone_db.tunnel` −3 → 0. Gemessen auf Lüttich – Paris (Tunnel km 385,0–386,3 innerhalb der
Stadtgrenze, nur Wind, 100 km/h, ohne Böen): vorher im Tunnel **1,8 dB leiser** als davor, nachher **1,0 dB lauter**
(die Stadtzone davor hat −1 dB, der Tunnel jetzt 0 dB).

### 2.4 R4 Brückenfugen und Tankspur (Autopilot über die Etappe)

`trigger_log.gd` von KRITIK-FAHRBAHN unverändert; „vorher“ = deren Läufe auf `4209268`.

| Brücke | Deck, Länge | vorher | nachher (Lage ab Brückenanfang) | Soll |
|---|---|---|---|---|
| Köhlbrandbrücke (Kiel – Hamburg) | Stahl, 261 m | 12 (alle 24 m) | **4** (0, 100, 200, 261 m) | Enden + ~100 m, etwa 4 |
| Elbbrücken (Kiel – Hamburg) | Stahl, 201 m | 9 | **3** (0, 100, 201 m) | dito |
| Damm nach Venedig (Mailand – Venedig) | Beton, 378 m | 17 | **13** (alle 32 m) | alle 32 m |
| Steinbogen vor Paris (Lüttich – Paris) | Stein, 129 m | 6 | **0** | keine |

Keine Fuge abseits einer Brücke. Alle übrigen Feed-Ereignisse (Tunnel, Brückenenden, Dächer, Vorbeifahrten 1 281 → 1 282 – ein Baum an einer
Bildgrenze) sind auf allen vier Etappen gleich häufig; das `ERGEBNIS` jeder Etappe ist gleich (Regel 3).
**Tankspur** (`kr_fuel.gd`, jedes Bild km 13,0–15,2, Autopilot): Rüttellinie rechts bei Tankspur vorher **8 Bilder**,
nachher **0**. Das rechte Rad auf dem Schotter neben der Tankspur (die Physik meldet Bankett) bleibt: 7 → 9 Bilder.

### 2.5 R5 Spitzen und Begrenzer (Gesamtlautstärke 1,0)

| Szene | True Peak vorher | True Peak nachher | Begrenzung nachher | Ziel |
|---|---|---|---|---|
| schwerer Aufprall, 130 km/h Schließgeschwindigkeit, Pkw, 24 Unfälle (eigene Zufallsfolge 777) | −0,66 (Median −0,80) | **−1,75** (Median −2,12) | max **2,97 dB**, Median 0,46 | ≤ −1,0 dBTP; ≤ 3 dB |
| … mit dem Pegel von AU-C1 (`hit_heavy` −9) | – | −1,38 | max **4,02 dB**, Median 1,74; 5 von 24 > 3 dB | (begründet die Senkung) |
| schwerer Aufprall gegen Lkw, 16 Unfälle (778) | −0,57 (−0,90) | **−1,58** (−1,98) | max **3,00 dB**, Median 0,72 | ≤ −1,0; ≤ 3 dB |
| … mit dem Lkw-Pegel von AU-C1 (−10) | – | −1,57 | max **2,66 dB**, Median 0,88 | (begründet die Senkung **nicht**) |
| Höchsttempo 245 km/h, Motor + Fahrbahn + Wind (15 s) | −2,32 | **−1,93** | 0,81 dB, 1 Eingriff | ≤ −1,0 |
| schlimmster Fall von AU-C1 (Szenario unverändert, 14 s) | −0,25 | **−1,43** | Median **4,0 dB**, max 7,5; > 1 dB in 99 % der Zeit (vorher nahm der Arcade-Begrenzer Median 2,8 / max 6,2 dB) | ≤ −1,0 |
| Reisen 130 Asphalt / 130 Beton / 170 Beton / 200 Asphalt (je 20 s) | −8,7 / −4,0 / −1,5 / −6,4 | −7,9 / −4,4 / −1,9 / −6,7 | 0 / 0 / 0,03 / 0 (Rauschgrund) | ≤ 0,5 dB |
| **Reisen 200 Beton (57 s)** | −0,80 | −1,94 | **max 0,44 dB**, 9 Eingriffe (vor dem Begrenzer −1,56 dBFS) | ≤ 0,5 dB |
| Planzeile Höchsttempo, Lautheit @0,8 | −14,94 LUFS | −14,72 LUFS | – | −15 ± 1 |

Der Begrenzer (`AudioEffectHardLimiter`, −2,0 dB, Release 0,12 s) sitzt nur auf `MMaster` hinter dem Kleber;
`Master` behält seinen Arcade-Begrenzer (−0,8 dB). Alle True-Peak-Ziele halten. Die Begrenzung bei schweren
Unfällen liegt **genau an der 3-dB-Grenze** (2,97 / 3,00 dB); sie ist das Maximum einer Zufallsgröße (±2 dB, 0–20 ms,
Variante, Tonhöhe je Schicht) und wächst mit der Zahl der Unfälle (AU-R maß mit anderen Folgen 2,4 / 2,1 dB). Beim
Reisen mit 200 km/h auf Beton liegt sie mit 0,44 dB knapp unter 0,5 dB; AU-R maß 0,96 dB – das Ziel hält also nur in
manchen Läufen (Ursache: die Plattenschläge). Mit dem alten `hit_heavy` −9 nahm der Begrenzer 4,0 dB → dessen Senkung
um 2,5 dB ist vom Auftrag gedeckt; **mit dem alten Lkw-Pegel blieb die Begrenzung bei 2,66 dB** → die Senkung des
Lkw-Schlags um 1 dB ist durch meine Messung nicht gedeckt (M4).

### 2.6 R6 Abwechslung, Tankspur, Schnee

| Prüfung | vorher | nachher | Ziel |
|---|---|---|---|
| Varianten Glas / Kleinteile / Lkw-Schlag | je 1 | je **4**; Variante a = alte Datei nach 20 ms Vorlauf (bitgleich) | ≥ 4 aus demselben Generator |
| Klangfarbe der Varianten gegen die alte Datei (Terzen aus einer FFT über die ganze Datei, gleiche Energie) | – | Glas ≤ 0,24 dB, Kleinteile ≤ 0,44, Lkw-Schlag ≤ 0,63 dB | ±1 dB |
| Pegel der Varianten bei gleicher Spitze (das Spiel stellt nach Spitze ein) | – | −0,80 … +0,73 dB | – |
| Auswahl (24 / 16 Unfälle) | Glas, Kleinteile, Lkw: immer a; Schlag, Blech: strikt a/b im Wechsel | zufällig, bei 4 Varianten nie dieselbe zweimal hintereinander (0 Wiederholungen), alle 4 genutzt | zufällig statt reihum |
| Pegel- und Zeitversatz je Schicht | 0 | ±1,9 dB (Einstellung ±2), 0–19,9 ms später (Einstellung „±10 ms“ = 0–20 ms) | ±2 dB / ±10 ms |
| Glas bei 130 km/h Schließgeschwindigkeit | 24 von 24 | 24 von 24 | ab 80 km/h immer |
| Glas bei 60 km/h, 60 Unfälle | (immer) | **27 von 60 = 0,45** (erwartet 0,40 ± 0,06) | Wahrscheinlichkeit 0,4 |
| Quietschen, 16 Ansätze | Faktor 1,0; Ton 861–863 Hz | Faktor 0,951–1,046; Ton 826–953 Hz (mit dem Vibrato der Schleife, die jetzt an zufälliger Stelle beginnt) | ±5 % je Ereignis |
| Vorbeifahrten | Variante streng a/b im Wechsel, 0 dB | zufällig, ±1,99 dB | zufällig, ±2 dB |
| Rüttellinie rechts neben der Tankspur | 8 Bilder | 0 | keine |
| Schnee | Schotter-Schleife × 0,35 | eigene Schleife: tonale „Pings“ 2,1–5,6 kHz (STFT-Spitze ≥ 15 dB über dem Bandmedian) 0,3–0,6 je s gegen 3,6–4,5 je s beim Schotter; Schwerpunkt 2,4 statt 3,0 kHz, 8 % statt 32 % unter 180 Hz | weiches Knirschen, keine Steinschläge |
| Schnee im Spiel (50 / 90 / 130 km/h, nur Fahrbahn) | – | +0,84 / +1,00 / +0,91 LU; −5 … −6 dB unter 160 Hz, +2 … +4 dB bei 1–2,5 kHz, −2 … −5 dB über 4 kHz | (keine Grenze: noch nicht gehört) |

---------------------------------------------------------------------------------------------------------------------

## 3. Klangcharakter (Grenzen: Terz ±1 dB, Lautheit ±0,5 LU bei den Bezugstempi)

Plan B (ohne Drift, Böen, Vorbeifahrten; deterministisch), 20 s (Sonderbeläge 8–15 s), Terzen 25 Hz–12,5 kHz bis
30 dB unter der lautesten, Lautheit (ungegatet) @1,0:

| Schicht | Lautheit vorher → nachher | größte Terz-Abweichung | Grenzen |
|---|---|---|---|
| Asphalt 130, nur Fahrbahn | −27,81 → −27,64 (+0,17 LU) | +0,54 dB bei 251 Hz | ja |
| Beton 130, nur Fahrbahn (Reifen + Platten) | −22,38 → −22,34 (+0,04) | **+1,09 dB bei 398 Hz** | knapp nein |
| – nur Reifen | −25,30 → −25,24 (+0,06) | +0,44 dB bei 50 Hz | ja |
| – **nur Platten** | −25,49 → −25,43 (+0,06) | **+1,75 dB bei 398 Hz** (+0,9 bei 316, +1,7 bei 501, +1,2 bei 631, −0,8 bei 1 kHz) | **nein** |
| Pflaster 50, nur Fahrbahn | −20,99 → −21,27 (−0,28) | −0,77 dB bei 40 Hz | ja (Einzelspitzen s. u.) |
| Rüttelstreifen 130 | −18,84 → −18,86 (−0,02) | +0,48 dB bei 79 Hz | ja |
| Stahldeck 80 (Köhlbrandbrücke, ohne Fugen) | −31,34 → −31,10 (+0,24) | +0,55 dB bei 40 Hz | ja |
| Nässe 130 | −22,91 → −22,87 (+0,04) | −0,56 dB bei 25 Hz | ja |
| Schotter 100 | −17,80 → −17,75 (+0,05) | +0,77 dB bei 25 Hz | ja |
| Gras 60 | −20,69 → −20,75 (−0,06) | +0,74 dB bei 50 Hz | ja |
| Wind 130 / 200 / Höchsttempo (mit Wummern) | +0,04 / +0,04 / +0,03 LU | −0,33 / +0,71 / −0,54 dB (25 Hz) | ja |
| Spielmix Asphalt 130 / Beton 130 / Pflaster 50 | −0,05 / −0,04 / +0,30 LU | +0,42 / +0,78 / −1,02 dB (40 Hz) | ja / ja / an der Grenze (Motorstreuung 0,3–0,4 LU) |

Weitere Prüfungen der Klangfarbe (gemessen):
- **Plattenschicht** – die einzige Schicht über ±1 dB: Die neuen 32-Platten-Entwürfe sind im Bereich 300–630 Hz um
  0,9–1,8 dB kräftiger als die 8-Platten-Entwürfe von AU-C1, bei gleicher Lautheit (+0,06 LU) und um 0,35 dB höherer
  Spitze. Die Reifenschleifen hat AU-R an den gehörten Klang angeglichen (`match_loop`), die Plattenschleifen nicht.
- **Pflaster – einzelne Spitzen:** gleiche Lautheit und Terzen, aber der lauteste Stein liegt im Spiel 1,6 dB (links)
  bzw. 3,0 dB (rechts) über dem lautesten Stein von AU-C1 (True Peak der Schicht −9,02 → −6,34 dBTP); die 99,9-%-
  und 99-%-Spitzen sind unverändert (12,6–13,4 bzw. 10,4–10,9 dB über dem Effektivwert, vorher 13,2–13,4 / 10,8).
  Diese einzelnen Steine kehren mit der Schleifenlänge wieder (rechts bei 1,76 / 8,72 / 15,68 s = alle 6,96 s).
- **Pfeifton des Winds (3,15 kHz):** in der Langzeit-Messung schwächer (Datei 14,8 → 10,9 / 10,3 dB über dem Umfeld),
  in 0,2-s-Fenstern aber gleich stark (Median 13,6 → 13,6 / 13,2 dB) – die längeren Schleifen wandern nur mehr in der
  Frequenz. Kein Befund.
- **Einmalklänge mit Vorlauf:** Schlag, Blech, leichter Schlag (je a/b) sind nach den 20 ms Vorlauf bitgleich mit
  AU-C1; der Vorlauf ist still.
- **Musik im Spiel:** `audio.modern.music` (Pegel je Kontext, Renn-EQ), `audio.modern.duck` und die Mischzustände
  unverändert (Konfigurationsvergleich: nur die 45 Schlüssel aus Abschnitt 4 geändert).
- **Motor v3 und Musik:** 39 Dateien (`assets/audio/modern/engines`, `…/music`, `assets/audio/music`) byte-gleich;
  `mischung.json`: alle alten Werte gleich, neu `low_shelf_db` 0 / `low_shelf_hz` 120; `music_lib.py` fügt den Filter
  nur bei ≠ 0 ein – der Determinismus-Lauf von `linke_spur.py` mit dem neuen `music_lib.py` erzeugt die
  eingecheckten Dateien bitgleich (gemessen).

---------------------------------------------------------------------------------------------------------------------

## 4. Regressionen

| Prüfung | Ergebnis (gemessen, sofern nicht anders gesagt) |
|---|---|
| neuer reiner Ton | keiner: tonale Spitzen ≥ 12 dB in den Fahrbahn- und Windaufnahmen gleich oder weniger (Pflaster vorher 121 Hz / 14,4 dB, nachher keine; Rüttelstreifen 120/241/361/482 Hz unverändert; Dateien: neue Schleifen ohne neue Töne) |
| Knacken an neuen Nähten | keins: alle 26 Ogg-Schleifen im Spiel abtastgenau – Wiedergabe = mit ffmpeg dekodierte Datei, gekachelt, Rest ≤ 2,4·10⁻⁷ an den Nähten wie anderswo, gespielte Periode = Dateilänge; Sprung an der Naht 0,00–0,54 × des größten Sprungs im Umkreis von 100 ms; `audio_qc` Nähte ×0,02–1,89 |
| Klicks in den Aufnahmen | keine (Detektor: 4-kHz-Hochpass, Spitze 30 dB über dem laufenden Pegel; einziger Treffer = Rand der Aufnahme) |
| „Zipper“ durch die Pegeldrift | keiner: keine Linie bei der Bildrate (55–65 Hz) oder Blockrate im Modulationsspektrum (≤ 10 dB über dem Grund – vorher 29–40 dB-Linien der exakt periodischen Schleifen); Drift wirkt als langsame Modulation 0,1–1 Hz (Anteil 0,2 % → 15 %, gewollt) |
| pumpender Begrenzer | beim Fahren nicht: 130–200 km/h Begrenzung 0–0,44 dB in wenigen Eingriffen; schwerer Aufprall bis 3 dB für Sekundenbruchteile (abgeleitet: unter dem Aufprall-Mischzustand, der Musik/Auto ohnehin 3–5 dB absenkt); **schlimmster Fall** Median 4,0 dB, > 1 dB in 99 % der Zeit – vorher nahm dort der Arcade-Begrenzer Median 2,8 dB (Ursache: Platzhalter von Verkehr und Martinshorn, AU-C2) |
| Auslösung auf vier Etappen | Tunnel, Brückenenden, Zonen, Dächer, Vorbeifahrten gleich; Fugen wie bestellt; Pflaster nur in Altstädten und auf dem Steinbogen; Rüttellinie nur an Autobahnrändern; **neu sichtbar:** Pflaster auf dem Damm nach Venedig (Betonbrücke in der Altstadtzone, 16 von 28 Zeilen) – vorher verdeckte der Hash-Fehler das (L2) |
| Rechenzeit je Bild (`perf_auc1.gd`, km 76 Asphalt) | `road` 0,166 → 0,211 ms (+0,045), Feed 0,067 → 0,075, `impact` gleich |
| Rechenzeit auf Beton (`kr_perf_conc.gd`, km 42, je 3 Läufe) | `road` Mittel 0,165 / 0,197 / 0,172 → **0,398 / 0,368 / 0,384 ms**, 95 % 0,22–0,26 → **0,59–0,62 ms**, Maximum 2,1 / 6,3 / 0,7 → **8,4 / 16,6 / 9,1 ms** (M1) |
| Lecks beim Beenden | keine Meldung „leaked at exit“ / „still in use“ in 40 Spielläufen (beide Stände) |
| Arcade spielt nichts Neues | `check_arcade_lean`: OK (0 von 35 Modern-Skripten geladen); Regel-1-Dateien `v0.7.0..3d2e6e1`: 0; keine Datei außerhalb des AU-R-Bereichs geändert; Konfiguration nur `audio.modern.*` (45 Schlüssel) |
| Speicher/Größe | Modern-Klänge 17,9 → 19,0 MB (Budget 23); Musik 18,5 MB unverändert |

---------------------------------------------------------------------------------------------------------------------

## 5. Gates

| Gate | Ergebnis |
|---|---|
| `audio_qc.py --determinism` | **grün** für alle Klänge: 98 Klänge, 0 Fehler (Nähte, Pegel, Spitzen, Manifest); Größen 19,005 von 23 MB, Musik 18,54 von 25 MB; Determinismus `engine_synth3`, `make_placeholders`, `sfx_modern`, `vehicle_loops` und `linke_spur` je zweimal gleich und gleich den eingecheckten Dateien. Die übrigen Musik-Generatoren habe ich nach 23 min abgebrochen (je 5–8 min, Vorrang der Testversion; ihre Dateien sind byte-gleich, `linke_spur` belegt den unveränderten `music_lib`-Weg). |
| `check_arcade_lean` | OK |
| eingefrorene Arcade-Dateien = v0.7.0 | 0 geänderte Dateien |
| `tools/run_tests.sh` (einmal, auf der Kopie von `3d2e6e1`) | **grün**: „652 Tests, 0 fehlgeschlagen“, 110 CHECK-Zeilen OK, 0 FEHLER, „Tests bestanden (645 s)“ – darin `test_arcade_identity` (eingefrorene Klänge, Motor-Mischer byte-gleich zu v0.7.0), `test_limiter_from_config`, `test_top_speed_row_of_the_plan`, `check_arcade_lean` |
| `tools/golden.sh check` (einmal) | **grün**: „GOLDEN arcade: 20 von 20 identisch (228 s)“ |

---------------------------------------------------------------------------------------------------------------------

## 6. Befunde nach Rang

Schwere nach Auftrag: blocker = Gate verfehlt oder hörbare Regression; hoch = Ziel verfehlt oder Klangfarbe über den
Grenzen; mittel/niedrig = der Rest.

| Nr | Schwere | Befund | Beleg | Korrektur (Datei → Stelle → Wert) |
|---|---|---|---|---|
| H1 | hoch | Plattenschicht in der Klangfarbe über der Grenze: +1,8 dB bei 398 Hz, +1,7 bei 501, +1,2 bei 631 Hz (Grenze ±1); im Beton-Fahrbahnklang +1,09 dB bei 398 Hz | gemessen, Plan B (`c_conc130_slab`, `c_conc130_road`), 20 s, deterministisch | `tools/audio/modern/vehicle_loops.py` → `slab_loop()`-Entwürfe wie die Reifen mit `match_loop()` an AU-C1s `slab_slow`/`slab_fast` angleichen (oder Seeds mit ≤ 1 dB wählen), neu erzeugen, Plan B wiederholen |
| H2 | hoch (Vertragsfrage V1) | R1 auf Beton verfehlt: 0,642 bei 1,80 s (2,5–8 kHz) – der Takt der Plattenschläge, ohne Plattenschicht 0,26 | gemessen, Plan A | Entscheidung Leitung: R1 auf Beton ohne Plattenschicht messen; oder nächste Runde `audio.modern.road.slabs.db` 3 → −3 (KRITIK-FAHRBAHN B4) |
| M1 | mittel | `AudioServer.lock()` in jedem Bild auf Beton: `road` 0,17–0,20 → 0,37–0,40 ms, 95 % 0,22–0,26 → 0,59–0,62 ms, einzelne Bilder bis 8–17 ms (vorher bis 0,7–6 ms); der Hauptfaden wartet auf den Mischer (gemessen) und der Mischer auf den Hauptfaden, solange dieser sperrt (abgeleitet) | gemessen, `kr_perf_conc.gd`, 3 Läufe je Stand; Deck: abgeleitet kürzere, aber gleich häufige Wartezeiten | `scripts/audio/modern/road_audio.gd` → `_update_slabs()`: sperren nur, wenn ein Plattenspieler gleich startet (nicht spielt und Ziel > `SILENT`) oder beim 0,5-s-Abgleich; sonst ohne Sperre |
| M2 | mittel | Begrenzung bei schweren Unfällen genau an 3 dB: Pkw max 2,97 dB (24), Lkw 3,00 dB (16) – ein Maximum, das mit der Zahl der Unfälle wächst | gemessen, eigene Zufallsfolgen | Vertragsfrage V3 (Kriterium als 95-%-Wert über eine feste Zahl Unfälle); bei Überschreiten im 95-%-Wert nur die lauteste Schicht weiter senken (Auftrag R5) |
| M3 | mittel | Reisen 200 km/h auf Beton: 0,44 dB Begrenzung (Grenze 0,5) in meinem Lauf, 0,96 dB in AU-Rs – hält nur in manchen Läufen | gemessen, 57 s; vor dem Begrenzer −1,56 dBFS | `audio.modern.road.slabs.db` 3 → 2 oder tiefer (je dB Plattenpegel −1 dB Plattenspitze, abgeleitet); löst mit H2 zusammen |
| M4 | mittel | Lkw-Schlag (schwer) um 1 dB gesenkt, ohne dass die 3-dB-Regel es verlangt: mit dem alten Pegel −10 blieb die Begrenzung bei 2,66 dB | gemessen, 16 Unfälle mit dem neuen Begrenzer | `audio.modern.impact.collision.truck.heavy` −11 → −10, außer eine größere Stichprobe (≥ 50 Unfälle) zeigt > 3 dB im 95-%-Wert |
| M5 | mittel | Pflaster: einzelne Steine 1,6 / 3,0 dB lauter als der lauteste von AU-C1; sie kehren alle 5,7 / 6,96 s wieder (Hüllkurve nur Fahrbahn 0,478 bei 5,70 s) – Terzen und Lautheit in den Grenzen | gemessen (Plan A/B, Einzelspitzen je Kanal); hörbar als wiederkehrender „Ausreißer“: abgeleitet, unsicher | `vehicle_loops.py` → Pflaster-Generator: Schlagstärken auf das Maximum von AU-C1 begrenzen (lauteste Ereignisse kappen) und neu erzeugen; für Ereignistexturen zufällige Leseposition (Auftrag R1 erlaubt es) |
| L1 | niedrig (Vertragsfrage V2) | Betonanteil SI 0,211, LT 0, BG 0 (und LV) außerhalb ±0,05 – 1–5 Abschnitte | gemessen | Vertrag: ±0,05 nur für Länder mit ≥ 10 Abschnitten |
| L2 | niedrig | Pflaster auf dem Damm nach Venedig (Betonbrücke in der Altstadtzone: 16 von 28 Zeilen), dazu Betonfugen alle 32 m – real Asphalt; vorher vom Hash-Fehler verdeckt | gemessen (Triggerlog) | `scripts/audio/modern/audio_feed.gd` → `_paving()`: auf Brücken mit Deck ≠ `stone` kein Altstadtpflaster |
| L3 | niedrig | schlimmster Fall: Begrenzung Median 4,0 dB, > 1 dB in 99 % der Zeit (vorher 2,8 dB durch den Arcade-Begrenzer) | gemessen | AU-C2: Platzhalter von Verkehr und Martinshorn −4 dB (KRITIK-FAHRBAHN 2.6.4) |
| L4 | niedrig | Höchsttempo: der Begrenzer greift kurz ein (0,81 dB, 1-mal in 14 s); True Peak −1,93 hält | gemessen | – (gehört nicht zum Reise-Ziel) |
| L5 | niedrig | Kollisionsschichten setzen im Mittel 10 ms später ein (0–20 ms statt ±10 ms) | Code, gemessen 0–19,9 ms | – (abgeleitet unhörbar) |

---------------------------------------------------------------------------------------------------------------------

## 7. Abweichungen von AU-R gegenüber dem Auftrag (beobachtet) und Vertragsfragen

**Abweichungen (alle von AU-R selbst genannt, hier nachgemessen):**
- A1 R2 über `fmix32` hinaus: genaue Zuteilung je Altstadt (`cobbled_blocks`) und kalibrierte Hash-Schwelle je Land
  (`concrete_threshold`, `calibrate_concrete.gd`). Wirkt (gemessen), ist aber an die Etappenliste und den Anteil
  gebunden – neue Etappen brauchen einen neuen Lauf des Werkzeugs (ein Test meldet geänderte Anteile).
- A2 zwei Schichten gesenkt: `hit_heavy` −2,5 dB (gedeckt: 4,02 dB Begrenzung mit altem Pegel), Lkw-Schlag −1 dB
  (nicht gedeckt: 2,66 dB) – M4.
- A3 „±10 ms“ als 0–20 ms später – L5.
- A4 Plattenabgleich mit 6 ms Toleranz – wirkt (0 Nachstellungen, ≤ 4 ms im Ton), aber mit Sperre in jedem Bild – M1.
- A5 `tools/audio/qc/audio_qc.py` geändert (Ogg für Fahrzeugschleifen) – außerhalb der eigenen Dateien.

**Vertragsfragen:**
- V1 R1 („keine Spitze ≥ 0,40 bei 0,3–3 s“) passt nicht zu einem gewollt regelmäßigen Takt (Platten alle 5 m) bei
  `slabs.db` 3; Vorschlag: R1 für Beton ohne Plattenschicht messen (0,26) oder die Plattenschicht leiser.
- V2 ±0,05 je Land ist für Länder mit 1–5 Abschnitten nicht erreichbar (SI, LT, BG, LV).
- V3 „Begrenzung ≤ 3 dB beim schweren Aufprall“ und „≤ 0,5 dB beim Reisen“ sind Maxima von Zufallsgrößen; ohne Zahl
  der Unfälle / Messdauer und Perzentil nicht prüfbar (gemessen 2,97 / 3,00 dB und 0,44 dB, AU-R 2,4 / 2,1 und 0,96).
- V4 Messpunkt: Aufnahmen am `Master` liegen vor dessen Lautstärke (= Gesamtlautstärke 1,0); Pegelplan-Zahlen „bei
  Standardreglern“ sind 1,94 dB tiefer. KRITIK-FAHRBAHN, AU-R und dieser Bericht rechnen das richtig um; neue
  Werkzeuge sollten es im Kopf nennen.

---------------------------------------------------------------------------------------------------------------------

## 8. Was ein Mensch hören muss (Kopfhörer und Steam-Deck-Lautsprecher)

1. Beton 130–170 km/h: Klingt das „ta-tock“ der Platten voller/dumpfer als in der ersten Hörprobe (H1, +1,5 dB um
   400–600 Hz)? Stört der Takt nach 30 s (H2)?
2. Hamburger Altstadt mit 50 km/h: Fällt ein einzelner lauter Stein auf, der alle 6–7 s wiederkommt (M5)?
3. Asphalt 130 km/h, 30 s: Ist das „Pochen im Sekundentakt“ weg, und wirkt die langsame Pegeldrift je Seite natürlich?
4. Schwerer Aufprall gegen einen Lkw: genug Wucht mit −1 dB Lkw-Schlag (M4)? Pkw mit −2,5 dB tiefem Schlag?
5. Schnee (neu, noch nie gehört): Knirschen statt Schotter – und ist es 1 LU lauter als vorher zu laut?

---------------------------------------------------------------------------------------------------------------------

## 9. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R/`:
`tools/` – `kr_capture.gd` (+ `plan_a.json`, `plan_b.json`, `plan_t.json`), `kr_crash.gd`, `kr_slab.gd`,
`kr_shares.gd`, `kr_dirs.gd`, `kr_fuel.gd`, `kr_worst.gd` (AU-C1-Szenario, Aufnahme bei 1,0), `kr_seam.gd`,
`kr_perf_conc.gd`, `vol_probe.gd`; Auswertung `dsp.py` (KRITIK-FAHRBAHN), `ana_cap.py`, `ana_compare.py`,
`ana_mod.py`, `ana_crash.py`, `ana_slab.py`, `ana_shares.py`, `ana_seam.py`, `ana_files.py`, `ana_files2.py`,
`ana_trigger.py` (KRITIK-FAHRBAHN); Abläufe `batch1.sh`–`batch4.sh`, `gates.sh`. Ergebnisse `res/*.json`
(u. a. `compare.json`, `crash_*.json`, `slab_*.json`, `shares.json`, `seam_after.json`, `files2.json`,
`worst_*.json`), Protokolle `logs/` (u. a. `compare.txt`, `trigana_*`, `qc_after.log`, `run_tests.log`,
`golden.log`). Die Kopien der Arbeitsbäume und die Aufnahmen sind nach dem Bericht gelöscht (Platz).
