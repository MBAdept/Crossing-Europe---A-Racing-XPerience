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

@@B3PLUS@@
