# QA-SYSTEM – unabhängige Prüfung von Push M1 (Kopf 9b6adbc)

Linse: Arcade-Identität, Klang, Menüs, Robustheit, Modell-Pipeline. Rolle ohne Commits; Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3` (ff auf 9b6adbc, danach sauber).
Alle Messungen auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne, während der Prüfung Last 7–13 durch die
anderen Pakete). „gemessen“ = hier gemessen; „abgeleitet“ = nicht messbar hier (echte Grafikkarte, Steam Deck, wie es
klingt). Arbeitsdateien: `<scratch>/v080/m1/QA-SYSTEM/` (im Folgenden relativ dazu).

## Urteil

Push M1 (Kopf 9b6adbc) ist in meiner Linse **bereit für den Testbuild**; kein Befund blockiert ihn. **Arcade ist
unverändert**: 0 Änderungen an eingefrorenen Dateien, `ERGEBNIS` auf drei Etappen gleich v0.7.0, der Klang-Fingerabdruck
aus v0.7.0 neu erzeugt gleich, `golden.sh check` **20 von 20 identisch**, dazu Menüs, Pausemenü, Ladebild und Arcade bei
1280×800 bildgleich mit v0.7.0 (bis auf die mit der Wanduhr pulsierenden Pfeile zweier Menüs, die schon v0.7.0 hat).
Einstellungen, Bestenlisten und Spielstand, **vom echten v0.7.0 geschrieben**, wandern verlustfrei nach Version 3; die
Auswahl erscheint genau einmal; Grafik und Klang lassen sich mitten in der Meisterschaft umstellen und wirken erst ab der
nächsten Etappe; die neuen Menüs gehen allein mit dem Gamepad, ohne Falle, bei 1280×720 und 1280×800 mit Schrift ≥ 18 px.
Rückfall auf Arcade (Selbsttest, fehlendes und kaputtes Manifest), Leistungstest-Datei, Beenden über das Spiel,
20 Minuten Modern ohne Fehlerzeile, der Windows-Build unter Wine (Arcade und Modern) und die Modell-Pipeline (Validator,
byte-gleicher Neu-Export über alle Materialwege, Archiv 156,5 MB von 350) sind in Ordnung; der Modern-Klang trifft den
Pegelplan, Ducking und „Musik im Rennen: Aus“ wirken. **Nicht in Ordnung**: das Tor `run_tests.sh` ist hier nicht
grün – eine lastabhängige Attract-Prüfung verdeckt den ganzen Modern-Haken, und `check_facade` scheitert hier
reproduzierbar an einer Bildschirm-Annahme (Prüfungsfehler, kein Spielfehler, QS-01/02/03). Im Spiel selbst ist der
wichtigste Befund QS-04: ein `SIGTERM` (Steam „Spiel beenden“) während eine Modern-Etappe lädt, gilt als Absturz, und die
vorausgewählte Antwort schaltet dauerhaft auf Arcade. Wie es klingt und wie schnell es auf Steam Deck und Windows-GPU
läuft, ist hier nicht messbar (abgeleitet) – dafür ist der Testbuild da.

## Befunde

| Nr. | Schwere | Bereich | Wo | Was | Beleg | Nachstellen | Abhilfe |
|---|---|---|---|---|---|---|---|
| QS-01 | mittel | Prüfläufe | `tools/run_tests.sh:123` | Der Haken aller Modern-Prüfungen (`tests/race3d/check_*.gd`, `tests/sim/modern_*.gd`) läuft nur bei `CODE == 0`. Eine einzige wackelnde frühere Prüfung verdeckt alle Naht-, Fahrzeug-, Fassaden- und Fairnessprüfungen – Lauf 1 hier endete nach `check_escapes` ohne Haken, `check_facade` war rot und blieb unsichtbar. | `run_tests_1.log` (Ende), `hook_run.log` (gemessen) | `tools/run_tests.sh` mit einer roten Prüfung in Schritt 3 laufen lassen | Haken immer ausführen und `CODE` sammeln; am Ende eine Liste der roten Dateien drucken. |
| QS-02 | mittel | Prüfläufe | `tests/race3d/check_facade.gd:328,344` (und `:688`) | „fassade“ scheitert hier 3 von 3: ohne Bildschirm ist das sichtbare Rechteck 1280 × 1280 (`expand`), die Grenze `y > 0,45 · Höhe` = 576 px verfehlt der Punkt 100 m voraus mit y = 570–573 – abhängig davon, wie weit die Etappe bis zur Prüfung gefahren ist (RINT-B: 30/32 Aufrufe, bestanden; hier 39/40). „geruest“ scheitert unter Last an `frames > 5`. Kein Produktfehler, aber das Tor „run_tests grün“ hängt vom Zeitablauf ab. | `hook/check_facade.log`, `facade_dbg_*.log` (gemessen) | `godot --headless --path . -s res://tests/race3d/check_facade.gd` bei Last ≥ 7 | Horizont aus der Kamera berechnen (z. B. `world_to_screen` eines Punktes 2 km voraus in Augenhöhe) statt 0,45 × Fensterhöhe; die Fassadenprüfung bei festem `camera_z` (Sync-Modus) ausführen; „geruest“ auf eine Mindestzahl Bilder warten lassen statt sie zu einem Zeitpunkt zu verlangen. |
| QS-03 | niedrig | Prüfläufe | `tests/race/check_attract.gd` mit `--graphics=modern` | Unter Last wackelt die Prüfung: 3 von 5 Läufen rot, jedes Mal eine andere Teilprüfung („dauer“ 4,75 s > 4,6 s; „gamepad“; „klick“ + „ziel: Ende time“), 3 von 3 Läufen grün. Die Logik von `AttractMode.handle_input()` ist richtig (gelesen, Eingaben kamen bei laufender Etappe an). | `run_tests_1.log`, `attract_modern_*.log`, `attract_dbg_*.log` (gemessen) | `check_attract.gd -- --graphics=modern` bei Last 7–10 mehrfach | Vor den Eingabeprüfungen auf `stage_live` warten, Zeitgrenzen an der gemessenen Bildzeit ausrichten, die Zielszene näher ans Ziel legen. |
| QS-04 | mittel | Robustheit | Absturz-Wächter (`Settings.crash_guard`, `race_session._release_crash_guard`, Titel-Frage) | `SIGTERM` – so beenden Steam („Spiel beenden“), das Abmelden und `systemd` ein Spiel unter Linux – während eine Modern-Etappe lädt: Godot endet mit 143 ohne Aufräumen, der Marker bleibt, der nächste Start meldet „… wurde beim letzten Start nicht richtig beendet. Vielleicht ist das Spiel dabei abgestürzt …“ und läuft in Arcade; die vorausgewählte Antwort „Bei Arcade bleiben“ speichert Arcade **dauerhaft**. Auf dem Steam Deck lädt eine Etappe einige Sekunden (abgeleitet) – wer dabei über das Steam-Menü beendet, landet nach einmal A in Arcade. | `quit_restart.out`, `quit/q3_sigterm_restart.png` (gemessen) | Modern-Etappe starten, nach 6 s `kill -TERM`, ohne Argumente neu starten | „Bei Arcade bleiben“ nur für diesen Start gelten lassen und Arcade erst nach einem zweiten Marker in Folge speichern, oder die Frage mit „Modern noch einmal versuchen“ vorbelegen, wenn der Marker aus der Ladephase stammt (Phase in den Marker schreiben). |
| QS-05 | niedrig | Testbuild | `project.godot` (`config/version="0.7.0"`), Titel, `leistungstest.json`, Spielstand | Der Testbuild von v0.8.0 zeigt auf dem Titel „v0.7.0“ und schreibt `"game_version": "0.7.0"` in die Leistungstest-Datei, die der Nutzer zurückschicken soll. | `quit/qt_modern_pair.png`, `fallback/bench_fail.json` (gemessen) | Titel ansehen | Für den Testbuild eine Kennung setzen (z. B. „0.8.0-test1“) – Vertrag §5 sieht die Version erst in Welle 8 vor (siehe Vertragsfragen). |
| QS-06 | niedrig | Menüs/Look | `assets/ui/gfx_preview_modern.webp` (Auswahl, Optionen) | Auf Kartengröße unterscheiden sich die Vorschaubilder kaum: Modern ohne Sonne, etwas dunkler, Schatten der Leitplanke und Feldstreifen; nichts zeigt, warum man Modern wählen sollte. | `vorschau_arcade_modern.png`, `menue_auswahl_1280x800.png` | Auswahl ansehen | Vorschau aus einer Stellung rendern, die Moderns Stärken zeigt (Dämmerung mit Scheinwerfern, Laternenschein, Schatten), sobald die Sonne da ist. |
| QS-07 | niedrig | Menüs | `scripts/ui/screens/result_screen.gd` (`UiKit.place(... Rect2(40, 618, 584, 50))`) | Der Rückfall-Hinweis sitzt knapp unter dem Rahmen der linken Tafel (1–6 px). | `rueckfall_ergebnis_hinweis.png` | `--screen=result --sample-gfx-fallback` | Hinweis in die Tafel legen oder 10 px tiefer setzen. |
| QS-08 | niedrig | Doku | `docs/grafik-modi.md:192,222,227`; `docs/audio-modern.md:30–31,42` | Veraltet: `check_options_tabs` und Attract-Modern laufen inzwischen in `run_tests.sh`; die Vorschau ist nicht mehr „das Gerüst“; UI1 verdrahtet `set_profile` längst. | Zeilen im Bericht | – | Sätze nachziehen (Besitzer UI bzw. Audio). |

## 1. Arcade-Identität (Regeln 1–3)

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Eingefrorene Dateien (Vertrag §2 Regel 1, alle 29 Pfade/Ordner) gegen `main` | **0 Dateien geändert**, keine fehlt, Arbeitsbaum sauber | `bin/frozen_diff.sh` (gemessen) |
| `ERGEBNIS` von `run_stage.gd`, v0.7.0 (`git archive v0.7.0`, eigener Import) gegen diesen Baum mit `--graphics=arcade` | **identisch** auf drei Etappen: Kiel–Hamburg 12 Uhr trocken, dev_testetappe 21 Uhr Regen, Hamburg–Hannover 22 Uhr Schnee (je 27 Schlüssel; dazu nur `gfx: "arcade"`) | `ergebnis/ref_*.json`, `ergebnis/cur_*.json` (gemessen) |
| Regel 3: dieselbe Etappe in Modern | dev_testetappe Regen/Nacht: identisch bis auf `gfx: "modern"` | `ergebnis/curmodern_dev.json` (gemessen) |
| Klang-Fingerabdruck Arcade (Motor-Mischer je Auto mit Seed, `SfxSynth`, Verkehr, Busse mit Effekten, 40 eingefrorene Dateien) | aus v0.7.0 **selbst neu erzeugt** = eingecheckter Fingerabdruck = dieser Baum (ohne Bildschirm) | `audio_golden/ref_headless.json`, `cur_headless.json` (gemessen) |
| Arcade-Bilder `tools/golden.sh check` | **20 von 20 identisch** (Abschnitt 8) | `golden.log` (gemessen) |
| Herkunft der Hash-Liste, unabhängig nachgerechnet | race_s1 von v0.7.0 selbst gerendert = Eintrag der Liste (00b9c70a…) = dieser Baum **ohne** `--shot-fast` (volle Renderschleife wie beim Spieler); race_n1 dieser Baum ohne `--shot-fast` = Liste (c62695c8…) | `golden_spot/` (gemessen) |
| Arcade bei 1280×800 (Steam-Deck-Fenster, Balken) | v0.7.0 = dieser Baum (d516d6bc…) | `golden_spot/*_1280x800_00.png` (gemessen) |
| Menübilder Arcade v0.7.0 gegen diesen Baum (Beispieldaten, 1280×720, 2 Zeitpunkte je Bildschirm) | siehe Abschnitt 1.1 | `menus/1280x720/` |

### 1.1 Menüs in Arcade gegen v0.7.0

Zwölf Bildschirme mit `--screen=<name>` (Beispieldaten), je zwei Bilder bei 1,0 s und 3,0 s, `--fixed-fps 60`, einmal mit
v0.7.0 und einmal mit diesem Baum (`--graphics=arcade`), `bin/menu_shots.sh` + `bin/menu_compare.sh` (gemessen):

- **bildgleich (md5)**: Titel, Rennwahl, Etappenwahl, Routenwahl, Etappenbildschirm, Etappenergebnis, Rennergebnis,
  Bestenlisten, Fähre – 9 von 12, beide Zeitpunkte.
- **Optionen**: anders, so gewollt (zwei Seiten, „Klang“, „Musik im Rennen“; „Vollbild“ steht jetzt auf GRAFIK) –
  Bild `menus/options_ref_cur.png`.
- **Fahrzeugwahl, Startzeit**: 424–966 bzw. 896 Pixel anders, ausschließlich im Band der ◀▶-Pfeile. Die Pfeile pulsieren
  mit `Time.get_ticks_msec()` (Wanduhr, `vehicle_screen.gd:162`, `start_time_screen.gd:126`); beide Dateien sind gegen
  `main` unverändert. Kein Unterschied des Spiels, sondern einer der Uhr (abgeleitet aus Code und Lage der Pixel).
- **Ladebild** „Etappe wird geladen …“ so, wie die Menüs es zeigen (ohne `set_progress`): v0.7.0 = dieser Baum, md5
  9387c10d… (`gd/qa_loading_overlay.gd`, Ordner `loading/`, gemessen).
- **Pausemenü** über einem Arcade-Rennen (S1, 150 Bilder, dann `_pause_now()`, Bild nach 30 weiteren Bildern,
  `--fixed-fps 60`): v0.7.0 = dieser Baum, md5 c951403f… (`gd/qa_pause_shot.gd`, Ordner `pause/`, gemessen).
- Nicht verglichen: die Menüs bei 1280×800 (A-6 sieht dafür eine zweite Liste von QA1 vor; dafür brauchen die Pfeile
  von Fahrzeugwahl und Startzeit eine Spieluhr statt der Wanduhr).

## 2. Einstellungen, Bestände, Auswahl, Umschalten

**Daten von v0.7.0 echt erzeugt** (nicht von Hand geschrieben): das Spiel v0.7.0 selbst (`git archive v0.7.0`) hat eine
Einstellungsdatei mit Nicht-Standardwerten (Vollbild **Aus gewählt**, Lautstärken 0,55/0,35/0,25, Vibration aus,
Name „Jörg Ü“, Filter „kompakt“), zwei Bestenlisteneinträge (Etappe und Rennen) und über `run_race.gd` einen
Spielstand nach der ersten Etappe von Kiel–Nürnberg geschrieben (`bin/make_v070_data.sh`, Ordner `xdg_v070/`).
v0.8.0 liest dieselbe Kopie (`gd/v080_migration.gd`): **23 von 23 Prüfungen bestanden** (gemessen, `migration.log`):

- alle Werte von v0.7.0 gelesen, „Vollbild: Aus“ bleibt die Wahl des Spielers (die Falle `FULLSCREEN_CHOICE_SINCE` ist
  richtig umgesetzt), neue Schlüssel nicht gewählt (`graphics_mode` leer, Klang „Wie Grafik“, Musik im Rennen an);
- ohne Kommandozeile: Modus Arcade (Grund `default`), Klang Arcade; die Auswahl ist fällig, der Spieler gilt als
  bestehender Spieler (Untertitel „Neu in v0.8.0 …“);
- Speichern schreibt `settings_version` 3, verliert nichts, schreibt keinen ungewählten neuen Schlüssel; ein
  Schlüssel einer späteren Version überlebt Laden und Speichern;
- Wahl „Modern“: genau `graphics_mode` wird gespeichert, Klang folgt (Modern), Auswahl danach nicht mehr fällig;
- Bestenlisten: die Einträge von v0.7.0 unverändert (ohne `gfx`), neue Einträge tragen `gfx` (`modern`, nach einem
  Rückfall `arcade` + `gfx_fallback`); der Spielstand von v0.7.0 lädt unverändert, `gfx_summary()` = `arcade`.
- Rückweg (Information): v0.7.0 liest eine v3-Datei richtig, entfernt beim Speichern aber `graphics_mode` (eingefrorener
  Code von v0.7.0) – wer zurück- und wieder vorwechselt, sieht die Auswahl noch einmal.

**Umschalten mitten in der Meisterschaft** (`gd/qa_champ_switch.gd`, echter `GameFlow`, Autopilot, ohne
`--graphics`; **9 von 9 bestanden**, `champ_switch.log`, keine Fehler- oder Warnzeile): Etappe 1 Arcade (Bild und Klang),
zurück zum Titel, Optionen → Grafik „Modern“ über den Handler der Zeile → Klang folgt sofort im Menü, gespeichert;
„Rennen fortsetzen“ → Etappe 2 in Modern (Bild und Klang); während Etappe 3 Grafik und Klang auf Arcade gestellt →
die laufende Etappe bleibt Modern (Bild und Klang), der Klang wechselt erst auf dem Ergebnisbildschirm; Etappe 4 Arcade;
Rennen `gfx_summary()` = `mixed`.

**Auswahl „GRAFIK WÄHLEN“ genau einmal**: siehe Abschnitt 5 (echter Start ohne Argumente unter Xvfb mit Tastatur) und
die Pad-Prüfung unten.

## 3. Menüs nur mit dem Gamepad, 1280×720 und 1280×800

`gd/qa_pad_walk.gd` mit echten Pad-Ereignissen im echten `GameFlow`, unter Xvfb in beiden Fenstergrößen, Bilder in
`pad/<größe>/`: **14 von 14 bestanden in beiden Größen** (gemessen):

- Auswahl: ▲▼ und B ändern nichts (keine Falle, kein Ausweg – so gewollt), ◀▶ wechselt zwischen genau zwei Karten,
  A übernimmt → Titel; empfohlen ist auf diesem Rechner (llvmpipe) Arcade mit Warnzeile.
- Titel: ▼ von „Rennen starten“ bis „Beenden“ ohne Umbruch (wie v0.7.0), Optionen erreichbar.
- Optionen ALLGEMEIN: ▼ läuft Gesamtlautstärke → … → Zurück → wieder oben; RB → GRAFIK mit Fokus auf „Grafik“; mit
  Modern alle zehn Zeilen, mit Arcade nur Grafik, Vollbild, Leistungstest, Zurück (Qualität gedimmt und übersprungen);
  RB auf der letzten Seite bleibt dort.
- Leistungstest-Seite: ◀▶ zwischen „Leistungstest starten“ und „Zurück“, B → Optionen mit Fokus auf „Leistungstest“;
  B → Titel, gespeichert.
- Absturz-Frage auf dem Titel: Fokus „Bei Arcade bleiben“, B speichert Arcade und entfernt den Marker.
- **Schrift**: kleinste Schrift aller sichtbaren Text-Steuerelemente je Schritt 18,0 px (1280×720 und 1280×800, Streck-
  faktor 1,0). Selbst gezeichneter Text (Karten der Auswahl, Tabelle des Leistungstests, Steuerungstabelle) ist laut
  Code 18–40 px. Bilder angesehen: nichts abgeschnitten, nichts überlappt; 1280×800 zentriert mit freiem Rand unten.

## 4. Klang

Hier hört niemand zu: alles unten ist an Dateien **gemessen**; wie es klingt, ist **abgeleitet** bzw. Sache des
Nutzers. Mitschnitte des Master-Busses mit `tools/audio/modern/capture_mix.gd` (Kopie `gd/qa_capture_mix.gd` mit dem
zusätzlichen Schalter `--race-music=0`), ohne Bildschirm, Dummy-Treiber, Echtzeit, Last 11–14; Ordner `sound/`,
`sound_drive/`, `sound_rep/`, `sound_seam/`.

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Arcade-Klang unverändert | Fingerabdruck aus v0.7.0 neu erzeugt = eingecheckt = dieser Baum (Abschnitt 1); `test_arcade_identity.gd`, `check_modern_audio.gd`, `check_music.gd` (Profil Arcade: kein `ModernAudio`, kein Modern-Bus) im Unit-Lauf grün | `audio_golden/`, `run_tests_1.log` |
| Klangdateien Modern (`audio_qc.py`) | 24 Dateien, 0 Fehler (Manifest = Datei, True Peak, Lautheit, Gleichanteil, **Schleifennähte**, Import); Klänge 12,6 MB von 23 MB, Musik 7,5 MB von 25 MB | `audio_qc.log` |
| Profil Modern in Menüs und Rennen | folgt Auswahl und Optionen sofort im Menü, wechselt nie in einer laufenden Etappe (Abschnitt 2); „ModernAudio: Profil „Modern“ gestartet (22 Busse, 24 Klangdateien)“ in jedem Modern-Lauf, keine Fehlerzeile | `champ_switch.log`, `pad/*/run.log` |
| Alle Kombinationen Bild × Klang | Arcade-Bild/Modern-Klang und Modern-Bild/Arcade-Klang: `ERGEBNIS` = v0.7.0, keine Fehlerzeile | `ergebnis/combo_*.json` |
| **Motor v3, alle fünf Autos** | je ein Mitschnitt (3 s Leerlauf, Vollgas bis Höchsttempo, 6 s Vollgas, 3 s Gas weg, 130 km/h) in beiden Profilen; Spektrogramme `klang_spektrogramme_motor_arcade_modern.png` (oben Arcade, darunter Modern je Auto, log. Frequenzachse): alle fünf Modern-Motoren haben ihre Harmonischen, folgen den Gängen (Sägezahn), dem Plateau, dem Gaswegnehmen und dem Reisetempo; Modern mit mehr Obertönen und Rauschen 1–10 kHz, Kombi/Kompakt/Limousine fast mono (Korrelation 0,98–1,00, bekannt: Raum fehlt noch, AU-C2), Sportwagen und Gran Turismo breiter (0,84–0,85) | `sound_drive/`, `sound_report.json` |
| Pegelplan Modern je Auto (`measure_mix.py`) | Vollgas −15,7 … −17,0 LUFS (Plan −16), Reisetempo −21,6 … −22,2 (Plan −21), Leerlauf −24,0 … −25,3 (Plan −24), True Peak ≤ −5,5 dBTP. Achtung: unter Last ist die Aufnahme bis 5 % kürzer als die Zeitleiste der Phasen – Werte am Phasenende ungenau | `python3 tools/audio/modern/measure_mix.py sound_drive/modern_drive_<auto>.wav` |
| Aussetzer | 0 in 17 von 18 Mitschnitten (10 Fahrten, 5 Musik/Menü, 3 Wiederholungen); **1 × 41 ms digitale Stille** im ersten Sportwagen-Mitschnitt beim Übergang Leerlauf → Vollgas mit hartem Wiedereinsatz (`klang_sportwagen_aussetzer.png`); in 3 Wiederholungen 0 – abgeleitet: Unterlauf des Mischer-Threads bei Last 11–14 (wie in audio-modern.md Falle 12 beschrieben), kein Fehler der Bank | `sound_rep/` |
| Knacken | Motor: Kandidaten (Sprung > 4 × Umgebung) nur im Leerlauf (Zündstöße, in **Arcade genauso**), beim Gaswegnehmen und Gasgeben (Crackle/Tip-in, gewollt); kein Kandidat an Zyklus- oder Schleifengrenzen erkennbar; in der Musik zählt der Detektor Schlagzeug (Arcade-Menü 0, Modern-Musik 6–65). Ein allgemeiner Knackdetektor unterscheidet das nicht sicher (abgeleitet) | `sound_report.json` |
| Ducking | Musik allein (Auto-Gruppe stumm): Vollgas −23,7 LUFS = 7,7 dB unter dem Auto (Plan 8 dB), Leerlauf −18,8 (Plan −19,5); Absenkung −4,5 dB bei Vollgas, −2,1 dB bei 130 km/h, 0 im Leerlauf | `sound/modern_race_music*.json` |
| „Musik im Rennen“ An/Aus | An: Leerlauf mit Musik −18,2 LUFS; **Aus: −23,9 LUFS = Auto allein** (Musik still), Vollgas −16,1 statt −15,5 | `sound/modern_race_music_off.wav` |
| Menümusik | Modern −21,2 LUFS integriert, Kurzzeit-Median −20,1 (Plan −20); Arcade −29,5 LUFS (Titelmelodie von v0.7.0, unverändert) – mit dem Wechsel auf Modern wird die Menümusik rund 8 dB lauter (so geplant) | `sound/*_menu.wav` |
| Titelmusik über die Schleifennaht (212 s Menü mitgeschnitten) | kein stiller 50-ms-Block, der größte Sprung ±1 s um die Naht (202,5 s) 0,205 liegt unter dem des Stücks (0,26, Schlagzeug) – die Naht fällt in den Daten nicht auf | `sound_seam/` |
| Sauberes Beenden | über „Beenden“ 4 von 4 ohne „leaked“/„still in use“ (Abschnitt 5.2); Render-Prüfung `check_quit_sound` siehe 5.5 | `quit/qt_*.log` |

## 5. Robustheit

### 5.1 Rückfall auf Arcade (Vertrag D34, §4.4.2)

Echter Start über `GameFlow --stage=kiel_hamburg --autopilot` unter Xvfb, Bilder bei 2 s und 6 s (`bin/fallback.sh`,
Ordner `fallback/`, gemessen):

| Fall | Ergebnis |
|---|---|
| `--gfx-debug=fail` | Arcade-Bild, HUD-Meldung wörtlich wie im Vertrag („Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter.“), Log `selftest:debug`, kein Absturz-Marker übrig – `fallback/fail_00.png` |
| `manifest.json` fehlt | dasselbe mit Grund `manifest`, kein Marker – `fallback/nomanifest_00.png` |
| `manifest.json` abgeschnitten (kaputtes JSON) | ein `ERROR: Parse JSON failed` im Log (so gewollt: „ein kaputtes ist ein Fehler im Log“), dann Rückfall `manifest`, kein Marker |
| Ergebnisbildschirm nach Rückfall (Beispieldaten) | Hinweiszeile „Diese Etappe lief im Modus „Arcade“: „Modern“ ließ sich auf diesem Rechner nicht starten.“ – sitzt knapp unter dem Rahmen der linken Tafel (`fallback/result_note_00.png`) |
| Leistungstest mit `--gfx-debug=fail` | endet sofort, schreibt `leistungstest.json` mit `"fallback": "selftest:debug"`, ohne Szenen, Vorschlag Arcade, Exit-Code 1 (so dokumentiert) |

Danach Manifest byte-gleich zurückgelegt, Arbeitsbaum sauber.

### 5.2 Erster Start, Beenden und Neustart

Echtes Spiel unter Xvfb, Tastatur über `xdotool` (`bin/quit_restart.sh`, `bin/quit_title.sh`, Bilder in `quit/`,
gemessen):

- **Auswahl genau einmal**: Start **ohne jedes Argument** in einem leeren Benutzerordner → „GRAFIK WÄHLEN“
  (`q1a_chooser.png`); Prozess beendet ohne Wahl → beim nächsten Start wieder die Auswahl (richtig: nichts gewählt);
  ▶ + Enter → Titel, `graphics_mode: "modern"` sofort gespeichert; Neustart ohne Argument → **direkt der Titel**
  (`q1_bc.png`).
- **Beenden über das Spiel** (Titel → „Beenden“ → Frage → „Beenden“), je zweimal mit gespeichertem Modus Modern
  (Modern-Klang, Titel-Remaster läuft) und Arcade: **4 von 4 mit Exit-Code 0, keine „leaked“-, „still in use“- oder
  Fehlerzeile** (`quit/qt_*.log`, Bild der Frage `qt_modern_pair.png`).
- **Fenster schließen**: ein `WM_DELETE_WINDOW` per `XSendEvent` ohne Fenstermanager nimmt Godot hier nicht an –
  **v0.7.0 genauso** (`bin/xclose_debug.sh`); dieser Weg (X-Knopf, Alt+F4) ließ sich hier nicht nachstellen. Die
  Fälle liefen deshalb als harter Abbruch (`kill -9`) – das ist die Probe für den Absturz-Wächter:
  - Abbruch während eine Modern-Etappe lädt (Last 13 auf 4 Kernen: auch nach 30 s noch das Ladebild mit Balken
    ≈ 65 %, `q3_driving.png`) → Marker bleibt → Neustart ohne Argument zeigt die Absturz-Frage, der Start läuft in
    Arcade (`q3_loading_pair.png`). Richtig.
  - Optionen mit ungespeicherter Änderung und Abbruch → Änderung verloren (bei einem Abbruch erwartet; beim Schließen
    speichert `Settings` über `NOTIFICATION_WM_CLOSE_REQUEST`, Code gelesen).
  - Fahrzeugwahl mit erzwungenem 3D-Showroom, laufender Leistungstest: Abbruch hinterlässt keinen Marker und keine
    `leistungstest.json` („Ein Abbruch schreibt nichts“).
- **`SIGTERM` während eine Modern-Etappe lädt** (so beenden Steam „Spiel beenden“ und das Abmelden unter Linux –
  abgeleitet): Godot beendet sich mit **143** ohne Aufräumen, der Marker bleibt, und der nächste Start meldet
  „Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet … Vielleicht ist das Spiel dabei abgestürzt“ und
  läuft in Arcade; die vorausgewählte Antwort „Bei Arcade bleiben“ **speichert Arcade dauerhaft**
  (`q3_sigterm_restart.png`). Siehe Befund QS-04.

### 5.3 20 Minuten Modern

`bin/soak.sh`: `tests/race/run_race.gd` durch den echten `GameFlow` (Rennen Kiel–Nürnberg, Autopilot), Xvfb,
**Modern-Bild + Modern-Klang** (Motor-Thread, Rennmusik), Voreinstellung Mittel (mit Schatten), Zeitraffer 1,
1 233 s Wanduhr (gemessen):

- **Log: keine einzige Fehler-, Skript- oder „Too many instances“-Zeile**; einzige Warnung die übliche „Could not set
  V-Sync mode“ des Software-Treibers. Ende durch mein Zeitlimit (`FEHLER: Zeitlimit überschritten im Zustand racing`).
- Bei Last 10–14 auf 4 Kernen lief die Simulation langsamer als die Uhr (Physik höchstens 8 Schritte je Bild): Kiel–Hamburg
  war nach 20 min noch nicht im Ziel – Etappenwechsel und Ergebnisbildschirm kamen in diesem Lauf also **nicht** vor
  (die liefen kopflos im Meisterschaftslauf, Abschnitt 2, viermal fehlerfrei).
- Speicher des Prozesses (RSS, alle 20 s): 1 526 MB → 1 586 MB in 16 min (+4 %, Kurve mit Auf und Ab: 1 573 → 1 552 →
  1 587), 23 Threads und 8 Dateideskriptoren konstant – kein Hinweis auf ein Leck, für eine Aussage über Stunden zu kurz
  (`soak/rss_godot.tsv`).

### 5.4 Leistungstest `--bench=all`

`bin/bench.sh` (Xvfb, Voreinstellung dieses Rechners „Niedrig“, gemessen; Ordner `bench/`): läuft durch (146 s, Exit 0),
schreibt `user://leistungstest.json` und `--bench-out` **identisch**, Format nach Vertrag §4.8 vollständig (alle
Pflichtschlüssel, Version 1, je Szene id/avg/1 %-low/p95/p99/Skript/Aufrufe/Dreiecke, `suggested_preset`; dazu die
Zusatzfelder), Prüfskript `bin/bench_check.py`: **FORMAT OK**. Urteil auf llvmpipe: „too_slow“ → Vorschlag Arcade
(richtig für Software-Grafik). Zahlen (gemessen bei Last 13 auf 4 Kernen, für eine echte Grafikkarte bedeutungslos):

| Szene | Ø fps | 1 % niedrig | p95 / p99 ms | `render()` ms | Aufrufe | Dreiecke | Vorbereitung |
|---|---|---|---|---|---|---|---|
| Autobahn bei Tag | 4,1 | 1,2 | 312 / 801 | 2,10 | 129 | 89 258 | 42,1 s (kalter Shader-Cache) |
| Stadt bei Nacht im Regen | 0,9 | 0,6 | 1 555 / 1 555 | 7,10 | 67 | 26 900 | 18,6 s |
| Bergstrecke mit Tunnel | 2,5 | 1,5 | 610 / 689 | 2,39 | 56 | 19 989 | 14,5 s |

Hinweis für den Testbuild (abgeleitet): In M1 fehlen in Modern Wetter, Stadtgebäude und Tunnelbauwerke noch (M2) –
die Szenen „Stadt bei Nacht im Regen“ und „Bergstrecke mit Tunnel“ messen deshalb weniger, als sie später kosten; die
Zahlen, die der Nutzer vom Steam Deck zurückschickt, sind für diese Szenen zu günstig. Die Datei trägt
`"game_version": "0.7.0"` (Befund QS-05).

### 5.5 Render-Prüfungen der Systemlinse (`tools/run_render_checks.sh`, Xvfb)

`bin/render_subset.sh`, gemessen – **alle grün**:

| Datei | Ergebnis |
|---|---|
| `check_quit_sound.gd` | Beenden über `GameFlow.quit_game()` je 3 Starts mit Klang Arcade und Modern: kein „leaked at exit“ |
| `check_seam_render.gd` | Selbsttest (Kugel 0,87, Hintergrund 0,00, Shaderfläche 0,09/0,80/0,30; 1 223 ms beim ersten Mal), gleiche Simulationsschritte zur gleichen Aufnahmezeit in beiden Modi, Rückfall-Bild = Arcade-Bild bis auf die Meldung (0 px), **Arcade – Modern – Arcade im selben Prozess: 0 Pixel verschieden**, 16:10-Fenster ohne Balken in Modern / mit Balken in Arcade |
| `check_session_modern.gd` | Pause: 30 Bilder, 0 Bildpunkte verschieden; `--gfx-debug=fail` → `gfx_fallback selftest:debug`, Etappe läuft; danach Arcade: 0 Netze, 0 Texturen, Materialien freigegeben |
| `check_showroom_render.gd` | physische Pixel 660 × 400 bzw. 990 × 600 (Streckfaktor 1,5), durchsichtig, nicht angeschnitten, dreht |
| `check_instance_budget.gd` | 100 s Verkehr bei 6-facher Zeit: keine Ablehnung des globalen Shader-Puffers, Fahrzeug-Ebene ≤ 128 Instanzen |
| Arcade: `check_glow_occlusion.gd`, `check_sprite_flip.gd` | 16/16 und OK |

### 5.6 Builds und Größen (`tools/build_linux.sh`, `tools/build_windows.sh`, `tools/pck_report.py`)

Beide Exporte aus diesem Baum gebaut (gemessen, `build_linux.log`, `build_windows.log`): Linux 36 s, Windows 87 s, beide
Exit 0; Windows-Icon und Versionsressource geprüft (`FileVersion 0.7.0.0` – QS-05).

| Teil (Windows-Archiv) | Dateien | roh MB | im Archiv MB | Budget MB |
|---|---|---|---|---|
| Programm (Godot-Vorlage) | 1 | 109,30 | 37,95 | 38,0 |
| Arcade-Sprites | 375 | 305,22 | 71,07 | 71,0 (unverändert) |
| Arcade-Klang und -Musik | 31 | 15,75 | 14,72 | 14,7 (unverändert) |
| UI, Schriften, Skripte, Daten | 378 | 4,19 | 3,72 | 5,0 |
| Modern: Modelle | 98 | 4,83 | 4,64 | 40,0 |
| Modern: Texturen | 60 | 16,72 | 5,59 | 60,0 |
| Modern: Klang | 52 | 12,63 | 11,14 | 23,0 |
| Modern: Musik | 9 | 7,68 | 7,54 | 25,0 |
| **Summe** | 1 004 | 476,31 | 156,36 | 277,0 |

**Zip gemessen: 156,5 MB** (Warnung > 300, Abbruch > 330, Grenze 350) – in Ordnung. Linux-Programm 440,6 MB, Archiv
geschätzt 146,7 MB. Mit ausgeliefert werden je Klangordner ein Platzhalter (6 Dateien, zusammen < 0,3 MB) und die
`model.json`-Bruchstücke – vernachlässigbar.

### 5.7 Windows-Build unter Wine

`bin/wine.sh` (wine64, eigenes Präfix, Xvfb, `-- --stage=kiel_hamburg --autopilot --gfx-preset=medium`, gemessen):

- **Arcade** (`--graphics=arcade --sound=arcade`): startet, fährt, Bilder bei 6 s und 14 s, Exit 0 nach 29 s.
- **Modern** (`--graphics=modern --sound=modern`): startet, bereitet vor, fährt (Modern-Bild, Modern-Klang laut Log),
  Bilder bei 6 s und 14 s, Exit 0 nach 159 s; kein Rückfall, keine Fehlerzeile.
- Gleiche Aufnahmezeit, gleicher Simulationszustand in beiden Modi (km 0,3 / 59 km/h und km 2,9 / 168–170 km/h) –
  `windows_wine_arcade_oben_modern_unten.png`.
- Leistungstest-Szene „autobahn“ (8 s) unter Wine: `win_bench.json` **FORMAT OK** (5,0 fps auf llvmpipe, Vorschlag
  Arcade).
- Nicht prüfbar hier: ANGLE/Direct3D und echte Windows-Treiber (abgeleitet; Nutzertest am Gate).

## 6. Modell-Pipeline

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| `validate_models.py --report` (inkl. dekodierter Ecken über `inspect_models.gd`) | **OK**: 28 Modelle, 182 Sets (40 mit Modell, 142 Platzhalter); Netze 4,47 MB von 40 MB, Texturen 15,94 MB Grafikspeicher von 240 MB, Quellen 10,29 MB von 60 MB (gemessen) | `validate.log` |
| Manifest neu erzeugt (`export_models.py --manifest-only`) | **byte-gleich** mit dem eingecheckten (md5 8ab4951b…), Arbeitsbaum danach sauber | `python3 tools/blender/export_models.py --manifest-only`, `md5sum` davor und danach |
| Export-Determinismus (erzwungener Export aus den Generatoren mit Blender 5.2, neu gebacken, `git status`) | **byte-gleich** für alle sechs Stichproben (siehe 6.1); `--check-keys` OK | `exportdet/`, `export_det.out` |
| Größen im Build (`tools/pck_report.py`) | siehe Abschnitt 5.6 | `build_*.log` |

### 6.1 Export-Determinismus

`bin/export_det.sh` (gemessen, 161 s): sechs Modelle, die alle Materialwege abdecken, mit `--force --jobs=1` aus den
Generatoren neu exportiert und mit `bake_models.gd --only=…` in `assets/models` gebacken – danach ist
`git status -- assets/models` **leer**, die eingecheckten Dateien entstehen also Byte für Byte wieder:

| Modell | Weg | Export | Ergebnis |
|---|---|---|---|
| `player/kompakt` | Spielerauto, Aufkleber als Geometrie, `show`, Schatten | 15,9 s, 147 856 Dreiecke, 5 Netze | byte-gleich |
| `traffic/hatch` | Verkehr LOD0–2, Lampenkanäle | 3,4 s | byte-gleich |
| `props/tree_birch` | Kartenbaum mit Blattatlas und Ersatzbild | 6,7 s | byte-gleich |
| `props/haybale`, `props/customs_booth` | Cycles-gebackener Atlas | 30,2 s / 27,7 s | byte-gleich |
| `props/streetlight` | Lampenkanal 12 mit Lichtankern | 0,2 s | byte-gleich |

Dazu `export_models.py --check-keys`: „28 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung …
ergibt für genau die betroffenen Modelle einen neuen Schlüssel“ – OK. (RINT-B hatte Lkw und Limousine geprüft, AS1b alle
21 Requisiten; hier unabhängig eine Stichprobe über alle Wege.)

## 7. Prüfläufe: `tools/run_tests.sh` und der Haken der Modern-Prüfungen

- **Lauf 1** (`run_tests_1.log`, 887 s, Last 7–10 auf 4 Kernen, ein eigener Kopflos-Lauf parallel): Skripte 298/0,
  **Unit-Tests 692/0**, Sitzungsszenarien, Attract Arcade, Gamepad 9/9, Optionen 10/10, Attract-Szenen beider Modi,
  Polizeiflucht – alles grün **außer** `check_attract.gd --graphics=modern` („dauer“ 4,75 s, Grenze 4,6 s). Ergebnis
  „Tests FEHLGESCHLAGEN“.
- **Der Haken (`tests/race3d/check_*.gd`, `tests/sim/modern_*.gd`) lief danach gar nicht**: `run_tests.sh` startet ihn nur
  bei `CODE == 0` (Zeile 123). Eine einzige wackelnde Zeitprüfung verdeckt also alle Naht-, Fassaden-, Fahrzeug- und
  Fairnessprüfungen. Von Hand mit derselben Regel nachgeholt (`bin/hook_checks.sh`, Ordner `hook/`): 10 von 11 Dateien
  grün (u. a. `modern_sight` F1–F3/F7 6/6, `modern_path_check` 2/2, `check_modern_stage` 8/8, `check_vehicles` 8/8,
  `check_seam` 9/9, `check_benchmark` 8/8, `check_showroom` 7/7); **`check_facade` rot**.
- **`check_facade` „fassade“** scheitert hier in 3 von 3 Läufen: „ein Punkt 100 m voraus liegt unter dem Horizont in
  Bildmitte (647,2 / 573,1 / 99,4)“. Ursache (gemessen mit einer Kopie, `gd/qa_facade_dbg.gd`): ohne Bildschirm ist das
  sichtbare Rechteck **1280 × 1280** (Seitenverhältnis `expand` auf einem quadratischen Kopflos-Fenster); die Grenze
  `y > 0,45 · Höhe` = 576 px verfehlt der Punkt um 3 px. Bei RINT-B lief die Etappe bis zur Prüfung weniger weit
  („services in 30/32 Aufrufen“ gegen 39/40 hier) und bestand – die Prüfung hängt also von Zeitablauf und Straßenlage ab.
  In einem zweiten Lauf scheiterte zusätzlich „geruest“ („render() läuft (Ø 3,956 ms)“): die Bedingung ist
  `frames > 5 and render_ms_avg < 20` (Zeile 688) – unter Last waren bis zur Abfrage nicht mehr als 5 Bilder gezählt.
- **`check_attract.gd --graphics=modern`** einzeln: 2 von 2 Läufen rot mit jeweils **anderen** Prüfungen („gamepad“;
  „klick“ + „ziel: Ende time“), danach 3 von 3 grün (Kopie mit Ausgaben, `gd/qa_attract_dbg.gd`: Eingabe kam jedes Mal
  bei laufender Etappe an). Die Logik von `AttractMode.handle_input()` beendet eine Demo in jedem Zustand (Code gelesen);
  die Fehlschläge sind Zeitgrenzen der Prüfung (8-s-Warten auf die Demo, 4,6-s-Dauer, 14 s für 0,5 km bis zum Ziel bei
  langsamer Bildrate). **Abgeleitet:** kein Produktfehler, aber das Tor ist unter Last nicht verlässlich.
- Ein zweiter vollständiger Lauf von `run_tests.sh` bleibt mir erlaubt; er hätte an derselben Stelle wieder abbrechen
  können, darum wurden Haken und wackelnde Prüfungen einzeln wiederholt (oben).

## 8. Arcade-Bilder: `tools/golden.sh check` (einmal, zum Schluss)

`GOLDEN arcade: 20 von 20 identisch (235 s)` – gemessen um 18:16 auf sauberem Arbeitsbaum (9b6adbc), Bilder behalten in
`golden_keep/`, Protokoll `golden.log`. Dazu unabhängig (Abschnitt 1): die Hash-Liste stammt nachweislich aus v0.7.0
(race_s1 von v0.7.0 selbst gerendert = Listeneintrag), und Arcade ist auch **ohne** `--shot-fast` und bei 1280×800
bildgleich.

## Geprüft und in Ordnung (Kurzliste)

- Eingefrorene Arcade-Dateien (Regel 1): 0 Änderungen gegen `main`.
- `ERGEBNIS` Arcade = v0.7.0 auf drei Etappen; Modern = Arcade bis auf `gfx`; beide gemischten Kombinationen Bild × Klang = v0.7.0.
- Golden 20/20, Herkunft der Liste nachgerechnet, Arcade ohne `--shot-fast` und bei 1280×800 gleich; Menüs (9/12 + Ladebild + Pause) bildgleich.
- Arcade-Klang: Fingerabdruck aus v0.7.0 neu erzeugt = eingecheckt = dieser Baum.
- Einstellungen v2 → v3, Bestenlisten und Spielstand von v0.7.0: 23/23; neue Einträge tragen `gfx` / `gfx_fallback`.
- Auswahl genau einmal (echter Start ohne Argument), ohne Falle mit dem Pad; Umschalten in der Meisterschaft 9/9.
- Gamepad-Gang 14/14 bei 1280×720 und 1280×800, kleinste Schrift 18 px.
- Rückfall bei `--gfx-debug=fail`, fehlendem und kaputtem Manifest mit der Meldung des Vertrags; kein Marker übrig.
- Leistungstest: gültige Datei (beide Pfade gleich), auch unter Wine und im Rückfall.
- Beenden über das Spiel 4/4 ohne „leaked“; Absturz-Marker nach hartem Abbruch → Frage und Arcade.
- 20 Minuten Modern (Bild + Klang, Mittel) ohne Fehlerzeile; Speicher +4 %, Threads/Deskriptoren konstant.
- Render-Prüfungen der Systemlinse alle grün (u. a. Arcade–Modern–Arcade im selben Prozess 0 px).
- Klang: Motor v3 aller fünf Autos (Spektrogramme), Pegel im Plan, Ducking, „Musik im Rennen: Aus“, Menümusik, Schleifennaht.
- Modelle: Validator OK, Manifest neu = eingecheckt, Neu-Export byte-gleich (6 Stichproben über alle Wege), `--check-keys` OK.
- Builds Linux/Windows, Windows-Zip 156,5 MB (Budget 277, Grenze 350); Windows-Build unter Wine fährt Arcade und Modern.
- Unit-Tests 692/0; Haken-Prüfungen bis auf `check_facade` grün (Fairness `modern_sight` 6/6, `modern_path_check` 2/2).

## Bilder und Dateien (`<scratch>/v080/deliver/QA-SYSTEM/`)

`menue_auswahl_1280x800.png`, `menue_optionen_grafik_1280x800.png`, `menue_absturzfrage_1280x800.png`,
`menue_leistungstest_1280x720.png`, `menue_optionen_v070_gegen_v080.png`, `erster_start_ohne_argumente_auswahl.png`,
`erster_start_wahl_dann_neustart_titel.png`, `rueckfall_gfx_debug_fail_hud.png`, `rueckfall_ergebnis_hinweis.png`,
`sigterm_falsche_absturzfrage.png`, `vorschau_arcade_modern.png`, `windows_wine_arcade_oben_modern_unten.png`,
`klang_spektrogramme_motor_arcade_modern.png`, `klang_sportwagen_aussetzer.png`.
Alle Werkzeuge dieser Prüfung liegen in `<scratch>/v080/m1/QA-SYSTEM/bin/` und `gd/` (Skripte werden mit `-s` über
ihren absoluten Pfad gestartet, nichts davon liegt im Repository).

## 9. Vertragsfragen (contract_issues)

1. **D15 `gfx`**: Der Vertrag kennt nur `"arcade" | "modern"`; ein Renneintrag, dessen Etappen in beiden Modi liefen,
   bekommt von UI1 `"mixed"` (`RaceState.gfx_summary()`). Sinnvoll – der Vertrag sollte den Wert nennen.
2. **§4.9.1 / A-6 Haken in `run_tests.sh`**: „Später fügen Pakete nur Dateien hinzu, niemand ändert `run_tests.sh`“ –
   der Haken aus Welle 0 läuft aber nur, wenn alles davor grün war (QS-01). Wer darf das jetzt ändern? (A-8 nennt die
   Integration und QA1.)
3. **Regel 8 („jeder Lauf mit `--graphics=`“)** schließt genau die Läufe aus, die Auswahl, gespeicherten Modus und
   Absturz-Frage prüfen (die brauchen einen Start ohne Argument bzw. ohne `--graphics`). Diese Prüfung lief bewusst
   ohne `--graphics` – der Vertrag sollte die Ausnahme nennen.
4. **D34 (b) Absturz-Wächter**: „entfernt nach 2 s gezeichneter Bilder oder beim geordneten Verlassen“ deckt `SIGTERM`
   nicht ab, und ein Laden der Etappe von mehreren Sekunden liegt immer im Fenster (QS-04). Der Vertrag sollte festlegen,
   ob die Antwort „Bei Arcade bleiben“ dauerhaft speichert.
5. **§5 `project.godot` erst in Welle 8**: M1 geht als Testbuild an den Nutzer, der Build heißt aber überall 0.7.0
   (QS-05). Eine Kennung für Testbuilds fehlt im Plan.

## 10. Für die Nächsten (notes_for_next)

- QS-01/02/03 vor dem Gate-Build beheben, dann `run_tests.sh` zweimal auf ruhiger Maschine (Last ≤ 4) laufen lassen.
- QS-04 entscheiden (Absturz-Frage nach `SIGTERM`) – betrifft Steam Deck und Linux-Desktop.
- Fenster schließen (X, Alt+F4, Steam „Spiel beenden“) konnte hier ohne Fenstermanager nicht nachgestellt werden: beim
  Nutzertest unter Windows und auf dem Deck ausdrücklich prüfen lassen (Einstellungen gespeichert? Marker weg?).
- Leistungstest: In M1 fehlen in Modern Wetter, Tunnelbauwerke und Stadtgebäude – die Zahlen des Nutzers für „Stadt bei
  Nacht im Regen“ und „Bergstrecke mit Tunnel“ werden später schlechter; bei Gate 2 neu messen lassen.
- QA1: Für die zweite Golden-Liste (Menüs, Pause, 1280×800) pulsieren die ◀▶-Pfeile von Fahrzeugwahl und Startzeit
  mit `Time.get_ticks_msec()` – in Testläufen eine feste Uhr nehmen (z. B. bei `--gfx-sync`); alles andere war hier
  schon bildgleich (Menüs, Ladebild, Pause).
- Doku nachziehen (QS-08).
