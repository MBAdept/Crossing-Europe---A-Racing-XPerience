## 5. Tests

**Neu** (`tests/unit/race3d/`, laufen in `tools/run_tests.sh` mit):

| Datei | Test | prüft |
|---|---|---|
| `test_bridge.gd` (10) | `test_water_lies_on_the_water_rows_out_to_the_ribbon` | Wasser 0,15 m über den Wasserzeilen bis zum letzten Ring des Bands |
| | `test_banks_follow_arcades_rule` | Kaimauer bei einsegmentiger Böschung ohne Uferfarbe, sonst Böschung; Gras/Stein nach Uferfarbe |
| | `test_far_quay_wall_faces_the_camera_and_reaches_into_the_water` | ferne Kaimauer zeigt zur Kamera, reicht 0,6 m unter das Wasser |
| | `test_koehlbrand_pylons_beacons_and_cables` | 4 Pylone, Höhe `height_m`/88,8, Flugbefeuerung bei `height_m` + 1,6 m, 7 Seile je Richtung |
| | `test_no_cable_reaches_over_a_lane` | kein Seil über einer Spur (≥ 1,5 m jenseits, drei Schrägseilbrücken) |
| | `test_structure_keeps_out_of_the_lanes` | kein Eckpunkt des Tragwerks über den Spuren und dem ersten Meter des Banketts (nur neben und unter dem Deck) |
| | `test_props_builder_leaves_the_bridge_parts_to_this_builder` | `props.gd` lässt die `bridge`-Teile liegen, sobald der Builder existiert |
| | `test_dark_pylon_material_at_night` | Pylon nachts: `emit_energy` 0, `night_albedo` 0,45 (M2ZS1) |
| | `test_every_bridge_type_builds` | jeder Typ (cable_stayed, truss_arch, river, canal, stone_arch, causeway) baut ohne Fehler |
| | `test_far_ground_quay_copy_equals_arcade` (Nachfolger 4) | `far_ground.gd`s Kopie `ARCADE_QUAY` = `RoadRenderer.QUAY` |
| `test_tunnel.gd` (8) | `test_tube_niches_doors_fans_cap_portal_exit` | Röhre, Nischen alle 150 m, Türen alle 300 m, Lüfter, Kappe, Portal, Ausfahrtsrahmen |
| | `test_nothing_of_the_tube_over_the_road` | nichts über den Spuren unter 5,2 m, über dem Bankett unter 4 m (F1) |
| | `test_hill_closes_the_terrain_at_the_portal` | Hügel schließt das Gelände am Portal |
| | `test_hill_never_cuts_through_the_tube` | Hang des Hügels nie durch die Röhre |
| | `test_short_tunnel_low_hill_no_cap` | kurzer Altstadttunnel (Valík 40 m): flacher Hügel, keine Kappe |
| | `test_cap_only_for_a_camera_outside` | Kappe bei `peek_m` nur von außen |
| | `test_zone_follows_the_rigs_law` | `zone_amount` = Gesetz von `EnvironmentRig.tunnel_blend()` |
| | `test_set_zone_only_when_the_rig_has_it` | `set_zone` nur duck-typed und nur bei Änderung; ohne die Methode bleibt `tunnel01` |

**Render-Prüfung** `tests/race3d/render/check_tunnel_bridge.gd` (läuft in `tools/run_render_checks.sh modern`):
U1_portal, U1_innen, U1_ausfahrt, Somport_portal, B1, beacon (Kopf der Datei: Grenzen und Messweise).

**Bestehende Wächter der ZS1-Korrekturen** (müssen halten): `test_far_ground_water` (4/4), `test_props` (12/12),
`test_terrain_builder` (Fernboden unter dem Wasser), Render-Prüfungen `check_start_km0`, `check_terrain_cover` inkl. K1,
`check_light_base` (Abschnitt 6).

Unit-Tests `race3d` vor dem letzten Code-Commit: 137 Tests, 0 fehlgeschlagen (106 s); auf dem Endstand im vollen Lauf: Abschnitt 6. In einem
früheren Lauf (vor dem Neustart) schlug `test_props :: test_library_resolves_every_prop_set` einmal fehl
(„fallback_sets 78“ – die Modellbibliothek war beim Test noch nicht fertig geladen), allein und in allen späteren Läufen
grün; R5 ändert weder `props.gd` noch `prop_library.gd` – ein Zeitproblem des Tests unter Last, gemeldet unter
Für die Nächsten.
