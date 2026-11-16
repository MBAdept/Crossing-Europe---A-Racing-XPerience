# QA-R4 – Unabhängige Prüfung von R4 „Licht, Nacht, Wetter“

Prüfling: `origin/wip/v080-r4`, Kopf `7f0eae2` (20 Commits über der Basis `6e48405` = `origin/wip/v080-m2int`).
Prüfer-Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3` (vorgespult auf
`7f0eae2`, **kein Commit, kein Push**); Basis als `git archive`-Kopie (importiert) unter `m1/QA-R4/base`; Mutationen in
einer Kopie des Kopfes (`m1/QA-R4/mut`). „gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte
Kerne, Last 13–18 durch andere Pakete); alles über Steam Deck, echte Grafikkarten und Wirkung auf Menschen ist
**abgeleitet**. Alle Läufe mit absolutem `XDG_DATA_HOME` und `--graphics=` ausdrücklich, schwere Jobs nacheinander,
`nice -n 10` (`QA_M2_FERTIG` lag vor).

## Urteil

**Nicht unverändert in Testbuild 2 – zwei hohe Bildfehler nachts im Regen müssen vorher behoben werden; alles
andere hält.** R4 schließt die größte Lücke, die der Nutzer gesehen hat: Regen und Schneefall in der Luft auf jeder
„Effekte“-Stufe (auch „Steam Deck“), Gischt, nasse Fahrbahn mit Himmels- und Lichtspiegelungen, Schneewälle, Schnee auf
den Dingen, Sonnenscheibe, überstrahlte Tunnelausfahrt, Blaulicht-Kegel und ein Nachtgesetz, das die Limousine aus dem
Schwarz holt. Die Tore halten (gemessen): Fairness F1–F7 im ganzen Netz grün, Arcade 20 von 20 und 17 von 17 identisch, alle
9 gefahrenen Render-Prüfdateien grün (darunter `check_start_km0`, `check_terrain_cover` mit K1, `check_light_base` und
F6 an N1), kalter Cache an N1 und N2 ohne Übersetzung während der Fahrt (die Basis übersetzte an N1 drei Varianten),
`run_tests.sh` bis auf zwei lastabhängige Fremdtests grün, Dateibesitz sauber bis auf die gemeldeten Grenzfälle.

**Aber:** (B1) die Rücklicht-Spiegelungen sind waagrechte Vierecke und stehen an jeder Steigung als rote Säule über
fernen Autos in der Luft – in meinem Bild bei 4 s und in R4s eigenem Clip bei 6 s; (B2) die nasse Fahrbahn im
Abblendlicht ist 1,77 × so hell wie bei Arcade und in der Basis, die Markierungen dort haben weniger als den halben
Kontrast – ein cremefarbener Fleck genau dort, wohin der Spieler schaut. Beides geht durch alle Prüfungen des Pakets.
Für B2 habe ich die Behebung in einer Kopie ausprobiert (Lichter nur auf den diffusen Anteil): Kegel 54 statt 108
(Arcade 61), Markierungskontrast 3,30 statt 1,31 (Arcade 2,93) – ein kleiner, gezielter Eingriff in `road.gdshader`.
Nachts im Regen ist Modern damit heute **in der Luft besser, auf der Straße schlechter** als Arcade; bei Tag, im Schnee,
in der Dämmerung und an der Tunnelausfahrt ist es gleichwertig bis klar besser. Offen bleibt der Lack (GT nachts grau,
Limousine nachts zu satt / in der Dämmerung blass) – teils schon in der Basis, teils FIX-M2 B-06.


## Befunde

Schwere: Blocker = darf nicht in Testbuild 2; hoch = der Nutzer merkt es sofort; mittel = merklich; niedrig = Politur.

### B1 – hoch – Rücklicht-Spiegelungen schweben als rote Säule in der Luft, wenn die Straße voraus ansteigt
- **Wo**: `scripts/race3d/layers/vehicles.gd` `_put_streak()` / `_add_flares()` (Spiegelung jeder Rück-/Bremsleuchte bei
  `_wet > 0`) und `assets/shaders/modern/flare.gdshader`, Zweig `CE_STREAK`, `vertex()`: der Streifen ist ein
  **waagrechtes** Viereck in der Höhe des Bodens unter der Lampe (`ground = lamp - vec3(0, h - 0.03, 0)`,
  `to_cam.y = 0.0`) bis zu 18 m zur Kamera hin. Steigt die Straße zum Auto hin an (das Auto liegt höher als der
  Boden zwischen ihm und der Kamera), liegt dieses Viereck über der Fahrbahn in der Luft; über der Augenhöhe der
  Kamera steht es auf dem Bild als senkrechte rote Säule über dem Auto. Der Tiefentest verdeckt es nicht (davor ist
  nur Himmel/Gelände dahinter). Dasselbe Gesetz haben die Laternen-Spiegelungen (`flares.gd` `_put_streak`, gelb).
- **Was**: N2N (Dortmund – Frankfurt km 121, 22 Uhr, Regen, „Hoch“), Bild bei 4 s: über einem Auto rund 300 m voraus
  steht eine rote, im Takt des Schimmers gestreifte Säule von etwa 65 Bildpunkten Höhe über dem Horizont (gemessen
  am Bild; Arcade und Basis: ein kleiner roter Punkt). In R4s eigenem Clip `clip_nacht_regen_verkehr_N2.mp4` reicht
  sie bei 6,2 s bis an den oberen Bildrand.
- **Beleg** (gemessen): `m1/QA-R4/shots/head/N2N_high_ab_01.jpg`; derselbe Lauf mit `STREAK_GAIN := 0.0` in der
  Mutationskopie (`sh/x_streakoff.sh`) zeigt keine Säule → `bilder/B1_spiegelung_schwebt_arcade_kopf_ohne-spiegelung.png`
  (Arcade | Kopf | Kopf ohne Spiegelungen); `bilder/B1b_R4-clip_6s_rote_saeule.png`.
- **Nachstellen**: `sh/ab.sh head N2N_high N2N high --shot-times=2,4` (= `tools/ab_shot.sh` mit
  `--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=22 --weather=rain --vehicle=gran_turismo --seed=14
  --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120 --shot-times=4`,
  `GFX_ARGS=--gfx-preset=high`), Bild `_01`, Bereich x 620–660, y 240–320.
- **Behebung**: den Streifen auf die Fahrbahn legen statt waagrecht: `vehicles.gd` gibt das ferne Ende des Streifens auf
  der Straße mit (`path.world(z_auto − len, x, 0)` als Instanzdaten, z. B. anstelle von `length` die Höhe dieses Punktes
  relativ zur Lampe) oder die Bodennormale des Autos (`car.pose.basis.y`); der Shader baut `dir` in dieser Ebene
  (`dir = normalize(to_cam − n·dot(to_cam, n))`) und kürzt `len` dort, wo der Pfad mehr als ~0,3 m von der Ebene
  abweicht (Kuppe/Senke). Gleiches für die Laternen in `flares.gd`. Prüfung dazu in `check_weather` „nass“ oder
  `check_night`: an einer Steigung (z. B. diese Stelle, 4 s) keine rot verschobenen Bildpunkte oberhalb der
  Lampenzeile eines fernen Autos.

### B2 – hoch – Nasse Fahrbahn im Abblendlicht fast doppelt so hell wie Arcade, Markierungen mit halbem Kontrast
- **Wo**: `assets/shaders/modern/road.gdshader`, nasser Asphalt (`sky_k = sky / max(ce_ambient_display.rgb, vec3(0.2))`,
  `asph = mix(asph, sky_k, mirror)`, `line = mix(…, sky_k, mirror * 0.35)`) und danach
  `EMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(base) * extra)` mit
  `extra = ce_pools(...) + ce_headlight_light(...)`. Der gespiegelte Himmel wird als **Albedo** eingemischt (durch die
  Umgebung geteilt, damit er unter dem Umgebungslicht als Himmelsfarbe erscheint); das Abblendlicht und die
  Lichtkegel multiplizieren diese Albedo dann wie eine helle, matte Fläche. Nachts ist `ce_ambient_display` < 0,2 →
  `sky_k ≈ 5 × Himmel ≈ 0,5–0,6`, gegen nassen Asphalt ≈ 0,14; 30–50 m voraus ist `mirror` 0,25–0,29 → der Asphalt im
  Kegel wird fast doppelt so hell. Echte nasse Fahrbahn wird im Scheinwerfer **dunkler** (Arcade: −32 %).
- **Was** (gemessen, Median der Leuchtdichte 0–255 in x 560–720 / y 380–440, 2 s): N2N 22 Uhr Regen **Arcade 61,
  Basis 59, Kopf 108 (1,77×)**; mit „Steam Deck“ (1.500 statt 4.000 Teilchen) ebenso (114–129 gegen 53–68 je Zeile) –
  also die Fahrbahn, nicht der Regen. Trocken: N1 Schnee 1,08×, DEV 1,18× (night_lift). Markierung gegen Asphalt in
  Zeile 372: Arcade 224 / 57 (Weber-Kontrast 2,93), Basis 208 / 47 (3,4), **Kopf 232 / 100 (1,31)**.
  `check_weather_tabelle` sah das nicht (22 Uhr Regen 0,97 ×, gemessen), weil sie über den ganzen Boden unter dem Horizont mittelt.
- **Beleg**: `bilder/B2_nasse_fahrbahn_im_abblendlicht_arcade_basis_kopf.png` (Arcade | Basis | Kopf: cremefarbener
  Fleck), auch in R4s eigenem Clip sichtbar.
- **Nachstellen**: wie B1, Bild `_00`; Bereich wie oben.
- **Behebung**: die Lichter nur auf den diffusen Anteil wirken lassen: in `road.gdshader` den Asphalt vor der
  Spiegelung merken (`vec3 diffuse = asph * (1.0 − mirror)`), den Himmel als eigenen, unbeleuchteten Anteil führen und
  `EMISSION = encode(ground_base_lin(base) + pools_to_lin(diffuse_surf) * extra)` rechnen (Markierungen ebenso); dann
  wird der Kegel auf nasser Fahrbahn dunkler als trocken, wie bei Arcade. **Ausprobiert** (Kopie des Kopfes,
  `deliver/QA-R4/b2_behebung_probe_road_gdshader.py`, 16 Zeilen, gemessen am selben Bild): Kegel **54** (Arcade 61,
  Kopf 108), Markierung 200 / 46 (Weber **3,30**, Arcade 2,93), ferne Fahrbahn mit Himmelsspiegelung unverändert (21);
  Bild `bilder/B2b_behebung_probe_arcade_kopf_probe.png`. Prüfung: `check_night` um „nass_kegel“
  erweitern – N2 22 Uhr Regen, Median der Fahrbahn im Kegel ≤ 1,15 × Arcade und Weber-Kontrast der Markierung
  ≥ 0,8 × Arcade.

### B3 – mittel – Silberner Gran Turismo nachts im Regen hellgrau statt dunkel-marineblau (offen, schon in der Basis)
- **Wo**: Lack-Look `ModernMaterials.VEHICLE_LOOK` / `vpbr.gdshader` (Klarlack spiegelt den grauen Regen-Nachthimmel,
  `env_night` 0,35; Füll-Schimmer `fill_sheen_tint`).
- **Was** (gemessen, Heck x 520–800 / y 520–720, N2N 22 Uhr): 75. Perzentil der Leuchtdichte Arcade 36,9 / Kopf 40,5
  (+10 %), Median-Sättigung 0,47–0,50 / 0,38 (0,78×); `check_night` „spielerauto“ misst 0,93× / 0,73× (Schranke 0,7×,
  knapp). Bild `bilder/11_N2N_GT_arcade_kopf.png`. In der Basis ebenso grau (`10_N2N_basis_kopf.jpg`) – R4 hat es nicht
  verschlechtert, aber nicht gelöst; R4 meldet es selbst als offen.
- **Nachstellen**: `sh/ab.sh head N2N_high N2N high --shot-times=2`.
- **Behebung**: bei FIX-M2 B-06 / R7: Klarlack-Spiegelung nachts bei Regen auf die Himmelsfarbe des Sprites (blaue
  Nachttönung) statt Grau, oder `env_night` für helle Metallic-Lacke senken; Schranke der Sättigung in `check_night`
  von 0,7× auf 0,85× anheben, wenn es gelöst ist.

### B4 – mittel – Die neuen Prüfungen bewachen die beiden sichtbarsten Fehler nicht
- **Wo**: `tests/race3d/render/check_weather.gd` „nass“ (nur Spiegelung unter dem eigenen Auto auf ebener Strecke und
  Helligkeitsverhältnis fern/nah bei Tag), `check_weather_tabelle*.gd` (Mittel über den ganzen Boden),
  `check_night` „fahrbahn“ (nur N1 Schnee, trocken), `check_weather` „schneewall“ (prüft die Funktion
  `bank_height()`, nicht das gebaute Netz), `test_environment_rig` `test_exit_ramp`.
- **Was**: B1 und B2 gehen durch alle Prüfungen (R4: 23/23 grün). Mutationen (gemessen): U5 (Nachglühen springt bei 60 m
  von 0,39 auf 0) unerkannt; R3 (Profil-Scheitel ×2,6 → 0,78 m hoher Wall im Netz) ebenso unerkannt (die Prüfung misst die Funktion `bank_height()`, nicht das Netz).
- **Behebung**: `check_night` um „nass_kegel“ (B2) und eine Steigungs-Stelle für Spiegelungen (B1) erweitern;
  „schneewall“ die Höhe aus dem Netz messen (größtes y der Wall-Ecken über dem Boden-Ring, das liefert
  `TerrainBuilder.debug()` schon fast); `test_exit_ramp` zusätzlich Stetigkeit prüfen (`exit_after(EXIT_AFTER_M − 0,5) < 0,02`).

### B5 – niedrig – Wetter-Ebene folgt dem Wächter nicht (`quality_lowered` fehlt)
- **Wo**: `scripts/race3d/layers/weather.gd` hat `apply_quality()`, aber kein `quality_lowered(levels)`;
  `ModernRenderer` ruft beim Herabstufen im Countdown nur Hooks mit dieser Methode (`modern_renderer.gd` Z. ~599).
- **Was** (aus dem Code, abgeleitet): senkt der Langsamkeits-Wächter die Voreinstellung (z. B. „Hoch“ → „Mittel“),
  behält der Niederschlag 4.000 Teilchen im großen Kasten und die volle Gischt – gerade das, was auf llvmpipe die
  Bildzeit „Stadt bei Nacht im Regen“ um 29 % erhöht hat (R4, gemessen 552 → 710 ms).
- **Nachstellen**: `--gfx-preset=high` auf einer langsamen Maschine mit Wächter (ohne `--gfx-sync`), Schnappschuss
  `weather.particles` nach dem Herabstufen.
- **Behebung**: `func quality_lowered(levels): apply_quality(levels); _box = box_for(kind, _level);`
  `_particles.multimesh.instance_count`/`visible_instance_count` auf `_count` setzen und `box_lo/box_hi` neu setzen.

### B6 – niedrig – Nachglühen nach der Tunnelausfahrt hängt am Ort, nicht an der Zeit
- **Wo**: `environment_rig.gd` `exit_after(exit_behind(...))` – Stärke als Funktion der Kamerastrecke hinter dem Portal
  (60 m), keine Uhr.
- **Was** (aus dem Code, abgeleitet): steht das Auto innerhalb von 60 m hinter einer Ausfahrt (Stau, Unfall, Polizei),
  bleibt das ganze Bild dauerhaft überbelichtet (bei 10 m: Stärke 0,37 → × 1,43 + 0,15); bei 140 km/h dauert es wie
  gewollt ~1,5 s, bei 30 km/h 7 s. Am Portal (TEXIT 3,8 s) ist der Himmel fast weiß und das Gras blass, während Arcade
  sein normales Draußen zeigt (Bild `06_TEXIT_arcade_basis_kopf.jpg`, dritte Zeile) – Arcade kennt kein Nachglühen.
- **Behebung**: Stärke = Ortsgesetz × Abklingen über `view.time` seit dem Verlassen (z. B. 1,2 s), beides mit
  `--gfx-sync` bestimmt; oder das Nachglühen weglassen und nur das Viereck im Portal behalten (das ist Arcades Gesetz).

### B7 – niedrig – Limousine nachts satter als ihr Sprite (Königsblau statt Marine)
- **Wo**: Nacht-Füll-Licht `fill_sheen_tint` 0,8 (`ModernMaterials.VEHICLE_LOOK`, `vpbr.gdshader`).
- **Was** (gemessen, DEV 21 Uhr, Auto-Ausschnitt): Leuchtdichte 32,9 gegen 30,3 (1,09×, in Ordnung), Median-Sättigung
  0,87 gegen 0,63 (**1,38×**); Kofferraumdeckel 0,87 gegen 0,68. Bild `12_DEV_limousine_arcade_kopf.png`. Die Basis war
  dort fast schwarz (0,49×) – insgesamt ein Fortschritt, aber `check_night` hat nur eine Untergrenze der Sättigung.
- **Behebung**: Obergrenze (≤ 1,25×) in `check_night` „spielerauto“ und die DEV-Stelle als vierten Fall; den Tint des
  Schimmers nach der Sättigung des Lacks begrenzen.

### B8 – niedrig – Blendviereck der Ausfahrt kann durchsichtige Dinge dahinter überschreiben (abgeleitet)
- **Wo**: `environment_rig.gd` `GLARE_SHADER` (`ALPHA = 1.0`, liest `hint_screen_texture`) – die Kopie des Bildes enthält
  nur das Undurchsichtige; was im durchsichtigen Durchgang **vor** dem Viereck gezeichnet wurde (Lichtpunkte, Regen,
  Glas jenseits des Portals) wird überschrieben. Die Reihenfolge ergibt sich aus der Tiefe der AABB-Mitte; die
  Lichtpunkt-Ebenen haben eine riesige AABB um den Weltursprung (bis 2.000 m hinter der Kamera nach einem
  Ursprungsversatz).
- **Was**: nur bei Tag an Tunnelausfahrten; ein Bremslicht oder Blinker eines Autos direkt hinter dem Ausgang könnte
  verschwinden, solange die Kamera in der Röhre ist (F6). Nicht beobachtet in den Bildern, aus dem Code abgeleitet.
- **Behebung**: dem Blend-Material `render_priority = -128` geben (wird vor allen anderen durchsichtigen Dingen
  gezeichnet) oder die Lichtpunkt-Materialien höher priorisieren; Probe: TEXIT mit bremsendem Auto 20 m hinter dem
  Ausgang.

### B9 – niedrig – Dateibesitz und Zusammenführung
- `flare.gdshader` ohne W3-Besitzer geändert (R4 hat es gemeldet); `tests/golden/modern_slice.{md5,env}` ohne
  W3-Besitzer neu erzeugt (Konflikt mit FIX-M2, R5, R6; `docs/renderer-modern.md` mit R5). Behebung: RINT-M2 löst die
  Hash-Dateien nicht von Hand, sondern erzeugt sie nach dem Zusammenführen mit `golden.sh modern-make` neu (nach
  Ansicht der Bilder); den Abschnitt in `renderer-modern.md` beider Pakete hintereinanderstellen.



## Geprüft und in Ordnung

- Ownership: 42 Dateien, keine eingefrorene Arcade-Datei, `race_session.gd`/`race_renderers.gd`/Konfiguration unberührt.
- Fairness: `modern_sight.gd -- --full` und `modern_path_check.gd -- --full` grün (Zahlen in §3).
- Arcade-Gleichheit: 20 von 20 und 17 von 17 identisch.
- `run_tests.sh` Vollauf: alle CHECK-Dateien grün, 760 von 762 Einheitstests (die zwei roten sind lastabhängig und nicht
  von R4, die Basis fällt beim selben Kern-Test ebenso).
- Render-Prüfungen: `check_night` 4/4, `check_weather` 5/5, beide Wettertabellen (24 Starts, 0,90–1,01 × Helligkeit,
  Kontrast ≥ 0,74 ×), `check_vehicle_lights` 4/4 (F6 an N1), `check_occlusion` 2/2, `check_start_km0` 3/3,
  `check_light_base` 2/2, `check_terrain_cover` 7/7 inkl. K1 – alle mit denselben Zahlen wie R4 (bestimmt).
- Geschützte Korrekturen des ersten Testbuilds halten: Start km 0, Fernboden/K1, Tageslicht, `test_far_ground_water`,
  `test_props`; `PYLON_BLINK`, `blink_lit`, `night_albedo`, `_dark_model_override` unverändert vorhanden.
- Kalter Shader-Cache „Steam Deck“: N1 443 Varianten vor dem Start, 0 während der Fahrt (Basis: 3 bei 4,6 s → R4s
  Aufwärm-Ebene wirkt); N2 22 Uhr Regen 459 / 0. Längstes Bild ≤ 1.546 ms bei Grenze 2.390–3.602 ms.
- Lichtdeckel: ≤ 8 Punktlichter, ≤ 2 Spots, ≤ 22 Kegel entlang dreier Nachtetappen; R5/R6 erzeugen keine eigenen
  Lichter (die Ebene 20 bleibt sauber).
- Netz: Schneewälle auf allen 64 Etappen ohne Fehler gebaut (≤ 0,351 m), alle 26 Tunnelausfahrten erkannt, keine
  Tunnel-Lücke < 60 m.
- Schnittstellen: `set_zone()` dokumentiert und von R5 richtig benutzt; `add_lamps()` unverändert; Zusammenführung
  mit FIX-M2/R5/R6 nur in Hash-Dateien und einer Doku-Datei im Konflikt.
- Mutationen: 9 von 12 sinnvollen Brüchen erkannt (U1–U4, U6, U7, R1, R2, R4).
- Bilder: N1 (Hoch, Deck), S1 bedeckt, S1 Morgen/Abend, C1, DEV, Tunnelausfahrt in der Röhre – gleichwertig bis besser
  als Arcade und nirgends schlechter als die Basis (außer B1/B2 nachts im Regen).


## 1. Bilder (`tools/ab_shot.sh`, Modern „Hoch“ wenn nicht anders genannt; angesehen)

Jede Stelle als A/B gegen Arcade desselben Simulationszustands und gegen die Basis `6e48405` (Modern der Basis mit
denselben Argumenten). Dateien in `deliver/QA-R4/bilder/`.

| Stelle | Datei(en) | gegen Arcade | gegen die Basis |
|---|---|---|---|
| **N1** Hamburg – Hannover km 71, 22 Uhr, Schnee, „Hoch“ (2 s / 4 s) | `N1_high_ab_00/01.jpg`, `09_N1_basis_kopf.jpg` | **besser**: dichter Schneefall als gezogene Flocken, Schneewälle an der Bankette, Schnee auf den Büschen, Kegel; Kompakt gelb wie das Sprite, etwas heller und gelber (Arcade bernstein). Ferne Flocken verdichten sich am Fluchtpunkt zu einem Punktefeld („Sternenflug“) – Geschmack, kein Fehler | besser (die Basis hatte keinen Niederschlag); nichts schlechter. Die gezackte Schattenkante rechts neben dem Auto ist schon in der Basis da (nicht R4) |
| **N1** „Steam Deck“ 1280×800 | `N1_deck_ab_00.jpg` | besser: 1.500 Teilchen sichtbar, Wälle, 16:10 gefüllt | – |
| **N2N** Dortmund – Frankfurt km 121, 22 Uhr, Regen, „Hoch“ | `N2N_high_ab_00/01.jpg`, `10_N2N_basis_kopf.jpg`, `B1_*`, `B2_*`, `11_N2N_GT_arcade_kopf.png` | Regen, Gischt und Rücklicht-Spiegelungen **besser**; **schlechter**: (1) der Abblendlicht-Fleck auf der nassen Fahrbahn ist ein heller cremefarbener Fleck – Median der Fahrbahn im Kegel 108 gegen Arcade 61 (1,77×), Markierungen dort mit halbem Kontrast (Befund B2); (2) bei 4 s steht über einem Auto 300 m voraus eine rote Säule in der Luft (Befund B1); (3) der GT liest sich hellgrau-silbern statt dunkel-marineblau (75. Perzentil +10 %, Sättigung 0,78×) | Regen besser, aber B1 und B2 sind **neu** (die Basis hat dort einen normalen Kegel – Median 59 – und einen roten Punkt); der graue GT ist schon in der Basis so |
| **N2N** „Steam Deck“ | `N2N_deck_ab_00.jpg` | wie „Hoch“: Regen sichtbar, Kegel-Fleck ebenso hell (Median 114–129 gegen 53–68) | – |
| **C1** Frankfurt km 221, 19:30 | `C1_high_ab_00.jpg`, `07_DEV_C1_arcade_basis_kopf.jpg` | gleichwertig bis besser: Fassaden, Gehwegpflaster, Laternen; der Sportwagen etwas satter rot | praktisch gleich |
| **DEV** Teststrecke km 48, 21 Uhr | `DEV_high_ab_00.jpg`, `07_…`, `12_DEV_limousine_arcade_kopf.png` | gleichwertig; die Limousine ist jetzt so hell wie Arcades Sprite (Auto-Ausschnitt Median 32,9 gegen 30,3), aber deutlich satter (0,87 gegen 0,63 – leuchtendes Königsblau statt Marine) | **besser**: in der Basis war das Auto fast schwarz (Median 14,8 = 0,49× Arcade) |
| **S1 Morgen** 6:36 | `S1DAWN_high_ab_00.jpg`, `08_…` | besser: Sonnenscheibe links am Horizont wie Arcade, lange Schatten; Limousine etwas heller (+9 %) und blasser/lila (Sättigung 0,86×) | gleich bis besser (Sonnenscheibe) |
| **S1 Abend** 19:12 | `S1DUSK_high_ab_00.jpg` | besser (Sonnenscheibe rechts wie Arcade, Gegenlicht); Limousine wie am Morgen etwas blasser | – (Basisbild aus Zeitgründen ausgelassen) |
| **S1 bedeckt** 12 Uhr, Regen | `S1OVC_high_ab_00.jpg`, `08_…` | **deutlich besser**: Regen über das ganze Bild, nasse Fahrbahn spiegelt den Himmel, Gischt an den Hinterrädern; Arcades Gras greller | besser (Basis: nur dunklere Fahrbahn) |
| **Tunnelausfahrt** Teststrecke km 52,8, 12 Uhr (1,0 / 2,4 / 3,8 s) | `TEXIT_high_ab_00/01/02.jpg`, `06_TEXIT_arcade_basis_kopf.jpg` | in der Röhre **gleichwertig**: die Öffnung ist überstrahlt wie bei Arcade (die Basis zeigte sie normal belichtet); am Portal (3,8 s) liegt das Nachglühen über dem ganzen Bild – Himmel fast weiß, Gras blass, während Arcade dort sein normales, sattes Draußen zeigt (Szene: Mittel 0,63 gegen 0,71, Kontrast 0,24 gegen 0,22 – nicht kontrastärmer als Arcade, aber milchiger) | in der Röhre besser (Ausfahrt jetzt überstrahlt), am Portal Geschmackssache (Nachglühen ist eine Zutat über Arcade hinaus) |

Bewertung insgesamt: Wetter in der Luft, Gischt, Schneewälle und die Sonnenscheibe sind echte Gewinne gegen Arcade und
gegen die Basis – genau die Lücke, die `was_neu.md` dem Nutzer genannt hat, ist geschlossen. **Nachts im Regen ist das
Bild aber an zwei Stellen schlechter als Arcade und als die Basis** (B1, B2), und zwar an der Stelle, die der Spieler
die ganze Zeit ansieht (Kegel vor dem Auto, Rücklichter voraus).


## 2. Funktion im ganzen Netz

Datenscan `m1/QA-R4/sh/scan_data.gd` (kopflos, gemessen, 57 s), alle 64 Etappen des Netzes (ohne Dev-Etappen):
- **Schneewälle**: je Etappe drei Kamerafenster (bei ¼, ½, ¾ der Strecke), jedes Stück, das der Streamer dort will, mit
  dem Terrain-Builder und Schnee gebaut – **2.517 Stücke, 2.331 mit Wall, 884.292 Walldreiecke, 0 Fehler**, höchster
  Wall 0,351 m (Grenze 0,45 m), keine Wall-Reihe in Tunnel, Wasser oder Stadt.
- **Tunnelausfahrt**: alle 26 Tunnel (13 Tunnel × 2 Richtungen) – `EnvironmentRig.exit_ahead()` erkennt jede Ausfahrt
  5 m vor dem Portal (0 Fehler); **keine** zwei Tunnel liegen weniger als 60 m (`EXIT_AFTER_M`) auseinander, das
  Nachglühen kann also nie in die nächste Röhre fallen.
- Niederschlag, Gischt, Spiegelungen, Blaulicht und Nachtgesetz sind etappenunabhängig (Wetter je Start, Fahrzeuge der
  Ansicht, Lampen über `add_lamps()`); `check_light_cap` „deckel“ (im Vollauf, gemessen) fuhr drei Nachtetappen
  (N1 197 Proben, Kiel – Hamburg ab km 76 206 Proben, C1 Regen) mit höchstens 8 Punktlichtern / 2 Spots / 18 Kegeln.
- **Schnittstellen**: `set_zone(kind, amount)` ist wie dokumentiert (`docs/renderer-modern.md` §15.1) und passt zu R5:
  `origin/wip/v080-r5` `builders/tunnel.gd` ruft `env.call("set_zone", "tunnel", amount)` duck-typed nur bei Änderung –
  der Wert hält bis zum nächsten Aufruf, also richtig. `add_lamps()` und seine Rollen sind unverändert (R6, R5 nutzen
  sie; Tunnellampen mit `range` 0 zählen nicht zum Pool – R4 hat das gemeldet). Probe-Zusammenführung mit
  `git merge-tree`: R4 + FIX-M2 nur Konflikte in `tests/golden/modern_slice.{md5,env}` (Code von `lights.gd`,
  `vehicles.gd`, `modern_materials.gd` mischt sich automatisch); R4 + R5 `docs/renderer-modern.md` und `modern_slice.md5`;
  R4 + R6 nur die Modern-Hashes.

## 3. Fairness (gemessen)

- `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (207 s): **F1** 0 Fälle bis 270 m in
  99.424.500 Stichproben (128 Etappenrichtungen), **F1 Außenspuren** 0 bis 260 m, **F2** höchstens 0,593 trocken /
  0,596 Regen / 0,555 Schnee (≤ 0,60), **F3** 0 von 5.923 Zielen später, **F7** 0 von 2.011.532 Querschnittsseiten,
  Modell 0 abweichend.
- `modern_path_check.gd -- --full` (87 s): kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000).
- **F4/F5/F6** (Render, gemessen): `check_vehicle_lights` 4/4 OK – Rücklicht bei 0,839 × Sicht an N1 (Schnee, 22 Uhr,
  Sichtweite 338 m, Auto bei 283 m) hebt das Bild um 0,090 Leuchtdichte / 0,239 Rot (Schwellen 0,02 / 0,10), Blinker bei
  300 m, Sichtgrenze 0,00 %. `check_night` „verdeckung“: Kuppe und Sattelzug verdecken Auto, Lichtpunkt **und**
  Spiegelung (0 Pixel). R4 berührt `tests/sim/modern_*` und den Kern nicht; Kamera und Gelände unverändert.
- Fairness-Risiko aus B1/B2 (abgeleitet): die schwebende Spiegelung zeigt ein Auto hinter einer Steigung nicht früher
  als Arcade (das Auto selbst ist sichtbar), aber sie ist ein falsches Signal über dem Horizont; der halbierte
  Markierungskontrast im Kegel (B2) betrifft etwas, worauf der Spieler reagiert (Regel 9 sinngemäß).

## 4. Arcade-Gleichheit und Dateibesitz

- `tools/golden.sh check` (einmal, am Ende): **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** (gemessen, 20:07–20:18, Kopf `7f0eae2`)
- `git diff 6e48405..7f0eae2 --stat`: 42 Dateien, +3.219 / −48. Kein eingefrorener Arcade-Pfad (`scripts/race/*`,
  `scripts/gameplay`, `scripts/data`, `data/**`, Sprites, Arcade-Audio). Alle Code-Dateien gehören R4 in W3
  (`environment_rig.gd`, `modern_renderer.gd`, `prewarm.gd`, `layers/{lights,backdrop,vehicles,flares}.gd`,
  `builders/terrain.gd`, `modern_materials.gd`, Shader road/vpbr/glass/baked/leaves/billboard) oder sind neue Dateien
  des Pakets (`layers/weather.gd`, `particles_rain/snow`, `spray`, Tests). `race_session.gd`, `race_renderers.gd`,
  `config/game_config.json` unverändert.
- Abweichungen: `assets/shaders/modern/flare.gdshader` hat in W3 keinen Besitzer (W1: R3) – R4 hat es als Vertragsfrage
  gemeldet, sinnvoll beim Besitzer von `flares.gd`. `tests/golden/modern_slice.{md5,env}` hat in W3 keinen Besitzer
  (§5: „–“); R4, R5, R6 und FIX-M2 haben sie alle neu erzeugt → bei RINT-M2 nach dem Zusammenführen einmal
  `golden.sh modern-make` statt Handmischen. Neue Testdateien (`tests/race3d/check_light_cap.gd`,
  `check_weather_tabelle*.gd`, `tests/unit/race3d/test_weather.gd`) liegen in Modern-Testordnern – zulässig.

## 5. Tests, Render-Prüfungen und Mutationen

**`tools/run_tests.sh`** (Vollauf 1 von 2 erlaubten, 1.319 s, gemessen): 762 Einheitstests, **2 rot**, alle CHECK-Dateien
grün (u. a. `check_light_cap`, `check_modern_stage` mit `kern_zeit` 0,389 ms, Sicht, Weg, `check_terrain_plan`):
- `test_engine3_checks` „thread“ (Audio, 15 Aussetzer bei 6 Hängern des Hauptthreads – Last; R4 berührt kein Audio).
- `test_chunk_services` „threaded“: `commit()` 23 statt 25 – ein Wettlauf im Kern-Test, nicht R4: einzeln wiederholt
  Kopf 1 von 2 und 0 von 6 rot, **Basis 1 von 6 rot** (gemessen).
- Die geschützten Tests des ersten Testbuilds sind grün: `test_far_ground_water` 4/4, `test_props` 12/12.

**Render-Prüfungen** (`tools/run_render_checks.sh modern <Datei>`, je Datei, gemeinsamer Mesa-Cache, gemessen):

| Datei | Ergebnis |
|---|---|
| `check_night.gd` | 4/4 OK (344 s): Fahrbahn N1 +4,9 % (Mittel und Steam Deck), Spielerauto 1,04/0,93/… Sättigung 0,95/0,73/0,91, Verdeckung 0 Pixel, Blaulicht 7.848 blauer |
| `check_weather.gd` | 5/5 OK (472 s): Teilchen 7.343/20.021/45.417 Bildpunkte Regen, Gischt 1 bzw. 3 Wolken, nass, Tunnel aus, Schneewall 0,35 m |
| `check_vehicle_lights.gd` | 4/4 OK (90 s), F6 an N1 |
| `check_start_km0.gd` | 3/3 OK (258 s) – Fix des ersten Testbuilds hält |
| `check_light_base.gd` | 2/2 OK (142 s) – Tageslicht −6,6 % Asphalt, Schatten ±0,09 % |
| `check_terrain_cover.gd` | 7/7 OK (78 s) inkl. **K1** 0,000 % Magenta |
| `check_occlusion.gd` | 2/2 OK (33 s): Kuppe 0 von 921.600 Pixeln, Lkw 0 Pixel |
| `check_weather_tabelle.gd` | OK (414 s): klar/Regen × 6:36/12/19:12/22 Uhr 0,90–1,01 × Helligkeit, Kontrast 0,74–1,17 × – **Regen 22 Uhr 0,97 × / 1,17 ×**: das Mittel über den ganzen Boden verdeckt B2 |
| `check_weather_tabelle_schnee.gd` | OK (213 s): 0,98–1,00 × / 0,96–0,99 × |

Die Zahlen von `check_night` und `check_weather` stimmen auf die Stelle mit R4s Bericht überein (bestimmte Bilder).

**Mutationen** (`m1/QA-R4/sh/mutate.py`: eine Zeile je Regel in einer Kopie des Kopfes gebrochen, der zuständige Test
gefahren, Datei zurückgesetzt; gemessen):

| Nr. | Regel | gebrochen | Ergebnis |
|---|---|---|---|
| U1 | jede Effekte-Stufe ≥ Arcades Dichte | `RAIN_BOX[0]` 24 × 70 m statt 14 × 45 m | **erkannt** (`test_weather`) |
| U2 | Aufwärm-Ebene ohne echte Lichter | `LIGHT_MASK` ohne `~(1 << 19)` | **erkannt** (`test_light_pool`, 2 Tests) |
| U3 | `set_zone("tunnel")` ersetzt `tunnel_blend` | Zweig `if _zones.has("tunnel")` tot | **erkannt** (`test_set_zone`) |
| U4 | Nachtgesetz Mond ≥ 55° | `MOON_MIN_ELEV_DEG` 15 | **erkannt** (`test_night_moon_and_floor`) |
| U5 | Nachglühen klingt über 60 m stetig ab | Abklingweg × 10 (Sprung von 0,39 auf 0 bei 60 m) | **nicht erkannt** (`test_exit_ramp` prüft nur „bei 60 m vorbei“ und „fällt“) |
| U6 | Blaulicht leuchtet nur nachts | Schwelle `lights <= 0.04` aus | **erkannt** (`test_beacon_of`) |
| U7 | Gischt auch bei „Effekte: Aus“ | eine Wolke → keine | **erkannt** (`test_spray_puffs`) |
| U8 | Schneewall ≤ 0,45 m | `BANK_MAX_M` 0,95 | nicht erkannt von den Einheitstests (keiner prüft die Höhe; nur die Render-Prüfung, s. R4) |
| R1 | N1-Fahrbahn nie dunkler als Arcade | `night_lift` 0 | **erkannt** (`check_night` fahrbahn −2,9 %) |
| R2 | Niederschlag im Tunnel aus | `_fade = 1.0` | **erkannt** (`check_weather` tunnel) |
| R3 | Schneewall-Netz ≤ 0,45 m | Profil-Scheitel 1,0 → 2,6 (Wall 0,78 m hoch im Netz) | **nicht erkannt** – „schneewall“ misst `bank_height()`, nicht die Ecken des Netzes |
| R4 | Schneewall-Höhe | `BANK_H_M` 0,8 und `BANK_MAX_M` 0,95 | **erkannt** (0,927 m) |
| (B1/B2) | Spiegelung in der Fahrbahn, Kegel auf nasser Fahrbahn | – (kein Bruch nötig: die Fehler sind im Kopf und alle Prüfungen grün) | **nicht bewacht** |

Fazit: die Einheits- und Render-Prüfungen bewachen die meisten Regeln wirklich (9 von 12 Brüchen rot); Lücken sind
das Netz des Schneewalls, die Stetigkeit des Nachglühens und – wichtiger – die beiden Bildfehler B1/B2 (B4).

## 6. Leistung

Gemessen auf llvmpipe unter Xvfb (Last 13–18), „Steam Deck“-Voreinstellung 1280×800, kalter Shader-Cache,
`tests/race3d/render/warmup_cold.gd` (30 s echte Fahrt mit Autopilot und Verkehr), Kopf und Basis nacheinander:

| Stelle | Stand | Varianten vor Start / in Fahrt | Vorbereitung | `render()` Mittel | Einhängen max | Zeichenaufrufe | Dreiecke | Bildzeit Median / max |
|---|---|---|---|---|---|---|---|---|
| N1 22 Uhr Schnee | Basis | 354 / **3** (FEHLER) | 54,7 s | 1,965 ms | 1,14 ms | 64 | 85.717 | 980 / 1.642 ms |
| N1 22 Uhr Schnee | Kopf | 443 / 0 | 64,1 s | 2,149 ms | 1,27 ms | 72 | 99.499 | 797 / 1.480 ms |
| N2 22 Uhr Regen | Basis | 360 / 0 | 59,3 s | 2,027 ms | 1,04 ms | 79 | 91.974 | 1.275 / 1.875 ms |
| N2 22 Uhr Regen | Kopf | 459 / 0 | 71,7 s | 1,928 ms | 1,01 ms | 82 | 91.789 | 1.201 / 1.546 ms |

Gelesen: R4 kostet im Skript nichts Messbares (±0,2 ms, Rauschen; `kern_zeit` im Vollauf 0,389 ms), keine Spitze beim
Einhängen (≤ 1,27 ms, Deck-Budget 3 ms), +3 bis +8 Zeichenaufrufe (Niederschlag, Gischt, zwei Spiegelungsebenen) und an
N1 +16 % Dreiecke (Schneewälle, Teilchen) – weit unter dem Deck-Budget (650 Aufrufe, 450.000 Dreiecke). Die Vorbereitung
mit kaltem Cache dauert hier 9–12 s länger (89–99 Shader-Varianten mehr, u. a. Teilchen, Gischt, Streifen,
Blendviereck, Schnee-Varianten) – auf echter Hardware abgeleitet wenige Sekunden beim allerersten Start. Bildzeiten auf
llvmpipe sagen über das Deck nichts (R4 maß in „Stadt bei Nacht im Regen“ +29 % Bildzeit durch die Füllrate der
Regenstriche in Software); ob 1.500 Teilchen auf dem Deck frei sind, zeigt nur der Leistungstest des Nutzers (abgeleitet:
ja, eine kleine Menge). Einen ganzen Etappenlauf habe ich nicht wiederholt (R4: 95 km ohne Fehler, gleiches Ergebnis wie
die Basis).

## 7. Vertragsfragen

1. §6 R4 nennt `GPUParticles3D`; mit Regel 10 (bestimmte Bilder, `--shot-fast`) und dem schwimmenden Ursprung ist
   R4s zustandsloses MultiMesh im Kamera-Raum die bessere Lösung – ich stimme R4s Vorschlag zu, §6 so zu ändern.
2. §4.10 „Effekte“: `spray` false bei „Aus“ und `wet_reflections` nur bei „Voll“ widersprechen „keine Stufe zeigt weniger
   als Arcade“ – R4 zeigt beides auf jeder Stufe; die Tabelle sollte das nachziehen.
3. §6 R4 Abnahme prüft die Nacht-Fahrbahn nur an N1 (trocken, Schnee). Die nasse Nacht – wo B2 sitzt – hat keine
   Abnahme; Vorschlag: „N2 22 Uhr Regen: Fahrbahn im Abblendlicht höchstens +15 % gegen Arcade, Markierungskontrast
   ≥ 0,8 ×“ und „keine Spiegelung über der Lampenzeile ihres Fahrzeugs“.
4. §5 W3: `flare.gdshader` hat keinen Besitzer, `tests/golden/modern_*` ebenfalls nicht, obwohl jedes Renderer-Paket
   die Modern-Bilder ändert – Vorschlag: Shader beim Besitzer von `flares.gd`; Modern-Hashes erzeugt nur die
   Zusammenführung (RINT), Pakete prüfen mit `modern-check` lokal.

## 8. Für die nächsten Pakete

1. **R4-Nacharbeit (vor Testbuild 2)**: B1 (Streifen in die Fahrbahnebene, `vehicles.gd` + `flare.gdshader`
   `CE_STREAK`, auch Laternen) und B2 (Lichter nur auf den diffusen Anteil, Probe-Patch
   `deliver/QA-R4/b2_behebung_probe_road_gdshader.py`), je mit einer neuen Prüfung (B4).
2. **RINT-M2**: `tests/golden/modern_slice.{md5,env}` nicht von Hand mischen – nach dem Zusammenführen
   `golden.sh modern-make` (Bilder ansehen); `docs/renderer-modern.md` R4- und R5-Abschnitt hintereinander.
3. **FIX-M2 B-06 / R7**: GT nachts im Regen grau (B3), Limousine nachts zu satt (B7) und in der Dämmerung blass/lila;
   `check_night` „spielerauto“ mit Obergrenze der Sättigung und dem DEV-Fall.
4. **R4/R7**: `quality_lowered()` in `weather.gd` (und `lights.gd` für den Punktlicht-Pool), B5.
5. **R4**: Nachglühen zeitlich begrenzen oder weglassen (B6); `render_priority` des Blendvierecks (B8).
6. **Kern-Testbesitzer**: `test_chunk_services` „threaded“ ist ein Wettlauf (Basis 1 von 6 rot) – A-11 verlangt
   lastfeste Prüfungen.
7. **PERF**: Vorbereitung mit kaltem Cache +9–12 s auf llvmpipe durch ~95 neue Varianten – beim ersten Start auf dem Deck
   beobachten (Leistungstest).
