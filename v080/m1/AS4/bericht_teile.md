## Vertragsfragen (contract_issues)

- **Dateihoheit Brückenteile/Hausboot:** `bridge_lamp`, `bridge_pylon`, `bridge_truss_arch` und `houseboat` werden in
  `cesprites/props_cities.py` erzeugt – die Datei gehört AS5a/AS5b, der Auftrag gibt AS4 nur `props`,
  `props_buildings`, `props_road`. Lösung ohne Eingriff: Die Bauer lesen die Generatornetze zurück
  (`bridges3d.boxes()`), und `props_cities.wallmat` wird während des Baus von außen umhüllt (`_log_city_walls`).
  Der Schlüssel dieser Modelle hängt an der ganzen Datei `props_cities.py` (jede Änderung der Stadtpakete exportiert
  sie neu – deterministisch, aber Zeit).
- **`props_cities.lace_mat` ohne `ce_role`:** Geländermaterialien der Stadtsets haben keine Rolle (der Exporter
  bricht sonst ab). `buildings3d._route` setzt für Materialien mit Ausschneidemaske `proc` (Strukturregel, kein
  Namensraten). AS5a sollte das im Generator nachtragen (Hook) oder die Regel übernehmen.
- **Budget Fähre:** Die 182-m-Fähre fällt als `building` ohne `city` unter „Landgebäude“ (2 000 Dreiecke, Atlas
  1024). Das reicht nur mit gemalten Kabinenfenstern; ein eigenes Budget „Schiff“ fehlt im Vertrag.
- **Lampenkanal 12 bei Tag** (wie AS1b): Glas einer Laterne zeigt unbeleuchtet die halbe Leuchtfarbe (hellbraun).
  Lösung hier: Kanal 14 (angestrahlte Fläche) für die Seiten, Kanal 12 nur für die Unterseite mit dem Anker. Eine
  Lampenrolle „Glas“ (Tag: eigene Farbe, Nacht: leuchtend + Anker) wäre sauberer.
- **Pylonhöhe:** Arcade zeichnet den Pylon prozedural mit `height_m` der Brücke (50–120 m); das Modell hat die feste
  Höhe des Sprites (82 m + 6,8 m Kopf). Der Requisiten-Builder skaliert Modelle nicht nach `height_m`.

## Bedarf bei anderen Paketen

- **R5 (Brücken):** Maße und Anschlusspunkte siehe Abschnitt „Brückenteile“; Seile des Pylons sind im Modell (vom
  Kopf zum Deckrand), R5 kann sie stattdessen prozedural ziehen – dann wäre ein Pylon ohne Seile sinnvoll (eine
  Katalogzeile mit `cables`-Präfix auf ein leeres Objekt). Wasser fehlt: Hausboot und Fähre schweben bis dahin auf
  Wasserhöhe über dem Gelände.
- **R2/R7 (Requisiten-Builder):** `prefer_proc`/`height_m` des Pylons auswerten (Skalierung in der Höhe), Fähre wird
  nie gespiegelt (Bug zeigt nach +X).
- **R4 (Nacht):** Scheibenlicht ist auf `lamp_off_props` 0,5 und `lights_energy` 4 abgestimmt (Leuchtfarbe = Licht
  des Sprites × 0,47); Turm-Flutlicht der Kirche und die Fenster der Fähre leben im Nachtlicht-Atlas
  (`emit_energy` 1,6).
- **AS5a/AS5b:** `buildings3d` kann die Wände von `props_cities` schneiden (Fensterlog von außen, Raster als
  Rechtecke, Türen aus Rastern der Art `door`), Lochfüller-Bake, lod1 – für die Stadthäuser direkt nutzbar.
