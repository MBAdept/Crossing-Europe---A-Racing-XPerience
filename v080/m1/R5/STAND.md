# R5 STAND (Tunnel, Brücken, Wasser) – Übergabe

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2
- Branch: worktree-wf_fd1de4ee-28b-2 (Sicherung: origin wip/v080-r5)
- Basis: 6e484056ec87e2fa614061000a362feb2b5a6db8 (ff gemerged)
- Basis-Kopie für Vergleichsbilder (git archive + .godot): m1/R5/base (WT=… für tools/ab.sh) – am Ende löschen

## Commits (gepusht)
- 173a412 bridge.gd + water.gdshader
- 937d3b2 tunnel.gd v2 + tunnel.gdshader v2 + far_ground.gd (Fernwasser/-land/-ufer)
- 452d96b test_bridge.gd (9 grün), test_tunnel.gd (7 grün), Gehweg wie Arcade (0,9 m/0,25 m)
- 51774de Hügel nach Arcade (Folge, Verlauf, Bäume), Lichthof von außen, Seile hell, Wasser dz, check_tunnel_bridge, Doku
- 649be5d Hügelhang nie durch die Röhre (+Test), Seile 0,07 m, Fliesen ruhiger, Check-Fixes
- 8456140 Wasser nachts ohne Glitzerpunkte
- uncommitted: nichts (Stand 19:45)

## Nachfolger 4 (15.11. 08:05): Container-Neustart (2 Tage Pause). Scratch-uids im Worktree gelöscht.
- Erledigt: import4.log sauber, Unit race3d 137/0 (unit_race3d_4.log); Nachtreihe shots/row gemessen (alle ≤ Arcade: 73,1/55,9/46,2/53,1/49,4 gegen 76,5/60,1/48,1/54,3/51,6).
- LÄUFT seit 08:07: tools/batch5.sh -> batch5.log (kb_beacon abgebrochen – Spitze hinter HUD; u1_nacht, damm_venedig, gracht_amsterdam, 3× deck -> shots/new3, dann clip_u1, clip_kb -> clips/). Hintergrund-Limit 2 h: Clips ggf. einzeln nachholen (batch5.sh clip_u1 / clip_kb).
- Danach einzeln (je eigener Hintergrundjob, max 2 h): tools/batch6.sh (new4: b1, somport, u1_ausfahrt, kb_nacht2 vom Endstand + check mit --save -> check5/ inkl. Beacon-Bild ohne HUD); gates.sh in Teilen; perf.sh new / base (jetzt Kiel–Hamburg).
- chain.sh NICHT benutzen (2-h-Limit).
- 19:20: FERTIG. Clip KB in deliver/R5/clips (2923 s Modern). Bericht deliver/R5/bericht.md final. Nur noch StructuredOutput.
- 18:35: Bericht fertig zusammengebaut (deliver/R5/bericht.md via tools/assemble.py). HEAD 5558bdc = origin/wip/v080-r5. Basiskopie gelöscht. NUR NOCH: clip_kb (läuft, ETA 19:15) -> Bilder ansehen, nach deliver/R5/clips kopieren, StructuredOutput.
- 18:15: run_tests #2: 767/3 fehlgeschlagen (Klang-Echtzeit unter Last; einzeln grün, modern_checks auch auf Basis rot) – im Bericht. LÄUFT: clip_kb mit CLIP_TIMEOUT=6000 (clip_kb_run2.log). Danach: Clip ansehen, nach deliver/R5/clips kopieren, assemble.py, Push-Prüfung, StructuredOutput.
- 17:45: clip_kb Modern Zeitlimit 3600 s überschritten (fast fertig) -> nach den Tests neu mit CLIP_TIMEOUT=6000 (ab_clip.sh Variable) als eigener Job. LÄUFT: run_tests #2 (letzter; gates/tests.log, Lauf 1 = gates/tests_lauf1.log). Bericht-Teile fertig, tools/assemble.py baut deliver/R5/bericht.md (Platzhalter TESTS2, HEAD).
- 16:30: batch6 fertig (new4 + check5), deliver2.sh gelaufen (deliver/R5/bilder), counters fertig (perf/counters_*.log, im Bericht). LÄUFT: clip_kb (clip_kb_run.log). Danach run_tests #2 (letzter!), Bericht zusammenbauen, aufräumen (base-Kopie!), StructuredOutput.
- 15:35: perf base fertig (Vergleich: render avg 3.13->3.97 ms, Last beim neuen Lauf ~16-25 % höher (sim_avg 1.73->2.00, wall 3127->3914 s); draw_calls/primitives in PERF sind nur das letzte Bild -> tools/counters.sh new|base misst an Köhlbrand/U1). LÄUFT: batch6 (batch6.log). Danach counters new/base, clip_kb, run_tests #2, deliver2, Bericht.
- 14:40: perf new fertig (perf/new.log: 3920 s, 0 Fehler, render avg 3.97/max 139.7 ms, commit max 8.0, far_ground hook max 69.9 ms!). LÄUFT: perf base (perf/base.log). Danach: far_ground-Spitze mit Basis vergleichen, batch6, clip_kb, run_tests #2, deliver2, Bericht.
- 13:40: sight/path --full OK. NÄCHSTES: perf.sh new, perf.sh base (je eigener Hintergrundjob), batch6, clip_kb, run_tests #2.
- 13:30: Waldprüfung allein OK (2188 s). QA_M2_FERTIG existiert -> nice 10. LÄUFT: gates.sh sight path (gates_run4.log). Danach perf new/base, batch6, clip_kb, run_tests #2, deliver2.sh, Bericht.
- 12:45: render all: alles OK außer check_instance_budget_wald Exit 124 (900 s, bekannter Basisbefund M2S-01 aus QA-M2-SYSTEM: Last). LÄUFT: Waldprüfung allein mit RENDER_CHECK_TIMEOUT=3600 (gates/render_wald.log). Danach sight path, perf, batch6, clip_kb, run_tests #2.
- 11:50: Gates: import ok, scripts 314/0, golden 20/20 + 17/17, modern-check 5/6 (s4 gewollt, angesehen, 5558bdc gepusht; GLES ok). LÄUFT: gates.sh render (gates_run3.log). Danach: sight path, perf, batch6, clip_kb, run_tests #2 (letzter!).
- 10:55: 2919660 gepusht (far_ground ARCADE_QUAY statt RoadRenderer.QUAY – check_terrain_plan fiel im vollen Lauf; Pin-Test). Voller run_tests #1 (gates/tests.log): nur check_terrain_plan rot -> behoben. Voller Lauf #2 erst ganz am Ende (letzter erlaubter!). Clip U1 fertig (clips/u1_gotthard.mp4). LÄUFT: gates.sh golden modern_check (gates_run2.log). Danach: render, sight path, perf new/base, batch6, clip_kb, run_tests #2.
- 09:35: ef88c1a gepusht (Netzlauf --full: 122 Brücken, 26 Tunnel, 0 Mängel, 90 s, full_scan.log). batch5 gestoppt (deck fertig). LÄUFT: batch5.sh clip_u1 (clip_u1_run.log, clips/). Danach (Priorität Gates zuerst): gates.sh in Teilen (import scripts tests | golden modern_check | render | sight path), perf.sh new/base, batch6.sh, batch5.sh clip_kb.
- 08:50: new3 fertig: u1_nacht, damm_venedig, gracht_amsterdam (angesehen: ok). Deck läuft. Plan: nach kb_rampe_deck batch5 stoppen (TaskStop) und Clips einzeln (batch5.sh clip_u1, dann clip_kb), dann --full-Scan, batch6, Gates, Perf. Neue Befunde für R4 in bericht_teil_naechste.md (Abblendlicht ohne Kante -> Portal nachts hell; Fahrbahn im Tunnel von außen kalt). Lieferskript: tools/deliver2.sh.
- cb08179 (gepusht): check_tunnel_bridge -- --full (Netzlauf aller Brücken+Tunnel, headless) + Doku Abschnitt 7. NOCH LAUFEN LASSEN: godot --headless -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full (Zeit messen, in Doku "rund 4 Minuten" korrigieren).
- Bericht-Teile: bericht_kopf.md, bericht_teil_tests.md, bericht_teil_naechste.md (+ alte Teile gebaut/entscheidungen/mess/bilder)
- Bilder new2 vor 649be5d/8456140: b1, somport, u1_ausfahrt, kb_nacht2 -> durch new4 ersetzen (deliver.sh anpassen).

## Nachfolger 3 (13.11. 05:25): Container-Neustart, batch2c Nachtreihe abgebrochen (row new_modern 00-04 da, base fehlt). Weiter: Unit-Tests, Bilder ansehen, Reste rendern, Gates.

## Lief (vor Neustart)
- batch2c (Log batch2c.log): new holtenau, kb_ende, u1_innen; b1 neu; Nachtreihe row new/base
- danach: Unit-Tests (neuer Hügeltest!), commit, gates.sh in Teilen (Hintergrund max 2 h!), perf.sh new/base, batch3 deck + clips
- Bilder fertig (new2 + Dreier *_abn_*.jpg): u1_ausfahrt, somport, elbbruecken, stein, kb_nacht2, dev, kb_rampe, u1_anfahrt

## Ergebnisse bisher
- new1 (vor Hügel/Lichthof-Fix): kb_rampe, holtenau, u1_anfahrt, u1_innen in shots/new1 (+ *_abn_*.jpg Dreier)
- Render-Check: U1_portal 0 %, U1_innen 0 % Magenta/612 Leuchtenpkt/0,322, B1 0 % Fernboden, Somport 0 %, Ausfahrt 0,226, Beacon 4/4 blinken

## Als Nächstes
- Bilder ansehen (Dreier Arcade | Basis | R5 mit tools/combine.sh), Nachtreihe messen (x500–780, y150–350)
- Gates: import, check_scripts, run_tests (≤2×), golden check, modern-check (s4 ändert sich: ansehen, modern-make), render checks all,
  modern_sight/path --full, Perf hamburg_hannover (Elbtunnel+Leinebrücke) neu vs Basis unter Xvfb
- bericht.md, deliver/R5 Bilder, StructuredOutput

## Stolperfallen
- 1 km Etappe = 100 m sichtbar (time_scale 10): Valík 40 m (kürzer als peek_m), Elbtunnel 330 m, Gotthard 1690 m
- Köhlbrand: km 78,00–80,61, Pylone km 78,705 / 79,905 (95 m); Beacon im Bild nur mit Kamera ≥ 220 m davor (km ≤ 76,5)
- Flares: Tunnelleuchten nur nachts/Kamera im Tunnel an -> Lichthof von außen bei Tag im tunnel.gdshader
- Bash: keine Heredocs mit cd; Skripte nach m1/R5/tools schreiben; kein sleep-Polling (until-Schleifen im Hintergrund)
- pkill verboten -> TaskStop für eigene Hintergrundjobs
- Basis-Bilder NIE aus dem Worktree rendern -> WT=m1/R5/base
- r5_scratch_*.gd im Worktree-Root ist Scratch: NICHT committen, am Ende löschen
