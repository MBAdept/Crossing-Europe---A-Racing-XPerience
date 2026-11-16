# KRITIK-5a2 – Unabhängige Kunstkritik von AS5a2 (Stadthäuser dutch, belgian, french, paris, swiss)

- Gegenstand: Zweig `worktree-wf_db8ba6cd-508-4` (gesichert als `origin/wip/v080-as5a2`), Stand **3c5e37a**, nur
  gelesen. Geprüft in einer Kopie im Arbeitsordner (`m1/KRITIK-5a2/tree`). Keine Commits, kein Zweig, keine Datei des
  AS5a2-Arbeitsbaums geändert.
- Modelle (zwölf, nach Häufigkeit im ganzen Netz): Südhaus `city_french_sud` (588), Lütticher Reihenhäuser
  `city_belgian_terrace` (315), Loire-Haus `city_french_maison` (209), Lyoner Stadthaus `city_french_immeuble` (202),
  niederländische Reihenhäuser `city_dutch_terrace` (130, davon 50 getönt), Maashaus `city_belgian_stone` (96),
  Haussmann-Block `city_paris_haussmann` (55), Chalet `city_swiss_chalet` (54), Grachtenhäuser A `city_dutch_canal`
  (51), Berner Lauben `city_swiss_laube` (46), Grachtenhäuser B `city_dutch_canal_b` (22), Haussmann-Eckhaus
  `city_paris_corner` (8).
- **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, Spiel-Shader über `ModelFactory`, Renn-Licht
  bzw. das Rennen selbst); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte
  Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Stadthäuser sichtbar feiner als die Arcade-Bilder und gut genug, um stundenlang durch die Städte zu
fahren?**

- **Feiner: ja – bei Tag bei allen zwölf, bei zehn deutlich.** Von 5 bis etwa 150 m haben die Häuser echte Tiefe, wo
  Arcade eine flache, aus der Nähe verschwimmende Bildfläche vorbeischiebt: Haussmann-Flanken mit Bogenläden,
  Auslagen, Konsolen und Schmiedeeisen, Lyoner Haus mit Quadern, Läden und Fenstergittern, Berner Lauben als echte
  Arkaden mit Blumenkästen, Grachtenhäuser mit Treppen-, Glocken- und Halsgiebeln und Fenstern an der Straßenflanke,
  Maashaus mit Blausteinbändern und Kreuzstockfenstern (Bilder 01, 03, 04, 06, 10, 20). Umriss, Dächer, Farben und
  Fensterraster sind die des Sprites (IoU 0,945–0,999), Budgets und Bytes stimmen (größtes Modell 6 518 Dreiecke,
  2 Aufrufe je Stufe, Archiv 0,94 + 5,82 MB). Bern ist das stärkste Bild der Charge; Chalet und Südhaus sind nur
  etwas feiner (ihr Garten sieht aus wie im Sprite).
- **Stundenlang: bei Tag ja, nachts in den Ladenstraßen noch nicht.** Nachts leuchten die Wohnfenster wie in Arcade
  (Paris 4,0 gegen 4,0 % der Fassade, Amsterdam gleich), die **Schaufenster aber auf einem Drittel der Fläche und
  deutlich dunkler** (Paris: Ladenfläche 8,9 gegen 24,4 %, Helligkeit 149 gegen 203; Bern: warmes Licht im Bild
  1,5–2,0 gegen 3,7–4,0 %) – eine Pariser Straße wirkt in Modern nachts dunkler und leerer als in Arcade (K1, Bild 02).
  Weitere Schwächen, die man auf Dauer sieht: ab 100 m werden die Fassaden blasser und ihre Fenster zu rosa-lila
  Flecken (K2, Bild 29), Schmiedeeisen und Sprossen der Pariser Häuser flimmern bei 40–100 m 3–11× so stark wie das Sprite und
  schließen sich in der Ferne zu dunklen Bändern (K4) – im Fahrfilm durch eine Pariser Prüfstraße sind die fernen
  Zeilen 2–3× so unruhig wie die Arcade-Straße (Bild 43/44), dafür scharf statt verschwommen, der Gartenbaum des häufigsten Modells ist aus der Nähe eine
  facettierte Klumpen-Krone (K3), der Stufenwechsel bei 60 m tauscht 9–18 % der Pixel ohne Überblenden (K5).
- **Nicht an den Modellen, aber im Rennen sichtbar:** In Lyon und Bern fehlen in Kurven ganze Häuser (Kurvenkorridor,
  FIX-M2 B-01 ist in diesem Stand noch nicht enthalten); die niedrigen Garten- und Backsteinmauern und Hecken am
  Straßenrand fehlen, bis R6 den Bauer `city` liefert; sonnige helle Fassaden sind 15–20 % heller als in Arcade (R4).
- **Empfehlung:** Die zwölf Modelle können in den nächsten Testbuild – sie sind bei Tag klar besser als die
  Arcade-Bilder, nichts ist kaputt, kein Prüfer rot. Vor einem Testbuild, in dem der Nutzer nachts durch Paris fährt,
  sollte K1 (Ladenlicht, eine Formel in `cities3d._display_mat`, ein Neu-Export beider Chargen) erledigt sein. In
  derselben Nacharbeit AS5a-N: K2 Fernfenster, K3 Gartenbaum/-mauer, K4 Geländer in lod1, K7 Geranien. Die Leitung
  sollte vorher die Vertragsfragen 1 und 2 entscheiden (Abschnitt 7) – sie betreffen auch AS5b.

| Modell (Platzierungen) | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Südhaus (588) | etwas feiner | ja | Läden mit Fensterläden, Balkongitter, Genoise, Kanalziegel | Gartenplatane als Klumpen, Gartenmauer 15 px/m (K3); ganze Fassade `baked_cutout`; lod1 = 69 % von lod0 |
| Lütticher Reihenhäuser (315) | **feiner** | ja | vier Ziegelarten, Blausteinstürze, Gauben, Café, Flanke mit Fenstern und Tür | Café nachts vermutlich wie die Pariser Läden zu dunkel (gleiche Formel, gefolgert; K1) |
| Loire-Haus (209) | **feiner** | ja | Tuffstein mit Quadern, Fensterläden, Steingauben, Kamine | Gartenbaum/-mauer (K3), lod1 flimmert 1,0–1,4 % (K6) |
| Lyoner Haus (202) | **feiner** | ja | Quaderecken, Läden, Fenstergitter, Balkon, Bäckerei um die Ecke | Gitter schließen sich (Mip 4: 4,2-fach), Bäckerei nachts dunkel (gleiche Formel, gefolgert) |
| niederl. Reihenhäuser (130) | **feiner** | ja (Tönung fehlt, R7) | Ziegelreihen, breite Gauben, Endgiebel mit Fenster und Seitentür | Tönung `#ead6cc` an 50 Stellen (R7) |
| Maashaus (96) | **feiner** | ja | Blausteinbänder, Kreuzstockfenster, Treppengiebel, Rundbogentür | fern am blassesten (Fenster-p10 +21) |
| Haussmann-Block (55) | **deutlich feiner** | ja, mit K1/K4 | Bogenläden mit Auslage, Konsolen, Balkone, Verdachungen, Zinkmansarde | Flimmern 1,0–1,2 % (Sprite 0,0–0,3), Läden nachts dunkel |
| Chalet (54) | etwas feiner | ja | Blockbau, Fensterläden, Holzbalkone, tiefe Traufe, Holzstapel | Geranien als Perlenkette (K7), IoU 0,945 |
| Grachtenhäuser A (51) | **feiner** | ja | drei Giebelformen, Flanke mit Schiebefenstern, Stufen | Gegenseite 12–15 px/m; Wechsel bei 120 m 22,6 % |
| Lauben (46) | **deutlich feiner** | ja | Arkaden als echte Öffnungen, Läden darin, Blumenkästen, Gauben | Arkaden nachts dunkler als Arcade (K1) |
| Grachtenhäuser B (22) | **feiner** | ja | Gesimshaus mit Kranzgesims um die Ecke, Speicher, Renaissance-Giebel | flimmert 0,7–1,0 % (K6) |
| Haussmann-Eckhaus (8) | **deutlich feiner** | ja | abgeschrägte Ecke mit Laden, Balkone um die Ecke | Rückseite blank 9–12 px/m (K8) |

## 2. Wie geprüft wurde

- **Gegenstand.** Zweig `worktree-wf_db8ba6cd-508-4` (gesichert als `origin/wip/v080-as5a2`), Stand **3c5e37a**, nur
  gelesen. Gerendert und gemessen in einer Kopie im Arbeitsordner (`m1/KRITIK-5a2/tree`: Arbeitsbaum ohne `.git`,
  `build/` und `_cache3d`, mit seinem Import-Cache; Import 0 Fehler). Keine Commits, kein Zweig, keine Datei des
  AS5a2-Arbeitsbaums geändert. Alle Läufe mit `nice -n 19`, immer nur ein schwerer Lauf, absolutes `XDG_DATA_HOME`
  und eigener Mesa-Cache im Arbeitsordner.
- **Messgrundlage.** **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig` bzw. das Rennen selbst); **angesehen** = Urteil nach Bildern;
  **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen) oder aus Code und
  Maßen abgeleitet.
- **Lage wie im Rennen.** Positionen und Kanten aus der Zählung `census_all.log` (AS5a1, alle Etappen): Innenstadt-Sets
  stehen 6,6–9 m von der Fahrbahnmitte (Kante), Vorort-Sets 10–19 m. In den Prüfszenen steht jedes Modell wie vom
  Requisiten-Bauer verankert: Anker = Kante (Innenstadt 7 m, Vorort 13 m) + `extent_l`.
- **Werkzeuge** (nur in der Kopie unter `tools/kritik/`, aufbewahrt in `m1/KRITIK-5a2/kt/`; die Kopie selbst ist gelöscht): `k4_scene.gd` (KRITIK-4:
  `dist2` Spielkamera bei 10/30/100/250 m mit dem Arcade-Platzhalter derselben Lage darunter, `close` Nahansichten,
  `outline2` Umriss in der Sprite-Kamera, `lods` Stufenwechsel), `my_scene --mode=sparkcam` (AS4R: Flimmern),
  `tint_scene.gd`, `texel_k5.gd` (KRITIK-5a1: Texeldichte je Wandrichtung), `k5_scene --mode=drive` (Fahrfilm durch eine
  Prüfstraße bei 50 km/h, 60 Bilder/s); **neu** `k6_scene.gd --mode=lodcol` (dasselbe Modell bei 60/120/250 m als lod0,
  lod1 und Sprite im selben Licht: mittlere Farbe, Helligkeitsstreuung, dunkles und helles Zehntel), dazu
  `py/rough2.py` (zeitliche Rauheit einer Bildfolge) und die Hilfen von KRITIK-5a1/AS5a2 (`share.py`, `mipcov.py`,
  `mipband.py`, `boxlum.py`, `litpx.py`, `tiles.py`).
- **Rennen.** `tools/ab_shot.sh` (Arcade | Modern aus demselben Simulationszustand, Seed 11, Limousine, Autopilot,
  Verkehr eingeschwungen, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start) an den Ankünften
  Paris, Amsterdam, Brüssel, Lyon, Bern und in den Vororten von Lyon und Amsterdam; „Hoch“ wenn nicht anders gesagt.
- **Was der Bauer selbst schon gemessen hat**, habe ich nachgerechnet statt übernommen (Abschnitt 6).

## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS5a-N** = Nacharbeit der Modelle (`ce3d/cities3d.py`, Hooks in `cesprites/props_cities.py`, Katalog),
**R7** = Fernbild, Tönung, Überblenden, LOD, Anbauten im Requisiten-Bauer, **R4** = Licht, **Import** =
`.import`/`bake.py`. Bilder in diesem Ordner (Nummer vorn im Dateinamen).

### K1 – hoch, nachts (AS5a-N) – Schaufenster und Ladenzeilen leuchten viel schwächer als in Arcade

**Wo:** jede Innenstadt mit Läden – Paris (Haussmann-Bogenläden, Eckhaus-Café), Lyon/Toulouse/Bordeaux (Bäckerei des
Lyoner Hauses), Brüssel/Lüttich (Café der Reihenhäuser), Bern (Läden in den Lauben); dazu Charge 1 (Gründerzeit,
Kontor), weil die Formel geteilt ist.
**Gemessen** (Paris km 387,9, 22 Uhr, Hoch, `py/litpx.py`, Bild 02): Wohnfenster des Eckhauses leuchten gleich wie in
Arcade (4,0 gegen 4,0 % der Fassade), die Bogenläden nur auf **8,9 statt 24,4 %** der Erdgeschossfläche und dunkler
(Mittel (196,155,108) gegen (250,215,158)); 2 s später an der Ladenflanke rechts warme Pixel **3,7 gegen 19,7 %**,
deren Helligkeit **149 gegen 203** (AS5a2: 124 gegen 207). Die ferne Ladenzeile in Bildmitte (150–300 m) hat
3,4–4,9 % warme Pixel gegen 9,8–10,9 % in Arcade.
**Angesehen:** In Arcade ist eine Pariser Straße nachts eine Kette heller gelber Bögen; in Modern liegen dort
warmbraune Auslagen hinter dunklem Glas, die Fassade selbst ist im Mondlicht gut lesbar – stimmungsvoll, aber der
Straßenzug wirkt **dunkler und leerer als in Arcade**. Das widerspricht dem Wunsch des Nutzers nach „besseren
Lichteffekten“ genau dort, wo Städte nachts leben sollen. Teil des Unterschieds ist, dass Arcade die beleuchtete
Flanke als großes Billboard zeigt; die Helligkeit der einzelnen Auslage (149 gegen 203) ist aber eindeutig ein
Modellwert.
**Fix (AS5a-N, beide Chargen in einem Neu-Export):** in `cities3d._display_mat` die Lichtschicht der Auslage
um den Faktor ≈ 1,6 anheben (AS5a2s Vorschlag `shop_glow`) und das obere Drittel der Auslage als helle Rückwand bzw.
Deckenlicht backen statt dunkler Regale, so dass der Mittelwert der beleuchteten Ladenpixel bei ≈ 200 liegt wie in
Arcade; prüfen, wie viel die dunkle Glastönung nachts schluckt. Nachweis: dieselbe A/B-Stelle, Ladenpixel 190–210, Anteil ≥ 0,7 × Arcade;
Tag unverändert (nichts leuchtet bei Tag).

### K2 – mittel, häufig (AS5a-N + R7) – Fassaden werden ab 100 m blass, die Fenster rosa-lila

**Wo:** alle zwölf Modelle, bei jeder Stadteinfahrt im Bild geradeaus (100–350 m), am deutlichsten an farbigen
Putzfassaden (Südhaus, Lyoner Haus, Lauben) und am Maashaus.
**Gemessen** (5.4, `k6_scene --mode=lodcol`): zwischen 60 und 250 m werden die Modelle um 5–10 % heller, das Sprite um
1–3 % dunkler; das dunkle Zehntel (die Fenster) hellt beim Modell um 13–23 Stufen auf, beim Sprite um 2–15. Der
Kontrast der Fassade bei 150 m ist beim Modell kleiner als beim Sprite (Haussmann 59 gegen 75, Lauben 81 gegen 97,
`sparkcam`). lod0 und lod1 verhalten sich gleich – es ist die Mip-Kette des Atlas, nicht die Stufe.
**Angesehen** (Bild 29, 25): bei 200–350 m werden die Fenster zu hellen rosa-lila Flecken, die Lauben verlieren das
Dunkel ihrer Bögen, das Sprite behält dunkle Fensterreihen. Im Rennen ist es schwächer (Dunst, Gegenlicht): in Bern
und Paris lesen sich die fernen Zeilen noch gut, etwas heller als Arcade; in Lyon zeigt die Flanke des Lyoner Hauses bei
≈ 150 m zwischen den grünen Fensterläden rosa-lila Flecken statt dunkler Scheiben (Bild 13, Ausschnitt 6× vergrößert). Das ist die Schwäche „Scheiben ~10 Stufen heller, grau-lila bei 250 m“ aus der Einordnung
von AS4R – sie wurde wiederholt.
**Fix:** (AS5a-N) die Fensterbereiche der kleinen Mips vorfiltern: ab Mip 2 Rahmen, Sohlbank und Sprossen mit dem
Glas mischen und das Ergebnis auf die mittlere Fensterfarbe des Sprites ziehen (eigene Mip-Kette beim Bake, wie das
Sprite bei kleiner Auflösung gerendert ist); billiger Ersatz: in lod1 die Fenster auf eine eigene, dunkle
„Fernfenster“-Kachel im Atlas legen (Glas + schmaler dunkelgrauer Rahmen, ein Mal gebacken, wiederverwendet).
(R7) ab ≈ 200 m das Fernbild des Sets (Sprite-Relief, A-16) – dann bleibt AS5a-N nur 100–200 m. Nachweis:
`lodcol` p10 bei 250 m ≤ p10 bei 60 m + 8, Luma ±3 %.

### K3 – mittel bis hoch, häufigstes Modell (AS5a-N) – Gartenbaum als Klumpen, Gartenmauer weich (Südhaus, Loire-Haus)

**Wo:** `city_french_sud` (588 Platzierungen: Vororte von Toulouse, Montpellier, Lyon, Bordeaux, Pau, Tours, Bern-Abfahrt
…) und `city_french_maison` (209: Paris, Tours, Bordeaux, Toulouse) – zusammen 797, die meisten Stadthäuser der Charge.
**Was:** Der Gartenbaum steht auf der Straßenseite des Hauses (Generator: `x0 − 3,2 m`) und ist die dezimierte
Kugelkrone des Generators: aus 10–15 m eine Traube facettierter grüner Steine mit harten Kanten (Bild 30 links). Bei
30 m wirkt sie wie das Sprite (Bild 30 rechts), aber die Vororthäuser stehen 10–19 m vom Rand – der Baum zieht
näher an der Kamera vorbei als die Hauswand. Die Gartenmauer davor hat 14–16 px/m (5.2), unter den 26 px/m des
Vertrags und unter der Angabe von AS5a2 („0,6 der Dichte“ ≈ 32 px/m); sie ist eine glatte, leicht verschwommene Fläche.
Die Vorgabe sagt für Gartenbäume ausdrücklich „the AS3 tree models if a tree stands there“ – das ist nicht umgesetzt.
**Fix (AS5a-N, mit Vertragsfrage 1):** die Krone aus dem Modell nehmen und an ihrer Stelle einen AS3-Baum stellen
(Platane ≈ `tree_beech`/`tree_oak`, Maßstab aus Kronenradius 3,0 / 2,2 m) – als Anbau des Requisiten-Bauers oder als
dritte Oberfläche `leaves`; solange das nicht geht: die Kronenkugeln mit `smooth` schattieren und ihre Facetten im
Atlas mit einer Blattstruktur (Rauschen 2–4 cm) backen, Ziel „weiche Wolke“ wie das Sprite. Gartenmauer in den Chart
der Straßenwand (≥ 32 px/m), Mauerkrone mit Abdeckplatte. Nachweis: Nahansicht `road` und Fahrfilm durch eine Vorortstraße.

### K4 – mittel (Modell + Import/Renderer) – Schmiedeeisen und Fenstergitter schließen sich in der Ferne und flimmern

**Wo:** Haussmann (55), Eckhaus (8), Lyoner Haus (202), Südhaus (588), Chalet (54) – alle Modelle mit `baked_cutout`.
**Gemessen:** Deckung des Alpha-Tests gegen Mip 0 steigt auf 1,2–1,8 (Mip 2, ab ≈ 20 m), 1,5–2,2 (Mip 3, ab ≈ 40 m)
und 1,9–4,2 (Mip 4, ab ≈ 75 m); vor hellem Stein wird das Geländerband dabei 25–89 Stufen dunkler (5.6). Flimmern
Haussmann/Eckhaus 1,0–1,2 % bei 40–100 m gegen 0,0–0,3 % beim Sprite (5.5). **Angesehen:** Bei 100 m sind die
durchgehenden Haussmann-Balkone geschlossene grau-braune Bänder ohne Durchblick (Bild 10 paris, 100 m), dunkler und
dichter als die gemalten Bänder des Sprites; im Paris-Clip von AS5a2 zeigen die fernen Fassaden in der Bildmitte eine fast doppelt so große
zeitliche Unruhe wie Arcade (`py/rough2.py`: 7,0 gegen 3,8, H.264, grob). Halo oder Aufblitzen sehe ich in den
Standbildern nicht – die Klasse `baked_cutout` funktioniert, ihre Mip-Kette nicht.
**Fix:** (Import/`bake.py`, Vertragsfrage 2) eine deckungserhaltende Mip-Kette für die Ausschneide-Inseln (Alpha je
Stufe so skaliert, dass der Anteil ≥ 0,5 dem von Mip 0 gleicht); (AS5a-N) in **lod1** die Geländer als halbdeckendes
gemaltes Band in den deckenden Atlas (dann ist lod1 `baked` statt `baked_cutout`, ohne `discard`, mit Rückseiten-Culling)
und die Fassadenwände von lod0 aus der Ausschneide-Klasse nehmen, sobald drei Oberflächen erlaubt sind (Vertragsfrage 1).
Nachweis: `mipcov.py` 0,9–1,1 für Mip 1–4, `sparkcam` ≤ 0,5 % bei 40–150 m.

### K5 – mittel (R7 + AS5a-N) – Stufenwechsel ohne Überblenden, nachts heller

**Gemessen** (5.3): bei 60 m („Mittel“) 9–18 % der Pixel, auf „Hoch“ bei 120 m bis 22,6 % (Grachtenhäuser); nachts
springt die Helligkeit um +3 bis +5 % (lod1-Scheiben ohne Laibung, p90 der Fensterpixel beim Maashaus 80 → 119).
Bestätigt AS5a2. In einer dichten Zeile geht der Wechsel im Bewegungsrauschen unter (Prüfstraße Paris, `py/swappop.py`: 10,8 % neu
geänderte Pixel im Wechselbild gegen 10,4 % davor und danach; so auch KRITIK-5a1), sichtbar bleibt er bei frei stehenden Häusern und nachts. **Fix:** (R7) Dither-Überblenden 0,3–0,5 s auch für
`city`/`building`; (AS5a-N) lod1-Scheiben nachts um den Laibungsschatten dimmen (`light_mul` lod1 ≈ 0,8).

### K6 – mittel (AS5a-N) – Flimmern von Sprossen und Rahmen auch ohne Geländer

**Gemessen** (5.5): Grachtenhäuser B 0,7 / 1,0 / 0,6 / 0,9 % gegen 0,1 / 0,2 / 0,2 / 0,4 %; Loire-Haus in lod1 1,0 / 1,4 %
bei 100 / 150 m (Sprite 0,6 / 0,9); Lauben und Südhaus 1,5–3× das Sprite. Das Sprite ist vorgefiltert, das Modell
zeigt 1–2 Pixel breite weiße Rahmen und Sprossen vor dunklem Glas. In Bewegung (Abschnitt 4, Clip): ferne Zeilen
2,0–2,8× so unruhig wie die Arcade-Platzhalter (Prüfstraße Paris), Rennclip Amsterdam 1,7–1,9× (H.264, grob). **Fix:** dieselbe Ursache wie K2 – die Fensterregion
der kleinen Mips vorfiltern (Rahmen und Sprossen ab Mip 2 mit dem Glas mischen, Kontrast der Sprossen 30 % senken);
Sprossen-Geometrie erst ab lod0 < 40 m.

### K7 – niedrig bis mittel (AS5a-N) – Chalet: Geranien als Perlenkette

**Wo:** `city_swiss_chalet` (54, Vororte Bern, Mailand-Abfahrt) – Balkon- und Fensterkästen. **Was:** Die Geranien sind
eine Reihe großer, facettierter roter und grüner Kugeln (Bild 31): aus 10–20 m eine Perlenkette aus Plastik. Aus 30 m
wie das Sprite. **Fix:** Blumenkasten als niedriger Wulst mit gebackenem Blütenrauschen (rote Tupfen 3–5 cm auf Grün),
dazu 3–5 kleine Kugeln je Meter mit `smooth`; nicht mehr als heute an Dreiecken.

### K8 – niedrig (AS5a-N) – Rück- und Gegenseiten

Eckhaus: Rückseite und Gegenseite blanke Putzflächen mit 9–12 px/m (Bild 32; bekannt, AS5a2). Grachtenhäuser A/B:
Gegenseite (+x) 12–15 px/m, blank. Lauben: die Rückseite zeigt Läden ohne Arkaden (die Arkaden stehen nur vorn). Zu
sehen nur in Kurven und beim Zurückschauen (gefolgert: selten). **Fix:** Fernwand-Zuordnung für Grundrisse mit
abgeschrägter Ecke (AS5a2 nennt sie), sonst der Straßenwand-Chart gespiegelt.

### K9 – niedrig (AS5a-N/AS5b) – Nachts keine Wand- und Eingangsleuchten

Die zwölf Generatoren rufen `wall_lamp` nicht auf (die Funktion gibt es, das Hausboot nutzt sie); die Vorgabe nennt
„entrance and wall lamps as light anchors (lamp channel 12 + lights)“. Arcade zeigt dort auch keine Leuchten – Modern
ist nachts also nicht schlechter, aber auch nicht lebendiger als Arcade, wo es leicht wäre: Haussmann-Portal,
Café-Markise, Bäckerei Lyon, Lauben-Gewölbe. **Fix:** über `close3d` je Haus eine Wandleuchte am Eingang
(`wall_lamp`, Kanal 12, `lights`-Anker), Sprite unverändert.

### K10 – niedrig – Kleinkram

- **Tönung (R7):** 50 Reihenhausreihen im Ruhrgebiet stehen ohne `#ead6cc` (Bild 27), bis R7 die Tönung auf Modelle legt.
- **lod1 spart wenig beim häufigsten Modell:** Südhaus lod1 = 69 % von lod0 (3 716 / 5 359), Haussmann 57 %, Eckhaus
  60 % – Baumkrone und Geländer bleiben in lod1 fast voll. Ziel ≤ 40 %.
- **Sonnige Fassaden heller als Arcade (R4):** im Rennen Paris rechte Flanke Median-Luma 182 gegen 152 (+20 %),
  Amsterdam +15 % (gemessen, `py/boxlum.py`) – wie KRITIK-5a1 K8; Licht, nicht Modell.

## 4. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit 50 km/h (der Autopilot beschleunigt auf
84–114 km/h), Bilder 2 s und 4 s nach dem Start; „Hoch“ wenn nicht anders gesagt. Alle 11 Läufe Exit 0, 0 Zeilen
`SCRIPT ERROR`/`Parse Error`/`ERROR:` in 22 Protokollen (gemessen); ein A/B-Lauf (Arcade + Modern, zwei Bilder) brauchte 4–8 min.
Der Stand enthält FIX-M2 **nicht** – in Kurven nimmt der Requisiten-Bauer deshalb noch ganze Häuser weg (F7 in
strenger Lesart, B-01); das sehe ich in Lyon und Bern (unten) und rechne es nicht den Modellen an.

| Bild | Ort | Zeit | Was man sieht (angesehen; Zahlen gemessen) |
|---|---|---|---|
| 01 | Paris (Lüttich – Paris km 387,5) | 12 Uhr | +2 s: Eckhaus voraus wie das Sprite, aber plastisch; +4 s: rechts die Haussmann-Flanke mit Bogenläden, Auslagen, Konsolen, Balkon und Gittern – Arcade schiebt dort eine verschwommene Bildfläche vorbei. **Klar feiner.** Sonnenseite heller als Arcade (Median-Luma 182 gegen 152) |
| 02 | Paris | 22 Uhr | Wohnfenster am Eckhaus gleich viele wie Arcade (4,0 / 4,0 % der Fassade), die Läden aber auf einem Drittel der Fläche und dunkler (8,9 / 24,4 %; warme Pixel rechts 149 gegen 203 Helligkeit) – **K1**. Die Fassade selbst ist im Mondlicht lesbar, Arcade zeigt dort Schwarz mit hellen Bögen |
| 03 | Amsterdam (Bremen – Amsterdam km 357,3) | 12 Uhr | Treppen-, Glocken-, Halsgiebel scharf, Flanke des Treppengiebelhauses mit Schiebefenstern (Arcade: blinde Backsteinflanke als Fläche), Stufen und Geländer am Kai. **Klar feiner** |
| 07 | Amsterdam | 22 Uhr | Fensterlicht wie Arcade (warme Pixel 1,65 / 1,67 % gegen 1,35 / 1,94 %), unregelmäßig und warm; die Giebel im Mondlicht lesbar – **gleichwertig bis besser** |
| 04 | Brüssel (Köln – Brüssel km 195,5) | 12 Uhr | Maashaus-Flanke mit Blausteinbändern und Kreuzstockfenstern links nah, Lütticher Reihe voraus. **Feiner.** Es fehlen in Modern die niedrigen Backsteinmauern, die Arcade am Straßenrand zeigt – das ist der `fence` „wall“ der Szenerie `city_belgian_outskirts`, den der Bauer `city` von R6 zeichnen wird (in diesem Stand fehlt er) – kein Modellfehler |
| 09 | Brüssel | 19:30, Mittel | einzelne Fenster warm erleuchtet wie Arcade, Fassaden im Abendlicht; gleiche Mauerlücke |
| 05 | Lyon (Montpellier – Lyon km 297,0) | 12 Uhr | +2 s: rechts fehlt in Modern das Lyoner Haus ganz (Kurvenkorridor, FIX-M2); +4 s: Lyoner Haus mit Quadern, Läden, Gittern, daneben AS4-Hochhaus. Fern (≈ 150 m) zeigen die Fenster der Flanke rosa-lila Flecken (**K2**) |
| 06 | Bern (Lyon – Bern km 302,3) | 12 Uhr | Lauben als echte Arkaden beidseits, Blumenkästen, Dachgauben; +2 s fehlt links eine Laube (Kurvenkorridor). **Das stärkste Bild der Charge** – eine glaubwürdige Berner Gasse |
| 08 | Bern | 22 Uhr | Fenster warm und unregelmäßig, einzelne Läden in den Lauben erleuchtet; insgesamt weniger Licht als Arcade (warme Pixel 1,5–2,0 % gegen 3,7–4,0 %), weil Arcade die Arkadenbögen hell zeigt (**K1**) |
| 11 | Lyon Vorort (Montpellier – Lyon km 285,6) | 12 Uhr | Südhäuser bei 40–100 m schärfer als Arcade (Läden, Balkon, Gitter, Ziegel); die Gartenplatane wirkt aus dieser Entfernung wie im Sprite (Klumpen, K3). In Modern fehlen die niedrigen Gartenmauern an der Straße (Szenerie-`fence`, R6) und einzelne Bäume (Kurvenkorridor) – die Straße wirkt leerer als in Arcade |
| 12 | Amsterdam Vorort (Bremen – Amsterdam km 345,5) | 12 Uhr | niederländische Reihenhäuser scharf, Endgiebel mit Fenstern und Seitentür nah an der Straße – **feiner**; die Hecken am Straßenrand (Szenerie-`fence`) fehlen noch (R6) |

**Clip:** (1) **Rennclip Amsterdam** (`tools/ab_clip.sh`, Bremen – Amsterdam ab km 357,2, `--autopilot-target=50`, Mittel, 12 Uhr,
6 s, 60 fps, je Seite 1280×720; Bilder 40–42; beide Läufe Exit 0, Modern 311 s): Grachtenhäuser beidseits, Flanken mit
Fenstern, ferne Giebel scharf – in Bewegung klar feiner als Arcade. Zeitliche Unruhe der fernen Fassaden in der Bildmitte
(`py/rough2.py`, mittlere |2. Zeitableitung| der Helligkeit, H.264): Modern 10,8 gegen Arcade 5,7, „kippende“ Pixel
11,4 gegen 6,6 % (gemessen; Inhalt nicht identisch, grob). In den Folgebildern (42) bleiben die Fensterraster stabil;
dünne weiße Gesimslinien kippen von Bild zu Bild. (2) **Prüfstraße Paris** (`k5_scene --mode=drive`, Haussmann und
Eckhaus beidseits alle 26 m, 50 km/h, Mittel, 2,5 s, unkomprimiert; Bild 43/44): ferne Zeilen 2,0–2,1× so unruhig wie
die Arcade-Platzhalter (8,5 / 14,9 gegen 4,1 / 7,5; kippende Pixel 11,4 / 17,5 gegen 4,1 / 8,5 %), nahe Fassaden
1,3–1,7×. Dafür ist das Modell scharf und perspektivisch richtig, die Platzhalter sind unscharfe, zur Kamera gedrehte
Tafeln (Bild 44). Die zwei Stufenwechsel bei 60 m im Film gehen im Bewegungsrauschen unter (`py/swappop.py`: 10,8 % neu
geänderte Pixel im Wechselbild gegen 10,4 % davor/danach). Die Wirkung auf einem echten 60-Hz-Bildschirm ist gefolgert.

## 5. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)

### 5.1 Prüfer, Budgets, Zeichenaufrufe, Bytes

`python3 tools/blender/validate_models.py --report` auf der Kopie → `CHECK models OK` (110 Modelle, 183 Sets, 128 mit
Modell; Netze 19,76 MB von 40 MB, Texturen 78,70 MB im Grafikspeicher von 240 MB; `logs/validate.log`). Bytes mit der
Rechnung von `tools/pck_report.py` (deflate -9 je Datei, `py/share.py`, `logs/share.log`):

| Modell | Platzierungen (Netz) | Dreiecke lod0 / lod1 | Klassen je Stufe | Atlas | Netze (Archiv) | Texturen PCK (Archiv) |
|---|---|---|---|---|---|---|
| `city_french_sud` | 588 | 5 359 / 3 716 (69 %) | vpbr + **baked_cutout** | 1024² RGBA | 118,9 kB | 1 573 kB (393,7 kB) |
| `city_belgian_terrace` | 315 | 2 586 / 1 162 | vpbr + baked | 2048×1024 | 46,4 kB | 1 748 kB (550,0 kB) |
| `city_french_maison` | 209 | 3 910 / 1 874 | vpbr + baked | 1024² | 90,0 kB | 874 kB (311,1 kB) |
| `city_french_immeuble` | 202 | 4 020 / 2 486 | vpbr + **baked_cutout** | 2048×1024 RGBA | 75,1 kB | 3 146 kB (566,4 kB) |
| `city_dutch_terrace` | 130 | 3 346 / 1 060 | vpbr + baked | 1024² | 73,0 kB | 874 kB (286,8 kB) |
| `city_belgian_stone` | 96 | 1 336 / 278 | vpbr + baked | 1024² | 20,7 kB | 874 kB (266,9 kB) |
| `city_paris_haussmann` | 55 | 6 518 / 3 714 (57 %) | vpbr + **baked_cutout** | 2048×1024 RGBA | 124,6 kB | 3 146 kB (600,8 kB) |
| `city_swiss_chalet` | 54 | 3 128 / 1 280 | vpbr + **baked_cutout** | 1024² RGBA | 55,6 kB | 1 573 kB (282,1 kB) |
| `city_dutch_canal` | 51 | 3 734 / 1 802 | vpbr + baked | 2048×1024 | 76,8 kB | 1 748 kB (631,4 kB) |
| `city_swiss_laube` | 46 | 4 865 / 942 | vpbr + baked | 2048×1024 | 69,5 kB | 1 748 kB (569,3 kB) |
| `city_dutch_canal_b` | 22 | 3 625 / 1 545 | vpbr + baked | 2048×1024 | 69,3 kB | 1 748 kB (682,8 kB) |
| `city_paris_corner` | 8 | 5 675 / 3 418 (60 %) | vpbr + **baked_cutout** | 2048×1024 RGBA | 111,9 kB | 3 146 kB (677,0 kB) |
| **Summe** | 1 776 | | | | **0,94 MB** | **22,2 MB im PCK (5,82 MB Archiv)** |

Alle zwölf ≤ 10 000 Dreiecke lod0 (größtes: Haussmann 6 518) und 2 Aufrufe je Stufe; Archivanteil 0,94 / 5,82 MB
unter der Grenze der Charge (3 / 7 MB). Das bestätigt AS5a2 (0,93 / 5,79 MB; das Eckhaus rechne ich mit 677 statt
653 kB Texturen – Rundung/Messweg, unerheblich). Backzeiten habe ich nicht nachgemessen (kein Neuexport in einer
Kritik); AS5a2 nennt 166–800 s je Modell.

Auffällig: **Fünf der zwölf Modelle (907 Platzierungen) sind als Ganzes `baked_cutout`** – Südhaus, Lyoner Haus,
Haussmann, Eckhaus, Chalet. Weil die Geländer eine Ausschneide-Klasse brauchen und die Grenze zwei Aufrufe je Stufe
ist, liegt die ganze Fassade in der Klasse mit `cull_disabled` und `discard` (`baked.gdshader`, `CE_CUTOUT`) – auch in
lod1, wo man die Geländer als gemaltes Band im deckenden Atlas zeigen könnte. Auf einer echten Grafikkarte kostet das
frühe Tiefentests und verdoppelt die gezeichneten Flächen (gefolgert, hier nicht messbar; Charge 1 hat dasselbe bei
Mietshaus und Gründerzeit). Das häufigste Modell (Südhaus, 588) spart in lod1 nur 31 % der Dreiecke.

### 5.2 Texeldichte (`texel_k5.gd`, lod0, Modellmaß, Außenwände je Richtung; `logs/texel*.log`)

| Modell | Straße unten (EG + 1. OG) | Straße oben | Anfahrt unten | Gegenseite (+x) | Bemerkung |
|---|---|---|---|---|---|
| Grachtenhäuser A | 49 (p10 50) | 40 | 48 | **15 / 12** | Gegenseite grob (zulässig: „reused walls on the far side“) |
| Grachtenhäuser B | 47 | 38 | 47 | **14 / 12** | dto. |
| niederl. Reihenhäuser | 46 | 46 | 45 | 46 / 14 | |
| belg. Reihenhäuser | 63 | 51 | 63 | 64 / 50 | |
| Maashaus | 54 | 44 | 54 | 55 / 44 | |
| Lyoner Haus | 65 | 59 | 71 | 65 / 52 | |
| Haussmann | 60 (p10 50) | 51 (p10 38) | 62 | 50 / 36 | |
| Eckhaus | 58 (p10 47) | 50 (p10 35) | 58 | **12 / 9** | Rückseite und Gegenseite blank (K8) |
| Lauben | 44 (p10 44) | 35 | 44 | 41 / 34 | im Spiel bei Maßstab 1,10: 39,7 |
| Chalet | 55 | – | 69 | 53 | |
| Südhaus | Hauswand 54, **Gartenmauer 15** | – | 45 (Mauer 16) | 53 | Mauer steht an der Straße |
| Loire-Haus | Hauswand 51, **Gartenmauer 14** | 51 | 43 (Mauer 15) | 49 | dto. |

Vertrag ≥ 26 px/m an Straßenwänden und Vorgabe ≥ 40 px/m im Erdgeschoss der Innenstadthäuser: **an den Hauswänden
erfüllt** (Lauben im größten Maßstab 39,7 – wie AS5a2 sagt). **Nicht erfüllt an den Gartenmauern** von Südhaus und
Loire-Haus: 14–16 px/m (AS5a2 schreibt „0,6 der Dichte“, das wären ≈ 32 px/m; gemessen sind es 0,28). Diese Mauern
stehen an der Straßenkante der Vororte, also näher an der Kamera als jede Hauswand dieser Sets – eine glatte,
weichgezeichnete Putzfläche.

### 5.3 Stufenwechsel (`--mode=lods`, Anker 20 m seitlich; `logs/lods/*.log`)

Anteil der Pixel mit Σ|ΔRGB| > 0,06 beim Wechsel lod0 → lod1, Helligkeitssprung:

| Modell | Mittel 60 m, 12 Uhr | Mittel 60 m, 22 Uhr | Hoch 120 m, 12 Uhr |
|---|---|---|---|
| Südhaus | 16,4 %, +0,1 % | 7,8 %, +1,3 % | 16,1 %, +0,1 % |
| Loire-Haus | 11,9 %, +0,6 % | 7,8 %, +1,9 % | 12,9 %, +0,4 % |
| Lyoner Haus | 14,6 %, +0,3 % | 10,0 %, +4,0 % | 13,9 %, −0,1 % |
| belg. Reihenhäuser | 16,4 %, +0,4 % | 12,4 %, +3,0 % | 16,9 %, −0,9 % |
| Maashaus | 16,2 %, −0,1 % | 11,8 %, +3,5 % | 19,9 %, −0,9 % |
| niederl. Reihenhäuser | 14,4 %, +0,6 % | 9,1 %, +3,0 % | 17,1 %, −0,1 % |
| Grachtenhäuser A | 18,3 %, −0,3 % | 14,5 %, +3,0 % | **22,6 %, −3,2 %** |
| Grachtenhäuser B | 17,5 %, −0,5 % | 13,3 %, +1,6 % | 21,6 %, −1,2 % |
| Chalet | 14,9 %, +0,6 % | 11,2 %, **+4,9 %** | 15,8 %, +0,8 % |
| Lauben | 9,1 %, +0,4 % | 9,0 %, **+4,9 %** | 9,7 %, +0,1 % |
| Haussmann | 14,2 %, +0,1 % | 11,8 %, +3,0 % (Farbton +45°) | 13,3 %, +0,1 % |
| Eckhaus | 13,3 %, +0,3 % | 11,0 %, +3,5 % | 12,7 %, +0,2 % |

Bestätigt AS5a2 (9–18 % bei 60 m). Nachts wird lod1 heller, weil die Scheiben ohne Laibung leuchten (lod1 hat beim
Maashaus und Lyoner Haus bei 60 m p90 der Fensterpixel 119 / 114 statt 80 / 80; `logs/lodcol_h22.log`). Auf „Hoch“
(Wechsel bei 120 m) tauschen die Grachtenhäuser fast ein Viertel der Pixel. Ein Arcade-Platzhalter wechselt nie.

### 5.4 Fernbild: die Fassaden werden mit der Entfernung heller und verlieren ihre Fenster (`k6_scene --mode=lodcol`)

Mittlere Helligkeit (Luma 0–255) und das dunkle Zehntel (p10 = Fenster) der Modellpixel bei 60 und 250 m, gleiche
Stufe, gleiches Renn-Licht (Hoch, 12 Uhr), daneben das Arcade-Sprite in derselben Lage (`logs/lodcol_h12.log`):

| Modell | Luma lod0 60 → 250 m | Sprite 60 → 250 m | p10 lod0 60 → 250 m | p10 Sprite 60 → 250 m | lod1 250 m gegen lod0 250 m |
|---|---|---|---|---|---|
| Haussmann | 134,8 → 148,9 (**+10,5 %**) | 111,9 → 109,6 (−2,1 %) | 55 → 77 (**+22**) | 42 → 53 (+11) | Luma −0,1, p10 +1 |
| Eckhaus | 144,8 → 154,6 (+6,8 %) | 120,8 → 119,2 (−1,3 %) | 66 → 83 (+17) | 44 → 59 (+15) | −0,8 |
| Grachtenhäuser A | 78,5 → 86,6 (+10,3 %) | 68,5 → 67,1 (−2,0 %) | 30 → 35 (+5) | 36 → 40 (+4) | −7,1 |
| Südhaus | 117,0 → 128,2 (+9,6 %) | 100,8 → 98,2 (−2,6 %) | 65 → 79 (+14) | 59 → 63 (+4) | −0,4 |
| Maashaus | 108,2 → 113,4 (+4,8 %) | 90,7 → 88,7 (−2,2 %) | 61 → 82 (**+21**) | 64 → 70 (+6) | −2,6 |
| Lauben | 106,1 → 111,3 (+4,9 %) | 92,0 → 89,0 (−3,3 %) | 56 → 79 (**+23**) | 56 → 58 (+2) | −0,6 |
| Lyoner Haus | 121,3 → 127,1 (+4,8 %) | 104,2 → 101,1 (−3,0 %) | 56 → 69 (+13) | 43 → 58 (+15) | −0,6 |
| niederl. Reihenhäuser | 90,3 → 95,2 (+5,4 %) | 82,5 → 82,1 (−0,5 %) | 45 → 63 (+18) | 43 → 54 (+11) | −0,8 |

Die absolute Helligkeit Modell gegen Sprite ist in der Prüfszene nicht zu vergleichen (der Platzhalter hat ein
eigenes Licht, KRITIK-5a1 K9); verglichen wird jeweils mit sich selbst. Ergebnis: Die Modelle werden zwischen 60 und
250 m um 5–10 % heller, das Sprite um 1–3 % dunkler (Dunst); das dunkle Zehntel – die Fenster – hellt beim Modell um
13–23 Stufen auf, beim Sprite um 2–15. lod0 und lod1 verhalten sich gleich (Unterschied ≤ 3 Stufen, Grachtenhäuser 7):
**es ist nicht die Stufe lod1, sondern die Mip-Kette des Atlas**, in der weiße Rahmen, Sohlbänke und Sprossen das
dunkle Glas überstimmen. Angesehen (Bild 29): die Fenster werden bei 200–350 m zu blassen rosa-lila Flecken (Südhaus,
Maashaus, Lyoner Haus, Lauben), das Sprite behält dunkle Fensterreihen. Das ist der Punkt „Scheiben ~10 Stufen heller,
grau-lila bei 250 m“ aus der Einordnung von AS4R – wiederholt.

### 5.5 Flimmern (`my_scene --mode=sparkcam`, Mittel, 12 Uhr, Viertelpixel-Schritte, Anteil kippender Pixel)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m | Kontrast 150 m Modell / Sprite |
|---|---|---|---|---|---|---|
| Haussmann | **1,0 %** | **1,2 %** | **1,0 %** | 0,6 % | 0,0 / 0,2 / 0,3 / 0,4 | 59 / 75 |
| Eckhaus | **1,1 %** | **1,2 %** | **1,0 %** | 0,7 % | 0,1 / 0,2 / 0,2 / 0,3 | 57 / 70 |
| Grachtenhäuser B | 0,7 % | **1,0 %** | 0,6 % | 0,9 % | 0,1 / 0,2 / 0,2 / 0,4 | 80 / 91 |
| Loire-Haus | 0,4 % | 0,5 % | **1,0 %** | **1,4 %** | 0,2 / 0,4 / 0,6 / 0,9 | 95 / 94 |
| Südhaus | 0,4 % | 0,4 % | 0,6 % | 0,8 % | 0,2 / 0,3 / 0,4 / 0,6 | 86 / 95 |
| Lauben | 0,3 % | 0,4 % | 0,3 % | 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 | 81 / 97 |

Bestätigt AS5a2 (Haussmann identisch). Die Paris-Häuser flimmern bei 40–100 m 3–11× so stark wie ihr Sprite (bei 150 m 1,5–2,3×) – mehr als Block B,
den AS4R mit 1,0 % als Schwäche führte. Ursache: die Schmiedeeisen-Bänder und Fenstergitter (Alpha-Test, s. 5.6)
und Rahmen/Sprossen, 1–2 Pixel breit. Der Kontrast der fernen Fassade ist beim Modell geringer als beim Sprite
(dieselbe Blässe wie 5.4).

### 5.6 Geländer `baked_cutout` in den kleinen Mips (`py/mipcov.py`, `py/mipband.py`, Hintergrund Stein `#e4d9c2`)

| Atlas | Deckung (Anteil ≥ 0,5) gegen Mip 0: Mip 1 / 2 / 3 / 4 | Helligkeit des Bandes gegen Mip 0 (8-Bit-Luma) |
|---|---|---|
| Haussmann | 1,16 / 1,55 / 1,96 / **2,74** | −4 / −16 / −27 / **−53** |
| Eckhaus | 1,14 / 1,51 / 1,97 / 2,67 | −4 / −16 / −30 / −54 |
| Lyoner Haus | 1,16 / 1,77 / 2,24 / **4,15** | −3 / −21 / −32 / **−89** |
| Südhaus | 1,20 / 1,50 / 1,75 / 2,35 | −6 / −16 / −25 / −46 |
| Chalet | 1,00 / 1,17 / 1,48 / 1,85 | +0 / −13 / −36 / −65 |

Bei 150 Texeln je Meter (`CUT_PPM`) und 711 px Brennweite liegt Mip 3 ab etwa 38 m, Mip 4 ab etwa 76 m (gerechnet wie
KRITIK-5a1). Die Geländer verschwinden nicht mehr (der Fehler von Charge 1 vor `cut_fill`), sie **schließen sich**:
Ab 40 m wird aus dem durchbrochenen Schmiedeeisen ein doppelt so dichtes, ab 75 m ein fast geschlossenes dunkles Band.
AS5a2 meldet „±3 Stufen“ – mit einem dunklen Hintergrund gerechnet; vor hellem Stein ist das Band 27–89 Stufen
dunkler als nah. Die Auflage „coverage kept in small mips“ ist damit nicht erfüllt (Deckung 0,9–1,1 gefordert),
sichtbar als dunkle Querstreifen an den Haussmann-Fassaden bei 40–150 m und als Flimmern beim Übergang (5.5).

### 5.7 Umriss gegen das Sprite (`k4_scene --mode=outline2`, Sprite-Kamera −20°, 6°; Bild 26)

IoU lod0 / lod1: Grachtenhäuser A 0,999 / 0,999, Grachtenhäuser B 0,998 / 0,998, niederl. Reihenhäuser 0,997 / 0,997,
belg. Reihenhäuser 0,998 / 0,998, Maashaus 0,998 / 0,998, Loire-Haus 0,952 / 0,950, Südhaus 0,961 / 0,963, Lyoner
Haus 0,996 / 0,996, Haussmann 0,996 / 0,996, Eckhaus 0,997 / 0,997, Chalet 0,945 / 0,945, Lauben 0,997 / 0,997 –
**bestätigt AS5a2** (0,945–0,999; Abweichungen bei Bäumen und der Chalet-Traufe). Proportionen, Geschosse, Dachformen,
Giebel und Fensterraster sind die des Sprites.

### 5.8 Tönung (`tint_scene`, Bild 27)

`city_dutch_terrace` × `#ead6cc` trifft das getönte Sprite im Farbton (angesehen) – bestätigt. Bis R7 die Tönung
auf Modell-Instanzen legt, stehen die 50 getönten Reihen im Ruhrgebiet ungetönt (etwas röter) da.

## 6. Was ich von den AS5a2-Angaben bestätige – und was nicht

| AS5a2 sagt | nachgeprüft mit | Ergebnis |
|---|---|---|
| Prüfer grün, 12 Sets mit Modell | `validate_models.py --report` auf der Kopie | **bestätigt** (`CHECK models OK`) |
| 1 336–6 518 Dreiecke lod0, 2 Aufrufe je Stufe | Prüferbericht | **bestätigt** (Grachtenhäuser B 3 625 / 1 545 statt 3 623 / 1 543 – unerheblich) |
| Archiv 0,93 MB Netze, 5,79 MB Texturen | `share.py` (deflate -9 wie `pck_report.py`) | **bestätigt** (0,94 / 5,82 MB) |
| Umriss IoU 0,945–0,999 | `outline2` | **bestätigt** (gleiche Zahlen, Bild 26) |
| Straßenwände ≥ 26 px/m, EG ≥ 40 px/m (Lauben bei 1,10: 39,8) | `texel_k5.gd` | **bestätigt für die Hauswände**; **nicht** für die Gartenmauern von Südhaus und Loire-Haus: 14–16 px/m statt der angegebenen „0,6 der Dichte“ (≈ 32) |
| Stufenwechsel 60 m: 9–18 % (Tag), 8–15 % (Nacht), +0,6 … +4,9 % | `--mode=lods` „Mittel“ | **bestätigt**; auf „Hoch“ (120 m) bis 22,6 % (Grachtenhäuser) – nicht gemessen von AS5a2 |
| Flimmern 2–5× Sprite (Haussmann 1,0 / 1,2 / 1,0 / 0,6 %) | `sparkcam` | **bestätigt**, beim Eckhaus bei 40–100 m 5–11×, bei Grachtenhäusern B bis 7× (5.5) |
| „Das Geländer wird zum Band, verschwindet nicht“ (±3 Stufen) | `mipcov.py`, `mipband.py` | **Deckung bestätigt** (Haussmann 1,16 / 1,55 / 1,96 / 2,74), **Helligkeit nicht**: vor hellem Stein wird das Band ab Mip 3 27–89 Stufen dunkler – die Geländer schließen sich (5.6) |
| Tönung: Albedo × `#ead6cc` = getöntes Sprite | `tint_scene` | **bestätigt** (Bild 27) |
| lod1 bei 200–250 m heller als das Sprite | `k6_scene --mode=lodcol` | **bestätigt, aber nicht lod1**: lod0 und lod1 werden gleich blass; es ist die Mip-Kette (5.4) |
| Schaufenster nachts dunkler als Arcade (124 gegen 207) | A/B Paris 22 Uhr | **bestätigt und genauer:** Paris km 387,9, 22 Uhr, Hoch – am Haussmann-Eckhaus leuchten die Wohnfenster in beiden Modi gleich (4,0 gegen 4,0 % der Fassadenfläche), die Bogenläden im Erdgeschoss aber nur auf 8,9 statt 24,4 % der Fläche und dunkler (Mittel (196,155,108) gegen (250,215,158)); bei 4 s an der Ladenflanke rechts: warme Pixel 3,7 gegen 19,7 % der Fläche, Helligkeit 149 gegen 203 (`py/litpx.py`, gemessen) |
| „Im Rennen bei Paris nicht auffällig“ (Fernbild) | A/B an fünf Ankünften | **teilweise bestätigt:** im Rennen ist die Blässe schwächer als in der Prüfszene (Dunst, Gegenlicht) – Paris und Bern lesen sich fern gut, etwas heller als Arcade; in Lyon zeigen die Fenster des Lyoner Hauses bei ≈ 150 m rosa-lila Flecken (Bild 13). Messbar ist sie überall (5.4) |
| Backzeiten 166–800 s, Determinismus, Gates, Arcade-Identität | – | nicht nachgemessen (Kritik ohne Neuexport und ohne Testlauf; die Kopie ist byte-gleich mit 3c5e37a ohne `.git`) |

## 7. Vertragsfragen und Bedarf bei anderen Paketen

1. **Zwei Zeichenaufrufe je Stufe gegen Geländer, Gartenbäume und Wandleuchten (§4.6.9, §4.6.3).** Ein Stadthaus
   mit Schmiedeeisen braucht `baked_cutout`; weil nur zwei Aufrufe erlaubt sind (`vpbr` + eine gebackene Klasse),
   liegt bei fünf der zwölf Modelle (907 Platzierungen) und bei zwei Modellen der Charge 1 die **ganze Fassade** in der
   Ausschneide-Klasse (`cull_disabled`, `discard`, auch in lod1). Dieselbe Grenze verhindert, dass ein Gartenbaum ein
   AS3-Baum (`leaves`) wird, wie die Qualitätsvorgabe es verlangt. Vorschlag: für Stadthäuser drei Oberflächen
   zulassen (`vpbr` + `baked` + `baked_cutout` oder `leaves`), lod1 immer ohne Ausschneide-Klasse – **oder** ein
   Anbau-Mechanismus im Requisiten-Bauer (R7: Modell nennt in `model.json` Anbauten wie `tree_oak@x,z,h`, der Bauer
   stellt das AS3-Modell dazu). Bitte um Entscheidung der Leitung vor AS5b (dort kommen mediterrane Gärten, Palmen,
   Oliven, Balkone).
2. **Mip-Kette der Ausschneide-Atlanten (§4.6.5, D23; offen seit KRITIK-5a1 K7).** Mit den Import-Mips (Box-Filter)
   ist „Deckung in kleinen Mips erhalten“ nicht erfüllbar: ohne `cut_fill` verschwanden die Geländer (Charge 1), mit
   `cut_fill` schließen sie sich (hier 1,5–4,2-fache Deckung ab Mip 2). Wer darf eine deckungserhaltende Mip-Kette in
   `bake.py`/den Import-Einstellungen bauen (oder Alpha-to-Coverage im Renderer, R7)? Ohne diese Entscheidung bleibt
   jede Ausschneide-Arbeit an Modellen Flickwerk.
3. **„Die Generatoren SIND das Aussehen“ gegen erfundene Flankenöffnungen.** AS5a2 hat – wie AS5aR1 – Fenster und
   Türen an Flanken gesetzt, die im Sprite blind sind und in Wirklichkeit Brandwände wären (Grachten- und Reihenhäuser).
   Für das Spiel ist das richtig (Bild 10/20: die Flanke ist im echten 3D die größte Fläche beim Vorbeifahren), aber
   es weicht vom Wortlaut ab. Die Zustimmung der Leitung, die KRITIK-5a1 erbat, sollte festgeschrieben werden (A-16
   oder ein neuer Punkt), damit AS5b nicht neu fragen muss.
4. **Fernbild (R7).** Die Fassaden aller zwölf Modelle werden zwischen 60 und 250 m 5–10 % heller und verlieren ihre
   dunklen Fenster (5.4) – unabhängig von der Stufe. R7 plant Fernbilder (Impostoren mit dem Relief des Sprite-Rigs,
   A-16). Wenn R7 ab etwa 200 m das Sprite-Bild des Sets zeigt, ist das Problem dort gelöst; dann müsste AS5a-N nur den
   Bereich 100–200 m (dunklere Fenster in den kleinen Mips) behandeln. Bitte R7 diese Grenze nennen lassen.
5. **Überblenden der Stufen (A-16 nur für Bäume).** Stadthäuser wechseln bei 60 m 9–18 % der Pixel, auf „Hoch“ bei
   120 m bis 23 %, nachts +3 bis +5 % Helligkeit. Bitte R7 das Dither-Überblenden auch für `building`/`city` geben.
6. **Nachtlicht der Schaufenster (A-16: „emit_energy 1.6 gegen Arcade abgeglichen“).** Die Wohnfenster sind
   abgeglichen, die Auslagen nicht (AS5a2 gemessen 124 gegen 207, siehe K1). Weil die Formel in `cities3d._display_mat`
   beide Chargen trägt, braucht die Korrektur einen Neu-Export aller 23 Stadthäuser – die Leitung sollte das der
   Nacharbeit AS5a-N zusammen mit K2–K4 geben, damit nur einmal neu gebacken wird.

## 8. Für die Nacharbeit und die anderen Pakete – in dieser Reihenfolge

1. **Leitung:** die Vertragsfragen 1 (drei Oberflächen oder Anbauten für Stadthäuser) und 2 (deckungserhaltende
   Mip-Kette) entscheiden, **bevor** AS5b mit mediterranen Gärten und Balkonen beginnt; Flankenöffnungen (Frage 3)
   festschreiben.
2. **AS5a-N (ein Neu-Export für beide Chargen, 23 Stadthäuser):** K1 Schaufenster nachts auf Arcade-Niveau
   (`_display_mat`), K2 Fernfenster (vorgefilterte Fensterregion der kleinen Mips oder Fernfenster-Kachel in lod1),
   K3 Gartenbaum und Gartenmauer von Südhaus/Loire-Haus, K4 Geländer in lod1 als gemaltes Band (lod1 ohne
   `baked_cutout`), K7 Geranien, K9 eine Eingangsleuchte je Haus; dann K8 und die lod1-Ersparnis (K10).
3. **Import/`bake.py` (Freigabe nötig):** deckungserhaltende Mips für `baked_cutout` (K4).
4. **R7:** Überblenden für Gebäude (K5), Fernbild ab ≈ 200 m (K2), Tönung der Modell-Instanzen (K10), Anbauten für
   Gartenbäume (Vertragsfrage 1).
5. **R4:** Sonnenseite heller Putz- und Steinfassaden gegen Arcade abgleichen (+15–20 % in Paris und Amsterdam, K10).
6. **RINT-M2:** FIX-M2 B-01 (Kurvenkorridor nur Vegetation) mergen und Lyon km 297,4 / Bern km 302,7 als A/B
   wiederholen – dort fehlen heute ganze Häuser.
7. **R6 / RINT-M2:** die Szenerie-Zäune `fence` (hier `style: "wall"` der Brüsseler Vororte, `#9c7466`, 0,9 m) zeichnet
   erst der Bauer `city` von R6, der in diesem Stand fehlt; nach dem Zusammenbau Brüssel km 196 als A/B wiederholen.

## 9. Bilder und Filme (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `01_rennen_paris_mittag.jpg` | Paris km 387,5, Hoch, 12 Uhr, +2 s / +4 s, Arcade links, Modern rechts |
| `02_rennen_paris_nacht.jpg` | Paris, 22 Uhr: Wohnfenster wie Arcade, Läden dunkler (K1) |
| `03_rennen_amsterdam_mittag.jpg`, `07_rennen_amsterdam_nacht.jpg` | Amsterdam km 357,3, 12 und 22 Uhr |
| `04_rennen_bruessel_mittag.jpg`, `09_rennen_bruessel_daemmerung_mittel.jpg` | Brüssel km 195,5, 12 Uhr Hoch, 19:30 Mittel |
| `05_rennen_lyon_mittag.jpg` | Lyon km 297,0, 12 Uhr (+2 s: Haus im Kurvenkorridor entfallen) |
| `06_rennen_bern_mittag.jpg`, `08_rennen_bern_nacht.jpg` | Bern km 302,3, 12 und 22 Uhr |
| `11_rennen_lyon_vorort_mittag.jpg`, `12_rennen_amsterdam_vorort_mittag.jpg` | Vororte: Südhäuser, niederländische Reihenhäuser |
| `13_rennen_fernfassaden_ausschnitt.jpg` | Ausschnitte: Lyoner Haus fern mit rosa-lila Fenstern (K2), Bern Lauben |
| `10_abstaende_{paris,dutch,belgian,french,swiss}_{mittag,daemmerung,nacht}.jpg` | Spielkamera 10 / 30 / 100 / 250 m, je Modell eine Zeile, darunter der Arcade-Platzhalter in gleicher Lage (Hoch). Der Platzhalter der Prüfszene zeigt nachts kein Fensterlicht – Licht nur im Rennen vergleichen |
| `20_nahansichten_*_tag.jpg`, `21_nahansichten_*_nacht.jpg` | Straßenflanke, schräg, vorn, hinten (lod0, Hoch) |
| `25_stufenwechsel_G{1,2,3}_mittel_{tag,nacht}.jpg` | lod0 / lod1 bei 60 m, lod1 und Sprite bei 200 m (K5) |
| `26_umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera |
| `27_toenung_reihenhaeuser_ead6cc.jpg` | Modell, Modell × Tönung, Sprite × Tönung, Sprite |
| `28_flimmern_messbild.jpg` | Messbild der Flimmermessung (K4, K6) |
| `29_fern_250m_blass.jpg` | lod0 bei 60 m, lod0 / lod1 / Sprite bei 250 m (K2) |
| `30_mangel_gartenbaum_suedhaus.jpg` | Südhaus: Klumpen-Krone von der Straße, 30 m Modell gegen Sprite (K3) |
| `31_mangel_geranien_chalet.jpg` | Chalet: Geranien als Kugelkette (K7) |
| `32_mangel_rueckseite_eckhaus.jpg` | Rückseiten Eckhaus (blank) und Haussmann-Block (K8) |
| `40_fahrt_amsterdam_50kmh_mittel.mp4` | Rennclip Amsterdam, 50 km/h, Mittel, 6 s, Arcade links, Modern rechts |
| `41_fahrt_amsterdam_standbilder.jpg`, `42_fahrt_amsterdam_folgebilder.jpg` | Standbilder 1/3/5 s; vier Folgebilder (Flimmern) |
| `43_pruefstrasse_paris_50kmh_modell_gegen_sprite.mp4`, `44_pruefstrasse_paris_folgebilder.jpg` | Prüfstraße Paris, 50 km/h, Modell links, Arcade-Platzhalter rechts; Folgebilder |
| `bericht.md` | dieser Bericht |
