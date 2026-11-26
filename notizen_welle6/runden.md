# Welle 6 – Runden-Notizen (Leitung)

## AS5b C1

### props/city_eastern_plattenbau – Runde 1 (Export 206 s, lod0 4.433 / lod1 1.390 Dreiecke, glb 422 kB)
- Tag 10/30 m: Fenster mit Rahmen und Sprossen, Plattenfugen, Loggien mit Platten und farbigen Brüstungen (vpbr) und
  Schatten, Schüsseln – deutlich feiner als das unscharfe Sprite. 100/250 m: Farben, Geschosse, Loggien-Rhythmus wie
  Sprite; das Sprite zeigt schräg die Seitenwand (Gierung −20°), das Modell aus der Straße fast frontal.
- Nacht: alle Loggien warm wie die Lichtebene des Sprites (die leuchtet jede Loggia, sprite_sheet.png), dazu einzelne
  Fenster und das Treppenhaus – wie Arcade. prop_scene zeigt beim Sprite keine Lichtebene (Werkzeug, kein Befund).
- Stufenwechsel 60 m: 5,4 % Pixel, Helligkeit −1,0 % (gut). Fernbild 200 m 23 % heller als das Sprite (Sprite mit
  schattiger Flanke im Bild) – im Rennen A/B ansehen.
- Urteil Runde 1: gut; offen: A/B im Rennen (Leipzig/Magdeburg-Rand, Warschau), Tönung keine.

### props/city_vienna_zinshaus – Runde 1 (Export 298 s, lod0 6.155 / lod1 3.475, glb 703 kB)
- Tag: Stuck-Ädikulen, Giebel und Gesimse mit Tiefe (vpbr), Fenster mit Rahmen und Kämpfer, Ladenportale aus dunklem
  Holz mit Bücherregalen dahinter, rote Markise, Eckerker mit Kupferkuppel und echten Fenstern – deutlich feiner als
  das Sprite; 100/250 m Umriss, Dach mit Gauben, Kuppel und Farben wie Sprite.
- Nacht: einzelne Fenster warm und unregelmäßig, Läden hell mit Auslage, Erkerfenster – wie Arcades Lichtebene.
- Stufenwechsel 60 m: 17,7 % Pixel (Tag) / 12,3 % (Nacht), Helligkeit −1,1 / +2,4 % (im Bereich von AS5a; der
  Renderer blendet über 0,5 s mit Dither).
- Urteil Runde 1: gut.

### props/city_spanish_casa – Runde 1 (Export 155 s, lod0 2.744 / lod1 1.403, glb 268 kB)
- Tag: Orangenbaum auf Blattkarten mit Früchten (liest sich als Baum), Rejas und Balkongeländer als Eisenstäbe,
  Gartenmauer mit Tor, Geranien, Ocker-Rahmen – feiner als das Sprite. Nacht: 2 Fenster wie die Lichtebene des Sprites.
- MANGEL M1: ab ~100 m werden Rejas und Balkon zu hellgrauen Kästen (Lückenfarbe cut_fill #b9b2a2 mischt sich in den
  kleinen Mips mit dem schwarzen Eisen) – das Sprite zeigt dunkle Gitter. Fix: cut_fill #3d3b38 (dunkles Fenster
  dahinter). Neu-Export in Runde 2. Gleiches bei den anderen Geländer-Sets prüfen.

### props/city_spanish_block – Runde 1 (Export 302 s, lod0 8.287 / lod1 4.692, glb 849 kB)
- Tag: Eisenbalkone vor jedem Fenster (ausgeschnitten), grüne Rollos, Klimageräte und Pflanzen, Platten mit Schatten,
  Läden mit Regalen und Kleiderstangen, Penthouse mit Ziegeldach – deutlich feiner als das Sprite. 100 m: Balkone als
  dunkle Reihen (Lückenfarbe #8f8470 reicht hier, die Stäbe sind dicht), 250 m wie Sprite.
- Nacht: einzelne Fenster warm, Läden hell mit Auslage. Urteil Runde 1: gut, kein Neu-Export nötig.

### props/city_italian_block – Runde 1 (Export 275 s, lod0 6.238 / lod1 2.810, glb 618 kB)
- Tag: grüne Persiane mit Lamellen, Eisenbalkone (ausgeschnitten), Blumenkästen, gestreifte Markisen, Läden mit
  Regalen, Sparren unter dem tiefen Dachüberstand – deutlich feiner als das Sprite; 100/250 m wie Sprite.
- Nacht: einzelne Fenster warm, Läden hell mit Auslage. Stufenwechsel 60 m: Tag 13,9 % Pixel, Helligkeit −2,2 %; Nacht 11,7 %, +1,8 %
- Urteil Runde 1: gut.

### props/city_vienna_palais – Runde 1 (Export 252 s, lod0 6.999 / lod1 4.049, glb 828 kB)
- Tag: Rustika-Sockel mit Rundbogenfenstern, Kolossalpilaster und Gesimse in Weiß (vpbr) mit Tiefe, Giebel mit
  vergoldetem Wappen, Attika mit Figuren, Kupferdach – feiner als das Sprite. Frontal sieht man vom Dach nur die Kante
  (das Sprite zeigt es von schräg oben, 6° Elevation) – Eigenschaft der Spielkamera, kein Fehler.
- Nacht: einzelne Fenster warm und unregelmäßig. Urteil Runde 1: gut.

### props/city_italian_palazzo – Runde 1 (Export 274 s, lod0 5.170 / lod1 3.159, glb 660 kB)
- Tag: Rustika-Sockel mit Rundbogenportal (Holztor), Piano nobile mit wechselnden Giebeln, Balkon mit Balustern
  (ausgeschnitten) auf Konsolen, grüne Läden, tiefes Cornicione, Kamine – feiner als das Sprite; 100/250 m wie Sprite.
- Nacht: einzelne Fenster warm. Urteil Runde 1: gut.

### props/city_spanish_ladrillo – Runde 1 (Export 385 s, lod0 7.107 / lod1 5.353, glb 859 kB)
- Tag: Ziegel mit Steingewänden und Giebeln (vpbr), Eisenbalkone (ausgeschnitten), Läden mit Regalen, Schiefer-
  Mansarde mit Gauben, der Eckturm mit Schieferhelm – feiner als das Sprite; 100/250 m wie Sprite.
- Nacht: einzelne Fenster warm, Läden hell. Urteil Runde 1: gut.

### props/city_italian_venezia – Runde 1 (Export 338 s, lod0 3.408 / lod1 1.229, glb 292 kB)
- Tag: venezianisches Rot mit gotischen Spitzbogenfenstern in weißem Istrischem Stein (vpbr), Polifora mit
  Balustradenbalkon, ockerfarbenes Haus mit grünen Läden und Eisenbalkonen, Wassertor, Trichterkamine – feiner als
  das Sprite; 100/250 m wie Sprite.
- Nacht: einzelne Spitzbogenfenster warm. Urteil Runde 1: gut.

### props/city_vienna_kirche – Runde 1 (Export 350 s, lod0 4.469 / lod1 3.416, glb 471 kB)
- Tag: Zwillingstürme mit Kupferhauben, Säulenportikus mit Giebel, geschwungener Giebel, Kuppel mit Laterne,
  vergoldete Kreuze; 100/250 m Umriss wie Sprite (das Sprite zeigt zusätzlich das Langhaus schräg).
- Aus der niedrigen Spielkamera verdeckt der geschwungene Giebel den Tambour fast ganz (Geometrie des Generators wie
  im Sprite; das Sprite sieht von 6° oben darüber); lod1 bei 250 m: kleine dunkle Flecken der Tambourfenster – klein.
- Nacht: einzelne Fenster warm. Stufenwechsel 60 m: 3,8 % / 1,4 % Pixel (sehr ruhig). Urteil Runde 1: gut, Notiz
  Tambour (niedrig).

### props/city_spanish_casa – Runde 2 (cut_fill #3d3b38, Export 151 s, Dreiecke unverändert)
- M1 behoben: Balkon und Rejas aus 100 m dunkles Eisen wie im Sprite statt grauer Kästen
  (shots/r2_spanish_casa/vorher_nachher_100m.png).

### props/city_central_jugendstil – Runde 1 (Export 283 s, lod0 4.787 / lod1 1.281, glb 433 kB)
- Tag: Rundbogenfenster, Fliesenbänder in Türkis und Gold, runder Ziergiebel mit Goldmosaik, Kupfermansarde, Läden
  mit Bücherregalen in Rundbögen – feiner als das Sprite. Nacht: einzelne Fenster, Läden hell.
- MANGEL M2: die halbrunden Gitterbalkone (Gitter „lattice“ vor heller Wand) werden ab 30 m zu schwarzen Blöcken, das
  Sprite zeigt sie hell und zart. Ursache: dunkle Lückenfarbe (#4a4640) – die Lücken wiegen 0,4 in den Mips. Fix:
  Lückenfarbe = beschattete Wandfarbe #cfc5ab (auch bj/bhb/bw/bwb vor ihrem Export angepasst). Neu-Export in Runde 2.

### props/city_central_barock – Runde 1 (Export 350 s, lod0 4.537 / lod1 2.900, glb 542 kB)
- Tag: Volutengiebel, weiße Pilaster und Segmentgiebel über den Fenstern (vpbr), Hauszeichen, rote Ziegeldächer,
  Kamine – feiner als das Sprite; 100/250 m wie Sprite. Nacht: einzelne Fenster warm.
- Klein: das vergoldete Hauszeichen bei 10 m facettiert (8 Kanten) – smooth=("cba_sign",), Runde 2.

### props/city_central_eckturm – Runde 1 (Export 285 s, lod0 3.961 / lod1 1.941, glb 446 kB)
- Tag: Zsolnay-Dach mit Rautenmuster, Eckturm mit Ziegelhelm und vergoldeter Spitze, Fenstergiebel und Sohlbänke,
  Läden mit Bücherregalen – feiner als das Sprite; 100/250 m wie Sprite. Nacht: Fenster und Turmfenster warm,
  Läden hell. Urteil Runde 1: gut.

### props/city_eastern_house_a – Runde 1 (Export 184 s, lod0 8.170 / lod1 6.980, glb 853 kB)
- Tag: Würfelhaus mit Walmdach, Balkon über dem Vorbau, Zaun mit verputzten Pfosten und dunklen Stäben, Apfelbaum auf
  Blattkarten mit Äpfeln – feiner als das Sprite. Der Schuppen steht hinter dem Baum (frontal verdeckt, im Sprite
  schräg sichtbar) – Geometrie wie im Generator.
- NOTIZ N1 (Leistung): lod1 spart kaum (6.980 von 8.170) – der Zaun mit einzelnen Stäben (Art „metal“, Teilung 0,14 m)
  und die Blattkarten bleiben in lod1. Im Budget (10.000), aber das Haus steht in den Vororten von eastern und
  central oft; für PERF merken (Zaun in lod1 als ausgeschnittene Fläche).

### props/city_eastern_house_c – Runde 1 (Export 205 s, lod0 5.220 / lod1 3.070, glb 592 kB)
- Der Ausreißer des Vertrags (23.000 Garten-Dreiecke im Generator) ist auf 5.220 / 3.070 gesunken: Thujen auf 12 %
  (lod1 40 %), Gartenbaum auf Blattkarten.
- Tag: Lachsputz mit weißem Feld, anthrazitfarbene Fenster mit Rollläden, Garage mit Dachterrasse und Geländer,
  Bretterzaun zwischen verputzten Pfosten – feiner als das Sprite; 100/250 m wie Sprite. Urteil Runde 1: gut.

### props/city_eastern_house_b – Runde 1 (Export 203 s, lod0 4.029 / lod1 2.836, glb 452 kB)
- Tag: hellgrüner Putz, Giebel zur Straße mit Dachfenstern, rotes Blechdach, Vorbau, grüner Lattenzaun, Blumenbeet,
  Brunnen mit Dach, Birke auf Blattkarten mit weißem Stamm – feiner als das Sprite; 100/250 m wie Sprite.
- Urteil Runde 1: gut.

### props/city_balkan_house – Runde 1 (Export 124 s, lod0 3.364 / lod1 2.734, glb 295 kB)
- Tag: verputztes Erdgeschoss, rohes Hohlziegel-Obergeschoss im Betonrahmen, Bewehrungseisen auf der Decke (vpbr,
  lod0), das leere Fensterloch, Pergola mit Weinlaub, Gartenmauer mit rotem Tor – feiner als das Sprite.
- Urteil Runde 1: gut.

### props/city_balkan_house_b – Runde 1 (Export 166 s, lod0 6.462 / lod1 5.360, glb 702 kB)
- Tag: Pfirsichputz, die weiße Balustrade über die ganze Front (ausgeschnitten, Lückenfarbe Wand – aus 100 m weiß wie
  im Sprite), rotes Walmdach, unverputzte Ziegel-Straßenseite, Schmiedeeisenzaun auf weißen Pfosten, Feigenbaum auf
  Blattkarten, Rosen – feiner als das Sprite. lod1 spart wenig (Zaunstäbe, Baluster) – wie N1.
- Urteil Runde 1: gut.

### props/city_balkan_plattenbau – Runde 1 (Export 192 s, lod0 7.628 / lod1 1.888, glb 665 kB)
- Tag: roher Beton mit Balkonbändern, verglaste Loggien unregelmäßig verteilt, Klimageräte und Schüsseln, Läden im
  Erdgeschoss mit roten Schildern und Regalen – feiner als das Sprite; 100/250 m: Geschosse und Rhythmus wie Sprite
  (das Sprite schräg mit Seitenwand, das Modell frontal).
- Nacht: viele unregelmäßig erleuchtete Fenster und Loggien, Läden hell – wie Arcade-Lichtebene (Werkzeug zeigt
  beim Sprite keine Lichtebene).
- Stufenwechsel 60 m: 8,5 % Pixel, Helligkeit −1,2 % (Nacht 7,0 %, +0,7 %) – gut. Fernbild/Sprite −25 % wie beim
  eastern_plattenbau (Sprite mit schattiger Flanke) – im Rennen A/B (Sofia/Belgrad/Bukarest).
- Urteil Runde 1: gut.

### props/city_baltic_jugendstil – Runde 1 (Export 330 s, lod0 3.874 / lod1 1.399, glb 460 kB)
- Tag: hellblauer Putz, weiße Lisenen, Fenster mit Sprossen und Rahmen, Rundbogenläden mit Bücherregalen im hellen
  Steinsockel, Mansarde mit rundem Ziergiebel – feiner als das Sprite; 100/250 m Umriss und Farben wie Sprite.
- Nacht: einzelne Fenster warm, Läden hell mit Auslage.
- Stufenwechsel 60 m: 11,6 % Pixel, Helligkeit −0,7 % (Nacht 9,0 %, +2,3 %) – im Bereich von AS5a.
- Urteil Runde 1: gut.

### props/city_baltic_wood – Runde 1 (Export 283 s, lod0 6.080 / lod1 4.512, glb 639 kB)
- Tag: ockerfarbene Stülpschalung mit Brettstruktur, weiße Eckbretter und Fensterverdachungen, rotes Dach, Giebel mit
  Balkon und Balustrade (Lückenfarbe Wand – aus 100 m hell wie im Sprite), verglaste Veranda, Flieder auf
  Blattkarten, Lattenzaun – feiner als das Sprite.
- Nacht: fast alle Fenster warm, Veranda hell.
- Stufenwechsel 60 m: 10,1 % Pixel, −1,0 % (Nacht 7,6 %, +1,4 %). lod1 spart wenig (Zaun, Blattkarten) – wie N1.
- Urteil Runde 1: gut.

### props/city_baltic_wood_b – Runde 1 (Export 184 s, lod0 3.975 / lod1 3.057, glb 487 kB)
- Tag: grüne Stülpschalung, weiße Rahmen und Verdachungen, Schieferdach, Giebelbalkon (Wandfarbe als Lücke, hell),
  Vordach über der Tür, Birke auf Blattkarten, weißer Lattenzaun – feiner als das Sprite. Die Birkenkrone wirkt aus
  10 m etwas licht (Karten erkennbar) – wie die AS3-Birken, kein Befund.
- Nacht: einzelne Fenster warm. Stufenwechsel 60 m: 10,3 % Pixel, −1,2 % (Nacht 6,2 %, −0,5 %).
- Urteil Runde 1: gut.

### Runde 2 (queue_r2, 18:34–18:48)
- central_jugendstil (Export 305 s, Zahlen gleich): M2 BEHOBEN – die Gitterbalkone sind aus 30/100/250 m hellgrau
  und durchbrochen statt schwarz, nah am Sprite. Stufenwechsel 16,5 % Pixel, −0,8 % (Nacht 12,7 %, +1,8 %).
- central_barock (Export 352 s): Ergebnis byte-gleich zu Runde 1 – der Generator legt das Hauszeichen schon glatt an
  (`mk(..., smooth=True)` in props_cities); die acht Kanten aus 10 m sind der Umriss der achteckigen Scheibe. Klein,
  nur aus der Nähe; bleibt. Der Katalogeintrag smooth=("cba_sign",) ist damit wirkungslos – in der Nacharbeit
  entfernen.

## Rennen A/B (ab_c1, Arcade | Modern, gleicher Simulationszustand, high)
- warschau_zentrum (12 Uhr): Plattenbauten und Zentrum als Modelle – feiner, Maßstab und Farben wie Arcade. Gut.
- warschau_nacht (22 Uhr): Loggien und Fenster warm, Läden hell. Gut. Fassaden heller als Arcade (gemessen linke
  Fassade Median 63 gegen 41).
- leipzig_rand (12 Uhr, 2 Bilder): Vorstadthäuser, Mietshaus mit Balkonen, Wahrzeichen und Hochhaus an derselben
  Stelle wie Arcade; Modern mit Gehweg, Hecken, Schatten. Gut.
- wien_zentrum (12 Uhr): Zinshäuser und Palais als Modelle, Stuck mit Tiefe. Gut.
- wien_nacht (22 Uhr): Straßenschlucht mit Laternen, Läden hell, Bäume. Gut. BEOBACHTUNG B-N1: die hellgelben
  Zinshausfassaden sind nachts 1,7 × so hell wie Arcade (Median 59 gegen 35; rechts 77 gegen 45), obere Geschosse des
  nahen Hauses mit weniger leuchtenden Fenstern als das Sprite. Ursache ist das Lichtgesetz (docs/renderer-modern.md
  9.6: helle Albedo nachts bis +27 % über Albedo × Umgebung, das Sprite hat zusätzlich eingebackene Schattierung) –
  keine Modellfrage; Renderer-Look wartet auf die Rückmeldung zu Gate 2. Für den Bericht als Frage an den Nutzer.
- linz_zentrum (12 Uhr, 2 Bilder): Brücke, dann Zinshaus mit Eckerker und Kupferkuppel, Palais – Umriss, Dach, Kuppel
  und Farben an derselben Stelle wie Arcade, Modern mit Laibungen, Markise und Läden. Dom als Bild in beiden. Gut.

### props/city_balkan_church – Runde 1 (Export 581 s, lod0 3.944 / lod1 3.154, glb 261 kB)
- Tag: serbisch-byzantinischer Bau aus rotem Ziegel mit hellen Bändern (Ziegelstruktur ab 10 m lesbar), Rundbogenfenster
  mit Steinrahmen, Holztür, Glockenturm mit Zwiebelhaube, Tambourkuppeln, Kreuze – feiner als das Sprite. 100/250 m:
  Umriss und Farben wie Sprite (Sprite schräg mit Seitenschiff und Hauptkuppel, Modell frontal mit dem Turm davor).
- Nacht: Fenster warm erleuchtet, Tür dunkel – wie Arcade (Lichtebene im Werkzeug nicht sichtbar).
- Stufenwechsel 60 m: 6,0 % Pixel, Helligkeit ±0 % (Nacht 2,9 %, +0,8 %) – gut. lod1 spart wenig (Kuppeln, Bögen) –
  bei 13 Platzierungen ohne Belang.
- Urteil Runde 1: gut.
- madrid_zentrum (12 Uhr, 1 Bild – das zweite fiel ins Zeitlimit von ab_shot, 600 s auf llvmpipe neben einem
  Blender-Export; ab 26.11. AB_TIMEOUT 1200): spanische Blöcke mit Balkongittern, Läden mit Auslage, Palmen – an
  derselben Stelle wie Arcade, deutlich feiner. Gut.
- madrid_rand (12 Uhr, 2 Bilder): weiße Casa mit Orangenbaum und Gartenmauer, Blöcke mit Balkonen, Ziegelhaus mit
  Turmspitze, Hochhäuser als Bild – Farben und Maßstab wie Arcade. Gut.
- mailand_zentrum (12 Uhr, 1 Bild): ockerfarbene Blöcke mit grünen Läden und gestreiften Markisen, Palazzo links,
  Dom als Bild rechts – wie Arcade, feiner. Gut.
- (wien_zentrum und wien_nacht ebenfalls nur 1 Bild – gleiche Ursache.)

## AS6 Wahrzeichen (views_lm: 80/250/600/1200 m, Tag 12 Uhr / Nacht 22 Uhr, Sprite darunter)

### landmarks/elbphilharmonie – L1 (Export 121 s, lod0 908 Dreiecke, glb 43 kB, nur eine Stufe)
- Tag: Backsteinsockel mit Fensterraster, Loggienband mit hellen Pfosten, Glaskörper mit Paneelmuster und den
  dunklen „Mund“-Fenstern, Wellenkante – Farben, Raster und Umriss wie das Sprite. Das Sprite zeigt zusätzlich die
  weißen Dachwellen; die sieht man nur von oben (Sprite mit 3° Blickhöhe und Drehung), aus Straßenhöhe verdeckt die
  Vorderkante sie – physikalisch richtig, kein Befund. Modell frontal, Sprite gedreht (Seitenwand sichtbar).
- Nacht: Glas mit vielen hellen Paneelen, Loggienband hell, Sockel mit verstreuten Fenstern – genau das Muster der
  Lichtebene des Sprites (Sprite-Blatt angesehen, m1/W6/tmp/elb_sprite.png); die Paneele des Modells sind blockiger
  (quadratische Zellen statt senkrechter Streifen). Prüfen: Render-Prüfung „nacht_hell“ (Fassade 22 Uhr 0,8–1,1 ×
  Arcade) misst jetzt das Modell – in den Toren laufen lassen.
- Urteil L1: gut; offen: nacht_hell, A/B Hamburg Tag/Nacht.

### landmarks/kaiserburg_nuernberg – L1 (Export 146 s, lod0 1.016, glb 69 kB, eine Stufe)
- Tag: Sandsteinburg auf dem Felssockel, Zinnenmauer, Palas und Kaiserstallung mit roten Dächern, Sinwellturm mit
  hellem Holzumgang, Türme – Umriss, Proportion und Farben fast deckungsgleich mit dem Sprite. Aus 80 m ist der
  Sandstein glatt (32 px/m, kein Fugenbild) – das Sprite aus 80 m ist genauso weich; Wahrzeichen stehen ≥ 60 m weg.
- Nacht: Mauern warm angestrahlt, Fenster von Palas und Stallung erleuchtet – die Anstrahlung kommt aus dem
  Emissionsatlas (Lichtebene des Generators). Helligkeit gegen Arcade im Rennen prüfen (A/B Nürnberg Nacht fehlt in
  ab_lm1 – nachtragen).
- Urteil L1: gut.

### Zwischenprüfung validate_models --only=props/city_* (26.11. 05:50)
- FEHLER props/city_eastern_house_c: lod1_body.res[baked_cutout] 89 von 3060 Dreiecken gegen ihre Normalen gewickelt
  (Grenze 8). Ursache: lod1_decimate 0,4 auf die schon mit 0,12 dezimierte Thujen-Hecke kippt dünne Dreiecke. Fix:
  Thujen in lod1 nicht noch einmal dezimieren (Katalog, Commit „Thujen …“); Runde 2 über queue_r3.sh nach L1, danach
  validate. Alle anderen 45 Stadthäuser ohne Befund.
- mailand_nacht (22 Uhr, 2 Bilder): Blöcke mit warmen Fenstern und hellen Läden unter den Markisen, Laternen, Dom als Bild
  angestrahlt rechts – wie Arcade, Modern mit Tiefe (Balkone, Läden). Gut.
  Bild 01: naher Mailänder Block links nachts heller als Arcade (Median 44 gegen 27, 1,6 ×) – wie B-N1.
  Nachtrag: Lichtebene des Sprite-Blatts angesehen (tmp/sheet_kaiserburg_nuernberg.png) – Mauern warm angestrahlt,
  Fenster hell, wie das Modell.

### landmarks/dom_fulda – L1 (Export 493 s, lod0 4.560, glb 221 kB, eine Stufe)
- Tag: barocke Doppelturmfassade mit roten Sandsteingliedern auf weißem Putz, Kupferhauben mit Laternen, Giebel,
  Vierungskuppel mit Laterne dahinter, Seitenschiff – Gliederung und Farben wie das Sprite (Sprite gedreht mit
  Langhaus und großer Kuppel, Modell frontal: Kuppel hinter dem Giebel, aus 600/1200 m sichtbar).
- Nacht: Fassade warm angestrahlt, Hauben dunkel – genau die Lichtebene des Sprite-Blatts (tmp/sheet_dom_fulda.png).
  Die Anstrahlung ist kräftig (Fassade fast tageshell); Helligkeit gegen Arcade im Rennen prüfen (A/B Fulda Nacht
  nachtragen).
- Urteil L1: gut.
- venedig_zentrum (12 Uhr, 2 Bilder): Damm über die Lagune, dann Palazzo mit Rustika und Balkon, Mailänder Blöcke mit
  grünen Läden und Markisen, venezianische rote Häuser mit gotischen Fenstern in Istrischem Stein – an derselben
  Stelle wie Arcade, Modern mit Tiefe und Schatten. Gut.

### landmarks/koelner_dom – L1 (Export 579 s, lod0 11.900, glb 833 kB, eine Stufe + Godot-LOD)
- Tag: Doppelturmfassade mit Maßwerkhelmen, Kreuzblumen, Fialen, Portale, dunkler verwitterter Stein, Vierungsturm
  dazwischen – Umriss und Gliederung wie das Sprite, aus 600/1200 m die Silhouette der Helme sauber. Ein heller Fleck
  an der rechten Turmflanke (halb vor dem Himmel) steht genauso im Sprite – Geometrie des Generators, kein Modellfehler.
- Nacht: Fassade warm angestrahlt, Stern auf dem Vierungsturm hell – wie die Lichtebene des Sprite-Blatts
  (tmp/sheet_koelner_dom.png).
- Größtes L1-Modell (11.900 Dreiecke, 833 kB) – Budget im Validator prüfen.
- Urteil L1: gut.

### landmarks/frauenkirche_dresden – L1 (Export 294 s, lod0 4.124, glb 274 kB)
- Tag: heller Sandstein mit den dunklen alten Steinen als Flecken, Steinerne Glocke, vier Ecktürme, Laterne mit Kreuz,
  Fensterreihen – wie das Sprite (auch die schräge Stange vor den Fenstern steht im Generator). Modell frontal, Sprite
  gedreht.
- Nacht: warm angestrahlt, einzelne Fenster hell, Kreuz golden – wie die Lichtebene des Sprite-Blatts.
- Urteil L1: gut.
- bordeaux_rand (12 Uhr): Südhäuser mit Gartenmauern, Zypressen, Blöcke in der Ferne – wie Arcade. Gut.
- ab_c1 vollständig (12 Stellen, 06:11). C1 abgeschlossen.

### landmarks/frauenkirche_muenchen – L1 (Export 233 s, lod0 1.782, glb 79 kB)
- Tag: Backstein-Doppeltürme mit den grünen Welschen Hauben, Schallfenster, Mittelgiebel, helles Gesimsband, Portal
  – Farben und Proportion wie das Sprite (Modell frontal: Langhaus und großes Dach liegen hinter der Fassade; im
  Rennen schräg sichtbar). Der Backstein des Modells etwas heller/röter als das Sprite.
- Nacht: angestrahlt, Schallfenster hell, Kugeln golden – wie die Lichtebene des Sprite-Blatts.
- Urteil L1: gut.

## Rennen A/B C2 (ab_c2)
- prag_zentrum (12 Uhr, 2 Bilder): Steinbrücke mit Laternen, dann die Barockhäuser (rosa, gelb, Volutengiebel,
  Hauszeichen) – an derselben Stelle wie Arcade, Modern mit Gesimsen, Laibungen und Schatten; Veitsdom noch als Bild
  (L2). Gut.

### landmarks/st_petri_riga – L1 (Export 201 s, lod0 1.308, glb 91 kB)
- Tag: Backsteinkirche mit langem Schiff, grünem Kupferdach und dem barocken Turmhelm mit zwei Galerien und Hahn –
  fast deckungsgleich mit dem Sprite (beide seitlich).
- Nacht: Backstein angestrahlt, Galeriefenster hell, Hahn golden – wie die Lichtebene des Sprite-Blatts.
- Urteil L1: gut.

### landmarks/fernsehturm_berlin – L1 (Export 142 s, lod0 4.548, glb 163 kB)
- Tag: konischer Betonschaft mit Schalungsfugen, Kugel mit dunklem Fensterband, rot-weiße Antenne, Pavillon mit den
  gefalteten Dächern – Proportion und Farben wie das Sprite, aus 1200 m die schlanke Silhouette sauber.
- Nacht: Fensterband der Kugel und Pavillon hell, Antenne rot-weiß – wie die Lichtebene des Sprite-Blatts.
- Urteil L1: gut.
- prag_nacht (22 Uhr, 2 Bilder): Barockhäuser mit warmen Fenstern, Laternen auf der Brücke, Kaimauer – wie Arcade;
  Fassaden heller als Arcade (B-N1: Median 55 gegen 34, 1,6 ×).

### landmarks/frankfurt_skyline – L1 (Export 338 s, lod0 1.936, glb 122 kB)
- Tag: sechs Türme – Westend-Turm mit Krone, Messeturm (roter Granit, Pyramide), Kronenhochhaus, Zwillingsscheibe,
  Main Tower mit Antenne, Commerzbank mit grünen Gärten und Antenne – Reihenfolge, Höhen und Farben wie das Sprite;
  Fensterraster aus 80 m scharf.
- Nacht: verstreute helle Büros, Pyramide und Krone hell, Commerzbank-Krone golden – wie die Lichtebene des
  Sprite-Blatts. Die roten Flugwarnlichter der Antennen (Lichtebene: rote Punkte) zeigt prop_scene nicht – im
  Rennen prüfen (A/B Frankfurt Nacht in ab_lm1).
- Urteil L1: gut.

### L1 vollständig (06:29): 9 von 9 gut. Offen: Render-Prüfungen nacht_hell/anstrahlung/flugfeuer, A/B ab_lm1.
- budapest_zentrum (12 Uhr, 2 Bilder): Schrägseilbrücke, Parlament noch als Bild (L3), dahinter die Barockhäuser mit
  Volutengiebeln am Kai – an derselben Stelle wie Arcade, Modern mit Kaimauer, Tiefe und Schatten. Gut.

### Budget nach L1 und house_c r2 (validate 06:34)
- Netze 22,97 / 40 MB, Texturen im Grafikspeicher 159,0 / 240 MB, Texturquellen 50,42 / 60 MB.
- L1-Wahrzeichen tragen je 0,19–1,26 MB Texturquellen (Mittel 0,42). 23 weitere mit 2048² wären ~10 MB → über 60 MB.
  Darum Atlas nach Größe (Commit „Atlasgröße der Wahrzeichen L2/L3“): groß 2048², mittel 2048×1024, schlank 1024².
  stephansdom lief schon mit 2048² (bleibt so, gehört zu „groß“).

### landmarks/stephansdom – L2 (Export 193 s, lod0 3.410, glb 242 kB, 2048²)
- Tag: das Zickzack-Ziegeldach in Grün, Gelb, Weiß und Schwarz, Südturm mit Helm und Maßwerk, Wimperge und Fialen
  über den Fenstern, Heidentürme – wie das Sprite (das grüne Dachreitertürmchen steht frontal hinter dem Turm).
- Nacht: angestrahlt, einzelne Fenster hell, Dach farbig – wie die Lichtebene des Sprite-Blatts.
- Urteil: gut.

### landmarks/riesenrad – L2 (Export 93 s, lod0 17.816, glb 1.331 kB, 2048×1024)
- Tag: echtes Gitter – Speichen als Geometrie, Ringe, A-Böcke, rote Gondeln, Glühlampen am Ring, Pavillon – aus
  80/250 m deutlich feiner als das Sprite. Ab 600 m wird die Speichenscheibe zum gepunkteten Gittermuster (dünne
  Geometrie unter einem Pixel), das Sprite zeigt dort nur Ring und dunkle Nabe. NOTIZ N2: in Bewegung flimmern die
  Speichen vermutlich – im Rennen prüfen (A/B Wien Riesenrad, ab_lm2). Größtes Netz bisher (17.816 von 25.000).
- Nacht: Lampenketten am Ring und an den Speichen, Gondeln und Pavillon hell – lebendiger als das Sprite.
- Urteil: gut, offen N2.
- budapest_rand (12 Uhr): Würfelhäuser mit Walmdach und Balkon, Zäune, Thujen, Plattenbau in der Ferne – an derselben
  Stelle wie Arcade, Modern mit Zaunstäben und Blattkarten-Bäumen. Gut.
