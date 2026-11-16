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
