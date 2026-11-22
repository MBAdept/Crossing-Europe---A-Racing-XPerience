- Gates auf dem Endstand `2c154bc` (§6): Import, Skripte (334/0), `run_tests.sh` (ein voller Lauf, bestanden),
  Golden Arcade 20/20 und 17/17, Render-Prüfungen 29/29, Sicht und Pfad `--full` OK, ganze Etappen Modern ohne
  Skriptfehler. Golden Modern 5/6: `modern_s4_mittel` weicht gewollt um höchstens 2/255 ab (der Michel kommt jetzt
  aus `landmarks.gd`) – nach A-18 nicht neu erzeugt.
- Leistung (§7, gemessen auf llvmpipe): render() im Mittel wie die Basis; der Builder kostet 0,05 ms je Bild
  (höchstens 1,2 ms), `props.gd` wird 0,04 ms billiger.
- Bild (§5): Stelle wie Arcade; die 3D-Formen sind bei Tag besser als Arcades flache Zeichnungen (Belgrad, Dortmund,
  Madrid). Schwächer: rotes Flugwarnlicht nachts etwa dreimal so groß wie Arcades Punkt; Kuppelformen stehen aus
  260 m in Kurven bis etwa 85 px neben Arcades Zeichnung (gerade Anfahrt bei 600 m: 0,0 / 24,7 px).
