# Sprites – Blender-Pipeline

Alle Fahrzeug-, Requisiten- und UI-Grafiken werden **prozedural in Blender 5.2** (Python-Modul `bpy`)
modelliert und mit **Cycles** gerendert. Ergebnis sind die Sprite-Sheets unter `assets/sprites/` und das
Manifest `assets/sprites/manifest.json` im Format von [ARCHITECTURE.md §12](../ARCHITECTURE.md), erweitert
um den Vertrag [Fahrzeugdarstellung v2](fahrzeug-darstellung.md) (Raster-Sheets, `yaw_deg`, `pivot`,
perspektivische Spieler-Sprites, Lkw/Busse als texturierte Quader).
Kein Modell wird von Hand gebaut oder importiert – alles ist Code und damit reproduzierbar.

## Aufruf

```bash
# alles rendern (vom Projektverzeichnis aus)
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py
# nur einzelne Sets (Präfixe, kommagetrennt), schnelle Vorschau mit wenigen Samples
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py --only player/kompakt,traffic/truck_ --quick --out /tmp/vorschau
# Liste aller Sets
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py --list

# prüfen und ansehen (nur Pillow + numpy nötig)
python3 tools/blender/validate_manifest.py
python3 tools/blender/contact_sheet.py --out build/sprite_review [--only player/] [--every 2]
```

| Option | Wirkung |
|---|---|
| `--only P1,P2` | nur Sets, deren ID mit einem der Präfixe beginnt; das Manifest wird zusammengeführt |
| `--quick` | 8 statt der vollen Samples (Vorschau); eigener Cache-Schlüssel |
| `--force` | Render-Cache der gewählten Sets ignorieren |
| `--out DIR` | Ausgabeverzeichnis (Standard `assets/sprites`) |

Cycles rendert auf der CPU mit **3 Threads** (Umgebungsvariable `CE_THREADS`, `threads_mode = FIXED`).
Base-Ebene 40 Samples + OpenImageDenoise (Spielerautos 56, Showroom 160, Lkw/Bus-Flächen 32),
Licht-Ebenen 12 Samples (Spielerautos 24) ohne Bounces. Jedes Rendering landet im Cache
`tools/blender/_cache/` (git-ignoriert); der Schlüssel enthält Geometrie-Parameter, Kamera, Farbe (nur
Base) und einen Hash des Builder-Codes. Farbvarianten teilen sich deshalb Schatten- und Licht-Renderings,
und ein erneuter Lauf rendert nur, was sich geändert hat. Das Zusammensetzen der Sheets (Pillow) läuft
immer. Das Manifest wird nach jedem Set geschrieben (lange Läufe lassen sich unterbrechen und fortsetzen).

## Drei Darstellungsarten (Vertrag v2)

| Gruppe | Darstellung | Winkel | Drehpunkt | Auflösung |
|---|---|---|---|---|
| `player/*` | `projection: "perspective"` – mit der Spielkamera gerendert | 21: −20° … +20° in 2°-Schritten | `pivot: "center"` | `supersample` ≤ 2,0 (je Auto 1,65–1,9, siehe unten) |
| `traffic/<pkw>_*`, `police/*` | `projection: "ortho"` | 17: −24° … +24° in 3°-Schritten | `pivot: "rear"` | 52 px/m (Polizei 56), Kamera 9° geneigt |
| `traffic/truck_*`, `traffic/bus_*` | `render: "box"` – Flächenbilder texturierter Quader | – | – | Heck 100 px/m, Seiten/Dach 80 px/m |
| `showroom/*`, `props/*`, `ui/*` | ein Bild (wie bisher) | `c` | – | Showroom 768×480 |

### Raster-Sheets

Ein PNG je Set; alle Zellen gleich groß. Zellindex `i = ebene * len(angles) + winkel`, Spalte
`i % grid_cols`, Zeile `i / grid_cols`. `grid_cols` wird so gewählt, dass das Sheet höchstens 4096 px je
Seite misst und möglichst quadratisch ist (Pkw 4–5 Spalten, Polizei 6–7, Spieler 6–7). Sets mit nur einem
Winkel (Requisiten, UI, Showroom) haben kein `grid_cols` (bisheriges Layout: eine Zeile je Ebene).
`yaw_deg` ist eine Liste mit einem Gierwinkel je Eintrag von `angles` (gleiche Reihenfolge, + = nach
rechts gedreht, rechte Flanke sichtbar). Winkelnamen: `l24 … l3, c, r3 … r24` bzw. `l20 … l2, c, r2 … r20`.

### Pkw im Verkehr und Polizei (`ortho`, `pivot: "rear"`)

- **Orthografische Kamera**, `ortho_scale = image_width_m`, Sensor-Fit horizontal → Pixel pro Meter =
  `cell.x / image_width_m` exakt. Die Modelle sind in echten Metern gebaut.
- **Anker** = Heckmitte am Boden (Heckstoßstange, z = 0); die Fahrzeuge drehen sich **um diesen Punkt**,
  der Anker gilt damit für alle 17 Zellen. Die Zellen sind breiter als das Auto (Platz für die bei ±24°
  ausschwenkende Front).
- Die Karosserien (Unterteil, Glashaus, Stoßfänger) haben eine Unterteilungsstufe (Subdivision Surface)
  und harte Kanten nur noch an echten Kanten (> 70°) – deutlich weicher als zuvor.
- `extent_m`, `elevation_deg` wie bisher; neu `projection`, `pivot`, `grid_cols`, `yaw_deg` (Liste).

### Spielerautos (`perspective`, `pivot: "center"`)

- Gerendert **mit der Spielkamera** aus `config/game_config.json` (`render.*`): Kamera
  `camera_distance_m` (9,0 m) hinter und `camera_height_m` (3,4 m) über der Fahrzeugmitte, waagrechter
  Blick, horizontales Sichtfeld `fov_deg` (84°) über 1280 px → Brennweite 710,8 px, Horizont bei
  `horizon_y_frac` (0,45). Die Werte stehen im Manifest unter `camera`; wird die Kamera in der Konfiguration
  geändert, müssen die Spieler-Sprites neu gerendert werden (der Validator meldet die Abweichung).
- Die **Zelle** ist genau der Bildschirmausschnitt (Spielpixel) um das Auto über alle 21 Winkel samt
  Schatten (+ 4 px Rand), per Objektiv-Shift (`shift_x/shift_y` in Einheiten der Bildbreite) eingestellt
  und `supersample`-fach größer gerendert.
- **Supersampling**: angestrebt 2,0. Mit ±20° um die Mitte schwenkt das Heck so weit aus, dass ein langes
  Auto 330–345 Spielpixel breit und 200–220 hoch wird; 63 Zellen (21 Winkel × 3 Ebenen) bei 2,0 bräuchten
  18–20 Mpx, ein Sheet mit höchstens 4096 × 4096 px fasst 16,8 Mpx. Deshalb wählt die Pipeline je Auto den
  größten Faktor ≤ 2,0 (in 0,05-Schritten), bei dem alle Zellen in ein Raster ≤ 4096 px passen
  (Zellen Vielfache von 4 px, Bildschirmrechteck = Zelle / Faktor). Der tatsächliche Wert steht im
  Manifest (`supersample`); der Renderer skaliert mit `distance_m / Tiefe / supersample`.
- **Anker** = projizierter Bodenpunkt der Fahrzeugmitte (für alle Winkel gleich). Der Renderer zeichnet die
  Zelle mit dem Anker auf dem projizierten Bodenpunkt, Maßstab `distance_m / Tiefe / supersample`.
  `image_width_m` = Breite der Zelle in Metern in der Ebene der Fahrzeugmitte (= `cell.x · distance_m /
  (Brennweite · supersample)`), damit bleibt `cell.x / image_width_m` als Pixel pro Meter in Fahrzeugmitte
  gültig.
- Empfehlung an den Renderer: Textur mit Mipmaps filtern (Sprite wird um 1/`supersample` verkleinert).

### Lkw und Busse (`render: "box"`)

Kein gedrehtes Sprite, sondern Bilder der Quaderflächen (Vertrag §4):

| Set | Teile (Meter relativ zur Fahrzeugmitte; z längs, + vorn) | Flächen |
|---|---|---|
| `traffic/truck_*` (16,5 m) | `trailer` z −8,25 … 5,35, x ±1,275, y 0 … 4,0 · `cab` z 5,75 … 8,25, x ±1,25, y 0 … 3,8 | `rear`, `left`, `right`, `top` je Teil |
| `traffic/bus_*` (12,8 m) | `body` z −6,4 … 6,4, x ±1,275, y 0 … 3,65 | `rear`, `left`, `right`, `top` |

- Jede Fläche wird **orthografisch genau von vorn** (von außen) gerendert; das Bild deckt exakt das
  Flächenrechteck ab (alle Maße sind Vielfache von 5 cm → ganzzahlige Pixel: Heck 100 px/m, Seiten und Dach
  80 px/m). Ausrichtung wie im Vertrag: `rear` u: x0 → x1, `left` vorn links im Bild, `right` vorn rechts,
  `top` vorn oben; v jeweils oben → unten.
- Sichtbar ist alles, was von außen im Rechteck liegt: Räder, Fahrgestell, Unterfahrschutz, Kotflügel …;
  wo kein Fahrzeug ist (zwischen den Achsen, um das Fahrerhaus, Deflektor-Umriss) ist das Bild transparent.
  Für die Flächen des Fahrerhauses wird der Auflieger ausgeblendet; die Zugmaschinen-Hinterachse und
  Tanks unter dem Aufliegerbug gehören zu den Aufliegerflächen.
- Beleuchtung fest zur Welt (nicht zur Kamera): Himmel + Sonne von oben, leicht von hinten – für alle
  Flächen gleich, linke und rechte Seite gleich hell.
- **Lichtüberlagerungen** (`lights`): `tail` = Heckleuchten, Konturmarkierung und Kennzeichenlicht der
  Heckfläche sowie die gelben Seitenmarkierungsleuchten auf `left`/`right`; `brake` = Bremsleuchten
  (+ dritte Bremsleuchte beim Bus) der Heckfläche. Gleiche Größe und Ausrichtung wie die Fläche.
- Alle Bilder werden in ein Sheet gepackt (Regalpackung, Rechtecke auf 4-px-Raster); jedes Rechteck ist von
  4 px wiederholten Randpixeln umgeben, damit bilineare Filterung und Mipmaps keine Nähte erzeugen. Die
  `rect`-Angaben im Manifest schließen diesen Rand aus.

## Die Spielerautos

Fünf neue Modelle (`tools/blender/cesprites/player_cars.py`), Länge und Breite exakt aus
`vehicles.types`:

| Set | Typ | Farbe | Erkennungsmerkmale (Heck) |
|---|---|---|---|
| `player/kompakt` (4,10 × 1,78 m) | Kompakt-Sportler (Hot Hatch) | Gelb, schwarzes Glanzdach | Dachspoiler mit dritter Bremsleuchte, keilförmige Leuchten mit LED-Haken, schwarzes Band mit Emblem, Diffusor mit Finnen, zwei runde Endrohre in der Mitte, Heckwischer, rote Bremssättel |
| `player/kombi` (4,80 × 1,85 m) | Kombi | Dunkelgrün metallic | Dachreling, L-förmige Leuchten an den D-Säulen, Chromleiste, Kennzeichen in der Heckklappe, trapezförmige Endrohre, Diffusor mit Alu-Lippe, Heckwischer |
| `player/limousine` (4,85 × 1,86 m) | Stufenheck-Limousine | Blau metallic | durchgehendes LED-Leuchtband, Abrisslippe, Chromleisten, Kennzeichen im Kofferraumdeckel, integrierte Endrohre |
| `player/sportwagen` (4,45 × 1,90 m) | Fastback-Coupé | Rot | Carbon-Heckflügel auf Schwanenhals-Stützen, je zwei runde Ringleuchten, Wabengitter, Carbon-Diffusor, vier Endrohre, breite Hüften, gelbe Bremssättel |
| `player/gran_turismo` (4,95 × 1,95 m) | Gran Turismo mit langer Haube | Silber metallic | Entenbürzel, schmales Leuchtband über die ganze Breite, Chromlinie, Schriftzug, vier ovale Endrohre, Kiemen hinter den Vorderrädern, Turbinenfelgen |

**Aufbau** (`carbody.SmoothCar` + `cardetail`):

- Die Karosserie ist ein dichter Loft aus analytischen Querschnitten; alle Kennlinien sind glatte,
  monotone Splines (`curves.Profile`, PCHIP): Grundriss (Breite inkl. ausgestellter Kotflügel/Hüften),
  Seitenlinie (Kofferraum, Gürtellinie, Motorhaube), Schulter-Charakterlinie (als harte Kante zwischen
  glatt schattierten Flächen), eingezogener Schweller, gerundete Enden (Superellipsen), Radläufe mit
  ausgestellter Lippe. Darüber das Glashaus (Dachlinie inkl. Front- und Heckscheibe, Tumblehome, gewölbte
  Seitenscheiben, gerundete Dachkante) und Stoßfänger, die einige Zentimeter vorstehen (Ladekante).
- **Konforme Details**: Scheiben, Leuchten, Kennzeichenmulden, Gitter, Fugen, Schriftzüge, Diffusoren usw.
  sind 2-D-Umrisse, fein trianguliert (`delaunay_2d_cdt`) und per BVH-Strahl auf die Karosserie projiziert,
  leicht angehoben, bei Bedarf mit Seitenwänden – sie folgen jeder Wölbung und sind in jeder Größe scharf.
- **Leuchten**: helles Gehäuse, Innenleben (glimmende Leuchtenfläche, satinierte Reflektoren,
  Bremssegmente, LED-Lichtleiter als feine Streifen, Rückfahr-/Nebelleuchte) unter einer erhabenen,
  getönten Streuscheibe (`materials.lens`: transparenter Farbfilter + Reflexion + etwas Streuung). In den
  Lichtebenen ist die Streuscheibe vollständig transparent, das Innenleben leuchtet durch. Dritte
  Bremsleuchte und beleuchtetes Kennzeichen wie bisher.
- **Materialien**: Lack mit Klarlack (`materials.paint`), Glas mit starker Fresnel-Spiegelung
  (`materials.glass_mat`), Chrom, Satin-Alu, Glanzschwarz, Carbon, Kunststoff, Gitter-Shader (Waben/Lamellen
  im Objektraum).
- **Räder**: Reifen mit Flanke, Schulter und Längsrillen, Felgen mit Bett, polierter Lippe, plastischen
  Speichen (gerade, Doppelspeiche, Y, Turbine) mit Schüsselung, Radmuttern, Bremsscheibe und farbigem Sattel;
  im Showroom sind die Vorderräder eingeschlagen.
- Außenspiegel mit Arm, Spiegelglas und Blinker, Türgriffe, Tankdeckel, Seitenschweller, Kennzeichen mit
  Schrift (Inter), Embleme (fiktives „CE“-Oval) und Modellschriftzüge.

**Showroom** (`showroom/<id>`): 3/4-Ansicht von vorn, perspektivisch, 768×480, Anker = Bodenpunkt unter
der Fahrzeugmitte; Scheinwerfer mit Projektorlinsen und Tagfahrlicht-Leiste, Kühlergrill, Lufteinlässe,
Frontkennzeichen.

## Beleuchtung und Materialien

- Sonne von **links oben, leicht von der Kameraseite** (fest relativ zur Kamera, für alle Winkel gleich),
  weicher Himmel (Gradient-Welt, liefert auch die Spiegelungen auf Lack und Glas), Standard-View-Transform.
  Ausnahme Lkw/Bus-Flächen: Licht fest zur Welt (siehe oben).
- Jedes Material enthält die gemeinsame Node-Gruppe `CE_PASS`; ein Pass ändert nur deren Werte
  (Base-BSDF ↔ Emission der jeweiligen Ebene).
- **Ebenen**: `base` = Tageslicht, Lichter aus, mit weichem Bodenschatten (eigener Schattenpass, darunter
  komponiert; bei Lkw/Bus-Flächen kein Schatten). `tail`, `brake`, `beacon_a`, `beacon_b`, `lights` = reine
  Emissionsrenderings: alles Nicht-Leuchtende ist schwarz (verdeckt korrekt), danach Alpha = Helligkeit,
  Farbe normiert, plus Bloom. Emissionswerte bleiben ≤ 1 (kein Clipping), die Helligkeit kommt aus einem
  Verstärkungsfaktor im Post-Processing (`light_gain`). Transparente Streuscheiben brauchen in den
  Licht-Pässen transparente Bounces (8).
- Verkehrs-/Polizeiautos: Details als Shader-Decals im Objektraum (wie bisher).
- Alle Zellen haben einen **transparenten Rand** (Schatten/Glühen werden an den Zellrändern weich
  ausgeblendet). Lkw/Bus-Flächen dagegen reichen bis an den Rand (genau das Flächenrechteck).

## Inhalt

| Gruppe | Sets | Zelle / Auflösung |
|---|---|---|
| Spieler | `player/kompakt`, `kombi`, `limousine`, `sportwagen`, `gran_turismo` – base/tail/brake, 21 Winkel | perspektivisch, Supersampling 1,65–1,9 |
| Showroom | `showroom/<typ>`: 3/4-Ansicht von vorn, 768×480, base | – |
| Verkehr | `traffic/<modell>_<farbe>`: hatch (5 Farben), sedan (4), wagon (4), suv (4), van (4), sports (5) – 17 Winkel; truck (4, Sattelzug 16,5 m), bus (3, Reisebus 12,8 m) als Quader | Pkw 52 px/m (9°); Lkw/Bus 100/80 px/m |
| Polizei | `police/<land>` – 17 Länder, landestypische Farben, Wort auf Flanken und Heck, Blaulichtbalken (beacon_a = linke, beacon_b = rechte Hälfte), 17 Winkel | 56 px/m, 9° |
| Requisiten | `props/<name>` (36 Stück, siehe unten); `lights` bei Gebäuden, Laternen, Leitpfosten, Tankstelle, Windrad (Flugfeuer) … | Bäume 256–384 px hoch, Gebäude bis 512 |
| UI | `ui/weather_normal`, `_rain`, `_snow`, `ui/daytime_day`, `_night`, `_dawn`, `_dusk` – 96×96, dunkle Kontur | – |

Polizei (keine echten Wappen/Logos, generische Lackierungen):

| Land | Wort | Basis | Livery |
|---|---|---|---|
| de | POLIZEI | Kombi | silber, blaues Band |
| nl | POLITIE | Schrägheck | weiß, blau + orange Streifen |
| be | POLICE | Kombi | weiß, blau/gelbes Karomuster |
| fr | POLICE | Schrägheck | unten dunkelblau, oben weiß |
| es | POLICÍA | Limousine | weiß, blaues Band |
| ch | POLIZEI | Kombi | weiß, orange/gelbes Karomuster |
| it | POLIZIA | Limousine | blau, weißes Band + rote Linie |
| si | POLICIJA | Kombi | weiß, blaues Band + grüne Linie |
| hr | POLICIJA | Limousine | unten blau, oben weiß |
| rs | ПОЛИЦИЈА | Limousine | weiß, blaues Band |
| bg | ПОЛИЦИЯ | Schrägheck | weiß, blaues Band + rote Linie |
| hu | RENDŐRSÉG | Limousine | weiß, blaues Band + gelbe Linie |
| at | POLIZEI | SUV | weiß, blaues Band + rote Linie |
| cz | POLICIE | Kombi | hellgrau, blaues Band + gelber Streifen |
| pl | POLICJA | Limousine | unten dunkelblau, oben weiß |
| lt | POLICIJA | SUV | hellgrau, blau/gelbgrünes Karomuster |
| lv | POLICIJA | Schrägheck | weiß, dunkelblau/gelbes Karomuster |

Requisiten: Bäume `tree_oak, tree_beech, tree_birch, tree_pine, tree_spruce, tree_poplar, tree_cypress,
tree_olive, tree_palm`; `bush_round, bush_low, heather, rock_a, rock_b, cliff, haybale`; Gebäude `farmhouse,
barn, church, windmill` (holländische Windmühle), `factory, house_med, building_block_a, building_block_b,
building_tall, building_oldtown, building_shop`; Infrastruktur `wind_turbine, power_pylon, streetlight,
delineator` (deutscher Leitpfosten mit Rückstrahler), `fuel_station` (Dach + Zapfsäulen + Shop + Preismast),
`fuel_pump` (Zapfinsel mit Lampenmast), `radar_camera` (Blitzersäule), `customs_booth`, `ferry_ship`
(große Seitenansicht, Bug rechts, Anker = Wasserlinie Mitte). Requisiten und UI wurden in v2 nicht neu
gerendert (unveränderte Sheets).

## Neues Modell hinzufügen

- **Spielerauto**: Entwurf in `player_cars.py` (`DESIGNS`): Maße, Achsen, Reifen, Grundriss `plan`,
  Deckel-/Haubenlinie `deck`, `crown`, Schulterlinie `shoulder`, Unterkante `under`, Endrundungen,
  Glashaus (`roof`, `g_range`, `tumble`, `r_roof` …), Scheiben (`glass`: Seitenfenster-Säulen, Front-,
  Heckscheibe), Felgen (`rims`); dazu eine Feature-Funktion in `FEATURES` (Leuchten, Kennzeichen, Diffusor,
  Endrohre, Spoiler/Flügel, Spiegel, Fugen, Front). Umrisse am Heck/Front sind `(x, z)` der rechten Seite
  (gespiegelt), an der Flanke `(y, z)`, von oben `(x, y)`. Farbe in `catalog.PLAYER_COLORS`.
  Schnellvorschau: `render_all.py --only player/<id> --quick --out /tmp/x`.
- **Pkw-Verkehr**: Entwurf in `designs.py` (Seitenprofil `lower`, Kabinenprofil `cabin`, Fenster `win`,
  Leuchten als Decals), in `TRAFFIC_MODELS` eintragen, Farben in `catalog.TRAFFIC_COLORS`.
- **Polizei**: Zeile in `catalog.POLICE` (Basismodell, Wort, Stil `band|band_pin|stripes|check|lower|italy`,
  Farben). Das Land muss in `data/countries.json` auf `police/<land>` zeigen.
- **Lkw/Bus**: `heavy.py` baut das Modell und liefert die Teile (`parts`: Name, Quadermaße relativ zur
  Fahrzeugmitte, Flächen, Objekte je Teil) und die Lichtflächen (`lights`). Quadermaße als Vielfache von
  5 cm halten (ganzzahlige Pixel).
- **Requisit**: Funktion `name(rig, p)` in `props_nature.py` / `props_buildings.py` / `props_road.py`,
  Eintrag in `props.PROPS`.
- Danach `render_all.py --only <id>` und `validate_manifest.py`; Kontaktbogen ansehen.

## Prüfung

`validate_manifest.py` prüft: alle Pflicht-IDs (Obermenge der Platzhalter), Schlüssel/Typen, Datei vorhanden,
**Rasterlayout** (PNG-Größe = `grid_cols` × Zeilen, Sheets ≤ 4096 px bei Fahrzeugen), Winkel-/Ebenennamen,
**`yaw_deg`** (Liste, ein Wert je Winkel, steigend, `c` = 0°; Verkehr/Polizei genau −24…24/3°, Spieler
−20…20/2°), `projection`/`pivot` je Gruppe, **Spielerkamera** (`camera` = `render.*` der Konfiguration,
`screen` 1280×720, `supersample`), Anker innerhalb der Zelle und passend zu den Pixeln (Verkehr: Bodenzeile
und horizontale Mitte; Spieler: horizontale Mitte, Heck unterhalb des Ankers, gemessene Heckbreite ↔
`object.width_m`), gemessene Breite ↔ `object.width_m`, transparente Zellränder, nicht leere Licht-Ebenen,
`beacon_a ≠ beacon_b`; **Quader-Sets**: Teile mit gültigen x/y/z-Bereichen innerhalb der Fahrzeuglänge,
Flächen `rear/left/right` vorhanden, Rechtecke im Sheet und ohne Überlappung, ≥ 48 px/m,
**Seitenverhältnis = Flächenmaße**, Flächen nicht leer, Lichter verweisen auf vorhandene Flächen und haben
deren Größe; Gesamtgröße ≤ 60 MB.
`contact_sheet.py` erzeugt je Kategorie einen Kontaktbogen (alle Winkel bei Tag + Nachtkomposit, Bremse an
jedem zweiten Winkel), einen Bogen aller Quaderflächen samt Lichtern (`contact_boxes.png`) und eine
maßstäbliche Aufstellung aller orthografischen Fahrzeuge (Lkw/Bus mit ihrer Heckfläche) auf gemeinsamer
Bodenlinie.

## Import und Speicher

Die Fahrzeug-Sheets (`player/`, `traffic/`, `police/`) werden **VRAM-komprimiert** importiert
(`compress/mode=2`, `compress/high_quality=true` → BPTC/BC7 auf dem Desktop, Mipmaps an); Showroom,
Requisiten und UI bleiben verlustfrei. Die `.import`-Dateien liegen im Repository.

`python3 tools/blender/set_vram_import.py` setzt diese Parameter (danach `godot --headless --path . --import`)
und gibt die Größen aus. Stand v2:

| Gruppe | PNG | GPU (alles geladen, inkl. Mipmaps) |
|---|---|---|
| player (5 Sheets, je bis 4096 × 3500) | 17,4 MB | 90,5 MB (BPTC, ≈ 18 MB je Auto) |
| traffic (26 Pkw + 7 Lkw/Bus-Quader) | 19,4 MB | 93,9 MB (BPTC) |
| police (17) | 11,5 MB | 78,8 MB (BPTC, ≈ 4,6 MB je Land) |
| props (36) | 3,2 MB | 31,8 MB (verlustfrei) |
| showroom (5) | 0,9 MB | 9,4 MB (verlustfrei) |
| ui (7) | 0,1 MB | 0,3 MB |
| **gesamt** | **52,4 MB** (Budget ≈ 60 MB) | **305 MB**, davon Fahrzeuge 263 MB |

In einem Rennen ist nur ein Spielerauto und die Polizei des aktuellen Landes geladen (SpriteDB lädt bei
Bedarf): typisch ≈ 150 MB, wenn alle Verkehrsmodelle und -farben vorkommen.

## Hinweise für die anderen Module

- **Fahrzeuggrößen**: `SpriteDB.object_size(set)` liefert echte Maße (Lkw 16,5 m, Bus 12,8 m, Transporter
  5,4 m). Bei Quader-Sets stehen die Maße zusätzlich in `parts` (relativ zur Fahrzeugmitte).
- **Schwere Fahrzeuge**: Tag `heavy` (`traffic/truck_*`, `traffic/bus_*`, `render: "box"`), Pkw-Tag `car`.
- **Spieler**: Zelle mit Mipmaps verkleinern (`supersample` 2); Gierwinkel nur aus `yaw_deg` lesen.
- **Spiegeln**: Requisiten mit Tag `mirror_left` sind für die rechte Straßenseite gerendert. Links platziert
  sollten sie gespiegelt werden; dabei auch den Anker spiegeln (`1 - anchor.x`).
- **Abstand zur Straße**: `extent_m = [links, rechts]` ist die sichtbare Ausdehnung links/rechts des Ankers
  in der ungespiegelten Zelle (siehe docs/renn-modul.md §5).
- **Tankstelle** (`wide`): Anker unter der Mitte des Dachs, Preismast links, Shop rechts.
- **Fähre**: `props/ferry_ship` ist eine große Seitenansicht (Bug rechts, Anker = Wasserlinie Mitte,
  ohne Schatten) für die Fährszene; Ebene `lights` für die Nachtfahrt.

## Renderzeiten

Gemessen auf der geteilten Maschine (Cycles CPU, leerer Cache):

| Gruppe | Zeit je Set |
|---|---|
| Spielerauto (84 Renderings: 21 × Schatten, Base 56 Samples, Rück- und Bremslicht; Bau ≈ 45 s) | 8,5–9,5 min (3 Threads) |
| Showroom (768×480, 160 Samples) | 1–1,5 min |
| Lkw/Bus-Quader (8 Flächen + 5 Lichtflächen) | 1–1,3 min |
| Pkw-Verkehr (17 Winkel) | erste Farbe eines Modells 50–70 s, jede weitere Farbe 25–35 s (2 Threads) |
| Polizei (17 Winkel × 6 Renderings) | ≈ 100 s (2 Threads) |
| Requisiten / UI | unverändert aus v1 (2–25 s bzw. 1–3 s) |

v2-Lauf: Verkehr + Polizei 43 Sets / 2474 Renderings in 47 min (2 Threads), Spieler + Showroom +
Lkw/Bus 17 Sets / 502 Renderings in 59 min (3 Threads). Ein erneuter Lauf ohne Änderungen rendert nichts
und setzt nur die Sheets neu zusammen. Änderungen an `rig.py`, `materials.py` oder `meshutil.py` machen den
ganzen Cache ungültig; Änderungen an einem Builder-Modul nur dessen Sets.
