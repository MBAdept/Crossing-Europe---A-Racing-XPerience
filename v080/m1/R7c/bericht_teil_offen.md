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
