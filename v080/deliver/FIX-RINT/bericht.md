# FIX-RINT – Nacharbeit nach der QA der zweiten Montage M2 (Basis `9b02f05`)

Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4`, Zweig
`worktree-wf_9927a373-337-4`, gesichert als `origin wip/v080-fix-rint` (nach jedem Commit gepusht, nie force).
Kein Vorgänger gefunden (kein STAND.md, kein Zweig) – Neustart: `git merge --ff-only 9b02f05`, `.godot` kopiert,
Import sauber.

Alle Spielläufe mit absolutem `XDG_DATA_HOME` unter `…/m1/FIX-RINT/xdg/…`, `TMPDIR` und Mesa-Cache ebenfalls dort
(Hilfsskripte `sh/ab.sh`, `sh/mshot.sh`, `sh/rc_one.sh`, `sh/q*.sh` exportieren alles), `--graphics=` ausdrücklich,
`nice -n 10`, `LP_NUM_THREADS=2`, ein schwerer Lauf zur Zeit (Warteschlangen `q1`–`q10`, Tore `sh/gates.sh`). Maschine: llvmpipe, Last
6–13 durch andere Pakete – alles über echte GPU oder Steam Deck ist **gefolgert**, nicht gemessen.

(Abschnitte 1–6 unten; Tore in Abschnitt 7.)

## 1. Blocker F-01 – Tunnelausfahrt bei Tag (behoben, gemessen)

**Nachgestellt** (`shots/f01_base`, QA-Aufruf, Valík 8 Uhr Schnee, „Hoch“): 4,05 / 4,08 s nach dem Start braune,
schneefreie Landschaft (Sättigung 0,18, Farbton 40°), 4,2–4,7 s 66–67 % reines Weiß in der Szenenzone (Arcade
0,4–0,7 %). Bestätigt.

**Ursachen und Änderungen** (`environment_rig.gd`, `builders/tunnel.gd`):
1. `ce_snow`/`ce_wet` folgten der Tunnelrampe der *Kamera*: die ganze Welt verlor ihren Schnee, solange die Kamera
   in der Röhre war. Jetzt immer der Wert der Palette; in der Röhre nimmt ihn niemand an (Fahrbahn Flag 64, Röhre ohne
   Wetter, Fahrzeuge ohne Schnee).
2. Die Lichtrampe lief bis 12 m hinter die Ausfahrt: die erste Landschaft stand im warmen Tunnellicht (auch mit
   Schnee noch beige – erste Prüfung zeigte das). Jetzt endet sie an der Ausfahrt (Arcade schaltet bei Kamera + 1 m
   um); gleiches Gesetz in `tunnel.gd zone_amount()` (der Test verlangt Gleichheit). Blendviereck und Nachglühen
   entscheiden ebenfalls bei Kamera + 1 m (sonst 59 % Weiß in genau dem Bild, in dem Arcade schon normal zeigt).
3. Nachglühen: eigenes Gesetz `1 − (1 − c)^(1 + 0,9·s)` statt Arcades klippendem Gesetz – brennt nur aus, was schon
   fast weiß war, monoton, Markierung behält ≥ 80 % ihres Abstands zur Fahrbahn; bei Schnee aus.

**Prüfung neu:** `tunnel_bridge_ausfahrt_schnee` / `_trocken` (Arcade und Modern derselben Schritte, 2 s nach der
Ausfahrt jedes 6. Bild): reines Weiß ≤ Arcade + 5 Punkte, Schnee im Bodenband ≥ 0,5 × Arcade. Gemessen: Schnee
höchstens +0,1 Punkte, Schnee ≥ 0,99 × Arcade; trocken höchstens +1,0 Punkte; `U1_ausfahrt` weiter OK (0,65 ×).
Gegenprobe auf den Bildern des alten Stands (gleiche Metrik in Python): braune Bilder Schnee 0,002 gegen 0,585, das
Ausbrennen 0,665 Weiß – beides rot. Die erste Fassung der Schneemetrik („hell und fast grau“) ließ ein braunes Bild
durch (0,50 ×) – ersetzt, bevor sie eingecheckt grün meldete.

**Bilder:** `F01_valik_schnee_02/04/06.jpg` (Arcade | vorher | FIX-RINT). Nach der Ausfahrt zeigt Modern jetzt eine
normale verschneite Strecke mit lesbaren Markierungen und verschneiten Fichten, Weiß 1–2 % (Arcade 0,4–0,7 %).

## 2. Hoch / Mittel

| Befund | Ergebnis |
|---|---|
| F-02 offene Autobahn nicht deutlich besser | **offen** – Gestaltungsaufgabe (Himmel mit Wolken, Dunst, Schatten der Vegetation), nicht in einer Nacharbeitsrunde ohne Bilderschleifen lösbar; Fahrbahnverschleiß existiert bereits im Shader (zu zart). An R7/R8 mit QAs Vorschlägen. |
| F-03 Vegetation | **R7** (A-17). S0: die große Eiche (z 27,9 m, x −17,1) fällt als „corridor“ aus dem Kurvenband einer Biegung voraus – gemessen mit einer Sonde über die Bausteine, also derselbe Grund wie T1–T4, kein Fehler des Startvorlaufs. Korridor nicht angefasst. |
| F-04 Stadthäuser nachts | **offen** (Asset-Pipeline). Die Wahl der beleuchteten Fenster folgt in `cities3d.py` den Zufallszahlen des Sprites (`wallmat`); der Mangel liegt also nicht in einem Renderer-Wert, sondern in der Wirkung der 3D-Fenster (Rahmen, Sprossen, Innenring, Tiefe) bzw. der Seitenwände (close3d) – ein Neubacken der AS5a-Modelle (R7/AS5b) mit Messung je Haus. Nicht nebenbei geändert. |
| F-05 Tankstelle nachts | **behoben** – Leuchtvolumen unter dem Shopvordach und Schaufensterschein (Flare, „halo“ 1); Zone 0,77 → 0,95 × Arcade (gemessen); Prüfung `tankstelle` misst die Tankstelle als Ganzes (≥ 0,85 ×). Bild `F05_*.jpg`. Ehrlich: Arcades Volumen ist noch heller und flächiger. |
| F-06 Lack nachts | **behoben für den Sportwagen** (1,19 × / Sättigung 1,83 × → 1,01 × / 1,21 ×, gemessen); die Prüfung misst jetzt alle fünf Autos, rote Lacke richtig. GT 0,92 × / 0,77 ×, Kompakt 1,05 × / 1,23 × (im Band, nicht geändert); der GT bleibt im Modell silbern (Asset). Bild `F06_*.jpg`. |
| F-08 Stöße | **eingegrenzt, teilweise** – Einhängen verteilt, Freigeben verzögert und in Stücken; Reststöße auf der VM nicht vom Rauschen zu trennen (Abschnitt 3). |
| B-01 Einhängen | **behoben** – Einhängen Baustein für Baustein, Ziel 2 ms je Bild (ein Baustein immer); Kiel – Hamburg Deck 8,96 → 3,24 / 2,53 / 2,01 / 2,11 ms (vier Läufe, gemessen, Budget 3 ms: der erste knapp darüber, siehe 3). |
| B-02 Tönungswächter | **behoben** – Mutation `baked`+`leaves` → `test_props` rot (gemessen). |

## 3. Leistung (gemessen auf dieser VM, Deck, Xvfb, Zeitraffer 16, Kiel – Hamburg ganz)

| Lauf | Einhängen max je Bild | Schritte / Stücke | längster Baustein beim Einhängen | Stoß-Liste (Teil, ms, km) |
|---|---|---|---|---|
| QA vorher (`9b02f05`) | 8,96 ms | – | – | – |
| FIX-RINT Lauf 1 | 3,24 ms | 100 / 95 | road 2,37 | streamer 17,5 (46,8), 13,9 (32,3) … |
| FIX-RINT Lauf 2 (+Teilzeiten) | 2,53 ms | 106 / 95 | props 1,54 | streamer 143,7 (7,3), 111,2 (41,0) … → `update_ms_max.free` **141,7 ms** |
| FIX-RINT Lauf 3 (Freigeben in Stücken) | 2,01 ms | 98 / 95 | road 1,23 | streamer 134,0 (90,1), 99,2 (28,8), far_ground 57,5 … → `trash` **133,8 ms** (ein einzelnes Kind) |
| FIX-RINT Lauf 4 (+ 4 Aufrufe Wartezeit) | 2,11 ms | 96 / 95 | props 1,52 | streamer 61,2 (47,7), 50,2 (58,0), vehicles 25,3 … → `trash` 57,4, `path` **49,6 ms** |

Die Stöße des Streamers lagen **nicht** im Einhängen, sondern im **Freigeben** der Stücke hinter der Kamera
(`_drop` → `node.free()` eines ganzen Stücks in einem Bild). Jetzt verlässt das Stück den Baum sofort (seine Lampen
werden vergessen) und wird Kind für Kind freigegeben, höchstens 1 ms je Bild (`FREE_BUDGET_MS`); `clear()` gibt alles
sofort frei. Lauf 3 zeigte, dass auch ein einzelnes Kind noch 134 ms brauchen kann – gleich nach dem Verlassen des
Baums (gefolgert: der Treiber wartet beim Löschen auf das Bild, das das Netz noch zeichnet). Darum wartet ein Stück
jetzt 4 Aufrufe (`TRASH_DELAY`), bevor es freigegeben wird. Lauf 4: `trash` 57 ms, aber auch der reine GDScript-Teil
`path` 49,6 ms und `vehicles` 25 ms – auf dieser VM (Last 12) sind einzelne Stöße dieser Größe nicht mehr vom Rauschen
zu trennen. **F-08 ist daher nur eingegrenzt, nicht als behoben bewiesen**: Einhängen ist es (≤ 2,1 ms je Bild in
Lauf 3/4), das Freigeben ist entschärft; ob die Stöße auf dem Gerät weg sind, zeigt `spikes` des Leistungstests auf
dem Deck. Mittlere Bildzeit Lauf 3/4 3,75 / 3,58 ms. Regel 3 in allen vier Läufen: Prüfsumme der 347 Sekunden = v0.7.0
(`087ade2e…`).

`collect()` der Tankstelle (B-03): `canopy_job_rest()` hält die Frist und macht im nächsten Aufruf weiter; gemessen
höchstens 0,13 / 0,17 ms (QA unter Last 3,6 / 4,9 ms). Der Leistungstest schreibt jetzt `chunk_commit_ms_max`,
`collect_ms_max_by`, `commit_ms_max_by` und `spikes` je Szene (Messung auf dem Deck).

## 4. Niedrig

| Befund | Ergebnis |
|---|---|
| B-03 | behoben (oben) |
| B-04 Wächter | behoben – drei Bilder > 1 s im Countdown urteilen „langsam“ / „zu langsam“; eine Pause allein urteilt nicht (Einheitstest) |
| B-05 Zensus | behoben – Szene zusätzlich in jedem Bild mit neuem Höchstwert der Fahrzeug-Ebene, obere Schranke gemeldet |
| B-06 SPOT_SPECULAR | dokumentiert (= Engine-Vorgabe 0,5); Vertragsfrage A-20 Satz 1 |
| F-07 Hochhaus Frankfurt | R7 – auf der Strecke km 220,95–221,8 gibt es kein Hochhaus-Sprite (2 Bäume, 6 Objekte, Sonde); Arcade zeichnet es aus der Stadt-/Skyline-Logik |
| F-09 Niedrig / Schatten-Draw-Calls | nicht geändert: Primitive 221 k < 250 k im Budget; Schatten-Draw-Calls entschieden in A-15 (Schattenwerfer und -dreiecke zählen) |
| B-07 echter Benutzerordner | nicht dieses Paket (R7a, RINT-Reste) – nichts von FIX-RINT dort (alle Läufe mit eigenem XDG) |

## 5. Bild gegen Arcade – ehrlich

Angesehen: `F01_valik_schnee_02/04/06.jpg`, `F05_tankstelle_21uhr(_ausschnitt).jpg`, `F06_sportwagen_22uhr_regen.jpg`
(je Arcade | Modern vorher | Modern FIX-RINT, gleiche Simulationsschritte).

- **Tunnelausfahrt Schnee (F-01):** vorher das schlechteste Bild des Spiels (weiße Wand, dann braune Landschaft), jetzt
  gleichwertig mit Arcade: verschneite Böschung, lesbare Leitlinien, Fichten mit Schnee, Straße grau. Modern ist hier
  etwas detailreicher (Schneeauflage auf Bäumen, Schneefall mit Tiefe), dafür ist der Schnee am Fahrbahnrand eine Spur
  grauer als Arcades fast weiße Fläche. Kein Sprung mehr beim Verlassen der Röhre.
- **Tankstelle 21 Uhr (F-05):** jetzt leuchtet unter dem Shopvordach ein warmer Lichtsaum und die Schaufenster
  scheinen; Leuchtdichte der Zone 0,95 × Arcade. Arcade wirkt immer noch einheitlicher und „flächiger“ hell (gemaltes
  Lichtvolumen), Modern hat dafür Tiefe, echte Lichtkegel auf dem Vorplatz und Spiegelungen. Nicht besser als Arcade,
  aber nicht mehr dunkler.
- **Sportwagen nachts im Regen (F-06):** vorher leuchtend kirschrot wie bei Tag, jetzt dunkles Nachtrot wie Arcade
  (1,01 × Leuchtdichte, 1,21 × Sättigung); die Oberseite ist etwas dunkler als Arcades Glanzlicht auf dem Heck.
- **Offen und sichtbar schlechter oder nicht besser als Arcade:** offene Autobahn bei Tag (F-02, Himmel ohne Wolken,
  wenig Tiefe), Stadthäuser nachts (F-04), fehlende Vegetation am Kurveninnenrand (F-03, R7), Frankfurter Hochhaus
  (F-07, R7).

## 6. Vertragsfragen, Abweichungen

Vertragsfragen:
1. **A-20 Satz 1 (B-06):** der Satz meint `SPOT_SPECULAR`, wirksam ist aber `ce_headlight_light`
   (`inc/headlight.gdshaderinc`, durch `nass_kegel` geschützt). `SPOT_SPECULAR` = 0,5 ist die Engine-Vorgabe; im Code
   nur so dokumentiert, nicht entfernt (Fassade/Vertrag gehören der Integration). Bitte A-20 Satz 1 auf
   `ce_headlight_light` beziehen.
2. **§4.10 Einhängebudget je Bild statt je Stück:** `commit_ms_max` misst jetzt die Einhängezeit eines *Bildes* (ein
   Stück verteilt sich auf mehrere). Der Vertrag spricht von „Einhängen je Bild“ – so gelesen; falls je Stück gemeint
   war, bitte klären.
3. **A-7 Fassade:** `chunk_node()` antwortet erst, wenn das Stück ganz eingehängt ist (vorher sofort nach dem
   Einhängen im selben Bild). Kein Aufrufer verlässt sich auf mehr (geprüft: Leistungstest, Prüfungen), aber es ist
   eine Verhaltensänderung der Schnittstelle.
4. **Nachglühen der Tunnelausfahrt:** Modern hat ein eigenes, nicht klippendes Gesetz statt Arcades × 1,7 + 0,25 –
   Abweichung von „wie Arcade“, begründet mit Regel 9 (Lesbarkeit). Das Blendviereck selbst folgt Arcade.

Abweichungen:
- F-02 und F-04 nicht behoben (Gestaltung bzw. Asset-Pipeline), F-03 und F-07 an R7 (A-17 Korridor nicht angefasst).
- F-08 nicht als behoben bewiesen (VM-Rauschen, Abschnitt 3).
- Der GT bleibt silbern statt Arcades Farbe (Asset, nicht Renderer); Kompakt-Nachtlack (1,05 × / 1,23 ×) nicht
  verändert, weil im Band.

## 7. Tore (Endstand `3248211`, gemessen)

| Tor | Ergebnis |
|---|---|
| Import | sauber (`.godot` aus der Basis, `--import` ohne Fehler) |
| `tools/run_tests.sh` Lauf 1 (`0ef122e`) | 804 Tests, 0 fehlgeschlagen; **3 Prüfdateien rot** durch meinen eigenen Fehler (`bool(e[8])` in `flares.gd`: der neue Merker lag auf dem Platz des Profil-Caches von `_lamp_profile()`, nachts im Regen brach `_add_statics()` ab) → behoben in `3248211` (Platz 10, `STATIC_SEEN`); `check_light_cap`, `check_benchmark`, `check_attract`, Attract-Szenen Modern einzeln grün |
| `tools/run_tests.sh` Lauf 2 (`3248211`) | alle Prüfdateien und Szenarien grün (Sicht `modern_sight_*` OK); **804 Tests, 2 fehlgeschlagen**: `test_engine3_checks` (18 Aussetzer des Generators, Füllung bis 190 ms – VM-Last 13) und `test_music_checks` (Szenario `race`) – beide Klang, von FIX-RINT nicht berührt, in Lauf 1 grün, **einzeln danach grün** (Last 6: 0 Aussetzer; 2/2 und 2/2). Kein dritter Volllauf (Grenze 2). |
| `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch, arcade-ui: 17 von 17 identisch** |
| `tools/golden.sh modern-check` | **6 von 6 identisch**, GLES gegen GL OK (2/255, 73,2 dB) – kein `modern-make` nötig (keins der sechs Bilder zeigt eine geänderte Lage; `modern_s1_nacht` angesehen) |
| `tools/run_render_checks.sh all` | **28 von 28 Render-Prüfdateien in Ordnung**, 81 RENDER-CHECK-Zeilen, keine SCRIPT/SHADER-Fehler, keine Ablehnung von Instanz-Uniforms; darunter `tunnel_bridge_ausfahrt_schnee/_trocken`, `tankstelle` (Tankstelle als Ganzes 0,87 ×), `spielerauto` (Sportwagen 1,01 × / 1,21 ×), `instanzen*` mit oberer Schranke |
| `modern_sight`/`path_check --full` | nicht gelaufen – keine Platzierung oder Größe geändert (die Tankstellen-Leuchtscheine sind Flares ohne Geometrie) |
| Validator / Export-Determinismus | nicht gelaufen – kein Modell geändert |
| `audio_qc` | nicht gelaufen – kein Klang geändert |
| Regel 3 | Prüfsumme der 347 Sekunden Kiel – Hamburg in vier Modern-Läufen = v0.7.0 (`087ade2e…`) |

Commits (alle nach `origin wip/v080-fix-rint` gepusht, nie force): `c6348fa`, `05156b8`, `f2d64f2`, `3628eab`, `c9b1070`,
`cc92991`, `0ef122e`, `3248211`.
