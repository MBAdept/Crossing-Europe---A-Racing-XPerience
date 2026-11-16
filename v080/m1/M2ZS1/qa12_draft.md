
## 12. Der Testbuild ZS1 in der M2-Linie (M2ZS1, Basis `49f221e`)

M2INT (`49f221e`) hatte AS2R, AS3R, AS4R und den Klang zusammengeführt, aber nicht die Behebungen, die danach in den
ersten Testbuild gingen (FIX-ZS1, FIX-WASSER, FIX-WASSER-R = `39849f0`). M2ZS1 führt sie mit `--no-ff` zusammen
(`25be6c7`) und prüft, ob jede Behebung mit dem Inhalt von M2 noch hält.

| Behebung aus ZS1 | hält nach dem Zusammenführen? | Beleg |
|---|---|---|
| FIX-ZS1: Start bei km 0 (Vorlauf, Stück −1, Auto im Countdown) | ja | `test_start_lead_in` 6/6; `check_start_km0`; A/B Start „Mittel“ und Steam Deck: Lackfläche der Limousine ±1 % an Arcades Stelle |
| FIX-ZS1: Lampenringe des Starttors ohne Schatten bei „Aus“ | ja | `check_light_base` „schatten“ (bei M2INT rot) |
| FIX-WASSER: Fernboden unter dem tiefsten Wasser | ja – eine Regel (unten) | `test_far_ground_water` 4/4, `test_terrain_builder` „unter dem Wasser einer Brücke“, `check_terrain_cover` K1 |
| FIX-WASSER-R: Ersatz-Sets der sechs prozeduralen Wahrzeichen | ja, jetzt als Modell (Kirche, Hochhaus seit AS4R) | `test_props` auf allen 20 Anfahrten |
| FIX-WASSER-R: Pylone nachts nicht heller als Arcade | erst nach Nacharbeit: der Pylon ist seit AS4R ein Modell | unten |

**Fernboden – eine Regel.** M2INT hatte denselben Befund (FIX-ZS1-B1) in `b341df8` anders behoben (Wasserhöhe statt
Straße in `lowest_road()`, jede vierte Reihe, Scheibe 4 m unter dem Wasser). Es gilt die Regel des Testbuilds
(FIX-WASSER: `target_height()` = min(tiefste Straße − 4 m, tiefstes Wasser − 0,3 m), jede Wasserreihe gelesen, Reihe
noch im Speicher der Strecke); `b341df8` deckte nichts darüber hinaus ab (nur Brückenreihen tragen `water_level`).
Sein Unit-Test bleibt, umgestellt auf die eine Regel.

**Pylone nachts (neu).** Mit dem Pylon-Modell von AS4R galt die dunkle Vertretung nicht mehr, und die Pylone der
Köhlbrandbrücke leuchteten um 22 Uhr wieder hellgrau: der Nachtatlas des Modells ist der angestrahlte Pylon des
Sprites, und der Mond hellt die hellen Betonflächen auf. Behebung in `builders/props.gd` (Kopie des Materials ohne
Nachtatlas, `night_albedo` 0,5; neuer Parameter von `baked.gdshader`, Vorgabe 1). Gemessen im Bereich von
FIX-WASSER-R (x 500–780, y 150–350, km 78,1, „Hoch“, mittlere Leuchtdichte): Arcade 60,1 – ZS1 58,4 – zusammengeführt
84,4 – behoben 58,0. Die rote Flugbefeuerung blinkt wie Arcades (1,6 s Takt, 0,8 s an, Seiten im Wechsel).
