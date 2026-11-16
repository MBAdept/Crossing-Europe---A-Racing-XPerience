
## 6. Sprite-Geometrie und Hooks

Regel 1 gilt: Kein Sprite wurde neu gerendert, keine eingefrorene Arcade-Datei geändert. Die Generatoren in
`tools/blender/cesprites` haben nur zusätzliche Schalter bekommen, deren Voreinstellung das Sprite-Modell ergibt:

- `carbody.py`: `lamp_depth` (Lampen als Mulden), `ring_min`, `ends_n`, `cap_sharp`, einzelne Stationen an den
  Radlaufkanten bei `arch_n ≤ 2`, `patch(…, sink=…)`.
- `cardetail.py`: `lamp()` mit `lamp_depth > 0` (kein Gehäuse, versenkte Teile, Marke `ce_sink`, bündige Scheibe).
- `player_cars.py`: Fugenbreite über `detail["seam"]`, Helfer `grille()` (im Sprite derselbe Aufruf wie vorher),
  3D-Blinkerfelder und Rückfahrlicht des Kompakten unter `detail["extras"]`.
- `vehicles.py`, `designs.py`, `heavy.py`: unverändert (werden nur gelesen).

`check_sprite_geometry.py` über alle 187 Sets nach der letzten Änderung an `cesprites`: **187 identisch**, davon
einmal „REIHENFOLGE“ (die UV-Kugel des Berliner Fernsehturms, wie in v0.7.0), 0 „ANDERS“, 346 s.

## 7. Showroom: A/B und Entscheidung

Bild `06_showroom_ab.jpg`: links Echtzeit (`show`), rechts das Cycles-Sprite, dieselbe Kamera, derselbe Boden.

Was das Echtzeit-Modell **besser** kann: durchsichtiges Glas mit Innenraum (Sitze, Lenkrad, Spiegel), Wischer,
Antenne, Lampen und Grill mit Tiefe, scharfe Fugen und Kennzeichen in jeder Größe, schaltbare Lichter.

Was ihm **fehlt** – und warum `showroom` für beide Autos `false` bleibt:

1. **Lack:** Das Sprite hat weiche Spiegelungen der Umgebung und einen Klarlack mit Fresnel; in Echtzeit ist der
   Lack eine gleichmäßig helle, grelle Fläche mit einem harten Glanzpunkt (am Gelb des Kompakten am deutlichsten).
2. **Umgebungsverdeckung und Kontaktschatten:** Radhäuser, Fugen, Schweller und der Boden unter dem Auto sind im
   Sprite weich abgedunkelt; in Echtzeit gibt es nur den harten Schlagschatten.
3. **Felgen, Chrom, Reifen:** spiegeln im Sprite die Umgebung, in Echtzeit eine Farbe.
4. **Licht:** Der Kontaktbogen hat eine Sonne und Himmelslicht; ein Showroom braucht weiches Führungs- und
   Aufhelllicht.

Nichts davon ist eine Frage des Netzes: 1–3 gehören zum Lackshader und zum Renderer (R3), 4 zum Showroom (UI1).
Sobald beides steht, das A/B wiederholen (`tools/models_contact_sheet.sh <bild> --only="player/*" --showroom`)
und bei Gleichstand in `tools/blender/ce3d/catalog3d.py` bei `showroom/limousine` und `showroom/kompakt`
`"showroom": True` setzen, danach `export_models.py --manifest-only`.

## 8. Schwächste Stellen (für die Abnahme)

Ehrlich, in der Reihenfolge, in der sie auffallen:

1. **Lack der Spielerautos wirkt wie Kunststoff** (flach, grell) – Shader, siehe oben. Das ist der größte Abstand
   zum Wunsch „detailreiche Grafik“.
2. **Verkehrsautos: Lampen sind ebene, eingeschnittene Felder** ohne Streuscheibe und Tiefe; das Heck ist eine
   fast senkrechte Fläche, das dunkle Glas hat keinen Innenraum dahinter. Aus der Verfolgerkamera ab 8 m trägt
   das, im Stand daneben nicht.
3. **`lod2` der Verkehrsautos** hat dreieckige Radausschnitte und sechseckige Räder (für > 120 m gedacht).
4. **Felgen** sind sauber, aber einfach (fünf gerade Speichen, wenig Tiefenwirkung); Reifen ohne Flankenzeichnung.
5. **Scheinwerfer der Spielerautos** zeigen von vorn wenig Tiefe (helle Leiste hinter klarer Scheibe); die
   vorderen Blinker sind klein (20–28 cm², erlaubt ab 15, weil das Auto im Rennen nie von vorn zu sehen ist).
6. **Türgriffe** sind kleine Bügel; Limousine: leichte Schattierungsdellen am vorderen Kotflügel nahe A-Säule.
7. **Sattelzug:** ein Koffer für alle vier Lackierungen (keine Plane), Fahrerhaus ohne gewölbte Front und ohne
   Innenraum; nachts sind die Rückleuchten auf 150 m nur noch zwei Bildpunkte (braucht den Schein des Renderers
   an den Lichtankern).
8. **Rücklicht bei Nacht** ist am Spielerauto recht dunkel gegen das Bremslicht (Verhältnis 2,6) – Geschmackssache
   des Renderers (`lamp`-Energien), nicht des Netzes.

## 9. Abweichungen vom Auftrag

- Verkehrsautos stehen auf den Lofts von `carbody.SmoothCar` statt auf denen von `vehicles.Car` (die knitterten in
  den groben Stufen). Maße, Fenster und Lampen kommen weiter aus `cesprites.designs`.
- Der Sattelzug ist ein eigener 3D-Aufbau (`ce3d/truck3d.py`) mit den Maßen von `cesprites.heavy`, nicht der
  Quader-Generator der Sprites.
- Ein Netz für alle vier Lkw-Lackierungen (Lackwerte `paint`/`paint2`/`paint3`), keine Planen-Variante.
- `lod2` der Verkehrsautos ohne Kennzeichen, Rückfahrlicht, Tagfahrlicht und Schwellerteilung (Budget 1 200).
- Verfolgerbilder der Spielerautos aus 9 m statt 8 m (bei 8 m liegt die Heckstoßstange unter dem Bildrand der
  Spielkamera).
- Lkw `lod0`: 13 Zeichenaufrufe (Zugmaschine 2 + 4 Räder, Auflieger 1 + 6 Räder); §4.6.9 nennt für Lkw in `lod0`
  kein Aufrufbudget.

## 10. Vertragsfragen

- `PREMUL_ALPHA_FACTOR` kennt der GLES3-Szenenshader von Godot 4.7.2 nicht (Übersetzungsfehler); das Glas
  arbeitet mit `blend_premul_alpha` und rechnet die Vormultiplikation selbst.
- `glass.gdshader`: Die Zeile `render_mode` (jetzt `blend_premul_alpha, depth_draw_never, cull_back`) teilen sich
  AS1 (Aussehen) und R3 – möglicher Zusammenführungskonflikt. `fade`, `sun` und `light()` sind unverändert.
- Knotennamen mit Gruppe (`tractor/body`, `trailer/wheel_0l`) und der Manifest-Schlüssel `groups` sind neu;
  `ModelFactory` baut die Teile, wertet `groups` aber nicht aus – der Zug knickt noch nicht.
- Der Vertrag sagt nichts zur Lage des Schattenwerfers. Neu als Regel der Modelle: Er liegt innerhalb der
  Außenhaut (sonst verschattet er die eigene Karosserie). Ein Prüfer dafür fehlt noch.

## 11. Was die Autos vom Lackshader brauchen (für R3)

- **Klarlack:** zweite Glanzschicht mit Fresnel und Spiegelung der Umgebung (Himmel/Horizont genügt), dazu ein
  etwas dunklerer Grundton – das ist der Hauptunterschied zum Sprite.
- **Metallic-Flocken:** leichtes, feines Glitzern bei `metal > 0` (optional, erst nach dem Klarlack).
- **Chrom und Felgen:** `metallic` 0,55–1,0 bei `roughness` 0,12–0,3 brauchen eine Umgebung zum Spiegeln.
- **Umgebungsverdeckung:** kein Vertexkanal ist dafür frei; ein Kontaktschatten unter dem Auto und dunklere
  Radhäuser kämen vom Renderer.
- **Lampen:** Die Leuchtkörper liegen bis 28 mm hinter einer fast klaren Streuscheibe (Deckkraft 0,08–0,10).
  Das Glas darf sie nicht abdunkeln; Lichtanker liegen in der Öffnung der Mulde (für Schein/Blendflecken).
- **Glas:** rechnet vormultipliziert; `tint_gain`, `fresnel_boost`, `mirror` sind die Stellschrauben.
- **Schatten:** Schattenwerfer liegen 12 mm (Lkw 30 mm) unter der Haut – die Schattenverschiebung des Renderers
  darf klein bleiben.

## 12. Bilder in diesem Ordner

| Datei | Inhalt |
|---|---|
| `01_tag_spieler.jpg`, `02_tag_verkehr.jpg` | Kontaktbögen bei Tag: jede Stufe von hinten und von vorn, Farbsets, Schattenwerfer |
| `03_nacht_spieler.jpg`, `04_nacht_verkehr.jpg` | Kontaktbögen bei Nacht: je Fahrzeug eine Kachel pro Lampenzustand |
| `05_lampenkanaele.jpg` | Prüfstreifen aller 15 Lampenkanäle |
| `06_showroom_ab.jpg` | A/B Echtzeit `show` gegen Cycles-Sprite, dieselbe Kamera |
| `07_verfolger_spieler.jpg` | Spielkamera 9 m und 30 m, Tag / Nacht Rücklicht / Nacht Bremslicht + Blinker |
| `08_verfolger_verkehr.jpg` | Spielkamera 8, 30, 80 m für alle Verkehrsmodelle |
| `09_verfolger_lkw.jpg` | Sattelzug aus 20, 60, 150 m |
| `10_verfolger_nacht.jpg` | Verkehr bei Nacht aus 30 m |
| `11_review_limousine.jpg`, `12_review_kompakt.jpg` | große Ansichten der Spielerautos (Heck, Front, Rad, Innenraum, Lampen nah, Nacht) |
| `13`–`15_stufen_*.jpg` | Verkehrsautos: `lod0` / `lod1` / `lod2` nebeneinander aus drei Blickwinkeln |
| `16_review_lkw.jpg`, `17_stufen_lkw.jpg` | Sattelzug: Ansichten und Stufen |
| `18_review_sedan.jpg` | Verkehrs-Limousine groß |
| `pruefer_bericht.txt`, `lampenflaechen.txt` | Ausgabe des Prüfers, Lampenflächen und Lichtanker |

## 13. Läufe

@@RUNS@@
