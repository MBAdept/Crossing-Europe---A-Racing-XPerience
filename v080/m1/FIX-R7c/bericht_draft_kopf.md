# FIX-R7c – Nacharbeit nach der unabhängigen Prüfung von R7c (Fern-LOD der Bauten und Pflanzen)

- Basis: R7c `bd1803b` (`origin/wip/v080-r7c`), Prüfbericht `deliver/QA-R7c/bericht.md` (8 Befunde, kein Blocker, kein
  hoher). Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10`, Zweig
  `worktree-wf_ba4424b4-294-10`, gesichert als `origin/wip/v080-fix-r7c`.
- Vergleichsbaum für „vorher“-Bilder und die Leistung: `m1/FIX-R7c/ref` (= `git archive bd1803b` + `.godot`,
  importiert). Die Bilder von QA-R7c ließen sich daraus **bit-genau** nachstellen (Hamburg Deck 12 Uhr zwei Bilder,
  Countdown Nürnberg – Fulda: 0 Pixel Unterschied, `compare -metric AE`) – die „R7c“-Spalte der Bildvergleiche ist
  also QAs Bild desselben Simulationsstands.
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt); **angesehen** = Urteil nach Bildern;
  **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen).
