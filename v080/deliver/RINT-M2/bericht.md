# RINT-M2 – Zweite Montage des Schubs M2

Zweig `wip/v080-rint-m2` (nur dorthin gepusht, nach jedem Commit), Basis `515dd51`. Alle Zahlen gemessen auf dieser
Maschine (Xvfb, llvmpipe, Godot 4.7.2 Compatibility), sonst steht **(gefolgert)** dabei. Jeder Spiellauf mit
`--graphics` ausdrücklich und einem eigenen absoluten `XDG_DATA_HOME` – **bis auf rund 20 Einzelprüfungen eines
Hilfsskripts, die den echten Benutzerordner trafen (selbst gefunden, §6)**; schwere Läufe einzeln über eine
Warteschlange, `nice -n 10`, `LP_NUM_THREADS=2`.

## 1. Kurzfassung

- Vier Merges `--no-ff` in der verlangten Reihenfolge, Vertrag §11.3 wörtlich angehängt.
- Leitungsnotizen 3–11 umgesetzt und gemessen; Notiz 10 (Lack) gemessen, nicht mit einer Konstante lösbar → gelistet;
  Notiz 12 befolgt (nichts gegen das Flackern).
- **Selbst gefunden und behoben:** die erste Fassung der Tönung (Notiz 5, `b04d28a`) färbte Fensterrahmen,
  Garagentore, Bäume und Windräder leuchtend grün. Ursache ist ein Verhalten von Godots Compatibility-Renderer bei
  `INSTANCE_CUSTOM` (mit Sonden eingegrenzt, §3 Notiz 5); behoben in `a3120e4`, Bilder vorher/nachher.
- Notiz 8 brauchte nach dem ersten Einfrieren (`1cd689d`) noch fünf Code-Schritte am Tankstellendach (`c72d484`,
  `b673df5`, `02051f7`, `b903797`, `9b02f05`): `collect()` der Tankstelle höchstens 1,36 ms, Mittel 0,11 ms auf
  „Deck“ (Merge-Stand 3,41 / 0,20; ein Messlauf auf belasteter VM, §3 Notiz 8); Entscheide netzweit unverändert
  (1909 Dächer, 0 verschieden).
  Dazu eine angepasste Render-Prüfung (`ab2a400`), Doku (`ae1fd76`, `92dbff2`) und ein Prüfungskommentar (`dd7d984`).
  Endstand `9b02f05`.
- A/B: an den Bezugsstellen 2 besser, 8 gleich, 4 schlechter (Kurveninnenseiten in Bergetappen, A-17 → R7); an den
  weiteren Stellen 4 besser (zwei davon klein), 15 gleich, 2 mit schlechterem Lack der Limousine in der Dämmerung; Clips: Köhlbrandbrücke
  nachts im Regen besser, nach der Gotthard-Ausfahrt die Kurveninnenseiten schlechter (§5, §7).

## 2. Zusammenbau

| Schritt | Commit | Konflikte / Auflösung |
|---|---|---|
| R4 `origin/wip/v080-fix-r4` (`b156763`) | `04de79f` | nur `tests/golden/modern_slice.{md5,env}` – R4s Seite, Liste wird am Ende neu erzeugt |
| R5 `origin/wip/v080-fix-r5` (`80b8141`) | `9fec3a7` | `modern_slice.md5`; `docs/renderer-modern.md`: R4 und R5 hatten beide §15 – R4 bleibt §15, R5 wird §16 |
| R6 `origin/wip/v080-fix-r6` (`2b7dcc0`) | `5c451f2` | nur `modern_slice.*` |
| AS5a `origin/wip/v080-as5ar1` (`7153381`) | `cee4590` | nur `modern_slice.*`; `manifest.json` seit der Basis nur von AS5a geändert |
| Vertrag §11.3 (Leitung) wörtlich | `8999769` | „Vertrag §11.3 (Leitung): Sichtkorridor, Bauten, Instanz-Uniforms, Nachtlicht, Plan, Stadtgebäude“ |

Auf dem Merge-Stand `8999769` liefen die Render-Prüfungen `night_nass`, `night`, `weather`, `tunnel_bridge`,
`structures`, `structures_licht`, `vehicle_lights` grün (Ausgangspunkt der Nacharbeit).

Commits der Nacharbeit: `2322092` (Notiz 3), `1c61036`/`71ed4b7` (4), `b04d28a`/`a3120e4` (5), `967ad21` (6),
`6347e41`/`618561f` (8), `747fa30` (9), `4fc3d35` (7), `eb417a7` (11 a–d), `58eba9e`/`5294d00` (11 e: N1/N2),
`aa44247`/`1cd689d` (Doku), `c72d484`/`b673df5`/`02051f7`/`b903797`/`9b02f05` (8, Tankstellendach), `ab2a400` (Render-Prüfung
`props_spiegel`), `ae1fd76`/`92dbff2`/`dd7d984` (Doku §17.9/§17.10, Kopf von `check_night_nass`), dazu die Goldens
`6b17293` (§4).

## 3. Leitungsnotizen

### Notiz 3 – Abblendlicht behält seinen Glanz, Fahrzeuge dämpfen im Material (A-20): **erfüllt**

- `layers/lights.gd` `SPOT_SPECULAR` wieder 0,5. `vpbr`/`glass` nehmen die Glanzkeulen eines Lichts von neben dem Auge
  selbst heraus (`eye_lamp_spec` 0 im Renn-Look der Fahrzeuge, 1 im Studio; `eye_lamp_cos` 0,85 … 0,95).
- Lkw/Limousine gegen Arcade (Fahrzeugsonde, 22 Uhr, mittlere Leuchtdichte des Fußabdrucks, Arcade / neu): roter Lkw
  60 m 44,1 / 44,1 (Anteil > 200: 0,66 / 0,44 %), 20 m 57,0 / 63,0 (+10,5 %); Limousine silber 60 m 48,1 / 46,6.
  Mutation `eye_lamp_spec` 1: Lkw 60 m 171,5 (48 % weiß) – die Dämpfung wirkt.
- `check_vehicle_lights` „abblendlicht“ OK (20 m 0,5 % weiß, Mittel 0,24; 60 m 0,0 %, 0,17), `check_night_nass` grün
  (Render-Prüfungen, §4).
- Nasse Fahrbahn N2 22 Uhr Regen: mit `SPOT_SPECULAR` 0 und 0,5 **pixelgleich** (0 Pixel Unterschied) – die Fahrbahn
  liegt auf Ebene 2 und nahm den Spot nie; ihr Glanz kommt aus `inc/headlight.gdshaderinc`/`road.gdshader`. Die
  Annahme von NACH-M2 N-03 (der Spot-Glanz fehle der nassen Fahrbahn) stimmt nicht (Vertragsfrage, §6).
  Bild `n3_N2_22uhr_regen_nasse_fahrbahn.jpg`; N2/DEV auch in den A/B-Bögen.

### Notiz 4 – Brems- und Blaulichtzuschlag nach Tageslicht (A-20): **erfüllt (Bremse), Blaulicht bewusst nicht**

- `model_glow_gain(role, a, lights, dist_m)`: Bremszuschlag 2,2 bei Tag voll; nachts Anteil nach Abstand zur Kamera
  (0,6 bis 22 m, 0,15 ab 60 m, `smoothstep`). Ein Anteil für alle Abstände reichte nicht (gemessen: 0,35 → Sportwagen
  60 m +22 %, Limousine 20 m −32 %; 0,15 → −1 % / −46 %).
- Sonde 22 Uhr, rote Pixel Arcade / neu: **Sportwagen 60 m 95 / 94** (−1 %), **Limousine 20 m 539 / 476** (−12 %),
  Sportwagen 20 m 567 / 454 – alle innerhalb „Arcade + 10 %“ (obere Grenze). Polizei 60 m: Blau nachts 97 gegen
  Arcade 184 – der Blaulicht-Zuschlag bleibt darum nachts (ohne ihn wäre es noch weniger; die Notiz verlangt nur die
  obere Grenze; „blaulicht“ fällt mit Verstärkung 1,0 durch, gemessen in FIX-M2 und hier erneut).
- Prüfung „bremsschein“ (aufsummiertes Rot, das die Bremse hinzufügt): Tag ≥ 29 (Kopf 33,1; **Verstärkung 1,0: 25,0 →
  FEHLER**), Nacht Sportwagen 60 m ≤ 57 (Kopf 28,3; voller Tageszuschlag nachts 68,9 → FEHLER), Limousine 20 m ≤ 500
  (Kopf 436,1; voller Zuschlag 602,8 → FEHLER). Unit-Tests nah/fern/Tag/stetig.

### Notiz 5 – Tönung der Modelle über Instanzdaten (A-19): **erfüllt, nach einem eigenen Fehlschlag**

- `b04d28a` legte die Tönung als MultiMesh-Custom-Daten an Modelle. Die Bilder danach (Kiel km 0,6 und Hamburg-Rand
  km 81,2) zeigten **leuchtend grüne** Fensterrahmen, Garagentore, Giebelkanten, Kronen, Stämme und Windräder.
- Eingegrenzt mit Sonden (`probe/mm_custom*.gd`, `probe/mm_models.gd`): Godot 4.7.2 Compatibility liest
  `INSTANCE_CUSTOM` falsch (a) bei Farbe ohne Custom-Daten: (0, 1, 0, 1); (b) bei Custom-Daten ohne Farbe, über
  `MultiMesh.buffer` gesetzt, auf den echten Modellnetzen (über `set_instance_custom_data()` richtig – je Instanz zu
  teuer). Mit Farbe **und** Custom-Daten stimmt es: grüne Pixel der Modellreihe 0,292 % → 0,002 % (ohne Instanzdaten
  0,006 %). Ohne beides liest es 0, ein `MeshInstance3D` ebenso – die Shader lassen dort die Albedo.
- `a3120e4`: jede Instanz der Requisiten 20 Werte (Transformation, Farbe, Custom); Modell: Farbe weiß, Custom =
  Tönung; Vertretung: Farbe = Tönung, Custom leer. Unit-Test `test_model_instances_carry_the_placement_tint`
  (Pufferlayout, Knoten mit Farbe und Custom-Daten, Shadercode), Doku `docs/modelle.md` „Tönung“, §17.3.
- A/B: `n5_toenung_hamburg_rand.jpg` (Arcade rosa Einfamilienhaus `#e8b8a4` / vorher weiß / jetzt rosa wie Arcade),
  `n5_gruenstich_vorher_nachher.jpg`, `n5_gruenstich_kiel.jpg`, Sonde `n5_sonde_instanzdaten.jpg`.

### Notiz 6 – Instanzbudget ≤ 230 bei „Hoch“, Waldprüfung unter Last (A-19): **erfüllt**

| Prüfung (Hoch) | Verkehr | ganze Szene (≤ 230) | Fahrzeug-Ebene | Ablehnungen |
|---|---|---|---|---|
| `instanzen` Kiel – Hamburg km 2, 100 s | eigener | 141 | 128 (Budget 128) | 0 |
| `instanzen_wald` Dortmund – Frankfurt ab km 40 (Wald km 40–60) | 48 eingespeist | **216** | 208 | 0 |
| `instanzen_stadt` Würzburg – Nürnberg ab km 106 (Ziel in der Stadt) | 48 eingespeist | 171 | 176 | 0 |
| `instanzen_wald` **ohne `VPBR_STATIC`** (Mutation) | 48 eingespeist | 306 | 208 | **144 → FEHLER** |

- Eigene Kopfzeile `## render-check-timeout: 2400`; Belastung verlangt (Fahrzeug-Ebene ≥ 90 % ihres Budgets, sonst
  „nicht belastet“). Mit 48 gezeigten Autos geht die Fahrzeug-Ebene über ihr Budget (sie gibt nur Pool-Autos und
  verborgene Stufen frei) – dort binden die Szenengrenze und die Ablehnung; gezählt wird dann alle 10 Bilder.
- Die Szene im Wald liegt mit 48 gleichzeitig gezeigten Autos 14 Instanzen unter der Grenze (§6).

### Notiz 7 – Dächer ohne Stütze hängen wie die Grenzdächer; scan_f1 0 Paare ≥ 6 px (A-18): **erfüllt**

- Die drei Tankstellendächer, deren Stützen alle wegfielen (prag_leipzig km 148,08, sibiu_timisoara km 148,98,
  prag_nuernberg km 233,13), hingen bisher an einer Notstütze auf der Insel (Arcade hat keine; sie verdeckte eine
  Kurventafel aus 210 m zu 89 %). Jetzt Mast mit Zugstangen (`station.gd`, „mast“ rechts jenseits der Tafeln, sonst
  „mast_l“ links jenseits des Seitenstreifens bei −9,625 m, Zugstangen 7–9 m über den Spuren); an allen drei links.
- `scan_f1` über das ganze Netz: Paare an Tankstellen-Endstützen 38 → 3, **keines ≥ 6 px auf einer Spieltafel**. Das
  einzige verbliebene Nicht-Arcade-Paar ≥ 6 px: Grenzstation Amsterdam – Lüttich km 210,175 Endstütze gegen die Tafel
  „town_ahead“ (22 %, keine Spieltafel nach A-18) – gelistet.
- Unit-Test (Mast verdeckt keine Tafel, steht außerhalb des Korridors).

### Notiz 8 – collect() je Baustein ≤ 2 ms auf „Deck“ (A-18): **erfüllt im Messlauf – Sichtlinien auf dem Arbeitsfaden, Vorwärmen in Stücken; Tankstelle höchstens 1,36 ms (Mittel 0,11)**

- Gemessen mit `ChunkStreamer.stats()` → `collect_by` (neu, `6347e41`): Hauptfadenzeit von `collect()` je Baustein,
  Testetappe ganz, „Steam Deck“, Zeitraffer 16, llvmpipe – auf dieser Maschine lief gleichzeitig ein anderes Paket
  (AS5a2, nice 19): Höchstwerte sind unruhig, die Mittel belastbar.

| Stand | Tankstelle `collect()` max / Mittel (Fahrt, 134 Aufrufe) | Ursache der Spitzen (Instrumentierung `STATDBG`) |
|---|---|---|
| Merge-Stand (`eb417a7`, Entscheid inline) | 3,41 / 0,20 ms | die Sichtlinien eines Dachs im Hauptfaden |
| `618561f` (Sichtlinien auf Arbeitsfaden) | **8,04** / 0,33 ms | Sammeln las Korridor-Merker 600 m voraus (Geländezeilen) |
| `c72d484` (Korridor erst in `finish()`, Sammeln in zwei Hälften) | 9,50 / 0,20 ms | bei sechs Dächern einer Station reichten 600 m Vorlauf nicht: die letzten drei Dächer inline (4–6 ms) |
| Zwischenstand mit 2000 m Vorlauf (verworfen, nicht eingecheckt) | 19,59 / 0,36 ms | der Vorlauf erzwang die Strecke weit voraus (rund 13 ms je km Erzeugung): eine Spitze von 18 ms |
| `b673df5` (Vorlauf 600 m mit Zeitbudget 0,5 ms, Spuren und Krümmung geteilt) | 2,86 / 0,16 ms | Schilder je Dach neu gelesen |
| `02051f7` (dazu Schilder je Segment geteilt) | 2,40 / 0,14 ms | alle neun Dächer vor ihrem Stück gesammelt und auf dem Arbeitsfaden entschieden, keines inline; erstes Dach einer Station zwei Hälften zu 1,2–1,5 ms (kalte Caches), jedes weitere 0,2–0,6 ms |
| Versuch `warm_step()` mit 0,7 ms Budget und 600 m Vorlauf (verworfen) | 8,71 / 0,26 ms | zu wenig Arbeit je Aufruf: ein Dach war nicht rechtzeitig fertig |
| **`b903797`** (`warm_step()`: Strecke in Stücken zu 6 Segmenten erzeugt, Caches der Schilder und Kamerastellen Stück für Stück bis 1,0 ms je Aufruf) | **2,08 / 0,12 ms** | die kalte Arbeit des ersten Dachs ist auf mehrere Aufrufe verteilt |
| **`9b02f05`** (dazu Vorlauf `WARM_AHEAD_M` 1200 statt 600 m – das Erzeugen geschieht jetzt in Stücken) | **1,36 / 0,11 ms** | alle neun Dächer beim Stück gesammelt und entschieden (Rest dort 0,02–0,18 ms, Kopie mit Ausgaben), keines inline; alle Bausteine in diesem Lauf ≤ 1,36 ms |

- Ergebnis: der Entscheid (Sichtlinien) läuft auf dem Arbeitsfaden (`WorkerThreadPool`), das Sammeln der Strecke bleibt
  im Hauptfaden (`Track` erzeugt sich beim Lesen, nicht fadensicher; Arcade-Datei, eingefroren) und ist mit
  `warm_step()` in kleine Stücke unter einem Zeitbudget verteilt. Mit 1200 m Vorlauf bleiben genug Aufrufe, bis das Stück eines Dachs gebraucht wird: **höchstens 1,36 ms, Mittel 0,11 ms** – unter dem Ziel von 2 ms. Entscheide gleich: Sonde `jobpath` 1909 Dächer, 0 verschieden (auch für 600 m und 0,7 ms); Unit-Test `test_station_warm_step_prepares_what_the_halves_read`; `test_structures` 14/14.
- **Messgüte:** ein Lauf, ein Höchstwert, auf einer VM mit zwei Paketen gleichzeitig. Die Höchstwerte der anderen
  Bausteine schwanken zwischen gleichen Läufen stark (Requisiten in vier Läufen 0,12 / 0,34 / 0,70 / **4,19 ms**,
  ohne Codeänderung dort) – Mittel sind belastbar, ein einzelner Höchstwert um 2 ms nicht. Für eine harte Aussage
  „≤ 2 ms auf dem Deck“ braucht es das Gerät oder mehrere Läufe auf einer ruhigen Maschine.

- Sonde ohne Spiel (`bin/canopytime.gd`, Kiel – Hamburg und Testetappe, 22 Dächer): Sammeln vorher am Stück bis 3,9 ms
  (davon Korridor-Merker bis 17 ms beim ersten Dach einer Station), jetzt je Hälfte höchstens 1,2 / 1,4 ms; Sichtlinien
  auf dem Arbeitsfaden 0,1–2,5 ms.
- Entscheide unverändert: `scan_f1` netzweit zeilengleich (3486 Stützen, 1648 Verdeckungszeilen), `startdep` 1909 Dächer
  0 abweichend, `test_structures` 13/13; Modern-Goldens vorher/nachher MD5-gleich.
- Die übrigen Bausteine während der Fahrt: Grenze ≤ 0,44 ms, Schilder ≤ 0,42, Gelände ≤ 1,07, Requisiten ≤ 0,12 (Mittel
  0,02–0,05 ms). In der Ladephase (vor dem Start) `city` bis 6,0 ms – nicht im Fahrbudget, aber notiert.

### Notiz 9 – Lichtebenen: **erfüllt**

- `lights.gd` liest die Stärke statischer Lampen jedes Bild (`entry_energy`, Unit-Test
  `test_static_lamp_energy_is_read_every_frame`); `flares.gd` überspringt Stärke 0 (Blitzer zwischen den Blitzen,
  dunkle Countdown-Lampen kosten keine Instanz); Schlüssel `"halo"` und `"glow": false`; der Blitzer nutzt `halo` 1
  statt des Ausgleichs in `FLASH_GAIN` (gleiches Bild) und wirft nachts einen 9-m-Lichtkegel. Unit-Tests der Schlüssel.

### Notiz 10 – Lack ±15 % zu Arcade, wo eine Konstante es löst: **gemessen, keine Konstante löst es → gelistet**

Sättigung neu / Arcade (`check_night` „spielerauto“ auf dem Merge-Stand): Limousine S1 0,95×, Limousine Testetappe
1,00×, **Kompakt N1 (Schnee, 22 Uhr) 1,23×**, **Gran Turismo N2 (Regen) 0,77×** (Leuchtdichte 0,92×). Die zwei
Ausreißer gehen in entgegengesetzte Richtungen; eine Renderer-Konstante (`paint_desat`, `paint_base`) bringt den
einen nur auf Kosten des anderen und der beiden passenden in ±15 %. Der Gran Turismo ist im Modell silbern, Arcades
Sprite dunkel blaugrau (Sonde 22 Uhr Regen, Bild in den A/B-Bögen N2) – ein Asset-Befund. Offen für die
Modellnacharbeit (§7).

### Notiz 11 – Tunnel, Brücken, Kleinkram: **erfüllt**

- (a) Blendfläche der Ausfahrt bei `tunnel_state.exit_z − 0,05 m`; `check_tunnel_bridge` „U1_ausfahrt“ misst gegen
  Arcade (mindestens 0,6 × Arcades 0,89 draußen, Rahmen glüht nicht mit) – grün (§4).
- (b) Fahrbahn der Röhre von außen in Arcades Tunnellicht (`road.gd` liest `tunnel_state.light`, `road.gdshader`
  `tunnel_out/ambient/fog/darkness_m`).
- (c) Steinbrücken mit Arcades Balustrade: fünf Docken je Segment (0,14 m, 0,24–0,92 m hoch) zwischen Sockel und
  Handlauf, ein Pfeiler (0,56 × 1,32 m) alle vier Segmente – nach Arcades `_balustrade`, nicht 0,35 m wie im Auftrag
  (Abweichung, §6).
- (d) Hausboote und Schiffe +0,15 m (`BRIDGE_WATER_LIFT`), schwimmen jetzt auf dem Brückenwasser.
- (e) Laternen-Spiegelung (NACH-R4 N1): Profil je Lampe gehalten, solange die Kamera < 3 m fährt; Schnappschuss
  meldet Streifen, größte Profilhöhe, neu gerechnete Profile. Prüfung (N2) `check_night_nass` „laternen“ auf der
  Steigung Kassel – Würzburg km 61,6 (die Köhlbrandbrücke ist im Profil eben, gemessen 0 an jeder Startstelle): Profil
  bis 15,8 m, 4 von 160 Profilen gerechnet; mit flachem Profil (Mutation) FEHLER.

### Notiz 12 – kein Eingriff gegen das Flackern: **befolgt** (A-21).

## 4. Tore (Befehle und Ausgaben)

Läufe über `sh/gates.sh <Schritt>` (Kopie von M2INTs Skript: eigenes absolutes `XDG_DATA_HOME` je Schritt,
`nice -n 10`, `LP_NUM_THREADS=2`, ein schwerer Lauf zur Zeit über die Warteschlange). Neben dieser Montage lief auf
der Maschine das Paket AS5a2 (nice 19) – Zeiten und Höchstwerte sind davon beeinflusst.

| Tor | Befehl | Stand | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` | `1cd689d` | Exit 0, 0 Fehlerzeilen (14 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | `1cd689d` | „330 Skripte geprüft, 0 fehlerhaft“ |
| Skripte auf dem Endstand | `godot --headless --path . -s res://tests/check_scripts.gd` | `9b02f05` | Exit 0, „330 Skripte geprüft, 0 fehlerhaft“ |
| Tests Lauf 1 | `tools/run_tests.sh` | `1cd689d` | **802 Tests, 0 fehlgeschlagen**; 150 CHECK-Zeilen OK, 0 FEHLER (1008 s) |
| Tests Lauf 2 | `tools/run_tests.sh` | `9b02f05` | **803 Tests, 0 fehlgeschlagen** (einer mehr: `test_station_warm_step_prepares_what_the_halves_read`); 150 CHECK-Zeilen OK, 0 FEHLER (964 s) |
| Arcade-Goldens (einmal) | `tools/golden.sh check` | `1cd689d` | **GOLDEN arcade: 20 von 20 identisch**, **arcade-ui: 17 von 17 identisch** |
| Modern-Melder ansehen | `KEEP=… tools/golden.sh modern-check` | `1cd689d` | 0 von 6 identisch (erwartet nach den Merges); alle sechs angesehen (`bilder/goldens_modern_sechs.jpg`); `modern-gles` OK (2/255, 73,2 dB) |
| Modern-Melder neu | `tools/golden.sh modern-make` | `c72d484` | MD5 gleich den behaltenen Bildern von `1cd689d`; Commit `6b17293` |
| Modern-Melder prüfen | `tools/golden.sh modern-check` | `6b17293` | **GOLDEN modern: 6 von 6 identisch**, **modern-gles OK** (max. 2/255, PSNR 73,2 dB) |
| Modern-Melder auf dem Endstand | `tools/golden.sh modern-check` | `9b02f05` | **GOLDEN modern: 6 von 6 identisch**, **modern-gles OK** (max. 2/255, PSNR 73,2 dB) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | `b673df5` | **27 von 28 Dateien OK**; rot nur `check_props_render` „props_spiegel“ – die Prüfung erwartete das Einfamilienhaus noch als Ersatzbild (seit AS5a ein Modell); angepasst, einzeln: `props_spiegel` OK, `rotor` OK (`ab2a400`); die Strukturprüfung (`countdown`, `zieltor`, `grenze`, `blitz`) auf `02051f7` erneut OK |
| Strukturen auf dem Endstand | `check_structures.gd`, `check_structures_licht.gd` | `9b02f05` | **7 von 7 OK**: `countdown`, `zieltor`, `grenze`, `blitz`; `tankstelle` (21 Uhr Tankspur 0,406 / Arcade 0,459), `stadt` (0,491 / 0,501), `schatten` (mit eigenem `XDG_DATA_HOME`, der echte Benutzerordner unberührt) |
| Sicht | `modern_sight.gd --full`, `modern_path_check.gd --full` | `b673df5` | **6 von 6 OK** (`f1` 0 Fälle bis 270 m in 99,4 Mio. Stichproben, `f1_lanes`, `f2` ≤ 0,596, `f3` 0 von 5923, `f7`, `model`); Pfad **2 von 2 OK** (Abstand ≥ 267,6 m, Schleifen ≥ 2064 m) |
| ERGEBNIS Arcade = Modern | `run_stage.gd` (Zeitraffer 40) | `b673df5` | **Kiel – Hamburg, Testetappe, Saragossa – Pau: je 28 Schlüssel identisch (außer gfx)** |
| Texturspeicher | `probe/texmem_probe.gd` (20 s Fahrt) | `b673df5` | Arcade 201,7 / 200,6 MB, Modern **109,2 / 110,8 MB** (Kiel – Hamburg / Dortmund – Frankfurt; Spitze 109,2 / 110,8) |
| Prüfer, Schlüssel, Sprites, Klang | `validate_models.py --report`, `export_models.py --check-keys`, `check_sprite_geometry.py`, `audio_qc.py` | `ae1fd76`/`dd7d984` (Modelle, Sprites, Klänge seit `cee4590` unverändert) | `CHECK models OK`; `CHECK cache_keys OK` (98 Modelle); `CHECK sprite_geometry OK`; `audio_qc`: 98 Klänge, 0 mit Fehlern |
| Export-Determinismus | zwei AS5a-Modelle zweimal `--force` exportiert und gebacken | `dd7d984` | Kontor und Einfamilienhaus je zweimal: Cache und gebackene Modelle byte-gleich, `git status assets/models` 0 Dateien |
| Leistung neben `515dd51` | `run_stage.gd` unter Xvfb, Zeitraffer 40 (Testetappe 16) | `b903797` / `9b02f05` | §4.1 |
| Builds | `tools/build_linux.sh`, `tools/build_windows.sh`, `pck_report.py` | `9b02f05` | Exit 0 / 0; Linux **191,1 MB** (geschätzt), Windows-ZIP **200,9 MB** (gemessen) – Budget 277 MB, Warnung über 300; Modern: Modelle 19,6 / 40, Texturen 18,4 / 60, Klang 16,4 / 23, Musik 18,6 / 25 MB; die eingefrorenen Arcade-Teile wie gehabt (Sprites 71,07 / 71,0, Klang 14,72 / 14,7 – Rundung der Budgets) |
| Rauchtest | `tools/smoke_modern.sh` (Linux, GLES, Windows unter wine64) | `9b02f05` | **SMOKE linux OK, linux_opengl3_es OK, windows OK** (Arcade und Modern starten, Leistungstest 6,7 / 5,8 / 5,7 fps auf llvmpipe, Vorschlag arcade/low; Nutzerordner je im Arbeitsordner) |

Regel 1: `git diff --stat 515dd51..9b02f05` über alle eingefrorenen Arcade-Dateien des Vertrags (Liste §Rule 1) ist
leer – keine dieser Dateien geändert, auch nicht durch die Merges.

Ausgewählte Zeilen der Render-Prüfungen (`b673df5`):
- `abblendlicht` OK – roter Lkw 22 Uhr, 20 m: 0,5 % weiß, Mittel 0,24; 60 m: 0,0 %, 0,17.
- `bremsschein` OK – 12 Uhr Sportwagen 60 m Rot 33,1; 22 Uhr Sportwagen 60 m Rot 28,3, Limousine 20 m Rot 436,1.
- `blaulicht` OK – Polizei (Modell) 60 m: 12 Uhr 309, 22 Uhr 1157 Pixel deutlich blauer.
- `nass_kegel` OK – N2 22 Uhr Regen, eigene Spur 16–34 m: Modern 0,219, Arcade 0,250 (0,88×), Randlinie 1,19×;
  `spiegelung` OK (0 Pixel über dem Dach); `laternen` OK (Profil bis 15,84 m, 4 von 160 gerechnet).
- `tunnel_bridge_U1_ausfahrt` OK – Ausfahrt 0,584 = 0,66 × Arcade (verlangt 0,6), 0,0 % reines Weiß, Rahmen 0,501.
- `instanzen` 141 / `instanzen_wald` 216 / `instanzen_stadt` 171 von 230, keine Ablehnung.
- `spielerauto` OK – Sättigung Kompakt N1 1,23×, Gran Turismo N2 0,77×, Limousine S1 0,95× (Notiz 10).
- `tankstelle` OK – 21 Uhr Tankspur Modern 0,406, Arcade 0,459; `grenze` OK.

### 4.1 Leistung neben der Basis `515dd51`

Dieselbe Autopilot-Fahrt (`run_stage.gd`, Xvfb, llvmpipe, Zeitraffer 40, Seed 7, 12 bzw. 15 Uhr) auf dem Endstand
(`b903797`, Arbeitsbaum zur Zeit des Laufs; `9b02f05` ändert danach nur den Vorlauf der Tankstelle – die Testetappe
lief mit genau diesem Stand) und auf einer Kopie der Basis. llvmpipe rechnet auf der CPU: Bildzeiten
um 0,7 s sind die Software-Rasterung, nicht das Spiel; verglichen wird das Verhältnis.

| Etappe, Voreinstellung | Bild Median Basis → neu | 95 % Basis → neu | Draw-Calls | Primitive | `script_ms` | längstes Einhängen |
|---|---|---|---|---|---|---|
| Kiel – Hamburg, Mittel | 658 → 741 ms (+13 %) | 879 → 1094 ms (+24 %) | 108 → 156 | 99 k → 182 k | 4,15 → 4,04 | 1,9 → 3,8 ms |
| Kiel – Hamburg, Deck | 652 → 726 ms (+11 %) | 874 → 1025 ms (+17 %) | 104 → 136 | 99 k → 182 k | 3,96 → 4,06 | 4,2 → 2,9 ms |
| Dresden – Leipzig (Ziel in der Stadt), Mittel | 644 → 661 ms (+3 %) | 886 → 1471 ms (+66 %) | 131 → 184 | 157 k → 224 k | 4,55 → 4,79 | 2,5 → 3,8 ms |
| Testetappe ganz, Deck (Zeitraffer 16, Seed 11; Notiz 8) | 618 → 549 ms (−11 %) | 797 → 743 ms | 98 → 105 | 94 k → 95 k | – | 4,2 → 6,8 ms |

Auf der Testetappe (Deck) braucht `collect()` eines ganzen Stücks im Hauptfaden (Pfad, Kontext, alle Bausteine)
höchstens 3,96 ms, im Mittel 1,96 ms – Basis 4,34 / 1,91 ms, Merge-Stand vor der Nacharbeit 6,16 / 2,16 ms.

- Mehr Geometrie durch die Inhalte dieser Montage (R4–R6: Tankstellen, Grenzen, Tore, Laternen, Brückenteile; AS5a:
  Stadtgebäude in 3D): Primitive +84 % auf Kiel – Hamburg, +43 % in Dresden – Leipzig; auf llvmpipe wächst die
  Bildzeit damit (gefolgert: Software-Rasterung skaliert mit Primitiven und Fläche). Alle Werte liegen unter den
  Budgets der Voreinstellungen (Deck 650 Draw-Calls / 450 k Primitive, Mittel 900 / 700 k).
- Die Skriptzeit je Bild ist gleich geblieben (4,0–4,8 ms); `collect()` der Bausteine in diesen Läufen höchstens
  1,34 ms (Tankstelle). Das längste Einhängen eines Stücks 3,8 ms auf Kiel – Hamburg, 6,8 ms auf der Testetappe
  (Budget „commit_ms“ 3,0 ms für Mittel/Deck – in der Basis mit 4,2 ms schon überschritten; einzelne Höchstwerte auf
  llvmpipe, nicht untersucht).
- Das 95-%-Quantil in Dresden – Leipzig steigt am stärksten (Zieleinfahrt mit AS5a-Stadthäusern); auf einer echten
  Grafikkarte nicht gemessen.

## 5. Bilder Arcade | Modern

Alle Bilder links Arcade, rechts Modern, gleiche Stelle, gleicher Augenblick (`tools/ab_sheet.sh`, `tools/ab_shot.sh`,
Bezugsbögen 09:14–10:58 Uhr auf dem Arbeitsbaum zwischen `6b17293` und `b673df5`, weitere Stellen und Clips auf
`02051f7`; die Tankstellen-Schritte dazwischen ändern keinen Entscheid und kein Bild). Jedes Bild angesehen; Urteile
hier, gesammelt in §7. Ordner
`ab_boegen/` (Bezugsstellen Hoch, Mittel, Deck mit Übersichten), `ab_weitere/` (weitere Stellen), `clips/`.

### 5.1 Bezugsstellen, „Hoch“ (`tools/ab_sheet.sh`, Bild 3 s nach dem Start; alle angesehen)

| Stelle | Urteil | Was |
|---|---|---|
| S1 Kiel – Hamburg km 2 | gleich | Gras mit Struktur, Leitplanken, Windräder, Birken wie Arcade; ein Busch links vorne fehlt |
| S2 km 13,6 (Tankspur) | besser | echtes Tankstellendach mit Säulen, Zapfsäulen, Preistafel, Shop; Arcades Komposition |
| S3 km 60 | gleich | offene Autobahn, Windräder, Baumgruppen |
| S4 km 80 (Stadtgrenze Hamburg) | besser | Einfamilienhäuser jetzt getönt wie Arcade (rosa statt weiß, Notiz 5), Hansehäuser und Kran in 3D, Pflaster |
| S5 km 94 (Ziel) | gleich | Zielbanner, Stadthäuser; Bremsleuchten des Spielerautos bei Tag kräftiger (Tageszuschlag, gewollt) |
| T1 Kassel – Würzburg km 46,5 | schlechter (klein) | Gefälle in die Kurve gleich; die große Fichte links vorne fehlt (Kurvenkorridor, A-17 → R7) |
| T2 km 61,9 (Kuppe) | schlechter | links der Kuppe keine Bäume (Arcade: Eichen, Kiefern) – Kurvenkorridor; Fernsicht gleich |
| T3 Saragossa – Pau km 172,8 | schlechter | Innenseite der Kurve kahl (Arcade: zwei Felsen, Bäume); Hügel links und Hang besser |
| T4 km 198,8 | schlechter (klein) | die große Fichte rechts auf der Kurveninnenseite fehlt; links gleich |
| C1 Dortmund – Frankfurt km 221, 19:30 | gleich | Abendhimmel, Häuser mit Licht, Laternen; rechts ein Gebäude statt Arcades Baum |
| N1 Hamburg – Hannover km 71, Schnee 22 Uhr | gleich | Schneefall, Abblendkegel, Büsche; Lack des Kompakt satter (Notiz 10) |
| N2 km 121, Regen 16 Uhr | gleich | Regen, Gischt, nasse Fahrbahn; links ein Baum weniger |
| U1 Gotthard km 186 | gleich | Röhre mit Leuchten und Fliesen; die Limousine wirkt im Tunnel dunkler als Arcades Sprite |
| DEV Testetappe km 48, 21 Uhr | gleich | Portal mit Hügel, Abblendlicht; Arcades Fichte links fehlt |

### 5.2 „Mittel“ und „Steam Deck“

- **Mittel** (`ab_boegen/uebersicht_mittel.jpg`, alle 14 Stellen): dieselben Urteile wie „Hoch“ – S2 und S4 besser,
  T1–T4 schlechter (Kurveninnenseiten), sonst gleich. Mittel zeigt etwas weniger Grasstruktur und kürzere Schatten,
  nichts fehlt gegenüber „Hoch“ außer dem, was schon bei „Hoch“ fehlt.
- **Deck** (`ab_boegen/uebersicht_deck.jpg`, S1, N2, U1): gleich. Modern füllt den 16:10-Schirm, Arcade hat schwarze
  Balken; N2 mit Regenstreifen und Gischt hinter dem Gran Turismo, U1 Röhre und Leuchten wie Arcade, die Limousine im
  Tunnel dunkler als Arcades Sprite.

### 5.3 Weitere Stellen („Hoch“, `tools/ab_shot.sh`; alle angesehen)

| Stelle | Urteil | Was |
|---|---|---|
| Gotthard innen 22 Uhr (U1, Tag in 5.1) | gleich | Röhre, Leuchten, Fliesen, grünes Notausgangslicht |
| Tunel Valík (Prag – Nürnberg km 87,6–88,2) 12 Uhr, Einfahrt | besser | Portal mit Hügel und Bäumen statt Arcades flacher Stirnwand |
| Tunel Valík innen 12 Uhr | gleich | Ausfahrt überstrahlt (Notiz 11 a), Fliesen; Arcades Ausfahrt klarer |
| Tunel Valík innen 22 Uhr | gleich | Leuchten, Nacht draußen |
| Köhlbrandbrücke 12 Uhr | besser (klein) | Pylone, Seile, Geländer gleich; das Wasser unter der Brücke sichtbar |
| Köhlbrandbrücke 22 Uhr | gleich | Abblendlicht, Pylone, Stadtlichter |
| Steinbrücke (Augustusbrücke Dresden) 12 Uhr | gleich | Balustrade mit Docken wie Arcade (Notiz 11 c), Kandelaber, Frauenkirche, Wasser |
| Steinbrücke 22 Uhr | gleich | Kandelaber warm statt Arcades weiß, Balustrade |
| Tankstelle Kiel – Hamburg km 14,6–14,9, 12 Uhr (zwei Bilder) | gleich | Dach auf Säulen, Zapfsäulen, Shop mit grünem Band, Mast – Arcades Komposition in 3D; Windräder, Birke |
| Tankstelle 21 Uhr (zwei Bilder) | gleich, unter dem Dach etwas dunkler | Shopfenster warm mit Rahmen, Zapfsäulen leuchten, Preistafel hell; Arcades Dachleuchten sind große weiße Flächen, Moderns kleine Punkte – die Tankspur 0,88 × Arcade (`tankstelle` 0,406 / 0,459) |
| Grenze Niederlande (Bremen – Amsterdam km 140) 12 Uhr | besser (klein) | Dach auf Stützen, Häuschen mit Tiefe und Schatten; Arcade flaches Dach ohne Stützen |
| Grenze 22 Uhr | besser | Häuschenfenster warm mit Rahmen; Arcade zwei rein weiße Flächen ohne Zeichnung |
| Start Kiel – Hamburg 12 Uhr | gleich | Startportal als Fachwerkträger statt zweier Pfosten, sonst gleich (durchscheinende Tafel bei beiden) |
| Ziel Kiel – Hamburg 12 Uhr | gleich | Ziel-Banner, Stadtrand; Modern Asphalt etwas dunkler |
| Hamburg Mitte 12 Uhr (km 88,6) | gleich | Backstein, Fensterrahmen, Bäume; Modern mit Laterne links |
| Hamburg Mitte 19:30 | gleich, Wagen schlechter | Stadt und Abendhimmel gleich, Abblendlicht auf dem Asphalt; der Lack der Limousine wirkt in der Dämmerung grau-lila statt Arcades kräftigem Blau (Farbton 271° statt 242°, §7; vermutlich Himmelsreflex, gefolgert) |
| Hamburg Mitte 22 Uhr | gleich | Fenster warm, Laternen werfen Licht auf Gehweg und Wagen (Modern heller als Arcades dunkle Straße); Rücklichter beider rot |
| Kiel Stadtrand 12 Uhr (km 1,0) | gleich | offene Landschaft wie Arcade (in Kiel – Hamburg beginnt die Etappe ohne Stadt), Wegweiser, Rapsfeld, Leitplanken |
| Kiel Stadtrand 19:30 | gleich, Wagen schlechter | Abendhimmel, Bäume, Wegweiser gleich; der Lack der Limousine wieder blass grau-lila statt Blau (wie Hamburg 19:30) |
| Kiel Stadtrand 22 Uhr | gleich | Abblendlicht, Rücklichter, Mond; Wegweiser bei Modern im Licht lesbarer |
| Nürnberg Altstadt 12 Uhr (Würzburg – Nürnberg km 103) | gleich | Fachwerk links, rosa Bürgerhäuser rechts mit Tiefe und Laternen; Arcades Baum vorne links bei Modern dunkler |

Die erste Aufnahme der Tankstelle (Start km 15, `TS15`) zeigte die Station nicht – sie liegt bei km 14,6–14,9; mit
Start km 14,3 und Bildern nach 1,5 und 2,5 s wiederholt (oben). Ordner `ab_weitere/`.

### 5.4 Zwei Clips zu je 30 s (`tools/ab_clip.sh`, links Arcade, rechts Modern, „Hoch“, 60 Bilder/s)

Je sechs Einzelbilder angesehen (2, 8, 14, 20, 26, 29 s), beim Gotthard dazu vier um die Ausfahrt (3–5,2 s).

- `clips/koehlbrand_nacht_regen.mp4` – Kiel – Hamburg ab km 76,3, 22 Uhr, Regen: über die Köhlbrandbrücke (190 km/h)
  durch den Stadtrand bis auf die Elbbrücken. **Besser:** die nasse Fahrbahn spiegelt Laternen und Rücklichter in
  langen goldenen Streifen (Arcade: trockene, matte Fahrbahn bei Regen), Gischt hinter dem Wagen; Häuser mit warmen
  Fenstern, Elbphilharmonie und Fachwerkbögen der Elbbrücken wie Arcade. Bewegung (Flackern, Springen) lässt sich an
  Einzelbildern nicht beurteilen – der Clip selbst ist dafür da.
- `clips/gotthard_ausfahrt.mp4` – Bern – Mailand ab km 199,6, 12 Uhr: die letzten gut 2 km der Röhre, die Ausfahrt bei
  180 km/h, dann 12 km offene Strecke. **Ausfahrt gleich:** Modern zeigt die Öffnung mit Betonrahmen und die Landschaft
  dahinter, weniger überstrahlt als Arcades fast weiße Fläche (gewollt, Notiz 11 a: 0,66 × Arcade); Leuchten und
  Fliesen wie Arcade; die Limousine in der Röhre dunkler als Arcades Sprite. **Danach schlechter (klein):** in den
  Kurven fehlen bei Modern Fichten und ein großer Felsen nah an der Straße, die Arcade zeigt (Bild 26 s; Sichtkorridor
  A-17, kommt mit R7); Berge, Wolken, Bauernhaus, Radar-Tafeln gleich.

## 6. Abweichungen und Vertragsfragen

**Abweichungen vom Auftrag**
- Notiz 11 (c): Docken 0,14 m breit nach Arcades `_balustrade` (fünf je Segment, Pfeiler alle vier Segmente) statt
  der 0,35 m des Auftrags – Arcade ist die Vorlage.
- Notiz 4: Der Zuschlag des Blaulichts bleibt nachts (nur der Bremszuschlag fällt): nachts liegt das Blau der Modelle
  ohnehin bei etwa der Hälfte von Arcade; „höchstens Arcade + 10 %“ ist erfüllt.
- Notiz 6: Mit eingespeistem Verkehr (48 Autos) gilt die Budgetgrenze der Fahrzeug-Ebene (128) nicht – sie kann
  gezeigte Stufen nicht freigeben; gebunden wird durch die Szenengrenze 230 und die Ablehnung der Engine. Ohne
  Einspeisung (Kiel – Hamburg) gilt sie weiter.
- Notiz 4: „bremsschein“ misst das aufsummierte Rot statt der Zahl der Pixel (die Zahl trennte Tag und Verstärkung
  1,0 nicht sicher).
- Determinismus: zwei AS5a-Modelle zweimal erzwungen exportiert und gebacken (nicht alle elf; AS5aR1 hat alle elf
  echt exportiert und zwei davon so geprüft).
- Nach dem ersten Einfrieren (`1cd689d`) noch Code am Tankstellendach (`c72d484`, `b673df5`, `02051f7`, `b903797`,
  `9b02f05`, Notiz 8) und eine Render-Prüfung (`ab2a400`). Die Goldens `6b17293` entstanden auf `c72d484`; die
  späteren Schritte ändern keinen Entscheid (Sonde über das ganze Netz, 1909 Dächer, 0 verschieden) – `modern-check`
  auf dem Endstand: 6 von 6 identisch, GLES OK. Run_tests Lauf 2, Builds und Rauchtest liefen auf dem Endstand, die Render-Prüfungen
  auf `b673df5`, die Strukturprüfungen auf dem Endstand erneut: 7 von 7 OK.
- Notiz 8: „≤ 2 ms“ ist in einem Messlauf auf einer belasteten VM erfüllt (1,36 ms); Höchstwerte streuen dort stark
  (Requisiten 0,12–4,19 ms in vier Läufen ohne Änderung) – auf dem Gerät nicht gemessen.
- **Regelverstoß, selbst gefunden (14:00 Uhr):** mein Hilfsskript für einzelne Render-Prüfungen (`sh/rc_snap.sh`)
  legte zwar einen eigenen Ordner an, exportierte aber `XDG_DATA_HOME` nicht. Rund 20 Läufe (Bremsschein, Laternen, Budget, Wald, Stadt,
  Strukturen, Requisiten; 06:16–13:57 Uhr) liefen deshalb mit dem echten Benutzerordner
  `~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience`. Geschrieben haben sie dort Godot-Logs
  (die Rotation behält fünf – ältere Logs anderer Läufe vor heute sind dadurch verdrängt), den Startwächter
  `modern_start.lock` (von jedem Lauf beim sauberen Ende wieder entfernt, jetzt nicht vorhanden) und 31 Dateien im
  Shader-Cache. Keine Einstellungen, keine Rekorde, kein Spielstand (die Prüfungen speichern nichts). Behoben: das
  Skript exportiert jetzt den Ordner; meine fünf Logs dort gesichert (`logs/userfolder_artefacts/`) und entfernt; die
  Shader-Cache-Dateien liegen noch dort (nicht sicher zuzuordnen, harmlos). Die Ergebnisse der Prüfungen hängen nicht
  daran (kein gespeicherter Grafikmodus, `--graphics=modern` ausdrücklich).
- Die A/B-Bögen und Einzelbilder bis 13:57 Uhr liefen mit dem eigenen leeren, absoluten `XDG_DATA_HOME` von
  `tools/ab_shot.sh` unter `/tmp` (nicht im Arbeitsordner); ab dann mit `TMPDIR` im Arbeitsordner.

**Vertragsfragen**
- NACH-M2 N-03 nahm an, die nasse Fahrbahn verliere mit `SPOT_SPECULAR` 0 ihren Glanz – gemessen pixelgleich: die
  Fahrbahn liegt auf Ebene 2 und nahm den Spot nie (A-20 erster Spiegelstrich ist damit gegenstandslos für die Fahrbahn).
- A-19: Der Wald mit 48 gleichzeitig gezeigten Autos erreicht 216 von 230 – mehr gleichzeitig gezeigte Autos als dort
  verträgt die Szene nicht; die Fahrzeug-Ebene ist ein weiches Budget. Vorschlag: eine harte Obergrenze gezeigter
  Modellautos (Rest als Stand-in-Karte) oder `buffer_size` des globalen Puffers in den Projekteinstellungen prüfen.
- A-19 Tönung: Für Pakete, die MultiMeshes mit `vpbr`/`baked`/`leaves`/`billboard` bauen, gilt jetzt „Farbe und
  Custom-Daten oder keins von beiden“ (Godot 4.7.2 Compatibility, gemessen, §17.3) – als Regel in den Vertrag?
- A-20: Für das Blaulicht gibt es nur die obere Grenze; nachts liegt es bei der Hälfte von Arcade. Eine untere Grenze
  (z. B. 0,8 × Arcade) wäre eine eigene Aufgabe (Blaulicht-Schein der Modelle).

## 7. Besser / gleich / schlechter als Arcade (alle angesehenen Bilder)

**Besser**

- S2 Tankspur Kiel – Hamburg: echtes Dach mit Säulen, Zapfsäulen, Preistafel, Shop.
- S4 Stadtgrenze Hamburg: Einfamilienhäuser getönt wie Arcade, Hansehäuser und Kran in 3D.
- Tunnel Valík, Einfahrt bei Tag: Portal mit Hügel und Bäumen statt flacher Stirnwand.
- Grenze Niederlande nachts: Häuschenfenster warm mit Rahmen statt zweier weißer Flächen; bei Tag (klein) Dach auf
  Stützen, Häuschen mit Tiefe.
- Köhlbrandbrücke bei Tag (klein): das Wasser unter der Brücke sichtbar.
- Clip Köhlbrandbrücke nachts im Regen: die nasse Fahrbahn spiegelt Laternen und Rücklichter (Arcade matt).

**Gleich**
- S1, S3, S5, C1 (19:30), N1 (Schnee 22 Uhr), N2 (Regen), U1 (Gotthard), DEV (21 Uhr); dieselben Urteile bei „Mittel“;
  „Deck“ S1, N2, U1.
- Gotthard 22 Uhr innen, Tunnel Valík innen bei Tag und 22 Uhr, Köhlbrandbrücke 22 Uhr, Augustusbrücke 12 und 22 Uhr
  (Balustrade wie Arcade), Start und Ziel Kiel – Hamburg, Hamburg Mitte 12 und 22 Uhr, Kiel Stadtrand 12 und 22 Uhr,
  Nürnberg Altstadt, Tankstelle Kiel – Hamburg km 15 bei Tag und 21 Uhr; die Gotthard-Ausfahrt im Clip.

**Schlechter**
- T1 (klein), T2, T3, T4 (klein) und der Clip nach der Gotthard-Ausfahrt (klein): Kurveninnenseiten in Bergetappen
  kahl – der Sichtkorridor nimmt dort Bäume und Felsen, die Arcade zeigt (A-17, kommt mit R7).
- Abenddämmerung 19:30 (Hamburg Mitte, Kiel Stadtrand): der Lack der Limousine wirkt grau-lila statt Blau
  (`bilder/lack_daemmerung_hamburg_19_30.jpg`). Gemessen im A/B-Bild (Ausschnitt Heck und Dach): Farbton 271–276°
  statt Arcades 242°, Sättigung 0,27–0,28 / 0,29, Helligkeit 0,30 / 0,37; am Tag 217° / 222°, 22 Uhr 227° / 225°.
  Ursache vermutlich der Abendhimmel im Lack **(gefolgert)**. Neu gelistet (§17.9, Hinweis für die nächste Runde).
- Im Tunnel (U1) wirkt die Limousine dunkler als Arcades Sprite (wie im ersten Testbuild, unverändert).
- Tunnel Valík innen bei Tag: Arcades Ausfahrt ist klarer, Moderns überstrahlt (gewollt nach Notiz 11 a, 0,66 ×
  Arcades Leuchtdichte – „gleich“ gezählt, hier der Vollständigkeit halber).
- Tankstelle 21 Uhr: unter dem Dach etwas dunkler als Arcade (Tankspur 0,88 ×, Dachleuchten kleine Punkte statt
  großer weißer Flächen) – „gleich“ gezählt, hier vermerkt.

## 8. Hinweise für die nächste Runde

- **Kurveninnenseiten (A-17 → R7):** T1–T4 zeigen innen keine Bäume und Felsen, wo Arcade welche hat – der größte
  sichtbare Unterschied zu Arcade in dieser Montage.
- **Lack:** Gran Turismo (Modell silbern, Arcade dunkel blaugrau, N2 0,77×) und Kompakt nachts (1,23×) sind
  Asset-Fragen; die Limousine in der Dämmerung (19:30) grau-lila statt Blau (Farbton 271° statt 242°) – vermutlich der
  Abendhimmel im Lack, nicht untersucht.
- **`collect()` auf dem Deck:** in einem Lauf auf der VM alle Bausteine ≤ 1,36 ms; Höchstwerte streuen auf der
  belasteten VM bis 4,19 ms (Requisiten) – auf dem Gerät oder mit mehreren Läufen bestätigen.
- **Wald 216 von 230** Instanzen mit 48 gleichzeitig gezeigten Autos: wenig Luft; harte Obergrenze gezeigter
  Modellautos oder größerer globaler Puffer (Vertragsfrage §6).
- **Grenzstation Amsterdam – Lüttich km 210,175:** Endstütze gegen „town_ahead“ (22 %) – keine Spieltafel, gelistet.
- **Offen aus den Vorpaketen:** Geländewasser unter Brücken (FIX-R5 8.6), Mondlichtstreifen am Portalhügel
  (NACH-R5 N-01), Abblendlicht ohne Hell-Dunkel-Grenze, die Limousine im Tunnel dunkler als Arcade.
- **Tests:** `test_chunk_services` „services_reach_collect_and_commit_on_the_main_thread“ fiel in einem Einzellauf
  dieser Montage (06:13 Uhr, neben anderer Last) einmal aus – „commit() je gebautem Stück: erwartet 25, ist 23“ –,
  in der Wiederholung und in den vollen Läufen grün; vermutlich zeitabhängig (gefolgert) – beobachten.
- **Werkzeug:** ein Hilfsskript ohne `XDG_DATA_HOME` traf den echten Benutzerordner (§6); `tools/ab_shot.sh` und
  `tools/ab_clip.sh` legen ihren Ordner unter `TMPDIR` an – in Paketen mit der XDG-Regel `TMPDIR` in den Arbeitsordner
  setzen.
- Lackflackern des weißen Autos: weiter pausiert (A-21), hier nichts geändert.

## 9. Lieferung

- Zweig `wip/v080-rint-m2`, Endstand **`9b02f05`** (nach jedem Commit gepusht, nie mit Gewalt; nichts nach `v0.8.0` oder
  `main`, keine Tags, keine Pull Requests).
- Dieser Ordner: `bericht.md`; `ab_boegen/` (Bezugsstellen „Hoch“ und „Mittel“, „Deck“ S1/N2/U1, drei Übersichten);
  `ab_weitere/` (26 Bilder der weiteren Stellen); `clips/` (zwei Clips zu 30 s); `bilder/` (Notizen 3 und 5, die sechs
  Modern-Goldens, Lack in der Dämmerung).
- Arbeitsdateien (Skripte, Sonden, Logs, `STAND.md`) im Arbeitsordner `v080/m1/RINT-M2/` – nicht eingecheckt.
