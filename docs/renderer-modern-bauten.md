# Modus „Modern“ – Bauten an der Strecke: Tankstelle, Grenze, Stadt, Start und Ziel, Blitzer

Bauabschnitt R6 von v0.8.0 (Bauplan `docs/dev/v080_contract.md` §6 Welle 3, Nachträge §11). Fünf Builder zeichnen,
was Arcade neben und über der Straße an festen Bauten zeigt – an Arcades Stellen, in Arcades Maßen und Farben, als
echte Geometrie mit Licht und Schatten. Sie finden sich wie jeder Builder über ihren festen Dateinamen
(`BuilderRegistry`) und reden mit dem Rest nur über die Fassade des Renderers (A-7: `add_lamps()`, `materials`,
`track`, `world`) und `has_method`.

„gemessen“ heißt in diesem Dokument: auf der Build-Maschine (Software-OpenGL llvmpipe unter Xvfb bzw. headless);
alles über echte Grafikkarten und das Steam Deck ist abgeleitet.

## 1. Dateien

| Datei | zeichnet | Arcade-Vorbild (eingefroren) |
|---|---|---|
| `scripts/race3d/builders/station.gd` | Insel, Vorplatz, Dach mit Blenden, Stützen, Leuchtfeldern, Stirnblende mit „TANKSTELLE“, Preissäule; dazu die gemeinsamen Hilfsklassen der fünf Builder (Abschnitt 2) | `RoadRenderer._fuel_structures`, `_fuel_pylon` |
| `scripts/race3d/builders/border.gd` | Dach der Grenzstation über die ganze Straße, Stirnblende mit Europaflagge und Landesname, Pfeiler, Lichtbänder | `RoadRenderer._border_cover` |
| `scripts/race3d/builders/city.gd` | Straßenlaternen der City Limits, Zäune / Hecken / Mauern / Gitter der Stadtlandschaft, Daten der Zebrastreifen | `RoadRenderer._streetlight`, `_fence` |
| `scripts/race3d/builders/gantry.gd` | Start- und Zieltor mit Banner und Countdown-Lampen | `SignPainter._gantry`, `RoadRenderer._start_light_glows` |
| `scripts/race3d/builders/radar.gd` | Blitz der Blitzer | `RoadRenderer._radar_cam` (Blitz) |
| `tests/unit/race3d/test_structures.gd` | Unit-Tests (headless, ohne Szenenbaum) | |
| `tests/race3d/render/check_structures.gd`, `check_structures_licht.gd` | Render-Prüfungen (Xvfb) | |

Zapfsäulen, Tankstellen-Gebäude, Zollhäuschen und die Kamerasäule der Blitzer sind Modelle von AS1b
(`props/fuel_pump`, `props/fuel_station`, `props/customs_booth`, `props/radar_camera`) und stehen über den
Requisiten-Builder (`builders/props.gd`) an Arcades Stellen; ohne Modell zeigt er Arcades Sprite. Die Straßenlaternen
der City Limits sind „object“-Einträge des `Track` – `props.gd` überlässt sie dem Builder `city`, sobald es ihn gibt
(`_skip_objects`).

## 2. Gemeinsame Hilfen (innere Klassen von `station.gd`)

Die anderen vier Builder laden sie mit `preload("res://scripts/race3d/builders/station.gd")`:

- **`Kit`** – Vertex-Arrays im Format `vpbr` (`COLOR` sRGB mit Lackcode 1, `UV` = Rauheit/Metall, `UV2` = Lampenkanal):
  `quad`, `tri`, `box` (in einem starren Rahmen von `ChunkContext.frame()`), `road_box` (folgt der Straße zwischen zwei
  Straßenpositionen), `column` (Prisma).
- **`PanelBuf`** – Tafel-Vierecke mit Atlas-UV (Materialklasse `baked`).
- **`PanelAtlas` / `PanelCanvas`** – der **Schriftatlas der Bauten**: jede Tafel, die ein Builder braucht, wird in
  `prepare()` einmal mit Arcades `SignPainter` (Schildschrift, Farben) in **eine** SubViewport gezeichnet – oben das
  Tagbild, darunter das Nachtbild (was nachts leuchtet, sonst schwarz) –, nach zwei gezeichneten Bildern
  zurückgelesen und als zwei `ImageTexture` mit Mipmaps behalten. Die Ränder jeder Zelle werden in ihren Rand von
  8 Pixeln fortgesetzt, damit ferne Mipmaps keine dunklen Säume ziehen. Während der Fahrt entsteht nichts; headless
  (oder ohne Halter im Baum) gibt es einen Platzhalter mit denselben Zellen. Gezeichnet wird mit dem Shader der Klasse
  `baked` (Tagbild als Albedo, Nachtbild als Emission × `ce_night`) – **kein `Label3D`** mehr.
- `vpbr_node()` / `panel_node()` – Knoten mit dem Material **`ModernMaterials.VPBR_STATIC`** (ohne Instanz-Uniforms:
  der globale Shader-Puffer bleibt den Fahrzeugen, docs/renderer-modern.md §13.8) bzw. dem Tafelmaterial.

## 3. Tankstelle (`station.gd`)

Nach den Bits von `TrackSegment.fuel_zone`, wie `RoadRenderer._fuel_structures`:

| Teil | Maße (Arcade) | in Modern dazu |
|---|---|---|
| Insel (`FUEL_ISLAND`) | 0,18 m hoch, 0,35 … 2,3 m hinter der befestigten Kante (inklusive Tankspur), gelber Bordstein zur Tankspur | gelb gestrichene Bordsteinkante oben; Betonvorplatz bis 5,4 m mit Plattenkante bis in den Boden |
| Dach (`FUEL_CANOPY`) | Unterseite 5,6 m von 0,5 m innerhalb der Kante bis 4,6 m dahinter, dunkler Streifen 0,6 m an der Straßenseite, rotes Band 5,6–5,95, weißes 5,95–6,45 m | Blendenbänder auf beiden Längsseiten und am Ende, mit dunkler Fuge und Metallabdeckung; nachts leicht von innen leuchtend (Lampenkanal 14); Dachfläche |
| Stirnblende (`FUEL_CANOPY_FRONT`) | weiß über rotem Band, „TANKSTELLE“ blau, Versalhöhe 0,32 m | Tafel des Schriftatlas, nachts hinterleuchtet |
| Stützen | eine an der Front, 0,3 m, auf der Insel bei 1,3 m | an Front und Ende jedes Daches, mit Sockel – keine vor einem Schild (`column_plan`, siehe Fairness) |
| Leuchten | zwei je zweitem Segment (1,0 × 0,36 m), nachts mit Schein | Leuchtfelder (Kanal 12), Arcades weißer Schein (1,8 m) über die Ebene `flares` |
| Preissäule (`object` `fuel_pylon`) | Mast 0,36 m bis 6 m, Tafel 2,2 × 3,8 m bei 5,8–9,6 m: blau, roter Kopf 0,7 m, Zapfsäulen-Piktogramm, „1,79“ / „1,85“ | Fundament, Stahlmast, Tafelkasten mit der Tafel auf beiden Seiten; nachts leuchten Ziffern und Piktogramm, Arcades blauer Schein |

**Licht.** Arcade legt alle 18 m einen Lichtkegel von 11 m mit 0,8 × `lights` an den Rand der Tankspur
(`_collect_static_lights`). Modern: je Leuchtenreihe (alle 6 m) ein Kegel von 9 m mit Stärke 0,6 (Ebene `lights`:
0,55 × Stärke in der Mitte), drei überlappen an jeder Stelle der Spur. Die Lampe dieses Kegels sitzt **im Dachkasten**
zwischen Unterseite und Dach: die Ebene `flares` zeichnet zu jeder Lampe mit Kegel Arcades warmen Laternenschein –
im Dach verdeckt ihn der Tiefentest, sichtbar bleiben nur die weißen Scheine der Leuchtfelder (Arcades Farbe).

**Fairness.** Über Fahrbahn und Tankspur liegt nichts unter 5,6 m (Unit-Test über alle Ecken); die Kamera in 3,4 m
sieht unter dem Dach jedes Auto der Spur. Die Stützen stehen auf der Insel (im Bankettstreifen, dort reicht keine
Sichtschneise einer Kurve hin). Die Inselsegmente liegen nur neben der
ganz geöffneten Tankspur (`Track.fuel_lane_factor` = 1, `Track.fuel_lane_at`): ihre Kante ist genau
`Track.road_edges_at().y`, die Spurmitte `Track.fuel_lane_x()` liegt eine halbe Spur davor (Unit-Test).

**Keine Stütze vor einem Schild (F1).** Arcade zeichnet ein Schild, das unter einem Dach steht, im selben Streifen
seiner Malreihenfolge **über** den Pfeiler; in 3D würde die Stütze davor es verdecken. `column_plan()` plant die Stützen
aus den Schildern der Strecke (rechts, aus `Track` bis 120 m hinter dem Dach gelesen, in `collect()`): die vordere
(Arcades) steht auf der Insel, wenn kein Schild unter dem Dach hinter ihrem Sockel steht; die am Ende (nicht in Arcade)
auf der Insel, wenn bis 120 m dahinter kein Schild steht (`SIGN_SCAN_M`; ein Schild weiter hinten könnte sie nur
verdecken, solange es mehrere hundert Meter entfernt ist). Sonst rückt die Stütze **nach außen**, ihre Innenseite
0,25 m jenseits der Außenkante jeder Schildtafel (von der Straße aus kann sie dann keine verdecken), auf den Vorplatz
oder dahinter, mit einem Träger unter der Dachkante; dort (außerhalb des Bankettstreifens) nie in einer Sichtschneise
(F7). Auswertung aller Etappen: unter 39 von 1909 Dächern steht ein Schild, hinter 134 eines in 120 m (meist
Leitpfeile einer Kurve); mit bloßem Weglassen standen 34 Dächer ohne Stütze.

## 4. Grenze (`border.gd`)

Auf den Segmenten mit `cover == "border"` (18 m ab der Grenze), wie `RoadRenderer._border_cover`:
- **Dach** mit Unterseite in 6,0 m über die ganze Straße bis 1,6 m hinter die Bankettkanten, Platte bis 6,8 m, weiße
  Seiten mit blauem Band.
- **Stirnblende** 6,0–7,6 m: weiß, blaues Band unten, Europaflagge 1,2 m vom linken Ende, der Name des Landes
  (`plan.borders` `name_local`, in Großbuchstaben) – eine Tafel des Schriftatlas je Grenze, nachts hinterleuchtet.
- **Pfeiler** 0,55 m (`pillar_plan`): Arcades zwei an der Front 0,6 m außerhalb der Bankette, zwei weitere am Ende des
  Daches – aber keiner vor einem Schild (F1) und keiner außer Arcades vorderen in der Sichtschneise einer Kurve (F7):
  - Steht auf einer Seite ein Schild unter dem Dach hinter dem vorderen Pfeiler, zeichnet Arcade es im selben Streifen
    seiner Malreihenfolge **über** den Pfeiler; in 3D würde der Pfeiler es verdecken (auf DEV „Tankstelle 15 km“ im
    ersten Dachsegment, Bild `v2_border_day` zeigte es halb verdeckt). Dann rückt der Pfeiler **nach außen**: seine
    Innenseite 0,25 m jenseits der Außenkante jeder Schildtafel seiner Seite vom Dach bis 120 m dahinter. Von der Straße
    aus kann ein so stehender Pfeiler keine Tafel verdecken (jede Sichtlinie zu einer Tafel kreuzt seine Ebene näher an
    der Straße). Ein Träger unter der Dachkante (6,0–6,45 m) trägt das Dach zu ihm hinüber.
  - Der Pfeiler am Ende (nicht in Arcade) steht an Arcades Abstand, wenn bis 120 m dahinter kein Schild seiner Seite
    steht, sonst ebenso außen (nach der Grenze steht rechts meist das neue Tempolimit 20 m dahinter).
  - Ein Schild bei 120 m oder weiter hinter einem Pfeiler könnte dieser nur verdecken, solange es mehr als ~350 m
    entfernt ist; ein Schild hinter dem Dachende steht in Arcade in einem anderen Streifen, Arcades vorderer Pfeiler
    verdeckt es dort ebenso.
  Auswertung aller 48 Grenzen der Etappen (gemessen, headless mit dem Builder): 43 Dächer stehen auf beiden Seiten
  (26 auf vier, 16 auf drei Pfeilern), 4 nur auf einer Seite (Grenze in einer Kurve: die Innenseite ist Sichtschneise,
  und Arcades vorderer Pfeiler musste wegen eines Schildes weichen), eines hat kein Dach (Somport: die Grenze liegt im
  Tunnel). Auf DEV (Grenze in einer Rechtskurve, Schilder unter dem Dach auf beiden Seiten) steht das Dach links auf
  einem äußeren Pfeiler vorn und einem am Ende; rechts ist alles Sichtschneise.
- **Lichtbänder** je zweitem Segment, drei quer (25 / 50 / 75 % der Straße), Kanal 12, weißer Schein; **Lichtkegel** wie
  Arcade alle vier Segmente in der Straßenmitte, Radius 16 m, Stärke 1,27 (= 0,7 × `lights` in der Mitte), die Lampe im
  Dach verdeckt.
- Arcade hat **keine Schranke und keine Haltelinie** – Modern auch nicht. Die Zollhäuschen sind Modelle (AS1b).

## 5. Stadt (`city.gd`)

- **Straßenlaternen**: die Einträge des `Track` (alle `road.streetlight_every_m` = 33 m, die Seiten im Wechsel, auf dem
  Gehweg 1,9 m hinter der Fahrbahnkante) als Modell `props/streetlight` (AS1b) in einem MultiMesh je Stück, links
  gespiegelt (D24); ohne Modell Arcades Laterne (Mast 8,5 m, Ausleger 2,2 m). Lampe: Rolle `street`, Kegel 9 m,
  Stärke 1,0 – mit den 0,55 je Einheit der Ebene `lights` genau Arcades 0,55 × `lights` in der Mitte. (Der
  Requisiten-Builder gab den Laternen 0,55, also 0,30 in der Mitte.)
- **Zäune** der Stadtlandschaft (`scenery.fence`: `picket`, `hedge`, `wall`, `iron`; Farbe, Abstand hinter dem Gehweg,
  Höhe, Lücke `gap_m` alle `gap_every_m` – Arcades Einfahrten, dieselbe Phase je Seite): Latten mit Querriegeln und
  spitzem Kopf, Hecke mit gerundeter Krone, Mauer mit Abdeckung und Pfeilern, Gitter mit Sockel, Stäben, Spitzen und
  Pfosten. Arcade zeichnet sie nur bis 240 m; hier gehören sie zum Stück. Stücke im Sichtkorridor einer Kurve fallen
  weg (F7, Unit-Test auf einer engen Stadtkurve).
- **Zebrastreifen-Daten**: die Straßenpositionen, an denen der Fahrbahn-Shader einen Zebrastreifen malt (City Limits,
  alle `road.crosswalk_every_m`, nicht auf Brücken) – Debug-Teil `crosswalks`.
- Schatten: Laternen ab „Schatten: Niedrig“, Zäune erst bei „Hoch“ (kleine Landschaft).

## 6. Start- und Zieltor (`gantry.gd`)

Aus den Schild-Einträgen mit Seite 0 („start“ 14 m nach der Startlinie, „finish“ am Ziel), wie `SignPainter._gantry`:
- Stahlstützen 0,45 m knapp außerhalb der Bankette, 7 m hoch, auf Betonfundamenten mit Fußplatte, Gelenkbändern und
  Kappe;
- das Banner 5,4–7 m, 0,3 m tief; seine Vorderseite ist eine Tafel des Schriftatlas, gezeichnet mit Arcades Aufteilung:
  Ziel rot mit den Schachbrettstreifen oben und unten und dem Text („ZIEL“), Start dunkel mit hellem Streifen und
  „START“ – je Tor eine Tafel in seiner Breite (Schlüssel aus Art, Text und den Bankettkanten, in `prepare()` aus dem
  `Track` berechnet, im Stück aus `ChunkContext.shoulder_edge()` – derselbe Wert, Unit-Test);
- drei Countdown-Lampen in schwarzen Gehäusen mit Schirm an Arcades Stellen (1,4 + i × 1,15 m rechts der Straßenmitte,
  0,8 m unter der Oberkante): rot, eine mehr je Sekunde, alle grün ab „LOS!“ bis 2 s danach, sonst aus
  (`lamp_state()`, Arcades Regel, Unit-Test über die Countdown-Werte); Schein über die Ebene `flares` mit Arcades
  Radius 1,4 m.
Das Auto im Countdown steht, wo Arcade es zeigt (FIX-ZS1, Render-Prüfung `check_start_km0`).

## 7. Blitzer (`radar.gd`)

Die Kamerasäulen sind Modelle (AS1b). Der Builder setzt an jede (dieselben Einträge: Set `props/radar_camera` bzw.
Arcades `radar_cam`) einen Blitz in 2,85 m Höhe vor den Kamerakopf, zur Anfahrt gerichtet. Er folgt
`view.radar_flash01` wie in Arcade (die Sitzung setzt ihn beim Blitz auf 1 und lässt ihn in `radar.flash_s` fallen):
jeder Blitzer im Bild blitzt, weiß, Radius 6 m × Blitz, ab 0,05 (`flash_entry()`, Unit-Test). Stärke: Arcades Schein
fügt Farbe × Blitz hinzu, ein Lichtpunkt der Ebene `flares` Farbe × 0,5 × Stärke – und einer Lampe, die auf dem Bild
größer als 6 px ist, gibt die Ebene nur 35 % (`STATIC_HALO`, dort trägt sonst die leuchtende Lampe selbst). Der Blitz
hat keine leuchtende Geometrie und ist immer so groß: Stärke = 2 / 0,35 × Blitz (die Render-Prüfung `blitz` maß ohne
diesen Ausgleich am Kopf nur +0,17 Leuchtdichte). Der weiße Blitz über den Bildschirm kommt in beiden Modi vom HUD.

## 8. Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_structures.gd` | Tankstelle auf der Tankspur von Kiel – Hamburg (Kante = `Track.road_edges_at`, Spurmitte = `fuel_lane_x`, Bordstein als Ecke des Netzes, Zapfsäulen auf der Insel, nichts unter 5,6 m über Fahrbahn und Spur); Stützen nie vor einem Schild (`column_plan`, gebaute Stücke von Hamburg – Hannover); Grenze der Testetappe (Dach auf jedem Segment, eine Stirnblende „NL“, Pfeiler nie vor einem Schild und außer Arcades vorderen nie in der Sichtschneise, Kegel, nichts unter dem Dach außer Arcades Lichtbändern); `pillar_plan`; Laternen alle 33 m im Wechsel mit Lampen und Kegeln, Zebrastreifen-Daten, Zäune; Zäune nicht im Kurvenkorridor; Tore und Countdown-Regel; Blitz; Atlas-Layout; statisches `vpbr` und Schattenregel der Knoten |
| `tests/race3d/render/check_structures.gd` | `countdown` (Lampen rot/rot/aus, grün, aus), `zieltor` (Banner rot mit Schachbrett), `grenze` (Tag: Blende weiß und europablau; Nacht: Lichtbänder leuchten), `blitz` (um den Kopf im Blitzbild 0,25 mehr Leuchtdichte und 5 % mehr weiße Bildpunkte als im Bild davor) |
| `tests/race3d/render/check_structures_licht.gd` (erbt die Hilfen der ersten Datei; zwei Dateien, damit jede unter `RENDER_CHECK_TIMEOUT` bleibt) | `tankstelle` (Tag: Stirnblende weiß mit blauer Schrift, kein `Label3D`; Nacht: Blende leuchtet, Tankspur unter dem Dach mindestens 0,85 × so hell wie Arcade an derselben Stelle), `stadt` (Kegel einer Laterne mindestens 0,85 × Arcade), `schatten` |
| `tests/race3d/check_minimal_structures.gd` | `station`, `tore`: die Schriftzüge werden über die Debug-Daten (`letterings`) gezählt statt über `Label3D` |

## 9. Offen

- Die AS1b-Modelle von Tankstellengebäude und Zollhäuschen haben ihre Fensterscheiben noch in Lampenkanal 12 (bei Tag
  bräunlich, M2INT); der Umbau auf den Nachtlicht-Atlas des Bauers „house“ gehört zu den Modellen (AS5/AS-Nacharbeit).
- Die Kegel der Bauten leuchten nur, solange die Ebene `lights` sie unter ihren 16 nächsten Lampen führt (an einer langen
  Tankstelle mit vielen Dächern teilen sie sich die Plätze mit nahen Laternen).
