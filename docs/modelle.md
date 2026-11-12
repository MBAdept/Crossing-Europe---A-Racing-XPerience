# Echtzeit-Modelle – Pipeline für den Grafikmodus „Modern“

Der Modus „Modern“ zeichnet echte 3D-Modelle statt Sprites. Die Modelle entstehen aus **denselben
prozeduralen Generatoren** wie die Sprites (`tools/blender/cesprites`, siehe [sprites.md](sprites.md)): Die
Generatoren haben dafür Schalter („Hooks“) bekommen, deren Voreinstellung exakt das Sprite-Modell von v0.7.0
ergibt. Kein Modell wird von Hand gebaut oder importiert. Der Modus „Arcade“ benutzt nichts von alledem.

Stand: erste Zusammenführung von M2 (M2INT) – jedes Fahrzeug-Set hat ein Modell (Spielerautos und Verkehrsautos
aus Abschnitt 15, Sattelzüge, Busse und Polizei aus Abschnitt 16, die Nacharbeit in Abschnitt 17), dazu Vegetation
und Natur (Abschnitt 18) und ländliche Gebäude, Stadthäuser, Brückenteile und Schiffe (Abschnitt 19); die
Stadthäuser der Stilfamilien (`props/city_*`) und die Wahrzeichen außer dem Michel sind noch Arcade-Bilder.
Zahlen mit „gemessen“ stammen von der
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
tools/models_contact_sheet.sh <bild.png> [--only=<glob>[,<glob>..]] [--night] [--showroom] [--channels] [--lods=lod0,show]
        [--tile=480x320] [--cols=4] [--sun=x,y,z] [--sun-energy=<e>] [--ambient-energy=<e>]
        [--review [--views=0,4,..] [--set=<Set>]] [--chase=9,30 [--lane=<m>] [--day] [--arcade]] [--clay] [--caster]
        [--look=race|neutral] [--tonemap=agx]
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
| `tools/blender/ce3d/` | Exporter: `glb` (GLB-Schreiber), `core` (Netze einsammeln, Achsen, Verschweißen), `roles` (Material-Rollen -> Klassen, Lampenkanäle, Lichtanker), `export` (Modell -> GLB + Meta), `lod` (Detailtabellen), `bake` (Atlas-Bake), `manifest` (Budgets, Merge), `catalog3d` (Liste aller Modelle), dazu die Bauer `props3d`, `veg3d` + `leafatlas`, `vehicles3d` + `extras3d` (Spielerautos), `traffic3d` + `decalgeo` (Verkehrsautos), `truck3d` (Sattelzüge), `heavy3d` (Bus), `police3d` (Polizei) |
| `tools/blender/cesprites/carinterior.py` | Innenraum der Spielerautos (nur 3D; die Sprites rufen es nie auf) |
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
- **Seit Bauabschnitt 3 (AS2a)**, alle nur im 3D-Bau (`detail["extras"]` bzw. Lampen als Mulde), die Sprites
  bauen exakt wie vorher:
  - `grille(…, proj=, sym=)`: auch Kühlergrill und Lufteinlass von Kombi und GT, Lufteinlass und Heckgitter des
    Sportwagens sind Mulden mit Lamellen (im Sprite dieselbe Fläche mit dem Lamellen- bzw. Wabenshader). Die Mulde
    geht in alle Körper unter der Kontur (Ziel `all`): Die Front der Karosserie liegt 1–4 cm hinter der Haut des
    Stoßfängers, der Boden einer Mulde nur im Stoßfänger lag dort, und zwischen den Lamellen schien der Lack durch.
  - Blinker (Heck ≥ 60 cm², Front ≥ 15 cm² je Seite) für Kombi, Sportwagen und GT; beim Sportwagen und GT ein
    eigener schmaler Blinkerstreifen unter der Leuchte (`tag="ind"`), weil die runden bzw. 5 cm hohen Leuchten keinen
    Platz haben. Zusätzlicher Projektor im Scheinwerfer von Sportwagen und GT (Abblendlicht ≥ 80 cm²).
  - `cardetail.lamp`: die Projektoren eines Scheinwerfers liegen über dem Chromreflektor (im Sprite einen Hauch
    darunter – im Echtzeitmodell war das Abblendlicht unsichtbar); **Rückleuchten laufen um die Ecke** (`WRAP3D`,
    `_lamp_wrap`): Wo die Heckleuchte auf der Karosserie endet (äußerster Strahl von hinten, dessen Fläche nach
    hinten schaut – die Sprite-Umrisse ragen über die Ecke hinaus), beginnt eine seitlich projizierte Mulde von
    16 cm Länge mit Füllung (Rück- und Bremslicht), Lichtleiter und Streuscheibe. Runde Leuchten (Sportwagen)
    nicht (`wrap3d=False`). Befund A9 der Kritik.
  - `cardetail.mirrors`: Der Spiegelarm beginnt 1,5 cm in der Karosserie (Strahl von der Seite) statt bei
    halber Breite − 3 cm, wo er neben schmaleren Flanken in der Luft hing.
  - `player_cars.brake3`: dritte Bremsleuchte als dunkles Gehäuse mit einer nach hinten leuchtenden Fläche (ein
    geschlossener Kasten hat keine Richtung – der Lichtanker braucht eine).
  - `vehicles.LAMP_TAGS["reflector"] = "-tail:0.3"`: Rückstrahler glimmen mit dem Rücklicht, sind aber keine
    Lichtquelle (kein Lichtanker; die Stoßfänger-Rückstrahler des SUV zogen den Anker der Rückleuchte 4,5 mm
    unter die Lampe). Nur 3D-Modelle lesen `LAMP_TAGS`.
- Der Innenraum der Spielerautos ist seit Bauabschnitt 3 ein Generator-Modul (`cesprites/carinterior.py`, vorher
  `ce3d/interior3d.py`); die Sprites rufen es nie auf.

`check_sprite_geometry.py` baut jedes Sprite-Set (ohne zu rendern) und vergleicht Zählwerte, Hüllquader,
Positions-Hash, Topologie, Materialien und Builder-Angaben mit `fixtures/geometry_v070.json`. Die Fixture stammt
aus den unveränderten Generatoren von v0.7.0. Eine Besonderheit: Blenders UV-Kugel liefert ihre Flächen in jedem
Prozess in anderer Reihenfolge (auch in v0.7.0; betrifft die Kugel des Berliner Fernsehturms). Darum gibt es
neben `topo` die Felder `ctopo` (Polygone als Eckenzyklen, sortiert) und `nstat` (Summen der Normalen, mit
Toleranz); weicht nur `topo` ab, zählt das Set als identisch.
Gemessen nach allen Hooks (Stand Bauabschnitt 1): **187 von 187 Sets identisch** (eines davon mit anderer
Flächenreihenfolge), 346 s. Stand Bauabschnitt 3: siehe Abschnitt 15.

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

Fahrzeuge (Pkw): Stand Bauabschnitt 3 (AS2a, Abschnitt 15); Sattelzug und die übrigen Zeilen aus Bauabschnitt 0
bzw. 1. Innenraum der Rennstufe (mit Verkleidung, Budget 6 000): Limousine 3 560, Kompakt 3 658, Kombi 3 860,
Sportwagen 3 514, GT 3 412 Dreiecke (Showroom-Stufe 6 242–7 058).

| Modell | Dreiecke je Stufe | Aufrufe | Netze | Texturquellen | Export | Bake |
|---|---|---|---|---|---|---|
| `player/limousine` | lod0 47 904 · show 98 786 · Schatten 2 320 | 6 / 6 | 1 637 806 B | – | 16,5 s | 0,07 s |
| `player/kompakt` | lod0 49 111 · show 106 609 · Schatten 2 320 | 6 / 6 | 1 770 564 B | – | 15,4 s | 0,08 s |
| `player/kombi` | lod0 54 306 · show 117 206 · Schatten 2 320 | 6 / 6 | 1 965 013 B | – | 17,8 s | 0,11 s |
| `player/sportwagen` | lod0 46 805 · show 94 983 · Schatten 2 320 | 6 / 6 | 1 688 705 B | – | 13,6 s | 0,09 s |
| `player/gran_turismo` | lod0 48 106 · show 102 289 · Schatten 2 320 | 6 / 6 | 1 776 118 B | – | 13,1 s | 0,13 s |
| `traffic/sedan` (4 Farbsets) | lod0 17 552 · lod1 5 808 · lod2 1 171 · Schatten 972 | 6 / 1 / 1 | 271 845 B | – | 2,5 s | 0,03 s |
| `traffic/hatch` (5 Farbsets) | lod0 17 636 · lod1 5 661 · lod2 1 197 · Schatten 988 | 6 / 1 / 1 | 271 024 B | – | 2,6 s | 0,03 s |
| `traffic/wagon` (4 Farbsets) | lod0 17 459 · lod1 5 941 · lod2 1 176 · Schatten 940 | 6 / 1 / 1 | 276 615 B | – | 2,6 s | 0,03 s |
| `traffic/suv` (4 Farbsets) | lod0 17 748 · lod1 5 889 · lod2 1 195 · Schatten 1 004 | 6 / 1 / 1 | 280 568 B | – | 2,5 s | 0,03 s |
| `traffic/van` (4 Farbsets) | lod0 17 655 · lod1 5 845 · lod2 1 195 · Schatten 1 064 | 6 / 1 / 1 | 271 200 B | – | 2,4 s | 0,03 s |
| `traffic/sports` (5 Farbsets) | lod0 17 751 · lod1 5 741 · lod2 1 164 · Schatten 972 | 6 / 1 / 1 | 287 170 B | – | 2,5 s | 0,03 s |
| `traffic/truck` (Koffer weiß, AS2b) | lod0 19 010 · lod1 5 174 · lod2 1 346 · Schatten 476 | 13 / 1 / 1 | 170 944 B | – | 1,6 s | 0,04 s |
| `traffic/truck_transport` (Koffer blau) | lod0 19 134 · lod1 5 260 · lod2 1 346 · Schatten 476 | 13 / 1 / 1 | 172 239 B | – | 1,7 s | 0,03 s |
| `traffic/truck_tarp` (Plane rot, grün) | lod0 23 412 · lod1 5 168 · lod2 1 270 · Schatten 476 | 13 / 1 / 1 | 210 702 B | – | 2,0 s | 0,02 s |
| `traffic/bus` (3 Farbsets) | lod0 19 238 · lod1 6 398 · lod2 1 500 · Schatten 516 | 6 / 1 / 1 | 227 704 B | – | 3,5 s | 0,02 s |
| `police/*` (18, je ein Modell) | lod0 19 778–21 970 · lod1 5 331–5 975 · lod2 1 061–1 196 · Schatten 1 020–1 084 | 6 / 1 / 1 | 295–345 kB | – | 2,4–3,5 s | 0,04–0,67 s |
| `props/tree_oak` | lod0 1 220 (420 Karten) · lod1 459 (140) · Schatten 179 · Fernbild | 2 / 2 / 1 | 53 072 B | 373 558 B | 2,2 s | 0,01 s |
| `props/farmhouse` | lod0 104 | 1 | 2 586 B | 752 795 B (1024², Nachtlicht 512²) | 58 s | 0,01 s |
| `props/streetlight` | lod0 312 (keine automatische Stufe) | 1 | 4 395 B | – | 0,1 s | < 0,01 s |
| `landmarks/michel` | lod0 3 024 | 1 | 63 648 B | 377 301 B (2048² WebP, Nachtlicht 1024²) | 329 s | 0,02 s |

Zusammen (Stand AS2b): Netze 16,44 MB von 40 MB (AS2a: 10,28 MB; die 18 Polizeiautos 5,6 MB, Bus und Sattelzüge
0,75 MB; MB = 2²⁰ Bytes wie im Prüfer), Texturen 4,59 MB im Grafikspeicher, Quellen 1,43 MB. Der Export des
Michel besteht fast ganz aus dem Cycles-Bake des 2048er-Atlas (980 Karten). Die Sprite-Geometrieprüfung aller
187 Sets dauert etwa 6 Minuten (2 Prozesse) bzw. 697 s (1 Prozess, AS2a). Alle Zeiten sind auf dieser VM
gemessen, während drei andere Läufe die vier Kerne mitbenutzten (2 Prozesse, `nice`): Sie schwanken von Lauf zu
Lauf um etwa 10 %.

Lampenflächen (gemessen mit `inspect_models.gd`: projizierte Fläche aus der Blickrichtung der Regel in
Abschnitt 9, nach der Wicklung der Dreiecke, cm² je Fahrzeug bzw. je Seite bei den Blinkern):

| Modell, Stufe | Rücklicht | Bremslicht | Blinker hinten l / r | Scheinwerfer | Blinker vorn l / r |
|---|---|---|---|---|---|
| `player/limousine` lod0 / show | 887 / 882 | 841 / 839 | 84 / 84 · 81 / 80 | 90 / 89 | 20 / 20 · 20 / 19 |
| `player/kompakt` lod0 / show | 929 / 922 | 901 / 898 | 102 / 102 · 100 / 100 | 101 / 103 | 28 / 27 · 27 / 27 |
| `player/kombi` lod0 / show | 782 / 820 | 751 / 785 | 78 / 79 · 77 / 78 | 92 / 93 | 29 / 29 · 28 / 28 |
| `player/sportwagen` lod0 / show | 804 / 803 | 767 / 764 | 66 / 66 · 66 / 66 | 85 / 84 | 30 / 30 · 31 / 31 |
| `player/gran_turismo` lod0 / show | 390 / 385 | 327 / 342 | 72 / 73 · 72 / 73 | 102 / 101 | 31 / 31 · 32 / 32 |
| `traffic/sedan` lod0 / lod1 / lod2 | 639 / 847 / 887 | 759 / 967 / 1 007 | 99 / 99 in jeder Stufe | 161 / 242 / 327 | 95 / 95 / 86 |
| `traffic/hatch` lod0 / lod1 / lod2 | 727 / 902 / 965 | 846 / 1 021 / 1 084 | 95 / 95 in jeder Stufe | 195 / 273 / 360 | 112 / 100 / 95 |
| `traffic/wagon` lod0 / lod1 / lod2 | 973 / 1 188 / 1 031 | 1 093 / 1 308 / 1 081 | 102 / 102 in jeder Stufe | 171 / 250 / 316 | 95 / 90 / 50 |
| `traffic/suv` lod0 / lod1 / lod2 | 775 / 895 / 740 | 731 / 851 / 880 | 120 / 120 in jeder Stufe | 264 / 329 / 414 | 108 / 98 / 90 |
| `traffic/van` lod0 / lod1 / lod2 | 489 / 624 / 763 | 596 / 736 / 875 | 86 / 85 / 82 | 476 / 505 / 583 | 109 / 109 / 100 |
| `traffic/sports` lod0 / lod1 / lod2 | 830 / 940 / 933 | 830 / 940 / 933 | 74 / 73 / 71 | 142 / 212 / 241 | 85 / 85 / 85 |
| `traffic/truck` lod0 / lod1 / lod2 | 860 in jeder Stufe | 860 | 450 / 450 | 1 000 | 320 / 320 |

Die Blinker der Pkw haben in allen drei Stufen dieselbe Fläche, weil sie mit derselben Kontur eingeschnitten sind.
Rück- und Bremslicht wachsen zu den groben Stufen hin, weil dort die schwarzen Lampenringe und die schmalen
Chromleisten wegfallen (erlaubt: höchstens 2 × + 5 cm²). Lichtanker: Verkehrsautos höchstens 6 mm von ihrer
Lampe (Transporter, Anker des Bremslichts), Spielerautos bis 40 mm (der Anker liegt in der Öffnung der Mulde, die
Leuchtkörper bis 28 mm dahinter; Kombi-Blinker); keiner liegt unter seiner Lampe (höchstens 0,9 mm, erlaubt 3).
Der GT hat mit 390 cm² das kleinste Rücklicht (eine 5 cm hohe Leiste über die ganze Breite, Regel: 200).

### Ehrliche Einordnung gegen die Cycles-Sprites

- **Spielerautos (alle fünf, seit AS2a):** Form, Fugen, Lampen und Räder stimmen mit den Sprites überein; das
  Echtzeit-Modell hat mehr Modelldetail als das Sprite (durchsichtiges Glas mit Innenraum, Lampen und Grill mit
  Tiefe, Wischer, Antenne, Kennzeichenrahmen). Im A/B-Bild aus der Showroom-Kamera bleibt es trotzdem hinter dem
  Sprite zurück – wegen Lack und Licht, nicht wegen des Netzes: Der Lack ist greller und gleichmäßiger (keine
  weichen Spiegelungen der Umgebung, kein Klarlack-Fresnel), es fehlen Kontaktschatten und Umgebungsverdeckung in
  Radhäusern und Fugen, Felgen und Chrom spiegeln nur eine Farbe. `showroom` bleibt deshalb bei allen fünf `false`
  (A/B nach R3 wiederholt, Abschnitt 15), bis das Showroom-Licht steht; danach genügt eine Zeile im Katalog.
- **Verkehrsautos (alle sechs Pkw-Typen):** dieselben Maße, Fenster und Lampen wie die Sprites, aber eine
  straffere Karosserie (Abschnitt 13). Die Lampen sind eingeschnittene, ebene Felder ohne Streuscheibe und Tiefe;
  das Heck ist eine fast senkrechte Fläche; Glas dunkel und spiegelnd, kein Innenraum. Die Blinkerfelder (71–120
  cm² je Seite) gibt es nur im 3D-Entwurf – das Sprite zeigt dort den schmalen Streifen. `lod2` hat
  dreieckige Radausschnitte mit sechseckigen Rädern – gedacht für mehr als 120 m.
- **Sattelzug:** Zugmaschine und Auflieger mit lesbarem Heck; seit AS2b drei Bauarten wie im Sprite (Koffer mit
  Schriftzug LOGISTIK bzw. TRANSPORT, Plane mit Gurten). Das Fahrerhaus ist ein Profilkörper mit Scheiben aus Glas
  (keine gewölbte Front), kein Innenraum. Der Lack des weißen Koffers erscheint im Kontaktbogen noch als reines Weiß
  (Belichtung des Renderers).
- **Bus:** derselbe Reisebus wie das Sprite (Fensterband, Streifen, Lampen, Zielanzeige) als Körper mit Radläufen,
  Stoßfängern und Spiegeln statt eines bemalten Quaders. Kein Innenraum: Die Scheiben sind dunkel.
- **Polizei:** die Verkehrsautos mit eingeschnittener Lackierung, Wörtern und einem Lichtbalken mit Tiefe; in `lod0`
  gleichwertig mit den Verkehrsautos, die Karos von Belgien, Schweiz, Litauen, Lettland, Rumänien zeigt `lod1` nur
  an Heck und Front.
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
- Sportwagen und GT (Spieler): Die Schulterkante der Entwürfe läuft unter dem Scheitel des vorderen Radlaufs. Seit
  der Nacharbeit (Abschnitt 17) folgt der Kotflügel im 3D-Bau dem Kreis Reifenradius + 25 mm; die Kante über dem
  Rad ist dadurch eine gestauchte Lippe, keine runde Schulter (aus der Nähe als Knick zu sehen).
- Die Blinker der Spielerautos leuchten nie (die Ansicht des Spielers hat kein `blink`); der Prüfer verlangt sie
  trotzdem (Regel 9), bei Tag sind sie als bernsteinfarbene Felder zu sehen.
- Laub nimmt den Schatten der Sonne nur zu einem Viertel an (sonst verschattet die Schattenhülle die Krone).
- Aufgesetzte Details der Verkehrsautos sind in die Karosserie geschnitten (eine Lage, kein Flimmern) – auch
  bei `lod1`/`lod2`, dort mit weniger Teilen.
- Komprimierte Netze melden immer ein Tangenten-Array (mit den Normalen gepackt, kostet keine Bytes).
- Seit AS2b sind alle Fahrzeug-Lampenkanäle belegt: Blaulicht A/B (10, 11) die Polizei, „immer an“ (13) die
  Zielanzeige des Busses, Rückstrahlung (14) Kontur und Dreiecke des Sattelzugs, Umrissleuchten (9) Sattelzug und
  Bus (die Anstrahlung des Michel steckt weiter in seinem Nachtlicht-Atlas). Die Lackcodes `paint2`/`paint3`
  tragen Sattelzug, Bus und Polizei. Der Prüfstreifen (`--channels`) zeigt alle 15 Kanäle, die Render-Prüfung
  `check_models.gd` schaltet die Lackcodes an einem Prüfnetz durch.
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
| `player/limousine`, `player/kompakt`, `player/kombi`, `player/sportwagen`, `player/gran_turismo` | `player` (`ce3d/vehicles3d.py`) | `cesprites.player_cars` in den Stufen `PLAYER_DETAIL` (`lod0`, `show`), dazu `ce3d/extras3d.py` (dritte Bremsleuchte, Kennzeichenrahmen mit zwei Leuchten, Dachantenne, Scheibenwischer) und `cesprites/carinterior.py` (Sitze, Kopfstützen, Armaturenbrett, Lenkrad links, Hutablage, Verkleidung) |
| `traffic/sedan`, `traffic/hatch`, `traffic/wagon`, `traffic/suv`, `traffic/van`, `traffic/sports` | `car` (`ce3d/traffic3d.py`) | Karosserie aus den Lofts von `carbody.SmoothCar`, gespeist aus den Entwurfstabellen `cesprites.designs` (`smooth_design`); Fenster, Lampen, Kennzeichen, Griffe und Fugen aus den Decal-Listen von `vehicles.Car`, als Geometrie eingeschnitten |
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
  Leuchten, Rückfahrlicht, Tagfahrlicht und Schwellerteilung; die Scheiben von `lod2` waren nach der
  Flächennormale gefärbt (seit der Nacharbeit: Heckscheibe nach der Kontur des Entwurfs, Abschnitt 17). Rücklicht,
  Bremslicht, Blinker und Scheinwerfer behalten ihre Kontur.
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
Tönung kommt aus der Vertexfarbe. Spielerautos: Scheiben mit Deckkraft 0,48 (bis Bauabschnitt 1: 0,36 – im
A/B gegen die Sprites zu hell und bläulich), Streuscheiben 0,10, klare 0,08;
dahinter Sitze, Kopfstützen, Armaturenbrett, Lenkrad und Hutablage (`cesprites/carinterior.py`, bis Bauabschnitt 1
`ce3d/interior3d.py`). Die Kabine wird dafür geöffnet
(`_open_cabin`): die Scheiben aus dem Loft geschnitten, die Innenseite verkleidet – mit einem groben zweiten Loft
der Kabine (`_lining_loft`: halbe Punktzahl, 2,2-facher Stationsabstand; Kompakt 1 378 statt 4 112 Dreiecke).
Der Innenraum der Rennstufe samt Verkleidung bleibt unter 6 000 Dreiecken (§4.6.9); der Export bricht sonst ab
(gemessen: Limousine 3 560, Kompakt 3 658). Wanne und Armaturenbrett halten Abstand zu den Rädern, auch zu einem
um 25° eingeschlagenen Vorderrad (`carinterior.wheel_houses`); die Hutablage folgt der Außenhaut (`outer_z`) – ihre
Ecke stand beim Kompakten als schwarzes Blatt über den Rückleuchten aus der Schulter.

Verkehrsautos: undurchsichtiges Glas, aber heller, glatter und leicht metallisch (`TRAFFIC_GLASS`: `#2a343e`,
Rauheit 0,02, Metall 0,25), damit der Himmel sich spiegelt; `lod1`/`lod2` zeichnen es als `vpbr` mit derselben
Rauheit und demselben Metallwert, aber heller (`TRAFFIC_GLASS_FAR` `#3a4652`, auch für Lkw und Bus): `vpbr`
spiegelt den Himmel etwa halb so stark wie die Klasse `glass`, die Scheiben wurden beim Wechsel dunkler (AS2R,
Abschnitt 17).

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
Seit Bauabschnitt 3 druckt `CE_STATS` auch die Lage der Rückleuchten-Fortsetzung um die Ecke (`wrap …`).

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

## 15. Fahrzeuge des Bauabschnitts 3 (AS2a)

Seit diesem Abschnitt hat **jedes Pkw-Set ein Modell**: die fünf Spielerautos (je mit Showroom-Stufe) und alle 26
Farbsets der sechs Verkehrsauto-Typen. Platzhalter (`box`) gibt es unter den Fahrzeugen nur noch für Lkw, Busse und
Polizei (Bauabschnitt 4).

### Verkehrsautos SUV, Transporter, Sportwagen

Derselbe Bau wie Limousine, Schrägheck und Kombi (Abschnitt 13), mit den Lampenteilen und Fugen der 3D-Entwürfe in
`ce3d/traffic3d.py`:

- **Lampen** (`CAR_3D`): Blinker im unteren Band der Rückleuchte und im äußeren Ende des Scheinwerfers,
  Rückfahrlicht am inneren Ende der Rückleuchte, Tagfahrlicht unter dem Scheinwerfer. Der Transporter hat seinen
  Blinker oben in der hohen Eckleuchte schon im Entwurf; in 3D bleibt er auf der Heckfläche (bis 0,992 statt 1,02 m
  – um die Ecke lag sein Lichtanker 5,6 mm unter der Lampe).
- **Reihenfolge der Lampenliste** (`order`): Der Schnitt stapelt die Decals nach Materialgruppen in der Reihenfolge,
  in der eine Gruppe zuerst vorkommt. Der Leuchtbalken des Sportwagens (rot, ohne schwarzen Rand) stand vor seinen
  Eckleuchten (rot mit Rand) – der schwarze Rand lag dann über dem Rot, in `lod0` waren die Leuchten schwarz. In
  3D kommen die Eckleuchten zuerst.
- **Fugen** (`REAR_LID`): Heckklappe des SUV, Kofferraumdeckel des Sportwagens (mit Längsfugen auf dem Deck), beim
  Transporter zwei Hecktüren bis unter das Dach (`cabin`: die Linien laufen auf dem Aufbau weiter, das Emblem sitzt
  auf der Tür).
- **Heckflügel** des Sportwagens (`_wing`): in `lod0` ein gewölbtes Profil mit Endplatten auf zwei Stützen, in
  `lod1`/`lod2` der Kasten des Sprites auf seinen Stützen – derselbe Umriss in jeder Stufe.
- **Schulter** (`SMOOTH_3D`): Die Gürtellinie des Sportwagens liegt so tief, dass die Schulterkante über den Scheitel
  der großen Radläufe lief; die Öffnung wurde darunter abgeschnitten und der Loft faltete sich an den Radlaufkanten.
  Seine Schulter liegt 4,5 cm höher.
- **Verdrehte Splitter** (`_drop_flipped_slivers`): Wo der Boden des Lofts an der Kante eines Radlaufs zwischen zwei
  4 mm entfernten Stationen hochspringt, verdrehen sich die Ringe; ein paar etwa 1 mm hohe Dreiecke zeigen gegen ihre
  Normalen (Sportwagen 12, Kombi 5, Limousine 3). Sie werden von der Seite, die sie zeigen sollen, ohnehin
  weggeschnitten und fallen jetzt weg; Decal-Dreiecke behalten die Wicklung ihrer Fläche und sind nie betroffen.
- **Budgets** über Detail-Overrides je Modell in `catalog3d` (längere Stationsabstände): SUV, Transporter und
  Sportwagen tragen mehr Decals (Verkleidung, Dachreling, Flügel, vier Endrohre).
- Rückstrahler (SUV) ohne Lichtanker und in `lod2` ohne Schnitt (`decalgeo`: Lampen mit `-`).
- Gemessen (Spielkamera, Tag, Anteil der Autopixel, die sich beim Wechsel um mehr als 24 Stufen ändern): 40 m
  `lod0` → `lod1` SUV 5,6 %, Transporter 4,7 %, Sportwagen 9,3 %; 120 m `lod1` → `lod2` 32,3 / 33,9 / 37,2 %
  (Sportwagen vor der Scheibenkorrektur 42,6 %). Bei 120 m sind die Autos 12 × 9 Pixel groß; was wechselt, sind
  die Kanten der groben Kabine, die Spiegelung der Heckscheibe (in `lod1` heller) und die unterste Pixelreihe.
- **Scheiben in `lod2`** (`far_glass`): Die Fließheckscheibe des Sportwagens liegt 17° flach, genau auf der
  Schwelle der Normalenregel (eine Fläche ist Front- oder Heckscheibe, wenn ihre Normale mit mehr als 0,3 längs
  zeigt): In jedem ihrer zwei Vierecke blieb ein Dreieck Lack, eine diagonale halbe Scheibe, die beim Wechsel bei
  120 m 43 % der Autopixel änderte. `CAR_3D["sports"]["design"]` setzt `far_pane_ny` auf 0,25. (Eine Regel über
  den Scheibenbereich des Entwurfs schnitt bei der Limousine Dreiecke der Dachkante mit – verworfen.)

### Spielerautos Kombi, Sportwagen, Gran Turismo

Derselbe Bau wie Limousine und Kompakt (Abschnitt 13): Rennstufe, Showroom-Stufe, Schattenwerfer, Innenraum,
durchsichtiges Glas. Neu für alle fünf: Rückleuchten um die Ecke, sichtbare Projektoren, dritte Bremsleuchte mit
Richtung, Spiegelarme aus der Karosserie, Kühlergrill bzw. Lufteinlass als Mulde mit Lamellen (Abschnitt 8).
Felgen: jedes Auto behält seinen Stil (Kompakt 6 Doppelspeichen schwarz, Kombi 10 gerade Speichen, Limousine 5
Doppelspeichen, Sportwagen 5 Y-Speichen schwarz, GT 10 gebogene Turbinenspeichen); die silbernen Felgen von Kombi
und GT tragen das Silber, das ihr Sprite zeigt (in Echtzeit waren sie weiß wie die der Limousine vor AS1R).
Der Kombi hat in `lod0` einen längeren Stationsabstand (4,8 m Länge; der Karosserie-Loft allein hatte 20 000
Dreiecke). Gefaltete Pfadflächen (der L-förmige Lichtleiter des Kombi: 13 Dreiecke gegen ihre Normalen) und
Splitter an den Radlaufkanten entfernt der Exporter (`vehicles3d._drop_flipped`).

Nur in 3D (das Sprite bleibt, wie es ist): Blinker vorn als schmaler Streifen am Scheinwerfer bzw. auf der
Lichtleiste (Sportwagen, GT: der Prüfer verlangt 15 cm² je Seite), je ein zusätzlicher Projektor in den schmalen
Scheinwerfern von Sportwagen und GT (Scheinwerferfläche ≥ 80 cm²), beim Kombi das Rückfahrlicht im weißen Feld der
Rückleuchte. Die Rückbank der 2+2-Sitzer (Sportwagen, GT) sitzt über der Hinterachse: Sie bleibt schmaler als die
Kabine, bis sie aus den Radhäusern heraus ist (vorher 89 bzw. 60 mm im Hinterreifen, verdeckt).

### Prüfungen (gemessen, Stand AS2a)

- `check_sprite_geometry.py --jobs 1`: **187 von 187 Sets identisch** (eines mit anderer Flächenreihenfolge, der
  Fernsehturm wie bisher), 697 s – alle Hooks dieses Abschnitts ändern kein Sprite.
- Determinismus: erzwungener Export und Bake aller `player/*` und `traffic/*` ließen das Repository unverändert,
  ein zweiter Bake war byte-gleich (80 Dateien), `--check-keys` grün.
- Radfreiheit (Netz-Dump): Hinterräder aller Spielerautos und alle Räder von Kompakt, Kombi, Limousine, SUV und
  Transporter frei; Vorderräder Sportwagen/GT siehe Abschnitt 12; Verkehrs-Sportwagen erst ab 15° Lenkeinschlag
  (32 mm), Verkehr lenkt nur um atan(Radstand × Krümmung).

### Showroom-Entscheid

A/B mit derselben Kamera (Showroom-Ansicht der Sprites, Kontaktbogen `--showroom --tonemap=agx`): Form,
Fugen, Lampen, Felgen und Kennzeichen der Stufe `show` stimmen mit dem Cycles-Sprite überein, der Innenraum ist
durch das Glas sogar zu sehen. Gleichwertig ist sie trotzdem bei keinem der fünf Autos: Der Lack ist flach (keine
Spiegelung der Umgebung, kein Klarlack-Glanzlicht über die Rundungen), es fehlen Umgebungsverdeckung in Fugen,
Radhäusern und unter dem Auto und der Kontaktschatten, das Glas ist heller und spiegelt kaum, unter AgX wird Gelb
blass. Alle `showroom`-Flags bleiben `false`. Was fehlt, liegt im Renderer (Umgebungsspiegelung und Licht des
Showrooms, R3/UI1), nicht im Netz.

**Nachprüfung M2INT** (Kontaktbogen `--showroom --tonemap=agx` mit dem Look des Showrooms aus
`ModernMaterials.STUDIO_LOOK`, gemessen auf der Tür jedes Autos, Echtzeit gegen Sprite): Helligkeit × 0,95 (GT),
1,02 (Kombi), 1,18 (Kompakt), 1,08 (Limousine), 1,08 (Sportwagen); die Sättigung des Lacks liegt bei Kombi,
Limousine und Sportwagen um 0,24–0,39 höher als im Sprite – dort mischt der Klarlack das Grau des Studios hinein,
in Echtzeit fehlt diese Spiegelung (`env_energy` 0 im Studio), der Lack wirkt flach und bunt; der Sportwagen kippt
nach Orange, der Kompakt bleibt blass. Kein Auto ist damit mindestens so gut wie sein Sprite: **alle Flags bleiben
`false`**. Der nächste Schritt gehört dem Showroom (UI2/R8): ein Studiohimmel, den der Klarlack spiegelt
(`env_zenith/horizon/ground` grau, `env_energy` > 0), Kontaktschatten unter dem Auto, dann neu vergleichen.

## 16. Fahrzeuge des Bauabschnitts 4 (AS2b): Lkw, Busse, Polizei

Seit diesem Abschnitt hat **jedes Fahrzeug-Set ein Modell**: neben Spieler- und Verkehrsautos die sieben schweren
Sets (vier Sattelzüge, drei Busse) und alle 18 Polizeiautos. Platzhalter (`box`) gibt es nur noch unter den
Requisiten und Wahrzeichen.

| Modell | Bauer | Sets |
|---|---|---|
| `traffic/truck` | `truck` (`ce3d/truck3d.py`) | `traffic/truck_white` (Koffer, Schriftzug LOGISTIK) |
| `traffic/truck_transport` | `truck` | `traffic/truck_blue` (Koffer, Schriftzug TRANSPORT) |
| `traffic/truck_tarp` | `truck` | `traffic/truck_red`, `traffic/truck_green` (Planenauflieger) |
| `traffic/bus` | `bus` (`ce3d/heavy3d.py`) | `traffic/bus_white`, `traffic/bus_red`, `traffic/bus_blue` |
| `police/<land>` (18) | `police` (`ce3d/police3d.py`) | `police/<land>` |

### Sattelzüge

- **Drei Bauarten** nach `cesprites.heavy.TRUCK_VARIANTS` (Plane ja/nein, Schriftzug): ein Modell je Bauart, die
  Farbsets einer Bauart unterscheiden sich nur im Lack (Instanz-Uniforms). `build_truck` bricht ab, wenn die Sets
  eines Modells verschiedene Bauarten verlangen.
- **Koffer:** Streifen und Schriftzug auf beiden Flanken (`paint3`), der Schriftzug aus den Glyphen der
  Sprite-Schrift (`police3d.glyph_outlines`, in `lod0` mit zwei, in `lod1` mit einem Kurvenpunkt je Bogen, in `lod2`
  ohne Schrift). Das Emblem des ersten Entwurfs ist entfallen (das Sprite hat keines).
- **Plane:** gewellte Plane zwischen den Rahmen (14 mm Amplitude), 22 Spanngurte (`lod0` mit Schnallen, `lod1` ohne,
  `lod2` keine). Die Kanten der Plane laufen auf die Rahmen (vorher ein Spalt am Ober- und Untergurt).
- **Fahrerhaus:** Scheiben in der Klasse `glass` (der Glaston der Verkehrsautos; `lod1`/`lod2` als `vpbr` in
  `truck3d.GLASS_FAR`, Abschnitt 17), fünf bernsteinfarbene
  Dachleuchten über der Sonnenblende (Kanal 9, ohne Lichtanker), Seitenblinker hinter den Türen (`lod0`).
- **Heck in `lod2`:** die vier Verschlussstangen als Leisten wie in `lod1` (+48 Dreiecke). Ohne sie wurde das Heck
  beim Wechsel bei 180 m zur glatten Fläche (27,5 % der Lkw-Pixel änderten sich, mit ihnen 1,2 %).
- **Räder:** `truck3d._wheel` nimmt Radius und Spurbreite (der Bus benutzt dieselben Räder mit 0,5 m); die Reifen
  der fernen Stufen haben keine innere Flanke mehr (unsichtbar, kostete in `lod2` ein Fünftel des Budgets).
- **Gruppen** unverändert: `tractor` (Drehpunkt [0, 0, −3,1]), `trailer` (Königszapfen [0, 1,19, −3,7]), in
  `lod1`/`lod2` ein Netz `body`.
- **Teilquader (gemessen, Netz-Dump `lod0`):** Auflieger x ±1,275, y 0,21–4,00, z −5,35…8,291 – Arcade-Teil
  `trailer` ±1,275 × 0–4,0 × −5,35…8,25 (hinten 41 mm Unterfahrschutz und Leuchtenträger). Fahrerhaus ohne
  Spiegel x ±1,24 (Teil `cab` ±1,25), Höhe 3,878 m (Teil 3,80: Dachspoiler, seit AS1), oberhalb des Rahmens bis
  z −5,46 (Teil endet bei −5,75; die Rückwand liegt im 40-cm-Spalt zwischen den Teilen, der Auflieger beginnt bei
  −5,35). Spiegel bis ±1,535 m. Der Rahmen der Zugmaschine reicht unter dem Auflieger bis z −2,075. Die Kollision
  rechnet weiter mit den Arcade-Teilen.

### Bus

- **Starr** wie der Arcade-Quader (ein Teil `body`, 12,8 × 2,55 × 3,65 m): Knoten `body`, `wheel_0l|r` (vorn),
  `wheel_1l|r` (hinten, Zwillingsräder); `lod1`/`lod2` ein Netz. Ein Gelenkbus braucht erst ein Sprite-Set mit zwei
  Teilen.
- **Hülle:** ein Loft mit gerundeten Enden, Dachkante und aus dem Boden geschnittenen Radläufen. Die langen Linien
  der Flanken (Schürze, Streifen, Fensterband) sind Zeilen des Lofts (`ROWS`): ein Schnitt längs durch die Vierecke
  einer Flanke kostet doppelt so viele Dreiecke.
- **Eingeschnitten** (eine Lage): Fensterband mit Dichtungen und sieben Scheiben, Doppeltür rechts, Fahrerfenster
  links, Streifen (`paint2` Keil, `paint3`), Gepäckklappen mit Griffen (`lod0`), Seitenmarkierungsleuchten,
  Heckscheibe, Lüftungsgitter (`lod0`, `lod1`), hohe Rückleuchten mit Blinker und Rückfahrlicht, dritte
  Bremsleuchte, rote Umrissleuchten, Frontscheibe mit Zielanzeige (bernsteinfarbene LED-Felder, Kanal 13 „immer
  an“), Scheinwerfer, Blinker, Grill.
- **Teile:** Stoßfänger (hinten mit Kennzeichen samt Zeichen in `lod0`), Radlaufverkleidungen (`lod0`, `lod1`),
  Spiegel an Armen (`lod2`: ein gerader Arm), Scheibenwischer.
- **Lack:** `paint` = Aufbau, `paint2` = unterer Streifen, `paint3` = oberer Streifen; fast weißer Lack wird wie beim
  Lkw begrenzt (`truck3d._tone`).
- **Schattenwerfer:** der grobe Loft 3 cm innerhalb der Haut – auch an den Enden (die Endflächen lagen zuerst in der
  Ebene von Heck und Front und ragten im Bogen `--caster` heraus), dazu die Trommeln der Räder.
- **Maße (gemessen):** Aufbau ohne Spiegel x ±1,275, y 0,37–3,65, z ±6,43 (Arcade ±1,275 × 0–3,65 × ±6,4;
  Stoßfänger je 30 mm). Die Spiegel reichen bis ±1,505 m und 0,435 m vor die Front – in 2,2 bis 2,9 m Höhe, über
  jedem Pkw-Dach.

### Polizei

- **Basis:** das Verkehrsauto des Sprite-Katalogs (Kombi, Limousine, Schrägheck oder SUV) aus `traffic3d`. Der Bauer
  hakt sich nur für die Dauer eines Baus in drei Schritte ein (`police3d._hooks`, zur Laufzeit; die Dateien der
  Verkehrsautos bleiben unverändert, eine Nacharbeit an ihnen erreicht die Polizei mit): der Entwurf ohne Dachreling
  und ohne Emblem unter dem Heckwort, `decalgeo.car_surfaces` gefolgt von Lackierung und Wörtern,
  `SmoothCar.lower_half`/`bumper_half_fn` mit einer Loft-Zeile je Lackierungslinie.
- **Lackierung** (`cesprites.police.livery`: Band, Band mit Linie, Streifen, Karos, unten, Italien) in die Karosserie
  geschnitten: `paint` = Wagenfarbe, `paint2` = `c1`, `paint3` = `c2` (Lack des Sets). Flächen, die nach oben
  schauen (n_z > 0,75), behalten wie im Sprite die Wagenfarbe – geteilt wird dafür nur im Bereich der Bänder. Die
  flachen Endkappen werden mit den Lackierungslinien als Kanten neu trianguliert (`_recap`, Delaunay mit
  Zwangskanten): Jede Linie kreuzte sonst alle langen Fächerdreiecke.
- **Schwellen:** Eine Linie teilt nur Dreiecke, die quer zu ihr größer als 1 / 4 / 15 cm und größer als 2 / 40 /
  300 cm² sind (`lod0` / `lod1` / `lod2`); kleinere nehmen die Farbe ihres Mittelpunkts (Sägezahn unter einem
  Pixel bei 10 / 40 / 120 m). Streifen unter 10 cm fallen in `lod2` weg.
- **Karos:** `lod0` überall. `lod1` nur auf den Stoßfängern (Heck und Front – was die Spielkamera sieht), die Flanken
  in der Mischfarbe; die Enden der Karosserie liegen im Band hinter den Stoßfängern und werden nicht geschnitten (sie
  kosteten 770 Dreiecke). `lod2` überall Mischfarbe. Die Mischfarbe ist die Farbe, die der Renn-Look für die Karos
  zeigt (Potenzmittel in linearem Licht, Exponent `CHECK_MEAN_EXP` 0,6; AS2R, Abschnitt 17) – das lineare Mittel kam
  27–33 Stufen heller heraus.
- **Wörter:** das Landeswort auf beiden Flanken (auf den Türen, zwischen den Achsen) und am Heck, aus den Glyphen der
  Inter-Schrift, die Blender mitbringt (Kurve, fett um 3,5 % der Höhe); Löcher (O, A, P, R …) bestimmt die
  Umlaufrichtung der Randkanten (bei sich überlappenden fetten Glyphen verlor ein Test „liegt in einer anderen
  Kontur“ das L von POLIZEI). Nur `lod0`: Bei 40 m ist ein Buchstabe 3 px hoch. Der Export bricht ab, wenn die
  Wörter die Fläche der Karosserie ändern.
- **Lichtbalken:** Füße, dunkle Basis, je Seite eine klare blaue Kuppel (Klasse `glass`, Deckkraft 0,22) über drei
  LED-Modulen auf einem Chrom-Reflektor, weißes Mittelmodul. Blaulicht A links (Kanal 10), B rechts (Kanal 11), mit
  Lichtankern; die Sitzung lässt sie abwechseln. `lod1`/`lod2`: leuchtende Blöcke auf derselben Fläche wie die
  Module (vorher sprang der Lichtpunkt beim Wechsel). Oberkante 0,13 m über dem Dach (Objekthöhe Auto + 0,13 wie im
  Sprite).
- **Schattenwerfer:** die Hülle des Verkehrsautos, dazu der Balken aus Sockel, je einem Block in jedem LED-Modul und
  dem Mittelteil – in jeder Stufe mindestens 1 cm innerhalb des sichtbaren Balkens. Ein einziger Block über den
  ganzen Balken umschloss Module und Leuchtblöcke: Sie lagen bei Tag in seinem Schatten und wirkten dunkel. (Die
  roten Räder im Bogen `--caster` sind die Trommeln des Verkehrsauto-Werfers, wie bei allen Verkehrsautos.)
- **Budgets** (6 000 in `lod1` wie ein Verkehrsauto, obwohl Bänder, Wörter und Balken dazukommen):
  `catalog3d.POLICE_DETAIL` (gröbere Stationsabstände je Basis in `lod1`/`lod2`) und `POLICE_DETAIL_CC` (Karos,
  Ungarn mit dem längsten Wort, Rumänien, Österreich, Belgien/Schweiz).

### Prüfungen (gemessen, Stand AS2b)

- `validate_models.py`: **CHECK models OK**, 37 Modelle, 180 Sets (65 mit Modell; ohne Modell nur Requisiten und
  Wahrzeichen), Netze 16,44 MB von 40 MB. Höchstwerte gegen die Budgets: Polizei `lod0` 21 970 / 22 000, `lod1`
  5 991 / 6 000, `lod2` 1 185 / 1 200; Lkw/Bus `lod0` 23 412 / 25 000 (Plane), `lod1` 6 398 / 7 000 (Bus), `lod2`
  1 500 / 1 500 (Bus), Schattenwerfer höchstens 1 084 / 3 000.
- Blaulicht A und B: im Nachtbogen je Kanal einzeln geschaltet, A links, B rechts (`--night`, Kontaktbogen).
- Stufenwechsel (Spielkamera von hinten, Tag, Anteil der Fahrzeugpixel, die sich um mehr als 24 Stufen ändern;
  Fahrzeugpixel = mehr als 24 Stufen neben dem Hintergrund ihrer Zeile):

  | Modell | nah (`lod0` → `lod1`) | fern (`lod1` → `lod2`) |
  |---|---|---|
  | `police/de` | 40 m: 13,8 % | 120 m: 35,6 % |
  | `police/be` | 40 m: 18,8 % (vor den Karos in `lod1`: 29,9 %) | 120 m: 59,0 % (vorher 41,0 %) |
  | `traffic/bus` | 60 m: 6,7 % (vor dem Gitter in `lod1`: 16,7 %) | 180 m: 23,2 % (vorher 9,7 %) |
  | `traffic/truck_tarp` | 60 m: 2,4 % | 180 m: 1,2 % (ohne Verschlussstangen in `lod2`: 27,5 %) |

  Was beim nahen Wechsel der Polizei bleibt: Wörter und Kennzeichenzeichen (nur `lod0`) und der Lichtbalken – die
  Glaskuppel von `lod0` erscheint bei Tag heller als die Blöcke von `lod1`. Die Karos und das Lüftungsgitter
  wechseln jetzt beim fernen Wechsel, wo das Fahrzeug etwa 11 × 10 (Polizei) bzw. 10 × 14 Pixel (Bus) groß ist;
  in Bildpunkten bei 1280 × 720 gezählt ändern beide Wechsel zusammen weniger als vorher (Belgien 270 statt 374,
  Bus 151 statt 302; abgeleitet: Anteil × Fahrzeugpixel der Kachel ÷ Vergrößerung²).
- `lod2` des Busses liegt mit 1 500 Dreiecken genau auf dem Budget (zwei breite Gitterstäbe statt sechs).
- `check_sprite_geometry.py --only traffic/truck,traffic/bus,police --jobs 1`: **25 von 25 Sets identisch** (67 s);
  `cesprites` ist in diesem Abschnitt unverändert, die Hooks der Polizei wirken nur während eines 3D-Baus.
- Determinismus: Erzwungener Export und Bake aller 22 Modelle dieses Abschnitts ergaben byte-genau die eingecheckten
  Dateien (die aus einem früheren Bake stammen); ein weiterer Bake in denselben Ordner war byte-gleich (142 Dateien);
  `--check-keys` grün.

## 17. Nacharbeit nach der Kunstkritik der Bauabschnitte 3 und 4 (AS2R)

Die unabhängige Kritik der Pkw von AS2a (KRITIK-2) hat ihre Befunde mit Messwerten und Bildern belegt. Jeder Befund
wurde vor der Änderung am Netz oder im Bild nachgeprüft; was am Modell lag, ist geändert. Lackbelichtung,
unbeleuchtete Lampen (`lamp_off`), Metallic-Flocken, die Nacht-Signatur ohne Flares und der Look im Showroom liegen
im Renderer (R1/R3/R4/UI1) und sind dort offen. Die Lkw, Busse und Polizeiautos von AS2b wurden mit derselben
Strenge geprüft (Spielkamera 20/60/150 m bei Tag und Nacht neben dem Arcade-Quader bzw. -Sprite, Blaulicht,
Stufenwechsel).

| Befund (Kritik) | Ursache (geprüft) | Änderung | Messung vorher -> nachher |
|---|---|---|---|
| Transporter `lod2`: obere Kastenhälfte ganz Glas (B2) | Normalenregel `far_glass`: jede Fläche der Kabine über der Gürtellinie, die nicht Dach ist, wurde Scheibe | `car_surfaces(far_windows=...)`: die Heckscheibe wird entlang der Kontur des Entwurfs geschnitten, Seitenscheiben nur im Bereich der Seitenfenster (Flächen an dessen erstem und letztem y geteilt) | Wechsel bei 120 m (Tag, mit Renn-Look): 46,4 -> 12,0 % (90 / 160 m: 42,7 / 52,5 -> 9,6 / 15,8 %) |
| SUV und Flotte: Kabine in `lod2` eine dunkle Kappe samt Säulen (B2, Flotte) | dieselbe Regel: das ganze Heckende der Kabine wurde Glas | wie oben – die Säulen bleiben Lack | SUV 32,3 -> 29,8 %, Limousine 26,9 -> 14,4 %, Schrägheck 35,7 -> 22,4 %, Kombi 31,4 -> 6,9 %; nachts (120 m) SUV 14,1 -> 4,5 %, Transporter 30,1 -> 3,6 % |
| Budget von `lod2` (1 200) | der Schnitt der Heckscheibe in die Fächer der Endkappe kostete 50–280 Dreiecke | Endkappen von `lod2` als Bänder (`carbody`-Hook `cap_strips`, Sprite unverändert); Räder von `lod2` als Lauffläche + eine Scheibe in der Mischfarbe von Reifen und Felge (12 Dreiecke je Rad weniger); feinere Kabine (`gstep` 60) bei Sportwagen, Schrägheck, Kombi | alle `lod2` ≤ 1 197 / 1 200 |
| Stufenwechsel bei 40 m mit Renn-Look (B4) | `lod1` zeichnet die Scheiben als `vpbr`, das den Himmel halb so stark spiegelt wie die Klasse `glass` von `lod0`: die Scheiben waren 20–27 Stufen dunkler | eigene Scheibenfarbe der fernen Stufen `TRAFFIC_GLASS_FAR` (`#3a4652`), gemessen auf die mittlere Farbe der `lod0`-Scheibe abgestimmt | Transporter 17,8 -> 4,2 % (25 / 60 m: 20,8 / 16,8 -> 8,0 / 5,8 %), Sportwagen 13,3 -> 11,4 %; Scheibe des Transporters in 40 m: (76, 97, 127) in lod0 gegen (49, 73, 107) -> (70, 94, 130) in lod1 |
| Weiße Verkehrsautos und Polizei ohne Form (B1) | `#ececea`/`#e8e8e5`/`#e6e6e3`/`#f2f2ef` erscheinen in der Sonne als reines Weiß; `truck3d._tone` galt nur für Lkw und Bus | `_tone` (höchstens `#d8d8d6`) auch für die Farbsets der Pkw und die Lackierungsfarben der Polizei | Transporter weiß, 10 m: Pixel mit allen Kanälen ≥ 250: 22 473 -> 7 565 (der Rest ist Belichtung, R1/R3) |
| SUV-Front: weiße Sägezähne an der Stoßfängerkante (B3) | Stoßfänger dunkel erst unter 0,42 m, Karosserie (Schweller) schon unter 0,47 m: wo das runde Stoßfängerende in die Karosserie läuft, kreuzten sich die weiße und die schwarze Fläche | im 3D-Entwurf reicht der dunkle Teil der Stoßfänger bis zur Schwellerlinie | im Nahbild keine Zähne mehr |
| SUV-Rückstrahler unsichtbar (B6) | als Teil der Rückleuchtenliste in den Karosserie-Loft 3 cm hinter der Stoßfängerhaut geschnitten | auf den Stoßfänger (`bumper_decals_3d`), auch in `lod2` (`far_reflectors`) | sichtbarer Anteil (Strahltest der Kritik): 0 -> 100 % |
| Rückfahrlicht Kombi und Kompakt unsichtbar (A6) | Kombi: das weiße Feld lag 0,3 mm unter der roten Füllung; Kompakt: Nebel- und Rückfahrleuchte als Mulde unter der Diffusorplatte | Kombi: Feld 1,7 mm vor der Füllung; Kompakt: beide Leuchten auf der Platte (3D-Hooks, Sprite unverändert) | sichtbar 10 % -> 100 % bzw. 0 % -> 100 % |
| GT nachts nur eine dünne Linie (A2) | Leuchtenkörper 6–15 mm innerhalb der Streuscheibe, Lichtleiste 6 mm hoch | im 3D-Bau füllt der Leuchtenkörper die Streuscheibe (3 mm Rand), die Lichtleiste ist 12 mm hoch | rote Pixel in 8 m: Rücklicht 353 -> 477, Bremse 587 -> 716 (Arcade 733 / 957) |
| Vorderrad Sportwagen und GT im Kotflügel (A5) | `SmoothCar.frame()` beginnt den Querschnitt unter der Schulter, die tiefer liegt als die Reifenoberkante | `vehicles3d._clear_front_arches`: die Ecken des Kotflügels über dem Vorderrad werden auf den Kreis Reifenradius + 25 mm gezogen | Ecken im Reifen (Werkzeug der Kritik): 114 / 71 bei 0° -> 0 bei 0° und ±7° (`show` bei ±25°: 2 bzw. 1) |
| Silberne Felgen fast weiß (A7) | Metall spiegelt mit `env_energy` 1,6 den hellen Himmel | Felgenfarbe Kombi `#7a7e84`, GT `#83878d` | – |
| Kontaktbogen: `--look=race` ohne Wirkung (C2) | `set_class_parameter` erreicht nur vorhandene Materialien | der Kontaktbogen legt die Klassenmaterialien vorher an | race gegen neutral: 0 -> 31 429 Pixel verschieden |

Nicht geändert: die Diffusor-Finnen (A8, niedrig; unter dem Heck, aus der Spielkamera kaum zu sehen), der
Schattenwerfer ohne Außenspiegel und das fehlende Rückfahrlicht von Sportwagen und GT (A9, nur im Showroom).

**Lkw, Bus, Polizei (Prüfung AS2R):** In der Spielkamera (20 / 60 / 150 m, Tag und Nacht, neben dem Arcade-Quader
bzw. -Sprite) stimmen Hecks, Lampen und Blaulicht A/B mit Arcade überein. Gemessen mit Renn-Look, Tag, an den
Wechselabständen: Planen-Sattelzug 2,2 / 1,1 % und Bus 6,8 / 21,7 % (60 / 180 m), Polizei Deutschland 14,3 /
20,4 % und Belgien 19,9 / 38,1 % (40 / 120 m; AS2b ohne Look: Plane 2,4 / 1,2 %, Bus 6,7 / 23,2 %, Deutschland
13,8 / 35,6 %, Belgien 18,8 / 59,0 %). Bei 40 m sind es bei der Polizei vor allem Kennzeichenzeichen, Wörter und
Lichtbalken, die es nur in `lod0` gibt.

- **Scheiben von Bus und Lkw in den fernen Stufen:** wie bei den Pkw (B4) als `vpbr` dunkler als das Glas von `lod0`;
  die Heckscheibe des Busses änderte beim Wechsel bei 60 m 43 % ihrer Pixel (`lod0` (78, 97, 121), `lod1`
  (59, 77, 100)). `truck3d.GLASS_FAR` (= `traffic3d.TRAFFIC_GLASS_FAR`) für `lod1`/`lod2` von Lkw und Bus:
  `lod1` (73, 93, 119), 0,1 % der Scheibenpixel; Bus bei 60 m 11,0 -> 6,8 % (gemessen).
- **Polizei, Heck in `lod2`:** Heckscheibe nach der Kontur (`far_windows="rear"`; die Seitenteilung hat im Budget
  keinen Platz neben Lackierung und Lichtbalken), Tschechien behält die Normalenregel (`catalog3d.POLICE_SPEC_CC`,
  mit Schnitt 1 204 / 1 200 Dreiecke).
- **Polizei, Karoband in der Ferne:** Das linear gemittelte Band kam heller heraus als die Karos daneben – die gelbe
  Zelle liegt in der Schulter der Tonkurve (Belgien, 120 m: `lod2` (201, 201, 136) gegen `lod1` (174, 178, 125),
  Mittel in linearem Licht über das Band). `police3d._hex_mix` nimmt jetzt das Potenzmittel mit Exponent
  `CHECK_MEAN_EXP` = 0,6: `lod2` (171, 180, 121) gegen (173, 178, 124). Der Anteil geänderter Pixel bleibt 38,1 %:
  Jede Zelle eines Pixels ist gelb oder blau, das Band einfarbig – diese Zahl misst hier die Textur, nicht die
  Helligkeit.
- **Offen:** Der Lichtbalken von `lod0` (Glaskuppel mit Himmelsspiegelung) ist bei Tag heller als die Blöcke von
  `lod1` – unbeleuchtet zeigt eine Lampe `lamp_off` × Leuchtfarbe, eine hellere Leuchtfarbe änderte das Blaulicht
  (gehört zu `lamp_off`, Renderer). Die zwei breiten Gitterstäbe im `lod2` des Busses (Budget 1 500 / 1 500) lesen
  sich anders als die sechs feinen von `lod1`. Weiß übersteuert (Renderer).

**Was mit dem Renn-Look gemessen ist:** `TRAFFIC_GLASS_FAR` (und `truck3d.GLASS_FAR`), `FAR_PLATE` und
`CHECK_MEAN_EXP` sind auf `LOOK` der Fahrzeug-Ebene (`env_energy` 1,6, `paint_base` 0,9, Glas 2,2) und das Licht
des Kontaktbogens abgestimmt. Ändern sich Look, Belichtung oder Tonkurve, sind sie neu zu messen (mittlere Farbe von
Scheibe, Kennzeichen und Karoband in beiden Stufen an den Wechselabständen). Der Look steht seit M2INT an einer Stelle,
`ModernMaterials.VEHICLE_LOOK` (A-13); RINT-B hatte ihn vorher geändert (`paint_base` 1,0 mit Knie 0,7 / Steigung
0,45, 8 % Entsättigung, `lamp_off` 0,28) – die Nachmessung von M2INT steht unten („Ferne Stufen nach dem Look von
RINT-B“).

**Kennzeichen und Zählweise:** Mit `FAR_PLATE` `#a2a2a0` stimmt die mittlere Helligkeit; die Zählung geänderter
Pixel steigt dadurch bei 25–60 m etwas (SUV 40 m 5,6 -> 6,8 %, Limousine 13,2 -> 14,4 %), weil die weißen Pixel des
`lod0`-Kennzeichens jetzt mehr als 24 Stufen vom grauen Feld entfernt sind. Bei 40 m entfallen 2–4 Prozentpunkte des
Wechsels auf das Kennzeichen. Bei der Limousine bleiben 11 Punkte außerhalb von Kennzeichen und Scheibe; nach dem
Differenzbild liegen sie vor allem auf den Fugen des Kofferraumdeckels (6 mm, bei 40 m ein Zehntel Pixel), die
`lod0` als Treppenlinie zeigt und `lod1` weglässt.

### Ferne Stufen nach dem Look von RINT-B (Nachmessung M2INT)

Mit den Werkzeugen von AS2R (Spielkamera 1280 × 720, vierfach überabgetastet, Renn-Look aus
`ModernMaterials.VEHICLE_LOOK`, gemessen), mittlere Farbe in beiden Stufen am Wechselabstand:

| Stelle | nahe Stufe | ferne Stufe | Urteil |
|---|---|---|---|
| Transporter, Heckscheibe, 40 m (`TRAFFIC_GLASS_FAR`) | (69, 86, 107) | (67, 87, 111) | stimmt (≤ 4 Stufen) |
| Limousine, Kennzeichen, 40 m (`FAR_PLATE`, lineares Mittel) | (192, 193, 195) | (197, 201, 202) | stimmt (≤ 7) |
| Bus, Heckscheibe, 60 m (`truck3d.GLASS_FAR`) | (70, 86, 105) | (69, 86, 105) | stimmt, 0,0 % der Fensterpixel > 24 Stufen |
| Bus, Kennzeichen, 180 m (`heavy3d.FAR_PLATE`, seit M2INT `#a2a2a0` statt `#c4c4c1`) | (161, 170, 181) | (165, 174, 185) | stimmt (≤ 4) |
| Polizei Belgien, Karoband, 120 m (`CHECK_MEAN_EXP` 0,6) | (166, 171, 126) | (168, 175, 112) | Rot/Grün stimmen, Blau 14 Stufen tiefer |

Scheiben und Kennzeichen sind feste Farben – Knie, Entsättigung und `paint_base` von RINT-B wirken nur auf Lack und
lassen sie unberührt. Das Karoband ist Lack: die 8 % Entsättigung ziehen die einzelnen gelben und blauen Karos von
`lod1` zum Grau hin, die Mischfarbe von `lod2` weniger – das Band wird in 120 m (7 × 2 Pixel) etwas gelber. Offen für
den Besitzer der Polizeimodelle: die Mischfarbe aus den Karos nach Knie und Entsättigung bilden.

**Stufenwechsel lod1 → lod2 mit der Überblendung von RINT-B** (Probe `pop_probe.gd` von RINT-B: das Auto fährt in
0,03-m-Schritten durch die Grenze, je Bild der Anteil geänderter Pixel des Autos; Voreinstellung dieses Rechners mit
`vehicle_lod1_m` 90 m, gemessen): größte Änderung je Bild rund um den Wechsel SUV 7,2 %, Sportwagen 8,1 %, Polizei
Belgien 13,1 %, Bus (Grenze 180 m × 90/120 = 135 m) 4,7 %; Bewegung allein im Median 0,3 / 0,8 / 0,5 / 0,0 %. Ohne
Überblendung sprangen in der Zählweise von AS2R 28–30 % (SUV, Sportwagen), 38 % (Polizei Belgien) und 22 % (Bus) in
einem Bild. Der Wechsel lod0 → lod1 (40 m) blendet nicht (`XFADE_LODS` = lod1, lod2).

**Olive (AS3R-Bericht 11.):** `tree_olive_b` trägt einen eigenen lod1-Abgleich (`params` „lift“ 1,057 statt der 1,12
der Art, `veg3d.build_tree`). Helligkeit lod0 → lod1 beim Wechsel bei 60 m, mittags / 19:30 / 23 Uhr
(`tools/models/prop_scene.sh --mode=lods --look=race`, gemessen): vorher +5,0 / +6,5 / +8,3 %, jetzt −0,2 / +0,5 /
+0,7 %; `tree_olive` unverändert −1,9 / −0,4 / −0,4 %.

## 18. Vegetation und Natur (Bauabschnitt 4, AS3)

Alle Pflanzen- und Natur-Sets der Sprites haben jetzt ein Modell: neun Baumarten mit je zwei Samen-Varianten
(Eiche, Birke, Buche, Pappel, Olive, Kiefer, Fichte, Zypresse, Palme), runder und niedriger Busch, Heide, die beiden
Felsen und die Klippe. Eiche, Birke und Büsche sind mit dem überarbeiteten gemeinsamen Bauer neu gebaut. Das Aussehen
jeder Art ist ihr Sprite (`cesprites/props_nature.py`): Das Modell nimmt dessen Kronenkugeln, Stämme und Farben und
gibt ihnen Tiefe und Blattwerk – es ist kein neuer Entwurf.

### Laubkuppeln statt flacher Karten (`ce3d/veg3d.py`)

Die flachen Laubkarten von Bauabschnitt 2 wirkten von nahem unruhig und zeigten flach angeschnittene Karten als
dunkle Schlieren; die Krone hatte weniger Form als die schattierten Kugeln des Sprites. Neu:

- **Eine gewölbte Karte je Kronenkugel** (`_dome_cards`): Sie liegt auf dem Ellipsoid der Kugel (Mittelpunkt, Radius,
  Höhenfaktor aus `CROWN_LOG`) und deckt den Teil, den keine andere Kugel verdeckt (48 Stichproben je Kugel), plus
  14° Rand, der unter die Nachbarn läuft. Weil sie der Kugel folgt, steht sie von keiner Seite flach im Bild außer an
  ihrem Rand – und dort macht der zerzauste Rand der Blattkugel-Textur den Umriss der Kugel laubig.
- **Normalen je Ecke** sind die der Kugel an dieser Ecke (dazu 22 % Rundung der ganzen Krone und ein wenig nach
  oben): Jede Kugel hat Licht- und Schattenseite wie im Sprite, und Nachbarn springen nicht in der Helligkeit.
- **Helligkeit je Ecke** (`COLOR.a`) = Verdeckung durch die anderen Kugeln (16 Strahlen über der Halbkugel der
  Normalen) mal **Himmelslicht** (eine nach unten zeigende Ecke bekommt `sky_lo` = 60 %, eine nach oben ganz): Die
  Falten zwischen den Kugeln und die Unterseite der Krone sind dunkel – das Umgebungslicht des Renderers kommt von
  allen Seiten gleich, das Sprite wurde unter einem Himmel gerendert.
- **Unterteilung im Budget** (`_rim_plan`, AS3R): jede Kuppel hat in lod0 einen Rand aus 12 Ecken (1, 6, 12); die
  wichtigsten bekommen einen Ring mehr vor dem Rand (1, 6, 12, 12), solange die 2 500 Dreiecke reichen – gewichtet
  nach Sichtbarkeit von der Straße (Kuppeln mit nach unten oder seitlich zeigender Achse zuerst). lod1 (900) liegt
  auf **demselben Rand**: jede zweite seiner Ecken (gleiche Lage, Verwacklung und Texturlage) als (1, 3, 6), sonst
  als Fächer (1, 6); bleibt Budget (Kronen mit wenigen Kugeln: Kiefer, Olive, Birke), der ganze Rand (1, 6, 12). Innere Ringe liegen ein wenig neben ihrem Ring (Winkel ±22 % eines Schritts, Radius ±7 %),
  der Rand ist stärker ausgefranst (siehe „Nacharbeit nach der Kunstkritik (AS3R)“).
- **Blattkugel-Zellen** des Atlas (`leafatlas.ball`): innen eine deckende Laubmasse (Blätter auf tieferem Laub, nie
  ein Loch), außen ein zerzauster Rand einzelner Blätter; Halo-Alpha 0,28 wie in Bauabschnitt 2 (mipmap-fest,
  unter der Schwelle 0,42 auch nach der BC3-Quantisierung). Keine eigene Licht-und-Schatten-Malerei in der Textur:
  die Kuppel schattiert.
- **Zelle, Drehung und Windphase einer Kugel** sind in beiden Stufen gleich (eigener Zufallsstrom je Kugel): beim
  Stufenwechsel bleiben die Blätter einer Kugel, wo sie waren.
- **Kern:** eine geschlossene Hülle (Strahlen von der Kronenachse zur fernsten Kugel, 0,86 eingezogen; Normalen der
  getroffenen Kugel) in einem tiefen, aber nicht schwarzen Laubton – was zwischen zwei Kuppeln offen bleibt, zeigt
  tieferes Laub, nie den Himmel. Birke und Kiefer haben keinen (ihre Kronen sind licht).
- **Holz:** Stamm und Äste des Generators (ein Stamm wird nie angeschnitten – ein halbes Rohr zeigte den Himmel), ein
  Ast in jeden Kugelhaufen (k-Means), Äste und Astteile außerhalb der Krone fallen weg (keine dunklen Stöcke auf
  einer flachen Olivenkrone), das Holz ist in der Krone durch dieselbe Verdeckung abgedunkelt (keine hellen
  Aststummel). Der **Stammfuß reicht 0,55 m unter den Boden** mit 12 % Wurzelanlauf: am Hang schwebt kein Baum.
  Olivenstämme sind knorrig (Verschiebung entlang der Normalen); Dreiecke, die das umklappt, werden nach ihrer
  Normale gewickelt.
- **Farbe:** Die Palette jeder Art sind die beiden Laubfarben ihres Generators, mit Sättigung `sat`, Wert `gain` und
  Tönung `tint` so eingestellt, dass die Krone im Renn-Licht (Mittag, Voreinstellung „Mittel“) dieselbe mittlere
  Helligkeit und denselben Farbton zeigt wie das Sprite am selben Ort (gemessen mit `prop_scene.sh --mode=lods
  --look=race --sprite`, Tabelle im Bericht). `lift` hebt lod1 auf die mittlere Helligkeit von lod0 an der
  Umschaltentfernung.
- **Fernbild:** das Bild von lod0 (Albedo × Eckhelligkeit; das Himmelslicht steckt schon darin), Verstärkung und
  Blauanteil je Art (`imp`: die Kuppeln spiegeln den Himmel, das Fernbild nicht) so gewählt, dass es bei Tag
  innerhalb von 5 % von lod1 bleibt (gemessen an den inneren Pixeln; der Rand dünner Bäume ist durch die
  Kantenglättung der Netze mit dem Himmel gemischt, beim Fernbild nicht). Ausnahme Fichte: ihre Astkarten zeigen
  nach oben und bekommen mittags mehr Sonne als das Fernbild, abends weniger – eine feste Verstärkung kann nur
  mitteln (Mittag −8 bis −11 %, Dämmerung +2 bis +6 %). Im fernen Nebel ist es nicht blasser als das
  Arcade-Sprite im selben Nebel (Bild im Bericht).

### Sonderkronen (`ce3d/veg3d_shapes.py`)

| Art | Krone |
|---|---|
| Fichte | jede Etage des Generators: ein geschlossener innerer Kegel (Nadelmasse; seine Unterseite zeigt nach unten und bleibt dunkel), auf seiner Oberseite Astkarten (Zweig vom Stamm zur hängenden Spitze, Nadeln), lod0 zwei Lagen um eine halbe Teilung gedreht |
| Zypresse | der Drehkörper der Flamme des Generators (20 × 30 Teilungen), glatt wie im Sprite, ein wenig klumpig (der Generator verschiebt seine Fläche um 0,35 m), dichte Zweig-Textur |
| Palme | Stamm neu mit einem Ring alle 0,24 m (dunkle Rinde, jedes zweite Ringband ±8 % heller, leichte Wülste); jeder Wedel des Generators als gebogener, flach V-förmig gefalteter Streifen entlang seiner Mittelrippe mit Fiedern (AS3R: breiter und hängender als der Generator-Wedel, weil die Fiedern Himmel durchlassen); dunkler Kronenschaft und Nüsse; kein eigener Schattenwerfer (die Wedel werfen ihre Fiedern selbst) |
| Kiefer | Waldkiefer wie ihr Sprite: hoher Stamm, unten dunkel, oben orangerot, flache Nadelpolster als Laubkuppeln |

### Heide, Büsche, Felsen, Klippe

- **Heide** (`build_bush`, Hook `SHAPE_LOG["heather"]`): die rosa und grünen Büschel des Generators als Laubkuppeln;
  rosa Büschel aus Zellen mit Zweigen voller Blüten, grüne aus feinen Zweigen. 390 / 118 Dreiecke, ein Aufruf.
- **Büsche und Bodendecker:** dieselben Laubkuppeln, nur Klasse `leaves`; die untersten Kugeln des Generators liegen
  schon im Boden (am Hang schwebt nichts).
- **Felsen und Klippe** (neuer Bauer `rock`, `ce3d/rock3d.py`): die Geometrie des Generators mit angewandten
  Modifikatoren (verschobene Ikosphären: echte Facetten), bei Bedarf auf das Budget dezimiert, das Gesteinsmaterial
  des Sprites (Rissnetz, Schichtbänder, Moos auf den Oberseiten; bei der Klippe die Sträucher) mit Cycles in einen
  Atlas gebacken, mit Umgebungsverdeckung; der Fuß der Klippenwand 0,9 m in den Boden, die Felsfüße 0,45 m (AS3R).
  Die Klippe ist im 3D-Bau ein geschlossener Felskörper (Generator-Parameter `solid3d`, siehe AS3R). Eine Fläche
  `baked` = ein Aufruf, automatische Stufen (`auto_lod`, keine Lampen).

### Wind, Schnee und Nässe – was die Modelle liefern

`COLOR` der Klasse `leaves`: r = Ausschlag nach Höhe (Stamm steif: er ist `vpbr` und schwingt nicht; Krone sanft;
Palmwedel: nach dem Abstand vom Wedelansatz, die Spitzen am weitesten), g = Phase je Kugel bzw. Wedel (alle Ecken
einer Kuppel schwingen gemeinsam), b = Steifheit (Laub 0,55, Pappel 0,35, Fichte 0,7, Zypresse 0,75, Palme 0,15),
a = Helligkeit. Das Fernbild schwingt nicht. `NORMAL` zeigt aus der Kugel (Kuppeln), aus dem Kegel (Fichte), aus
dem Drehkörper (Zypresse) bzw. aus der Wedeloberseite (Palme) nach außen und oben: Ein Schnee-Term im
`leaves.gdshader` kann mit `NORMAL.y` die nach oben schauenden Teile weißen, ein Nässe-Term sie abdunkeln. Nichts
leuchtet selbst.

### Hooks im Generator (Voreinstellung = Sprite)

| Hook | Generator | im 3D-Bau |
|---|---|---|
| `SHAPE_LOG` | `tree_spruce`, `tree_cypress`, `tree_palm`, `heather` | Etagen (Höhe, Radius, Ringpunkte) und Spitze; Profil der Flamme; Stamm und Wedel; Büschel mit Farbe |
| `CROWN_LOG` | `tree_pine` | die Nadelpolster als Kronenkugeln |
| Knoten `crown` | Kiefer, Fichte, Zypresse, Palme, Heide | die Kronenobjekte ersetzt das Modell |
| `tiers`, `taper` / `bulge`, `width` / `bend` | Fichte / Zypresse / Palme | Parameter der zweiten Variante (Etagen, Verjüngung; Bauch und Breite der Flamme; Krümmung des Stamms) |
| `solid3d` (`crest`, `back_run`) | `cliff` | AS3R: die Klippe als geschlossener Felskörper (Vorderwand des Sprites, Grat, Rückflanke, geschlossene Enden), Sträucher als eigene Objekte auf dem Grat |

`check_sprite_geometry.py --only props` nach allen Hooks (gemessen): **86 von 86 Sets identisch**.

### Werkzeug: `tools/models/prop_scene.sh` mit Renn-Licht

- `--look=race [--hour=12] [--weather=normal] [--preset=medium]`: das Licht eines Rennens statt des kleinen
  Prüf-Rigs – der `EnvironmentRig` des Renderers mit der Palette der Stunde, die Qualitätsstufen der Voreinstellung,
  die Sichtweite des Rennens, der Look, den die Fahrzeug-Ebene auf `vpbr` legt (Stämme sind `vpbr`), der Himmel
  der Palette. Bilder des alten Rigs waren heller und satter als im Rennen.
- `--sprite`: das Arcade-Sprite des Sets als Platzhalter-Billboard im selben Licht und Nebel (Reihe bzw. Spalte).
- `--mode=lods` meldet je Modell `UMSCHALT`: Anteil geänderter Pixel und 3×3-Blöcke, Helligkeits- und
  Farbtonsprung an beiden Umschaltentfernungen (Helligkeit aus den inneren Pixeln). Jede Spalte zeigt die
  Darstellung, die der Props-Bauer für Stufe 0/1/2 nimmt (`PropLibrary`-„reps“): ein Busch ohne Fernbild bleibt
  jenseits der zweiten Entfernung lod1, ein Felsen mit einer Stufe (automatische Netz-Stufen) bleibt lod0.
- `--mode=clip`: die Kamera fährt mit `--kmh` an Baumreihen entlang, jedes Bild wird geschrieben (Flimmern,
  Stufenwechsel Bild für Bild).

### Nacharbeit nach der Kunstkritik (AS3R)

Die unabhängige Kunstkritik von AS3 fand drei Dinge gröber als das Sprite (Birkenstamm, Palme, Klippe) und
mehrere mittlere Mängel. Was geändert ist (Messungen im Bericht des Pakets):

- **Birkenrinde** (`_birch_marks`, `_birch_trunk`): weiße Rinde mit dünnen Querbändern statt eines Schachbretts aus
  Dreiecken. Jede Marke ist ein eigenes Ringpaar (5–8,5 cm hoch, am Fuß höher und dichter, in der Krone spärlich),
  dunkel über 1–4 von 6 Segmenten; Farbe je Viereck, der dunkle Fuß als weicher Verlauf. lod1 zeigt dieselben
  Marken an denselben Stellen, nur die größeren, doppelt so hoch und halb so dunkel – gleiche mittlere Farbe, keine
  Streifen unter einem Pixel, die bei 60 m und weiter flimmern würden.
- **Kuppelränder** (Kritik: „Lampenschirm“ aus geraden Vieleck-Kanten unter 25 m): der Rand jeder Kuppel ist
  ausgefranst (Winkel ±35 % eines Schritts, Radius ±12 %), jede zweite Randecke hängt 5–10 % des Kugelradius tiefer
  (hängendes Laub statt einer Kante); die Kuppeln, die man von der Straße sieht (Achse nach unten oder zur Seite),
  werden zuerst verfeinert; Äste nur innerhalb von 90 % der Kugeln und 92 % der ganzen Krone (`WOOD_HULL`,
  `WOOD_MASS`); der Kern liegt näher an den Kuppelrändern (0,86 statt 0,8: weniger Himmelslöcher).
- **lod1 auf dem Rand von lod0** (Kritik: das Blattmuster springt beim Wechsel): lod1 nimmt jede zweite Randecke
  von lod0 unverändert (Lage, Verwacklung, Texturlage), mit Budget übrig den ganzen Rand. Ein lod1 aus reinen Fächern
  über den ganzen Rand von lod0
  wurde gebaut und verworfen: die flachen Kegel sinken in die Kugel, der Kern scheint durch (gemessen: lod1 26 %
  dunkler, 15 % kleiner, stachelig). Der Anteil geänderter Pixel beim Wechsel bleibt hoch (harte Stufe); die
  eigentliche Abhilfe ist eine kurze Dither-Überblendung im Props-Bauer (R2/R7).
- **Fernbild mit Relief** (Kritik: 30–80 % weniger Kontrast als lod1): ein Teil `relief` der Helligkeit ist das Licht
  des Sprite-Rigs (`cesprites/rig.py` `SUN_DIR`, Himmel von oben, umwickelt wie `leaves.gdshader`) auf den eigenen
  Normalen des Modells (Attribut `ce_nrm` – Cycles dreht die Normale einer von hinten gesehenen Fläche zur Kamera),
  auf den Mittelwert 1 der zur Straße zeigenden Ecken normiert: Sonnenseite und Falten der Krone sind zurück, die
  gegen lod1 gemessene Verstärkung bleibt. Die Fichte bekommt zusätzlich einen Anteil `lit` einer echten
  Cycles-Beleuchtung mit Schatten (jede Etage schattet die nächste – sonst fehlen die Etagen), `sat` hebt die
  Sättigung, ein Alpha-Halo (0,32) hält dünne Stämme und Wedel in den gröberen Mipmaps. Gezeigt wird es weiter mit
  dem Gesetz von `billboard.gdshader` ohne `baked_light` – der Renderer braucht dafür nichts Neues.
- **Ein Laubatlas je Art**: eine Saat-Variante (`variant_of`) zeichnet mit dem Atlas ihrer Art
  (`"textures": {"leaves": "props/tree_oak/leaves.png"}` im Fragment der Variante, Schlüssel `variant_of`);
  `export.py` lässt Pfade mit Ordner stehen, `validate_models.py` erlaubt genau diese Textur. Texturquellen
  37,1 → 22,1 MB, im Rennen ein Atlas und ein Material je Art.
- **Büsche**: die kleinsten Kugeln des Generators verschmelzen mit ihren Nachbarn (`merge`: höchstens 15 Kuppeln),
  jede Kuppel bekommt einen 12-eckigen Rand (vorher Fächer aus 5–6 Ecken); lod1 hat einen Kern und die Kappen von
  lod0 (vorher ein dunkles Loch); die Laubbälle sind satter (`sat` 0,72) mit weniger hellen Glanzlichtern
  (`sheen`) und weniger Kontrast (`contrast` 0,2).
- **Am Hang**: Büsche, Bodendecker und Heide haben einen Kern mit Schürze bis 0,4 m unter den Boden
  (`_bush_core`), Grashalme beginnen 0,1 m unter dem Boden, die Felsfüße reichen 0,45 m hinein. Für den
  Props-Bauer tragen die Modelle Kennzeichen in `tags`: `ground_align` (flache Pflanzen: an die Bodennormale
  kippen), `ground_sink` (Felsen: auf den tiefsten Bodenpunkt der Grundfläche setzen), `face_road` (Klippe:
  Schauseite zur Straße, höchstens ±20° drehen).
- **Klippe** (`props_nature._cliff_solid`, nur im 3D-Bau): die Vorderwand des Sprites bis zu seiner Gratlinie, ein
  runder Grat von 1,8 m Dicke, eine steile Rückflanke bis unter den Boden, beide Enden mit Ringen geschlossen;
  dieselbe Verschiebung, Felsbrocken und Sträucher – diese als eigene Objekte, die `rock3d._seat_shrubs` per
  Strahl auf den verschobenen Fels setzt. Von hinten und von der Seite Fels statt Fetzen und Horn.
- **Palme**: Wedel breiter (Halbbreite 0,78 m), weniger gefaltet und hängender, mit mehr und breiteren Fiedern;
  dunkler Stamm mit Ringen als ±8 % Helligkeit; `palm_b` gebogen wie das Sprite (nur eine andere Saat); Fernbild
  512 px.
- **Kleinkram**: Olive mit weniger und weniger hellen Blattunterseiten; Kiefer-Stamm oben 15 % dunkler, ruhigerer
  Polsterrand; Zypresse
  mit einer Windphase je Ring und nach oben gekippten Normalen in der oberen Hälfte der Flamme (für Schnee und
  Nässe).

## 19. Gebäude, Brückenteile und Schiffe (Bauabschnitt 5, AS4)

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

Messungen vorher (AS4) / nachher (AS4R), Software-OpenGL, Renn-Look der Prüfszene bzw. `tools/ab_shot.sh`:

| Messung | AS4 | AS4R | Arcade / Sprite |
|---|---|---|---|
| Pylon: Seilende quer (Aufstellung 7,55 m; Fahrbahnkante 3,75 m, Geländer 6,25 m) | 3,35 m | 6,40 m | 6,15 m |
| Pylon: Fächer längs | ±82,7 m | ±36 m | 33,8–62,6 m je Brücke |
| Pylon: Stufenwechsel | 58 % der Pixel | eine Stufe | – |
| Anteil Braun unter den dunklen, farbigen Pixeln, Nahansichten 12 Uhr (Laden / Altstadt / Block A / Block B / Haus) | 8,3 / 21,4 / 23,6 / 16,4 / 10,6 % | 0,0 / 3,3 / 4,1 / 2,8 / 5,2 % | – |
| Fensterlicht Paris–Tours km 131,3, 23 Uhr, hoch: Spitze / Pixel > 150 / Pixel > 200 | 165 / 143 / 0 | 216 / 379 / 163 | 225 / 543 / 388 |
| Fabrik nachts, acht Drehungen bei 70 m: weiße Pixel über den Wänden / hellster Wert | 12 690 / 255 | 0 / 163 | – |
| Kirche im Rennbild Paris–Tours 12 Uhr: Wand Mittel / 95. Perzentil | 204 / 229 | 181 / 200 | 173 / 194 |
| Fachwerkportal: Kontrast zum Himmel bei 100 / 250 / 400 m | 95 / 100 / 82 | 108 / 106 / 94 | 109 / 131 / 138 |
| Mühle: Flimmern mit bewegter Kamera bei 60 / 120 / 250 / 400 m | 4,2 / 3,3 / 5,5 / 7,5 % | unverändert | 2,9 / 2,5 / 4,4 / 4,3 % |
| Block B: Flimmern bei 60 / 120 / 250 / 400 m (Nebenwirkung der Scheiben) | 0,1 / 0,1 / 0,7 / 0,9 % | 0,2 / 1,0 / 0,8 / 0,6 % | 0,1 / 0,2 / 0,5 / 0,4 % |
| Stufenwechsel bei 60 m, mittel (Haus / Kirche / Fabrik / Laden / Altstadt / Block A / Block B) | 11,3 / 3,4 / 6,5 / 4,2 / 8,1 / 8,3 / 8,9 % | 11,2 / 3,0 / 7,0 / 5,4 / 8,4 / 8,2 / 9,4 % | – |

**Nicht im Modell lösbar** (an die Renderer-Pakete): Fähren und Hausboote stehen ohne Wasser auf der Wiese (R2:
Requisiten mit `h` < 0 auslassen, bis R5 Wasser hat – behoben im Fernboden durch FIX-WASSER, in der M2-Linie seit
M2ZS1: die Scheibe liegt unter dem Wasser, die Schiffe schwimmen); der Nachtatlas des Pylons ist der angestrahlte Pylon
des Sprites, den Arcade nie zeigt (der Renderer zeichnet die Pylone der Brücken nachts ohne ihn und dunkler, M2ZS1,
renderer-modern.md 14.7); die Höhe des Pylons folgt nicht `height_m` der Brücke (50–120 m,
das Modell hat 88,8 m), und gerade Seile folgen keiner Kurve (bei R 449 m liegt ein Seilende bis 1,4 m neben der
Deckkante – auf dem Seitenstreifen, nicht in der Fahrbahn); die Phase der Rotoren hängt an der ursprungsrelativen
Weltposition und springt bei jedem Versatz des Ursprungs (alle 2 km).
