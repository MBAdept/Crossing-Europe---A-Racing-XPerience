## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS4-N** = Nacharbeit der Modelle (`ce3d/buildings3d.py`, `ce3d/bridges3d.py`, Katalog, Hooks),
**R2** = Requisiten-Bauer (`builders/props.gd`, `prop_library.gd`), **R5** = Brücken und Wasser,
**Shader** = Besitzer von `vpbr.gdshader` (R4/R7 je Welle). Bilder in diesem Ordner.

### M1 – hoch – Pylon: die Seile enden in den Fahrspuren und laufen über die Brückenenden hinaus (AS4-N, R2/R5)
Bild `01_rennen_pylon_seile_in_der_fahrbahn.jpg` (Rennbild, Kiel–Hamburg km 77,9 / 78,3 / 79,0, hoch, 12 Uhr).
- **Wo:** `props/bridge_pylon`, Köhlbrandbrücke auf Kiel–Hamburg (km 78,7 und 79,9, je ein Paar) – also auf der
  Etappe des ersten Testbuilds, kurz vor dem Ziel –, dazu Hamburg–Hannover, Hamburg–Bremen und neun weitere
  Etappen (44 Pylone im Netz).
- **Was:** Die Deckanker der Seile liegen im Modell bei x = −4,2 m (gemessen am Netz: −4,43 … −3,97 m, Höhe
  0,42–0,78 m), der Fächer reicht ±(15,8 … 82,7) m entlang der Straße. Der Requisiten-Bauer stellt den Pylon bei
  |x| = 7,5 m auf (Zählung). Damit landen die Seile bei |x| ≈ 3,3 m **mitten auf der Fahrbahn**, 0,6 m über dem Belag:
  im Rennen fährt man durch einen Käfig dicker weißer Stäbe, ein Seil endet direkt vor dem eigenen Auto
  (km 77,9), und die Fächer reichen 15 m vor die Brücke auf die Zufahrt (die Brücke ist dort rund 250 m lang,
  gefolgert aus dem Pylonabstand). Die beiden Beine neigen sich zur Straße: die Köpfe stehen 5 m auseinander über den
  Spuren. Arcade zeichnet den Pylon prozedural (`prefer_proc`): senkrecht, Höhe `height_m` der Brücke, 7 Seile je
  Seite bis zur **Deckkante** (x − 1,4 m) und nur `cables` = min(64 m, 0,24 × Brückenlänge) weit. Die A/B-Bilder von AS4
  (km 75,8, 120–260 m vor dem Pylon) zeigen das nicht; aus der Nähe ist es das Auffälligste aller AS4-Modelle.
- **Fix:** (a) AS4-N, sofort: Deckanker an die Deckkante legen (Modell-x ≈ −1,4 m, wie Arcade) und den Fächer auf
  ±60 m kürzen (7 Seile je Seite, 0,30 m in **einer** Stufe, siehe M5), Beine senkrecht oder Kopf über der Deckkante;
  (b) R2 jetzt bzw. R5 später: den Pylon ohne Seile laden (Katalogzeile mit leerem `cables`-Präfix, von AS4
  vorbereitet) und die Seile je Brücke aus `it.cables` und `height_m` bauen, wie `RoadRenderer._pylon()` es tut;
  Modell nach `height_m` / 88,8 skalieren. Bis dahin für den Testbuild: lieber (a) als das heutige Modell.

### M2 – hoch (bis Wasser existiert) – Fähren und Hausboote stehen auf der Wiese (R2/R5)
Bild `01_rennen_pylon_seile_in_der_fahrbahn.jpg` (links und rechts der Brücke), AS4-Bild
`ab_kiel_hamburg_km75_8_pylone_faehren_hoch_mittag_01.jpg`.
- **Wo:** `props/ferry_ship` (26 im Netz, Kiel–Hamburg km 78,9 / 79,1 / 84,6) und `props/houseboat` (20, Bremen–
  Amsterdam, Amsterdam–Lüttich).
- **Was:** Modern hat noch kein Wasser (R5). Die Schiffe stehen auf Höhe `h` = −Tiefe über grünem Gelände; im Rennbild
  liegen zwei weiße Kreuzfahrtschiffe auf einer Wiese, wo Arcade die Elbe zeigt. Mit einer Prüf-Wasserfläche sitzen
  beide Modelle richtig: Wasserlinie am Ursprung, roter Wasserpass knapp über dem Wasser (Bild
  `13_schiffe_abstaende_tag_daemmerung_nacht.jpg`) – das Modell ist nicht der Fehler.
- **Fix:** R2 sofort: Requisiten mit `h` < 0 (Schiffe) nicht setzen, solange kein Wasser-Bauer registriert ist
  (`renderer.builder("bridge") == null`); R5: Wasserfläche unter Brücken in Höhe `−depth`.

### M3 – mittel (am häufigsten gesehen) – Fensterscheiben bei Tag halb braun, halb blau (Shader + AS4-N)
Bilder `23_fenster_tag_braun_blau.jpg`, `14_gross_abstaende_tag_daemmerung_nacht.jpg` (Büroturm bei 100 m).
- **Wo:** jedes AS4-Gebäude mit Fenstern (Haus 940, Block B 541, Laden 497, Fabrik 430, Kirche 305 … im Netz),
  am stärksten der Büroturm: 1 247 von 2 759 Scheiben-Ecken sind Lampen (≈ 45 %).
- **Was:** Die Scheiben, die nachts leuchten, sind `vpbr`-Lampen (Kanal 12) mit warmer Leuchtfarbe
  (120, 92, 50); unbeleuchtet zeigt `vpbr` sie mit `lamp_off_props` 0,5 – also dunkelbraun. Die übrigen Scheiben sind
  blaugraues Glas (38, 48, 59) bzw. (57, 83, 103) am Turm (gemessen an den Netzen). Im Bild (gemessen, Block B aus 7 m):
  Lampen-Scheiben (53, 45, 39) … (69, 62, 50), Farbton 27–38°; Glas (39, 52, 63), Farbton 207°. Bei Tag verrät jede
  Fassade, welche Fenster nachts leuchten: ein braun-blaues Salz-und-Pfeffer-Muster, am Turm ein Schachbrett in der
  blauen Glasfassade. Die Sprites zeigen alle Scheiben gleich dunkel-blaugrau. Nichts leuchtet bei Tag (Helligkeit
  0,21–0,27) – das Kriterium ist erfüllt, der Farbton aber nicht.
- **Fix:** Shader: für Kanal 12 die Tagesfarbe vom Leuchtwert trennen – unbeleuchtet `lights_day_tint` (Glasfarbe,
  ein Uniform) statt `alb × lamp_off_props`, oder eine eigene Fensterrolle. Dann kann AS4-N die Leuchtfarbe heller
  wählen (Sprite-Licht × 0,7–0,8 statt × 0,47, siehe M6). Übergang ohne Shader: alle Scheiben einer Fassade als
  Kanal-12-Lampe mit **derselben** Farbe, die nicht leuchtenden mit Gewicht 0 – bei Tag gleichmäßig (wenn auch
  bräunlich), nachts unverändert.

### M4 – niedrig bis mittel – Fabrik: weiße Dreiecke und Flächen über dem Sheddach bei Nacht (AS4-N)
Bild `24_fabrik_dreiecke_nacht.jpg` (Drehung in 8 Richtungen bei 70 m, 23 Uhr, und bei Tag).
- **Wo:** `props/factory` lod0 (bis 60 m bei „Mittel“, 120 m bei „Hoch“), Dortmund, Bremen, Hannover, Paris,
  Lüttich (430 im Netz, 24–67 m neben der Fahrbahn).
- **Was:** Nachts stehen über dem Dach zwei reinweiße, flache Dreiecke, sichtbar aus Blickrichtungen nahe der
  Gebäudeachse. Der Sprite-Entwurf hat an jedem Shed eine dünne Glasleiste (`fac_glass`, 0,15 m) mit Emission; im
  3D-Bau leuchten offenbar die dreieckigen Stirnflächen der Sheds bzw. ihre Projektion im Nachtlicht-Atlas
  (`baked_lamps=("fac_skylight",)`) als volle Flächen, ohne Abstufung – sie wirken wie Papier, nicht wie beleuchtetes
  Glas. Die Drehung zeigt, woher sie kommen: die senkrechten Glasbänder der Sheds leuchten als ungegliederte
  reinweiße Flächen (bei 270° ein weißes Rechteck über die ganze Halle), von vorn ragen ihre Ränder als Dreiecke über
  die Dachschrägen (0°, 180°, 315°, 330°). Von der Straßenseite (30°, 60° – so steht die Fabrik rechts der Fahrbahn,
  gespiegelt links genauso) sieht man sie nicht; im Rennbild Bremen–Dortmund bei Nacht (Bild 07) fehlen sie. Sichtbar
  also in Kurven, aus denen man auf die Fabrikfront oder ihre abgewandte Seite schaut (angesehen).
- **Fix:** im Nachtlicht-Atlas nur die Glasflächen der Sheds leuchten lassen (Stirnflächen schwarz backen), Leuchtwert
  auf etwa die Hälfte und nach oben abklingend (wie das Turm-Flutlicht der Kirche).

### M5 – mittel – Pylon: Stufenwechsel ändert 58,5 % der Pixel (AS4-N)
Bild `27_pylon_stufenwechsel.jpg`.
- **Was:** lod0 hat 0,28 m, lod1 0,34 m starke Seile. Bei 60 m vor dem Pylon (Wechsel bei „Mittel“) laufen die nahen
  Seile schon über und neben der Kamera und sind groß im Bild: 58,5 % der Pixel bzw. 66,9 % der 3×3-Blöcke ändern sich
  (gemessen, `prop_scene --mode=lods`, Pylon bei x 7,5 m). AS4 hat bei anderem Ausschnitt 3,2 % gemessen.
- **Fix:** eine Stufe (520 Dreiecke brauchen keine zweite) mit einer Seilstärke von 0,30–0,34 m.

### M6 – mittel – Nachts leuchten die Fenster matter als in Arcade (Shader/R4 + AS4-N)
Bild `03_rennen_dorf_nacht.jpg` (Paris–Tours km 131,3, 23 Uhr, hoch).
- **Was:** Gleiches Haus, gleiche Stelle: Arcade-Fenster bis Leuchtdichte 225, 523 Pixel über 150; Modern bis 165,
  143 Pixel über 150 (gemessen im Ausschnitt). Die Hauswand ist in Modern dazu heller (Mond + Umgebung), die Fenster
  heben sich weniger ab; Arcade zeigt mehr leuchtende Fenster (5 gegen 3 auf derselben Ansicht).
- **Fix:** nach M3 die Leuchtfarbe der Scheiben anheben (Sprite-Licht × 0,7–0,8) oder `lights_energy` für Gebäude
  (R4-Nachtabgleich); `lit`-Anteil wie im Sprite (Haus: 5 von 12).

### M7 – mittel – Windmühle: Flügelgitter flimmert 2–3× so stark wie das Sprite (AS4-N; Flügel von AS1b)
Bild `26_flimmern.jpg`, Film `32_film_muehle.mp4`.
- **Wo:** `props/windmill` (189 im Netz, Niederlande, Spanien; 79–147 m neben der Fahrbahn, drehende Flügel).
- **Was:** 9,2–9,9 % der Pixel kippen je Viertelpixel-Schritt (Sprite 2,5–4,4 %, gemessen bei 60/120/250/400 m);
  bei 250–400 m zerfallen die Flügel in weiße Punkte; dazu drehen sie im Rennen (1,35 rad/s). Der Turm selbst (neue
  Fenster von AS4) ist ruhig.
- **Fix:** eine zweite Stufe ab 100 m: Flügel als Rahmen mit halb so vielen, doppelt so breiten Sprossen oder als
  geschlossene Segelfläche (die Silhouette bleibt, der Rotorcode bleibt `vpbr`).

### M8 – niedrig – Büroturm: Foyer nachts eine weiße Fläche, Fenster in Spalten (AS4-N)
Bilder `22_nahansichten_nacht.jpg`, `14_gross_abstaende_tag_daemmerung_nacht.jpg`.
- **Was:** Das Foyer leuchtet als ungegliederte, ausgebrannte weiße Fläche (Nachtlicht-Atlas: ein weißes Rechteck);
  die beleuchteten Scheiben stehen oft ganze Spalten übereinander (bei 250 m wie senkrechte Streifen), im Sprite
  verstreut. Nur 5 Türme im Netz (Wahrzeichen-Ersatz, Maßstab 2,15).
- **Fix:** Foyer warmweiß mit Pfosten (die Vorhangfassade hat sie schon) und 60 % Leuchtwert; Auswahl der hellen
  Scheiben je Geschoss neu würfeln (Hash aus Geschoss und Achse).

### M9 – niedrig – Ladenschild nachts ein leerer Leuchtkasten, Schaufenster flach (AS4-N)
Bild `22_nahansichten_nacht.jpg`.
- **Was:** Das Schild ist bei Tag ein petrolfarbenes Band ohne Schrift, nachts ein weißes Rechteck; die Schaufenster
  sind gleichförmig cremefarbene Flächen. Aus 30 m sieht man es; im Sprite ist es genauso schlicht.
- **Fix:** Schrift als Geometrie wie das Werkszeichen (der Laden ist `mirror_left` – also ein symmetrisches Zeichen
  oder kurze Wörter, die gespiegelt lesbar bleiben, z. B. „OTTO“), Schaufenster mit Auslage-Silhouetten im Atlas.

### M10 – niedrig – kleinere Mängel
- **Fachwerkportal bei 400 m blasser als das Sprite:** gleiche Pixelzahl (250 gegen 289), aber mittlerer Kontrast zum
  Himmel 78 gegen 120 (gemessen, Bild `12_bruecke_abstaende_tag_daemmerung_nacht.jpg`). Es flimmert weniger als das
  Sprite (6,7 gegen 13,7 %). Fix: Streben im Ausschneidebild 1,2× breiter und dunkler.
- **Hausboot:** die abgewandte Längsseite ist eine glatte dunkelgrüne Wand ohne Fenster (Bild `21_nahansichten_tag.jpg`,
  „back“); sichtbar, wenn man an einem Liegeplatz vorbei ist. Fix: Fenster der Straßenseite gespiegelt wiederverwenden.
- **Fabrik, Straßenseite:** nur 18,7 px/m (gemessen; Anfahrtseite 29,2) – unter dem Ziel 26 px/m. Fabriken stehen
  ≥ 32 m von der Mitte; leicht weich in der Nähe. Fix: Gewicht der Seitenwand auf 1,0.
- **Fähre aus der Nähe:** weiße Kästen ohne Gliederung (Bild `21_nahansichten_tag.jpg`); im Spiel nie näher als etwa 60 m –
  dort gleich dem Sprite.
- **Kirche im Rennen kalkweiß:** Wand im Rennbild heller als das Arcade-Sprite (95. Perzentil 229 gegen 203, Mittel
  202 gegen 171, gemessen; Bild 29); das Haus daneben ist gleich hell (202 gegen 203). Fix: Putz `#e8e1d0` um 10 %
  dunkler (die Sonne wird in sRGB addiert, sehr helle Albedo läuft nahe Weiß).
- **Kirche, Rückgiebel:** gemaltes Fenster unscharf (AS4 nennt es selbst).
