# Modus „Modern“ – Gelände, Requisiten, Fernboden

Technische Dokumentation des Bauabschnitts „Gelände, Requisiten, Fernboden“ des echten 3D-Renderers (v0.8.0). Der
Bauplan steht in [dev/v080_contract.md](dev/v080_contract.md) (D14 F7, D16, D21–D24, §4.5, §4.6.7, Nachträge A-3,
A-4, A-7); das Weltmodell, die Stücke und das Geländeprofil des Kerns (`TerrainProfile`) beschreibt
[renderer-modern.md](renderer-modern.md), die Modelle und ihre Shader [modelle.md](modelle.md). Hier steht, was der
Bauabschnitt daraus macht: das Geländeband als Netz mit Shader, die Ebene darunter bis zum Horizont und die
Landschafts-Requisiten.

„gemessen“ = auf dieser Entwicklungsmaschine (headless bzw. Mesa llvmpipe unter Xvfb, 4 geteilte Kerne);
„abgeleitet“ = gerechnet oder gefolgert, nicht gemessen. Bilder auf einer echten Grafikkarte gibt es hier nicht.

## 1. Dateien

| Datei | Aufgabe |
|---|---|
| `scripts/race3d/builders/terrain.gd` | Builder `terrain`: das Geländeband eines Stücks als ein Netz (Ringe × Reihen je Seite, Schürze zur Talsohle) |
| `assets/shaders/modern/terrain.gdshader` | Oberfläche des Bands: Arcades Grasbänder, Kiesstreifen, gemähtes Bankett, Graben, Felder, Schnee, Nässe, Übergang in den Fernboden, Lichtkegel |
| `assets/shaders/modern/inc/ground.gdshaderinc` | das gemeinsame Bodenbild von Band und Fernboden (Felder, Flecken, Schnee, Streifen ohne Flimmern) |
| `scripts/race3d/ground_look.gd` (`GroundLook`) | Farben und Stile des Bodens je Landschaft, Überblendung Randbezirk → Zentrum, Bild in der Ferne, Detailtextur |
| `scripts/race3d/layers/far_ground.gd` | Ebene `far_ground`: Scheibe unter der tiefsten geladenen Straße mit Kragen bis Augenhöhe |
| `assets/shaders/modern/far_ground.gdshader` | Oberfläche der Scheibe (dasselbe Bodenbild wie der äußere Ring) |
| `scripts/race3d/prop_library.gd` (`PropLibrary`) | was ein Requisiten-Set ist (Modell, Sprite-Vertretung, nichts), Netze und Materialien dazu, Laden über `ModelDB` |
| `scripts/race3d/builders/props.gd` | Builder `props`: die Requisiten eines Stücks als MultiMesh-Knoten, Detailstufen, Kontaktschatten, Lampen |
| `assets/shaders/modern/billboard.gdshader` | aufrechte Billboards: Fernbilder (Impostor) der Kartenbäume und Vertretungen der Sets ohne Modell |
| `assets/shaders/modern/contact_shadow.gdshader` | weicher Schattenfleck unter jeder Requisite, von der Sonne weg gestreckt |
| `tests/unit/race3d/test_terrain_builder.gd`, `test_props.gd` | Unit-Tests (Abschnitt 6) |
| `tests/race3d/check_terrain_plan.gd` | Draufsicht-Prüfung (headless, in `tools/run_tests.sh`) |
| `tests/race3d/render/check_terrain_cover.gd`, `check_props_render.gd` | Render-Prüfungen (`tools/run_render_checks.sh modern`) |

Alle Builder und Ebenen werden vom Renderer über ihren Dateinamen gefunden (renderer-modern.md §4.5, §9); sie reden
mit anderen Bauabschnitten nur über die Fassade (`has_method`, `renderer.layer(id)`, `ctx.services`). Fehlt der
Renderer (Tests des Kerns), arbeiten beide Builder ohne ihn: Materialien über `ModernMaterials.shared()`, keine
Lampen, die Requisiten-Sets werden im ersten `collect()` geladen.

## 2. Gelände (`builders/terrain.gd`)

### 2.1 Netz

Das Band ist genau das Profil des Kerns: je Reihe des Stücks (33 Grenzen) und Seite eine Kette von Ringen in den
Abständen `ChunkContext.ring_x` jenseits der Bankettkante mit den Höhen `ring_h` (Bankett und Graben, mildes Relief
außerhalb des Sichtkorridors, der äußere Ring auf der Talsohle). Damit steht eine Requisite auf
`ChunkContext.ground()` genau auf dem Netz (Unit-Test: jeder Eckpunkt = `ctx.local()` seines Rings, `ground()` liegt
auf dem Netz). Gemeinsame Eckpunkte, weiche Normalen aus den Nachbarn im Gitter.

- **Schürze**: unter dem äußeren Rand eine senkrechte Wand von 60 m (`SKIRT_M`), ohne Fläche in der Draufsicht. Sie
  schließt das Band zum Fernboden, wo der tiefer liegt, und die Wände des Spalts an einer Mittelachse und des Lochs
  im Kurvenmittelpunkt.
- **Tunnel**: in Tunnelreihen kein Gelände (Portal und Hügel schließt der Tunnel-Builder).
- **Brücken**: alle Ringe liegen auf dem Wasser (`TrackSegment.water_level`), gezeichnet als Wasserfläche.
- **Budget**: 32 Segmente × 6 Ringabstände × 2 Seiten × 2 = 768 Dreiecke + 128 der Schürze = **896 je Stück**
  (Bauplan: ≤ 1.100).
- Ein Material für alle Stücke; es wirft keinen Schatten (`terrain_shadows` in den Qualitätsstufen schaltet es ein,
  heute nirgends gesetzt: das Relief ist mild, es kostete je Stück einen Schattendurchgang).

### 2.2 Eckpunktdaten

| Attribut | Inhalt |
|---|---|
| `COLOR.rgb` | Bodenton als sRGB-Wert: das Mittel der zwei Grastöne der Landschaft (`data/scenery.json`), in den City Limits mit Arcades Überblendung vom Randbezirk ins Zentrum (`GroundLook.ground_blend`, 150 m wie `RoadRenderer.GROUND_BLEND_M`); auf einer Brücke die Wasserfarbe |
| `COLOR.a` | Natur: 1 Bewuchs (Bankett, Graben, Felder) … 0 Pflaster eines Stadtzentrums |
| `CUSTOM1` | rgb = halbe Differenz der zwei Grastöne, a = wie viel der Bänder zu sehen ist (1 bis 6 m jenseits des Banketts, 0 ab 40 m; in den City Limits 35 % des Kontrasts, auf dem Wasser 0) |
| `UV` | x = Meter jenseits des Banketts, y = **Bandphase** = Segmentnummer / `render.stripes.grass`, gezählt ab einer geraden Bandzahl vor dem Stück |
| `UV2` | x = Meter ab Straßenmitte (mit Vorzeichen), y = Übergang in den Fernboden (1 am äußeren Ring und an der Schürze) |
| `CUSTOM0` | rgb = Akzentfarbe der Landschaft, a = Anteil der Akzentfelder; −1 markiert Wasser |

Die Bänder zeichnet der Shader scharf: gerade Bandphase = Ton 0, ungerade = Ton 1 (so wie Arcade ein Segment färbt).
`TerrainBuilder.band_tone(part, v)` rechnet für Tests nach, mit welchem Ton der Shader an einem Eckpunkt beginnt.

### 2.3 Shader (`terrain.gdshader`, `inc/ground.gdshaderinc`)

Eine beleuchtete Fläche (Sonne mit Schatten, Umgebungslicht, Nebel kommen aus der Umgebung des Renderers), deren
Farbe Schicht für Schicht gemalt wird:

1. **Arcades Grasbänder** quer zur Straße, scharf, nahe der Straße (siehe 2.2); sobald ein Band dünner als ein, zwei
   Bildpunkte ist, bleibt ihr Mittel.
2. **Felder** ab 16–34 m jenseits des Banketts: ein im Shader berechnetes Voronoi-Muster (Zellen etwa 110 × 72 m,
   um 23° gegen die Weltachsen gedreht), jedes Feld mit eigener Schattierung (± 7 %), der Anteil `amount` der Felder
   in der Akzentfarbe der Landschaft (Getreide, Heide, Fels …), Furchen in eigener Richtung (nicht am Feldrand),
   ein dunklerer Rand (Hecke, Weg), weiche Flecken in zwei Größen. Die Grenze zweier Felder ist über einen
   Bildpunkt geglättet.
3. **Streifen an der Straße** (nur Bewuchs): Kies an der Bankettkante (ausgefranst), gemähtes Bankett bis 6 m mit
   Mähstreifen entlang der Straße, Graben 5–12 m dunkler und erdiger.
4. **Pflaster** (Stadtzentren, `COLOR.a` = 0): Platten von 2 m mit Fugen, nur aus der Nähe.
5. **Feine Körnung** in zwei Maßstäben, bis 85 m.
6. **Schnee** aus `ce_snow` (Arcades 94 % `Palette.SNOW_GROUND`, solange er dünn ist fleckig, auf dem Kies dünner),
   **Nässe** aus `ce_wet` (dunkler, glatter: glänzt gegen die Sonne).
7. **Äußerer Ring**: Farbe und Normale gehen in den Fernboden über – die Scheibe darunter setzt das Band ohne Naht
   fort; die Schürze zeigt denselben Ton.
8. **Wasser** unter Brücken: glatte Fläche in der Wasserfarbe der Landschaft.
9. **Lichtkegel** von Laternen und Scheinwerfern (`inc/pools.gdshaderinc`) und das **Abblendlicht** des Spielers
   (`inc/headlight.gdshaderinc`) mit Arcades Rückstrahlfaktoren (Gras 0,45, Kiesstreifen 0,6, Pflaster 0,8, Wasser
   0,45); das Material meldet sich mit `renderer.add_pool_material()` an. Das Netz liegt wie die Fahrbahn auf
   Render-Ebene 2: die echten Spots und Punktlichter der Ebene `lights` lassen den Boden aus (renderer-modern.md
   §10.6, §12.3).

**Kein Flimmern, keine Streifen**: Alles, was feiner ist als ein paar Bildpunkte, geht nach dem *Fußabdruck* des
Bildpunkts auf dem Boden (`fwidth` der Bodenposition, die längere Seite) in sein Mittel über, nicht nach der
Entfernung allein – ein Hang unter flachem Blickwinkel bleibt ruhig. Die Felder werden gerechnet statt aus einer
Zelltextur gelesen: In einer gefilterten Textur verschwimmen die Zellwerte in der Ferne, und jede daraus
abgeleitete Größe (Schattierung, Farbe, Furchenrichtung) wurde zu Streifen (gesehen am Hang bei Saragossa – Pau
km 172,8, Bilder im Abgabeordner). Die Muster liegen in Weltkoordinaten plus `pattern_origin`; der Builder zieht
jede Verschiebung des schwimmenden Ursprungs ab (`rebased`), das Muster bleibt also, wo es auf dem Boden ist.

### 2.4 Landschaftsstile (`GroundLook`)

`data/scenery.json` ist eingefroren und kennt je Landschaft nur die zwei Grastöne. `GroundLook.STYLES` ergänzt je
ländlicher Landschaft eine Akzentfarbe und ihren Anteil (z. B. `north_plain` Getreidegelb 42 %, `heath`
Heidekraut 50 %, `alps` Felsgrau 30 %); Stadtzentren (`*_center`, `city`) sind Pflaster in einem zweiten Grau,
Randbezirke (`city*`) Gärten. `graphics.modern.terrain.styles` in der Konfiguration überschreibt einzelne
Landschaften (`{"<id>": {"accent": "#rrggbb", "amount": 0.4, "nature": 1}}`; heute nicht gesetzt).
`GroundLook.far_look()` mittelt Ton und Stil über 16 Punkte von 96 m hinter bis etwa 670 m vor der Kamera – so
ändert sich das Bild in der Ferne in kleinen Schritten entlang der Strecke. Die Detailtextur (`noise_texture()`,
256², r = Körnung, g = Flecken) wird beim ersten Gebrauch in etwa 20 ms erzeugt und gilt, solange ein Material sie
hält.

### 2.5 Haken

`setup` (merkt sich den Renderer), `apply_quality` (`terrain_shadows`), `collect` (Stadt der Etappe, Bandbreite,
Stile: einfache Daten für den Arbeiter-Thread), `build` (nur Schnappschuss-Arrays), `commit` (ein
`MeshInstance3D` je Stück), `update` (Bild in der Ferne für den Übergang des äußeren Rings), `rebased`
(`pattern_origin`), `warmup_nodes` (eine kleine Fläche mit dem Material: der Shader wird hinter dem Ladebild
übersetzt), `debug` (Zähler, Prüfsumme, Hüllquader).

## 3. Fernboden (`layers/far_ground.gd`)

Eine Scheibe von 2.400 m Radius um die Kamera (innerhalb der fernen Schnittebene von 2.600 m, jenseits jeder
Sichtweite) auf

    far_y = min(tiefste Straße des geladenen Fensters − graphics.modern.terrain.far_ground_drop_m (4,0 m),
                tiefste Wasserfläche des geladenen Fensters − 0,3 m)

und an ihrem Rand ein **Kragen**, der bis zur Augenhöhe der Kamera reicht – also genau bis zur Horizontzeile des
Bildes. Weil die Scheibe unter jeder geladenen Straße und unter jedem geladenen Wasser liegt, kann sie nichts
verdecken (F7). Sie schließt, was die Bänder offen lassen: den Boden jenseits der äußeren Ringe, den Spalt von etwa
12 m an einer Mittelachse und das Loch im Mittelpunkt enger Kurven (A-3). Der Kragen ist der „Boden im
Unendlichen“: Auf 2,4 km ist er in jedem Wetter reine Nebelfarbe, das Bild ist unter dem Horizont geschlossen, ohne
dass es auf die Füllung des Hintergrunds ankommt.

- Fenster: von `keep_behind_m` hinter der Kamera bis min(`load_path_m`, Sichtweite + zwei Stücke) voraus – die
  Straße jede vierte Reihe (feste Reihen: nichts ändert sich, bis die Kamera die nächste Reihe erreicht), das Wasser
  jede Reihe jeder Brücke darin (`Track.bridges`; nur deren Reihen tragen `TrackSegment.water`), auf der Höhe, auf
  die das Gelände die Ringe einer Wasserreihe legt: Fahrbahnhöhe + `water_level`.
- **Wasser unter hohen Brücken** (FIX-WASSER): Liegt das Wasser tiefer als `far_ground_drop_m` unter der Fahrbahn,
  läge die Scheibe sonst darüber und deckte den Fluss zu – an der Köhlbrandbrücke (Elbe 9 m unter der Fahrbahn) zeigte
  Modern Wiese statt der Elbe, die Fähren standen auf der Wiese. Betroffen sind alle Brücken über Wasser tiefer als
  4 m: Köhlbrandbrücke (Hamburg, 9 m), Holtenauer Hochbrücke (Kiel, 16 m), Kirchenfeldbrücke (Bern, 8 m) und die
  Schrägseilbrücken mit der Vorgabetiefe 5 m – Severinsbrücke (Köln), Elisabethbrücke (Budapest), Ada-Brücke
  (Belgrad), Vanšu-Brücke (Riga). Flacheres Wasser (Elbbrücken 3,6 m, Steinbrücken 3,2 m, Kanäle, der Damm nach
  Venedig 1,4 m) lag schon über der Scheibe; dort und überall ohne Wasser im Fenster liegt sie wie bisher.
- Eine Regel: M2INT hatte denselben Befund (FIX-ZS1-B1) unabhängig behoben (`b341df8`: Wasserhöhe statt Straße in
  `lowest_road()`, Scheibe 4 m unter dem Wasser). Beim Zusammenführen mit dem ersten Testbuild (M2ZS1) gilt nur die
  Regel von FIX-WASSER, die der Nutzer im Testbuild hat: Sie liest jede Wasserreihe statt jeder vierten, prüft, dass
  die Reihe noch im Speicher der Strecke liegt (`index == k`), und lässt die Scheibe an den Elbbrücken bitgleich wie
  vorher. Von `b341df8` bleibt der Unit-Test `test_far_ground_lies_below_the_water_of_a_bridge` (synthetische
  Strecke, auf die eine Regel umgestellt) und der Befund: Schiffe und Hausboote stellt `Track` nur neben Brücken über
  Wasser (gezählt: 46 von 46 im ganzen Netz auf Wassersegmenten, Rumpf ganz über Wasser).
- Die Höhe folgt ihrem Ziel um höchstens 0,35 × die gefahrene Strecke je Bild – auch wenn eine Brücke etwa 1,1 km
  voraus ins Fenster kommt (Köhlbrandbrücke: 5 m tiefer in 14 m Fahrt, lange bevor das Wasser in Sicht ist) und wenn
  sie 250 m hinter der Kamera wieder hinausgeht; das erste Bild und ein Sprung über 150 m setzen sie sofort.
- Jenseits des äußeren Rings des Wassers (480 m, „Details: Hoch“ 1.000 m) zeigt die Scheibe Land in der Farbe der
  Landschaft: am Horizont ein schmaler Streifen Wiese neben dem breiten Fluss, wo Arcade das graue Ufer zeigt (ein
  Fernwasser gibt es nicht; offen, siehe 8).
- Acht Sektoren statt eines Knotens: Ihre Mittelpunkte liegen fern der Kamera, der Renderer zeichnet sie nach dem
  Gelände davor (ein großer Knoten um die Kamera würde zuerst gezeichnet und überall Füllrate kosten).
- Setzt das Global `ce_far_y`. `--gfx-debug=far` zeichnet Signalfarben (Scheibe cyan, Kragen gelb) für die
  Render-Prüfung.
- Wie das Gelände: Render-Ebene 2, Lichtkegel und Abblendlicht (Gras 0,45), Material über `add_pool_material()`
  angemeldet – wo die Scheibe nahe dem Wagen durch eine Lücke der Bänder zu sehen ist, ist sie beleuchtet wie der
  Boden daneben.

## 4. Requisiten (`builders/props.gd`, `prop_library.gd`)

### 4.1 Quelle und Auslassungen

Gezeichnet wird genau die Liste, die Arcade zeichnet: die Einträge `kind: "prop"` von `TrackSegment.sprites` (und,
solange es den Builder `city` nicht gibt, die Straßenlaternen `kind: "object"`, `obj: "streetlight"`; Wahrzeichen
und Brückenteile übernehmen später `landmarks` bzw. `bridge`, sobald es sie gibt) – abzüglich dokumentierter
Auslassungen (`debug()["dropped"]`):

| Grund | wann |
|---|---|
| `ribbon` | die Requisite steht jenseits des gekürzten Geländebands (Kurveninnenseite, Mittelachse): dort ist kein Boden |
| `corridor` | im Sichtkorridor einer Kurveninnenseite (F7): schmückende Requisiten einer Landschaftsregel und jede Vegetation. Eine weggelassene Pflanze wird durch **Bodendecker** ersetzt (Nachtrag A-3): Stücke der Sets aus `graphics.modern.props.bend_cover` (`props/cover_bush`, `props/cover_grass`), höchstens `bend_cover_max_h_m` (0,5 m) hoch – eins für einen Busch, drei für einen Baum, über seinen Fuß verteilt (höchstens 2,5 m), nie näher als 0,8 m an der Fahrbahnkante, nicht in den City Limits (dort ist der Boden Pflaster; `cover_pieces()`; Liste `cover_list`, `debug().cover`). Ein Set der Liste, das die Strecke selbst setzt, bleibt und wird auf diese Höhe verkleinert |
| `missing` | weder das Set noch sein Ersatz-Set hat ein Modell oder ein Sprite-Blatt (Arcade lässt es ebenso aus). Ausnahme **Wahrzeichen**, die Arcade prozedural zeichnet (`proc`; `Track._build_landmark` streicht dafür ihr `fallback`): hat ihr Set weder Modell noch Sprite, steht das Ersatz-Set ihres Eintrags im Etappenplan (`landmark_fallbacks()`, mit `fallback_scale` und `fallback_tint`) – im Stück und als ferne Vertretung. Betrifft Belgrad, Hannover, Leipzig, Dortmund, Calais und Madrid (FIX-WASSER-R, QA-WASSER B1: dort fehlte das Wahrzeichen in Modern ganz) |
| `density` | „Details“ unter 1,0 dünnt Bäume, Büsche, Felsen und niedrige Dinge (Strohballen) aus – nie Gebäude, Wahrzeichen oder hohe Bauwerke (Windräder, Masten, Mühlen); über 1,0 kommt nichts hinzu |

Was ein Ereignis der Etappe gesetzt hat (Tankstelle, Grenze, Radar …, Einträge mit `offset`), bleibt auch im
Korridor stehen, sofern es keine Vegetation ist (Regel 9).

Einträge mit `prefer_proc` (die Pylone der Schrägseilbrücken: Arcade zeichnet sie prozedural, nachts betongrau) zeigen
als Vertretung **nicht** die Lichtebene ihres Sprites – sie ist ein angestrahlter Pylon, den Arcade nie zeigt – und
nehmen kein Scheinwerferlicht an (das Billboard ist 88 m hoch, das Licht käme vom Fuß): eigenes Material
`dark_material()`, Gruppe `d|<set>|<gespiegelt>`. Bei Tag ist das Bild dasselbe (FIX-WASSER-R, QA-WASSER B2: nachts
leuchteten die Pylone der Köhlbrandbrücke fast weiß).

### 4.2 Was ein Set ist (`PropLibrary`)

`request(sets, owner)` löst jedes Set über `ModelDB.resolve` auf: **MODEL** (das Set hat ein Modell im Manifest),
**SPRITE** (`fallback: "sprite"`: ein Billboard der Zelle des Arcade-Sprites) oder **NONE**. Für Modelle wird
`ModelDB.request(…, owner)` angestoßen (alle Stufen, Texturen, Fernbild), für Vertretungen die Sprite-Blätter im
Hintergrund geladen. `pending()` meldet, solange etwas lädt; danach werden Modelle, deren Dateien fehlen
(`ModelDB.missing`), zu Vertretungen – oder, ohne Sprite, zu NONE mit `fail_reason() = "manifest"` (die Etappe
fällt dann auf Arcade zurück). `clear(owner)` gibt die Modelle mit `ModelDB.release_all(owner)` zurück; der Builder
ruft es, wenn er freigegeben wird. Die Tabellen `sets` und `models` sind einfache Daten für `build()` und werden nie
verändert, während ein Bau läuft (neue Sets kommen in Kopien).

Je Set: Klasse (`tree`, `plant`, `rock`, `building`, `landmark`, `other` – aus `kind` des Modells bzw. den Tags),
Maße, Anker und seitliche Ausdehnung aus dem Sprite-Manifest bzw. dem Modell, `mirror_left`, Dichte des
Kontaktschattens, ab welcher Schattenstufe es einen echten Schatten wirft (Bäume und Gebäude ab 2, alles andere 3).
Je Modell: die Darstellung je Detailstufe des Stücks (`lod0`, `lod1`, Fernbild bzw. die gröbste Stufe), ob es einen
eigenen Schattenwerfer hat, seine Lampen (Lichtanker mit Richtung).

### 4.3 Stellen

- Ein **Modell** steht wie ein Fahrzeug (A-4): lokales −Z entlang der Straße, die Seite, die das Sprite zeigt, nach
  +Z, Ursprung = Anker des Sprites – über `ctx.frame(z, x, ctx.ground(z, x))`. Bäume, Büsche und Felsen bekommen
  eine stabile zufällige Drehung um die Hochachse; hat ein Set mehrere `variants`, wählt ein stabiler Hash aus
  Stücknummer und Set **eine Variante je Stück** (`chunk_variant()`; §4.6.6 nennt Segment- und Requisitennummer –
  so kostete jede Variante eigene Knoten und Zeichenaufrufe). Nachbarstücke wechseln, im Stück verdeckt die
  zufällige Drehung jedes Baums die Wiederholung.
- Eine **Vertretung** steht auf dem Boden an ihrem Anker; ihre Farbe trägt die Tönung der Landschaftsregel.
- Kantenbündige Requisiten (`align`) setzen ihre Vorderkante wie Arcades `RoadRenderer.edge_anchor_x`.
- Requisiten mit eigener Höhe (`h`: Schiffe auf dem Wasser) und Brückenteile stehen nicht auf dem Gelände.

### 4.4 MultiMesh, Spiegelung, Zeichenaufrufe

Je Stück und (Modell bzw. Set, gespiegelt) gibt es einen `MultiMeshInstance3D` je Darstellung. Requisiten der
linken Straßenseite, deren Set für die rechte gebaut ist (Tag `mirror_left`; bei Vertretungen auch `mirror` der
Landschaftsregel), kommen in einen **zweiten** Knoten, dessen Basis in x gespiegelt ist (D24: eine gespiegelte
Instanz *in* einem MultiMesh würde von innen nach außen gezeichnet); ihre Instanzen tragen `mirror_x(T)`, so dass
Knoten × Instanz = Rahmen × Spiegelung. Wahrzeichen werden nie gespiegelt. Die Render-Prüfung `props_spiegel`
zeichnet das wirklich (Abschnitt 6).

Zeichenaufrufe je Set, Stück **und Seite** (Unit-Test): eine Fläche je Klasse des sichtbaren Netzes; von den
Darstellungen eines Modells ist immer nur eine sichtbar. Heute: Eiche und Birke 2 (Stamm `vpbr` + Laub `leaves`),
Fernbild 1, Bauernhaus 2 je Seite (`baked` + Scheiben in `vpbr`, AS1b), Laterne 1 je Seite, Vertretung 1 je Seite.
Steht ein Set mit zwei Flächen auf beiden Straßenseiten, braucht es 2 × 2 Aufrufe (gespiegelter Knoten, D24) – die
Grenze „2 je Set und Stück“ des Bauplans hält dann nur je Seite. Dazu ein Knoten der Kontaktschatten je Stück (alle
Sets) und im Schattendurchgang der Schattenwerfer der Kartenbäume.

### 4.5 Detailstufen und Schatten

Die Stufe gilt für ein ganzes Stück, nach dem Weg seiner nächsten Reihe zur Kamera: Stufe 0 bis `prop_lod0_m`,
Stufe 1 bis `prop_lod1_m`, dann Stufe 2 (Qualität „Details“: 40/120, 60/200, 120/350 m), mit 6 m Hysterese, harte
Wechsel (D9), geprüft alle 2 m Fahrt. Echte Schatten: ab `shadow_casters` 2 werfen Bäume (ihr niedriges
Schattennetz, nur im Schattendurchgang) und Gebäude, ab 3 alles; jenseits von `shadow_distance_m` + 40 m sind die
Schattenwerfer aus.

### 4.6 Vertretungen (`billboard.gdshader`)

Ein Billboard dreht sich um die Hochachse zur Kamera (wie die Sprites in Arcade); unter einem gespiegelten Knoten
zeigt es das Spiegelbild. Es ist unbeleuchtet, rechnet aber nach, was eine beleuchtete Fläche zeigen würde
(modelle.md §4). Für die Arcade-Sprites, die Licht und Schatten aus Cycles schon tragen (`baked_light` = 1): Bild ×
das Licht, das eine mittelgraue Fläche bekommt – Arcades Gesetz „Sprite × Umgebungsfarbe“, das die Farbtöne des
Sprites erhält –, die Sonne wie auf ebenem Boden, gegen die Sonne × 0,8, mit ihr × 1,15
(`PropLibrary.STANDIN_SUN`). Der in die Sprites gebackene Bodenschatten (dunkle, halbtransparente Bildpunkte) wird
verworfen (`shadow_cut` 0,97); den Schatten legt der Kontaktschatten auf den echten Boden. Nachts legt sich die
Lichtebene der Zelle über das Bild (Fenster der Häuser), wie in Arcade; die Scheinwerfer des Spielers hellen
Vertretungen in ihrem Kegel auf (`ce_headlight*`).

Gemessen (mittlere Farbe der Baumkronen vor Himmel): Mit 1,0 / 1,0 ist eine Vertretung 7–16 % dunkler als das
Arcade-Sprite an derselben Stelle (Fichte bei Kassel – Würzburg km 46,5, Birke bei Kiel – Hamburg km 2) – Arcade
nebelt Sprites schon aus der Nähe zu einer aufgehellten Nebelfarbe hin, der Tiefennebel von Modern beginnt erst bei
0,45 × Sichtweite (Regel F4). Mit 0,72 / 1,18 waren es 13–21 %; 0,8 / 1,15 lässt einen leichten Hinweis auf die
Richtung der Sonne.

### 4.7 Kontaktschatten (`contact_shadow.gdshader`)

Ein weicher dunkler Fleck unter jedem Baum, Busch, Felsen, Strohballen und Haus (nicht unter Masten, Windrädern,
Laternen, Schiffen, Brückenteilen und Wahrzeichen), ein MultiMesh je Stück: in die Ebene des Bodens unter der
Requisite gekippt, von der Sonne weg gestreckt (Länge = Höhe × Kotangens der Sonnenhöhe, höchstens 1,6 Breiten), so
dunkel wie der Anteil der Sonne am Licht ebenen Bodens (aus `ce_sun_color` und `ce_ambient`) plus ein kleiner
Kontaktanteil, der auch bei bedecktem Himmel und nachts bleibt. Wirft die Requisite einen echten Schatten, blendet
der Fleck zur Kamera hin aus (zwischen 60 % und 100 % von `shadow_distance_m`), wo die Schattenkarte übernimmt.

### 4.8 Lampen

Lichtanker mit Richtung werden je Stück über `ctx.services.renderer.add_lamps(holder, lamps)` angemeldet (A-7):
Position und Richtung im Knoten `Props` des Stücks, Rolle `lights`, Farbe und Größe aus dem Manifest. Kegel und
Stärke gibt `PropLibrary.lamp_pools()`: nach unten (Laterne, Tankstellendach) 9 m und Arcades Laternenstärke 0,55,
eine Gruppe teilt sich 1,6 (Tankstellendach: acht Lampen je 0,2); Wandlampen (Bauernhaus, Scheune, Zollhäuschen)
5 m und 0,4, der Kegel liegt vor der Wand unter der Lampe; Lampen ab 25 m Höhe (Flugbefeuerung des Windrads) ohne
Kegel. Die Ebenen `lights` und `flares` machen daraus Lichtkegel am Boden und den Schein in der Ferne; ohne sie
geschieht nichts. Fensterlicht gebackener Modelle steckt im Nachtlicht-Atlas bzw. in Lampenkanal 12, nicht in
Ankern.

### 4.10 Ende der Sicht

Fernbilder und Laub blenden zwischen 0,85 und 1,0 des Nebelendes (`ce_fog_range.y`) mit geordnetem Dither aus:
jenseits davon wären sie reine Nebelfarbe – helle Flecken („Rauten“) vor den dunstigen Silhouetten des
Hintergrunds, gesehen an S1 (renderer-modern.md §12.6).

### 4.9 Laden und Freigeben

`prepare(ctx)` nimmt aus `ctx.sets` alle `props/*` und `landmarks/*` und ihre Ersatz-Sets (`Track.sprite_fallbacks`)
und stößt das Laden an; `prepare_pending()` hält die Etappe an, bis alles da ist; `fail_reason()` meldet
`manifest` (siehe 4.2). Ein Set, das die Liste der Etappe nicht nennt, wird im `collect()` des ersten Stücks, das es
braucht, synchron nachgeladen. Freigegeben wird mit dem Builder (`ModelDB.release_all(builder)`); Materialien kommen
aus `ModernMaterials.shared()`.

## 5. Konfiguration

Alle Schlüssel sind optional, die Vorgaben stehen im Code (der Abschnitt `graphics` der Konfiguration gehört in
diesem Bauabschnitt dem Renderer-Kern):

| Schlüssel | Vorgabe | Bedeutung |
|---|---|---|
| `graphics.modern.terrain.far_ground_drop_m` | 4,0 | Fernboden so weit unter der tiefsten geladenen Straße (und immer mindestens 0,3 m – `WATER_MARGIN_M` im Code – unter dem tiefsten geladenen Wasser) |
| `graphics.modern.terrain.styles` | – | Stile einzelner Landschaften überschreiben (2.4) |
| `graphics.modern.props.bend_cover` | `["props/cover_bush", "props/cover_grass"]` (Vorgabe im Code `[]`) | Bodendecker-Sets für den Kurvenkorridor (4.1) |
| `graphics.modern.props.bend_cover_max_h_m` | 0,5 | ihre größte Höhe dort |
| Qualitätsstufen (`Gfx.levels`) | – | `prop_lod0_m`, `prop_lod1_m`, `deco_density`, `shadow_casters`, `shadow_distance_m`; `terrain_shadows` (nicht in `Gfx`, Vorgabe aus) |

## 6. Prüfungen

| Prüfung | Inhalt |
|---|---|
| `test_terrain_builder.gd` | das Netz ist das Band des Kerns (jeder Eckpunkt, `ground()` liegt darauf), innerhalb des Budgets, wasserdicht zwischen Stücken, Dreiecke nach oben, Schürze nach außen ohne Fläche, kein Gelände im Tunnel, Ringe auf dem Wasser; Bandton am Bankett = Arcades Band (beide Seiten), Bandphase = Arcades Band auch über Stückgrenzen, außen das Mittel; Überblendung wie `RoadRenderer.ground_blend`; Detailtextur deterministisch und geteilt; Fernboden unter jeder geladenen Straße; Fernboden unter dem Wasser einer Brücke auf einer synthetischen Strecke (`test_far_ground_lies_below_the_water_of_a_bridge`, von M2INT, seit M2ZS1 auf die eine Regel `target_height()` umgestellt: jede Wasserreihe gelesen, auch eine zwischen zwei Straßenproben; ohne Wasser die Straßenregel genau) |
| `test_far_ground_water.gd` | Fernboden mit Wasser im Fenster (die Ebene mit ihrem eigenen `update()` an einem Stellvertreter der Renderer-Fassade): unter der Köhlbrandbrücke (km 73–80,3) liegt die Scheibe mindestens 0,25 m unter dem tiefsten Wasser des Fensters und unter jeder geladenen Straße, die zwei Fähren stehen auf der Wasserhöhe über ihr; ohne tiefes Wasser (km 2, 30, 60, 65, Elbbrücken, Ziel) genau wie bisher; kommt die Brücke ins Fenster, sinkt die Scheibe mit höchstens 0,35 m je Meter Fahrt und liegt unter dem Wasser, bevor es in Sichtweite ist; Holtenauer Hochbrücke, Severinsbrücke, Elisabethbrücke ebenso. Auf `3a23cb8` (vor der Behebung) rot |
| `test_props.gd` | Helfer wie Arcade (`edge_anchor_x`), Spiegelung (Knoten × Instanz), Detailstufen; jedes Requisiten-Set ist Modell oder Vertretung; Stellen, Auslassungen, Lampen, Zeichenaufrufe je Set und Stück; Korridor und Dichte; auf fünf Landschaften echter Etappen ist die Liste eines Stücks die Liste seiner `TrackSegment.sprites` minus der Auslassungen |
| `tests/race3d/check_terrain_plan.gd` (headless) | `terrain_plan_overlap`: in den zwölf härtesten Etappenrichtungen (je drei engste Kurven) und an T1–T4 überlappen sich die Geländestreifen verschiedener Straßenteile in der Draufsicht nicht; `terrain_plan_tips`: Bandspitzen derselben Kurveninnenseite (siehe 8); `terrain_plan_budget`: ≤ 1.100 Dreiecke je Stück. `-- --dump=<Ordner>` schreibt die Daten der Draufsichten |
| `tests/race3d/render/check_terrain_cover.gd` | Geländesperre (§4.9.2): an T1–T4, S1, C1, K1 mit `--gfx-debug=cover,far` höchstens 0,2 % magenta Bildpunkte unter der Horizontzeile; meldet die Anteile von Fernboden und Kragen. K1 (Köhlbrandbrücke, Kiel – Hamburg km 78,1, FIX-WASSER-R) prüft zusätzlich höchstens 2 % Fernboden: die Scheibe darf die Elbe nicht verdecken (gemessen 0,38 %; mit dem `far_ground.gd` vor FIX-WASSER 31,96 % – rot) |
| `tests/race3d/render/check_props_render.gd` | `props_spiegel`: beidseitig gleiche Requisiten (Bauernhaus, Laterne, Birke, Strohballen) aus der Straßenmitte, Sonne im Zenit – das Bild ist sein eigenes Spiegelbild |
| `tests/sim/modern_sight.gd` | F7 mit dem ausgelieferten Relief (gehört dem Kern; das Netz ist dessen Profil) |

## 7. Messwerte

| Messung | Wert |
|---|---|
| Geländesperre (Render-Prüfung), Magenta unter dem Horizont an T1, T2, T3, T4, S1, C1 | 0,000 % überall (Grenze 0,2 %) – gemessen |
| sichtbarer Fernboden + Kragen | T1 2,9 % + 2,6 %, T4 0,4 % + 1,8 %, C1 1,7 % + 0,3 %, T2, T3, S1 0 % – gemessen |
| Draufsicht: 40 Kamerapositionen, 583 Stücke, 36.336 Streifen | 0 Überlappungen verschiedener Straßenteile, 0 gefaltete Streifen, schmalstes Band 101 m; 71 Paare von Bandspitzen an 7 Positionen, tiefste 1,83 m – gemessen |
| Dreiecke je Stück | höchstens 896 – gemessen |
| `render()` des Renderers mit Debug-Straße, Gelände, Requisiten, Fernboden, headless, 20 s Fahrt, Voreinstellung „Mittel“ | im Mittel 0,17–0,22 ms (S1, C1, T4) – gemessen |
| Bauen eines Stücks (Arbeiter-Thread, alle Builder) / Einhängen | im Mittel 2,0–2,6 ms, höchstens 6,2 ms / höchstens 0,41 ms – gemessen |
| Zeichenaufrufe des ganzen Bildes (mit Debug-Straße, ohne Fahrzeuge), Voreinstellung „Mittel“, Xvfb | S1 82, C1 96 – gemessen |

Die Zeiten stammen aus je einem Lauf auf einer Maschine, die andere Aufträge mitbenutzten (Last 7–10 auf vier
Kernen); ihre Streuung ist nicht gemessen. Zeiten auf einer echten Grafikkarte und dem Steam Deck sind hier nicht
messbar; die Feldmuster kosten je Bildpunkt eine Schleife über neun Zellen (auf einer Grafikkarte vernachlässigbar,
abgeleitet).

## 8. Grenzen und offene Punkte

- **Bandspitzen in Kurven**: erledigt mit der Zusammenführung – `TerrainProfile` kürzt jede Reihe auch nach der
  stärksten Krümmung ihrer Seite im Korridorfenster; `check_terrain_plan` ist streng (`STRICT`, 0 Paare an 40
  Kamerapositionen), `modern_sight.gd --full` grün.
- **Kurveninnenseiten**: F7 nimmt dort Bäume und schmückende Requisiten weg (an T2 38 von 135, an T4 der große
  Felsen, den Arcade zeigt); weggelassene Pflanzen werden seit der Zusammenführung Bodendecker (4.1). Felsen und
  Häuser bleiben weg, bis die Projektleitung mit den Bergbildern von Zwischenstand 2 entscheidet.
- **Vertretungen**: Bis die Umgebungsmodelle kommen, sind 83 der 86 Requisiten-Sets und 32 der 33 Wahrzeichen
  Billboards der Arcade-Sprites – sie bestimmen, wie Kiel – Hamburg aussieht. Aus der Nähe sind sie flach, und sie
  drehen sich mit der Kamera.
- **Zeichenaufrufe bei Varianten und Spiegelung**: Varianten kosten nichts mehr (eine je Stück, 4.3); ein Set mit
  zwei Flächen auf beiden Seiten braucht 2 × 2 Aufrufe je Stück (4.4).
- Das Gelände wirft keinen eigenen Schatten (2.1); Berge, die die Sonne verdecken, gibt es nicht.
- **Kein Fernwasser**: Das Wasser einer Brücke reicht so weit wie das Band (äußerer Ring 480 m, auf „Hoch“ 1.000 m);
  dahinter zeigt der Fernboden Land. An breiten Flüssen (Elbe an der Köhlbrandbrücke) sieht man deshalb am Horizont
  einen schmalen Streifen Wiese, wo Arcade das graue Ufer zeichnet. Eine Wasserfläche im Fernboden (Farbe des Flusses
  quer zur Straße, so weit Arcade ihn zeigt) wäre der nächste Schritt; sie ist nicht gebaut.
