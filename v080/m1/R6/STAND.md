# R6 STAND (Übergabe für Nachfolger)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
- Branch: worktree-wf_3b3101bc-877-1  (Sicherung: origin wip/v080-r6, nach jedem Commit pushen)
- Basis: 6e484056ec87e2fa614061000a362feb2b5a6db8 (ff gemergt, .godot kopiert, Import sauber)

## Erledigt (Commits auf wip/v080-r6, Stand 17:10, Kopf 5393f3c)
- f849f01 … 8ddbeca: station/gantry neu, border/city/radar neu, Tests, Doku, Nachtleuchten
- 2d80276 / 3e286d3 / a625d93: F1 – Pfeiler (Grenze) und Stützen (Tankstelle) nie vor einem Schild: rücken nach
  außen jenseits der Schildtafeln (Träger zur Dachkante); Grenze: 43/48 Dächer beidseitig, 4 einseitig (Kurve, F7),
  Somport ohne Dach (Tunnel). Auswertungsskripte bin/border_pillars.gd, bin/station_columns.gd.
- a625d93: Blitz-Stärke / 0,35 (flares STATIC_HALO), Render-Prüfung in zwei Dateien (check_structures.gd +
  check_structures_licht.gd, je < 900 s)
- Render-Prüfung Lauf 1 (alter Stand, 1205 s): countdown, zieltor, grenze, stadt, schatten OK; tankstelle (Blende
  vom ersten Dach verdeckt -> Startpunkt 13.62) und blitz (zu schwach) FEHLER -> behoben, Wiederholung läuft

## Stand 18:25 (Kopf bb38876)
- batch2 fertig (v3_*), alle angesehen; daraus: Zielbanner nachts dunkel -> 7b27108/bb38876 (Nachtbild der Banner),
  Schein vor dem Tankstellengebäude dfaa4cd; v3_kh_city_night ungültig (Modern fiel wegen halbem Edit auf Arcade)
- läuft: bin/chain2.sh = batch3 (v4_*: DEV Start/Ziel Tag+Nacht, Blitzer Tag, Tankstelle Nacht, KH Stadt Nacht)
- danach: bin/clips.sh (eigener Job), bin/golden_make.sh, Commit md5, gates_a/b/c, perf.sh head + base

## Stand 19:45 (Kopf bb38876, Code eingefroren)
- batch3 (v4_*) fertig, Bilder 01–22 + 5 Bögen in deliver/R6, bericht.md Entwurf (Abschnitt 3 + Clip-Tabelle fehlen)
- Clip countdown_los fertig (8 s, angesehen: rot -> grün bei LOS in beiden Modi)
- läuft: clips.sh tanken_km15 ziel (Job b0rhw3emd, Log shots/clips_a.log)
- danach je eigener Job: golden_make.sh -> Bilder ansehen -> md5 committen/pushen; clips.sh blitz_polizei;
  gates_a.sh; gates_b.sh; gates_c_list.sh (Render-Prüfungen einzeln je Filter, Zustand gates/rc_done.txt, neu
  starten bis alle 18 erledigt); perf.sh head <WT>; perf.sh base R6/base
- clip_*.log aus deliver/R6 nach shots/ verschieben

## Gerade dabei (alt)
- bin/chain1.sh (Hintergrund): rc blitz, rc tankstelle (licht), dann batch2 (v3_*, 16 Bildsätze)
- danach: bin/clips.sh (eigener Hintergrundjob, max 2 h je Job!), dann Gates, dann perf (bin/perf.sh head/base)

## Als Nächstes
- Gates: import, check_scripts, run_tests.sh (max 2x), golden.sh check + modern-make (4 von 6 Modern-Bildern
  ändern sich absichtlich: Start, S2 Tankstelle, S4 Stadt, S5 Ziel) + modern-check, run_render_checks.sh all
  (RENDER_CHECK_TIMEOUT hoch setzen), modern_sight --full, modern_path_check --full, perf head vs base
- bericht.md (Entwurf in deliver/R6), Bilder + Bögen (bin/sheet.sh)
- Basis-Kopie R6/base (577 MB) nach perf löschen

## Stolpersteine
- QA läuft parallel: solange m1/lead/QA_M2_FERTIG fehlt -> nice -n 19, schwere Jobs einzeln
- Hintergrundjobs werden nach 2 h abgebrochen -> Ketten kurz halten
- Heredocs/komplexe Befehle verweigert das Bash-Werkzeug: Skripte schreiben

## Nachfolger-Lauf 3 (13.11. ab 05:25, Container neu gestartet; Worktree sauber, Kopf bb38876 = origin)
- Code bleibt eingefroren (bb38876). Clip tanken_km15 war abgebrochen (Modern-Seite fehlte).
- 05:28 gestartet: bin/golden_make.sh (Log R6/golden_make_run.log, Bilder gates/modern_make)
- danach: Bilder ansehen -> md5 committen/pushen; clips.sh tanken_km15 / blitz_polizei / ziel (einzeln);
  gates_a, gates_b, gates_c_list (Zustand gates/rc_done.txt), perf head + base; bericht.md fertig

## Nachfolger-Lauf 4 (15.11. ab 08:03, Container neu gestartet; Worktree sauber, Kopf bb38876 = origin)
- golden_make war am 13.11. nach 2 von 6 Bildern abgebrochen ("Terminated"); nichts committet.
- Plan (je ein Hintergrundjob, nice 19 solange QA_M2_FERTIG fehlt): golden_make -> ansehen -> md5 commit/push;
  gates_a; gates_b; gates_c_list (bis 18/18); clips tanken_km15, blitz_polizei, ziel; perf head + base; bericht.md
- 08:50 golden_make fertig: 3 von 6 gewollt geändert (start, s2, s4; s3/s5/s1 bildgleich), Vergleich Basis/Kopf in R6/cmp/*.jpg (Basisbilder: m1/M2ZS1/golden_make_keep). Commit c8b18d1 gepusht.
- clips.sh angepasst: tanken_km15 mit --fuel=0.7 (sichtbares Tanken), blitz_polizei 32 s mit --autopilot-target=150 (sonst 235 km/h -> Flucht statt Stopp)
- 08:51 gestartet: gates_a.sh (Log R6/gates_a_run.log)
- 09:16 gates_a fertig: import 0 Fehler, check_scripts 316/0, run_tests 759 Tests 3 FAIL (nur Echtzeit-Audio: test_engine3_checks/test_modern_checks/test_music_checks :: running_game) bei Last 25 -> Wiederholung einzeln auf Kopf und Basis (bin/audio_retest.sh)
- 09:20 gestartet: audio_retest.sh, danach gates_b1.sh (golden check + modern-check); Log R6/chain_b1.log; danach gates_b2 (sight/path), gates_c_list, clips, perf
- 09:41 golden check: 20/20 + 17/17 identisch; modern-check läuft (chain_b1.log)
- 10:12 modern-check 6/6 + GLES OK; gestartet gates_b2 (sight/path --full), Log R6/chain_b2.log
- 10:15 sight/path --full OK; QA_M2_FERTIG liegt -> nice 10. gestartet gates_c_list.sh (Zustand gates/rc_done.txt, neu starten bis 18/18), Log R6/chain_c.log
- 11:42 render checks 14/18 OK (alles grün bisher); Rest (structures, terrain_cover, vehicle_, warmup_cold) neu gestartet, gleiche chain_c.log
- 12:20 render checks: 21 von 21 Dateien OK (warmup_cold.gd ist keine check_*-Datei, gehört nicht zu all). gestartet perf_all.sh (Log R6/chain_perf.log), danach clips
- 12:32 perf_all fertig (4 Läufe, Logs R6/perf_{head,base}_{medium,deck}.log); gestartet clips.sh tanken_km15 (Log R6/clip_run1.log), danach blitz_polizei, dann ziel – je eigener Job
- 12:53 Kette: wartet auf clip_run1 DONE, dann clips.sh blitz_polizei ziel (Log R6/clip_run2.log)
- 13:30 clip_tanken_km15.mp4 fertig (18 MB, angesehen: Tanken 18 L in beiden Modi gleich), blitz_polizei läuft (clip_run2.log), danach ziel
- 14:39 clip_blitz_polizei.mp4 fertig; ziel läuft
- 14:59 Kette nach 2 h abgebrochen (ziel unvollständig) -> ziel neu gestartet (clip_run3.log)
- 15:20 ALLES FERTIG: clips 4/4, gates, perf, bericht.md fertig; R6/base gelöscht (perf/audio erledigt). Kopf c8b18d1 = origin wip/v080-r6. Nur noch Ergebnis melden.
