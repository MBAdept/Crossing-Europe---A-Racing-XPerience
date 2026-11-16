## Geprüft und in Ordnung (Kurzliste, alles gemessen)

- Eingefrorene Arcade-Dateien (Regel 1): 0 Änderungen gegen `main`.
- `ERGEBNIS` Arcade = v0.7.0 auf drei Etappen (Kiel – Hamburg ganz; Bern – Mailand Schnee/Nacht; Dortmund – Frankfurt Regen/Dämmerung); Modern = Arcade bis auf `gfx`.
- Arcade-Klang: Fingerabdruck aus v0.7.0 neu erzeugt = eingecheckt = Kopf.
- `tools/run_tests.sh`: bestanden (749/0 Unit-Tests, 175 CHECK-Zeilen OK, 0 FEHLER; Fairness F1–F3/F7, Pfad).
- `audio_qc.py` über alle Ordner: 98 Klänge, 0 Fehler, Nähte, Pegel, True Peak, Manifest = Datei, Budgets (19,0/23 MB, 18,5/25 MB).
- Modell-Manifest: neu erzeugt byte-gleich; 87 Modelle = 87 Ordner; 490 Dateien da; keine Waisen; Validator OK.
- Kiel – Hamburg im Spiel (Movie Maker, Modern-Klang): Betonplatten ab km 25 hörbar im Takt, Köhlbrandbrücke mit 4 Fugen genau an den Fugen der Strecke, Hamburger Altstadt im Wechsel Pflaster/Asphalt genau nach den Blöcken, kein Aussetzer, kein Übersteuern, schwerer Unfall ≤ −4 dBTP bei Gesamtlautstärke 1,0.
- `tools/golden.sh check`: Arcade 20/20 und Arcade-UI 17/17 identisch; `modern-check` 6/6 und OpenGL ES gegen OpenGL OK (2/255).
- Render-Prüfungen: 2/2 Arcade, 17/17 Modern (die Waldprüfung erst mit erhöhtem Zeitlimit, M2S-01): kein Shader-Puffer-Überlauf im Wald bei „Hoch“ (≤ 142 von 230).
- Begrenzer: schwerer Unfall ≤ −4,1 dBTP bei Gesamtlautstärke 1,0; beim Reisen greift er höchstens 0,25 dB (p95).
- Musik: Rotation 1 → 2 → 3 → 1, Stinger (Polizei, Tank), Zwischenspiel, Ziel-Stich, „Musik im Rennen: Aus“; Pegelplan bis auf V-6 eingehalten.
- Wind (stetig mit dem Tempo), Reifenquietschen (+13,8 dB, kein Hängenbleiben), neun Menü-/Ansageklänge ohne Sprung.
- Modell-Pipeline: Export und zweites Backen byte-gleich, `--check-keys` OK, Sprites 187/187 unverändert, Validator und Budgets OK.
- Rückfall auf Arcade (`--gfx-debug=fail`, Manifest fehlt/kaputt, Netzdatei fehlt), Leistungstest-JSON, Beenden/Neustart in 14 Bildschirmen und der Modern-Etappe (Laden, Zeichnen, Pause, Strike 1 und 2), 20 min Modern ohne Fehler bei flachem Speicher, Linux- und Windows-Build (Wine) Arcade und Modern.
