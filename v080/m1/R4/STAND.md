# R4 – Licht, Nacht, Wetter – STAND (Übergabe bei Neustart)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
Branch:   worktree-wf_fd1de4ee-28b-1 (Basis 6e484056ec87e2fa614061000a362feb2b5a6db8 = origin/wip/v080-m2int)
Sicherung: git push origin HEAD:refs/heads/wip/v080-r4 nach jedem Commit (nie force)
Scratch: <scratch>/v080/m1/R4/   Abgabe: <scratch>/v080/deliver/R4/ (bericht.md ENTWURF mit @@-Platzhaltern, bilder/ 19 Stück)
Basis-Kopie (git archive 6e48405, importiert): m1/R4/base  (Vorher-Bilder, Leistungsvergleich)
Skripte: m1/R4/sh/{pos.sh, ab.sh, batch.sh, gates.sh (Schritte einzeln), warm.sh, bench.sh, stage.sh, clips.sh, leistung.sh}
Älterer Stand des Vorgängers (Details zu allen Commits bis 33ded9a): m1/R4/STAND_alt_vorgaenger.md

## NACHFOLGER 2 (2026-11-13 05:30 UTC, Container neu nach Ausgabenlimit gestern 20:20)
- Vorgänger-Probe (XFADE_LODS ohne lod0) als WIP 68c5c2b gesichert und mit e68b51f zurückgenommen (gepusht).
- run_tests (1. Vollauf, 19:43, Last 20+): 4 rot: test_engine3_checks thread, test_modern_checks race (Sitzung 64/74
  < 90 %), test_music_checks race – alle mit --graphics=arcade -> Lastartefakte (Basis bei QA grün); check_vehicles
  leistung 52 µs > 40 µs -> R4-Verdacht, Messung head/base im Wechsel (queue8).
- Noch offen: sight/path (sight.log leer – abgebrochen), render_checks all, modern_check, golden_check (zuletzt),
  warm.sh, bench.sh, stage.sh head+base, clips.sh N2N N1 TEXIT, Bericht-Platzhalter @@URTEIL@@ @@WETTER@@ @@WARM@@ @@REST4@@.
- Vollauf run_tests: 1 von 2 verbraucht.

## Fallstricke
- QA_M2_FERTIG fehlt -> schwere Jobs nice -n 19, einzeln.
- Git: Befehle einzeln (keine && Ketten mit git), Commit-Text per Datei (msgNN.txt).
- FIX-FLACKERN (Lackflackern = Überlauf Instanz-Uniform-Puffer 255 Plätze) berührt layers/vehicles.gd (Haken „FIX-FLACKERN“).

## NACHFOLGER 3 (2026-11-15 08:05 UTC, Container neu gestartet; Kopf e68b51f = origin/wip/v080-r4, Baum sauber)
- Plan: import + check_scripts, dann Tore einzeln (run_tests Vollauf 2/2, sight, path, render_checks all,
  modern_check), warm.sh, bench.sh, stage.sh head+base, clips.sh, golden_check zuletzt; Bericht-Platzhalter füllen.
- Fortschritt steht in queue9.log (sh/queue9.sh).
- 2577b30 (gepusht): fill_sheen_tint 0,8 (Nacht-Schimmer in Lackfarbe), check_night spielerauto misst Sättigung
  (≥ 0,7 ×): vorher 0,74/0,70/0,91, jetzt 0,95/0,73/0,91; Helligkeit 1,04/0,93/0,86 (rc/sat_t0, sat_m8).
- 866a74c (gepusht): Tunnelausfahrt als Belichtungsgesetz (Bildschirmtextur, Arcade ×1,7 + 0,25) statt Weißmischung;
  TEXIT v8 angesehen: L 0,638->0,717 (Arcade 0,600), Sättigung 0,20->0,26 (Arcade 0,43).
- queue10.sh (= queue9 + modern_make) läuft seit 12:14 mit QUEUE9="modern_make golden_check pic_N1 pic_N2N warm bench_head bench_base stage_head stage_base clips" (Log queue9.log); nach modern_make: tests/golden/modern_slice.{md5,env} committen (Bilder angesehen: modern_golden_new.jpg).
  pic_N2N warm bench_head bench_base stage_head stage_base clips golden_check. Bei Neustart: einfach
  sh/queue9.sh wieder starten (setsid nohup …), erledigte Schritte ("DONE x" in queue9.log) werden übersprungen.
- KEINE Codeänderung mehr ohne Neustart der betroffenen Tore. Offen bleibt (nur Bericht): Dämmerung Lack lila
  (Klarlack spiegelt Himmel; Limousine unten Sättigung 0,8 ×, +7 % heller), GT Regen Tag +13 %.
- 11:13 Tore auf 866a74c: sight OK, path OK, render_checks all 23/23 OK (gates/*.log). Läuft: run_tests (Vollauf 2/2).
- 11:38 run_tests (2/2 verbraucht): 2 rot = Last: audio race 89/99 (Einzel-Nachlauf grün, gates/run_tests_modern_checks_rerun.log), kern_zeit Einhängen 4,07 ms (kern.log: head 1,59/1,58, base 1,50/3,00 ms). Läuft: modern_check.
- NEUSTART-REGEL (gilt ab 12:14): QUEUE9="modern_make golden_check pic_N1 pic_N2N warm bench_head bench_base stage_head stage_base clips" setsid nohup sh/queue10.sh … & – erledigte Schritte werden übersprungen. Nach modern_make: modern_slice.{md5,env} committen + pushen.
- 12:45 83dbdac (gepusht): modern_slice.{md5,env} neu (modern-make, Hashes = Bilder der Prüfung). Läuft: golden_check, dann pic_N1 pic_N2N warm bench stage clips. Bericht: rep1–rep3.py angewandt; offen @@WARM@@ @@URTEIL@@ @@REST4@@ + Tore/Leistung.
- 13:50 7f0eae2 (gepusht): Aufwärm-Knoten auf Render-Ebene 20 (N1 kalt: vorher 3 Varianten bei 6–8 s = sign.gdshader
  „ohne Licht“, nachher 0; Probe warm/P1–P6, Skript sh/wprobe.sh + tests/race3d/render/warm_probe_tmp.gd GELÖSCHT).
  Golden arcade 20/20 + 17/17 lief auf 866a74c (Arcade unberührt). Läuft: queue11.sh (Log queue9.log):
  rc_facade mc_night warm2 bench_head bench_base stage_head stage_base clips. NEUSTART: setsid nohup sh/queue11.sh &.
- 14:15 bench (5) + stage head/base fertig (Bericht gefüllt); läuft: clips (queue11), danach queue12.sh (wartet auf QUEUE11_DONE): warm N2N 22 Uhr + golden_check2 auf Endstand. NEUSTART: queue11.sh und queue12.sh je setsid nohup.
- 15:10 Clip N2N fertig (deliver/R4/clip_nacht_regen_verkehr_N2.mp4); läuft N1, dann TEXIT, dann queue12. Bericht fast fertig (offen: @@CLIPS@@, @@GOLDEN2@@).
- 16:45 alle 3 Clips im Abgabeordner, Bericht gefüllt bis auf @@GOLDEN2@@; läuft queue12 (warm N2N, golden_check2).

## ABGESCHLOSSEN (Nachfolger 3, 2026-11-15 17:05 UTC)
- Endstand 7f0eae2 = origin/wip/v080-r4, Baum sauber. Alle Tore gefahren (gates/*.log, queue9.log), Bericht
  deliver/R4/bericht.md vollständig (keine @@-Platzhalter), 21 Bilder + 3 Clips im Abgabeordner.
- Basis-Kopie, Mesa-Caches, xdg-Ordner und Clip-Zwischenstände gelöscht (Platz). Nichts läuft mehr.
