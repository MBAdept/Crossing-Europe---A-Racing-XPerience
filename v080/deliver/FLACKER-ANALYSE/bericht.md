# FLACKER-ANALYSE: Ein weißer Pkw verlor kurz seine Lackierung (ZS1, Kassel–Erfurt)

Rolle: Analyse von Code, Shadern und Modellen. Nur gelesen: kein Commit, kein Branch, keine Änderung am Repository.
Untersucht wurden zwei Stände:

- **ZS1** = `39849f0` (erster Testbuild, den der Nutzer gespielt hat)
- **M2-Kopf** = `6e48405`

Gemessen wurde auf dieser VM mit llvmpipe (Software-OpenGL) unter Xvfb oder headless, mit Godot 4.7.2 und dem
Spielstand ZS1 (Scratch-Kopie, `git archive`). Alles über die echte Grafikkarte des Nutzers ist **abgeleitet**, nicht
gemessen. Kennzeichnung im Text: **gemessen** / **abgeleitet**.

Bericht des Nutzers (12.11.): Ein weißer Pkw etwa 40 m vor ihm „verlor kurz seine Lackierung“, zweimal in der Etappe,
offenbar im Zusammenhang mit seinem Lenken. Main-PC unter Windows, echte Grafikkarte, vermutlich Modern mit dem Preset
des ersten Starts.

## 1. Ergebnis in Kürze

1. **Bei 40 m wechselt jedes Modell-Auto seine Detailstufe (lod0 ↔ lod1), hart und ohne Überblendung.**
   - Bei „Mittel“ (Preset des ersten Starts auf einem PC mit Grafikkarte) geschieht das, wenn die Wagenmitte 38–42 m
     vor der Kamera ist. Das sind rund 25–30 m Lücke zwischen den Stoßstangen.
   - Lenken bremst durch Untersteuern um bis zu 3 m/s². Dadurch pendelt der Abstand durch das 4-m-Band, und das Auto
     springt bei jedem Durchgang. Das passt genau zu „40 m“, „zweimal“ und „beim Lenken“.
   - **Gemessen:** Der Wechsel ändert 5,7–11,4 % der Autopixel um mehr als 24 Stufen (Kennzeichen erscheint oder
     verschwindet, Lampenringe, Scheiben), die Mittelfarbe um 1,2–4,0 Stufen. **Der Lack selbst bleibt.** Die Regel
     „Stufenwechsel unsichtbar“ ist damit verletzt, bei jedem Modell-Pkw und jedem Preset.
2. **Den Lack wirklich verlieren kann ein Auto in ZS1 nur auf einem Weg: Godot lehnt die Instanz-Uniforms einer
   Fahrzeugstufe ab** (globaler Shader-Puffer voll, 254 Instanzen für die ganze Szene).
   - Dann ist die Karosserie schachbrettartig durchsichtig und flach überstrahlt: **gemessen** 52–63 % der Autopixel
     ändern sich um mehr als 24 Stufen, die Mittelfarbe um 21–72 Stufen.
   - Die Ablehnung bleibt, bis der Knoten frei wird. Sichtbar wird sie genau beim Wechsel in die kaputte Stufe, also
     wieder am 40-m-Band.
   - **Auf dieser Etappe nicht nachgestellt.** Neu gemessen im echten Rennen unter Xvfb mit einer Probe, die die freie
     Kapazität des Engine-Puffers direkt misst: **0 Ablehnungen**, kleinste freie Kapazität **48 Instanzen** (ab
     Kassel, km 136, 17 Uhr, Verkehr vorgewärmt). Headless über die ganze Etappe: kleinste Reserve **40**
     (214 Instanzen).
     Die Zählung der Szene stimmt in jeder Probe exakt mit der Engine überein (keine versteckten Verbraucher).
   - Für einen Überlauf beim Nutzer hätte die Szene also um rund 40 Instanzen voller sein müssen als an der dichtesten
     gemessenen Stelle (etwa drei Lkw zugleich in lod0, je 13 Instanzen).
3. **Rangfolge** nach der Passung zu „weißer Pkw, etwa 40 m, verliert kurz den Lack, zweimal, beim Lenken“:
   - **Rang 1, wahrscheinlich: der harte Stufenwechsel (M2).** Er tritt sicher und genau dort auf. Nur das Wort
     „Lackierung“ passt nicht ganz: Es springen Kennzeichen, Lampen und Scheiben, der Lack bleibt. Der Nutzer nennt es
     selbst „Grafikflackern“ und setzt „verlor“ in Anführungszeichen. Dass er es nur zweimal und an einem weißen Auto
     bemerkte, passt: Auf Weiß stechen die dunklen Details des Hecks am stärksten hervor; meist kreuzt ein Auto das Band
     nur einmal, auffällig wird es erst beim Hinterherfahren mit Lenkkorrekturen; weiße SUV und Transporter sind in ZS1
     Ersatzbilder ohne Stufen (**abgeleitet**).
   - **Rang 2, möglich, aber nicht belegt: die abgelehnte Stufe (M1).** Sie nimmt dem Auto wirklich den Lack, braucht
     aber einen Überlauf, den ich auf dieser Etappe nicht erzeugen konnte.
   - **Rang 3, klein: die Grenze der Schattenkaskaden (M3)** in derselben Entfernung (36 m bei Mittel, 40 m bei Hoch).
     Sie ändert den Schatten unter dem Heck, nicht den Lack.
   - **Widerlegt:** Lackcodes im Atlas, Mipstufen und BC-Kompression (Fahrzeuge haben keine Textur), veralteter
     Uniform-Cache, ein Bild mit alten Puffer-Werten nach dem Bau einer Stufe (gemessen), fehlender LOOK, Pool über
     Farben hinweg, verspätet geladenes Modell, Materialwechsel an geteilten Netzen, F5-Ausblendung bei 40 m,
     Ersatzbild-Zelle außerhalb des Bereichs, Scheinwerfer, die der Lenkung folgen.
4. **Billig und entscheidend: das Log des Nutzers.** `%APPDATA%\crossing-europe-zwischenstand\logs\godot*.log` und
   `settings.json` (Preset, Details). Steht im Log „Too many instances using shader instance variables“, war es M1.
   Steht es nicht darin, war es M2.
5. **Behebung, unabhängig vom Log nötig:** Beide Ursachen sind echte Mängel im ZS1 und im M2-Kopf. Abschnitt 8 hat die
   Möglichkeiten. Empfehlung: Modelle so angleichen, dass der Stufenwechsel unsichtbar wird (D), und Instanz-Uniforms
   nur noch dort, wo ihre Zahl beschränkt ist, mit einem Budget für die ganze Szene (A + B, Wächter C).

## 2. Was „40 m“ im Spiel ist (Code und Zahlen)

- **Entfernungen:** Der Kilometerzähler läuft zehnmal schneller als die sichtbare Straße (`time.time_scale` 10).
  Die „realen 40 m“ des Nutzers sind sichtbare Meter, wie die 40 m der Detailstufen.
- **Kamera:** 9 m hinter der Wagenmitte des Spielers (`render.camera_distance_m`), 3,4 m hoch. Die Blickrichtung hängt
  nur von der Position ab (`chase_camera.gd:39–59`, `look_yaw`), nicht von der Lenkung. Seitlich folgt `camera_x` dem
  Spieler mit Verzögerung.
- **Entfernung für die Stufe:** `dist = z + length/2 - cam_z`, Wegstrecke Kamera → Wagenmitte
  (`layers/vehicles.gd:539`). Seitliches Lenken ändert sie nicht, das Tempo schon.
- **Lenken ändert das Tempo:** Untersteuern zieht bis zu 3 m/s² ab (`scripts/gameplay/vehicle_model.gd:92`
  `_us_scrub_max` 3,0, Config `driving.understeer.scrub_max_mps2`). Eine Sekunde Untersteuern verschiebt den Abstand
  um rund 1,5 m, zwei Sekunden um rund 6 m: genug für das 4-m-Band (**abgeleitet**).
- **Stufengrenzen:** `VehiclePose3D.lod_index()` (`vehicle_pose3d.gd:168–176`), Manifest-`max_dist_m` mal
  `vehicle_lod0_m / 40` bzw. `vehicle_lod1_m / 120` (`vehicles.gd:252–253`), Hysterese `LOD_HYSTERESIS` 0,05
  (`vehicle_pose3d.gd:19`). lod0 ↔ lod1 wird **nicht** überblendet (`XFADE_LODS = ["lod1", "lod2"]`,
  `vehicles.gd:71`; Wechsel `vehicles.gd:549–564`). lod1 ↔ lod2 wird 0,5 s überblendet.

| Preset (Details) | Pkw, Polizei: lod0 ↔ lod1 | lod1 ↔ lod2 | Lkw, Bus: lod0 ↔ lod1 | lod1 ↔ lod2 |
|---|---|---|---|---|
| Niedrig (0) | 25 m (23,75–26,25) | 90 m | 37,5 m | 135 m |
| Mittel und Deck (1) | **40 m (38–42)** | 120 m | 60 m | 180 m |
| Hoch (2) | 60 m (57–63) | 160 m | 90 m | 240 m |

Spielerautos haben nur lod0 (kein Wechsel). Werte gleich in ZS1 und M2-Kopf.

- **Schattenkaskaden** (`environment_rig.gd:181–194`, Config `graphics.levels.shadows`): Mittel 2 Kaskaden,
  Grenze 0,3 × 120 m = **36 m**, ohne Überblendung; Hoch 4 Kaskaden mit Überblendung, 16 / **40** / 90 m; Deck
  0,3 × 80 m = 24 m; Niedrig keine Schatten.
- **Preset des Nutzers:** Ein Adapter, der weder Software noch „weak“ noch Deck ist, gilt als „ok“
  (`scripts/core/gfx.gd` `classify_adapter`), `recommended_preset("ok")` = **„medium“** (`gfx.gd:125–131`,
  **abgeleitet**). Hat er „Hoch“ gewählt: Stufengrenze 57–63 m, Kaskadengrenze 40 m.
- **Rennen und Richtung** (gemessen mit dem Routen-Skript über `RoadNetwork.race_routes`): `erfurt_kassel` kommt nur
  im Rennen **Dresden–Dortmund** vor (Dresden–Leipzig–Erfurt–Kassel–Dortmund), Richtung **Erfurt → Kassel**.
  **Kassel → Erfurt** gibt es nur als Einzeletappe.

## 3. Weiße Pkw in ZS1 und im M2-Kopf

- **ZS1:** Verkehrs-Pkw werden gleichverteilt aus den Sets mit dem Tag „traffic“ gezogen (`traffic_system.gd:1304`).
  Weiß sind `traffic/hatch_white` (#e8e8e5) und `traffic/wagon_white` (#e6e6e3) als **Modelle**, `traffic/suv_white`
  und `traffic/van_white` als **Ersatzbild** (Arcade-Bild, A-9). Ein weißer Pkw ist in ZS1 also etwa zur Hälfte ein
  Modell. Die deutsche Polizei ist silbern (#c9cdd3) und in ZS1 ein Ersatzbild.
- **M2-Kopf:** Auch SUV, Transporter, Sportwagen, Bus und Polizei sind Modelle; Weiß ist einheitlich #d8d8d5.

## 4. Die Mechanismen im Einzelnen

### M2 – Harter Wechsel lod0 ↔ lod1 bei 38–42 m → Rang 1

**Code:** `vehicles.gd:549–564` (Wahl der Stufe, `_set_level`), `vehicle_pose3d.gd:168–176`, `XFADE_LODS`
`vehicles.gd:71`.

**Bedingungen:** jedes Preset (Band 25 / 40 / 60 m), jedes Modell-Auto (Pkw, Polizei im M2-Kopf, Lkw und Bus bei
1,5-facher Entfernung), Tag und Nacht. Ausgelöst, sobald der Abstand das Band kreuzt: Aufholen, Zurückfallen,
Untersteuern beim Lenken.

**Was sich ändert** (gemessen, Kontrollszene mit Spielkamera, Licht genähert, Bogen
`stufen_kaskade_ablehnung.png`, Spalten 1 und 2):

| Wechsel bei 40 m (36 m seitlich) | Autopixel > 24 Stufen | Änderung der Mittelfarbe |
|---|---|---|
| lod0 → lod1, 1280×800 / 1920×1080, Sonne hinten, vorn, seitlich | 5,7–10,6 % | 1,5–3,3 |
| lod0 in Kaskade 1 → lod1 in Kaskade 2 (Mittel, Auto quert dabei die 36-m-Grenze) | 8,5–11,4 % | 1,2–4,0 |
| lod1 → lod2 (überblendet 0,5 s) | 16,8–26,5 % | 3,7–11,7 |

- Am auffälligsten: das **Kennzeichen**. lod0 hat ein Schild mit Zeichen und Euroband, lod1 ein leeres Feld
  (`#c4c4c1`) bzw. beim Schrägheck gar keins.
- Dazu Lampenringe und dritte Bremsleuchte (fallen weg) und die Scheiben: lod0 `glass`-Klasse (spiegelt,
  `env_energy` 2,2), lod1 dunkles `vpbr` (`TRAFFIC_GLASS_FAR`).
- Lack: In allen Stufen trägt die Karosserie Code 0 (`paint`), der Lack wird bei jedem Bau gesetzt
  (`model_factory.gd:122`, `apply_paint` `:214–221`), LOOK und Materialien sind dieselben (Abschnitt 5).

**Wirkung beim Spieler (abgeleitet):** Ein Auto, das gerade noch ein Kennzeichen und spiegelnde Scheiben hatte, ist
im nächsten Bild „glatt“, mit leerer Heckfläche, oder umgekehrt. Beim Hinterherfahren am Band wiederholt sich das bei
jeder Tempoänderung. Ein Spieler kann das als „das Auto sah kurz anders aus“ beschreiben; „verlor seine Lackierung“
ist dafür eine lockere, aber mögliche Beschreibung (die Heckfläche wird einheitlich weiß).

### M1 – Abgelehnte Instanz-Uniforms (globaler Shader-Puffer voll) → Rang 2

**Code und Engine**

- Instanz-Uniforms in `vpbr.gdshader:44–59` (Indizes 0–9: `paint`, `paint2`, `paint3`, `lamp_a`, `lamp_b`, `fade`,
  `sun`, `fill`, `gloss`, `xfade`), `glass.gdshader:11–12` (5, 6), `vehicle_sprite.gdshader:48–49`.
- Godot legt für **jede** Instanz, deren Material Instanz-Uniforms hat, 16 Plätze im globalen Puffer an, sichtbar oder
  nicht. Der Puffer ist so groß wie der Uniform-Block der GPU, 64 KB = 4096 Plätze (llvmpipe, und die meisten
  Desktop-Treiber; die Engine meldet „Maximum items supported by this hardware is: 4096“). Nach den 18 `ce_*`-Globals
  bleiben **254 Instanzen für die ganze Szene** (gemessen, Abschnitt 7: Reserve + Zählung = 254 in jeder Probe).
- Abgelehnt wird mit „Too many instances using shader instance variables“; die Instanz bekommt den Offset −1.
  GLES3 liest `global_shader_uniforms[instance_offset + i]` mit `uniform highp uint instance_offset` (Godot-Binary):
  Index 0 (`paint`) liest außerhalb des Puffers, Index k die globale Variable an Platz k−1 (gemessen,
  `flk_refuse.gd`, `flk_slots.gd`).
- **Neu:** Godot verarbeitet die schmutzigen Instanzen eines Bildes **in umgekehrter Reihenfolge** (zuletzt angelegt
  zuerst). Läuft der Puffer in einem Bild über, trifft die Ablehnung die **zuerst** angelegten Instanzen dieses Bildes
  (gemessen: von 300 Quads wurden Nr. 0–44 abgelehnt, `flk_refuse.gd`).
- Eine Ablehnung heilt nicht: Freigeben anderer Plätze, `visible`, neue Werte, Transform ändern nichts (gemessen,
  `flk_refuse2.gd`). Sie endet erst, wenn der Knoten frei wird.

**Wer in ZS1 Plätze belegt**

- Fahrzeuge: lod0 = Karosserie, 4 Räder, Schattenhülle = 6 Instanzen (Lkw 13); lod1 und lod2 = Körper + Hülle = 2.
  Die Fahrzeug-Ebene hält alle gebauten Stufen bei `INSTANCE_BUDGET` = 128 (`vehicles.gd:37`, `_trim_instances`
  `:1152–1176`), gezeigte Stufen kann sie nicht freigeben.
- Requisiten mit `vpbr` (Eiche, Birke, Hof, Scheune, Laterne, Windrad, Mühle, Zoll, Tankstelle): ein
  MultiMesh-Knoten je Stück, Stufe, Spiegelseite und Werfer (`builders/props.gd:751–772`, `_mmi` `:824`). Erst M2INT
  gab ihnen `VPBR_STATIC` ohne Instanz-Uniforms – **nicht in ZS1**.
- Leitplanken, Torbrücke, Tankstelle, Tunnelportal (`material("vpbr")`, auch im M2-Kopf noch:
  `roadside.gd:356`, `gantry.gd:158`, `station.gd:217`, `tunnel.gd:392`), Bögen der Ersatzbilder und Kastenflächen.

**Wie das weiße Auto dann aussieht** (gemessen, `flk_swap.gd`, Bogen Spalten 5–7)

- Karosserie etwa zur Hälfte schachbrettartig ausgestanzt (die Straße scheint durch), der Rest flach überstrahlt.
- 52–63 % der Autopixel > 24 Stufen, Mittelfarbe 21–72 Stufen.
- Auf einer echten GPU (abgeleitet): Index 0 außerhalb des Puffers ist treiberabhängig (meist 0, unter ANGLE/D3D11
  sicher 0). Die übrigen Indizes liest jede GPU gleich falsch, also auch das Ausstanzen.

**Bedingungen:** Die Szene ist in dem Bild voll, in dem eine Stufe gebaut wird (erster Bedarf, oder Neubau nach
`_trim_instances`). Danach ist diese Stufe dieses Auto-Objekts kaputt, auch für spätere Autos desselben Sets aus dem
Pool (`POOL_PER_SET` 6). Sichtbar bei jedem Wechsel in diese Stufe, am 40-m-Band. Betroffen: alle Fahrzeugmodelle und
Kastenflächen (`kind` 1). **Nicht** betroffen: Pkw-Ersatzbilder (`kind` 0 liest nur `COLOR` und `INSTANCE_CUSTOM`,
`vehicle_sprite.gdshader:85–101`) – ein weißer SUV oder Transporter in ZS1 kann so nicht flackern.

**Bewertung:** Das Aussehen passt am besten zu „verlor seine Lackierung“. Auf dieser Etappe aber in keinem Lauf
erzeugt, und die Reserve lag in jeder Messung bei mindestens 40 Instanzen (live 48, Abschnitt 7). Dazu kommt: Ein
abgelehntes Auto ist schachbrettartig durchsichtig – ein Spieler würde eher „durchsichtig“ sagen als „ohne Lack“.

### M3 – Grenze der Schattenkaskaden → Rang 3

- `environment_rig.gd:143–151` (Bias 0,04, Normal-Bias 1,2, Unschärfe 1,2), Splits `:181–194`.
- Mittel: Grenze 36 m ohne Überblendung; Hoch: 40 m mit Überblendung. Die Texelgröße springt an der Grenze etwa um den
  Faktor 3 (abgeleitet aus der Splitgeometrie).
- Die Kaskaden hängen an der Blicktiefe; die Kamera dreht nicht mit der Lenkung, nur das Tempo verschiebt das Auto
  über die Grenze.
- Gemessen: Kaskadenwechsel bei unverändertem Auto ändert 0,4–4,7 % der Autopixel (> 24 Stufen), Mittelfarbe
  0,1–3,3. Betroffen ist vor allem der Schatten unter dem Heck. Alle drei Stufen werfen denselben Schattenkörper
  (`model_factory.gd:62–117`: jede Stufe bekommt die Hülle `model.shadow`, die Karosserie wirft nie) – der Wechsel
  ändert also die Selbstverschattung nicht.

### M4 – Weitere Pfade, geprüft

| Pfad | Code | Ergebnis |
|---|---|---|
| Uniform-Cache je Auto nicht zurückgesetzt (These des Leads) | `_set_level` `vehicles.gd:1318–1323`, `_acquire` `:1090–1095`, `_set_uniforms` `:852–867` | **widerlegt**: beide setzen `fade`, `sun`, `la`, `lb` auf −1, `_set_uniforms` schiebt im selben Bild (`:632`) |
| Neu gebaute Stufe zeigt ein Bild lang alte Pufferwerte (Plätze einer eben freigegebenen Instanz, Upload zu spät) | Engine | **widerlegt, gemessen** (`flk_firstframe.gd`): neue Instanz auf frischen Plätzen, auf den Plätzen einer im selben Bild freigegebenen, ohne gesetzte Werte und nach einer Wertänderung – jeweils schon im ersten Bild richtig |
| Auto aus dem Pool für anderes Set oder andere Farbe | `_free[set_id]`, `_acquire` `:1065–1105`, Setwechsel `:516–519` | **widerlegt**: Pool je Set, Lack je Set |
| Modell nach dem Erscheinen geladen (`ModelDB.request`) | `prepare` `:258–268`, `prepare_pending` `:302–311` | **widerlegt**: alle gewünschten Stufen geladen, bevor die Etappe startet; fehlt eine, fällt die Etappe auf Arcade zurück |
| LOOK fehlt auf einem später angelegten Material | ZS1 `vehicles.gd:231–233`, M2 `apply_look`; alle Bauer nutzen `ModernMaterials.shared()` | **widerlegt** für Fahrzeuge: genau ein `vpbr`- und ein `glass`-Material, vor allen Bauten angelegt |
| Materialwechsel an einem geteilten Netz (`surfaced_mesh` setzt das Oberflächenmaterial des gecachten Netzes; M2 `class_for` → `VPBR_STATIC` für Nicht-Fahrzeuge) | `model_factory.gd:186–198` | **widerlegt**: keine Netzdatei wird von einem Fahrzeug- und einem Nicht-Fahrzeugmodell geteilt (ZS1 68, M2 282 Netze geprüft, `shared_mesh.py`) |
| Lackcodes, Atlas, Mipstufe, BC-Kompression | `vpbr`/`glass` ohne `sampler`; Netzdaten Abschnitt 5 | **widerlegt**: Lack sind Vertexcodes (0,000 / 1,000), keine Textur |
| Provoking Vertex des `flat`-Codes (GL letzte, D3D erste Ecke) | `vpbr.gdshader:128, 245` | **widerlegt**: 0 Dreiecke mit gemischten Codes |
| Überblendung lod1/lod2 hängt | `_xfade_begin/_step/_end` `:1188–1238` | bei 40 m nicht beteiligt; jeder Abbruch endet in `_xfade_end` |
| F5-Ausblendung (Dither) bei 40 m | `VehiclePose3D.fade` `vehicle_pose3d.gd:51–55` | **widerlegt**: beginnt bei 0,45 × Sicht (Sicht 900 m × Wetter × Nacht); im Tunnel bei 40 m Alpha 0,97 |
| Ersatzbild: Zelle außerhalb des Bereichs (falsche Bildzeile) | `vehicles.gd:656–749`, `VehicleStandIn.traffic_cell`, `VehiclePose.pick_cell` | **widerlegt**: Zelle immer gültig; Zellwechsel am Lenk-Yaw wie in Arcade |
| Klarlack-Sonnenglanz, Himmelsspiegelung, `sky_update_s` | `vpbr.gdshader:308–325, 375–386` | heller Fleck möglich, kein Lackverlust |
| Scheinwerfer des Spielers schwenken mit der Lenkung | `lights.gd:252–290` | **widerlegt**: Richtung = Straßenrichtung |
| Lecks über Etappen (alte Renn-Szene hält Plätze) | `game_flow.gd:186–190` (`queue_free` vor dem Zeichnen) | **abgeleitet unwahrscheinlich**; am Etappenstart stimmte Engine = Szene (Abschnitt 7) |

## 5. Stufen der Fahrzeugmodelle (gemessen, `flk_dump_meshes.gd` → `meshes_zs1.json`, `meshes_m2.json`)

Alle Verkehrs-, Polizei- und Spielermodelle beider Stände:

- **Lackcodes:** Pkw nur 0,000 (`paint`) und 1,000 (feste Farbe); Lkw und Bus zusätzlich 0,251 (`paint2`), 0,502
  (`paint3`); Polizei-lod0 zusätzlich 0,220 (`paint2`, nur lod0). Abstand zu den Schwellen des Shaders
  (0,125 / 0,375 / 0,75) bei Verkehrsmodellen mindestens 0,124. 0 gemischte Dreiecke in jeder Stufe.
- **Klassen:** lod0 = `vpbr` + `glass` (Scheiben 6–9 % der Heckansicht); lod1, lod2 = ein `vpbr`-Körper.
- **LOOK:** ZS1 `vehicles.gd:51–62` (`env_energy` 1,6, `paint_base` 1,0, `paint_knee` 0,7, Steigung 0,45,
  `paint_desat` 0,08, `flake_strength` 0,6, `lamp_off` 0,28, `tail_level` 0,5, `env_night` 0,35, `fill_night` 0,3;
  `glass` `env_energy` 2,2) auf dem einen gemeinsamen Material – gleich für jede Stufe. M2: `VEHICLE_LOOK`, gleiche
  Werte bis auf `flake_strength` 0,0.
- **Lack-Uniforms:** je Set bei jedem Bau (`apply_paint`); fehlt einer, gilt die Vorgabe (0,5, 0,5, 0,52), grau.
- **Normalen:** lod1 und lod2 übernehmen sie von lod0 (`core.transfer_normals`, `docs/modelle.md` §13), höchstens 6
  Dreiecke je Stufe zeigen gegen ihre Normale.
- **Polizei (M2):** in lod2 fällt `paint3` teils weg (Liverie vereinfacht).

| Modell | Stufe | Dreiecke (ohne Räder) | Lack | fest | glass | Codes |
|---|---|---|---|---|---|---|
| `traffic/hatch` (beide) | lod0 / lod1 / lod2 | 14 388 / 5 661 / 1 180 (M2 1 197) | 0,63 / 0,58 / 0,57 | 0,30 / 0,42 / 0,43 | 0,07 / 0 / 0 | 0 und 1 |
| `traffic/wagon` (beide) | lod0 / lod1 / lod2 | 14 216 / 5 941 / 1 141 (M2 1 176) | 0,63 / 0,58 / 0,53 | 0,30 / 0,42 / 0,47 | 0,07 / 0 / 0 | 0 und 1 |
| `traffic/sedan` (beide) | lod0 / lod1 / lod2 | 14 307 / 5 809 / 1 149 | 0,62 / 0,58 / 0,55 | 0,30 / 0,42 / 0,45 | 0,08 / 0 / 0 | 0 und 1 |
| `traffic/truck` (ZS1) | lod0 / lod1 / lod2 | 4 772 / 4 672 / 1 490 | 0,26+0,23 / 0,23+0,21 / 0,30+0,26 | 0,50 / 0,55 / 0,43 | – | 0 / 0,251 / 0,502 / 1 |
| `traffic/suv`, `van`, `sports` (M2) | lod0 / lod1 / lod2 | 14,0–14,5 k / 5,7–5,9 k / 1,2 k | 0,38–0,52 / 0,35–0,47 / 0,41–0,46 | – | 0,06–0,09 / 0 / 0 | 0 und 1 |
| `police/de` (M2) | lod0 / lod1 / lod2 | 16 985 / 5 656 / 1 196 | 0,45+0,16 / 0,41+0,16 / 0,45+0,09 | – | 0,08 / 0 / 0 | 0 / 0,22 / 0,251 / 1 |

Ganze Tabelle: `m1/FLACKER-ANALYSE/mesh_table.md`. Anteile = sichtbare Fläche von hinten, 5° von oben.

**Welche Stufen beim Wechsel anders aussehen** (gemessen bei 40 m): lod0 ↔ lod1 Kennzeichen, Lampenringe, Scheiben
(6–11 % der Pixel); lod1 ↔ lod2 Kabinenquerschnitt, Radausschnitte, Heckabschluss (17–27 %, überblendet). Eine Stufe,
die bei richtiger Zuteilung den Lack verliert, gibt es in keinem Modell, weder in ZS1 noch im M2-Kopf.

## 6. Was ich nicht messen konnte

- GPU, Treiber, Preset und Tageszeit des Nutzers; ob in seiner Fahrt eine Ablehnung stattfand (nur sein Log zeigt es).
- Das Ergebnis des Lesens außerhalb des Puffers auf NVIDIA, AMD oder Intel unter Windows.
- Den Uniform-Block seiner GPU. 64 KB ist üblich (abgeleitet); wäre er größer, gäbe es bei ihm gar keinen Überlauf,
  wäre er kleiner, liefe die Szene ständig über (dann hätte er viele kaputte Autos gesehen, nicht zwei Momente).
- Die Kontrollszene der Stufenbilder nähert das Licht (Palette 13 Uhr, keine `EnvironmentRig`-Lichtaufteilung). Die
  Zahlen gelten für die *Unterschiede* zwischen den Fällen. Nachstellung im echten Rennen macht das Paket
  FLACKER-NACHSTELLEN.

## 7. Nachstellung im echten Rennen unter Xvfb: Engine-Reserve und Ablehnungen (gemessen)

**Verfahren** (`flk_refusal_run.gd`, nur Scratch): echte Renn-Szene `race.tscn`, Modern, Einzeletappe
`erfurt_kassel`, Autopilot, `--fixed-fps 30`, vier- bzw. achtfache Zeit, Xvfb mit llvmpipe (der echte
4096-Platz-Puffer).

- Ein `Logger` fängt jede Ablehnung der Engine, ab dem Ladebild (Aufwärmen eingeschlossen).
- **Engine-Probe:** Alle 30 (Lauf 2: 20) Bilder wird die Renn-Szene für ein Bild angehalten (dann reiht das Spiel nichts ein); in
  `frame_pre_draw` werden 300 Probe-Quads mit einer Instanz-Uniform angelegt, in `frame_post_draw` gezählt und
  freigegeben. Freie Kapazität = 300 − abgelehnte Proben. Proben-Ablehnungen werden getrennt gezählt.
- Daneben die Zählung aller Knoten mit Instanz-Uniforms in der Szene (wie die headless-Zählung `flk_count.gd`).

| Lauf | Abschnitt | Bilder | echte Ablehnungen | Szene max (Laden / Fahrt) | kleinste Engine-Reserve | Fahrzeug-Ebene |
|---|---|---|---|---|---|---|
| 1: Mittel, ab Erfurt km 0, 13 Uhr | km 0–45 | 715 | **0** | 162 (162 / 157) | **105** (km 12,7) | Spitze 128 (Budget griff, 9 Freigaben, 48 Bauten) |
| 2: Mittel, ab Kassel km 100, 17 Uhr, Verkehr vorgewärmt, achtfache Zeit | km 100–136,2 | 372 | **0** | 206 (101 / 206) | **48** (km 136,2) | Spitze 127 (3 Freigaben, 42 Bauten) |

Ein dritter Lauf (ab Erfurt km 124) wurde nach 90 Bildern abgebrochen: Eine kurze Fahrt baut die Fahrzeug-Ebene nicht
auf (26 statt rund 120 Instanzen). Er bestätigte nur Engine = Szene (`lauf2_abgebrochen_km124.log`).

**Ergebnisse**

- **Engine = Szene, in jeder Probe:** Reserve + gezählte Instanzen = 254 (alle 43 Proben der drei Läufe). Es gibt keine
  versteckten Verbraucher (Waisen, Reste früherer Szenen). Die headless-Zählung meines Vorgängers ist damit ein
  gültiges Maß für die Engine.
- **Headless über die ganze Etappe** (`count_*.log`, beide Richtungen, Mittel, Hoch, Deck): höchstens 214 Instanzen
  (ab Kassel km 136: 113 Fahrzeuge, 62 Requisiten, 39 Rest) → kleinste Reserve **40**.
- Live und headless stimmen an der dichtesten Stelle überein: live 206 bei km 136,2 ab Kassel, headless 214 bei km 136.
  Dort treffen die volle Fahrzeug-Ebene (rund 125) und die Requisiten vor Erfurt (bis 62) zusammen.
- Weder im echten Rennen noch headless lief der Puffer auf dieser Etappe über. Ein Überlauf beim Nutzer bräuchte rund
  40 Instanzen mehr als die dichteste gemessene Stelle (z. B. drei Lkw in lod0 mit je 13 Instanzen zugleich, oder ein
  Verkehrsstau); das ist möglich, aber nicht belegt.
- Die Reserve ist dünn (40 von 254, 16 %). Auf Waldetappen im M2-Kopf fand M2INT schon Ablehnungen – die Überlauf-
  Klasse muss unabhängig von diesem Bericht behoben werden (Abschnitt 8, A–C).

## 8. Möglichkeiten zur Behebung

Harte Regeln: Arcade und Simulation bleiben unberührt. Alles spielt im Modern-Renderer und in den Modellen. Fairness
F1/F6: kein Auto später oder kleiner als in Arcade; Lichter behalten ihre Mindestgröße.

| Option | löst | Risiko | Fairness (F1/F6) | Aufwand |
|---|---|---|---|---|
| **D – Stufen angleichen (Ursache von M2, am Modell).** lod1 bekommt das Kennzeichen von lod0 (helles Schild, Band, mittlere Zeichenfarbe als Fläche), Lampenringe als Flächen, Scheibenfarbe = mittleres Bild der `glass`-Scheibe bei 40 m. Abnahme je Modell, Stufe und Preset (25 / 40 / 60 m; Lkw 37,5 / 60 / 90 m), 1280×800 und 1920×1080, Tag/Dämmerung/Nacht: Autopixel > 24 Stufen ≤ 2 %, Mittelfarbe ≤ 1 Stufe | M2 bei allen Modellen | Kunstarbeit je Modellfamilie, Re-Export, Validator, Kontaktbogen; lod1 wird etwas schwerer | keine | M |
| **A – Instanz-Uniforms nur, wo ihre Zahl beschränkt ist (Ursache von M1).** Leitplanken, Tore, Tankstelle, Tunnelportal (`roadside.gd:356`, `gantry.gd:158`, `station.gd:217`, `tunnel.gd:392`) auf `VPBR_STATIC` wie die Requisiten in M2; Schattenhülle der Fahrzeuge (wirft nur, liest nichts) auf ein statisches Material: lod0 6 → 5, lod1/lod2 2 → 1 Instanz; Ersatzbild-Bögen (`kind` 0) in eine Variante ohne `instance uniform` | Überlauf-Klasse, spart rund 40 % der Fahrzeug-Instanzen | gering; Bild gleich (wie `instanzen_wald` für Requisiten zeigte); eine Shader-Variante mehr vorwärmen | keine | S–M |
| **B – Budget für die ganze Szene.** Der Renderer zählt alle Knoten mit Instanz-Uniforms (Bauer melden sie), Grenze 254 minus Reserve. Die Fahrzeug-Ebene hält **einschließlich gezeigter Stufen** ihr Budget; reicht es nicht, zeigt sie für die fernsten lod0-Autos lod1 (Auto bleibt da und gleich groß) | M1 auch bei dichtem Lkw-Verkehr in Hoch | gering; testbar (`check_instance_budget` auf `erfurt_kassel` Hoch mit Stau) | keine (nie unsichtbar, gleiche Größe, Lichter getrennt) | M |
| **C – Wächter.** Ein `Logger` im Modern-Renderer fängt „Too many instances …“, zählt `instance_refusals` in `perf_stats` und im Log, baut nach Platzschaffen die in diesem Bild gebauten Fahrzeugstufen neu (eine Ablehnung heilt nie von selbst). Render-Prüfungen scheitern bei jeder Ablehnung | Restfälle; macht Ablehnungen in Testbuilds sichtbar | Meldungstext kann sich mit einer Godot-Version ändern (Test prüft ihn) | keine | S |
| **A′ – Fahrzeuge ganz ohne Instanz-Uniforms** (je Auto-Objekt ein eigenes `vpbr`- und `glass`-Material aus dem Pool, Werte als Material-Uniforms) | M1 endgültig, kein Budget mehr nötig | mehr Material-Uploads je Bild (rund 2 × sichtbare Autos), auf dem Deck zu messen; Eingriff in R3-Code | keine | M–L |
| **E – Überblendung auch für lod0 ↔ lod1** (`XFADE_LODS` um `lod0`; `glass` braucht dafür `xfade`, Index 9) | verdeckt M2 (0,5 s statt 1 Bild) | löst nichts (Vertrag: Ursache vor Verdeckung); +6 Zeichenaufrufe je Auto für 0,5 s | keine | S |
| **F – Breitere Hysterese** (`LOD_HYSTERESIS` 0,05 → 0,15, Mittel 34–46 m) | weniger Pendeln beim Hinterherfahren | mehr lod0-Zeit | keine | S |
| **G – Kaskaden:** Mittel mit `shadow_blend` oder `split_1` weg vom Stufenband | M3 | eine Shader-Variante, GPU-Kosten | keine | S |
| **H – Diagnose beim Nutzer:** `logs/godot*.log` und `settings.json` aus `%APPDATA%\crossing-europe-zwischenstand\` | entscheidet zwischen M1 und M2 | keins | – | sehr gering |

**Empfehlung**

1. Sofort H.
2. D – die Regel „Stufenwechsel unsichtbar“ ist in jedem Fall verletzt (gemessen 5,7–11,4 %), egal was das Log sagt.
3. A + B + C für die Überlauf-Klasse, im M2-Kopf vor dem nächsten Testbuild. A′ nur, wenn B auf dem Deck zu eng
   wird.
4. F zusätzlich, E nur, falls D die 2-%-Grenze an einem Modell nicht erreicht. G bei Gelegenheit.

## 9. Vertragsfragen

1. **D20, §4.6.4:** Der Vertrag beschreibt Instanz-Uniforms für alles in `vpbr`, nennt aber nicht die Grenze der Engine
   (254 Instanzen je Szene bei 64 KB Uniform-Block). Vorschlag: Instanz-Uniforms nur für Fahrzeuge; szenenweites
   Budget mit Prüfung. Belege: Abschnitt 4 M1, Abschnitt 7, M2INT `instanzen_wald`.
2. **D9, §4.6.9:** „Harte Wechsel, durch Entfernung und Nebel verborgen“ gilt bei 40 m nicht (gemessen 5,7–11,4 % der
   Autopixel). Für Fahrzeugwechsel fehlt eine Abnahmegrenze. Vorschlag wie Option D: ≤ 2 % der Autopixel über 24
   Stufen, Mittelfarbe ≤ 1 Stufe, in jedem Preset.
3. **Aufgabentext und §4.6.3:** Die These „Lackcodes im Atlas“ passt nicht zum Vertrag. Fahrzeuge (`vpbr`) haben keine
   Textur; Atlanten gibt es nur für `baked` und `leaves`.

## 10. Für die Nächsten

- Log und Einstellungen des Nutzers anfordern (H). Erst dann gewichten, aber D und A–C nicht davon abhängig machen.
- Die Engine-Probe (`flk_refusal_run.gd`, FLKH-Zeilen) taugt als Render-Prüfung: kleinste Reserve je Etappe und
  Preset. Lohnend auf Waldetappen im M2-Kopf (M2INT fand dort Ablehnungen) und mit Stau.
- Im M2-Kopf belegen Leitplanken, Tore, Tankstelle und Tunnelportal weiter Instanzplätze (Option A).

## 11. Dateien

- **Bogen:** `deliver/FLACKER-ANALYSE/stufen_kaskade_ablehnung.png` – lod0, lod1, lod2, Kaskade 1, abgelehnte Stufen
  (Kombi und Schrägheck, 1280×800 und 1920×1080, Sonne hinten/vorn).
- **Skripte** (nur Scratch, nie committet) in
  `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/skripte/`:
  `flk_refusal_run.gd` (echtes Rennen, Logger, Engine-Probe), `flk_firstframe.gd` (erstes Bild einer neuen Instanz),
  `flk_dump_meshes.gd`, `flk_count.gd`, `flk_refuse.gd`, `flk_refuse2.gd`, `flk_slots.gd`, `flk_swap.gd`,
  `flk_routes.gd`, `shared_mesh.py`, `white_sets.py`, `cfg_levels.py`, `run_one.sh`. Die `flk_*.gd` laufen im Wurzel-
  ordner einer Scratch-Kopie von ZS1 (`mk_checkout.sh 39849f0 <Ordner>`, dann Skript hineinkopieren); die Kopie selbst
  ist gelöscht (Platz).
- **Ergebnisse** in `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/`:
  `lauf1_medium_erfurt_km0_13uhr.log`, `lauf2_medium_kassel_km100_17uhr.log`, `lauf2_abgebrochen_km124.log`,
  `meshes_*.json`, `mesh_table.md`, `count_*.log`, `swaps.log`, `swap/*.png`.
