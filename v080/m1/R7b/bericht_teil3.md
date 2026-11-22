
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
