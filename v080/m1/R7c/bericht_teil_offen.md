## 7. Abweichungen und Vertragsfragen

- **lod0-Entfernungen in der Konfiguration statt in `model.json`** (A-22 sagt „max_dist_m in model.json“): die Mechanik
  liest `max_dist_m` aus `model.json` (heute überall der Exporter-Standard 60), die gemessenen Werte (Stadthäuser 35 m,
  Fachwerk und Paris 30 m bei „Mittel“) stehen bis zur nächsten Neuausgabe der Modelle in
  `graphics.modern.props.lod0_m` (Datei des Renderers). `model.json` gehört den Asset-Paketen; eine Handänderung
  dort würde beim nächsten Export überschrieben (`cities3d.py` setzt `H.LOD0_M` für alle Häuser).
- **Instanzabstand statt Wegabstand**: die Stufe hängt am geraden Abstand Instanz – Kamera (der Shader kennt keinen
  Weg); bisher galt der Wegabstand des Stücks. In Kurven ist der gerade Abstand kürzer, die Stufe also eher feiner.
- **`vpbr_static` per Texteinschub**: Band, Fernlicht und Rotorphase stehen in `ModernMaterials.STATIC_INJECT`
  (eigene Datei), nicht in `vpbr.gdshader` (nicht in meiner Liste, FIX-RINT ändert ihn vielleicht); ein Test prüft
  jeden Einschub. Sauberer wäre es, sie in `vpbr.gdshader` zu schreiben (notes_for_next).
- **Kein `environment_rig.gd`**: das Fernlicht kommt ohne die angebotene Ausnahme aus (Material-Uniforms je Netz,
  gesetzt von `props.gd` aus `levels.shadow_distance_m`). Folge: Modelle, die andere Bausteine zeichnen (Tankstelle,
  Grenze, Brückenteile), bekommen kein Fernlicht.
- **A-18 / Brief**: der Vertrag sagt, Pakete erneuern `tests/golden/modern_slice.*` nicht; der Brief verlangt
  `modern-make` nach Ansicht. Ich bin dem Brief gefolgt (Abschnitt 5).
- **Überblenden über den Weg statt über die Zeit** (A-16: „0,3–0,5 s wie `xfade` der Fahrzeuge“): eine Blende in der
  Zeit bräuchte je Instanz einen Zustand (Instanz-Uniforms sind nach A-19 tabu, MultiMesh-Daten je Bild neu zu
  schreiben wäre teuer). Das Band ist ±12 % der Stufengrenze (mind. 4, höchst. 25 m): bei 100 km/h dauert der Wechsel
  eines Hauses bei 35 m 0,3 s, der eines Baums bei 60 m 0,5 s, lod1 → Fernbild bei 200 m 1,7 s; bei 50 km/h doppelt so
  lange.
- **Bilder**: je Stadt drei der sechs Kombinationen (Hoch 12 Uhr, Mittel 19:30, Hoch 22 Uhr), dazu Nürnberg und Paris
  Mittel 12 Uhr und die Dämmerung in Hamburg (Mittel 19:00 / 19:30 / 22:00) – nicht jede Stadt in jeder Stufe zu jeder
  Stunde (Rechenzeit; die Stufe verschiebt die Entfernungen, nicht das Licht).
- **Flimmern ≤ 2 × Sprite** nicht überall erreicht: Fachwerkzeile lod1 bei 100 / 150 m 2,0 / 2,25 ×, Südhaus bei 40 m
  3 × (Abschnitt 3.2).
- **Arcade-Goldens** einmal auf `965b8a9` (wie verlangt nur einmal); danach habe ich nur Modern-Dateien geändert
  (`baked.gdshader`, `props.gd`, Tests, Doku).
