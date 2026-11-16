import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'docs/renderer-modern.md'
rep(p, '''| `scripts/race3d/quality.gd`, `perf_probe.gd`, `prewarm.gd` | – | Qualitätszustände des Viewports, Bildzeit-Sonde und Wächter, Aufwärmen der Shader (10.8) |
''', '''| `scripts/race3d/quality.gd`, `perf_probe.gd`, `prewarm.gd` | – | Qualitätszustände des Viewports, Bildzeit-Sonde und Wächter, Aufwärmen der Shader (10.8) |
| `scripts/race3d/builders/terrain.gd`, `props.gd`, `layers/far_ground.gd`, `prop_library.gd`, `ground_look.gd` | – | Gelände, Requisiten, Fernboden – eigene Dokumentation: [renderer-modern-gelaende.md](renderer-modern-gelaende.md) |
| `scripts/race3d/layers/vehicles.gd`, `flares.gd`, `builders/signs.gd`, `vehicle_pose3d.gd`, `sign_atlas.gd` | – | Fahrzeuge, Lichtpunkte, Schilder (Abschnitt 11) |
''')
rep(p, '''- Busse, Lieferwagen, SUV, Polizei, Sportwagen und drei der fünf Spielerautos haben noch kein Modell: sie fahren als
  Kasten (AS2a/AS2b liefern die Modelle; sie erscheinen dann ohne Codeänderung). Gelenkbusse brauchen nur `groups`.
- Die Sonne steht mittags in Fahrtrichtung: das Heck jedes Autos liegt im eigenen Schatten. Das Fülllicht hält das
  Spielerauto lesbar; die Lichtrichtung ist Sache der Umgebung (R1).
- Scheinwerferkegel des Verkehrs auf der Straße und das Licht der eigenen Scheinwerfer: Ebene `lights` (R1/R4).''', '''- Busse, Lieferwagen, SUV, Polizei, Sportwagen und drei der fünf Spielerautos haben noch kein Modell: sie fahren als
  Kasten (AS2a/AS2b liefern die Modelle; sie erscheinen dann ohne Codeänderung). Gelenkbusse brauchen nur `groups`.
- (Erledigt mit der Zusammenführung, Abschnitt 12:) Die Mittagssonne des Renderer-Kerns steht hinter dem Wagen, das
  Heck liegt im Licht; Abblendlicht und Verkehrskegel setzt die Ebene `lights` (`ce_headlight*`), die Schilder
  strahlen damit die echten Scheinwerfer zurück; Lack und Glas haben genau eine Spiegelquelle (12.2).''')
s = open(p).read()
s += '''
## 12. Zusammenführung des Schubs M1 (Bauabschnitt RINT-A)

Die Pakete R1 (Kern), R2 (Gelände, Requisiten, Fernboden), R3 (Fahrzeuge, Schilder), AS1b (Umgebungsmodelle) und
UI1 (Optionen, Showroom, Leistungstest, mit AS1 und AU-B) sind zusammengeführt. Was sie erst zusammen brauchten,
steht hier; die Dokumentation der Pakete gilt sonst unverändert.

### 12.1 Konflikt beim Zusammenführen

`assets/shaders/modern/contact_shadow.gdshader` hatten R2 (Schattenfleck der Requisiten) und R3 (Schattenfleck der
Fahrzeuge) unabhängig angelegt. R2s Datei behält den Namen; R3s Shader heißt jetzt `vehicle_shadow.gdshader`
(Materialklasse `vehicle_shadow`, eigene uid aus dem Import).

### 12.2 Eine Spiegelquelle für Lack und Glas

Gemessen am Spielerauto (Kiel – Hamburg km 2, 12 Uhr und 19:24 Uhr, „Hoch“, ohne Verkehr, Bildausschnitt des Autos):
der `Sky` des Umgebungs-Rigs (D7) und der analytische Himmel von `vpbr`/`glass` (R3, `env_energy` aus der
Fahrzeug-Ebene) spiegelten im Rennen **beide** – das Auto war mittags im Mittel 3 bis 11 Stufen heller als mit
einer Quelle (Mittelwerte des Ausschnitts: beide 86/102/136, nur Sky 75/92/126, nur analytisch 83/96/122).

Entscheidung: **der analytische Himmel ist die Quelle für Fahrzeuge und alles in `vpbr`** (Leitplanken, Laternen,
Windräder). Er trägt Horizontband und Boden, spiegelt in der Dämmerung den roten Himmel (der Sky der Umgebung
gab dort fast nichts), und er gilt in jeder Voreinstellung gleich – den Sky gibt es bei „Effekte: Aus“ nicht.
Umsetzung: solange `env_energy > 0` ist (im Rennen immer), schreiben `vpbr` und `glass` `SPECULAR = 0` und `vpbr`
zusätzlich `METALLIC = 0` mit dem Diffusanteil eines Metalls linear aus `ALBEDO` genommen (die Engine rechnet
Albedo × (1 − Metallic)); das f0 des eigenen `light()` kommt über Varyings. Ohne analytischen Himmel
(`env_energy` 0: Showroom, Kontaktbogen, neutrale Prüfungen) spiegelt die Engine wie bisher – gemessen
pixelgleich zum Stand vor der Änderung. Fahrbahn, Gelände und Requisiten behalten den `Sky` als Quelle (nasse
Fahrbahn). Vergleichsbild: Abgabeordner RINT-A, `spiegelung_eine_quelle.png`.

### 12.3 Gelände und Fernboden im Licht

Wie die Fahrbahn liegen das Geländeband und die Sektoren des Fernbodens auf Render-Ebene 2 (`GROUND_LAYERS`): die
echten Spots und Punktlichter lassen sie aus. Beide Shader binden `inc/pools.gdshaderinc` und
`inc/headlight.gdshaderinc` ein und zeigen Lampen- und Verkehrskegel und das Abblendlicht mit Arcades
Rückstrahlfaktoren (Gras 0,45, Kiesstreifen 0,6, Pflaster 0,8, Wasser 0,45); der Fernboden meldet sein Material wie
das Gelände mit `add_pool_material()` an.

### 12.4 Lampen der Requisiten

`PropLibrary.lamp_pools()` gibt jedem Lichtanker eines Modells Kegel und Stärke:
- Lampen, die nach unten schauen (Laterne, Tankstellendach), bekommen den Kegel von Arcades Laternen (9 m); eine
  Gruppe teilt sich das Licht von Arcades Tankstellenkegel: je Lampe min(0,55; 1,6 / Anzahl) – die acht Lampen
  des Tankstellendachs je 0,2.
- Wandlampen (Bauernhaus, Scheune, Zollhäuschen: Blick zur Seite) bekommen einen kleinen Kegel (5 m, 0,4) auf dem
  Boden vor der Wand – die Ebene `lights` legt ihn höchstens 1,5 m vor die Wand unter die Lampe
  (`pool_centre()`), nicht dorthin, wo die waagrechte Achse den Boden träfe.
- Lampen hoch oben (Flugbefeuerung des Windrads, ab 25 m) bekommen keinen Kegel, nur den Schein der Ebene `flares`.
Fenster leuchten über Lampenkanal 12 (Modelle) bzw. den Nachtlicht-Atlas, ohne Anker.

### 12.5 Rotoren

`vpbr.gdshader` dreht die Rotorteile (Lackcode 0,875, `UV2.y` = Nabenhöhe / 128 m; docs/modelle.md §14) in
`vertex()` um die Z-Achse des Modells durch die Nabe: Winkel = −`ce_time` × `rotor_speed` (1,35 rad/s) + Phase aus der
Lage der Instanz – von der Straße (+Z) aus im Uhrzeigersinn wie echte Anlagen; mit dem Spiel steht auch der Rotor
still (`ce_time` ist Spielzeit). Render-Prüfung `rotor` in `check_props_render.gd` (drei Zeitpunkte: der Rotor
ändert sich, der Turm nicht); Bild: `rotor_drei_bilder.png` im Abgabeordner.

### 12.6 Requisiten: Varianten, Bodendecker, Ende der Sicht

- **Varianten** (`variants` eines Sets): eine je Stück und Set nach stabilem Hash (`chunk_variant()`), nicht mehr je
  Requisite – so kostet ein Set je Stück und Seite höchstens seine Flächen an Zeichenaufrufen (Kartenbaum 2).
- **Bodendecker** (Nachtrag A-3): im Sichtkorridor einer Kurveninnenseite weggelassene Pflanzen werden durch
  `props/cover_bush` und `props/cover_grass` ersetzt (`graphics.modern.props.bend_cover`), höchstens 0,5 m hoch –
  ein Stück je Busch, drei je Baum über seinen Fuß verteilt, nie näher als 0,8 m an der Fahrbahnkante. Felsen und
  Häuser einer Landschaftsregel bleiben im Korridor weggelassen (strengere Lesart von R2, bis die Projektleitung mit
  den Bergbildern von Zwischenstand 2 entscheidet). Bilder T2/T4 vorher/nachher im Abgabeordner.
- **Ende der Sicht**: die „hellen Rauten“ am Horizont von S1 waren Fernbilder ferner Bäume jenseits des Nebelendes –
  reine Nebelfarbe vor den dunstigen Silhouetten des Hintergrunds (gemessen: ohne die Fernbild-Knoten verschwinden
  sie, ohne die Kontaktschatten nicht). `billboard.gdshader` und `leaves.gdshader` blenden zwischen 0,85 und 1,0 des
  Nebelendes (`ce_fog_range.y`, die Sichtweite) mit geordnetem Dither aus, wie Arcades Sprites am Ende der Sicht.

### 12.7 Prüfungen nach der Zusammenführung

- `check_light_base` → `schatten` vergleicht jetzt **beleuchtete, unbeschattete Flächen** (D5 meint: gleich hell),
  nicht mehr das Mittel des ganzen Bodens: Bildpunkte, die in einem der beiden Bilder um mehr als 0,04 dunkler sind,
  gelten als Schatten und zählen nicht; mindestens 75 % des Bodens müssen unbeschattet sein (eine Änderung des
  Grundlichts machte den meisten Boden „verschieden“). Gemessen an S1: beleuchtete Flächen −0,09 %, ganzer Boden
  −1,69 % (5,6 % des Bodens im Schatten der Werfer).
- `check_props_render` → `props_spiegel` nimmt Buche und Fels als Vertretungen (Birke und Strohballen haben seit AS1b
  Modelle, Bäume drehen sich zufällig) und `rotor` (12.5).
- `test_props.gd`: Varianten je Stück, Wandlampen, Tankstellendach, Flugbefeuerung, Bodendecker; „höchstens zwei
  Zeichenaufrufe je Set und Stück“ gilt **je Seite** – ein Haus aus AS1b hat zwei Flächen (`baked` + Scheiben in
  `vpbr`), auf beiden Straßenseiten also 2 × 2 Aufrufe (gespiegelter Knoten, D24).
- `check_terrain_plan` ist streng: `TerrainProfile` kürzt die Innenseite einer Kurve auch nach der stärksten Krümmung
  ihrer Seite in der Nähe (drei Zeilen, R2); 0 überlappende Bandspitzen an 40 Kamerapositionen, `modern_sight --full`
  grün.
- `tools/run_tests.sh` startet zusätzlich `check_options_tabs` (Arcade) und `check_attract`, `check_attract_scenes`
  in Modern; die Render-Prüfungen der Pakete findet `tools/run_render_checks.sh` über ihren Dateinamen.

### 12.8 Moduswechsel und Programmende

- `RaceRenderers.leave_modern()` ist die eine Stelle, die freigibt, was Modern geladen hat (`ModelDB.release_all()`
  + `ModernMaterials.drop_shared()`, A-4): beim Arcade-Renderer nach einem Modern-Renderer und – mit `always` – aus
  den Menüs, wenn „Grafik“ Modern verlässt (GameFlow), und beim Beenden.
- Beim Beenden stoppt `AudioManager` Motor, Schleifen und Einzelgeräusche und wartet 60 ms, damit der Audio-Server
  die gestoppten Wiedergaben verwirft: sonst meldete Godot sie (mit ihren Klängen und dem Generator des Motors) in
  2 von 3 Läufen als „ObjectDB instances leaked at exit“ (gemessen; danach 0 von 6 Läufen in Arcade, 0 von 3 in
  Modern).
'''
open(p, 'w').write(s)
print('ok')
