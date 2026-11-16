# AS2R – Nacharbeit der Fahrzeugmodelle nach der Kunstkritik: Bericht

- Paket: AS2R (v0.8.0, Vorstart M2) · Zweig `worktree-wf_72970c4d-66e-4` · Sicherheitskopie `origin wip/v080-as2r`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4`
- Basis: `19624cd` (AS2a + AS2b, ff). Commits: `7c86864` (C2), `a79f959`, `d5a62a2`, `ecff521`, `8039c36`, `77cea90` (WIP-Stände), `2faa219` (Lkw/Bus-Scheiben, Doku), `c7546c1` (Ende: nur Umbruch der Doku); alle auf `origin wip/v080-as2r` gesichert
- **gemessen** = auf dieser VM gemessen (Software-OpenGL llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader `vpbr`/`glass`
  über `ModelFactory`, das Licht-Rig des Kontaktbogens mit dem **Renn-Look** der Fahrzeug-Ebene). **abgeleitet** =
  hier nicht messbar (echte Grafikkarte, Steam Deck, das Licht von R1/R4, die Wirkung auf einen Menschen).
- Werkzeug der Vergleiche: der Renderer und die Auswertungen der Kritik KRITIK-2 (`kritik_render.gd`, `sheet_*.py`,
  `mesh_analysis.py`, `lamp_vis.py`), unverändert kopiert und auf diesen Arbeitsbaum gerichtet, dazu eigene kleine
  Auswertungen (Abschnitt 11). Die Zahlen „vorher“ sind die der Kritik (gleiche Werkzeuge, Stand vor AS2R) oder
  eigene Messungen vor der jeweiligen Änderung.

## 1. Ergebnis in Kürze

Jeder Befund der Kritik wurde vor der Änderung am Netz, mit dem Strahltest oder im Bild nachgeprüft. Kein Befund war
falsch, keiner ist abgelehnt. Alle hohen und mittleren Befunde, die am Modell liegen, sind behoben; von den niedrigen
A6, A7 und B6, nicht aber A8 (Diffusor-Finnen), A9 und der Kleinkram von B7 (Abschnitt 3). Bei dreien lag die
Ursache anders als vermutet: B3 (nicht die Kontur der Verkleidung, sondern zwei verschiedene Kunststoff-Höhen von
Stoßfänger und Schweller), B6 (die Rückstrahler waren in den Karosserie-Loft hinter dem Stoßfänger geschnitten) und
A6 beim Kompakt (die Diffusorplatte lag über den Leuchten).

Was der Spieler am meisten sieht, und was sich dort geändert hat (gemessen mit den Werkzeugen der Kritik, Renn-Look):

- **Verkehr in 90–160 m:** Die ferne Stufe hat jetzt Heckscheiben nach der Kontur des Entwurfs mit Säulen in Lack,
  der Transporter keine Glaskiste mehr. Wechsel bei 120 m: Transporter 46,4 -> 12,0 %, Kombi 31,4 -> 6,9 %, Limousine
  26,9 -> 14,4 %, Schrägheck 35,7 -> 22,4 %, Sportwagen 31,6 -> 28,4 %, SUV 32,3 -> 29,8 %; nachts SUV 14,1 -> 4,5 %,
  Transporter 30,1 -> 3,6 %. Alle `lod2` bleiben im Budget (höchstens 1 197 / 1 200).
- **Verkehr in 25–60 m:** Die Scheiben von `lod1` haben die Farbe, die das Glas von `lod0` mit dem Renn-Look zeigt:
  Transporter 17,8 -> 4,2 % bei 40 m (25 m: 20,8 -> 8,0 %), Sportwagen 13,3 -> 11,4 %.
- **Weiß:** Die weißen Verkehrsautos und 16 der 18 Polizeiautos (weiß oder fast weiß) sind wie Lkw und Bus auf
  `#d8d8d6` begrenzt. Transporter in 10 m: Pixel mit allen Kanälen ≥ 250 22 473 -> 7 565. Der Rest ist Belichtung
  (Renderer).
- **Spielerheck nachts:** Der GT leuchtet nicht mehr nur als dünne Linie (Rücklicht 353 -> 477, Bremse 587 -> 716
  rote Pixel in 8 m; Arcade 733 / 957). Die Rückfahrlichter von Kombi und Kompakt sind zu sehen (Strahltest 10 bzw.
  0 % -> 100 %).
- **Seitlich und im Showroom:** Sportwagen und GT haben über dem Vorderrad Luft: 0 Ecken im Reifen bei 0° und ±7°
  (vorher 114 Ecken bis 84 mm bzw. 71 bis 61 mm). Die SUV-Front hat keine Sägezähne mehr, die SUV-Rückstrahler sind
  sichtbar (0 -> 100 %).

Unverändert, weil sie im Renderer liegen: Lackbelichtung (Kompakt 87 %, Sportwagen 55 % geclippt), unbeleuchtete
Lampen mit `lamp_off` 0,5, Flocken des GT, Nacht ohne Flares, der Look im Showroom (Abschnitt 8).

Lkw, Bus und Polizei (AS2b) habe ich mit derselben Strenge geprüft (Abschnitt 4). Hecks, Lampen, Blaulicht A/B
und die Stufen stimmen mit Arcade überein. Behoben habe ich:

- das Weiß der Polizei (wie oben);
- die ferne Heckscheibe der Polizei;
- die fernen Scheiben von Bus und Lkw: Wechsel des Busses bei 60 m 11,0 -> 6,8 %, die Heckscheibe ändert statt
  43 % noch 0,1 % ihrer Pixel;
- das Karoband der Polizei in der Ferne: Es war 27–33 Stufen zu hell, jetzt höchstens 13;
- das Kennzeichen der fernen Stufen.

Offen bleiben der hellere Lichtbalken von `lod0` bei Tag und das Lüftungsgitter des Busses in `lod2` (beides
gemessen und begründet).

**Eine Zahl ist schlechter geworden:** Mit dem dunkleren fernen Kennzeichen steigt die Zählung der Kritik beim
Wechsel bei 25–60 m um etwa 1 Punkt (SUV bei 25 m 2,6). Die mittlere Helligkeit stimmt dafür (Abschnitt 5).

`showroom` bleibt bei allen fünf Spielerautos `false` (Abschnitt 6). Gates: Prüfer grün, Sprite-Geometrie 61 von 61 identisch, Export deterministisch (auch nach den letzten Änderungen), 594 Unit-Tests ohne Fehler, Golden 20 von 20 identisch; rot nur die zwei bekannten Prüfungen `kasten`/`leistung` von R3 (Abschnitt 7).

## 2. Befunde der Kritik: geprüft, Ursache, Änderung, Messung

Reihenfolge wie die Kritik (zuerst das Heck der Spielerautos, dann der Verkehr in 20–150 m). „gemessen“ mit den
Werkzeugen der Kritik; „vorher“ = Zahlen der Kritik.

| Nr. | Befund | geprüft | Ursache | Änderung | Ergebnis (gemessen) |
|---|---|---|---|---|---|
| A1 | Lack zu hell/satt, geclippt | bestätigt (Bild 01: Kompakt 87 %, Sportwagen 55 % geclippt, unverändert) | Licht und Belichtung: Sonne, Umgebung und Füll-Licht 0,7 werden addiert; die Lackwerte sind die des Sprites | keine am Modell (Renderer, Abschnitt 8) | – |
| A2 | Rück- und Bremslicht nachts kleiner und dunkler als Arcade (alle), beim GT nur eine dünne Linie | bestätigt; GT: Leuchtenkörper 6–15 mm innerhalb der Streuscheibe, Lichtleiste 6 mm hoch | alle: keine Flares/kein Glow für das Spielerauto (R3), kein Nacht-Füll-Licht (R4); GT: Entwurf des Sprites (dort trägt die Leuchtschicht mit Glow) | GT (Modellteil): 3D-Hook in `player_cars`, Leuchtenkörper füllt die Streuscheibe bis 3 mm an den Rand, Lichtleiste 12 mm; der Rest ist Renderer | rote Pixel in 8 m, GT: Rücklicht 353 -> 477, Bremse 587 -> 716 (Arcade 733 / 957); die anderen vier unverändert 536–690 / 949–1 052 (Arcade 1 061–1 617 / 1 197–2 034) |
| A3 | unbeleuchtete Lampen wirken an | bestätigt | `lamp_off` 0,5 im Shader | keine am Modell (R3) | – |
| A4 | Metallic-Flocken blinken (GT) | bestätigt (Bild 16, Zeile 2) | Zellen kleiner als ein Pixel, `flake_near_m` 14 m | keine am Modell (R3) | – |
| A5 | Vorderrad Sportwagen/GT im Kotflügel, Falte | bestätigt: 114 / 71 Ecken bis 84 / 61 mm im Reifen | `SmoothCar.frame()` beginnt den Querschnitt unter der Schulter (0,672 / 0,715 m), die tiefer liegt als die Reifenoberkante (0,684 / 0,70 m): der Bogen des Radlaufs wird bis 0,60 / 0,64 m abgeschnitten | `vehicles3d._clear_front_arches` (nur 3D): die Ecken des Kotflügels über dem Vorderrad (außen, über der Achse, innerhalb des Kreises Radius + 25 mm) werden auf diesen Kreis gezogen; die Fläche bleibt geschlossen, die Lippe wandert mit | Werkzeug der Kritik: 0 Ecken im Reifen bei 0°, ±7°, ±15°, ±25° in `lod0`; `show` nur bei ±25°: 2 Ecken / 15 mm bzw. 1 / 6 mm (Bild 21) |
| A6 | Rückfahrlicht Kombi/Kompakt unsichtbar | bestätigt (Strahltest 10 % / 0 %) | Kombi: das weiße Feld lag 0,3 mm unter der roten Füllung; Kompakt: **Ursache anders** – keine Lippe, sondern die Diffusorplatte, die über den Mulden von Nebel- und Rückfahrleuchte lag | Kombi: Feld 1,7 mm vor der Füllung; Kompakt: beide Leuchten auf der Platte statt als Mulde, Platte 0,7 mm tiefer (3D-Hooks) | Strahltest: 100 % / 100 % sichtbar (Bild 16) |
| A7 | silberne Felgen fast weiß | bestätigt | Metall spiegelt mit `env_energy` 1,6 den hellen Himmel | Felgenfarbe im 3D-Bau: Kombi `#8e9297` -> `#7a7e84`, GT `#9a9ea3` -> `#83878d` | Bild 03 (Showroom-A/B) |
| A8 | Diffusor-Finnen als Kamm | bestätigt | frei hängende Plättchen des Generators | **nicht geändert** (niedrig; unter dem Heck, aus der Spielkamera kaum sichtbar) | – |
| A9 | Kleinkram (Werfer ohne Spiegel, kein Rückfahrlicht bei Sportwagen/GT) | bestätigt | – | nicht geändert (niedrig, nur Showroom) | – |
| B1 | weiße Lacke ohne Form | bestätigt | `truck3d._tone` galt nur für Lkw und Bus | `_tone` für die Farbsets der Pkw (Transporter, SUV, Schrägheck, Kombi weiß) und für die Lackierungsfarben der Polizei (16 von 18 weiß oder fast weiß) | Transporter weiß 10 m, Pixel ≥ 250: 22 473 -> 7 565 (Rest: Belichtung) |
| B2 | Transporter `lod2` als Glaskasten; SUV-Kabine dunkle Kappe | bestätigt | Normalenregel `far_glass` der fernen Stufe | `decalgeo.car_surfaces(far_windows=True)`: Heckscheibe nach der Kontur des Entwurfs (ein Schnitt mit den Kabinen-Decals), Seitenscheiben nur im y-Bereich der Seitenfenster; Endkappen von `lod2` als Bänder (`carbody`-Hook `cap_strips`), ferne Räder einfacher, feinere Kabine bei Sportwagen/Schrägheck/Kombi – alles im Budget | 120 m: Transporter 46,4 -> 12,0 %, SUV 32,3 -> 29,8 % (Bild 13) |
| B3 | SUV-Front: Sägezähne | bestätigt; **Ursache anders** als vermutet (nicht die Kontur der Verkleidung) | Stoßfänger dunkel erst unter 0,42 m, Schweller schon unter 0,47 m – am runden Stoßfängerende kreuzten sich die weiße und die schwarze Fläche | dunkler Teil der Stoßfänger bis zur Schwellerlinie (3D-Entwurf) | keine Zähne mehr (Bild 16) |
| B4 | Wechsel bei 40 m mit Renn-Look 17–21 % | bestätigt; Scheibe in 40 m: `lod0` (76, 97, 127) gegen `lod1` (49, 73, 107) | `vpbr` spiegelt den Himmel etwa halb so stark wie die Klasse `glass` | eigene Scheibenfarbe der fernen Stufen `TRAFFIC_GLASS_FAR` `#3a4652` (gemessen abgestimmt), auch für Lkw und Bus (Abschnitt 4) | `lod1`-Scheibe (70, 94, 130); 40 m: Transporter 17,8 -> 4,2 %, Sportwagen 13,3 -> 11,4 % |
| B5 | wie A3 | – | – | keine am Modell | – |
| B6 | SUV-Rückstrahler unsichtbar | bestätigt; **Ursache genauer** | als Teil der Rückleuchtenliste in den Karosserie-Loft 3 cm hinter der Stoßfängerhaut geschnitten | auf den Stoßfänger (`bumper_decals_3d`), auch in `lod2` (`far_reflectors`) | sichtbar 0 -> 100 % |
| B7 | Kleinkram (Kennzeichen-Zeichen wie Balken, sechseckige Räder in `lod2`, Ecken im Vorderreifen des Verkehrs-Sportwagens ab ±7°) | bestätigt | – | nicht geändert (niedrig; der Verkehr lenkt unter 2°); `lod2`-Räder jetzt Lauffläche + Scheibe, weiter sechseckig | – |
| Flotte | Limousine/Schrägheck/Kombi 120 m 27–36 % | bestätigt | wie B2 | wie B2 | 26,9 / 35,7 / 31,4 -> 14,4 / 22,4 / 6,9 % |
| C2 | Kontaktbogen: `--look=race` wirkungslos | bestätigt (pixelgleich) | `set_class_parameter` erreicht nur vorhandene Materialien | Kontaktbogen legt die Klassenmaterialien vor dem Look an | race gegen neutral: 0 -> 31 429 Pixel verschieden |
| C3 | Prüfer zählt verdeckte Lampen | bestätigt | Regel nach Wicklung, nicht nach Sichtbarkeit | die drei verdeckten Lampen sind sichtbar gemacht; die Regel selbst ist eine Vertragsfrage (Abschnitt 9) | – |

Zusätzlich gefunden und behoben: Das graue Kennzeichen der fernen Stufen (`#c4c4c1`) kam in 40 m 50 Stufen heller
heraus als das `lod0`-Kennzeichen (dessen Weiß übersteuert, die Zeichen bleiben dunkel): `#a2a2a0` ergibt den
angezeigten Mittelwert (Limousine, Spielkamera: `lod0` 192, `lod1` vorher 242, jetzt 199). Die Zählung der Kritik
steigt dadurch bei 25–60 m um etwa einen Punkt (Abschnitt 5).

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

## 4. Selbstprüfung Lkw, Bus, Polizei (Modelle von AS2b)

Geprüft wie die Kritik die Pkw: Spielkamera 20 / 60 / 150 m bei Tag und nachts (Rücklicht, Bremse + Blinker,
Rücklicht + Blaulicht A) neben dem Arcade-Quader bzw. -Sprite, mit Renn-Look (Kontaktbogen `--chase --arcade`, jetzt
mit wirksamem Look); jede Lampe einzeln nachts; Tagbogen aller Stufen; Stufenwechsel mit dem Werkzeug der Kritik an
den Wechselabständen der Modelle (Lkw und Bus 60 / 180 m, Polizei 40 / 120 m). Modelle: Koffer-, Planen- und
Autotransporter-Sattelzug, Bus, Polizei Deutschland, Belgien, Italien, Österreich, Niederlande (Tag alle 18).

**Was stimmt (gesehen, Bögen `h_*` und `08_kontaktbogen_polizei_tag.jpg`):** Hecks in 20 m in Lage und Farbe wie
Arcade: Rückleuchten, Kennzeichen, Konturmarkierung, Verschlussstangen und Unterfahrschutz (Lkw), Lüftungsgitter und
Heckscheibe (Bus), Lichtbalken mit Kuppeln und Heckwort (Polizei). Die Aufbauten sind bei Tag heller als der
Arcade-Quader (Belichtung wie A1). Nachts sind Rück-, Brems-, Blink- und Kennzeichenlicht getrennt, die
Konturmarkierung leuchtet, Blaulicht A links und B rechts schalten einzeln, und der Lichtbalken leuchtet in allen
Stufen an derselben Stelle. In 150 m sind alle als Umriss mit Rückleuchten lesbar. Der Planen-Sattelzug wechselt
praktisch unsichtbar.

**Gefunden und behoben:**

1. **Weiß der Polizei** (wie B1): 16 der 18 Lackierungen sind weiß oder fast weiß und kamen als reines Weiß ohne
   Form heraus – jetzt mit `_tone` begrenzt wie Lkw, Bus und Verkehr.
2. **Heck der Polizei in `lod2`:** Die Normalenregel machte die ganze Rückseite der Kabine samt Säulen dunkel (wie
   B2). Jetzt die Heckscheibe nach der Kontur des Entwurfs (`far_windows="rear"`); Tschechien behält wegen des
   Budgets die Normalenregel.
3. **Karoband der Polizei in der Ferne (neu):** Das linear gemittelte Band kam mit dem Renn-Look 27–33 Stufen heller
   heraus als die Karos daneben; jetzt Potenzmittel (`CHECK_MEAN_EXP` 0,6). Belgien, 120 m, Mittel über das Band:
   `lod2` (201, 201, 136) gegen `lod1` (174, 178, 125) -> (171, 180, 121) gegen (173, 178, 124), gemessen.
4. **Scheiben von Bus und Lkw in den fernen Stufen (wie B4, neu):** Sie waren als `vpbr` dunkler als das Glas von
   `lod0`; die Heckscheibe des Busses änderte beim Wechsel bei 60 m 43 % ihrer Pixel. Jetzt die ferne Scheibenfarbe des
   Verkehrs (`truck3d.GLASS_FAR`): Heckscheibe in 60 m `lod0` (78, 97, 121), `lod1` vorher (59, 77, 100), jetzt
   (73, 93, 119).
5. **Kennzeichen der fernen Stufen** der Polizei (über `traffic3d.FAR_PLATE`, Abschnitt 2).

**Stufenwechsel** (gemessen, Spielkamera 1280 × 720, Tag, Renn-Look; Anteil der Fahrzeugpixel, die sich um mehr als
24 Stufen ändern):

| Modell | nah | fern | AS2b (ohne Look, zum Vergleich) |
|---|---|---|---|
| `police/de` | 40 m: 14,3 % | 120 m: 20,4 % | 13,8 / 35,6 % |
| `police/be` | 40 m: 19,9 % | 120 m: 38,1 % (Band jetzt gleich hell, Abschnitt 5) | 18,8 / 59,0 % |
| `police/ch` | – | 120 m: 33,6 % | – |
| `traffic/bus` | 60 m: 11,0 % -> 6,8 % | 180 m: 21,1 % -> 21,7 % (beide Stufen mit der neuen Scheibe) | 6,7 / 23,2 % |
| `traffic/truck_tarp` | 60 m: 2,2 % (unverändert, von hinten keine Scheibe) | 180 m: 1,1 % | 2,4 / 1,2 % |

Die Zahlen von AS2b sind ohne Renn-Look gemessen (C2) und nur grob vergleichbar. Bei 40 m bleiben bei der Polizei
vor allem Kennzeichenzeichen, Wörter und der Lichtbalken, die es nur in `lod0` gibt; bei 120 m die Karos (jede Zelle
ein Pixel, gelb oder blau, gegen ein einfarbiges Band – die Zählung misst dort Textur, nicht Helligkeit).

**Offen (gemessen, begründet):**

- Lichtbalken: Die Glaskuppel von `lod0` ist bei Tag heller als die Blöcke von `lod1` (`lamp_off`, Renderer;
  Abschnitt 3).
- Bus bei 180 m (21 %): vor allem die zwei breiten Gitterstäbe von `lod2` gegen die sechs feinen von `lod1`, die in
  zweieinhalb Pixeln zu einem Grau verschwimmen. Eine Fläche in der Mischfarbe ginge nicht (die Lackfarbe kommt je
  Set aus dem Lack-Slot), drei schmalere Stäbe kosten Dreiecke, und `lod2` liegt auf 1 500 / 1 500.
- Kennzeichen von Lkw und Bus in `lod2` (`heavy3d.FAR_PLATE` `#c4c4c1`): nicht an den Pkw-Wert angeglichen (ab
  180 m ein bis zwei Pixel).

## 5. Messungen

Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL, Renn-Look, Werkzeuge der Kritik), „vorher“ = Zahlen der
Kritik bzw. eigene Messung vor der Änderung.

**Stufenwechsel der Pkw** (Spielkamera 1280 × 720, MSAA 2×, Anteil der Autopixel, die sich um mehr als 24 Stufen
ändern; Farbsets wie die Kritik):

| Typ | 25 m | 40 m | 60 m | 90 m | 120 m | 160 m | Nacht 40 / 120 m |
|---|---|---|---|---|---|---|---|
| SUV | 4,8 -> 7,4 | 5,6 -> 6,8 | 5,6 -> 6,7 | 23,8 -> 12,8 | 32,3 -> 29,8 | 23,3 -> 11,8 | 3,4 / 14,1 -> 3,5 / 4,5 |
| Transporter | 20,8 -> 8,0 | 17,8 -> 4,2 | 16,8 -> 5,8 | 42,7 -> 9,6 | **46,4 -> 12,0** | **52,5 -> 15,8** | 1,9 / 30,1 -> 1,8 / 3,6 |
| Sportwagen | 16,3 -> 12,3 | 13,3 -> 11,4 | 19,1 -> 8,1 | 28,2 -> 22,7 | 31,6 -> 28,4 | 24,1 -> 15,5 | 3,6 / 3,7 -> 3,6 / 4,5 |
| Limousine | – | 13,2 -> 14,4 | – | – | 26,9 -> 14,4 | – | – |
| Schrägheck | – | 7,3 -> 8,2 | – | – | 35,7 -> 22,4 | – | – |
| Kombi | – | 5,8 -> 6,8 | – | – | 31,4 -> 6,9 | – | – |

Was bei 25–60 m bleibt, aufgeteilt (gemessen, `pop_split.py`): das Kennzeichen 2–5 Prozentpunkte (Zeichen gegen
graues Feld), die Scheibe 0,2–2,4, der Rest Umriss und Kleinteile. **Hier ist eine Zahl schlechter geworden:** Mit
dem dunkleren fernen Kennzeichen (`#a2a2a0`, Abschnitt 2) stimmt die mittlere Helligkeit (`lod0` 192, `lod1` vorher
242, jetzt 199), aber die weißen Pixel des `lod0`-Kennzeichens liegen jetzt mehr als 24 Stufen vom grauen Feld
entfernt: SUV, Limousine, Schrägheck und Kombi bei 40 m je etwa 1 Punkt mehr, SUV bei 25 m 2,6 Punkte. Ich halte
die gleiche mittlere Helligkeit für das kleinere Springen (bei 40 m ist das Kennzeichen 9 × 2 Pixel groß, das Auge
mittelt); das ist **abgeleitet**, nicht gemessen. Bei der Limousine liegen 11 der 14,4 Punkte außerhalb von
Kennzeichen und Scheibe, nach dem Differenzbild vor allem auf den Fugen des Kofferraumdeckels (6 mm, bei 40 m ein
Zehntel Pixel), die `lod0` als Treppenlinie zeigt. SUV bei 120 m (29,8 %): 13 der 37 geänderten Pixel sind Umriss
(Radläufe und Reling von `lod2` schmaler), dazu Scheibe und Kante unter der Scheibe 20–30 Stufen dunkler (gröbere
Normalen von `lod2`).

**Spielerheck nachts, 8 m** (rote Lampenpixel Rücklicht / Bremse, gemessen): GT 353 / 587 -> 477 / 716 (Arcade
733 / 957); Kombi 536 / 991, Sportwagen 690 / 1 052, Limousine 555 / 1 000, Kompakt 538 / 949 (unverändert; Arcade
1 617 / 2 034, 1 061 / 1 197, 1 369 / 1 656, 1 193 / 1 479).

**Silhouette gegen das Sprite** (9 m, unverändert nach A2/A5): IoU Kombi 0,992, Sportwagen 0,992, GT 0,990,
Limousine 0,994, Kompakt 0,989.

**Radfreiheit** (Ecken im Reifenvolumen, Werkzeug der Kritik): Sportwagen und GT `lod0` 0 bei 0°, ±7°, ±15°, ±25°
(vorher 114 / 71 Ecken bis 84 / 61 mm bei 0°); `show` 0 bis ±15°, bei ±25° 2 Ecken / 15 mm bzw. 1 / 6 mm.

**Lampen sichtbar** (Strahltest der Kritik): Rückfahrlicht Kombi 10 -> 100 %, Kompakt 0 -> 100 %; SUV-Rückstrahler
0 -> 100 %.

**Weiß** (Transporter weiß, 10 m, Pixel mit allen Kanälen ≥ 250): 22 473 -> 7 565.

**Scheiben, Kennzeichen, Karoband** (mittlere Farbe in linearem Licht gemittelt):

| Stelle | `lod0` bzw. nahe Stufe | ferne Stufe vorher | ferne Stufe jetzt |
|---|---|---|---|
| Transporter, Heckscheibe, 40 m | (76, 97, 127) | (49, 73, 107) | (70, 94, 130) |
| Bus, Heckscheibe, 60 m | (78, 97, 121) | (59, 77, 100) | (73, 93, 119) |
| Limousine, Kennzeichen, 40 m (Helligkeit) | 192 | 242 | 199 |
| Polizei Belgien, Karoband, 120 m | (173, 178, 124) | (201, 201, 136) | (171, 180, 121) |

**Budgets** (Manifest = Prüfer, gemessen): Spieler `lod0` 46 805–54 306 / 55 000, `show` 94 983–117 206 / 120 000;
Verkehr `lod0` 17 459–17 748 / 18 000, `lod1` 5 661–5 941 / 6 000, `lod2` 1 164–1 197 / 1 200; Polizei `lod0`
19 778–21 970 / 22 000, `lod1` 5 331–5 975 / 6 000, `lod2` 1 061–1 196 / 1 200; Lkw/Bus unverändert (`lod2` Bus
1 500 / 1 500). Schattenwerfer unverändert.

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

## 7. Gates

| Gate | Ergebnis (gemessen) |
|---|---|
| Prüfer `validate_models.py --report` | **CHECK models OK** – 37 Modelle, 180 Sets (65 mit Modell, 115 Platzhalter), Netze 16,45 MB von 40 MB, Texturen 4,59 MB von 240 MB, Quellen 1,43 MB von 60 MB; alle Budgets eingehalten (Abschnitt 5) |
| Determinismus, alle Fahrzeuge (14:10) | erzwungener Export + Bake von Spieler, Verkehr, Polizei: `git status` leer (byte-gleich mit dem Commit), zweiter Bake byte-gleich (213 Dateien), `--check-keys` grün |
| Determinismus nach den letzten Änderungen (Polizei, Lkw, Bus) | erzwungener Export + Bake von Polizei (18), Lkw (3) und Bus nach Commit `2faa219`: `git status` leer, zweiter Bake byte-gleich (142 Dateien), `--check-keys` grün |
| `check_sprite_geometry.py --only player,showroom,traffic,police --jobs 1` | **61 von 61 Sets identisch** (404 s); `carbody` hat den neuen Hook `cap_strips` mit Voreinstellung aus, `player_cars` nur 3D-Hooks |
| Arcade-Dateien | unberührt (Regel 1); kein Sprite neu gerendert |
| Kontaktbögen Tag und Nacht | Bilder 04–09, mit wirksamem Renn-Look (C2), angesehen |
| Showroom-A/B | Bild 03; Schalter bleiben `false` (Abschnitt 6) |
| `tools/run_tests.sh` (einmal) | 613 s: 241 Skripte fehlerfrei, **594 Unit-Tests, 0 fehlgeschlagen**, 79 CHECK-Zeilen, davon **2 rot** in `tests/race3d/check_vehicles.gd` (R3): `kasten` (erwartet Sets ohne Modell als Kasten – jedes Fahrzeug-Set hat jetzt ein Modell) und `leistung` (35 statt 34 Knotenbauten). Dieselben zwei wie bei AS2b; Exit 1 nur deswegen (Abschnitt 9) |
| `tools/golden.sh check` (einmal, am Ende) | **GOLDEN arcade: 20 von 20 identisch** (185 s) |

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

## 10. Bilder in diesem Ordner

Alle mit den Spiel-Shadern und dem Renn-Look, Software-OpenGL; was ein Mensch auf echter Hardware sieht, ist
abgeleitet. Die Bilder 01, 02, 10, 13 und 16 sind die Vergleichsansichten der Kritik, mit ihren Werkzeugen und
Beschriftungen neu gerendert (die Beschriftungen von Bild 16 nennen die Mängel, die Bilder zeigen den neuen Stand).

| Datei | Inhalt |
|---|---|
| `01_spieler_spielkamera_sprite_gegen_modern.jpg` | Spielerautos in 9 m: Arcade-Sprite, Modern mit Renn-Look, neutral, Silhouette; 8 m im Spielbild, „Niedrig“, 30 m |
| `02_spieler_nacht_und_bremse.jpg` | 8 m nachts: Arcade gegen Modern, Rück- und Bremslicht; Tag mit und ohne Bremse (A2: GT) |
| `03_showroom_ab.jpg` | Showroom-A/B: Echtzeit-Stufe `show` gegen das Cycles-Sprite, dieselbe Kamera (AgX) |
| `04_kontaktbogen_spieler_tag.jpg`, `05_kontaktbogen_spieler_nacht.jpg` | alle Stufen bei Tag; nachts jede Lampe einzeln |
| `06_kontaktbogen_verkehr_tag.jpg`, `07_kontaktbogen_verkehr_nacht.jpg` | sechs Verkehrstypen, alle Stufen und Farbsets; nachts SUV, Transporter, Sportwagen je Lampe |
| `08_kontaktbogen_polizei_tag.jpg` | alle 18 Polizeiautos (`lod0`, Heck und Front) |
| `09_lampenkanaele.jpg` | Lampenkanäle 0–14 des Shaders (Prüfbild) |
| `10_verkehr_spielkamera_sprite_gegen_modern.jpg` | SUV, Transporter, Sportwagen in 10/30/80/120 m: Arcade gegen Modern |
| `13_stufenwechsel.jpg` | SUV, Transporter, Sportwagen: Wechsel bei 40 und 120 m, Tag und Nacht, mit Differenzbild (B2, B4); bei SUV und Sportwagen bleibt bei 120 m vor allem ein Ring am Umriss |
| `16_maengel_belege.jpg` | die Stellen von A5, A4, A6, B1–B3, A8 im neuen Stand |
| `21_radlauf_sportwagen_gt.jpg` | A5: Vorderrad von Sportwagen und GT, seitlich, von schräg unten und im Schnitt |
| `30_polizei_de_spielkamera.jpg`, `31_polizei_be_spielkamera.jpg` | Polizei in 20 / 60 / 150 m, Tag und Nacht (Rücklicht, Bremse + Blinker, Blaulicht A), neben dem Arcade-Sprite |
| `32_bus_spielkamera.jpg`, `33_planen_lkw_spielkamera.jpg` | Bus und Planen-Sattelzug ebenso, neben dem Arcade-Quader |
| `34_polizei_be_120m_karoband.jpg` | Wechsel bei 120 m, Belgien: Karos gegen das Band in der neuen Mischfarbe |
| `35_bus_60m_heckscheibe.jpg` | Wechsel bei 60 m, Bus: Heckscheibe mit `GLASS_FAR` |
| `36_suv_120m_rest.jpg` | Wechsel bei 120 m, SUV: was bleibt (Umriss, Normalen; Stand vor dem dunkleren Kennzeichen, das in beiden Stufen gleich ist) |

## 11. Geänderte Dateien und Werkzeuge

Code und Doku (seit `19624cd`): `tools/blender/ce3d/decalgeo.py` (ferne Fenster nach der Kontur, `split_coord`,
Rückstrahler), `traffic3d.py` (ferne Scheibe und Kennzeichen, `cap_strips`, Räder von `lod2`, `_tone`, SUV-Entwurf),
`catalog3d.py` (Kabinen-Stationen von `lod2`, `POLICE_SPEC_CC`), `police3d.py` (`_tone`, `far_windows`,
`CHECK_MEAN_EXP`), `truck3d.py` und `heavy3d.py` (`GLASS_FAR`), `vehicles3d.py` (Felgen, `_clear_front_arches`),
`tools/blender/cesprites/carbody.py` (Hook `cap_strips`, Voreinstellung aus), `cesprites/player_cars.py` (nur
3D-Hooks: GT-Rücklicht, Rückfahrlichter), `tools/models/contact_sheet.gd` (C2), `docs/modelle.md` (Abschnitte 11–16).
Modelle: alle Spieler-, Verkehrs-, Polizei-, Lkw- und Busmodelle neu gebaut (120 Dateien unter `assets/models`,
Manifest).

Werkzeuge (Arbeitsordner `…/scratchpad/v080/m1/AS2R/`, nicht im Repository):

- `bin/rebuild.sh "<glob>" [--force]` – Export, Bake, Manifest, Prüfer (nice 19, ein Prozess);
  `bin/sheet.sh <abs.png> <Kontaktbogen-Argumente>`; `bin/gates.sh`, `bin/gates3.sh`, `bin/final_gates.sh`.
- `kritik/` – die Werkzeuge der Kritik, auf diesen Arbeitsbaum gerichtet: `run_jobs.sh`, `round.sh` (alle
  Vergleichsansichten), `probe.sh <tag> <m> <lodA> <lodB> <sets…>` (Stufenwechsel eines Sets mit Bogen und Zahl),
  `bin/pop_split.py` (Wechsel aufgeteilt in Kennzeichen / Scheibe / Rest), `bin/bandmean.py`, `bin/buswin.py`,
  `bin/winmean.py`, `bin/platemean.py` (mittlere Farben). `kritik/tools_kritik/kritik_render.gd` (und
  `kritik_dump.gd`) muss dafür nach `tools/kritik/` einer Arbeitskopie (unversioniert, nie committen); aus meinem
  Arbeitsbaum ist der Ordner wieder entfernt, `git status` ist leer.
