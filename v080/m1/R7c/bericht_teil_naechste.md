## 8. Für die nächsten Pakete

- Asset-Paket: `H.LOD0_M` in `cities3d.py` je Stil (Stadthäuser 35 m, Fachwerk und Paris 30 m bei „Mittel“ ≙
  `max_dist_m` 35 / 30) beim nächsten Export – dann `graphics.modern.props.lod0_m` leeren.
- Besitzer von `vpbr.gdshader`: `ModernMaterials.STATIC_INJECT` (Band, Fernlicht, Rotorphase) in den Shader selbst
  übernehmen; `test_static_materials_per_mesh_and_injection` bewacht jeden Einschub bis dahin.
- Nachtfenster (F-04, Asset): Haussmann, Kontor und Fachwerk zeigen um 22 Uhr deutlich weniger leuchtende Fenster als
  Arcade – Auswahl im Nachtatlas, nicht im Shader (`window_cover`/`window_ramp` regeln nur die Dämmerung).
- R7a / Korridor: Lyon-Vorort (Montpellier – Lyon km 286) und Kurveninnenseiten im Wald zeigen Häuser/Bäume, die
  Modern weglässt (schon in der Basis); prüfen, ob die Hülle von A-17 dort zu breit ist.
- Stadthäuser: eine dritte Fläche je Haus (opake Fassade `baked`, nur Geländer und Laub `baked_cutout`) – ganze
  Fassaden als Ausschnitt kosten auf llvmpipe das 1,9- bis 2,4-fache.
- Fachwerkzeile lod1 flimmert bei 100–150 m noch 2,0–2,25 × Sprite; Wege: dickere Balken in lod1 oder Fernbild früher.
- Zusammenbau (Probe mit `git merge-tree` gegen den heutigen Stand der Sicherungszweige): mit `wip/v080-r7a` und
  `wip/v080-r7b` ohne Konflikt; mit `wip/v080-fix-rint` ein Konflikt in `tests/unit/race3d/test_props.gd`
  (`modern_materials.gd` mischt sich selbst).
- Fernlicht nur auf den Modellen von `props.gd`; Tankstelle, Grenze und Brückenteile bekommen es, wenn ihre Bausteine
  `shadow_far`/`far_sun` auf ihre Materialien setzen (Uniforms sind in `baked` schon da).
- Neue Uniforms in `baked.gdshader` (`albedo_bias`, `cutout_bias`, `window_ramp`, `window_cover`) haben neutrale
  Vorgaben; wer sie für andere Modelle will, setzt sie wie `props.gd` (`PROP_LOOK`).
- Der Paris-Clip stammt von vor der Korrektur des Schattendurchgangs; QA-mid sollte ihn mit dem Endstand ansehen.
