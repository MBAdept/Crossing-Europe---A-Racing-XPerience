# Sprites – Blender-Pipeline

Alle Fahrzeug-, Requisiten- und UI-Grafiken werden **prozedural in Blender 5.2** (Python-Modul `bpy`)
modelliert und mit **Cycles** gerendert. Ergebnis sind die Sprite-Sheets unter `assets/sprites/` und das
Manifest `assets/sprites/manifest.json` im Format von [ARCHITECTURE.md §12](../ARCHITECTURE.md).
Kein Modell wird von Hand gebaut oder importiert – alles ist Code und damit reproduzierbar.

## Aufruf

```bash
# alles rendern (vom Projektverzeichnis aus)
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py
# nur einzelne Sets (Präfixe, kommagetrennt), schnelle Vorschau mit wenigen Samples
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py --only traffic/,police/de --quick --out /tmp/vorschau
# Liste aller Sets
/home/user/tools/bpyenv/bin/python tools/blender/render_all.py --list

# prüfen und ansehen (nur Pillow + numpy nötig)
python3 tools/blender/validate_manifest.py
python3 tools/blender/contact_sheet.py --out build/sprite_review
```

| Option | Wirkung |
|---|---|
| `--only P1,P2` | nur Sets, deren ID mit einem der Präfixe beginnt; das Manifest wird zusammengeführt |
| `--quick` | 8 statt 40 Samples (Vorschau); eigener Cache-Schlüssel |
| `--force` | Zellen-Cache der gewählten Sets ignorieren |
| `--out DIR` | Ausgabeverzeichnis (Standard `assets/sprites`) |

Cycles rendert auf der CPU mit **2 Threads** (`threads_mode = FIXED`), Base-Ebene 40 Samples + OpenImageDenoise,
Licht-Ebenen 12 Samples ohne Bounces. Jede gerenderte Zelle landet im Cache `tools/blender/_cache/`
(git-ignoriert); der Schlüssel enthält Geometrie-Parameter, Kamera, Farbe (nur Base) und einen Hash des
Builder-Codes. Farbvarianten teilen sich deshalb Schatten- und Licht-Renderings, und ein erneuter Lauf
rendert nur, was sich geändert hat. Das Zusammensetzen der Sheets (Pillow) läuft immer.

## Format und Konventionen

Ein PNG je Set, **Spalten = Winkel, Zeilen = Ebenen**, alle Zellen gleich groß (ARCHITECTURE.md §12).

- **Orthografische Kamera**, `ortho_scale = image_width_m`, Sensor-Fit horizontal → Pixel pro Meter =
  `cell.x / image_width_m` ist exakt. Die Modelle sind in echten Metern gebaut; das Spiel skaliert danach.
- **Anker** = Bodenpunkt in der Mitte der nahen Kante: bei Fahrzeugen die Heckstoßstange (Mitte, z = 0),
  bei Requisiten die Mitte der Vorderseite. Die Kamera wird so verschoben, dass dieser Weltpunkt genau auf
  `anchor` fällt. Fahrzeuge drehen sich für die Winkel **um diesen Ankerpunkt** – der Anker gilt damit für
  alle Spalten, und die Heckmitte bleibt beim Winkelwechsel stehen (kein seitliches Springen in Kurven).
  Deshalb sind Fahrzeugzellen breiter als das Auto (Platz für die ausschwenkende Front bei ±25°).
- **Winkel** `l2, l1, c, r1, r2` = Gierwinkel −25°, −12°, 0°, +12°, +25°; `r` = nach rechts gedreht
  (Nase nach rechts, rechte Flanke sichtbar). Kameraneigung: Spieler 20°, Pkw-Verkehr/Polizei 9°,
  Lkw/Bus 3,5° (die Spielkamera auf 3,2 m liegt unter deren Dach), Requisiten 6°, Fähre 3,5°.
- **Ebenen**: `base` = Tageslicht, Lichter aus, mit weichem Bodenschatten (eigener Schattenpass, darunter
  komponiert). `tail`, `brake`, `beacon_a`, `beacon_b`, `lights` = reine Emissionsrenderings: alles
  Nicht-Leuchtende ist schwarz (verdeckt korrekt), danach Alpha = Helligkeit (max. Kanal), Farbe normiert,
  plus Bloom (Gauß). Über `base` gelegt ergibt das nachts glühende Lampen; `brake` enthält die vollen
  Bremsleuchten + dritte Bremsleuchte und funktioniert auch ohne `tail` (Tag). Leuchtfarben werden so stark
  gerendert, dass kein Kanal clippt (sonst kippt z. B. Blaulicht ins Cyan); die Helligkeit kommt aus einem
  Verstärkungsfaktor im Post-Processing, der den Farbton erhält. Dithering ist nur im Base-Pass aktiv.
- Alle Zellen haben einen **transparenten Rand** (Schatten/Glühen werden an den Zellrändern weich ausgeblendet).
- Zusätzliche Manifest-Schlüssel (optional, vom Spiel nicht benötigt): `elevation_deg`, `yaw_deg`
  (Winkel → Grad), `extent_m` = `[links, rechts]`: sichtbare Breite des Objekts links/rechts vom Anker in
  Metern (gemessen an der `c`-Zelle der Basisebene, ohne Schatten) – damit lassen sich breite Requisiten mit Abstand zur
  Fahrbahn platzieren. Zusätzliche Tags: `mirror_left` (Requisit ist für die **rechte** Straßenseite gerendert –
  z. B. Laternenarm zur Straße, 3/4-Ansicht von Gebäuden; links gespiegelt zeichnen), `wide` (Tankstelle:
  Anker sitzt unter dem Dach, der Shop steht rechts daneben), `tree`, `building`, `city`, `road`, `fuel`, …
- `object`: echte Abmessungen des Modells in Metern (`width_m`, `length_m`, `height_m`), bei Fahrzeugen
  ohne Spiegel. Spielerautos haben exakt Länge/Breite aus `config/game_config.json` (`vehicles.types`).

## Beleuchtung und Materialien

- Sonne von **links oben, leicht von der Kameraseite** (fest relativ zur Kamera, für alle Winkel gleich),
  weicher Himmel (Gradient-Welt, liefert auch die Spiegelungen auf Lack und Glas), Standard-View-Transform.
- Jedes Material enthält die gemeinsame Node-Gruppe `CE_PASS`; ein Pass ändert nur deren Werte
  (Base-BSDF ↔ Emission der jeweiligen Ebene). Prozedurale Masken (beleuchtete Fenster) steuern so Tag und
  Nacht konsistent.
- Fahrzeugdetails (Leuchten, Kennzeichen, Fugen, Fenster, Lackierung/Livery) sind **Shader-Decals** im
  Objektraum: Polygone auf Heck-/Front-/Seitenflächen. Sie sind gestochen scharf in jeder Größe; eine
  einzige Principled-BSDF pro Material (Masken mischen die Eingänge) hält Cycles unter dem Closure-Limit.
- Fenster an Gebäuden: Fensterraster im Fassaden-Shader, nachts per White-Noise zufällig beleuchtet.

## Inhalt

| Gruppe | Sets | Zelle / Auflösung |
|---|---|---|
| Spieler | `player/kompakt` (Kompakt-Schrägheck, gelb), `kombi` (grün), `limousine` (blau, Lichtband), `sportwagen` (rot, Flügel), `gran_turismo` (silber, lange Haube) – base/tail/brake | 112 px/m, 20° |
| Showroom | `showroom/<typ>`: 3/4-Ansicht von vorn, perspektivisch, 384×240, base | – |
| Verkehr | `traffic/<modell>_<farbe>`: hatch (5 Farben), sedan (4), wagon (4), suv (4), van (4), sports (5), truck (4, Sattelzug 16,5 m), bus (3, Reisebus 12,8 m) | Pkw 52 px/m (9°), Lkw/Bus 34 px/m (3,5°) |
| Polizei | `police/<land>` – 17 Länder, landestypische Farben, Wort auf Flanken und Heck, Blaulichtbalken (beacon_a = linke, beacon_b = rechte Hälfte) | 56 px/m, 9° |
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
(große Seitenansicht, Bug rechts, Anker = Wasserlinie Mitte).

## Neues Modell hinzufügen

- **Pkw-Verkehr**: Entwurf in `tools/blender/cesprites/designs.py` (Maße, Seitenprofil `lower`, Kabinenprofil
  `cabin`, Fenster `win`, Leuchten als Polygone), in `TRAFFIC_MODELS` eintragen, Farben in
  `catalog.TRAFFIC_COLORS`. Die Set-ID lautet dann `traffic/<modell>_<farbe>`.
- **Polizei**: Zeile in `catalog.POLICE` (Basismodell, Wort, Stil `band|band_pin|stripes|check|lower|italy`,
  Farben). Das Land muss in `data/countries.json` auf `police/<land>` zeigen.
- **Requisit**: Funktion `name(rig, p)` in `props_nature.py` / `props_buildings.py` / `props_road.py`
  (Ursprung = Bodenmitte der Vorderseite, Gebäude erstrecken sich nach +y), Eintrag in `props.PROPS`
  (Zielhöhe der Zelle in px, Blickwinkel, Glühen, Tags). Leuchtende Teile bekommen `emit={"lights": (farbe, stärke)}`.
- Danach `render_all.py --only <id>` und `validate_manifest.py`; Kontaktbogen ansehen.

## Prüfung

`validate_manifest.py` prüft: alle Pflicht-IDs (Obermenge der Platzhalter), Schlüssel/Typen, Datei vorhanden,
PNG-Größe = Zellen × Winkel/Ebenen, Winkel-/Ebenennamen und Reihenfolge, Anker innerhalb der Zelle und passend
zu den gerenderten Pixeln (Bodenzeile, horizontale Mitte), gemessene Breite ↔ `object.width_m`, transparente
Zellränder, nicht leere Licht-Ebenen, `beacon_a ≠ beacon_b`, Gesamtgröße < 40 MB.
`contact_sheet.py` erzeugt je Kategorie einen Kontaktbogen (Tag + Nacht-Komposit) und eine maßstäbliche
Aufstellung aller Fahrzeuge/Requisiten auf gemeinsamer Bodenlinie.

## Hinweise für die anderen Module

- **Fahrzeuggrößen**: `SpriteDB.object_size(set)` liefert echte Maße (Lkw 16,5 m, Bus 12,8 m, Transporter
  5,4 m). Der Verkehr sollte Länge/Breite/Höhe daraus übernehmen; der Renderer zeichnet den Anker an die
  Hinterkante (`z - length/2`), sonst ragt ein Lkw optisch weit über seine Kollisionsbox hinaus.
- **Schwere Fahrzeuge**: Tag `heavy` (`traffic/truck_*`, `traffic/bus_*`), Pkw-Tag `car`.
- **Spiegeln**: Requisiten mit Tag `mirror_left` sind für die rechte Straßenseite gerendert (Laternenarm zur
  Straße, 3/4-Ansicht von Gebäuden mit der Straßenseite sichtbar). Links platziert sollten sie gespiegelt
  werden (`"mirror": true` im Sprite-Eintrag – der Renderer unterstützt das bereits). Beim Spiegeln muss
  auch der Anker gespiegelt werden (`1 - anchor.x`), sonst verrutscht ein nicht mittiger Anker.
- **Abstand zur Straße**: Gebäude sind 10–34 m breit, der Anker sitzt in der Mitte ihrer Vorderseite.
  `extent_m[0]` (rechts der Straße) bzw. `extent_m[1]` (links, gespiegelt) ist der Mindestabstand des Ankers
  vom Fahrbahnrand, damit nichts in die Straße ragt.
- **Tankstelle** (`wide`): Anker unter der Mitte des Dachs, Preismast links, Shop rechts.
- **Fähre**: `props/ferry_ship` ist eine große Seitenansicht (Bug rechts, Anker = Wasserlinie Mitte,
  ohne Schatten) für die Fährszene; Ebene `lights` für die Nachtfahrt.
- **Speicher**: Fahrzeugzellen sind wegen der Drehung um den Heckanker breit. Alle Sheets zusammen belegen
  unkomprimiert rund 200 MB Grafikspeicher, wenn wirklich alles geladen ist (SpriteDB lädt nur benutzte
  Sets). Falls nötig, kann der Import der großen Sheets auf „VRAM Compressed“ umgestellt werden.

## Renderzeiten

Gemessen auf der geteilten Maschine (Cycles CPU, 2 Threads, leerer Cache): **103 Sets, 1070 Zellen in
rund 35 Minuten**, Sheets zusammen 15,5 MB PNG.

| Gruppe | Zeit je Set |
|---|---|
| Spieler (20 Zellen, 112 px/m) | 1,5–2 min |
| Showroom | ~12 s |
| Pkw-Verkehr | erste Farbe eines Modells ~20 s, jede weitere Farbe ~9 s (nur Base neu) |
| Lkw / Bus | 40–60 s |
| Polizei (25 Zellen + Schatten) | ~30 s |
| Requisiten | 2–25 s (Ø ~11 s) |
| UI-Symbole | 1–3 s |

Ein erneuter Lauf ohne Änderungen rendert nichts und setzt nur die Sheets neu zusammen (wenige Minuten).
Änderungen an `rig.py`, `materials.py` oder `meshutil.py` machen den ganzen Cache ungültig; Änderungen an
einem Builder-Modul nur dessen Sets (Requisiten je Quelldatei).
