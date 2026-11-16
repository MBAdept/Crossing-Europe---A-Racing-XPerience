## Runden (bauen → Tag/Nacht ansehen → Mängel → beheben)

**Runde 1 – Gebäudebauer, acht Gebäude (Vorschau-Bake, halbe Auflösung).**
- Heller Saum um jedes Fenster ab etwa 60 m (gemessen im Bogen: die Dilatation füllte die Löcher des Atlas mit der
  Rahmenfarbe, die Mipmaps mischten sie in die Wand) → **Lochfüller-Bake**: jedes Loch wird für den Farb-Bake mit dem
  gemalten Fenster des Sprites geschlossen, vor der Verdeckung wieder entfernt.
- Licht-Krümel nachts neben Rundbogenfenstern (Sehnen des Bogenpolygons ließen gemaltes Fenster stehen) → das
  Polygon **umschreibt** den Kreis; gemalte Splitter (15 cm eines fünften Fensters am Kirchenschiff, angeschnittene
  oberste Reihe von Block B) über Hooks entfernt.
- Öffnungen im Kirchturm übersprungen (Hüllquader-Test von AS1b: der Turm „steckt“ im Schiff) → Strahl entlang der
  Wandnormale je Öffnung (`Cover`).
- 55 Lichtanker an der Fabrik (Oberlichter als Lampen) → `baked_lamps` (Licht im Nachtlicht-Atlas, kein Anker).
- Kirche ohne Fallrohre (Wanderkennung des alten Bauers) → eigene Rinnen/Fallrohre an benannte Wände.

**Runde 2 – Brückenteile, Schiffe, Mühle.**
- Hausboot: Exporter brach ab (`props_cities.lace_mat` ohne `ce_role`) → Ausschneide-Materialien ohne Rolle werden
  `proc`; 2 914 Dreiecke (Budget 2 000) → Topfpflanzen dezimiert, Ausschneide-Geländer als Pfosten und Holme: 1 054.
- Pylon und Fähre mit 12 bzw. 5,6 px/m (eine 82-m- bzw. 182-m-Karte bestimmt die Atlasdichte) → Höhenbänder bzw.
  Schnittebenen: Pylon 21,8, Fähre 12,2 px/m (Modellmaß; im Spiel mit Maßstab 0,33–0,45 → 27–37 px/m auf dem
  Bildschirm, gefolgert).
- Mühle 2 072 Dreiecke → Öffnungen nur in vier Flächen des Achtecks: 1 928.
- Laternenglas bei Tag hellbraun (vpbr-Lampe zeigt unbeleuchtet die halbe Leuchtfarbe) → Seiten als angestrahlte
  Fläche (Kanal 14), nur die Unterseiten Lampen mit Ankern.
- Validator: „Stufe lod1 ist für die Kategorie … nicht vorgesehen“ (9 Fehler) → `lod1`-Budget in `validate_models.py`.

**Runde 3 – voller Export, Renn-Look, Spielkamera, Messung.**
- Renn-Look (A/B Kiel–Hamburg km 75,8, hoch, 12 Uhr): Pylone, Fähren, Altstadt, Haus erscheinen wie im Sprite,
  keine Skriptfehler.
- Pylon am Fuß neben der Fahrbahn nur 21,8 px/m → Texeldichte folgt der Höhe (`band_w` 1 / 0,6 / 0,45): **29,9 px/m**
  am Fuß, 17,9 px/m Mitte, 13,4 px/m Kopf (gemessen, Bake-Statistik).
- Fähre: drei grüne Lichtflecken nachts, zwei davon an weißen Lichtern (`roles.lights()` gibt allen Ankern einer Rolle
  die Farbe der ersten Lampe) → Positionslichter ohne Anker (ein Signallicht beleuchtet kein Deck).
- Stufensprung gemessen (`prop_scene --mode=lods`, eigenes Maß `pop.py`): Wohnblöcke in lod1 um 8/255 dunkler (Rahmen
  und Sprossen fehlten ersatzlos), Büroturm 18 % der Pixel geändert (Lisenenseiten nur in lod0), Pylon 7 % (Seile
  0,24 → 0,4 m) → lod1 bekommt einen **Rahmenring mit der Fläche von Rahmen + Sprossen** (`_far_inset`),
  Lisenenseiten bleiben in lod1, Seile 0,28 / 0,34 m. Werte danach siehe Messungen.
- Renn-Look Bremen–Dortmund (A/B, km 2,9): der Schriftzug „WERK 2“ der Fabrik stand am linken Fahrbahnrand in
  **Spiegelschrift** (das Set trägt `mirror_left`, der Requisiten-Builder spiegelt es dort, D24) → Werkszeichen ohne
  Schrift: Zahnrad zwischen Balken, spiegelsymmetrisch (`_gear_logo`); lod0 1 840 → 1 624 Dreiecke.
