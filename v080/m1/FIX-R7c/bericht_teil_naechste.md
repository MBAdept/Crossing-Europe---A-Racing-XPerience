1. **Zusammenbau RINT-M3:** `git merge-tree` des Endstands mit `origin/wip/v080-fix-rint`, `-fix-r7a`, `-fix-r7b` ohne
   Konflikt (gemessen). MERGENOTE Danach `tools/run_tests.sh test_props` und `tools/run_render_checks.sh modern
   check_lod_band`.
2. **Asset-Paket Stadthäuser:** lod1 des Speichers (1 283 statt 8 950 Dreiecke) mit gebackenen Türkassetten und
   Laibungen; das Kontor flimmert in lod1 bei 100–150 m 4–5 × sein Sprite (Kanten der Geometrie, der Farb-Bias hilft
   nicht); Grachtenhaus und Chalet in lod0 bei 40–60 m 3–4 × (Leitentscheid 1 gegen 3, Vertragsfrage).
3. **Asset-Paket, das `attach` als erstes nutzt:** Versätze klein halten (ein Anbau jenseits des eigenen 96-m-Stücks wird
   nicht gestellt); höchstens 8 je Modell. `H.LOD0_M` je Stil in `cities3d.py` (30 m Fachwerk/Paris) – dann
   `graphics.modern.props.lod0_m` leeren.
4. **Besitzer von `vpbr.gdshader`:** `ModernMaterials.STATIC_INJECT` in den Shader übernehmen (unverändert von R7c).
5. **`collect()` aller Bausteine** auf Kiel – Hamburg „Steam Deck“ max. 2,9–3,9 ms in R7c und FIX-R7c (A-18: 2 ms; der
   Anteil von `props` 0,08 ms) – Leitung/QA-mid.
6. **QA-mid:** den Paris-Clip und einen Clip mit Halt (Stau/Polizei) bei „Mittel“ ansehen: beim Anhalten blendet das
   Band in 0,4 s zur feineren Stufe, beim Anfahren zurück (gefolgert, hier nur als Standbild und Render-Prüfung gesehen).
7. **Nachtfenster F-04, Lyon-Vorort und Wald (R7a):** unverändert gegen Arcade schwächer – nicht von R7c/FIX-R7c.
