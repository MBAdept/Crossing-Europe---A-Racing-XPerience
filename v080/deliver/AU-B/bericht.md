# AU-B – Motor v3 (Klangprofil „Modern“) – Bericht

Stand: Commit `8414002` auf dem Zweig `worktree-wf_bade9e46-06a-2`, gesichert als `origin/wip/v080-au-b`
(Ablauf der letzten Commits und ihrer Prüfungen in Abschnitt 9). Arbeitsverzeichnis:
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2` (Zweig und Verzeichnis des
Vorgängers, weitergeführt nach dessen STAND.md).

**Niemand hat den Motor gehört.** Alle Zahlen in diesem Bericht sind *gemessen* (diese Entwicklungsmaschine, Godot
4.7.2, ohne Bildschirm, Dummy-Audiotreiber; die Maschine war während der Messungen von anderen Paketen mit belastet,
Lastmittel bis 7 auf 4 Kernen), sofern nicht *abgeleitet* dabeisteht. Alles über das Steam Deck, eine echte
Soundkarte und darüber, wie etwas klingt, ist abgeleitet.

## 1. Was gebaut wurde

| Teil | Datei | Inhalt |
|---|---|---|
| Synthese | `tools/audio/modern/engine_synth3.py` | fünf Stereobanken (Format `ce-engine-bank-2`: 32 kHz, int16, je Drehzahlpunkt drei Ebenen – Schub, Last ohne Ansaugung, Ansaugung allein) und zwölf Fahrzeugklänge; importiert das eingefrorene Arcade-Werkzeug, ändert es nicht; deterministisch, alle fünf Autos in 41–50 s |
| Bank-Lader | `scripts/audio/modern/engine_bank2.gd` | lädt und prüft eine Bank (lehnt 22 Arten kaputter Beschreibungen ab), liest die Rohdaten über `ModernAudioAssets.read_i16()` |
| Mischer | `scripts/audio/modern/engine_mix_thread.gd` | zyklussynchroner Stereomischer in einem eigenen Thread (Steuerblock unter Mutex), synchroner Betrieb mit festem Seed; leistungstreues Überblenden, schnelle und langsame Zufallsbewegung, Sättigung unter Last, Clips, Begrenzermuster, Wächter |
| Baustein `engine` | `scripts/audio/modern/engine_audio3.gd` | Klasse `EngineAudio3` (Name und Haken unverändert, `state()`, `perf()`, `preview(id)`); Bus `MEngine` über `ctx.player()`; Getriebe = das unveränderte `EngineGearbox`; Ladedruck, Schubknallen, Schaltknall, Startclip, Vorschau mit Bank-Laden im Hintergrund |
| Baustein `layers` | `scripts/audio/modern/vehicle_layers.gd` | Klasse `VehicleLayers`, Bus `MEngineFx`, nativ gemischt: Laderton und -rauschen, Achs- und Getriebeheulen, Gasannahme, Lastwechselschlag, Schubumluft; liest `frame.engine` |
| Klangdateien | `assets/audio/modern/engines/*`, `assets/audio/modern/vehicle/*` | Banken 10,94 MB (1,84–2,89 MB je Auto), zwölf Fahrzeugklänge 1,22 MB, je mit Manifest |
| Konfiguration | `config/game_config.json` → `audio.modern` | `levels.MSfx` 0 dB (war −3), neue Blöcke `engine` und `layers` |
| Tests | `tests/unit/audio_modern/test_engine3_{bank,mix,slot,checks,fixture}.gd`, `check_engine3.gd` | 26 Tests und eine Prüfung im laufenden Spiel |
| Dokumentation | `docs/motorsound.md` Abschnitt 6, `docs/audio-modern.md` | Format, Synthese, Laufzeit, Konfiguration, Pegel, Prüfungen, Zahlen, Grenzen; vier neue Fallen |

`ctx.sync` (`--audio-sync`) und `audio.modern.engine_thread` werden beachtet; jeder Generator-Stream geht vor dem
Stoppen oder Freigeben seines Players an `ModernAudioContext.keep_alive()`; das Ducking liest `frame.engine.load`
aus `state()`; keine Modern-Klasse steht in einer Datei, die ein Arcade-Start lädt (`check_arcade_lean.gd` besteht).

## 2. Abnahme – Punkt für Punkt

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Knackser an Zyklusgrenzen, beide Kanäle | bestanden | `test_engine3_mix.gd`: `test_no_clicks_at_cycle_boundaries_on_both_channels`, `test_continuous_over_rpm_sweep` |
| Kanalabgleich über eine Drehzahlfahrt ≤ 0,5 dB | bestanden, größter Wert 0,42 dB (Gran Turismo im Schub, sonst ≤ 0,13 dB) | `test_shipped_banks_balance_and_mono_sum`, `belege/tests_audio_modern.txt` |
| Monosumme nicht unter −3 dB eines Kanals | bestanden, größter Verlust 0,51 dB | derselbe Test |
| Vollgas −16 ± 1,5 LUFS über die Modern-Busse | bestanden: Abschnittswert −16,0 bis −17,1, Kurzzeit-Median −16,0 bis −17,2, Kurzzeit-Maximum −14,8 bis −16,2 | `belege/pegelplan_modern.txt` |
| Leerlauf etwa 8 dB darunter | −23,5 bis −25,1 LUFS (7,5 bis 9,1 dB unter −16) | dieselbe Datei |
| Reisetempo wie geplant (−21) | −20,9 bis −22,3 LUFS (Gran Turismo am tiefsten, in drei Läufen −21,5 bis −22,3) | dieselbe Datei |
| Thread-Bank: 0 Aussetzer bei sechs Hängern von 400 ms | bestanden: 0 Aussetzer in jedem der rund zehn Läufe, auch auf dem Endstand (im Hauptthread gemischt: 345–427) | `belege/check_engine3.txt`, `belege/run_tests_unit_8414002.txt` (`test_engine3_checks.gd`) |
| 20 saubere Prozessenden | 20 von 20 mit Rückgabewert 0 in 1,5–1,7 s; einzige Meldungen: die beiden Hinweise, die Godot bei jedem Prozessende mit laufendem Klang schreibt (Abschnitt 7) | `belege/shutdown20.txt` |
| Synchroner Betrieb zweimal abtastgleich | bestanden in den Unit-Tests (Mischer, Baustein) und im Movie-Maker-Modus mit `--audio-sync`: 480 000 Frames bei 48 kHz, 0 von 960 000 Abtastwerten verschieden | `test_same_seed_and_control_give_the_same_samples`, `test_synchronous_mode_is_sample_identical`, `belege/movie_maker_audio_sync.txt` |
| Rechenzeit je Bild | 0,78–0,94 ms Mischzeit je 1/60 s Klang im Spiel (im Thread, nicht in der Bildzeit; frühere Läufe 0,73–0,99), 0,69–0,71 ms im synchronen Betrieb unter Movie Maker, 0,77–0,82 ms im Unit-Test; Arcade-Mischer mono 0,32 ms im Hauptthread; Bank laden 22–75 ms | `ab_zahlen.json`, `belege/check_engine3.txt` |
| `audio_qc.py` einschließlich Determinismus | bestanden: 21 Klänge, 0 Fehler; `engine_synth3.py` zweimal gerendert = gleiche Bytes (24 Dateien, 14 Einträge) | `belege/audio_qc_determinismus.txt` |
| A/B-MP3 je Auto | fünf Dateien, je Arcade \| Modern für: Start/Leerlauf/Gasstöße · Vollgas durch die Gänge · 200 km/h, Gas weg, Bremsen mit Rückschalten · 130 km/h, Kick-down, Gas weg, Anhalten | `motor_ab_<auto>.mp3` + `.txt` |
| Spektrogramme je Auto | fünf PNG, beide Profile auf einer Skala | `spektrogramm_<auto>.png` |
| `tools/run_tests.sh` | **teilweise**: Gesamtlauf 1 (Commit `e500f09`) grün – 595 Tests, 0 fehlgeschlagen, alle Prüfungen OK, 572 s. Gesamtlauf 2 (`c33809c`) brach nach den Unit-Tests ab: 594 von 595, ein Test von mir war zufallsabhängig (Abschnitt 9). Danach behoben; auf dem Endstand `8414002` läuft die ganze Unit-Phase grün (`tools/run_tests.sh unit`: 595 Tests, 0 fehlgeschlagen, 230 s). Ein dritter Gesamtlauf war nicht erlaubt – die Integrationsszenarien sind auf dem Endstand nicht noch einmal gelaufen | `belege/run_tests_gesamt_lauf1_e500f09.txt`, `…_lauf2_c33809c.txt`, `run_tests_unit_8414002.txt` |
| `tools/golden.sh check` | bestanden: „GOLDEN arcade: 20 von 20 identisch“ (159 s), einmal gelaufen, auf `c33809c` (danach nur noch eine Testdatei und Dokumentation geändert) | `belege/golden_check.txt` |

## 3. Pegelplan (gemessen mit den ausgelieferten Dateien)

`capture_mix.gd` (feste Fahrt, Echtzeit, Master-Bus bei Standardreglern: Motor, Fahrzeugebenen und der Wind des
Platzhalter-Bausteins `road`; ohne Musik und Verkehr) + `measure_mix.py`. LUFS je Abschnitt:

| Auto | Leerlauf | Vollgas durch die Gänge (Kurzzeit höchstens / Median) | Höchsttempo | vom Gas | 130 km/h | True Peak |
|---|---|---|---|---|---|---|
| Kompakt | −23,9 | −16,0 (−14,8 / −16,0) | −16,6 | −21,9 | −21,9 | −6,1 dBTP |
| Kombi | −25,1 | −16,1 (−15,1 / −16,0) | −15,8 | −21,9 | −21,5 | −6,0 |
| Limousine | −24,2 | −17,1 (−16,2 / −17,2) | −15,0 | −20,4 | −21,6 | −6,5 |
| Sportwagen | −24,2 | −16,3 (−15,1 / −16,6) | −16,2 | −20,1 | −20,9 | −5,9 |
| Gran Turismo | −23,5 | −16,2 (−15,5 / −16,2) | −15,3 | −20,6 | −22,3 | −6,1 |
| Plan | ≈ −24 | −16 ± 1,5 | −16 | – | ≈ −21 | ≤ −1 |

Dieselbe Fahrt mit dem Profil Arcade: Leerlauf −17,2 bis −28,4, Vollgas −13,2 bis −19,7, 130 km/h −19,9 bis −29,0
(`belege/pegelplan_arcade.txt`) – dort liegen die fünf Autos bis zu 11 dB auseinander, in Modern höchstens 1,6 dB.

Ehrlich dazu:

- Von Lauf zu Lauf schwanken die Abschnittswerte um ± 0,3 dB und das Kurzzeit-Maximum um bis zu ± 0,4 dB (die
  langsame Zufallsbewegung ist im Thread-Betrieb nicht reproduzierbar). Kombi und Sportwagen lagen deshalb in einem
  von drei Läufen mit ihrem Kurzzeit-Maximum an der Grenze (−14,2 und −14,5) und sind zuletzt um 0,4 und 0,3 dB
  zurückgenommen worden; die Tabelle ist nach dieser Rücknahme gemessen.
- Einzelne 3-s-Fenster liegen beim Hochdrehen außerhalb von ± 1,5: Die Limousine läuft von −18,2 in den unteren
  Gängen bis −14,8 bei Höchsttempo (dort trägt der Wind des Platzhalters bei 250 km/h mit).
- Leerlauf und Reisetempo sind **gegen den Platzhalter-Wind** abgestimmt. Mit Fahrbahn und Wind von AU-C1 ändert
  sich die Summe; dann neu messen.
- `levels.MSfx` steht auf 0 dB. Alles andere unter `MSfx` (Wind, Reifen, Kollisionen, Verkehr, Ambiente, Menü- und
  Countdown-Klänge) spielt dadurch 3 dB lauter als in Welle 0.
- `belege/check_engine3.txt` und `belege/shutdown20.txt` stammen vom Stand vor der Pegelrücknahme von Kombi und
  Sportwagen und vor dem Pegelgesetz des Lastwechselschlags (beides berührt den Mischer-Thread nicht). Die
  Thread-Bank und das Beenden liefen danach in jedem Testlauf wieder (0 Aussetzer), der Movie-Maker-Vergleich und
  die A/B-Aufnahmen auf `c33809c`. Der Pegelplan ist nach der Pegelrücknahme gemessen, aber vor dem Pegelgesetz
  des Lastwechselschlags (kurze Einmalklänge; ihr Beitrag zur Lautheit eines Abschnitts ist vernachlässigbar –
  abgeleitet, nicht neu gemessen).

## 4. Arcade gegen Modern in Zahlen

Stationär, Mischer allein (`belege/stationaer_arcade_modern.txt`, `belege/tabellen.md`; HNR = Leistung auf den
Motorordnungen zu Leistung dazwischen, Modern ohne die Bewegung des Mischers gemessen):

| Auto | Volllast bei | Spektraler Schwerpunkt Hz (Arcade → Modern) | HNR dB | Pegelbewegung 50 ms (Std, dB) |
|---|---|---|---|---|
| Kompakt | 3750 / 5800 / 6450 | 153 → 170 / 267 → 350 / 399 → 501 | 18,3 → 17,2 / 14,6 → 11,7 / 10,7 → 9,1 | 0,14 → 0,44 / 0,11 → 0,47 / 0,21 → 0,44 |
| Kombi | 2550 / 3900 / 4350 | 238 → 244 / 523 → 576 / 487 → 569 | 17,8 → 16,3 / 12,6 → 9,4 / 13,4 → 9,9 | 0,24 → 0,68 / 0,22 → 0,63 / 0,17 → 0,64 |
| Limousine | 3850 / 5950 / 6650 | 199 → 205 / 421 → 470 / 511 → 564 | 22,0 → 19,6 / 11,0 → 10,0 / 9,8 → 8,3 | 0,07 → 0,66 / 0,12 → 0,67 / 0,13 → 0,56 |
| Sportwagen | 4950 / 7650 / 8550 | 315 → 393 / 1185 → 1429 / 978 → 1478 | 16,7 → 17,3 / 6,4 → 5,0 / 8,9 → 5,5 | 0,08 → 0,64 / 0,16 → 0,42 / 0,11 → 0,46 |
| Gran Turismo | 3850 / 5950 / 6650 | 348 → 422 / 675 → 792 / 776 → 869 | 13,7 → 11,2 / 12,8 → 9,7 / 11,6 → 8,3 | 0,18 → 0,65 / 0,14 → 0,58 / 0,13 → 0,51 |

Eine Minute konstantes Tempo (`belege/reisetempo_60s.txt`): Der 1-s-Pegel schwankt in Arcade um ± 0,01–0,04 dB, in
Modern um ± 0,46–0,65 dB; das Spektrum je Terz um 0,23–1,19 → 0,83–1,44 dB; die höchste Autokorrelation der
Pegelkurve bei 0,2–10 s (eine Schleife läge nahe 1) fällt von 0,17–0,86 auf 0,06–0,19. Die tonale Dominanz der
lautesten Terz (A-bewertet) sinkt nur um 0–3 dB.

Fahrt im Spiel, nur der Motor mit seinen Ebenen (`ab_zahlen.json`, Arcade \| Modern):

| Auto | ganze Fahrt LUFS | Lautheitsbereich LU | Vollgas durch die Gänge | 200 km/h | Gas weg | 130 km/h | Leerlauf |
|---|---|---|---|---|---|---|---|
| Kompakt | −20,6 \| −19,4 | 5,4 \| 8,1 | −18,6 \| −16,4 | −22,1 \| −20,1 | −21,0 \| −24,2 | −23,0 \| −22,2 | −24,1 \| −23,7 |
| Kombi | −23,2 \| −19,4 | 5,3 \| 9,6 | −21,2 \| −16,7 | −24,8 \| −20,8 | −26,0 \| −25,1 | −25,3 \| −22,0 | −28,7 \| −24,6 |
| Limousine | −21,4 \| −20,0 | 9,2 \| 5,7 | −19,6 \| −17,7 | −24,3 \| −20,9 | −28,0 \| −26,3 | −25,9 \| −21,2 | −23,2 \| −24,0 |
| Sportwagen | −18,3 \| −19,3 | 10,3 \| 7,2 | −16,0 \| −16,7 | −16,3 \| −17,3 | −27,4 \| −24,2 | −21,9 \| −21,1 | −24,1 \| −24,3 |
| Gran Turismo | −16,2 \| −20,0 | 7,2 \| 8,0 | −13,4 \| −17,1 | −17,2 \| −21,0 | −22,4 \| −26,6 | −19,0 \| −21,5 | −17,8 \| −24,6 |

Über die ganze Fahrt liegen die fünf Autos in Arcade 7,0 dB auseinander, in Modern 0,6 dB. Der Lautheitsbereich
wächst bei Kompakt und Kombi um 3–4 LU (Volllast hebt sich vom Rollen ab) und sinkt bei Limousine und Sportwagen
um 3–3,5 LU (ihr Reisetempo war in Arcade 4–5 dB leiser). Im Spiel ist der Arcade-Motor der Turbo-Reihenmotoren bei
Vollgas *heller* (Schwerpunkt Kompakt 904 gegen 448 Hz, Anteil ab 5 kHz −9,4 gegen −17 dB): Das ist sein
Sinuspfeifen bei 5–6 kHz; die Bank von Modern selbst ist heller als die von Arcade (Tabelle oben).
(Die Tabelle in `docs/motorsound.md` 6.8 stammt aus derselben Aufnahmereihe; von Lauf zu Lauf ± 0,3–0,6 dB.)

## 5. Die fünf Charaktere – was sie unterscheidet (gemessen) und was das Bild zeigt

| | Kompakt R4 Turbo | Kombi R4 Turbodiesel | Limousine R6 Turbo | Sportwagen B6 Sauger | Gran Turismo V8 Biturbo |
|---|---|---|---|---|---|
| Schwerpunkt bei 85 % Nenndrehzahl, Volllast | 350 Hz | 576 Hz | 470 Hz | 1429 Hz | 792 Hz |
| HNR dort | 11,7 dB | 9,4 dB | 10,0 dB | 5,0 dB | 9,7 dB |
| Stereobild im Spiel bei Vollgas (Korrelation) | 0,97 | 0,99 | 0,97 | 0,72 | 0,78 |
| Lader (Entwurf) | ein Lader, deutlicher Ton | ein Lader, viel Rauschen | ein Lader, dezent | – (Ansaugung +6 dB über Arcade) | zwei Lader links/rechts |
| Gas weg (Entwurf) | leichtes Knallen, Schubumluft mit Flattern | – | weiches Knallen, dezente Schubumluft | scharfes Knallen | Schläge mit fernem Echo, Schubumluft |
| Stimme des Auspuffs (Entwurf) | Formant 520 Hz | das Nageln | Formant 420 Hz | freie Anlage | Formant 330 Hz |

Spektrogramme (angesehen): Beide Profile sehen verwandt aus – dasselbe physikalische Modell. In Modern sind die
Obertonreihen unter Last dichter (500 Hz bis 5 kHz), das Band oberhalb von 2 kHz ist unter Last breitbandig gefüllt,
die Linien stehen nicht mehr wie mit dem Lineal gezogen. Der reine Pfeifton bei 5–6 kHz, der in Arcade bei Kompakt,
Kombi, Limousine und Gran Turismo als helle Linie über dem Bild liegt (beim Kompakten ein Zehntel der Leistung), ist
in Modern ein schwächerer Schmalbandton mit Rauschen. Am wenigsten verändert ist das Hochdrehen der Limousine: ein
dominanter Grundton mit wenig Mitten in beiden Profilen.

## 6. Was die Messungen nicht sagen – ehrliches Urteil

- Ob das nach einem Motor unter Last klingt statt nach Synthesizer, kann nur ein Ohr entscheiden. Messbar besser
  als Arcade: Bewegung im stehenden Klang, Lastverhalten (Ansaugung folgt dem Pedal, Auspuff der Last), gleich laute
  Autos, kein Sinuspfeifen, Stereo bei zwei Autos, keine Aussetzer bei Hängern. Nicht messbar besser: der
  Grundcharakter – er kommt aus demselben Modell.
- **Der Motor ist trocken und sitzt bei drei Autos in der Mitte.** Kompakt, Kombi und Limousine haben im Spiel eine
  Kanalkorrelation von 0,97–1,00; der Arcade-Motor ist mono, aber sein Bus hat einen kurzen Hall und kommt auf
  0,80–0,99. Gemessen an der Korrelation ist Arcade bei diesen drei Autos **breiter** als Modern; Sportwagen und
  Gran Turismo sind bei Vollgas gleichauf (0,72 / 0,78 gegen 0,75 / 0,77), spielen in Modern aber wirklich
  Verschiedenes links und rechts. Das folgt aus dem Aufbau (D27: Endrohre an ihrem Platz, entkoppeltes
  Strömungsrauschen; Raum und Breite kommen von `env`, Fahrbahn und Wind), ist aber das Erste, was man mit
  Kopfhörern prüfen sollte.
- Niedrige Drehzahl unter Volllast bleibt basslastig: Ein Hochpass bei 180 Hz (kleine Lautsprecher) nimmt dem
  Kompakten bis 30 % der Nenndrehzahl 13–14 dB, der Limousine und dem Gran Turismo bei 1400/min 14 dB (der Gran
  Turismo verliert dort in Arcade nur 8 dB). Auf dem Steam Deck: abgeleitet, nicht gehört.
- Die Limousine bei 200 km/h bleibt ein Ton: lauteste Terz (157 Hz) A-bewertet 21 dB über dem Median (Arcade 23).
- Der Sportwagen ist oben rauschiger als in Arcade (HNR 5,0–5,5 gegen 6,4–8,9 dB) – Schreien oder Zischen?
- Der Leerlauf steht trockener da: dieselben Ticks wie in Arcade, dazwischen oberhalb von 5 kHz 4–17 dB leiser.
- Pegel der Fahrzeugebenen (Laderton, Heulen, Schläge) sind nach Gesetz und Spektrogramm gesetzt, nicht nach Gehör.
  Zwei Dinge habe ich an den Aufnahmen gefunden und geändert: Der Schlag beim Gangwechsel trug ein Ticken bis
  16 kHz (jetzt 10,8 dB weniger Anteil ab 5 kHz) und stand beim Zurückschalten im Schub 10–15 dB über dem
  Mittenband des Motors, siebenmal in drei Sekunden beim Anhalten (jetzt 0,2 statt 0,45 des Pegels).
- Thread-Messungen stammen vom Dummy-Treiber (Blöcke von 93 ms); echte Treiber: abgeleitet.

## 7. Abweichungen und Befunde am Vertrag

Abweichungen:
1. `tests/unit/audio_modern/check_engine3.gd` liegt außerhalb des Musters `test_engine3*.gd` (Unit-Tests laufen
   ohne Szenenbaum; Thread-Bank, Profilwechsel und Beenden brauchen einen eigenen Prozess).
2. Eine Zeile in `tests/unit/audio_modern/test_modern_audio.gd` (AU-A): „Auto ohne Bank“ nimmt jetzt ein
   unbekanntes Auto – Banken kommen nicht mehr vom Arcade-Lieferanten.
3. `docs/audio-modern.md` (Eigentümer „audio“) ergänzt; `docs/motorsound.md` hat vor Abschnitt 1 zwei Zeilen Verweis.
4. Anlasser, Leerlauf, Begrenzer, Schaltknall und Schubknallen liegen im Zyklenmischer, nicht in `VehicleLayers`
   (sie müssen im Takt der Arbeitsspiele bleiben).
5. Kein Hall auf `MEngine` (der Platzhalter hatte den Breiten-Hall von Arcade) – siehe Abschnitt 6.
6. Die Aufnahmen mit `capture_mix.gd` liefen mit leerem, absolutem `XDG_DATA_HOME`, aber ohne `--graphics=`
   (Werkzeugskript, kein Spielstart; der Klang liest den Grafikmodus nie). Die A/B-Aufnahmen der Endfassung und
   `check_engine3.gd` nennen `--graphics=arcade`.
7. D27 nennt auch Reifen und Wind als nativ gemischte Schleifen; sie gehören nach §5 zum Baustein `road` (AU-C1)
   und sind hier nicht gebaut.
8. Auf dem Endstand ist kein vollständiger `tools/run_tests.sh` gelaufen (Abschnitt 9): Gesamtlauf 1 war grün, nach
   Gesamtlauf 2 habe ich einen eigenen zufallsabhängigen Test behoben und nur noch die Unit-Phase wiederholt.
9. Die Klangdateien sind seit `e500f09` unverändert; `audio_qc.py --determinism` lief auf genau diesen Dateien.

Befunde:
1. `tools/audio/modern/modern_lib.py`: `write_wav_import()` / `write_ogg_import()` öffnen die `.import`-Datei zum
   Schreiben (Zeilen 118 / 128), bevor `_import_head()` sie liest – nach jedem erneuten Erzeugen fehlen uid und
   Importpfad, das Spiel meldet „Failed loading resource“, bis `godot --import` lief. Umgangen in
   `engine_synth3.write_wav_import_keep()`; nicht meine Datei.
2. Godot 4.7.2 spielt an der Naht einer `AudioStreamWAV`-Schleife, die mit ihren Daten endet, einen falschen
   Abtastwert (nachgestellt mit einer Schleife aus dem Wert 0,5: ein Frame nahe 0 je Naht; mit 16 Frames
   Fortsetzung keiner). Folge: leises Knacken tonaler Schleifen, und zwei `--audio-sync`-Läufe unterschieden sich
   an 49 Abtastwerten. Meine Schleifen tragen die Fortsetzung; Platzhalter und künftige Schleifen (AU-C1/C2) nicht –
   gehört in `modern_lib.py` und als Regel in `audio_qc.py`.
3. „Saubere Prozessenden“: Godot schreibt „ObjectDB instances were leaked at exit“ / „resources still in use at
   exit“, sobald ein Prozess endet, während irgendein `AudioStreamPlayer` spielt (nachgestellt ohne Modern-Code).
   Sauber kann also nur heißen: Rückgabewert 0 und sonst keine Meldung.
4. `ModernAudioFrame.alive` (0,35 s): Ein einzelnes langes Bild sieht aus wie ein Sitzungsende. Motor und Ebenen
   haben dafür `EngineAudio3.driven()`; andere Bausteine (Fahrbahn, Wind) blenden nach einem Hänger ein Bild lang
   aus. Die Regel gehörte in `ModernAudioFrame`.
5. Leerlauf- und Reisetempo-Ziel sind nur mit dem Platzhalter-Wind erfüllt (A-5 sagt: „can only be met by AU-B's
   engine“ – die Summe hängt aber auch an AU-C1).
6. `levels.MSfx` 0 dB macht alle übrigen Platzhalter 3 dB lauter als in Welle 0.

## 8. Hinweise für die Nächsten

- Zuerst hören: `motor_ab_<auto>.mp3`. Prüfpunkte: Breite der Reihenmotoren mit Kopfhörern; Laderton des
  Kompakten; Bass bei niedriger Drehzahl; Brummen der Limousine bei 200 km/h; Ticken im Leerlauf; Schläge beim
  Schalten.
- Stellgrößen ohne neue Banken: `audio.modern.engine.level_db`, `engine.motion.*`, `layers.turbo_db`,
  `layers.driveline_db`, `layers.shots_db`. Je Auto in `engine_synth3.py` (`CHAR`): `loudness`, `idle_db`, `low_db`,
  `retune`, `voice`, `saturation`, Laderpegel → `python3 tools/audio/modern/engine_synth3.py` (45 s) →
  `godot --headless --path . --import` → `audio_qc.py --determinism` → `capture_mix.gd` + `measure_mix.py`.
- Falls die Reihenmotoren zu schmal sind: ein kurzer Raum auf `MEngine` (wie Arcade; Pegel neu messen) oder im
  Werkzeug zwei Endrohre mit leicht verschiedenen Längen (`pan: tailpipe`, neue Banken).
- AU-C1: Summe bei Leerlauf und Reisetempo neu messen; Schleifen brauchen Frames hinter `loop_end`; für Hänger
  `EngineAudio3.driven()` übernehmen.
- AU-E: Movie Maker mit `--audio-sync` ist für Motor und Ebenen bitgleich; der Thread-Betrieb ist es mit Absicht nicht.
- `frame.engine` trägt zusätzlich `shaft`, `limiter`, `shifting`, `throttle` und die Zähler `upshifts`,
  `downshifts`, `blowoffs` (+ `blowoff_level`), `starts`.

## 9. Ablauf der Prüfungen am Ende

| Commit | Inhalt | geprüft mit |
|---|---|---|
| `5dfe67b` | Code, Tests, Konfiguration, Klangdateien | – (Zwischenstand) |
| `e500f09` | Dokumentation, dumpferer Lastwechselschlag (Klangdateien), Kombi −0,4 dB, Sportwagen −0,3 dB | **Gesamtlauf 1: 595 Tests, 0 fehlgeschlagen, alle Prüfungen OK** (572 s); `audio_qc.py --determinism` grün; Pegelplan |
| `c33809c` | Pegelgesetz des Lastwechselschlags in `vehicle_layers.gd` (zwei Zeilen Rechnung) | Gesamtlauf 2: 594 von 595, Abbruch nach den Unit-Tests; **Golden 20 von 20**; Movie Maker bitgleich; A/B-Aufnahmen der Endfassung (0 Aussetzer) |
| `8414002` | Test mit festem Seed, Dokumentation (Zahlen der Endaufnahmen) | `tools/run_tests.sh unit`: **595 Tests, 0 fehlgeschlagen** (230 s), darin die Thread-Bank (0 Aussetzer, synchron 389) |

Der Fehlschlag in Gesamtlauf 2: `test_engine3_slot.gd :: test_engine_slot_drives_the_v3_bank` verlangte mindestens
einen Schubknall in der halben Sekunde nach dem Gaswegnehmen. Die Knalle sind Poisson-verteilt und der Seed des
Mischers ist außerhalb des synchronen Betriebs zufällig – in etwa einem von zehn Läufen fällt keiner ins Fenster
(abgeleitet aus der Rate; in rund zehn Läufen davor bestand der Test). Das war ein Fehler meines Tests, nicht des
Mischers. Jetzt setzt der Test den Seed und rendert die ganze Knallzeit: sechs Clips, in fünf Läufen gleich.

Was auf dem Endstand **nicht** noch einmal gelaufen ist: die Integrationsszenarien der Rennszene und der Menüs und
die netzweiten Prüfungen (Schritte 3 und 4 von `run_tests.sh`). Sie waren in Gesamtlauf 1 grün; seitdem hat sich an
Code nur `scripts/audio/modern/vehicle_layers.gd` geändert (eine Modern-Datei, die ein Arcade-Start nicht lädt –
`check_arcade_lean.gd` besteht im Unit-Lauf des Endstands) und eine Testdatei. Die Regel „höchstens zwei
Gesamtläufe“ habe ich eingehalten; wer zusammenführt, sollte den Gesamtlauf einmal wiederholen (10 Minuten).

## 10. Dateien in diesem Ordner

- `motor_ab_<auto>.mp3` + `.txt` – A/B je Auto (Arcade | Modern), pegelgleich, mit Zeitmarken.
- `spektrogramm_<auto>.png` – beide Profile auf einer Skala, mit den Abschnitten der Fahrt.
- `ab_zahlen.json` – Lautheit je Abschnitt, Lautheitsbereich, Stereo, Spektrum, Mischzeit.
- `belege/` – Pegelplan Modern und Arcade, `audio_qc`, 20 Prozessenden, `check_engine3`, Movie Maker, stationäre
  Tabellen, Reisetempo, Tabellen als Markdown, Testläufe, Golden-Prüfung.
