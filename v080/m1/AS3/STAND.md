# AS3 – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-1
- Branch: worktree-wf_aad8d49e-fb4-1  (Sicherung: origin wip/v080-as3, nach jedem Commit gepusht)
- Endstand: be866d2 (alle Commits gepusht). Basis 8f58b2d.
- Bericht und Bilder: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3/ (bericht.md)

## Commits
- d4f0d83 Laubkuppeln + prop_scene --look=race/--sprite/clip/UMSCHALT
- f67ade1 sieben Arten je 2 Varianten, Hooks props_nature (geometry 86/86 identisch)
- accba59 Heide, Felsen, Klippe, Büsche; Farbabgleich
- 76c743b docs/modelle.md §15; 8c48f77 Bodengras dichter/dunkler
- 791853f Fichte lift (1, 1.16), Fernbild 1.38; prop_scene --mode=lods zeigt die Stufen des Props-Bauers
- 6222b66 docs §15 (Fichten-Fernbild, lods-Spalten); be866d2 contact_sheet.gd baut Varianten ohne Set

## Gates (Endstand be866d2)
- validate --report: CHECK models OK; check-keys OK; Determinismus: det3.sh (erzwungener Export aller 27 AS3-Modelle,
  Bake, Import, Manifest) -> git status leer
- A/B: 4 Stellen (Alpen/Heide/Mittelmeer/Pyrenäen) hoch 12 + Alpen mittel 19.5 auf 6222b66, alle exit 0, 0 Fehler
- gates.sh: Kontaktbögen neu, check_sprite_geometry --only props --jobs 1, run_tests.sh, golden.sh check -> logs/gates.log

## Offen / Hinweise
- Fichten-Fernbild mittags −8/−11 %, Palmen-Fernbild Farbton −16°, Stufenwechsel ändert 34–76 % der Pixel
- Props-Bauer F7 lässt Klippen/Felsen in Kurvenkorridoren weg (drops.gd zählt es)
- 15.8 MB doppelte Atlanten (Varianten = Grundart)

## Fallstricke
- leafatlas.halo/bleed/coverage/png_bytes nicht ändern (Strommast-Lattice nutzt sie)
- Godot-Glob kennt nur * und ?; veg3d.py steht im Cache-Schlüssel aller AS3-Modelle (Rock-Bauer importiert veg3d)
