## 2. Wie geprüft wurde

- **Gegenstand.** Zweig `worktree-wf_db8ba6cd-508-4` (gesichert als `origin/wip/v080-as5a2`), Stand **3c5e37a**, nur
  gelesen. Gerendert und gemessen in einer Kopie im Arbeitsordner (`m1/KRITIK-5a2/tree`: Arbeitsbaum ohne `.git`,
  `build/` und `_cache3d`, mit seinem Import-Cache; Import 0 Fehler). Keine Commits, kein Zweig, keine Datei des
  AS5a2-Arbeitsbaums geändert. Alle Läufe mit `nice -n 19`, immer nur ein schwerer Lauf, absolutes `XDG_DATA_HOME`
  und eigener Mesa-Cache im Arbeitsordner.
- **Messgrundlage.** **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig` bzw. das Rennen selbst); **angesehen** = Urteil nach Bildern;
  **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und
  Maßen abgeleitet.
- **Lage wie im Rennen.** Positionen und Kanten aus der Zählung `census_all.log` (AS5a1, alle Etappen): Innenstadt-Sets
  stehen 6,6–9 m von der Fahrbahnmitte (Kante), Vorort-Sets 10–19 m. In den Prüfszenen steht jedes Modell wie vom
  Requisiten-Bauer verankert: Anker = Kante (Innenstadt 7 m, Vorort 13 m) + `extent_l`.
- **Werkzeuge** (nur in der Kopie unter `tools/kritik/`, aufbewahrt in `m1/KRITIK-5a2/kt/`; die Kopie selbst ist gelöscht): `k4_scene.gd` (KRITIK-4:
  `dist2` Spielkamera bei 10/30/100/250 m mit dem Arcade-Platzhalter derselben Lage darunter, `close` Nahansichten,
  `outline2` Umriss in der Sprite-Kamera, `lods` Stufenwechsel), `my_scene --mode=sparkcam` (AS4R: Flimmern),
  `tint_scene.gd`, `texel_k5.gd` (KRITIK-5a1: Texeldichte je Wandrichtung), `k5_scene --mode=drive` (Fahrfilm durch eine
  Prüfstraße bei 50 km/h, 60 Bilder/s); **neu** `k6_scene.gd --mode=lodcol` (dasselbe Modell bei 60/120/250 m als lod0,
  lod1 und Sprite im selben Licht: mittlere Farbe, Helligkeitsstreuung, dunkles und helles Zehntel), dazu
  `py/rough2.py` (zeitliche Rauheit einer Bildfolge) und die Hilfen von KRITIK-5a1/AS5a2 (`share.py`, `mipcov.py`,
  `mipband.py`, `boxlum.py`, `litpx.py`, `tiles.py`).
- **Rennen.** `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand, Seed 11, Limousine, Autopilot,
  Verkehr eingeschwungen, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start) an den Ankünften
  Paris, Amsterdam, Brüssel, Lyon, Bern und in den Vororten von Lyon und Amsterdam; „Hoch“ wenn nicht anders gesagt.
- **Was der Bauer selbst schon gemessen hat**, habe ich nachgerechnet statt übernommen (Abschnitt 6).
