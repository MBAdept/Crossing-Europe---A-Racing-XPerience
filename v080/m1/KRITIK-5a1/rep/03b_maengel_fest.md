### MFLANKE – Giebelzeile (`city_hanse_gabled`, 54 Platzierungen, Hamburg/Bremen-Innenstadt): die Flanke zur Fahrbahn ist eine leere Ziegelwand

**Wo:** jede Giebelzeile der hanseatischen Innenstädte (Kante 6,7–10 m), beidseits; im Rennen Kiel – Hamburg km 87–95.
**Was:** Der Generator `hanse_gabled` hat nur Fensterraster auf `front` (17 Raster, 0 auf `left`, gezählt in
`props_cities.py`) – die zur Straße gewandte Flanke der ersten Giebelhauses ist eine 16 m tiefe, bis 17 m hohe
Ziegelwand ohne Öffnung, ohne Sockel, ohne Gesims, ohne Fallrohr. Im Sprite ist sie unter −20° nur ein schmaler
Streifen; im echten 3D wächst sie in den letzten 20–30 m vor dem Vorbeifahren zur größten Fläche links oder rechts
im Bild (Bild 30: Spielkamera 10 m voraus; Nahansicht von der Straße bei Tag und 22 Uhr). Nachts ist sie eine dunkle
Platte, wo Arcade im selben Moment beleuchtete Giebelfassaden zeigt (AS5a1-Bild `ab_hamburg_hoch_nacht.jpg` links,
und in diesem Ordner Bild 03). Die Ziegeltextur selbst ist ordentlich (41,9 px/m unten, gemessen) – es fehlt Tiefe.
**Fix (AS5a-N, `props_cities.py` Hook + `cities3d.py`):** wie der Rückgiebel der Fachwerkhäuser (`close3d`): mit
`close3d=True` gibt `gable_house` der Außenflanke der ersten und letzten Hauses ein Fensterraster (`grid("left", …)`)
im Rhythmus der Front (Segmentbogenfenster 1,1 × 1,9 m, Achsen 2,4 m, Geschosshöhen der Front), dazu einen
Sockel aus Granit (0,6 m, 5 cm vorstehend) und zwei Maueranker je Geschoss (vpbr, dunkel); im Sprite bleibt alles
aus (Geometrie-Gate). Alternativ ohne Fenster: Sockel, Gesimsband je Geschoss, Blendnischen wie im Treppengiebel und
ein Fallrohr – billiger, aber nachts bleibt die Wand dunkel. Nachweis: Spielkamera 10 m und Rennbild Hamburg 22 Uhr.

### MERKER – Fachwerk mit Turm (`city_german_old_fachwerk_b`, 95 Platzierungen): Erkerfenster gemalt, Konsole wie weißes Plastik

**Wo:** der Eckerker (Turm) steht auf der Straßenseite – genau das Teil, an dem die Kamera in Würzburg, Nürnberg,
Fulda, München vorbeifährt (Bild 31).
**Was:** Die Fenster des Erkers sind dunkelblaue Rechtecke im Atlas ohne Laibung, Rahmen, Sprossen (nachts gelbe
Flächen ohne Teilung), während die Fenster daneben geschnitten sind und Rahmen und Sprossen haben (angesehen,
12 und 22 Uhr). Die kegelförmige Konsole unter dem Erker ist hellgrau-weiß und glatt verlaufend – sie liest sich
als Kunststofftrichter, nicht als verputzte oder hölzerne Konsole; nachts heller als die Wand (AS5a1 nannte es,
nicht behoben).
**Fix (AS5a-N, `cities3d.py`):** die Erkerfenster wie die Wandfenster durch den Öffnungs-Pfad schicken (der Erker
ist ein Prisma: das Wand-Log muss seine Facetten als Wände führen, oder ein eigener kleiner Schnitt je Facette mit
Rahmen 6 cm und einer Sprosse); Konsole mit der Farbe des Erkerputzes × 0,85 und einem AO-Bake statt glatter
Verlaufsschattierung, `light_mul` 0,35 für ihr Material nachts.

### MGELÄNDER – Geländer (`baked_cutout`) verdichten sich bis ~40 m und lösen sich ab ~75 m auf

**Wo:** Balkone von Mietshaus (77) und Gründerzeithaus (72) – die ersten Nutzer der Klasse `baked_cutout`.
**Was (gemessen, `mipcov.py` von AS5a1 auf den gelieferten Atlanten nachgerechnet):** Deckung des Alpha-Tests gegen
Mip 0: Mietshaus mip1–3 1,11 / 1,20 / 1,40, mip4 **0,29**; Gründerzeit 1,12 / 1,19 / 1,32, mip4 **0,59**. Mit
150 Texeln je Meter (`CUT_PPM`) und 711 px Brennweite liegt Mip k ab etwa 4,7 m × 2^k (gerechnet): Mip 3 ab 38 m,
Mip 4 ab 76 m. Das Geländer wird also zwischen 20 und 60 m dichter und dunkler als bei 10 m und verschwindet ab
etwa 75 m fast ganz – bei 100 m sieht man in Bild 10 statt Gitter einen dünnen schwarzen Strich (angesehen). Kein
Halo, kein Flimmern sichtbar in den Standbildern (angesehen); die Klasse funktioniert, die Mip-Kette nicht.
**Fix:** im Bake der Ausschneide-Inseln eine eigene Mip-Kette mit erhaltener Deckung schreiben (je Mip die
Alpha-Schwelle so wählen, dass der Anteil ≥ 0,5 dem von Mip 0 entspricht – „alpha-to-coverage preserving mips“),
oder für `baked_cutout` die Mips im Import aus (`mipmaps/limit`) und stattdessen ab lod1 das Geländer als
halbtransparentes gemaltes Band im deckenden Atlas (wie das Sprite). Renderer-Variante (R7): Alpha-to-Coverage bei
MSAA. Nachweis: `mipcov.py` 0,9–1,1 für mip1–4.

### MFOYER – Büroturm (`city_german_office`, 7 Platzierungen): Foyer nachts weiße Tafeln, Bürofenster kalt und flach

**Was (angesehen, Bild 21 german):** Das Erdgeschoss leuchtet nachts als Reihe gleichmäßig hellgrauer Tafeln
ohne Inhalt; die beleuchteten Bürofenster sind grauweiße Rechtecke (kein Raum, keine Decke, keine Leuchten) – bei
100–250 m in Ordnung, aus der Nähe nicht. Selten (7×, Maßstab 0,37–0,5, 15–24 m von der Kante).
**Fix:** Foyer wie die Schaufenster der anderen Häuser behandeln (`shop_depth` mit „Theke“, Lichtkegel an der
Decke, `shop_light` 0,35), Bürofenster mit dem Display-Weg (Deckenband hell, untere Hälfte dunkler).

### MGARTEN – Einfamilienhaus (`city_german_house`, 282 Platzierungen – das häufigste Stadtmodell)

**Was (gemessen + angesehen):** lod1 hat 2 526 von 2 962 Dreiecken (85 %) – Hecken und Gartenbaum bleiben
voll; aus der Nähe sind Hecken und Baum klumpige facettierte Kugeln (Bild 20 german, „schräg“), so wie im
Generator. Die Garagenfront zur anfahrenden Kamera hat 16 px/m (5 m², gemessen). Bei 30–100 m dem Sprite gleich bis
leicht feiner.
**Fix:** in lod1 Hecken als zwei Boxen mit gebackener Seite, Baum als zwei gekreuzte Karten (oder das AS3-Baummodell
`props/tree_*` an den Gartenbaum-Anker) – Ziel lod1 ≤ 900 Dreiecke; Garagenfront in den Straßenwand-Chart nehmen.
