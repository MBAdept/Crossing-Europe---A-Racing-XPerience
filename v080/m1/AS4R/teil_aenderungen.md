**Pylon** (`ce3d/bridges3d.py`: `_upright`, `fan_cables`; Katalog `props/bridge_pylon`)
- Das Bein des Generators neigt sich um 3,5° zur Straße (Kopf 5 m über der Fahrbahnkante). `_upright` stellt es
  senkrecht (Scherung bis 82 m, darüber der Versatz des Kopfes), rückt es 0,9 m nach außen und kappt den Sockel an
  der Deckkante: Fuß und Sockel enden bei Modell-x −1,3 m (= Geländerlinie bei 7,55 m Aufstellung).
- `fan_cables` ersetzt die zehn Seile je Seite des Generators durch sieben: Kopfanker 55–79 m auf der Straßenseite
  des Beins, Deckanker bei x −1,15 m (Seilachse; mit 0,32 m Stärke enden die Seile außerhalb der Geländerlinie), 1,1 m
  hoch wie in Arcade, 8–36 m vor und hinter dem Pylon, als Halbfächer ohne Kreuzung (der höchste Anker läuft am
  weitesten – Generator und Arcade kreuzen ihre Seile).
- 36 m: die Zählung aller Schrägseilbrücken des Netzes (`pylon_census.gd`, 5 Brücken, 44 Pylone) ergibt als
  kleinsten Platz vom Pylon zum nächsten Brückenende 40,5 m (Elisabeth- und Vanšu-Brücke, je 150 m); Arcade zeichnet
  `cables` = min(64 m, 0,24 × Länge) = 33,8–62,6 m. Engster Bogen an einem Pylon R 449 m: das gerade Seil endet dort bis
  1,4 m neben der Deckkante – auf dem Seitenstreifen (2,5 m), nicht in der Fahrbahn (gerechnet).
- Eine Stufe (232 Dreiecke, vorher 520 / 520 in zwei Stufen), die Ankerplatten (`bpy_anch`) entfallen.
- `extent_m` = Wert des Sprites aus dem Generatornetz (`extent_source`): der kürzere Fächer hätte die Ausdehnung
  in der Sprite-Ansicht verändert; der Pylon wird nicht kantenbündig gestellt (kein `align`).
- Neu **`props/bridge_pylon_bare`** (`bare`, Set `modern_only`): derselbe Pylon ohne Seile (120 Dreiecke) für R2/R5.

**Fensterscheiben** (`ce3d/buildings3d.py`: `_filler_mat`, `_settle_fillers`, `_pane_mask`, `Patches`)
- Die Lochfüller (Kopie des Fassadenmaterials, schließt jedes Loch für den Farb-Bake) behalten bei Fenstern das
  Licht des Sprites × `PANE_LIGHT_K` 0,55 und werden nach Farb- und Licht-Bake um die Laibungstiefe zurückgesetzt –
  sie **sind** die Scheiben. Bei Tag: das gemalte Glas, 8 % zum Himmel getönt (`PANE_TINT`), ohne
  Umgebungsverdeckung. Nachts: das Licht des Sprites für genau dieses Fenster aus dem Nachtlicht-Atlas.
- Füller von Türen und Schallluken werden wie bisher gelöscht.
- Vorhangfassade und Mühlenfenster (kein gemaltes Fenster dahinter): `Patches` – je Material ein kleines Quadrat
  unter dem Modell wird mitgebacken, alle Scheiben lesen dessen Atlasfeld.
- `PANE_LIGHT_K` 0,55: so liegt die Spitze der Fenster im Rennen bei 216 (Arcade 225) und die Farbe nahe am
  Sprite (geprüft mit 0,4: orange und dunkler).

**Fabrik** (`_skylight`): die fünf Shed-Glasbänder bekommen ein eigenes Material – Glas des Sprites mit Sprossen alle
1,4 m, Kämpfer und Randrahmen; Licht #cfe0ff × 0,9 × 0,3, nach oben auf die Hälfte abklingend, nur in den Scheiben.

**Büroturm** (`_curtain`): Scheiben als Atlasfelder im Glasverlauf des Sprites (#2c4256 unten → #6f8ea8 oben, sechs
Stufen); 35 % (293 von 840) leuchten in drei Stärken, ausgewählt per SHA-1 je Seite, Geschoss, Achse; Foyer: `light_scale`
`tower_lobby` 0,2, davor 13 Pfosten (vpbr) und ein Kämpfer.

**Ladenhaus** (`_bag_logo`, `_sign` mit `panel=None`): Einkaufstasche mit Henkel zwischen zwei Balken auf dem Schild
des Generators (22 Dreiecke, Kanal 14), Schildlicht `light_scale` 0,25.

**Kirche**: Hook `plaster` in `props_buildings.church` (Voreinstellung = Sprite), Katalog `#ccc6b7`.

**Fachwerkportal** (nur Katalog): Streben im Ausschneidebild 1,2× breiter und 15 % dunkler (`web_k`, `web_dark`),
Stahl `#49585a` statt `STEEL_GREEN` `#56676a` des Sprites (`steel`): Sonne und Himmelslicht machen das Modell heller
und blauer als das vorbeleuchtete Sprite. Die Streben allein brachten bei 400 m nur +4 Kontrast (82 → 86), der Stahl
weitere +8 (→ 94); bei 100 m gleicht das Portal jetzt dem Sprite.

**Werkzeuge** (nur Scratch, nicht eingecheckt): `pylon_census.gd`, `emit_probe.gd`, `probe_saw.py`,
`texel_wall.gd`, `my_scene.gd` (`--mode=sparkcam`: Flimmern mit bewegter Kamera, Kontrast zum Hintergrund),
`lum.py` (Fensterlicht im A/B-Ausschnitt).
