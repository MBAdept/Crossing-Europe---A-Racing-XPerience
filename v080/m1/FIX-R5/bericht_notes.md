## 8. Offen – genaue Änderungen für die Eigentümer (notes_for_next)

1. **R4 `environment_rig.gd` (Stand `origin/wip/v080-fix-r4`, Zeile 433) – Belichtungsfläche an die wahre Ausfahrt**
   (QR5-03-Rest): `var z_quad := z_exit - 0.6` → `var z_quad := ceilf(z_exit / _track.seg_len - 1.0e-6) * _track.seg_len - 0.05`
   (oder duck-typed `renderer.builder("tunnel").tunnel_state["exit_z"] - 0.05`). Die Röhre endet an der Segmentgrenze
   nach `end_km` (wie Arcades Tunnelsegmente), R5s Ausfahrtsrahmen steht von `exit_z` − 0,35 bis `exit_z`; bei
   `end_km` − 0,6 m liegt die Fläche bis zu 3,6 m davor und überstrahlt Rahmen und letzte Röhrenmeter. In der
   Scratch-Kopie gerendert: Abschnitt 3.
2. **R4 `road.gdshader` / `road.gd` – Fahrbahn in der Röhre im Tunnellicht** (QR5-02): für Fragmente mit Flag 64
   (`tunnel`) statt Bodengesetz (Umgebung des Himmels + Sonne) Arcades Tunnellicht: `ALBEDO = vec3(0)` (kein Sonnen-
   und Himmelsanteil der Engine), `EMISSION = ce_pools_encode(ce_ground_unshow(mix(base * tunnel_ambient, tunnel_fog, f))
   + ce_pools_to_lin(lit) * extra)` mit
   `f = pow(clamp((length(VERTEX) − 12) / tunnel_darkness_m, 0, 1), 0.8)` (Gesetz von `tunnel.gdshader`);
   `road.gd update()` setzt die drei Uniforms jedes Bild aus `renderer.builder("tunnel").tunnel_state["light"]`
   (duck-typed; `ambient_in` wenn `cam_tunnel_z` > −1e8, sonst `ambient_out`; `fog`, `darkness_m`). Ziel (Arcade,
   gemessen von QA-R5): U1-Portal 12 Uhr 42,33,24, 22 Uhr 103,87,70 statt heute 48,50,57 / 66,65,67.
3. **R4 `layers/lights.gd` – Abblendkante** (Ursache von QR5-01): ein flacher zweiter Kegel oder eine Projektortextur am
   Spot, damit senkrechte Flächen 60–70 m voraus nicht bis oben hell werden. Danach darf der Fuß des Portalrahmens wieder
   auf Layer 1 (`tunnel.gd PORTAL_LAYERS`).
4. **R4 `builders/roadside.gd` `_railing` für `stone_arch`** (QR5-04, 35 Steinbrücken): das geschlossene Mittelband
   [0,24, 0,92] durch Docken alle 0,35 m (0,14 m Kante) ersetzen wie Arcade – oder die Leitung gibt Geländer auf
   Brückensegmenten R5 (Vertragsfrage 1).
5. **R4 `builders/props.gd` Zeile 599** (QR5-08, A-16 „Schiffe auf der Wasseroberfläche“):
   `h = float(it["h"]) + (0.15 if bool(inp.get("skip_bridge", false)) else 0.0)`.
6. **R4 `builders/terrain.gd`**: die Wasserquads des Geländebands weglassen, wenn `renderer.builder("bridge")` existiert
   (sie liegen 0,15 m unter R5s Wasser, etwa 768 Dreiecke je Brückenstück) – danach kann R5s `WATER_LIFT` auf 0.
7. **Integration (RINT-M2) `tests/golden/modern_slice.md5`** (QR5-07): mit `tools/golden.sh modern-make` neu erzeugen, nicht
   von Hand mischen (R5, R4, R6 ändern Zeilen). FIX-R5 ändert kein Modern-Golden.
8. **R5-Rest, klein:** der Kopfblock der Köhlbrand-Pylone ist nachts etwas heller als der dunkle Pylon (Struktur-Material
   ohne `night_albedo`; im Rennbild hinter dem HUD); die Spalten des Portalhügels zeigen nachts schwache helle/dunkle
   Streifen im Mondlicht (Arcades gesäte Höhen je Spalte; Normalen könnten aus der ungestörten Form berechnet werden).
9. **Leistung:** `chunk_commit_ms_max` an Portalen im Leistungstest des Nutzers beobachten (llvmpipe unter Last 4–18 ms
   in Basis und FIX-R5, headless ≤ 0,25 ms). Worker-Bauzeit am Tunnel 3–4 ms je Stück (Basis-FIX1 0,6 ms) – nur
   Eintreffzeit.
10. **Doku-Merge:** `docs/renderer-modern.md` §15 (R5) kann mit R4/R6 kollidieren (R4 hat 232 Zeilen ergänzt) –
    beim Merge neu nummerieren.

## 9. Vertragsfragen

1. **Geländer an Brücken** (wie QA-R5 7.1-1): Inventar B / §6 R5 nennt „railings per type“ als R5-Ausgabe, §5 W3 gibt
   `builders/roadside.gd` R4. Die Steinbrüstung (QR5-04) hat damit keinen Besitzer, der sie an Arcades Docken bringen
   muss. Beleg: `ausschnitt_stein_bruestung.jpg` von QA-R5; R5 kann eine geschlossene Wand nicht von außen durchsichtig
   machen.
2. **Licht in der Röhre über Paketgrenzen** (QR5-02/03): das Tunnellicht entsteht in R5s `tunnel.gdshader`, die Fahrbahn
   und die Belichtung gehören R4. Lösung ohne Vertragsänderung: R5 liefert `tunnel_state.light` und `exit_z`
   (dokumentiert in renderer-modern.md §15.1), R4 liest duck-typed. Vorschlag: so im Vertrag festhalten.
