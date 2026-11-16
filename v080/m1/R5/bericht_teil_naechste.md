## 8. Für die Nächsten (fremde Dateien: genaue Änderung; dazu R5s eigene Reste)

R5 hat außerhalb seines Eigentums nur die Golden-Zeile `modern_s4_mittel` geändert. Was in fremden Dateien besser würde:

1. **R4 `builders/props.gd`, Schiffe auf das Wasser** (Vertrag A-Nachtrag „R5 sets them on the water surface“): Schiffe
   und Hausboote stehen bei `h = float(it["h"])` (Zeile 599, `h` = −Tiefe = Höhe der Wasserzeilen des Geländes); das
   Wasser von R5 liegt `WATER_LIFT` (`bridge.gd`) = 0,15 m darüber. Änderung: Zeile 599
   `h = float(it["h"]) + (0.15 if bool(inp.get("skip_bridge", false)) else 0.0)` (nur wenn der Brücken-Builder da
   ist). Bis dahin liegt die Wasserlinie 0,15 m zu tief (im Bild kaum zu sehen).
2. **R4 `builders/roadside.gd` `_railing`, Steinbrücken**: Arcade zeigt an Steinbrücken eine Balustrade aus hellen
   Docken (Ludwigsbrücke Würzburg, Bild `stein_01`), Modern eine geschlossene Brüstung. Änderung: für `"stone_arch"`
   das mittlere Band `[0.24, 0.92]` durch Docken ersetzen (alle 0,35 m, 0,14 × 0,14 m, oben/unten 0,03 m breiter),
   Sockel und Handlauf bleiben. Erst dann ist die Steinbrücke besser als Arcade, heute nur gleich.
3. **R4 `layers/flares.gd`, Tunnelleuchten bei Tag von außen**: Arcade zeigt die Leuchten der Röhre mit Lichthof auch
   von außen bei Tag; die Flare-Ebene schaltet die Rolle `tunnel` nur nachts bzw. mit der Kamera im Tunnel an. R5
   malt den Lichthof deshalb selbst im `tunnel.gdshader` (Zeile 226, `halo_k` = 1 − `lights`). Änderung: in
   `_add_statics` `var on := 1.0 if role == "on" or role == "tunnel" else (…)`; danach in `tunnel.gdshader` Zeile 226
   `halo_k = 0.0` (sonst doppelt).
4. **R4 `environment_rig.gd`, Ausfahrt**: Arcade überbelichtet das Draußen aus dem Tunnel (`RoadRenderer`:
   `amb_out = min(2, amb × 1,7 + 0,25)`, Nebel nach Weiß 0,55); Modern zeigt es normal belichtet (Ausfahrt 0,226
   Leuchtdichte gegen Röhre 0,449, gemessen). Quelle ohne eigene Rechnung: `renderer.builder("tunnel").tunnel_state`
   (`exit_m`, `exit_in_sight`) oder `set_zone("tunnel", amount)` (Abschnitt 15.1 der Doku).
5. **R4 `builders/terrain.gd`, Wasserzeilen**: die Wasserzeilen des Geländebands liegen 0,15 m unter dem Wasser von R5
   und werden nur verdeckt (rund 768 Dreiecke je Brückenstück). Änderung: Wasser-Quads auslassen, wenn
   `renderer.builder("bridge") != null`.
6. **R4 `layers/lights.gd`, Abblendlicht ohne Hell-Dunkel-Grenze**: der Spot hat 30° halben Öffnungswinkel in alle
   Richtungen (`SPOT_ANGLE_DEG`), also keine Abblendkante: eine senkrechte Fläche 60–70 m voraus wird bis oben
   angestrahlt. Am Gotthard-Portal um 22 Uhr (Bild `u1_nacht_00`) liest sich die Stirnwand dadurch wie bei Tag:
   linke Flügelmauer 89,79,67 gegen Arcade 61,57,56, Gesims 72,72,74 gegen 37,45,60 (gemessen, 0–255); nah am Portal
   (Bild 01) passt es (48,54,65 gegen 38,46,62). Änderung: eine Abblendkante (Projektortextur am Spot oder ein
   zweiter, flacher Kegel) – nicht im Portal ausblenden, das träfe jede Mauer gleich.
7. **R4 `builders/road.gd` / Straßenshader, Fahrbahn im Tunnel von außen**: Arcade beleuchtet die Fahrbahn in der Röhre
   immer mit Tunnellicht (warm), Modern nur, wenn die Kamera im Tunnel ist: von außen ist sie kalt grau (Tag
   47,49,57 gegen Arcade 42,33,24; 22 Uhr 94,94,99 gegen 148,126,102 – gemessen am Gotthard-Portal). Änderung: die
   Tunnel-Segmente (die `road.gd` schon kennt) bekommen dasselbe Licht wie `tunnel.gdshader` (`TUNNEL_FOG`,
   Lampenfarbe, `darkness_m`), unabhängig vom Ort der Kamera.
8. **Modell `props/bridge_pylon_bare` (AS4-Nachfolger)**: Sonnenseite bei Tag rund 12 % heller als Arcades Säule,
   Schattenseite rund 11 % dunkler (Mittel gleich, km 78,4). Ein 10 % dunklerer Atlas mit `night_albedo` 0,5 statt
   0,45 hielte die Nachtreihe gleich.
9. **R5 selbst (nicht mehr geschafft): Spitze im Haken `far_ground`** 69,9 ms gegen 17,7 ms der Basis (einmal je Lauf
   gemessen, Last 20): vermutlich das Bild, in dem `build_river()`/`_build_land()` Fluss und Fernland einer Brücke
   anlegen. Auf echter Hardware messen; wenn bestätigt, `river_reach()` (Schleife über das ganze Pfadfenster) und den
   Aufbau auf zwei Bilder verteilen oder im `prepare()` vorbauen.
10. **R5 selbst, klein**: der Kopfblock der Pylone ist nachts heller als der dunkle Pylon (Strukturmaterial ohne
   `night_albedo`) – im 4-fach-Ausschnitt von `kb_flugfeuer_22uhr.jpg` sichtbar, im Spiel 2 × 2 m in 95 m Höhe.
11. **Doku**: `docs/renderer-modern.md` Abschnitt 15 (R5) kann beim Zusammenführen mit R4/R6 kollidieren – dort neu
   nummerieren.
12. **Test `test_props :: test_library_resolves_every_prop_set`** (R4s Datei) schlug in einem gefilterten Lauf vor dem
   Neustart einmal fehl („fallback_sets zählt die Vertretungen: erwartet 0, ist 78“ – Bibliothek noch nicht fertig
   geladen), allein und in allen späteren Läufen grün: wartet vermutlich unter Last nicht lange genug auf `ModelDB`.
