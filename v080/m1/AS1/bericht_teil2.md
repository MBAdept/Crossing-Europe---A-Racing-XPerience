## 4. Was gebaut wurde

### Spielerautos `player/limousine`, `player/kompakt`

- Karosserie aus den Generatoren der Sprites (`cesprites.player_cars`) in zwei Stufen: `lod0` (Rennen) und `show`
  (Showroom). Hooks mit Voreinstellung „wie im Sprite“ – kein Sprite-Vertex bewegt sich (Abschnitt 6).
- **Lampen mit Tiefe:** Jede Lampeneinheit ist eine Mulde in der Karosserie (Hook `lamp_depth`): Boden, Wände,
  versenkte Leuchtkörper, Streuscheibe bündig in der Öffnung. Der Lichtanker liegt an der Oberfläche.
- **Heck:** Leuchten mit Tiefe, dritte Bremsleuchte (Limousine: Leiste unter dem Dach hinter der Heckscheibe;
  Kompakt: die des Entwurfs im Dachspoiler), Kennzeichen mit Rahmen und zwei Kennzeichenleuchten (leuchten mit
  dem Rücklicht), Rückstrahler, Endrohre, Emblem, Rückfahrlicht, eigene Blinkerfelder.
- **Glas und Innenraum:** durchsichtiges, getöntes Glas mit Spiegelung (Fresnel), dahinter Sitze, Kopfstützen,
  Armaturenbrett, Lenkrad links, Hutablage, Innenverkleidung. Die Kabine ist dafür aufgeschnitten.
- **Front:** Scheinwerfer mit Tiefe und Tagfahrlicht, Kühlergrill als Vertiefung mit Lamellen, Spiegel mit Glas,
  zwei Scheibenwischer, Türgriffe, Dachantenne (Haifischflosse).
- **Räder:** Speichenfelgen mit Tiefe, Bremsscheiben und Sättel, Reifen, Radhäuser mit Innenkotflügel.
- **Schattenwerfer:** grobe Hülle, 12 mm unter die Außenhaut gezogen (Abschnitt 5, Runde 6).

### Verkehrsautos `traffic/sedan`, `traffic/hatch`, `traffic/wagon`

- Neu aufgebaut auf den glatten Lofts von `carbody.SmoothCar` (bisher nur für die Spielerautos benutzt), gespeist
  aus den Entwurfstabellen der Sprites (`cesprites.designs`). Die alten Lofts von `vehicles.Car` knitterten in
  `lod1`/`lod2`, ihre Stoßfänger stachen an den Ecken durch die Karosserie.
- Fenster, Lampen, Kennzeichen (mit Zeichen), Griffe, Fugen, Tankklappe: als Geometrie in die Karosserie
  geschnitten, entlang ihrer Kontur – in `lod0`, `lod1` und `lod2` dieselben Linien.
- `lod1`/`lod2`: dieselben Lofts mit weniger Stationen, Normalen von `lod0` übertragen. Sie vereinfachen, sie
  knittern nicht. Neue Prüfregel: Hüllquader jeder Stufe ≤ 3 cm neben dem von `lod0`.
- Alle Farbsets sind Lackwerte desselben Netzes (Limousine 4, Schrägheck 5, Kombi 4).
- Glas dunkel und spiegelnd (Glas-Klasse in `lod0`), kein Innenraum. Felgen mit fünf Speichen und Bremsscheibe,
  Spiegel mit Glas, Endrohr, Kombi mit Dachreling.

### Sattelzug `traffic/truck`

- Zugmaschine (Fahrerhaus nach Profil, Sonnenblende, Dachspoiler, Seitenverkleidung, Stoßfänger mit
  Scheinwerfern, Tritte, Tanks, Spiegel, Wischer) und Kofferauflieger als eigene Knotengruppen mit Drehpunkten
  (`groups` im Manifest) – der Renderer kann den Zug knicken.
- **Heck (liest sich auf 20–150 m):** Türen mit Rahmen und Gestängen, rot-weiße Konturmarkierung (leuchtet bei
  Nacht als angestrahlte Fläche), zwei rote Umrissleuchten oben, Leuchtenträger mit Blinker / Rück- und
  Bremslicht / Rückfahrlicht, Dreieckrückstrahler, Kennzeichen, Unterfahrschutz, Schmutzfänger.
- Vier Lackierungen als Lackwerte (Koffer, Fahrerhaus, Streifen + Schriftzug „CE“).

## 5. Runden: was ich gesehen und geändert habe

1. **Bestand aufgenommen** (Lauf 1 war durch einen Neustart beendet): Katalogeinträge für Kompakt, Schrägheck,
   Kombi; erster Export. Prüfer rot (Budgets, Lampenflächen).
2. **Spielerautos, Runde 1:** Lampen waren aufgesetzte Schichten ohne Tiefe, Glas undurchsichtig. → Mulden
   (`lamp_depth`), Glas-Shader mit vormultipliziertem Alpha, Innenraum sichtbar. Fehler dabei: 24 verdrehte
   Dreiecke (Fasen breiter als das halbe Teil; Splitter nach der 16-Bit-Quantisierung) → Splitterfilter.
3. **Spielerautos, Runde 2:** Kamm aus Lackdreiecken entlang der Scheibenoberkante; Decal-Enden gezackt. →
   Schnitt entlang der Normalen-Isolinie, Splitter in der Projektion übersprungen, Deckungsprüfung.
4. **Spielerautos, Runde 3:** Heck zu leer, Grill flach. → dritte Bremsleuchte, Kennzeichenrahmen + Leuchten,
   Antenne, Wischer, Grill mit Tiefe; Fugen über den Lampenmulden weggeschnitten; Mulde des Kompakten läuft über
   Karosserie und Kabine.
5. **Verkehrsautos:** `lod1`/`lod2` knitterten, Stoßfänger stachen durch, Loch unter der Rückleuchte der
   Limousine, vordere Blinker des Kombi 0 cm², Scheinwerfer in `lod1` 8 cm². → Neuaufbau auf `SmoothCar`,
   Flächenbilanz beim Schnitt, Rang der Decals aus der vollständigen Liste, Blinker immer oben; dunkles „Brett“
   an den flachen Endkappen → `flatten_ends`.
6. **Showroom-Vergleich:** dunkle Schraffur auf Kotflügel und Tür des Kompakten. Ursache war nicht das Netz,
   sondern der Schattenwerfer: Die grobe Hülle stand hinter dem ausgestellten Radlauf 7,9 mm aus der Karosserie
   (gemessen) und warf ihren Schatten auf sie. Außerdem lag die Kappe der Radtrommeln vor den Felgen – die Felgen
   bekamen nie Sonne („stumpfe Felgen“). → `core.tuck_inside` (Hülle 12 mm unter der Haut), Trommeln nur noch die
   innere Reifenhälfte; Verkehrsautos bekommen Radtrommeln im Werfer, der Lkw ein Fahrerhaus nach Profil.
7. **Lkw:** Heck aus 20 / 60 / 150 m betrachtet; Reifen standen 13 mm über dem Boden (Prüfer) → Drehkörper beginnt
   mit einem Punkt senkrecht unten; `lod2` über Budget → Schriftzug und Grilllamellen dort weggelassen.
