## 21. Stadthäuser dutch, belgian, french, paris und swiss (Bauabschnitt 5, AS5a2)

Die zwölf Stadthaus-Sets der Stilfamilien `dutch`, `belgian`, `french`, `paris` und `swiss` haben Echtzeit-Modelle
aus demselben Bauer `city` wie Abschnitt 20. Sie stehen in Amsterdam (dutch), Brüssel, Lüttich und Calais (belgian),
Tours und Pau (french), Bordeaux, Lyon, Montpellier und Toulouse (french_south: Immeuble und Südhaus), Paris (paris),
Bern (swiss) und über die Mischstile in Dortmund (ruhr: getönte niederländische Reihenhäuser). Reihenfolge nach
Häufigkeit im ganzen Netz (gezählt: Platzierungen aller Etappen, mit Wiederholungen): Südhaus 588, belgische
Reihenhäuser 315, Loire-Haus 209, Lyoner Stadthaus 202, niederländische Reihenhäuser 130, Maashaus 96, Haussmann-Block
55, Chalet 54, Grachtenhäuser 51, Lauben 46, Grachtenhäuser B 22, Haussmann-Eckhaus 8.

TABELLE

### Was neu ist (Bauer `city`, Hooks im Generator)

- **Straßenflanken mit Öffnungen von Anfang an** (Hook `close3d`). Die Flanke zur Fahrbahn (−x) ist im Sprite ein
  schmaler Streifen und im echten 3D die Wand, die in Augenhöhe vorbeizieht. Grachtenhäuser: die 14 m tiefe Flanke
  des Treppengiebelhauses mit Schiebefenstern auf 3-m-Achsen in allen Geschossen, Seitentür und Gesims; das
  Glockengiebelhaus zeigt über der Traufe des Nachbarn drei Fenster seines obersten Geschosses; die Dachrückseiten
  sind mit Giebeln geschlossen. Grachtenhäuser B: die weiße Flanke des Gesimshauses (14 × 13 m, im Sprite blind) mit
  Fenstern in allen vier Geschossen, Seitentür, das Kranzgesims um die Ecke. Belgische Reihenhäuser: Erdgeschoss der
  Flanke mit zwei Fenstern und Seitentür, Blausteinstürze an allen Flankenfenstern, Dachfenster im Giebel.
  Maashaus: Kreuzstockfenster und Rundbogentür im Blaustein-Erdgeschoss der Flanke. Lyoner Stadthaus: die Bäckerei
  läuft mit zwei Schaufenstern um die Ecke, Haustür im dritten Feld. Niederländische Reihenhäuser: Fenster und
  Seitentür mit Vordach im Erdgeschoss des Endhauses, Dachfenster im Giebel. Lauben: zwei Schaufenster und eine Tür
  im Erdgeschoss der Flanke, Blumenkästen an allen Flankenfenstern.
- **Geländer als wiederholtes Modul** (`rail_module` {Objekt-Präfix: L}). Ein Geländer des Generators wiederholt
  sein Muster alle `pitch` Meter längs der Platte, vom Fuß seines Bandes an. Jedes Geländerobjekt wird bei u = k·L
  geschnitten (L ein Vielfaches des Rasters); eine Fläche, die ein ganzes Modul überspannt, wird gebacken, alle anderen
  bekommen nach dem Packen die Atlaskoordinaten (u − k·L, z) dieses Moduls; Ober-, Unter- und Stirnflächen die Farbe
  des Handlaufs. Ein durchgehender Haussmann-Balkon von 22 m kostete vorher 2 × 22 m × 0,95 m bei 150 Texeln je
  Meter – mehr, als ein 2048×1024-Atlas hält –, jetzt ein Modul je Band. Schräge Platten (die Ecke des Eckhauses)
  behalten eigene Texel.
- **Fenstergitter verdecken keine Fenster** (`openings.cover_skip`). Die französischen Fenstergitter stehen 10–16 cm
  vor dem Glas, innerhalb des Abstands, in dem eine Fläche als Verdeckung gilt (0,3 m): Ihre Fenster blieben gemalt.
- **Baumkronen ohne Löcher im Atlas** (`weights.solid` {Objekt-Präfix: Gewicht}). Die dezimierten Kronen der
  Gartenbäume (Platane, Hortensien, Oleander, Hecken) bekommen ein Gewicht unabhängig von der Blickrichtung und gelten
  nie als verdeckt: Ihre Unterseiten (Gewicht `under` 0,05: weniger als ein Texel) zeigten in Augenhöhe die Farben
  benachbarter Karten als hellgraue Flecken.
- **Abgeschrägte Ecke** (`openings.chamfer`): Fenster und Laden der 45°-Ecke des Haussmann-Eckhauses werden
  geschnitten wie die der Achsenwände (vorher blieben sie gemalt).

### Hook im Generator (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `close3d` (AS5a2) | `props_cities.dutch_canal` (über `_canal_house`: `side`, `close3d`) | Straßenflanke des Treppengiebelhauses mit Schiebefenstern auf 3-m-Achsen, Seitentür und Gurtgesims; drei Fenster des Glockengiebelhauses über der Nachbartraufe; Rückgiebel aller drei Dächer |
| `close3d` (AS5a2) | `props_cities.dutch_canal_b` | Straßenflanke des Gesimshauses mit Fenstern in allen Geschossen, Seitentür, Kranzgesims um die Ecke |
| `close3d` (AS5a2) | `props_cities.dutch_terrace` | Fenster und Seitentür mit Vordach im Erdgeschoss der Endhausflanke, Dachfenster im Giebel |
| `close3d` (AS5a2) | `props_cities.belgian_terrace` | Erdgeschoss der Flanke mit zwei Fenstern und Seitentür, Blausteinstürze und -bänke an den Flankenfenstern, Dachfenster im Giebel |
| `close3d` (AS5a2) | `props_cities.belgian_stone` | Kreuzstockfenster und Rundbogentür im Blaustein-Erdgeschoss der Flanke |
| `close3d` (AS5a2) | `props_cities.french_immeuble` | zwei Schaufenster der Bäckerei und die Haustür im Steinsockel der Flanke |
| `close3d` (AS5a2) | `props_cities.swiss_laube` | zwei Schaufenster und eine Tür im Erdgeschoss der Flanke, Blumenkästen an den Flankenfenstern |

GEOMETRIE

EINORDNUNG
