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
