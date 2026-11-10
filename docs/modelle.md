# Echtzeit-Modelle – Pipeline für den Grafikmodus „Modern“

Der Modus „Modern“ zeichnet echte 3D-Modelle statt Sprites. Die Modelle entstehen aus **denselben
prozeduralen Generatoren** wie die Sprites (`tools/blender/cesprites`, siehe [sprites.md](sprites.md)): Die
Generatoren haben dafür Schalter („Hooks“) bekommen, deren Voreinstellung exakt das Sprite-Modell von v0.7.0
ergibt. Kein Modell wird von Hand gebaut oder importiert. Der Modus „Arcade“ benutzt nichts von alledem.

Stand: Bauabschnitt 0 (Pipeline-Kern und sechs Referenzmodelle). Zahlen mit „gemessen“ stammen von der
Build-VM (4 Kerne, mit anderen Aufträgen geteilt, Software-OpenGL), „abgeleitet“ ist gerechnet, nicht gemessen.

## 1. Ablauf und Befehle

```bash
# 1 Export: Generatoren -> eigener GLB-Schreiber -> Zwischenstände (nie im Repository)
/home/user/tools/bpyenv/bin/python tools/blender/export_models.py [--only=<glob>] [--force] [--jobs=2] [--list]
      -> tools/blender/_cache3d/<gruppe>/<name>/{model.glb, model_meta.json, *.png|*.webp}
# 2 Bake: Godot ohne Fenster -> Dateien des Spiels
godot --headless --path . -s res://tools/models/bake_models.gd -- [--only=<glob>]
      -> assets/models/<gruppe>/<name>/{<stufe>_<knoten>.res, model.json, *.png|*.webp + .import}
godot --headless --path . --import                      # Texturen importieren (S3TC)
# 3 Manifest: sets_default.json + alle model.json (sortiert) -> assets/models/manifest.json
python3 tools/blender/export_models.py --manifest-only   # --defaults schreibt sets_default.json neu
# 4 prüfen und ansehen
python3 tools/blender/validate_models.py [--report]
tools/models_contact_sheet.sh <bild.png> [--only=<glob>] [--night] [--showroom] [--channels] [--lods=lod0,show]
        [--tile=480x320] [--cols=4] [--sun=x,y,z] [--sun-energy=<e>] [--ambient-energy=<e>]
# Sprite-Geometrie unverändert? (nach jeder Änderung an tools/blender/cesprites)
/home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py [--only PRÄFIX,..] [--jobs 2]
```

`<gruppe>` = `player | traffic | police | props | landmarks` (die Präfixe der Sprite-Sets). Der Export
überspringt Modelle, deren Schlüssel (Hash aus Generator-Code, Parametern und Exporter-Version) im Cache
steht. `_cache3d` ignoriert sich selbst für Git (`.gitignore`) und für Godot (`.gdignore`).
`assets/models/manifest.json` ist erzeugt: Bei einem Merge-Konflikt Schritt 3 wiederholen.

**Reproduzierbar (gemessen):** Ein erzwungener zweiter Export aller sechs Modelle ergibt byte-gleiche
Zwischenstände (auch die Cycles-Atlanten). Zwei Bakes in denselben, jeweils leeren Ordner ergeben 28
byte-gleiche Dateien; die Modellordner gelöscht und neu gebacken ergeben wieder genau die eingecheckten
Dateien. Eine `.res`-Datei enthält eine aus ihrem Pfad abgeleitete UID – dasselbe Modell in einem *anderen*
Ordner gebacken unterscheidet sich deshalb in genau diesen Bytes.

## 2. Was wo liegt

| Pfad | Inhalt |
|---|---|
| `tools/blender/ce3d/` | Exporter: `glb` (GLB-Schreiber), `core` (Netze einsammeln, Achsen, Verschweißen), `roles` (Material-Rollen -> Klassen, Lampenkanäle, Lichtanker), `export` (Modell -> GLB + Meta), `lod` (Detailtabellen), `bake` (Atlas-Bake), `manifest` (Budgets, Merge), `catalog3d` (Liste aller Modelle), dazu die Bauer `props3d`, `veg3d` + `leafatlas`, `vehicles3d` + `decalgeo` |
| `tools/blender/export_models.py`, `validate_models.py`, `check_sprite_geometry.py`, `fixtures/geometry_v070.json` | Export, Prüfer, Regressionsprüfung der Sprite-Geometrie |
| `tools/models/` | `bake_models.gd`, `set_model_import.py` (.import-Dateien), `inspect_models.gd` (dekodiert die Netze für den Prüfer), `contact_sheet.gd` |
| `assets/models/` | `manifest.json`, `sets_default.json`, je Modell ein Ordner |
| `scripts/core/model_db.gd` | `ModelDB`: Manifest, Auflösung Set -> Modell, Laden |
| `scripts/race3d/modern_materials.gd`, `model_factory.gd` | Materialien je Klasse, Knotenbaum eines Modells |
| `assets/shaders/modern/` | `vpbr`, `glass`, `baked`, `leaves`, `billboard` |

## 3. Konventionen

**Modellraum:** +X rechts, +Y oben, **−Z in Fahrtrichtung**, Meter. Fahrzeuge: Ursprung in der Mitte auf dem
Boden, Front bei −Z. Requisiten: Ursprung = Anker des Sprites; die Seite, die das Sprite zeigt (Anfahrt),
schaut nach +Z, „links/rechts“ von `extent_m` ist ∓X. Ein Modell wird also wie ein Fahrzeug gestellt: −Z
entlang der Straße. Für die linke Straßenseite spiegelt der Renderer den Knoten (Markierung `mirror_left`).

**Stufen (LOD):** `lod0`, `lod1`, `lod2`, bei Spielerautos zusätzlich `show` (Showroom, `max_dist_m` 0 = nie
nach Entfernung gewählt), optional `shadow` (grober Schattenwerfer; dann werfen die sichtbaren Netze keinen
Schatten). Stufen entstehen aus **gröberen Generator-Parametern** (`ce3d/lod.py`), nie durch Dezimieren eines
fertigen Autos. Godots automatisches Mesh-LOD wird nur für Modelle ohne aufgesetzte Details eingeschaltet
(`auto_lod`: Gebäude, Wahrzeichen, Straßenmöbel).

**Knoten:** `body`; Räder `wheel_<achse><l|r>` (Achse 0 = vorn), Drehpunkt in der Radmitte, Rollachse = lokales
X, linke Räder sind das um 180° gedrehte rechte Rad (keine negativen Skalierungen), Bremssättel gehören zu
`body`. `lod1`/`lod2` eines Fahrzeugs sind ein Netz samt Rädern. Requisiten haben nur `body`.

**Materialklassen** = Namen der Flächen eines Netzes (höchstens eine je Klasse), der Renderer bindet je Klasse
ein Material:

| Klasse | wofür | Textur | Shader |
|---|---|---|---|
| `vpbr` | Fahrzeuge samt Rädern und Lampen, Straßenmöbel, Stämme | keine | `vpbr.gdshader` |
| `glass` | Verglasung bei `lod0`/`show` | keine | `glass.gdshader` |
| `baked` / `baked_cutout` | Gebäude, Wahrzeichen | Atlas (BC1 / BC3), Nachtlicht-Atlas halber Größe | `baked.gdshader` |
| `leaves` | Laubkarten | Blattatlas mit Alpha (BC3) | `leaves.gdshader` |

### Vertexformat `vpbr` („VPBR-L“)

| Attribut | Inhalt |
|---|---|
| `COLOR.rgb` | Farbe als sRGB-Bytes; bei den Lampenkanälen 0–13 die **leuchtende** Farbe |
| `COLOR.a` | Lackcode: 1.0 feste Farbe · 0.0 `paint` · 0.25 `paint2` · 0.5 `paint3` |
| `UV` | (Rauheit, Metall) |
| `UV2` | (Lampenkanal + 0.5, Gewicht 0..1) oder (−1, 0) |

Lampenkanäle: 0 Rücklicht · 1 Bremslicht · 2 Rück- + Bremslicht (Rücklicht 35 %) · 3/4 Blinker links/rechts ·
5 Scheinwerfer · 6 Tagfahrlicht (mit Abblendlicht gedimmt) · 7 Rückfahrlicht · 8 Kennzeichen · 9 Umriss (beide
folgen dem Rücklicht) · 10/11 Blaulicht A/B · 12 Lichter von Requisiten (`ce_night`) · 13 immer an ·
14 angestrahlte Fläche (behält ihre Farbe, plus Farbe × Gewicht × `ce_night`).
Je Instanz (`set_instance_shader_parameter`, feste Indizes 0–6): `paint`, `paint2`, `paint3` (Farbe, Alpha =
Metallwert), `lamp_a` = (Rück, Brems, Blinker links, rechts), `lamp_b` = (Scheinwerfer, Rückfahr, Blaulicht A,
B), `fade` (Dither-Ausblendung, bleibt undurchsichtig), `sun` (0 im Tunnel).
`tools/models_contact_sheet.sh x.png --channels` zeigt jeden Kanal an einem Prüfstreifen.

Die anderen Klassen: `glass` – `COLOR` = Tönung + Deckkraft, `UV` = (Rauheit, Metall). `baked` – `UV` = Atlas
in 0..1, Rauheit eine Zahl je Modell, Nachtlicht = Emissions-Atlas × `ce_night`. `leaves` – `UV` = Blattatlas,
`COLOR` = (Schwankung nach Höhe, Phase je Karte, Steifheit, Helligkeit), Normalen zeigen aus der Krone nach
außen; Wind aus `ce_wind` und `ce_time` (nie `TIME`).

## 4. Wie der Renderer rechnet (gemessen, Godot 4.7.2, GL Compatibility)

Diese Befunde bestimmen die Shader und sind für jeden wichtig, der einen Modern-Shader schreibt:

1. **`ALBEDO` und `EMISSION` sind im Shader sRGB-kodiert.** Vertexfarben (auch Alpha), `source_color`-Uniforms,
   Instanz- und globale Farb-Uniforms kommen unverändert an; die Engine linearisiert `ALBEDO` erst danach.
   Shader wandeln `COLOR.rgb` also **nicht** um; Energien wirken als `pow(e, 1/2.2)` auf kodierte Farben.
2. **Die Umwandlungen sind Näherungen, die unten abschneiden.** sRGB -> linear: `c·(c·(c·0.3053 + 0.6822) +
   0.01252)`; linear -> Anzeige am Ende jedes Durchgangs: `max(1.055·x^(1/2.4) − 0.055, 0)`. Ein unbeleuchtetes
   Material mit `ALBEDO = v` zeigt (Messung = Rechnung):

   | `ALBEDO` | 0.02 | 0.04 | 0.06 | 0.08 | 0.10 | 0.15 | 0.20 | 0.30 | 0.50 |
   |---|---|---|---|---|---|---|---|---|---|
   | Wert × 255 | 5.1 | 10.2 | 15.3 | 20.4 | 25.5 | 38.2 | 51.0 | 76.5 | 127.5 |
   | Anzeige ohne Nachbearbeitung | 0 | 4 | 11 | 17 | 22 | 37 | 50 | 77 | 128 |
   | Anzeige mit `adjustment_enabled` | 0 | 0 | 5 | 12 | 19 | 35 | 49 | 77 | 128 |

   Unter linear 0.0008 zeigt ein Durchgang **nichts**; mit eingeschalteter Nachbearbeitung (im Spiel immer)
   läuft das Bild noch einmal durch beide Näherungen. Dunkle Nachttöne unter etwa 12/255 werden so um bis zu 6
   Stufen gedrückt, alles unter 5/255 wird schwarz. Mondlicht und Nacht-Umgebungslicht müssen darüber liegen.
3. **Das eine schattenwerfende Licht wird in sRGB addiert:** Anzeige = Anzeige(Farbe × Umgebungslicht) +
   Anzeige(Farbe × Sonne), nicht Anzeige(Farbe × (Umgebung + Sonne)) – gemessen am Boden des Kontaktbogens:
   27 + 55 -> 87 (linear gerechnet wären es 60).
4. Ein eigenes `light()` mit `LIGHT_COLOR · ATTENUATION · n·l / PI` und GGX trifft die eingebaute Beleuchtung
   genau. Rückseiten bekommen bei `cull_disabled` gedrehte Normalen.
5. `RenderingServer.global_shader_parameter_get_list()` meldet außerhalb des Editors einen Fehler –
   `ModernMaterials.ensure_globals()` merkt sich deshalb selbst, dass die `ce_*`-Globals angelegt sind.
6. Benutzen zwei Shader an einem Knoten dieselbe Instanz-Uniform (`fade`, `sun` in `vpbr` und `glass`), braucht
   sie in beiden denselben `instance_index`.

**Lichtwerte:** `ce_sun_color` und `ce_ambient` sind **lineare** Werte: `ModernMaterials.light_value(farbe,
energie)` = linearisierte Farbe × Energie – das, womit der Renderer selbst rechnet. `billboard.gdshader` bildet
damit die Rechnung aus 2 und 3 nach und zeigt deshalb bei Tag und bei Mondlicht dasselbe wie beleuchtete Flächen.

## 5. Texturen

Atlas-Bake (`ce3d/bake.py`): Flächen nach ihrer Hauptachse in Karten zerlegt, Texel nach Sichtbarkeit gewichtet
(zur Straße 1.0, abgewandt 0.3, Unterseiten 0.05, verdeckte Flächen 0.03), mit Drehung dicht gepackt; Cycles
backt die Farbe in doppelter Auflösung mit 16 Samples, dann wird verkleinert und der Rand aufgefüllt. Quellen:
PNG bis 1024 px, WebP Qualität 95 für 2048 px; Nachtlicht halbe Größe. Import: S3TC (BC1 ohne, BC3 mit Alpha)
mit Mipmaps. Die `.import`-Dateien schreibt `tools/models/set_model_import.py` genau so, wie Godot sie
schreibt (UID aus dem Pfad) – ein Import ändert sie nicht, sie sind eingecheckt.

Bäume: Der Generator protokolliert seine Kronenkugeln; daraus entstehen Laubkarten (an die Silhouette des
Sprites angepasst), ein Kern, eine Schattenhülle und ein in Cycles gerendertes Fernbild (Impostor).

## 6. Manifest

`assets/models/manifest.json` = `{"version": 1, "exporter", "models": {...}, "sets": {...}}`, Pfade relativ zu
`assets/models/`.

- `models["<gruppe>/<name>"]`: `kind` (`vehicle | heavy | tree | plant | rock | building | landmark |
  furniture`), `object` und `extent_m` (wie im Sprite-Manifest), `aabb`, `lods` (`name`, `max_dist_m`, `tris`,
  `parts`: `node`, `mesh`, `classes`, bei Rädern `pos`, `yaw_deg`, `wheel` = Radius und Lenkbarkeit), `shadow`,
  `lights` (Anker: `role`, `pos`, `size`, `color`), `paint` (Voreinstellung), `textures`, `roughness`,
  `impostor` (`texture`, `size_m`, `anchor_x`), `cards`, `auto_lod`, `tags`, `bytes`, `hash`.
- `sets["<Sprite-Set>"]`: entweder `{"model": id, "paint": {...}, "lod": "show", "showroom": bool,
  "variants": [...]}` oder ein Platzhalter `{"fallback": "sprite" | "box", "object", "paint"}`.

**Jedes Sprite-Set außer `ui/*` hat einen Eintrag** – darum ist jede Etappe in Modern fahrbar: Fahrzeuge ohne
Modell werden als Kasten in ihrer Lackfarbe gezeichnet (`box`), alles andere als Billboard des Arcade-Sprites
(`sprite`). Die Platzhalter stehen in `assets/models/sets_default.json` (erzeugt aus dem Sprite-Manifest und den
Farbtabellen des Sprite-Katalogs); ein Modell überschreibt die Einträge seiner Sets. `showroom: true` setzt nur,
wer per A/B-Bild gezeigt hat, dass das Echtzeit-Modell dem Cycles-Sprite mindestens gleichkommt.

## 7. Im Spiel

```gdscript
if ModelDB.available():                                   # statisch, lädt erst bei der ersten Frage
    var r := ModelDB.resolve("traffic/sedan_red")         # {model_id, model, fallback, lod, paint, object, ...}
    ModelDB.request(["traffic/sedan_red"], ["lod0"])      # lädt im Hintergrund; ModelDB.pending() == 0 abwarten
    var mats := ModernMaterials.new()                     # legt die ce_*-Globals an, lädt Shader erst dann
    var car := ModelFactory.build("traffic/sedan_red", "lod0", mats)     # Node3D: body, wheel_*, shadow
    ModelFactory.set_lamps(car, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0))
    var parts := ModelFactory.multimesh_parts("props/tree_oak", "lod1", mats)   # für MultiMesh-Ebenen
```

- `ModelDB` ist **kein Autoload**; Arcade berührt es nie. `load_manifest(pfad)` lädt ein anderes Manifest
  (Tests). Die Funktion heißt nicht `reload`: `ModelDB.reload("…")` ruft in GDScript `Script.reload(keep_state)`
  der Skript-Ressource auf und erreicht eine statische Funktion dieses Namens nie.
- Modern-Shader nie mit `preload()` laden: Sie brauchen die `ce_*`-Globals, die erst `ModernMaterials` anlegt
  (nichts davon steht in `project.godot`).
- `ModelDB.lod_for_distance(model, meter, faktor)` wählt die Stufe; `release_all()` leert die Caches.

## 8. Hooks in den Generatoren

Regel: **Kein Sprite-Vertex bewegt sich.** Jeder Hook hat eine Voreinstellung, die das Modell von v0.7.0 ergibt.

- **Marken:** Materialien tragen `ce_role` (`paint`, `flat`, `glass`, `lens`, `surface`, `proc`, `fx`) und
  Daten in `ce_data`; Objekte tragen `ce_node` (`body`, `wheel_0l` …, `none` = nur fürs Sprite), `ce_pivot`
  und `ce_lamp` (`tail`, `brake`, `ind`, `head`, `plate:0.6`, `none` …). Objekte werden nur markiert, wenn der
  Exporter `meshutil.tagging(True)` gesetzt hat; `with meshutil.node("wheel_0l", pivot=…)` ordnet alles darin
  Gebaute einem Knoten zu. Der Exporter bricht bei einem unmarkierten Objekt ab.
- **Detailparameter:** `vehicles.Car(detail=…)` (Unterteilung, Querschnitt, Stationsabstand, Räder, Fasen,
  Spiegel, Kleinteile), `carbody.SmoothCar(detail=…)` (Ringe, Stationen, Raster und Höhe der aufgesetzten
  Flächen, Räder, Zusatzlampen, `graze`). Die Tabellen je Stufe stehen in `ce3d/lod.py`.
- **Rundum-Ansicht:** `allround` ergänzt bei Bauernhaus und Michel die Fenster der abgewandten Seiten.

`check_sprite_geometry.py` baut jedes Sprite-Set (ohne zu rendern) und vergleicht Zählwerte, Hüllquader,
Positions-Hash, Topologie, Materialien und Builder-Angaben mit `fixtures/geometry_v070.json`. Die Fixture stammt
aus den unveränderten Generatoren von v0.7.0. Eine Besonderheit: Blenders UV-Kugel liefert ihre Flächen in jedem
Prozess in anderer Reihenfolge (auch in v0.7.0; betrifft die Kugel des Berliner Fernsehturms). Darum gibt es
neben `topo` die Felder `ctopo` (Polygone als Eckenzyklen, sortiert) und `nstat` (Summen der Normalen, mit
Toleranz); weicht nur `topo` ab, zählt das Set als identisch.
Gemessen nach allen Hooks: **187 von 187 Sets identisch** (eines davon mit anderer Flächenreihenfolge), 338 s.

## 9. Ein Modell hinzufügen

1. Eintrag in `ce3d/catalog3d.py` (`builder`, `source` = Sprite-Set, `kind`, `sets`, Optionen).
2. Fehlende Marken und Detail-Hooks im Generator ergänzen; `check_sprite_geometry.py` muss „identisch“ melden.
3. Export, Bake, Import, Manifest (Abschnitt 1), dann `validate_models.py` und Kontaktbogen bei Tag und Nacht.
4. `showroom` erst nach dem A/B-Bild (`--showroom`) auf `true` setzen.

Der Prüfer bricht ab bei: Manifest ≠ Fragmente oder ≠ Dateien, Hash/Bytes falsch, fehlender `.import`,
unbekannter Klasse/Knoten/Stufe/Lichtrolle, Budget überschritten (Dreiecke, Zeichenaufrufe, Karten, Texturen),
Lackcode oder Lampenkanal neben seinem Wert (±0.02), Atlas-Koordinaten außerhalb 0..1, unkomprimierter Fläche,
Material im Netz, `object`/`extent_m` mehr als 2 % (mindestens ein halbes Sprite-Pixel) neben dem
Sprite-Manifest, Rad nicht auf dem Boden (±1 cm), Sprite-Set ohne Eintrag.

## 10. Budgets

| Kategorie | `lod0` | `lod1` | `lod2` | Zeichenaufrufe | sonst |
|---|---|---|---|---|---|
| Spielerauto | 55 000 | – | – | 2 + 4 Räder | `show` ≤ 120 000, Schattenwerfer ≤ 3 000 |
| Pkw, Van | 18 000 | 6 000 | 1 200 | 6 / 1 / 1 | |
| Lkw, Bus | 25 000 | 7 000 | 1 500 | – / 1 / 1 | |
| Polizei | 22 000 | 6 000 | 1 200 | 6 / 1 / 1 | |
| Baum | 2 500 (≤ 450 Karten) | 900 | Fernbild | 2 / 2 / 1 | |
| Landgebäude / Stadtgebäude / Wahrzeichen | 2 000 / 10 000 / 25 000 | auto | – | ≤ 2 | Atlas 1024 / 2048 / 2048 |
| Straßenmöbel | 1 500 | auto | – | 1 | |

Gesamt: Netze ≤ 40 MB, Texturen ≤ 240 MB im Grafikspeicher.

## 11. Referenzmodelle (gemessen)

| Modell | Dreiecke je Stufe | Aufrufe | Netze | Texturquellen | Export | Bake |
|---|---|---|---|---|---|---|
| `player/limousine` | lod0 49 636 · show 102 314 · Schatten 1 872 | 6 / 6 | 1 445 196 B | – | 4,9 s | 0,09 s |
| `traffic/sedan` (4 Farbsets) | lod0 17 276 · lod1 4 147 · lod2 1 144 · Schatten 632 | 6 / 1 / 1 | 247 795 B | – | 9,9 s | 0,02 s |
| `props/tree_oak` | lod0 1 220 (420 Karten) · lod1 459 (140) · Schatten 179 · Fernbild | 2 / 2 / 1 | 53 072 B | 373 558 B | 1,7 s | 0,01 s |
| `props/farmhouse` | lod0 104 | 1 | 2 586 B | 752 795 B (1024², Nachtlicht 512²) | 49 s | < 0,01 s |
| `props/streetlight` | lod0 312 | 1 | 5 023 B | – | 0,2 s | < 0,01 s |
| `landmarks/michel` | lod0 3 024 | 1 | 63 648 B | 377 301 B (2048² WebP, Nachtlicht 1024²) | 315 s | 0,01 s |

Zusammen: Netze 1,73 MB, Texturen 4,59 MB im Grafikspeicher, Quellen 1,43 MB. Der Export des Michel besteht fast
ganz aus dem Cycles-Bake des 2048er-Atlas (980 Karten). Die Sprite-Geometrieprüfung aller 187 Sets dauert etwa
6 Minuten (2 Prozesse).

### Ehrliche Einordnung gegen die Cycles-Sprites

- **Limousine (Spielerauto):** Form, Fugen, Lampen und Räder stimmen mit dem Sprite überein. Im A/B-Bild aus der
  Showroom-Kamera bleibt das Echtzeit-Modell hinter dem Sprite zurück: Der Lack wirkt greller und flacher (keine
  weichen Spiegelungen), die Felgen zu dunkel, es fehlen Kontaktschatten und Innenraum, das Glas ist
  undurchsichtig; die um die Ecke laufenden Rückleuchten enden leicht gezackt. `showroom` bleibt deshalb `false`.
- **Limousine (Verkehr):** dieselbe schlichte Grundform wie das Sprite, Fenster, Lampen und Kennzeichen sind in
  die Karosserie geschnitten. Glas undurchsichtig, kein Innenraum; die hinteren Blinker sind mit 2,7 cm zu klein,
  um aus der Ferne sichtbar zu sein. `lod2` ist kantig – gedacht für mehr als 120 m.
- **Eiche:** Laubkarten statt Kugelhaufen – klar feiner als das Sprite, aber aus der Nähe als Karten erkennbar,
  ohne sichtbare Äste. Fernbild und `lod1` stimmen bei Tag in Rot und Grün auf 3 % überein, Blau liegt rund 20 %
  darunter (dem Fernbild fehlt der Himmelsglanz der Karten); bei Mondlicht sind beide gleich dunkel.
- **Bauernhaus, Michel:** dieselben Volumen wie die Sprites mit gebackener Farbe: Fenster, Fugen und Gesimse sind
  gemalt, nicht modelliert. Von der Straße aus trägt das, aus der Nähe wirkt es flach (kein Umgebungsschatten im
  Atlas; Michel nur 17 px/m). Der angestrahlte Michel ist nachts sehr hell (`emit_energy` in `baked.gdshader`).
- **Laterne:** gleichwertig.
- Der Kontaktbogen hat sein eigenes kleines Licht-Rig; Farben erscheinen dort heller und satter als im Sprite.
  Die endgültige Lichtstimmung legt der Renderer fest.

## 12. Bekannte Grenzen

- Glas von Fahrzeugen ist undurchsichtig, Innenräume fehlen (Budget: ≤ 6 000 Dreiecke in `body`).
- Die abgewandten Wände werden nicht per UV-Spiegelung wiederverwendet; stattdessen ergänzt der Generator
  (`allround`) Fenster auf der Rückseite, die eigene Atlasfläche bekommen.
- Laub nimmt den Schatten der Sonne nur zu einem Viertel an (sonst verschattet die Schattenhülle die Krone).
- Aufgesetzte Details der Verkehrsautos sind in die Karosserie geschnitten (eine Lage, kein Flimmern) – auch
  bei `lod1`/`lod2`, dort mit weniger Teilen.
- Komprimierte Netze melden immer ein Tangenten-Array (mit den Normalen gepackt, kostet keine Bytes).
- Die Lampenkanäle 9, 10, 11, 13 und 14 sowie die Lackcodes `paint2`/`paint3` benutzt noch kein Referenzmodell
  (die Anstrahlung des Michel steckt in seinem Nachtlicht-Atlas); der Prüfstreifen (`--channels`) zeigt alle
  15 Kanäle.
