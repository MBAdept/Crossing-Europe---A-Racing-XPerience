# AS4R – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
- Branch: worktree-wf_aad8d49e-fb4-6 (Sicherung: origin wip/v080-as4r, nach JEDEM Commit pushen)
- Basis: 9eef9a8 (AS4), ff-merge erledigt; _cache3d und .godot aus AS4-Worktree (wf_aad8d49e-fb4-2) kopiert, Import ok
- Prüfwerkzeuge UNVERSIONIERT in tools/kritik/ (install_tools.sh; vor run_tests.sh LÖSCHEN: rm -rf tools/kritik)
- Skripte (scratch): export_mine.sh [--force] [ids] (Export+Bake+Import+Manifest), ab.sh <name> <preset> <args>
  (A/B), k4.sh <name> <args> (KRITIK-4-Szene: dist2/close/outline2/approach mit Renn-Look), pylon_census.gd,
  emit_probe.gd (welche Dreiecke leuchten im Emissionsatlas), probe_saw.py, dbg_build.py (Schnell-Export "debug")

## Befunde geprüft
- M1 bestätigt: Deckanker x -4.2 -> Welt 3.35 = 0.4 m IN der Fahrbahn (Kante 3.75, Pylon 7.55). Zählung (pylon_census.log):
  5 Brücken, Platz Pylon->Brückenende min 40.5 m (Elisabeth/Vansu 150 m), Köhlbrand 70.5, Radien >= 449 m
- M4 Ursache anders: KEINE verdrehten Flächen (probe_saw: alle Normalen außen); die "Dreiecke" sind die senkrechten
  Shed-Glasbänder (fac_glass, Emission #cfe0ff x0.9 -> weiß), gesehen über der Schräge des nächsten Sheds
- M3/M6 bestätigt (vpbr Kanal 12: Tag = Leuchtfarbe x lamp_off_props 0.5)

## Erledigt
- 4398cee (gepusht): Pylon aufrecht (+0.9 m außen, Sockel gekappt), 7 Seile/Seite bis Deckkante x-1.4 z1.1, Fächer 36 m,
  eine Stufe 0.32 m, extent_source; props/bridge_pylon_bare (modern_only). A/B ab/pylon1_ab_0[0-3].jpg: Seile neben
  der Fahrbahn, kein Käfig. (bare: object-Breite 5.25 erst im nächsten Export)

## Jetzt
- Fenster M3/M6: Füller als Scheiben absenken (Licht des Sprites x K im Emissionsatlas), Turm/Mühle per Farbfeld

## Als Nächstes
- M4 Shed-Glas (Sprossen, Licht x0.45), M7 Mühlenflügel (6 Sprossen 0.15 m), M8 Turm (Hash, Foyer), Kirche Putz -10 %,
  Fachwerk 1.2x; voller Export; Bilder; Gates

## Fallstricke
- nice -n 19, eine Worker-Instanz, nie zwei schwere Jobs gleichzeitig
- git: keine verketteten git-Befehle (Werkzeug lehnt ab) -> einzeln; Commit-Text per Datei
- jede Änderung an buildings3d.py ändert die Schlüssel aller 15 AS4-Modelle (voller Export ~20-40 min)

## Update 23:20
- Code fertig (nicht committet!): Fenster = abgesenkte Füller (PANE_LIGHT_K 0.55), Patches (Turm, Mühle), Turm-Hash +
  Verlauf + Foyer (light_scale 0.2, Pfosten), Fabrik-Shed (_skylight), Mühlenflügel 7x0.13 (Hook sail_bars),
  Kirche Putz #ccc6b7 (Hook plaster), Fachwerk web_k 1.2 / web_dark 0.85
- Hausprobe K=0.4: Tag einheitlich blaugrau, nachts 3 warme Fenster (shots/r1_house_*.png) -> K auf 0.55 (Arcade gelber)
- voller Export läuft: logs/export_r1.log (danach: validate, batch_views.sh v1, Geometrie-Gate wegen Hooks!)

## Update 23:58
- 2a80df0 (gepusht): Runde 1 komplett exportiert + Ladenschild-Zeichen + Seilachse x -1.15. Validator OK.
- Bilder Runde 1: shots/v1_* (batch_views.sh v1), A/B ab/dorf_nacht_* (M6: Spitze 216 statt 165, Arcade 225;
  >150: 376 statt 143, Arcade 543), ab/fabrik_nacht_* (Block B nachts wie Arcade), ab/pylon1_* (Seile neben Fahrbahn)
- Katalog Runde 2 (NICHT exportiert): Shed k 0.3, Schild 0.25
- läuft: batch_measure.sh m1 (Flimmern, Stufen, Fabrik-Drehung) -> logs/batch_m1.log
- danach: Runde-2-Export (factory, building_shop) ODER gleich finaler Vollexport (Schlüssel!), dann Gates

## Update 00:45 (12.11.)
- Runde 2 Code (nicht committet, Export läuft: logs/export_final.log): Scheiben ohne AO (_pane_mask), Tönung
  PANE_TINT (#8fa3b5, 0.08), Mühlenflügel ZURÜCK auf Sprite (Hook sail_bars entfernt: M7 war Messartefakt -
  Rotorphase hängt an Welt-x; mit bewegter Kamera (my.sh sparkcam) alt 4.2/3.3/5.5/7.5 %, neu gleich, Sprite
  2.9/2.5/4.4/4.3), Shed k 0.3, Schild 0.25
- Block B Flimmern: AS4 0.1/0.1/0.7/0.9, Runde1 0.5/1.7/1.5/1.4, mit Tönung 0.2/1.0/0.8/0.6 (Rest: Schwellenartefakt
  an einer Fensterspalte, Max-Kanal 52 statt 42); Fabrik-Seitenwand 29.3 px/m (texel_wall.gd; KRITIK 18.7 =
  Fehlzuordnung: die verdeckten Shed-Gläser liegen im selben Richtungsfach)
- WÄHREND DES EXPORTS KEINE CODE-DATEIEN ÄNDERN (Schlüssel)
- danach: validate, Bilder final (batch_views v2, batch_measure m2), A/B (pylon, dorf_nacht, fabrik_nacht, turm),
  Geometrie-Gate, check-keys, Determinismus (zweiter --force-Export, Arbeitsbaum muss sauber bleiben), run_tests, golden

## Update 00:50
- f349c01 (gepusht) = Endstand der Modelle (Runde 2 exportiert, Validator OK, Doku Abschnitt 15 ergänzt;
  Platzhalter MESSUNGEN_AS4R in docs/modelle.md noch füllen!)
- läuft: batch_final.sh (views v2, measure m2 + sparkcam, A/B f_*, Geometrie-Gate, check-keys) -> logs/batch_final.log
- danach: Determinismus (export_mine.sh --force, dann Arbeitsbaum prüfen), rm -rf tools/kritik, run_tests, golden,
  Bericht (Bausteine teil_*.md, bericht_draft.md), Lieferbilder nach deliver/AS4R

## Update 01:25
- batch_final.sh vom Zeitlimit (30 min) gestoppt nach views v2, measure m2, A/B pylon_mittag + dorf_nacht
- 8dd2fef (gepusht): Fachwerkportal steel #49585a (Kontrast 100 m 98->108, Sprite 109; 400 m 86->94, Sprite 138),
  Doku Mühle ehrlich (1,3-1,7x Sprite mit bewegter Kamera)
- Messwerte fertig: M3 hue_tiles.py (braun Laden 8.3->0, Altstadt 21.4->3.3, Block A 23.6->4.1, Block B 16.4->2.8 %),
  M4 Dach weiß 12690->0 px, max 255->163; M6 lum.py 165/143/0 -> 216/379/163 (Arcade 225/543/388);
  Kirche wall.py AS4 Mittel 204 p95 229, Arcade 173/194 (neu: aus f_dorf_mittag_modern_01, Box 965 240 1075 318)
- läuft: batch_rest.sh (A/B dorf_mittag, fabrik_nacht, turm, elbe_deck; m3_flimmer_portal; Geometrie; check-keys)
  -> logs/batch_rest.log (REST_DONE)
- danach: MESSUNGEN_AS4R füllen, Determinismus, rm -rf tools/kritik, run_tests, golden, Bericht

## Update 01:50
- 09f679b (gepusht): Doku-Messtabelle gefüllt. A/B f_* alle 6 Läufe mit 0 Skriptfehlern; Geometrie-Gate 86 identisch,
  kein ANDERS; check-keys OK; Portal-Flimmern 1.0/2.4/7.7/8.5 (Sprite 2.7/4.8/10.3/13.7)
- tools/kritik GELÖSCHT (bei Bedarf install_tools.sh)
- läuft: final_gates.sh (export --force aller 15 -> gates/status_after_force.txt muss leer sein; validate; run_tests;
  golden) -> logs/final_gates.log (FINAL_GATES_DONE)
- Bericht: deliver/AS4R/bericht.md (Platzhalter *_TODO), Bilder: python3 deliver.py, Bausteine teil_*.md

## FERTIG 02:45
- Endstand 09f679b (gepusht nach wip/v080-as4r), Arbeitsbaum sauber
- Gates grün: export --force byte-identisch (2022 s, status leer), validate CHECK models OK, run_tests 692 Tests 0 Fehler
  (833 s), golden 20 von 20 identisch, Geometrie 86/86, check-keys OK, A/B 6 Läufe 0 Skriptfehler
- Bericht deliver/AS4R/bericht.md (assemble.py 09f679b), 41 Bilder in deliver/AS4R (deliver.py)
