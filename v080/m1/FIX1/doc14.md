

## 14. Nacharbeit nach der Prüfung des Schubs M1 (Bauabschnitt FIX1)

Die unabhängige Prüfung von M1 (QA-BILD, QA-SYSTEM am Kopf 9b6adbc) fand an den markanten Stellen von Kiel – Hamburg
und in anderen Etappen Lücken, die Modern schlechter als Arcade aussehen ließen. FIX1 schließt die meisten davon mit
**Mindestbauten in Arcades Formen und Farben** – die echten Bauten bleiben Sache der Bauabschnitte von M2 (R4 Wetter,
R5 Tunnel und Brücken, R6 Tankstelle/Grenze/Stadt/Tore, R7 Wahrzeichen). Die neuen Builder tragen die Dateinamen der
Registry (`builders/tunnel.gd`, `station.gd`, `gantry.gd`); R5/R6 übernehmen und ersetzen sie. Zahlen „gemessen“ stammen
von der Build-VM (llvmpipe unter Xvfb, Voreinstellung Mittel); alles über echte Grafikkarten ist abgeleitet.

### 14.1 Arcades Nebel für alles in der Landschaft (`inc/fog_law.gdshaderinc`)

Arcade tönt jedes Sprite mit `RoadRenderer._modulate`: zur eigenen Farbe mal aufgehellter Nebelfarbe (× 1,25) um
0,7 × den Nebelanteil der Entfernung – ein dunkles Auto bleibt dunkel – und blendet es mit seiner Alpha-Ausblendung aus
(in Modern: F5 als Dither). Gelände und Fernboden haben dieses Gesetz seit RINT-B; jetzt auch `baked`, `leaves`,
`billboard`, `vpbr`, `glass` und `sign` (`FOG = ce_arcade_fog(albedo, Entfernung, ce_fog_color, ce_fog_range)` ersetzt den
Tiefennebel der Engine), der Kontaktschatten der Requisiten blendet nach demselben Gesetz aus. Wirkung (gemessen, S1
nach 6 s): ferne Bäume dunkelgrün wie in Arcade statt graublauer „Geisterbäume“, das Bauernhaus in seinen Farben. Eine
schwarze Limousine bei 0,839 × Sicht behält 16 % Kontrast ihrer Pixel gegen 22 % am Nebelbeginn (Render-Prüfung
`sichtgrenze`); mit dem Tiefennebel der Engine wären es etwa 30 % davon gewesen (abgeleitet aus dem Gesetz).

### 14.2 Kein Mondglanz auf dem Lack

`light()` von `vpbr` und `glass` behandelt das gerichtete Licht als Punkt. Bei Tag darf der Sonnenglanz sättigen; nachts ist
das Licht der Mond, eine matte Scheibe im Himmel, und Grund- und Klarlackkeule legten zwei weiße Flecken auf Dach und
Kofferraum. Die Keulen des gerichteten Lichts (Grundkeule, Klarlack, Flocken) behalten nachts 8 % (`coat_sun` / `sun_spec`,
gesetzt von der Fahrzeug-Ebene, wenn `palette.night` > 0,5 – dieselbe Regel, nach der das Rig den Mond nimmt). Wichtig:
`SPECULAR_AMOUNT` in `light()` ist die Spiegelstärke des **Lichts**, nicht das `SPECULAR` des Materials – die Grundkeule
war trotz `SPECULAR = 0` im Rennen aktiv. Gemessen DEV 21 Uhr, Wagenausschnitt: p95-Leuchtdichte 193 → 69 (Arcade 51).

### 14.3 Tunnel (`builders/tunnel.gd`, `assets/shaders/modern/tunnel.gdshader`)

Vorher lag in Tunneln offenes Gelände (der Fernboden) unter einem schwarzen Himmel. Jetzt:
- **Röhre** je Tunnelsegment ab der äußeren Bankettkante: Fliesenband bis 2,9 m (jedes zweite Segmentpaar 6 % dunkler),
  Wand bis `render.tunnel.wall_height_m`, Vouten um `haunch_m` nach innen bis `ceiling_m`, Decke; Lampenbänder auf beiden
  Vouten alle `light_every_m` (die Ebene `flares` legt Arcades Lichthof dazu: 1,6 m, Stärke 0,45), grünes Notrufschild alle
  150 m rechts.
- **Shader**: unbeleuchtet mit Arcades Tunnellicht (`Palette.tunnel().ambient`; von außen gesehen × (0,5 + 0,5 × Lichter)
  wie Arcades an Tageslicht gewöhnte Augen) und Tunnelnebel (`pow((d − 12) / darkness_m, 0,8)` zu `Palette.TUNNEL_FOG`) –
  die Röhre sieht von außen und innen gleich aus, was immer die Umgebung tut. Ecken des Vertex-Formats: `UV` = (Tiefe ab
  dem Portal, z des Portals), `UV2.x` = Art (0 Fläche, 1 Kappe, 2 Lampe, 3 Notrufschild).
- **Von außen** nur die ersten `peek_m` (45 m), dort schließt eine dunkle Kappe die Röhre (Arcade: `_tunnel_cap`); der
  Shader entscheidet nach dem Portal-z jeder Ecke gegen `cam_tunnel_z` (gesetzt in `update()`).
- **Portal**: Stirnwand aus Beton über der Öffnung, Flügelmauern, Gesims, dunkler Rahmen; darüber Arcades bewachsener
  Hügel (85 m + halbe Straßenbreite je Seite, 30 m ± gesäte Abweichung hoch, Grat bis 38 m hinter dem Portal, dahinter
  abfallend; bei kurzen Tunneln niedriger und vor der Ausfahrt zu Ende) in der abgedunkelten Grasfarbe der Landschaft, in
  `vpbr`, beleuchtet.
- **Hintergrund**: mit Röhre bleibt die Leinwand im Tunnel dunkel, bis die Ausfahrt in Sicht ist (Arcades
  `_tunnel_exit_visible`) – das Ende der geladenen Röhre zeigt nie den Himmel.
Bilder: U1 (Gotthard), DEV (Testtunnel 21 Uhr: Hügel und Portal wie Arcade), Elbtunnel (Hamburg – Hannover km 3,3, von
außen und innen) im Abgabeordner FIX1. Offen für R5: Nischen mit Türen, Gehwege, Portalrahmen, Belichtungsrampe an der
Ausfahrt (draußen wirkt die Welt durch die Ausfahrt noch nicht überstrahlt wie in Arcade), Straße und Tiefe der Röhre bei
starken Kurven von außen.

### 14.4 Tankstelle (`builders/station.gd`)

Nach den Flags `TrackSegment.fuel_zone` wie `RoadRenderer._fuel_structures`: **Insel** 0,18 m hoch von 0,35 bis 2,3 m
hinter der befestigten Kante mit gelbem Bordstein zur Tankspur; **Dach** über Insel und halber Tankspur (Unterseite
5,6 m, 0,5 m innerhalb der Kante bis 4,6 m dahinter) mit rotem und weißem Band, Stirnblende mit „TANKSTELLE“ (`Label3D` in
Arcades Schildschrift: Ersatzschrift der Engine, fett), Stützen auf der Insel, zwei Lampen je zweitem Segment
(Lampenkanal 12, Lichtkegel und Schein über `add_lamps`, Rolle `canopy`). Die Zapfsäulen (Requisiten) stehen damit auf
der Insel. Bild S2: gleichwertig zu Arcade.

### 14.5 Start- und Zieltor (`builders/gantry.gd`)

Aus den Schild-Ereignissen mit Seite 0 (`start` 14 m nach der Startlinie, `finish` am Ziel), wie `SignPainter._gantry`:
zwei Pfosten 0,45 m außerhalb der Bankette, 7 m hoch; Banner von 5,4 bis 7 m – Ziel rot mit Schachbrettstreifen und dem
Text des Ereignisses („ZIEL“), Start dunkel mit hellem Streifen, „START“ und drei Countdown-Lampen (rot, eine mehr je
Sekunde, alle grün beim Start; Schein über die Ebene `flares`, Farbe und Stärke je Bild aus `view.countdown`).

### 14.6 Wahrzeichen bis Arcades Reichweite

Arcade zeigt Wahrzeichen bis Sichtweite × `render.landmark_range_factor` (2), höchstens `landmark_far_m` (1.900 m), mit
eigenem Dunst (`RoadRenderer.landmark_fade`). In Modern standen sie nur in geladenen Stücken und wurden wie Requisiten am
Ende der Sicht ausgedithert – Elbphilharmonie und Michel fehlten an S4. Jetzt:
- `billboard.gdshader` und `baked.gdshader` kennen `landmark_law`: Ausblendung über die letzten 28 % von L, Dunst zur
  Nebelfarbe × 1,15 mit 0,85 × Anteil ab dem Nebelbeginn; `props.gd` setzt es auf eigene Kopien der Materialien seiner
  Wahrzeichen (Ersatzbild oder Modell mit einer Fläche – der Michel ist ein Modell).
- Jenseits der eingehängten Stücke stellt `props.gd` (`update()`, alle 2 m Fahrt, `rebased()`) jedes Wahrzeichen bis L als
  einzelnes Ersatzbild bzw. Modell an den Pfad – genau wie `_place()` es im Stück setzt; das Stück übernimmt nahtlos.
Gemessen an S4 nach 6 s: Elbphilharmonie (1.018 m) und Michel (1.178 m) stehen am Horizont an Arcades Stelle (Michel
etwa 15 px versetzt, Blick in die Kurve).

### 14.7 Brücken: Geländer und Wasser

- `builders/roadside.gd` setzt auf jedem Wassersegment Arcades Geländer an die Deckkante (Bankettkante + 0,4 m außerhalb
  der City Limits) in der Farbe der Brücke: Stahlgeländer mit Betonsockel und Pfosten je zweitem Segment, Brüstung für
  `stone_arch`, Mauer für `causeway`, Eisengeländer für `canal`.
- `builders/terrain.gd`/`terrain.gdshader`: Wasser in Arcades Farbe der Brücke (`water` der Brücke, sonst der Landschaft,
  sonst `CityData.WATER_COLOR`) und zum Horizont hin den Himmel spiegelnd wie Arcades `water_tint` (16 % nah, bis 70 %
  in 324 m; die Nebelfarbe vertritt `sky_bottom`).
Offen für R5: Deck, Träger, Pylone, Uferwände.

### 14.8 Zeit je Teil von `render()`

`perf_stats()` meldet `hooks_ms_avg` und `hooks_ms_max` je Teil (Umgebung, Streamer, Kamera, jeder Builder und jede Ebene
mit `update()`); der Leistungstest schreibt je Szene `script_ms_max` und `hooks_ms_max` – eine Spitze auf dem Steam Deck
lässt sich so einer Ebene zuordnen. Gemessen headless an Kiel – Hamburg km 2 mit allen neuen Buildern: ganzer Renderer
0,81 ms je Bild bei normalem Tempo (`renderer_zeit`, Budget 1,5 ms), Kern 0,27 ms (`kern_zeit`, 0,6 ms).

### 14.9 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/race3d/check_minimal_structures.gd` (Haken) | `tunnel` (jedes Tunnelsegment der geladenen Stücke mit Röhre, ein Portal mit Hügel, eine Kappe, Lampen, Röhre weiß Kamera draußen/innen, Leinwand dunkel bis zur Ausfahrt), `station` (Insel und Dach genau auf den Flag-Segmenten, Stirnblende mit Schriftzug, Lampen), `tore` (Start- und Zieltor mit Schrift), `wahrzeichen` (jenseits der Stücke bis zur Reichweite, keines doppelt), `bruecke` (Geländer auf jedem Wassersegment) |
| `tests/race3d/render/check_vehicle_lights.gd` → `sichtgrenze` | Pflichtprüfung §4.9.2 „Objekt an der Sichtgrenze < 3 % Kontrast“ und Arcades Tönung bei 0,839 × Sicht |
| `tests/unit/core/test_gfx_settings.gd` → `test_crash_guard_strikes` | Absturz-Wächter: erst der zweite Fehlstart in Folge speichert Arcade (docs/grafik-modi.md) |
| `tests/race3d/check_facade.gd`, `tests/race/check_attract.gd`, `tools/run_tests.sh` | lastfest: Projektionsgesetz statt fester Horizontzeile, Demo-Dauer ab dem Start der Etappe, Haken läuft auch nach einem Fehler davor, Liste der Fehlschläge am Ende |

### 14.10 Bekannte Lücken im Testbuild (für die Testhinweise)

- **Kein Wetter in der Luft** (R4, M2): kein Regen, kein Schneefall, keine Gischt; nasse Fahrbahn und Schneeränder gibt es.
- Tunnel und Brücken nur als Mindestbauten (14.3, 14.7); keine Grenzstationen (Dach, Kabinen) – Arcade zeigt sie.
- Keine Sonnenscheibe am Tag; kein überstrahltes Draußen an der Tunnelausfahrt.
- Spielerautos: Limousine mit steiler Heckscheibe statt Arcades Fließheck, Kompakt mit schwarzem Dach (Modellnacharbeit).
- Kurveninnenseiten in Bergetappen kahler als Arcade (Sichtkorridor F7: Bäume werden durch Bodendecker ersetzt –
  Entscheidung der Leitung nach A-3).
- Die Leistung auf echter Hardware ist nur über den Leistungstest messbar.
