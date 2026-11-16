# FIX-WASSER – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1
- Branch: worktree-wf_bdb6e1e1-c64-1 (Sicherung: origin wip/v080-fix-wasser)
- Basis: 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf (ff-merge erledigt 05:21 UTC)

## Erledigt
- 05:21 UTC Start, kein Vorgänger; ff-merge auf 3a23cb8; .godot kopiert; Import sauber
- Brückenliste aus den Daten: scan_bridges.gd (erste Fassung: scan_bridges.log; korrigiert je Brücke: scan_bridges2.log).
  Betroffen (tiefer als 4 m): Köhlbrandbrücke 9 m (HH), Holtenauer Hochbrücke 16 m (Kiel), Kirchenfeldbrücke 8 m (Bern, je nach Fenster),
  alle Schrägseilbrücken mit 5 m: Severinsbrücke (Köln), Elisabethbrücke (Budapest), Ada-Brücke (Belgrad), Vanšu (Riga).
- Fix far_ground.gd: target = min(lowest_road - drop, lowest_water - 0.3) (Commit 5f70201, gepusht)
- Unit-Test tests/unit/race3d/test_far_ground_water.gd: 4/4 grün, auf 3a23cb8 3/4 rot (ut_on_base.sh / ut_on_base.log)
- Erstes A/B Tag/Hoch km 77.5: shots/kb_tag_high_ab_0[0-3].jpg – Elbe da, Fähren schwimmen; grüner Streifen am Horizont
  (Fernboden jenseits des äußeren Rings 1000 m) statt Arcades grauem Ufer (shots/horizont_km78_5.jpg)
- modern-make: nur modern_s4_mittel neu (a55e8fa3 -> 3b8f9601), 944 s (golden_make.log, Bilder golden_make_keep/)
- Commit 0ad9012 (Liste + Doku), gepusht – Kandidat für den Schluss-Commit, Baum sauber
- scan_bridges2.log: 7 Brücken / 15 Richtungen betroffen, neue Scheibe überall 0,30 m unter dem Wasser
- scan_gaps.log: wo die Scheibe tiefer liegt, ist das schmalste Band in 300 m voraus 319 m (keine Lücke nahe der Straße)
- kb_nacht_high angesehen: Elbe dunkel wie Arcade, Fähren beleuchtet auf dem Wasser; Pylone nachts sehr hell (nicht Wasser)

- queue2 fertig: kb_tag_deck, kb_nacht_deck, kb_cover_deck angesehen – Elbe + Fähren ok; cover: 0,000 % Magenta,
  Fernboden 0,26–0,32 % + Kragen 0,43–0,61 % nur in den Zeilen 364–371 (Horizont 359) – keine Grube
- Build aus 0ad9012 fertig 06:11 (build.log), nach deliver/FIX-WASSER/build/ kopiert, sha256sum -c OK

## Jetzt (08:25 UTC) – FERTIG
- Alles erledigt: Fix + Test (5f70201), Liste + Doku (0ad9012 = Schluss-Commit, gepusht, Baum sauber), Build aus 0ad9012
  in deliver/FIX-WASSER/build (sha256 OK), Smokes Linux/GLES/Wine OK, Export-Bilder, Walk, alle Tore grün,
  alle Bilder (vorher/nachher) in deliver/FIX-WASSER/bilder, Nutzerdokumente, bericht.md fertig.
- Aufgeräumt: testbuild/, Wine-Präfix, Mesa-Caches, xdg-Ordner gelöscht.
- Ein Nachfolger muss nur noch das Ergebnis (StructuredOutput) aus bericht.md zusammenfassen.

## Fallstricke
- Bash-Tool: git-Befehle einzeln, keine Ketten mit git
- ab_shot Modern Hoch kalt 313 s; Mesa-Cache in $S/mesa; modern-make ~170 s je Bild bei Last 9

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER/
- Abgabe: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-WASSER/
