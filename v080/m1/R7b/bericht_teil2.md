
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
