## 2. Hält jede Behebung des Testbuilds nach dem Zusammenführen?

| Behebung (ZS1) | hält? | Beleg (gemessen) |
|---|---|---|
| FIX-ZS1: Vorlauf vor der Startlinie, Stück −1, Spielerauto im Countdown (`road_path`, `chunk_streamer`, `chunk_context`, `layers/vehicles`) | **ja** | `test_start_lead_in` 6/6; A/B Start „Mittel“: Lackfläche gegen Arcade Kanten +0,0/+0,5/+0,0/+0,0 % (Countdown 1 s) und +0,0/+1,0/−0,5/+0,5 % (1,5 s nach LOS) – wie FIX-ZS1; Steam-Deck-Stufe 1280 × 800: Auto im Countdown an seinem Platz (Bild); Render-Prüfung `check_start_km0` (Gates) |
| FIX-ZS1: Lampenringe des Starttors werfen bei „Aus“ keinen Schatten (`gantry.gd`) | **ja** | `check_light_base` „schatten“ – bei M2INT der einzige rote Render-Check (Gates) |
| FIX-WASSER: Fernboden unter dem tiefsten Wasser (`far_ground.gd`) | **ja**, eine Regel | `test_far_ground_water` 4/4, `test_terrain_builder` (b341df8, umgestellt) grün; `check_terrain_cover` mit K1 (Gates); A/B Köhlbrandbrücke Tag/Nacht und Holtenau: Wasser wie in ZS1 |
| FIX-WASSER-R: Ersatz-Sets der sechs prozeduralen Wahrzeichen (`props.gd`) | **ja**, jetzt als Modell | `test_props` auf allen 20 Anfahrten (Kirche bzw. Hochhaus als Modell, Wahrzeichengesetz, nie gespiegelt, `fallback_scale`); A/B Belgrad |
| FIX-WASSER-R: Pylone nachts nicht heller als Arcade (`dark_material()`) | **zuerst nein** – mit AS4Rs Pylon-Modell galt die Vertretung nicht mehr (84,4 gegen Arcade 60,1); **nach Nacharbeit ja** (Abschnitt 3) | Messungen Abschnitt 3 |
| FIX-WASSER-R: Prüfposition K1, Draufsicht über `target_height()` | **ja** | `check_terrain_cover` K1, `check_terrain_plan` (Gates) |
