## 3. Nicht umgesetzt oder anders als vorgeschlagen

Kein Befund der Kritik war falsch; abgelehnt ist keiner. Nicht oder anders umgesetzt:

- **A8 Diffusor-Finnen (niedrig): nicht geändert.** Unter dem Heck, aus der Spielkamera als dunkle Fläche zu sehen,
  die Finnen selbst nicht (Bild 01). Der Umbau zu Rippen auf einer Platte berührt den Sprite-Generator (die Finnen
  sind ein Teil des Entwurfs) und hätte einen eigenen 3D-Hook je Auto gebraucht – zu teuer für „kaum zu sehen“.
- **A9 (niedrig): nicht geändert.** Schattenwerfer ohne Spiegel, kein Rückfahrlicht bei Sportwagen und GT (der
  Spieler fährt nie rückwärts).
- **B7 (niedrig): nur die Räder von `lod2`.** Sie sind jetzt Lauffläche plus Scheibe in der Mischfarbe von Reifen
  und Felge (12 Dreiecke je Rad weniger, für das Budget der Scheiben), bleiben aber sechseckig. Kennzeichen-Zeichen,
  dreieckige Radausschnitte in `lod2` und die Ecken im Vorderreifen des Verkehrs-Sportwagens ab ±7° (der Verkehr
  lenkt unter 2°) sind unverändert.
- **B4 anders als vorgeschlagen:** Rauheit und Metallwert der fernen Scheibe waren schon die von `lod0` (0,02 /
  0,25). Der Unterschied kommt aus dem Shader: `vpbr` spiegelt den Himmel etwa halb so stark wie die Klasse `glass`.
  Deshalb hat die ferne Scheibe eine hellere Albedo (`TRAFFIC_GLASS_FAR` `#3a4652`), gemessen auf die mittlere Farbe
  der `lod0`-Scheibe mit Renn-Look abgestimmt. Das hängt am Look (Abschnitt 9, Punkt 2).
- **B2 anders als vorgeschlagen:** keine eigene Liste von Fensterkonturen für `lod2`, sondern die Fenster des
  Entwurfs selbst: Die Heckscheibe wird entlang ihrer Kontur geschnitten (ein Schnitt zusammen mit den
  Kabinen-Decals), die Seitenscheiben bleiben im y-Bereich der Seitenfenster. Das gilt für alle sechs Verkehrstypen
  und das Heck der Polizei. Die Dachreling des SUV in `lod2` habe ich **nicht** auf das Dach gesetzt: Sie steht im
  Nahbild weiter als zwei Stäbe ohne Füße knapp über dem Dach (Bild 06); ab 90 m ist sie weniger als ein Pixel hoch
  (abgeleitet).
- **B3, B6, A6 (Kompakt): Ursache anders als vermutet** (Abschnitt 2) und dort behoben, wo sie lag.
- **A5:** Der Kotflügel wird nur im 3D-Bau auf den Kreis Reifenradius + 25 mm gezogen; das Sprite bleibt, wie es ist
  (Regel 1). `show` bei ±25° Lenkung (nur im Showroom): noch 2 Ecken bis 15 mm (Sportwagen) bzw. 1 Ecke bis 6 mm (GT).
  Den vorgeschlagenen Freigangs-Test im Export (mindestens 20 mm bei 0° und ±7°) habe ich nicht eingebaut; geprüft
  ist mit dem Werkzeug der Kritik, das Ecken **im** Reifen zählt (0 bei 0° und ±7°), nicht die 20 mm Reserve.
- **C3:** Die Regel des Prüfers ist unverändert (Vertragsfrage, Abschnitt 9); die drei verdeckten Lampen sind
  sichtbar gemacht, die Regel trifft also wieder nur Sichtbares.
- **Polizei-Lichtbalken bei Tag (AS2b, offen):** nicht geändert. Die Blöcke von `lod1`/`lod2` sind Lampenflächen;
  unbeleuchtet zeigen sie `lamp_off` × Leuchtfarbe (A3). Eine hellere Leuchtfarbe änderte das Blaulicht selbst.
  Das gehört zu A3 (Renderer).
- **Bus `lod2`, zwei breite Gitterstäbe statt sechs feiner (AS2b, offen):** nicht geändert; das Budget von `lod2`
  ist voll (1 500 / 1 500), und ab 180 m ist das Gitter drei Pixel hoch.
- **Kennzeichen der fernen Stufen bei Lkw und Bus** (`heavy3d.FAR_PLATE` `#c4c4c1`): nicht angeglichen. Sie gilt erst
  in `lod2` ab 180 m, wo das Kennzeichen ein bis zwei Pixel groß ist.

## 6. Showroom-Schalter

`showroom` bleibt bei allen fünf Spielerautos `false` (Manifest, gemessen). Begründung:

- Der Showroom von UI1 setzt den Renn-Look nicht (C1, Renderer/UI1). Solange das so ist, zeigt er je nach dem, was
  vorher lief, ein anderes Material.
- Mit dem Look (Bild `03_showroom_ab.jpg`, Kontaktbogen-Rig, jetzt mit wirksamem Look nach C2) sind Form, Fugen,
  Felgen, Lampen und Kennzeichen gleich. Unterschiede: Der Lack ist heller und gesättigter als im Sprite (A1,
  Belichtung), das Gelb des Kompakt blasser; das Glas ist durchsichtiger und zeigt den Innenraum; die Felgen von Kombi
  und GT sind dunkler als vorher, aber noch heller als im Sprite.
- Nach A5 sind Sportwagen und GT keine Ausnahme mehr: Wenn UI1/R3 den Look im Showroom setzen, sind Kombi,
  Limousine, Sportwagen und GT aus meiner Sicht Kandidaten für `true`, der Kompakt erst mit richtigem Gelb (A1).
  Das ist abgeleitet; entscheiden muss es jemand, der den Showroom auf echter Hardware sieht.

## 8. Was die Modelle vom Renderer brauchen (R1, R3, R4, UI1)

Unverändert aus der Kritik, am Modell nicht lösbar (gemessen bleibt hier: Kompakt 87 %, Sportwagen 55 % der
Lackpixel geclippt in 9 m):

1. **Belichtung des Lacks (A1, R1/R4):** Sonne, Umgebung und Füll-Licht 0,7 addieren sich; die Lackwerte sind die
   des Sprites. Vorschlag der Kritik: Belichtung oder `paint_base` senken und neu messen.
2. **Nacht (Rest von A2, R3/R4):** Ohne Flares/Glow erreichen die Spielerautos in 8 m beim Rücklicht 33–65 %, bei der
   Bremse 49–88 % der roten Pixel von Arcade (gemessen); die Karosserie bleibt nachts fast schwarz (kein
   Nacht-Füll-Licht).
3. **Unbeleuchtete Lampen (A3/B5, R3):** `lamp_off` 0,5 lässt Lampen bei Tag eingeschaltet wirken; das betrifft auch
   den Lichtbalken der Polizei.
4. **Flocken (A4, R3):** Zellen kleiner als ein Pixel blinken beim GT; `flake_near_m` 14 m.
5. **Showroom-Look (C1, UI1/R3):** Der Showroom setzt `LOOK` und eine eigene Umgebung; der Look gehört an eine Stelle,
   die beide lesen.
6. **Drei Werte der Modelle sind auf den Renn-Look gemessen** (`LOOK` in `layers/vehicles.gd`: `env_energy` 1,6,
   `paint_base` 0,9, Glas `env_energy` 2,2): die ferne Scheibenfarbe (`traffic3d.TRAFFIC_GLASS_FAR`,
   `truck3d.GLASS_FAR`), das ferne Kennzeichen (`traffic3d.FAR_PLATE`) und das Karoband der Polizei
   (`police3d.CHECK_MEAN_EXP`). Ändern R3/R4 Look, Belichtung oder Tonkurve, müssen sie neu gemessen werden:
   `kritik/probe.sh <tag> 40 lod0 lod1 <sets>` und `… 120 lod1 lod2 …` (Abschnitt 11), dazu `bin/winmean.py`,
   `bin/platemean.py`, `bin/bandmean.py`, `bin/buswin.py` für die Mittelwerte von Scheibe, Kennzeichen und Karoband.

## 9. Vertragsfragen

1. **Lampenregel des Prüfers zählt verdeckte Lampen (C3).** Die Regel prüft Fläche und Wicklung, nicht die
   Sichtbarkeit; drei unsichtbare Lampen waren grün. Vorschlag: ein Strahltest wie `lamp_vis.py` der Kritik (etwa 5 s
   je Modell) im Prüfer, Schwelle z. B. 50 % sichtbar von der Seite der Lampe.
2. **§4.6.4: ferne Verglasung als `vpbr`.** `vpbr` spiegelt den Himmel halb so stark wie `glass`; damit die Scheiben
   beim Wechsel nicht springen, braucht die ferne Stufe eine auf den Look gemessene Albedo. Das ist die nächste
   saubere Lösung im Vertrag; sie bricht, wenn der Look sich ändert (Abschnitt 8, Punkt 6). Alternative für den
   Vertrag: die Klasse `glass` auch in `lod1` (ein Zeichenaufruf mehr je Auto).
3. **Budget `lod2` der Polizei = Verkehrsauto (1 200).** Lackierung, Lichtbalken und Heckscheibe nach der Kontur
   teilen sich das Budget; die Seitenscheiben der Polizei bleiben deshalb nach der Normalenregel, Tschechien ganz
   (mit Schnitt 1 204 / 1 200). AS2b hat 1 400 vorgeschlagen; das würde beides lösen.
4. **`tests/race3d/check_vehicles.gd` (R3):** `kasten` und `leistung` sind rot, wie bei AS2b. `kasten` erwartet für
   `traffic/sports_red` und `police/at` einen Kasten ohne Modell; beide haben seit AS2a/AS2b ein Modell, die
   Vorbedingung der Prüfung stimmt nicht mehr. `leistung` zählt 35 statt 34 Knotenbauten. Beides gehört R3; am Modell
   ist nichts zu ändern (Abschnitt 7).
5. **`LOOK` hat keinen gemeinsamen Ort.** Fahrzeug-Ebene, Kontaktbogen und Showroom setzen ihn je für sich; die
   Modellwerte aus Punkt 2 hängen daran. Vorschlag wie die Kritik: eine Konstante in `ModernMaterials`.
