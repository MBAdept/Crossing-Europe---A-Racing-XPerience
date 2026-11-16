## 2. Wie geprüft wurde

- **Gegenstand und Kopie.** Zweig `worktree-wf_aad8d49e-fb4-2`, Stand `9eef9a8`, nur gelesen. Gerendert und gemessen in
  einer Kopie im Arbeitsordner (`m1/KRITIK-4/tree`: Arbeitsbaum ohne `.git`, `build/`, `_cache3d`, dazu der
  Import-Cache des Hauptarbeitsbaums, einmal importiert; `diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits,
  kein Zweig, keine Datei des AS4-Arbeitsbaums geändert.
- **Renn-Look in den Prüfbildern.** Die Prüfszene ist `tools/models/prop_scene.gd` in der Fassung von AS3 (`be866d2`,
  `--look=race`), nur in der Kopie: das `EnvironmentRig` des Renderers mit der Palette der Stunde, die Stufen der
  Voreinstellung (Schatten, MSAA, Umschaltentfernungen der Requisiten), die Sicht des Rennens und der `vpbr`-Look der
  Fahrzeug-Ebene (`LOOK`, `env_*`), gesetzt **nachdem** die Klassenmaterialien existieren (die Falle der
  Fahrzeug-Kritik). Das Rennen setzt auf `baked` keine Klassen-Parameter (Code gelesen: nur `layers/vehicles.gd` stellt
  `vpbr`/`glass` ein); die Fensterscheiben sind `vpbr`-Lampen und tragen damit den Renn-Look. Gegenprobe: acht
  Rennbilder mit `tools/ab_shot.sh` (Abschnitt 4).
- **Eigene Werkzeuge** (nur in der Kopie benutzt, aufbewahrt unter `m1/KRITIK-4/tools_kritik/` – in eine Kopie des Baums
  nach `tools/kritik/` legen, `prop_scene_as3.*` nach `tools/models/prop_scene.*`):
  - `k4_scene.gd` (erbt von `kritik_scene.gd` der KRITIK-3, das von `prop_scene.gd` erbt): `dist2` (Spielkamera bei
    30/100/250/400 m, je Modell die seitliche Lage aus der Zählung, Maßstab, Wasserfläche, darunter dasselbe als
    Arcade-Sprite-Platzhalter), `outline2` (Umriss in der Sprite-Kamera von `cesprites`: `view_yaw` des Sets und
    `elevation_deg` des Sprite-Manifests), `close` (Nahansichten: Anfahrt, schräg, Straßenseite, Dach, Rückseite),
    `approach` (Anfahrt mit 120 km/h, 30 Bilder/s, Stufenwahl wie der Requisiten-Bauer mit 6 m Hysterese).
  - `mesh_probe.gd` (Lampenkanäle, Farben, Lage von Ecken in den gebackenen Netzen), `texel_probe.gd` (Texeldichte je
    Flächenrichtung aus UV- und Weltfläche).
  - `prop_scene.gd --mode=lods` (Stufenwechsel: Anteil geänderter Pixel und 3×3-Blöcke, Helligkeit, Farbton),
    `kritik_scene.gd --mode=sparkle` (Viertelpixel-Schritte: Anteil kippender Pixel, Modell gegen Sprite).
  - `positions.gd` und `census_all.log` von AS4 (wo die Sets stehen, seitlicher Abstand, Maßstab).
- **Lage der Modelle in den Bildern** (aus der Zählung, gemessen am `Track`-Generator; Anker = Kante + `extent_l` ×
  Maßstab): Ladenhaus 17,6 m, Altstadthaus 15,5 m, Block A 21,5 m, Block B 22 m (Mitte 37 m), Haus 34 m, Kirche 40 m
  (als Wahrzeichen-Ersatz Maßstab 2,2 bei 69 m), Fabrik 49 m, Mühle 90 m, Hausboot 25 m, Fähre 100 m (Maßstab 0,4),
  Büroturm 68 m (Maßstab 2,15), Pylon 7,5 m, Brückenlaterne 6 m, Fachwerkportal über der Fahrbahnmitte.
- **Rahmen der Läufe.** Alles mit `nice -n 19`, immer nur ein schwerer Lauf, `XDG_DATA_HOME` und Mesa-Cache absolut im
  Arbeitsordner. Software-OpenGL (llvmpipe) unter Xvfb: Aussagen über echte Grafikkarten, das Steam Deck und die
  Wirkung auf einen Menschen sind **gefolgert**.
