
## 15. Gebäude, Brückenteile und Schiffe (Bauabschnitt 5, AS4)

Die übrigen Land- und Stadtgebäude, die Brückenteile und die Schiffe der Sprite-Sets haben jetzt Echtzeit-Modelle:
Kirche, Fabrik, Haus mit Läden, Wohnblock A und B, Altstadthaus mit Treppengiebel, Ladenhaus, Büroturm,
Brückenlaterne, Pylon der Schrägseilbrücke, Fachwerkportal, Hausboot und Fähre; die Windmühle von Bauabschnitt 2 hat
echte Fensteröffnungen bekommen. Damit hat jedes Requisiten-Set außerhalb von `city_*`, den Wahrzeichen und der
Vegetation ein Modell.

TABELLE

### Bauer `house` (`ce3d/buildings3d.py`)

Der Gebäudebauer von Bauabschnitt 2 (`props3d.py`, unverändert – die Schlüssel aller bisherigen Modelle bleiben
gleich) hat einen Nachfolger in einem eigenen Modul:

- **Öffnungen:** Fenster aus den Rastern des Generators (`WINDOW_LOG`), auch mit Rundbogen. Das Bogenpolygon
  umschreibt den gemalten Kreis (sonst blieben zwischen den Sehnen Streifen des gemalten Fensters – und nachts seines
  Lichts – auf der Wand). Laibung (gebacken, mit Verdeckung), Rahmen als Ring zwischen Umriss und Innenumriss,
  Sprossen je Fensterart (`bars`: Sprossenfenster der Fabrik 4 × 4, Oberlicht der Läden), Sohlbank, Scheibe. Ob
  eine Öffnung in ein anderes Volumen führen würde (der Turm steht vor dem Kirchenschiff), entscheidet ein Strahl
  entlang der Wandnormale (`Cover`), nicht mehr ein Hüllquader.
- **Licht der Scheiben:** Kanal 12, die Leuchtfarbe ist die Lichtfarbe des Sprite-Rasters × 0,47 (sRGB). Eine
  unbeleuchtete Lampe zeigt die Hälfte davon: bei Tag dunkel getöntes Glas, nachts warmes (Wohnungen), kaltweißes
  (Fabrikhalle) oder hellweißes Licht (Läden). Welche Scheibe leuchtet, folgt dem Anteil `lit` des Rasters.
- **Fensterläden** (Haus): Tafeln 3 cm stark, 1 cm vor der Wand, mit Lamellen im Atlas (gebacken).
- **Schallluken** (Kirchturm, `louvre`): schräge Lamellen vor einer dunklen Rückwand.
- **Uhren** (Kirchturm, Dekore mit `clock`): Zifferblatt als angestrahlte Fläche (Kanal 14: bei Tag seine Farbe,
  nachts beleuchtet), Rahmen, Stundenmarken, Zeiger.
- **Türen:** Flügel in der Farbe des Dekors mit Füllungen und Fuge, Stufen davor; Tore über 2,6 m Breite mit
  waagerechten Rippen (Fabrik).
- **Dachrinnen und Fallrohre** an die eigenen Wände (`gutters.walls`), **Flutlicht** des Kirchturms (`flood`:
  Materialkopie, deren Lichtebene die Wandfarbe mit der Höhe abklingend hinzufügt – im Nachtlicht-Atlas).
- **Schriftzug** (`sign`): Buchstaben aus `cesprites.textgeo` auf einer Tafel, nachts beleuchtet (Kanal 14).
- **Vorhangfassade** (Büroturm, `curtain`): die Wände werden ersetzt durch Brüstungsbänder (gebacken, aus dem
  Material des Turms), zurückgesetzte Scheiben je Achse und Geschoss (vpbr: spiegeln den Himmel, ein Drittel leuchtet
  nachts) und Lisenen; Eckpfosten schließen die Ecken.
- **lod1** ohne Feinteile (Rahmen, Sprossen, Sohlbänke, Rinnen, Lamellen, Marken, Geländerstäbe): ab der ersten
  Umschaltentfernung des Requisiten-Builders. Rahmen von 6 cm sind dort unter einem Pixel und würden nur flimmern.

**Bake mit Lochfüllern.** Die Öffnungen werden vor dem Bake geschnitten. Würde man die Löcher im Atlas einfach
auffüllen (Dilatation), stünde dort die Farbe des gemalten Rahmens – in den kleineren Mipmap-Stufen umgab dann ein
heller Saum jedes Fenster (bei 60 m deutlich, auf der Rückseite mit geringerer Texeldichte schon näher). Darum wird
jedes Loch für den Farb-Bake mit einer Füllfläche geschlossen (eine Kopie des Fassadenmaterials ohne Licht): Im Atlas
steht in der Öffnung das gemalte Fenster des Sprites, die Mipmaps mitteln Wand und Fenster richtig. Die Lichtebene
backt die Füller schwarz (nur die vpbr-Scheiben leuchten), vor der Umgebungsverdeckung werden sie wieder entfernt
(sie würden die Laibungen verschließen), und das Netz enthält sie nicht.

### Brückenteile (`ce3d/bridges3d.py`)

Die Generatoren stehen in `cesprites/props_cities.py` (Stadtpakete) und bleiben unverändert: Die Bauer lesen die
Balken des Generatornetzes zurück (`boxes()`: Achse, Enden, Querschnitt jedes Kastens).

- **Pylon** (Bauer `pylon`, Kategorie Mast: ein Zeichenaufruf): Beton, Kopf, Ankerplatten und Flugbefeuerung in
  einem Atlas; der Pylon ist in drei Höhenbänder geteilt (eine 82 m lange Karte begrenzt den Atlas auf 12 px/m). Die
  Seile sind vierseitige Prismen, deren Dreiecke alle ein einfarbiges Feld des Atlas lesen. `lod1` hat 0,4 m statt
  0,24 m starke Seile (ein Seil von 0,24 m ist ab etwa 170 m schmaler als ein Pixel). Die Flugbefeuerung hat einen
  Lichtanker mit Richtung (Fernglühen der Flare-Ebene).
- **Fachwerkportal** (Bauer `truss`, Straßenmöbel: ein Zeichenaufruf): Gurte, Pfosten, Sockel und Querriegel als
  Geometrie; Streben und Knotenbleche jeder Ebene als gezeichnetes Ausschneidebild (Streben ≥ 2,5 Texel, Halo 0,33 –
  mipmap-fest wie der Strommast) auf einem Streifen aus Vierecken um das Fachwerk. Die beiden Hängelampen leuchten
  nachts und haben Lichtanker nach unten (Lichtpfützen auf der Fahrbahn).
- **Brückenlaterne** (Bauer `lantern`, ein Zeichenaufruf): eine unbeleuchtete vpbr-Lampe zeigt die halbe
  Leuchtfarbe – das Milchglas war bei Tag hellbraun. Die Seiten des Glases sind angestrahlte Fläche (Kanal 14: hell
  bei Tag, leuchtend bei Nacht), nur die nach unten schauenden Flächen sind Lampen (Kanal 12) mit den drei
  Lichtankern.

### Schiffe

- **Fähre:** Das Sprite zeigt ihre Steuerbordseite (`view_yaw` 90°). Das Modell ist um −90° gedreht: Die
  Breitseite schaut zum anfahrenden Spieler, der Bug nach +X (wie im Sprite rechts). Hook `lowpoly3d` in
  `props_road.ferry_ship` (Rumpfstationen nur, wo sich der Querschnitt ändert; Rettungsboote mit weniger Flächen;
  Decklampen als Würfel). Die vielen Kabinenfenster bleiben gemalt (nachts im Nachtlicht-Atlas), Rumpf und Aufbauten
  sind in Stücke von höchstens 82 m geschnitten (Atlas-Karten). Decklampen leuchten ohne Anker, die drei
  Positionslichter haben Anker.
- **Hausboot:** Seine Wände kommen aus `props_cities.wallmat`, das kein Fensterlog schreibt. Während das Modell
  gebaut wird, wird die Funktion von außen umhüllt (`_log_city_walls`): Ihre Raster gehen als Rechtecke ins Log.
  Das ausgeschnittene Geländer (Stäbe von 3 cm) ist als Pfosten und Holme neu gebaut, die Topfpflanzen sind dezimiert
  (Budget Landgebäude).

### Neue Hooks (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `allround` | `church`, `house_med`, `factory`, `building_block_a/b`, `building_oldtown`, `building_shop` | Rückseiten mit Fenstern (Haus, Laden: Tür), Kirchturm mit Schallluken und Uhren rundum, Rückgiebel des Altstadthauses; gemalte Splitter (Kirchenschiff, oberste Reihe von Block B) und das Tor über zwei Fenstern der Fabrik bereinigt |
| `gable3d` | `building_oldtown` | Treppengiebel als ein Prisma (seine Fenster lassen sich schneiden) |
| `win3d` | `windmill` | keine gemalten Fenster (das Raster liegt über einer Ecke des Achtecks); der Bauer schneidet Öffnungen in die Mitte der Flächen |
| `lowpoly3d` | `props_road.ferry_ship` | weniger Rumpfstationen, einfachere Rettungsboote und Decklampen |

`check_sprite_geometry.py --only props/`: GEOMETRIE

### Ehrliche Einordnung

EINORDNUNG
