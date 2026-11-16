# M2INT – erste Zusammenführung von M2 (Bericht)

Paket **M2INT** des Schubs M2 (Vertrag §6 Wellen 3–5, §11.2 A-9 … A-16). Basis `350b071` (= QA1-Kopf `92ece73` +
Vertragscommit §11.2). Branch `worktree-wf_438996b0-243-1`, Sicherung `origin/wip/v080-m2int` (nach jedem Commit
gepusht), Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1`.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. ohne Bildschirm, 4 geteilte Kerne, bis zu sechs Pakete
gleichzeitig); alles über echte Grafikkarten, Steam Deck, ANGLE/Direct3D und Klang für Menschen ist **abgeleitet**.

## 1. Zusammenführungen

| Merge | Commit | Konflikte und Lösung | Prüfung danach (gemessen) |
|---|---|---|---|
| AS2R `c7546c1` (alle Fahrzeugmodelle) | `aa9a469` | `catalog3d.py`, `export_models.py`: Vereinigung; `contact_sheet.gd`: `--showroom` mit dem Showroom-Look (RINT-B), sonst Renn-Look mit vorher angelegten Klassenmaterialien (AS2R C2); `docs/modelle.md`: beide Teile, Nummern 14 Umgebung / 15 AS2a / 16 AS2b / 17 AS2R; Lkw-Dateien von AS2R, Kanal 15 neu exportiert (`da7483a`); Manifest neu erzeugt | Import ohne Fehler, 304 Skripte fehlerfrei, `check_vehicles` zuerst 2 rot (kasten, leistung – Leitungsnotiz 4), nach `632b411` 8 von 8 OK; Modell-Tests 48/48; Prüfer OK |
| AS3R `638debc` (Vegetation) | `0e0f45c` | `catalog3d.py` Vereinigung; `docs/modelle.md` AS3 = Abschnitt 18; Manifest neu | Prüfer OK (73 Modelle), `test_props` 7/7 (mit Notiz-4-Änderung), Modell-Tests 48/48 |
| AS4R `09f679b` (Gebäude, Brückenteile, Schiffe) | `afe1c8d` | `catalog3d.py`, `export_models.py` Vereinigung; `docs/modelle.md` AS4 = Abschnitt 19, Standzeile, Abschnittsverweise der Bauer-Module; Manifest neu | Import der 26 neuen Texturen (≈ 12 min bei nice 19), Prüfer OK (87 Modelle, 183 Sets, 105 mit Modell; Netze 18,08/40 MB, Texturen 38,20/240 MB, Quellen 26,58/60 MB), `test_props` 7/7, Modell-Tests 48/48 |
| Klang `f253687` (AU-R4-Kopf) | `d493c6a` | `docs/audio-modern.md` §1: Text von FIX1 zur Einstellung „Klang“ behalten, neue Absätze AU-D2/AU-C1/AU-R3 dazu, überholter Satz entfernt | Import ohne Fehler, `config/game_config.json` gültig, Klang-Tests 172/172 |

## 2. Leitungsnotizen

### Notiz 2 – Lkw: Rückstrahler-Kanal 15, Re-Export, Determinismus
- Die drei Sattelzug-Typen von AS2b/AS2R bauen ihren Auflieger mit demselben `truck3d._trailer`: Konturband
  rot/gelb und Dreiecksrückstrahler tragen in allen drei `"retro:%.2f" % TAPE_NIGHT` (RINT-B, im zusammengeführten
  `truck3d.py`), `roles.py` (SURFACE_CHANNELS + retro) und der Prüfer (16 Kanäle) von RINT-B sind behalten.
  Gemessen (Kanalzählung der gebackenen Netze): Kanal 15 in `lod0_trailer` / `lod1_body` / `lod2_body` aller drei
  Typen (60 / 52 / 1 502 Ecken beim Planen-Lkw). Bus: keine retroreflektierenden Flächen (Leuchten Kanal 9);
  Polizei: das Reflektorbett der Lichtbalken ist Chrom, kein Rückstrahler. **SUV**: seine Stoßfänger-Rückstrahler
  (von AS2R sichtbar gemacht) sind `"-tail:0.3"` – Kanal 0 mit Gewicht 0,3 ohne Lichtanker, sie glimmen mit dem
  Rücklicht wie im Arcade-Sprite; bewusst nicht auf Kanal 15 gelegt (das wäre ein neuer Look gegenüber Arcade und hätte
  alle Verkehrs- und Polizeimodelle neu exportiert).
- `--check-keys` ist ein Selbsttest des Schlüssels, keine Liste veralteter Modelle. Weil `roles.py` und
  `ce3d/__init__.py` zu `COMMON_CODE` gehören, sind nach der Zusammenführung **alle** Schlüssel neu (gemessen: jeder
  Export lief neu). Exportiert habe ich nur, was neue Dateien braucht (drei Lkw, später olive_b und Bus) und, als
  Beleg, die AS1b-Modelle des Bauers „building“, Strommast, Windrad, Laterne und den Michel: **alle byte-gleich**.
- Danach **ein Bake aller 87 Modelle** aus den Zwischenständen (Caches von AS2R, AS3R, AS4R per `cp -an` je Eigentümer
  übernommen + die neu exportierten): außer den gewollten Änderungen (olive_b, Bus) byte-gleich mit dem Repository
  (`git status` leer), Manifest mit `--manifest-only` neu erzeugt, Prüfer OK. Zweiter erzwungener Export + Bake der
  Lkw: byte-gleich.

### Notiz 3 – Vereinigungen
`contact_sheet.gd`: AS2a (`--tonemap=agx`), AS2b (`--arcade` für Verkehr/Polizei/Lkw, Blaulicht-Kachel), AS2R (Look
mit vorher angelegten Klassenmaterialien), RINT-B (`--showroom` mit dem Showroom-Look), AS3 (Sets für Varianten im
Prozess) – alle drin; der Look kommt seit `f040637` aus `ModernMaterials`. `catalog3d.py`/`export_models.py`: Vereinigung
aller Einträge; `docs/modelle.md`: eine Nummerierung 14 Umgebung, 15 AS2a, 16 AS2b, 17 AS2R, 18 AS3, 19 AS4.

### Notiz 4 – Tests
- `check_vehicles.gd` „kasten“: Test-Manifest (das ausgelieferte mit `traffic/sports_red` und `police/at` ohne Modell)
  in `user://`; `ModelDB.load_manifest()` liest dafür einen optionalen Schlüssel `"root"` (Ordner der Netzpfade, nur
  `res://`), danach wird das ausgelieferte Manifest wieder geladen. „leistung“: die 35. Knotenbau war ein Sportwagen
  des echten Verkehrs, der im Messfenster von lod1 (118 m) nach lod2 (147 m) fuhr – die erste Stufe eines Autos ist
  erlaubt, jede weitere (Neubau nach Freigabe) nicht; dazu keine Freigabe fürs Instanzbudget. 8 von 8 OK, 28,7 µs je
  Auto (Referenz × 0,97, gemessen).
- `test_props.gd`: AS3-Vorschlag übernommen, aber ohne festen Set-Namen (die Kirche hat seit AS4 ein Modell): das
  erste Requisiten-Set, das das Manifest als Arcade-Bild zeigt, Kontaktschatten nach dessen Klasse. 7 von 7.
- Zwei **Render-Prüfungen**, die der Inhalt überholt hat (Vorlauf `run_render_checks.sh all`, `af5fbe1`):
  `check_props_render` „props_spiegel“ stellte Buche und Fels als Ersatzbilder auf – seit AS3 Modelle mit zufälliger
  Drehung, das Bild kann nicht sein eigenes Spiegelbild sein (Abweichung 10,56); jetzt Bauernhaus und Laterne (Modelle
  ohne Drehung) und zwei Stadthäuser ohne Modell: 0,13, OK. `check_vehicle_standin` „laden“ verlangte gezeigte
  Ersatzbilder – seit AS2R hat jedes Fahrzeug-Set ein Modell; jetzt nur, solange eines fehlt, sonst kein Ersatzbild und
  kein Blatt (0, 0,0 MB), OK.
- Neu: `test_props` „static_vpbr_has_no_instance_uniforms“, Render-Prüfung `check_instance_budget_wald.gd`,
  `check_minimal_structures` „wahrzeichen“ mit Nachtstart (Notizen 5 und 6).

### Notiz 5 – Speicher, Instanzen, Größe
- **Ersatzbilder der Fahrzeuge** werden in `prepare()` nicht mehr geladen: die Fahrzeug-Ebene lädt nur Bögen von
  Sets ohne Modell (`_load_standins` überspringt `ModelDB.has_model`) – gemessen `standin_sheets` 0, 0,0 MB auf
  Kiel – Hamburg und Dortmund – Frankfurt km 221.
- **Texturspeicher** (A-6: Modern ≤ Arcade derselben Etappe + 60 MB; `Performance RENDER_TEXTURE_MEM_USED` nach 15 s
  Fahrt, Xvfb 1280 × 720, Voreinstellung dieses Rechners, gemessen): Kiel – Hamburg km 2 Arcade 225,8 MB / Modern
  **103,6 MB**; Dortmund – Frankfurt km 221 (City Limits, 19:30) Arcade 214,6 MB / Modern **97,5 MB**. Modern braucht
  weniger als Arcade, weil es die Sprite-Bögen der Fahrzeuge nicht lädt.
- **Instanzen mit Instanz-Uniforms** (Zählprobe von RINT-B, Kiel – Hamburg km 2, Autopilot 120 km/h, 900 Bilder):
  Fahrzeug-Ebene höchstens **107 von 128** (`INSTANCE_BUDGET`), 0 Freigaben; alle `vpbr`-Instanzen zusammen höchstens
  157 während der Fahrt, 217 in den ersten Bildern (Aufwärmknoten) – der globale Puffer fasst 256 (4 096 Plätze / 16).
- **Überlauf auf Waldetappen – behoben** (`b2c6b52`): Kiel – Hamburg in „niedrig“ blieb darunter, aber in „Hoch“
  meldete Godot „Too many instances using shader instance variables“ in den A/B-Läufen T1 (5×) und T4 (2×) und im
  ersten Clip Dortmund – Frankfurt km 121 (55×, abgebrochen) – gemessen in den Logs. Ursache: jeder Baum von AS3R hat
  einen Stamm in `vpbr`, jeder MultiMesh-Knoten mit `vpbr` nimmt 16 Plätze, auch wenn er nie einen Instanzwert setzt.
  Abhilfe: alle Modelle, die keine Fahrzeuge sind, zeichnen `vpbr` mit `ModernMaterials.VPBR_STATIC` (derselbe Shader,
  Instanz-Uniforms als gewöhnliche Uniforms mit denselben Vorgaben; Look und Klassenparameter wie bisher). Gemessen
  danach: Render-Prüfung `instanzen` ganze Szene höchstens **142** (RINT-B: 196–229), neue Prüfung `instanzen_wald`
  (Kassel – Würzburg ab km 46,5, „Hoch“, Autopilot) höchstens **140**, keine Ablehnung; T1 „Hoch“ neu gerendert:
  0 Ablehnungen, **pixelgleich** mit dem Bild vor der Änderung (die A/B-Bögen von `c317625` gelten weiter).

### Notiz 6 – Look nach dem Inhaltswechsel
- **Ferne Stufen gegen den heutigen Look** (Werkzeuge von AS2R, auf diesen Worktree umgestellt, gemessen, Mittel in
  beiden Stufen am Wechselabstand): Transporter-Heckscheibe 40 m (69, 86, 107) / (67, 87, 111); Limousinen-Kennzeichen
  40 m (192, 193, 195) / (197, 201, 202); Bus-Heckscheibe 60 m (70, 86, 105) / (69, 86, 105), 0,0 % der Fensterpixel
  > 24 Stufen; Bus-Kennzeichen 180 m (161, 170, 181) / (165, 174, 185) – seit M2INT mit `heavy3d.FAR_PLATE` `#a2a2a0`
  wie der Verkehr (vorher `#c4c4c1`, etwa 50 Stufen zu hell). Scheiben und Kennzeichen sind feste Farben, Knie und
  Entsättigung von RINT-B wirken nur auf Lack: `TRAFFIC_GLASS_FAR`, `truck3d.GLASS_FAR`, `FAR_PLATE` stimmen weiter.
  **Polizei-Karoband** (Lack) 120 m: (166, 171, 126) / (168, 175, 112) – Rot/Grün stimmen, Blau 14 Stufen tiefer (die
  8 % Entsättigung ziehen die Karos von lod1 zum Grau, die Mischfarbe von lod2 weniger); 7 × 2 Pixel, offen gelassen.
- **Stufenwechsel mit der Überblendung von RINT-B** (`pop_probe.gd` von RINT-B, Auto fährt langsam durch die Grenze
  lod1 → lod2, Voreinstellung dieses Rechners: Grenze 90 m, gemessen): größte Änderung je Bild rund um den Wechsel SUV
  7,2 %, Sportwagen 8,1 %, Polizei Belgien 13,1 % (Bewegung allein im Median 0,3 / 0,8 / 0,5 %); vorher, ohne
  Überblendung, sprangen 28–30 % bzw. 38 % in einem Bild (AS2R-Zählweise, andere Messung). Der **Bus** wechselt bei
  180 m × 90/120 = 135 m (Kopie der Probe mit `--lod1=135`): größte Änderung je Bild rund um den Wechsel 4,7 %, Summe
  über 40 Bilder 19,3 %, Bewegung allein 0,0 % (vorher 22 % in einem Bild, AS2R); der Bus ist dort 18 × 15 px groß.
  Der Wechsel lod0 → lod1 der Limousine (40 m) ist ohne Überblendung (nur lod1/lod2 blenden, `XFADE_LODS`),
  unverändert 14 % (AS2R).
- **Metallic-Flocken**: im Renn-Look aus (`flake_strength` 0), im Showroom an – eine Flockenzelle ist beim Spielerauto
  0,3 px breit (KRITIK-2 A4: 83 glitzernde Pixel je Bild).
- **Showroom-Flags**: alle bleiben `false` (Bild `showroom_ab_agx.jpg`; Tür-Messung Echtzeit/Sprite: Helligkeit
  × 0,95–1,18, Sättigung bei Kombi/Limousine/Sportwagen +0,24…+0,39 – ohne Klarlack-Spiegelung wirkt der Lack flach und
  bunt, der Kompakt bleibt blass, der Sportwagen kippt nach Orange). Kein Auto ist mindestens so gut wie das Sprite.
- **Look an einer Stelle** (A-13): `ModernMaterials.VEHICLE_LOOK`, `VEHICLE_PLAYER_FILL`, `STUDIO_LOOK`,
  `apply_look()`; Fahrzeug-Ebene, Showroom, Kontaktbogen und `prop_scene` lesen dort.
- **Wahrzeichen bei Nacht** (`c317625`, Befund aus dem A/B Köhlbrandbrücke 22 Uhr): Arcade zeigt Elbphilharmonie und
  Michel beleuchtet, Modern zeigte dort nichts – die Nachtsicht ist 495 m, Wahrzeichen standen nur bis 2 × Sicht = 990 m
  am Pfad und wurden weggedithert. Arcade zeichnet die Lichtebene nachts bis `landmark_far_m` (1 900 m) ohne Dunst. Jetzt
  ebenso (`props.far_reach`, Licht-Pfad in `billboard.gdshader` und – für den Michel – `baked.gdshader`); Prüfung
  `check_minimal_structures` „wahrzeichen“ um einen Nachtstart erweitert (1 900 m statt 990 m, 2 Wahrzeichen, gemessen).
  Bild `koehlbrand_nacht_ab.jpg`: beide leuchten an Arcades Stelle; der Michel ist als Modell ganz angestrahlt (sein
  Emissionsatlas), in Arcade verdecken ihn die Giebelhäuser fast.

### Notiz 7 – Punkte von AS3R/AS4R
- **Olive**: `tree_olive_b` eigener lod1-Abgleich (lift 1,057 statt 1,12 der Art, neuer 3D-Parameter „lift“ einer
  Saat-Variante). lod0 → lod1 bei 60 m mittags / 19:30 / 23 Uhr: vorher +5,0 / +6,5 / +8,3 %, jetzt −0,2 / +0,5 /
  +0,7 % (gemessen, `prop_scene.sh --mode=lods --look=race`); `tree_olive` unverändert −1,9 / −0,4 / −0,4 %.
- **Saat-Varianten im exportierten Spiel**: aus dem Linux- und dem Windows-Export geladen (Barcelona – Montpellier
  km 42,7, Abschnitt 4, Bild `oliven_aus_pck_linux_windows.jpg`).
- **Schlüssel des Bauers „building“** (AS4Rs Hook in `props_buildings.py`): AS1b-Modelle neu exportiert –
  byte-gleich (Notiz 2).
- **AS1b-Fensterscheiben** (Bauernhaus, Zollhäuschen, Tankstelle: Kanal-12-Scheiben bei Tag braun/blau): **nicht
  umgebaut**. Der Weg von AS4R ist der Bauer „house“ (`buildings3d.py`); er backt die Scheiben in den Nachtlicht-Atlas,
  müsste aber die Wandlampe des Bauernhauses und die Dachlampen der Tankstelle mit ihren Lichtankern (Lichtkegel nachts,
  `test_props`) erhalten – ein eigener Kunstdurchgang mit Bildprüfung, kein billiger Umbau. Liste für AS5/R6.
- **Fähre nie gespiegelt**: Tags `prop, ship` ohne `mirror_left`; der Props-Bauer spiegelt ein Modell nur mit
  `mirror_left` (gemessen im Manifest). Das Hausboot trägt `mirror_left` (Bug zeigt nicht nach vorn, Arcade spiegelt
  es auch).
- **Schiffe nur auf Wasser** (A-16): `Track` stellt Fähren und Hausboote nur neben Brücken über Wasser – Probe über
  alle 128 Etappenrichtungen: 46 von 46 auf Wassersegmenten, Rumpf (± 25 m) ganz über Wasser. Dass sie trotzdem auf
  der Wiese standen, war der Fernboden (Befund FIX-ZS1-B1): die Scheibe lag 4 m unter der Straße, die Elbe 9 m
  (aus Hamburg 16 m). Behoben in `b341df8` – die Scheibe liegt unter dem Wasser der geladenen Brücken; eine Regel für
  Modelle und Ersatzbilder, weil sie am Boden ansetzt, nicht am Set.
- **Pylon Köhlbrandbrücke** (eine Stufe, Halbfächer ±36 m): A/B Kiel – Hamburg ab km 77,4, Hoch, 12 Uhr Bilder bei 2–7 s
  (über beide Pylone, unter 40 m) und 22 Uhr: kein Seil über einer Spur, die Seile enden an der Geländerlinie
  (Bilder `koehlbrand_*`). Höhe je Brücke (`height_m` / 88,8): kein Einzeiler (das Item trägt `height_m` auch bei
  Wahrzeichen; nicht-gleichmäßige Skalierung der Instanz) – bleibt bei R5 (A-16).
- **Fensterlicht** `emit_energy` 1,6 unverändert. **Nicht von mir** (R7/R4): Baum-Überblendung, `ground_align` /
  `ground_sink` / `face_road`, Tageszeit-Relief der Fernbilder, Kurvenkorridor-Regel, Rotorphase der Windmühle (springt
  bei jedem Ursprungsversatz alle 2 km, `vpbr` nutzt die ursprungsrelative Position) – gelistet.

### Notiz 8 – Klang im Spiel
- **Menüklänge** (`9477629`): die drei UI-Klänge von AU-D2 ohne Aufruf klingen im Profil Modern – Optionen LB/RB
  `ui/ui_tab`, ◀▶ in einer Zeile `ui/ui_toggle`, ◀▶ am Listenende `ui/ui_error`; im Profil Arcade bleibt es bei
  v0.7.0 (`ui_move`, am Listenende still). `UiKit.sound_modern()` liest das Klangprofil, nie den Grafikmodus (Regel 4).
  `check_options_tabs.gd` um „klang_wert“ und „klang_seite“ erweitert: 12 von 12 OK (gemessen).
- Schichten Fahrbahn/Reifen/Wind/Aufprall mit Motor v3 und Modern-Limiter, Musikrotation 1–3 mit Stingern und
  Zwischenspiel, Arcade byte-gleich: belegt durch die Prüfungen, die mit dem Klang-Merge kamen und in
  `tools/run_tests.sh` laufen – `check_modern_audio` (arcade_boot, delegation, race, arcade_after: Mischer-SHA-256 wie
  v0.7.0), `test_arcade_identity`, `check_arcade_lean`, `check_music`/`test_music_director`, `test_road_audio`,
  `test_modern_mix`, `check_engine3`. Nach dem Merge 172 von 172 Klang-Tests (gemessen); Endstand siehe Abschnitt 5.
- Kein „leaked at exit“: Render-Prüfung `check_quit_sound.gd` (je Profil drei Spielstarts mit Titelmusik, Beenden
  über `GameFlow.quit_game()`); `audio_qc.py` über alle Ordner – beide in Abschnitt 5.

### Notiz 9 – Modern-Goldens
Erst angesehen, dann neu erzeugt (`49f221e`): `golden.sh modern-check` mit `KEEP` auf `af5fbe1` – **0 von 6
identisch** (der Inhalt von M2 ändert jedes Bild), OpenGL ES gegen OpenGL an S3 „Hoch“ OK (max. 2/255, PSNR 73,2 dB);
die sechs Bilder angesehen (Start mit Tor und Countdown, S2 Tankstelle, S3 Autobahn „Hoch“, S4 Stadtgrenze, S5 Ziel,
S1 Nacht): Bäume, Verkehr und Gebäude von M2, keine Fehler außer dem bekannten Startbild (Spielerauto im Countdown
unsichtbar – behebt erst ZS1). `modern-make` danach pixelgleich mit diesen Bildern, Liste und `modern_slice.env`
im Commit. Mit dem ZS1-Merge sind sie noch einmal neu zu erzeugen (Start und S4 ändern sich dort).

### Notiz 10 – Zeitplan und Start-Fix (ZS1)
**`ZS1_FERTIG` lag bis 12:00 UTC nicht vor** (geprüft alle 10 min von 04:30 bis 12:00, zuletzt 12:00:13); die Datei
erschien erst um 12:47 UTC mit `39849f0` (= `wip/v080-fix-wasser-r`). Nach der Vorgabe habe ich **ohne diesen Merge
abgeschlossen**. Bis zum Schluss liefen alle schweren Jobs mit `nice -n 19` und
einzeln. Stand der Zweige zuletzt: `wip/v080-fix-zs1` `3a23cb8`, `wip/v080-fix-wasser` `0ad9012`,
`wip/v080-fix-wasser-r` `39849f0` (Leitungs-Workflow `wf_m2k_zs1_wasser` noch in Arbeit).
Vorbereitet für den Merge (Probe mit `git merge-tree`, gemessen):
- `3a23cb8` (FIX-ZS1) allein: **konfliktfrei**.
- `39849f0` (FIX-WASSER-R, enthält FIX-ZS1): Konflikte nur in `scripts/race3d/layers/far_ground.gd` und
  `docs/renderer-modern-gelaende.md` – dieselbe Ursache (Fernboden über der Elbe, Befund FIX-ZS1-B1) hat M2INT in
  `b341df8` anders behoben. Empfehlung: die Lösung von FIX-WASSER übernehmen (`target_height`/`lowest_water`, eigene
  Tests), mein `lowest_road(…, track)` und `test_terrain_builder` „far_ground_lies_below_the_water_of_a_bridge“
  streichen, Doku von FIX-WASSER. `props.gd` und `test_props.gd` (Wahrzeichen-Ersatz, dunkle Pylone) mischen sich
  automatisch mit `far_reach` und `VPBR_STATIC`. Danach: Modern-Goldens einmal neu (Start und S4 ändern sich), die
  Render-Prüfung `check_light_base` „schatten“ wird grün (Lampenringe des Starttors), `check_start_km0` kommt dazu.
  Die Merge-Nachricht liegt bereit (`m1/M2INT/msg_merge_zs1.txt`).
- Folgen hier: der Start-Clip zeigt den Stand **ohne** Start-Fix (in Modern ist das Spielerauto im Countdown
  unsichtbar, Bild `clips/kiel_hamburg_start_bilder_1_5_20s.jpg`); `check_light_base` „schatten“ bleibt rot (QA1-Befund).

## 3. Bilder – A/B gegen Arcade und gegen ZS1

`tools/ab_shot.sh`/`ab_sheet.sh` an S1–S5, T1, T4, C1 (19:30), N1 (Nacht, Schnee), N2 (Regen), Modern „Hoch“ und die
Voreinstellung dieses Rechners („niedrig“), dazu S1 mit Kombi, Sportwagen und Gran Turismo (Hoch); gerendert aus einer
Kopie des Worktrees bei `c317625`. Ordner `ab_boegen/`: je Position `<Pos>_hoch.jpg` / `<Pos>_rechner.jpg` und
`vergleich_zs1_*.jpg` (Zeilen Arcade | Modern ZS1 aus `deliver/gate1` | Modern M2INT). Angesehen habe ich jedes Bild,
dazu je Position ein Differenzbild M2INT − ZS1 und Ausschnitte (Autos, Horizont, Flocken).

**Urteil: M2INT ist an keiner Position schlechter als ZS1, an mehreren besser; Arcade bleibt in drei Punkten vorn.**

| Position | M2INT gegen ZS1 | M2INT gegen Arcade (ehrlich) |
|---|---|---|
| S1–S3 Kiel – Hamburg | Bäume von AS3R (Birken mit Rinde, Eichen voller), Verkehr neue Modelle, sonst gleich (Differenz nur dort) | gleiche Komposition; Wiese gestreifter, Asphalt heller mit Textur |
| S4 Stadtgrenze Hamburg | gleich, Bäume am Straßenende neu | Arcades Birke vor dem Backsteinhaus fehlt (schon in ZS1) |
| S5 Ziel | jetzt im selben Augenblick wie Arcade (0:02,65 mit Zielbanner; ZS1-Bogen 0:01,50) | gleichwertig |
| T1 Kassel – Würzburg | Fichten/Kiefern feiner und dunkler; Kombi jetzt Modell (ZS1: Sprite) | große Kurventafel am rechten Rand fehlt (schon ZS1); Kombi steht am Hang etwas höher im Bild |
| T4 Saragossa – Pau | Tannen von AS3R | nahe Fichte am rechten Rand fehlt (schon ZS1) |
| C1 Frankfurt 19:30 | Sportwagen jetzt Modell (ZS1: Sprite); Fenster der Häuser abends gelb (AS4R) | Baum vor dem Haus rechts fehlt (schon ZS1); Lack satter als das Sprite (Sättigung 0,79 statt 0,70, Median 18 % dunkler, Glanzlichter heller, gemessen) |
| N1 Nacht, Schnee | Birken, Kiefern, Heide neu | **kein Schneefall** in Modern (R4, `renderer-modern.md` „Kein Wetter in der Luft“); Spielerauto nachts heller als das Sprite (Spieler-Aufhellung, schon ZS1) |
| N2 Regen | GT jetzt Modell (ZS1: Sprite) | **kein Regen** in der Luft (R4); GT weißer und flacher als das Sprite (keine Klarlack-Spiegelung) |
| S1 Kombi / Sportwagen / GT | – | alle drei lesen sich wie ihr Sprite; GT-Heckscheibe mittags himmelblau (flache Scheibe spiegelt den Himmel), im Sprite dunkel |
| Köhlbrandbrücke 22 Uhr | vorher fehlten Elbphilharmonie und Michel | jetzt beide beleuchtet (`c317625`) |

Rechner-Voreinstellung („niedrig“): dieselben Aussagen; weniger ferne Bäume als Arcade (Dichte der Stufe, wie ZS1).
Billig behoben habe ich nur die Nacht-Wahrzeichen. Nicht billig (Liste für R4/R5/R6): Niederschlag, fehlende nahe
Requisiten an T1/T4/C1/S4 (Platzierung der Szenerie in Modern), Lack der neuen Spielerautos (Klarlack/Umgebung),
Spielerauto nachts.

**Clips** (`tools/ab_clip.sh`, 30 s, 60 Bilder/s, Arcade links, Modern „Hoch“ rechts, mit HUD, Ordner `clips/`):
- `dortmund_frankfurt_km121_wald_doerfer.mp4` (23 MB, aus `b2c6b52`): Wald und Dörfer, Gran Turismo, Lkw; beide
  Seiten im selben Augenblick (Bilder bei 2/15/28 s in `dortmund_frankfurt_km121_bilder_2_15_28s.jpg`) – gleichwertig;
  Modern ohne Sonnenscheibe, nahe Fichte am rechten Rand fehlt (wie T4), GT heller. Der erste Versuch aus `c317625`
  meldete 55 Pufferüberläufe und wurde abgebrochen (Notiz 5); dieser Lauf 0.
- `kiel_hamburg_start_tag_ohne_zs1.mp4` (21 MB, aus `b2c6b52`): Start Kiel – Hamburg mit Countdown – **ohne den
  Start-Fix von ZS1**: im Countdown fehlt in Modern das Spielerauto (Bild bei 1 s), ab dem Losfahren gleichwertig.

## 4. Gates

Alle Werte gemessen auf dieser VM (Mesa llvmpipe unter Xvfb, `nice -n 19`, ein Job nach dem anderen), Logs in
`m1/M2INT/gates/`. **Endstand `49f221e`** (ohne ZS1, Notiz 10). Die Erzeuger-Gates liefen auf `c317625`; danach hat
sich an `assets/models`, `tools/blender`, Sprites und Klängen nichts geändert – sie gelten für den Endstand. Die
Spiel-Gates der zweiten Tabelle liefen auf `af5fbe1`: `49f221e` ändert danach nur die Modern-Goldenliste
(`tests/` gehört nicht zum Export) – Code, Exporte und Ergebnisse sind dieselben. Import, voller Testlauf,
Arcade-Goldens und Render-Prüfungen liefen auf `49f221e` (dritte Tabelle).

| Gate | Ergebnis |
|---|---|
| Export-Schlüssel `export_models.py --check-keys` | OK – 87 Modelle; Selbsttest „ein geänderter Lack … ergibt genau für die betroffenen Modelle einen neuen Schlüssel“ (440 s) |
| zweiter Bake aller 87 Modelle | byte-gleich: `git status` 0 geänderte Dateien unter `assets/models`; Manifest mit `--manifest-only` neu erzeugt, unverändert |
| `validate_models.py --report` | `CHECK models OK` (87 Modelle) |
| `check_sprite_geometry.py` | 187 von 187 Sets identisch (1 mit anderer Flächenreihenfolge: Fernsehturm, wie v0.7.0), 0 verändert (754 s) |
| `audio_qc.py` über alle Ordner | 98 Klänge, 0 Fehler; Klänge 19,000 von 23 MB, Musik 18,539 von 25 MB |

**Endstand `49f221e`, gemessen:**

| Gate | Ergebnis |
|---|---|
| Import (`godot --headless --import`) | Exit 0, 0 Fehlerzeilen |
| `tools/run_tests.sh` (Lauf 2 von 2) | **735 Tests, 0 fehlgeschlagen**; 148 CHECK-Zeilen OK, 0 FEHLER; 307 Skripte fehlerfrei (903 s) |
| `tools/golden.sh check` (einmal, am Schluss) | **GOLDEN arcade: 20 von 20 identisch**, arcade-ui: 17 von 17 identisch |
| `tools/run_render_checks.sh all` | **17 von 18 Dateien OK** – rot nur `check_light_base` „schatten“ („mit Aus wirft kein Knoten Schatten (3)“: die Lampenringe des Starttors, QA1-Befund, behoben im nicht zusammengeführten ZS1); `instanzen` ganze Szene ≤ 142, `instanzen_wald` ≤ 140, keine Ablehnung; `quit_arcade`/`quit_modern` ohne „leaked at exit“; `props_spiegel` 0,13; `laden` 0 Blätter |

**Spiel-Gates auf `af5fbe1` (Code = Endstand), gemessen:**

| Gate | Ergebnis |
|---|---|
| `tools/run_tests.sh` (Lauf 1 von 2, auf `c317625`, Vorlauf) | 734 Tests, 0 fehlgeschlagen; 148 CHECK-Zeilen OK, 0 FEHLER (899 s) |
| `tools/run_render_checks.sh all` (Vorlauf auf `b2c6b52`) | 15 von 18 Dateien: `check_light_base` „schatten“ (QA1-Befund, behebt der ZS1-Fix), `check_props_render` „props_spiegel“ und `check_vehicle_standin` „laden“ (vom Inhalt überholt, in `af5fbe1` angepasst, danach einzeln OK) |
| `modern_sight.gd --full` / `modern_path_check.gd --full` | 6 von 6 / 2 von 2 OK (195 s) |
| ERGEBNIS Arcade gegen Modern (`run_stage.gd`) | Kiel – Hamburg, Testetappe (21 Uhr, Regen), Saragossa – Pau (Schnee): je 28 Schlüssel identisch außer `gfx` |
| Autopilot Modern unter Xvfb („mittel“, Zeitraffer 40) | Kiel – Hamburg ganz: Exit 0, 0 Skriptfehler, `render()` Mittel 3,80 ms (max 15,8), 108 Zeichenaufrufe, 98 945 Dreiecke, Fahrzeug-Instanzen höchstens 128, Texturen 82,6 MB, Vorbereitung 9,3 s; Dresden – Leipzig (Ziel in der Stadt): Exit 0, `render()` 4,49 ms (max 12,5), 131 Zeichenaufrufe, 157 249 Dreiecke, 73,2 MB. **Gegen ZS1** (renderer_zeit 0,911/0,825 ms ohne Bild, Leistungstest `render()` 2,13–3,02 ms, 64–160 Zeichenaufrufe, 24k–107k Dreiecke): Zeichenaufrufe im selben Rahmen, Dreiecke bis 157k (mehr Geometrie durch Bäume/Gebäude von M2), `render()` höher – bei Zeitraffer 40 baut jedes Bild mehr Stücke, also nicht gleich gemessen; auf echter GPU/Deck abgeleitet: mehr Dreiecke, Zeichenaufrufe gleich |
| Texturspeicher (A-6) | Kiel – Hamburg km 2: Arcade 228,3 / Modern 98,9 MB; Dortmund – Frankfurt km 221 (19:30): Arcade 202,6 / Modern 97,5 MB |
| Builds (`build_linux.sh`, `build_windows.sh`, Größe `pck_report.py`) | beide Exit 0; Linux 496,5 MB roh, Archiv geschätzt **184,7 MB**; Windows-Zip gemessen **194,5 MB** (ZS1: 146,9 / 156,6 MB) – Grenze 300/330/350 MB, Download-Ziel ≈ 280 MB eingehalten; Modern: Modelle 18,73 / 40, Texturen 13,04 / 60, Klang 16,38 (roh 19,08 von 23), Musik 18,60 / 25 MB im Archiv |
| Rauchtest der Exporte (`tools/smoke_modern.sh`) | Linux (Xvfb): Arcade OK (17 s), Modern OK (42 s), Leistungstest „autobahn“ 6,2 Bilder/s (Software, „niedrig“); **Windows unter wine64**: Arcade OK (22 s), **Modern OK** (50 s), Leistungstest 5,4 Bilder/s; Nutzerdaten im eigenen Ordner bzw. im Präfix |
| Saat-Varianten aus dem pck (`variant_of`, Leitungsnotiz 7) | Barcelona – Montpellier km 42,7, Modern „Hoch“, aus dem Linux- und dem Windows-Export: Bild entsteht, 0 Fehlerzeilen, Oliven, Palme und Zypressen sichtbar (`oliven_aus_pck_linux_windows.jpg`) |

## 5. Abweichungen, Vertragsfragen, Nächste Schritte

**Abweichungen vom Auftrag**
1. AS1b-Fensterscheiben (Bauernhaus, Zollhäuschen, Tankstelle) nicht auf den Bauer „house“ umgebaut – er müsste
   Wandlampe und Dachlampen mit Lichtankern übernehmen (Kunstdurchgang mit Bildprüfung). Liste für AS5/R6.
2. Pylonhöhe je Brücke (`height_m`/88,8) nicht eingebaut – kein Einzeiler (das Item trägt `height_m` auch bei
   Wahrzeichen; nicht-gleichmäßige Skalierung) – bleibt bei R5 (A-16).
3. SUV-Rückstrahler bleiben auf dem Rücklichtkanal (`-tail:0.3`), nicht Kanal 15 – Arcade-Look, kein Neuexport aller
   Verkehrsmodelle.
4. Polizei-Karoband in 120 m 14 Stufen gelber (Blau) – offen für den Besitzer der Polizeimodelle.
5. Showroom-Flags alle `false` – kein Auto ist im Studio-Look mindestens so gut wie sein Sprite.
6. Über den Auftrag hinaus, weil beim Hinsehen gefunden und billig: Wahrzeichen nachts (`c317625`) und der Überlauf
   des Shader-Puffers (`b2c6b52`). Beide ändern Code des Renderers; das Bild bleibt außer nachts an Wahrzeichen gleich.
7. A/B-Bögen aus einer Kopie des Worktrees gerendert (`c317625`, damit Änderungen im Worktree den Lauf nicht treffen);
   die Puffer-Abhilfe danach ist an T1 pixelgleich nachgeprüft.
8. Der Start-Fix ZS1 ist **nicht** zusammengeführt (`ZS1_FERTIG` fehlte um 12:00 UTC, Notiz 10).

**Vertragsfragen**
1. Klassenmaterial `vpbr` „für alle Modelle geteilt, Instanzdaten als Instanz-Uniforms“ (`ModernMaterials`, §4/A-13)
   trägt nicht mehr: Godot gibt jeder Instanz mit Instanz-Uniforms 16 Plätze eines Puffers von 4 096 – mit dem Inhalt
   von M2 lief die Szene auf Waldetappen über (gemessen). Umgesetzt ist die nächstliegende Lösung (`VPBR_STATIC` für
   alle Nicht-Fahrzeuge); der Vertrag sollte festhalten: Instanz-Uniforms nur für Fahrzeuge, statische Modelle ohne.
2. Leitungsnotiz 10 setzt den ZS1-Merge vor die Schluss-Gates; ZS1 kam bis 12:00 nicht. Die Gates laufen daher auf
   dem Stand ohne Start-Fix (Render-Prüfung `check_light_base` „schatten“ bleibt rot, bis ZS1 drin ist).

**Nächste Schritte**
1. ZS1 (`wip/v080-fix-wasser-r` bzw. der Commit in `ZS1_FERTIG`) zusammenführen – Konfliktlösung wie in Notiz 10,
   danach Modern-Goldens neu, `check_start_km0`/`check_light_base`, Start-Clip neu.
2. R4: Niederschlag in der Luft (Regen, Schneefall, Gischt) – größter sichtbarer Unterschied zu Arcade (N1, N2).
3. R5: nahe Requisiten am Bildrand und in der Stadt (Kurventafel T1, Fichte T4, Baum C1, Birke S4); Pylonhöhe je Brücke.
4. Lack der neuen Spielerautos: Klarlack-/Umgebungsspiegelung (GT weiß und flach, Sportwagen satter); erst dann
   Showroom-Flags `true` prüfen; Spielerauto nachts heller als das Sprite.
5. AS5/R6: AS1b-Scheiben über den Bauer „house“ mit Lichtankern; Polizei-Karoband in 120 m.
6. Stufenwechsel lod0 → lod1 (40 m, 14 %) ohne Überblendung; Rotorphase der Windmühle beim Ursprungsversatz.
7. Neue statische Inhalte immer mit `kind` ≠ `vehicle`/`heavy` anlegen (sonst Instanz-Uniforms); `instanzen_wald`
   hält es fest.
