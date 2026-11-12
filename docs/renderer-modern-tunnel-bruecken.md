# Modus „Modern“ – Tunnel, Brücken, Wasser und Ufer

Technische Dokumentation des Bauabschnitts R5 (v0.8.0, Welle 3 von M2) des echten 3D-Renderers. Der Bauplan steht in
[dev/v080_contract.md](dev/v080_contract.md) (§6 „Tunnel und Brücken“, Inventar B, Nachträge A-7, A-8, A-16); Kern,
Fassade und Stücke beschreibt [renderer-modern.md](renderer-modern.md), Gelände und Fernboden
[renderer-modern-gelaende.md](renderer-modern-gelaende.md), die Modelle [modelle.md](modelle.md). FIX1 hatte Tunnel und
Brücken als Mindestbauten in Arcades Formen gelegt (renderer-modern.md 14.3, 14.7); R5 baut sie aus.

„gemessen“ = auf dieser Entwicklungsmaschine (headless bzw. Mesa llvmpipe unter Xvfb, geteilte Kerne);
„abgeleitet“ = gerechnet oder gefolgert, nicht gemessen. Bilder auf einer echten Grafikkarte gibt es hier nicht.

## 1. Dateien

| Datei | Aufgabe |
|---|---|
| `scripts/race3d/builders/tunnel.gd` | Builder `tunnel`: Röhre mit Gehwegen, Fliesen, Kabeltrassen, Leuchten, SOS-Nischen, Notausgängen, Strahlventilatoren; Kappe; Portal mit Rahmen, Stirnwand, Flügelmauern und Hügel; Rahmen der Ausfahrt; Zone für die Umgebung |
| `assets/shaders/modern/tunnel.gdshader` | Oberfläche der Röhre: Arcades Tunnellicht und Tunnelnebel, Fliesenfugen, Ringfugen, Ruß, Schilder (SOS, Notausgang), Lampenschein an den Wänden |
| `scripts/race3d/builders/bridge.gd` | Builder `bridge`: Wasser, Ufer (Kaimauer, Böschung), Tragwerk je Brückentyp, Pylone mit Seilen und Flugbefeuerung, Fachwerkportale, Brückenlampen |
| `assets/shaders/modern/water.gdshader` | Materialklasse `water`: Wasserfläche (Wellen, gespiegelter Himmel, Glitzern) und die Ufer (Naturstein, Klinker, Gras mit Steinschüttung, Pflaster) |
| `scripts/race3d/layers/far_ground.gd` | Ebene `far_ground` (Übernahme durch R5 nach Entscheidung der Leitung): zusätzlich Fernwasser, Fernland und Fernufer je Brücke im Fenster |
| `tests/unit/race3d/test_tunnel.gd`, `test_bridge.gd` | Unit-Tests (Abschnitt 6) |
| `tests/race3d/render/check_tunnel_bridge.gd` | Render-Prüfung (`tools/run_render_checks.sh modern`) |

Beide Builder werden über ihren Dateinamen gefunden (renderer-modern.md §4.5); mit anderen Bauabschnitten reden sie
nur über die Fassade (A-7): `renderer.add_lamps()`, `renderer.add_pool_material()`, `renderer.env` (duck-typed
`set_zone`), `renderer.builder("bridge")` für die Ebene `far_ground`. `builders/props.gd` lässt die Brückenteile
(Pylone, Portale, Brückenlampen) liegen, sobald `builders/bridge.gd` existiert (`_skip_bridge`, keine Zeile in
`props.gd` geändert).

## 2. Tunnel (`builders/tunnel.gd`)

### 2.1 Röhre

Je Tunnelsegment ab der äußeren Bankettkante beider Seiten (dort, wo Arcades Wände stehen):
- **Gehweg** 0,9 m breit, 0,25 m hoch, mit Bordsteinkante – Arcades Notgehweg (`RoadRenderer._draw_ground`) in seinen
  Farben; die Fahrbahn bis dahin zeichnet `builders/road.gd`.
- **Wand**: Fliesenband bis 2,9 m in Paneelen von 1,2 × 0,6 m mit Fugen und Straßenschmutz unten (jedes zweite
  Segmentpaar 6 % dunkler wie Arcade; der Ton je Paneel blendet aus, sobald ein Paneel nur wenige Bildpunkte groß ist),
  darüber Sichtbeton bis `render.tunnel.wall_height_m` (4,2 m), die Vouten um
  `haunch_m` (1,8 m) nach innen bis `ceiling_m` (6,2 m), die Decke mit Ringfugen alle 12 m und Ruß über der Fahrbahn.
- **Kabeltrassen** unter beiden Vouten; **Leuchten** auf beiden Vouten alle `light_every_m` (12 m) als Gehäuse mit
  Glas (den Lichthof legt die Ebene `flares` mit der Rolle `tunnel` darüber); die Wände sind neben jeder Leuchte heller.
- **SOS-Nischen** alle 150 m in der rechten Wand (wo Arcade sein grünes Notrufschild malt): beleuchtete Nische 2,2 m
  breit, 2,4 m hoch, 0,9 m tief mit Notruftelefon, orangem SOS-Schild darüber und Arcades grünem Schild daneben.
- **Notausgänge** alle 300 m in der linken Wand (75 m versetzt): grüne Stahltür in einer flachen Laibung, darüber ein
  beleuchtetes grünes Schild (Pfeil und Tür).
- **Strahlventilatoren**: ein Paar alle 300 m (225 m versetzt) unter der Decke, Unterkante mindestens 5,2 m über der
  Fahrbahn (`FAN_MIN_BOTTOM`; die Augenhöhe der Kamera liegt bei 3,4 m, unter einer 6,2-m-Decke verdecken sie nichts).
- **Kappe**: für eine Kamera außerhalb des Tunnels zeichnet der Shader nur die ersten `peek_m` (45 m); dort schließt eine
  dunkle Kappe die Röhre (Arcades `_tunnel_cap`). Der Shader entscheidet nach dem Portal-z jeder Ecke gegen
  `cam_tunnel_z` (gesetzt in `update()`); die Röhre des eigenen Tunnels ist von innen ganz sichtbar. Ein Tunnel, der
  kürzer als `peek_m` ist (Tunel Valík: 40 m sichtbar), hat keine Kappe – durch ihn sieht man die Ausfahrt.
- **Ausfahrt**: ein Betonrahmen um die Öffnung am Ende des letzten Segments (von innen gesehen).

Etappen-km sind 100 m sichtbar (`time.time_scale` 10): der Gotthard (16,9 km) ist 1.690 m lang, der Elbtunnel 330 m.

### 2.2 Portal und Hügel

Am ersten Segment eines Tunnels (vpbr, statisch, beleuchtet):
- **Rahmen** 0,7 m breit um die Öffnung (Wand, Voute, Decke – Gehrungen an den Ecken), 0,3 m vor der Stirnwand, mit
  dunkler Laibung bis zur Röhre;
- **Stirnwand** 1,4 m über den Rahmen hinaus bis `ceiling_m` + 2,4 m (Arcade: `head_h`), **Gesims** darauf;
- **Flügelmauern** 9 m zu beiden Seiten, von Kopfhöhe bis 0,6 m über dem Gelände an ihrem Ende, mit Abdeckung;
- **Hügel**: Arcades bewachsener Hügel nach `RoadRenderer._draw_portal` mit derselben gesäten Folge je Tunnel (30 Spalten
  und die beiden Straßenkanten, 85 m + halbe Straßenbreite je Seite, 30 m ± Abweichung hoch, Grat bis 38 m hinter dem
  Portal), im Verlauf von der abgedunkelten Grasfarbe am Fuß zur helleren am Grat, mit glatten Normalen und Arcades
  Nadelbäumen auf dem Grat (drei von vier Spalten, 5–9 m); hinter dem Grat fällt er bis 8 m unter die Straße – über der
  Röhre endet der Hang über der Decke (er darf nie durch die Röhre schneiden). Bei kurzen Tunneln niedriger und
  spätestens an der Ausfahrt zu Ende. Seine Vorderkante liegt auf der Stirnwand, auf den Flügelmauern und jenseits davon
  0,5 m im Gelände – er schließt das Geländeband am Portal (Render-Prüfung: Abdeckung ≤ 0,2 % an den Portalen von U1 und
  Somport).
- **Lichthof** um die Leuchten von außen: Arcade zeigt die Leuchten der Röhre auch bei Tag von außen mit ihrem Lichthof
  (1,6 m, `LAMP_COL`, 0,45); die Ebene `flares` lässt Tunnelleuchten nur nachts oder mit der Kamera im Tunnel leuchten.
  Darum legt `tunnel.gdshader` den Lichthof als Licht auf die Röhre um jede Leuchte, solange die Kamera draußen ist,
  × (1 − Lichter) – nachts und von innen zeichnet ihn die Ebene `flares`.

### 2.3 Shader (`tunnel.gdshader`)

Unbeleuchtet mit Arcades Tunnellicht (`Palette.tunnel().ambient`; von außen gesehen × (0,5 + 0,5 × Lichter) wie
Arcades an Tageslicht gewöhnte Augen) und Tunnelnebel (`pow((d − 12) / darkness_m, 0,8)` zu `Palette.TUNNEL_FOG`) – die
Röhre sieht von außen und innen gleich aus, was immer die Umgebung tut. Scheinwerfer über `inc/headlight.gdshaderinc`.

| Attribut | Inhalt |
|---|---|
| `COLOR` | Grundfarbe (Arcades Farben: Fliese, Wand, Voute, Decke, Beton, Lampe) |
| `UV` | (Tiefe ab dem Portal, z des Portals) – Kappe und Nebel |
| `UV2` | (Art, Höhe über der Fahrbahn) |
| `CUSTOM0.xy` | Schildkoordinaten (u von links, v von oben) für SOS- und Notausgangsschilder |

Arten (`UV2.x`): 0 Fläche, 1 Kappe, 2 Leuchte, 3 grünes Schild, 4 Fliese, 5 Wand, 6 Decke/Voute, 7 Gehweg, 8 Nische,
9 SOS-Schild, 10 Metall, 11 Tür.

### 2.4 Zone für die Umgebung

`tunnel.gd` rechnet jedes Bild `tunnel_state` = {`amount`, `inside`, `exit_m`, `portal_m`, `exit_in_sight`} und ruft –
wenn das Umgebungs-Rig sie hat (R4, duck-typed) – `renderer.env.set_zone("tunnel", amount)` (Einzelheiten und genaue
Aufrufe: renderer-modern.md Abschnitt 15). `amount` folgt demselben Gesetz wie `EnvironmentRig.tunnel_blend()`
(0 ab 12 m vor einem Portal bis 1 bei 14 m drin, eine Funktion des Orts); ohne `set_zone` behält das Rig seinen eigenen
Weg (`tunnel01`).

### 2.5 Fairness

Wände und Portal stehen, wo Arcades stehen (Bankettkante). Was dazukommt, sitzt in den Wänden, auf den Gehwegen oder
unter der Decke: über den Spuren nichts unter 5,2 m, über dem Bankett vor dem Gehweg nichts unter 4 m
(`test_nothing_of_the_tube_over_the_road`).

## 3. Brücken (`builders/bridge.gd`)

### 3.1 Daten

Je Brücke `Track.bridges` (z0, z1, Typ, Tiefe, Böschung `slope`, Wasser- und Uferfarbe) und je Segment
`TrackSegment.water` / `water_level` / `bridge_i`. `bridge_info()` fasst das für Builder und Fernboden zusammen
(Wasserfarbe wie Arcade: die der Brücke, sonst der Landschaft, sonst `CityData.WATER_COLOR`). Die Teile auf dem Deck
(Pylone, Fachwerkportale, Brückenlampen) setzt `Track` als Requisiten mit dem Schlüssel `bridge`.

### 3.2 Wasser

Eine Fläche 0,15 m über den Wasserzeilen des Geländebands (die bleiben darunter, verdeckt) bis zum letzten Ring des
Bands; `water.gdshader`: Arcades Farbe, analytische Wellen (fünf Wellenzüge, nach Bildpunktgröße ausgeblendet), der
gespiegelte Himmel nach Arcades Anteil (16 % nah bis 70 % in der Ferne, `water_tint`), dunkler an Mauern, Glitzern
der Sonne (des Mondes nachts schwächer), Nässe und Schnee. Nebel nach Arcades Bodengesetz.

### 3.3 Ufer

Arcade (`RoadRenderer._draw_water`) malt die Zeilen der Uferböschung (Wasserspiegel steigt von −Tiefe auf 0) in seiner
Kaifarbe oder der Uferfarbe der Brücke; Modern malte sie als Wasser (am Ende der Köhlbrandbrücke „Wasser, das ins Grün
übergeht“, der Nord-Ostsee-Kanal wie ein See). Jetzt nach Arcades Regel:
- **Kaimauer**, wo die Böschung ein Segment ist (niedrige Brücken ohne Uferfarbe): senkrechte Mauer aus Naturstein
  (Klinker an Kanälen) bis 0,6 m unter das Wasser, Abdecksteine, gepflasterte Fläche dahinter; die ferne Mauer schaut
  zur Kamera.
- **Böschung** sonst: Fläche auf den Böschungszeilen des Geländes – Gras in der Uferfarbe der Brücke mit Steinschüttung
  an der Wasserlinie (Holtenauer Hochbrücke), Naturstein in der Kaifarbe ohne Uferfarbe (Köhlbrandbrücke).

### 3.4 Tragwerk

vpbr, statisch: Randbalken und Untersicht des Decks hinter dem Geländer von `builders/roadside.gd`; Pfeiler mit
Eisbrechern unter Balkenbrücken (bei Schrägseilbrücken nur außerhalb der Hauptöffnung); Steinbögen für `stone_arch`,
`canal`, `causeway` (Stirnmauern, Gesims, Gewölbe, Pfeiler mit Vorköpfen); Arcades Fachwerkträger
(`RoadRenderer._truss_girder`: Gurte, Pfosten, Diagonalen alle 7,5 m) an Fachwerkbrücken; unter jedem Pylon sein
Fundament und ein Querträger.

| Typ | Decktiefe | Feld | Farbe |
|---|---|---|---|
| `river` | 1,7 m | 44 m | Beton #a9a69e |
| `cable_stayed` | 2,3 m | 55 m | Geländerfarbe |
| `truss_arch` | 1,1 m | 40 m | #8d8a83 |
| `stone_arch` | 0,9 m | 21 m | Geländerfarbe |
| `canal` | 0,7 m | 14 m | Klinker #7a5648 |
| `causeway` | 0,8 m | 9,5 m | Geländerfarbe |

### 3.5 Pylone, Seile, Flugbefeuerung (A-16, Entscheidung der Leitung)

- Pylon = Modell `props/bridge_pylon_bare`, in der Höhe skaliert auf `height_m` / 88,8 (Köhlbrandbrücke 95 m), links
  gespiegelt; darauf Arcades Kopfblock (1,6 m), darunter Fundament und Querträger.
- **Seile** wie Arcade (`RoadRenderer._pylon`, 0,07 m dick, Farbe #ecebe6; alle Flächen mit der Normalen nach oben –
  hell wie Arcades Linien, kein halbdunkler Stab): 7 je Richtung, Spannweite = `cables` des Pylons, von 0,95 … 0,65 der
  Höhe zur Deckkante 1,4 m innerhalb des Pylons und 1,1 m hoch – nie über einer Spur (Unit-Test: ≥ 1,5 m jenseits der
  Spuren an Köhlbrand-, Severins- und Ada-Brücke).
- **Nachts dunkel** wie Arcades prozeduraler Pylon (M2ZS1 übernommen): Kopie des Modellmaterials ohne Nachtatlas
  (`emit_energy` 0) mit `night_albedo` 0,45.
- **Flugbefeuerung** bei `height_m` + 1,6 m, rot, blinkt im Takt von Arcade (`fmod(t + Seite × 0,4, 1,6) < 0,8`;
  `blink` = (1,6; 0,8; Seite × 0,4) für `flares.blink_lit()`).

### 3.6 Fachwerkportale, Brückenlampen

`props/bridge_truss_arch` auf die Deckbreite skaliert (`fit_w`), `props/bridge_lamp` an Stein- und Dammbrücken mit
Lichtkegel und Schein über `renderer.add_lamps()`. Fehlt ein Modell, entsteht einfache Geometrie.

## 4. Fernwasser, Fernland, Fernufer (`layers/far_ground.gd`)

Jenseits der Geländebänder zeigte die Scheibe einen Wiesenstreifen statt Arcades fernem Ufer, und unter tiefen Brücken
musste sie seit FIX-WASSER unter dem Wasser liegen (ZS1-Regel: höchstens tiefstes Wasser − 0,3 m). Je Brücke im
geladenen Fenster legt die Ebene jetzt, am Pfad verankert und freigegeben, wenn die Brücke das Fenster verlässt:
- **Fernwasser**: ein Band zwischen den beiden Uferlinien quer zur Straße bis 3 km zu beiden Seiten (auf der
  Innenseite einer Kurve höchstens 0,8 × Radius, nie über einem tieferen Teil der geladenen Straße), 0,05 m unter dem
  Wasser des Builders, im selben Material;
- **Fernland**: solange die Scheibe unter tiefem Wasser liegt, Land auf der alten Höhe der Scheibe (tiefste Straße −
  `far_ground_drop_m`) außer in den Bändern der tiefen Brücken, mit den Parametern der Scheibe;
- **Fernufer**: Böschungen vom Land zum Wasser entlang beider Uferlinien in Ufer- bzw. Kaifarbe.
Die Scheibe selbst bleibt bei der ZS1-Regel (`test_far_ground_water`, Render-Prüfung `terrain_cover` K1).

## 5. Schnittstellen

| Wer | Was |
|---|---|
| `tunnel.gd` → Rig | `env.set_zone("tunnel", amount)`, wenn `env.has_method("set_zone")` – je Bild, nur wenn sich `amount` ändert |
| Rig, Tests → `tunnel.gd` | `tunnel_state` (Eigenschaft), `zone_amount(track, z)` (statisch) |
| `far_ground.gd` → `bridge.gd` | `renderer.builder("bridge")`: `get_water_material(materials)`, `bridge_info(br, scenery, city)` (statisch) |
| `bridge.gd` → Renderer | `add_lamps(parent, lamps)`, `add_pool_material(material)` (Wasser), `materials` |
| `props.gd` | überspringt Teile mit `bridge`-Schlüssel, sobald der Builder `bridge` existiert |

## 6. Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_bridge.gd` | Wasser auf den Wasserzeilen bis zum Bandende, Ufer nach Arcades Regel, ferne Kaimauer zur Kamera, Köhlbrand-Pylone (Maßstab, Befeuerung, Takt, Seile), kein Seil über einer Spur, kein Tragwerk in den Spuren, Brückenteile nicht im Requisiten-Builder, Pylon nachts dunkel, jeder Brückentyp baut |
| `tests/unit/race3d/test_tunnel.gd` | Röhre, Nischen/Türen/Lüfter im Abstand, Kappe, Portal, Ausfahrt; nichts über der Fahrbahn; Hügel schließt das Gelände; kurzer Tunnel ohne Kappe; Kappe nur von außen; Zone nach dem Gesetz des Rigs; `set_zone` nur, wenn das Rig es kann |
| `tests/race3d/render/check_tunnel_bridge.gd` | siehe Abschnitt 7 |
| `tests/race3d/check_minimal_structures.gd` | `tunnel`, `bruecke` (seit FIX1) |
| `tests/unit/race3d/test_far_ground_water.gd`, Render-Prüfung `terrain_cover` K1 | ZS1-Regel der Scheibe |
