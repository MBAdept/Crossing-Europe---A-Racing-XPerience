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

(27.11. 11:01 Container war seit ~06:55 26.11. abgeschaltet – Inaktivität; Läufe laufen nur bei aktiver Sitzung.
 Alle vier Warteschlangen 11:02 neu gestartet.)

### landmarks/mariendom_linz – L2 (Export 587 s, lod0 5.888, glb 410 kB, 2048²)
- Tag: neugotischer Turm mit durchbrochenem Helm, Uhr, Fialen, grüne Kupferdächer, heller Kalkstein – wie das Sprite
  (frontal: Langhaus hinter der Fassade). Nacht: angestrahlt, Uhr hell – wie die Lichtebene. Urteil: gut.

### landmarks/dom_passau – L2 (Export 243 s, lod0 4.316, glb 211 kB, 2048×1024)
- Tag: weiße Doppelturmfassade mit grünen Zwiebelhauben, Vierungskuppel dahinter, Pilaster – wie das Sprite (Sprite
  schräg mit Langhaus). Nacht: angestrahlt, Hauben dunkelgrün – wie die Lichtebene. Urteil: gut.
- belgrad_zentrum (12 Uhr, 2 Bilder): Eckladen mit gestreifter Markise, Jugendstilhäuser mit Kupfermansarden – an
  derselben Stelle wie Arcade, Modern mit Fensterrahmen, Ladenschild und Tiefe. Gut.

### landmarks/dom_regensburg – L2 (Export 195 s, lod0 6.806, glb 472 kB, 2048×1024)
- Tag: gotische Doppelturmfassade mit durchbrochenen Helmen, Wimperg über dem Portal, Maßwerkfenster, Strebepfeiler
  – wie das Sprite (frontal: das grüne Dach liegt hinter der Fassade). Nacht: angestrahlt wie die Lichtebene.
- Urteil: gut.

### landmarks/veitsdom_prag – L2 (Export 107 s, lod0 1.718, glb 111 kB, 2048×1024)
- Tag: Burgpalast mit Fensterreihen und grünem Dach vorn, dahinter der Dom mit Hauptturm (barocke Kupferhaube) und den
  Westtürmen – wie das Sprite (frontal stehen die zwei Westtürme hintereinander, im Sprite gedreht nebeneinander).
- Nacht: Palastfenster unregelmäßig warm, Dom angestrahlt – wie die Lichtebene.
- Urteil: gut.
- sofia_rand (12 Uhr, 2 Bilder): Balkanhäuser (roh/verputzt, Pergola, Bewehrung), Haus B mit weißer Balustrade und
  rotem Walmdach, Plattenbau und Jugendstil in der Ferne, Berge – an derselben Stelle wie Arcade, Modern mit
  Zäunen, Mauern und Tiefe. Plattenbau im Rennen unauffällig (Fernbild-Helligkeit −25 % aus der Prüfszene sieht man
  hier nicht). Gut.

### landmarks/eiffel_tower – L2 (Export 257 s, lod0 25.152 > 25.000!, glb 1.722 kB, 2048²)
- Tag: echtes Gitter aus Kastenträgern, Bögen, Plattformen mit Friesen, Spitze mit Antenne – aus 80/250 m deutlich
  feiner als das Sprite, aus 1200 m saubere Silhouette. Nacht: golden angestrahlt, Plattformen hell – lebendiger als
  das dunkle Sprite (Arcade: Lichtebene golden? – im Rennen A/B prüfen).
- BEFUND E1: lod0 25.152 Dreiecke, Budget 25.000. Fix: neue Option drop_caps des Bauers prop_baked – die zwei
  Stirnflächen jedes Gitterträgers (in Gurten/Boden/Plattform verborgen, ein Drittel der Gitter-Dreiecke) fallen
  weg (Commit „Stirnflächen …“). Neu-Export in queue_r4.

### landmarks/atomium – L2 (Export 53 s, lod0 12.674, glb 336 kB, 2048×1024)
- Tag: Form, Kugeln, Röhren, Stützen, Pavillon und oberes Fensterband wie das Sprite. BEFUND A1: die Kugeln sind
  matt grau mit Paneellinien, das Sprite zeigt polierten Chrom mit Himmel/Boden-Spiegelung und Glanzlichtern – im
  Atlas geht metallic verloren. Fix: Option vpbr + overrides (at_steel/at_tube als Vertex-PBR, metallic 1,
  Rauheit 0,22/0,3) – Commit „Atomium mit Stahl als Vertex-PBR“. Neu-Export in queue_r4 (nach L2).
- Nacht: Fensterband hell, Kugeln mit Lichtpunkten (Lichtebene des Generators); Sprite nachts nur dunkle Kugeln.
- sofia_nacht (22 Uhr): Jugendstilhaus mit warmen Fenstern und hellen Ladenbögen, Plattenbau mit Fenstern, Nevsky-
  Kathedrale noch als Bild angestrahlt – wie Arcade; die Fassade hier etwa so hell wie in Arcade (helles Haus,
  Fenster bestimmen das Bild). Gut.

### landmarks/basilika_koekelberg – L2 (Export 252 s, lod0 3.354, glb 231 kB, 2048²)
- Tag: Art-déco-Fassade aus hellem Backstein mit Lisenen, zwei Türme mit grünen Spitzen, Kupferkuppel auf dem Tambour,
  Seitenflügel – Farben und Gliederung wie das Sprite. Frontal aus Straßenhöhe verdeckt die Fassade den Tambour zur
  Hälfte (Sprite gedreht und leicht von oben: Kuppel frei) – Geometrie, kein Fehler; im Rennen A/B ansehen.
- Nacht: angestrahlt, Tambourfenster hell – wie die Lichtebene. Urteil: gut.

### landmarks/beffroi_calais – L2 (Export 74 s, lod0 2.890, glb 172 kB, 1024²)
- Tag: Rathaus aus rotem Backstein mit weißen Steinbändern, Schieferdach mit Gauben, Eckgiebel, Belfried mit Uhr,
  Laterne und grüner Haube – fast deckungsgleich mit dem Sprite; die 1024²-Textur reicht (Fenster und Bänder aus
  80 m scharf). Nacht: angestrahlt, einzelne Fenster warm. Urteil: gut.

### landmarks/duomo_milano – L2 (Export 182 s, lod0 5.062, glb 363 kB, 2048²)
- Tag: weiße Marmorfassade mit Fialen und Strebepfeilern, Giebel, dahinter der Vierungsturm mit Madonnina (golden) –
  wie das Sprite (frontal: Langhaus und Dachfialen hinter der Fassade). Aus 80 m etwas flach (Fassadenrelief nur
  in Lisenen) – wie der Generator. Nacht: hell angestrahlt, Madonnina golden. Urteil: gut.
- kaunas_rand (12 Uhr, 2 Bilder): baltische Holzhäuser (gelb mit Giebelbalkon, grün), Birken, Lattenzäune,
  Jugendstilhäuser und Plattenbau in der Ferne – an derselben Stelle wie Arcade, Modern mit Brettstruktur,
  Zaunstäben und Blattkarten-Birken. Gut.

### landmarks/campanile_venezia – L3 (Export 52 s, lod0 3.728, glb 148 kB, 1024²)
- Tag: Campanile aus rotem Backstein mit weißer Glockenstube, grüner Pyramide und goldenem Engel, daneben San Marco
  mit Bögen (goldene Mosaike), Fenstern und den Kuppeln – wie das Sprite (80-m-Kachel leer: das Wahrzeichen steht
  160 m seitlich, außerhalb des Bildes). Fassade von San Marco etwas wärmer als im Sprite. Nacht: angestrahlt.
- Urteil: gut.

### landmarks/sagrada_familia – L3 (Export 220 s, lod0 17.100, glb 1.187 kB, 2048²)
- Tag: Geburtsfassade (ocker, gefurcht), helle Seitenschiffe mit Lanzettfenstern, Türme mit Lochmustern und bunten
  Fruchtaufsätzen, Mittelturm mit Kreuz, Zypresse – fast deckungsgleich mit dem Sprite. Nacht: angestrahlt, Kreuz
  und Aufsätze hell, einzelne Fenster warm. Urteil: gut.

### landmarks/basilica_pilar – L3 (Export 111 s, lod0 12.580, glb 439 kB, 2048×1024)
- Tag: lange Ziegelfassade mit Rundbogenfenstern und hellem Gesims, die bunt glasierten Kuppeln (grün/gelb/blau/weiß)
  mit Laternen, Ecktürme – wie das Sprite (frontal stehen die Ecktürme hintereinander: 3 statt 4 sichtbar).
- Nacht: angestrahlt, einzelne Fenster warm, Kuppeln farbig – wie die Lichtebene. Urteil: gut.
- riga_zentrum (12 Uhr, 2 Bilder): Schrägseilbrücke über die Daugava, Jugendstilhäuser (blau mit Bögen und
  Läden), Freiheitsdenkmal noch als Bild (L3) – an derselben Stelle wie Arcade, Modern mit Kaimauer, Wasser und
  Läden mit Auslage. Gut.

### landmarks/kathedrale_burgos – L3 (Export 131 s, lod0 1.266, glb 90 kB, 2048×1024)
- Tag: helle Westfassade mit zwei durchbrochenen Turmhelmen, Fensterreihen, dunkle Rosette, Portal, Seitenbauten –
  wie das Sprite. Der Generator ist hier schlicht (1.266 Dreiecke): Rosette eine flache dunkle Scheibe, Fassade aus
  80 m flach – genauso im Sprite; ein reicherer Generator wäre eigene Arbeit (Notiz N3, nicht in dieser Welle).
  Der Vierungsturm (Cimborrio) steht frontal hinter der Fassade. Nacht: angestrahlt. Urteil: gut (Notiz N3).

### landmarks/parlament_budapest – L3 (Export 157 s, lod0 3.804, glb 265 kB, 2048²)
- Tag: lange neugotische Front mit Spitzbogenfenstern, rote Dächer, die gerippte Kuppel auf dem Tambour, Türmchen
  und Fialen – fast deckungsgleich mit dem Sprite (bei 16 px/m aus 80 m weich, das Wahrzeichen steht 180 m weit).
- Nacht: hell angestrahlt, Fenster warm, Kuppel rot – wie die Lichtebene. Urteil: gut.
- sibiu_zentrum (12 Uhr, 2 Bilder): Barockhäuser (gelb, grün, rosa), Cibinbrücke mit Kaimauer, Stadtpfarrkirche
  noch als Bild (L3 folgt) – an derselben Stelle wie Arcade, Modern mit Fensterrahmen, Kaimauer und Wasser. Gut.
- ab_c2 vollständig (10 Stellen, 11:40). C2 abgeschlossen.

### landmarks/kulturpalast_warschau – L3 (Export 158 s, lod0 5.788, glb 414 kB, 2048²)
- Tag: gestufter Turm mit Fensterraster, Attiken mit Fialen, Uhr, Spitze, Seitenflügel – Silhouette und Stufen wie das
  Sprite, aus 1200 m sauber. Nacht: viele unregelmäßig erleuchtete Fenster, Uhr hell – lebendiger als das dunkle
  Sprite (Lichtebene: Fenster). Urteil: gut.

### landmarks/freiheitsdenkmal_riga – L3 (Export 32 s, lod0 422, glb 31 kB, 1024²)
- Tag: roter Granitsockel, heller Obelisk mit Bändern, grüne Milda mit den drei goldenen Sternen – wie das Sprite.
- Nacht: Schaft angestrahlt, Sterne golden – deutlich heller als das dunkle Sprite (Anstrahlung des Generators).
  Urteil: gut.

### landmarks/nevsky_kathedrale – L3 (Export 105 s, lod0 4.590, glb 156 kB, 2048×1024)
- Tag: helle Steinfassade, grüne Kupferdächer und Nebenkuppeln, Glockenturm, Kreuze – wie das Sprite. BEFUND N4: die
  Goldkuppeln sind matt senfgelb, das Sprite zeigt glänzendes Gold mit Glanzlicht (wie A1 beim Atomium: metallic
  geht im Atlas verloren). Fix: an_gold als vpbr (metallic 1, Rauheit 0,28) mit Anstrahlung Kanal 14 – Commit
  „Goldkuppeln …“; Neu-Export in queue_r4. (gold() nutzt sonst nur der Michel – kleine Teile, bleibt.)
- Nacht: angestrahlt, Fenster warm, Kuppeln hell. Urteil: gut nach Fix.

## Rennen A/B Wahrzeichen (ab_lm1)
- lm_elbphilharmonie (km 91, 12 Uhr): falsch gewählte Stelle – die Elbphilharmonie (links, 55 m) liegt hier in Arcade
  und Modern hinter den Backsteinhäusern; sichtbar ist rechts der Michel (Modell, wie Arcade, gut). Stelle der
  Render-Prüfung (km 85,6) für Tag und Nacht nachgetragen (lm_elbphilharmonie_fern, _nacht auf 85,6 umgestellt).

### landmarks/stadtpfarrkirche_sibiu – L3 (Export 141 s, lod0 1.012, glb 76 kB, 2048×1024)
- Tag: heller Putzturm mit Uhr, Wehrgang, grün glasiertem Helm mit vier Ecktürmchen, rotes Kirchendach, gotische
  Fenster – wie das Sprite (frontal: Langhaus hinter dem Turm). Nacht: angestrahlt, Uhr hell. Urteil: gut.

### landmarks/catedrala_timisoara – L3 (Export 126 s, lod0 8.228, glb 380 kB, 2048×1024)
- Tag: rot-gelb gestreifter Ziegelbau, glasierte Dächer mit Rautenmuster (grün/gelb/rot), Zwiebelkuppeln mit
  goldenen Kreuzen, hoher Mittelturm – Farben und Muster wie das Sprite. Nacht: angestrahlt, Kreuze hell.
- Urteil: gut.
- lm_michel_nacht (km 91, 22 Uhr; lief noch mit der alten Stelle, umbenannt): Michel als Modell angestrahlt mit Uhr
  und grüner Haube, Kirchenschiff mit warmen Fenstern – wie Arcade. Links ein naher Speicher mit vielen hellen
  Fenstern (Modell), den Arcade an dieser Stelle schon hinter sich hat. Gut. Elbphilharmonie Tag/Nacht bei km 85,6
  am Ende von ab_lm1 nachgetragen.

### landmarks/catedrala_mantuirii – L3 (Export 212 s, lod0 5.176, glb 182 kB, 2048²)
- Tag: heller Stein mit Arkaden, Mosaik-Portal (gold), Haupt- und Ecktürme mit Zwiebelkuppeln – Form wie das Sprite.
  BEFUND N5 wie N4: Kuppeln matt gelb statt Gold mit Glanzlicht. Fix: cm_gilded als vpbr + Anstrahlung (Commit
  „Goldkuppeln der Kathedrale der Erlösung“), Neu-Export in queue_r4. Nacht: angestrahlt, Kuppeln hell.
- Urteil: gut nach Fix.

### landmarks/palatul_parlamentului – L3 (Export 184 s, lod0 2.380, glb 145 kB, 2048²)
- Tag: gestufter Monumentalbau, Fensterraster, Säulenportikus, Arkaden im Sockel, Attiken – Stufen und Raster wie das
  Sprite (frontal: Seitenflügel hinter der Front; bei 16 px/m aus 80 m weich, steht 40 m weit – im Rennen A/B).
- Nacht: angestrahlt, einzelne Fenster warm. Urteil: gut.

### L2/L3 vollständig exportiert (QUEUE L2 DONE 12:00). Alle 33 Wahrzeichen angesehen: 33 gut, davon 4 nach Fix
(Eiffelturm E1, Atomium A1, Newski N4, Erlösung N5 – Neu-Export queue_r4 läuft). Notizen: N2 Riesenrad-Speichen,
N3 Burgos schlicht.
- lm_kaiserburg (km 107,4 → 108,7): die Burg (rechts, 80 m) liegt hier in Arcade und Modern hinter der Straßenfront –
  wie bei Hamburg falsch gewählte Stelle. Fachwerk- und Barockhäuser der Stadt wie Arcade, gut.
- UMSTELLUNG 12:05: ab_lm1/2/3 abgebrochen (500 m vor dem Anker verdecken die Straßenfronten die Wahrzeichen). Neu
  ab_lmp.txt: alle 33 Wahrzeichen 130 m vor dem Anker (der freie Platz vor einem Wahrzeichen ist 100 m lang,
  CityData.DEFAULT_CLEAR_M), Bilder nach 1 und 2,5 s; 8 davon auch 22 Uhr (40 Läufe, ~4,5 h).

### Neu-Export R4 (12:05–12:07)
- eiffel_tower: lod0 25.152 → 17.072 Dreiecke (4.040 Stirnflächen weg), Ansicht unverändert (keine Löcher sichtbar
  aus 80–1200 m). validate: Budget-Fehler – Texturquellen 62.953.675 B > 60 MB (Grafikspeicher 219,5/240 MB).
- atomium: Stahl als vpbr (Export 14 s – nur der Pavillon wird gebacken), validate rc 0.
- BEFUND B1 (Budget): Texturquellen 60,04 von 60 MB. Ursache u. a.: 1024²-Atlanten wurden als PNG geschrieben
  (Belfried 606 kB, Campanile 592 kB) – größer als ein 2048×1024-WebP. Fix: Wahrzeichen-Atlas immer WebP
  (Commit „Wahrzeichen-Atlas immer als WebP“). R5 exportiert Newski, Erlösung (Gold vpbr) und die drei 1024er neu.
- Hinweis: queue_r4 lief mit der Liste vom Start (sed -i ersetzt die Datei, bash liest die alte weiter) – daher R5.
- KORREKTUR 12:15: Etappen-km sind gestaucht (ab_shot.sh: bei 120 km/h ~0,35 Etappen-km je Sekunde; 1 Etappen-km ≈
  95 sichtbare Meter). „130 m vor dem Anker“ waren 0,13 Etappen-km = 12 sichtbare Meter – das Auto war schon am
  Wahrzeichen vorbei (Hamburg: km 91,6 → 92,0). Neu: Start 1,6 Etappen-km (~150 sichtbare m) vor dem Anker, Bilder
  nach 1 und 2,5 s (~140 und ~110 m davor, im freien Platz von 100 sichtbaren Metern). Alte Läufe in ab/alt_p.

### Neu-Export R5 (12:08–)
- nevsky_kathedrale: Gold als vpbr – Tag glänzendes Gold mit Glanzlicht wie das Sprite, Nacht angestrahlt golden
  (shots/r3_nevsky_kathedrale). Texturquellen jetzt 59,81 / 60 MB.
- BEFUND B2 (validate): automatische Stufen 5–7 behalten vom Lampenkanal 14 (angestrahltes Gold) nur 46–69 % der
  Fläche (Grenze LAMP_KEEP 0,8). Fix: auto_lod=False für Newski und Erlösung (Vertrag A-4: Lampenkanal auf vpbr →
  keine automatischen Stufen, wie prop_vpbr); je ~5 000 Dreiecke, also billig. Neu-Export queue_r6.sh nach R5,
  Tore (gates3.sh) warten auf R6.

### N2 gemessen (12:25, prop_scene dist mit Abständen im Abstand eines Bildes bei 120 km/h = 0,56 m, flicker.py)
Anteil der Kachelpixel, die sich von Bild zu Bild um > 24/255 ändern (Modell | Sprite), 12 Uhr:
- riesenrad 250 m: 6,5 | 2,1 %; 600 m: 8,8 | 0,6 %; 1 000 m: 4,5 | 0,1 %; 600 m 22 Uhr: 1,4 | 0,0 %.
- eiffel_tower 250 m: 2,3 | 2,3 %; 600 m: 0,3 | 0,4 %; 1 200 m: 0,1 | 0,0 % – kein Flimmern über dem Sprite.
- Gleiche Abstände doppelt gerendert: 0,0 % (deterministisch).
Ursache: 120 Speichen à 0,14 m und die Zickzack-Streben der Kränze (0,22 m) sind ab ~250 m schmaler als ein Pixel
(0,14 m × 711 px / 600 m = 0,17 px); MSAA trifft sie mal, mal nicht. Godots automatische Stufen behalten sie
(flach schattierte Kästen: jede Kante ist Rand). Das Sprite zeigt dort nur Kranz und Nabe (Mip-Filter).
Lösung (eigener Schritt, Renderer): dünne Stäbe im Shader auf mindestens 1 px verbreitern und mit der Deckung
(Breite in px) durchscheinend zeichnen („phone-wire AA“), als eigene Flächenklasse der Wahrzeichen; oder Speichen
als Alphakarte. Nicht in dieser Welle – Vorschlag im Bericht, Rückstau.

### Neu-Export R6 + ganze Prüfung (12:26)
- Newski, Erlösung ohne automatische Stufen: validate ohne Lampenfehler; Texturquellen 58,71 / 60 MB, Netze 25,76 / 40,
  Grafikspeicher 219,5 / 240 MB.
- BEFUND B3 (validate, ganz): landmarks/frankfurt_skyline lod0[baked] 11 von 1 936 Dreiecken gegen ihre Normalen
  (Grenze 8) – seit dem L1-Export (frühere Prüfungen liefen mit --only). In der glb sind sie richtig gewickelt; es
  sind 21 Splitter mit Höhe ~0 (n-Eck-Deckel mit kollinearen Ecken: Fuß bei y 0 und Dach bei y 246), die 16-Bit-
  Positionen (5 mm Raster bei 300 m) drehen einige um. Unsichtbar, aber gezählt. Belfried hat 12 solche (unter der
  Grenze). Fix: build_baked mit mb.finish(min_height=1e-4) wie Stadt-/Brückenbauer; alle anderen 31 Wahrzeichen
  haben keine Splitter (glb_thin.py) → unverändert. Neu-Export queue_r7.sh (Frankfurt, Belfried), Tore gates4.sh
  danach (gates3 angehalten, manifest/status bleiben, validate neu).

## Rennen A/B Wahrzeichen vom Platz (ab_lmp, neue Stelle 1,6 Etappen-km vor dem Anker) – erste Läufe
- p_elbphilharmonie (Tag/Nacht): an dieser Stelle in beiden kaum im Bild (links oben, hinter Parkbäumen und HUD);
  Michel rechts wie Arcade. „LOS!“-Schriftzug halbtransparent im ersten Bild (Startanzeige, kein Befund).
- p_kaiserburg_nuernberg (Tag/Nacht): Burg an dieser Stelle in beiden nicht im Bild; Pegnitzbrücke, Fachwerk wie Arcade.
- p_dom_fulda: BEFUND N6 – Arcade zeigt den Dom in der 3/4-Ansicht des Sprites (Fassade + Langhaus + Kuppel, breit,
  linke Kante weit zur Straße), Modern frontal: nur die Doppelturmfassade, schmal, weiter rechts. Ursache: jedes
  Wahrzeichen-Sprite ist mit view_yaw −10…−28° gerendert (props_landmarks.py LANDMARKS), die Aufstellung rechnet
  schon mit diesen Ausdehnungen (model.json extent_m = sprite_extent(view_yaw); Fulda links 50,4 / rechts 17,1 m),
  das Modell steht aber frontal (±24 m). Probe prop_scene --yaw=+22 (neue Option): Modell zeigt Fassade, Langhaus
  und Kuppel wie das Sprite (shots/yaw/fulda_cmp.png); −22 die falsche Seite. Godot rotation.y = −view_yaw, d. h.
  Kurs t = face_heading + view_yaw (heading_basis: rotation.y = −t).
  Plan N6 (Nacharbeit dieser Welle): model.json view_yaw_deg (Exporter + deterministischer Nachtrag), landmarks.gd
  dreht um view_yaw (gespiegelt: Gegenwinkel), near_shift gegen Arcades Bildkante (x_m-Linie) statt gegen den
  frontalen Grundriss – mit Sprite-Winkel liegt die nächste Ecke dann auf Arcades Vorderkante; Tests
  (test_landmarks Knotenverschiebung, Anker), Render-Prüfungen, Goldens, A/B vorher/nachher. Erst Tore auf dem
  jetzigen Stand (Basis), dann N6.
- N6 genauer (12:40): Mit dem Sprite-Winkel liegt der straßennächste Punkt genau auf Arcades Bildkante (x_m vom
  Fahrbahnrand; extent_l ist über alle Punkte im Sprite-Blick gemessen) – aber bei langen Kirchen ist das das
  HINTERE Ende (Fulda: Langhaus 99 m, schwenkt ~37 m zur Straße, liegt bis ~92 m hinter dem Anker). Frei sind hinter
  dem Anker nur clear_m[1] = 40 m (Track._build_landmark, gemeinsam mit Arcade – eingefroren). 14 Aufstellungen haben
  x_m 12–30 m (Sagrada 12, Passau/Timișoara 20, Fulda/Riga 25, Stephansdom 28, …) → das Langhaus könnte in die
  Häuserzeile nach dem Platz ragen. near_shift gegen den frontalen Grundriss schiebt es dafür 26 m nach außen (dann
  kleiner als Arcade). Lösung braucht: Drehwinkel je Aufstellung so begrenzen, dass hinter clear_m[1] keine Ecke näher
  als die Häuserzeile kommt (oder near_shift nur dort), Prüfung gegen die Stadthäuser, Netztest, A/B vorher/nachher.
  → eigener Schritt direkt nach Welle 6 (Bericht: Vorschlag, wird ohne Rückfrage begonnen).
- p_dom_fulda_nacht: Dom in beiden warm angestrahlt, ähnlich hell; Modern wieder frontal und schmaler (N6).
- p_frankfurt_skyline: auf der Friedensbrücke; rechts der hohe Turm in beiden an derselben Stelle, Mainufer und
  Häuser wie Arcade. Gut.
- p_frankfurt_skyline_nacht: hoher Turm rechts mit erleuchteten Büros in beiden, Häuser am Main – wie Arcade. Gut.
- p_koelner_dom: Dom links (dunkler Stein, Helme) in beiden an derselben Stelle, im Modern dazu die Seile der
  Severinsbrücke; Dom im Modern etwas dunkler. Gut.
- p_fernsehturm_berlin: Bild 0 – Arcade zeigt rechts den Schaft und den Pavillon; Modern verdeckt den Schaft durch
  ein nahes gelbes Haus rechts, dessen Körper (3D, nach hinten tief) noch vor der Kamera steht, während Arcade das
  Hausbild am Anker schon hinter sich hat. Physikalisch richtig, kein Wahrzeichen-Befund; Pavillon in beiden. Bild 1:
  Turm in beiden aus dem Bild. Notiz (Nahbereich Häuser, wie in AS5a bekannt).
- p_frauenkirche_dresden: Augustusbrücke mit Laternen, Frauenkirche rechts in beiden an derselben Stelle und etwa
  gleich groß (Kuppel, Ecktürme) – Modern mit Tiefe und Schatten. Gut.
- p_frauenkirche_muenchen: Backsteinkirche links oben (halb hinter dem HUD) in beiden, Häuser wie Arcade. Gut.
- p_st_petri_riga (Rostock): Backsteinturm mit Helm und langes Schiff mit grünem Dach rechts in beiden an derselben
  Stelle und gleich groß. Gut.
- p_riesenrad (Wien, Tag): auf der Reichsbrücke; Riesenrad an dieser Stelle in beiden nicht im Bild (Häuser am Kai
  wie Arcade, Modern mit Kaimauer und Wasser). Kein Befund; N2 bleibt aus der Messung.
- p_riesenrad_nacht: Bild 1 – Riesenrad rechts oben mit Lampenketten in beiden; in Modern weiter am Bildrand und
  teils hinter dem Eckhaus (frontal statt 3/4-Ansicht, N6). Häuser nachts wie Arcade.
- p_stephansdom: Bild 1 – das bunte Zickzack-Dach links oben in beiden an derselben Stelle, Barockhäuser rechts wie
  Arcade. Gut.
- Render-Prüfung check_landmarks_render (mit Modellen): Stelle km 85,6 Versatz (8, −6) px, weich, nachts nur
  beleuchtet, nacht_hell Elbphilharmonie 1,01 × Arcade, Flugfeuer Florianturm 29/28 px, Anstrahlung Bremer Dom 0,97 ×.
- p_stephansdom_nacht: Dom links mit Zickzack-Dach und warm angestrahlter Fassade in beiden, etwa gleich hell;
  Modern dazu ein naher Laden mit Auslage. Gut.
- p_mariendom_linz: Nibelungenbrücke, Mariendom rechts (Turm mit Helm) in beiden an derselben Stelle. Gut.
- p_dom_passau: Dom links (weiße Doppeltürme mit grünen Hauben) in beiden an derselben Stelle. Gut.
- p_dom_regensburg: Eiserne Brücke, Dom rechts (gotische Doppeltürme) in beiden an derselben Stelle und gleich groß. Gut.
- Render-Prüfung check_props_render: props_spiegel FEHLER – kein Set mehr als Ersatzbild (gleiche Ursache wie T4/T5);
  behoben mit Test-Manifest ohne das Chalet-Modell (Commit 679215d), Nachlauf nach den Toren.
- p_veitsdom_prag: Legionsbrücke mit Laternen, Domtürme rechts oben in beiden an derselben Stelle. Gut.
- p_eiffel_tower: Bein und Gitter des Eiffelturms rechts oben in beiden an derselben Stelle und gleich groß (Modern:
  echtes Gitter). Gut.
- p_eiffel_tower_nacht: golden angestrahltes Gitter rechts in beiden fast deckungsgleich (Lage, Größe, Farbe);
  Modern dazu Haussmann-Fassade mit erleuchteten Läden. Sehr gut.
- p_atomium: BEFUND A2 – Atomium rechts an derselben Stelle wie Arcade, aber Kugeln, Röhren und Stützen kräftig blau
  (Metall 1, Rauheit 0,22 spiegelt fast nur den blauen Himmel); das Sprite zeigt neutralen, dunkleren Chrom mit
  Glanzlichtern. Auch in prop_scene (shots/r2_atomium) heller und bläulich. Vorschlag: Stahl dunkler und neutraler
  (#a0a5ab statt #c8ccd1), Rauheit 0,3 / 0,38 – nach den Toren neu exportieren (14 s) und vergleichen.
  Links die Basilika Koekelberg: Arcade breit mit Langhaus und Kuppel, Modern frontal schmal (N6).
- p_basilika_koekelberg: Basilika links in beiden an derselben Stelle und etwa gleich groß (aus dieser Stelle schräg
  gesehen, Kuppel sichtbar). Gut.
- p_beffroi_calais: Rathaus mit Belfried links in beiden an derselben Stelle (Backstein mit hellen Bändern, Giebel). Gut.
- p_duomo_milano: N6 deutlich – Arcade zeigt rechts groß die weiße Flanke und Fassade des Doms (3/4-Ansicht, die
  Flanke reicht bis an Arcades Bildkante x_m), Modern den Dom frontal, kleiner und weiter rechts (Fassade ±34 m um den
  Anker, der wegen der langen Flanke im Sprite weit draußen liegt). Mailänder Blöcke links wie Arcade.
- p_campanile_venezia: Campanile (x_m 160) an dieser Stelle in beiden nicht im Bild; venezianische Häuser wie Arcade.
- p_sagrada_familia: Türme der Sagrada rechts in beiden an derselben Stelle und etwa gleich groß. Gut.
- Tore: render 29/30 (nur props_spiegel, behoben), golden (Arcade) rc 0.
- p_basilica_pilar: Puente de Piedra, Basilika links mit den bunten Kuppeln in beiden an derselben Stelle. Gut.
- p_kathedrale_burgos: Kathedrale links (Türme mit Helmen) in beiden an derselben Stelle und etwa gleich groß. Gut.
- p_parlament_budapest: Bild 0 – Modern zeigt das Parlament links jenseits der Donau (rote Dächer, Türmchen),
  Arcade an dieser Stelle nicht (x_m 180 m; die 3D-Straße biegt hier nach rechts, Arcades Bild liegt links außerhalb
  des Bildes bzw. hinter dem Pylon). Kein Modellbefund – Anordnung aus R7b (Anker gleich, Bildlage in Kurven nicht).
  Elisabethbrücke mit Seilen und Häuser am Kai wie Arcade. Notiz NB1.
- p_kulturpalast_warschau: Poniatowski-Brücke, Plattenbauten links wie Arcade; Kulturpalast rechts oben am Bildrand
  in beiden nur angeschnitten. Gut.

## N6 Entwurf (14:50)
- Kein Code räumt Stadthäuser gegen den Grundriss eines Wahrzeichens frei – nur der Platz von Track._build_landmark
  (clear_m vor/nach dem Anker, plaza none = kein Platz). Stadthäuser stehen 0,5–4 m hinter der Fahrbahnkante, bis
  ~30 m tief.
- Kurs t = face_heading + yaw, yaw = view_yaw (rad), gespiegelt Gegenwinkel; near_shift/capped_turn gegen die Lage im
  Sprite-Blick (Kurs a + yaw) statt gegen die frontale – auf gerader Straße dann keine Verschiebung, die nächste Ecke
  auf Arcades Bildkante (x_m).
- Grenze: Punkte des gedrehten Grundrisses, die längs der Straße mehr als clear_m[1] hinter dem Anker liegen (bzw.
  jeder Punkt hinter dem Anker bei plaza none), müssen mindestens HOUSE_BAND_M (~35–40 m) von der Fahrbahnkante
  bleiben; sonst yaw per Bisektion kürzen (bis 0 = heutiger Stand). Grundriss: 2D-Hülle der Netzpunkte (einmal je
  Modell), nicht nur das AABB.
- Track: landmarks-Eintrag bekommt clear_m und plaza (Arcade liest sie nicht – Golden Arcade muss gleich bleiben).
- Tests: Einheitstest für die Grenze (lange Kirche nah an der Straße → gekürzt; weit weg → ganzer Winkel), Netztest
  Knoten ≤ 12 m mit Winkel, Ankertest unverändert; Render-Prüfung Wahrzeichen; Goldens (Kiel–Hamburg: Michel,
  Elbphilharmonie); A/B Fulda, Mailand, Koekelberg, Dresden, Riesenrad vorher/nachher.
- p_freiheitsdenkmal_riga: Vanšu-Brücke, Jugendstilhäuser wie Arcade; Denkmal an dieser Stelle in beiden nicht im Bild.
- p_nevsky_kathedrale: Bild 1 – Kathedrale links mit Goldkuppeln in beiden an derselben Stelle (Modern: Gold mit
  Glanz). Gut.
- p_nevsky_kathedrale_nacht: Kathedrale links angestrahlt mit Goldkuppeln in beiden an derselben Stelle, ähnlich
  hell. Gut.
- p_stadtpfarrkirche_sibiu: Kirche rechts in beiden an derselben Stelle; Arcade zeigt Turm und langes Schiff (3/4),
  Modern frontal Turm und Giebel, schmaler (N6).
- p_catedrala_timisoara: Kathedrale links (rot-gelb gestreift, Türme) in beiden an derselben Stelle und gleich groß. Gut.
- p_catedrala_mantuirii: Kathedrale links (heller Stein mit Arkaden, goldenes Portal) in beiden an derselben Stelle;
  rechts die Balkankirche wie Arcade. Gut.
- p_palatul_parlamentului (vor N6): Arcade rechts groß und nah der Palast (3/4-Ansicht mit langer Flanke), Modern
  frontal am rechten Bildrand, kleiner (N6). Links die Kathedrale der Erlösung in beiden.
- ab_lmp vollständig (40 Läufe, 15:04). Ergebnis: wo das Wahrzeichen im Bild ist, steht es an Arcades Stelle; lange
  Bauten in Modern schmaler/weiter weg (N6: Fulda, Mailand, Sibiu, Palast, Riesenrad am Rand); Atomium blau (A2,
  behoben); Budapest Parlament nur in Modern im Bild (NB1); Berlin Turm von nahem 3D-Haus verdeckt (Notiz).

## N6 umgesetzt (65c9999, 15:05)
- place_model dreht um view_yaw, near_shift/capped_turn gegen den Sprite-Blick, yaw_within_band (HOUSE_BAND_M 36 m
  hinter clear_m[1]), Hülle footprint_hull(). Netztest: 78 Aufstellungen gedreht, 15 gekürzt (Mailand −13/−14°,
  Stephansdom −11/−22°, Linz −16/−20°, Fulda −12/−22°, Sibiu −17/−22°, Timișoara 0/−24° …), Knoten ≤ 12,00 m.
- Prüfungen laufen (gates_n6.sh: Render Wahrzeichen, Golden Modern mit KEEP, Golden Arcade, ganze Suite);
  Nachher-Bilder ab_n6.txt (9 Läufe, ab/n6_*).
- N6 Nachher (ab/n6_*, Vergleich Arcade | vorher | nachher: ab/n6_cmp_*.jpg):
  - Fulda (12° statt 22°, Häuserzeile): Fassade schräg, Langhaus links dahinter angedeutet (vom Baum verdeckt) –
    näher an Arcade, aber weniger als dort.
  - Dresden: Frauenkirche schräg mit Ecktürmen, Lage und Größe fast wie Arcade. Gut.
  - Atomium (mit A2): gedreht wie das Sprite, grauer Chrom. Koekelberg links jetzt mit Langhaus und Kuppel wie
    Arcade. Gut.
  - Mailand (13° statt 14°): die lange weiße Flanke mit Strebepfeilern ist jetzt sichtbar, Dom wirkt größer – wie
    Arcade. Gut.
  - Goldens: Modern s4 – Michel leicht gedreht, Elbphilharmonie-Glas jetzt ganz hinter dem Haus (729 px, angesehen,
    2b93865); Arcade unverändert; Render Wahrzeichen OK (Elbphilharmonie 12 020 px, Versatz 12 px, Nacht 1,02 ×).
  - Sagrada Família (x_m 12, ganz nah an der Straße): wegen der Häuserzeile kaum gedreht – vorher wie nachher, Lage
    und Größe wie Arcade. Gut.
  - Sibiu (17° statt 22°): Turm und langes Schiff mit rotem Dach wie in Arcade (vorher nur Turm und Giebel). Sehr gut.
  - Riesenrad nacht, Elbphilharmonie: an diesen Stellen in beiden kaum im Bild (wie vorher).
