# FIX-WASSER-R – Stand

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3
- Branch: worktree-wf_bdb6e1e1-c64-3 (Sicherung: origin/wip/v080-fix-wasser-r), Kopf 39849f0 (gepusht)
- Basis: 0ad9012 (FIX-WASSER-Kopf)

## FERTIG (11:40 UTC)
- Commits 2011ec8 (props.gd B1/B2, Tests, B5) und 39849f0 (Doku), beide gepusht.
- Gates auf 39849f0 grün: check_scripts 307/0, run_tests 705/0, golden arcade 20/20 + 17/17, modern 6/6 (+GLES OK),
  render checks 18/18 (K1 0,38 % Fernboden).
- Build 0.8.0-zs1 aus 39849f0, geliefert nach deliver/FIX-WASSER/build (sha256 --ignore-missing OK); alter Build
  (0ad9012) in alt/ (Rückfall, löschbar). Spielpaket: nur props.gdc anders.
- Smokes: Linux OK, Linux GLES OK, Windows/Wine OK; Exportbilder Start + Brücke Tag/Nacht (Linux = Windows pixelgleich);
  Erststart-Lauf OK.
- Doku: deliver/FIX-WASSER/was_neu.md, steamdeck_checkliste.md geändert; Bericht deliver/FIX-WASSER-R/bericht.md.
- Aufgeräumt: testbuild/, Wine-Präfix, Shader-Caches, xdg-Ordner gelöscht.

## Offen (für die Nächsten)
- B3 (Kaimauern/fernes Ufer), Pylonfüße bei Tag, rotes Warnlicht, Elbphilharmonie nachts, Wahrzeichen als echte
  Zeichnung/Modell, Belgrader Stadtrand rechts ohne Häuser (gesehen, nicht untersucht).
