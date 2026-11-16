**Builds und Größen** (`bin/builds.sh` im Gate-Arbeitsbaum; `build/` ist ignoriert, der Arbeitsbaum blieb sauber):

| Build | Ergebnis (gemessen) |
|---|---|
| Linux `tools/build_linux.sh` | Exit 0, 94 s; `CrossingEurope.x86_64` 496,5 MB, 1 574 Dateien im PCK; `pck_report.py`: Summe im Archiv **184,7 MB** von 277 MB Budget, kein Teil über seinem Budget (Arcade-Sprites 71,07 / 71,0 und Arcade-Klang 14,72 / 14,7 liegen in der Toleranz × 1,02 für unveränderte Teile); Modern: Modelle 18,73 / 40, Texturen 13,04 / 60, Klang 16,38 / 23, Musik 18,60 / 25 MB |
| Windows `tools/build_windows.sh` | Exit 0, 190 s; `CrossingEurope.exe` 532,3 MB (Versionsfelder 0.7.0.0, PE-Prüfsumme stimmt), **Zip 194,5 MB gemessen** (Warnung erst über 300, Abbruch über 330 MB; Vorgabe „Download höchstens ≈ 280 MB“ erfüllt) |
| Smoke Linux `tools/smoke_modern.sh build/CrossingEurope.x86_64` | **OK**: Arcade (29 s) und Modern (304 s bei Last 24) fahren Kiel – Hamburg (Bilder 6 s/14 s nach dem Start angesehen: Auto, Strecke, HUD, Tipps), Leistungstest im Build: Autobahn 2,2 fps, Vorschlag Arcade/Niedrig; 0 Fehlerzeilen |
| Smoke Windows unter Wine `tools/smoke_modern.sh build/CrossingEurope.exe` (eigenes Wine-Präfix) | **OK**: wineboot 49 s; Arcade (49 s) und Modern (338 s bei Last 24) fahren Kiel – Hamburg – im Bild 10,97 s nach „LOS!“ derselbe Simulationsstand in beiden Modi (km 2,9, 168 km/h, Tipp, Tankanzeige; `wine_arcade_modern.png`, angesehen), Leistungstest im Build: Autobahn 3,2 fps, p95 496 ms, Vorschlag Arcade/Niedrig; im Modern-Log nur die Wine-Warnung „Failed to get SDR white level“, keine Fehlerzeile |

Die Builds tragen die Version **0.7.0** (Datei- und Produktversion der `.exe` 0.7.0.0, `game_version` in `leistungstest.json`,
„v0.7.0“ im Titel): so vorgesehen – `project.godot` wird erst bei REL angehoben, und ein Testbuild für den Nutzer läuft
über `tools/build_testbuild.sh <version> <name> <Nutzerordner>`, das Version, Nutzerordner und Dateinamen nur für den
Export setzt (Vertrag §11). Kein Befund; für den nächsten Testbuild dieses Werkzeug nehmen, nicht `build_linux.sh`/`build_windows.sh`.
