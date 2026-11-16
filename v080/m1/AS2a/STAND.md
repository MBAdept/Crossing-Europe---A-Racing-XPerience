# AS2a – STAND (Übergabe für Nachfolger)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
Branch:   worktree-wf_72970c4d-66e-1  (Sicherung: origin wip/v080-as2a, nach jedem Commit gepusht)
Basis:    c478902 (AS1R) ff, dann R3 4d02ada per --no-ff gemergt (fa6560c)
Kopf:     19aa138 (gepusht) – FERTIG, Abschlussmeldung abgegeben

## Ergebnis
- Commits: d527535 Verkehr suv/van/sports; eda9449 Spieler kombi/sportwagen/GT + Wrap/Projektoren/brake3/Felgen;
  0d3bdc3 Glas 0,48 + AgX; 135b265 Runde 4 (Einlässe durch alle Körper, Rückbank, lod2-Scheibe Sports);
  19aa138 Doku (Zahlen, Prüfungen, Grenzen)
- Prüfer grün; 26/26 Pkw-Sets + 5/5 Spieler + 5/5 Showroom mit Modell; showroom alle false (A/B Bild 07)
- check_sprite_geometry 187/187 identisch (697 s); Determinismus grün (git leer, 2. Bake byte-gleich, check-keys OK)
- golden 20/20 identisch
- run_tests: ROT nur in tests/race3d/check_vehicles.gd (R3): kasten (Fixture traffic/sports_red hat jetzt Modell),
  leistung (traffic/sports_yellow der Etappe wechselt in Bild 17 lod1->lod2, _set_level baut Stufe beim ersten
  Gebrauch). Datei NICHT geändert (gehört R3) – als Vertragsfrage gemeldet mit Vorschlag.
- Lieferung: deliver/AS2a (13 Bildtafeln + bericht.md)

## Werkzeuge (Scratch m1/AS2a/bin)
- rebuild.sh "<glob>" [--force]; sheet.sh <out.png> <contact sheet args> (ABSOLUTE Ausgabepfade!)
- deliver.sh, pop.sh, finish_images.py; determinism.sh; measure.sh (inspect + report + lamptable)
- ana2.py clear|lamps (nach dump2.gd), intake.py, rearpane.py, paneband.py, diag_vehicles.gd (Test-Diagnose)

## Fallstricke
- nice -n 19, --jobs 1, nie zwei schwere Jobs gleichzeitig.
- sheet.sh macht cd in den Worktree: relative Ausgabepfade landen im Repository!
- _decal_items gruppiert nach Material-Preset: Reihenfolge der Lampenliste zählt.
- far_glass-Schwelle per Design (far_pane_ny); eine Bereichsregel machte die Limousine schlechter.
