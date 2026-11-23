## 10. Für die nächsten Pakete / die Leitung

1. **QR7c-01:** `graphics.modern.props.lod0_m` – `tag:city` streichen (oder ≥ 50 m); 30 m nur für Fachwerkzeile,
   Fachwerkzeile B, Haussmann, Pariser Eckhaus. Danach Hamburg Deck 12 Uhr gegen 43a1fcc ansehen (Speicher-Türen).
2. **QR7c-06:** Raster bei stehender Kamera abschalten (`ce_lod_still`) oder Entscheidung der Leitung; Startbild
   Nürnberg – Fulda km 0 als Prüfbild.
3. **QR7c-02:** sechs Tests/Prüfungen nachrüsten (Fernlicht-Material und -Render, Shader-Marker leaves/cutout/relief/
   cover, Phasenvielfalt, sink/align mit Werten, Anbau im Korridor).
4. **QR7c-03:** `_apply_lod` nur bei Bandkreuzung über die Kinder laufen lassen; Haken danach auf Deck ≤ 1 ms Spitze.
5. **Zusammenbau:** Konflikt `tests/unit/race3d/test_props.gd` mit FIX-RINT – beide Fassungen behalten; FIX-R7a
   (`4a43944`) mischt konfliktfrei; nach dem Zusammenbau `tools/run_tests.sh test_props` und
   `tools/run_render_checks.sh modern check_lod_band`.
6. **Asset-Paket:** lod1 des Speichers (und anderer Häuser mit 3D-Kassetten) sollte die Türkassetten im Atlas tragen;
   Nachtfenster F-04 (Haussmann, Kontor, Fachwerk, Berner Lauben) bleiben das größte Nacht-Defizit gegen Arcade.
7. **R7a/R6 (nicht R7c):** Lyon-Vorort km 286 ohne Gartenmauern und Bäume, Wald Dortmund – Frankfurt km 48–50 ohne die
   rechte Fichtenreihe/Baumgruppe – in Basis und R7c gleich; mit FIX-R7a erneut ansehen.
8. **QA-mid:** einen Clip „Paris-Einfahrt Mittel“ auf dem Endstand aufnehmen (R7cs Clip ist vor dem
   Schattendurchgang-Fix entstanden; Kachel-Auswertung ohne Stufen-Spitze).
9. `vpbr.gdshader`-Besitzer: `STATIC_INJECT` (Band, Fernlicht, Rotorphase) in den Shader übernehmen.
10. Fernlicht auch für Tankstelle/Grenze/Brücke (`shadow_far`/`far_sun` auf ihre `baked`-Materialien), falls ihre
    Fassaden fern heller werden – nicht gemessen.
