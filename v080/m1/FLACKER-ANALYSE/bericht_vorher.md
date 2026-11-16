# FLACKER-ANALYSE: Ein weißer Pkw verlor kurz seine Lackierung (ZS1, Kassel–Erfurt)

Rolle: Analyse des Codes, der Shader und der Modelle. Ich habe nur gelesen: kein Commit, kein Branch, keine Änderung
am Repository. Untersucht wurden zwei Stände:

- **ZS1** = `39849f0` (erster Testbuild, den der Nutzer gespielt hat)
- **M2-Kopf** = `6e48405`

Alles, was ich gemessen habe, lief auf dieser VM mit llvmpipe unter Xvfb oder headless. Wie es auf der echten
Grafikkarte des Nutzers aussieht, ist **abgeleitet**, nicht gemessen.

Bericht des Nutzers: Ein weißer Pkw etwa 40 m vor ihm „verlor kurz seine Lackierung“. Das passierte zweimal und hing
offenbar mit seinem Lenken zusammen. Gespielt hat er auf dem Main-PC unter Windows, wahrscheinlich in Modern mit dem
Preset, das der erste Start vorschlägt.

## 1. Ergebnis in Kürze

1. **Bei 40 m wechselt ein Auto seine Detailstufe (lod0 ↔ lod1), und zwar ohne Überblendung.** Bei „Mittel“ passiert
   das, wenn die Wagenmitte 38–42 m vor der Kamera ist (Wegstrecke). Dann ist der Abstand Stoßstange zu Stoßstange
   etwa 25–30 m.
   - Wer lenkt, verliert durch Untersteuern bis zu 3 m/s² an Tempo. Dadurch pendelt der Abstand zum Vordermann durch
     das 4-m-Band, und das Auto springt mehrmals zwischen den Stufen.
   - Das passt zu „40 m“, „kurz“, „zweimal“ und „beim Lenken“.
   - Der Wechsel **allein nimmt aber keinen Lack weg.** Die Netze aller Stufen tragen denselben Lackcode, und der Lack
     wird bei jedem Bau einer Stufe gesetzt.
   - Gemessen bei 40 m: Es ändern sich nur 5,7–10,9 % der Pixel des Autos um mehr als 24 Stufen, vor allem das
     Kennzeichen und kleine Teile. Die Mittelfarbe des Autos ändert sich um 1,5–3,3 Stufen.
2. **Einzige Ursache im Code, die wirklich „ohne Lack“ aussieht: Godot lehnt die Instanz-Uniforms einer
   Fahrzeugstufe ab.**
   - Godot hat für alle Instanzen mit Instanz-Uniforms zusammen nur einen Puffer: 4096 Plätze, also rund 255 Instanzen
     in der ganzen Szene.
   - In ZS1 belegen auch Bäume, Höfe, Laternen und Windräder Plätze. Sie nutzen das gemeinsame `vpbr`-Material, das
     Instanz-Uniforms hat.
   - Eine abgelehnte Instanz liest falsche Werte: Index 0 (`paint`) liest außerhalb des Puffers, die übrigen Indizes
     lesen die globalen `ce_*`-Werte.
   - Gemessen: Das weiße Auto wird schachbrettartig durchsichtig, die übrigen Pixel sind flach überstrahlt.
     52–63 % der Autopixel ändern sich um mehr als 24 Stufen, die Mittelfarbe um 21–72 Stufen.
   - Gemessen: Eine Ablehnung bleibt bestehen, bis der Knoten freigegeben wird.
   - Der sichtbare Wechsel zwischen guter und kaputter Stufe kommt dann **genau am 40-m-Band**.
   - Auf Erfurt–Kassel fand ich headless höchstens 214 Instanzen (Mittel, Hoch und Deck, beide Richtungen). Der
     Überlauf trat in meinen Läufen also nicht auf; es blieben nur 41–50 Instanzen Reserve.
3. **Eine Schattenkaskaden-Grenze liegt in derselben Entfernung:** 36 m bei Mittel, 40 m bei Hoch. Gemessen ändert der
   Kaskadenwechsel 0,4–4,7 % der Autopixel (den Schatten unter dem Heck), nicht den Lack.
4. **Widerlegt:**
   - **Lackcodes im Atlas, Mipstufen, BC-Kompression:** Fahrzeuge haben gar keinen Atlas. Die Codes sind
     Vertexwerte, genau 0,000 und 1,000, und es gibt 0 gemischte Dreiecke.
   - **Veralteter Uniform-Cache:** `_set_level()` setzt den Cache zurück.
   - **LOOK fehlt auf später angelegten Materialien:** Es gibt nur zwei gemeinsame Fahrzeugmaterialien.
   - **Wiederverwendung über Farben hinweg:** Der Pool gilt je Farbset.
   - **Modell lädt verspätet:** `prepare()` wartet, bis alles geladen ist.
   - **Klarlack-Glanz und `sky_update_s`.**
   - **Scheinwerfer:** Sie folgen der Straße, nicht der Lenkung.
5. **Billig und entscheidend: den Nutzer um seine Logdateien bitten.** Sie liegen unter
   `%APPDATA%\crossing-europe-zwischenstand\logs\godot*.log`, dazu `settings.json` für das Preset. Steht darin
   „Too many instances using shader instance variables“, ist Ursache 2 bewiesen. Steht es nicht darin, bleibt der
   Stufenwechsel (Ursache 1) mit seinen Details.

## 2. Was „40 m“ im Spiel ist (Code und Zahlen)

- **Entfernungen:** Der Kilometerzähler läuft zehnmal schneller als die sichtbare Straße (`time.time_scale` 10:
  1 km entspricht 100 m Straße). Die „realen 40 m“ des Nutzers sind also sichtbare Meter, wie die 40 m der
  Detailstufen.
- **Kamera:** Sie steht 9 m hinter der Wagenmitte des Spielers (`render.camera_distance_m`), 3,4 m hoch.
  `cam_x` folgt dem Spieler seitlich mit Verzögerung und höchstens 1,1 m Versatz
  (`scripts/race/race_session.gd`, `cam_x = lerpf(...)`, `clampf(cam_x, vx - lag, vx + lag)`).
- **Entfernung für die Stufe:** `dist = z + length/2 - cam_z`, also Wegstrecke Kamera → Wagenmitte
  (`layers/vehicles.gd:539`). Seitliches Lenken ändert sie nicht.
- **Was das Lenken ändert, ist das Tempo:** Untersteuern zieht bis zu 3 m/s² ab
  (`scripts/gameplay/vehicle_model.gd:400, 425`, `driving.understeer.scrub_max_mps2` 3,0).
- **Stufengrenzen:**
  - Formel: `VehiclePose3D.lod_index()` in `vehicle_pose3d.gd:168–176`. Die Grenze ist Manifest-`max_dist_m` (40/120)
    mal `vehicle_lod0_m/40`, mit Hysterese `LOD_HYSTERESIS` 0,05 (`:19`).
  - Niedrig: 23,75–26,25 m. Mittel: **38–42 m**. Hoch: 57–63 m (lod0 → lod1). Lkw: 60 m mal Faktor.
  - lod0 ↔ lod1 wird **nicht** überblendet: `XFADE_LODS = ["lod1", "lod2"]` (`vehicles.gd:71`), Logik
    `vehicles.gd:549–564`.
- **Schattenkaskaden** (`environment_rig.gd:181–194`, Stufen in `config graphics.levels.shadows`):
  - Mittel: 2 Kaskaden, `split_1` 0,3 × 120 m = **36 m**, ohne Überblendung.
  - Hoch: 4 Kaskaden mit Überblendung, 0,08 / 0,2 / 0,45 × 200 m = 16 / **40** / 90 m.
  - Deck und Niedrig: 0,3 × 80 m = 24 m bzw. keine Kaskaden.
- **Preset des Nutzers:** Ein PC mit Grafikkarte gilt als Stufe „ok“. `recommended_preset("ok")` ergibt „medium“
  (abgeleitet, §4.1). Hat der Nutzer „Hoch“ gewählt, liegen die Stufengrenze bei 57–63 m und eine Kaskadengrenze
  bei 40 m.
- **Rennen und Richtung** (gemessen mit dem Routen-Skript über `RoadNetwork.race_routes`):
  - `erfurt_kassel` kommt nur im Rennen **Dresden–Dortmund** vor, Route Dresden–Leipzig–Erfurt–Kassel–Dortmund,
    Richtung **Erfurt → Kassel**.
  - In der Richtung **Kassel → Erfurt**, wie der Nutzer schreibt, gibt es die Etappe nur als Einzeletappe.

## 3. Weiße Pkw in ZS1 und im M2-Kopf

- **ZS1:** Die Verkehrs-Pkw werden gleichverteilt aus allen Sets mit dem Tag „traffic“ gezogen
  (`traffic_system.gd:1304`). Weiß sind:
  - `traffic/hatch_white` und `traffic/wagon_white`: echte Modelle mit lod0, lod1, lod2.
  - `traffic/suv_white` und `traffic/van_white`: Arcade-Bild als Ersatz (Ersatzbilder-Pfad, A-9).
  - Silberne Sets wie `sedan_silver` und `wagon_silver` wirken ebenfalls hell.

  Ein weißer Pkw ist in ZS1 also etwa zur Hälfte ein Modell, zur Hälfte ein Ersatzbild.
- **M2-Kopf:** Auch SUV, Transporter, Sportwagen, Bus und Polizei sind Modelle. Weißes Weiß ist seit dem M2-Look
  `#d8d8d5` statt `#e8e8e5`.

## 4. Die Mechanismen im Einzelnen

Rangfolge danach, wie gut ein Mechanismus zu „weißes Auto, etwa 40 m, verliert kurz den Lack, zweimal, beim Lenken“
passt.

### M1 – Abgelehnte Instanz-Uniforms (Überlauf des globalen Shader-Puffers) → Rang 1 beim Aussehen, nicht nachgestellt

**Code**

- Instanz-Uniforms in `vpbr.gdshader:44–59` (Indizes 0–9); `glass.gdshader:11–12` (Indizes 5 und 6).
- GLES3 liest Instanzwerte über `uniform highp uint instance_offset;` aus `GlobalShaderUniformData`. Das steht im
  Shader-Quelltext im Godot-Binary.
- Jede Instanz mit einem solchen Material belegt 16 Plätze (`vehicles.gd:30–37`, Doku `renderer-modern.md` §13.8).

**Wer in ZS1 Plätze belegt**

- Fahrzeuge: lod0 = Karosserie, 4 Räder und Schattenhülle, also 6 Instanzen; Lkw 13. `INSTANCE_BUDGET` = 128 nur für
  die Fahrzeugebene (`vehicles.gd:37`, Kürzen in `:1152–1176`).
- **Alle Requisiten-Modelle mit `vpbr`-Fläche:** Eiche, Birke (jeweils mit Variante b), Hof, Scheune, Laterne,
  Windrad, Mühle, Zoll, Tankstelle. In ZS1 bekommen sie das gemeinsame `vpbr` (`modern_materials.gd:118–139`).
  - Je Stück und je Darstellung (lod0, lod1, Werfer) und je Spiegelseite gibt es einen MultiMesh-Knoten
    (`builders/props.gd:751–772`, `_mmi` `:824`).
  - Jeder Knoten belegt 16 Plätze, sichtbar oder nicht.
- Dazu Leitplanken, Torbrücke, Tankstelle und Tunnelportal (`material("vpbr")`), Ersatzbild-Bögen und Kastenflächen
  (`vehicle_sprite`).
- Erst M2INT hat Requisiten auf `VPBR_STATIC` ohne Instanz-Uniforms umgestellt. Das ist **nicht in ZS1**.

**Was eine Ablehnung bewirkt** (gemessen, llvmpipe)

- `flk_refuse.gd`: 300 Quads → 45 abgelehnt. Bei einer abgelehnten Instanz liest Index 0 den Wert 0 (außerhalb des
  Puffers), Index 1 liest globalen Platz 0.
- `flk_slots.gd` mit den echten `ce_*`-Globals: `paint` liest 0, die Indizes 3–6 lesen `ce_snow`, `ce_time`,
  `ce_wind` und `ce_fog_color`.
- `flk_refuse2.gd`: **Eine abgelehnte Instanz erholt sich nicht.** Ich habe 100 Plätze freigegeben, `visible`
  umgeschaltet, Werte neu gesetzt und das Transform verschoben – sie blieb falsch.

**Wie das weiße Auto dann aussieht** (gemessen, `flk_swap.gd`, Bogen `stufen_kaskade_ablehnung.png`)

- Die Karosserie ist zu etwa der Hälfte schachbrettartig ausgestanzt, die Straße scheint durch. Der Rest ist flach
  überstrahlt.
- Weißer Kombi bzw. Schrägheck bei 40 m: 52–63 % der Autopixel ändern sich um mehr als 24 Stufen, die Mittelfarbe
  um 21–72 Stufen.
- Abgeleitet für eine echte GPU: Index 0 außerhalb des Puffers ist treiberabhängig (meist 0). Die übrigen Werte
  liest jede GPU gleich falsch, also auch das Ausstanzen.

**Bedingungen**

- Die Szene ist im Moment des Baus einer Stufe voll. Gebaut wird eine Stufe beim ersten Bedarf oder nach dem
  Freigeben durch das Budget (`_set_level`, `vehicles.gd:1242–1267`).
- Danach ist **diese eine Stufe dieses einen Auto-Objekts** dauerhaft kaputt. Das Auto-Objekt wandert sogar über den
  Pool (`POOL_PER_SET` 6) zu späteren Autos **desselben Farbsets**.
- Sichtbar wird es bei jedem Wechsel in diese Stufe, also am 38–42-m-Band. Das passt zu „kurz“, „zweimal“, „beim
  Lenken“.
- Ersatzbilder von Pkw (`kind` 0) lesen keine Instanzwerte (`vehicle_sprite.gdshader:86–101`). Ein weißer SUV oder
  Transporter in ZS1 ist dagegen also gefeit, ebenso die Lkw-Modelle nicht – Kastenflächen von Bussen dagegen schon.

**Gemessen auf dieser Strecke** (`flk_count.gd`, headless, ganze Etappe, Autopilot, 13 Uhr, Seed 3):

| Preset | ab Kassel: max (Fahrzeuge / Requisiten / Rest) | ab Erfurt: max | über 255 |
|---|---|---|---|
| medium | 214 bei km 136 (113 / 62 / 39) | 205 bei km 136,6 (113 / 55 / 37) | 0 |
| high | 214 (gleich) | 205 (gleich) | 0 |
| deck | 202 (113 / 50 / 39) | 196 | 0 |

- Die Requisiten erreichen ihr Maximum von 80 bei km 5 ab Erfurt.
- Im schlimmsten Fall kommen Fahrzeuge bis 128 (+ Bauten, wenn gezeigte Stufen das Budget allein sprengen, z. B.
  mehrere Lkw in lod0 mit je 13 Instanzen), 80 Requisiten und 39 Rest zusammen. Das sind rund 247 bis über 255.
- Headless fehlen die Aufwärmknoten hinter dem Ladebild (laut RINT-B bis +135) und die Verkehrsspitzen.
- Nachstellung im echten Rennen unter Xvfb mit Logger: siehe Abschnitt 7.

**Bewertung**

- Das Aussehen passt am besten zu „verlor seine Lackierung“.
- Nicht nachgestellt: Auf dieser Etappe bleibt rechnerisch eine Reserve von nur 41–50 Instanzen. Sie lässt sich
  durch Verkehr und Lkw aufbrauchen, aber ein Überlauf ist nicht belegt.
- Beweis oder Widerlegung liefert das Log des Nutzers (Abschnitt 1, Punkt 5).

### M2 – Hartes Umschalten lod0 ↔ lod1 bei 38–42 m → Rang 2 (Auslöser stimmt, Aussehen nicht)

**Code:** `vehicles.gd:549–564`, `vehicle_pose3d.gd:168–176`, `XFADE_LODS` `:71`.

**Netzvergleich** (gemessen, `flk_dump_meshes.gd`, Tabelle in Abschnitt 5)

- Alle drei Stufen jedes Verkehrsmodells tragen auf der Karosserie Lackcode 0.000 (Lkw zusätzlich 0.251 und 0.502).
  Es gibt keine Stufe mit festem Lack.
- 0 Dreiecke, deren drei Ecken verschiedene Codes haben. Das Provoking Vertex (GL letzte Ecke, D3D/ANGLE erste Ecke)
  spielt also keine Rolle.
- Abstand der Codes zu den Schwellen des Shaders (0,125 / 0,375 / 0,75): mindestens 0,124.
- Der Lack kommt nicht aus einer Textur. `vpbr` hat keine Textur, also gibt es keine Mipstufe und keine
  BC-Kompression des Lacks (§4.6.4).
- `apply_paint()` wird in jedem `build()` aufgerufen (`model_factory.gd:122, 214–221`).
- `_set_level()` setzt `fade`, `sun`, `lamp_a` und `lamp_b` zurück und schiebt sie im selben Bild neu
  (`vehicles.gd:1318–1323`, `_set_uniforms` `:852–867`).
- Der LOOK liegt auf **einem** gemeinsamen `vpbr`- und **einem** `glass`-Material, die vor allen Bauten angelegt
  werden (`vehicles.gd:231–233`; M2: `ModernMaterials.apply_look`). Er gilt also für jede Stufe.

**Bildvergleich** (gemessen, Kontrollszene mit Spielkamera, Licht genähert, Bogen `stufen_kaskade_ablehnung.png`):

| Wechsel bei 40 m (36 m seitlich) | Autopixel > 24 Stufen | Änderung der Mittelfarbe |
|---|---|---|
| lod0 → lod1, 1280×800 / 1920×1080, Sonne hinten, vorn, seitlich | 5,7–10,9 % | 1,5–3,3 |
| lod1 → lod2 (überblendet 0,5 s) | 16,8–26,5 % | 3,7–11,7 |

**Was sich ändert:**
- Am auffälligsten ist das Kennzeichen: lod0 hat ein weißes Schild mit Zeichen und Euroband, lod1 ein graues Feld
  `#c4c4c1`.
- Dazu kommen Lampenringe, dritte Bremsleuchte, Glas-Klasse gegen dunkle `vpbr`-Scheibe und Schattenkanten.

**Bewertung**

- Der Wechsel ist sichtbar und am Band wiederholbar, aber er ist **kein Lackverlust**.
- Er ist der Auslöser, an dem M1 sichtbar würde.
- Für sich genommen erklärt er das Gesehene nur, wenn der Nutzer den Kennzeichen- und Detailsprung als
  „Lackierung“ beschreibt. Das halte ich für wenig wahrscheinlich.

### M3 – Schattenkaskaden-Grenze in derselben Entfernung → Rang 3

**Code und Bedingung**

- `environment_rig.gd:181–194`, gesetzt im `_init` (`:143–151`): Bias 0,04, Normal-Bias 1,2, Unschärfe 1,2,
  16-Bit-Atlas.
- Mittel ohne Überblendung bei 36 m, Hoch mit Überblendung bei 40 m.
- Die Texelgröße springt an der Grenze etwa um den Faktor 3. Abgeleitet aus der Splitgeometrie:
  - Kaskade 1 hat einen Kugeldurchmesser von rund 80 m auf 1024 px, also etwa 8 cm.
  - Kaskade 2 hat rund 260 m, also etwa 26 cm.

**Gemessen:** Der Wechsel der Kaskade bei unverändertem Auto ändert 0,4–4,7 % der Autopixel um mehr als 24 Stufen,
die Mittelfarbe um 0,1–3,3. Betroffen ist vor allem der Schatten unter dem Heck.

**Bewertung:** Ein kleiner Sprung von Schattenkante und Schattenweiche, kein Lackverlust.

### M4 – Weitere Pfade, geprüft

| Pfad | Code | Ergebnis |
|---|---|---|
| Uniform-Cache je Auto nicht zurückgesetzt (These des Leads) | `_set_level` `vehicles.gd:1318–1323`, `_acquire` `:1090–1095` | **widerlegt**: beide setzen `fade`, `sun`, `la`, `lb` auf −1; im selben Bild folgt `_set_uniforms` |
| Auto aus dem Pool für anderes Set oder andere Farbe | `_free[set_id]`, `_acquire` `:1065–1105`, Setwechsel `:516–519` | **widerlegt**: Pool je Set, Lack je Set |
| Stufe bei Bedarf gebaut | `_set_level` `:1245–1267`, `build()` mit `apply_paint` | ohne M1 **widerlegt**: Werte vor der Zuteilung gesetzt, Godot übernimmt sie |
| Modell nach dem Erscheinen geladen (`ModelDB.request`) | `prepare_pending()` `vehicles.gd:302–311` | **widerlegt**: Start erst bei `pending() == 0`; fehlt eine Datei, wird der Kasten gebaut (nie halbes Auto) |
| Überblendung lod1/lod2 bleibt hängen | `_xfade_begin/_step/_end` `:1188–1238` | bei 40 m nicht beteiligt; jede Unterbrechung endet in `_xfade_end` (`xfade` auf 0) |
| LOOK fehlt auf einem Material | ZS1 `vehicles.gd:231–233`, M2 `apply_look` | **widerlegt** für Fahrzeuge (zwei gemeinsame Materialien); die Lücke betraf statische Kopien (M2: `VPBR_STATIC` übernimmt) |
| Lackcodes, Atlas, Mipstufe, BC | §4.6.4, Netzdaten Abschnitt 5 | **widerlegt**: Vertexcodes, keine Textur |
| Klarlack-Sonnenglanz, Himmelsspiegelung, `sky_update_s` | `vpbr.gdshader:308–325, 375–386`; Engine-Spiegelung aus (`SPECULAR 0`, `:330–335`) | heller Fleck möglich, kein Lackverlust; analytischer Himmel ändert sich nur mit der Palette (`_set_environment` `:1040–1060`) |
| Scheinwerfer des Spielers schwenken mit der Lenkung | `lights.gd:252–290`: Richtung = Straßenrichtung `path.heading_at(z)` | **widerlegt** (nur nachts, folgt nicht der Lenkung) |
| Omni-Pool springt zwischen Laternen | `lights.gd` `_update_pools` | nur nachts unter Laternen (Stadt), Helligkeitssprung möglich – niedrig |
| Ersatzbilder `suv_white` / `van_white`: Zellwechsel bzw. Falten am Lenk-Yaw | `vehicles.gd:656–749`, `vehicle_sprite.gdshader` | Bildwechsel wie in Arcade, kein Lackverlust; immun gegen M1 (`kind` 0 liest `COLOR` und `INSTANCE_CUSTOM`) |
| `fade` (F5) bei 40 m | `VehiclePose3D.fade`: 1,0 bis 0,45 × Sicht | nicht beteiligt |

## 5. Stufen der Fahrzeugmodelle (gemessen, `flk_dump_meshes.gd` → `meshes_zs1.json`, `meshes_m2.json`)

Die Prüfung umfasst alle Verkehrs-, Polizei- und Spielermodelle, sowohl in ZS1 als auch im M2-Kopf. Ergebnis:

- In keiner Stufe gibt es gemischte Lackcodes.
- In jeder Stufe tragen Karosserie und Dach Code 0 (`paint`).
- Die Scheiben von lod0 gehören zur `glass`-Klasse (7–9 % der Heckansicht). In lod1 und lod2 sind sie dunkles
  `vpbr` mit `TRAFFIC_GLASS_FAR`.
- Feste Farben werden zur groben Stufe hin heller (Kennzeichen grau, Lampenringe fallen weg).
- Bei der Polizei verschwindet in lod2 teils `paint3` (Liverie vereinfacht).
- Normalen von lod1 und lod2 werden von lod0 übernommen (`core.transfer_normals`, `docs/modelle.md` §13).
  Höchstens 6 Dreiecke je Stufe zeigen gegen ihre Normale.

Auszug (Tabelle ganz: `m1/FLACKER-ANALYSE/mesh_table.md`):

| Modell (ZS1) | Stufe | Dreiecke | Lack | fest | glass | Codes |
|---|---|---|---|---|---|---|
| `traffic/hatch` | lod0 / lod1 / lod2 | 14 388 / 5 661 / 1 180 | 0,63 / 0,58 / 0,57 | 0,30 / 0,42 / 0,43 | 0,07 / 0 / 0 | nur 0,000 und 1,000 |
| `traffic/wagon` | lod0 / lod1 / lod2 | 14 216 / 5 941 / 1 141 | 0,63 / 0,58 / 0,53 | 0,30 / 0,42 / 0,47 | 0,07 / 0 / 0 | nur 0,000 und 1,000 |
| `traffic/sedan` | lod0 / lod1 / lod2 | 14 307 / 5 809 / 1 149 | 0,62 / 0,58 / 0,55 | 0,30 / 0,42 / 0,45 | 0,08 / 0 / 0 | nur 0,000 und 1,000 |
| `traffic/truck` | lod0 / lod1 / lod2 | 4 772 / 4 672 / 1 490 (Zugmaschine bzw. ganz) | 0,26 / 0,23 / 0,30 (+ Lack2 0,23 / 0,21 / 0,26) | 0,50 / 0,55 / 0,43 | – | 0,000 / 0,251 / 0,502 / 1,000 |

Die Dreieckszahlen sind ohne Räder gezählt. Die Anteile beziehen sich auf die Fläche, die aus 5° über dem Heck
sichtbar ist.

**Welche Stufen beim Wechsel anders aussehen** (gemessen bei 40 m, Abschnitt 4 M2):

- **lod0 ↔ lod1:** Kennzeichen, Lampenringe, Scheiben. Das sind 6–11 % der Pixel.
- **lod1 ↔ lod2:** Kabinenquerschnitt, dreieckige Radausschnitte, dunkler Heckabschluss. Das sind 17–27 % der Pixel,
  der Wechsel wird überblendet.

Eine Stufe, die bei richtiger Zuteilung den Lack verliert, gibt es in keinem Modell, weder in ZS1 noch im M2-Kopf.

## 6. Was ich nicht messen konnte

- Die GPU, den Treiber und das Preset des Nutzers.
- Ob in seiner Fahrt eine Ablehnung stattfand.
- Seine Tageszeit.
- Das Ergebnis eines Lesezugriffs außerhalb des Puffers auf NVIDIA, AMD oder Intel unter Windows bzw. ANGLE.
- Das Licht meiner Kontrollszene ist eine Näherung (Palette 13 Uhr, keine `EnvironmentRig`-Lichtaufteilung). Die
  Vergleiche gelten daher für die *Unterschiede* zwischen den Fällen, nicht für die absolute Helligkeit.

## 7. Nachstellung im echten Rennen unter Xvfb (Logger auf die Ablehnung, `flk_refusal_run.gd`)

ERGEBNIS_PLATZHALTER

## 8. Möglichkeiten zur Behebung

Harte Regeln: Arcade und Simulation bleiben unberührt. Alles spielt im Modern-Renderer und in den Modellen.

| Option | löst | Risiko | Fairness (F1/F6) | Aufwand |
|---|---|---|---|---|
| **A Ursache M1 beheben: kein Instanz-Uniform ohne Bedarf.** Neben den Requisiten (M2: `VPBR_STATIC`) auch Leitplanken, Tore, Tankstelle und Tunnelportal (`material("vpbr")` in `roadside.gd:356`, `gantry.gd:158`, `station.gd:217`, `tunnel.gd:392` – im M2-Kopf noch mit Instanz-Uniforms) auf `VPBR_STATIC`. Die Schattenhülle der Fahrzeuge (nur Schatten, liest nichts) bekommt ein statisches Material. Die Bögen der Ersatzbilder (`kind` 0) bekommen eine Variante ohne `instance uniform` | Überlauf-Klasse für alle Modelle und Stufen; spart pro lod0-Auto 1 von 6 Instanzen | gering; Bild gleich (wie `instanzen_wald` es für Requisiten zeigte); eine weitere Shader-Variante je Klasse vorwärmen | keine | S–M |
| **B Szenenweites Budget statt nur Fahrzeugbudget.** Der Renderer zählt alle Knoten mit Instanz-Uniforms (Bauer melden ihre Knoten). Die Fahrzeugebene begrenzt **einschließlich gezeigter Stufen** – reicht es nicht, zeigt sie für die fernsten lod0-Autos lod1 (Auto bleibt da und gleich groß) | M1 auch bei dichtem Lkw-Verkehr in Hoch | gering; Budget testbar (`check_instance_budget*` erweitern, Etappe `erfurt_kassel` Hoch ab Erfurt) | keine (nie unsichtbar, gleiche Größe, Flares getrennt) | M |
| **C Erkennen und reparieren.** Ein `Logger` im Modern-Renderer fängt „Too many instances …“, zählt sie in `perf_stats` (`instance_refusals`) und baut alle in diesem Bild entstandenen Fahrzeugstufen nach Platzschaffen neu (eine Ablehnung heilt nie von selbst, gemessen) | Restfälle, die A und B nicht verhindern; macht Ablehnungen in Testbuilds und Leistungstest sichtbar | Text der Engine-Meldung kann sich mit einer Godot-Version ändern (Test prüft ihn) | keine | S |
| **D Stufenwechsel lod0 ↔ lod1 unsichtbar machen (Ursache am Modell).** Kennzeichen von lod1 und lod2 wie lod0 (helles Schild mit den mittleren Zeichen- und Bandfarben statt `#c4c4c1`), Lampenringe und Scheibenbild an die 40-m-Ansicht angleichen. Abnahme an jeder Stufe und jedem Preset (25 / 40 / 60 m), 1280×800 und 1920×1080: Autopixel > 24 Stufen ≤ 2 %, Mittelfarbe ≤ 1 Stufe | Sprung M2 bei allen Modellen | Kunstarbeit je Modellfamilie, Re-Export und Validator | keine | M |
| **E Überblendung auch für lod0 ↔ lod1** (`XFADE_LODS` um `lod0`; `glass` braucht dafür `xfade`, Index 9) | verdeckt M2 (0,5 s statt 1 Bild) | verdeckt nur, löst nichts (Vertrag: Ursache vor Verdeckung); +6 Zeichenaufrufe je Auto für 0,5 s | keine (jedes Pixel gehört einer Stufe) | S |
| **F Breitere Hysterese** (`LOD_HYSTERESIS` 0,05 → 0,15: Mittel 34–46 m) | weniger Hin- und Herspringen beim Hinterherfahren | mehr lod0-Zeit (Dreiecke) | keine | S |
| **G Kaskaden:** Mittel mit `shadow_blend` (oder `split_1` weg vom Stufenband) | M3 (klein) | eine Shader-Variante, GPU-Kosten | keine | S |
| **H Diagnose beim Nutzer:** `logs/godot*.log` und `settings.json` aus `%APPDATA%\crossing-europe-zwischenstand\` | entscheidet zwischen M1 und M2 | keins | – | sehr gering |

**Empfehlung:**
1. Zuerst H.
2. Unabhängig davon A + B + C als Ursachenbehebung der Überlauf-Klasse, im M2-Kopf und für den nächsten Testbuild.
3. Danach D für die Unsichtbarkeit des Stufenwechsels. F nur zusätzlich, E nur, falls D die 2-%-Grenze nicht
   erreicht.

## 9. Vertragsfragen

1. **D20, §4.6.4:** Der Vertrag beschreibt Instanz-Uniforms für alles in `vpbr`, nennt aber nicht die Grenze der
   Engine. Für die ganze Szene gibt es 4096 Plätze, also rund 255 Instanzen (gemessen, „Maximum items supported by
   this hardware is: 4096“). Er sollte festlegen:
   - Nur Fahrzeuge nutzen Instanz-Uniforms.
   - Es gibt ein szenenweites Budget mit Prüfung.
   - Belege: Abschnitt 4 M1, M2INT `instanzen_wald`.
2. **D9, §4.6.9:** „Harte Wechsel, durch Entfernung und Nebel verborgen“ gilt bei 40 m nicht. Gemessen ändert der
   Wechsel lod0 → lod1 5,7–10,9 % der Autopixel. Der Vertrag hat für Fahrzeugwechsel keine Abnahmegrenze. Vorschlag
   wie Option D: höchstens 2 % der Autopixel über 24 Stufen, Mittelfarbe höchstens 1 Stufe, in jedem Preset.
3. **Aufgabentext und §4.6.3:** Die These „Lackcodes im Atlas“ passt nicht zum Vertrag. Fahrzeuge (`vpbr`) haben
   keine Textur; Atlanten gibt es nur für `baked` und `leaves`.

## 10. Für die Nächsten

- Logs und Einstellungen des Nutzers anfordern (Option H). Erst dann den Fix festlegen.
- `flk_refusal_run.gd` auf der ganzen Etappe in Hoch, mit Rushhour-Verkehr (17 Uhr) und Aufwärmphase wiederholen.
  Hier liefen wegen der Last (Load 26) nur kurze Abschnitte.
- Die Kontrollszene mit der echten `EnvironmentRig`-Lichtaufteilung wiederholen, um absolute Werte zu bekommen.
- Im M2-Kopf belegen Leitplanken, Tore, Tankstelle und Tunnelportal weiterhin Instanzplätze. Dort `VPBR_STATIC`
  nachziehen (Option A).

## 11. Dateien

- **Bogen:** `deliver/FLACKER-ANALYSE/stufen_kaskade_ablehnung.png`. Er zeigt lod0, lod1, lod2, Kaskade 1 gegen 2,
  die abgelehnten Stufen und die abgelehnte Stufe ohne Dither-Globals, jeweils für Kombi und Schrägheck, 1280×800
  und 1920×1080, Sonne hinten bzw. vorn.
- **Skripte** (nur Scratch, nie committet) in
  `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/co_zs1/`:
  `flk_dump_meshes.gd`, `flk_count.gd`, `flk_refuse.gd`, `flk_refuse2.gd`, `flk_slots.gd`, `flk_swap.gd`,
  `flk_refusal_run.gd`, `flk_routes.gd`.
- **Ergebnisse** in `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/`:
  `meshes_*.json`, `mesh_table.md`, `count_*.log`, `swaps.log`, `swap/*.png`, `refusal_*.log`.
