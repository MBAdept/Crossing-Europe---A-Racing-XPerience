## 14. Umgebung des Schnitts (Bauabschnitt 2)

Was ein Spieler auf den ersten 75 km von Kiel nach Hamburg sieht, gezählt mit dem `Track`-Generator der Etappe
(alle Segmente bis km 75, Richtung ab Kiel; die Gegenrichtung zeigt dieselben Sets): Eiche 147, Birke 88, runder
Busch 76, Heuballen 48, Windrad 28, Zapfsäule 9, Bauernhaus 7, Blitzer 2, Tankstelle 1 und die Preissäule der
Tankstelle (ein `object`, das kein Sprite-Set hat: Sache des Tankstellen-Builders). Jedes dieser Sets hat jetzt
ein Modell – auf diesem Abschnitt steht kein Sprite-Platzhalter mehr. Dazu kommen die Modelle, die die Strecke erst
später oder anderswo zeigt: niedriger Busch, Scheune, Windmühle, Strommast, Laterne (wie Bauabschnitt 0),
Leitpfosten, Zollhäuschen, und die Bodendecker für die Innenseite von Kurven.

| Modell | Bauer | Dreiecke je Stufe | Aufrufe | Texturen |
|---|---|---|---|---|
| `props/tree_oak`, `tree_oak_b` | `tree` | lod0 1 490 / 1 520 · lod1 679 / 755 · Schatten 179 / 235 · Fernbild | 2 / 2 / 1 | Blätter 1024², Fernbild |
| `props/tree_birch`, `tree_birch_b` | `tree` | lod0 1 880 / 1 910 · lod1 591 / 644 · Schatten 154 / 177 · Fernbild | 2 / 2 / 1 | Blätter 1024², Fernbild |
| `props/bush_round`, `bush_round_b`, `bush_low` | `bush` | lod0 372 / 372 / 384 · lod1 88 / 88 / 104 | 1 / 1 | Blätter 512² |
| `props/cover_bush`, `cover_grass` | `bush`, `grass` | lod0 182 / 42 · lod1 54 / 12 | 1 / 1 | 512² |
| `props/farmhouse` | `building` | 1 107 | 2 | Atlas 1024² |
| `props/barn`, `windmill`, `customs_booth`, `fuel_station` | `building` | 290 · 1 640 · 206 · 1 480 | 2 | 1024² · 1024² · 512² · 1024² |
| `props/haybale`, `fuel_pump`, `radar_camera`, `delineator` | `building` (ein Atlas) | 672 · 384 · 328 · 12 | 1 | 512² · 512² · 256² · 128² |
| `props/wind_turbine` | `prop_vpbr` | 744 | 1 | – |
| `props/power_pylon` | `lattice` | 220 | 1 | Ausschneide-Atlas 1024² |

Alle Zahlen gemessen (`validate_models.py --report`); Exportzeiten auf dieser VM: Bäume 5–7 s, Büsche unter 1 s,
Gebäude 24–133 s (Cycles: Farbe in doppelter Auflösung plus Umgebungsverdeckung), Straßenmöbel mit Atlas
3–38 s, Strommast 2 s. Die Gebäude und Straßenmöbel haben nur `lod0`: Ihre Netze tragen Lampenkanäle, und eine
automatische Stufe darf es dann nicht geben (die Dreieckszahlen sind ohnehin klein).

### Kartenbäume (`ce3d/veg3d.py`, `ce3d/leafatlas.py`)

- **Krone:** Die Kugeln der Sprite-Krone (`props_nature.CROWN_LOG`) bleiben die Form. Auf ihrer Außenhaut liegen
  viele kleine, flache Laubkarten (Eiche bis 450, 1,5–2 m); Karten, die in einer anderen Kugel lägen, werden
  woanders hingelegt (man sähe sie nie). Gemessen schlechter: Zeltkarten (die Mitte angehoben) kräuseln sich an der
  Silhouette wie Papier, gekreuzte Kartenpaare ziehen Schlieren, wo eine Karte flach angeschnitten wird. Karten
  liegen nie waagerecht (die Neigung nach oben wird gestaucht): eine waagerechte Karte oben in der Krone sah von der
  Straße aus wie ein Strich.
- **Licht in der Krone:** Die Helligkeit jeder Karte ist ihre Verdeckung durch die übrigen Kugeln (14 Strahlen über
  der Halbkugel ihrer Normale) – innen und unten dunkler. Die Normale ist zu 55 % die Richtung aus ihrer eigenen
  Kugel: Jeder Klumpen hat eine Licht- und eine Schattenseite wie im Cycles-Sprite.
- **Holz:** Stamm und Äste des Generators, dazu ein Ast in jeden Laubklumpen (k-Means der Kugeln, 9 bei der Eiche,
  7 bei der Birke); Astenden, die aus der Krone ragen, fallen weg. Der Birkenstamm wird mit einem Ring alle 25 cm
  neu gebaut und bekommt die schwarzen Marken als Farbe **je Dreieck** (der Verschweißer teilt keine Ecke zwischen
  zwei Farben, die Marken bleiben scharf; als Farbe je Ecke verschmierten sie über die langen Dreiecke).
- **Kern:** eine geschlossene, dunkle Hülle (Klasse `leaves`, ein deckendes Feld des Atlas) – durch die Krone sieht
  man nie den Himmel. Jedes Dreieck des Kerns ist unverzerrt in sein Atlasfeld gelegt (eine Abwicklung um die
  Hochachse verzog die Blätter zu Streifen).
- **Blatt-Atlas:** 4 × 4 Felder (Büsche 2 × 2), 15 Blattbüschel und der Kern. Ein Büschel ist eine Kuppel: die
  Blätter in der Mitte liegen oben und sind heller, die am Rand dunkler; eiförmige, gesägte (Birke) oder gelappte
  (Eiche) Blätter, 4-fach überabgetastet.
- **Halo-Alpha (mipmap-fest):** Godot baut die Mipmaps mit einem Kastenfilter; ein dünnes Blatt fällt dabei unter
  die Schwelle (0,42), die Krone wird mit der Entfernung licht. Jedes durchsichtige Texel bis 2 Texel neben einem
  Blatt bekommt Alpha 0,28: in voller Größe unsichtbar (auch nach der BC3-Quantisierung: deren Alphastufen sind 1/7
  des Blockumfangs – ein Wert von 0,36 kam als 0,43 heraus), in den gemittelten Texeln der kleineren Stufen hält es
  ein Blatt über der Schwelle, solange es 20 % statt 42 % des Texels deckt. Gemessen (Anteil der Texel über der
  Schwelle je Mipmap-Stufe, Eichenbüschel): 0,443 · 0,460 · 0,478 · 0,489 · 0,535.
- **Stufen ohne Sprung:** gemessen mit `tools/models_prop_scene.sh --mode=lods` (mittlere Farbe und Pixelzahl
  des Baums an der Umschaltentfernung): Eiche lod0/lod1 bei 60 m (60,103,32) / (59,103,31), 11 980 / 12 314 px;
  lod1/Fernbild bei 200 m (67,111,37) / (63,107,35), 1 093 / 1 018 px. Birke lod1/Fernbild (112,154,64) /
  (111,154,67), 342 / 367 px. Dafür sind die Karten von `lod1` um 6 % aufgehellt (`LOD1_LIFT`: durch die größeren
  Karten sieht man mehr vom dunklen Kern), das Fernbild hat den Faktor 1,27 und ein blaues Plus von 25 %
  (`IMPOSTOR_TINT`: beleuchtete Karten spiegeln den Himmel, das Bild nicht).
- **Varianten:** `tree_oak_b`, `tree_birch_b`, `bush_round_b` sind derselbe Generator mit anderem Samen
  (Katalog `variant_of`, Parameter `seed`); sie haben keine eigenen Sets, das Set der Art nennt sie in `variants`.
  Der Requisiten-Builder wählt je Stück eine Variante, eine Drehung und die Größe der Szenerie-Regel.
- **Wind:** Ausschlag nach Höhe (Karten, Kern), Phase und Steifheit je Karte (`leaves.gdshader`); Büsche schwanken
  mit 45 % des Ausschlags. Schnee und Nässe bietet `leaves.gdshader` noch nicht an (Abschnitt „Offen“).

### Büsche und Bodendecker

Büsche (`bush`) bestehen nur aus der Klasse `leaves` (ein Zeichenaufruf, Budget 400 / 120 Dreiecke): Karten auf den
Kugeln des Generators und ein kleiner Kern (ein großer zeigte sich als flache dunkle Scheiben zwischen den Karten).
**Bodendecker** für die Innenseite von Kurven (Nachtrag A-3, höchstens 0,5 m): `props/cover_bush` (Strauch-Polster
1,5 × 1,2 × 0,45 m, aus der Kronenfunktion des Generators) und `props/cover_grass` (Grasbüschel 1,0 × 0,9 ×
0,42 m, sieben Büschel aus je drei gekreuzten Halmkarten). Ihre Sets heißen wie die Modelle und gibt es nur in
Modern: Im Manifest tragen sie `"modern_only": true`, der Prüfer und `test_model_db.gd` erlauben sie ohne
Sprite-Set (nur mit Modell). Der Requisiten-Builder setzt sie anstelle weggelassener Vegetation ein.

### Gebäude mit Tiefe (Bauer `building`, `ce3d/props3d.py`)

- **Öffnungen statt gemalter Fenster:** Der Generator meldet die Fensterraster und Dekore jeder Fassade
  (`props_buildings.WINDOW_LOG`, Voreinstellung `None`: das Sprite merkt nichts). Der Bauer schneidet jedes Fenster
  und jede Tür (ein großes Dekor in Türfarbe, das auf dem Boden steht) mit einer Delaunay-Triangulierung mit
  Zwangskanten in die Wand (`mathutils.geometry.delaunay_2d_cdt`; sie füllt nur gegen den Uhrzeigersinn gegebene
  Umrisse – im Uhrzeigersinn kam eine Wand ohne ein Dreieck zurück). Dazu: Laibung 12 cm tief (gebacken, mit
  Umgebungsverdeckung), Rahmen mit Sprosse und Kämpfer, Sohlbank, Scheibe. Innenflächen (die Rückseite des
  Giebels unter dem Dach) und Wände, die nicht entlang einer Achse stehen (der achteckige Mühlenturm), bleiben
  unberührt.
- **Scheiben leuchten nachts über Kanal 12:** Eine `vpbr`-Lampe zeigt bei Tag die Hälfte ihrer Leuchtfarbe – eine
  helle Leuchtfarbe machte die Fenster tagsüber gelb. Darum ist die Leuchtfarbe ein dunkles Warm (`#7a5e3a`) mit
  hohem Gewicht (0,55–0,9): bei Tag dunkles Glas mit warmem Vorhang, nachts warmes Licht. Welches Fenster leuchtet,
  entscheidet der Anteil `lit` des Rasters (wie die Lichtebene des Sprites), fest je Fenster. Lampen an Wänden
  verlieren die Seite, die in die Wand zeigt: so liegt ihr Lichtanker vorn auf der Lampe und hat eine Richtung
  (mit allen Seiten hoben sich die Normalen auf, der Anker lag mitten im Kasten).
- **Dachrinnen, Fallrohre, Kappen:** halbrunde Rinnen unter den beiden längsten Traufen jedes Dachs, Fallrohre mit
  Knick an die Wand und bis zum Boden; eine Abdeckplatte auf jedem Schornstein. Alles in der Klasse `vpbr`.
- **Umgebungsverdeckung im Atlas:** `bake.bake_atlas(ao=…)` backt mit Cycles die Verdeckung (Atlasgröße, eine
  Bodenplatte darunter) und multipliziert die Farbe mit `floor + (1 − floor) · ao^gamma` (Bauernhaus: 0,42 …
  1, Abstand 1,6 m, Mittel 0,84). Sie wird zuletzt gebacken: Ihr eigener Bildknoten wird in jedem Material aktiv,
  die Nachtlicht-Ebene danach landete sonst im falschen Bild. Ein Nachtlicht-Atlas, in dem nach dem Ausschneiden
  nur noch Krümel leuchten (unter 5 % am hellsten Texel), wird nicht ausgeliefert.
- Zwei Flächen (`baked` + `vpbr`, Budget Landgebäude: 2 Aufrufe), **kein `auto_lod`** (Lampenkanäle). Textur-
  dichte der Straßenseite: 35 px/m (Bauernhaus), 1 024² mit Gewichten nach Sichtbarkeit; `allround` gibt
  Bauernhaus (Rückgiebel) und Tankstellenladen (Seiten, Rückseite) Fenster auf allen Seiten.
- **Straßenmöbel mit einem Atlas** (Zapfsäule, Blitzer, Leitpfosten, Heuballen; Budget ein Zeichenaufruf):
  derselbe Bauer ohne Öffnungen und mit `vpbr_lamps=False` – ihre Lampen bleiben im Nachtlicht-Atlas.
- **Tankstelle:** vier Lampenfelder unter dem Dach (Kanal 12 mit Lichtankern nach unten: Lichtpfützen auf der
  Fahrbahn), der Lichtschleier des Sprites ist ein Sprite-Effekt (Knoten `none`). **Scheune:** Torrahmen und
  Streben als Bretter 5 cm vor der Wand (`boards3d`).

### Rotoren (Windrad, Windmühle)

Die Teile, die sich drehen, tragen im `vpbr`-Format den **Lackcode 0,875** und in `UV2.y` die Nabenhöhe / 128 m
(`props3d.ROTOR_CODE`, `ROTOR_HUB_M`; Windrad 89,6 m, Windmühle 19,8 m). Der heutige `vpbr.gdshader` zeichnet sie
als feste Farbe – ein stehender Rotor. Gedreht werden sie mit einer Erweiterung im `vertex()` des Shaders um die
Z-Achse des Modells durch (0, Nabenhöhe) mit `ce_time` (auf einem Wegwerfzweig erprobt: zehn Zeilen, Bilder bei
0 / 0,4 / 0,8 s drehen sich richtig). Der Prüfer kennt den Code.

### Strommast: das Fachwerk im Ausschneide-Atlas (Bauer `lattice`)

Der Generator meldet sein Gerüst (`props_road.PYLON_LOG`: Ebenen, halbe Breiten, Ausleger, Isolatoren, Spitze).
Statt tausender Balken von 9 cm (bei 100 m 0,6 px breit: sie flimmern und zerfallen) zeichnet der Bauer jede
Turmseite je Abschnitt, Boden und Schrägen jedes Auslegers und die Spitze als Fläche mit eingezeichneten Streben
in einen RGBA-Atlas (Klasse `baked_cutout`, Schwelle 0,5; die vier Seiten eines Abschnitts teilen sich ein Bild).
Isolatorketten sind sechseckige Prismen. 220 Dreiecke, ein Zeichenaufruf – der erste Lauf der Klasse
`baked_cutout` vom Generator bis ins Bild, mit Schatten. Mipmap-fest wie das Laub: Streben mindestens 2,5 Texel,
Halo 3 Texel mit Alpha 0,33. Gemessen (Anteil deckender Texel je Stufe, Stufe 0 = 7,3 %): ohne Halo hält Stufe 4
55 % und Stufe 5 3 %, mit 2 Texeln 74 % / 17 %, mit **3 Texeln 84 % / 26 %**, mit 4 Texeln 106 % / 40 % (aber
Stufe 3 schon 143 %: zu fette Streben auf 50–100 m). Die Streben sind 1,3-mal so breit wie die Balken des
Generators und dunkler: vor hellem Himmel liest sich das Fachwerk bei 250 m noch als Gitter.

### Neue Hooks (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `props_buildings.WINDOW_LOG` | `facade()` | meldet Raster, Dekore, Rahmen, Glas, Anteil `lit` jeder Fassade |
| `boards3d` | `barn()` | Torrahmen und Streben als Bretter vor der Wand |
| `lights3d`, `allround` | `props_road.fuel_station()` | Lampenfelder unter dem Dach; Fenster an Seiten und Rückseite des Ladens |
| Knoten `none` | `fs_haze` (Tankstelle) | der Lichtschleier gehört nur zum Sprite |
| `hub_subdiv` | `wind_turbine()` | Unterteilung der Nabe (Sprite 3, Modell 2) |
| `props_road.PYLON_LOG` | `power_pylon()` | meldet das Gerüst (Ebenen, Breiten, Ausleger, Isolatoren, Spitze) |

`check_sprite_geometry.py --only props/` nach allen Hooks (gemessen): **86 von 86 Sets identisch**, 118 s
(die übrigen Generatoren importieren aus `props_buildings` nur `obj_size`, das unverändert ist).

### Werkzeug: `tools/models_prop_scene.sh`

Modelle neben einer Straße durch die Spielkamera (3,4 m, Brennweite 711 px, Horizont bei 45 %), Tiefennebel wie
im Rennen, die Stufe nach Entfernung wie im Requisiten-Builder: `--mode=dist` (Ausschnitte bei 15/40/100/250 m),
`--mode=lods` (Stufen an den Umschaltentfernungen nebeneinander, mit gemessener mittlerer Farbe und Pixelzahl),
`--mode=road` (ein ganzer Straßenrand). Varianten ohne eigenes Set sind erreichbar.

### Ehrliche Einordnung

- **Bäume:** deutlich feiner als die Sprites (Blätter, Äste, Stamm, Birkenrinde), dunkler und natürlicher; von
  nahem (unter 25 m) wirkt die Krone unruhig, es gibt noch einzelne flach angeschnittene Karten als dunkle Schliere.
  Die Klumpen sind weicher als die scharf schattierten „Blumenkohl“-Kugeln der Cycles-Sprites.
- **Gebäude:** echte Tiefe (Fenster, Tür, Rinnen, Kappen, Verdeckung) – das gemalte Bauernhaus aus Bauabschnitt 0
  ist ersetzt. Scheune und Zollhäuschen haben hinten keine Öffnungen; der Mühlenturm behält gemalte Fenster.
- **Bodendecker:** Gras ist bei 15 m nur 20 px hoch und liest sich als hellgrüner Fleck.

### Offen (für die Shader- und Renderer-Pakete)

- `leaves.gdshader`: Schnee (aufwärts gerichtete Karten weißen mit `ce_snow`) und Nässe (dunkler, glänzender mit
  `ce_wet`); ein Ausblenden flach angeschnittener Karten nach der Kartennormale bräuchte eine zweite Normale.
- `vpbr.gdshader`: die Rotordrehung (siehe oben).
- Requisiten-Builder: Bodendecker-Sets in Kurven-Korridoren einsetzen; Leitungen zwischen Strommasten.
