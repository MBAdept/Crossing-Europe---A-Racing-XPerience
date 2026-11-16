## 2. Wie geprüft wurde

- **Werkzeuge**: nur in der Kopie, nie eingecheckt; aufbewahrt unter `m1/KRITIK-3/tools_kritik/` (in eine Kopie des Baums nach `tools/kritik/` legen; erbt von `tools/models/prop_scene.gd`) und `m1/KRITIK-3/py/`.
  - `prop_scene.sh` von AS3: Spielkamera (D12: 3,4 m, Brennweite 711 px, 1280 × 720, MSAA wie „Mittel“) in 15 / 40 /
    100 / 250 m, das Arcade-Sprite als Stand-in am selben Ort, um 12, 19:30 und 23 Uhr (18 Bögen). Dazu
    `--mode=lods` (Stufenwechsel) und `--mode=clip` (2 s, 120 km/h, 120 Bilder).
  - `kritik_scene.gd`, eigener Zusatz, der von `prop_scene.gd` erbt. Modi:
    - `turn`: das Modell in 8 Drehungen (Kartenkanten, Rückseiten).
    - `slope`: Boden 30° geneigt, der Fuß 4× vergrößert.
    - `sparkle`: Viertel-Pixel-Schritte; gemessen wird der Anteil kippender Pixel, Modell gegen Sprite.
    - `outline`: orthografische Sprite-Kamera mit 6° wie `cesprites/props.py`; Umriss von lod0, lod1 und Fernbild
      gegen den Alpha-Umriss des Sprites, ohne dessen eingebackenen Bodenschatten.
    - `under`: Nahsicht wie bei Stadtbäumen 3,5 m neben der Fahrbahn.
    - `levels`: alle Stufen an den Umschaltentfernungen mit Helligkeit, **Sättigung** und **Kontrast** (Streuung der
      Helligkeit über die inneren Pixel).
  - `vertex_data.gd`: Winddaten, Normalen und Fußtiefe aus den gebackenen Netzen.
  - Zensus der Strecken mit `stage_sets.gd` von AS1b, um eine Liste je Set erweitert.
- **Rennbilder** mit `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand) an neun Stellen
  (Abschnitt 4). Dazu die zehn Rennbilder von AS3 angesehen.
- **Prüfer** gelaufen (`validate_models.py --report`, Abschnitt 5.1).
- **Rahmen der Läufe:** alles mit `nice -n 19`, immer nur ein schwerer Lauf, `XDG_DATA_HOME` absolut im Arbeitsordner.
  Etwa 45 min Render-Zeit bei einer Maschinenlast von 7–12 (gemessen).

