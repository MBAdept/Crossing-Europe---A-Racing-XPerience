# KRITIK-R2-MESS – Abnahmemessung des Modern-Klangs, Endstand AU-R3 (`b6339ad`)

**Prüfgegenstand:** `b6339ad4fe5d26c14e5ad4912848f32f8eb7cd5e` (`origin/wip/v080-au-r3` = AU-C1 + AU-R + AU-R2 + AU-R3),
verglichen mit AU-C1 `4209268` (der Klang, den der Nutzer auf Kopfhörern gehört hat) und, wo es hilft, mit AU-R
`3d2e6e1`. **Rolle:** unabhängige Abnahmemessung, nur lesend – keine Commits, kein Zweig, kein Arbeitsbaum eines
anderen Pakets berührt. Gemessen in drei Kopien (`git archive` + `.godot` des Hauptbaums, je einmal importiert);
jeder Lauf mit absolutem `XDG_DATA_HOME`, `nice -n 19`, ein schwerer Lauf nach dem anderen (die Maschine war mit
dem Testbuild und einem Modellpaket belastet, Last 5–9).

**Gehört hat hier niemand.** *gemessen* = Zahl aus einer Aufnahme des laufenden Spiels (Godot 4.7.2 ohne Bildschirm,
Dummy-Audiotreiber, Limousine, Kiel – Hamburg) oder aus den Dateien. *abgeleitet* = aus Code, Konfiguration oder einem
Modell geschlossen – dazu gehört jede Aussage darüber, wie etwas klingt, ob man es hört und wie es sich auf dem Steam
Deck verhält. Keine Zahl ist aus einem Bericht übernommen; wo ich eine fremde Zahl nenne, steht „(laut …)“ dabei.
Neue Zufallsfolgen: Fahrten `--seed` 7101–7801 (setzt die beiden Zufallsgeneratoren des Fahrbahn-Slots je Abschnitt neu),
Unfälle 9311 (Pkw) und 9312 (Lkw) – nicht 777/778.
Messpunkt selbst geprüft (`vol_probe.gd`): Ein `AudioEffectRecord` am Ende von `Master` nimmt **vor** dessen Lautstärke
auf (Sinus −15,05 dBFS RMS bei 0 dB und bei −20 dB Master-Lautstärke) – jede Aufnahme am Master ist der Klang bei
Gesamtlautstärke 1,0; bei der Voreinstellung 0,8 ist alles 1,94 dB leiser (in den Tabellen „@0,8“). Die Aufnahmen laufen
in Echtzeit; unter der Last lieferte der Mischer 3–5 % weniger Ton als Wanduhrzeit (20 s → 19,0–19,7 s).
Nicht Teil dieser Messung (zweiter Prüfer): Code, Auslösung, Regressionen außerhalb des Klangs, V2 (Betonanteil je Land).

---------------------------------------------------------------------------------------------------------------------

## 0. Kurzfassung

**Ergebnis: Der Endstand besteht die Abnahmemessung.** Kein Blocker, kein hoher Befund; ein mittlerer (knappe Marge
von V3 beim Lkw) und drei niedrige. Alle Zahlen gemessen auf dieser VM (Godot 4.7.2, Dummy-Treiber, Last 5–9); wie es
klingt, ist abgeleitet – gehört hat hier niemand.

| Prüfung (Rang nach dem, was der Spieler am meisten hört) | AU-C1 → Endstand (gemessen) | Ziel | erfüllt |
|---|---|---|---|
| 1 Charakter, Plan B: Fahrbahnschichten und Spielmixe bei 130 km/h Asphalt/Beton, 50 km/h Pflaster | größte Terz-Abweichung 0,89 dB (Spielmix Pflaster, 32 Hz, Motorstreuung), Schichten allein ≤ 0,53 dB; Lautheit ≤ 0,29 LU | ±1 dB, ±0,5 LU | ja |
| 1 Plattenschicht im Spiel 110–200 km/h | gegen AU-R 110/130/150: −0,08 / +0,12 / +0,08 dB (stetig), 170: −0,82, 200: −1,96 dB (Gesetz −0,87 / −2,00); Klangfarbe gegen AU-C1 bei jedem Tempo ≤ 0,57 dB | wie dokumentiert | ja |
| 1 rechte Pflasterschleife | lautester Stein rechts +0,28 … +0,43 dB über AU-C1 (AU-R: +3,0 laut KRITIK-R), Scheitel 13,99–14,21 dB (AU-C1 13,58), True Peak −8,2 … −8,9 dBTP (AU-C1 −9,0) | wie AU-C1 | ja |
| 2 V1, Spielmix, zwei neue Folgen | Asphalt 0,637 → 0,137 / 0,230; Pflaster 0,985 → 0,098 / 0,179; Beton ohne Platten 0,815 → 0,151 / 0,239; Beton mit Platten 0,714 / 0,710 (Takt, zur Kenntnis) | < 0,40 bei 0,3–3 s | ja |
| 3 V3 schwerer Aufprall, je 60 (Folgen 9311 / 9312) | 95 %: Pkw **2,05 dB**, Lkw **2,66 dB**; True Peak höchstens −1,38 / −1,21 dBTP (AU-C1: −0,31 / −0,29, 71 von 120 über −1,0) | ≤ 3 dB; ≤ −1,0 dBTP | ja (Lkw knapp, M1) |
| 3 V3 Reisen | Beton 200 km/h, vier Läufe à 57,5–57,9 s: 0,00 / 0,00 / 0,00 / **0,22 dB**; Beton 170, Asphalt 200, Höchsttempo: 0,04 dB (Rest) | ≤ 0,5 dB je Lauf | ja |
| 3 True Peak: Höchsttempo / schlimmster Fall von AU-C1 | −2,39 → −2,01 dBTP / −0,31 → **−1,54 dBTP** | ≤ −1,0 dBTP | ja |
| 4 Nähte, Starts, Nachstellen, Töne, Drift, Pumpen | 26 Ogg + 2 WAV abtastgenau; kein Ereignisfenster über dem Gewöhnlichen (6 Starts, 94 erzwungene Nachstellungen); kein neuer Ton; Bildraten-Linie mit Drift 11 dB wie ohne (AU-C1: 32 dB); 1 Begrenzer-Eingriff in ~6 min Reisen | keine | ja |
| 5 Rechenzeit `road` je Bild (Median / 95 %) | Beton 0,13 / 0,18–0,22 → 0,20 / 0,28–0,29 ms; Asphalt 0,12 / 0,18 → 0,17 / 0,25–0,26 ms; Sperren 2 je s nur bei 110–150 km/h auf Beton | kein Warten je Bild (AU-R laut KRITIK-R: Mittel 0,37–0,40 / 95 % 0,59–0,62 ms) | ja |
| 6 Hörproben | Marken ±0,15 s (Brücke, Fugen, Hamburg); „Bankett“/„Leitplanke“ 0,6–1,5 s früher als hörbar (N1); nachher-Hälfte und Spielmix = Dateien und Klang des Endstands | stimmig | ja (N1 niedrig) |

Was ein Ohr noch prüfen sollte (abgeleitet, hier nicht hörbar): ob bei 130 km/h auf Beton die Platten präsent genug sind
(sie liegen dort seit AU-C1 3 dB unter ihrem Gesetz, N3) und ob der neue Schnee (+0,9–1,05 LU, −5 … −6 dB unter 160 Hz,
bewusst neu seit AU-R) gefällt.

---------------------------------------------------------------------------------------------------------------------

## 1. Charakter gegen AU-C1 (deterministisch, Plan B)

Plan B = feste Tempi auf der echten Strecke Kiel – Hamburg, Belag auf beiden Ständen gleich erzwungen (Asphalt km 15,
Beton km 42, Pflaster km 87,3), **ohne** Pegeldrift, Böen und Vorbeifahrten, 20 s, Aufnahme am Master vor dessen
Lautstärke (= Gesamtlautstärke 1,0; bei der Voreinstellung 0,8 alles 1,94 dB leiser). Lautheit ungegatet nach BS.1770,
Terzen 25 Hz–12,5 kHz bis 30 dB unter der lautesten. Grenzen: Terz ±1 dB, Lautheit ±0,5 LU.

### 1.1 Fahrbahnschichten und Spielmixe bei den Bezugstempi

| Aufnahme (Plan B, 20 s) | AU-C1 (LUFS) | Endstand (LUFS) | Δ Lautheit | größte Terz-Abweichung | RMS der Terz-Abweichungen | True Peak AU-C1 → Endstand (dBTP) | in den Grenzen |
|---|---|---|---|---|---|---|---|
| Asphalt 130, nur Fahrbahn | −27,80 | −27,66 | +0,14 LU | +0,46 dB bei 251 Hz | 0,22 dB | −17,50 → −16,72 | ja |
| Beton 130, nur Fahrbahn (Reifen + Platten) | −22,38 | −22,26 | +0,12 LU | +0,39 dB bei 316 Hz | 0,19 dB | −6,63 → −6,86 | ja |
| Beton 130, nur Reifen | −25,31 | −25,23 | +0,08 LU | +0,33 dB bei 100 Hz | 0,20 dB | −16,13 → −15,24 | ja |
| Beton 130, nur Platten | −25,48 | −25,37 | +0,11 LU | +0,30 dB bei 40 Hz | 0,16 dB | −8,52 → −7,59 | ja |
| Pflaster 50, nur Fahrbahn | −20,98 | −21,20 | −0,22 LU | −0,53 dB bei 40 Hz | 0,36 dB | −9,02 → −8,21 | ja |
| Spielmix Asphalt 130 | −15,18 | −15,47 | −0,29 LU | −0,82 dB bei 40 Hz | 0,25 dB | −8,15 → −8,68 | ja |
| Spielmix Beton 130 | −14,83 | −14,62 | +0,21 LU | +0,40 dB bei 40 Hz | 0,20 dB | −3,59 → −4,49 | ja |
| Spielmix Pflaster 50 | −17,01 | −17,18 | −0,17 LU | +0,89 dB bei 32 Hz | 0,33 dB | −5,37 → −6,44 | ja |

In den Spielmixen streut der Motor (Dateien seit AU-C1 byte-gleich) von Lauf zu Lauf um einige Zehntel LU, seine
tiefen Terzen (32–40 Hz) am stärksten – die größten Abweichungen der Spielmixe liegen genau dort (+0,89 / −0,82 dB)
und sind darum zum Teil Streuung des Motors (abgeleitet). Die Fahrbahnschichten allein bleiben unter 0,53 dB und 0,22 LU.

### 1.2 Die Plattenschicht im Spiel, 110–200 km/h (nur Platten, ohne Zufall, je 15 s)

Gesetz (`road_audio.slab_lufs`): bis 150 km/h 20 dB je Dekade (alle Stände), darüber seit AU-R2 nur 4 dB je Dekade –
gegenüber AU-R also −0,45 dB bei 160, −0,87 dB bei 170, −2,00 dB bei 200 km/h, bei 150 km/h stetig (Knick, kein
Sprung). Zwischen 110 und 150 km/h klingen beide Entwürfe zugleich: Für den Vergleich mit AU-C1 müssen sie wie dort
gemeinsam starten (Plan S2 mit einem kurzen Abschnitt ohne Platten davor); in Plan S lief bei AU-C1 bei 130 und
140 km/h der langsame Entwurf schon und der schnelle setzte versetzt ein – dann weicht AU-C1 **selbst** um bis zu
4 dB bei 79–100 Hz von seiner gleichzeitig gestarteten Fassung ab (gemessen: −3,85 dB bei 79 Hz, −4,15 dB bei 100 Hz).

| km/h | AU-C1 (LUFS / dBTP) | AU-R | Endstand | Endstand − AU-R: gemessen / Gesetz | Endstand − AU-C1: Lautheit | größte Terz-Abweichung zu AU-C1 (nach Abzug der Lautheit) |
|---|---|---|---|---|---|---|
| 110 | −23,68 / −7,03 | −23,71 / −6,65 | −23,79 / −7,75 | −0,08 / 0 | −0,11 LU | +0,45 dB bei 501 Hz |
| 120 (gemeinsam gestartet) | −24,50 / −7,73 | – | −24,46 / −7,69 | – | +0,04 LU | +0,26 dB bei 40 Hz |
| 130 (gemeinsam gestartet) | −25,48 / −8,61 | −25,24 / −7,84 ¹ | −25,35 / −7,59 | +0,12 / 0 ¹ | +0,13 LU | −0,57 dB bei 794 Hz |
| 140 (gemeinsam gestartet) | −22,60 / −7,00 | −22,53 / −7,27 ¹ | −22,54 / −7,24 | +0,08 / 0 ¹ | +0,06 LU | −0,45 dB bei 25 Hz |
| 150 | −20,71 / −5,75 | −20,74 / −6,60 | −20,66 / −6,18 | +0,08 / 0 | +0,05 LU | −0,41 dB bei 200 Hz |
| 160 | −20,33 / −5,48 | −20,36 / −6,32 | −20,75 / −6,30 | −0,39 / −0,45 | −0,42 LU | −0,15 dB bei 1 kHz |
| 170 | −19,90 / −5,18 | −19,94 / −5,94 | −20,76 / −6,52 | **−0,82 / −0,87** | −0,86 LU (gewollt) | +0,33 dB bei 251 Hz |
| 200 | −18,59 / −4,32 | −18,62 / −4,76 | −20,58 / −6,66 | **−1,96 / −2,00** | −1,99 LU (gewollt) | −0,13 dB bei 40 Hz |

¹ AU-R startet seine Entwürfe im Gleichschritt (seit AU-R) – Plan S ist dort gültig. Ergebnis (gemessen): Der Pegel
folgt dem Gesetz auf 0,12 dB, ist bei 150 km/h stetig und liegt bei 170 / 200 km/h 0,82 / 1,96 dB unter AU-R – wie
dokumentiert. Die Klangfarbe der Schicht bleibt bei jedem Tempo innerhalb 0,6 dB von AU-C1; gegen AU-R ist sie bei
130 km/h um +1,47 dB bei 501 Hz und bei 200 km/h um +1,03 dB bei 398 Hz **zurück** zu AU-C1 gewandert (der Befund
H1 der Nachmessung ist behoben). Datei-Ebene: Die 32 Platten beider Entwürfe sind die 8 Fugen von AU-C1
(Korrelation je Platte ≥ 0,966), jede viermal, in beiden Entwürfen in derselben Folge.
Zur Kenntnis (unverändert seit AU-C1, kein Befund dieser Runde): In der Mitte der Überblendung (130 km/h) liegt die
Schicht 1,3 dB unter ihrem Wert bei 110 km/h, obwohl das Gesetz +1,5 dB verlangt – die beiden Entwürfe werden mit
linearen Gewichten (1 − x, x) überblendet, bei x = 0,5 je −6 dB (gemessen in allen drei Ständen gleich).

### 1.3 Die rechte Pflasterschleife (neuer Seed, für ihre Tonhöhe angeglichen)

50 km/h, nur Fahrbahn, ohne Drift, vier Läufe je Stand (Plan B + drei mit anderen Startpunkten); AU-C1 spielt eine
Schleife auf beiden Rädern mit festem Versatz und ist darum in jedem Lauf gleich.

| Stand | True Peak der Schicht (dBTP) | Scheitelfaktor L / R (dB) | 99,9 %-Spitzen über RMS L / R (dB) | lautester Stein gegen den lautesten von AU-C1, L / R (dB) |
|---|---|---|---|---|
| AU-C1 (4 Läufe, gleich) | −9,02 … −9,01 | 13,56 / 13,58 | 11,29–11,31 / 11,31–11,32 | 0 / 0 |
| Endstand Lauf 1–4 | −8,21 / −8,87 / −8,72 / −8,71 | 13,71–14,73 / 13,99–14,21 | 10,89–11,17 / 10,94–11,14 | **−0,04 … +0,91 / +0,28 … +0,43** |

Datei-Ebene (gemessen, Monosumme der Datei): rechte Schleife AU-R Scheitel 16,18 dB → Endstand 13,88 dB (AU-C1s
einzige Schleife 15,64 dB, die linke seit AU-R 14,25 dB). Rechts liegt der lauteste Stein jetzt höchstens 0,43 dB über
AU-C1 (AU-R: +3,0 dB laut KRITIK-R) – behoben. Links (Schleife seit AU-R unverändert) erreicht in einem von vier Läufen ein
einzelner Stein +0,91 dB, je nachdem, wie die Steine der beiden Schleifen zufällig zusammentreffen; die Masse der
Steine (99,9 %) liegt 0,2–0,4 dB **unter** AU-C1. Ob ein einzelner Stein um 0,9 dB auffällt: abgeleitet nein.

### 1.4 Die übrigen Fahrbahnschichten und der Wind (Plan B, seit AU-R unverändert – zur Vollständigkeit neu gemessen)

| Aufnahme (8–20 s) | AU-C1 (LUFS) | Endstand (LUFS) | Δ LU | größte Terz-Abweichung |
|---|---|---|---|---|
| Rüttelstreifen 130 | −18,85 | −18,84 | +0,01 | −0,58 dB bei 50 Hz |
| Stahldeck 80 (ohne Fugen) | −31,34 | −31,30 | +0,04 | −0,56 dB bei 50 Hz |
| Nässe 130 | −22,90 | −22,87 | +0,03 | +0,54 dB bei 50 Hz |
| Schotter (Bankett) 100 | −17,80 | −17,72 | +0,08 | +0,81 dB bei 25 Hz |
| Gras 60 | −20,65 | −20,72 | −0,07 | −0,61 dB bei 25 Hz |
| Wind 130 / 200 / Höchsttempo (mit Wummern) | −34,78 / −24,49 / −18,55 | −34,77 / −24,44 / −18,48 | +0,01 / +0,05 / +0,07 | +0,25 / +0,38 / +0,56 dB |
| Schnee 50 / 90 / 130 (seit AU-R bewusst eine eigene Knirsch-Schleife) | −40,41 / −33,72 / −29,24 | −39,54 / −32,67 / −28,29 | +0,87 / +1,05 / +0,95 | −6,3 / −6,0 / −6,3 dB unter 160 Hz |

Alles in den Grenzen außer dem Schnee, der kein Bezugsfall der Charaktergrenze ist: er ist seit AU-R absichtlich ein
anderer Klang (laut Auftrag von AU-R „weiches Knirschen statt Steinschläge“, Hörprobe `schnee_neu` liegt beim Nutzer) –
zur Kenntnis, kein Befund dieser Runde.

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

## 4. Nähte und Artefakte im Spiel

### 4.1 Nähte: jede Schleife abtastgenau

Jede Datei für sich auf einem eigenen Bus, Tonhöhe 1, 17 s, Aufnahme am Busende gegen die mit ffmpeg dekodierte Datei,
gekachelt mit ihrer Schleifenlänge (WAV: Schleifenende aus den Importeinstellungen; die Plattendateien tragen 16 Frames
nach dem Schleifenende).

| Schleifen | Anzahl | Start-Korrelation | gespielte Periode = Schleifenlänge | Rest an den Nähten (±20 ms) / sonst | Sprung an der Naht der Datei (× größter Sprung in ±100 ms) |
|---|---|---|---|---|---|
| Reifen, Nässe, Schnee, Wind (Ogg, je Seite eine eigene) | 26 | 1,000000 | 26 von 26, auf das Sample | 3·10⁻⁸ … 1,8·10⁻⁷ / 1,2·10⁻⁷ … 2,4·10⁻⁷ | 0,00 … 0,54 |
| Platten langsam / schnell (WAV, 282 240 / 141 120 Frames) | 2 | 1,000000 | 2 von 2 | 1,7·10⁻⁵ / 2,1·10⁻⁵ und 2,1·10⁻⁵ / 2,2·10⁻⁵ (< 1 LSB, überall gleich) | 0,00 / 0,00 (Schleife beginnt und endet zwischen zwei Schlägen) |

Kein Rest an einer Naht über dem Rest anderswo – keine Naht ist hörbar (gemessen: kein Sprung; „hörbar“ abgeleitet).

### 4.2 Wenn ein Plattenmuster startet oder nachgestellt wird

Was Godot 4.7.2 an diesen Stellen tut, mit einem Sinus (441 Hz, eigener Bus, `kr_restart.gd`) gemessen:

| Vorgang | gemessen (einfacher und 2D-Spieler gleich) |
|---|---|
| `play(pos)` auf einem stehenden Spieler | **harter Einsatz**: erstes Sample springt auf den Wert der Datei an `pos` (0 → 0,43 bei Amplitude 0,49), keine Einblendung |
| `play(pos)` auf einem laufenden Spieler (= Nachstellen, `restart`) | neuer Abspielvorgang setzt **hart** ein, der alte blendet in ~470 Samples (eine Mischblocklänge, 10,7 ms) aus; Sprung 0,48 bei Amplitude 0,49 |
| `volume_db` ändern (jedes Bild, 0 / −3 dB im Wechsel) | linear über einen Mischblock geführt: 10–90 % in 405 Samples – **kein** Treppensprung |
| `stop()` | Ausblendung, 10–90 % in 408 Samples |

Im Spiel startet eine Plattenschleife mit dem ersten Schritt der Pegelglättung (24 % des Ziels bei 60 Bildern/s) und
einer Stelle zwischen zwei Schlägen oder an der Stelle der laufenden Schleife; der Einsatzsprung ist daher klein
(Datei-Ebene: Betrag an einer zufälligen Stelle im Median −25 / −20 dB unter der Schlagspitze, in 10 % der Fälle über
−13 / −11 dB). Gemessen im Spiel (`km_slab.gd`, Tempoprofil 90–160 km/h mit Rampen und Sprüngen durch die Überblendung,
beide Entwürfe getrennt aufgenommen; Maß = größter Samplesprung und größte 8-kHz-Spitze im 93-ms-Fenster um das
Ereignis, gegen alle Fenster derselben Aufnahme):

| Lauf | Starts | Nachstellungen | größter Sprung im Ereignisfenster (× 99-%-Wert gewöhnlicher Fenster) | Rang unter allen Fenstern |
|---|---|---|---|---|
| normal (`align_ms` 6), 90 s | 6 | **0** | 0,28 | ≤ 31 % |
| erzwungen (`align_ms` 0,1), 90 s | 6 | 94 | Starts 0,30, Nachstellungen 0,44 (8 kHz: 0,56) | ≤ 67 % |

Kein Ereignisfenster ragt aus den gewöhnlichen heraus; die Schläge des Musters selbst sind größer als jeder Einsatz.
Abstand der beiden Entwürfe (Abspielpositionen, 3 906 Bilder mit beiden): Median 1,9 ms, 95 % 4,0 ms; in keinem
normalen Lauf (rund 220 s mit beiden Entwürfen, Pläne A, B, S, S2 und das Fahrprofil) wurde nachgestellt.

### 4.3 Neue Töne, Reißverschluss durch die Drift, Pumpen

| Prüfung | AU-C1 | Endstand | Ergebnis |
|---|---|---|---|
| tonale Spitzen ≥ 12 dB über der Terzumgebung (Plan B, nur Fahrbahn) | Asphalt –, Pflaster 121 Hz, Beton 51/65/94/108/122/217/231 Hz | Asphalt –, Pflaster –, Beton 65/94/109/122/217/231 Hz (dieselben, je ≤ 0,9 dB anders); nur Platten zusätzlich 137 Hz mit 12,6 dB (Teilton der Fugen, im Beton-Fahrbahnklang nicht über der Schwelle) | kein neuer Ton |
| Linie der Bildrate (55–65 Hz) im Hüllkurvenspektrum, nur Fahrbahn, mit Drift (Plan A) / ohne (Plan B) | 32–37 dB (exakte Schleifen) | 11,0 / 11,6 / 10,7 dB mit Drift gegen 9,2 / 10,3 / 10,6 dB ohne (Asphalt / Pflaster / Beton) | kein Reißverschluss |
| Linie der Mischblockrate (83–90 Hz) | 23–33 dB | 7,9–11,0 dB mit, 8,5–11,0 dB ohne Drift | dito |
| Sinus mit der Drift der Fahrbahn (1,5 dB, 0,8 s, jedes Bild) | – | Linien 8,2 / 10,1 dB (55–65 Hz), keine bei 83–90 Hz | dito |
| Klick-Detektor (4-kHz-Hochpass, 30 dB über dem laufenden Pegel), Plan A/B | 0 | 0 (nur die Plattenschläge selbst lösen ihn in der Aufnahme „nur Platten“ aus, bei AU-C1 genauso) | keine Klicks |
| Begrenzer beim Reisen 130–245 km/h | – | 1 Eingriff von 0,22 dB in 7 Läufen (≈ 6 min) | kein Pumpen |

## 5. Rechenzeit (GDScript je Bild) und Sperren des Audioservers

`kr_perf_conc.gd` (Beton erzwungen, km 42, 140 km/h – beide Plattenentwürfe klingen) und `perf_asph.gd` (= `perf_auc1.gd`
von KRITIK-FAHRBAHN, Asphalt km 76, 140 km/h), je 840 gemessene Bilder; die Skripte rufen `update()` der Slots ein
zweites Mal je Bild nur für die Zeitmessung (der Plattenabgleich zählt darum doppelt: Sperre alle 0,25 s statt 0,5 s).
Drei Durchgänge, Endstand und AU-C1 im Wechsel unter derselben Last (Maschine mit Last 6–8).

| Slot, Belag | AU-C1 Mittel / Median / 95 % (ms) | Endstand Mittel / Median / 95 % (ms) | Endstand − AU-C1 (Median / 95 %) | Maximum einzelner Bilder AU-C1 / Endstand |
|---|---|---|---|---|
| `road`, Beton (Lauf 1 · 2 · 3) | 0,60 ¹ / 0,13 / 0,20 · 0,13 / 0,13 / 0,18 · 0,15 / 0,14 / 0,22 | 0,26 / 0,20 / 0,28 · 0,22 / 0,20 / 0,28 · 0,23 / 0,20 / 0,29 | +0,06 / +0,08 ms | 376,7 ¹ · 2,0 · 1,4 / 21,0 · 2,7 · 7,5 ms |
| `road`, Asphalt (Lauf 1 · 2 · 3) | 0,19 / 0,12 / 0,18 · 0,13 / 0,12 / 0,18 · 0,15 / 0,12 / 0,18 | 0,21 / 0,17 / 0,26 · 0,20 / 0,17 / 0,25 · 0,21 / 0,18 / 0,26 | +0,05 / +0,08 ms | 49,8 · 2,5 · 8,6 / 7,3 · 6,1 · 7,3 ms |
| `impact`, beide | 0,008 / 0,006 / 0,015 | 0,008–0,010 / 0,006 / 0,015–0,019 | 0 | ≤ 46,3 ¹ / ≤ 1,2 ms |
| `feed`, beide | 0,05–0,07 / 0,05 / 0,07–0,08 | 0,06–0,07 / 0,05 / 0,07–0,09 | ≤ +0,01 ms | – |

¹ einzelne Bilder, in denen die Maschine stand (AU-C1 sperrt nie) – die Maxima sind Last, nicht Klang.

Sperren des Audioservers (`slab_locks`, gemessen): im Spiel (ein `update()` je Bild) **2 je Sekunde, solange beide
Plattenentwürfe klingen** (110–150 km/h auf Beton: 38–39 in 20 s bei 130 km/h, 29 in 15 s bei 120/130/140 km/h), **0** bei
110 km/h und darunter, 0 ab 150 km/h, 0 auf jedem anderen Belag, dazu je eine beim Start eines Musters; in den
Messskripten mit doppeltem Aufruf 61–63 in 840 Bildern. Gegen die Nachmessung von AU-R (`road` auf Beton im Mittel
0,37–0,40 ms, 95 % 0,59–0,62 ms laut KRITIK-R) ist der Befund M1 behoben; gegen AU-C1 bleiben +0,05–0,08 ms je Bild
für die eigenen Schleifen je Seite und die Drift (gemessen), das sind 0,3–0,5 % eines 16,7-ms-Bildes dieser VM;
auf dem Steam Deck abgeleitet ähnlich klein.

## 6. Die Hörproben, die der Nutzer jetzt hört (`deliver/AU-R/`)

Die MP3s dekodiert (ffmpeg) und an jeder Zeitmarke der .txt gesucht, wo sich das Hörbare tatsächlich ändert
(Stufe eines Bandpegels in 20-ms-Schritten, 0,3 s davor gegen 0,3 s danach; Fugen als Transienten 2,5–8 kHz; Neuheit
des Bark-Spektrums). Gemessen; ob ein Mensch eine Abweichung von 0,1 s bemerkt, ist abgeleitet (nein).

### 6.1 Zeitmarken gegen das Hörbare

| Datei | Marke (.txt) | hörbar (gemessen) | Abweichung | Merkmal |
|---|---|---|---|---|
| koehlbrandbruecke_fugen_vorher_nachher | vorher 12 Fugen 0:01.93 … 0:09.47 | 0:01.96 … 0:09.50 | alle ±0,10 s | Transienten 2,5–8 kHz (+11,8 … +13,9 dB) |
| koehlbrandbruecke_fugen_vorher_nachher | nachher 0:14.74 / 17.58 / 20.43 / 22.17 | 0:14.67 / 17.56 / 20.44 / 22.21 | −0,07 / −0,02 / +0,01 / +0,04 s | dito (+12,3 … +15,1 dB) |
| fahrt_kiel_hamburg_vorher_nachher | nachher Innenstadt 1:23.72 | 1:23.66 | −0,06 s | Pegelstufe 1–8 kHz −10,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | nachher Pflaster 1:25.81 | 1:25.76–1:25.80 | −0,05 … −0,01 s | Stufe 250–1000 Hz +6,4 dB, 2,5–8 kHz +8,4 dB |
| fahrt_kiel_hamburg_vorher_nachher | nachher Asphalt 1:31.98 | 1:32.02–1:32.04 | +0,04 … +0,06 s | Stufe −6,4 / −8,4 dB |
| fahrt_kiel_hamburg_vorher_nachher | Beton (keine Marke; Bericht AU-R2: „ab 0:05 und ab 0:53“) | 0:04.9 / 0:53.4 | – | Stufe 2,5–8 kHz +3,6 / +2,2 dB |
| fahrt_kiel_hamburg_vorher_nachher | Köhlbrandbrücke 0:09.43 / 0:57.82 | 0:09.58 / 0:57.74 | +0,15 / −0,08 s | Neuheit 8,3 / 7,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | vorher Innenstadt + Pflaster 0:35.86 | 0:36.00 | +0,14 s | Stufe 250–1000 Hz +4,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | Bankett 0:25.77 / 1:13.87 | 0:27.26 / 1:14.94 | **+1,49 / +1,07 s** | Schotter beginnt erst, wenn das Rad das Bankett erreicht |
| fahrt_kiel_hamburg_vorher_nachher | Leitplanke 0:30.51 / 1:18.50 | 0:31.48 / 1:19.10 | **+0,97 / +0,60 s** | der Schlag kommt 0,9 s Skriptzeit nach dem Phasenbeginn |
| fahrt_kiel_hamburg_spielmix_neu | Pflaster 0:37.39 / Asphalt 0:43.64 | 0:37.38 / 0:43.68 | −0,01 / +0,04 s | Stufe 250–1000 Hz +3,9 / −2,9 dB (über 2,5 kHz verdeckt die Musik die Stufe) |
| fahrt_kiel_hamburg_spielmix_neu | Beton (keine Marke) | 0:04.6 | – | Stufe 1–8 kHz +3,6 dB |

### 6.2 Ist die „nachher“-Hälfte der Klang des Endstands?

Zwei unabhängige Wege, beide gemessen:

**(a) Welche Schleifendatei spielt?** Eine Strecke mit festem Tempo wird gegen jede Kandidatendatei kreuzkorreliert
(Datei mit der Tonhöhe des Tempos gerendert, 1–8 kHz, normiert, jede Verschiebung einer Periode). Die Datei, die spielt,
gibt einen klaren Höchstwert; fremde bleiben nahe am Rauschen (≤ 0,12 – die Plattendatei des Endstands erreicht in der
AU-C1-Hälfte 0,121, weil ihre Platten aus denselben 8 Fugen bestehen). Probe aufs Exempel an meinen eigenen Aufnahmen: die
Neuaufnahme auf dem Endstand findet die Dateien des Endstands (0,421 / 0,731), die auf AU-R die von AU-R (0,462 / 0,750).

| Strecke | Endstand-Datei | AU-R-Datei | AU-C1-Datei |
|---|---|---|---|
| vorher_nachher, **nachher**, Beton 175 km/h (`slab_fast`, 0:54.2–0:57.6) | **0,414** | 0,039 | 0,089 |
| vorher_nachher, **nachher**, Hamburger Pflaster rechts (`tyre_cobbles_b`, 1:26.3–1:31.6) | **0,700** | 0,020 | 0,019 |
| vorher_nachher, vorher, Beton 175 km/h | 0,121 | 0,043 | **0,481** |
| vorher_nachher, vorher, Pflaster (AU-C1s eine Schleife) | – | – | **0,824** |
| spielmix_neu, Beton 175 km/h (0:05.4–0:08.8, mit Musik) | **0,387** | 0,039 | 0,085 |
| spielmix_neu, Pflaster rechts (0:37.9–0:43.3, mit Musik) | **0,255** | 0,018 | – |

Die beiden Dateien, die AU-R2 geändert hat (Plattenmuster, rechte Pflasterschleife), sind in beiden neuen Hörproben
die des Endstands; AU-R3 hat keine Klangdatei geändert (git: nur `audio_feed.gd`, Test, Doku, eine Beschreibung).

**(b) Klingt eine Neuaufnahme gleich?** Dieselbe Fahrt (`drive_ab.gd` von AU-R2, `--cobble-km=88.4`) auf dem Endstand,
auf AU-R und auf AU-C1 neu aufgenommen und Strecke für Strecke mit den Hälften der MP3 verglichen (Terzen, Lautheit):

| Vergleich | Beton 175 km/h | Stahldeck 120 km/h (mit Fugen) | Pflaster 50 km/h |
|---|---|---|---|
| nachher → Neuaufnahme **Endstand** | Terzen 500 Hz–10 kHz **−0,2 … +0,1 dB**; Motorbänder 125 / 251 / 398 Hz +1,9 / +1,0 / +1,5 dB → +1,16 LU | −0,4 … +0,9 dB, −0,21 LU | −0,2 … +0,5 dB, +0,17 LU |
| nachher → Neuaufnahme AU-R | −0,2 … +1,5 dB (Motorbänder +1,1 / +0,7 / +1,5), +0,82 LU | −0,1 … +1,3 dB, +0,78 LU | −0,3 … +1,1 dB, +0,04 LU |
| nachher → Neuaufnahme AU-C1 | −0,5 … +1,3 dB (Motorbänder +1,3 / +0,7 / +1,0), +0,98 LU | **+0,2 … +6,4 dB** (12 Fugen statt 4), +0,48 LU | −0,7 … +1,2 dB, −0,24 LU |
| vorher → Neuaufnahme AU-C1 (Streuung einer Neuaufnahme desselben Stands) | −0,2 … +0,5 dB, +0,35 LU | −0,1 … +0,9 dB, +0,24 LU | −0,9 … +0,6 dB, +0,09 LU |

Ergebnis: **Ja.** Die nachher-Hälfte und der Spielmix sind der Klang des Endstands: über 500 Hz (Platten, Reifen, Wind)
auf 0,2 dB gleich, auf Pflaster und Deck innerhalb der Streuung einer Neuaufnahme. Die +1,16 LU auf Beton kommen aus den
Motorbändern (125 / 251 / 398 Hz); alle drei Neuaufnahmen – gleich welcher Stand – liegen dort 0,7–1,9 dB über der MP3:
die Hörprobe hat in diesen 3,6 s einen leiseren Motormoment (Motor-Bewegung; Motordateien seit AU-C1 byte-gleich).

### 6.3 Die übrigen Hörproben

`koehlbrandbruecke_fugen_vorher_nachher`, `aufprall_abwechslung_neu`, `schnee_neu` stammen von AU-R. Zwischen AU-R und dem
Endstand haben sich nur die Plattenmuster, die rechte Pflasterschleife, das Plattengesetz über 150 km/h, die Sperre und
die Altstadtregel geändert (git diff `3d2e6e1..b6339ad`); keine davon spielt auf dem Stahldeck, beim Aufprall oder im
Schnee. Diese drei Hörproben gelten darum für den Endstand (abgeleitet aus dem Diff; die Fugenzeiten der Brücke sind
gemessen, Tabelle 6.1). Die Angaben in den .txt (z. B. „tiefer Schlag 2,5 dB leiser“, „bei 170 km/h knapp 1 dB leiser“,
„Pflaster ohne die zwei lauten Steine“) stimmen mit der Konfiguration bzw. meinen Messungen überein
(`hit_heavy` −11,5 statt −9; −0,82 dB bei 170 km/h; rechts ≤ +0,43 dB).

## 7. Befunde nach Rang

Schwere nach Auftrag: Blocker = Gate verfehlt, True Peak über −1,0 dBTP oder ein hörbarer Klick / eine hörbare
Regression; hoch = ein Ziel aus V1/V3 oder eine Charaktergrenze verfehlt oder eine irreführende Hörprobe; mittel/niedrig
= der Rest. **Kein Blocker, kein hoher Befund.**

| Nr | Schwere | Befund | Beleg (gemessen, sofern nicht anders gesagt) | Vorschlag (Datei → Stelle → Wert) |
|---|---|---|---|---|
| M1 | mittel | **V3 beim Lkw hält nur knapp:** 95-%-Wert der Begrenzung 2,66 dB bei 60 Unfällen (Grenze 3 dB), 3 von 60 über 3 dB; der 95-%-Wert aus 60 Unfällen streut selbst (Bootstrap: Standardfehler 0,37 dB, in 35 % der Wiederholungen über 3 dB – abgeleitet). Eine künftige Abnahme mit neuen Zufallsfolgen kann daran scheitern, ohne dass sich etwas geändert hat. Pkw: 2,05 dB (2 %). | `res/crash_truck_obj.json`, Folge 9312; AU-R2 laut Bericht 2,42 dB mit Folge 778 | Entweder V3 für Abnahmen über ≥ 120 Unfälle (zwei Folgen zusammen) auswerten, oder `config/game_config.json` → `audio.modern.impact.collision.truck.heavy` −11 → −11,5 (verändert den Lkw-Schlag um 0,5 dB – Mischentscheidung; vorher mit 60 Unfällen nachmessen) |
| N1 | niedrig | Hörprobe `fahrt_kiel_hamburg_vorher_nachher.txt`: Die Marken „Bankett“ und „Leitplanke“ sind Phasenanfänge; hörbar wird der Schotter 1,1–1,5 s und der Leitplankenschlag 0,6–1,0 s später (0:27,3 statt 0:25,77; 0:31,5 statt 0:30,51; 1:14,9 statt 1:13,87; 1:19,1 statt 1:18,50). Alle anderen Marken ±0,15 s. | Abschnitt 6.1 | `AU-R2/prev/build_r2.py` → `drive_lines()`: für „Bankett“ den ersten Eintrag `*/shoulder` aus `surfaces`, für „Leitplanke“ Phasenanfang + 0,9 s × k angeben (oder „Fahrt zum Bankett / zur Leitplanke“ schreiben) |
| N2 | niedrig | Ein Nachstellen der Plattenmuster ist in Godot ein harter Schnitt: `play(pos)` auf einem laufenden Spieler startet den neuen Abspielvorgang ohne Einblendung, der alte blendet in ~470 Samples aus (Sinus-Messung). Für die leisere Schleife bedeutet das einen Sprung von der Größe ihres Samples an der neuen Stelle (Median −25 / −20 dB unter der Schlagspitze, in 10 % über −13 / −11 dB) und 11 ms Doppelbild. | 94 erzwungene Nachstellungen: kein Ereignisfenster über dem gewöhnlichen Bereich (≤ 0,56 × 99-%-Wert); im normalen Betrieb 0 Nachstellungen in rund 220 s mit beiden Entwürfen; hörbar: abgeleitet nein | keiner nötig; falls je hörbar: `scripts/audio/modern/road_audio.gd` → `_update_slabs()` nur nachstellen, wenn der leisere Entwurf ≥ 10 dB unter dem lauteren liegt, oder über einen zweiten Spieler überblenden |
| N3 | niedrig (zur Kenntnis, seit AU-C1) | In der Mitte der Überblendung der beiden Plattenentwürfe (120–135 km/h) liegt die Plattenschicht 2,3–3,4 dB unter ihrem Gesetz (lineare Gewichte 1 − x / x, bei x = 0,5 je −6 dB); gleich in AU-C1, AU-R und dem Endstand – der Klang, den der Nutzer gehört hat. | Plan S/S2, Fahrprofil `km_slab` (Abschnitt 1.2) | keine Änderung in dieser Runde; für die spätere Mischentscheidung über `slabs.db`: bei 130 km/h, dem häufigsten Autobahntempo, sind die Platten 3 dB leiser als das Gesetz sagt |

## 8. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS/`
(Kopien der Stände und Aufnahmen nach dem Bericht gelöscht; Ergebnisse und Skripte bleiben):

- `tools/` – Kopien der Skripte der Nachmessung (KRITIK-R) in der Fassung von AU-R2 (`ktools/`): `kr_crash.gd`,
  `kr_perf_conc.gd`, `kr_seam.gd`, `kr_worst.gd`, `vol_probe.gd`, `dsp.py`, `ana_cap.py`, `ana_compare.py`,
  `ana_crash.py`, `crash_p95.py`, `ana_peaks.py`, `ana_mod.py`, `char_cmp.py`; `perf_asph.gd` (= `perf_auc1.gd` von
  KRITIK-FAHRBAHN, Asphalt km 76), `drive_ab.gd` (AU-R2 `prev/`, die Fahrt der Hörproben).
  Eigene: `km_capture.gd` (= `kr_capture.gd` + `--seed` + Sperrzähler zu Beginn jedes Abschnitts), `km_slab.gd`
  (= `kr_slab.gd` + `--align-ms` + Zähler je Bild), `kr_restart.gd` (Verhalten von Godot bei Start, Neustart,
  Pegelschritten, Stopp), Pläne `plan_m{B,S,S2,A,V,C,Bx}.json`, `ana_slabsweep.py`, `ana_slabcurve.py`,
  `ana_slabclick.py`, `ana_restart.py`, `ana_seam2.py` (WAV-Schleifen mit Schleifenende), `ana_cobblepeaks.py`,
  `ana_perf.py`, `ana_prev.py`, `ana_marks.py`, `ana_ident.py`, `ana_drivecmp.py`, `plot_levels.py` (nur zur eigenen
  Sichtkontrolle), Abläufe `run_cap.sh`, `batch1.sh`–`batch3.sh`, `mk_head.sh`.
- `res/` – alle Ergebnisse als JSON, `logs/` – alle Protokolle (je Lauf eins), `fig/` – Pegelverläufe der Hörproben
  (eigene Kontrolle, nicht für den Nutzer).
