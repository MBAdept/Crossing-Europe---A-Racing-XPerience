# FIX-M2 STAND

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5
- Branch: worktree-wf_438996b0-243-5 (push: origin wip/v080-fix-m2 nach jedem Commit)
- Base: 6e48405 (ff-merged), .godot kopiert + importiert

## Erledigt
- f45268e (gepusht): B-05 SPOT_SPECULAR 0 (lights.gd); B-03/B-04 VehiclePose3D.model_glow_gain (Bremse 2,2,
  Blaulicht 2,4, nur Modelle); Render-Prüfungen blaulicht/abblendlicht (check_vehicle_lights, Mutation geprüft:
  abblendlicht rot mit altem Wert); M2S-07 Rückfalltext Dateien + check_seam rueckfall_dateien; M2S-04 Logger im
  run_tests.gd (mit Test-Datei geprüft, gelöscht) + test_props null-Prüfung.
- B-01 nachgestellt (sh/props_probe.sh, fair/props_base_*.txt): T4 9/12, T2 9/18, T1 5/13, C1 4/16, S4 3/12, T3 4/8, S0 Eiche.
- Fahrzeugsonde: probe/qa_vehicles.gd (+ --flaredump, --depth_eps, --flare_strength, --spot_spec), sh/veh.sh,
  sh/lc.py (TAGS=...), QA-Bilder arc/zs1/m2 in shots/veh (m2 = bitgleich mit meiner Basis), fx1_* = nach Fix.
  Bögen shots/sheet_h12_*.jpg, sheet_h22_*.jpg.

- 7a45fe5 (gepusht): M2S-01 Wald 20 s + ZEITLIMIT + Kopfzeile Zeitlimit (Mutation vpbr: rot, 456 s); M2S-02/03/05/06; Doku 14.10.
- 86c58e1 (gepusht): standin mit sports_red (Kuppe), alle 6 Fälle OK.
- B-01 Studie: probe/fx_chord.gd, fair/chord_full.txt, fair/chord_positions.txt (F2-Sehne nur in Saragossa–Pau < 300 m).
- Merge-Baum mit R4: m1/FIX-M2/mt (git archive von merge-tree, .godot kopiert, Import fehlt noch) – sh/mt_queue.sh.

## Entscheidungen
- B-02 (Niederschlag), B-10 (Sonne), B-08 (lod0-Überblendung): in R4 (818816c, 9a5ffe4/e68b51f); Flackern auf
  Nutzerwunsch pausiert -> nicht hier.
- B-06 (Spielerlack): R4 ändert VEHICLE_LOOK (fill/hemi/sheen, check_night Sättigung) -> erst auf Merge-Baum
  (merge-tree HEAD + origin/wip/v080-r4) messen, nicht doppelt korrigieren.
- B-01: A-3/A-10 = Leitungsentscheidung zu Zwischenstand 2; nur vorbereiten (Schalter, Bilder, Zahlen).

## Als Nächstes (Stand 11:20)
- B-01 Vorschau (NICHT committen): sh/preview_corridor.py apply veg 119 -> sh/occl.sh modern T4_prev ... + shot T4 -> revert
- sh/mt_queue.sh (Import Merge-Baum, S1/C1/N1 Lack, Fahrzeugsonde) -> B-06 entscheiden
- Gates: run_tests (1/2 genutzt: 0), render_checks all, golden check, sight/path nicht nötig (keine Platzierung geändert)
- M2S-01 Waldprüfung (SIM_S überschreibbar, Laufzeit je Phase, ZEITLIMIT-Meldung in run_render_checks.sh)
- M2S-05, M2S-03, M2S-02, B-09, M2S-06
- B-07 Laden/collect untersuchen
- B-01 Vorbereitung
- Doku docs/renderer-modern.md, Gates, Bericht

## Fallstricke
- git-Befehle einzeln (keine && Ketten mit git), Commit-Text per Datei (msgN.txt)
- ACHTUNG: scripts/race3d/builders/props.gd steht ggf. im Vorschau-Zustand (B-01) -> python3 sh/preview_corridor.py revert, dann Diff prüfen!

## Tore (seit 12:58): sh/gates.sh läuft (setsid), Log logs/gates.log, Ausgaben gates/*.log; bei Neustart einfach sh/gates.sh neu starten (erledigte Schritte werden übersprungen). Nach modern_make: Bilder gates/modern_keep ansehen, dann tests/golden/modern_slice.md5 committen.
- Head vor den Toren: 6209384 (B-06 final 0ad9487). B-06 auf Merge-Baum gemessen: Limousine 0,631 (Arcade 0,583), Sportwagen 0,391 (0,344), Kompakt Nacht 0,755 (0,718).
- 515dd51 (gepusht): Modern-Goldens neu (Bilder angesehen). gates.sh läuft weiter: run_tests, render_checks, golden_check.
- run_tests (1. Vollauf, 13:12–13:35): 751 Tests, 3 rot (test_engine3 thread, test_modern race, test_music race = Last, wie bei R4) + check_modern_stage kern_zeit (Einhängen 4,39 ms > 3 ms, Last). Nach den Render-Prüfungen einzeln nachfahren (Filter).
- 2026-11-15 Abschluss: Bericht fertig (257 Zeilen), Endstand 515dd51 gepusht nach origin/wip/v080-fix-m2, Arbeitsbaum sauber; nur noch Rückgabe.
