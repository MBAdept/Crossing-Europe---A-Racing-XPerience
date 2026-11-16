# KRITIK-4 – Unabhängige Kunstkritik von AS4 (Gebäude, Brückenteile, Schiffe)

- Gegenstand: Zweig `worktree-wf_aad8d49e-fb4-2`, Stand **9eef9a8** (nur gelesen). Gerendert und gemessen in einer
  Kopie im Arbeitsordner (`m1/KRITIK-4/tree`, `diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits, kein Zweig,
  keine Datei des AS4-Arbeitsbaums geändert.
- Modelle: `house_med`, `church`, `factory`, `windmill` (von AS1b, Fenster neu), `building_shop`, `building_oldtown`,
  `building_block_a`, `building_block_b`, `building_tall`, `houseboat`, `ferry_ship`, `bridge_lamp`, `bridge_pylon`,
  `bridge_truss_arch`.
- **gemessen** = auf dieser VM gemessen (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig`); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht
  messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Modelle sichtbar feiner als die Arcade-Sprites und gut genug, um stundenlang daran vorbeizufahren?**

- **Die Gebäude: ja.** Haus, Kirche, Fabrik, Ladenhaus, Altstadthaus und beide Wohnblöcke sind in der Nähe deutlich
  feiner als ihre Sprites – echte Fensterlaibungen mit weißen Rahmen, Sprossen und Sohlbänken, Fensterläden mit
  Lamellen, Balkone, die Schatten auf die Fassade werfen, Rinnen und Fallrohre, Mauerwerk im Ziegelverband, Ziegel- und
  Schieferdächer, Uhren und Schallluken am Kirchturm, Werkszeichen, Sprossenfenster und Rolltor an der Fabrik
  (angesehen, Bilder 21, 22). Umriss, Dach und Fensterraster decken sich mit den Sprites (IoU 0,986–1,000, gemessen),
  sie stehen im Rennen, wo Arcade sie zeigt, in gleicher Größe und Farbe (Bilder 02, 03), und sie flimmern nicht mehr
  als die Sprites (0,0–0,9 % gegen 0,1–1,7 % kippende Pixel, gemessen). Ab etwa 250 m sind sie dem Sprite gleich – mehr gibt die
  Auflösung nicht her. Nachts leuchten einzelne Fenster warm und unregelmäßig, Kirchturm, Uhren und Fabrikhalle haben
  eigenes Licht, bei Tag leuchtet nichts.
- **Die Brückenteile: der Pylon ist im Rennen kaputt.** Seine Seile enden mitten in den Fahrspuren, 0,6 m über dem
  Belag, und reichen vor die Brücke auf die Zufahrt; man fährt durch einen Käfig weißer Stäbe (M1, Bild 01, gemessen am
  Netz und im Rennbild Kiel–Hamburg km 77,9–79,0). Das liegt auf der Etappe des ersten Testbuilds, kurz vor dem Ziel.
  Laterne und Fachwerkportal sind gut (feiner bzw. gleich, flimmern weniger als die Sprites).
- **Die Schiffe:** dem Sprite gleich, aber im Rennen stehen sie auf der Wiese, weil Modern noch kein Wasser hat
  (M2, R5).
- **Was man stundenlang sieht und was stört:** (1) bei Tag verraten die Fenster, welche nachts leuchten – braune
  neben blauen Scheiben auf jeder Fassade, am Büroturm ein Schachbrett (M3; das häufigste Modell-Merkmal im Bild);
  (2) nachts leuchten die Fenster matter als in Arcade (M6); (3) die Glasbänder des Fabrik-Sheddachs leuchten nachts als
  reinweiße Flächen, sichtbar von vorn, hinten und von der abgewandten Seite (M4); (4) die Windmühlenflügel flimmern 2–3× so stark wie das Sprite (M7).
- **Empfehlung:**
  - In den Testbuild können: Haus, Kirche, Fabrik (mit M4 als bekanntem Mangel), Ladenhaus, Altstadthaus, Block A und B,
    Büroturm, Brückenlaterne, Fachwerkportal, Windmühle.
  - **Nicht** in dieser Form: der Pylon (M1 – vor dem Kiel–Hamburg-Build reparieren oder durch den Arcade-Weg ersetzen:
    Modell ohne Seile + Seile vom Renderer) und die Schiffe ohne Wasser (M2 – ausblenden, bis R5 Wasser hat).
  - Nacharbeit AS4-N: M1, M4, M5, M7 (Modelle), M3/M6 zusammen mit dem Shader-Besitzer.

| Modell | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Haus `house_med` (940 im Netz) | **feiner** | ja | Läden mit Lamellen, Rahmen + Sprossen + Sohlbänke, Balkon mit Schatten, Walmdach mit Ziegelreihen, Rinnen, Fallrohre; 59,8 px/m zur Straße | braune/blaue Scheiben bei Tag (M3); nachts matter als Arcade (M6); Sprossen verschwinden bei 60 m (11 % der Pixel) |
| Kirche (305) | **feiner** | ja | Turm mit Uhren (nachts beleuchtet), Schallluken, Rundbogenfenster, Schieferdach, Flutlicht, Kreuz | Flutlicht schwach; Rückgiebel unscharf; als Wahrzeichen-Ersatz bis Maßstab 2,6 (11 px/m, bei ≥ 69 m ausreichend) |
| Fabrik (430) | **feiner** | ja, mit M4 | Sheddach, Sprossenfenster 3×3, Rolltor mit Rippen, Werkszeichen (Zahnrad, nachts hell), Schlot mit Flugbefeuerung, Silo | reinweiße Shed-Glasbänder nachts (M4); Straßenseite 18,7 px/m |
| Windmühle (189, von AS1b) | gleich | ja | neue Turmfenster mit Rahmen (ruhig), Galerie, Reetkappe | Flügelgitter flimmert 2–3× (M7, Flügel von AS1b) |
| Ladenhaus (497) | **feiner** | ja | Markise, Schaufenster, Schildband, Rahmenfenster; nachts Schild und Schaufenster hell | Schild ohne Schrift, nachts weißer Kasten (M9) |
| Altstadthaus (127) | **feiner** | ja | Treppengiebel als Geometrie, Arkaden, Rahmenfenster, Ziegeldach | – |
| Wohnblock A (86) | **feiner** | ja | Balkone mit Schlagschatten, Rahmen + Sprossen, Putz | Sprossen verschwinden bei 60 m (8 % der Pixel) |
| Wohnblock B (541) | **feiner** | ja | Ziegelverband lesbar, Rahmen + Kreuzsprossen, Ladenzone mit Gesims | braun/blaue Scheiben bei Tag auf 250 m deutlich (M3) |
| Büroturm (5, Maßstab 2,15) | gleich | ja | Vorhangfassade mit Pfosten, Dachaufbau, Antenne | Schachbrett brauner Scheiben bei Tag (M3), weißes Foyer nachts (M8) |
| Hausboot (20) | gleich | nein – ohne Wasser (M2) | Kabine mit Rahmenfenstern, Dachgeländer, Pflanzen, Türlampe | abgewandte Seite fensterlos |
| Fähre (26, Maßstab 0,4) | gleich | nein – ohne Wasser (M2) | wie das Sprite, nachts Kabinenlicht | gemalte Fenster, aus der Nähe weiße Kästen (nie näher als ≈ 60 m) |
| Brückenlaterne (304) | **feiner** | ja | Kandelaber mit drei Laternen, Lichtanker | – |
| Pylon (44) | **gröber** (im Rennen) | **nein** | Beton mit Schalungsbild, Flugbefeuerung, nachts angestrahlt | Seile in den Fahrspuren und vor der Brücke (M1), Stufenwechsel 58 % (M5), feste Höhe |
| Fachwerkportal (15) | gleich | ja | Fachwerk als mipmap-festes Ausschneidebild, Hängelampen mit Lichtfleck | bei 400 m blasser als das Sprite (M10) |

## 2. Wie geprüft wurde

- **Gegenstand und Kopie.** Zweig `worktree-wf_aad8d49e-fb4-2`, Stand `9eef9a8`, nur gelesen. Gerendert und gemessen in
  einer Kopie im Arbeitsordner (`m1/KRITIK-4/tree`: Arbeitsbaum ohne `.git`, `build/`, `_cache3d`, dazu der
  Import-Cache des Hauptarbeitsbaums, einmal importiert; `diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits,
  kein Zweig, keine Datei des AS4-Arbeitsbaums geändert.
- **Renn-Look in den Prüfbildern.** Die Prüfszene ist `tools/models/prop_scene.gd` in der Fassung von AS3 (`be866d2`,
  `--look=race`), nur in der Kopie: das `EnvironmentRig` des Renderers mit der Palette der Stunde, die Stufen der
  Voreinstellung (Schatten, MSAA, Umschaltentfernungen der Requisiten), die Sicht des Rennens und der `vpbr`-Look der
  Fahrzeug-Ebene (`LOOK`, `env_*`), gesetzt **nachdem** die Klassenmaterialien existieren (die Falle der
  Fahrzeug-Kritik). Das Rennen setzt auf `baked` keine Klassen-Parameter (Code gelesen: nur `layers/vehicles.gd` stellt
  `vpbr`/`glass` ein); die Fensterscheiben sind `vpbr`-Lampen und tragen damit den Renn-Look. Gegenprobe: acht
  Rennbilder mit `tools/ab_shot.sh` (Abschnitt 4).
- **Eigene Werkzeuge** (nur in der Kopie benutzt, aufbewahrt unter `m1/KRITIK-4/tools_kritik/` – in eine Kopie des Baums
  nach `tools/kritik/` legen, `prop_scene_as3.*` nach `tools/models/prop_scene.*`):
  - `k4_scene.gd` (erbt von `kritik_scene.gd` der KRITIK-3, das von `prop_scene.gd` erbt): `dist2` (Spielkamera bei
    30/100/250/400 m, je Modell die seitliche Lage aus der Zählung, Maßstab, Wasserfläche, darunter dasselbe als
    Arcade-Sprite-Platzhalter), `outline2` (Umriss in der Sprite-Kamera von `cesprites`: `view_yaw` des Sets und
    `elevation_deg` des Sprite-Manifests), `close` (Nahansichten: Anfahrt, schräg, Straßenseite, Dach, Rückseite),
    `approach` (Anfahrt mit 120 km/h, 30 Bilder/s, Stufenwahl wie der Requisiten-Bauer mit 6 m Hysterese).
  - `mesh_probe.gd` (Lampenkanäle, Farben, Lage von Ecken in den gebackenen Netzen), `texel_probe.gd` (Texeldichte je
    Flächenrichtung aus UV- und Weltfläche).
  - `prop_scene.gd --mode=lods` (Stufenwechsel: Anteil geänderter Pixel und 3×3-Blöcke, Helligkeit, Farbton),
    `kritik_scene.gd --mode=sparkle` (Viertelpixel-Schritte: Anteil kippender Pixel, Modell gegen Sprite).
  - `positions.gd` und `census_all.log` von AS4 (wo die Sets stehen, seitlicher Abstand, Maßstab).
- **Lage der Modelle in den Bildern** (aus der Zählung, gemessen am `Track`-Generator; Anker = Kante + `extent_l` ×
  Maßstab): Ladenhaus 17,6 m, Altstadthaus 15,5 m, Block A 21,5 m, Block B 22 m (Mitte 37 m), Haus 34 m, Kirche 40 m
  (als Wahrzeichen-Ersatz Maßstab 2,2 bei 69 m), Fabrik 49 m, Mühle 90 m, Hausboot 25 m, Fähre 100 m (Maßstab 0,4),
  Büroturm 68 m (Maßstab 2,15), Pylon 7,5 m, Brückenlaterne 6 m, Fachwerkportal über der Fahrbahnmitte.
- **Rahmen der Läufe.** Alles mit `nice -n 19`, immer nur ein schwerer Lauf, `XDG_DATA_HOME` und Mesa-Cache absolut im
  Arbeitsordner. Software-OpenGL (llvmpipe) unter Xvfb: Aussagen über echte Grafikkarten, das Steam Deck und die
  Wirkung auf einen Menschen sind **gefolgert**.

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

## 4. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Acht Läufe in der Kopie, je mit eigenem `XDG_DATA_HOME`, Autopilot, Samen 11, ohne Countdown; Modern ohne
Skriptfehler (0 Treffer für `SCRIPT ERROR|Parse Error|SHADER ERROR`, gemessen). Die Stellen kommen aus der Zählung
(`census_all.log`) und `positions.gd`.

| Bild | Stelle | Befund |
|---|---|---|
| 01 | Kiel–Hamburg ab Kiel, km 77,9 / 78,3 / 79,0, 12 Uhr, Hoch | **M1**: die Pylon-Seile fallen in die Fahrspuren (ein Seil endet vor dem eigenen Auto), zwischen den Pylon-Paaren ein Käfig aus Stäben; die Fächer reichen vor die Brücke. **M2**: zwei Fähren auf der Wiese. Arcade: Seile zur Deckkante, Elbe, Geländer (Deck und Wasser fehlen in Modern bis R5) |
| 02 | Paris–Tours ab Paris, km 129,3 / 130,5 / 131,2, 12 Uhr, Hoch | Haus (Vorderkante 33 m seitlich) und Kirche (81 m) stehen, wo Arcade sie zeigt, gleich groß; das Haus ist gleich hell (Wand p95 202 gegen 203), die Kirche heller (229 gegen 203, gemessen) und dadurch kalkweiß (Bild 29). Modern zeigt die Anfahrtsseite, Arcade die Dreiviertelansicht – im Spiel wirkt Modern ruhiger und genauer |
| 03 | dieselbe Stelle, 23 Uhr, Hoch | Fenster warm und vereinzelt; Arcade-Fenster heller (bis 225 gegen 165) und das Arcade-Haus dunkler – Modern wirkt nachts flauer (**M6**, Bild 28) |
| 04 | Kassel–Würzburg ab Kassel, km 201,6 / 203,0 / 204,8, 21 Uhr, Mittel | Altstadthaus mit Treppengiebel als Modell zwischen Stadthaus-Platzhaltern (Sprites mit Lichtebene); das Modell hat 41 % weniger helle Fensterpixel als das Sprite (gemessen) und fällt neben den hell leuchtenden Platzhaltern ab (**M6**) |
| – | Bremen–Amsterdam ab Bremen, km 357,0 / 358,3, 12 Uhr, Hoch | kein AS4-Set im Bild: die Hausboote an der Singelgracht liegen hinter den Grachtenhäusern (Platzhalter-Sprites); nicht ausgeliefert. Hausboote auf Wasser: Prüfszene, Bild 13 |
| 05 | Hamburg–Hannover ab Hamburg, km 142,4 / 143,3, 12 Uhr, **Steam-Deck-Voreinstellung, 1280×800** | Stadteinfahrt Hannover: fast alle Häuser sind Stadthaus-Platzhalter (`city_*`, AS5a); das Ladenhaus steht klein in der Ferne. Modern füllt 16:10, Arcade mit Balken; kein Fehler der AS4-Modelle sichtbar |
| 06 | Dresden–Leipzig ab Dresden, km 111,6 / 112,8, 15 Uhr, Hoch | Büroturm (Maßstab 2,15) an derselben Stelle wie das Sprite hinter den Häusern; kurz davor bleibt das Modell am linken Rand im Bild (echtes 3D), das Sprite ist dort schon weg. Das braune Scheibenmuster ist im Rennbild auf diesem Abstand schwach zu sehen |
| 07 | Bremen–Dortmund ab Dortmund, km 2,2 / 2,9, 23 Uhr, Hoch | Fabrik (links gespiegelt) mit hellem Werkszeichen und zwei hellen Hallenfenstern, Wohnblock B mit vielen warmen Fenstern; Arcade zeigt die Hallenfenster der Seitenwand hell, Modern die Front – insgesamt matter (M6); keine Shed-Dreiecke von der Straßenseite (M4) |

## 5. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)

### 5.1 Umriss gegen das Sprite (Sprite-Kamera von `cesprites`: `view_yaw` des Sets, 6° bzw. 3,5° Höhe)
`k4_scene --mode=outline2`, Bild `20_umrisse_sprite_gegen_modell.jpg` (grün = beide, orange = nur Modell, blau = nur Sprite).

| Modell | lod0 außerhalb | Sprite gedeckt | IoU lod0 | IoU lod1 |
|---|---|---|---|---|
| house_med | 1,4 % | 100,0 % | 0,986 | 0,998 |
| church | 0,1 % | 99,9 % | 0,997 | 0,999 |
| factory | 0,0 % | 99,3 % | 0,993 | 0,993 |
| windmill | 9,4 % | 88,9 % | 0,814 | – (Flügelstellung: der Rotor dreht mit `ce_time`) |
| building_shop | 0,0 % | 99,8 % | 0,998 | 0,998 |
| building_oldtown | 0,3 % | 99,9 % | 0,996 | 0,999 |
| building_block_a | 0,0 % | 100,0 % | 1,000 | 1,000 |
| building_block_b | 0,0 % | 100,0 % | 1,000 | 1,000 |
| building_tall | 0,0 % | 99,9 % | 0,999 | 0,999 |
| houseboat | 1,7 % | 98,4 % | 0,968 | – |
| bridge_lamp | 1,8 % | 99,3 % | 0,975 | – |
| bridge_truss_arch | 1,9 % | 99,4 % | 0,976 | – |
| bridge_pylon | 5,1 % | 98,8 % | 0,938 | 0,882 (dickere Seile) |
| ferry_ship (Modell um −90° gedreht, Kamera ohne Drehung) | 0,1 % | 99,9 % | 0,999 | – |

Proportionen, Dachformen und Fensterraster stimmen – erwartet, weil die Modelle aus denselben Generatoren stammen.

### 5.2 Texeldichte je Flächenrichtung (`texel_probe.gd`, UV-Fläche × Atlasgröße gegen Weltfläche, lod0)

| Modell | Anfahrt (+Z) | Straßenseite (−X) | abgewandt (+X) | Rückseite (−Z) | Dach |
|---|---|---|---|---|---|
| house_med | 59,8 | 59,8 | 18,0 | 18,2 | 35,5 |
| church | 28,5 | 29,9 | 7,5 | 7,3 | 14,6 |
| factory | 29,2 | **18,7** | 7,3 | 7,3 | 11,8 |
| windmill | 30,5 | 30,0 | 30,0 | 30,5 | 28,9 |
| houseboat | 36,8 | 36,9 | 12,3 | 11,8 | 33,3 |
| ferry_ship (Modellmaß; ×2,5 im Spiel) | 12,1 | 11,9 | 3,6 | 3,6 | 3,7 |
| building_shop | 44,2 | 44,2 | 13,3 | 13,6 | 33,1 |
| building_oldtown | 40,3 | 40,7 | 12,2 | 12,2 | 24,2 |
| building_block_a | 48,9 | 49,0 | 24,5 | 24,6 | 15,1 |
| building_block_b | 43,9 | 44,0 | 22,0 | 22,0 | 13,1 |
| building_tall (÷2,15 im Spiel) | 29,8 | 29,8 | 8,9 | 8,9 | 23,9 |
| bridge_pylon (Mittel über die Höhe) | 18,2 | 15,7 | 15,7 | 18,2 | – |
| farmhouse (AS1b, Vergleich) | 35,1 | 35,1 | 10,5 | 10,6 | 32,3 |

Ziel ≥ 26 px/m an den Wänden zur Straße: erfüllt außer der Fabrik-Seitenwand (18,7) und dem Pylon (AS4: Fuß 29,9,
Kopf 13,4). Die großen Maßstäbe (Turm 2,15, Kirche bis 2,6) senken die Dichte im Spiel auf 11–14 px/m – bei ihrem
Abstand (≥ 68 m, dort 10 px/m Bildschirmauflösung) ausreichend (gerechnet).

### 5.3 Stufenwechsel (`prop_scene --mode=lods`, Renn-Licht 12 Uhr; Anteil der Pixel mit Summe |ΔRGB| > 0,06 und der 3×3-Blöcke)

| Modell | „Mittel“ bei 60 m | „Hoch“ bei 120 m | Helligkeit | nachts bei 60 m |
|---|---|---|---|---|
| house_med (x 34 m) | 11,3 % / 20,8 % | 14,9 % / 18,6 % | +0,9 % / −0,1 % | 8,3 % / 12,7 %, +0,7 % |
| church | 3,4 % / 5,6 % | 4,8 % / 8,3 % | +0,4 % / +0,5 % | 2,0 % / 3,4 %, +0,7 % |
| factory | 6,5 % / 10,9 % | 9,1 % / 6,5 % | −0,1 % | – |
| building_shop (x 18 m) | 4,2 % / 9,3 % | 4,8 % / 9,6 % | −0,3 % / −0,4 % | 5,2 % / 11,3 %, −0,4 % |
| building_oldtown | 8,1 % / 13,9 % | 9,5 % / 18,3 % | 0,0 % / −0,4 % | – |
| building_block_a | 8,3 % / 17,4 % | 10,8 % / 21,0 % | −0,7 % | – |
| building_block_b | 8,9 % / 17,0 % | 10,1 % / 19,4 % | −0,6 % / −1,1 % | 8,6 % / 15,9 %, −0,6 % |
| building_tall | 0,0 % (lod1 = lod0) | – | 0 | – |
| bridge_pylon (x 7,5 m) | **58,5 % / 66,9 %** | – | +1,5 % | – |

Die mittlere Farbe springt nirgends (≤ 1,1 %, bestätigt AS4: ≤ 2/255); was wechselt, sind Sprossen, Rahmen, Uhrzeiger
– Teile von 0,3–0,7 Pixel Breite. Silhouette und Fensterrhythmus bleiben. Ausreißer ist der Pylon (M5).

### 5.4 Flimmern (Viertelpixel-Schritte seitlich, Anteil der Pixel, die je Schritt um > 0,2 kippen; Modell / Sprite)

| Modell | 50–60 m | 100–120 m | 250 m | 400 m |
|---|---|---|---|---|
| building_block_b | 0,1 / 0,1 % | 0,1 / 0,2 % | 0,7 / 0,5 % | 0,9 / 0,4 % |
| building_tall | 0,0 / 0,1 % | 0,0 / 0,1 % | 0,0 / 0,5 % | 0,0 / 0,7 % |
| factory | 0,0 / 0,2 % | 0,0 / 0,5 % | 0,1 / 1,1 % | 0,1 / 1,7 % |
| windmill | **9,3 / 2,9 %** | **9,9 / 2,5 %** | **9,2 / 4,4 %** | **9,3 / 4,3 %** |
| bridge_pylon | 3,0 / 3,0 % | 6,0 / 5,1 % | 0,8 / 6,4 % | 0,8 / 6,2 % |
| bridge_lamp | 7,8 / 5,2 % | 13,6 / 11,2 % | 27,7 / 38,4 % | 37,0 / 61,5 % (19 / 3 px) |
| bridge_truss_arch | 1,1 / 2,7 % | 2,5 / 4,8 % | 8,1 / 10,3 % | 6,7 / 13,7 % |

Gebäude flimmern nicht mehr als ihre Sprites (Block B bei 250–400 m knapp mehr: 0,7–0,9 gegen 0,4–0,5 %); Fachwerkportal und Pylon flimmern weniger als die Sprites; die Windmühle 2–3×
mehr (M7). Bewegtbilder (120 km/h, 30 Bilder/s): `30_film_pylon.mp4`, `31_film_portal.mp4`, `32_film_muehle.mp4`
(angesehen; llvmpipe, ohne echte GPU – gefolgert für das Steam Deck).

### 5.5 Fenster bei Tag und Nacht (Netzdaten mit `mesh_probe.gd`, Bildpixel)
- Leuchtfarben Kanal 12: Haus (120, 92, 50), Block B (120, 92, 51), Kirche (120, 98, 57), Turm (125, 103, 83);
  Gewichte 0,50–1,00. Glas ohne Lampe: Haus (38, 48, 59), Turm (57, 83, 103). Turm: 1 247 Lampen-Ecken, 1 512 Glas-Ecken.
- Bei Tag im Bild (Block B aus 7 m): Lampen-Scheiben (53, 45, 39) … (69, 62, 50), Glas (39, 52, 63) – gleich dunkel,
  entgegengesetzter Farbton (M3).
- Nachts im Rennen (Paris–Tours km 131,3, Haus 70 m voraus): Arcade-Fenster bis Leuchtdichte 225, Modern bis 165 (M6).

### 5.6 Prüfer, Budgets, Zeichenaufrufe, Bytes (auf der Kopie)
`validate_models.py --report`: **CHECK models OK**, 41 Modelle, 182 Sets (53 mit Modell); Netze 4,94 MB von 40 MB,
Texturen 26,85 MB Grafikspeicher von 240 MB, Quellen 14,57 MB von 60 MB – dieselben Zahlen wie bei AS4. Je Modell:
Land 1 054–1 928 Dreiecke (Budget 2 000), Stadt 1 085–5 180 (10 000), Laterne 882 und Portal 1 100 (1 500), Pylon 520
(5 000); Aufrufe 2/2 bzw. 1. AS4-Anteil: Netze 0,49 MB, Texturquellen 5,07 MB (AS4, Summen der Tabelle bestätigt).
Bake-Zeiten (AS4 gemessen, nicht wiederholt – Export ist schwer): 46–144 s je Gebäude, Godot-Bake ≤ 0,05 s.
Umschaltentfernungen: lod0 bis 40 / 60 / 120 m (niedrig / mittel / hoch, `prop_lod0_m`), danach lod1 ohne Fernbild.
Sprite-Geometrie, `--check-keys`, Determinismus, `run_tests.sh` und `golden.sh` habe ich nicht wiederholt (nur lesende
Rolle, keine Änderung; AS4 meldet alle grün auf `9eef9a8`).

## 6. Was ich von den AS4-Angaben bestätige – und was nicht

| AS4 sagt | Prüfung | Ergebnis |
|---|---|---|
| Budgets eingehalten, Validator OK | `validate_models.py --report` auf der Kopie | **bestätigt** (gleiche Zahlen) |
| Wände zur Straße 29,5–59,9 px/m | `texel_probe.gd` | **bestätigt** für die Anfahrtsseiten; die **Seitenwand** der Fabrik zur Straße hat nur 18,7 px/m |
| Farbsprung beim Stufenwechsel ≤ 2/255 | `prop_scene --mode=lods`, Tag und Nacht | **bestätigt** (Helligkeit ≤ 1,1 %); der Pylon wechselt aber 58 % seiner Pixel (M5) – die 3,2 % von AS4 galten für einen anderen Ausschnitt |
| Modelle stehen im Rennen, wo Arcade die Sprites zeigt, gleich groß und farbig | eigene A/B-Bilder | **bestätigt** für die Gebäude; **nicht** für den Pylon: Arcade zeichnet ihn prozedural mit Seilen zur Deckkante, das Modell legt sie in die Fahrspuren (M1). Die AS4-Bilder (km 75,8, ≥ 120 m davor) zeigen das nicht |
| Bei Tag leuchtet nichts | Bildpixel, Netzdaten | **bestätigt** (Scheiben 0,21–0,27 Helligkeit); aber die Lampen-Scheiben sind bei Tag braun statt blau (M3) |
| Nachts leuchten die Fenster unregelmäßig wie im Sprite | Prüfbilder und Rennbild | **bestätigt**, aber matter als Arcade (M6); am Turm in Spalten (M8) |
| Fachwerk bis 400 m lesbar ohne Flimmern | Viertelpixel-Test, Film | **bestätigt** (flimmert weniger als das Sprite); bei 400 m blasser (M10) |
| Seile bei 400 m 0,6 px, bei „niedrig“ evtl. Flimmern | Viertelpixel-Test | Flimmern 0,8 % (Sprite 6,2 %) – **unkritisch**; das Problem der Seile ist ihre Lage, nicht ihre Stärke |
| Fähre schwächstes Modell | Prüfbilder | **teilweise**: auf Spielabstand (≥ 60 m, Maßstab 0,4) ist sie dem Sprite gleich; schwächer im Rennen ist der Pylon |
| Prüfwerkzeuge überstrahlen helle Putzwände, im Renn-A/B nicht | Renn-Look-Prüfszene (AS3) gegen A/B | **teilweise**: nicht ausgebrannt (Kirchenwand im Rennbild p95 229 < 255), aber 13 % heller als das Arcade-Sprite (203) und damit kalkweiß (M10, Bild 29); das Haus ist gleich hell |

## 7. Vertragsfragen und Bedarf bei anderen Paketen

- **Pylon gehört eigentlich zum Brückenbau (R5).** Arcade zeichnet ihn prozedural (`prefer_proc`, `height_m`,
  `cables`); ein Modell fester Höhe mit fest eingebauten Seilen passt zu keiner Brücke des Netzes. Vorschlag für einen
  Nachtrag: `bridge_pylon` wird als Modell **ohne Seile** geliefert (Bein, Kopf, Flugbefeuerung), Seile und Höhe kommen
  vom Renderer aus den Track-Daten (`height_m`, `cables`, Deckkante) – bis R5 durch den Requisiten-Bauer (R2),
  wie es `RoadRenderer._pylon()` tut.
- **Schiffe ohne Wasser.** Der Requisiten-Bauer setzt Requisiten mit `h` < 0 auf das Gelände, solange es kein Wasser
  gibt. Bis R5: auslassen (Grund „water“ in `drop_reason()`, R2).
- **Fensterlicht (Kanal 12) bei Tag.** AS1b und AS4 haben es beide gemeldet: eine unbeleuchtete `vpbr`-Lampe zeigt
  die halbe Leuchtfarbe. Für Fenster heißt das: entweder braun bei Tag (heute) oder kalt bei Nacht. Ein Nachtrag sollte
  eine Tagesfarbe für Kanal 12 festlegen (Uniform `lights_day_tint` oder eine Rolle „Fenster“), Besitzer des Shaders
  in Welle 3 ist R4.
- **Kein Budget „Schiff“** (AS4): bestätigt; auf Spielabstand reicht das Landgebäude-Budget – keine Änderung nötig.
- **Requisiten-Bauer skaliert nicht nach `height_m`** (AS4): bestätigt für den Pylon; betrifft auch die Kirche als
  Wahrzeichen-Ersatz (Maßstab aus `scale`, das funktioniert).

## 8. Für die Nacharbeit (AS4-N) und die anderen Pakete – in dieser Reihenfolge

1. **M1 Pylon** vor dem Kiel–Hamburg-Testbuild: Seile an die Deckkante, Fächer ≤ 60 m, eine Stufe; besser Pylon ohne
   Seile + Seile vom Renderer (R2 jetzt, R5 später). Danach Bild 01 mit denselben Argumenten wiederholen
   (`tools/ab_shot.sh … --stage=kiel_hamburg --from=kiel --start-km=77.4 --start-speed=50 --shot-times=1,2.5,4,6`).
2. **M2** R2: Schiffe auslassen, solange es kein Wasser gibt.
3. **M3/M6** Shader-Besitzer: Tagesfarbe für Kanal 12; danach AS4-N: Scheiben-Leuchtfarbe Sprite-Licht × 0,7–0,8,
   alle Scheiben einer Fassade gleiche Tagesfarbe. Messen wie hier: Bildpixel der Scheiben bei Tag, Fensterleuchtdichte
   nachts gegen Arcade an Paris–Tours km 131,3.
4. **M4** Fabrik-Glasbänder, **M5** Pylon eine Stufe, **M7** Mühlenflügel zweite Stufe, **M8–M10** Kleinteile.
5. Werkzeuge für die nächste Runde (nicht eingecheckt): `m1/KRITIK-4/tools_kritik/`
   (`k4_scene.gd` mit `dist2`, `outline2`, `close`, `approach`; `mesh_probe.gd`; `texel_probe.gd` – Achtung: Godot
   wickelt Vorderseiten im Uhrzeigersinn, die Normalen des Kreuzprodukts zeigen nach innen). `prop_scene.gd` mit
   `--look=race` liegt nur auf dem AS3-Zweig – beim Zusammenführen mitnehmen.

## 9. Bilder und Filme (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `01_rennen_pylon_seile_in_der_fahrbahn.jpg` | M1/M2: Kiel–Hamburg km 77,9 / 78,3 / 79,0, Arcade \| Modern |
| `02_rennen_dorf_tag.jpg`, `03_rennen_dorf_nacht.jpg` | Paris–Tours km 129–131: Haus und Kirche, Mittag und 23 Uhr |
| `04_rennen_altstadt_abend.jpg` | Kassel–Würzburg km 201,6–204,8, 21 Uhr |
| `05_rennen_stadt_steamdeck.jpg` | Hannover-Einfahrt, Steam-Deck-Voreinstellung, 1280×800 |
| `06_rennen_bueroturm.jpg`, `07_rennen_fabrik_nacht.jpg` | Dresden–Leipzig km 111–113; Bremen–Dortmund km 2–3 nachts |
| `10`–`14_*_abstaende_tag_daemmerung_nacht.jpg` | Spielkamera 30/50–400 (600) m, Modell über Arcade-Sprite, 12 / 19:30 / 23 Uhr |
| `20_umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera (IoU-Tabelle 5.1) |
| `21_nahansichten_tag.jpg`, `22_nahansichten_nacht.jpg` | je Modell: Anfahrt, schräg, Straßenseite, oben, Rückseite |
| `23_fenster_tag_braun_blau.jpg` | M3 |
| `24_fabrik_dreiecke_nacht.jpg` | M4 |
| `25_stufenwechsel.jpg`, `27_pylon_stufenwechsel.jpg` | Stufenwechsel Mittel/Hoch/Nacht; M5 |
| `26_flimmern.jpg` | Viertelpixel-Test Modell gegen Sprite |
| `28_nachtfenster_arcade_gegen_modern.jpg` | M6 |
| `29_kirche_hell_im_rennen.jpg` | Kirche im Rennen heller als das Sprite (M10) |
| `30_film_pylon.mp4`, `31_film_portal.mp4`, `32_film_muehle.mp4` | Anfahrt mit 120 km/h, 30 Bilder/s, Spielkamera, Stufenwahl mit Hysterese |

## 10. Prozess und Werkzeuge (was die Prüfung von AS4 verfehlen ließ)

- Die Renn-A/B-Bilder von AS4 endeten 120–260 m vor dem Pylon; die Vorbeifahrt (≤ 40 m, auf der Brücke) wurde nie
  gezeigt – genau dort liegt M1. Brückenteile und Straßenmöbel brauchen ein Rennbild **auf** dem Bauwerk.
- `prop_scene.gd --look=race` gibt es nur auf dem AS3-Zweig (`be866d2`); die Prüfbilder von AS4 entstanden im kleinen
  Prüf-Rig (überstrahlte Putzwände). Das Werkzeug sollte vor den nächsten Modellpaketen zusammengeführt werden.
- Weder Kontaktbogen noch Prüfszene haben Wasser: die Wasserlinie der Schiffe ließ sich nur mit einer eigenen
  Prüf-Wasserfläche beurteilen (Vorschlag: Option `--water` in `prop_scene`).
- Der Prüfer sieht keine lageabhängigen Fehler: eine Prüfung „kein Teil eines `bridge`-Requisits unter 2,5 m Höhe
  innerhalb der halben Deckbreite“ hätte M1 gefunden.
- Messwerte des Stufenwechsels hängen vom Ausschnitt ab (Pylon: 3,2 % bei AS4, 58,5 % an der echten Lage x 7,5 m):
  an der seitlichen Lage aus der Zählung messen.
- `ab_shot.sh` mit Autopilot beschleunigt (50 → 141 km/h in 6 s, nachts bis 200 km/h): Stellen werden schneller
  passiert als geplant; Startgeschwindigkeit nahe der Reisegeschwindigkeit wählen.
