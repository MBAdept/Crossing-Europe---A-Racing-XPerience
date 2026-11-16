# QA-BILD – unabhängige Prüfung des Schubs M1 (Kopf 9b6adbc): Bild, Fairness, Leistung

Prüfer: QA-BILD (keine Commits, kein Push). Arbeitskopie `.claude/worktrees/wf_ae4df3ba-14f-2`, per `--ff-only` auf
`9b6adbce9b2b1443ee3ec795c16460e3890328b3`. „Gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne,
Last während der Prüfung 4–12 durch andere Aufträge, llvmpipe mit 2 Rasterthreads); alles über echte Grafikkarten,
das Steam Deck und Windows/ANGLE ist „abgeleitet“. Bilder und Clips liegen in diesem Ordner (Abschnitt 8).

## Urteil

Technisch ist der Schub solide: Die Fairness-Rechnungen F1–F3, F7 und die Pfadprüfung halten im vollen Netz genau die
Vertragszahlen (Reserve bei F2 Regen nur 0,004), Rückfall, OpenGL ES, 16:10 auf dem Deck und gleiche
Simulationszustände funktionieren, in Bewegung flimmert nichts und keine Detailstufe springt sichtbar, kein Lauf meldete
eine Instanz-Ablehnung oder einen Skript-/Shaderfehler, der Lack liegt mittags innerhalb 10 % am Sprite.

Bildlich ist Modern **noch nicht deutlich besser als Arcade**. Auf freier Autobahn bei Tag ist es gleichwertig bis
etwas besser (Gelände mit Tiefe, echte Schatten, scharfe Nahmodelle, Felder), an den markanten Stellen von Kiel–Hamburg
aber schlechter: Tankstelle ohne Dach im Tutorial-Moment, Köhlbrandbrücke ohne Geländer, Elbphilharmonie und Michel
fehlen (neu, steht in keiner Lückenliste), kein Zieltor; nachts zwei weiße Mond-Glanzflecken auf dem Spielerauto; kein
Regen/Schnee; ferne Bäume als graublaue „Geisterbäume“; Straßenränder in Kurven durch den Sichtkorridor kahl. Tunnel
anderer Etappen sind offenes grünes Gelände unter schwarzem Himmel (ebenfalls nicht in der Lückenliste).

Leistung (nur Software-Rasterung messbar): Modern kostet auf llvmpipe 6–10 × Arcades Rasterzeit. `render()` liegt unter
dem echten GL-Pfad bei Last 10 im Mittel bei 1,9–2,7 ms (Budget 1,5 bzw. 2,0; Median 1,6 ms), Stück-Einhängen bis
20 ms (Budget 3) – die Budgets werden nur kopflos geprüft. Einzelne Bilder mit 45–479 ms in der Fahrzeug-Ebene, an
wechselnden Stellen, vermutlich Rechenzeitentzug der überlasteten VM. Laden hier 15–37 s (RINT-B: 5,2–5,6 s), fast nur
Aufwärmen. Speicher: über die ganze Etappe Lüttich–Paris (16 min Spielzeit) kein Wachstum, keine
Waisen – kein Leck. Gegen Arcades `_draw` (9 ms) braucht der Renderer in GDScript nur ein Viertel.

Empfehlung für den Testbuild: Tunnel-Abhilfe (oder Modern auf Kiel–Hamburg beschränken), Mondglanz dämpfen und ein
Ersatz-Tankstellendach vorher; Brücke, Zieltor, Wahrzeichen, Wetter als bekannte Lücken in die Testhinweise; die
Leistungstest-Werte vom Deck (render-ms, 1 %-Tief) als einzige echte Leistungsaussage behandeln.
