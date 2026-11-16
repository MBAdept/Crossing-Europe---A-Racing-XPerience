# R3 – Stand (Übergabe für einen Nachfolger)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-1
Branch:   worktree-wf_2e14ac26-9d4-1  (Sicherung: origin wip/v080-r3, nach jedem Commit pushen)
Basis:    d025d1d (R1a 65c7560 + AS1 53bcc1b), ff-merge gemacht, .godot kopiert, Import gelaufen.

## Erledigt (Commit f57f9dc, gepusht)
- scripts/race3d/vehicle_pose3d.gd (VehiclePose3D, rein): Fade-Gesetz, chord_pose, player_yaw, lod_index,
  lamp_a/b, flare_params, flare_points (tail+brake -> "rear"), wheel_spin, steer_angle.
- scripts/race3d/layers/vehicles.gd: Pool je Set, Pose aus 2 Pfadpunkten, LOD mit Hysterese, Räder, Sattelzug
  (groups), Lampen/Fade/Sonne nur bei Änderung, Kontaktschatten (MultiMesh), Flares an layer("flares").
- scripts/race3d/layers/flares.gd: zwei MultiMeshes (Fahrzeuge, statische Lampen), add_static, Tiefentest im Shader.
- model_factory.gd: build(..., articulated) mit Gruppenknoten, rekursive Helfer, build_box (Kasten-Stellvertreter).
- Shader: vpbr (Klarlack, analytische Umgebung env_*, Flakes), glass (+env-Spiegelung als EMISSION, R3-Teil markiert),
  flare, contact_shadow, sign.
- Schilder: sign_canvas.gd, sign_atlas.gd (Katalog aus Track.events_for_segment + dynamische, Trockenlauf für
  Grenzen/Pfosten, ein Atlas), builders/signs.gd.
- Werkzeuge (scratch): mshot.sh (nur Modern-Lauf), probe/car_bench.gd (Lichtbank: --scene=chase|side|traffic|boxes|trucks).

## Erledigt danach (Commits 041586b, dbbdd37, 3e8f408 – gepusht)
- Unit-Tests test_vehicles (11), test_fade_law (3), test_sign_atlas (4): grün.
- tests/race3d/check_vehicles.gd (lampen, kasten, leistung 31 µs/Auto, schilder): grün.
- Render: check_vehicle_lights.gd (blinker 300 m, ruecklicht_n1, bremslicht), check_occlusion.gd (kuppe, lkw 0 px): grün.
- VehiclePose3D nennt RoadRenderer nicht mehr (SpriteDB-Autoload in -s-Skripten), Konstanten kopiert + Test.

## Erledigt danach (Commits 6e95512, e5882f3, 37cd54d, 1ca9f7b, 3655c19 – gepusht)
- Lack-Look über die Ebene (LOOK), neutrale Shader-Vorgaben (check_models grün); Fülllicht Spielerauto, Kasten matt.
- Schilder mit Fülllicht; flares.add_static hing (Schleife ohne i += 1) – behoben, Prüfung lampen_fest.
- Doku docs/renderer-modern.md §10 (3655c19).
- A/B-Bilder fertig in m1/R3/ab/ (s1_tag, s1_nacht, dicht, s3_tag, s1_hoch, lampen_tag/nacht, lkw, schild_s1..s5, schild_nacht).

## Abschluss (Kopf 4d02ada = origin wip/v080-r3)
- 4d02ada: Prüfung check_vehicles schatten (deck/low/medium/high: Kontaktschatten 15/15, Werfer an/aus/an/an),
  snapshot cast/caster, perf contact_shadows, Doku.
- run_tests.sh vollständig auf 3655c19: bestanden (594 Tests, 78 CHECK, 566 s) – 1 von 2 erlaubten Läufen.
- run_tests.sh vehicles + run_render_checks.sh modern (5/5) + golden.sh check (20 von 20 identisch) auf 4d02ada.
- deliver/R3: 14 Bilder + bericht.md. Scratch aufgeräumt (xdg*, mesa, shots, Roh-PNGs gelöscht).
- Offen: nur die Rückgabe (StructuredOutput).

## Fallstricke
- mshot.sh: Pfade absolut (Screenshot-Pfad relativ zum Worktree!) – behoben.
- Tiefentextur nur in fragment() (nicht vertex()); Reverse-Z, ndc_z = 2d-1.
- Debug-Straße nimmt keinen Schatten an (R1a) – Kontaktschatten trägt.
- Sonne steht mittags in Fahrtrichtung: Heck aller Autos im Eigenschatten (Hinweis an R1).

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/ (shots/, probe/, mshot.sh)
- Bilder/Bericht: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R3/
