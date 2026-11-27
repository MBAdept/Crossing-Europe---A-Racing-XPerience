
### Aufstellung: lange Grundrisse drehen nur so weit, wie der Knoten rücken darf

Der Renderer dreht ein Wahrzeichen-Modell zur Anfahrt (renderer-modern.md 19.1, FIX-R7b) und rückt es mit
`near_shift()` von der Straße weg, wenn die Drehung eine Ecke näher an die Straße brächte; der gezeichnete Knoten darf
dabei höchstens 12 m von Arcades Anker liegen (A-25, `MAX_NODE_SHIFT_M`). Die langen AS6-Modelle hielten das nicht:
der Mailänder Dom (158 m tief) wurde auf Bern – Mailand um 26,7 m verschoben, das Atomium 15,9 m, die
Elbphilharmonie auf Hamburg – Bremen 12,5 m. `landmarks.gd` `capped_turn()` kürzt die Drehung (Bisektion auf ihren
Anteil) gerade so weit, dass die Verschiebung in der Grenze bleibt; kurze Grundrisse behalten die ganze Drehung
(`test_landmarks` „long_footprint_turns_only_as_far_as_the_node_may_move“, Netztest „drawn_node_stays_near…“).

### Messungen (llvmpipe, Prüfszene im Renn-Look und Rennen, gemessen)

| Messung | Ergebnis |
|---|---|
| Ansicht neben dem Sprite, 80 / 250 / 600 / 1 200 m, 12 und 22 Uhr | alle 32: Umriss, Gliederung, Farben wie das Sprite; nachts die Anstrahlung und die Fenster der Lichtebene |
| Bildwechsel von Bild zu Bild bei 120 km/h (Anteil der Pixel mit > 24/255 Änderung, Modell / Sprite) | Riesenrad 250 m 6,5 / 2,1 %, 600 m 8,8 / 0,6 %, 1 000 m 4,5 / 0,1 %; Eiffelturm 250 m 2,3 / 2,3 %, 600 m 0,3 / 0,4 % |
| Anker gegen Arcade, ganzes Netz (143 Wahrzeichen) | größter Unterschied 0,34 m (Erlösung: das Sprite misst seine Breite in Pixeln von 0,23 m) |
| Render-Prüfung `check_landmarks_render` (Kiel – Hamburg, jetzt mit den Modellen) | Stelle km 85,6: Elbphilharmonie im Bild an Arcades Stelle (Versatz 8 / −6 px); weich ausgeblendet (km 76); nachts nur beleuchtet (km 77,4); **Nachtfassade der Elbphilharmonie 1,01 × Arcade** (Luminanz 116,8 gegen 115,9) |

### Ehrliche Einordnung

Gut: Die Wahrzeichen sind aus der Nähe echte Bauwerke – Maßwerkhelme und Fialen in Köln, Regensburg und Linz, das
Zickzack-Dach des Stephansdoms, die Kastenträger des Eiffelturms, Speichen und Gondeln des Riesenrads, die
Kugeln des Atomiums in Chrom, die Goldkuppeln von Sofia und Bukarest mit Glanzlicht. Aus der Ferne stimmen Umriss
und Farben mit den Sprites überein; nachts sind sie angestrahlt wie Arcades Lichtebene.

Noch nicht gut:
- **Blickwinkel (N6).** Jedes Sprite zeigt sein Wahrzeichen um 10–28° gedreht (`view_yaw` in `props_landmarks.py`);
  die Modelle stehen frontal zur Anfahrt. Im Rennen wirken lange Bauten dadurch schmaler als in Arcade (Fulda: nur
  die Doppelturmfassade statt Fassade, Langhaus und Kuppel), die Kuppel von Koekelberg steht hinter der Fassade.
  Um den Sprite-Winkel gedreht sieht das Modell aus wie das Sprite (`prop_scene --yaw`); die Drehung schwenkt aber
  das Ende langer Kirchen zur Straße, hinter dem Anker sind nur 40 m frei. Eigener Schritt.
- **Speichen des Riesenrads (N2)** flimmern ab etwa 250 m (Messung oben): 0,14 m sind dort schmaler als ein Pixel.
- **Burgos (N3)** ist schon im Generator schlicht (Rosette eine flache Scheibe) – Modell wie Sprite.
- Die zehn Einträge ohne Generator bleiben prozedurale Formen (oben).
