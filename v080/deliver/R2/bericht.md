# Bericht R2 – Gelände, Requisiten, Fernboden (v0.8.0, M1)

Bauabschnitt R2 nach Bauplan §6 Welle 1, Nachträge A-3, A-4, A-7, A-8. Dieser Lauf ist der **zweite Nachfolger**:
Der erste Lauf wurde nach gut einer Stunde von einem Nutzungslimit gestoppt (nicht durch einen eigenen Fehler).

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2`
- Branch: `worktree-wf_145e8e23-1e4-2`, Sicherungskopie `origin wip/v080-r2`
- Basis: Gerüst R1a `65c7560` → Stand des Vorgängers `f21537c` (vorgespult) → dieser Lauf (Commits unten)
- „gemessen“ = auf dieser VM (headless bzw. llvmpipe unter Xvfb, 4 geteilte Kerne, Last 6–11 durch andere Aufträge);
  „abgeleitet“ = gerechnet/gefolgert. Nichts hier ist auf einer echten Grafikkarte oder dem Steam Deck gemessen.

**Prüfläufe auf dem Endstand `b947e73`** (sauberer Baum, alle gemessen): `tools/run_tests.sh` vollständig grün –
592 Unit-Tests, 76 `CHECK … OK`, 0 `FEHLER`, 630 s (ein einziger vollständiger Lauf dieses Nachfolgers);
`tools/golden.sh check`: **GOLDEN arcade: 20 von 20 identisch** (220 s); `tools/run_render_checks.sh modern`: 5 von 5
Dateien OK (Fassade, Modelle, Requisiten, Naht, Geländesperre); `tests/sim/modern_sight.gd` F1–F3, F7 grün.

## 1. Übernahme und Durchsicht

Der Vorgänger hatte alles committet (`d3e61d6` … `f21537c`, sieben WIP-Commits); einen Commit „Stand beim Abbruch“
des Leiters gab es nicht, der letzte Commit (`f21537c`) ergänzte nur die fehlende `.uid`-Datei der
Draufsicht-Prüfung. Seine STAND.md war hinter seinen Commits zurück (nannte Tests und Prüfungen noch als „next“).
Durchsicht von `f21537c` (gemessen): `tests/check_scripts.gd` 237 Skripte, 0 fehlerhaft; `tools/run_tests.sh race3d`
57 Tests, 0 fehlgeschlagen; `check_terrain_plan` grün; `modern_sight.gd` grün; `check_terrain_cover` 6 von 6 grün.
Alle Dateien gehören R2 (oder sind neue Dateien seines Bereichs); keine eingefrorene Datei, kein Kern, keine
Konfiguration berührt. Die Durchsicht des Codes fand keinen Fehler; gefunden habe ich ein Bildproblem (Streifen,
Abschnitt 3) und einen Messbefund (Vertretungen dunkler als Arcade, Abschnitt 4).

## 2. Was geliefert ist

| Datei | Inhalt |
|---|---|
| `scripts/race3d/builders/terrain.gd` | Geländeband je Stück (Kern-Profil, Bankett, Graben, Relief, Talsohle), Schürze, Wasser unter Brücken, kein Gelände im Tunnel; 896 Dreiecke je Stück |
| `assets/shaders/modern/terrain.gdshader`, `inc/ground.gdshaderinc` | Oberfläche: Arcades Grasbänder (scharf, nahe der Straße), Kies, gemähtes Bankett, Graben, berechnete Felder mit Akzentfarbe der Landschaft, Furchen, Ränder, Flecken, Körnung, Schnee (`ce_snow`), Nässe (`ce_wet`), Übergang in den Fernboden, Wasser, Lichtkegel (`pools`) |
| `scripts/race3d/ground_look.gd` | Landschaftsstile, Randbezirk → Zentrum, Bild in der Ferne, Detailtextur |
| `scripts/race3d/layers/far_ground.gd`, `far_ground.gdshader` | Fernboden: Scheibe unter der tiefsten geladenen Straße mit Kragen bis Augenhöhe; schließt Spalt an der Mittelachse und Loch im Kurvenmittelpunkt; `ce_far_y` |
| `scripts/race3d/prop_library.gd`, `builders/props.gd` | Requisiten: MultiMesh je Netz und Stück, gespiegelte Knoten (D24), auf `ctx.ground()`, Detailstufen aus den Qualitätsstufen, Fernbilder, Sprite-Vertretungen, Kontaktschatten, Lampen über `add_lamps`, Auslassungen (Band, Korridor, fehlend, Dichte), Mechanismus `bend_cover` (Liste leer), `ModelDB.request/missing/release_all` |
| `assets/shaders/modern/billboard.gdshader` (übernommen von PIPE), `contact_shadow.gdshader` | Vertretungen mit Arcades Lichtgesetz und Scheinwerfern; Kontaktschatten |
| `tests/unit/race3d/test_terrain_builder.gd`, `test_props.gd` | Unit-Tests |
| `tests/race3d/check_terrain_plan.gd` | Draufsicht-Prüfung (headless, läuft über den Haken in `run_tests.sh`) |
| `tests/race3d/render/check_terrain_cover.gd`, `check_props_render.gd` | Geländesperre; Spiegelung der Requisiten wirklich gezeichnet |
| `docs/renderer-modern-gelaende.md` | deutsche Dokumentation des Bauabschnitts |

Commits dieses Laufs (alle nach `origin wip/v080-r2` gesichert): `4cc20a4` Feldmuster berechnet, Arcade-Bänder scharf
im Shader · `34a84da` Render-Prüfung `props_spiegel` · `b947e73` Dokumentation, Sonne der Vertretungen 0,8 / 1,15.
Davor die sieben Commits des Vorgängers `d3e61d6` … `f21537c`. 30 Dateien gegenüber dem Gerüst `65c7560`
(einschließlich `.uid`), +4.070 Zeilen, keine Datei außerhalb des Bereichs von R2.

## 3. Gelände: was dieser Lauf geändert hat

**Streifen an Hängen** (gefunden im A/B-Bild T3, Saragossa – Pau km 172,8): Der Hang links zeigte waagrechte helle
und dunkle Streifen. Ursache: Schattierung, Farbe und Furchenrichtung jedes Felds kamen aus einer gefilterten
Zelltextur; in der Ferne verschwimmen die Zellwerte, und `fract()` der verschwommenen Werte wurde zu Streifen,
dazu Feldränder ohne Ausblendung nach Fußabdruck. Jetzt: Felder als im Shader berechnetes Voronoi-Muster (etwa
110 × 72 m, geglättete Grenze), alles Feine blendet nach dem Fußabdruck des Bildpunkts aus. Vorher/nachher:
`vorher_nachher/T3_*`, `vorher_nachher/S3_*`.

**Arcades Grasbänder** waren als Eckpunktfarbe zwischen den Reihen verschmiert und kaum zu sehen. Jetzt zeichnet der
Shader sie scharf aus der Bandphase (`UV.y` = Segment / `render.stripes.grass`), die Eckpunktfarbe ist das Mittel,
`CUSTOM1` trägt die halbe Differenz; nahe der Straße voll, ab 40 m das Mittel, in den City Limits 35 % (wie zuvor).

## 4. Requisiten: was dieser Lauf geändert hat

- **Licht der Vertretungen** (Auftrag: `sun_min`/`sun_max` einstellen): gemessen (mittlere Farbe der Baumkronen vor
  Himmel) waren die Vertretungen mit dem Wert des Vorgängers (0,72 / 1,18) 13–21 % dunkler als das Arcade-Sprite
  an derselben Stelle, mit 1,0 / 1,0 noch 7–16 %. Der Rest ist Arcades eigener Sprite-Nebel (Arcade blendet Sprites
  schon aus der Nähe zu einer aufgehellten Nebelfarbe, Modern darf nach F4 nicht stärker nebeln). Jetzt 0,8 / 1,15.
- **Render-Prüfung `props_spiegel`** (neu): Die gespiegelten MultiMesh-Knoten des Builders wirklich gezeichnet –
  Bauernhaus (`baked`, `mirror_left`), Laterne (`vpbr`, `mirror_left`), Birke und Strohballen (Vertretungen mit
  Regel-Spiegelung) beidseitig, Kamera auf der Mitte, Sonne im Zenit: das Bild ist sein Spiegelbild (gemessen:
  je Hälfte rund 10.000 Bildpunkte, Abweichung im Mittel 0,14 Stufen, 0,06 % über 40 Stufen). Bild:
  `props_spiegel.png`. (PIPEs `check_models.gd` → `multimesh` prüft schon Laterne und Fernbild im MultiMesh.)

## 5. Abnahme (Bauplan §6 R2 und Auftrag)

| Abnahmepunkt | Ergebnis | Beleg |
|---|---|---|
| Geländesperre: `check_terrain_cover` ≤ 0,2 % an T1–T4, S1, C1 | erfüllt | 0,000 % an allen sechs (gemessen auf `b947e73`, Bilder `cover/`); siehe aber Abschnitt 9, Punkt 4 |
| A/B-Bilder T1–T4 ohne Leere, sichtbare Bandkante oder Unterseite | erfüllt | `ab/T1…T4_ab_00.jpg`, `draufsicht/`; angesehen: keine Leere, keine Kante, keine Unterseite |
| headless: keine Geländedreiecke verschiedener Stücke überlappen in der Draufsicht (12 härteste Richtungen) | teilweise | verschiedene Straßenteile: 0 Überlappungen; Bandspitzen derselben Kurveninnenseite: 71 Paare ≤ 1,83 m (Ursache im Kern, Behebung gemessen, Abschnitt 9) |
| Requisitenliste eines Stücks = `TrackSegment.sprites` minus dokumentierte Auslassungen (fünf Landschaften) | erfüllt | `test_props.gd` → `test_chunk_list_is_the_tracks_list_minus_the_documented_drops` |
| F7 grün mit dem ausgelieferten Relief | erfüllt | `modern_sight.gd`: `modern_sight_f7` 0 von 207.166 |
| ≤ 1.100 Geländedreiecke je Stück | erfüllt | 896 (`terrain_plan_budget`, Unit-Test) |
| ≤ 2 Zeichenaufrufe je Set und Stück | erfüllt (heute) | Unit-Test; mit Varianten/zweiflächigen gespiegelten Modellen nicht haltbar (Abschnitt 9, Punkt 2) |
| Geländeshader mit Oberfläche statt Flachfarbe (Gras, Mähstruktur, Bankett, Kies, Graben, Schnee, Nässe, Übergang), `pools` eingebunden und angemeldet | erfüllt | `terrain.gdshader`; Bilder S1–S3, N1, R1; `ground_material()` → `add_pool_material` |
| Fernboden deckt Spalt an der Mittelachse und Loch im Kurvenmittelpunkt (A-3) | erfüllt | Draufsichten (blasse Flächen), Fernboden-Anteile der Geländesperre, Unit-Test „Fernboden unter jeder geladenen Straße“ |
| Requisiten als MultiMesh je Netz und Stück, gespiegelter Knoten (D24), auf `ctx.ground()` | erfüllt | `test_props.gd`; `props_spiegel` (wirklich gezeichnet) |
| LOD aus den Qualitätsstufen, Fernbilder, Vertretungen mit Szenenlicht und Kontaktschatten, `sun_min/max` eingestellt | erfüllt | `test_chunk_lod_shows_one_representation`; Messung Abschnitt 4 |
| Modell wie ein Fahrzeug gestellt; Requisiten jenseits des Bands weggelassen; Kurvenkorridor-Mechanismus mit leerer Liste | erfüllt | `test_placement_drops_and_lamps`, `test_bend_corridor_and_density` |
| Lampen der Requisitenmodelle über `add_lamps(parent, lamps)` (A-7) | erfüllt | Unit-Test mit Prüf-Renderer (zwei Laternen, Felder aus A-7) |
| `ModelDB.request` in `prepare()`, `missing()` → Vertretung oder „manifest“, `release_all(self)`, `ModernMaterials.shared()` | erfüllt | `prop_library.gd`; Unit-Test „jedes Set Modell oder Vertretung“ |
| `build()` nur mit Schnappschuss-Arrays (Arbeiter-Thread) | erfüllt | Code-Durchsicht: `build()` beider Builder liest nur `ctx`-Arrays und die einfachen Daten aus `collect()` |
| `tools/run_tests.sh` grün | erfüllt | vollständiger Lauf auf `b947e73`: 592 Unit-Tests, 76 Prüfungen OK, 0 fehlgeschlagen, 630 s |
| `tools/golden.sh check`: 20 von 20 identisch | erfüllt | „GOLDEN arcade: 20 von 20 identisch (220 s)“ auf `b947e73`, sauberer Baum |
| `tools/run_render_checks.sh modern` | erfüllt | 5 von 5 Dateien OK auf `b947e73` (Fassade, Modelle, Requisiten, Naht, Geländesperre) |

## 6. Bilder und ehrliches Urteil

Ordner `ab/`: Arcade | Modern desselben Simulationszustands (`tools/ab_shot.sh` über `ab_all.sh`, Modern mit
`--gfx-preset=medium`), Aufnahme 2 s nach fliegendem Start genau am Referenzkilometer: S1 (km 2), S2 (km 13,6),
S3 (km 60), T1 (Kassel – Würzburg km 46,5), T2 (km 61,9), T3 (Saragossa – Pau km 172,8), T4 (km 198,8),
C1 (Dortmund – Frankfurt km 221, 19:30), dazu N1 (Hamburg – Hannover km 71, Schnee, 22 Uhr) und R1 (S3 bei Regen,
19:30). Übersicht: `uebersicht.jpg`. Draufsichten T1–T4: `draufsicht/`. Geländesperre: `cover/`.

**Ehrliches Urteil** (gegen das Arcade-Bild desselben Zustands; im Modern-Bild stehen nur das Gerüst R1a – Debug-Straße,
eingebaute Umgebung, Himmelsverlauf – und R2; Straße, Leitplanken, Markierungen, Hintergrund, Fahrzeuge und Schilder
kommen von R1/R3 erst mit RINT):

- **Besser – das Gelände.** Echte Hügel und Täler: an T1 windet sich die Straße sichtbar über die Hügel, an T2/T3
  Kuppen und Hänge, an T4 die Haarnadel mit dem Hang dahinter. Felder in den Farben der Landschaft mit scharfen
  Rändern (S1, S3: Getreide), gemähtes Bankett mit Arcades zwei Grastönen als Bänder, Kies, Graben, Wasser unter
  der Brücke (C1), Schnee bei Nacht (N1), Nässe am Abend (R1). Keine Löcher, keine sichtbare Bandkante, keine
  Unterseite an T1–T4 (auch nicht in den Bildern mit `--gfx-debug=cover,far`). Arcades Boden ist dagegen flach mit
  Bändern bis zum Horizont.
- **Besser – die Kartenbäume** (Eiche, das einzige Baummodell): feiner als die Sprites, mit echtem Schatten (S1, S3).
- **Gleich – die Vertretungen**: 83 von 86 Requisiten-Sets sind noch die Arcade-Sprites als Billboards, flach, sie
  drehen mit der Kamera; nach der Einstellung 7–16 % dunkler als in Arcade (Arcades Sprite-Nebel, Abschnitt 4).
- **Schlechter – die Kurveninnenseiten** (Regel F7): an T2 fehlen links 38 von 135 Requisiten, an T4 rechts der
  große Felsen und die Fichte, die Arcade in die Kurve stellt; dort ist nur Wiese.
- **Schwächer in der Ferne**: Felder blenden ab etwa 270 m in ihren Mittelton (gegen Flimmern) – die Landschaft dahinter
  ist gleichmäßig, im Nebel unauffällig. Den Horizont bilden heute nur Nebelfarbe und Kragen; Berge und
  Silhouetten bringt `layers/backdrop.gd` (R1).
- **Gesamtbild**: Mit dem Gerüst allein ist das Modern-Bild heute **nicht** klar besser als Arcade – es fehlen die
  Inhalte von R1 und R3, und die Vertretungen sind Arcades Sprites. Das Gelände allein ist klar besser.

Ältere Stände zum Vergleich (`vorher_nachher/`): T3 und S3 mit dem Feldmuster des Vorgängers (Streifen am Hang).

## 7. Messwerte

| Messung (alle gemessen, je ein Lauf, Maschine mit Last 6–11) | Wert |
|---|---|
| Geländesperre `check_terrain_cover`, Magenta unter der Horizontzeile an T1, T2, T3, T4, S1, C1 | 0,000 % an allen sechs (Grenze 0,2 %); Fernboden + Kragen sichtbar: T1 2,93 + 2,60 %, T4 0,39 + 1,78 %, C1 1,74 + 0,25 %, T2/T3/S1 0 % |
| `check_terrain_plan`: 40 Kamerapositionen in 13 Etappenrichtungen, 583 Stücke, 36.336 Streifen, 1.677.371 Paare | 0 Überlappungen verschiedener Straßenteile (zwischen und in Stücken), 0 gefaltete Streifen, schmalstes Band 101 m; Bandspitzen derselben Kurve: 71 Paare an 7 Positionen, tiefste 1,83 m; mit den drei Kernzeilen 0; 18 s |
| Dreiecke je Stück | höchstens 896 (Budget 1.100) |
| Zeichenaufrufe je Set und Stück (Unit-Test, Hauptdurchgang) | höchstens 2 (Eiche 2, alle anderen 1 je Seite) |
| Requisiten in der Draufsicht (gezeichnet / im Kurvenkorridor weggelassen) | T1 77 / 36, T2 97 / 38, T3 15 / 14, T4 95 / 61; jenseits des Bands 0 |
| `modern_sight.gd` (F1–F3, F7 mit dem ausgelieferten Relief) | alle OK: F7 0 von 207.166 Querschnittsseiten; 18 s |
| `render()` des Renderers (Debug-Straße, Gelände, Requisiten, Fernboden), headless, 20 s Fahrt, „Mittel“ | im Mittel 0,22 ms (S1) / 0,17 ms (C1) / 0,17 ms (T4), höchstens 8,7 / 1,5 / 5,1 ms |
| Bauen eines Stücks (Arbeiter-Thread, alle Builder) / Einhängen | im Mittel 2,0–2,6 ms, höchstens 6,2 ms / höchstens 0,41 ms |
| Zeichenaufrufe des Bildes unter Xvfb, „Mittel“ (mit Debug-Straße, ohne Fahrzeuge) | S1 82 (22.411 Dreiecke + 1.432 im Schatten), C1 96 (28.028 + 358) |
| Vertretung gegen Arcade-Sprite (mittlere Farbe der Krone vor Himmel) | mit 0,72 / 1,18: 13–21 % dunkler; mit 1,0 / 1,0: 7–16 % dunkler; eingestellt 0,8 / 1,15 |
| `props_spiegel` | je Hälfte 10.024 / 10.009 Bildpunkte, Abweichung vom Spiegelbild im Mittel 0,14 Stufen, 0,06 % über 40 Stufen |

Bildzeiten unter llvmpipe (145–200 ms je Bild bei Last ~10, mit dem alten wie mit dem neuen Feldmuster) sagen nichts
über eine Grafikkarte; die Feldmuster kosten je Bildpunkt eine Schleife über neun Zellen (abgeleitet: auf einer
Grafikkarte vernachlässigbar).

## 8. Abweichungen vom Bauplan

1. **Neue Dateien über die Liste von §6 hinaus**, alle im Bereich von R2: `scripts/race3d/ground_look.gd`,
   `assets/shaders/modern/inc/ground.gdshaderinc`, `assets/shaders/modern/contact_shadow.gdshader`,
   `tests/race3d/check_terrain_plan.gd`, `tests/race3d/render/check_props_render.gd`, `docs/renderer-modern-gelaende.md`.
2. **Dokumentation in einer eigenen Datei** `docs/renderer-modern-gelaende.md` statt eines Abschnitts in
   `docs/renderer-modern.md` (die gehört „dem Renderer“; R1, R2 und R3 hätten sich in dieser Welle darin gekreuzt).
   RINT sollte in `docs/renderer-modern.md` §1 und §9.11 darauf verweisen.
3. **Kurvenkorridor**: weggelassen werden schmückende Requisiten *jeder* Klasse (Landschaftsregel, ohne `offset`) und
   jede Vegetation – F7 nennt nur „decorative vegetation“, `docs/renderer-modern.md` §7.6 „Relief, Vegetation und
   Bauten“. Folge: an T4 fehlt der große Felsen, den Arcade in die Kurve stellt. Ereignis-Requisiten (Tankstelle,
   Grenze, Radar) bleiben stehen, solange sie keine Vegetation sind.
4. **Das Gelände wirft keinen Schatten** (Schalter `terrain_shadows` in den Qualitätsstufen, den `Gfx.levels` nicht
   kennt – also aus): das Relief ist mild, es kostete je Stück einen Schattendurchgang.
5. **Felder im Shader gerechnet** statt aus der Zelltextur (Abschnitt 3): die Kanäle b/a von
   `GroundLook.noise_texture()` sind seitdem ungenutzt (bleiben erzeugt, 256² RGBA).
6. **Bandspitzen**: `check_terrain_plan` duldet Überlappungen von Bandspitzen *derselben* Kurveninnenseite bis 3 m
   (`terrain_plan_tips`, `STRICT = false`), weil die Ursache im Kern liegt (Abschnitt 9, Punkt 1); verschiedene
   Straßenteile dürfen sich gar nicht überlappen.
7. **Zeichenaufrufe je Set und Stück** zählt der Unit-Test im Hauptdurchgang je Netz; der Schattenwerfer der
   Kartenbäume (nur Schattendurchgang) und der eine Kontaktschatten-Knoten je Stück (alle Sets) zählen nicht dazu.
8. Sets, die die Liste der Etappe (`prepare(ctx).sets`) nicht nennt, lädt `collect()` synchron im Hauptthread nach;
   an den Referenzpositionen nicht beobachtet, aber nicht ausgeschlossen.

## 9. Probleme im Bauplan (mit Belegen)

1. **Bandspitzen in Kurven (Kern)**: `TerrainProfile` kürzt jede Reihe nach ihrer eigenen Krümmung; wo sie sich
   entlang der Kurve ändert, überlappen die Spitzen der Innenseite (gemessen: 71 Paare an 7 von 40
   Kamerapositionen, tiefste 1,83 m) – wörtlich verletzt das „no terrain triangles of different chunks overlap“.
   Drei Zeilen im Kern (auch nach `_kappa()` der Seite kürzen) beheben es: 0 Paare, `modern_sight.gd` F1–F3, F7
   grün (gemessen, Versuch mit `m1/R2/bin/exp_kernel.sh`, danach zurückgesetzt). Der Kern gehört R1 → RINT.
2. **„≤ 2 Zeichenaufrufe je Set und Stück“ gegen §4.6.6 und D24**: Varianten werden je Requisite gewählt und
   Gespiegeltes braucht einen zweiten Knoten; ein Kartenbaum (2 Flächen) mit zwei Varianten oder ein Haus mit
   `baked` + `baked_cutout` auf beiden Seiten braucht 4. Heute hat kein Modell Varianten oder zwei Flächen mit
   `mirror_left` → gemessen ≤ 2. Lösung, falls gewünscht: eine Variante je Stück (stabiler Hash der Stücknummer).
3. **F7-Wortlaut**: „no decorative vegetation“ (D14) gegen „Relief, Vegetation und Bauten“ (renderer-modern.md
   §7.6); umgesetzt ist die strengere Lesart (Abweichung 3). Die Projektleitung sollte festlegen, ob Felsen und
   Häuser einer Landschaftsregel im Korridor bleiben dürfen.
4. **Die Geländesperre (§4.9.2, ≤ 0,2 % Magenta)** ist durch den Kragen des Fernbodens schon erfüllt, sobald es ihn
   gibt: Er schließt alles unter der Horizontzeile. Über Löcher im Band sagt erst der Anteil des Fernbodens etwas
   (die Prüfung meldet ihn) – und die A/B-Bilder.
5. **Arcade nebelt Sprites schon aus der Nähe** (zu einer aufgehellten Nebelfarbe, `RoadRenderer._modulate`); F4
   verbietet Modern, statische Szenerie stärker zu nebeln. Darum wirken Vertretungen und Gelände in mittlerer
   Entfernung 7–16 % dunkler und satter als in Arcade (gemessen) – unvermeidlich, für R4 (Nebel) wichtig.
6. **Konfiguration**: `graphics.modern.props.bend_cover`, `bend_cover_max_h_m` und `graphics.modern.terrain.styles`
   liest R2 mit Vorgaben im Code; der Abschnitt `graphics` gehört R1 – RINT kann sie (leer) eintragen.
7. **A-4 „release“ ohne Eigentümer**: Der Builder gibt seine Modelle beim Freigeben mit `ModelDB.release_all(self)`
   zurück; `ModernMaterials.drop_shared()` beim Verlassen von Modern ruft weiter niemand (schon von R1a gemeldet).
8. **Auftrag „multimesh_parts im echten MultiMesh, in Welle 0 nie so gezeichnet“**: PIPEs `check_models.gd` →
   `multimesh` zeichnet Laterne und Fernbild schon so (mit gespiegeltem Knoten); R2 ergänzt `props_spiegel` für die
   Knoten des Builders selbst (Bauernhaus `baked`, Vertretungen, Kontaktschatten).

## 10. Für RINT und die nächsten Bauabschnitte

1. **RINT**: die drei Kernzeilen (Abschnitt 9, Punkt 1) einbauen, dann `STRICT = true` in `check_terrain_plan.gd`.
2. **RINT/R1**: `--gfx-debug=cover` muss auch in `environment_rig.gd` (Nebel aus) und `layers/backdrop.gd` (Leinwand
   magenta) gelten, sonst schlägt `check_terrain_cover` fehl („über dem Horizont ist die Leinwand nicht magenta“);
   `far` färbt der Fernboden selbst.
3. **R1**: `layers/lights.gd` setzt die Lichtkegel-Uniforms auf dem Geländematerial (angemeldet über
   `add_pool_material`) und nimmt die Straßenlaternen über `add_static(holder, lamps)` an (Rolle `lights`, Kegel 9 m).
4. **RINT**: Das Gelände beginnt an der äußeren Bankettkante (`rows_edge` + `shoulder_w`) und malt dort 1,2 m Kies;
   mit `builders/road.gd` statt der Debug-Straße die Fuge Bankett → Kies im Bild prüfen (Stadt: Gehwege).
5. **AS1b**: Modelle für Birke, Büsche, Strohballen … ersetzen die Vertretungen ohne Code-Änderung über das Manifest;
   mit Varianten oder zweiflächigen gespiegelten Modellen steigen die Zeichenaufrufe (Abschnitt 9, Punkt 2).
6. **Projektleitung**: `bend_cover` füllen, sobald Bodenbewuchs ≤ 0,5 m existiert; die kahlen Kurveninnenseiten
   (T2, T4) mit den Bildern von Zwischenstand 2 entscheiden.
7. **QA1**: neue Render-Prüfung `check_props_render.gd`; die Geländesperre an den Anteilen von Fernboden und Kragen
   lesen, nicht nur am Magenta.
8. **Leistung**: Die Felder kosten im Geländeshader zweimal eine Schleife über neun Zellen je Bildpunkt (nahes Bild
   und Fernboden-Ton), im Fernboden einmal – auf einer Grafikkarte vernachlässigbar (abgeleitet), im Leistungstest
   auf dem Deck nachsehen.
