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
| `tests/race3d/render/check_structures.gd` | Render-Prüfung (Xvfb) | |

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
| Stützen | eine an der Front, 0,3 m, auf der Insel bei 1,3 m | an Front und Ende jedes Daches, mit Sockel |
| Leuchten | zwei je zweitem Segment (1,0 × 0,36 m), nachts mit Schein | Leuchtfelder (Kanal 12), Arcades weißer Schein (1,8 m) über die Ebene `flares` |
| Preissäule (`object` `fuel_pylon`) | Mast 0,36 m bis 6 m, Tafel 2,2 × 3,8 m bei 5,8–9,6 m: blau, roter Kopf 0,7 m, Zapfsäulen-Piktogramm, „1,79“ / „1,85“ | Fundament, Stahlmast, Tafelkasten mit der Tafel auf beiden Seiten; nachts leuchten Ziffern und Piktogramm, Arcades blauer Schein |

**Licht.** Arcade legt alle 18 m einen Lichtkegel von 11 m mit 0,8 × `lights` an den Rand der Tankspur
(`_collect_static_lights`). Modern: je Leuchtenreihe (alle 6 m) ein Kegel von 9 m mit Stärke 0,6 (Ebene `lights`:
0,55 × Stärke in der Mitte), drei überlappen an jeder Stelle der Spur. Die Lampe dieses Kegels sitzt **im Dachkasten**
zwischen Unterseite und Dach: die Ebene `flares` zeichnet zu jeder Lampe mit Kegel Arcades warmen Laternenschein –
im Dach verdeckt ihn der Tiefentest, sichtbar bleiben nur die weißen Scheine der Leuchtfelder (Arcades Farbe).

**Fairness.** Über Fahrbahn und Tankspur liegt nichts unter 5,6 m (Unit-Test über alle Ecken); die Kamera in 3,4 m
sieht unter dem Dach jedes Auto der Spur. Die Stützen stehen auf der Insel. Die Inselsegmente liegen nur neben der
ganz geöffneten Tankspur (`Track.fuel_lane_factor` = 1, `Track.fuel_lane_at`): ihre Kante ist genau
`Track.road_edges_at().y`, die Spurmitte `Track.fuel_lane_x()` liegt eine halbe Spur davor (Unit-Test).

## 4. Grenze (`border.gd`)

Auf den Segmenten mit `cover == "border"` (18 m ab der Grenze), wie `RoadRenderer._border_cover`:
- **Dach** mit Unterseite in 6,0 m über die ganze Straße bis 1,6 m hinter die Bankettkanten, Platte bis 6,8 m, weiße
  Seiten mit blauem Band.
- **Stirnblende** 6,0–7,6 m: weiß, blaues Band unten, Europaflagge 1,2 m vom linken Ende, der Name des Landes
  (`plan.borders` `name_local`, in Großbuchstaben) – eine Tafel des Schriftatlas je Grenze, nachts hinterleuchtet.
- **Pfeiler** 0,55 m, 0,6 m außerhalb der Bankette: Arcades zwei an der Front, zwei weitere am Ende des Daches (nicht im
  Sichtkorridor einer Kurve, F7).
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
jeder Blitzer im Bild blitzt, weiß, Radius 6 m × Blitz, ab 0,05 (`flash_entry()`, Unit-Test). Der weiße Blitz über den
Bildschirm kommt in beiden Modi vom HUD.

## 8. Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_structures.gd` | Tankstelle auf der Tankspur von Kiel – Hamburg (Kante = `Track.road_edges_at`, Spurmitte = `fuel_lane_x`, Bordstein als Ecke des Netzes, Zapfsäulen auf der Insel, nichts unter 5,6 m über Fahrbahn und Spur); Grenze der Testetappe (Dach auf jedem Segment, eine Stirnblende „NL“, Pfeiler, Kegel, nichts unter dem Dach außer Arcades Lichtbändern); Laternen alle 33 m im Wechsel mit Lampen und Kegeln, Zebrastreifen-Daten, Zäune; Zäune nicht im Kurvenkorridor; Tore und Countdown-Regel; Blitz; Atlas-Layout; statisches `vpbr` und Schattenregel der Knoten |
| `tests/race3d/render/check_structures.gd` | `countdown`, `tankstelle` (Tag: Stirnblende weiß mit blauer Schrift, kein `Label3D`; Nacht: Blende leuchtet, Tankspur heller als die Fahrbahn daneben), `zieltor`, `grenze`, `blitz`, `stadt` (Straße bei Nacht nicht dunkler als Arcade), `schatten` |
| `tests/race3d/check_minimal_structures.gd` | `station`, `tore`: die Schriftzüge werden über die Debug-Daten (`letterings`) gezählt statt über `Label3D` |

## 9. Offen

- Die AS1b-Modelle von Tankstellengebäude und Zollhäuschen haben ihre Fensterscheiben noch in Lampenkanal 12 (bei Tag
  bräunlich, M2INT); der Umbau auf den Nachtlicht-Atlas des Bauers „house“ gehört zu den Modellen (AS5/AS-Nacharbeit).
- Die Kegel der Bauten leuchten nur, solange die Ebene `lights` sie unter ihren 16 nächsten Lampen führt (an einer langen
  Tankstelle mit vielen Dächern teilen sie sich die Plätze mit nahen Laternen).
