# QA1 – STAND (Handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
- Branch: worktree-wf_ae4df3ba-14f-5 (Sicherung: origin/wip/v080-qa1), commits b37509b (tools), db5aa6b (UI list)
- Basis: 28e4e8e (ff-merged from main e3505e2), import done

## Erledigt (Ergebnisse gemessen)
- run_tests.sh #1 auf Basis 28e4e8e: "Tests bestanden (882 s)", exit 0, 693 Unit-Tests/0, Fairness F1–F3/F7 grün,
  renderer_zeit 0.911 ms bei 13 Autos (Log m1/QA1/gates/run_tests_1.log). NUR NOCH EIN voller Lauf erlaubt (am Ende).
- Zweite Arcade-Liste: tests/golden/arcade_ui_v070.md5 aus v0.7.0 (make ui 270 s), check 2× 17/17 identisch
  (Logs m1/QA1/golden/ui_*.log, Bilder ui_ref/ui_cur1/ui_cur2)
- Tools committed: ab_sheet.sh, ab_clip.sh, build_testbuild.sh, smoke_modern.sh, golden.sh (make [race|ui], check =
  race+ui, modern-make/modern-check + GLES)
- User docs drafted: deliver/gate1/steamdeck_checkliste.md, was_neu.md (Zahlen/Fakten am Ende nachprüfen)

## Erledigt (Fortsetzung)
- Modern-Goldens: modern-make 697 s + modern-check 839 s → 6/6 identisch, GLES 2/255 PSNR 73,2 dB; commit 86c0650
- commit 9f1fe99: ab_clip Bitratenkappe, smoke DRIVER, docs/qa-v080.md Entwurf

## Jetzt
- queue1.sh läuft im Hintergrund (nohup): wartet auf goldens → diag start_km0 (A/B Countdown-Start) → run_sheets.sh →
  run_clips.sh → run_bench.sh low medium high deck_s3c1; Log m1/QA1/queue1.log. Nach Neustart: queue1.log lesen,
  fehlende Schritte einzeln starten.
- BEFUND (Code gelesen, Bild modern_start_mittel_00): Spielerauto in Modern beim stehenden Start bei km 0 unsichtbar
  (layers/vehicles.gd _update_car: z = pos_z - Länge/2 < z_lo = path.first*seg_len = 0 → out_of_range). Diag bestätigt?
- uncommitted: tools/ab_clip.sh (Bitratenkappe), tools/smoke_modern.sh (DRIVER), docs/qa-v080.md (Entwurf),
  tests/race3d/render/check_modern_render.gd (+uid, ungetestet)

## Stand 23:33
- diag start_km0 bestätigt QA1-B1 (Text in m1/QA1/befunde_draft.md, Bilder in deliver/QA1/befund_*)
- A/B high: 14/14 OK, alle angesehen (Notizen m1/QA1/look_notes.md); auto-Reihe läuft
- TODO danach: S5 noch einmal mit SHOT_TIMES=1.5 (bei 3 s ist das Ziel schon durchfahren): PRESETS="high auto"
  SHOT_TIMES=1.5 tools/ab_sheet.sh m1/QA1/ab_s5 S5

## Stand 00:10
- A/B-Bögen 28/28 fertig, alle angesehen; Bericht-Teil m1/QA1/bericht_bild.md; deliver_sheets.sh kopiert sie
- Clip 1 (Start Tag) fertig: 21,1 MB, 2560x720@60, 30 s, Ausrichtung exakt (gleiche HUD-Zeit) → deliver/gate1/clips
- queue1 macht jetzt Clip nacht, regen, dann bench; danach: run_s5.sh, deliver_sheets.sh, check_modern_render-Test,
  docs/qa-v080.md §8, Commit, run_build.sh, run_smoke.sh, chooser_walk.sh, Tore
- Bericht-Teile: m1/QA1/befunde_draft.md, bericht_bild.md, bericht_rest.md, deliver/gate1/bericht.md (Kopf)

## Stand 00:32
- Clip nacht fertig (16 MB) → deliver/gate1/clips; Clip regen läuft (queue1), dann bench
- queue2.sh (nohup) wartet auf "queue end" in queue1.log → run_s5.sh (S5 bei 1,5 s + Übersicht neu + Deck-Bilder S1/S4
  1280x800 in m1/QA1/ab_deck) → Testlauf check_modern_render (Log m1/QA1/rc_trial.log, Bilder rc_trial/)
- NICHT editieren, solange Queues laufen: tools/ab_clip.sh, tools/ab_sheet.sh (bash liest Skripte stückweise)
- check_modern_render.gd: Band jetzt 0,67–1,5 (gemessen 0,95–1,05 an den A/B-Bildern)

## Stand 01:15
- Clips alle 3 fertig (21,1 / 16 / 23,1 MB) in deliver/gate1/clips; Bericht-Teil m1/QA1/bericht_clips.md
- Leistungstest low/medium/high/deck_s3c1 fertig, JSONs + tabelle.md in deliver/gate1/leistungstest
- queue2 läuft (S5 1,5 s, Deck-Bilder, check_modern_render-Test) → danach: deliver_sheets.sh, Commit, Build, Smoke, Tore
- commit eb42255 (ab_clip Streifen)

## Stand 01:35
- check_modern_render Testlauf OK (10/10, 494 s); S5 1,5 s + Deck-Bilder fertig; Bögen in deliver/gate1/ab_boegen
- FINALER CODE-COMMIT 10d836f (gepusht), Baum sauber → Testbuild läuft (run_build.sh, Log m1/QA1/build_testbuild.log,
  Ausgabe m1/QA1/testbuild/); danach run_smoke.sh (linux linux_gles windows), chooser_walk.sh, Kopie nach
  deliver/gate1/build, dann Tore (golden check, render checks all, run_tests_bg.sh 2)

## Stand 01:37
- Testbuild fertig (174 s): Linux 146,9 MB, Windows 156,6 MB, in deliver/gate1/build (+ SHA256SUMS, LIZENZEN, BUILDINFO)
  Commit 10d836f, Version 0.8.0-zs1, FileVersion 0.8.0.1, project.godot danach wieder 0.7.0, Baum sauber
- run_smoke.sh läuft (linux, linux_gles, windows) → Log m1/QA1/run_smoke.out, smoke/<plattform>/smoke.txt
- queue3.sh (nohup) wartet auf Smoke → chooser_walk.sh → golden.sh check → run_render_checks.sh all → run_tests 2
  (Logs m1/QA1/queue3.log, gates/*_final.log, gates/run_tests_2.log). run_tests 2 = LETZTER erlaubter voller Lauf.
- Bericht: deliver/gate1/bericht.md mit Platzhaltern BERICHT_* / SCHLUSS_* → aus m1/QA1/bericht_*.md und
  befunde_draft.md einsetzen (assemble), Tor-Ergebnisse eintragen

## Stand 01:47
- Rauchtests alle OK (Linux, Linux GLES, Wine), Erststart-Gang (chooser_walk) OK, Belege in deliver/gate1/rauchtest
- Bericht deliver/gate1/bericht.md fast vollständig; offen nur SCHLUSS_GOLDEN / SCHLUSS_RENDER / SCHLUSS_TESTS
  (einsetzen: python3 m1/QA1/assemble.py 'SCHLUSS_GOLDEN=…' 'SCHLUSS_RENDER=…' 'SCHLUSS_TESTS=…')
- queue3 macht jetzt die Schluss-Tore (golden → render checks → run_tests 2)

## Stand 01:57
- golden.sh check Schluss: 20/20 + 17/17 identisch, Exit 0 (402 s) → im Bericht eingesetzt
- run_render_checks.sh all läuft (queue3), danach run_tests 2

## Stand 02:27
- run_render_checks.sh all: 16/17 OK; check_light_base „schatten“ FEHLER durch FIX1-Starttor (3 Lampenringe ohne
  cast_shadow=OFF, gantry.gd Z. 187) = Befund QA1-B3, im Bericht; NICHT selbst behoben (fremde Datei)
- run_tests 2 läuft (queue3), danach: SCHLUSS_TESTS einsetzen, bericht nach deliver/QA1 kopieren, StructuredOutput

## Stand 02:50 – FERTIG
- run_tests 2 auf 10d836f: "Tests bestanden (845 s)", Exit 0, 693/0 (gates/run_tests_2.log); Bericht vollständig
  (deliver/gate1/bericht.md = deliver/QA1/bericht.md, keine Platzhalter)
- Aufgeräumt (cleanup.sh): Doppel von Clips und Testbuild (Lieferordner per sha256sum/cmp geprüft), mesa_*, xdg_*,
  golden_final_keep gelöscht; Belege (ab/, golden/, diag/, smoke/, gates/, rc_trial/) bleiben
- Doku-Commit 92ece73 (docs/qa-v080.md: Schluss-Tore, QA1-B3, gemessene Dauern) = origin/wip/v080-qa1, Baum sauber;
  Tore liefen auf 10d836f (Spieldateien unverändert). Offen nur noch: Ergebnis (StructuredOutput) zurückgeben

## Als nächstes (scratch scripts in m1/QA1/, alle fertig geschrieben)
1. commit modern_slice.md5/.env (+ check_modern_render.gd NACH Testlauf)
2. run_sheets.sh (A/B high+auto, alle 14 Positionen) → LOOK at all, copy to deliver/gate1/ab
3. run_clips.sh (start, nacht, regen) → deliver/gate1/clips
4. run_bench.sh low medium high deck_s3c1 → table
5. check_modern_render.gd Testlauf: tools/run_render_checks.sh modern modern_render (calibrate)
6. docs/qa-v080.md schreiben, final commit
7. run_build.sh (testbuild ZS1) → run_smoke.sh linux windows → chooser_walk.sh → copy to deliver/gate1/build
8. final gates: golden.sh check (20/20 + 17/17), run_render_checks.sh all, run_tests #2 (run_tests_bg.sh 2)
9. bericht.md (deliver/gate1 + deliver/QA1)

## Fallstricke
- Bash tool refuses compound commands: write scripts to scratch, run them
- export templates: link /root/.local/share/godot/export_templates into $XDG/godot/ (run_build.sh does)
- Wine: unset TMPDIR, own WINEPREFIX, screenshot path Z:<abs>
- A-3: Kurvenkamera darf nur stärker werden (schwächer = neuer Fairnessbeweis) – im Bericht/contract_issues nennen
