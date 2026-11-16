# QA-WASSER – Unabhängige Prüfung des neu gebauten Testbuilds „Zwischenstand 1“ (v0.8.0-zs1 aus `0ad9012`)

Für die Leitung. Prüfrolle, keine Commits, kein Push. Worktree `…/.claude/worktrees/wf_bdb6e1e1-c64-2` (Branch
`worktree-wf_bdb6e1e1-c64-2`, per `--ff-only` auf `0ad9012353855295255c27dd987b90e30ff0f33f`, sauber). Kein Vorgänger
(keine `STAND.md`) – frisch begonnen um 08:22 UTC.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne); alles über Steam Deck, echte Grafikkarten,
ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.
Alle Bilder aus den **gelieferten** Programmen (nicht aus dem Projekt), mit `--fixed-fps 60 -- --gfx-sync` (gleiche
Bildzeiten in beiden Modi, Wächter aus, die gewählte Stufe bleibt stehen), je Lauf ein frisches `XDG_DATA_HOME`.

## Urteil

**Der Build kann zum Nutzer.** {{URTEIL_GATES}}

- **Die Behebung wirkt im ausgelieferten Build**: Die Elbe liegt unter und neben der Köhlbrandbrücke, die Fähren
  schwimmen – Tag und Nacht, „Hoch“ und Steam-Deck-Stufe (1280 × 800), im Linux-Export und im Windows-Export unter
  Wine (die Windows-Bilder sind **pixelgleich** mit den Linux-Bildern). Keine Grube, keine Naht, kein Springen des
  Bodens beim Absenken der Scheibe (km 67,1) und auf der Anfahrt ab km 76,5.
- **Der Build ist genau der geprüfte Stand**: Gegen den zuvor gelieferten Build (FIX-ZS1) unterscheidet sich im
  eingebetteten Spielpaket **genau eine von 1.011 Dateien** – `scripts/race3d/layers/far_ground.gdc`, in Linux und
  Windows; sie enthält die neuen Namen (`lowest_water`, `WATER_MARGIN_M`, `water_y`). {{URTEIL_REPRO}}
- **Code und Test**: Nur die vorgesehenen Dateien, keine Arcade-Datei. Die Scheibe kann nur tiefer liegen als vorher –
  sie verdeckt also nichts, worauf der Spieler reagieren muss (F7). Der neue Unit-Test ist ein echter Wächter: vier
  absichtliche Fehler in `far_ground.gd` (alte Regel, kein Abstand zum Wasser, Springen statt Gleiten, überall 0,5 m
  tiefer) werden alle erkannt (3, 3, 1 und 2 von 4 Tests rot), unverändert 4/4 grün.
- **Ehrlich zum Bild**: An der Köhlbrandbrücke ist Modern jetzt **gleichwertig bis etwas besser** als Arcade (echte
  Pylone und Seilfächer, Wasser, Fähren), **nicht deutlich besser**: das Wasser ist eine glatte, zum Horizont grau-
  helle Fläche, am Brückenende fehlt Arcades Kaimauer, nachts leuchten die Pylone fast weiß, die Pylonfüße wirken bei
  Tag verwaschen. Neu gefunden (nicht vom Wasser, schon im vorigen Build): **in sechs Städten fehlt in Modern das
  Wahrzeichen** (Belgrad gesehen; Hannover, Leipzig, Dortmund, Calais, Madrid aus den Daten) – Hannover liegt auf einem
  der zwei Wege des ersten Rennens Kiel – Nürnberg.

{{REST}}
