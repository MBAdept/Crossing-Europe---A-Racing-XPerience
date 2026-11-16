## Abweichungen

- **lod1 der Gebäude und des Pylons explizit statt „auto“:** Der Vertrag nennt für Land-/Stadtgebäude und Masten eine
  automatische zweite Stufe, Nachtrag A-4 verbietet automatische Stufen auf Netzen mit Lampenkanälen – jedes Gebäude
  hat leuchtende Scheiben. lod1 ist deshalb die Detailstufe des Generators (D21: ohne Sprossen, Sohlbänke, Rinnen,
  Lamellen; mit Rahmenring gleicher Fläche), Budget = lod0-Budget (`validate_models.py`).
- **Fähre unter „Landgebäude“** (2 000 Dreiecke, Atlas 1024): Kabinenfenster bleiben gemalt (siehe Einordnung).
- **Keine Vordächer über Türen, keine Schornsteine am Haus:** Die Sprite-Entwürfe haben keine (Haus ohne Kamin, Tür
  nur hinten); die Sprites sind der Look. Türen haben Stufen, das Ladenhaus seine Markise, die Fabrik ihren Schlot.
- **Windmühle:** Die vier Fenster sitzen in der Mitte von vier Achteckflächen statt im gemalten Raster (das über
  einer Ecke lag); Hook `win3d` nimmt die gemalten Fenster nur im 3D-Bau heraus.
- **Positionslichter der Fähre ohne Lichtanker** (leuchten nur): siehe Vertragsfragen (`roles.lights()`).

## Vertragsfragen

- **Dateihoheit Brückenteile/Hausboot:** `bridge_lamp`, `bridge_pylon`, `bridge_truss_arch` und `houseboat` werden in
  `cesprites/props_cities.py` erzeugt (Datei der Stadtpakete). Ohne Eingriff gelöst: die Bauer lesen das Generatornetz
  zurück (`bridges3d.boxes()`), `props_cities.wallmat` wird während des Baus von außen umhüllt. Der Schlüssel dieser
  Modelle hängt an der ganzen Datei – jede Änderung der Stadtpakete exportiert sie neu (deterministisch, kostet Zeit).
- **`props_cities.lace_mat` ohne `ce_role`:** der Exporter brach ab; `buildings3d._route` setzt für Materialien mit
  Ausschneidemaske `proc`. Besser im Generator (Hook der Stadtpakete).
- **`roles.lights()` (Kern, nicht meine Datei):** alle Anker einer Rolle bekommen die Farbe der ersten Lampe dieser
  Rolle – an der Fähre warfen die weißen Toplichter grüne Lichtflecken. Gruppierung nach (Rolle, Farbe) würde es
  lösen; ändert den Schlüssel aller Modelle, darum hier nur umgangen.
- **Kein Budget „Schiff“:** eine 182-m-Fähre als `building` ohne `city` = Landgebäude (2 000 Dreiecke, 1024er Atlas).
- **Lampenkanal 12 bei Tag:** eine unbeleuchtete Lampe zeigt die halbe Leuchtfarbe (Milchglas hellbraun). Hier über
  Kanal 14 gelöst; eine Rolle „Glas“ (Tag eigene Farbe, Nacht leuchtend + Anker) wäre sauberer.
- **Pylonhöhe:** Arcade zeichnet den Pylon prozedural mit `height_m` der Brücke (50–120 m), das Modell hat die feste
  Höhe des Sprites (88,8 m); der Requisiten-Builder skaliert Modelle nicht nach `height_m`.

## Bedarf bei anderen Paketen

- **R5 (Brücken):** Maße und Anker oben. Wasser fehlt noch: Hausboot und Fähre stehen auf Wasserhöhe über dem
  Gelände. Zieht R5 die Seile selbst, eine Katalogzeile für einen Pylon ohne Seile.
- **R2/R7 (Requisiten-Builder):** `height_m` des Pylons auswerten (Skalierung in der Höhe); Fähre nie spiegeln (Bug
  nach +X).
- **R4 (Nacht):** Scheibenlicht ist auf `lamp_off_props` 0,5 und `lights_energy` 4 abgestimmt (Leuchtfarbe = Licht des
  Sprites × 0,47); Kirchturm-Flutlicht, Fenster der Fähre und Oberlichter der Fabrik leben im Nachtlicht-Atlas
  (`emit_energy` 1,6).
- **Kern (`roles.py`):** Ankerfarbe je Lampengruppe statt je Rolle.
- **AS5a/AS5b (Stadt):** `buildings3d` schneidet auch Wände aus `props_cities` (Fensterlog von außen, Raster als
  Rechtecke, Türen aus Rastern der Art `door`), mit Lochfüller-Bake und lod1-Rahmenring – direkt für die Stadthäuser
  nutzbar.
