# R7b – Wahrzeichen, Skyline und Hintergrund (Welle 5, Schub M2)

Zweig `wip/v080-r7b` (Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2`,
lokaler Zweig `worktree-wf_ba4424b4-294-2`), Basis `9b02f05` (RINT-M2). Endstand: siehe §10.
„gemessen“ = auf dieser VM (llvmpipe unter Xvfb, vier geteilte Kerne, Last 12–14); „gefolgert“ = nicht messbar hier.

## 1. Kurz

- Neuer Builder `scripts/race3d/builders/landmarks.gd` und Shader `assets/shaders/modern/landmark.gdshader`: jedes
  Wahrzeichen, das Arcade zeigt, steht an Arcades Stelle auf dem Pfad, sobald es in Arcades Wahrzeichenreichweite
  kommt (bis `render.landmark_far_m` = 1.900 m; nachts bis dahin mit seiner Beleuchtung), mit Arcades Dunst- und
  Ausblendgesetz (`RoadRenderer.landmark_fade`) – **weich** ausgeblendet: ab 0,70 L zeichnet die durchscheinende
  Variante statt des geordneten Rasters (B-09).
- Darstellung (Entscheidung 3, Schnittstelle für AS6): Modell aus dem Manifest → sonst Arcades Bild → sonst Arcades
  prozedurale Art **als 3D-Form** (Kuppelkirche, Fernsehturm, Leuchtturm mit Strahlen, Hochhausgruppe; N2) → sonst
  Ersatz-Set. Nachts: Anstrahlung, warme Fenster, rote Flugwarnlichter, Leuchtfeuer.
- Hintergrund `layers/backdrop.gd`: Skyline der Zielstadt wie Arcade (Sprite-Silhouetten und Arcades prozedurale
  2D-Zeichnungen über eine nie eingehängte `RoadRenderer`-Instanz), ausgeblendet, solange das 3D-Wahrzeichen in
  Reichweite ist.
- `builders/props.gd` blieb unverändert: die Ente-Typ-Weiche `_skip_landmarks` stand schon im Code (Zeilen 88, 122,
  329, 539, 741).
- Gates auf dem Endstand `2c154bc` (§6): Import, Skripte (334/0), `run_tests.sh` (ein voller Lauf, bestanden),
  Golden Arcade 20/20 und 17/17, Render-Prüfungen 29/29, Sicht und Pfad `--full` OK, ganze Etappen Modern ohne
  Skriptfehler. Golden Modern 5/6: `modern_s4_mittel` weicht gewollt um höchstens 2/255 ab (der Michel kommt jetzt
  aus `landmarks.gd`) – nach A-18 nicht neu erzeugt.
- Leistung (§7, gemessen auf llvmpipe): render() im Mittel wie die Basis; der Builder kostet 0,05 ms je Bild
  (höchstens 1,2 ms), `props.gd` wird 0,04 ms billiger.
- Bild (§5): Stelle wie Arcade; die 3D-Formen sind bei Tag besser als Arcades flache Zeichnungen (Belgrad, Dortmund,
  Madrid). Schwächer: rotes Flugwarnlicht nachts etwa dreimal so groß wie Arcades Punkt; Kuppelformen stehen aus
  260 m in Kurven bis etwa 85 px neben Arcades Zeichnung (gerade Anfahrt bei 600 m: 0,0 / 24,7 px).

## 2. Was gebaut wurde

| Datei | Was |
|---|---|
| `scripts/race3d/builders/landmarks.gd` (neu) | Plan je Wahrzeichen (`resolve_item`: Modell / Bild / Form / Ersatz, Anker wie Arcade), Knoten unter `renderer.world` von der Reichweite bis 320 m nach dem Vorbeifahren, Arcades Gesetz je Bild (`fade`, `reach`, `landmark_range`), Wechsel deckend ↔ durchscheinend ab 0,70 L (`graphics.modern.landmark_blend_from`, Vorgabe 0,70, kein Eintrag in der Konfiguration nötig), Formen (`proc_mesh`, `ShapeKit`), Aufwärmen auf den echten Netzen, `snapshot()` / `perf()`, `rebased()` |
| `assets/shaders/modern/landmark.gdshader` (neu) | Varianten CE_PICTURE (Arcades Bild), CE_ATLAS (+ CE_CUTOUT; Modelle `baked`), CE_VCOL (Formen und `vpbr`-Flächen: Kanäle 10/11 Flugwarnlicht, 12 Fenster, 13, 14 Anstrahlung, 16 Glasfassade), CE_GLOW (Leuchtpunkte, Leuchtturmstrahlen), je mit CE_BLEND; keine Instanz-Uniform (A-19) |
| `scripts/race3d/layers/backdrop.gd` (Ausnahme der Leitung) | Skyline wie Arcade (§18.5 der Renderer-Doku) |
| `tests/unit/race3d/test_landmarks.gd` (neu) | 8 Tests: Gesetz = `RoadRenderer.landmark_fade` (20 Abstände × 3 Sichtweiten), Reichweite, jede Stadt-Landmarke dargestellt, Anker wie Arcade, Formen (Höhe, schlank, Windung, Leuchtpunkte), keine Instanz-Uniform, Varianten, Tönung (N1) |
| `tests/race3d/check_landmarks.gd` (neu) | Rennszene headless: reichweite, nacht, position, prozedural, weich, skyline |
| `tests/race3d/render/check_landmarks_render.gd` (neu) | Xvfb: wahrzeichen_stelle, wahrzeichen_weich, wahrzeichen_nacht, flugfeuer |
| `tests/race3d/check_minimal_structures.gd` | 4 Zeilen: „wahrzeichen“ verweist auf die Prüfungen oben, sobald es den Builder gibt (Abweichung, §8) |
| `docs/renderer-modern.md` | neuer Abschnitt §18 „Wahrzeichen und Skyline“ |

Nicht geändert: `builders/props.gd`, `billboard.gdshader`, `baked.gdshader`, `config/game_config.json`, eingefrorene Dateien.

### Darstellung je Wahrzeichen der Städte (gemessen, `test_every_city_landmark_has_a_representation`)

- Modell: `landmarks/michel` (Hamburg) und die gewöhnlichen Requisiten-Modelle, die Städte als Wahrzeichen setzen
  (`props/church`, `props/building_tall`, …; nachts angestrahlt wie in Arcade, `LANDMARK_FLOOD`).
- Arcades Bild: alle 32 Wahrzeichen mit Sprite (Elbphilharmonie, Eiffelturm, Atomium, Kaiserburg, …).
- 3D-Form: Neues Rathaus Hannover und Völkerschlachtdenkmal Leipzig (Kuppelkirche, ohne Kreuz), Florianturm Dortmund
  (Fernsehturm), Cuatro Torres Madrid (Hochhausgruppe), Kirche des Heiligen Sava Belgrad (Kuppelkirche), Leuchtturm
  Calais. Vorher standen dort ein breites Bürohaus- bzw. Kirchen-Ersatzbild (N2, „Belgrad schlechter“ in M2ZS1).
- Skyline-Einträge ohne Sprite (Herkules Kassel, Sacré-Cœur Paris, Colonius Köln, Fernsehturm Riga) zeichnet der
  Hintergrund mit Arcades eigener 2D-Zeichnung.

## 3. Entscheidungen der Leitung

1. **Stelle, Reichweite, Gesetz, weich** – umgesetzt (§2). Gemessen: Reichweite und Gesetz gleich Arcades Formeln
   (Einheitstest, Abweichung < 10⁻⁵); auf den drei geraden 640-m-Anfahrten des Netzes steht der Anker 600 m voraus
   0,0 px (Bild, Burgos) bzw. 24,7 px (Kirchenmodell, beide Richtungen um Slavonski Brod) neben Arcades Stelle, Grenze
   64 px; im Bild selbst (Render-Prüfung, Hamburg km 85,6, in einer Kurve mit Blick in die Kurve) findet sich das
   Pixelmuster der Wahrzeichen in Arcades Bild desselben Zustands mit 18 px Versatz. Weich: ab 0,70 L durchscheinend
   (`check_landmarks` „weich“), im Bild kein Rastermuster (Nachbarwechsel 0,23 der Änderung, ein geordnetes Raster
   läge bei ≈ 1). Deckend und durchscheinend bei voller Deckung pixelgleich (0 von 921.600 Pixeln, Sonde).
2. **Skyline und Silhouetten wie Arcade; unter der Horizontzeile fernes Land** – Skyline umgesetzt und an Kassel
   (Herkules, Azimut −24°) und Paris (Sacré-Cœur −30°, Eiffelturm in Reichweite schwach) im Bild nur des Hintergrunds
   gesehen (`bilder/skyline_*`). Unter der Horizontzeile ändert R7b nichts: die Skyline zeichnet über der Grundlinie,
   die Nebelfläche darunter deckt der Fernboden wie bisher. An S1–S5 und den zehn Einfahrten: kein heller Streifen,
   kein Wandmuster (§5).
3. **Eine Schnittstelle für AS6** – Modell aus dem Manifest vor dem Bild, dokumentiert in §18.2 von
   `docs/renderer-modern.md` (nicht §15/§16: die gehören R4/R5, Abweichung §8).
4. **Instanzbudget** – keine Instanz-Uniform: je Wahrzeichen eigene Materialien (Test liest Shader und Builder).

## 4. Abnahme

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Vertrag R7: Wahrzeichen auf dem Pfad bis 1.900 m mit Arcades Dunstgesetz und Nacht-Anstrahlung | erfüllt (gemessen) | `test_landmarks`: `fade()` = `RoadRenderer.landmark_fade` an 20 Abständen × 3 Sichtweiten (Abweichung < 10⁻⁵); `check_landmarks` „reichweite“ (props.gd zeichnet kein Wahrzeichen mehr, alle im Builder), „nacht“ (1.900 m, zwei beleuchtet) |
| Vertrag R7: A/B-Bögen von zehn Stadteinfahrten | erfüllt | `boegen/<stadt>.jpg` (12:00, 19:30, 22:00), dazu Nahbilder `boegen/nah_prozedural.jpg` |
| Vertrag R7: Wahrzeichen dort, wo Arcade es zeigt (≤ 5 % der Bildbreite bei 600 m, gerade Anfahrt) | erfüllt (gemessen) | `check_landmarks` „position“: 0,0 px (Burgos, Bild) und 24,7 px (Kirche bei Slavonski Brod, beide Richtungen) bei 600 m, Grenze 64 px; Render-Prüfung „wahrzeichen_stelle“ (Hamburg, Kurve): 18 px |
| Vertrag R7: Skyline und Silhouetten im Hintergrund wie Arcade | erfüllt | `check_landmarks` „skyline“ (Paris km 376: Sacré-Cœur −30° voll, Eiffelturm 0,21 – in Reichweite ausgeblendet; vor den City Limits keine); Bilder `bilder/skyline_*` |
| Vertrag R7: LOD-Wechsel in den Clips bei „Mittel“ unsichtbar | für R7b erfüllt (gemessen), Clips bei „Hoch“ | Der einzige Wechsel von R7b (deckend → durchscheinend bei 0,70 L) ist bei voller Deckung pixelgleich (0 von 921.600 Pixeln); Clips Hamburg/Paris ohne Springen. Die Fern-LOD der Bauten und Pflanzen ist R7c. |
| Leitung 1: Stelle, Reichweite, Gesetz, Flutlicht, weich (kein Raster) | erfüllt | s. o.; „wahrzeichen_weich“ (Nachbarwechsel 0,23, Raster ≈ 1), „weich“ (durchscheinend ab 0,70 L) |
| Leitung 2: Skyline wie Arcade; unter der Horizontzeile fernes Land (A-10) | erfüllt (Bild) | S1–S5 und zehn Einfahrten: kein heller Streifen, kein Wandmuster (§5) |
| Leitung 3: eine Schnittstelle für AS6, dokumentiert | erfüllt, Ort abweichend | §18.2 von `docs/renderer-modern.md` (nicht §15/§16, s. §8) |
| Leitung 4: keine Instanz-Uniform (A-19) | erfüllt (gemessen) | `test_landmarks` „keine Instanz-Uniform“ (Shader und Builder gelesen); je Wahrzeichen eigene Materialien |
| Offen N1: Tönung | erfüllt | `test_landmarks` „Tönung“: `tint` × `fallback_tint` steht im Material des Bildes und der Modellklassen `baked`/`baked_cutout`/`vpbr`, in der deckenden (nah) und der durchscheinenden (fern) Variante |
| Offen N2: Form je prozeduraler Art | erfüllt | vier 3D-Formen (`proc_mesh`), Test „Formen“ (Höhe, schlank, Windung, Leuchtpunkte) |
| Offen B-09: weiches Ausblenden | erfüllt | durchscheinende Variante statt Dither |
| Offen: Elbphilharmonie nachts | erfüllt, etwas heller als Arcade | `ab/hamburg_22_ab_00.jpg` |
| A-18: `collect()` jedes Builders ≤ 2 ms (Deck) | erfüllt (gemessen bei „Mittel“, Deck gefolgert) | `landmarks`: `collect` 0,001 ms, Hauptthread (`update`) Ø 0,054–0,056 ms, höchstens 1,2 ms (§7) |
| A-19: Instanzbudget ≤ 230 | erfüllt (gemessen) | `check_instance_budget*`: 141 / 172 / 216 |
| Korrekturen des ersten Testbuilds halten | erfüllt (gemessen) | `check_start_km0`, `check_terrain_cover` (K1), `check_light_base` OK; `test_far_ground_water` 3/3, `test_props` 13/13 |
| Gate Import | erfüllt | Exit 0, 0 Fehler |
| Gate `tests/check_scripts.gd` | erfüllt | 334 Skripte, 0 fehlerhaft |
| Gate `tools/run_tests.sh` | erfüllt (ein voller Lauf) | „Tests bestanden (995 s)“ |
| Gate `tools/golden.sh check` | erfüllt | 20 von 20 und 17 von 17 identisch |
| Gate `tools/golden.sh modern-check` | teilweise: 5 von 6 | `modern_s4_mittel` max. 2/255 an 369 Pixeln (Michel, gewollt), nach A-18 nicht neu erzeugt; OpenGL ES OK |
| Gate `tools/run_render_checks.sh all` | erfüllt | 29 OK, 0 failed |
| Gate `modern_sight.gd --full`, `modern_path_check.gd --full` | erfüllt | alle CHECK OK |
| Gate ganze Etappe Modern unter Xvfb ohne Skriptfehler, Leistung neben der Basis | erfüllt (gemessen) | Kiel–Hamburg, Dresden–Leipzig: ok, 0 Skriptfehler; Tabelle §7 |


## 5. Bilder und Urteil (LOOK, ehrlich gegen Arcade)

Alle Bilder „Details: Hoch“, 1280 × 720, llvmpipe unter Xvfb, `--seed=11`, Autopilot; links Arcade, rechts Modern.

**Bögen der zehn Stadteinfahrten** (`boegen/<stadt>.jpg`: 12:00, 19:30, 22:00 übereinander; je Bild
`ab/<stadt>_<zeit>_ab_00.jpg`). Startpunkt jeweils so, dass das erste Wahrzeichen der Stadt etwa 600 m voraus liegt.

| Stadt | Wahrzeichen (Darstellung) | Urteil |
|---|---|---|
| Hamburg | Elbphilharmonie (Bild), Michel (Modell) | Beide an Arcades Stelle (Render-Prüfung: 18 px Versatz). Tag gleich, Dämmerung gleich. **Elbphilharmonie nachts** (offener Punkt): Lichtebene des Sprites wie Arcade, das blau-weiße Fenstermuster und der warm beleuchtete Sockel stehen an derselben Stelle; in Modern etwas heller als in Arcade (das Bild wird wie die Vertretungen mit dem Licht einer mittelgrauen Fläche gerechnet). Clip: der Michel steht 20 s lang an Arcades Stelle, kein Springen, kein Raster. |
| Hannover | Neues Rathaus (3D-Kuppelkirche ohne Kreuz) | Bei 600 m in beiden Modi hinter Häusern; Nahbild siehe unten. |
| Leipzig | Völkerschlachtdenkmal (3D-Kuppelkirche ohne Kreuz) | wie Hannover: bei 600 m verdeckt; Nahbild (in der Kurve etwa 65 px neben Arcades Stelle, s. u.). Arcade zeichnet es selbst als Kuppelkirche – Modern folgt (kein eigenes Denkmal, das wäre AS6). |
| Dortmund | Florianturm (3D-Fernsehturm) | **Besser als Arcade bei Tag** (schlanker Turm mit Korb statt flacher Zeichnung, gleiche Stelle, gleiche Höhe). Nachts (Bild mit dem Endstand neu gerechnet): Fensterring warm, Schaft heller als in Arcade, rotes Flugwarnlicht an derselben Stelle – nach der Korrektur (erste Fassung: Leuchtpunkt füllte den Himmel, Prüfung „flugfeuer“) und einer Abschwächung **noch etwa dreimal so groß wie Arcades Punkt** (Schwäche). |
| Nürnberg | Kaiserburg (Bild) | Bei 600 m in beiden Modi hinter Fachwerkhäusern; Nahbild. Tag und Nacht ohne Unterschied am Horizont. |
| Paris | Eiffelturm (Bild), Sacré-Cœur (Skyline −30°) | Bei 600 m hinter Häusern; Clip und Nahbild. Die dunklen „X“ an einer Modern-Fassade rechts sind Geländer der Stadtgebäude (Probe mit und ohne Wahrzeichen-Knoten: 0 Pixel Unterschied) – kein R7b-Befund, Hinweis für AS5a/R7c. |
| Brüssel | Atomium (Bild), Basilika Koekelberg (Bild) | Beide an Arcades Stelle. In Modern sichtbar, in Arcade verdeckt: Arcades Häuserzeile davor (km 206,4, etwa x 550–760) fehlt in Modern – **ebenso auf der Basis** `9b02f05` (gemessen: `m1/R7b/basecmp/bruessel_12_base_ab_00.jpg`, Atomium und Koekelberg dort von `props.gd` an denselben Stellen), also kein R7b-Befund; Hinweis für die Stadtbauten (§9, Punkt 4). |
| Belgrad | Kirche des Heiligen Sava (3D-Kuppelkirche) | **Deutlich besser als vorher** (M2ZS1: „Belgrad schlechter“ – breites Ersatzbild): eine Kirche mit grünen Kuppeln an Arcades Stelle. Nachts angestrahlt wie Arcade (nach der Korrektur f0b30c7; vorher lag der Dunst über der Anstrahlung). Bei km 196,0 / 22 Uhr liegt sie in beiden Modi außerhalb des Bildes. Nahbild: etwa 85 px rechts von Arcades Stelle (Kurve, s. u.). |
| Calais | Leuchtturm (3D) | Bei 600 m verdeckt; Nahbild. Nachts: Feuer blitzt, vier Lichtstrahlen kreisen wie in Arcade. |
| Madrid | Cuatro Torres (3D-Hochhausgruppe) | **Besser als Arcade bei Tag** (fünf Glastürme mit Geschossbändern statt flacher Zeichnung). Nachts (mit dem Endstand neu gerechnet): Bürofenster auf grobem Raster wie Arcades Fenster, in der Ferne gemittelt (vorher flimmernd), rotes Flugwarnlicht oben. |

**Nahbilder** (`ab_nah/<stadt>_nah_<zeit>_ab_00.jpg`, Bogen `boegen/nah_prozedural.jpg`; etwa 250 m vor dem
Wahrzeichen, 12:00 und 22:00 – die sechs 3D-Formen und zwei Bilder):
- **Hannover** (Neues Rathaus, Kuppelform): an Arcades Stelle, Größe und Umriss wie Arcades Zeichnung (Kuppel mit
  Seitenkuppeln, Säulenfront); nachts angestrahlt mit warmem Schein um die Kuppel wie Arcade. Gleichwertig, in 3D
  plastischer.
- **Calais** (Leuchtturm): an Arcades Stelle, gleiche Höhe; nachts Laterne hell. Arcades Lichtstrahlen sind in diesem
  Bild als helle Streifen zu sehen, die kreisenden 3D-Strahlen stehen in diesem Augenblick quer zur Kamera und sind
  kaum zu sehen.
- **Nürnberg** (Kaiserburg, Bild) und **Paris** (Eiffelturm, Bild): pixelnah an Arcades Stelle, Tag und Nacht gleich
  (Burg warm angestrahlt, Turm golden).
- **Madrid** (Hochhausgruppe): 250 m sind zu nah – nur die Fußteile oben am Bildrand, in beiden Modi an derselben
  Stelle; nachts Bürofenster wie Arcade. Das Einfahrtsbild (600 m) zeigt die Türme ganz.
- **Dortmund** (Fernsehturm): bei km 228,5 in beiden Modi nicht im Bild (hinter Häusern) – das Einfahrtsbild zeigt ihn.
- **Leipzig** und **Belgrad** (Kuppelform) – **in Kurven sichtbar neben Arcades Stelle**: gemessen mit einer Sonde
  (`bilder/nah_kurve_leipzig_belgrad_sonde.jpg`: Arcade | Modern, darunter Modern nur mit den Wahrzeichen-Knoten):
  Leipzig bei 258 m etwa 65 px links von Arcades Zeichnung und die Kuppel etwa 35 px tiefer (die Kuppel steht
  25 m hinter der Front, Arcade zeichnet flach am Anker); Belgrad (Ada-Brücke, Kurve) bei 268 m etwa 85 px rechts und
  breiter, weil die Form mit der Straße gedreht ist und ihre Seitenwand zeigt. Ursache (gefolgert): echte Perspektive
  – 140–155 m Seitenabstand in einer Kurve verschieben die Tiefe, Arcade verschiebt nur seitlich. Auf gerader Anfahrt
  bei 600 m (Abnahme) 0,0 / 24,7 px; diese Nahbilder liegen außerhalb der Abnahme, aber über 5 %. Vorschlag in §9.

**Clips** (`clips/anfahrt_hamburg.mp4`, `clips/anfahrt_paris.mp4`, je 20 s, 960 × 540 je Seite):
- Hamburg (km 89,0 → 93,5): Michel und die Skyline stehen an Arcades Stelle; kein Springen, kein Raster beim
  Ein- und Ausblenden. Modern zeigt den Michel früher, wo Arcades Ladenbau höher gezeichnet ist.
- Paris (km 391,5 → Ziel): der Eiffelturm (Bild) steht bei km 393,1 (160 m voraus, nur die Beine im Bild) in beiden
  Modi an derselben Stelle am rechten Bildrand; davor in beiden hinter Bäumen, danach in beiden aus dem Bild. Die
  Skyline-Silhouetten am Ziel gleich. Kein Springen, kein Raster.

**Skyline und Horizont** (`ab/skyline_S1..S5_ab_00.jpg`, Kiel–Hamburg; `bilder/skyline_*`):
- S1–S5: unter der Horizontzeile liest der Fernboden als fernes Land (Grün bis zum Dunst), kein heller Streifen, kein
  Wandmuster – gleich wie Arcade. Am Ziel Hamburg (S5) stehen die grauen Stadt-Silhouetten in beiden Modi.
- Kassel (`bilder/skyline_kassel_nur_hintergrund.jpg`, nur der Hintergrund, 3D-Welt ausgeblendet): der Herkules als
  Arcades 2D-Zeichnung bei −24° (Azimut aus `cities.json`); nachts mit Licht (`…_22uhr_…`).
- Paris (`bilder/skyline_paris_nur_hintergrund.jpg`): Sacré-Cœur bei −30°, der Eiffelturm ausgeblendet, solange er
  auf der Straße in Reichweite steht (nie doppelt).

**Zoom-Bilder** (`bilder/*_tag_zoom_arcade_modern.png`): Belgrad, Dortmund, Madrid bei Tag, Ausschnitt um das
Wahrzeichen, Arcade oben, Modern unten. `bilder/kuppelkirche_durchscheinend_volle_deckung.png`: deckende und
durchscheinende Variante bei voller Deckung (pixelgleich).

**Gesamturteil**: Stelle und Gesetz wie Arcade; die vier prozeduralen Arten sind als 3D-Formen bei Tag besser als
Arcades flache Zeichnungen und als das alte Ersatzbild; die Bilder (32 Wahrzeichen mit Sprite) sehen aus wie in
Arcade, nur als flache Karte – erst AS6 bringt Modelle. Schwächer als Arcade: das rote Flugwarnlicht ist nachts etwa
dreimal so groß; die Elbphilharmonie nachts etwas heller; die Kuppelformen stehen aus der Nähe in Kurven bis etwa
85 px neben Arcades flacher Zeichnung. Fehlt: Modelle der Wahrzeichen (AS6). Die Stadteinfahrten zeigen das
Wahrzeichen bei 600 m oft gar nicht (verdeckt in beiden Modi) – darum die Nahbilder.

## 6. Gates auf dem Endstand `2c154bc`

Alle Läufe nacheinander mit `nice -n 10`, `XDG_DATA_HOME` = eigener Ordner unter dem Notizbuch, Speicherwächter
(< 3 GB frei → warten). Ausgaben vollständig in `m1/R7b/gates/` (Skript `m1/R7b/sh/gates.sh`).

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, 0 Fehler (6 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „334 Skripte geprüft, 0 fehlerhaft“ |
| Tests | `tools/run_tests.sh` (einmal, voll) | „==> Tests bestanden (995 s)“ – 811 Einheitstests ok (davon 8 in `test_landmarks.gd`), alle `tests/race3d/check_*.gd` OK, darunter `check_landmarks` 6/6 und `check_minimal_structures` „wahrzeichen“ (verweist auf den Builder); gehalten: `test_far_ground_water` (3), `test_props` (13) |
| Golden Arcade | `tools/golden.sh check` | „GOLDEN arcade: 20 von 20 identisch“, „GOLDEN arcade-ui: 17 von 17 identisch“ |
| Golden Modern | `tools/golden.sh modern-check` | „GOLDEN modern: 5 von 6 identisch“; `modern_s4_mittel` ANDERS; OpenGL ES gegen OpenGL OK (max. 2/255, 73,2 dB). Angesehen (s. u.); **nicht neu erzeugt** |
| Render-Prüfungen | `tools/run_render_checks.sh all` | „29 OK, 0 failed“ (5.147 s); `check_landmarks_render`: wahrzeichen_stelle (18 px), wahrzeichen_weich (0,23), wahrzeichen_nacht (659 helle Pixel), flugfeuer (242 rote Pixel, 0,40 % des Bildes); gehalten: `check_start_km0`, `check_terrain_cover` (mit K1), `check_light_base`; Instanzbudget: ganze Szene höchstens 141 / 172 / 216 mit Instanz-Uniforms (Grenze 230) |
| Sicht | `godot --headless -s res://tests/sim/modern_sight.gd -- --full` | Exit 0: f1 0 Fälle bis 270 m (99.424.500 Stichproben, 128 Richtungen), f1_lanes 0 bis 260 m, f2 ≤ 0,596, f3 0 von 5.923, f7 0 von 2.011.532, model 0 abweichend |
| Pfad | `godot --headless -s res://tests/sim/modern_path_check.gd -- --full` | Exit 0: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) |
| Ganze Etappe Modern | `xvfb-run … godot … -s res://tests/race/run_stage.gd -- --stage=… --seed=7 --timescale=40 --graphics=modern --gfx-preset=medium` | Kiel–Hamburg und Dresden–Leipzig mit dem Autopiloten: `ok: true`, 0 Skriptfehler, je auf Kopf und Basis (§7) |

**`modern_s4_mittel` (Kiel–Hamburg km 80, Mittel)**: auf Kopf und Basis mit `KEEP=` neu gerechnet
(`m1/R7b/golden_s4_head/`, `…_base/`; die Basis trifft ihren Hash). Unterschied: 369 Pixel, höchstens **2/255**, alle
im Feld x 430–533, y 253–310 – das ist der Michel 1,26 km voraus (Turmspitze), den jetzt `landmarks.gd` mit
`landmark.gdshader` statt `props.gd` mit `baked.gdshader` zeichnet. Mit dem Auge nicht zu sehen; gewollt. Nach A-18
gehört `tests/golden/modern_slice.*` der Integration und QA („packages do not regenerate it“) – darum kein
`modern-make` (Vertragsfrage §8: die Aufgabe nennt `modern-make` für gewollte Änderungen).

## 7. Leistung: ganze Etappe Modern, Kopf gegen Basis

`tests/race/run_stage.gd`, Zeitraffer 40, Seed 7, „Mittel“, 1280 × 720, llvmpipe unter Xvfb, vier geteilte Kerne mit
Last anderer Pakete – **gemessen**; echte Hardware **gefolgert**. Basis = `9b02f05` (RINT-M2, Kopie mit eigenem
`.godot`). render() / Stück / collect aus `perf_stats()` am Etappenende; Draw Calls und Primitive des letzten Bildes.

| Etappe | Stand | ok | Skriptfehler | render() Ø / max ms | Stück-Commit max ms | collect Ø / max ms | Draw Calls | Primitive | Textur MB | `landmarks` Ø / max ms | `backdrop` Ø / max ms | `props` Ø / max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Kiel–Hamburg | Basis | ja | 0 | 4,76 / 77,1 | 5,6 | 1,89 / 3,4 | 156 | 181.985 | 95,1 | – | 0,152 / 1,9 | 0,109 / 1,2 |
| Kiel–Hamburg | Kopf | ja | 0 | 4,38 / 61,6 | 2,3 | 1,67 / 2,8 | 156 | 181.985 | 97,6 | 0,054 / 0,6 | 0,174 / 2,9 | 0,069 / 1,2 |
| Dresden–Leipzig | Basis | ja | 0 | 5,29 / 60,0 | 3,4 | 1,89 / 6,6 | 184 | 223.856 | 87,4 | – | 0,158 / 4,8 | 0,107 / 1,2 |
| Dresden–Leipzig | Kopf | ja | 0 | 5,70 / 97,7 | 2,7 | 2,03 / 6,0 | 188 | 223.856 | 87,4 | 0,056 / 1,2 | 0,171 / 2,8 | 0,069 / 1,2 |

Lesart: render() im Mittel gleich (± 9 %, so weit streut llvmpipe unter fremder Last; die Maxima sind einzelne Bilder
mit Fremdlast). Der Builder `landmarks` kostet im Hauptthread 0,05 ms je Bild, höchstens 1,2 ms – unter der Grenze
von 2 ms (A-18; gemessen bei „Mittel“, für „Deck“ gefolgert: der Builder hängt nicht von der Stufe ab); sein
`collect()` ist leer (0,001 ms). `props` wird um 0,04 ms je Bild billiger (gefolgert: die fernen Vertretungen laufen nicht mehr).
`backdrop` +0,02 ms (Skyline). Draw Calls +4 am Ziel Leipzig (gefolgert: die Kuppelform des Völkerschlachtdenkmals mit
Flächen und Leuchtpunkten, deckend und im Schatten), Textur +2,5 MB am Ziel Hamburg (Ursache nicht gemessen; im Budget
von A-6). Die Wanduhr (233–274 s) misst den ganzen Prozess unter Fremdlast und ist kein Vergleich.

## 8. Abweichungen und Vertragsfragen

**Abweichungen**
- `tests/race3d/check_minimal_structures.gd` (nicht meine Datei): „wahrzeichen“ prüfte die fernen Vertretungen von
  `props.gd` (`props._far`, `far_reach`) – mit dem Builder `landmarks` gibt es sie nicht mehr. Vier Zeilen am Anfang
  von `_check_wahrzeichen()`: verweist auf `tests/race3d/check_landmarks.gd`, sobald `builders/landmarks.gd` existiert.
  Ohne die Änderung wäre `run_tests.sh` rot.
- `builders/props.gd`: **keine Zeile geändert** – die Ente-Typ-Weiche (`_skip_landmarks = renderer.builder("landmarks")
  != null`; Zeilen 88 Deklaration, 122 Setzen, 329 `_update_far_landmarks` kehrt zurück, 539 an `collect` übergeben,
  741 `item_set` lässt Einträge mit `landmark` aus) stand schon im Code. Der Code der fernen Vertretungen in
  `props.gd` (`_update_far_landmarks`, `_far`, `landmark_material`, `_landmark_override`, `landmark_fallbacks`) läuft
  mit dem Builder nicht mehr (toter Pfad, nur noch ohne Renderer in Tests).
- Lead-Entscheidung 3 nennt „§15/§16 von docs/renderer-modern.md“ – dort stehen R4 und R5; die Schnittstelle steht im
  neuen §18.2.
- Gerade Anfahrt (Abnahme „600 m auf gerader Anfahrt“): keine der zehn Stadteinfahrten verläuft in den letzten 640 m
  gerade (|curve| 0,11–0,29); im ganzen Netz nur drei Wahrzeichen-Anfahrten (Burgos; Kirche bei Slavonski Brod aus
  beiden Richtungen). Dort gemessen; zusätzlich die Bildprüfung in der Kurve vor Hamburg.
- Wahrzeichen nie gespiegelt (D24): Arcade spiegelt eine gewöhnliche Requisite mit `mirror_left` links
  (`props/church` als Wahrzeichen) und misst ihre Kante mit der anderen Ausdehnung – bis 24,7 px Versatz bei 600 m
  (innerhalb der 5 %).
- Clips bei „Hoch“, nicht „Mittel“: der LOD-Teil der Abnahme gehört R7c; der einzige Wechsel von R7b ist gemessen
  pixelgleich (§4).
- Golden `modern_s4_mittel` nicht neu erzeugt (s. Vertragsfragen).

**Vertragsfragen**
- Die Aufgabe sagt „modern-make nur, wenn sich ein Modern-Golden gewollt ändert“, A-18 sagt „packages do not
  regenerate it“ (§11 geht vor). `modern_s4_mittel` ändert sich gewollt um höchstens 2/255 an 369 Pixeln (der Michel,
  jetzt aus `landmarks.gd`) – nicht neu erzeugt; die Integration erzeugt es nach dem Zusammenführen neu.
- `VIEWPORT_SIZE` im Vertex-Schritt: die ersten Leuchtpunkte deckten den ganzen Nachthimmel rot (Dortmund 22 Uhr) –
  gefolgert, dass `VIEWPORT_SIZE` dort in Compatibility 0 liest; jetzt eine Uniform mit der Bildhöhe und eine Grenze
  (3 % des Abstands). Nicht isoliert nachgemessen; Prüfung `flugfeuer` hält es fest.
- Durchscheinende Wahrzeichen werfen keine Schatten – unschädlich, weil der Wechsel erst ab 0,70 L (≥ 420 m) kommt,
  jenseits jeder Schattenweite (≤ 200 m).
- Modelle von AS6 mit Glas- oder Laubflächen: diese Klassen behalten ihr Material und blenden nicht weich aus
  (§18.2) – AS6 sollte für Wahrzeichen `baked`/`baked_cutout`/`vpbr` nutzen.
- Das Völkerschlachtdenkmal (Leipzig) und das Neue Rathaus (Hannover) zeichnet schon Arcade als Kuppelkirche; R7b
  folgt Arcade. Ein eigenes Denkmal wäre ein Modell von AS6.

## 9. Hinweise für die Nächsten

1. **R7c / Besitzer von `props.gd`**: den toten Pfad der fernen Vertretungen entfernen (`_update_far_landmarks`,
   `_far`, `landmark_material`, `_landmark_override`, `landmark_fallbacks`) und `docs/renderer-modern-gelaende.md`
   Zeile 185 nachziehen (beschreibt noch das Ersatz-Set für prozedurale Wahrzeichen – jetzt 3D-Formen in §18.4).
2. **Integration / QA**: `tests/golden/modern_slice.*` nach dem Zusammenführen neu erzeugen (`modern_s4_mittel`:
   Michel, höchstens 2/255).
3. **AS6**: Modell in `assets/models/manifest.json` für `landmarks/<name>` genügt (§18.2): Ursprung = Anker des
   Sprites, −Z vom Fahrer weg, Klassen `baked`/`baked_cutout`/`vpbr`; Nachtlicht über Emissionsatlas bzw. Kanäle
   10–14. Auch die sechs prozeduralen Einträge (z. B. `landmarks/florianturm`) nehmen ein Modell an.
4. **Stadtbauten (AS5a2/R7c)**: Brüssel km 206,4 – Arcades Häuserzeile vor dem Atomium fehlt in Modern (auch auf der
   Basis). Paris – dunkle „X“ an Fassaden (Geländer) der Stadtgebäude.
5. **QA-mid**: Bei 600 m verdecken Häuser das Wahrzeichen in fast allen Stadteinfahrten (beide Modi) – für die
   Wahrzeichen die Nahpunkte aus `m1/R7b/sh/batch3.sh` nehmen (etwa 250 m davor).
6. **QA-mid**: Skyline im Bild nur an Kassel und Paris geprüft; ein Durchgang durch alle Städte mit Skyline-Einträgen
   lohnt (`backdrop.skyline` im Snapshot).
7. **Leuchtpunkte anderer Shader**: wer im Vertex-Schritt Pixelgrößen braucht, die Bildhöhe als Uniform übergeben
   (`VIEWPORT_SIZE` las dort 0, gefolgert).
8. **Feinschliff (Entscheidung der Leitung)**: (a) Flugwarnlicht des Fernsehturms nachts etwa dreimal so groß wie
   Arcades Punkt (`landmarks.gd`, `_tv_tower`: Stärke 0,6, Größe 5 m, Mindestgröße in Pixeln). (b) Die Formen stehen
   mit der Vorderseite am Anker; Arcade zeichnet flach am Anker. Die Form um ihre halbe Tiefe nach vorn zu setzen
   (Kuppel am Anker) brächte die Nahbilder in Kurven näher an Arcade (gefolgert; gemessen Leipzig −65 px, Belgrad
   +85 px bei 260 m);
   `test_procedural_shapes` prüft die Lage der Formen mit.
9. **R7c**: die Clips bei „Mittel“ für die LOD-Abnahme sollten eine Wahrzeichen-Anfahrt enthalten (z. B. Hamburg ab
   km 89).

## 10. Endstand und Ablage

- Zweig `wip/v080-r7b` (Sicherungskopie nach jedem Commit, nie erzwungen), lokaler Zweig
  `worktree-wf_ba4424b4-294-2`, Endstand **`2c154bc`** („v0.8.0 R7b: Doku – Prüfungen Flugfeuer und Tönung in der
  Dateitabelle“), 16 Commits auf `9b02f05`. Gates auf genau diesem Stand.
- Geänderte Dateien (2.540 Zeilen hinzu, 5 entfernt): `scripts/race3d/builders/landmarks.gd` (+ `.uid`),
  `assets/shaders/modern/landmark.gdshader` (+ `.uid`), `scripts/race3d/layers/backdrop.gd`,
  `tests/unit/race3d/test_landmarks.gd` (+ `.uid`), `tests/race3d/check_landmarks.gd` (+ `.uid`),
  `tests/race3d/render/check_landmarks_render.gd` (+ `.uid`), `tests/race3d/check_minimal_structures.gd`,
  `docs/renderer-modern.md`. Nicht berührt: `builders/props.gd`, `billboard.gdshader`, `baked.gdshader`,
  `config/game_config.json`, eingefrorene Arcade-Dateien.
- Ablage `deliver/R7b/`: `bericht.md`, `boegen/` (zehn Städte, Nahbilder, Horizont S1–S5), `ab/` und `ab_nah/` (die
  einzelnen A/B-Bilder), `clips/anfahrt_hamburg.mp4`, `clips/anfahrt_paris.mp4`, `bilder/` (Skyline nur Hintergrund,
  Zoom-Bilder, Sonde der Kurven, deckend gegen durchscheinend). Rohdaten der Gates: `m1/R7b/gates/`, Skripte
  `m1/R7b/sh/`.
