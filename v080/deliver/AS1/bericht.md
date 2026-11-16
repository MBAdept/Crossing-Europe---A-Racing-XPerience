# AS1 – Fahrzeugmodelle für den Schnitt: Bericht

- Paket: AS1 (v0.8.0, Bauabschnitt 1) · Zweig `worktree-wf_bade9e46-06a-1` · Stand `53bcc1b` ·
  Sicherheitskopie `origin wip/v080-as1`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1`
- Alle Zahlen sind **gemessen** (Prüfer, Inspektor, Render-Prüfung auf Software-OpenGL), wo nichts anderes
  dabeisteht. Aussagen über das Steam Deck oder eine echte Grafikkarte sind **geschlossen**, nie gemessen.

## 1. Ergebnis in Kürze

Alle sechs Modelle des Pakets existieren, der Prüfer ist grün, die Budgets sind eingehalten:
zwei Spielerautos (`player/limousine`, `player/kompakt`: Rennstufe, Showroom-Stufe, Schattenwerfer), drei
Verkehrsautos (`traffic/sedan`, `traffic/hatch`, `traffic/wagon`: `lod0`–`lod2`, alle Farbsets als Lack) und der
Sattelzug (`traffic/truck`: Zugmaschine + Auflieger, vier Lackierungen).

Die Spielerautos haben jetzt Lampen mit Tiefe, durchsichtiges Glas mit Innenraum, ein ausgearbeitetes Heck und
eine Front mit Grilltiefe, Wischern und Antenne. Die Verkehrsautos sind auf glatten Lofts neu aufgebaut: straffe
Form, dieselben Konturen in allen Stufen, nichts knittert mehr. Das Heck des Lkw liest sich auf 20–150 m sofort.

Nicht erreicht: Im Showroom-Vergleich ist das Echtzeit-Bild dem Cycles-Sprite **noch nicht ebenbürtig** – das
Netz ist reicher, Lack und Licht sind flacher. `showroom` bleibt für beide Spielerautos `false` (Abschnitt 7).

## 2. Abnahmepunkte

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Prüfer grün | erfüllt | `validate_models.py`: `CHECK models OK` – 10 Modelle, 180 Sets, 25 mit Modell (`pruefer_bericht.txt`) |
| Kontaktbögen Tag und Nacht mit jedem Lampenkanal | erfüllt | `01`–`04` (Nachtbögen: je Fahrzeug eine Kachel pro Lampenzustand), `05_lampenkanaele.jpg` (alle 15 Kanäle), `10_verfolger_nacht.jpg` |
| A/B Showroom-Sprite gegen Echtzeit `show`, dieselbe Kamera, beide Spielerautos | erfüllt, Entscheidung: `showroom = false` | `06_showroom_ab.jpg`; was fehlt, steht in Abschnitt 7 |
| ≤ 6 Zeichenaufrufe je Verkehrsauto in `lod0` | erfüllt | 6 (Karosserie: `vpbr` + `glass`, 4 Räder) bei Limousine, Schrägheck, Kombi; `lod1`/`lod2` je 1 |
| Geometrie-Fixture identisch | erfüllt | `check_sprite_geometry.py`: 187 von 187 Sets identisch (1 davon „REIHENFOLGE“), 0 „ANDERS“, 346 s |
| Byte-Bericht | erfüllt | Abschnitt 3, `pruefer_bericht.txt` |
| alle Tests | erfüllt | `tools/run_tests.sh`: 569 Tests, 0 fehlgeschlagen; 64 `CHECK … OK`, 0 `FEHLER`; 549 s |
| Arcade unverändert | erfüllt | `tools/golden.sh check`: 20 von 20 identisch (151 s) |
| Render-Prüfung Modelle | erfüllt | `tools/run_render_checks.sh modern check_models`: 6 Prüfungen OK (Blinker ≥ 240 px in jeder Stufe, Bremslicht 2,63 × Rücklicht) |

## 3. Zahlen (gemessen)

| Modell | Dreiecke je Stufe (Budget) | Aufrufe | Netze |
|---|---|---|---|
| `player/limousine` | lod0 45 764 (55 000) · show 99 670 (120 000) · Schatten 1 872 (3 000) | 6 / 6 | 1 573 290 B |
| `player/kompakt` | lod0 50 080 · show 107 042 · Schatten 1 872 | 6 / 6 | 1 742 534 B |
| `traffic/sedan` (4 Farben) | lod0 17 695 (18 000) · lod1 5 805 (6 000) · lod2 1 123 (1 200) · Schatten 636 | 6 / 1 / 1 | 260 279 B |
| `traffic/hatch` (5 Farben) | lod0 17 317 · lod1 5 753 · lod2 1 136 · Schatten 652 | 6 / 1 / 1 | 256 895 B |
| `traffic/wagon` (4 Farben) | lod0 17 888 · lod1 5 937 · lod2 1 103 · Schatten 604 | 6 / 1 / 1 | 269 062 B |
| `traffic/truck` (4 Lackierungen) | lod0 18 084 (25 000) · lod1 4 672 (7 000) · lod2 1 490 (1 500) · Schatten 356 | 13 / 1 / 1 | 160 568 B |

Zusammen 4 262 628 B (4,07 MB) für die sechs Fahrzeuge; alle Netze des Spiels 4,18 MB von 40 MB. Keine Texturen.
Export aller sechs Fahrzeuge: 31 s, Bake 0,3 s. Ein erzwungener zweiter Export ergab Byte für Byte dieselben
Karosserie-Netze (`git status` zeigte nach dem Neuexport nur die absichtlich geänderten Schattenwerfer).

Lampenflächen (projiziert, nach Wicklung, cm²; Blinker je Seite; Regel: hinten ≥ 60, vorn ≥ 40, Spielerauto vorn
≥ 15, Rücklicht ≥ 200, Bremslicht ≥ 100, Scheinwerfer ≥ 80):

| Modell, Stufe | Rücklicht | Bremslicht | Blinker hinten | Scheinwerfer | Blinker vorn |
|---|---|---|---|---|---|
| Limousine (Spieler) lod0 / show | 874 / 869 | 830 / 827 | 84 / 81 | 89 / 89 | 20 / 20 |
| Kompakt (Spieler) lod0 / show | 914 / 899 | 900 / 890 | 102 / 100 | 101 / 102 | 28 / 27 |
| Limousine (Verkehr) lod0 / lod1 / lod2 | 639 / 847 / 887 | 759 / 967 / 1 007 | 99 / 99 / 99 | 161 / 242 / 327 | 95 / 95 / 86 |
| Schrägheck lod0 / lod1 / lod2 | 727 / 902 / 965 | 846 / 1 021 / 1 084 | 95 / 95 / 95 | 195 / 273 / 360 | 112 / 100 / 95 |
| Kombi lod0 / lod1 / lod2 | 973 / 1 188 / 1 031 | 1 093 / 1 308 / 1 081 | 102 / 102 / 102 | 171 / 250 / 316 | 95 / 90 / 50 |
| Sattelzug, jede Stufe | 860 | 860 | 450 | 1 000 | 320 |

Die Blinker der Pkw sind in allen drei Stufen gleich groß: dieselbe Kontur, in jede Stufe eingeschnitten.
Im Bild der Render-Prüfung (Limousine silber von hinten, Blinker an): 390 / 390 / 390 Bildpunkte bernsteinfarben in
`lod0` / `lod1` / `lod2`; Bremslicht 2,63-mal so hell wie das Rücklicht in jeder Stufe.
Lichtanker: Verkehrsautos ≤ 3,5 mm von ihrer Lampe; Spielerautos bis 33 mm (der Anker liegt in der Öffnung der
Mulde, der Leuchtkörper bis 28 mm dahinter; „unter der Lampe“ höchstens 2,9 mm bei erlaubten 3 mm).

## 4. Was gebaut wurde

### Spielerautos `player/limousine`, `player/kompakt`

- Karosserie aus den Generatoren der Sprites (`cesprites.player_cars`) in zwei Stufen: `lod0` (Rennen) und `show`
  (Showroom). Hooks mit Voreinstellung „wie im Sprite“ – kein Sprite-Vertex bewegt sich (Abschnitt 6).
- **Lampen mit Tiefe:** Jede Lampeneinheit ist eine Mulde in der Karosserie (Hook `lamp_depth`): Boden, Wände,
  versenkte Leuchtkörper, Streuscheibe bündig in der Öffnung. Der Lichtanker liegt an der Oberfläche.
- **Heck:** Leuchten mit Tiefe, dritte Bremsleuchte (Limousine: Leiste unter dem Dach hinter der Heckscheibe;
  Kompakt: die des Entwurfs im Dachspoiler), Kennzeichen mit Rahmen und zwei Kennzeichenleuchten (leuchten mit
  dem Rücklicht), Rückstrahler, Endrohre, Emblem, Rückfahrlicht, eigene Blinkerfelder.
- **Glas und Innenraum:** durchsichtiges, getöntes Glas mit Spiegelung (Fresnel), dahinter Sitze, Kopfstützen,
  Armaturenbrett, Lenkrad links, Hutablage, Innenverkleidung. Die Kabine ist dafür aufgeschnitten.
- **Front:** Scheinwerfer mit Tiefe und Tagfahrlicht, Kühlergrill als Vertiefung mit Lamellen, Spiegel mit Glas,
  zwei Scheibenwischer, Türgriffe, Dachantenne (Haifischflosse).
- **Räder:** Speichenfelgen mit Tiefe, Bremsscheiben und Sättel, Reifen, Radhäuser mit Innenkotflügel.
- **Schattenwerfer:** grobe Hülle, 12 mm unter die Außenhaut gezogen (Abschnitt 5, Runde 6).

### Verkehrsautos `traffic/sedan`, `traffic/hatch`, `traffic/wagon`

- Neu aufgebaut auf den glatten Lofts von `carbody.SmoothCar` (bisher nur für die Spielerautos benutzt), gespeist
  aus den Entwurfstabellen der Sprites (`cesprites.designs`). Die alten Lofts von `vehicles.Car` knitterten in
  `lod1`/`lod2`, ihre Stoßfänger stachen an den Ecken durch die Karosserie.
- Fenster, Lampen, Kennzeichen (mit Zeichen), Griffe, Fugen, Tankklappe: als Geometrie in die Karosserie
  geschnitten, entlang ihrer Kontur – in `lod0`, `lod1` und `lod2` dieselben Linien.
- `lod1`/`lod2`: dieselben Lofts mit weniger Stationen, Normalen von `lod0` übertragen. Sie vereinfachen, sie
  knittern nicht. Neue Prüfregel: Hüllquader jeder Stufe ≤ 3 cm neben dem von `lod0`.
- Alle Farbsets sind Lackwerte desselben Netzes (Limousine 4, Schrägheck 5, Kombi 4).
- Glas dunkel und spiegelnd (Glas-Klasse in `lod0`), kein Innenraum. Felgen mit fünf Speichen und Bremsscheibe,
  Spiegel mit Glas, Endrohr, Kombi mit Dachreling.

### Sattelzug `traffic/truck`

- Zugmaschine (Fahrerhaus nach Profil, Sonnenblende, Dachspoiler, Seitenverkleidung, Stoßfänger mit
  Scheinwerfern, Tritte, Tanks, Spiegel, Wischer) und Kofferauflieger als eigene Knotengruppen mit Drehpunkten
  (`groups` im Manifest) – der Renderer kann den Zug knicken.
- **Heck (liest sich auf 20–150 m):** Türen mit Rahmen und Gestängen, rot-weiße Konturmarkierung (leuchtet bei
  Nacht als angestrahlte Fläche), zwei rote Umrissleuchten oben, Leuchtenträger mit Blinker / Rück- und
  Bremslicht / Rückfahrlicht, Dreieckrückstrahler, Kennzeichen, Unterfahrschutz, Schmutzfänger.
- Vier Lackierungen als Lackwerte (Koffer, Fahrerhaus, Streifen + Schriftzug „CE“).

## 5. Runden: was ich gesehen und geändert habe

1. **Bestand aufgenommen** (Lauf 1 war durch einen Neustart beendet): Katalogeinträge für Kompakt, Schrägheck,
   Kombi; erster Export. Prüfer rot (Budgets, Lampenflächen).
2. **Spielerautos, Runde 1:** Lampen waren aufgesetzte Schichten ohne Tiefe, Glas undurchsichtig. → Mulden
   (`lamp_depth`), Glas-Shader mit vormultipliziertem Alpha, Innenraum sichtbar. Fehler dabei: 24 verdrehte
   Dreiecke (Fasen breiter als das halbe Teil; Splitter nach der 16-Bit-Quantisierung) → Splitterfilter.
3. **Spielerautos, Runde 2:** Kamm aus Lackdreiecken entlang der Scheibenoberkante; Decal-Enden gezackt. →
   Schnitt entlang der Normalen-Isolinie, Splitter in der Projektion übersprungen, Deckungsprüfung.
4. **Spielerautos, Runde 3:** Heck zu leer, Grill flach. → dritte Bremsleuchte, Kennzeichenrahmen + Leuchten,
   Antenne, Wischer, Grill mit Tiefe; Fugen über den Lampenmulden weggeschnitten; Mulde des Kompakten läuft über
   Karosserie und Kabine.
5. **Verkehrsautos:** `lod1`/`lod2` knitterten, Stoßfänger stachen durch, Loch unter der Rückleuchte der
   Limousine, vordere Blinker des Kombi 0 cm², Scheinwerfer in `lod1` 8 cm². → Neuaufbau auf `SmoothCar`,
   Flächenbilanz beim Schnitt, Rang der Decals aus der vollständigen Liste, Blinker immer oben; dunkles „Brett“
   an den flachen Endkappen → `flatten_ends`.
6. **Showroom-Vergleich:** dunkle Schraffur auf Kotflügel und Tür des Kompakten. Ursache war nicht das Netz,
   sondern der Schattenwerfer: Die grobe Hülle stand hinter dem ausgestellten Radlauf 7,9 mm aus der Karosserie
   (gemessen) und warf ihren Schatten auf sie. Außerdem lag die Kappe der Radtrommeln vor den Felgen – die Felgen
   bekamen nie Sonne („stumpfe Felgen“). → `core.tuck_inside` (Hülle 12 mm unter der Haut), Trommeln nur noch die
   innere Reifenhälfte; Verkehrsautos bekommen Radtrommeln im Werfer, der Lkw ein Fahrerhaus nach Profil.
7. **Lkw:** Heck aus 20 / 60 / 150 m betrachtet; Reifen standen 13 mm über dem Boden (Prüfer) → Drehkörper beginnt
   mit einem Punkt senkrecht unten; `lod2` über Budget → Schriftzug und Grilllamellen dort weggelassen.

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
8. **Rücklicht bei Nacht** ist am Spielerauto recht dunkel gegen das Bremslicht – eine Frage der Lampenenergien
   des Renderers, nicht des Netzes.

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

| Lauf | Ergebnis |
|---|---|
| `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (10 Modelle, 180 Sets) |
| `check_sprite_geometry.py --jobs 2` (alle Sets) | 187 von 187 identisch, 1 davon „REIHENFOLGE“, 0 „ANDERS“, 346 s |
| `export_models.py --check-keys` | `CHECK cache_keys OK` (10 Modelle) |
| erzwungener Neuexport der sechs Fahrzeuge + Bake | Netze Byte für Byte unverändert (`git status` ohne Modelldateien) |
| `tools/run_tests.sh` (vollständig, einmal) | bestanden: 569 Tests, 0 fehlgeschlagen; 64 `CHECK … OK`, 0 `FEHLER`; 549 s |
| `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch` (151 s) |
| `tools/run_render_checks.sh modern check_models` | 1 von 1 Prüfdateien in Ordnung, 6 Prüfungen OK: Blinker Verkehrs-Limousine von hinten 390/389 · 390/390 · 390/390 px (lod0 · lod1 · lod2), von vorn 400/400 · 399/400 · 357/359 px (verlangt ≥ 240); Bremslicht 2,63 × Rücklicht in jeder Stufe |

Die Tests liefen auf dem Stand vor dem letzten Commit; der fügt nur eine Abbruchbedingung im Exporter und Text in
`docs/modelle.md` hinzu (die Modelldateien blieben beim Neuexport danach unverändert, der Prüfer grün).
Alle Läufe mit eigenem `XDG_DATA_HOME` im Arbeitsordner, Software-OpenGL unter Xvfb, höchstens zwei Prozesse.

