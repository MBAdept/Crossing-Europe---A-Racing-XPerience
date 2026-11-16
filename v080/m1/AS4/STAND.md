# AS4 – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
- Branch: worktree-wf_aad8d49e-fb4-2 (Sicherung: origin wip/v080-as4, nach JEDEM Commit pushen)
- Basis: 8f58b2d (ff-merge erledigt), .godot + _cache3d (aus wf_ae4df3ba-14f-1) kopiert, Import gelaufen
- Helfer (scratch, angepasst auf diesen Worktree, nice 19, jobs 1): cycle.sh "<glob>" [sheet], batch_build.sh,
  det.sh, stage_sets.gd (Zählung je Etappe), census_all.gd (ganzes Netz, Log census_all.log), sprite_sheet.py,
  bridges.py

## Befunde
- Sets ohne Modell (meine): church, factory, house_med, building_block_a/b, building_oldtown, building_shop,
  building_tall, bridge_lamp, bridge_pylon, bridge_truss_arch, houseboat, ferry_ship. Keine weiteren Land-/Straßen-Sets.
- houseboat + bridge_* liegen in cesprites/props_cities.py (AS5a gehört die Datei!) -> KEINE Hooks dort; Bauer
  liest Geometrie/Materialien von außen (wallmat zur Laufzeit umhüllen). In contract_issues melden.
- Netz-Zählung (census_all.log): house_med 940, block_b 541, shop 497, factory 430, church 305, bridge_lamp 304,
  oldtown 127, block_a 86, pylon 44, ferry 26 (Maßstab 0,33-0,45!), houseboat 20, truss 15, tall 5 (Wahrz.-Ersatz 2,15)
- Kiel-Hamburg ab Kiel: bridge_pylon km 78.7 (4), ferry km 78.9 (3), truss_arch km 84.1 (5), shop km 87.7 (10);
  ab Hamburg: church km 92.8 (Maßstab 2,2). ab_shot S4 = km 80.
- Kategorien: church/factory/house_med/houseboat/ferry = building ohne "city" -> rural 2000 Dr./2 Aufrufe/1024;
  building_* = city 10000/2/2048; bridge_lamp furniture 1500/1; bridge_pylon "pylon" 5000/1; truss furniture 1500/1.
- Arcade zeichnet bridge_pylon prozedural (prefer_proc, height_m 50-120, Seile), truss_arch + bridge_lamp als Sprite.
- Modern props.gd: Modell mit fit_w skaliert (truss), "bridge" -> h=0 (Fahrbahn), "h" -> Wasser (Schiffe),
  Lampen brauchen dir. lamp_off_props 0.5 (Tag = halbe Leuchtfarbe), lights_energy 4, flood (14) behält Albedo.
- Fähre: Sprite view_yaw 90 -> Modell um -90° um Z drehen (Breitseite +x nach -y, Bug nach +x).

## Plan
1. Hooks props_buildings (allround: Rückseiten, Uhr/Schallluken Turm, Rückgiebel Altstadt, gable3d, win3d Mühle)
2. Neues Modul tools/blender/ce3d/buildings3d.py (Bauer "house"): Bögen, Läden, Schallluken, Uhr, Türen+Stufen,
   lod1 ohne Feinteile, vpbr-/Atlas-Lenkung je Material, Gewichte (Dach/abgewandt), Vorhangfassade (tall),
   Schriftzug (factory), Drehung (Fähre), Achteck-Fenster (Mühle)
3. Katalog-Block "# --- AS4 ---" in catalog3d.py, BUILDERS in export_models.py
4. Reihenfolge: house_med, church, shop, block_b, factory, block_a, oldtown, tall, bridge_lamp, pylon, truss,
   ferry, houseboat, windmill; je 3 Runden (bauen, Tag/Nacht ansehen, Mängel, fixen)

## Erledigt
- Start: kein Vorgänger. ff-merge 8f58b2d, Import.
- 5e55725 (gepusht): buildings3d.py (Bauer "house"), Hooks props_buildings, Katalog-Block AS4, BUILDERS.
  Acht Gebäude als VORSCHAU-Bake (halbe Auflösung, Schlüssel "debug") in assets/models: house_med, church,
  building_shop, factory, building_block_a/b, building_oldtown, building_tall. Endgültiger Export steht aus!
- Werkzeuge scratch: dbg_build.py <wt> <ids> [--full] (schneller Export, Schlüssel "debug"),
  look.sh "<glob>" <name> (Bake+Import+Manifest+Bogen), look2.sh <prefix> <ids...> (alle props backen + Bögen)

- geom1.log: 86/86 identisch (nach den props_buildings-Hooks; props_road-Hook kam währenddessen -> am Ende erneut)
- 13e4cf3 (gepusht): bridges3d.py (pylon, truss, lantern), Fähre (lowpoly3d, Drehung -90°, Schnittebenen),
  Hausboot (wallmat-Log von außen, Geländer als Pfosten, Dezimierung), Mühle (octagon), Lochfüller-Bake.
- danach (noch nicht committet): Gewichte Kirche/Fabrik/Blöcke, Hausboot-Atlas 1024x512, Silo matter,
  Turm-Flutlicht der Kirche (_floodlight, Emissionsatlas).

- cb84e18 (gepusht): alle 14 Modelle in voller Qualität (export1.log: 2499 s), Validator OK (lod1-Regel in
  validate_models.py ergänzt, NICHT in manifest.py = Cache-Schlüssel aller Modelle), Doku-Abschnitt 15 (Entwurf
  mit Platzhaltern TABELLE/GEOMETRIE/EINORDNUNG in docs/modelle.md!).
- Skripte: export_mine.sh [--force] [ids] (echter Export+Bake+Import+Manifest), det_mine.sh (Determinismus),
  ab_runs.sh P1|P2|P3|P4 (A/B je high/medium, 12/19.5 Uhr; P3_ARGS/P4_ARGS setzen), positions.gd (km der Sets),
  budget_table.py, sprite_vs.py (Sprite neben prop_scene-Kacheln), bericht_teile.md (Vertragsfragen, Bedarf)

- 17:16 ab/t1_p1 (P1 high 12 Uhr): Pylone, Fähren, Altstadt, Haus im Rennen ok, keine Skriptfehler
- 17:20 Kontaktbögen sheets/k1_* (alle Gruppen, Tag+Nacht, lod0+lod1) angesehen: ok
- Runde 3 (nicht committet!): Pylon Höhenbänder band_w (1/0.6/0.45): Fuß 29.86 px/m (vorher 21.79);
  Fähre: Positionslichter ohne Anker (roles.lights() färbt alle Anker einer Rolle wie die erste Lampe -> grün)
  -> beide neu exportiert (export2.log, export3.log), Doku nachgezogen

- 18:00 views v1 (views/, pop.py misst Stufensprung): Blöcke lod1 8 Stufen dunkler (Rahmen+Sprossen fehlten),
  Turm 18 % Pixel (Lisenenseiten nur lod0), Pylon 7 % (Seile 0.24->0.4)
- Runde 3b (nicht committet): lod1-Rahmenring mit Fläche von Rahmen+Sprossen (_far_inset, far_ring), Lisenenseiten
  "both", Pylonseile (0.28, 0.34). Block B: Farbe lod0/lod1 jetzt (158,127,117)/(157,126,116), 5.2 % Pixel
- 18:20 export5.log: alle geänderten Modelle neu (buildings3d.py ist im Schlüssel aller house-Modelle)

- 871b963 (gepusht 18:16): Runde 3 (Rahmenring lod1, Lisenen, Pylon band_w + Seile, Fähre ohne Anker), alle
  Modelle neu (export5.log 1874 s), validate --report: CHECK models OK
- Bericht-Bausteine: bericht_entwurf.md, bericht_runden.md, bericht_rest.md, r5_masse.md; deliver.sh k3 v2

- views v2 / sheets k3 fertig (pop.py v2: Farbe <= 2/255, Blöcke 4.5/5.2 %, Turm 0 %, Pylon 3.2 %)
- check-keys OK (gates/check_keys.log); A/B P1_high_12, P2_high_12 fertig (ok, keine Skriptfehler)
- 18:50 A/B P3 zeigte "WERK 2" in SPIEGELSCHRIFT (Fabrik mirror_left, links gespiegelt) -> A/B abgebrochen,
  Werkszeichen = Zahnrad zwischen Balken (_gear_logo, spiegelsymmetrisch), Fabrik lod0 1624 / lod1 1108;
  buildings3d.py geändert -> alle Schlüssel neu -> export7.log (voller Export, NICHT committet)

- export7 (1220 s): nur die Fabrik geändert, die 13 übrigen Modelle mit neuem Schlüssel BYTE-GLEICH
- b860113 (gepusht 19:15): Werkszeichen Zahnrad, Doku-Tabelle/Einordnung

- A/B fertig: 12 Läufe, 24 Bilder, 0 Skriptfehler (ab_runs.log, ab_runs2.log); views v3 land (Fabrik pop 0 %)
- Lieferbilder kopiert (deliver.sh k3 v2 + k4 fabrik + v3 land): 60 Bilder, 46 MB
- Geometrie-Gate 86/86 identisch (gates/geometry.log); 9eef9a8 (gepusht): Doku vollständig = ENDSTAND

- Gates auf 9eef9a8: det.log (git status leer, 1142 s), check_keys.log OK, validate.log OK,
  run_tests.log (692 Tests 0 Fehler, 141 CHECK OK, bestanden 841 s)

- golden.log: GOLDEN arcade 20 von 20 identisch
- Bericht: deliver/AS4/bericht.md (assemble.py 9eef9a8), 60 Lieferbilder in deliver/AS4
- Aufgeräumt (21:00): look, mesa*, xdg*, tmp, sheets, views, ab/*.png|jpg gelöscht (Kopien in deliver/AS4)

## FERTIG – Endstand 9eef9a8 (gepusht nach origin/wip/v080-as4), Arbeitsbaum sauber
- Bericht: bericht_gates.md schreiben, python3 assemble.py <commit>; StructuredOutput
- ab_runs.sh (P1..P3 x high/medium x 12/19.5, TMPDIR scratch; P3 = km 1.9)
- Gates: Geometrie, check-keys, Determinismus (det_mine.sh, 42 min), validate --report, run_tests, golden
- Bericht deliver/AS4/bericht.md, Doku-Platzhalter TABELLE/GEOMETRIE/EINORDNUNG

## Stolpersteine
- Bash-Tool lehnt verkettete/komplexe Befehle ab -> Skripte in scratch, einzeln ausführen
- AS3 arbeitet parallel an tools/models/prop_scene.* (Renn-Look) -> diese Dateien NICHT anfassen
- props3d.py NICHT ändern (Cache-Schlüssel aller Bäume/Gebäude von AS1b/AS3 hängen daran)
