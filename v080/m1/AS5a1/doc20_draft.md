## 20. Stadthäuser german, german_old und hanse (Bauabschnitt 5, AS5a1)

Die elf Stadthaus-Sets der Stilfamilien `german`, `german_old` und `hanse` haben Echtzeit-Modelle – vorher zeichnete
Modern dort das Arcade-Bild als Platzhalter. Reihenfolge nach Häufigkeit auf Kiel–Nürnberg (gezählt: alle
Requisiten der Etappen des Rennens, mit Wiederholungen): Einfamilienhaus 282, Fachwerkzeile 99, Fachwerkhaus mit
Turm 95, Mietshaus 77, Gründerzeithaus 72, Giebelhauszeile 54, Barockhaus 32, Speicher 10, Büroturm 7, Kontorhaus 4,
Hafenkran 3.

TABELLE

Gemessen mit `validate_models.py --report`, dem Export-Bericht und `tools/kritik`-Proben (Software-OpenGL). px/m im
Modellmaß: Der Requisiten-Builder stellt die Häuser mit 0,85–1,2 auf (Büroturm 0,37–0,5: im Spiel hat er 2- bis
2,7-mal so viele Texel je Meter).

### Bauer `city` (`ce3d/cities3d.py`)

Ein eigener Bauer auf dem Gebäudebauer von AS4 (`ce3d/buildings3d.py` wird benutzt, aber nicht geändert – die
Schlüssel der AS4-Modelle bleiben): Öffnungen mit Laibung, Rahmen, Sprossen, Sohlbank und Scheibe, Türen mit Stufen,
Rinnen und Fallrohre, Lochfüller als Scheiben (Tag: das gemalte Glas des Sprites, Nacht: sein Licht × 0,55). Neu:

- **Wände aus `wallmat`.** `props_cities.wallmat` schreibt kein Fensterlog; während ein Modell gebaut wird, wird die
  Funktion umhüllt (wie beim Hausboot in AS4) und ihre Raster, Dekore, Oberflächen und Zonen gehen ins Log. Der
  Generator bleibt das Aussehen: Geometrie, Farben und Lichtentscheidung kommen aus derselben Funktion wie im Sprite.
- **Läden mit Auslage.** Schaufenster (Raster der Art `shop`): Rahmen und Sprossen in der Glasebene knapp hinter der
  Fassade, dahinter auf einer tieferen Fläche (`shop_depth`, 0,3–0,35 m) eine Auslage – Regale mit Waren, eine
  Kleiderstange oder eine Theke mit Regal, je Fenster gewählt. Bei Tag dunkel hinter dem Glas, nachts beleuchtet, wo
  das Sprite dieses Fenster beleuchtet (dieselben Zufallszahlen je Fenster wie `wallmat`) – nie eine weiße Fläche.
  Ein Foyer ohne Auslage (Büroturm: `shop_depth` 0) leuchtet mit eigenem Anteil (`shop_light`, `light_mul`).
- **Fachwerk als Hölzer.** Die Oberflächen der Art `timber` bekommen Ständer, Riegel, Schwelle, Rähm und Streben
  3,5 cm vor der Ausfachung (vpbr, Farbe des Sprites mit etwas Streuung), an den Öffnungen gekappt, nur an Front und
  Straßenseite und nur in lod0: Das gemalte Fachwerk im Atlas bleibt darunter und trägt lod1.
- **Balkone und Geländer.** Die ausgeschnittenen Geländer des Generators (`lace_mat`) bleiben im Atlas, Klasse
  `baked_cutout` – die ersten echten Nutzer: Ihre Karten bekommen 150 Texel je Meter (`cut_ppm`, ein 3-cm-Stab hat
  4,5 Texel) in einem zweiten Packlauf, Halo-Alpha 0,33 gegen Säume in den kleinen Mip-Stufen. Mit `single_cutout`
  liegt alles Gebackene in der Ausschneide-Klasse (zwei Oberflächen je Stufe).
- **Rückwände aus der Straßenwand.** Flächen, die von der Straße weg (+x) oder nach hinten (+y) schauen, bekommen die
  Atlaskoordinaten der gegenüberliegenden Wand aus demselben Material (affine Abbildung je Wandgruppe: dieselben
  Fenster, nachts dieselben Lichter) statt eigener Texel. Wände, die an ein anderes Volumen lehnen, gelten als
  verdeckt; Texel, die nur von innen gesehen werden (die Wand hinter einem Erker, die die Rückwand mitbenutzt), werden
  von einem zweiten Verdeckungslauf (100 m Reichweite) erkannt und nicht abgedunkelt.
- **Geschosse.** `floors` schneidet die Wände in der angegebenen Höhe; Karten darüber bekommen `upper` der Dichte –
  Erdgeschoss und erstes Obergeschoss der Innenstadthäuser mit voller Dichte (≥ 40 px/m).
- **lod1 flach.** Ab der ersten Umschaltentfernung (60 m bei „Details: Mittel“) und für alles dahinter (kein
  Fernbild): die geschnittenen Wände wieder flach (Kopie, koplanare Flächen aufgelöst, dieselben Atlaskoordinaten –
  das gemalte Fenster des Sprites steht im Atlas). Laibungen, Türflügel und Lamellen nur in lod0. Speicher: lod0
  ZAHL, lod1 ZAHL Dreiecke.
- **Licht.** Alles Licht, das im Atlas bleibt (nicht geschnittene Fenster, Gauben, Turmfenster), mit dem Faktor der
  Scheiben (0,55) – sonst leuchtete ein gemaltes Fenster heller als das geschnittene daneben. Lampen werden nur mit
  `lamps` zu vpbr-Lampen mit Lichtankern (Kanal 12): die Wandlampe des Einfamilienhauses, Rotlicht und Strahler des
  Krans, die Flugbefeuerung des Büroturms. Eine unbeleuchtete vpbr-Lampe zeigt die halbe Leuchtfarbe (AS4R) – bei Tag
  leuchtet nichts.
- **Kleinkram.** Hecken und Gartenbäume dezimiert und weich schattiert (`decimate`), Tore breiter als `gate_w` gerippt,
  Stufen vor erhöhten Türen, Schornsteinköpfe des Generators (keine zweite Abdeckung), verdeckte Dachschrägen der
  Giebelprismen entfernt (sie lagen koplanar unter dem Dach: weiße Streifen am Ortgang), `n_arc` für Bögen.

### Hook im Generator (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `close3d` | `props_cities.german_old_fachwerk` (über `timber_house`/`front_gable`) | Rückgiebel der beiden Häuser mit Giebel zur Straße (im Sprite offen, weil man sie nie sieht) |

`check_sprite_geometry.py --only props --jobs 1` nach der Änderung: 86 von 86 Sprite-Sets identisch,
`CHECK sprite_geometry OK`.

### Tönung

Fünf Sets werden auf den Etappen getönt (Einfamilienhaus `#e8b8a4`, Mietshaus `#e0b09c` und `#f6eee2`,
Gründerzeithaus `#f6eedc` und `#ece4d0`). Der Atlas trägt die ungetönten Farben des Sprites; Albedo × Tönung ergibt
dasselbe wie das getönte Sprite (Kontaktbogen in der Lieferung). Der Requisiten-Builder tönt bisher nur Platzhalter –
für die Modelle muss R7 die Tönung als Instanzfarbe auf die gebackene Albedo legen.

### Ehrliche Einordnung

EINORDNUNG
