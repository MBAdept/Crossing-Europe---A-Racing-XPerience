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

