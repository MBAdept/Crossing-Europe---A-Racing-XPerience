## 6. Was ich von den AS5a1-Angaben bestätige – und was nicht

| AS5a1 sagt | nachgeprüft | Ergebnis |
|---|---|---|
| Prüfer grün, 11 Sets mit Modell | `validate_models.py --report` auf der Kopie | **bestätigt** (`CHECK models OK`) |
| 427–9 865 Dreiecke lod0, 2 Aufrufe je Stufe | Prüferbericht | **bestätigt** |
| Netze 0,79 MB, Texturen 5,25 MB im Archiv | `share.py` (deflate -9 wie `pck_report.py`) | **bestätigt** (identische Bytes) |
| Umriss IoU 0,987–0,999 (Kran 0,922) | `outline2` mit Blickwinkel −20°/−24° | **bestätigt** (Zahlen gleich, Bild 26) |
| Straßenwände ≥ 26 px/m, Innenstadt EG/1.OG ≥ 40 px/m (Modellmaß) | `texel_k5.gd`, nur Außenwände | **bestätigt im Modellmaß**; im Spiel bei Maßstab 1,1–1,2 nicht (Kontor 34/24, Giebelzeile 36/29 px/m, gerechnet) – AS5a1 sagte das für Kontor/Giebelzeile auch |
| Stufenwechsel 60 m: 10–32 % der Pixel | `prop_scene --mode=lods` „Mittel“ | **bestätigt** (Fachwerkzeile 32,0 %, Kontor 24,7 %, nachts +9 bis +10 % Helligkeit) |
| Geländer: Deckung mip1–3 1,1–1,4, mip4 0,29/0,59 | `mipcov.py` auf den Atlanten | **bestätigt** – aber das ist ein Mangel, kein Nachweis „funktioniert“ (K7) |
| „In den A/B-Bildern sieht Modern klar besser aus“ | eigene A/B an 5 Orten mittags + Nacht/Dämmerung | **bestätigt für die Häuser**, aber: München links und Nürnberg rechts fehlen Häuser in Modern (Renderer), Hamburgs Vororte sind weiß statt rosa (Tönung, R7) |
| Nachts dieselben Fenster wie Arcade | Rennbilder 22 Uhr | **bestätigt** in Hamburg (0,6–1,0 × die beleuchteten Fensterpixel von Arcade); in Nürnberg weniger, weil ein Haus fehlt (K1) und blinde Flanken statt Fassaden vorbeiziehen (K2) |
| Tönung als Instanzfarbe machbar | `tint_scene` (Bild 27) | **bestätigt**: Atlas × Tönung trifft das getönte Sprite im Farbton; Mietshaus × `#e0b09c` etwas gesättigter als das Sprite |
| „Flimmern 2–10× Sprite“ | `sparkcam` (Teilmenge) und Fahrfilm | **bestätigt** (Fachwerkzeile 1,1–1,4 % gegen 0,1 %, Giebelzeile lod1 1,1–1,3 %; K6) |
| Bake-Zeiten 108–1 462 s | – | nicht nachgemessen (kein Neuexport in einer Kritik) |
