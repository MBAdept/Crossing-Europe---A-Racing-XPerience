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
        [--review [--views=0,4,..] [--set=<Set>]] [--chase=9,30 [--lane=<m>]] [--clay] [--caster]
tools/run_render_checks.sh modern check_models           # Materialklassen, Lampenkanäle, Blinker, MultiMesh (Xvfb)
# Sprite-Geometrie unverändert? (nach jeder Änderung an tools/blender/cesprites)
/home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py [--only PRÄFIX,..] [--jobs 2]
# Cache-Schlüssel: gibt eine Änderung im Sprite-Katalog den betroffenen Modellen einen neuen Schlüssel?
/home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys
```

`<gruppe>` = `player | traffic | police | props | landmarks` (die Präfixe der Sprite-Sets). `_cache3d` ignoriert
sich selbst für Git (`.gitignore`) und für Godot (`.gdignore`). `assets/models/manifest.json` ist erzeugt: Bei
einem Merge-Konflikt Schritt 3 wiederholen.

**Cache-Schlüssel.** Der Export überspringt Modelle, deren Schlüssel im Cache steht. Der Schlüssel
(`ce3d.catalog3d.cache_key`) ist ein Hash über alles, was der Bauer des Modells liest:

- den **Code**: die Dateien aus `COMMON_CODE`, `BUILDER_CODE[bauer]` und dem Feld `code` des Katalogeintrags
  (dazu gehören `cesprites/catalog.py`, bei Requisiten und Bäumen `cesprites/props.py` und `render_all.py`),
- den Katalogeintrag aus `catalog3d.MODELS` und die Exporter-Version,
- die **aufgelösten Einträge des Sprite-Katalogs** für das Quell-Set und jedes Set, das das Modell bedient
  (Parameter, Kamera samt Blickwinkel, Markierungen …), dazu die Farbtabellen, die die Fahrzeug-Bauer lesen
  (`TRAFFIC_COLORS`, `METALLIC`, `PLAYER_COLORS`),
- bei Wahrzeichen deren eigene Quell-Revision statt der ganzen Datei `props_landmarks.py`.

Ändert sich im Sprite-Katalog ein Lack, ein Metallwert, eine Markierung oder ein Blickwinkel, wird genau das
betroffene Modell neu exportiert. `export_models.py --check-keys` prüft das (gemessen: 4 s): Es ändert die
Tabellen im Speicher und erwartet neue Schlüssel für genau die betroffenen Modelle. (Bis zur Korrektur nach der
Abnahme von Bauabschnitt 0 enthielt der Schlüssel nur Katalogeintrag und Code-Listen: Ein geänderter Lack ließ
alle Modelle „aus dem Cache“, und die veralteten Zwischenstände wurden gebacken.)

**Reproduzierbar (gemessen):** Ein erzwungener zweiter Export aller sechs Modelle ergibt byte-gleiche
Modellordner im Cache (auch die Cycles-Atlanten): `diff -r -x '*_report.json' <a> <b>` ist leer. Was sich von
Lauf zu Lauf ändert – die Zeiten – steht nicht in den Modellordnern, sondern in `_cache3d/export_report.json`
(Export) und `_cache3d/bake_report.json` (Bake). Zwei Bakes in denselben, jeweils leeren Ordner ergeben
byte-gleiche Dateien; die Modellordner gelöscht und neu gebacken ergeben wieder genau die eingecheckten
Dateien. Eine `.res`-Datei trägt keine UID (im Kopf steht −1), aber die Kennung ihrer inneren Ressource
(`local://ArrayMesh_<5 Zeichen>`) leitet Godot aus dem Zielpfad ab (gemessen: derselbe Pfad ergibt immer
dieselbe Kennung, ein anderer Ordner eine andere). Dasselbe Modell mit `--out` in einen *anderen* Ordner gebacken
unterscheidet sich deshalb im unkomprimierten Inhalt in genau diesen fünf Zeichen; weil die Dateien komprimiert
gespeichert werden, weichen sie selbst an vielen Stellen und manchmal in der Länge ab (gemessen: Laterne
4 395 und 4 394 Bytes in zwei Ordnern). Bytezahl und Hash in `model.json` gelten also für `assets/models`.

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
(`auto_lod`: Gebäude, Wahrzeichen) – und **nie für Netze mit Lampenkanälen**: Die Dezimierung verkleinert den
Lampenkopf der Laterne und entfernt ihn in den beiden gröbsten Stufen ganz (gemessen: Lampenfläche 2.911 →
2.440 → 1.484 → 0 → 0 cm²). Der Prüfer verlangt, dass jede automatische Stufe mindestens 80 % jeder
Lampenfläche behält. Für Gebäude greifen die automatischen Stufen bei der Vorgabe des Viewports
(`mesh_lod_threshold` 1 px) innerhalb der Sichtweite von 900 m gar nicht (abgeleitet aus den gespeicherten
Kantenlängen: Michel ab etwa 1,8 km, Bauernhaus ab etwa 10 km) – sie sparen erst Dreiecke, wenn der Renderer
die Schwelle anhebt.

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
| `COLOR.rgb` | Farbe als sRGB-Bytes; bei den Lampenkanälen die **leuchtende** Farbe – außer bei den beleuchteten *Flächen* 8 (Kennzeichen) und 14 (angestrahlte Fläche): Sie tragen ihre eigene Farbe |
| `COLOR.a` | Lackcode: 1.0 feste Farbe · 0.0 `paint` · 0.25 `paint2` · 0.5 `paint3` |
| `UV` | (Rauheit, Metall) |
| `UV2` | (Lampenkanal + 0.5, Gewicht 0..1) oder (−1, 0) |

Lampenkanäle: 0 Rücklicht · 1 Bremslicht · 2 Rück- + Bremslicht (Rücklicht beim Anteil `tail_level`: Vorgabe 35 %, im
Rennen 50 %) · 3/4 Blinker links/rechts · 5 Scheinwerfer · 6 Tagfahrlicht (mit Abblendlicht gedimmt) · 7 Rückfahrlicht
· 9 Umriss (folgt dem Rücklicht) · 10/11 Blaulicht A/B · 12 Lichter von Requisiten (`ce_night`) · 13 immer an. Eine
Lampe, die nicht leuchtet, wird mit einem Bruchteil des Anzeigewerts ihrer Leuchtfarbe hinter einer glänzenden Linse
gezeichnet: `lamp_off` für Fahrzeuglampen (Kanäle 0–11; Vorgabe 0,5 = 22 % des Lichts, im Rennen 0,28 – bei 0,5 wirkte
ein Rücklicht bei Tag eingeschaltet, Kunstkritik B1), `lamp_off_props` (0,5) für die Lampen der Requisiten (12, 13).
**Beleuchtete Flächen** behalten Farbe und Rauheit und bekommen ihr Licht dazu: 8 Kennzeichen (Farbe × Gewicht ×
Rücklicht × `plate_energy`) · 14 angestrahlte Fläche (Farbe × Gewicht × `ce_night` × `flood_energy`) · 15 rückstrahlende
Fläche (RINT-B: Konturband und Rückstrahler des Lkw – Farbe × Gewicht × `retro_energy` × der Kegel des eigenen
Abblendlichts an der Fläche, dasselbe Gesetz wie `inc/headlight.gdshaderinc`; außerhalb des Kegels nur die eigene
Farbe). (Als unbeleuchtete Lampe gezeichnet war das hintere Kennzeichen bei Tag beigegrau, das vordere weiß.)
Je Instanz (`set_instance_shader_parameter`, feste Indizes 0–6): `paint`, `paint2`, `paint3` (Farbe, Alpha =
Metallwert), `lamp_a` = (Rück, Brems, Blinker links, rechts), `lamp_b` = (Scheinwerfer, Rückfahr, Blaulicht A,
B), `fade` (Dither-Ausblendung, bleibt undurchsichtig), `sun` (0 im Tunnel).

**Lampenenergien** (Uniforms von `vpbr.gdshader`, über `ModernMaterials.set_class_parameter("vpbr", …)`
einstellbar): `lamp_energy` 1,0 = lineare Leuchtstärke einer Lampe bei vollem Wert (Rücklicht, Umriss);
`lamp_gain` = Faktoren darauf für (Bremse 2,2 · Blinker 1,6 · Scheinwerfer, Tagfahr- und Rückfahrlicht 2,0 ·
Blaulicht 2,0); `lights_energy` 4,0 (Kanal 12). Ein Rücklicht bleibt damit deutlich unter Weiß (Kanal 2: 35 %),
Bremsen ist ein großer Schritt: gemessen 2,63 × die Leuchtdichte des Rücklichts (Anzeige `#ff4641` gegen
`#9e0b00`). Eine Lampe über Weiß **behält ihren Farbton**: Ihre Farbe wird auf den größten Kanal normiert und je
Einheit Übersteuerung um `lamp_whiten` (4 %, höchstens 35 %) zu Weiß gezogen, statt Kanal für Kanal
abzuschneiden – ein Blinker zeigt Bernstein (`#ffa433`, Farbton 33°; bei dreifacher Übersteuerung war er
zitronengelb), ein Blaulicht Blau (`#4676ff`). Die Übersteuerung selbst bleibt in den Kanälen, die die Farbe der
Lampe tragen, damit ein Glow-Durchgang die Lampe weiter als heller als Weiß findet.
`tools/models_contact_sheet.sh x.png --channels` zeigt jeden Kanal an einem Prüfstreifen;
`tests/race3d/render/check_models.gd` prüft die Werte.

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
  `lights` (Anker: `role`, `pos`, `dir`, `size`, `color`), `paint` (Voreinstellung), `textures`, `roughness`,
  `impostor` (`texture`, `size_m`, `anchor_x`), `cards`, `auto_lod`, `tags`, `bytes`, `hash`.
  **Lichtanker** liegen *auf* ihrer Lampe: Der flächengewichtete Mittelpunkt einer gewölbten Lampengruppe läge
  darunter (gemessen 28 mm bei der um die Ecke laufenden Rückleuchte) – ein tiefengeprüftes Leuchtbild säße dort
  in der Karosserie. Der Exporter schiebt ihn entlang der mittleren Flächennormale auf die Lampe und schreibt
  diese Normale als `dir` (Einheitsvektor im Modellraum: wohin die Lampe schaut). `dir` fehlt bei Lampen
  gebackener Modelle (ihr Licht steckt im Nachtlicht-Atlas).
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
    ModelDB.request(["traffic/sedan_red"], ["lod0"], self)   # lädt im Hintergrund; ModelDB.pending() == 0 abwarten
    if not ModelDB.missing(["traffic/sedan_red"], ["lod0"]).is_empty():
        pass                                              # Datei fehlt oder ist defekt -> fail_reason "manifest"
    var mats := ModernMaterials.shared()                  # legt die ce_*-Globals an, lädt Shader erst dann
    var car := ModelFactory.build("traffic/sedan_red", "lod0", mats)     # Node3D: body, wheel_*, shadow
    ModelFactory.set_lamps(car, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0))
    var parts := ModelFactory.multimesh_parts("props/tree_oak", "lod1", mats)   # für MultiMesh-Ebenen
    ModelDB.release_all(self)                             # am Ende der Etappe: nur der eigene Anteil
```

- `ModelDB` ist **kein Autoload**; Arcade berührt es nie. `load_manifest(pfad)` lädt ein anderes Manifest
  (Tests). Die Funktion heißt nicht `reload`: `ModelDB.reload("…")` ruft in GDScript `Script.reload(keep_state)`
  der Skript-Ressource auf und erreicht eine statische Funktion dieses Namens nie.
- Modern-Shader nie mit `preload()` laden: Sie brauchen die `ce_*`-Globals, die erst `ModernMaterials` anlegt
  (nichts davon steht in `project.godot`).
- `ModelDB.lod_for_distance(model, meter, faktor)` wählt die Stufe; jenseits der letzten Netz-Stufe liefert sie
  `"impostor"` (`ModelDB.IMPOSTOR`), wenn das Modell ein Fernbild hat (`ModelFactory.build_impostor`), sonst
  bleibt die letzte Stufe.
- **Nie ein halbes Modell:** `ModelFactory.build()` liefert `null` und `multimesh_parts()` eine leere Liste, wenn
  das Set kein Modell hat, die Stufe fehlt oder **irgendein** Netz der Stufe (auch der Schattenwerfer) sich nicht
  laden lässt – der Aufrufer zeigt dann den Platzhalter. `ModelDB.missing(sets, stufen)` nennt die Dateien, die
  fehlen oder (nach dem Laden) defekt sind: Der Renderer fragt das am Ende von `prepare()` und meldet
  `fail_reason() = "manifest"`. Ein Manifest, dessen Einträge den falschen Typ haben (ein Set als Text, `lods`
  keine Liste von Wörterbüchern), gilt als Ganzes als ungültig. Eine leere Stufe `""` heißt in beiden Funktionen
  dasselbe: die eigene Stufe des Sets (`show` der Showroom-Sets), sonst `lod0`.
- **Eine `ModernMaterials`-Instanz je Prozess** – im Spiel `ModernMaterials.shared()`. `ModelFactory` setzt die
  Klassenmaterialien auf die geteilten Netze von `ModelDB`; zwei Instanzen überschrieben sich gegenseitig (ein
  mit der ersten gebautes Auto zeichnete mit den Materialien der zweiten). `set_global()` legt die Globals selbst
  an, falls noch niemand es getan hat.
- **Wer die Caches leert:** *Den Modus „Modern“ verlassen* (der Modus-Wechsel) heißt `ModelDB.release_all()`
  **und** `ModernMaterials.drop_shared()` (oder `clear()`): Die Materialien halten die Texturen, `release_all()`
  allein gibt keinen Texturspeicher frei (gemessen: 13,60 MB bleiben, bis die Materialien gehen; danach 9,01 MB
  wie vorher). Das Ende einer Etappe ist **nicht** „Modern verlassen“: `GameFlow` hängt die nächste Etappe ein,
  bevor die alte den Baum verlassen hat – ein bedingungsloses `release_all()` nähme der neuen ihre Anforderungen
  (`pending()` meldet 0, die Dateien laden dann beim ersten Gebrauch im Hauptthread). Ein Renderer gibt deshalb
  sich selbst mit: `request(sets, stufen, self)` und `release_all(self)` – die Caches gehen erst, wenn keine
  andere Besitzerin mehr da ist.

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
- **Karosserie der Spielerautos** (`carbody.SmoothCar(detail=…)`, alle mit Voreinstellung „wie im Sprite“):
  `conform` (aufgesetzte Flächen werden mit den Flächen der Karosserie darunter trianguliert und übernehmen deren
  Normalen), `graze`, `crease` (Unterschnitt unter der Schulterlinie), `arch_r` (Kantenradius der Radläufe),
  `arch_n` (Stationen je Radlauf in gleichen Winkeln), `gstep` (Stationsabstand der Kabine), `seam` (Breite der
  Fugen), `wheel_plain` (Reifen ohne Rillen), `ring_min`/`ends_n` (kleinste Punktzahl eines Querschnitts-Segments,
  Stationen der runden Enden – für die fernen Stufen der Verkehrsautos), `cap_sharp`, und
  **`lamp_depth`**: Mit einem Wert über 0 ist eine Lampe keine aufgesetzte Schicht mehr, sondern eine Mulde.
  `cardetail.lamp()` legt dann kein Gehäuse auf, versenkt Reflektor, Leisten und Leuchtkörper um die Tiefe der
  Einheit (`patch(…, sink=…)`, das Objekt trägt `ce_sink = "<Projektion>:<Tiefe>"`), legt die Streuscheibe bündig
  in die Öffnung und merkt sich die Kontur in `car.lamp_pockets`; der Exporter schneidet die Mulde in die
  Karosserie (`decalgeo.pocket`: Boden, Wände, Öffnung) und verschiebt den Lichtanker an die Oberfläche.
- **Seit der Nacharbeit (AS1R)**, alle mit Voreinstellung „wie im Sprite“: `bumper_clamp` (keine Station eines
  Stoßfängers jenseits seines Endes am Radlauf), `bumper_end_r` (Radius, mit dem das Stoßfängerende in die
  Karosserie läuft), `plate_bold` (Strichstärke der Kennzeichenzeichen), `tyre_lite` (Reifen mit 9 Profilpunkten,
  Verkehrsautos) in `carbody.DETAIL`; `chmsl_lamp` (Lampenkanal der dritten Bremsleuchte) in den Entwürfen von
  `vehicles.Car`.
- **Kühlergrill** (`player_cars.grille`): im Sprite derselbe Aufruf wie zuvor, im 3D-Bau eine Vertiefung mit
  versenkten Lamellen. **Nur im 3D-Bau** (`detail["extras"]`): eigene Blinkerfelder und Rückfahrlicht des
  Kompakten; die 3D-Lampenteile der Verkehrsautos stehen in `ce3d/traffic3d.py` (`CAR_3D`), nicht im Generator.

`check_sprite_geometry.py` baut jedes Sprite-Set (ohne zu rendern) und vergleicht Zählwerte, Hüllquader,
Positions-Hash, Topologie, Materialien und Builder-Angaben mit `fixtures/geometry_v070.json`. Die Fixture stammt
aus den unveränderten Generatoren von v0.7.0. Eine Besonderheit: Blenders UV-Kugel liefert ihre Flächen in jedem
Prozess in anderer Reihenfolge (auch in v0.7.0; betrifft die Kugel des Berliner Fernsehturms). Darum gibt es
neben `topo` die Felder `ctopo` (Polygone als Eckenzyklen, sortiert) und `nstat` (Summen der Normalen, mit
Toleranz); weicht nur `topo` ab, zählt das Set als identisch.
Gemessen nach allen Hooks (Stand Bauabschnitt 1): **187 von 187 Sets identisch** (eines davon mit anderer
Flächenreihenfolge), 346 s.

## 9. Ein Modell hinzufügen

1. Eintrag in `ce3d/catalog3d.py` (`builder`, `source` = Sprite-Set, `kind`, `sets`, Optionen).
2. Fehlende Marken und Detail-Hooks im Generator ergänzen; `check_sprite_geometry.py` muss „identisch“ melden.
3. Export, Bake, Import, Manifest (Abschnitt 1), dann `validate_models.py` und Kontaktbogen bei Tag und Nacht.
4. `showroom` erst nach dem A/B-Bild (`--showroom`) auf `true` setzen.

Der Prüfer bricht ab bei: Manifest ≠ Fragmente oder ≠ Dateien, Hash/Bytes falsch, fehlender `.import`,
unbekannter Klasse/Knoten/Stufe/Lichtrolle, Budget überschritten (Dreiecke, Zeichenaufrufe, Karten, Texturen),
Lackcode oder Lampenkanal neben seinem Wert (±0.02), Atlas-Koordinaten außerhalb 0..1, unkomprimierter Fläche,
Material im Netz, `object`/`extent_m` mehr als 2 % (mindestens ein halbes Sprite-Pixel) neben dem
Sprite-Manifest, Rad nicht auf dem Boden (±1 cm), Sprite-Set ohne Eintrag – und bei den **Lampenregeln**
(Regel 9 des Bauplans: Lichter und Blinker sind das, worauf der Spieler reagiert):

| Regel | Grenze |
|---|---|
| Fahrzeuge, jede Stufe: projizierte Fläche von hinten (nach der Wicklung der Dreiecke) | Rücklicht ≥ 200 cm², Bremslicht ≥ 100 cm², **jeder Blinker ≥ 60 cm²** |
| … von vorn | Scheinwerfer ≥ 80 cm², jeder Blinker ≥ 40 cm² (Spielerauto ≥ 15 cm²: es ist im Rennen nie von vorn zu sehen) |
| eine gröbere Stufe zeigt höchstens 2 × (+ 5 cm²) die Lampe der feineren | die nahe Stufe darf nicht die kleinste Lampe haben |
| jede automatische (dezimierte) Stufe | behält ≥ 80 % jeder Lampenfläche |
| Lichtanker | höchstens 3 mm unter seiner Lampe, `dir` ein Einheitsvektor, der nicht in die Lampe zeigt |
| Wicklung | höchstens 8 Dreiecke einer `vpbr`- oder `baked`-Fläche und des Schattenwerfers zeigen gegen ihre Normalen |

`tests/race3d/check_models.gd` lässt den Prüfer in jedem Lauf von `tools/run_tests.sh` laufen (gemessen 1,7 s
samt dem Fall „defekte Netzdatei“).

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

Fahrzeuge: Stand nach der Nacharbeit AS1R (Abschnitt 13); die übrigen Zeilen aus Bauabschnitt 0.

| Modell | Dreiecke je Stufe | Aufrufe | Netze | Texturquellen | Export | Bake |
|---|---|---|---|---|---|---|
| `player/limousine` | lod0 44 095 · show 94 629 · Schatten 2 320 | 6 / 6 | 1 527 819 B | – | 13,3 s | 0,07 s |
| `player/kompakt` | lod0 47 524 · show 100 332 · Schatten 2 320 | 6 / 6 | 1 661 802 B | – | 13,2 s | 0,10 s |
| `traffic/sedan` (4 Farbsets) | lod0 17 555 · lod1 5 809 · lod2 1 149 · Schatten 972 | 6 / 1 / 1 | 271 351 B | – | 2,3 s | 0,02 s |
| `traffic/hatch` (5 Farbsets) | lod0 17 636 · lod1 5 661 · lod2 1 180 · Schatten 988 | 6 / 1 / 1 | 270 561 B | – | 2,2 s | 0,02 s |
| `traffic/wagon` (4 Farbsets) | lod0 17 464 · lod1 5 941 · lod2 1 141 · Schatten 940 | 6 / 1 / 1 | 276 055 B | – | 2,5 s | 0,02 s |
| `traffic/truck` (4 Lackierungen) | lod0 18 084 · lod1 4 672 · lod2 1 490 · Schatten 476 | 13 / 1 / 1 | 161 851 B | – | 1,0 s | 0,02 s |
| `props/tree_oak` | lod0 1 220 (420 Karten) · lod1 459 (140) · Schatten 179 · Fernbild | 2 / 2 / 1 | 53 072 B | 373 558 B | 2,2 s | 0,01 s |
| `props/farmhouse` | lod0 104 | 1 | 2 586 B | 752 795 B (1024², Nachtlicht 512²) | 58 s | 0,01 s |
| `props/streetlight` | lod0 312 (keine automatische Stufe) | 1 | 4 395 B | – | 0,1 s | < 0,01 s |
| `landmarks/michel` | lod0 3 024 | 1 | 63 648 B | 377 301 B (2048² WebP, Nachtlicht 1024²) | 329 s | 0,02 s |

Zusammen: Netze 4,18 MB (davon die sechs Fahrzeuge 4,07 MB), Texturen 4,59 MB im Grafikspeicher, Quellen
1,43 MB. Der Export des Michel besteht fast
ganz aus dem Cycles-Bake des 2048er-Atlas (980 Karten). Die Sprite-Geometrieprüfung aller 187 Sets dauert etwa
6 Minuten (2 Prozesse). Alle Zeiten sind auf dieser VM gemessen, während drei andere Läufe die vier Kerne
mitbenutzten (2 Prozesse, `nice`): Sie schwanken von Lauf zu Lauf um etwa 10 %.

Lampenflächen (gemessen mit `inspect_models.gd`: projizierte Fläche aus der Blickrichtung der Regel in
Abschnitt 9, nach der Wicklung der Dreiecke, cm² je Fahrzeug bzw. je Seite bei den Blinkern):

| Modell, Stufe | Rücklicht | Bremslicht | Blinker hinten l / r | Scheinwerfer | Blinker vorn l / r |
|---|---|---|---|---|---|
| `player/limousine` lod0 / show | 874 / 869 | 830 / 827 | 84 / 84 · 81 / 80 | 89 / 89 | 20 / 20 · 20 / 19 |
| `player/kompakt` lod0 / show | 914 / 899 | 900 / 890 | 102 / 102 · 100 / 100 | 101 / 102 | 28 / 27 · 27 / 27 |
| `traffic/sedan` lod0 / lod1 / lod2 | 639 / 847 / 887 | 759 / 967 / 1 007 | 99 / 99 in jeder Stufe | 161 / 242 / 327 | 95 / 95 / 86 |
| `traffic/hatch` lod0 / lod1 / lod2 | 727 / 902 / 965 | 846 / 1 021 / 1 084 | 95 / 95 in jeder Stufe | 195 / 273 / 360 | 112 / 100 / 95 |
| `traffic/wagon` lod0 / lod1 / lod2 | 973 / 1 188 / 1 031 | 1 093 / 1 308 / 1 081 | 102 / 102 in jeder Stufe | 171 / 250 / 316 | 95 / 90 / 50 |
| `traffic/truck` lod0 / lod1 / lod2 | 860 in jeder Stufe | 860 | 450 / 450 | 1 000 | 320 / 320 |

Die Blinker der Pkw haben in allen drei Stufen dieselbe Fläche, weil sie mit derselben Kontur eingeschnitten sind.
Rück- und Bremslicht wachsen zu den groben Stufen hin, weil dort die schwarzen Lampenringe und die schmalen
Chromleisten wegfallen (erlaubt: höchstens 2 × + 5 cm²). Lichtanker: Verkehrsautos höchstens 3,5 mm von ihrer
Lampe, Spielerautos bis 33 mm (der Anker liegt in der Öffnung der Mulde, die Leuchtkörper bis 28 mm dahinter).

### Ehrliche Einordnung gegen die Cycles-Sprites

- **Spielerautos (Limousine, Kompakt):** Form, Fugen, Lampen und Räder stimmen mit den Sprites überein; das
  Echtzeit-Modell hat mehr Modelldetail als das Sprite (durchsichtiges Glas mit Innenraum, Lampen und Grill mit
  Tiefe, Wischer, Antenne, Kennzeichenrahmen). Im A/B-Bild aus der Showroom-Kamera bleibt es trotzdem hinter dem
  Sprite zurück – wegen Lack und Licht, nicht wegen des Netzes: Der Lack ist greller und gleichmäßiger (keine
  weichen Spiegelungen der Umgebung, kein Klarlack-Fresnel), es fehlen Kontaktschatten und Umgebungsverdeckung in
  Radhäusern und Fugen, Felgen und Chrom spiegeln nur eine Farbe. `showroom` bleibt deshalb bei beiden `false`,
  bis der Lackshader (R3) und das Showroom-Licht stehen; danach genügt die eine Zeile im Katalog.
- **Verkehrsautos (Limousine, Schrägheck, Kombi):** dieselben Maße, Fenster und Lampen wie die Sprites, aber eine
  straffere Karosserie (Abschnitt 13). Die Lampen sind eingeschnittene, ebene Felder ohne Streuscheibe und Tiefe;
  das Heck ist eine fast senkrechte Fläche; Glas dunkel und spiegelnd, kein Innenraum. Die Blinkerfelder (rund
  95–100 cm² je Seite) gibt es nur im 3D-Entwurf – das Sprite zeigt dort den schmalen Streifen. `lod2` hat
  dreieckige Radausschnitte mit sechseckigen Rädern – gedacht für mehr als 120 m.
- **Sattelzug:** Zugmaschine und Koffer mit lesbarem Heck. Alle vier Lackierungen sind derselbe Koffer – eine
  Plane (Rot, Grün im Sprite) gibt es nicht. Das Fahrerhaus ist ein Profilkörper mit eingeschnittenen Scheiben
  (keine gewölbte Front), kein Innenraum.
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

- Spielerautos haben durchsichtiges, getöntes Glas und einen dunklen Innenraum (Abschnitt 13); die Verkehrsautos
  behalten dunkles, spiegelndes Glas ohne Innenraum (Budget 18 000 Dreiecke, ein Zeichenaufruf für die Karosserie).
- Die abgewandten Wände werden nicht per UV-Spiegelung wiederverwendet; stattdessen ergänzt der Generator
  (`allround`) Fenster auf der Rückseite, die eigene Atlasfläche bekommen.
- Laub nimmt den Schatten der Sonne nur zu einem Viertel an (sonst verschattet die Schattenhülle die Krone).
- Aufgesetzte Details der Verkehrsautos sind in die Karosserie geschnitten (eine Lage, kein Flimmern) – auch
  bei `lod1`/`lod2`, dort mit weniger Teilen.
- Komprimierte Netze melden immer ein Tangenten-Array (mit den Normalen gepackt, kostet keine Bytes).
- Die Lampenkanäle 10, 11, 13 und 14 benutzt noch kein Modell (die Anstrahlung des Michel steckt in seinem
  Nachtlicht-Atlas); Kanal 9 (Umrissleuchten) und die Lackcodes `paint2`/`paint3` trägt der Sattelzug. Der
  Prüfstreifen (`--channels`) zeigt alle 15 Kanäle, die Render-Prüfung `check_models.gd` schaltet die Lackcodes
  an einem Prüfnetz durch.
- Die Klasse `baked_cutout` benutzt noch kein Referenzmodell (sie kommt erst mit den Stadthäusern und
  Wahrzeichen aus `props_cities`/`props_landmarks`): Material und Prüfer kennen sie, der Weg vom Generator bis
  ins Bild ist dafür noch nicht einmal ganz durchlaufen worden.
- Eingeschnittene Teile folgen seit Bauabschnitt 1 in jeder Stufe ihrer eigenen Kontur (Abschnitt 13); der Prüfer
  misst weiterhin die Fläche jeder Lampe, nicht ihre Form – die Form zeigt nur der Stufenbogen (`--review`).
- Eine Lampe leuchtet nur auf ihrer eigenen Fläche. Gerechnet (nicht gemessen) mit der Brennweite von 711 px
  bei 1280 × 720: Die 0,61 m lange Leuchte der Laterne ist ab etwa 430 m kürzer als ein Bildpunkt, eine 25 cm
  breite Rückleuchte ab etwa 180 m. Jenseits davon trägt nur der Schein (Glow) oder ein Lichtpunkt des Renderers
  an den Ankern aus `lights` – für Fahrzeuge verlangt das die Fairness-Regel F6, für Laternen sieht der Bauplan
  bisher nur leuchtende Geometrie vor (offen für die Renderer-Abschnitte). Die Laterne hat keine automatische
  Stufe mehr: Sie hätte die Leuchte auf wenige Dreiecke verkleinert.

## 13. Fahrzeuge des Bauabschnitts 1

| Modell | Builder | woraus |
|---|---|---|
| `player/limousine`, `player/kompakt` | `player` (`ce3d/vehicles3d.py`) | `cesprites.player_cars` in den Stufen `PLAYER_DETAIL` (`lod0`, `show`), dazu `ce3d/extras3d.py` (dritte Bremsleuchte, Kennzeichenrahmen mit zwei Leuchten, Dachantenne, Scheibenwischer) und `ce3d/interior3d.py` (Sitze, Kopfstützen, Armaturenbrett, Lenkrad links, Hutablage, Verkleidung) |
| `traffic/sedan`, `traffic/hatch`, `traffic/wagon` | `car` (`ce3d/traffic3d.py`) | Karosserie aus den Lofts von `carbody.SmoothCar`, gespeist aus den Entwurfstabellen `cesprites.designs` (`smooth_design`); Fenster, Lampen, Kennzeichen, Griffe und Fugen aus den Decal-Listen von `vehicles.Car`, als Geometrie eingeschnitten |
| `traffic/truck` | `heavy` (`ce3d/truck3d.py`) | eigener Aufbau mit den Maßen von `cesprites.heavy`: Zugmaschine und Kofferauflieger |

Die Sprite-Generatoren `vehicles.Car` und `heavy` werden dafür **nicht** gebaut, nur gelesen: Ihre groben Lofts
knitterten in `lod1`/`lod2`, die Stoßfänger stachen durch die Karosserie. Die Verkehrsautos haben deshalb dieselben
Maße, Fenster und Lampen wie ihre Sprites, aber eine straffere Form (Schulterlinie, ausgestellte Radläufe mit
Innenkotflügel, abgesetzte Stoßfänger, Schweller) und Felgen mit fünf Speichen und Bremsscheibe.

### Eingeschnittene Flächen (`ce3d/decalgeo.py`)

Ein Decal ist eine Kontur in einer Projektionsebene (hinten/vorn: x–z, Seite: y–z, oben: x–y). `Tris.apply`
schneidet jede Kontur mit einer Delaunay-Triangulierung mit Zwangskanten (`mathutils.geometry.delaunay_2d_cdt`) in
die Dreiecke der Karosserie – eine Lage, nichts kann flimmern, und die Kontur ist in **jeder** Stufe dieselbe
Linie. Dazu gehört:

- **Ende an der Rundung:** Ob eine Fläche zu einer Projektion gehört, entscheidet die geglättete Normale. Vor dem
  Schnitt teilt `split_level` jedes betroffene Dreieck entlang der Linie, auf der diese Normale die Schwelle
  kreuzt – die Fenster enden an einer glatten Linie statt an den Zacken des Netzes.
- **Nichts geht verloren:** Splitter-Dreiecke in der Projektion werden nicht geschnitten (die Bibliothek meldet
  einen Splitter als Quelle jeder Ausgabefläche), jedes Teilstück muss in seinem Dreieck liegen, ein Dreieck wird
  nur ersetzt, wenn seine Teile es zu 98,5 % decken, und `car_surfaces` bricht ab, wenn sich die Oberfläche einer
  Projektion um mehr als ein paar cm² ändert.
- **Reihenfolge:** Der Rang eines Decals kommt aus der vollständigen Liste, nicht aus der gefilterten der Stufe;
  Blinker liegen immer oben (sonst deckte in `lod1` das Rücklicht den Blinker zu).
- **Stufen:** `lod1` lässt dünne Decals und die schwarzen Lampenringe weg, `lod2` zusätzlich Seitenteile der
  Leuchten, Rückfahrlicht, Tagfahrlicht und Schwellerteilung; die Scheiben von `lod2` sind nach der
  Flächennormale gefärbt. Rücklicht, Bremslicht, Blinker und Scheinwerfer behalten ihre Kontur.
- **Kennzeichen in allen Stufen** (`far_plate`): `lod1` und `lod2` zeigen es im Mittelwert des `lod0`-Kennzeichens
  samt Zeichen und Euroband (`#c4c4c1`), `lod2` behält es. (Weiß ohne Zeichen sprang es bei 40 m heller und
  verschwand bei 120 m – der hellste Punkt des Autos.) Der dunkle untere Teil des Heckstoßfängers wird in `lod2`
  auf das Heckende geschnitten (`far_sill`; nicht beim Schrägheck: 68 Dreiecke, `lod2` hätte 1 248 statt 1 200).

### Stufen, die nicht knittern

`lod1`, `lod2` und der Schattenwerfer sind dieselben analytischen Lofts mit weniger Stationen und Ringpunkten
(`TRAFFIC_DETAIL` in `ce3d/lod.py`), kein dezimiertes Netz. `core.transfer_normals` gibt den groben Lofts die
Normalen von `lod0` (die feine Fläche, die der groben am ähnlichsten sieht), `core.flatten_ends` lässt die flachen
Endkappen in die runden Enden übergehen. Der Prüfer hat eine neue Regel: Der Hüllquader jeder Stufe darf von dem
der feinsten Stufe höchstens um `BOUNDS_TOL_M` abweichen (Pkw 3 cm, Spielerauto 2 cm, Lkw 5 cm).

### Glas und Innenraum

`glass.gdshader` (Aussehen; `fade`, `sun` und `light()` unverändert): vormultipliziertes Alpha
(`blend_premul_alpha`), die Spiegelung wächst mit dem Fresnel-Term (`fresnel_boost` 0,85, `mirror` 0,75), die
Tönung kommt aus der Vertexfarbe. Spielerautos: Scheiben mit Deckkraft 0,36, Streuscheiben 0,10, klare 0,08;
dahinter Sitze, Kopfstützen, Armaturenbrett, Lenkrad und Hutablage. Die Kabine wird dafür geöffnet
(`_open_cabin`): die Scheiben aus dem Loft geschnitten, die Innenseite verkleidet – mit einem groben zweiten Loft
der Kabine (`_lining_loft`: halbe Punktzahl, 2,2-facher Stationsabstand; Kompakt 1 378 statt 4 112 Dreiecke).
Der Innenraum der Rennstufe samt Verkleidung bleibt unter 6 000 Dreiecken (§4.6.9); der Export bricht sonst ab
(gemessen: Limousine 3 560, Kompakt 3 658). Wanne und Armaturenbrett halten Abstand zu den Rädern, auch zu einem
um 25° eingeschlagenen Vorderrad (`interior3d.wheel_houses`); die Hutablage folgt der Außenhaut (`outer_z`) – ihre
Ecke stand beim Kompakten als schwarzes Blatt über den Rückleuchten aus der Schulter.

Verkehrsautos: undurchsichtiges Glas, aber heller, glatter und leicht metallisch (`TRAFFIC_GLASS`: `#2a343e`,
Rauheit 0,02, Metall 0,25), damit der Himmel sich spiegelt; `lod1`/`lod2` zeichnen es als `vpbr` mit denselben
Werten.

### Schattenwerfer

Die Karosserie wirft keinen Schatten, eine grobe Hülle tut es für sie (`ModelFactory`: nur Schatten). Steht die
Hülle irgendwo aus der Karosserie heraus, liegt die Karosserie dort im Schatten ihres eigenen Werfers – beim
Kompakten als dunkle Schraffur hinter dem vorderen Radlauf sichtbar (die Sehne der groben Hülle über der Kehle
hinter dem ausgestellten Radlauf, gemessen 7,9 mm). `core.tuck_inside` zieht die Hülle deshalb 12 mm unter die
Außenhaut von `lod0` (Stichproben an Ecken, Kantenmitten und im Inneren jedes Dreiecks; Radhäuser und nach unten
blickende Flächen zählen nicht). Die Radtrommeln des Werfers sind nur die innere Hälfte des Reifens: Eine Kappe in
der Ebene der Reifenflanke lag vor der Felge, die dann nie Sonne bekam. Der Export bricht ab, wenn die Hülle
eines Pkw danach nicht mindestens 6 mm unter der Haut liegt; gemessen (Exportbericht, `levels.shadow`): vorher
7,1–30 mm außerhalb (Spielerautos; 30 mm = der Grund des Grills), nachher 12,0 mm innerhalb. Der Prüfer
(`validate_models.py`) misst das noch nicht; der Kontaktbogen zeigt es (`--caster`: Werfer rot über dem Modell,
rot ist, was aus der Hülle ragt).

- Die Hülle wird **nach** dem Einschneiden der Lampen- und Grillmulden eingezogen: Vorher stand sie vor deren
  Grund (Mulden bis 30 mm tief) und verschattete ihn.
- Die Radläufe des Werfers sind offen wie die der Karosserie (Verkehr `arch_n` 6, Spielerautos mit Stationen an den
  senkrechten Kanten der Öffnung): Eine geschlossene oder grob angedeutete Öffnung lag über den Rädern und warf
  ihren Schatten auf sie.
- Der Lkw-Werfer ist der Koffer, das Fahrerhaus nach seinem Profil und darunter nur, was wirklich da ist
  (Stoßfänger, Kotflügel, Tritt- und Batteriekästen, Tanks, Rahmen), alles 3 cm innen, dazu die Trommeln. (Ein
  Kasten über die ganze Breite unter dem Fahrerhaus und eine Platte unter dem ganzen Auflieger ragten aus der Hülle.)

### Sattelzug

- Knoten in `lod0`: `tractor/body`, `tractor/wheel_0l|r` (gelenkt), `tractor/wheel_1l|r` (Zwillingsräder),
  `trailer/body` (Ursprung des Netzes = Königszapfen, `pos` = Königszapfen im Modell), `trailer/wheel_0…2 l|r`.
  `lod1`/`lod2`: ein Netz `body`. Das Fragment trägt zusätzlich
  `"groups": {"tractor": {"pivot": [0, 0, -3.1]}, "trailer": {"pivot": [0, 1.19, -3.7]}}` – die Drehpunkte, um die
  ein Renderer Zugmaschine und Auflieger knicken kann. `ModelFactory` wertet `groups` noch nicht aus.
- Lack: `paint` = Koffer, `paint2` = Fahrerhaus, `paint3` = Streifen und Schriftzug. Die vier Farbsets sind
  dasselbe Netz mit anderen Lackwerten (bei Rot und Grün ist `paint3` = `paint`: kein Streifen).
- Heck: Türen mit Rahmen und Gestängen, rote Konturmarkierung, zwei rote Umrissleuchten oben (Kanal 9, mit
  Lichtanker `marker`), Leuchtenträger mit Blinker, Rück-/Bremslicht und Rückfahrlicht je Seite,
  Dreieckrückstrahler, Kennzeichen, Unterfahrschutz, Schmutzfänger.
- **Rückstrahlende Markierung** (Kontur hinten, gelbes Band an den Seiten, Dreieckrückstrahler): Kanal 14
  (`flood`, Gewicht 0,8) – bei Tag ihre eigene Farbe, bei Nacht leuchtet sie mit `ce_night` (das Licht der
  Scheinwerfer des Spielers, bis der Renderer eine echte Rückstrahlung hat). Als Kennzeichen-Fläche (Kanal 8:
  Rücklicht × `plate_energy` 0,45) blieb die Kontur nachts fast dunkel – sie ist das Nachtmerkmal eines Lkw.
- Fast weiße Lackierungen (alle Kanäle über 85 %) werden auf `#d8d8d6` begrenzt (`truck3d._tone`): Weißer Lack wirft
  etwa 80 % des Lichts zurück; `#ececea` erschien in Echtzeit als reines Weiß ohne jede Form.

### Nacharbeit nach der Kunstkritik (AS1R)

Was die unabhängige Kritik der ersten Fassung fand und was am Modell geändert wurde (Lack, Belichtung und
unbeleuchtete Lampen sind Sache des Renderers, siehe unten):

| Befund | Ursache | Änderung |
|---|---|---|
| Rücklicht nachts nur dünne Lichtleiter | Leuchtenkörper Kanal 2 mit Gewicht 0,5: 0,35 × 0,5 = 17,5 % | Gewicht 1,0 (`cardetail._LAMP3D_TAIL`); die ganze Leuchte glimmt, Bremse bleibt ein großer Schritt |
| Kompakt: Stoßfänger 52 mm im Vorderreifen | Die Stationen der vorderen Endrundung (r_plan + 5 cm) reichten über das Stoßfängerende hinaus: der Loft lief 9 cm in den Radlauf | Hook `bumper_clamp` |
| Stoßfänger als aufgeklebter Kasten mit flacher Endkappe | Loft endet senkrecht am Radlauf | Hook `bumper_end_r` (5 cm): das Ende läuft rund in die Karosserie |
| Kompakt: schwarzer Keil über den Rückleuchten | die Ecke der Hutablage stand aus der gerundeten Schulter | Hutablage folgt der Außenhaut |
| Wanne im Reifen (bis 77 mm, verdeckt) | Boden und Türverkleidung liefen durch die Radhäuser | Wanne und Armaturenbrett mit Abstand zu den Rädern |
| Bremsscheibe wie polierte Kugel | gedrehter Kasten, glatt schattiert | harte Kanten (30°), Gusseisen matt |
| Limousinen- und Verkehrsfelgen hellsilber | im Sprite spiegelt das Metall das dunkle Radhaus: anthrazit | Felgenfarbe wie im Sprite |
| Kennzeichen und Fugen flimmern | dünne Zeichen auf reinem Weiß, Fugen 7 mm | Kennzeichen hellgrau, Zeichen kräftiger (`plate_bold`), Fugen 8 mm |
| Innenraum Kompakt 6 268 > 6 000 | Verkleidung = die volle Kabine | grober Verkleidungs-Loft, Export-Wächter |
| Dritte Bremsleuchte der Limousine ohne `dir` | geschlossener Kasten: Normalen heben sich auf | nach hinten blickende Fläche; Prüfer verlangt `dir` bei Fahrzeugen |
| Verkehr: dritte Bremsleuchte als roter Balken bei Tag | unbeleuchtet = halbe Leuchtfarbe | dunklere Leuchtfarbe (`chmsl_lamp`), mit Bremsverstärkung 2,2 leuchtet sie trotzdem voll |
| Verkehr: Stufensprung bei 40/120 m | Kennzeichen hell bzw. weg, Spiegel lackfarben, Heck unten | Kennzeichen grau in allen Stufen, Spiegelglas in allen Stufen, dunkler Heckabschluss in `lod2` |
| Verkehr: glattes Heck, schwebender Auspuffring | – | Kofferraum-/Heckklappenfugen, Emblem, Auspuff als dunkles Rohr |
| Lkw: Kontur nachts dunkel, Weiß ohne Form, Werfer ragt heraus | siehe „Sattelzug“ und „Schattenwerfer“ | Kanal 14, `#d8d8d6`, Werfer aus Teilen |

Gemessen (Spielkamera, Tag, Anteil der Autopixel, die sich beim Stufenwechsel um mehr als 24 Stufen ändern):
40 m `lod0` → `lod1` 6,6–9,8 % (vorher 6–11 %), 120 m `lod1` → `lod2` 22–34 % (vorher 24–38 %). Der Rest bei
120 m ist die grobe Kabine und der grobe Querschnitt von `lod2` (Budget 1 200 Dreiecke).

**Was die Modelle vom Renderer brauchen** (nicht im Modell lösbar): unbeleuchtete Fahrzeuglampen dunkler
(`lamp_off` etwa 0,25–0,3 statt 0,5 – rot und bernstein wirken bei Tag sonst eingeschaltet), Lackbelichtung ohne
Übersteuern (Kompakt-Gelb, Weiß), Klarlack mit Spiegelung, Kontaktschatten, Schein an den Lichtankern (F6).

### Diagnose

`CE_STATS=1` vor dem Export druckt je Stufe die Dreiecke je Objekt (Spielerautos) und je Projektion die Zahl der
Konturen und Dreiecke vor und nach dem Schnitt. Auf die Dateien hat die Variable keinen Einfluss.
Kontaktbogen: `--clay` (alles grau, Glas unsichtbar: Stufen, Blätter, Dellen), `--caster` (Schattenwerfer rot),
`--review --views=17,18` (Vorderrad, Radhaus), `--views=19,20` (Heck bei Nacht aus Kamerahöhe).


## 14. Umgebung des Schnitts (Bauabschnitt 2)

Was ein Spieler auf den ersten 75 km von Kiel nach Hamburg sieht, gezählt mit dem `Track`-Generator der Etappe
(alle Segmente bis km 75, Richtung ab Kiel): Eiche 147, Birke 88, runder
Busch 76, Heuballen 48, Windrad 28, Zapfsäule 9, Bauernhaus 7, Blitzer 2, Tankstelle 1 und die Preissäule der
Tankstelle (ein `object`, das kein Sprite-Set hat: Sache des Tankstellen-Builders). Jedes dieser Sets hat jetzt
ein Modell – auf diesem Abschnitt steht kein Sprite-Platzhalter mehr. Dazu kommen die Modelle, die die Strecke erst
später oder anderswo zeigt: niedriger Busch, Scheune, Windmühle, Strommast, Laterne, Leitpfosten, Zollhäuschen,
und die Bodendecker für die Innenseite von Kurven.

| Modell | Bauer | Dreiecke je Stufe | Aufrufe | Texturen |
|---|---|---|---|---|
| `props/tree_oak`, `tree_oak_b` | `tree` | lod0 1 490 / 1 520 · lod1 679 / 755 · Schatten 179 / 235 · Fernbild | 2 / 2 / 1 | Blätter 1024², Fernbild |
| `props/tree_birch`, `tree_birch_b` | `tree` | lod0 1 880 / 1 910 · lod1 591 / 644 · Schatten 154 / 177 · Fernbild | 2 / 2 / 1 | Blätter 1024², Fernbild |
| `props/bush_round`, `bush_round_b`, `bush_low` | `bush` | lod0 372 / 372 / 384 · lod1 88 / 88 / 104 | 1 / 1 | Blätter 512² |
| `props/cover_bush`, `cover_grass` | `bush`, `grass` | lod0 182 / 42 · lod1 54 / 12 | 1 / 1 | 512² |
| `props/farmhouse` | `building` | 1 107 | 2 | Atlas 1024² |
| `props/barn`, `windmill`, `customs_booth`, `fuel_station` | `building` | 290 · 1 640 · 206 · 1 480 | 2 | 1024² · 1024² · 512² · 1024² |
| `props/haybale`, `fuel_pump`, `radar_camera`, `delineator` | `building` (ein Atlas) | 672 · 384 · 328 · 12 | 1 | 512² · 512² · 256² · 128² |
| `props/wind_turbine` | `prop_vpbr` | 744 | 1 | – |
| `props/streetlight` | `prop_vpbr` | 274 (Bauabschnitt 0: 312) | 1 | – |
| `props/power_pylon` | `lattice` | 220 | 1 | Ausschneide-Atlas 1024² |

Alle Zahlen gemessen (`validate_models.py --report`); Exportzeiten auf dieser VM: Bäume 5–7 s, Büsche unter 1 s,
Gebäude 20–175 s (Cycles: Farbe in doppelter Auflösung plus Umgebungsverdeckung; je nach Last der VM – das
Bauernhaus brauchte allein 92 s, neben einem zweiten Export-Prozess 173 s), Straßenmöbel mit Atlas 3–53 s,
Strommast 2 s. Alle 21 Requisiten neu exportiert (`--force`, zwei Prozesse), gebacken und importiert: 369 s,
danach keine Datei verändert (byte-identisch, gemessen). Die Gebäude und Straßenmöbel haben nur `lod0`: Ihre Netze tragen Lampenkanäle, und eine
automatische Stufe darf es dann nicht geben (die Dreieckszahlen sind ohnehin klein).

### Kartenbäume (`ce3d/veg3d.py`, `ce3d/leafatlas.py`)

- **Krone:** Die Kugeln der Sprite-Krone (`props_nature.CROWN_LOG`) bleiben die Form. Auf ihrer Außenhaut liegen
  viele kleine, flache Laubkarten (Eiche bis 450, 1,5–2 m); Karten, die in einer anderen Kugel lägen, werden
  woanders hingelegt (man sähe sie nie). Gemessen schlechter: Zeltkarten (die Mitte angehoben) kräuseln sich an der
  Silhouette wie Papier, gekreuzte Kartenpaare ziehen Schlieren, wo eine Karte flach angeschnitten wird. Karten
  liegen nie waagerecht (die Neigung nach oben wird gestaucht): eine waagerechte Karte oben in der Krone sah von der
  Straße aus wie ein Strich.
- **Licht in der Krone:** Die Helligkeit jeder Karte ist ihre Verdeckung durch die übrigen Kugeln (14 Strahlen über
  der Halbkugel ihrer Normale) – innen und unten dunkler. Die Normale ist zu 55 % die Richtung aus ihrer eigenen
  Kugel: Jeder Klumpen hat eine Licht- und eine Schattenseite wie im Cycles-Sprite.
- **Holz:** Stamm und Äste des Generators, dazu ein Ast in jeden Laubklumpen (k-Means der Kugeln, 9 bei der Eiche,
  7 bei der Birke); Astenden, die aus der Krone ragen, fallen weg. Der Birkenstamm wird mit einem Ring alle 25 cm
  neu gebaut und bekommt die schwarzen Marken als Farbe **je Dreieck** (der Verschweißer teilt keine Ecke zwischen
  zwei Farben, die Marken bleiben scharf; als Farbe je Ecke verschmierten sie über die langen Dreiecke).
- **Kern:** eine geschlossene, dunkle Hülle (Klasse `leaves`, ein deckendes Feld des Atlas) – durch die Krone sieht
  man nie den Himmel. Jedes Dreieck des Kerns ist unverzerrt in sein Atlasfeld gelegt (eine Abwicklung um die
  Hochachse verzog die Blätter zu Streifen).
- **Blatt-Atlas:** 4 × 4 Felder (Büsche 2 × 2), 15 Blattbüschel und der Kern. Ein Büschel ist eine Kuppel: die
  Blätter in der Mitte liegen oben und sind heller, die am Rand dunkler; eiförmige, gesägte (Birke) oder gelappte
  (Eiche) Blätter, 4-fach überabgetastet.
- **Halo-Alpha (mipmap-fest):** Godot baut die Mipmaps mit einem Kastenfilter; ein dünnes Blatt fällt dabei unter
  die Schwelle (0,42), die Krone wird mit der Entfernung licht. Jedes durchsichtige Texel bis 2 Texel neben einem
  Blatt bekommt Alpha 0,28: in voller Größe unsichtbar (auch nach der BC3-Quantisierung: deren Alphastufen sind 1/7
  des Blockumfangs – ein Wert von 0,36 kam als 0,43 heraus), in den gemittelten Texeln der kleineren Stufen hält es
  ein Blatt über der Schwelle, solange es 20 % statt 42 % des Texels deckt. Gemessen (Anteil der Texel über der
  Schwelle je Mipmap-Stufe, Eichenbüschel): 0,443 · 0,460 · 0,478 · 0,489 · 0,535.
- **Stufen ohne Sprung:** gemessen mit `tools/models/prop_scene.sh --mode=lods` (mittlere Farbe und Pixelzahl
  des Baums an der Umschaltentfernung): Eiche lod0/lod1 bei 60 m (60,103,32) / (59,103,31), 11 980 / 12 314 px;
  lod1/Fernbild bei 200 m (67,111,37) / (63,107,35), 1 093 / 1 018 px. Birke lod1/Fernbild (112,154,64) /
  (111,154,67), 342 / 367 px. Dafür sind die Karten von `lod1` um 6 % aufgehellt (`LOD1_LIFT`: durch die größeren
  Karten sieht man mehr vom dunklen Kern), das Fernbild hat den Faktor 1,27 und ein blaues Plus von 25 %
  (`IMPOSTOR_TINT`: beleuchtete Karten spiegeln den Himmel, das Bild nicht).
- **Varianten:** `tree_oak_b`, `tree_birch_b`, `bush_round_b` sind derselbe Generator mit anderem Samen
  (Katalog `variant_of`, Parameter `seed`); sie haben keine eigenen Sets, das Set der Art nennt sie in `variants`.
  Der Requisiten-Builder wählt je Stück eine Variante, eine Drehung und die Größe der Szenerie-Regel.
- **Wind:** Ausschlag nach Höhe (Karten, Kern), Phase und Steifheit je Karte (`leaves.gdshader`); Büsche schwanken
  mit 45 % des Ausschlags. Schnee und Nässe bietet `leaves.gdshader` noch nicht an (Abschnitt „Offen“).

### Büsche und Bodendecker

Büsche (`bush`) bestehen nur aus der Klasse `leaves` (ein Zeichenaufruf, Budget 400 / 120 Dreiecke): Karten auf den
Kugeln des Generators und ein kleiner Kern (ein großer zeigte sich als flache dunkle Scheiben zwischen den Karten).
**Bodendecker** für die Innenseite von Kurven (Nachtrag A-3, höchstens 0,5 m): `props/cover_bush` (Strauch-Polster
1,5 × 1,2 × 0,45 m, aus der Kronenfunktion des Generators) und `props/cover_grass` (Grasbüschel 1,0 × 0,9 ×
0,42 m, sieben Büschel aus je drei gekreuzten Halmkarten). Ihre Sets heißen wie die Modelle und gibt es nur in
Modern: Im Manifest tragen sie `"modern_only": true`, der Prüfer und `test_model_db.gd` erlauben sie ohne
Sprite-Set (nur mit Modell). Der Requisiten-Builder setzt sie anstelle weggelassener Vegetation ein.

### Gebäude mit Tiefe (Bauer `building`, `ce3d/props3d.py`)

- **Öffnungen statt gemalter Fenster:** Der Generator meldet die Fensterraster und Dekore jeder Fassade
  (`props_buildings.WINDOW_LOG`, Voreinstellung `None`: das Sprite merkt nichts). Der Bauer schneidet jedes Fenster
  und jede Tür (ein großes Dekor in Türfarbe, das auf dem Boden steht) mit einer Delaunay-Triangulierung mit
  Zwangskanten in die Wand (`mathutils.geometry.delaunay_2d_cdt`; sie füllt nur gegen den Uhrzeigersinn gegebene
  Umrisse – im Uhrzeigersinn kam eine Wand ohne ein Dreieck zurück). Dazu: Laibung 12 cm tief (gebacken, mit
  Umgebungsverdeckung), Rahmen mit Sprosse und Kämpfer, Sohlbank, Scheibe. Innenflächen (die Rückseite des
  Giebels unter dem Dach) und Wände, die nicht entlang einer Achse stehen (der achteckige Mühlenturm), bleiben
  unberührt.
- **Scheiben leuchten nachts über Kanal 12:** Eine `vpbr`-Lampe zeigt bei Tag die Hälfte ihrer Leuchtfarbe – eine
  helle Leuchtfarbe machte die Fenster tagsüber gelb. Darum ist die Leuchtfarbe ein dunkles Warm (`#7a5e3a`) mit
  hohem Gewicht (0,55–0,9): bei Tag dunkles Glas mit warmem Vorhang, nachts warmes Licht. Welches Fenster leuchtet,
  entscheidet der Anteil `lit` des Rasters (wie die Lichtebene des Sprites), fest je Fenster. Lampen an Wänden
  verlieren die Seite, die in die Wand zeigt: so liegt ihr Lichtanker vorn auf der Lampe und hat eine Richtung
  (mit allen Seiten hoben sich die Normalen auf, der Anker lag mitten im Kasten).
- **Dachrinnen, Fallrohre, Kappen:** halbrunde Rinnen unter den beiden längsten Traufen jedes Dachs, Fallrohre mit
  Knick an die Wand und bis zum Boden; eine Abdeckplatte auf jedem Schornstein. Alles in der Klasse `vpbr`.
- **Umgebungsverdeckung im Atlas:** `bake.bake_atlas(ao=…)` backt mit Cycles die Verdeckung (Atlasgröße, eine
  Bodenplatte darunter) und multipliziert die Farbe mit `floor + (1 − floor) · ao^gamma` (Bauernhaus: 0,42 …
  1, Abstand 1,6 m, Mittel 0,84). Sie wird zuletzt gebacken: Ihr eigener Bildknoten wird in jedem Material aktiv,
  die Nachtlicht-Ebene danach landete sonst im falschen Bild. Ein Nachtlicht-Atlas, in dem nach dem Ausschneiden
  nur noch Krümel leuchten (unter 5 % am hellsten Texel), wird nicht ausgeliefert.
- Zwei Flächen (`baked` + `vpbr`, Budget Landgebäude: 2 Aufrufe), **kein `auto_lod`** (Lampenkanäle). Textur-
  dichte der Straßenseite: 35 px/m (Bauernhaus), 1 024² mit Gewichten nach Sichtbarkeit; `allround` gibt
  Bauernhaus (Rückgiebel) und Tankstellenladen (Seiten, Rückseite) Fenster auf allen Seiten.
- **Straßenmöbel mit einem Atlas** (Zapfsäule, Blitzer, Leitpfosten, Heuballen; Budget ein Zeichenaufruf):
  derselbe Bauer ohne Öffnungen und mit `vpbr_lamps=False` – ihre Lampen bleiben im Nachtlicht-Atlas.
- **Tankstelle:** vier Lampenfelder unter dem Dach (Kanal 12 mit Lichtankern nach unten: Lichtpfützen auf der
  Fahrbahn), der Lichtschleier des Sprites ist ein Sprite-Effekt (Knoten `none`). **Scheune:** Torrahmen und
  Streben als Bretter 5 cm vor der Wand (`boards3d`).

### Rotoren (Windrad, Windmühle)

Die Teile, die sich drehen, tragen im `vpbr`-Format den **Lackcode 0,875** und in `UV2.y` die Nabenhöhe / 128 m
(`props3d.ROTOR_CODE`, `ROTOR_HUB_M`; Windrad 89,6 m, Windmühle 19,8 m). Seit der Zusammenführung von M1 dreht
`vpbr.gdshader` sie in `vertex()` um die Z-Achse des Modells durch (0, Nabenhöhe) mit `ce_time` (1,35 rad/s, von der
Straße aus im Uhrzeigersinn, Phase je Instanz; docs/renderer-modern.md §12.5, Render-Prüfung `rotor`). Der Prüfer
kennt den Code.

### Laterne: der Lichtanker schaut nach unten

Die Linse der Laterne (ein flaches Ellipsoid) hängt zur Hälfte im Leuchtenkopf. Geschlossen hoben sich ihre
Normalen auf, und die Regel für geschlossene Fahrzeuglampen (die Hälfte, die von der Fahrzeugmitte wegschaut)
gab dem Anker die Richtung (−0,965; 0,261; 0): zur Seite und leicht nach oben – Lichtschein und Pfütze neben
der Lampe. Die Option `hidden_tops` des Bauers `prop_vpbr` entfernt die nach oben schauenden Flächen der
genannten Objekte (Normale z > 0,3; man sieht sie nie, der Kopf deckt sie): Der Anker liegt jetzt auf der
Unterseite der Linse (9,17 m) und schaut nach unten, `dir` (0,007; −1; 0) (gemessen). 274 statt 312 Dreiecke.

### Strommast: das Fachwerk im Ausschneide-Atlas (Bauer `lattice`)

Der Generator meldet sein Gerüst (`props_road.PYLON_LOG`: Ebenen, halbe Breiten, Ausleger, Isolatoren, Spitze).
Statt tausender Balken von 9 cm (bei 100 m 0,6 px breit: sie flimmern und zerfallen) zeichnet der Bauer jede
Turmseite je Abschnitt, Boden und Schrägen jedes Auslegers und die Spitze als Fläche mit eingezeichneten Streben
in einen RGBA-Atlas (Klasse `baked_cutout`, Schwelle 0,5; die vier Seiten eines Abschnitts teilen sich ein Bild).
Isolatorketten sind sechseckige Prismen. 220 Dreiecke, ein Zeichenaufruf – der erste Lauf der Klasse
`baked_cutout` vom Generator bis ins Bild, mit Schatten. Mipmap-fest wie das Laub: Streben mindestens 2,5 Texel,
Halo 3 Texel mit Alpha 0,33. Gemessen (Anteil deckender Texel je Stufe, Stufe 0 = 7,3 %): ohne Halo hält Stufe 4
55 % und Stufe 5 3 %, mit 2 Texeln 74 % / 17 %, mit **3 Texeln 84 % / 26 %**, mit 4 Texeln 106 % / 40 % (aber
Stufe 3 schon 143 %: zu fette Streben auf 50–100 m). Die Streben sind 1,3-mal so breit wie die Balken des
Generators und dunkler: vor hellem Himmel liest sich das Fachwerk bei 250 m noch als Gitter.

### Neue Hooks (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `props_buildings.WINDOW_LOG` | `facade()` | meldet Raster, Dekore, Rahmen, Glas, Anteil `lit` jeder Fassade |
| `boards3d` | `barn()` | Torrahmen und Streben als Bretter vor der Wand |
| `lights3d`, `allround` | `props_road.fuel_station()` | Lampenfelder unter dem Dach; Fenster an Seiten und Rückseite des Ladens |
| Knoten `none` | `fs_haze` (Tankstelle) | der Lichtschleier gehört nur zum Sprite |
| `hub_subdiv` | `wind_turbine()` | Unterteilung der Nabe (Sprite 3, Modell 2) |
| `props_road.PYLON_LOG` | `power_pylon()` | meldet das Gerüst (Ebenen, Breiten, Ausleger, Isolatoren, Spitze) |

`check_sprite_geometry.py --only props/` nach allen Hooks (gemessen): **86 von 86 Sets identisch**, 118 s
(die übrigen Generatoren importieren aus `props_buildings` nur `obj_size`, das unverändert ist).

### Werkzeug: `tools/models/prop_scene.sh`

Modelle neben einer Straße durch die Spielkamera (3,4 m, Brennweite 711 px, Horizont bei 45 %), Tiefennebel wie
im Rennen, die Stufe nach Entfernung wie im Requisiten-Builder: `--mode=dist` (Ausschnitte bei 15/40/100/250 m),
`--mode=lods` (Stufen an den Umschaltentfernungen nebeneinander, mit gemessener mittlerer Farbe und Pixelzahl),
`--mode=road` (ein ganzer Straßenrand). Varianten ohne eigenes Set sind erreichbar.

### Ehrliche Einordnung

- **Bäume:** deutlich feiner als die Sprites (Blätter, Äste, Stamm, Birkenrinde), dunkler und natürlicher; von
  nahem (unter 25 m) wirkt die Krone unruhig, es gibt noch einzelne flach angeschnittene Karten als dunkle Schliere.
  Die Klumpen sind weicher als die scharf schattierten „Blumenkohl“-Kugeln der Cycles-Sprites.
- **Gebäude:** echte Tiefe (Fenster, Tür, Rinnen, Kappen, Verdeckung) – das gemalte Bauernhaus aus Bauabschnitt 0
  ist ersetzt. Scheune und Zollhäuschen haben hinten keine Öffnungen; der Mühlenturm behält gemalte Fenster.
- **Bodendecker:** Gras ist bei 15 m nur 20 px hoch und liest sich als hellgrüner Fleck.

### Offen (für die Shader- und Renderer-Pakete)

- `leaves.gdshader`: Schnee (aufwärts gerichtete Karten weißen mit `ce_snow`) und Nässe (dunkler, glänzender mit
  `ce_wet`); ein Ausblenden flach angeschnittener Karten nach der Kartennormale bräuchte eine zweite Normale.
- Requisiten-Builder: Leitungen zwischen Strommasten. (Rotordrehung und Bodendecker in den Kurven-Korridoren sind
  mit der Zusammenführung von M1 erledigt.)

## 15. Gebäude, Brückenteile und Schiffe (Bauabschnitt 5, AS4)

Die übrigen Land- und Stadtgebäude, die Brückenteile und die Schiffe der Sprite-Sets haben jetzt Echtzeit-Modelle:
Kirche, Fabrik, Haus mit Läden, Wohnblock A und B, Altstadthaus mit Treppengiebel, Ladenhaus, Büroturm,
Brückenlaterne, Pylon der Schrägseilbrücke, Fachwerkportal, Hausboot und Fähre; die Windmühle von Bauabschnitt 2 hat
echte Fensteröffnungen bekommen. Damit hat jedes Requisiten-Set außerhalb von `city_*`, den Wahrzeichen und der
Vegetation ein Modell.

| Modell | Bauer | Kategorie | Dreiecke lod0 / lod1 | Aufrufe | Atlas | px/m zur Straße | Licht nachts |
|---|---|---|---|---|---|---|---|
| `house_med` | `house` | Land | 1 343 / 761 | 2 | 1024² + Licht | 59,9 | Fenster |
| `church` | `house` | Land | 1 740 / 1 284 | 2 | 1024² + Licht | 30,0 | Fenster, Uhren, Turm-Flutlicht |
| `factory` | `house` | Land | 1 624 / 1 108 | 2 | 1024² + Licht | 29,5 | Hallenfenster, Oberlichter, Werkszeichen, Schlotlicht |
| `windmill` | `house` | Land | 1 928 / – | 2 | 1024² + Licht | 31,2 | Fenster |
| `houseboat` | `house` | Land | 1 054 / – | 2 | 1024 × 512 | 37,3 | Fenster, Türlampe |
| `ferry_ship` | `house` | Land | 1 449 / – | 2 | 1024² + Licht | 12,2 (Modell; im Spiel ×1/0,33–0,45) | Kabinen, Bullaugen, Decklampen, Positionslichter |
| `building_shop` | `house` | Stadt | 1 107 / 779 | 2 | 1024² + Licht | 44,2 | Fenster, Schaufenster, Schild mit Zeichen |
| `building_oldtown` | `house` | Stadt | 2 328 / 1 576 | 2 | 1024² + Licht | 40,7 | Fenster, Arkaden |
| `building_block_a` | `house` | Stadt | 4 596 / 3 156 | 2 | 2048 × 1024 + Licht | 49,0 | Fenster |
| `building_block_b` | `house` | Stadt | 5 180 / 3 476 | 2 | 2048 × 1024 + Licht | 44,0 | Fenster, Läden |
| `building_tall` | `house` | Stadt | 2 565 / 2 513 | 2 | 2048 × 1024 + Licht | 29,8 | 293 von 840 Scheiben, Foyer mit Pfosten |
| `bridge_lamp` | `lantern` | Möbel | 882 / – | 1 | – (vpbr) | – | 3 Laternen mit Ankern |
| `bridge_pylon` | `pylon` | Mast | 232 / – | 1 | 1024² + Licht | 31,7 (Fuß) | Flugbefeuerung (Anker) |
| `bridge_pylon_bare` | `pylon` | Mast (nur Modern) | 120 / – | 1 | 1024² + Licht | 31,7 (Fuß) | Flugbefeuerung (Anker) |
| `bridge_truss_arch` | `truss` | Möbel | 1 100 / – | 1 | 1024 × 512 + Licht | 28 (Bild) | 2 Hängelampen mit Ankern |

Gemessen mit `validate_models.py --report` und dem Export-Bericht (Stand nach der Nacharbeit AS4R, unten); alle
Budgets eingehalten (Land 2 000 Dreiecke, Stadt 10 000, Möbel 1 500, Mast 5 000; zwei bzw. ein Zeichenaufruf je Stufe).

### Bauer `house` (`ce3d/buildings3d.py`)

Der Gebäudebauer von Bauabschnitt 2 (`props3d.py`, unverändert – die Schlüssel aller bisherigen Modelle bleiben
gleich) hat einen Nachfolger in einem eigenen Modul:

- **Öffnungen:** Fenster aus den Rastern des Generators (`WINDOW_LOG`), auch mit Rundbogen. Das Bogenpolygon
  umschreibt den gemalten Kreis (sonst blieben zwischen den Sehnen Streifen des gemalten Fensters – und nachts seines
  Lichts – auf der Wand). Laibung (gebacken, mit Verdeckung), Rahmen als Ring zwischen Umriss und Innenumriss,
  Sprossen je Fensterart (`bars`: Sprossenfenster der Fabrik 4 × 4, Oberlicht der Läden), Sohlbank, Scheibe. Ob
  eine Öffnung in ein anderes Volumen führen würde (der Turm steht vor dem Kirchenschiff), entscheidet ein Strahl
  entlang der Wandnormale (`Cover`), nicht mehr ein Hüllquader.
- **Licht der Scheiben:** seit AS4R aus dem Nachtlicht-Atlas – die Scheibe ist der zurückgesetzte Lochfüller, bei Tag
  das gemalte Glas des Sprites, nachts das Licht des Sprites für genau dieses Fenster × 0,55: warmes (Wohnungen),
  kaltweißes (Fabrikhalle) oder hellweißes Licht (Läden). (AS4 hatte Kanal-12-Lampen; unbeleuchtet zeigten sie die
  halbe Leuchtfarbe – braune Scheiben neben blauen, siehe „Nacharbeit“ unten.)
- **Fensterläden** (Haus): Tafeln 3 cm stark, 1 cm vor der Wand, mit Lamellen im Atlas (gebacken).
- **Schallluken** (Kirchturm, `louvre`): schräge Lamellen vor einer dunklen Rückwand.
- **Uhren** (Kirchturm, Dekore mit `clock`): Zifferblatt als angestrahlte Fläche (Kanal 14: bei Tag seine Farbe,
  nachts beleuchtet), Rahmen, Stundenmarken, Zeiger.
- **Türen:** Flügel in der Farbe des Dekors mit Füllungen und Fuge, Stufen davor; Tore über 2,6 m Breite mit
  waagerechten Rippen (Fabrik).
- **Dachrinnen und Fallrohre** an die eigenen Wände (`gutters.walls`), **Flutlicht** des Kirchturms (`flood`:
  Materialkopie, deren Lichtebene die Wandfarbe mit der Höhe abklingend hinzufügt – im Nachtlicht-Atlas).
- **Werkszeichen** (`sign`): auf einer Tafel ein Zahnrad zwischen zwei Balkenpaaren (`logo: "gear"`), nachts
  beleuchtet (Kanal 14). Bewusst spiegelsymmetrisch: Die Fabrik trägt `mirror_left`, der Requisiten-Builder spiegelt
  sie am linken Fahrbahnrand (D24) – ein Schriftzug („WERK 2“ in der ersten Fassung) stand dort in Spiegelschrift.
  Für Schilder, die nie gespiegelt werden, kann `sign` weiter Text setzen (`text`, Buchstaben aus
  `cesprites.textgeo`).
- **Vorhangfassade** (Büroturm, `curtain`): die Wände werden ersetzt durch Brüstungsbänder (gebacken, aus dem
  Material des Turms), zurückgesetzte Scheiben je Achse und Geschoss (seit AS4R einfarbige Atlasfelder im Glasverlauf
  des Sprites, ein Drittel leuchtet nachts) und Lisenen; Eckpfosten schließen die Ecken.
- **lod1** ohne Feinteile (Sprossen, Sohlbänke, Rinnen, Lamellen, Marken, Geländerstäbe): ab der ersten
  Umschaltentfernung des Requisiten-Builders (40 / 60 / 120 m je Detailstufe). Sprossen von 4,5 cm sind dort unter
  einem Pixel und würden nur flimmern. Damit das Fenster beim Umschalten nicht dunkler wird (ohne Ersatz wurden die
  Wohnblöcke bei 60 m um 8/255 dunkler), bekommt lod1 statt Rahmen und Sprossen **einen breiteren Rahmenring mit
  derselben Fläche** (`_far_inset`): gleiche mittlere Farbe bei Tag (gemessen: höchstens 2/255 Unterschied), nachts
  derselbe Anteil leuchtender Scheibe. Was bleibt, sind die Sprossenkreuze, die beim Umschalten verschwinden (bei 60 m
  ändern sich bei den Wohnblöcken 4,5–5,2 % der Pixel um mehr als 24/255). Die Seiten der Lisenen des Büroturms
  bleiben in lod1 (streifend gesehen verdecken sie das Glas einer Seite; ohne sie änderten sich 18 % der Pixel).

**Bake mit Lochfüllern.** Die Öffnungen werden vor dem Bake geschnitten. Würde man die Löcher im Atlas einfach
auffüllen (Dilatation), stünde dort die Farbe des gemalten Rahmens – in den kleineren Mipmap-Stufen umgab dann ein
heller Saum jedes Fenster (bei 60 m deutlich, auf der Rückseite mit geringerer Texeldichte schon näher). Darum wird
jedes Loch für den Farb-Bake mit einer Füllfläche geschlossen (eine Kopie des Fassadenmaterials): Im Atlas steht in
der Öffnung das gemalte Fenster des Sprites, die Mipmaps mitteln Wand und Fenster richtig. Seit AS4R behält der
Füller eines Fensters das Licht des Sprites und wird nach Farb- und Licht-Bake in die Laibung zurückgesetzt – er ist
die Scheibe; die Füller von Türen und Schallluken werden vor der Umgebungsverdeckung gelöscht.

### Brückenteile (`ce3d/bridges3d.py`)

Die Generatoren stehen in `cesprites/props_cities.py` (Stadtpakete) und bleiben unverändert: Die Bauer lesen die
Balken des Generatornetzes zurück (`boxes()`: Achse, Enden, Querschnitt jedes Kastens).

- **Pylon** (Bauer `pylon`, Kategorie Mast: ein Zeichenaufruf): Beton, Kopf, Ankerplatten und Flugbefeuerung in
  einem Atlas; der Pylon ist in drei Höhenbänder geteilt (eine 82 m lange Karte begrenzt den Atlas auf 12 px/m), und
  die Texeldichte folgt der Höhe (`band_w` 1 / 0,6 / 0,45: der Fuß neben der Fahrbahn bekommt 29,9 px/m, der Kopf,
  den man erst aus 100 m und mehr sieht, 13,4 px/m; vorher überall 21,8 px/m). Die
  Seile sind vierseitige Prismen, deren Dreiecke alle ein einfarbiges Feld des Atlas lesen. Seit AS4R: Bein
  senkrecht, sieben Seile je Seite bis zur Deckkante innerhalb 36 m, eine Stufe (siehe „Nacharbeit“ unten). Die
  Flugbefeuerung hat einen Lichtanker mit Richtung (Fernglühen der Flare-Ebene).
- **Fachwerkportal** (Bauer `truss`, Straßenmöbel: ein Zeichenaufruf): Gurte, Pfosten, Sockel und Querriegel als
  Geometrie; Streben und Knotenbleche jeder Ebene als gezeichnetes Ausschneidebild (Streben ≥ 2,5 Texel, Halo 0,33 –
  mipmap-fest wie der Strommast) auf einem Streifen aus Vierecken um das Fachwerk. Die beiden Hängelampen leuchten
  nachts und haben Lichtanker nach unten (Lichtpfützen auf der Fahrbahn).
- **Brückenlaterne** (Bauer `lantern`, ein Zeichenaufruf): eine unbeleuchtete vpbr-Lampe zeigt die halbe
  Leuchtfarbe – das Milchglas war bei Tag hellbraun. Die Seiten des Glases sind angestrahlte Fläche (Kanal 14: hell
  bei Tag, leuchtend bei Nacht), nur die nach unten schauenden Flächen sind Lampen (Kanal 12) mit den drei
  Lichtankern.

### Schiffe

- **Fähre:** Das Sprite zeigt ihre Steuerbordseite (`view_yaw` 90°). Das Modell ist um −90° gedreht: Die
  Breitseite schaut zum anfahrenden Spieler, der Bug nach +X (wie im Sprite rechts). Hook `lowpoly3d` in
  `props_road.ferry_ship` (Rumpfstationen nur, wo sich der Querschnitt ändert; Rettungsboote mit weniger Flächen;
  Decklampen als Würfel). Die vielen Kabinenfenster bleiben gemalt (nachts im Nachtlicht-Atlas), Rumpf und Aufbauten
  sind in Stücke von höchstens 82 m geschnitten (Atlas-Karten). Decklampen und die drei Positionslichter leuchten
  ohne Anker: Ein Signallicht beleuchtet kein Deck, und die Anker einer Rolle bekommen in `roles.lights()` die Farbe
  ihrer ersten Lampe (die weißen Toplichter warfen grüne Lichtflecken).
- **Hausboot:** Seine Wände kommen aus `props_cities.wallmat`, das kein Fensterlog schreibt. Während das Modell
  gebaut wird, wird die Funktion von außen umhüllt (`_log_city_walls`): Ihre Raster gehen als Rechtecke ins Log.
  Das ausgeschnittene Geländer (Stäbe von 3 cm) ist als Pfosten und Holme neu gebaut, die Topfpflanzen sind dezimiert
  (Budget Landgebäude).

### Neue Hooks (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `allround` | `church`, `house_med`, `factory`, `building_block_a/b`, `building_oldtown`, `building_shop` | Rückseiten mit Fenstern (Haus, Laden: Tür), Kirchturm mit Schallluken und Uhren rundum, Rückgiebel des Altstadthauses; gemalte Splitter (Kirchenschiff, oberste Reihe von Block B) und das Tor über zwei Fenstern der Fabrik bereinigt |
| `gable3d` | `building_oldtown` | Treppengiebel als ein Prisma (seine Fenster lassen sich schneiden) |
| `win3d` | `windmill` | keine gemalten Fenster (das Raster liegt über einer Ecke des Achtecks); der Bauer schneidet Öffnungen in die Mitte der Flächen |
| `lowpoly3d` | `props_road.ferry_ship` | weniger Rumpfstationen, einfachere Rettungsboote und Decklampen |

`check_sprite_geometry.py --only props --jobs 1` auf dem Endstand: 86 von 86 Sprite-Sets identisch (0 verändert,
0 Fließkomma-Rauschen), `CHECK sprite_geometry OK` – alle Hooks lassen die Sprites unverändert.

### Ehrliche Einordnung

- **Gut:** Haus, Kirche, Fabrik, Altstadthaus und die Wohnblöcke haben echte Tiefe (Laibungen, Rahmen, Sprossen,
  Sohlbänke, Türen mit Stufen, Rinnen und Fallrohre, Läden) und halten Farbe und Proportion des Sprites; nachts
  leuchten die Fenster unregelmäßig, Kirchturm und Fabrik haben ihr eigenes Licht. Der Stufenwechsel ändert die
  mittlere Farbe um höchstens 2/255. Fachwerkportal und Laterne sind je ein Zeichenaufruf mit Lichtankern.
- **Noch nicht gut:** Die **Fähre** ist das schwächste Modell – Kabinenfenster und Bullaugen sind gemalt (12 px/m im
  Modellmaß), Aufbauten flach; das Budget „Landgebäude“ (2 000 Dreiecke) lässt für ein 182-m-Schiff nicht mehr zu.
  Der **Pylon** hat die feste Höhe des Sprites (Arcade passt ihn der Brücke an) und am Kopf nur 13 px/m. Bei den
  Wohnblöcken verschwinden beim Umschalten die Sprossenkreuze (4,5 % bzw. 5,2 % der Pixel bei 60 m). Das gemalte
  Fenster im Rückgiebel der Kirche ist unscharf (abgewandte Seiten haben ein Viertel der Dichte).
- **Fehlt:** Wasser unter Hausboot und Fähre (R5); Vordächer und Schornsteine, wo die Sprites keine haben; Messungen
  auf echter Grafikkarte und Steam Deck.

### Nacharbeit nach der Kunstkritik (AS4R)

Die unabhängige Kunstkritik von AS4 fand einen Fehler, der nicht in den Testbuild durfte (die Seile des Pylons in
den Fahrspuren), und Schönheitsfehler, die man stundenlang sieht. Alle Zahlen gemessen auf Software-OpenGL.

- **Pylon.** Die Seile des Generators endeten bei Modell-x −4,2 m: bei der Aufstellung 7,55 m neben der Mitte
  0,4 m **innerhalb** der Fahrbahn, 0,6 m über dem Belag, und ihr Fächer (±82,7 m) reichte bis zu 42 m vor die Brücke.
  Jetzt steht das Bein senkrecht und 0,9 m weiter außen (Fuß und Sockel enden an der Deckkante, Modell-x −1,3 m), und
  `fan_cables` (`ce3d/bridges3d.py`) baut sieben Seile je Seite neu: vom Kopf (55–79 m) zur Deckkante (Achse bei
  x −1,15 m, 1,1 m hoch; Arcade zeichnet sie bis x −1,4 m), als Halbfächer ohne Kreuzung (der höchste Anker läuft am
  weitesten), höchstens 36 m vor und hinter dem Pylon. 36 m passen auf jede Schrägseilbrücke des Netzes (fünf
  Brücken; Platz vom Pylon bis zum nächsten Brückenende mindestens 40,5 m bei Elisabeth- und Vanšu-Brücke,
  Köhlbrandbrücke 70,5 m). Eine Stufe mit 0,32 m starken Seilen (vorher 0,28 / 0,34 m: der Wechsel änderte 58 % der
  Pixel). `extent_m` bleibt der Wert des Sprites (aus dem Generatornetz; der Pylon wird nicht kantenbündig gestellt).
  Neu: **`props/bridge_pylon_bare`** (Set nur für Modern, von keiner Etappe gestellt) – derselbe Pylon ohne Seile für
  einen Renderer, der die Seile je Brücke aus `height_m` und `cables` zeichnet wie `RoadRenderer._pylon()`.
- **Fensterscheiben.** Die Scheiben waren `vpbr`-Lampen (Kanal 12); unbeleuchtet zeigt eine Lampe die halbe
  Leuchtfarbe: bei Tag braune Scheiben neben blauen, am Büroturm ein Schachbrett. Jetzt ist die Scheibe der
  **Lochfüller des Fensters**, nach dem Farb- und dem Licht-Bake um die Laibungstiefe zurückgesetzt
  (`_settle_fillers`): Bei Tag zeigt sie das gemalte Glas des Sprites, ein wenig zum Himmel getönt (`PANE_TINT`, wie
  die Spiegelung der früheren Glasscheiben) und ohne Umgebungsverdeckung (`_pane_mask`); nachts das Licht des Sprites
  für **genau dieses Fenster** × `PANE_LIGHT_K` (0,55) aus dem Nachtlicht-Atlas – es leuchten dieselben Fenster wie in
  Arcade. Der Atlas wird nicht größer (die Füller lagen schon darin). Scheiben ohne gemaltes Fenster dahinter
  (Vorhangfassade, Mühlenfenster) sind einfarbige Atlasfelder (`Patches`).
- **Fabrik.** Die „weißen Dreiecke“ über dem Sheddach waren die senkrechten Glasbänder der Sheds (2,8 × 22 m, Licht
  #cfe0ff × 0,9 → reinweiß), gesehen über der Schräge des nächsten Sheds – keine verdrehten Flächen (geprüft: alle
  Normalen zeigen nach außen). Die Verglasung hat jetzt Sprossen alle 1,4 m und einen Kämpfer (`_skylight`), ihr Licht
  ist auf 30 % gesenkt und nimmt nach oben auf die Hälfte ab.
- **Büroturm.** Die Scheiben der Vorhangfassade sind Atlasfelder im Glasverlauf des Sprites (sechs Stufen, bei Tag für
  alle Scheiben gleich); welche leuchten, entscheidet ein gut streuender Hash je Seite, Geschoss und Achse (der alte
  bildete Spalten); das Foyer leuchtet mit 20 % (`light_scale`) und hat Pfosten und einen Kämpfer davor.
- **Ladenhaus.** Auf dem Schild steht ein Zeichen aus Geometrie: eine Einkaufstasche zwischen zwei Balken,
  spiegelsymmetrisch (das Set wird links gespiegelt), nachts beleuchtet (Kanal 14); das Schild selbst leuchtet mit
  25 % (nachts war es ein weißer Kasten).
- **Kirche:** Putz `#ccc6b7` statt `#e8e1d0` (Hook `plaster`; im Rennlicht war die Wand 13 % heller als das Sprite).
  **Fachwerkportal:** Streben im Ausschneidebild 1,2× breiter und 15 % dunkler, der Stahl 15 % dunkler als
  `STEEL_GREEN` des Sprites (`steel` `#49585a`; Sonne und Himmelslicht machen das Modell heller und blauer als das
  vorbeleuchtete Sprite). Bei 100 m hat es jetzt den Kontrast des Sprites; bei 400 m bleibt es blasser – die dünnen
  Streben verlieren in den kleinen Mip-Stufen Deckung (Alpha-Test), das ist keine Frage der Farbe mehr.
- **Windmühle:** unverändert. Das „Flimmern der Flügel“ der Kritik war vor allem Drehung: Die Messung verschob das
  Modell in Viertelpixel-Schritten, und der `vpbr`-Rotor nimmt seine Phase aus der Weltposition (0,37 rad je Meter) –
  bei 120 m dreht sich der Flügel dabei um 1,1 Pixel je Schritt. Mit bewegter Kamera und stehendem Modell flimmert
  die Mühle 1,3- bis 1,7-mal so stark wie das Sprite statt 2- bis 3-mal (Tabelle unten) – der Rest ist echte
  Kantenunruhe der Gitterflügel. Weniger und dickere Sprossen (7 × 0,13 m statt 13) änderten daran nichts (gemessen)
  und sind verworfen.

MESSUNGEN_AS4R

**Nicht im Modell lösbar** (an die Renderer-Pakete): Fähren und Hausboote stehen ohne Wasser auf der Wiese (R2:
Requisiten mit `h` < 0 auslassen, bis R5 Wasser hat); die Höhe des Pylons folgt nicht `height_m` der Brücke (50–120 m,
das Modell hat 88,8 m), und gerade Seile folgen keiner Kurve (bei R 449 m liegt ein Seilende bis 1,4 m neben der
Deckkante – auf dem Seitenstreifen, nicht in der Fahrbahn); die Phase der Rotoren hängt an der ursprungsrelativen
Weltposition und springt bei jedem Versatz des Ursprungs (alle 2 km).
