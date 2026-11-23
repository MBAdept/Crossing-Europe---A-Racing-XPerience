## 2. Prüfumfang (die sechs Punkte des Briefs)

1. **Bilder:** 27 Kombinationen (6 Städte + Wald + Countdown; Hoch und Steam Deck; 12 / 19:30 / 22 Uhr), je Arcade |
   Basis 9b02f05 | R7c, an sechs Stellen zusätzlich 43a1fcc; 7 Kombinationen aus Zeitgründen ausgelassen
   (`sh/tri_skip.txt`: Deck 12 Uhr Amsterdam/Bern/Lyon, Nürnberg 19:30, Lyon 22 Uhr, Hamburg Deck 19:30, Wald Deck 22
   Uhr). Jedes Bild angesehen, kritische Stellen vergrößert und gemessen (Abschnitt 5). R7cs zwei Clips Kachel für Kachel
   ausgewertet; eigener Clip nicht aufgenommen.
2. **Funktion:** echte Stück-Bauten aller 128 Richtungen + DEV in drei Bäumen, Bänder aller Modelle (Abschnitt 3.2).
3. **Fairness:** `modern_sight --full`, `modern_path_check --full` (Abschnitt 3).
4. **Arcade-Identität und Besitz:** `tools/golden.sh check`, `git diff --stat`, Zusammenbau-Proben (3.1, 3.5).
5. **Tests:** `tools/run_tests.sh` (einmal voll), `tools/run_render_checks.sh all`; 17 Mutationen (3.3, 3.4).
6. **Leistung:** `run_stage.gd` mit `perf_stats`, Deck und Hoch, R7c gegen 43a1fcc und Basis (Abschnitt 6); zusätzlich
   Fernlicht nachgemessen (5.2) und Studio-Vergleich lod0 | lod1 | Sprite (QR7c-01).
