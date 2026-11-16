# KRITIK-MISCHUNG – Mess-Review der Musikmischung (AU-D1, AU-D2) und des ganzen Spielmix im Klangprofil „Modern“

Objekt: Kopf `4209268` (`origin/wip/v080-au-c1`) mit AU-A, AU-B, AU-D1, AU-D2, AU-C1. Rolle: unabhängige Messung, nur
lesend – keine Commits, keine Änderung im Worktree des Bauers. Gemessen wurde in einer Kopie im Arbeitsordner
(`m1/KRITIK-MISCHUNG/copy`), alle schweren Läufe nacheinander mit `nice -n 19`.

**Niemand hier kann hören.** „gemessen“ = an den ausgelieferten Dateien oder an Aufnahmen aus dem laufenden Spiel
(Godot 4.7.2, Dummy-Treiber, Master-Bus, Standardregler Gesamt 0,8 / Effekte 1,0 / Musik 0,7). „abgeleitet“ = aus
Messwerten gerechnet, insbesondere jede Aussage über Hörbarkeit (Maskierungsmodell) und jede Aussage darüber, wie etwas
auf Kopfhörern, auf den Lautsprechern des Steam Deck oder über Stunden wirkt. Was ein Mensch beurteilen muss, steht in
Abschnitt 7; das Knopfblatt für die Überarbeitung nach dem Urteil des Nutzers in Abschnitt 6.

## 0. Kurzfassung

1. **Technisch sauber**: alle Dateien −14,1 ± 0,1 LUFS, True Peak −1,45 bis −1,80 dBTP nach Vorbis, Bass unter 120 Hz
   mono (Korrelation 1,00, nie gegenphasig), Nähte im Spiel exakt, Schlüsse am Taktstrich ohne Lücke und ohne Doppelschlag
   (im Spiel nachgeprüft), Nähte und Schlüsse ohne Lautheitssprung (≤ 1 LU), Stinger 2–3 LU über der Musik davor, Menü →
   Rennen → Ergebnis gleichmäßig (−20 / −19,6 / −20 LUFS). Die drei Rennstücke liegen in jedem Band höchstens 1,6 dB
   auseinander. Hier gibt es nichts zu reparieren.
2. **Wichtigster Befund für das Spiel**: Unter Vollgas ist die **Melodie** der Rennmusik überwiegend verdeckt – nach dem
   Maskierungsmodell liegen bei 130 / 200 / 250 km/h nur 41 / 33 / 27 % der Melodie-Energie über der Mithörschwelle des
   Autos (Median 4–7 dB darunter). Durch kommen Kick, Bass und Hi-Hats. Bei 130 km/h Teillast und darunter ist die Musik
   voll hörbar (99–100 %). Das Auto bleibt in jedem Zustand zu ≥ 96 % hörbar – die Musik kämpft nirgends gegen den Motor.
   Ursache: Plan D29 (8 dB unter dem Auto) plus Renn-EQ, der 500–1250 Hz (die Grundtöne der Melodien) um 1,2–3,1 dB
   absenkt und die Tiefen fast stehen lässt. **Abgeleitet: Das Urteil „Musik im Rennen zu leise“ ist wahrscheinlich.**
   Der Nutzer kann das heute Abend schon hören: Die Hörprobe `AU-D1/rennmix_linke_spur_unter_motor.mp3` zeigt das
   Verhältnis Musik/Auto unter Vollgas etwa wie im heutigen Spiel (dort noch Platzhalter-Wind statt Reifen und Wind von
   AU-C1; Unterschied ≤ 1 dB, abgeleitet aus den Messungen von AU-D1, AU-C1 und dieser).
3. **Bass**: Die Terz um 50 Hz liegt 10–11 dB über der Referenz (Titelmelodie v0.5.0); der größte Basshöcker (63 Hz) ist
   die Kick. **Die Knöpfe `sub_db` und `bass_db` in `mischung.json` wirken kaum** (gemessen: `sub_db −3` senkt nur 40–50 Hz
   um 2,1–2,6 dB, 63 Hz gar nicht; `bass_db −3` ≤ 0,6 dB). Für „zu viel Bass“ fehlt ein wirksamer Knopf – Vorschlag
   `low_shelf_db` (gemessen in der Kopie: −3 dB bei 120 Hz senkt 25–80 Hz um 2 dB, Balance Bass/Mitte −2,9 dB).
4. **Höhen und Breite**: über 5 kHz +3,5 bis +6,3 dB gegenüber der Referenz, 2–10 kHz fast so viel Seite wie Mitte
   (Korrelation 0,19–0,29 gegen 0,45–0,61). Auf Kopfhörern über Stunden ist „zu schrill/zischelig“ möglich (abgeleitet);
   `high_shelf_db` wirkt wie benannt (gemessen −3 dB bei 4 kHz: 5–8 kHz −2,1, über 8 kHz −2,5 dB).
5. **Schneller Weg**: Pegel, Ducking und Renn-EQ sind Laufzeitwerte in `config/game_config.json → audio.modern` – ohne
   Neu-Rendern, sogar per `game_config.json` neben der ausführbaren Datei. Die Pegelschlüssel in `mischung.json`
   (`race_music_db`, `menu_music_db`, `ui_db`) ändern nur das Manifest, kosten aber einen ganzen Lauf von `render_all.py`
   (gemessen: siehe Abschnitt 5).
6. **Empfehlung für „Musik im Rennen zu leise“ (ohne Rendern, Modell)**: `music.race_eq` = nur Tiefen −3 dB bei 160 Hz,
   `music.context_db.race` 1,0 → 0,8, `duck.depth_db` 4,5 → 3,0 und im Plan `loudness.music_under_car_db` 8 → 6,5:
   Melodie unter Vollgas (Abschnitte A1, B1, B2, D, S) 43 / 35 / 28 % → 63 / 58 / 52 % (130 / 200 / 250 km/h), Motor
   weiter ≥ 95 % hörbar, Bass unter dem Auto −3 dB. Das ändert D29 (6,5 statt 8 dB unter dem Auto) und drei Prüfungen (Abschnitt 6.1) – Entscheidung von
   Nutzer/Leitung. Ohne Planänderung bringt allein der neue Renn-EQ 51 / 40 % (130 / 250 km/h).
7. **Neu-Rendern** (`render_all.py`, alle Stücke + UI, `nice -n 19`, Maschine mit Last 7–9): **gemessen 1953 s = 32,6
   min** – länger als die 25–27 min von AU-D2 und länger als die 30 min, nach denen das Werkzeug einen Hintergrundauftrag
   abbricht (ist hier passiert): in der Überarbeitung mit ausdrücklichem Zeitlimit oder generatorweise (`--only`)
   starten. Ein Lauf mit Werten ≠ 0 (sub −3, Höhen −2 @ 5 kHz, Rennpegel +1) besteht `audio_qc.py` (29 Klänge, 0 Fehler).

## 1. Rangliste der Befunde mit Korrektur

| # | Schwere | Befund (Beleg) | Korrektur: Datei → Schlüssel → Wert | Wirkung |
|---|---|---|---|---|
| 1 | hoch | Melodie unter Vollgas überwiegend verdeckt: 41 / 33 / 27 % hörbar bei 130 / 200 / 250 km/h (GT; Sportwagen 45 / 24 / 28 %), Median −4,3 / −6,2 / −6,7 dB unter der Schwelle; Hook B1 besser (31–58 %), Grooves A1 schlechter (16–32 %). Musik 7,4–8,0 dB unter dem Auto (gemessen), Renn-EQ −1,2 bis −3,1 dB bei 500–1250 Hz (gemessen im Spiel). Tabellen T5–T7. | `config/game_config.json` → `audio.modern.music.race_eq` → `[{"shelf": "low", "hz": 160.0, "db": -3.0}]`; `audio.modern.music.context_db.race` 1,0 → 0,8; mit Planänderung D29 zusätzlich `audio.modern.duck.depth_db` 4,5 → 3,0 und `audio.modern.loudness.music_under_car_db` 8 → 6,5 (Prüfungen 6.1) | abgeleitet: nur EQ 51 / 40 % (130 / 250 Vollgas); mit Ducking 3,0: 63 / 58 / 52 % (130 / 200 / 250), Musik unter Vollgas +1,5 dB (≈ 6,0–6,5 dB unter dem Auto), Teillast +0,6 dB, Motor ≥ 95 % hörbar (T9). Weiter ginge Ducking 2,5 (67 / 56 %), dann fallen die 3-dB-Prüfungen. |
| 2 | hoch (Kopfhörer) | Tiefbass: 50-Hz-Terz +10,5 bis +11,1 dB über der Referenz (die 40-Hz-Terz dafür −10 bis −11 dB: der Sub sitzt eine Terz höher und viel kräftiger); 40–60 Hz +3,4 dB Anteil (T2); größter Höcker 63 Hz = Kick. `sub_db −3` → 40/50 Hz −2,1/−2,6 dB, 63 Hz +0,2 (gemessen); `sub_db −6` → −3,8/−5,2 dB, 63 Hz +0,4; `bass_db −3` → ≤ 0,6 dB irgendwo (T10, Bild 7). | Für das Rennen sofort: Renn-EQ wie Nr. 1. Überall: neuer Schlüssel `low_shelf_db`/`low_shelf_hz` in `tools/audio/music/mischung.json` (in `music_lib.PREFS_DEFAULT` und `Master.__init__` wie `high_shelf_db`, eine Zeile), Wert −3 dB bei 120 Hz, dann `render_all.py` | gemessen (Kopie, Skizze): 25–80 Hz −1,7 bis −2,1 dB, über 250 Hz +0,8 bis +0,9 dB (Lautheit bleibt −14 LUFS), True Peak −1,86 statt −2,25 dBTP vor Vorbis |
| 3 | mittel (Kopfhörer, Stunden) | Höhen +3,5 / +4,9 / +6,3 dB (5–8 / 8–12 / > 12 kHz) gegenüber der Referenz; Neigung 1–10 kHz −0,5 … −0,8 statt −2,5 dB/Okt; HF-Effektivwert +3,4 bis +3,9 dB; 2–5 kHz Korrelation 0,19–0,21 (Seite 1,6–1,8 dB unter Mitte), Master-M/S hebt die Seite +1 dB und über 4 kHz weitere +2 dB (T2, T3, Bilder 2–3) | `mischung.json` → `high_shelf_db` −2 … −3, `high_shelf_hz` 4000; bei „zischelig/unruhig“ zusätzlich in `music_lib.Master._ms` den Seiten-Kuhschwanz `("hs", 4000.0, 2.0)` auf 0,5 dB (Code, kein Schlüssel) | gemessen: −3 @ 4 kHz → 2–5 k −0,5, 5–8 k −2,1, > 8 k −2,5 dB, Rest +0,4; −2 @ 6 kHz → 5–8 k −0,9, > 8 k −1,5 … −1,7 dB. Danach immer noch 1,4–3,8 dB heller als die Referenz (abgeleitet) |
| 4 | mittel | Kleine Lautsprecher (Hochpass 180 Hz): unter Vollgas verliert die Musik 2,2–2,6 LU, das Auto nur 0,3–0,4 LU → Musik 8,7–10,2 dB unter dem Auto statt 7,4–8,0 (gemessen an den Aufnahmen, Hochpass gerechnet). Die Melodie-Bänder ändert der Hochpass nicht. | kein eigener Knopf (Regel 4: der Klang kennt das Gerät nicht); Nr. 1 und 2 helfen mit. Beim Hörtest die Rennmusik **auf den Deck-Lautsprechern und auf Kopfhörern** beurteilen lassen. | – |
| 5 | mittel | Pegelknöpfe doppelt: `race_music_db`/`menu_music_db`/`ui_db` (mischung.json, nur Manifest, aber ganzer Lauf von `render_all.py`) gegen `music.context_db.*` / `levels.MUI` (Konfiguration, sofort; per `game_config.json` neben der EXE überschreibbar). | Pegelurteile heute Nacht über die Konfiguration umsetzen; `mischung.json`-Pegel auf 0 lassen. Werkzeug: `render_all.py --manifest-only` (schreibt nur `gain_db`, Sekunden) | spart pro Pegelrunde den ganzen Lauf (Abschnitt 5) |
| 6 | niedrig | Ducking-Schlüssel ist der Plan, nicht das Auto: bei 80 km/h (Gas 0,3) nimmt der Plan −20,5 LUFS an, das Auto hat −24,2 → Musik 1,9 dB abgesenkt und trotzdem 2,6 dB über dem Auto; bei 130 km/h Teillast gleichauf (T5). Hörbar: Auto 96–98 % (abgeleitet), also kein Kampf. | nur bei „Musik übertönt in der Stadt/bei 80“: `music.context_db.race` 1,0 → 0,0 mit `loudness.music_under_car_db` 8 → 9 | −1 dB in allen Zuständen (abgeleitet aus der Formel in `ModernMix`) |
| 7 | niedrig | Stinger „Tank leer“ am leisesten: +6,5 bis +7,5 LU über der abgesenkten Musik, Spitze nur +0,2 bis +1,6 LU über der Musik davor (Polizei +9,6 bis +10,4, Ziel +9,9 bis +10,6 LU), dunkel (Neigung −7,1 bis −7,6 dB/Okt), T4, T11. | bei „Tank leer kaum hörbar“: `audio.modern.music.sting_duck_db` −9 → −12 (der Director liest den Schlüssel) | +3 LU Abstand für alle Stinger (abgeleitet) |
| 8 | niedrig (Stunden) | Wiederholung: je Etappe (≈ 9 min laut README) 2,8 (Nachtfahrt) bis 3,7 (Rückenwind) Schleifendurchgänge; 78–90 % der Takte haben in der Schleife einen nahezu gleichen Zwilling (normale Liedform). Drei Stücke reihum. | keiner in Daten; Stücke 4–5 (Vertrag D30, optional) oder Musikpausen im Director wären Sache einer späteren Welle | – |
| 9 | Hinweis | Wind verdeckt die Musik nicht: Wind allein bei 250 km/h lässt 96 % der Melodie und 99 % der Höhen hörbar (Median +4,6 dB); verdeckt wird vom Motor (allein 40–48 % hörbar) und ab 200 km/h zusätzlich von den Reifen (allein 69–85 %), T7. | – | – |
| 10 | mittel (Ablauf) | Ein ganzer Lauf von `render_all.py` dauerte unter Last 32,6 min (gemessen) und wurde beim ersten Versuch vom 30-min-Zeitlimit des Werkzeugs für Hintergrundaufträge abgebrochen. Die Pfade mit Werten ≠ 0 laufen und bestehen `audio_qc.py` (Abschnitt 5). | Überarbeitung: Lauf mit ausdrücklichem Zeitlimit (≥ 50 min) oder je Generator `--only`; Pegel nur über die Konfiguration | – |

## 2. Die Stücke (Dateien, wie ausgeliefert nach Ogg Vorbis)

Eigene Messung (eigene BS.1770-4-Umsetzung mit digitalem K-Filter, Kurzzeit 3 s / Momentan 400 ms in 100-ms-Schritten,
LRA nach EBU Tech 3342, True Peak 4-fach bandbegrenzt überabgetastet). Gegenprobe: alle integrierten Werte liegen
0,04–0,05 LU über dem Manifest (Analog- gegen Digitalfilter), True Peak gleich.

### T1 Lautheit und Spitzen (Schleife; Referenz ganze Datei)

| Stück | integriert LUFS | Kurzzeit max / P10 | LRA LU | True Peak dBTP | PLR dB | PSR Median dB | Einzähler / A1 LUFS |
|---|---|---|---|---|---|---|---|
| Titelmelodie v0.5.0 (Referenz) | −14,08 | −11,8 / −17,1 | 4,6 | −1,09 | 13,0 | 11,6 | – |
| Titel-Remaster | −13,93 | −11,8 / −15,8 | 3,1 | −1,64 | 12,3 | 10,8 | – |
| Zwischenspiel | −14,04 | −12,9 / −14,8 | 1,7 | −1,48 | 12,6 | 11,1 | – |
| Linke Spur | −14,08 | −12,4 / −15,1 | 2,3 | −1,80 | 12,3 | 11,1 | −14,7 / −14,5 |
| Nachtfahrt | −14,07 | −11,8 / −16,0 | 3,6 | −1,45 | 12,6 | 11,4 | −19,9 / −15,4 |
| Rückenwind | −14,09 | −12,5 / −15,2 | 2,1 | −1,78 | 12,3 | 10,7 | −17,8 / −14,3 |

- Gleichmäßig unter den Rennstücken (Schleifen −14,07 bis −14,09 LUFS). Jeder Breakdown (D) fällt etwa 10 s lang 5–6 LU
  unter die Schleife (Bild 8) – musikalisch gewollt; unter Vollgas ist er im Spiel ganz verdeckt (T6, Abschnitt D).
- Dynamik: PLR 12,3–12,6 dB, PSR 10,7–11,4 dB – kaum stärker verdichtet als die Referenz (13,0 / 11,6). **Kein
  Ermüdungsrisiko durch Überkompression** (abgeleitet: übliche, laute Popmaster liegen deutlich tiefer).
- Modulation: das Pumpen im Mittenband (200 Hz–2 kHz) im Schlagtakt hat Tiefe 0,12–0,13 gegen 0,09 der Referenz (+30 %),
  im Tiefband bei 8 Hz 0,38–0,40 gegen 0,28 (rollende Bässe) – deutlicher, aber nicht extrem (gemessen; Wirkung abgeleitet).

### T2 Klangbalance: Anteil je Band an der Gesamtenergie (dB), Neigung

| Stück | < 40 | 40–60 | 60–120 | 120–250 | 250–800 | 0,8–2 k | 2–5 k | 5–8 k | 8–12 k | > 12 k | Neigung 0,1–10 k / 1–10 k (dB/Okt) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Titelmelodie v0.5.0 (Referenz) | −25,6 | −10,7 | −5,5 | −5,7 | −7,0 | −10,4 | −13,1 | −19,1 | −22,6 | −26,6 | −1,94 / −2,53 |
| Titel-Remaster | −26,9 | −7,2 | −4,8 | −7,6 | −8,9 | −11,8 | −12,2 | −15,9 | −18,2 | −20,9 | −1,04 / −0,54 |
| Zwischenspiel | −36,9 | −10,6 | −6,8 | −9,4 | −4,3 | −7,9 | −14,3 | −19,6 | −21,2 | −24,5 | −1,59 / −3,15 |
| Linke Spur | −33,3 | −7,2 | −4,6 | −7,7 | −9,4 | −11,9 | −12,3 | −15,8 | −18,0 | −20,6 | −1,04 / −0,55 |
| Nachtfahrt | −32,2 | −7,5 | −4,9 | −7,6 | −8,4 | −11,4 | −12,5 | −16,0 | −17,8 | −20,3 | −1,16 / −0,83 |
| Rückenwind | −32,7 | −7,4 | −4,6 | −7,7 | −10,0 | −11,2 | −11,9 | −15,2 | −17,5 | −20,0 | −0,87 / −0,47 |
| **Rennstücke − Referenz** | −7,1 | +3,4 | +0,8 | −1,9 | −2,2 | −1,1 | +0,8 | +3,5 | +4,9 | +6,3 | |

Die neue Produktion ist eine „Lächelkurve“ gegenüber der Titelmelodie, die der Nutzer liebt: mehr Sub (die Terz um 50 Hz
+10–11 dB, Bild 2), weniger 120–800 Hz, deutlich mehr über 5 kHz. Unter 40 Hz weniger (Hochpass 24 Hz im Master,
Sub-Faltung ab 45 Hz in Stück 2–3) – auf Kopfhörern also kein Infraschall-Druck, aber ein kräftiger Höcker bei 50–63 Hz.
Das Zwischenspiel ist gewollt weicher (mehr Mitten, weniger Sub und Präsenz). **Der Nutzer hat diesen Stil bestätigt** –
die Messung sagt nur, wo die Kurve von der Referenz abweicht, nicht, ob es gefällt.

### T3 Stereo je Band: Korrelation / Seite gegen Mitte (dB)

| Stück | < 120 Hz | 120–500 | 0,5–2 k | 2–5 k | 5–10 k | > 10 k | Monosumme | Bass < 120 Hz: kleinste Korr. (100 ms) |
|---|---|---|---|---|---|---|---|---|
| Titelmelodie v0.5.0 (Referenz) | 1,00 / −27,0 | 0,70 / −7,6 | 0,55 / −5,4 | 0,45 / −4,2 | 0,61 / −6,1 | 0,83 / −10,1 | −0,7 dB | 0,87 |
| Titel-Remaster | 1,00 / −29,0 | 0,62 / −6,3 | 0,41 / −3,7 | 0,19 / −1,6 | 0,26 / −2,3 | 0,69 / −7,2 | −1,0 dB | 0,79 |
| Zwischenspiel | 1,00 / −28,2 | 0,35 / −3,2 | 0,35 / −3,2 | 0,19 / −1,7 | 0,51 / −4,7 | 0,82 / −9,0 | −1,4 dB | 0,75 |
| Linke Spur | 1,00 / −28,3 | 0,62 / −6,3 | 0,43 / −4,0 | 0,20 / −1,7 | 0,27 / −2,4 | 0,70 / −7,3 | −0,9 dB | 0,89 |
| Nachtfahrt | 1,00 / −27,1 | 0,61 / −6,2 | 0,41 / −3,8 | 0,21 / −1,8 | 0,29 / −2,6 | 0,72 / −7,4 | −1,0 dB | 0,80 |
| Rückenwind | 1,00 / −28,1 | 0,56 / −5,6 | 0,41 / −3,8 | 0,19 / −1,7 | 0,26 / −2,3 | 0,69 / −7,1 | −1,0 dB | 0,85 |

Bass mittig und gleichphasig (kein 100-ms-Fenster unter 0,75) – gut für Kopfhörer und Lautsprecher. Monosumme verliert
0,9–1,4 dB (unkritisch). Breit sind die Präsenz und die Höhen (Supersaws, Gitarren hart links/rechts, M/S-Anhebung).

### T4 Zusatzclips (Schlüsse, Ziel, Stinger)

| Clip | Länge s | LUFS | Kurzzeit max | Momentan max | True Peak | Neigung 1–10 k |
|---|---|---|---|---|---|---|
| linke_spur_schluss / _rekord / _finale | 7,8 / 10,1 / 11,9 | −15,7 / −15,2 / −14,6 | −13,6 / −13,6 / −12,6 | −11,9 / −11,9 / −10,9 | −2,42 / −2,47 / −2,19 | −1,6 / −1,8 / −1,2 |
| nachtfahrt_schluss / _rekord / _finale | 8,8 / 11,5 / 13,7 | −15,2 / −14,7 / −14,3 | −12,9 / −13,1 / −12,3 | −11,5 / −11,5 / −10,3 | −2,16 / −1,69 / −2,05 | −2,5 / −2,1 / −1,7 |
| rueckenwind_schluss / _rekord / _finale | 7,4 / 9,4 / 11,0 | −15,9 / −15,6 / −14,8 | −14,0 / −14,1 / −12,8 | −12,1 / −12,1 / −11,1 | −2,15 / −2,24 / −2,63 | −1,7 / −0,9 / −0,9 |
| *_ziel (LS / NF / RW) | 6,4 / 6,9 / 6,2 | −17,8 / −16,4 / −18,7 | −19,0 / −17,6 / −19,7 | −12,4 / −11,9 / −12,8 | −2,97 / −2,30 / −2,98 | −0,4 / −0,9 / −0,2 |
| *_polizei | 10,1 / 11,5 / 9,4 | −16,0 / −15,4 / −15,8 | −15,7 / −14,8 / −15,3 | −13,0 / −12,1 / −13,1 | −3,02 / −2,52 / −3,17 | −1,0 / −1,9 / −1,1 |
| *_tank | 8,2 / 9,2 / 7,8 | −19,2 / −17,9 / −19,2 | −18,3 / −17,2 / −18,4 | −16,0 / −14,9 / −16,2 | −4,95 / −4,76 / −6,44 | −7,6 / −7,1 / −7,5 |

UI-Klänge (Datei): Momentanlautheit −18,0 (`ui_ok`) bis −23,0 (`ui_move`), True Peak −8,4 bis −14,2 dBTP. Über der
Menümusik (Titel-Remaster, Abschnitt 60–90 s, −19,4 LUFS am Master) liegt jeder UI-Klang in seinem lautesten Band
13–28 dB über deren Mithörschwelle (abgeleitet): gut hörbar, ohne laut zu sein (`ui_ok` momentan −19,9 LUFS am Master).

## 3. Übergänge – Nähte, Schlüsse, Stinger, Zwischenspiel

**Im Spiel nachgeprüft** (`tests/unit/audio_modern/check_music.gd --only=interactive` auf dem Kopf, in der Kopie): `CHECK
interactive OK` – alle drei Rennstücke spielen nach dem Dateiende Frame für Frame wie der erste Durchgang (Abweichung 0);
der normale Schluss beginnt 2,90–2,93 ms vor dem Taktstrich, leisestes 5-ms-Fenster 6,4–7,6 dB unter der Musik davor
(keine Lücke), erste 100 ms −0,01 bis +0,01 dB gegen den Clip allein (kein Doppelschlag); `rekord`/`finale` ebenso
(−0,02 / −0,04 dB); Zwischenspiel-Naht Abweichung 0. Log: `m1/KRITIK-MISCHUNG/logs/check_music_interactive.log`.

### T11 Übergänge auf Dateiebene (Simulation wie Godot: Schluss 128 Frames vor dem Taktstrich, 1 ms Ausblenden; Stinger über der um 9 dB abgesenkten Musik)

| Stück | Naht: Sprung / größter Schritt ±50 ms | Schluss: leisestes 5-ms-Fenster | Schluss: Sprung momentan (LU) | Polizei über abgesenkter Musik | Tank | Ziel |
|---|---|---|---|---|---|---|
| Linke Spur | 0,038 / 0,250 | −9,0 dB | −0,6 … +0,9 | +9,8 LU (Spitze +2,5 über der Musik davor) | +6,5 LU (+0,9) | +10,1 LU (+3,0) |
| Nachtfahrt | 0,134 / 0,355 | −5,6 dB | −1,0 … +0,4 | +10,4 LU (+2,6) | +7,5 LU (+1,6) | +10,6 LU (+3,3) |
| Rückenwind | 0,109 / 0,246 | −7,4 dB | −0,7 … +0,9 | +9,6 LU (+1,9) | +6,5 LU (+0,2) | +9,9 LU (+2,4) |

- Naht: der Sprung an der Schleifenstelle ist kleiner als der größte Abtastschritt im Umkreis von 50 ms – kein Knacken.
- Schlüsse (je fünf Taktstriche über die Schleife): Lautheitssprung −1,0 bis +0,9 LU, also kein Aufspringen.
- Stinger: Polizei und Ziel stehen 10 LU über der abgesenkten Musik und 2–3 LU über der Musik davor – deutlich, ohne zu
  erschrecken (abgeleitet). „Tank leer“ ist der leiseste (Befund 7).
- Kontexte (abgeleitet aus Dateipegel + Kette): Menü −20,1 LUFS (Titel), Rennstart (Einzähler, kein Ducking) −19,6 LUFS
  gemessen, Schluss im Ziel −20,3 bis −21,0 LUFS, Zwischenspiel −20,1 LUFS – kein Sprung über 1,5 LU zwischen den
  Bildschirmen. Einzähler von Nachtfahrt / Rückenwind 5,8 / 3,7 LU leiser als ihre Schleife (Anschwellen, gewollt).

## 4. Der Spielmix: Musik unter dem Auto bei 80, 130, 200, 250 km/h

Aufnahme im laufenden Spiel mit einem eigenen Werkzeug (`m1/KRITIK-MISCHUNG/ana/mix_speeds.gd`, lief als
`res://kritik_tools/mix_speeds.gd` in der Kopie): echte Strecke
Kiel – Hamburg, Asphaltabschnitt A7 Bordesholm–Neumünster (Feed mit Leitpfosten, Schildern, Vorbeifahrten), feste Tempi,
Motor v3 + Fahrzeugebenen + Reifen + Wind, ohne Verkehr; je Variante ein Lauf mit `--mute-bus` (Auto allein, Motor,
Reifen, Wind, Musik allein, alles). Ausgewertet die ruhige Mitte jeder Phase.

### T5 Pegel je Fahrzustand (LUFS am Master, gemessen)

| Zustand | Auto GT | Motor | Reifen | Wind | Auto Sportwagen | Musik (Linke Spur) | Auto + Musik | Musik − Auto | Ducking | Plan-Schlüssel |
|---|---|---|---|---|---|---|---|---|---|---|
| Leerlauf | −24,6 | −24,6 | – | – | −24,2 | −19,6 | −18,2 | +5,1 | 0,0 dB | −24,0 |
| 80 km/h, Gas 0,3 | −24,2 | −24,5 | −37,0 | −49,2 | −19,1 | −21,6 | −19,7 | +2,6 | −1,9 dB | −20,5 |
| 130 km/h, Gas 0,3 | −21,0 | −20,8 | −30,7 | −38,2 | −19,9 | −21,1 | −17,8 | −0,1 | −2,4 dB | −19,8 |
| 130 km/h Vollgas | −15,9 | −16,6 | −30,7 | −38,5 | −17,8 | −23,9 | −15,2 | −8,0 | −4,5 dB | −16,0 |
| 200 km/h Vollgas | −16,1 | −16,6 | −25,0 | −28,3 | −15,1 | −23,9 | −15,4 | −7,9 | −4,5 dB | −16,0 |
| 250 km/h Vollgas | −15,3 | −17,1 | −22,1 | −23,7 | −15,3 | −22,7 | −14,7 | −7,4 | −4,5 dB | −16,0 |

- **Ducking gemessen**: Die Übertragung der Musikkette im Spiel (Aufnahme „Musik allein“ gegen die Datei, Terzen) ist im
  Leerlauf −5,0 dB unten, −7,1 dB bei 400–500 Hz, −4,0 dB ab 4 kHz (fest −4,04 dB + Renn-EQ). In jeder Phase ist sie um
  genau das protokollierte Ducking verschoben (−1,90 / −2,42 / −4,49 / −4,48 dB, Streuung über die Terzen 0,03 dB) – die
  Kette ist linear und tut, was die Doku sagt. Rückkehr nach dem Gaswegnehmen: im Mittel der Phase „vom Gas“ −1,6 dB
  (Plan-Schlüssel −21 LUFS), Freigabe 450 ms wie konfiguriert.
- Auto + Musik addieren sich (Leistungssumme der Einzelaufnahmen trifft die Gesamtaufnahme auf 0,0–0,3 dB): der
  Summenkompressor greift praktisch nicht; True Peak der Gesamtaufnahme ≤ −5,2 dBTP.
- Unter Vollgas trifft das Auto den Plan (−16 LUFS) auf −0,1 bis +0,9 dB (GT und Sportwagen); die Musik steht real
  7,4–8,0 dB darunter, wie geplant.

### T6 Hörbarkeit der Melodie (510 Hz – 3,2 kHz) – Modell, abgeleitet aus den gemessenen Spektren (Gran Turismo)

Modell: vereinfachtes Johnston/MPEG-1-Modell 1 je Frequenzgruppe (Zwicker), Tonalität des Maskierers aus der
spektralen Flachheit, Schroeder-Ausbreitung, Ruhehörschwelle (Kalibrierung 1,0 RMS = 94 dB SPL), je Ohr, besseres Ohr;
binaurale Entmaskierung nicht modelliert (für Kopfhörer vorsichtig). „hörbar“ = Anteil der Musik-Energie im Band, der
über der Mithörschwelle des Autos liegt. Die Musik ist die Datei mit der im Spiel gemessenen Übertragung und dem im
Spiel gemessenen Ducking; jeder 8-Takt-Abschnitt aller drei Stücke gegen jede Phase.

| Zustand | Linke Spur Hook B1 | Linke Spur Groove A1 | Nachtfahrt B1 / A1 | Rückenwind B1 / A1 | alle Abschnitte (Mittel) | Median Abstand zur Schwelle | Motor unter der Musik hörbar |
|---|---|---|---|---|---|---|---|
| 80 km/h, Gas 0,3 | 100 % | 100 % | 100 / 100 % | 100 / 100 % | 100 % | +13,5 dB | 96 % |
| 130 km/h, Gas 0,3 | 100 % | 97 % | 100 / 95 % | 100 / 98 % | 99 % | +7,2 dB | 98 % |
| 130 km/h Vollgas | 49 % | 29 % | 58 / 32 % | 52 / 30 % | 41 % | −4,3 dB | 100 % |
| 200 km/h Vollgas | 38 % | 24 % | 46 / 32 % | 39 / 23 % | 33 % | −6,2 dB | 100 % |
| 250 km/h Vollgas | 31 % | 18 % | 39 / 30 % | 32 / 16 % | 27 % | −6,7 dB | 100 % |

Bild 5 zeigt das Muster: unter Vollgas liegt die Musik unterhalb von 200 Hz (Kick, Bass) und oberhalb von 5 kHz (Hats)
über der Schwelle, im Melodiebereich bis 2 kHz 2–9 dB darunter (Hook „Linke Spur“, Median je Band). Abgeleitet: Unter
Vollgas hört der Spieler vom Stück vor allem „Bumm-Tss“; die Melodie kommt nur in ihren lautesten Momenten durch. Bass
hörbar 88–93 %, Höhen 91–97 % (Rohdaten `res/masking.json`).

### T7 Wer verdeckt die Melodie? (alle Abschnitte; in Klammern Median-Abstand)

| Zustand | ganzes Auto GT | nur Motor | nur Reifen | nur Wind | Sportwagen |
|---|---|---|---|---|---|
| 80 km/h, Gas 0,3 | 100 % (+13,5 dB) | 100 % (+17,5 dB) | 100 % (+16,3 dB) | 100 % (+32,3 dB) | 100 % (+9,3 dB) |
| 130 km/h, Gas 0,3 | 99 % (+7,2 dB) | 100 % (+11,9 dB) | 99 % (+9,3 dB) | 100 % (+20,2 dB) | 98 % (+6,5 dB) |
| 130 km/h Vollgas | 41 % (−4,3 dB) | 48 % (−3,3 dB) | 98 % (+7,2 dB) | 100 % (+17,5 dB) | 45 % (−4,4 dB) |
| 200 km/h Vollgas | 33 % (−6,2 dB) | 40 % (−5,2 dB) | 85 % (+1,4 dB) | 99 % (+7,9 dB) | 24 % (−7,4 dB) |
| 250 km/h Vollgas | 27 % (−6,7 dB) | 44 % (−4,3 dB) | 69 % (−1,5 dB) | 96 % (+4,6 dB) | 28 % (−6,8 dB) |

**Der Wind verdeckt die Musik nicht** (bei 250 km/h allein 96 % Melodie, 99 % Höhen hörbar); er liegt dort 6,6 dB unter
dem Motor (T5). Es ist der Motor unter Last (Obertöne 250 Hz – 2 kHz, gemessen), ab 200 km/h verstärkt durch die Reifen
(Maximum 1–1,6 kHz).

### T8 Welcher Musikpegel? (alle Abschnitte, GT; Melodie hörbar / Motor hörbar, in %)

| Zustand | −6 dB | −4 dB | −2 dB | 0 dB (heute) | +2 dB | +4 dB | +6 dB |
|---|---|---|---|---|---|---|---|
| 80 km/h, Gas 0,3 | 99 / 99 | 100 / 98 | 100 / 97 | 100 / 96 | 100 / 94 | 100 / 89 | 100 / 83 |
| 130 km/h, Gas 0,3 | 83 / 100 | 92 / 99 | 96 / 98 | 99 / 98 | 100 / 97 | 100 / 96 | 100 / 93 |
| 130 km/h Vollgas | 13 / 100 | 21 / 100 | 30 / 100 | 41 / 100 | 55 / 99 | 69 / 98 | 82 / 97 |
| 200 km/h Vollgas | 2 / 100 | 8 / 100 | 20 / 100 | 33 / 100 | 47 / 99 | 62 / 98 | 76 / 96 |
| 250 km/h Vollgas | 1 / 100 | 4 / 100 | 14 / 100 | 27 / 100 | 42 / 100 | 57 / 99 | 73 / 98 |

Lesart (abgeleitet): Teillast und Stadt brauchen nicht mehr Musik (99–100 %), Vollgas schon. Ein Pegelplus **nur unter
Vollgas** (kleineres Ducking) trifft genau die Lücke; ein Plus in allen Zuständen macht die Musik bei 80 km/h noch
lauter gegenüber dem Auto (dort heute schon +2,6 dB). Der Motor bleibt in jeder Variante bis +6 dB zu ≥ 83 % (Stadt)
bzw. ≥ 96 % (Autobahn) hörbar. **Pegel, der hörbar bleibt, ohne gegen den Motor zu kämpfen**: unter Vollgas etwa 5–6 dB
unter dem Auto statt 8 (Melodie ≈ 45–55 %), in Teillast wie heute.

### T9 Laufzeit-Alternativen (Modell; Abschnitte A1, B1, B2, D, S aller drei Stücke; Musik auf gleiche Lautheit gebracht)

| Variante | context_db.race für gleiche Lautheit | duck.depth_db | 130 Teillast Melodie | 130 Vollgas Melodie | 250 Vollgas Melodie (Abstand) | Bass hörbar 250 | Motor hörbar (min) |
|---|---|---|---|---|---|---|---|
| heute | +1,01 | 4,5 | 99 % | 43 % | 28 % (−6,6 dB) | 89 % | 96 % |
| Renn-EQ nur Tiefen −3 dB @ 160 Hz | +0,83 | 4,5 | 100 % | 51 % | 40 % (−5,5 dB) | 82 % | 95 % |
| ohne Renn-EQ | −0,09 | 4,5 | 99 % | 44 % | 33 % (−6,4 dB) | 88 % | 95 % |
| heute, Ducking 2,5 | +1,01 | 2,5 | 99 % | 57 % | 44 % (−4,6 dB) | 92 % | 96 % |
| heute, Ducking 1,5 | +1,01 | 1,5 | 100 % | 64 % | 52 % (−3,6 dB) | 93 % | 95 % |
| Tiefen −3 @ 160 + Ducking 2,5 | +0,83 | 2,5 | 100 % | 67 % | 56 % (−3,5 dB) | 88 % | 94 % |
| heute, Ducking 3,0 | +1,01 | 3,0 | 99 % | 54 % | 40 % (−5,1 dB) | 91 % | 96 % |
| **Tiefen −3 @ 160 + Ducking 3,0 (Empfehlung, 3-dB-Prüfungen bleiben grün)** | +0,83 | 3,0 | 100 % | 63 % | 52 % (−4,0 dB) | 86 % | 95 % |
| dazu Renn-EQ Höhen −2 dB @ 5 kHz | +1,14 | 3,0 | 100 % | 65 % | 54 % (−3,8 dB) | 87 % | 94 % |

Bei 200 km/h Vollgas: heute 35 %, Empfehlung 58 % (Rohdaten `res/eq_alt2.json`).

Die Form der Kuhschwanzfilter ist an der im Spiel gemessenen Übertragung des heutigen Renn-EQ angepasst (Restfehler
0,04 dB über 40 Hz–8 kHz). Die Lautheit der Musik ist je Variante auf heute angeglichen; die nötige `context_db.race`
steht in der zweiten Spalte.

### Kleine Lautsprecher (Steam Deck, angenommen als Hochpass 180 Hz, 12 dB/Okt)

| Zustand | Auto GT voll / 180 Hz-Hochpass | Musik voll / Hochpass | Musik − Auto voll / Hochpass |
|---|---|---|---|
| Leerlauf | −24,6 / −35,1 | −19,6 / −22,2 | +5,1 / +12,9 |
| 80 km/h | −24,2 / −27,5 | −21,6 / −24,4 | +2,6 / +3,0 |
| 130 km/h Teillast | −21,0 / −23,7 | −21,1 / −23,2 | −0,1 / +0,4 |
| 130 / 200 / 250 Vollgas | −15,9 / −16,1 / −15,3 → −16,3 / −16,4 / −15,7 | −23,9 / −23,9 / −22,7 → −26,5 / −26,1 / −24,4 | −8,0 / −7,9 / −7,4 → −10,2 / −9,8 / −8,7 |

Gemessen an den Aufnahmen, Hochpass gerechnet; der echte Frequenzgang des Deck ist nicht gemessen (abgeleitet).

## 5. Neu-Rendern: Dauer und Teilweg

**Gemessen** (`render_all.py --out <scratch>`, Werte `sub_db −3`, `high_shelf_db −2`, `high_shelf_hz 5000`,
`race_music_db +1`; `nice -n 19`, ein Prozess; die Maschine war mit Last 7–9 auf 4 Kernen von anderen Paketen belegt):

| Generator | Dauer | AU-D2 (leichtere Last) |
|---|---|---|
| `title_remaster.py` | 464 s | 264–295 s |
| `linke_spur.py` (mit Zusatzclips) | 458 s | 330–407 s |
| `nachtfahrt.py` | 518 s | 400–447 s |
| `rueckenwind.py` | 409 s | 305–337 s |
| `zwischenspiel.py` | 101 s | 76–81 s |
| `ui_klaenge.py` | 3 s | 1 s |
| **zusammen** | **1953 s = 32,6 min** | 25–27 min |

Der erste Lauf wurde nach 30 min vom Zeitlimit des Werkzeugs für Hintergrundaufträge abgebrochen (in `rueckenwind.py`);
die drei letzten Generatoren liefen danach mit `--only` noch einmal (alle Generatoren sind voneinander unabhängig, die
Summe ist die Dauer eines ganzen Laufs). **Für die Überarbeitung**: ausdrückliches Zeitlimit ≥ 50 min oder je Generator.

Ergebnis des Laufs mit Werten ≠ 0 (gegen die ausgelieferten Dateien, bei gleicher Lautheit, gemessen):
- `audio_qc.py --root <out>/assets/audio/modern --folders music,ui --no-import`: **29 Klänge, 0 Fehler** (Musik 18,41 MB
  von 25 MB). Die bisher nie benutzten Pfade (`apply_prefs`, Höhen-Kuhschwanz im Master, `gain_db` im Manifest) arbeiten.
- Alle Stücke gleich verschoben: 40–60 Hz −0,7 bis −0,9 dB (der schwache `sub_db`), 5–8 kHz −0,9 bis −1,2, 8–12 kHz −1,4
  bis −1,6, über 12 kHz −1,5 bis −1,7 dB, 60 Hz – 2 kHz +0,2 bis +0,4 dB; Neigung 1–10 kHz bei „Linke Spur“ −0,55 →
  −1,16 dB/Okt (Referenz −2,53). True Peak nach Vorbis −1,25 bis −2,08 dBTP; `gain_db` = +1 bei Rennstücken, Schlüssen
  und Stingern, 0 bei Titel und Zwischenspiel.

**Kann man nur Mischung und Master neu laufen lassen?** (Code gelesen, nicht geändert)
- `race_lib.render()` / `linke_spur.render()` synthetisieren jede Spur und mischen sie sofort im `Mixer` (Spur für Spur,
  danach verworfen); `Master.pre()`/`fit_gain()` arbeiten auf der fertigen Mischung im Speicher. **Nichts wird
  zwischengespeichert** – weder die Spuren noch die Mischung vor dem Master.
- `sub_db`, `bass_db` greifen im `Mixer` (Lautheitsziel der Spur) → brauchen die Spuren → **immer ganzer Lauf**.
- `high_shelf_db/_hz` (und ein künftiges `low_shelf_db`) greifen nur im `Master` → mit einem Zwischenspeicher der Mischung
  vor dem Master (je Stück ein Float32-Array, ≈ 60–75 MB, git-ignoriert, Schlüssel = Quelltext-Hash + `sub_db` + `bass_db`)
  ließe sich der Master allein in etwa einer Minute je Stück wiederholen (abgeleitet; heute nicht vorhanden).
- `race_music_db`, `menu_music_db`, `ui_db` ändern nur `gain_db` im Manifest – die Klangdateien bleiben bitgleich. Ein
  Schalter `render_all.py --manifest-only` bräuchte Sekunden. **Heute ist dafür ein ganzer Lauf nötig** (Doku 14.10).
- Schnellster Weg für Pegelurteile: die Laufzeitwerte in `config/game_config.json → audio.modern` (sofort, ohne Import).

## 6. Knopfblatt für heute Nacht

Ein Urteil – erster Griff ohne Rendern (Datei `config/game_config.json`, Block `audio.modern`; wirkt beim nächsten
Spielstart), zweiter Griff mit Rendern (`tools/audio/music/mischung.json`, danach `render_all.py` – 33 min gemessen –
und `godot --headless --import`). Zahlen „gemessen“ = an Skizzen, am ganzen Lauf oder an Aufnahmen gemessen, sonst
abgeleitet. Wenn mehrere Klang-Urteile kommen (Bass und Höhen): **alle in einen einzigen Render-Lauf**.

| Der Nutzer sagt | Sofort (Konfiguration) | Mit Rendern (mischung.json) | Wirkung | Nebenwirkung / Hinweis |
|---|---|---|---|---|
| „Musik im Rennen zu leise“ (unter Vollgas weg) – **Empfehlung** | `music.race_eq` → `[{"shelf":"low","hz":160.0,"db":-3.0}]`, `music.context_db.race` 1,0 → 0,8, `duck.depth_db` 4,5 → 3,0, `loudness.music_under_car_db` 8 → 6,5 | – | Musik unter Vollgas +1,5 dB, Teillast +0,6 dB (Formel); Melodie unter Vollgas 43 / 35 / 28 % → 63 / 58 / 52 % (130 / 200 / 250), Motor ≥ 95 % hörbar, Bass im Rennen −3 dB (T9, Modell) | Änderung von D29 (Nutzer/Leitung); mitändern: fester Wert 8,0 in `test_modern_mix.gd`, Live-EQ-Prüfung in `check_modern_audio.gd` (6.1) |
| … ohne Planänderung | nur `music.race_eq` und `music.context_db.race` wie oben | – | Melodie 51 / 40 % (130 / 250 Vollgas), Lautheit gleich | nur die Live-EQ-Prüfung mitändern |
| … weiter als die Empfehlung | `duck.depth_db` 2,5 (`music_under_car_db` 6,0) | – | 67 / 56 % | zusätzlich die beiden ≥-3-dB-Prüfungen und Vertrag §6 AU-E |
| „Musik im Rennen zu leise“ (überall) | `music.context_db.race` 1,0 → 3,0 und `loudness.music_under_car_db` 8 → 6 | `race_music_db` +2 (nur Manifest, ganzer Lauf) | +2 dB in allen Zuständen; Leerlauf −19,6 → −17,6 LUFS | bei 80 km/h dann 4,6 dB über dem Auto; Plan-Prüfung mitändern |
| „Musik im Rennen zu laut“ | `music.context_db.race` 1,0 → −1,0 und `loudness.music_under_car_db` 8 → 10 | `race_music_db` −2 | −2 dB überall; Melodie unter Vollgas 41 / 33 / 27 % → 30 / 20 / 14 % (T8) | unter Vollgas kaum noch Melodie; Plan-Prüfung mitändern |
| „Musik übertönt den Motor“ (Stadt, 80–130 Teillast) | `music.context_db.race` 1,0 → 0,0 und `loudness.music_under_car_db` 8 → 9 | – | −1 dB in allen Zuständen | Motor dort heute schon 96–98 % hörbar (Modell). Nur bei mittlerem Tempo absenken geht mit keinem einzelnen Schlüssel: `duck.from_lufs` muss über `idle_lufs` (−24) bleiben (Plan-Prüfung) |
| „zu viel Bass“ / „dröhnt“ (Kopfhörer) | nur im Rennen: `music.race_eq` wie oben (Tiefen −3 dB unter 160 Hz) | **neuer** Schlüssel `low_shelf_db` −3, `low_shelf_hz` 120 (eine Zeile in `music_lib.Master.__init__` + `PREFS_DEFAULT`) | gemessen (Skizze): 25–80 Hz −1,7 … −2,1 dB, über 250 Hz +0,8 … +0,9 dB → Balance −2,9 dB | `sub_db` allein reicht nicht (siehe nächste Zeile); Renn-EQ: Live-EQ-Prüfung mitändern |
| „zu viel Tiefbass / Druck ganz unten“ | wie oben | `sub_db` −3 (stärker −6) | gemessen: 40 / 50 Hz −2,1 / −2,6 dB (−6: −3,8 / −5,2), 63 Hz unverändert, Rest +0,2 | wirkt nur auf den gefalteten Sub und die Sub-Kick-Schicht |
| „zu wenig Bass“ | `music.race_eq` 2. Eintrag 180 Hz +2,2 → +4,0 (nur Rennen) | `sub_db` +3 oder `low_shelf_db` +2 | gemessen `sub_db +3`: 40/50 Hz +2,3/+2,5 dB, Rest −0,3 bis −0,4 | auf Deck-Lautsprechern (unter ≈ 180 Hz stumm) wirkungslos – dort hilft nur Pegel; Renn-EQ: Live-EQ-Prüfung mitändern |
| `bass_db` | – | **nicht verwenden** | gemessen `bass_db −3`: ≤ 0,6 dB in jedem Band | Knopf wirkt kaum (abgeleitet: die Kick mit ihrem 60-Hz-Körper beherrscht 50–100 Hz) |
| „zu schrill“ / „zischelig“ / „anstrengend“ | nur im Rennen: `music.race_eq` + `{"shelf":"high","hz":5000.0,"db":-2.0}` | `high_shelf_db` −3, `high_shelf_hz` 4000 (milder: −2 bei 6000) | gemessen: −3 @ 4 k → 5–8 k −2,1, > 8 k −2,5 dB, darunter +0,4; −2 @ 6 k → 5–8 k −0,9, > 8 k −1,5 … −1,7 | bleibt 1,4–3,8 dB heller als die Referenz; Breite (Seite) bleibt – dafür `Master._ms` (Code); Renn-EQ: Live-EQ-Prüfung (5 kHz) mitändern. Im ganzen Lauf gemessen: −2 @ 5 kHz → 5–8 k −0,9 … −1,2, > 8 k −1,4 … −1,7 dB in allen Stücken |
| „zu dumpf“ | – | `high_shelf_db` +1,5 (6000) | abgeleitet: > 8 kHz etwa +1,2 dB | schon heute +3,5 … +6,3 dB über der Referenz – unwahrscheinlich |
| „Menü zu laut / zu leise“ | `music.context_db.title`, `.menu`, `.race_menu`, `.result` je −1 → −3 bzw. +1; dazu `loudness.menu_music_lufs` −20 → −22 bzw. −18 | `menu_music_db` −2 / +2 | Menü −20,1 → −22,1 bzw. −18,1 LUFS | Ergebnis-/Etappenbildschirme folgen mit (Zwischenspiel); Plan-Prüfung (± 0,25 dB) |
| „Klicks/UI zu laut / leise“ | `levels.MUI` 0 → −3 / +3 | `ui_db` | ±3 dB auf alle Klänge des Busses `MUI` (Menüklänge und Countdown-Pieptöne) | heute 13–28 dB über der Mithörschwelle der Menümusik |
| „Tank leer / Erwischt geht unter“ | `music.sting_duck_db` −9 → −12 (der Director liest ihn) | – | +3 LU Abstand aller Stinger zur abgesenkten Musik | Musik darunter 3 dB tiefer |

Ausprobieren ohne Build: dieselben Schlüssel in einer `game_config.json` neben der ausführbaren Datei (bzw. unter
`user://`) – `ConfigLoader.load_merged()` mischt sie über die Standardwerte (Code gelesen), z. B.
`{"audio": {"modern": {"duck": {"depth_db": 3.0}, "music": {"context_db": {"race": 0.8}}}}}` (die Prüfungen lesen
`config/game_config.json`, nicht diese Datei).

### 6.1 Prüfungen, die bei einer Pegel- oder EQ-Änderung mitgehen müssen (Code gelesen)

| Prüfung | hält fest | betroffen von |
|---|---|---|
| `tests/unit/audio_modern/test_modern_mix.gd` (Plan) | `loudness.music_under_car_db` **genau 8,0**; `−14 + context_db.race − 1,5 + Regler − duck.depth_db` = `full_throttle_lufs − music_under_car_db` ± 0,6 dB; Menü/Titel `−14 + context_db + Regler` = `menu_music_lufs` ± 0,25 dB | jede Änderung von `duck.depth_db`, `context_db.race` (> 0,6 dB) oder `context_db.title/menu` (> 0,25 dB) – dann `loudness.*` (Plan, Vertrag D29) und den festen Wert 8,0 im Test mitändern |
| `tests/unit/audio_modern/check_music.gd` („race“) und `check_modern_audio.gd` („mix“) | Musik unter Vollgas ≥ 3 dB abgesenkt (Vertrag §6 AU-E) | `duck.depth_db` unter 3,0 |
| `tests/unit/audio_modern/check_modern_audio.gd --live` | Renn-EQ: Töne 62 / 500 / 5000 Hz verlieren 1,0 / 3,0 / 0,0 dB (± 0,4 / 0,4 / 0,3) | jede Änderung von `music.race_eq` |
| `tests/unit/audio_modern/test_modern_buses.gd` | Renn-EQ-Filter wie in der Konfiguration | passt sich selbst an |
| `audio_qc.py --determinism` | Generatoren byte-gleich mit dem Repository | jede Änderung von `mischung.json` – nach dem Lauf von `render_all.py` sind Repository und Generatoren wieder gleich |

## 7. Was ein Mensch beurteilen muss

- Ob die Melodie unter Vollgas fehlen darf („Musik als Teppich“, Plan D29) oder hörbar sein soll (Befund 1) – das ist
  eine Geschmacksfrage; die Messung sagt nur, dass sie heute meist verdeckt ist.
- Bass auf Kopfhörern: der 50–63-Hz-Höcker kann „drücken“ oder „dröhnen“ – über Stunden eher ermüdend (abgeleitet,
  nicht messbar).
- Höhen und Breite über 2 kHz auf Kopfhörern über Stunden („luftig“ oder „zischelig“).
- Die Rennmusik auf den Deck-Lautsprechern (Befund 4) – dort ist sie unter Vollgas 1,3–2,2 dB leiser gegenüber dem Auto.
- „Tank leer“ (dunkel, leise): melancholisch genug oder zu unauffällig.
- Ob drei Stücke reihum über Stunden genügen.

## 8. Methode, Grenzen, Dateien

- Dateien: alle `assets/audio/modern/{music,ui}` und `assets/audio/music/title_theme.ogg` (Referenz v0.5.0), über ffmpeg
  dekodiert (`ana/measure_files.py`, Ergebnis `res/files.json`). Spektren: Welch, 32768 Punkte, Terzen nach Basis 2.
- Spielmix: `ana/mix_speeds.gd` + `ana/cap_runs.sh` (sieben Aufnahmen, je 75 s Echtzeit, Dummy-Treiber; dessen
  Zeitversatz bis 0,4 s ist durch 2 s Rand je Phase abgefangen), `ana/phase_loud.py`; Aufnahmen in `cap/*.wav`.
- Maskierung: `ana/masking.py`, `ana/masking_run.py`, `ana/eq_alt.py`, `ana/eq_alt2.py` (`res/masking.json`,
  `res/eq_alt.json`, `res/eq_alt2.json`). Grenzen:
  Bandmodell ohne Zeitmaskierung und ohne binaurale Entmaskierung; die Melodie ist als Band 510 Hz – 3,2 kHz angenähert
  (Grundtöne der Hooks D5–F6 bzw. bis A6 laut Partitur und deren zweite Harmonische), nicht als eigene Spur. Die
  Prozentwerte sind Vergleichsgrößen, keine Hörversuche.
- Knöpfe: `ana/knobs.sh` + `ana/knobs_ana.py` (Skizze „Linke Spur“, 16 Takte, in der Kopie; `mischung.json` und für die
  zwei Kuhschwanz-Experimente `music_lib.py` der **Kopie** kurz geändert und wiederhergestellt; `res/knobs.json`).
- Übergänge: `ana/transitions.py` (`res/transitions.json`), im Spiel `check_music.gd --only=interactive`.
- Ganzer Lauf: `ana/chain2.sh`, `ana/chain3.sh` (Logs `logs/render_all*.log`, `logs/qc_cand.log`), Vergleich
  `ana/cand_compare.py` → `res/cand_compare.json`. Die Kopie, die Skizzen-WAVs und die Kandidaten-Dateien sind danach
  gelöscht (Platz); die Messwerte stehen in `res/`.
- Bilder (alle in diesem Ordner): `bild_1_terzspektrum_gegen_referenz.png`, `bild_2_abweichung_zur_referenz.png`,
  `bild_3_stereo_korrelation.png`, `bild_4_spielmix_pegel.png`, `bild_5_maskierung_hook_je_band.png`,
  `bild_6_pegel_sweep.png`, `bild_7_knopf_wirkung.png`, `bild_8_kurzzeitlautheit.png`.
- Arbeitsordner: `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-MISCHUNG/`
  (`ana/` Skripte, `res/` Rohdaten, `logs/`).

## 9. Vertragspunkte (contract issues)

1. **D29 gegen hörbare Melodie**: Der Plan „Musik 8 dB unter dem Auto bei Vollgas“ ist erfüllt (gemessen 7,4–8,0 dB), lässt
   nach dem Modell aber nur 27–41 % der Melodie hörbar. Ob die Musik unter Vollgas ein Teppich sein soll oder ihre Melodie
   tragen, ist eine Entscheidung für Gate 1 (Nutzer); jede Pegeländerung unter Vollgas ist eine Änderung von D29 und
   braucht die Plan-Prüfung (6.1) mit.
2. **`mischung.json` hält nicht, was die Schlüssel versprechen** (AU-D2, Doku 14.10): `sub_db` wirkt nur auf 40–50 Hz,
   `bass_db` kaum, die Kick (größter Basshöcker) hat keinen Knopf. Für „zu viel/zu wenig Bass“ fehlt ein wirksamer
   Schlüssel; Vorschlag `low_shelf_db`/`low_shelf_hz` (gemessen in der Kopie).
3. **Pegel an zwei Stellen mit zwei Eigentümern**: Musikpegel im Rennen und im Menü stehen sowohl in `mischung.json`
   (AU-D, ganzer Render-Lauf für eine Manifest-Zahl) als auch in `config/game_config.json → audio.modern` (in diesem Schub
   AU-C1, danach AU-C2/AU-E). Die Leitung sollte festlegen, wer heute Nacht `audio.modern` ändern darf.
4. **Renn-EQ (AU-A) arbeitet gegen die Melodie**: er senkt 500–1250 Hz um 1,2–3,1 dB, obwohl das Auto in jedem Zustand
   ≥ 96 % hörbar bleibt; der Platz für den Motor wäre unter 160 Hz billiger zu haben (T9). Die Live-Prüfung hält die
   heutige Kurve fest (6.1).

## 10. Für die Überarbeitung und die Nächsten

- Eine Render-Runde für alles, was den Klang der Dateien ändert (Bass, Höhen), dazu im selben Lauf in `linke_spur.py` die
  bekannte offene Korrektur `race_lib.phrase_end()` (Doku 14.14) – danach ist die Bitgleichheit zu den Hörproben ohnehin
  weg.
- Pegel und Renn-EQ nur über `audio.modern` (Abschnitt 6), mit den Prüfungen aus 6.1 im selben Commit.
- Werkzeug-Kandidaten für AU-E: `ana/mix_speeds.gd` (Spielmix bei festen Tempi auf echter Strecke mit Feed),
  `ana/masking*.py` (Maskierung je Frequenzgruppe), `ana/knobs.sh` (Knopf-Wirkung an einer Skizze in 35 s).
- Mit Verkehr (AU-C2) wird die Musik zusätzlich verdeckt – die Messung von Abschnitt 4 mit Verkehr wiederholen.
- Steam Deck: Rennmusik auf den eingebauten Lautsprechern und auf Kopfhörern hören lassen (Befund 4).
