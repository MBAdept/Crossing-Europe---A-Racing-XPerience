## 2. R1 nach V1 – keine exakte Wiederholung (Plan A, wie gespielt)

Plan A = wie Plan B, aber **mit** Pegeldrift je Seite, Böen und Vorbeifahrten (so, wie der Spieler es hört), 20 s je
Aufnahme, zwei eigene Zufallsfolgen (7301, 7401) auf dem Endstand, eine auf AU-C1. Hüllkurven-Autokorrelation wie in
allen Runden (`dsp.env_autocorr`: 10-ms-RMS der Monosumme im Band, logarithmisch, ohne Mittelwert), größter Wert im
Fenster 0,3–3 s (auch wenn er am Fensterrand liegt – strenger als „Spitze“) und die Spitzen bis 8 s.

| Aufnahme (Band) | AU-C1 größte 0,3–3 s | Endstand Seed 7301 | Endstand Seed 7401 | Endstand: Spitzen 3–8 s (7301) | L / R (7301) | V1 < 0,40 |
|---|---|---|---|---|---|---|
| **Asphalt 130, Spielmix** (600–1600 Hz) | 0,637 bei 0,97 s | 0,137 bei 0,30 s | 0,230 bei 0,32 s | 0,125 bei 5,15 s; 0,093 bei 3,58 s | 0,133 / 0,249 | **ja** |
| **Pflaster 50, Spielmix** (2,5–8 kHz) | 0,985 bei 1,25 s | 0,098 bei 0,48 s | 0,179 bei 0,36 s | **0,448 bei 5,70 s; 0,359 bei 6,96 s** | 0,149 / 0,087 | **ja** |
| **Beton 130 ohne Plattenschicht, Spielmix** (2,5–8 kHz) | 0,815 bei 0,97 s | 0,151 bei 0,30 s | 0,239 bei 0,30 s | 0,200 bei 4,96 s; 0,178 bei 6,01 s | 0,186 / 0,236 | **ja** |
| Beton 130 mit Platten, Spielmix (zur Kenntnis, 2,5–8 kHz) | 0,891 bei 0,97 s | 0,714 bei 0,83 s | 0,710 bei 1,80 s | 0,694 bei 6,23 s; 0,682 bei 7,20 s | 0,631 / 0,593 | – (Takt gewollt) |
| Asphalt 130, nur Fahrbahn (zur Kenntnis, 600–1600 Hz) | 0,812 bei 0,97 s | 0,353 bei 0,30 s | 0,228 bei 0,32 s | 0,222 bei 6,39 s | 0,351 / 0,339 | – |
| Pflaster 50, nur Fahrbahn (zur Kenntnis, 2,5–8 kHz) | 0,998 bei 1,25 s | 0,121 bei 0,62 s | 0,166 bei 0,49 s | 0,432 bei 5,70 s; 0,372 bei 6,96 s | 0,125 / 0,094 | – |
| Beton 130 ohne Platten, nur Fahrbahn (zur Kenntnis, 2,5–8 kHz) | 0,896 bei 0,97 s | 0,326 bei 0,30 s | 0,380 bei 0,33 s | 0,136 bei 6,01 s | 0,435 / 0,222 | – |

Lesart (gemessen): V1 hält in beiden Folgen mit Abstand (höchstens 0,239). AU-C1 wiederholte sich exakt (0,64–0,99
bei 0,97 / 1,25 s). Die höheren Werte der Aufnahmen „nur Fahrbahn“ am Fensteranfang (0,33–0,44 bei 0,30–0,33 s) sind
der Ausläufer der langsamen Pegeldrift je Seite (Ornstein-Uhlenbeck, 0,8 s), keine Wiederholung: Dieselben Schichten
ohne Drift (Plan B) liegen bei 0,061–0,111. Jede Seite wiederholt sich weiter exakt mit ihrer Schleifenlänge
(Pflaster links 5,70 s, rechts 6,96 s: 0,45 / 0,36 im Spielmix) – außerhalb des Fensters von V1, zur Kenntnis.
Mit Platten liegen alle Spitzen auf Vielfachen der Plattenzeit (0,138 s bei 130 km/h: 0,83 s = 6, 1,80 s = 13 Platten)
– der gewollte 5-m-Takt (V1: ohne Plattenschicht beurteilt).

## 3. V3 – Begrenzer und Spitzen (Gesamtlautstärke 1,0)

Begrenzung = Spitze vor dem Begrenzer / Spitze danach je 10-ms-Block, aus zwei `AudioEffectCapture` auf `MMaster`
(hinter dem Summenkompressor und am Busende, Verzögerung des Begrenzers 90 Frames ausgeglichen). Ohne Eingriff misst das Verfahren 0,00 dB; nach einem Eingriff
lässt der Begrenzer bis zum Ende der Aufnahme einen Rest von 0,04 dB stehen (Falle 8 der Doku).

### 3.1 Schwere Unfälle, 130 km/h Schließgeschwindigkeit, je 60 (Limousine mit 110 km/h, Motor + Fahrbahn + Wind)

| Partner, Stand (Zufallsfolge) | n | Begrenzung Median / 90 % / **95 %** / höchstens (dB) | Unfälle > 3 dB | True Peak höchstens / 95 % / Median (dBTP @1,0) | Unfälle > −1,0 dBTP | Spitze vor dem Begrenzer höchstens (dBFS) |
|---|---|---|---|---|---|---|
| Pkw, Endstand, `hit_heavy` −11,5 (9311) | 60 | 0,35 / 1,73 / **2,05** / 4,33 | 1 | **−1,38** / −1,77 / −2,14 | 0 | +2,33 |
| Lkw, Endstand, `truck.heavy` −11 (9312) | 60 | 0,48 / 2,28 / **2,66** / 3,63 | 3 | **−1,21** / −1,69 / −2,00 | 0 | +1,74 |
| Pkw, AU-C1, `hit_heavy` −9 (9311) | 60 | – (kein Modern-Begrenzer) | – | −0,31 / −0,66 / −0,77 | **39** | +1,76 |
| Lkw, AU-C1, `truck.heavy` −10 (9312) | 60 | – | – | −0,29 / −0,62 / −0,85 | **32** | +0,86 |

V3 hält: 95-%-Wert 2,05 / 2,66 dB ≤ 3 dB, jeder der 120 Unfälle ≤ −1,0 dBTP (AU-C1: 71 von 120 darüber). Der
Lkw-Wert hat 0,34 dB Luft (AU-R2 maß mit 778 laut Bericht 2,42 dB); der 95-%-Wert aus 60 Unfällen ist selbst eine
Zufallsgröße. Der einzelne Pkw-Unfall mit 4,33 dB: alle vier Schichten in Variante a, +0,6 / −0,6 / +1,7 / +1,5 dB
gewürfelt und fast gleichzeitig (Schlag 1,4 ms, Blech 17,5 ms) – die Summe lag +2,3 dBFS vor dem Begrenzer.

### 3.2 Reisen (je Lauf 60 s Wanduhr = 57,5–57,9 s Ton; neue Zufallsfolge 7501 ff.)

| Lauf | größte Begrenzung (dB) | Eingriffe > 0,1 dB | Anteil der 10-ms-Blöcke > 0,1 dB | Spitze vor dem Begrenzer (dBFS) | True Peak @1,0 (dBTP) | Lautheit @0,8 (LUFS) |
|---|---|---|---|---|---|---|
| Beton 200, Lauf 1 | 0,00 | 0 | 0 | −2,22 | −2,05 | −16,00 |
| Beton 200, Lauf 2 | 0,00 | 0 | 0 | −2,44 | −2,41 | −16,11 |
| Beton 200, Lauf 3 | 0,00 | 0 | 0 | −2,02 | −1,83 | −16,08 |
| Beton 200, Lauf 4 | **0,22** | 1 | 0,16 % | −1,78 | −1,96 | −16,29 |
| Beton 170 | 0,04 (Rest) | 0 | 0 | −2,02 | −2,06 | −15,23 |
| Asphalt 200 | 0,04 (Rest) | 0 | 0 | −5,32 | −5,28 | −17,93 |
| Höchsttempo 245 km/h, Asphalt (14,2 s) | 0,04 (Rest) | 0 | 0 | −1,97 | −2,01 | −14,54 |
| AU-C1 Beton 200 (58,4 s) | – | – | – | −1,15 | −1,16 | −15,73 |
| AU-C1 Höchsttempo (14,8 s) | – | – | – | −2,37 | −2,39 | −14,89 |

V3 hält: höchstens 0,22 dB in vier Läufen bei 200 km/h auf Beton (Grenze 0,5 dB je Lauf). Die Platten waren in allen
vier Läufen bis in die letzte Sekunde zu hören (Takt 11 Hz im 2,5–8-kHz-Band 11–20 dB über dem Umfeld; erst in der
letzten Sekunde Asphalt). Kein Pumpen: ein einziger Eingriff von 0,22 dB in 230 s Beton-200; 0,04 dB ist der Rest, den
`AudioEffectHardLimiter` nach dem Eingriff des vorigen Laufs stehen lässt (die Spitzen dieser Läufe liegen bei oder unter
der Obergrenze −2,0 dBFS: −2,02 / −5,32 / −1,97 dBFS). Planzeile Höchsttempo (−15 ± 1 LUFS bei 0,8): −14,54 LUFS.

### 3.3 Der schlimmste Fall von AU-C1 (Gran Turismo 230 km/h im Tunnel, Musik, Martinshorn, zwei Lkw, Polizei, zwei schwere Unfälle, harter Leitplankenschlag; 14 s)

| | AU-C1 | Endstand |
|---|---|---|
| True Peak @1,0 | **−0,31 dBTP** | **−1,54 dBTP** (≤ −1,0) |
| Spitze vor dem Modern-Begrenzer | +5,86 dBFS | +5,71 dBFS |
| Begrenzung Median / höchstens | – (Arcade-Begrenzer auf Master) | 4,0 / 7,7 dB, > 1 dB in 98,5 % der Zeit |

Nur der True Peak ist Kriterium (Auftrag); die starke Begrenzung in diesem künstlichen Stapel kommt von den
Platzhaltern für Verkehr und Martinshorn (AU-C2, laut KRITIK-R) und ist kein Befund dieser Runde.
