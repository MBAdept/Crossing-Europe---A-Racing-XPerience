## 6. Was ich von den AS5a2-Angaben bestätige – und was nicht

| AS5a2 sagt | nachgeprüft mit | Ergebnis |
|---|---|---|
| Prüfer grün, 12 Sets mit Modell | `validate_models.py --report` auf der Kopie | **bestätigt** (`CHECK models OK`) |
| 1 336–6 518 Dreiecke lod0, 2 Aufrufe je Stufe | Prüferbericht | **bestätigt** (Grachtenhäuser B 3 625 / 1 545 statt 3 623 / 1 543 – unerheblich) |
| Archiv 0,93 MB Netze, 5,79 MB Texturen | `share.py` (deflate -9 wie `pck_report.py`) | **bestätigt** (0,94 / 5,82 MB) |
| Umriss IoU 0,945–0,999 | `outline2` | **bestätigt** (gleiche Zahlen, Bild 26) |
| Straßenwände ≥ 26 px/m, EG ≥ 40 px/m (Lauben bei 1,10: 39,8) | `texel_k5.gd` | **bestätigt für die Hauswände**; **nicht** für die Gartenmauern von Südhaus und Loire-Haus: 14–16 px/m statt der angegebenen „0,6 der Dichte“ (≈ 32) |
| Stufenwechsel 60 m: 9–18 % (Tag), 8–15 % (Nacht), +0,6 … +4,9 % | `--mode=lods` „Mittel“ | **bestätigt**; auf „Hoch“ (120 m) bis 22,6 % (Grachtenhäuser) – nicht gemessen von AS5a2 |
| Flimmern 2–5× Sprite (Haussmann 1,0 / 1,2 / 1,0 / 0,6 %) | `sparkcam` | **bestätigt**, beim Eckhaus bei 40–100 m 5–11×, bei Grachtenhäusern B bis 7× (5.5) |
| „Das Geländer wird zum Band, verschwindet nicht“ (±3 Stufen) | `mipcov.py`, `mipband.py` | **Deckung bestätigt** (Haussmann 1,16 / 1,55 / 1,96 / 2,74), **Helligkeit nicht**: vor hellem Stein wird das Band ab Mip 3 27–89 Stufen dunkler – die Geländer schließen sich (5.6) |
| Tönung: Albedo × `#ead6cc` = getöntes Sprite | `tint_scene` | **bestätigt** (Bild 27) |
| lod1 bei 200–250 m heller als das Sprite | `k6_scene --mode=lodcol` | **bestätigt, aber nicht lod1**: lod0 und lod1 werden gleich blass; es ist die Mip-Kette (5.4) |
| Schaufenster nachts dunkler als Arcade (124 gegen 207) | A/B Paris 22 Uhr | {{BEST_LADEN}} |
| „Im Rennen bei Paris nicht auffällig“ (Fernbild) | A/B an fünf Ankünften | {{BEST_FERN}} |
| Backzeiten 166–800 s, Determinismus, Gates, Arcade-Identität | – | nicht nachgemessen (Kritik ohne Neuexport und ohne Testlauf; die Kopie ist byte-gleich mit 3c5e37a ohne `.git`) |
