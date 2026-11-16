**Was der Spieler jetzt sieht** (Bilder dieses Ordners; Wirkung auf einen Menschen gefolgert):

- **In den Altstädten (Würzburg, Nürnberg, Fulda, München) und in Hamburgs und Bremens Innenstadt** zieht an der
  Straße keine fensterlose Wand mehr vorbei. Wo vorher der Sandstein-, Ziegel- oder Rustikasockel blind war, stehen
  Fenster mit Gewände, Rahmen und Sprossen und Türen mit Stufe; das Fachwerkhaus mit Turm hat an der Flanke dieselben
  Fensterreihen wie vorn, die Giebelzeile ihre Segmentbogenfenster über drei Geschosse, mit Granitsockel und
  Mauerankern. Nachts leuchten diese Fenster unregelmäßig und warm wie die Front – die Giebelzeilen-Flanke ist keine
  dunkle Platte mehr (`flanken_vorher_nachher_nacht.jpg`, Prüfstraße `pruefstrasse_*_vorher_nachher_*.jpg`).
- **Der Erker** des Turmhauses (95 Platzierungen) liest sich als Erker mit Fenstern: Futter, Sprossen, Sohlbank, nachts
  Licht hinter Sprossen statt gelber Felder; die Konsole ist Stein, kein weißer Kegel.
- **Balkone** von Mietshaus und Gründerzeithaus: Das Geländer verschwindet ab 75 m nicht mehr und wird bis 40 m nicht
  mehr dunkler, es wird in der Ferne zu einem Band mit gleicher Helligkeit (`gelaender_*.jpg`).
- **Stufenwechsel**: nachts kleinerer Helligkeitssprung (Fachwerkzeile +9 → +5 %), sonst wie vorher.

**Was noch nicht gut ist** (gemessen, wo eine Zahl steht):

1. **Flimmern der Fachwerkhölzer** in Bewegung: 1,2–1,5 % der Pixel je Viertelpixel-Schritt bei 40–60 m gegen 0,1–0,3 %
   beim Sprite – unverändert. Mein Versuch (Hölzer schmaler als das gemalte Holz) hat nichts gebracht. Ohne Hölzer als
   Geometrie wäre es so ruhig wie lod1 (0,6 %), aber die Tiefe aus der Nähe wäre weg; die richtige Lösung ist eine
   kürzere lod0-Entfernung je Modell (~35 m) oder Überblenden im Renderer.
2. **Stufenwechsel bei 60 m** ändert weiter 13–27 % der Pixel (Fachwerkzeile, Kontor am meisten). Ohne Überblenden (R7)
   bleibt er für einen aufmerksamen Spieler an freistehenden Häusern sichtbar (gefolgert).
3. **Einfamilienhaus**: Die leichtere Gartenstufe (1 406 statt 2 526 Dreiecke) ändert beim Wechsel mehr Pixel als vorher
   (17,2 statt 11,1 %), weil die Hecken anders facettiert sind – in den Bildern bei 60 m nicht zu unterscheiden
   (angesehen), aber gemessen schlechter.
4. **Neue Flanken sind im Sprite nicht da**: Sie sind „im Stil des Generators“ ergänzt (dieselben Rasterfunktionen,
   Fenstertypen und Farben wie die Front), aber kein Bestandteil des Sprites – siehe Vertragsfrage.
5. Unverändert aus AS5a1: Büroturm-Foyer nachts flach, Kontor oben 24 px/m bei Maßstab 1,2, Tönung erst mit R7, die
   Konsole des Erkers bleibt ein glatter Kegel (nur in Stein).

**Was fehlt:** Messungen auf echter Grafikkarte (MSAA dort mildert das Flimmern – gefolgert) und auf dem Steam Deck; ein
Rennclip (Zeit: Prüfstraßen-Bilder bei 50 km/h stehen dafür); die zweite Hälfte der Stilfamilien (AS5a2/AS5b).
