
## 16. Nacharbeit nach der Kunstkritik der Bauabschnitte 3 und 4 (AS2R)

Die unabhängige Kritik der Pkw von AS2a (KRITIK-2) hat ihre Befunde mit Messwerten und Bildern belegt. Jeder Befund
wurde vor der Änderung am Netz oder im Bild nachgeprüft; was am Modell lag, ist geändert. Lackbelichtung,
unbeleuchtete Lampen (`lamp_off`), Metallic-Flocken, die Nacht-Signatur ohne Flares und der Look im Showroom liegen
im Renderer (R1/R3/R4/UI1) und sind dort offen. Die Lkw, Busse und Polizeiautos von AS2b wurden mit derselben
Strenge geprüft (Spielkamera 20/60/150 m bei Tag und Nacht neben dem Arcade-Quader bzw. -Sprite, Blaulicht,
Stufenwechsel).

| Befund (Kritik) | Ursache (geprüft) | Änderung | Messung vorher -> nachher |
|---|---|---|---|
| Transporter `lod2`: obere Kastenhälfte ganz Glas (B2) | Normalenregel `far_glass`: jede Fläche der Kabine über der Gürtellinie, die nicht Dach ist, wurde Scheibe | `car_surfaces(far_windows=...)`: die Heckscheibe wird entlang der Kontur des Entwurfs geschnitten, Seitenscheiben nur im Bereich der Seitenfenster (Flächen an dessen erstem und letztem y geteilt) | Wechsel bei 120 m (Tag, mit Renn-Look): 46,4 -> 12,0 % (90 / 160 m: 42,7 / 52,5 -> 9,6 / 15,8 %) |
| SUV und Flotte: Kabine in `lod2` eine dunkle Kappe samt Säulen (B2, Flotte) | dieselbe Regel: das ganze Heckende der Kabine wurde Glas | wie oben – die Säulen bleiben Lack | SUV 32,3 -> 29,8 %, Limousine 26,9 -> 14,4 %, Schrägheck 35,7 -> 22,4 %, Kombi 31,4 -> 6,9 %; nachts (120 m) SUV 14,1 -> 4,5 %, Transporter 30,1 -> 3,6 % |
| Budget von `lod2` (1 200) | der Schnitt der Heckscheibe in die Fächer der Endkappe kostete 50–280 Dreiecke | Endkappen von `lod2` als Bänder (`carbody`-Hook `cap_strips`, Sprite unverändert); Räder von `lod2` als Lauffläche + eine Scheibe in der Mischfarbe von Reifen und Felge (12 Dreiecke je Rad weniger); feinere Kabine (`gstep` 60) bei Sportwagen, Schrägheck, Kombi | alle `lod2` ≤ 1 197 / 1 200 |
| Stufenwechsel bei 40 m mit Renn-Look (B4) | `lod1` zeichnet die Scheiben als `vpbr`, das den Himmel halb so stark spiegelt wie die Klasse `glass` von `lod0`: die Scheiben waren 20–27 Stufen dunkler | eigene Scheibenfarbe der fernen Stufen `TRAFFIC_GLASS_FAR` (`#3a4652`), gemessen auf die mittlere Farbe der `lod0`-Scheibe abgestimmt | Transporter 17,8 -> 4,2 % (25 / 60 m: 20,8 / 16,8 -> 8,0 / 5,8 %), Sportwagen 13,3 -> 11,4 %; Scheibe des Transporters in 40 m: (76, 97, 127) in lod0 gegen (49, 73, 107) -> (70, 94, 130) in lod1 |
| Weiße Verkehrsautos und Polizei ohne Form (B1) | `#ececea`/`#e8e8e5`/`#e6e6e3`/`#f2f2ef` erscheinen in der Sonne als reines Weiß; `truck3d._tone` galt nur für Lkw und Bus | `_tone` (höchstens `#d8d8d6`) auch für die Farbsets der Pkw und die Lackierungsfarben der Polizei | Transporter weiß, 10 m: Pixel mit allen Kanälen ≥ 250: 22 473 -> 7 565 (der Rest ist Belichtung, R1/R3) |
| SUV-Front: weiße Sägezähne an der Stoßfängerkante (B3) | Stoßfänger dunkel erst unter 0,42 m, Karosserie (Schweller) schon unter 0,47 m: wo das runde Stoßfängerende in die Karosserie läuft, kreuzten sich die weiße und die schwarze Fläche | im 3D-Entwurf reicht der dunkle Teil der Stoßfänger bis zur Schwellerlinie | im Nahbild keine Zähne mehr (Bild 16) |
| SUV-Rückstrahler unsichtbar (B6) | als Teil der Rückleuchtenliste in den Karosserie-Loft 3 cm hinter der Stoßfängerhaut geschnitten | auf den Stoßfänger (`bumper_decals_3d`), auch in `lod2` (`far_reflectors`) | sichtbarer Anteil (Strahltest der Kritik): 0 -> 100 % |
| Rückfahrlicht Kombi und Kompakt unsichtbar (A6) | Kombi: das weiße Feld lag 0,3 mm unter der roten Füllung; Kompakt: Nebel- und Rückfahrleuchte als Mulde unter der Diffusorplatte | Kombi: Feld 1,7 mm vor der Füllung; Kompakt: beide Leuchten auf der Platte (3D-Hooks, Sprite unverändert) | sichtbar 10 % -> 100 % bzw. 0 % -> 100 % |
| GT nachts nur eine dünne Linie (A2) | Leuchtenkörper 6–15 mm innerhalb der Streuscheibe, Lichtleiste 6 mm hoch | im 3D-Bau füllt der Leuchtenkörper die Streuscheibe (3 mm Rand), die Lichtleiste ist 12 mm hoch | rote Pixel in 8 m: Rücklicht 353 -> 477, Bremse 587 -> 716 (Arcade 733 / 957) |
| Vorderrad Sportwagen und GT im Kotflügel (A5) | `SmoothCar.frame()` beginnt den Querschnitt unter der Schulter, die tiefer liegt als die Reifenoberkante | `vehicles3d._clear_front_arches`: die Ecken des Kotflügels über dem Vorderrad werden auf den Kreis Reifenradius + 25 mm gezogen | Ecken im Reifen (Werkzeug der Kritik): 114 / 71 bei 0° -> 0 bei 0° und ±7° (`show` bei ±25°: 2 bzw. 1) |
| Silberne Felgen fast weiß (A7) | Metall spiegelt mit `env_energy` 1,6 den hellen Himmel | Felgenfarbe Kombi `#7a7e84`, GT `#83878d` | – |
| Kontaktbogen: `--look=race` ohne Wirkung (C2) | `set_class_parameter` erreicht nur vorhandene Materialien | der Kontaktbogen legt die Klassenmaterialien vorher an | race gegen neutral: 0 -> 31 429 Pixel verschieden |

Nicht geändert: die Diffusor-Finnen (A8, niedrig; unter dem Heck, aus der Spielkamera kaum zu sehen), der
Schattenwerfer ohne Außenspiegel und das fehlende Rückfahrlicht von Sportwagen und GT (A9, nur im Showroom).

**Lkw, Bus, Polizei (Prüfung AS2R):** In der Spielkamera (20 / 60 / 150 m, Tag und Nacht, neben dem Arcade-Quader
bzw. -Sprite) stimmen Hecks, Lampen und Blaulicht A/B mit Arcade überein. Gemessen mit Renn-Look, Tag, an den
Wechselabständen: Planen-Sattelzug 2,2 / 1,1 % und Bus 6,8 / 21,7 % (60 / 180 m), Polizei Deutschland 14,3 /
20,4 % und Belgien 19,9 / 38,1 % (40 / 120 m; AS2b ohne Look: Plane 2,4 / 1,2 %, Bus 6,7 / 23,2 %, Deutschland
13,8 / 35,6 %, Belgien 18,8 / 59,0 %). Bei 40 m sind es bei der Polizei vor allem Kennzeichenzeichen, Wörter und
Lichtbalken, die es nur in `lod0` gibt.

- **Scheiben von Bus und Lkw in den fernen Stufen:** wie bei den Pkw (B4) als `vpbr` dunkler als das Glas von `lod0`;
  die Heckscheibe des Busses änderte beim Wechsel bei 60 m 43 % ihrer Pixel (`lod0` (78, 97, 121), `lod1`
  (59, 77, 100)). `truck3d.GLASS_FAR` (= `traffic3d.TRAFFIC_GLASS_FAR`) für `lod1`/`lod2` von Lkw und Bus:
  `lod1` (73, 93, 119), 0,1 % der Scheibenpixel; Bus bei 60 m 11,0 -> 6,8 % (gemessen).
- **Polizei, Heck in `lod2`:** Heckscheibe nach der Kontur (`far_windows="rear"`; die Seitenteilung hat im Budget
  keinen Platz neben Lackierung und Lichtbalken), Tschechien behält die Normalenregel (`catalog3d.POLICE_SPEC_CC`,
  mit Schnitt 1 204 / 1 200 Dreiecke).
- **Polizei, Karoband in der Ferne:** Das linear gemittelte Band kam heller heraus als die Karos daneben – die gelbe
  Zelle liegt in der Schulter der Tonkurve (Belgien, 120 m: `lod2` (201, 201, 136) gegen `lod1` (174, 178, 125),
  Mittel in linearem Licht über das Band). `police3d._hex_mix` nimmt jetzt das Potenzmittel mit Exponent
  `CHECK_MEAN_EXP` = 0,6: `lod2` (171, 180, 121) gegen (173, 178, 124). Der Anteil geänderter Pixel bleibt 38,1 %:
  Jede Zelle eines Pixels ist gelb oder blau, das Band einfarbig – diese Zahl misst hier die Textur, nicht die
  Helligkeit.
- **Offen:** Der Lichtbalken von `lod0` (Glaskuppel mit Himmelsspiegelung) ist bei Tag heller als die Blöcke von
  `lod1` – unbeleuchtet zeigt eine Lampe `lamp_off` × Leuchtfarbe, eine hellere Leuchtfarbe änderte das Blaulicht
  (gehört zu `lamp_off`, Renderer). Die zwei breiten Gitterstäbe im `lod2` des Busses (Budget 1 500 / 1 500) lesen
  sich anders als die sechs feinen von `lod1`. Weiß übersteuert (Renderer).

**Was mit dem Renn-Look gemessen ist:** `TRAFFIC_GLASS_FAR` (und `truck3d.GLASS_FAR`), `FAR_PLATE` und `CHECK_MEAN_EXP` sind auf `LOOK` der
Fahrzeug-Ebene (`env_energy` 1,6, `paint_base` 0,9, Glas 2,2) und das Licht des Kontaktbogens abgestimmt. Ändern sich
Look, Belichtung oder Tonkurve, sind sie neu zu messen (mittlere Farbe von Scheibe, Kennzeichen und Karoband in
beiden Stufen an den Wechselabständen).

**Kennzeichen und Zählweise:** Mit `FAR_PLATE` `#a2a2a0` stimmt die mittlere Helligkeit; die Zählung geänderter
Pixel steigt dadurch bei 25–60 m etwas (SUV 40 m 5,6 -> 6,8 %, Limousine 13,2 -> 14,4 %), weil die weißen Pixel des
`lod0`-Kennzeichens jetzt mehr als 24 Stufen vom grauen Feld entfernt sind. Bei 40 m entfallen 2–4 Prozentpunkte des
Wechsels auf das Kennzeichen. Bei der Limousine bleiben 11 Punkte außerhalb von Kennzeichen und Scheibe; nach dem
Differenzbild liegen sie vor allem auf den Fugen des Kofferraumdeckels (6 mm, bei 40 m ein Zehntel Pixel), die
`lod0` als Treppenlinie zeigt und `lod1` weglässt.
