### QR7c-06 (mittel) – Raster bei stehender Kamera → **behoben**

- **Nachgestellt (gemessen):** Countdown Nürnberg – Fulda km 0, Deck, 1,5 s aus `ref` bit-genau wie QA; die Eiche
  unten rechts steht im Band 53–67 m und zeigt das geordnete Raster zweier Stufen.
- **Fix (Zeitblende ohne Instanz-Uniform):** neues globales `ce_lod_still` (in `ModernMaterials.GLOBALS`, Vorgabe 0).
  `props.gd` misst in `update()` die Geschwindigkeit der Kamera entlang der Straße: unter 1,5 m/s wächst `ce_lod_still`
  in 0,4 s auf 1, beim Anfahren fällt es ebenso auf 0 (`still_step()`; 0,4 s wie das `xfade` der Fahrzeuge, A-16);
  gesetzt nur bei Änderung; zu Beginn einer Etappe steht die Kamera (`_still` = 1), also gibt es im Countdown kein Raster.
  `inc/lod_band.gdshaderinc` zieht jedes Band zu seinem **fernen Ende** zusammen (bei 1 auf 1 mm): eine stehende Kamera
  sieht je Instanz genau eine Stufe, und zwar im ganzen Band die feinere – nicht die gröbere, wie es eine harte
  Entscheidung in der Bandmitte (QAs Vorschlag; erster Versuch) gezeigt hätte: dort stand die Countdown-Eiche glatt,
  aber in lod1 kantiger als in der Basis. Beide Nachbarstufen verengen dasselbe Band, bleiben also komplementär; das
  Verengen über 0,4 s ist selbst ein Überblenden durch dasselbe Raster; der Schattendurchgang folgt dem verengten Band
  (es wirft die sichtbare Stufe). Bei `ce_lod_still` = 0 läuft derselbe Code wie bei R7c (eigener Zweig, kein
  Rundungsunterschied).
- **Nachgeprüft:** Render-Prüfung `check_lod_band` „lod_ueberblenden_stand“ und „lod_baum_stand“: mit `ce_lod_still` = 1
  weicht kein Schritt der Fahrt durch das Band vom harten Wechsel am Bandende ab (0,00 % der Pixel, Grenze 1 %;
  gemessen); in Fahrt unverändert 0,6 % gegen 7,1 % (Barock) und 1,1 % gegen 36,6 % (Eiche). Mutationen „Stand aus“
  (R7) und „Bandmitte statt Ende“ (R8) werden rot (6,5 % / 7,1 %). Angesehen: `start_countdown_deck_basis_r7c_fix.png`
  (2×) – die Eiche steht glatt und in derselben Stufe wie in der Basis.
- **Uhr der Rampe:** erst `dt` des Hakens; `check_weather` „teilchen“ zeichnet dieselbe Ansicht zweimal und verlangt
  dasselbe Bild – dazwischen wuchs `ce_lod_still` (17 / 18 Pixel anders bei „Steam Deck“). Jetzt ist die Uhr
  `view.time` (Regel 10; `dt` nur ohne sie), dieselbe Ansicht ändert nichts (`b22b90b`, Test). Ein angehaltenes Spiel
  (Zeit steht) behält damit den Zustand vor der Pause.
