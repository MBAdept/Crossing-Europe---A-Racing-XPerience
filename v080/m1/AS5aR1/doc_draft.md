### Nacharbeit nach der Kunstkritik (AS5aR1)

Die unabhängige Kunstkritik von AS5a1 fand die Häuser feiner als die Arcade-Bilder, aber in den Altstädten blinde
Straßenflanken, gemalte Erkerfenster, Geländer, die ab etwa 75 m verschwinden, einen deutlichen Stufenwechsel der
Fachwerkhäuser und Flimmern der Hölzer. Die Nacharbeit (alles im Bauer `city` und in Hooks des Generators, das Sprite
bleibt unverändert):

- **Straßenflanken mit Öffnungen** (Hook `close3d`, siehe Tabelle unten). Im Sprite (Blick −20°) ist die Flanke zur
  Fahrbahn ein schmaler Streifen; im echten 3D ist sie die größte Wand, die in Augenhöhe vorbeizieht. Fachwerkzeile:
  Erdgeschoss der Straßenflanke mit drei Fenstern und einer Rundbogentür im Sandstein. Fachwerkhaus mit Turm: die ganze
  Flanke wie die Front – Segmentbogenfenster und Rundbogentür im Sandstein, in den Fachwerkgeschossen jedes zweite Feld
  ein Fenster, drei Fenster im unteren und eines im oberen Giebelgeschoss. Barockhaus: Rundbogenfenster in der Rustika
  auf den Achsen der Obergeschosse, Rundbogentür in der Mitte. Giebelzeile: die 16 m tiefe Flanke des Treppengiebelhauses
  mit den Segmentbogenfenstern der Front auf 2,4-m-Achsen in jedem Geschoss, Seitentür, Granitsockel (0,6 m) und
  Mauerankern an den Balkenlagen. Nachts leuchten die neuen Fenster nach denselben Zufallszahlen wie die Front.
- **Erker mit echten Fenstern.** Die Glaskästen des Eckerkers (`props_cities.turret`) werden Fenster: Glas knapp vor
  der Facette, ein Futter in Rahmenfarbe 10 cm vor der Facette (seine Innenseiten sind die Laibung), ein senkrechter
  und ein waagrechter Sprossenstab, eine Sohlbank (vpbr, nur lod0). Die Konsole des Erkers bekommt eine eigene
  gebackene Farbe (roter Sandstein, `corbel`) statt der Ausfachung – vorher eine glatte weiße Kegelfläche.
- **Rahmenring im gemalten Glas** (`wallmat`-Hook `inner_frame`). Jedes Fenster der Art `win` trägt im Atlas innen
  einen unbeleuchteten Ring in Rahmenfarbe, so breit wie der Rahmen des geschnittenen Fensters (`FRAME_W` 6 cm): in
  lod0 liegt der echte Rahmen genau darüber, die flache lod1 zeigt damit dieselbe Licht- und Glasfläche wie lod0.
- **Hölzer schmaler als das gemalte Fachwerk** (`timber.inset` 3 cm je Seite). Die Kanten der Hölzer liegen auf dem
  gemalten Holz statt auf der weißen Ausfachung: Wo sie in Bewegung um einen Pixel springen, wechselt der Pixel von
  Holz zu Holz; beim Wechsel zu lod1 bleibt die dunkle Fläche die des gemalten Fachwerks.
- **Geländer, die in den kleinen Mip-Stufen nicht verschwinden** (`cut_fill`). Die Engine erzeugt die Mip-Stufen des
  BC3-Atlas mit einem Kastenfilter; ein Geländer aus 3-cm-Stäben alle 13–14 cm (ein Fünftel bis ein Viertel deckend)
  fiel ab Mip 4 durch den Alpha-Test und wurde in Mip 1–3 dichter. Jetzt tragen die Lücken in den Ausschneide-Karten
  Alpha 0,4 (unter der Schwelle 0,5: in Mip 0 unverändert) und die Farbe dessen, was hinter dem Geländer liegt. Im
  Mittel einer kleinen Mip-Stufe steigt Alpha über die Schwelle, und der Texel trägt die Mischfarbe aus Stäben und
  Hintergrund: Das Geländer wird zu einem Band mit der mittleren Helligkeit, wie ein Geländer aus Stäben unter einem
  Pixel aussieht – statt zu verschwinden.
- **Gartenstufe des Einfamilienhauses** (`lod1_decimate`): lod1-Kopien von Hecken und Gartenbaum nach dem Packen noch
  einmal dezimiert (dieselben Atlaskoordinaten).
