# FIX-ZS1 – Stand (Übergabe) – FERTIG 05:17 UTC

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
- Branch: worktree-wf_9559b070-4dd-1 = origin wip/v080-fix-zs1 = 3a23cb8 (Schluss-Commit, sauber, gepusht)
- Basis: 92ece73 (QA1 final head)

## Ergebnis
- FIX 1 (QA1-B1) + FIX 2 (QA1-B3) behoben; neue Render-Prüfung check_start_km0.gd (rot auf 92ece73, grün jetzt),
  Unit-Test test_start_lead_in.gd (6/6).
- Tore auf 634e28b (3a23cb8 = nur docs): import sauber, check_scripts 306/0, run_tests bestanden (699/0, 146 CHECK OK),
  golden check 20/20 + 17/17, modern-check 6/6 + GLES OK, render checks 18/18.
- Testbuild aus 3a23cb8 in deliver/FIX-ZS1/build/ (sha256sum -c --ignore-missing OK); Export-Starts Linux/Wine,
  Rauchtests Linux/GLES/Wine, Erststart-Walk OK.
- CHECK 3: nicht behoben (Fernboden deckt Elbe unter Köhlbrandbrücke) – gemeldet.
- Bericht: deliver/FIX-ZS1/bericht.md; Bilder deliver/FIX-ZS1/bilder/; Nutzerdokumente deliver/FIX-ZS1/*.md.

## Aufgeräumt
- testbuild-Programme/Archive (liegen in deliver), Wine-Präfix, Mesa-/Shader-Caches, xdg-Ordner, golden_make_keep.
