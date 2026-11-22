# AS5aR2 – STAND (Übergabe)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-6
Branch:   worktree-wf_db8ba6cd-508-6  (Sicherung: git push origin HEAD:refs/heads/wip/v080-as5ar2)
Basis:    3c5e37a (AS5a2), ff-only gemergt
Scratch:  m1/AS5aR2 (env.sh, k5.sh, v2.sh, tools/cycle.sh probe|real, real.sh, det.sh, py/*, kt/*)
          Review-Werkzeuge UNVERSIONIERT in tools/kritik (install_tools.sh) -> vor run_tests.sh LÖSCHEN
Probe-Exporte überschreiben assets/models/props/<id> (Halbatlas!) -> NIE committen, nur echte Exporte.

## Erledigt
- 11:40 Setup (ff, _cache3d + .godot aus 508-4, Import OK)
- Code (Commit b0bbc1d, gepusht): K1 _display_mat heller (SHOP_GLOW/EM/CEIL), K2 wallmat-Hooks inner_k/bars_k
  (INNER_K 0.6, BARS_K 0.35, alle Stadthäuser), K4 lod1_opaque (7 single_cutout-Häuser), K3 leaf_cards (sud, maison;
  maison jetzt single_cutout + lod1_opaque)
- Befunde geprüft: K4 "Band dunkler" = Hintergrund Stein statt cut_fill-Farbe (mipband mit Füllfarbe: dL <= 4) ->
  teilweise abgelehnt; K3 Gartenmauer 15 px/m = gemessen waren Baum/Oleander (Gewicht 0,3); Mauer selbst
  0,6 x ppm = 32,5 px/m (export_report ppm_road_min, GLB-Dreiecke) -> abgelehnt
- Probe r1 (haussmann, sud): Läden nachts hell, Tag unverändert

## FERTIG (22.11. ~08:50): Endstand 216ac5c (gepusht). Bericht deliver/AS5aR2/bericht.md zusammengesetzt
  (assemble.py 216ac5c 89ccc33). K2-Diagnose: Fernblässe = Ende/Auflösung der Echtzeitschatten (logs/k2, Bild
  deliver/AS5aR2/k2_ursache_schattenreichweite.jpg). Scratch aufgeräumt (shots, xdg, mesa, tmp gelöscht).
  Nur noch: Ergebnis (StructuredOutput) zurückgeben.

## Jetzt (22.11. 08:08, Nachfolger nach Neustart)
- chain_final fertig (16.11. 17:25): det/geom/keys/pck/tests/golden GRÜN; modern-check 4 von 6 (s4_mittel, s5_niedrig
  ANDERS, Bilder in golden_modern/). Jetzt: Bilder ansehen -> modern-make -> commit md5 -> assemble.py HEAD MCOMMIT
  -> bericht.md -> Ergebnis.
- 08:31 modern-make fertig, Commit 89ccc33 gepusht (Gates damit komplett grün). Jetzt: K2-Diagnose k2diag.sh
  (lodcol mit Schatten wie Rennen / aus / 1000 m; Verdacht: Fernblässe = Ende der Echtzeitschatten 170-200 m Hoch,
  102-120 m Mittel, nicht Mip-Kette). Logs logs/k2/. tools/kritik danach wieder löschen.

## Früher (12:20)
- CODE EINGEFROREN 7e57cb0 (gepusht): SHOP_GLOW 1.6, INNER_K 0.75, BARS_K 0.35, flower_shape chalet, leaf_cards sud+maison
- chain_real.sh LÄUFT (setsid, logs/chain_real.out): 12 Charge 2 -> 11 Charge 1 -> bridge_lamp/pylon/pylon_bare/
  truss_arch/houseboat (müssen byte-gleich sein: GITSTATUS_OTHER 0) -> validate. Fortschritt: grep -E "EXPORT|STAGE"
  Nach Neustart: Kette weg -> real.sh <restliche ids> einzeln
- nach jedem Stil-Block: git add assets/models/props/city_<..> (nur echte Exporte!) + commit + push; Manifest am Ende
- Vorher-Bilder Charge 1: shots/vorher (kontakt_b1_tag/nacht, b1_dist_h12/h22)
- Probe-A/B Paris 22 h (SHOP_GLOW 1.4): Ladenfläche 22,3 % (vorher 10,9, Arcade 28,2), rgb(223,183,128) vs (250,215,157)
- Bericht-Bausteine: bericht_pruefung.md, doc22_draft.md
- 16:45 FINAL-Stand: lod1-Karten = lod0-Karten (Katalog 4a2e99c, Modelle 6f44643), docs 047e10f (alles gepusht).
  Swap sud 8,2 %. chain_post2 -> chain_final läuft (logs/chain_final.out): det BYTEGLEICH x3, geom 86/86 OK,
  keys/pck/tests/golden/modern folgen. Lieferbilder gemacht (deliver.sh, deliver/AS5aR2). Bericht-Bausteine fertig
  (bericht_kopf/pruefung/aenderungen/mess/rest/einordnung) -> nach den Gates zusammensetzen (Platzhalter
  GEOMRESULT KEYSRESULT TESTSRESULT GOLDENRESULT MODERNRESULT HEADCOMMIT ZUSAMMENFASSUNG).
- 16:00 A/B 8 Läufe exit 0 / 0 Fehler (ab/), Clip fertig (clip/), sud+maison final committet 392b447 (gepusht).
  chain_post läuft: Bilder FRA/G1/spark_fr/outline, A/B ly_out, dann chain_final (logs/chain_final.out).
  Bericht-Bausteine: bericht_kopf/pruefung/aenderungen/mess/einordnung.md, del/ (Vorher-nachher-Bilder), deliver.sh
- 14:58 sud+maison mit lod1-Karten committet (2588185); Swap sud noch 27,4 % -> Code 7898d46 (lod1-Karten = erste n1
  von lod0). chain_post.sh LÄUFT (setsid, logs/chain_post.out): wartet auf chain_ab, exportiert sud+maison NEU,
  Bilder G1/FRA/spark_fr/outline, A/B ly_out, dann chain_final (logs/chain_final.out). NACH dem Re-Export: sud+maison
  + manifest committen!
- 14:40 Befund: Stufenwechsel Südhaus 34,8 % (Krone lod1 ohne Karten) -> Code f6cbdba (lod1-Karten n1/half1, sud+maison
  ohne lod1_opaque, gepusht). chain_ab.sh (neu) exportiert sud+maison neu, rendert G1-lods/FRA-Bilder neu, lodcol ohne
  Nebel, dann A/B + Clip. Danach sud+maison+Manifest committen!
- K2-Ergebnis: Innenring dunkler wirkt (Atlas angesehen), aber lodcol p10 bei 250 m kaum besser (-2..+1) -> Ursache
  woanders (Nebel/Glas?) -> Test lodcol_h12_nofog
- 14:20 ALLE 23 ECHT EXPORTIERT + committet (0abe54a, gepusht); 5 fremde byte-gleich; validate OK
- 14:20 run_meas_ab.sh LÄUFT (setsid): chain_meas (logs/chain_meas.out, shots/fin, logs/fin) -> chain_ab
  (logs/chain_ab.out, ab/, clip/). Danach: chain_final.sh (det geom keys pck tests golden modern), Lieferbilder,
  docs Abschnitt 22 (doc22_draft.md -> docs/modelle.md, Stand-Zeile schon geändert), Bericht
- 12:55 committet+gepusht: sud, belgian_terrace, maison (016b3cf), immeuble, dutch_terrace, belgian_stone,
  haussmann (824aa04). Danach: chain_meas.sh, chain_ab.sh, chain_final.sh (Skripte fertig im Scratch)

## Als Nächstes
- K7 Geranien Chalet, K8 Eckhaus-Rückseite?, K9 Wandleuchten? (niedrig)
- Probe-Runde aller 12 (+ Charge 1 Stichprobe) Tag/Nacht, Messungen (lodcol, litpx im Rennen)
- Code einfrieren -> echter Export aller 23 + bridge_lamp/pylon/pylon_bare/truss_arch/houseboat (byte-gleich?)
- Gates, A/B, Clip, Bericht

## Fallstricke
- Bash: keine heredocs mit cd + git in einem Befehl (Isolation) -> Skripte schreiben
- nice -n 19, ein schwerer Job, free -g >= 3
