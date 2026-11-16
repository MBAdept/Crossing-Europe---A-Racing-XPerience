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
