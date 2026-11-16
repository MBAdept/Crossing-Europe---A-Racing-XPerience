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
