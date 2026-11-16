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

## Jetzt (12:20)
- CODE EINGEFROREN 7e57cb0 (gepusht): SHOP_GLOW 1.6, INNER_K 0.75, BARS_K 0.35, flower_shape chalet, leaf_cards sud+maison
- chain_real.sh LÄUFT (setsid, logs/chain_real.out): 12 Charge 2 -> 11 Charge 1 -> bridge_lamp/pylon/pylon_bare/
  truss_arch/houseboat (müssen byte-gleich sein: GITSTATUS_OTHER 0) -> validate. Fortschritt: grep -E "EXPORT|STAGE"
  Nach Neustart: Kette weg -> real.sh <restliche ids> einzeln
- nach jedem Stil-Block: git add assets/models/props/city_<..> (nur echte Exporte!) + commit + push; Manifest am Ende
- Vorher-Bilder Charge 1: shots/vorher (kontakt_b1_tag/nacht, b1_dist_h12/h22)
- Probe-A/B Paris 22 h (SHOP_GLOW 1.4): Ladenfläche 22,3 % (vorher 10,9, Arcade 28,2), rgb(223,183,128) vs (250,215,157)
- Bericht-Bausteine: bericht_pruefung.md, doc22_draft.md
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
