## 3. Brückenpylon nachts und Flugbefeuerung (neu, `efff1ed`, `b693d33`)

**Befund nach dem Zusammenführen** (gemessen, Köhlbrandbrücke km 78,1, 22 Uhr, „Hoch“, Bereich von FIX-WASSER-R
x 500–780 × y 150–350, mittlere Leuchtdichte nach Rec. 709 wie in `NACH-WASSER/tools/measure.py`): Arcade 60,1,
ZS1 58,4, **zusammengeführt 84,4** – die Pylone leuchteten wieder hellgrau. Ursache, zwei Teile:
1. Seit AS4R ist `props/bridge_pylon` ein Modell; `dark_material()` von FIX-WASSER-R greift nur bei der
   Sprite-Vertretung. Der Nachtatlas des Modells (`emit.png`, mittlerer Wert 60/255, 85 % der Fläche > 32) ist der
   angestrahlte Pylon des Sprites – genau die Lichtebene, die FIX-WASSER-R abgeschaltet hatte.
2. Ohne Nachtatlas noch 79,5: der Mond beleuchtet die hellen Betonflächen (Albedo ≈ 0,78) und die Seile; Arcades
   prozeduraler Pylon ist nachts Beton × Umgebungslicht (`RoadRenderer._oc`, Licht nur 0,3 × am Fuß).

**Behebung** (`builders/props.gd`, `assets/shaders/modern/baked.gdshader`): Einträge mit `prefer_proc` (nur die Pylone
der Schrägseilbrücken, `Track._build_bridge`) kommen als Modell in eine eigene Gruppe `md|…`; `_dark_model_override()`
gibt dem Knoten eine Kopie des Materials mit `emit_energy` 0 und `night_albedo` = `PYLON_NIGHT_ALBEDO` 0,45 (neuer
Parameter von `baked.gdshader`: Albedo × (1 − (1 − n) × ce_night), Vorgabe 1 = Faktor genau 1,0 – kein anderes
Material ändert sich). Derselbe Shader, keine neue Variante, bei Tag dasselbe Bild.

**Messreihe** (gemessen; 22 Uhr, ab km 77,6 mit 80 km/h und Verkehr; Arcade-Bilder bitgleich mit FIX-WASSER-R):

| km | Arcade | ZS1 (Vertretung) | zusammengeführt | ohne Nachtatlas | `night_albedo` 0,55 / 0,5 | **0,45 (Endstand)** |
|---|---|---|---|---|---|---|
| 77,7 | 76,5 | 79,7 | 83,7 | – | – / 71,6 | **70,7** |
| 78,1 | 60,1 | 58,4 | 84,4 | 79,5 | 60,2 / 58,0 | **55,9** |
| 78,8 | 48,1 | 49,8 | 57,9 | 53,6 | 44,9 / 43,9 | **43,0** |
| 78,9 | 47,7 | – | – | – | – / 43,6 | **42,6** |
| 79,7 | 51,6 | 52,1 | 77,8 | – | – / 53,7 | **51,7** |

0,5 lag bei km 79,7 2 Stufen über Arcade (die Laternen beleuchten dort die Seile neben dem Deck) – darum 0,45: an
allen fünf Stellen höchstens Arcade (79,7: +0,1, Messrauschen) und an allen höchstens ZS1. **Steam-Deck-Stufe**
1280 × 800 (Arcade mit Balken, Bereich 40 Zeilen tiefer), 0,45: km 77,7 / 78,1 / 78,8 – Arcade 76,5 / 60,1 / 48,1,
ZS1 78,4 / 61,0 / 50,9, **M2ZS1 69,2 / 57,7 / 43,5**.

**Rote Flugbefeuerung** (Arcade: `RoadRenderer._pylon` blinkt bei Lichtern > 0,2, an solange
`fmod(time + side × 0,4, 1,6) < 0,8`, Schein max(3 px, 1,2 m), Alpha 0,8 × Lichter). Billig, weil das Pylonmodell
schon einen roten Lampenanker auf 88,3 m hat (bisher Dauerlicht der Ebene `flares`): `props.gd` gibt Ankern ab 25 m
Höhe eines Eintrags `proc` = `pylon` den Takt `PYLON_BLINK` (1,6 s, 0,8 s, Phase Seite × 0,4 s) als `"blink"`;
`layers/flares.gd` lässt eine Lampe mit Takt nur in ihrer Phase leuchten (`blink_lit()`, rein, nach `view.time`, steht
im Pausenbild still) und legt Arcades roten Schein als zweiten Lichtpunkt darum. Unit-Tests: Takt, Phasen ±0,4 s,
Wechsel der Seiten und Tag/Nacht gegen Arcades Formel über 1,6 s in 10-ms-Schritten; Lampenanker rot, ohne Kegel. Im
Bild nicht belegt (Pylonspitzen an den geprüften Stellen hinter dem oberen HUD-Balken).
