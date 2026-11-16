# KRITIK-5a1 – Unabhängige Kunstkritik von AS5a1 (Stadthäuser german, german_old, hanse)

- Gegenstand: Zweig `worktree-wf_db8ba6cd-508-1` (gesichert als `origin/wip/v080-as5a1`), Stand **63544b6**, nur
  gelesen. Geprüft in einer Kopie im Arbeitsordner (`m1/KRITIK-5a1/tree`). Keine Commits, kein Zweig, keine Datei des
  AS5a1-Arbeitsbaums geändert.
- Modelle (elf, nach Häufigkeit auf Kiel – Nürnberg): Einfamilienhaus `city_german_house` (282), Fachwerkzeile
  `city_german_old_fachwerk` (99), Fachwerk mit Turm `city_german_old_fachwerk_b` (95), Mietshaus
  `city_german_mietshaus` (77), Gründerzeithaus `city_german_gruenderzeit` (72), Giebelzeile `city_hanse_gabled` (54),
  Barock `city_german_old_barock` (32), Speicher `city_hanse_speicher` (10), Büroturm `city_german_office` (7), Kontor
  `city_hanse_kontor` (4), Kran `city_hanse_crane` (3).
- **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, Spiel-Shader über `ModelFactory`, Renn-Licht des
  `EnvironmentRig` bzw. das Rennen selbst); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar
  (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Stadthäuser sichtbar feiner als die Arcade-Bilder und gut genug, um stundenlang durch die Städte zu
fahren?**

- **Feiner: ja – bei neun von elf Modellen deutlich, bei Büroturm und Kran gleich.** Von 10 bis 100 m haben die Häuser
  echte Tiefe: Fenster in Laibungen mit Rahmen, Sprossen und Sohlbänken, Fachwerk als Hölzer vor der Ausfachung,
  Vorkragungen mit Balkenköpfen, Gesimse, Pilaster, Fensterverdachungen, Quaderecken, Balkone mit ausgeschnittenen
  Gittern und Schlagschatten, Rundbogentüren mit Flügeln, Schaufenster mit Regalen und Waren hinter dem Glas (Bilder
  10–12, 20). Im Rennen in Hamburg, Nürnberg und Hannover sind sie schärfer und plastischer als Arcade, dessen Sprites
  aus der Nähe verschwimmen (Bilder 02–04). Umriss, Geschosse, Dächer, Farben und Fensterraster decken sich mit dem
  Sprite (IoU 0,987–0,999, Kran 0,922, gemessen); Budgets, Zeichenaufrufe und Bytes sind eingehalten (größtes Modell
  9 865 Dreiecke, 2 Aufrufe je Stufe, Archiv 0,79 MB Netze + 5,25 MB Texturen, gemessen). Nachts leuchten dieselben Fenster warm und unregelmäßig wie in Arcade, Schaufenster mit Auslage, bei Tag leuchtet nichts (Bilder 06, 21; Anteil beleuchteter Fensterpixel in Hamburg 0,6–1,0 × Arcade, gemessen).
- **Stundenlang: noch nicht ohne Nacharbeit.** Was in den Innenstädten in Augenhöhe am meisten vorbeizieht, sind die
  Straßenflanken – und die sind bei Fachwerkzeile, Turmhaus und Barock im Erdgeschoss, bei der Giebelzeile über die
  ganze Höhe **blind** (K2, Bild 30): Arcade zeigt im selben Moment Fassaden mit Türen und Fenstern. Dazu flimmern die
  Fachwerk-Hölzer bei 40–60 m 3–14× so stark wie das Sprite (K6, 1,1–1,4 % gegen 0,1 %), der Stufenwechsel bei 60 m
  tauscht beim Fachwerk ein Drittel der Pixel (K5, nachts +9 % Helligkeit), Geländer verschwinden ab ~75 m (K7), und der
  Turm-Erker hat gemalte Fenster auf einer weißen Plastik-Konsole (K4).
- **Was nicht an den Modellen liegt, aber das Stadtbild im Rennen am stärksten verschlechtert:** In Kurven nimmt der
  Requisiten-Bauer ganze Häuser weg – in München fehlt die linke Straßenseite (K1, Bild 01; FIX-M2 B-01 ist offen).
  Hamburgs Vororte sind weiß statt rosa, bis R7 die Tönung auf Modelle legt (K3, Bild 05). Sonnige helle Putzfassaden
  sind mittags 8–51 % heller als in Arcade (K8, Licht).
- **Empfehlung:** Die elf Modelle können in den nächsten Testbuild – sie sind besser als die Arcade-Bilder, die sie
  ersetzen, und nichts ist kaputt. Vor dem Testbuild sollte die Leitung K1 entscheiden (sonst sieht der Nutzer
  halbleere Straßen). Nacharbeit AS5a-N in dieser Reihenfolge: K2 (Flankenöffnungen über `close3d`), K6 und K5
  (Hölzer, lod1), K4, K7, K10. R7: Tönung und Überblenden; R4: Sonne gegen Arcade und Lichtrampe der Dämmerung am Kontor (K9).

| Modell (Platzierungen K–N) | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Einfamilienhaus (282) | **feiner** | ja (Tönung fehlt, K3) | Rahmen + Sprossen, Rinnen, Fallrohre, Garagentor, Wandlampe nachts, 60 px/m zur Straße | Gartenkugeln, lod1 fast so teuer wie lod0 (K10) |
| Fachwerkzeile (99) | **feiner** | ja, mit K2/K5/K6 | Hölzer als Glieder, Vorkragungen, Blumenkästen, Rundbogentür | blinder Sandsteinsockel zur Straße, Stufenwechsel 32 %, Flimmern 1,1–1,4 % |
| Fachwerk mit Turm (95) | **feiner** | ja, mit K2/K4 | Hölzer, Turm mit Schieferhelm, Torbogen mit Holzflügeln | gemalte Erkerfenster, weiße Konsole, blinder Ziegelsockel |
| Mietshaus (77) | **feiner** | ja | Balkone mit Platte, Gitter und Schlagschatten, Treppenhausfenster, Gauben | Geländer ab ~75 m weg (K7) |
| Gründerzeithaus (72) | **feiner** | ja | Quaderecke, Verdachungen, Erker, Schaufenster mit Auslage auch zur Straße | sonnig sehr hell (K8), Geländer (K7) |
| Giebelzeile (54) | **feiner** (Front) | ja, mit K2 | Treppen-, Volutengiebel als Geometrie, Rundbogenfenster, Ziegelverband | Flanke 16 × 17 m ohne Öffnung, nachts dunkle Platte; flimmert in lod1 |
| Barock (32) | **feiner** | ja, mit K2 | Pilaster, Gesimse, Fensterverdachungen, Volutengiebel | blinder Rustika-Sockel zur Straße |
| Speicher (10) | **feiner** | ja | Granitsockel, Gesimsbänder, Ladeluken, Eckturm | – |
| Büroturm (7) | gleich | ja | Vorhangfassade mit Pfosten, Flugbefeuerung | Foyer nachts weiße Tafeln (K10) |
| Kontor (4) | **feiner** | ja | Pfeilerfassade, Staffelgeschosse, Schaufenster mit Auslage | Stufenwechsel 25 %, oben 24 px/m bei Maßstab 1,2 |
| Kran (3) | gleich | ja | Gitterausleger, Kabine, Seil, Rotlicht | flache rote Kästen (nie nah) |

## 2. Wie geprüft wurde

- **Gegenstand.** Zweig `worktree-wf_db8ba6cd-508-1` (gesichert als `origin/wip/v080-as5a1`), Stand **63544b6**, nur
  gelesen. Gerendert und gemessen in einer Kopie im Arbeitsordner (`m1/KRITIK-5a1/tree`: Arbeitsbaum ohne `.git`,
  `build/` und `_cache3d`, mit seinem Import-Cache; Import geprüft, 0 Fehler). Keine Commits, kein Zweig, keine Datei
  des AS5a1-Arbeitsbaums geändert. Alle Läufe mit `nice -n 19`, immer nur ein schwerer Lauf, absolutes
  `XDG_DATA_HOME` und eigener Mesa-Cache im Arbeitsordner.
- **Messgrundlage.** **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig`); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht
  messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.
- **Lage wie im Rennen.** Eigene Zählung der Etappen des Rennens Kiel – Nürnberg und München (`census_k5.gd`,
  `logs/census_k5.log`): Stadthäuser stehen **nur an den Ankünften** (Hamburg km 75–95, Hannover 130–150, Kassel
  145–165, Würzburg 190–210, Nürnberg 90–110, München 150–170 von Nürnberg aus); an den Abfahrten stellt die
  Strecke keine `props/city_*` auf – „Abfahrt“ ist deshalb in diesem Rennen nicht prüfbar. In den Prüfszenen steht
  jedes Modell wie vom Requisiten-Bauer verankert: Anker = Kante + `extent_l` × Maßstab (`edge_anchor_x`), die Kante aus
  der Zählung (Innenstadt 6,6–10 m, Vorort 12–19 m), links gespiegelt.
- **Werkzeuge** (nur in der Kopie benutzt, aufbewahrt unter `m1/KRITIK-5a1/tools_kritik/` – zum Wiederverwenden nach `tools/kritik/` einer Kopie legen; die Kopie selbst ist gelöscht): `k4_scene.gd` der
  KRITIK-4 (`dist2` Spielkamera bei 10/30/100/250 m mit dem Arcade-Platzhalter derselben Lage darunter, `close`
  Nahansichten, `outline2` Umriss in der Sprite-Kamera – Blickwinkel der Stadt-Sprites −20°/−24° aus
  `props_cities._b()` nachgetragen), `prop_scene --mode=lods` (Stufenwechsel), `my_scene --mode=sparkcam` (AS4R:
  Viertelpixel-Kameraschritte, Anteil kippender Pixel), `tint_scene.gd` (AS5a1), neu: `k5_scene.gd --mode=drive`
  (Spielkamera fährt mit 50 km/h durch eine Straße aus Stadthäusern beidseits, 60 Bilder/s, Stufenwahl mit der
  Hysterese des Requisiten-Bauers, wahlweise als Arcade-Platzhalter), `texel_k5.gd` (Texeldichte je Wandrichtung und
  Höhenband aus UV- und Weltfläche der gebackenen Netze), `py/swappop.py` (Stufenwechsel im Film), `py/bldlum.py`
  und `py/boxlum.py` (Helligkeit Modell gegen Sprite bzw. Arcade gegen Modern).
- **Rennen.** `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand, Seed 11, Limousine, Autopilot,
  fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start) an den Stadteinfahrten Hamburg (Stadtrand und
  Innenstadt), Hannover, Nürnberg und München mittags („Hoch“), Hamburg und Nürnberg um 22 Uhr („Hoch“), Hannover zur
  Dämmerung (19:30, „Mittel“). Ein Modern-Lauf mit zwei Bildern brauchte auf der geteilten Maschine 11–21 min
  (gemessen); Kassel und Würzburg habe ich deshalb nicht gefahren (gleiche Modelle wie Hannover bzw. Nürnberg).

## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS5a-N** = Nacharbeit der Modelle (`ce3d/cities3d.py`, Hooks in `cesprites/props_cities.py`, Katalog),
**R2/Leitung** = Requisiten-Bauer und Korridorregel (`builders/props.gd`, D14/F7, A-3/A-10), **R4** = Licht, Nacht,
Wetter, **R7** = Tönung der Modell-Instanzen, LOD-Feinabstimmung, **Import** = `.import`-Einstellungen bzw. Bake der
Mip-Kette. Bilder in diesem Ordner (Nummern vorn im Dateinamen).

### K1 – hoch (Rennen, R2/Leitung) – in Kurven fehlen ganze Häuserzeilen

**Wo:** München (Nürnberg – München km 161,7–162,6): links stehen in Arcade das rosa Barockhaus, das Wiener
Zinshaus und ein gelbes Haus – Modern zeigt dort leere Sandfläche, in beiden Bildern (2 s und 4 s, Bild 01).
Nürnberg (Würzburg – Nürnberg km 103,6): das Fachwerkhaus mit Turm rechts dicht an der Straße fehlt (Bild 03).
AS5a1 sah dasselbe in Hannover (Mietshaus links bei km 142,4).
**Was:** Es fehlen Modelle *und* Arcade-Platzhalter (das Wiener Zinshaus hat kein Modell) – es ist also nicht das
Modell, sondern die Auslassregel des Requisiten-Bauers (`drop_reason`: Kurvenkorridor F7 in strenger Lesart oder
Geländeband; welche der beiden, habe ich nicht gemessen). FIX-M2 hat B-01 **nicht** behoben (Leitungsentscheidung
offen, `deliver/FIX-M2/bericht.md` B-01); nach RINT-M2 bleibt es also so. In der Stadt (Tempo 50) ist das der
größte sichtbare Unterschied zu Arcade: eine Straßenseite ohne Häuser.
**Fix (Leitung, R2):** für Platzierungen in Stadtabschnitten (`seg.city`, Tempolimit ≤ 50) die Korridorsehne aus F2 bei
der erlaubten Geschwindigkeit rechnen (Anhalteweg bei 50 km/h ≈ 25–30 m, gerechnet) oder Gebäude einer Stadtregel aus
dem Korridor nehmen, wie Wahrzeichen. Nachweis: dieselben drei Stellen als A/B, F2-Prüfung (`modern_sight`).

### K2 – hoch, häufig (Modell, AS5a-N) – die Flanken zur Fahrbahn sind im Erdgeschoss blind, die Giebelzeile ganz

**Wo:** Fachwerkzeile (99 Platzierungen), Fachwerk mit Turm (95), Barock (32): Erdgeschoss der Straßenflanke ohne
Tür, Fenster oder Schaufenster (Sandstein-, Ziegel- bzw. Rustika-Sockel über die ganze Haustiefe); Giebelzeile (54):
die ganze Flanke, 16 m tief und bis 17 m hoch, ohne Öffnung, Sockel oder Gesims (Bild 30).
**Was:** Das ist, was in den Innenstädten von Würzburg, Nürnberg, Fulda, München, Hamburg und Bremen in 5–15 m
Abstand in Augenhöhe vorbeizieht (Prüfstraße Bild 30 oben links, Rennen Nürnberg oben rechts). Die Generatoren
zeichnen Fenster nur auf `front` (Giebelzeile: 17 Raster front, 0 left) bzw. nur in den Obergeschossen der Flanke;
im Sprite (Blick −20°) ist die Flanke ein schmaler Streifen, im echten 3D die größte Fläche beim Vorbeifahren.
Arcade zeigt im selben Moment die Fassade mit Türen und Fenstern (Billboard). Nachts ist die Flanke der Giebelzeile
eine dunkle Platte, wo Arcade beleuchtete Fenster zeigt. Texturen und Dichte sind in Ordnung (41–47 px/m), es fehlt
die Tiefe, die die Qualitätsvorgabe verlangt („nie ein flach gefärbter Kasten“).
**Fix (AS5a-N):** wie der Rückgiebel (`close3d`, Sprite unverändert, Geometrie-Gate): mit `close3d=True` bekommt die
Außenflanke (`left`) im Erdgeschoss je Haus eine Tür mit Stufe und zwei Fenster bzw. Schaufenster im Rhythmus der
Front (Fachwerk: Rechteckfenster mit Sandsteingewände und Rundbogentür; Barock: Rundbogenfenster in der Rustika wie
die Front; Giebelzeile: zusätzlich Segmentbogenfenster je Geschoss, Achsen 2,4 m, Granitsockel 0,6 m, zwei Maueranker
je Geschoss). Die beleuchteten Fenster nehmen den Lichtweg der Scheiben (Zufallszahlen von `wallmat`), nachts so
unregelmäßig wie die Front. Nachweis: Prüfstraße (`k5_scene --mode=drive`) bei 12 und 22 Uhr, IoU im Sprite-Blick
unverändert ≥ 0,98.

### K3 – mittel bis hoch (R7, kein Modellfehler) – Hamburgs Vororte weiß statt rosa

**Wo:** Kiel – Hamburg km 75–87 und die anderen hanseatischen Vororte (Bremen, Rostock, Kiel): 51 der 282
Einfamilienhäuser tragen in Arcade `#e8b8a4` (Bild 05: Arcade rosa Häuserzeilen, Modern weiß).
**Was:** Der Renderer gibt die Tönung nur an Platzhalter weiter. Die Modelle sind dafür bereit: Atlas × Tönung trifft
das getönte Sprite im Farbton (Bild 27; Mietshaus × `#e0b09c` etwas gesättigter als das Sprite × Tönung).
**Fix (R7):** Tönung als Instanzfarbe auf die gebackene Albedo (`baked`, nicht `vpbr`) – wie AS5a1 vorschlägt.

### K4 – mittel (Modell, AS5a-N) – Erker des Fachwerkhauses mit Turm: gemalte Fenster, Konsole wie weißes Plastik

**Wo:** jedes Fachwerkhaus mit Turm (95) – der Erker sitzt auf der Straßenseite (Bild 31; Bild 30 oben links, rechter Rand).
**Was:** Erkerfenster sind dunkelblaue bzw. nachts gelbe Rechtecke ohne Laibung, Rahmen, Sprossen, direkt neben
geschnittenen Fenstern mit Rahmen; die Kegelkonsole ist hellgrau-weiß und glatt verlaufend, nachts heller als die
Wand. AS5a1 kannte beides und ließ es (Runde 5).
**Fix (AS5a-N):** die Erkerfacetten ins Wand-Log aufnehmen, damit der Öffnungs-Pfad sie schneidet (Rahmen 6 cm, eine
Sprosse, Scheibe zurückgesetzt), sonst ein eigener kleiner Schnitt je Facette; Konsole mit der Putzfarbe × 0,85,
AO-Bake statt glatter Schattierung, `light_mul` 0,35 für ihr Material.

### K5 – mittel (Modell, AS5a-N; Überblenden R7) – Stufenwechsel bei 60 m: Fachwerk und Kontor wechseln ein Viertel bis ein Drittel der Pixel

**Gemessen** (`prop_scene --mode=lods`, „Mittel“, Anteil der Pixel mit Σ|ΔRGB| > 0,06 / Helligkeit, Bild 25):
Fachwerkzeile **32,0 %** (+4,7 %; nachts 23,8 %, **+9,0 %**), Kontor 24,7 % (nachts 18,1 %, **+9,9 %**), Barock 18,5 %,
Gründerzeit 18,0 %, Speicher 17,4 %, Fachwerk mit Turm 16,8 %, Giebelzeile 14,9 %, Mietshaus 14,2 %, Einfamilienhaus
11,1 %, Büroturm 3,3 %, Kran 2,1 % – dieselben Zahlen wie AS5a1. Zum Vergleich: die AS4-Häuser lagen bei 3–11 %
(KRITIK-4); ein Arcade-Platzhalter wechselt nie. Was wechselt: echte Hölzer gegen gemaltes Fachwerk, Laibungsschatten,
Sprossen, Türflügel; nachts wird lod1 deutlich heller (Scheiben ohne Laibung).
**Im Fahrfilm** (Prüfstraße Altstadt, 50 km/h, Bild 40, `py/swappop.py`): In einer dichten Zeile steht das Haus, das bei
60 m wechselt, meist hinter dem nächsten Haus derselben Seite; im Bildausschnitt des wechselnden Hauses war der Anteil
„neu geänderter“ Pixel im Wechselbild 7,7–16,2 % gegen 7,1–16,0 % in den Bildern davor und danach (gemessen) – in
Bewegung geht der Wechsel im Bewegungsrauschen weitgehend unter. Sichtbar bleibt er, wo das Haus frei steht (Platz,
Kurve, Straßenende) und nachts (+9–10 % Helligkeit). Gefolgert: mittel, nicht hoch.
**Fix:** (AS5a-N) lod1-Atlas der Fachwerkhäuser aus dem gerenderten lod0 backen (Hölzer mit Schatten und AO statt des
flachen Generator-Fachwerks; das hebt auch die +4,7 %), nachts in lod1 die Scheiben um die fehlende Laibung abdunkeln
(`light_mul` lod1 ≈ 0,9); (R7) Dither-Überblenden 0,3–0,5 s wie bei Bäumen und Fahrzeugen. Nachweis: `--mode=lods`
≤ 15 % und Helligkeit ±3 % bei 12 und 22 Uhr.

### K6 – mittel (Modell, AS5a-N) – Flimmern in Bewegung

**Gemessen** (`my_scene --mode=sparkcam`, Kamera in Viertelpixel-Schritten seitlich, Anteil der Pixel, die je Schritt um
> 0,2 kippen; „Mittel“, 12 Uhr, 20 m seitlich; Teilmenge, weil ein Lauf über alle elf auf der geteilten Maschine über
40 min brauchte):

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
| Fachwerkzeile | **1,1 %** | **1,4 %** | 0,6 % | 1,1 % | 0,1 / 0,1 / 0,2 / 0,4 % |
| Gründerzeithaus | 0,6 % | 0,5 % | 0,3 % | 0,4 % | 0,1 / 0,1 / 0,2 / 0,4 % |
| Giebelzeile | 0,5 % | 0,7 % | **1,1 %** | **1,3 %** | 0,1 / 0,1 / 0,3 / 0,4 % |

Dieselbe Größenordnung wie bei AS5a1 (Fachwerkzeile 1,1–1,3 %). Das Maß bestraft auch gewollte Schärfe (das Sprite
ist weichgezeichnet); zum Vergleich: die AS4-Häuser lagen bei 0,0–0,9 % gegen 0,1–1,7 % ihrer Sprites (KRITIK-4),
Block B mit 1,0 % galt bei AS4R als Schwäche. Ursachen: (a) die Hölzer der Fachwerkhäuser sind bei 40–60 m 1–2 Pixel
breite, dunkle Glieder vor weißer Ausfachung (lod0 – auf „Hoch“ sogar bis 120 m); (b) die Giebelzeile flimmert in
**lod1** (gemalter Atlas) bei 100–150 m – Ziegelverband, Treppengiebel-Kanten und Sprossen der Fenster im Atlas
ohne Vorfilterung der kleinen Mips. Im Fahrfilm (Bild 40/42, 50 km/h) sieht man an den fernen Fachwerkzeilen ein
leichtes Kriseln der Hölzer (angesehen); die Wirkung auf einem echten Bildschirm mit 60 Bildern/s ist gefolgert.
**Fix (AS5a-N):** (1) Fachwerk-Hölzer in lod0 nur bis ~35 m als Geometrie (eigene Stufe „lod0n“ oder Hölzer in
lod1 überblenden), darüber das gebackene Fachwerk; die gebackenen Hölzer im Atlas 10–15 % heller als die echten
(Kontrast der dünnen Linien senken), (2) Mips der Atlanten mit einem weicheren Filter (Lanczos/Kaiser statt Box) und
ab Mip 2 einem leichten Weichzeichner für die Ziegel- und Sprossenmuster vorberechnen, (3) Giebelzeile:
Ziegelfugen im Atlas eine Stufe kontrastärmer. Nachweis: `sparkcam` ≤ 0,6 % bei 40–150 m.

### K7 – mittel (Modell + Import) – Geländer (`baked_cutout`) verdichten sich bis ~40 m und lösen sich ab ~75 m auf

**Wo:** Balkone von Mietshaus (77) und Gründerzeithaus (72) – die ersten Nutzer der Klasse `baked_cutout`.
**Gemessen** (`mipcov.py` von AS5a1 auf den gelieferten Atlanten nachgerechnet): Deckung des Alpha-Tests gegen Mip 0:
Mietshaus mip1–3 1,11 / 1,20 / 1,40, mip4 **0,29**; Gründerzeit 1,12 / 1,19 / 1,32, mip4 **0,59**. Bei 150 Texeln je
Meter (`CUT_PPM`) und 711 px Brennweite gilt Mip k ab etwa 4,7 m × 2^k (gerechnet): Mip 3 ab 38 m, Mip 4 ab 76 m.
Das Geländer wird zwischen 20 und 60 m dichter und dunkler und ist ab etwa 75 m fast weg (bei 100 m ein dünner
schwarzer Strich, Bild 10 german). Kein Saum, kein Aufblitzen in den Standbildern (angesehen) – die Klasse
funktioniert, die Mip-Kette nicht; die Aufgabe „Deckung in kleinen Mips erhalten“ ist nicht erfüllt.
**Fix:** im Bake für die Ausschneide-Inseln eine eigene Mip-Kette schreiben, deren Alpha je Stufe so skaliert ist,
dass der Anteil ≥ 0,5 dem von Mip 0 gleicht (coverage-preserving mips; als `.dds`/vorberechnete Mips oder im
`bake.py`-Schritt vor dem Import), oder Geländer ab lod1 als gemaltes halbdeckendes Band im deckenden Atlas (wie das
Sprite); Renderer-Variante: Alpha-to-Coverage bei MSAA (R7). Nachweis: `mipcov.py` 0,9–1,1 für mip1–4.

### K8 – niedrig bis mittel (Licht R4; Modell kann mithelfen) – sonnige Putzfassaden viel heller als Arcade, schattige dunkler

**Gemessen** (`py/boxlum.py`, gleiche Bildausschnitte Arcade | Modern, 12 Uhr, Hoch): sonnige Straßenflanken rechts
Hamburg Speicher +8 %, Nürnberg Barock +18 %, Hannover Gründerzeit +13 % bzw. +51 %, München Gründerzeit +35 %
(Median-Luma 195 gegen 137, die hellsten 10 % bei 236–240 von 255); schattige Flanken links −20 bis −39 %. Die
AS4-Ladenfront (zur Kamera) ist in beiden Modi gleich hell. In Prüfszene und Kontaktbogen wirken Gründerzeit und
Barock bei 100–250 m blasser als ihr Sprite (Median-Luma +27–31 %).
**Bewertung:** Licht und Schatten sind Absicht des echten 3D; aber helle Putzfassaden laufen in der Mittagssonne fast
ins Weiß und verlieren Zeichnung. **Fix:** zuerst R4 (Sonnenstärke/Belichtung für `baked` gegen Arcade abgleichen,
wie AS4R es für die Kirche getan hat); bleibt es, `albedo_mul` 0,88 für die hellen Putze (Gründerzeit, Barock,
Mietshaus) in AS5a-N. Nachweis: Median-Luma der Sonnenseite ≤ +15 % gegen Arcade.

### K9 – niedrig (Licht R4) – Dämmerung: Fensterlicht in Hannover vergleichbar, der Prüfszenen-Platzhalter taugt dafür nicht

**Angesehen** (Bild 08, Hannover km 143,9, 19:30, „Mittel“): In beiden Modi leuchten einzelne Fenster warm, in Modern
dazu die Schaufenster mit Auslage; die Zahl der beleuchteten Fenster ist ähnlich. Eine Pixelzählung taugt hier nicht
(in Arcade färbt das Abendlicht die ganze Fassade gelb, `py/litpx.py` zählt sie mit). Den Befund von AS5a1 (Hamburg,
19:30: am Kontor in Modern deutlich weniger Fenster als in Arcade) habe ich aus Zeitgründen nicht nachgestellt. In der
Prüfszene (`prop_scene --look=race`) zeigt der Arcade-Platzhalter zur Dämmerung und nachts **gar kein** Fensterlicht,
das Modell dagegen schon – Licht ist deshalb nur im Rennen zu beurteilen (Hinweis für die nächste Kritik; die
Kontaktbögen 10–12 „daemmerung“/„nacht“ nicht als Vergleich lesen). **Fix:** keiner an den Modellen; R4 prüft die
Lichtrampe 19–21 Uhr an Kontor und Speicher gegen Arcade.

### K10 – niedrig (Modell, AS5a-N) – kleinere Mängel

- **Büroturm** (7): Foyer nachts eine Reihe gleichmäßig hellgrauer Tafeln ohne Inhalt, Bürofenster grauweiße
  Rechtecke (Bild 21 german). Fix: Foyer wie ein Schaufenster mit `shop_depth` und Theke, `shop_light` 0,35.
- **Einfamilienhaus** (282, das häufigste Modell): lod1 hat 85 % der Dreiecke von lod0 (2 526 / 2 962) – Hecken und
  Gartenbaum bleiben voll; aus der Nähe sind sie klumpige facettierte Kugeln wie im Generator. Garagenfront zur
  Anfahrt nur 16 px/m (5 m²). Fix: in lod1 Hecken als Boxen mit gebackener Seite, Baum als zwei gekreuzte Karten
  (oder ein AS3-Baum), Ziel ≤ 900 Dreiecke; Garagenfront in den Chart der Straßenwand.
- **Texeldichte im Spiel bei großem Maßstab:** Kontor oben 24 px/m bei Maßstab 1,2 (unter 26 px/m), Erdgeschoss
  Kontor 34, Giebelzeile 36, Fachwerkzeile 38 px/m (unter 40; gerechnet aus gemessenem Modellmaß). Fix: `floors.upper`
  des Kontors 0,8 statt 0,7, Innenstadt-Erdgeschosse auf 48 px/m (ein Viertel mehr Texel nur in diesem Band).
- **Kran** (3): aus der Nähe flache rote Kästen ohne Kante oder Niet – wie der Generator; steht 53–83 m vom Rand, also
  nie nah. Kein Handlungsbedarf.

## 4. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit 50 km/h (der Autopilot beschleunigt auf
80–115 km/h), Bilder 2 s und 4 s nach dem Start; „Hoch“ wenn nicht anders gesagt. 0 Skriptfehler in allen
Protokollen (gemessen). Positionen aus der eigenen Zählung.

| Bild | Ort | Zeit | Was man sieht (angesehen; Zahlen gemessen) |
|---|---|---|---|
| 02, 09 | Hamburg Innenstadt (Kiel – Hamburg km 88,2) | 12 Uhr | Speicher mit Granitsockel, Turm, grünen Ladeluken, Giebelzeilen beidseits: in Modern scharf, mit Tiefe und richtiger Perspektive, Arcade weich. Die blinden Flanken der Giebelzeilen sieht man in beiden Modi als Streifen (K2). Sonnenseite +8 %, Schattenseite −20 % gegen Arcade |
| 03, 09 | Nürnberg Altstadt (Würzburg – Nürnberg km 102,7) | 12 Uhr | Barock mit Pilastern und Fensterverdachungen, Fachwerkzeilen mit echten Hölzern und Blumenkästen – klar feiner. Bei 4 s fehlt rechts das Fachwerkhaus mit Turm, das Arcade dicht an der Straße zeigt (K1); links zieht die blinde Sandstein-Sockelwand der Fachwerkzeile vorbei (K2) |
| 04, 09 | Hannover (Hamburg – Hannover km 143,9) | 12 Uhr | Gründerzeithaus rechts mit Quaderecke und Schaufenstern mit Auslage direkt am Gehweg, Mietshäuser links: der deutlichste Gewinn gegen Arcade, dessen Sprites aus der Nähe verschwimmen. Sonnenseite +13 % / +51 % (K8) |
| 01, 09 | München (Nürnberg – München km 161,7) | 12 Uhr | **links keine Häuser** (Barock-Modell und Platzhalter fehlen, K1); rechts Gründerzeithaus ungetönt und deutlich heller als Arcade (+35 %, K3/K8) |
| 05, 09 | Hamburg Vorort (Kiel – Hamburg km 81,2) | 12 Uhr | Einfamilienhäuser in Modern **weiß**, in Arcade rosa (K3); sonst schärfer, Gärten wie das Sprite; rechts bei 4 s eine blinde rote Giebelflanke (K2) |
| 06 | Hamburg Innenstadt (km 88,2) | 22 Uhr | Fenster warm und unregelmäßig wie in Arcade, etwas oranger; Laden mit beleuchteter Auslage; Anteil beleuchteter Fensterpixel Modern/Arcade rechts 3,7/6,7 % (2 s) und 5,2/5,3 % (4 s), links 1,7/2,1 % und 2,1/2,5 % (gemessen, `py/litpx.py`). Bei Tag wie bei Nacht leuchtet nichts, was nicht soll (angesehen) |
| 07 | Nürnberg Altstadt (km 102,7) | 22 Uhr | rechts 4,3/4,6 % (2 s), aber 2,7/5,9 % bei 4 s – dort fehlt das Turmhaus (K1); links 0,5/0,9 % und 1,2/3,1 %: Arcade zeigt beleuchtete Fassaden, Modern die Flanke mit dunklem Sockel und wenigen Fenstern im Obergeschoss (K2). Ansonsten Hölzer im Mondlicht lesbar, Straße mit Laternenlicht – stimmungsvoller als Arcade |

**Nicht gelaufen** (Zeit: ein Modern-Lauf brauchte 11–21 min auf der geteilten Maschine, gemessen): Kassel und
Würzburg mittags (gleiche Modelle wie Hannover bzw. Nürnberg; Würzburg mittags hat AS5a1 geliefert), „Mittel“ außer
zur Dämmerung, und ein Rennclip: an seiner Stelle der Fahrfilm durch die Prüfstraße (Bild 40), der dieselben Modelle
mit der Stufenwahl des Requisiten-Bauers bei 50 km/h zeigt, aber ohne Straße, Gehweg und Verkehr.

## 5. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)

### 5.1 Prüfer, Budgets, Zeichenaufrufe, Bytes (auf der Kopie, gemessen)

`python3 tools/blender/validate_models.py --report` → `CHECK models OK` (logs/validate.log). Bytes mit derselben
Rechnung wie `tools/pck_report.py` (deflate -9 je Datei der `.res`, `model.json` und importierten `.ctex`;
`py/share.py`, logs/share.log):

| Modell | Platzierungen K–N | Dreiecke lod0 / lod1 | Aufrufe je Stufe | Atlas | Netze B (Archiv) | Texturen PCK (Archiv) |
|---|---|---|---|---|---|---|
| `city_german_house` | 282 | 2 962 / 2 526 | 2 / 2 | 1024² PNG | 97 896 (96 769) | 873 944 (253 529) |
| `city_german_old_fachwerk` | 99 | 6 913 / 1 041 | 2 / 2 | 2048×1024 | 102 857 (99 804) | 1 747 768 (506 772) |
| `city_german_old_fachwerk_b` | 95 | 3 332 / 978 | 2 / 2 | 2048×1024 | 57 697 (55 938) | 1 747 768 (401 478) |
| `city_german_mietshaus` | 77 | 2 176 / 506 | 2 / 2 | 2048×1024 BC3 | 34 819 (33 586) | 3 145 888 (483 204) |
| `city_german_gruenderzeit` | 72 | 4 410 / 2 394 | 2 / 2 | 2048×1024 BC3 | 78 280 (76 412) | 3 145 888 (551 904) |
| `city_hanse_gabled` | 54 | 3 712 / 1 233 | 2 / 2 | 2048×1024 | 69 663 (68 486) | 1 747 768 (664 333) |
| `city_german_old_barock` | 32 | 4 539 / 2 385 | 2 / 2 | 2048×1024 | 90 772 (88 684) | 1 747 768 (462 191) |
| `city_hanse_speicher` | 10 | 8 950 / 1 283 | 2 / 2 | 2048×1024 | 117 875 (114 183) | 1 747 768 (739 759) |
| `city_german_office` | 7 | 427 / 203 | 2 / 2 | 2048×1024 | 11 980 (11 020) | 1 747 768 (360 457) |
| `city_hanse_kontor` | 4 | 9 865 / 749 | 2 / 2 | 2048×1024 | 113 220 (108 978) | 1 747 768 (714 886) |
| `city_hanse_crane` | 3 | 1 260 / 1 052 | 2 / 2 | 1024² PNG | 41 091 (39 384) | 873 944 (114 492) |
| **Summe** | 735 | | | | **0,82 MB (Archiv 0,79 MB)** | **20,27 MB (Archiv 5,25 MB)** |

Alle elf ≤ 10 000 Dreiecke lod0 (größtes: Kontor 9 865) und ≤ 2 Aufrufe je Stufe (Klassen `baked`/`baked_cutout` +
`vpbr`); Archivanteil 0,79 / 5,25 MB unter dem Anteil der Charge (3 / 7 MB). Platzierungen: Zählung von AS5a1 auf
beiden Wegen Kiel – Nürnberg, von mir für die Etappen der Hauptroute nachgezählt (gleiche Größenordnung). Die
Backzeiten (108–1 462 s je Modell, AS5a1-Tabelle) habe ich nicht nachgemessen (kein Neuexport in einer Kritik).
Auffällig: **`city_german_house` lod1 hat 85 % der Dreiecke von lod0** (2 526 / 2 962) – Garten (Hecken, Baum) bleibt
in lod1 fast voll; das häufigste Modell (282) spart an seiner Fernstufe kaum etwas.

### 5.2 Texeldichte der Außenwände (`texel_k5.gd`, lod0, nur die äußersten 1,2 m je Richtung, Modellmaß, gemessen)

px/m = √(UV-Fläche × Atlasgröße / Weltfläche), flächengewichtet; „unten“ = Mitte des Dreiecks < 7,5 m (Erdgeschoss
und 1. OG), „oben“ darüber; Anfahrt = Fassade zur anfahrenden Kamera (+Z), Straße = Flanke zur Fahrbahn (−X).
In Klammern das Minimum im Spiel (geteilt durch den größten Maßstab der Zählung).

| Modell | Anfahrt unten | Anfahrt oben | Straße unten | Straße oben | Maßstab max |
|---|---|---|---|---|---|
| Mietshaus | 54,8 (48) | 55,8 | 52,9 (46) | 52,9 | 1,14 |
| Gründerzeithaus | 53,2 (46) | 43,4 (38) | 54,4 (47) | 41,1 (36) | 1,15 |
| Fachwerkzeile | 41,8 (38) | 35,0 (32) | 41,8 (38) | 35,0 | 1,10 |
| Fachwerk mit Turm | 41,9 (38) | 40,3 | 41,1 (37) | 40,2 | 1,10 |
| Barock | 46,4 (41) | 37,4 (33) | 47,2 (41) | 37,8 | 1,14 |
| Giebelzeile | 41,4 (**36**) | 33,5 (29) | 41,9 (37) | 33,5 | 1,14 |
| Speicher | 42,6 (39) | 30,4 (28) | – (Turm vorn) | 28,7 | 1,09 |
| Kontor | 41,2 (**34**) | 29,0 (**24**) | 41,2 (34) | 29,0 (**24**) | 1,20 |
| Büroturm | 20,8 (im Spiel ×2–2,7: 42–56) | 21,2 | 21,2 | 21,2 | 0,37–0,50 |
| Einfamilienhaus | 16,3 (Garagenfront, 5 m²) | – | 60,0 | – | 1,10 |

Vertrag ≥ 26 px/m an Straßenwänden: im Modellmaß erfüllt (außer der kleinen Garagenfront des Einfamilienhauses mit 16 px/m
und dem Büroturm, der im Spiel mit Maßstab 0,37–0,5 auf 42–56 px/m kommt). Im Spiel unterschreitet nur der **Kontor**
bei Maßstab 1,2 oben mit 24 px/m die 26 px/m. Die Vorgabe ≥ 40 px/m für Erdgeschoss und 1. OG der Innenstadthäuser
erfüllen im Modellmaß alle, im Spiel bei großem Maßstab nicht mehr: Kontor 34, Giebelzeile 36–37, Fachwerkzeile 38,
Speicher 39 px/m (gerechnet aus gemessenem Modellmaß). Aus 5–10 m (711 px Brennweite: 70–140 Bildpunkte je Meter) wird
jede dieser Wände 1,5–3,5-fach vergrößert – weich, aber gleichmäßig; Wände, die nur Spiegeltexel der Gegenseite
tragen, sind in diesen Zahlen enthalten (gleiche Dichte).

### 5.3 Stufenwechsel und Fernbild (`prop_scene --mode=lods`, „Mittel“, Anker 20 m seitlich, gemessen)

Anteil der Pixel mit Σ|ΔRGB| > 0,06 beim Wechsel lod0 → lod1 bei 60 m, Helligkeitssprung; dazu lod1 gegen den
Arcade-Platzhalter bei 200 m (nur als Hinweis: der Platzhalter der Prüfszene hat ein eigenes Licht, Abschnitt K8).

| Modell | 12 Uhr | 22 Uhr | Platzhalter dunkler als lod1 (200 m, 12 Uhr) |
|---|---|---|---|
| Fachwerkzeile | 32,0 %, +4,7 % | 23,8 %, +9,0 % | 18,3 % |
| Kontor | 24,7 %, −1,7 % | 18,1 %, +9,9 % | 13,1 % |
| Barock | 18,5 %, −1,7 % | 13,9 %, +1,6 % | 20,9 % |
| Gründerzeithaus | 18,0 %, −0,9 % | 14,1 %, +4,8 % | 22,5 % |
| Speicher | 17,4 %, −0,9 % | 14,0 %, +4,4 % | 10,8 % |
| Fachwerk mit Turm | 16,8 %, +2,7 % | 10,2 %, +5,7 % | 3,1 % |
| Giebelzeile | 14,9 %, −2,1 % | 10,4 %, +1,3 % | 19,6 % |
| Mietshaus | 14,2 %, −1,1 % | 10,5 %, +2,3 % | 20,1 % |
| Einfamilienhaus | 11,1 %, +2,6 % | 9,4 %, +3,9 % | −0,5 % (gleich) |
| Büroturm | 3,3 %, −0,1 % | 4,6 %, +2,1 % | 4,8 % |
| Kran | 2,1 %, −0,1 % | 2,0 %, +7,2 % | 2,6 % |

Kein Fernbild (lod1 bis zur Sichtweite) – nach Vertrag erlaubt („impostor optional“), lod1 ist billig genug (203–2 526
Dreiecke). Im Fahrfilm siehe K5.

### 5.4 Flimmern – siehe K6. 5.5 Geländer – siehe K7.

### 5.6 Umriss gegen das Sprite (`outline2`, Sprite-Kamera −20°/−24°, 6° Höhe, gemessen, Bild 26)

IoU lod0 / lod1: Einfamilienhaus 0,993 / 0,996, Mietshaus 0,995 / 0,999, Gründerzeit 0,999 / 0,999, Büroturm 0,997 /
0,997, Fachwerkzeile 0,998 / 0,999, Fachwerk mit Turm 0,999 / 0,999, Barock 0,999 / 0,999, Giebelzeile 0,998 / 0,998,
Speicher 0,999 / 0,999, Kontor 0,987 / 0,987, Kran 0,922 / 0,922 (dünne Stäbe gegen weichgezeichnete Pixel). Proportionen,
Geschosse, Dachformen, Giebel und Fensterraster stimmen – die Modelle sind kein neuer Entwurf.

## 6. Was ich von den AS5a1-Angaben bestätige – und was nicht

| AS5a1 sagt | nachgeprüft | Ergebnis |
|---|---|---|
| Prüfer grün, 11 Sets mit Modell | `validate_models.py --report` auf der Kopie | **bestätigt** (`CHECK models OK`) |
| 427–9 865 Dreiecke lod0, 2 Aufrufe je Stufe | Prüferbericht | **bestätigt** |
| Netze 0,79 MB, Texturen 5,25 MB im Archiv | `share.py` (deflate -9 wie `pck_report.py`) | **bestätigt** (identische Bytes) |
| Umriss IoU 0,987–0,999 (Kran 0,922) | `outline2` mit Blickwinkel −20°/−24° | **bestätigt** (Zahlen gleich, Bild 26) |
| Straßenwände ≥ 26 px/m, Innenstadt EG/1.OG ≥ 40 px/m (Modellmaß) | `texel_k5.gd`, nur Außenwände | **bestätigt im Modellmaß**; im Spiel bei Maßstab 1,1–1,2 nicht (Kontor 34/24, Giebelzeile 36/29 px/m, gerechnet) – AS5a1 sagte das für Kontor/Giebelzeile auch |
| Stufenwechsel 60 m: 10–32 % der Pixel | `prop_scene --mode=lods` „Mittel“ | **bestätigt** (Fachwerkzeile 32,0 %, Kontor 24,7 %, nachts +9 bis +10 % Helligkeit) |
| Geländer: Deckung mip1–3 1,1–1,4, mip4 0,29/0,59 | `mipcov.py` auf den Atlanten | **bestätigt** – aber das ist ein Mangel, kein Nachweis „funktioniert“ (K7) |
| „In den A/B-Bildern sieht Modern klar besser aus“ | eigene A/B an 5 Orten mittags + Nacht/Dämmerung | **bestätigt für die Häuser**, aber: München links und Nürnberg rechts fehlen Häuser in Modern (Renderer), Hamburgs Vororte sind weiß statt rosa (Tönung, R7) |
| Nachts dieselben Fenster wie Arcade | Rennbilder 22 Uhr | **bestätigt** in Hamburg (0,6–1,0 × die beleuchteten Fensterpixel von Arcade); in Nürnberg weniger, weil ein Haus fehlt (K1) und blinde Flanken statt Fassaden vorbeiziehen (K2) |
| Tönung als Instanzfarbe machbar | `tint_scene` (Bild 27) | **bestätigt**: Atlas × Tönung trifft das getönte Sprite im Farbton; Mietshaus × `#e0b09c` etwas gesättigter als das Sprite |
| „Flimmern 2–10× Sprite“ | `sparkcam` (Teilmenge) und Fahrfilm | **bestätigt** (Fachwerkzeile 1,1–1,4 % gegen 0,1 %, Giebelzeile lod1 1,1–1,3 %; K6) |
| Bake-Zeiten 108–1 462 s | – | nicht nachgemessen (kein Neuexport in einer Kritik) |

## 7. Vertragsfragen und Bedarf bei anderen Paketen

1. **F7-Korridor in der Stadt (D14, A-3, A-10; FIX-M2 B-01 offen).** Die strenge Lesart nimmt Gebäude einer
   Stadtregel aus Kurveninnenseiten – in München fehlt eine ganze Straßenseite, in Nürnberg und Hannover einzelne Häuser
   (K1). Bei Tempo 50 braucht F2 eine viel kürzere Sehne als 300 m. Bitte um Entscheidung der Leitung vor dem nächsten
   Testbuild: Stadtabschnitte mit Sehne aus F2 bei erlaubter Geschwindigkeit oder Gebäude der Stadtregel ausnehmen.
2. **„Die Generatoren SIND das Aussehen – nie ein neuer Entwurf“ gegen „Tiefe, wo die Kamera von der Straße aus
   hinsieht“.** Die Generatoren haben genau dort, wo die Kamera im 3D in Augenhöhe vorbeifährt (Straßenflanke), keine
   Öffnungen, weil das Sprite sie nur unter −20° zeigte. Die Behebung von K2 fügt Fenster und Türen hinzu, die das
   Sprite nicht hat (Umriss unverändert, Sprite-Geometrie unverändert über `close3d`). Bitte um ausdrückliche
   Zustimmung der Leitung, dass solche Flankenöffnungen „im Stil des Generators“ erlaubt sind – das betrifft auch
   AS5a2/AS5b (Grachtenhäuser, Reihenhäuser, Haussmann-Blöcke haben dieselbe Bauart).
3. **Überblenden der Stufen für Gebäude.** A-16 fordert das Dither-Überblenden nur für Bäume; die Stadthäuser
   wechseln bei 60 m 15–32 % der Pixel (K5). Bitte R7 auch für `building`/`city` beauftragen.
4. **Mip-Kette für `baked_cutout`.** §4.6.5/D23 lassen die Mips beim Import erzeugen (Box-Filter); damit ist
   „Deckung in kleinen Mips erhalten“ nicht erfüllbar (K7). Wer darf `bake.py` bzw. die Import-Skripte dafür ändern
   (in AS5a1 ausdrücklich nicht angefasst)? Vorschlag: AS5a-N mit Freigabe für den Ausschneide-Teil von `bake.py`.
5. **Helligkeit gegen Arcade (K8).** Der Vertrag misst Nachtfenster gegen Arcade (A-16), nicht die Tageshelligkeit
   sonniger Fassaden. Vorschlag für R4: Median-Luma der Sonnenseite ≤ +15 % gegen Arcade als Prüfwert.

## 8. Für die Nacharbeit (AS5a-N) und die anderen Pakete – in dieser Reihenfolge

1. **Leitung/R2:** K1 entscheiden (Stadt aus dem F7-Korridor), dann München km 162, Nürnberg km 103,6, Hannover km 142,4
   neu als A/B.
2. **AS5a-N:** K2 Flankenöffnungen im Erdgeschoss (Fachwerkzeile, Turmhaus, Barock) und Fenster/Sockel/Anker auf der
   ganzen Giebelzeilen-Flanke, über `close3d` (Sprite unverändert); nachts dieselben Lichtregeln wie die Front.
3. **AS5a-N:** K4 Erkerfenster schneiden, Konsole tönen; K5 lod1 der Fachwerkhäuser aus dem gerenderten lod0 backen,
   lod1 nachts abdunkeln; K6 Flimmern (siehe dort); K10 Kleinkram (Büroturm-Foyer, Gartenstufe des Einfamilienhauses,
   Texeldichte Kontor).
4. **AS5a-N + Import (Freigabe nötig):** K7 Mip-Kette der Geländer mit erhaltener Deckung.
5. **R7:** K3 Tönung der Modell-Instanzen; Dither-Überblenden für Gebäude (K5).
6. **R4:** K8 Sonnenseite gegen Arcade abgleichen; K9 (siehe dort).
7. **AS5a2/AS5b:** den Bauer `city` weiterverwenden, aber die Flanken von Anfang an mitdenken (K2) und die Geländer erst
   nach K7 in großer Zahl einsetzen (Paris: schmiedeeiserne Balkone an jedem Haussmann-Block).

## 9. Bilder und Filme (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `01_rennen_muenchen_links_fehlen_haeuser_mittag.jpg` | München km 161,7, 12 Uhr, Hoch: links in Modern keine Häuser (K1) |
| `02_rennen_hamburg_innenstadt_mittag.jpg` | Hamburg km 88,2 (+4 s): Giebelzeilen, Laden – Modern schärfer, Flanken (K2) |
| `03_rennen_nuernberg_altstadt_mittag.jpg` | Nürnberg km 102,7 (+4 s): Fachwerk, Barock; rechts fehlt das Turmhaus (K1), links blinder Sockel (K2) |
| `04_rennen_hannover_mittag.jpg` | Hannover km 143,9 (+4 s): Gründerzeit mit Schaufenstern am Gehweg |
| `05_rennen_hamburg_vorort_toenung_mittag.jpg` | Hamburg Vorort km 81,2: Häuser weiß statt rosa (K3) |
| `06_rennen_hamburg_innenstadt_nacht.jpg` | Hamburg km 88,2, 22 Uhr (+4 s): Giebelzeilen mit beleuchteten Fenstern, Laden |
| `07_rennen_nuernberg_altstadt_nacht.jpg` | Nürnberg km 102,7, 22 Uhr (+4 s): rechts fehlt das Turmhaus (K1), links dunkle Flanke (K2) |
| `08_rennen_hannover_daemmerung.jpg` | Hannover km 143,9, 19:30, Mittel (K9) |
| `09_rennen_weitere_mittag.jpg` | die übrigen Mittagsbilder (2 s bzw. 4 s) |
| `10/11/12_abstaende_{german,altstadt,hanse}_{mittag,daemmerung,nacht}.jpg` | Spielkamera 10/30/100/250 m, je Modell eine Zeile, darunter der Arcade-Platzhalter in gleicher Lage (Hoch). Achtung: der Platzhalter der Prüfszene zeigt nachts und in der Dämmerung kein Fensterlicht – für Licht gilt nur das Rennen |
| `20/21_nahansichten_{german,altstadt,hanse}_{tag,nacht}.jpg` | Anfahrt, schräg, Straßenseite, Rückseite (lod0, Hoch) |
| `25_stufenwechsel_mittel_{tag,nacht}.jpg` | lod0/lod1 bei 60 m, lod1 und Platzhalter bei 200 m („Mittel“) (K5) |
| `26_umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera (grün beide, orange nur Modell, blau nur Sprite) |
| `27_toenung_modell_gegen_sprite.jpg` | Modell, Atlas × Tönung, Sprite × Tönung, Sprite – die fünf getönten Platzierungen (K3) |
| `28_flimmern_messbild.jpg` | Messbild der Flimmermessung (Fachwerkzeile, Gründerzeit, Giebelzeile; Modell/Platzhalter) (K6) |
| `30_mangel_flanken_ohne_oeffnungen.jpg` | blinde Straßenflanken: Prüfstraße, Rennen Nürnberg, Giebelzeile 10 m und nachts (K2) |
| `31_mangel_erker_fachwerk_b.jpg` | gemalte Erkerfenster, weiße Konsole, Tag und Nacht (K4) |
| `40_fahrt_altstadt_50kmh_modell_gegen_sprite.mp4` | Prüfstraße Altstadt, 50 km/h, „Mittel“, 12 Uhr, 2,5 s: Modelle links, Arcade-Platzhalter rechts |
| `41_fahrt_gruenderzeit_50kmh_modell.mp4` | Prüfstraße Gründerzeit/Mietshaus/Büroturm, 50 km/h, 2,5 s |
| `42_fahrt_altstadt_50kmh_modell_4s.mp4` | Prüfstraße Altstadt 4 s, drei Stufenwechsel bei 60 m (Bilder 9, 121, 234) |
| `bericht.md` | dieser Bericht |
