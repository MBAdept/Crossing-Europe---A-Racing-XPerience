
## 4. Abnahme

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Vertrag R7: Wahrzeichen auf dem Pfad bis 1.900 m mit Arcades Dunstgesetz und Nacht-Anstrahlung | erfüllt (gemessen) | `test_landmarks`: `fade()` = `RoadRenderer.landmark_fade` an 20 Abständen × 3 Sichtweiten (Abweichung < 10⁻⁵); `check_landmarks` „reichweite“ (props.gd zeichnet kein Wahrzeichen mehr, alle im Builder), „nacht“ (1.900 m, zwei beleuchtet) |
| Vertrag R7: A/B-Bögen von zehn Stadteinfahrten | erfüllt | `boegen/<stadt>.jpg` (12:00, 19:30, 22:00), dazu Nahbilder `boegen/nah_prozedural.jpg` |
| Vertrag R7: Wahrzeichen dort, wo Arcade es zeigt (≤ 5 % der Bildbreite bei 600 m, gerade Anfahrt) | erfüllt (gemessen) | `check_landmarks` „position“: 0,0 px (Burgos, Bild) und 24,7 px (Kirche bei Slavonski Brod, beide Richtungen) bei 600 m, Grenze 64 px; Render-Prüfung „wahrzeichen_stelle“ (Hamburg, Kurve): 18 px |
| Vertrag R7: Skyline und Silhouetten im Hintergrund wie Arcade | erfüllt | `check_landmarks` „skyline“ (Paris km 376: Sacré-Cœur −30° voll, Eiffelturm 0,21 – in Reichweite ausgeblendet; vor den City Limits keine); Bilder `bilder/skyline_*` |
| Vertrag R7: LOD-Wechsel in den Clips bei „Mittel“ unsichtbar | für R7b erfüllt (gemessen), Clips bei „Hoch“ | Der einzige Wechsel von R7b (deckend → durchscheinend bei 0,70 L) ist bei voller Deckung pixelgleich (0 von 921.600 Pixeln); Clips Hamburg/Paris ohne Springen. Die Fern-LOD der Bauten und Pflanzen ist R7c. |
| Leitung 1: Stelle, Reichweite, Gesetz, Flutlicht, weich (kein Raster) | erfüllt | s. o.; „wahrzeichen_weich“ (Nachbarwechsel 0,23, Raster ≈ 1), „weich“ (durchscheinend ab 0,70 L) |
| Leitung 2: Skyline wie Arcade; unter der Horizontzeile fernes Land (A-10) | erfüllt (Bild) | S1–S5 und zehn Einfahrten: kein heller Streifen, kein Wandmuster (§5) |
| Leitung 3: eine Schnittstelle für AS6, dokumentiert | erfüllt, Ort abweichend | §18.2 von `docs/renderer-modern.md` (nicht §15/§16, s. §8) |
| Leitung 4: keine Instanz-Uniform (A-19) | erfüllt (gemessen) | `test_landmarks` „keine Instanz-Uniform“ (Shader und Builder gelesen); je Wahrzeichen eigene Materialien |
| Offen N1: Tönung | erfüllt | `test_landmarks` „Tönung“: `tint` × `fallback_tint` steht im Material des Bildes und der Modellklassen `baked`/`baked_cutout`/`vpbr`, in der deckenden (nah) und der durchscheinenden (fern) Variante |
| Offen N2: Form je prozeduraler Art | erfüllt | vier 3D-Formen (`proc_mesh`), Test „Formen“ (Höhe, schlank, Windung, Leuchtpunkte) |
| Offen B-09: weiches Ausblenden | erfüllt | durchscheinende Variante statt Dither |
| Offen: Elbphilharmonie nachts | erfüllt, etwas heller als Arcade | `ab/hamburg_22_ab_00.jpg` |
| A-18: `collect()` jedes Builders ≤ 2 ms (Deck) | erfüllt (gemessen bei „Mittel“, Deck gefolgert) | `landmarks`: `collect` 0,001 ms, Hauptthread (`update`) Ø 0,054–0,056 ms, höchstens 1,2 ms (§7) |
| A-19: Instanzbudget ≤ 230 | erfüllt (gemessen) | `check_instance_budget*`: 141 / 172 / 216 |
| Korrekturen des ersten Testbuilds halten | erfüllt (gemessen) | `check_start_km0`, `check_terrain_cover` (K1), `check_light_base` OK; `test_far_ground_water` 3/3, `test_props` 13/13 |
| Gate Import | erfüllt | Exit 0, 0 Fehler |
| Gate `tests/check_scripts.gd` | erfüllt | 334 Skripte, 0 fehlerhaft |
| Gate `tools/run_tests.sh` | erfüllt (ein voller Lauf) | „Tests bestanden (995 s)“ |
| Gate `tools/golden.sh check` | erfüllt | 20 von 20 und 17 von 17 identisch |
| Gate `tools/golden.sh modern-check` | teilweise: 5 von 6 | `modern_s4_mittel` max. 2/255 an 369 Pixeln (Michel, gewollt), nach A-18 nicht neu erzeugt; OpenGL ES OK |
| Gate `tools/run_render_checks.sh all` | erfüllt | 29 OK, 0 failed |
| Gate `modern_sight.gd --full`, `modern_path_check.gd --full` | erfüllt | alle CHECK OK |
| Gate ganze Etappe Modern unter Xvfb ohne Skriptfehler, Leistung neben der Basis | erfüllt (gemessen) | Kiel–Hamburg, Dresden–Leipzig: ok, 0 Skriptfehler; Tabelle §7 |
