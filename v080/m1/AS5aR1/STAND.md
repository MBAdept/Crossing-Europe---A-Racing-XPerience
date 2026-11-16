# STAND AS5aR1 (Nacharbeit AS5a1 nach KRITIK-5a1)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-3
- Branch: worktree-wf_db8ba6cd-508-3 -> push: git push origin HEAD:refs/heads/wip/v080-as5ar1
- Basis: 63544b6 (AS5a1), ff-merge erledigt, .godot kopiert + Import OK, _cache3d von AS5a1 kopiert
- Scratch: m1/AS5aR1 (env.sh, k5.sh, install_tools.sh -> tools/kritik UNVERSIONIERT, views.sh, real.sh,
  chain_final.sh, tools/{cycle.sh,probe.py,mipband.py,budget.py,share.py,stale.py,det.sh,ab_all.sh})

## Erledigt
- Mängel geprüft (shots/vor/ = Vorher-Stand 63544b6): K2 bestätigt, K4 bestätigt; K5/K6/K7 Zahlen zweimal gemessen
  (AS5a1, KRITIK) -> übernommen, nachher selbst messen
- Commits: a460272 (close3d-Flanken, _oriel, inset, _cut_fill, _lod1_decimated), 406f28a (inner_frame-Ring),
  0e23b6f (Doku, Konsole #a98a74) -> CODE EINGEFROREN (cities3d.py, props_cities.py nicht mehr ändern!)
- Runde 1 (Proben, Halbatlas): shots/r1/ - Flanken mit Fenstern/Türen, Erkerfenster echt, Geländer-Band;
  mipband Mietshaus neu: dL +0.2/+0.1/+0.2/-1.0 (alt -2.3/-4.2/-8.2/+14.4)
- Haus lod1 2526 -> 618 Dreiecke (Probe)

## Jetzt (19:15)
- r2.sh (lods-Bilder r1, Probe gruenderzeit, rail r1b) läuft, Log logs/r2.out
- chain_final.sh (setsid, Log logs/chain_final.out): wartet auf r2, dann check_sprite_geometry (logs/gate_geom.log),
  echte Exporte aller 11 + bridge_pylon/_bare/truss (byte-gleich?), stale.py
  -> Fortschritt: grep -E "GEOM|EXPORT|DONE|===" logs/chain_final.out

- post1.sh (setsid, logs/post1.out): wartet auf chain_final, dann real.sh bridge_lamp + houseboat (Schlüssel mit
  props_cities -> byte-gleich?), det.sh office,crane (BYTEGLEICH?), meas_final.sh (Bilder shots/fin/, Logs logs/fin/)
- Runde 2: Proben-lods (shots/r1/lods_h*.png): Fachwerk 32,0->25,8 % / nachts +9,0->+5,1 % (Halbatlas, Hinweis);
  Gründerzeit mipband neu dL +0,8/+0,7/+1,8/+0,0 (alt -5,2/-8,4/-13,6/+18,0)

## Stand 21:12
- chain_final FERTIG: GEOM 86/86 identisch; echte Exporte aller 11 committed (8e35d9c, 2042944, a3600a3, 1c09b12,
  5e80bca Manifest); Brücken + Hausboot neu exportiert -> byte-gleich; det office+crane BYTEGLEICH
- Prüfer fand 17 verkehrte Dreiecke in Haus-lod1 (Dezimierung 0,15) -> 0,3 (d159871), lod1 954, validate OK
- budget: logs/budget.md, share: Netze 0,81 MB / Texturen 5,36 MB Archiv; mipband final logs/mipband_final.log
- meas_final.sh läuft (setsid, logs/meas_final.out): lods spark outline tint dist close erker drive rail -> shots/fin

## Stand 22:00
- meas_final fertig (shots/fin, logs/fin): lods, spark (K6 unverändert ~1.2-1.5 %), outline, tint, dist, close, erker,
  drive, rail. Haus lod1: 0.3 -> Swap 20.8 %; Test 0.5 -> 1406 Dreiecke, Swap 17.2 %/11.5 % -> 0.5 committed (6299928)
  (fin-Bilder des Hauses ab 60 m zeigen noch 0.3)
- post2.sh läuft (setsid, logs/post2.out): ab_run 10 Läufe (ab/), rm tools/kritik, run_tests, golden check,
  modern-check (KEEP golden_modern/), check-keys
- danach: Modern-Goldens ansehen, ggf. tools/write_mlist.sh (Liste aus KEEP), commit; docs/modelle.md Abschnitt 20;
  bericht.md + Lieferbilder nach deliver/AS5aR1

## Stand 23:55
- docs committed (bd1c2be). AB 10 Läufe fertig, 0 Fehler (ab/, deliver rennen_*.jpg via ab_deliver.sh)
- Lieferbilder: deliver.sh (fertig), ab_deliver.sh (fertig); Berichtsteile part_*.md, bericht.md mit Platzhaltern
- post2 läuft weiter: run_tests -> golden check -> modern-check -> check-keys (logs/gate_*.log)
- danach: Goldens ansehen (golden_modern/), ggf. tools/write_mlist.sh + commit; bericht.md füllen; Ergebnis

## Als Nächstes (alt)
- git status: nur props/city_* + manifest geändert? Bridges byte-gleich? -> commit je Gruppe + push
- validate_models --report, budget.py, share.py, mipband (Mietshaus/Gründerzeit), check-keys
- Messungen: lods (K5) + spark (K6) alle 11 bzw. Fachwerk; rail; tint; close/drive/erker Bilder (Runde 3, echte Exporte)
- Determinismus: 2-3 Modelle erneut --force (det.sh) -> byte-gleich
- rm -rf tools/kritik; run_tests.sh; golden.sh check; golden.sh modern-check (KEEP=...) -> ggf. Liste neu
- ab_shot (tools/ab_all.sh mit KRITIK-Positionen), docs/modelle.md Abschnitt 20 nachtragen, bericht.md

## Fallstricke
- jede Änderung an cities3d.py / props_cities.py ändert den Schlüssel ALLER 11 (+ bridge pylon/truss: props_cities!)
- Probe-Dateien in assets/models/props/city_* NICHT committen (werden von chain_final überschrieben)
- tools/kritik vor run_tests.sh löschen (rm -rf tools/kritik)
- nice -n 19, ein schwerer Job, free -g >= 3 GB; Hintergrundläufe > 2 h nur mit setsid
- Büro-Foyer (K10) bewusst nicht: Auslage für 2-3-m-Schaufenster, Foyer 9,5 m hoch

## FERTIG (16.11. ~01:10) – Endstand 7153381 auf origin/wip/v080-as5ar1
- Gates: validate OK, geometry 86/86, check-keys OK, det office+crane byte-gleich, Brücken+Hausboot byte-gleich,
  run_tests: 1 Lastausreißer (engine3 thread), gefiltert wiederholt grün; golden 20/20 + 17/17; modern 4/6 -> Liste neu
  (7153381), AB 10 Läufe 0 Fehler
- bericht.md + Bilder in deliver/AS5aR1; Scratch aufgeräumt (Fahrbilder, PNG-Einzelbilder, mesa, xdg gelöscht)
- _cache3d im Worktree (Exporte dieses Stands) bleibt für eine weitere Nacharbeit
- Ein Nachfolger muss nichts mehr tun außer ggf. das Ergebnis erneut melden.
