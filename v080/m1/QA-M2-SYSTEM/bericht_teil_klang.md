## 2. Klang

Hier hört niemand zu: alles unten ist an Dateien **gemessen**; wie es klingt, ist **abgeleitet** bzw. Sache des Nutzers.

**Messweg.** Ein Echtzeit-Mitschnitt ohne Bildschirm (`capture_mix.gd`-Weg) lief unter der Last dieser VM (13–20 auf 4
Kernen) 10 % zu kurz: Die WAV war 67,2 s lang, die Uhr lief 75 s – der Dummy-Treiber mischt bei CPU-Mangel weniger
als Echtzeit, Zeiten im Protokoll und in der Datei laufen auseinander. Darum laufen alle Klangmessungen dieser Prüfung
im **Movie Maker** (`--write-movie`, `--fixed-fps 60`, `--audio-sync`): Der Klang wird im Gleichschritt mit den Bildern
gemischt, Protokoll und WAV haben eine Uhr, die Last kann nichts verschlucken. Damit der Movie Maker mit 44,1 kHz
mischt wie das Spiel (D26) und nicht mit seiner Vorgabe 48 kHz, liegt in der Prüfkopie eine `override.cfg`
(`editor/movie_writer/mix_rate=44100`). Bild: Arcade (Regel 4 – das Bild spielt für den Klang keine Rolle),
Klang: Modern, **Gesamtlautstärke 1,0**. Skripte: `gd/qa_race_sound.gd` (echte Rennszene mit Strecke, Verkehr und
`AudioFeed`; protokolliert Feed-Zustand, Einmalklänge, Ereignisse, Musik, Tempo je Bild), `bin/race_sound.sh`,
Auswertung `bin/race_sound_analyze.py` (BS.1770 und True Peak über `tools/audio/qc/qc_lib.py`).

**Kiel – Hamburg im echten Rennen** (Movie Maker, Gesamtlautstärke 1,0, Bild Arcade, Klang Modern; die Feed-Karte der
Etappe vorher aus `AudioFeed` berechnet: `gd/qa_feed_map.gd` → `sound/feed_map_kh.log`):

| Mitschnitt | was | True Peak / Lautheit | Befund (gemessen) |
|---|---|---|---|
| `rs_concrete` km 24,3 → 33,7, 0 → 174 km/h | Asphalt → **Betonplatten ab km 25,0** | −1,98 dBTP, −14,6 LUFS integriert | Belag wechselt bei km 25,02 genau wie in der Karte; auf Beton +7 dB 160–630 Hz-Rauschen gegen den Asphalt davor (andere Geschwindigkeit, vermischt), in der Hüllkurve eine Linie bei 14,1 Hz = 2 × v / 5 m bei 125,8 km/h (Plattenrhythmus); kein Aussetzer |
| `rs_koehlbrand` km 77,6 → 81,9 | **Köhlbrandbrücke**, Stahldeck km 78,0–80,61 | −4,54 dBTP, −16,3 LUFS | **4 Fugen** gespielt bei km 78,01 / 79,02 / 80,01 / 80,62 = Fugen der Strecke (78,0 / 79,0 / 80,0 / 80,61), jede als Spitze +5,2 … +10,3 dB über dem Median der Hüllkurve (±1 s); auf dem Deck +9 dB bei 630 Hz – 2,5 kHz, +7 dB bei 2,5 – 10 kHz gegen Asphalt; die zwei „Knack-Kandidaten“ des Detektors sind genau zwei dieser Fugen |
| `rs_cobbles` km 86,6 → Ziel 95,2 | **Hamburger Altstadt**: Pflaster und Asphalt im Wechsel | −1,55 dBTP, −15,4 LUFS | Wechsel genau an den Blöcken der Karte (87,01 P / 87,82 A / 88,71 P / 89,61 A / 90,51 P / 92,31 A / 94,11 P); bei gleichem Tempo (45–50 km/h) Pflaster gegen Asphalt **+3,6 … +4,6 dB bei 160–630 Hz und +5,8 … +7,6 dB bei 2,5–10 kHz** – deutlich im Spektrogramm; Etappe im Ziel (`stage_finish`) |
| `rs_crash` km 30, 220 km/h ohne Autopilot in die rechte Spur | Blitzer → Verfolgung (Martinshorn) → **schwerer Aufprall** bei 174 km/h → „busted“ | Aufprall-Fenster −4,56 dBTP, ganze Aufnahme −1,93 dBTP | Schichten `crunch`, `debris`, `hit_heavy`, `collision_heavy` (schwere Stufe); **≤ −1 dBTP bei Gesamtlautstärke 1,0 erfüllt** (A-14) |
| `rs_crash2` km 40, 240 km/h, mittlere Spur | zweiter schwerer Aufprall bei t 9,3 s | Fenster −4,06 dBTP, ganz −2,13 dBTP | wie oben; danach steht das Auto im Leerlauf (siehe Knack-Kandidaten unten) |
| `rs_arcade_koehlbrand` | dieselbe Fahrt mit Profil **Arcade** | −4,51 dBTP, −20,9 LUFS | keine Fugen, keine Feed-Ereignisse (Arcade hört nichts davon – unverändert); Modern bei gleicher Fahrt 4,6 LU lauter |

Spektrogramme mit Belagstreifen und Fugen-/Aufprallmarken: `klang_kiel_hamburg_spektrogramme.png`.

**Knacken.** Der allgemeine Detektor (Blocksprung > 4 × Umgebung) meldet in den Fahrten 1–4 Kandidaten je Mitschnitt;
jeder angesehen (`bin/click_inspect.py`, Wellenform ±15 ms): Fugen, ein Plattentransient, zwei tieffrequente Stöße
(Vorbeifahrt) – **kein Sprung im Signal** (Schritt ≤ 3,1 × p99 der Umgebung, Hüllkurve davor und danach gleich). Im
**Leerlauf nach einem Unfall** (Tempo 0) meldet er 19 bzw. 87 Kandidaten: Jeder Zündstoß trägt an seiner fallenden Flanke
einen 1,5-ms-Klingler über 8 kHz (`sound/rs_crash2_click_21.00.png`) – Textur des Motors, kein Sprung; die Prüfung von
M1 fand dasselbe im Arcade-Leerlauf. Ob man das als Ticken hört, ist abgeleitet bzw. Sache des Nutzers.

**Begrenzer und Stinger im echten Rennen** (Movie Maker, Gesamtlautstärke 1,0):

| Mitschnitt | Ergebnis (gemessen) |
|---|---|
| `rs_concrete` gegen `rs_concrete_nolim` (derselbe Lauf mit `audio.modern.limiter.enabled = false` über `user://game_config.json`) | Ohne Begrenzer True Peak −1,74 dBTP / Abtastspitze −1,77 dBFS; Absenkung durch den Begrenzer höchstens **0,86 dB** (beim Anfahren mit Vollgas, t 0,8 s), p95 0,25 dB, 5 von 600 50-ms-Blöcken über 0,5 dB – beim Reisen auf Beton greift er kaum (A-14). Die zwei Läufe sind nicht bitgleich (Median der Abweichung leiser Blöcke 0,09 dB): Zahlen ±0,1 dB |
| `rs_crash_music` – wie `rs_crash`, mit Rennstück | Stück „Linke Spur“ startet bei „LOS!“; „busted“ bei 15,13 s → **Stinger `linke_spur_polizei` bei 15,50 s** (nächster Schlag); True Peak gesamt −1,83 dBTP (Musik + schwerer Aufprall) |
| `rs_fuel_music` – `--fuel=0.004`, mit Rennstück | `out_of_fuel` bei 7,52 s → **Stinger `linke_spur_tank` bei 7,78 s**; Abschleppen bei 14,53 s |

**Pegelplan, Ducking, „Musik im Rennen“, Menüs** (`gd/qa_capture_mix.gd` = `tools/audio/modern/capture_mix.gd` mit
Movie-Maker-Uhr und `--race-music=0`; Standardregler, Gesamtlautstärke 0,8; Gran Turismo; `measure_mix.py`):

| Phase | Auto allein („Musik im Rennen: Aus“) | Musik allein (Auto stumm, Ducking folgt der Fahrt) | beides | Plan (D29) |
|---|---|---|---|---|
| Leerlauf | −23,96 LUFS | −18,43 | −17,13 | Auto −24, Musik −19,5 |
| Vollgas | −15,78 (Kurzzeit-Median −15,60, max −14,85) | −23,71 | −15,24 | Auto −16 ± 1,5, Musik 8 dB darunter (−24) |
| Vollgas am Anschlag | −14,42 | −23,70 | −14,11 | |
| Reisen 130 km/h | −21,47 | −21,47 | −18,74 | Auto −21 |
| Menü | Modern −21,2 integriert, Kurzzeit-Median −20,1 | | | −20 |
| Menü Arcade (v0.7.0-Titel, unverändert) | −29,5 | | | – |

Musik bei Vollgas **7,9 dB unter dem Auto** (Plan 8), Ducking Leerlauf → Vollgas 5,3 dB, „Aus“ = keine Musik im Rennen.
Beim Reisen mit 130 km/h ist die Musik so laut wie das Auto (0 dB darunter) – so gebaut (Ducking nach dem Fahrzustand),
ob das gefällt, entscheidet der Nutzer (abgeleitet).

**Musik über den echten Spielablauf** (`gd/qa_music_flow.gd` nach `tests/race/run_race.gd`: echter `GameFlow`, Rennen
Kiel – Nürnberg, Autopilot mit Countdown, kopflos mit spielenden Playern, Zeitraffer 6; jede Änderung des
`MusicDirector`-Zustands protokolliert, `bin/music_parse.py`):

| Lauf | Ergebnis (gemessen) |
|---|---|
| „Musik im Rennen: An“, 4 Etappen (512 s) | Etappenbildschirm: **Zwischenspiel**; Etappe 1 **Linke Spur** (#1), 2 **Nachtfahrt** (#2), 3 **Rückenwind** (#3), 4 wieder **Linke Spur** (#4) – Rotation 1 → 2 → 3 → 1; jedes Stück setzt mit „LOS!“ ein; im Ziel Schluss „normal“ und bei den Etappen 1–3 der Ziel-Stich (`*_ziel`), bei 4 der Schluss ohne Stich (Taktgrenze näher als `ZIEL_MIN_S`, so gebaut); Ergebnisbildschirm: das Stück klingt aus, das Zwischenspiel blendet in 0,6 s ein und läuft über Routenwahl und Etappenbildschirm ohne Neustart weiter. „rekord“ kam nicht vor, weil die Bestenlisten vorbelegte Zeiten haben, die der Autopilot nicht schlägt |
| „Musik im Rennen: Aus“, 2 Etappen (296 s) | in der Etappe **keine** Musik; im Ziel der Schluss des Stücks der Rotation als Ziel-Klang (`linke_spur_schluss`, dann `nachtfahrt_schluss` – so dokumentiert); Zwischenspiel zwischen den Etappen wie mit „An“ |
| Stinger in der Etappe (oben) | `busted` → `linke_spur_polizei`, `out_of_fuel` → `linke_spur_tank`, jeweils auf dem nächsten Schlag |

Keine Fehler- oder „leaked“-Zeile in allen Klangläufen (17 Prozesse).
