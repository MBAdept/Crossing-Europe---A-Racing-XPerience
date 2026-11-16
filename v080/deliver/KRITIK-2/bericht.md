# KRITIK-2 – Unabhängige Kunstkritik der Pkw-Modelle von AS2a

- Gegenstand: Zweig `worktree-wf_72970c4d-66e-1`, Stand `19aa138` (nur gelesen). Gerendert und gemessen in einer
  Kopie im Arbeitsordner (`diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits, kein Zweig, keine Datei des
  Arbeitsbaums geändert.
- Modelle: Spielerautos `kombi`, `sportwagen`, `gran_turismo` (neu), `limousine`, `kompakt` (neu gebaut: Innenraum,
  Glas, Felgen); Verkehr `suv`, `van`, `sports` (neu); zum Vergleich der Flotte `sedan`, `hatch`, `wagon` (AS1R).
- **gemessen** = auf dieser VM gemessen (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader `vpbr`/`glass` über
  `ModelFactory`, dazu der Renn-Look der Fahrzeug-Ebene von R3: `LOOK`, `PLAYER_FILL`, Kontaktschatten).
  **abgeleitet** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen Menschen, das Licht von R1/R4,
  das es auf diesem Zweig nicht gibt).
- Licht: das kleine Rig des Kontaktbogens (eine Sonne mit Schatten, Himmel, Umgebungslicht, linearer Tonemapper,
  Nachbearbeitung an; Nacht: Mond 0,1, Umgebung 0,55, Glow) – wie bei AS1-KRITIK, damit die Zahlen vergleichbar sind.
  Für den Showroom zusätzlich das Studio-Licht von UI1 (`showroom_3d.gd`, nachgebaut). **Ohne** Flares (R3) und ohne
  das Nachtlicht von R4: Aussagen zu Nacht und Belichtung gelten für dieses Rig.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Autos sichtbar feiner als die Arcade-Sprites, und kann man sie stundenlang ansehen?**

- **Feiner: ja – in Form, Schärfe und Detail.** Die Silhouetten decken sich mit den Sprites (Spielerautos in 9 m:
  Überdeckung 0,989–0,994; neue Verkehrsautos in der Sprite-Kamera 0,94–0,96, der Rest ist der Bodenschatten im
  Sprite; gemessen). Modern zeigt echte Perspektive und dreht stufenlos, Kennzeichen und Embleme sind lesbar, die
  Rückleuchten laufen sichtbar um die Ecke, durch das Glas sieht man Sitze und Kopfstützen. Nachts sind Rück-,
  Brems-, Blink- und Kennzeichenlicht sauber getrennt. Netz, Räder, Lenk- und Drehachsen, Schattenwerfer, Budgets und
  Prüfer sind in Ordnung (Abschnitt 4).
- **Schöner: noch nicht.** Das Auge sieht zuerst den Lack – und der ist zu hell und zu bunt. Gemessen in 9 m gegen
  das Cycles-Sprite: Kompakt Bernstein → Zitronengelb (Farbton 43° → 54°, 87 % der Lackpixel geclippt), Sportwagen
  55 % geclippt, Limousine Helligkeit 0,48 → 0,74, Kombi 0,30 → 0,45. Die Hauptursache ist das Licht (Sonne,
  Umgebung und Füll-Licht 0,7 werden addiert): Mit neutralem Shader sind Sportwagen und Kompakt genauso übersteuert.
  Der Klarlack des Renn-Looks legt bei Limousine und GT noch 0,1 Helligkeit drauf. Am Netz liegt es nicht. Das ist der
  Befund A1 von AS1-KRITIK, und er ist mit R3 **nicht** besser geworden. Dazu wirken unbeleuchtete Lampen bei Tag
  eingeschaltet.
- **Modellfehler, die man sieht** (Abschnitt 3, Bild 16):
  - Sportwagen und Gran Turismo: Der Vorderreifen liegt oben am Radlauf an, darüber eine Falte im Kotflügel; im
    Netz stecken 114 bzw. 71 Ecken bis 84 bzw. 61 mm im Reifen. Im Showroom und in Seitenansichten sichtbar, aus der
    Spielkamera nicht.
  - Gran Turismo: Die Metallic-Flocken blinken im Spielbild (83 Glitzerpixel je Bild, die bei jeder Bewegung neu
    springen).
  - Transporter `lod2`: Die ganze obere Kastenhälfte wird Glas – beim Wechsel ab 90 m ändert sich die Hälfte der
    Autopixel.
  - Weiße Verkehrsautos ohne jede Form (reines Weiß).
  - SUV-Front mit Sägezähnen.
  - Kombi und Kompakt: Rückfahrlicht unsichtbar.
- **Urteil je Modell** (gegen das Arcade-Sprite):

  | Modell | Urteil | was es trägt | was es kostet |
  |---|---|---|---|
  | Kombi | **feiner** | sauberes Heck, Leuchten um die Ecke, Felgen, Dachreling | Lack zu hell; Rückfahrlicht unsichtbar |
  | Limousine | **feiner** | ruhige Form, Lichtband, sauberer Radlauf | Lack zu hell, Felgen zu hell |
  | Kompakt | gleichwertig | Details, Leuchten | Zitronengelb statt Bernstein (Renderer) |
  | Sportwagen | gleichwertig | runde Leuchten nachts, Flügel, Einlässe | Radlauf vorn, Lack pink-rot |
  | Gran Turismo | gleichwertig, in Bewegung schlechter | Lichtleiste, Turbinenfelgen | Flocken blinken, Radlauf vorn, dünne Nachtsignatur |
  | SUV, Sportwagen (Verkehr) | gleichwertig | bis 30 m klar besser | weiß ohne Form, Lampen bei Tag „an“, Stufe 120 m |
  | Transporter | bis 80 m gleichwertig, ab 90 m schlechter | Türen, Eckleuchten | `lod2` als Glaskasten, weiß ohne Form |

- **Showroom-Schalter: `false` bleibt richtig – aber aus anderen Gründen, als AS2a meint.**
  - Das A/B von AS2a lief ohne Renn-Look: Der Kontaktbogen setzt ihn vor dem ersten Material, `--look=race` und
    `--look=neutral` sind pixelgleich (gemessen, Bild 20, C2).
  - Der Showroom von UI1 setzt den Renn-Look nicht. Mit neutralem Shader wird das Silber des GT ein dunkles Grau
    (Bild 08, Spalte 4).
  - Mit Renn-Look und dem Studio-Licht von UI1 sind Kombi und Limousine dem Sprite **nahe**: Form gleich, Lack und
    Glas etwas flacher, kein Umgebungsschatten.
  - Sportwagen und GT verlieren am vorderen Radlauf, der Kompakt am Gelb.
  - Empfehlung: Sobald UI1/R3 den Look im Showroom setzen, mit diesem Rig neu entscheiden – Kombi und Limousine
    zuerst.
- **Stundenlang ansehbar?**
  - Bei Tag aus der Spielkamera: Kombi, Limousine, Kompakt und Sportwagen ja, sobald R3/R1 die Lackbelichtung und die
    unbeleuchteten Lampen im Griff haben. Der GT erst ohne das Flockenblinken.
  - Nachts: erst mit Flares und Nachtlicht (R3/R4). Ohne Flares hat das Rücklicht nur 36–60 % der leuchtenden Fläche
    des Arcade-Sprites (gemessen), die Karosserie ist schwarz.

## 2. Wie geprüft wurde

Eigenes Werkzeug in der Kopie, nie eingecheckt: `tools/kritik/kritik_render.gd` (Jobliste → ein PNG je Kachel;
Grundlage ist der Renderer von AS1-KRITIK) und `kritik_dump.gd` (Netze → numpy), aufbewahrt im Arbeitsordner unter
`m1/KRITIK-2/tools_kritik/`.

- **Neu gegenüber AS1-KRITIK:**
  - der Renn-Look der Fahrzeug-Ebene, gelesen aus `layers/vehicles.gd`: `LOOK`, Füll-Licht `PLAYER_FILL` 0,7 für
    die Spielerautos, gespiegelte Umgebung aus dem Himmel des Rigs;
  - der weiche Kontaktschatten, den R3 unter jedes Auto legt;
  - das Studio von UI1 (Key 1,05 mit Schatten, Fill, zwei Randlichter, AgX) und die Kamera der Showroom-Sprites;
  - Schnittbilder (Ebene je Knoten), ein Modus „Karosserie wirft den Schatten“ und ein Modus „Glas ausgeblendet“.
- **Kameras:**
  - Spielkamera nach D12: 1280 × 720, Brennweite 711 px, 3,4 m hoch, Horizont bei 45 %, MSAA 2× wie „Mittel“ und
    „Steam Deck“; dazu Voreinstellung „Niedrig“ (75 %, ohne MSAA) und überabgetastete Fassungen.
  - Sprite-Kamera der Verkehrsautos: orthografisch, 9°, Drehpunkt am Heck.
  - Showroom-Kamera der Cycles-Sprites: 142°, 56 mm, 11°.
  - Orbit-Kamera für Nahansichten.
- **Sprite-Vergleich:** Das Arcade-Bild liegt so, wie `road_renderer.gd` es zeichnet: Spieler mit Anker auf dem
  Bodenpunkt der Wagenmitte und Maßstab Kameraabstand / Tiefe / Überabtastung, Verkehr mit Heckanker und
  711 / (Abstand · 52 px/m). Lage und Größe stimmen (Silhouetten unten). Beim Verkehr zeigt das Sprite die
  9°-Orthoansicht, Modern echte Perspektive: Spiegel und Dach wirken im Sprite breiter – das ist kein Fehler.
- **Netzanalyse in numpy** (`out/mesh_analysis.txt`, `lamp_visibility.txt`, `dup_check.txt`):
  - Wicklung, offene Kanten, deckungsgleiche Flächen mit verschiedener Farbe (z-Kampf);
  - Rundlauf der Räder;
  - Freigang Reifen ↔ Karosserie samt Innenraum, drehend und gelenkt (0°, ±7° wie im Rennen, ±15°, ±25°);
  - Innenraum gegen die Außenhülle;
  - Lampenflächen je Kanal und ihr **sichtbarer** Anteil (Strahl von jeder Lampenfläche zum Betrachter, Glas zählt
    als durchsichtig).
- **Umfang:** etwa 1 450 Renderbilder, gemessen gut 45 min Rechenzeit (`nice 19`, die Maschine war mit drei
  anderen Aufträgen geteilt, Last 6–10). Prüfer gelaufen (`validate_models.py --report`).
- **Ein Fehler im eigenen Werkzeug, gefunden und behoben:** Der Renn-Look wurde gesetzt, bevor die Materialien der
  Klassen existierten – `ModernMaterials.set_class_parameter` wirkt nur auf vorhandene Materialien, also wirkte er
  nicht. Alle betroffenen Bilder sind neu gerendert. **Derselbe Fehler steckt im Kontaktbogen von AS2a**
  (`tools/models/contact_sheet.gd`: `_apply_look()` direkt nach `ModernMaterials.new()`, vor dem ersten Material):
  dessen Bilder mit „Renn-Look“ zeigen in Wahrheit den neutralen Shader (gemessen: `--look=race` und `--look=neutral`
  sind pixelgleich, Bild 20; Abschnitt 5, C2).

## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS2a-N** = Nacharbeit der Modelle (AS2a oder Nachfolger), **R3** = Fahrzeug-Shader und
Fahrzeugebene, **R1/R4** = Licht und Belichtung, **UI1** = Showroom. Bilder in diesem Ordner.

### A. Spielerautos – das Heck in 8–9 m ist die ganze Spielzeit im Bild

**A1 – hoch – Lack zu hell, zu satt, geclippt (alle fünf; R3 + R1)**
- Was: Gemessen in 9 m, Sprite-Auflösung, Pixel mit dem Farbton des Lacks (Sprite → Modern mit Renn-Look):

  | Auto | Lack | Helligkeit V | Sättigung | Farbton | Lackpixel mit einem Kanal bei 255 |
  |---|---|---|---|---|---|
  | Kombi | `#1d6b45` | 0,30 → 0,45 | 0,55 → 0,73 | 152° → 159° | 0 % |
  | Sportwagen | `#cc1419` | 0,58 → 0,94 | 0,63 → 0,74 | 354° → 351° | 55 % |
  | Gran Turismo | `#b2b7bd` | 0,64 → 0,71 | 0,12 → 0,17 | 212° → 215° | 24 % |
  | Limousine | `#1d4ea8` | 0,48 → 0,74 | 0,59 → 0,74 | 221° → 219° | 25 % |
  | Kompakt | `#f0b30a` | 0,72 → 0,96 | 0,77 → 0,81 | **43° → 54°** | **87 %** |

  Mit neutralem Shader (gemessen): Sportwagen 49 %, Kompakt 85 % geclippt – das Licht allein übersteuert. Bei Limousine
  und GT legt der Klarlack des Renn-Looks 0,1 Helligkeit drauf (Limousine geclippt 1 % → 25 %). Die Lackwerte im
  Manifest sind richtig (dieselben wie im Sprite).
- Beleg: `01_spieler_spielkamera_sprite_gegen_modern.jpg` (Spalten 1–3).
- Behebung (R3/R1): helle Lacke weich begrenzen, statt sie zu clippen. Das Füll-Licht 0,7 nur im eigenen Schatten
  wirken lassen, nicht auf sonnenbeschienene Flächen. Danach mit dem Licht von R1 neu messen. Messgröße: unter 5 %
  geclippte Lackpixel, Farbton ±3° zum Sprite. (Offen seit AS1-KRITIK A1.)

**A2 – hoch (Nacht) – Rück- und Bremslicht kleiner und dunkler als in Arcade (alle; R3, AS2a-N beim GT)**
- Was: Spielkamera 8 m, rote Lampenpixel. Rücklicht Modern 353–690 px gegen das Arcade-Sprite (Schicht `tail`)
  733–1 617 px, also 36–60 %. Bremse Modern 587–1 052 px gegen 957–2 034 px. Gemessen ohne Flares.
- Beim GT leuchtet nachts nur eine dünne Linie.
- Die Karosserie bleibt nachts fast schwarz: Füll-Licht 0,7 × Nacht-Umgebung. Arcade hebt sein Spielerauto an
  (Modulation × 1,15 + 0,08).
- Beleg: `02_spieler_nacht_und_bremse.jpg`.
- Behebung:
  - R3: die Flares (F6) auch für das Spielerauto, mit Halo um die ganze Leuchte;
  - R4: ein Nacht-Füll-Licht für das Spielerauto;
  - AS2a-N (GT): die Lichtleiste höher machen (jetzt 226 cm² Kanal 2 von hinten, die anderen Spielerautos
    612–763 cm²).

**A3 – mittel – unbeleuchtete Lampen wirken bei Tag eingeschaltet (alle; R3)**
- Was: Bremse an/aus bei Tag hebt die Helligkeit der Lampenpixel nur um das 1,3- bis 1,6-Fache (gemessen, 8 m),
  weil unbeleuchtete Lampen mit `lamp_off` 0,5 kräftig rot sind.
- Beleg: Bild 01 (Rückleuchten bei Tag hellrot), Bild 02 (rechte Spalten).
- Behebung (R3): `lamp_off` 0,25–0,3 für die Kanäle 0–4; die Bremse bekommt bei Tag einen Schein wie in Arcade.
  (Offen seit AS1-KRITIK B1.)

**A4 – mittel (GT) – Metallic-Flocken blinken im Spielbild (R3)**
- Was: Gemessen in 8 m, Gierschritte von 0,2°: 78–92 Glitzerpixel je Bild auf der Kofferraumkante. Von einem Bild
  zum nächsten gehen 149–167 Pixel an oder aus – fast jeder Glitzerpunkt springt.
- Ursache: Eine Flockenzelle (260 je m) ist in 8 m kleiner als ein Drittel Pixel. Die Flocken wirken bis 14 m;
  MSAA glättet keine Schattierung.
- Kombi und Limousine (Metall 0,55) und die anderen Autos: 0 Glitzerpixel.
- Beleg: `19_lack_flocken_flimmern.jpg`, Bild 16.
- Behebung (R3): `flake_near_m` auf etwa 3 m senken (Flocken nur im Showroom und ganz nah), oder die Zellgröße an
  den Pixel-Fußabdruck koppeln (`fwidth`); sonst `flake_strength` 0 im Renn-Look.

**A5 – mittel – Sportwagen und Gran Turismo: Vorderrad oben im Kotflügel, Falte über dem Radlauf (AS2a-N)**
- Was: Die Radlaufkante liegt am Scheitel auf dem Reifen, ohne Spalt. Darüber knickt die Schulterkante zu einer
  sichtbaren Falte (Delle mit Schattierungssprung). Von schräg unten und vorn verschwindet der Reifen oben im
  Kotflügel.
- Gemessen (Netz, Lenkwinkel 0°): Sportwagen 114 Ecken bis 84 mm tief im Reifen, GT 71 Ecken bis 61 mm, jeweils am
  Reifenscheitel (−30° … +40°); show-Stufe genauso. Kombi, Limousine und Kompakt: 0.
- Sichtbar im Showroom, in Seitenansichten und beim Einscheren; aus der Spielkamera nicht. AS2a schreibt „von außen
  verdeckt“ – das stimmt nur für die Ecken selbst, nicht für die Falte und den anliegenden Radlauf.
- Beleg: `16_maengel_belege.jpg` (A5), `04_nah_sportwagen.jpg`, `05_nah_gran_turismo.jpg` (Vorderrad).
- Behebung (3D-Hook, das Sprite bleibt): den vorderen Radlauf im 3D-Bau mit Reifenradius + 25–30 mm ausschneiden.
  Die Schulterkante vor dem Radlauf auslaufen lassen (Flare statt Knick). Den Freigangs-Test des Exports auf Ecken
  über dem Reifen erweitern: mindestens 20 mm bei 0° und ±7°.

**A6 – niedrig – Rückfahrlicht unsichtbar (Kombi, Kompakt; AS2a-N + Prüfer)**
- Was: Kombi: die 47 Dreiecke des Rückfahrlichts liegen 0–1 mm **unter** der roten Fläche der Rückleuchte
  (Kanal 2). Strahltest: 10 % sichtbar; nachts mit Rückfahrlicht ändert sich **kein** Pixel (gemessen). Kompakt: das
  Feld sitzt unten in einer Mulde (y 0,33 m) und bleibt verdeckt, 0 Pixel Änderung. Der Prüfer zählt die Fläche
  trotzdem (41 bzw. 17 cm²).
- Für das Spiel ohne Folgen (der Spieler fährt nie rückwärts), für den Showroom und die Regel nicht.
- Beleg: Bild 16 (A6), `out/lamp_visibility.txt`.
- Behebung: Das weiße Feld vor die rote Fläche legen (mindestens 1,5 mm Abstand) und die rote Fläche dort
  ausschneiden. Der Prüfer sollte die **sichtbare** Lampenfläche messen (Strahltest wie `bin/lamp_vis.py`), nicht
  die Fläche nach Wicklung.

**A7 – niedrig – Felgen der silbernen Autos fast weiß (Kombi, GT; R3)**
- Was: Die Felgen spiegeln mit `env_energy` 1,6 den hellen Himmel und werden weiß. Im Sprite sind sie mittelgrau mit
  dunklen Speichenzwischenräumen.
- Beleg: Bild 03 und 05 (Rad).
- Behebung: Felgen-Albedo etwas dunkler, oder bei Metall die Umgebung schwächer spiegeln (Faktor 0,6).

**A8 – niedrig – Diffusor-Finnen als Kamm unter dem Heck (Sportwagen, GT, Kompakt; AS2a-N)**
- Was: dünne senkrechte Plättchen unter dem Stoßfänger, im Ton- und Nahbild wie ein Kamm. Aus der Spielkamera
  kaum zu sehen. (AS1-KRITIK A10, unverändert.)
- Behebung: als flache Rippen auf einer Diffusorplatte, nicht frei hängend.

**A9 – niedrig – Kleinkram**
- Der Schattenwerfer hat keine Außenspiegel: Ihr Schatten fehlt am Boden. Sonst deckt sich der Schatten des Werfers
  mit dem der Karosserie (Bild 18).
- Sportwagen und GT haben kein Rückfahrlicht. Der Spieler fährt nie rückwärts; nur für den Showroom relevant.
- Deckungsgleiche Flächen mit verschiedener Farbe: 0–25 je Netz, zusammen höchstens 7,8 cm². Meist Brems- auf
  Rücklichtrot, ohne sichtbaren z-Kampf (`out/dup_check.txt`).

### B. Neue Verkehrsautos – von hinten, 10–150 m

**B1 – hoch – weiße Lackierungen ohne Form (`suv_white`, `van_white`, auch `hatch_white`, `wagon_white`; AS2a-N + R3)**
- Was: Die Lacke `#ececea`, `#e8e8e5` und `#e6e6e3` werden in der Sonne reines Weiß. Gemessen beim Transporter in
  10 m: 22 473 Pixel mit allen Kanälen ≥ 250 – die ganze Hecktür ist eine Fläche ohne Schattierung, mit und ohne
  Renn-Look. Für den Lkw hat AS1R das schon gelöst (`truck3d._tone`: fast weiß wird auf `#d8d8d6` begrenzt), für
  die Pkw nicht.
- Beleg: Bild 16 (B1), Bilder 10, 12 und 15.
- Behebung: `_tone` auch auf die Farbsets der Pkw anwenden (AS2a-N, eine Zeile in `traffic3d`/`catalog3d`). Danach
  wie A1 die Belichtung (R3/R1).

**B2 – mittel bis hoch – Transporter `lod2`: die ganze obere Kastenhälfte wird Glas (AS2a-N)**
- Was: Die Normalenregel für die Scheiben von `lod2` (`far_glass`) macht beim Transporter Seiten und Heck oberhalb
  der Gürtellinie dunkel – aus dem weißen Kastenwagen wird ein Kleinbus mit getönten Scheiben.
- Gemessen beim Wechsel `lod1` → `lod2` (Anteil der Autopixel, die sich um mehr als 24 Stufen ändern):
  - Tag: 42,7 / 46,4 / 52,5 % bei 90 / 120 / 160 m;
  - Nacht, 120 m: 30,1 %;
  - zum Vergleich SUV 23–32 %, Sportwagen 24–32 %, die AS1R-Typen 27–36 %.
- Beim SUV wird in `lod2` die ganze Kabine samt Säulen zur dunklen Kappe; die Dachreling schwebt darüber.
- Beleg: Bild 13, Bild 12 (Spalte `lod2`), Bild 16 (B2).
- Behebung: für den Transporter die Scheiben von `lod2` aus den Fensterkonturen des Entwurfs schneiden (Heckfenster,
  Frontscheibe, vordere Seitenfenster) statt nach der Normale. Beim SUV die Säulen in Lackfarbe und die Reling auf
  das Dach der Stufe setzen.

**B3 – mittel – SUV-Front: Sägezähne an der Unterkante des Stoßfängers (AS2a-N)**
- Was: Die Grenze Weiß/Schwarz an der Stoßfänger-Unterkante läuft als Zickzack. Am Eck hängen weiße Spitzen. Das ist
  der offene Punkt aus A-4 („cut along the contour“). Man sieht es bei Gegenverkehr und beim Überholen.
- Beleg: Bild 16 (B3), Bild 11.
- Behebung: die untere Verkleidung als eigene Kontur entlang der Kante schneiden, nicht nach Dreiecken des Lofts.

**B4 – mittel – Stufenwechsel bei 40 m mit Renn-Look größer als von AS2a gemessen (AS2a-N + R3)**
- Was: Mit dem Renn-Look ändern sich beim Wechsel `lod0` → `lod1` beim Transporter 17–21 % und beim Sportwagen
  13–19 % der Autopixel (25/40/60 m), beim SUV 5–6 %. AS2a maß 4,7 % und 9,3 % – ohne Renn-Look, Abschnitt 2.
- Ursache: Die Spiegelung auf Dach und Heckscheibe ist in den Stufen verschieden (`glass`-Klasse in `lod0`, dunkles
  `vpbr` in `lod1`). Beim Transporter kommt die Dachkante dazu.
- Beleg: Bild 13.
- Behebung: Rauheit und Metallwert des `lod1`-Glases an das `lod0`-Glas mit Renn-Look angleichen (beide bei
  gleichem `env_energy` messen). Danach die Wechsel mit dem Renn-Look neu messen.

**B5 – mittel – unbeleuchtete Lampen bei Tag (alle; R3)** – wie A3; bei 30 m ist die Bremse bei Tag kaum zu sehen
(Bild 10). Offen seit AS1-KRITIK B1.

**B6 – niedrig – SUV-Rückstrahler unsichtbar (AS2a-N + Prüfer)**
- Was: Die Rückstrahler (Kanal 0, Gewicht 0,3, 184 cm²) liegen 3 cm **im** Stoßfänger; Strahltest 0 % sichtbar in
  `lod0` und `lod1`. Der Prüfer zählt sie trotzdem.
- Behebung: auf die Stoßfängerhaut legen (wie A6).

**B7 – niedrig – Kleinkram**
- Kennzeichen des Verkehrs: Die Zeichen sind dicke Balken, nah wie ein Strichcode.
- `lod2`: sechseckige Räder und dreieckige Radausschnitte; ab 120 m unsichtbar.
- Verkehrs-Sportwagen: Ab ±7° Lenkung stecken 2–8 Ecken 16–36 mm im Vorderreifen. Der Verkehr lenkt unter 2°, also
  unsichtbar.
- Glas der Verkehrsautos: undurchsichtig dunkelblau, durch den Renn-Look jetzt mit Himmel; aus der Nähe flach, ab
  20 m unauffällig.

### C. Renderer und Werkzeuge (für die Leitung)

- **C1 – Showroom ohne Renn-Look (UI1/R3):** Abschnitt 5.
- **C2 – Kontaktbogen: `--look=race` wirkt nicht (AS2a-Werkzeug):** gemessen pixelgleich mit `--look=neutral`
  (Bild 20). Alle Bilder, Showroom-A/B und Stufenzahlen von AS2a, die „mit Renn-Look“ entstanden, zeigen den
  neutralen Shader. Behebung: in `contact_sheet.gd` vor `_apply_look()` `_mats.material("vpbr")` und
  `_mats.material("glass")` aufrufen, wie es die Fahrzeug-Ebene tut.
- **C3 – Lampenregel misst verdeckte Flächen (Prüfer):** Kombi- und Kompakt-Rückfahrlicht und SUV-Rückstrahler
  zählen mit, obwohl sie unsichtbar sind (A6, B6). Behebung: sichtbare Fläche per Strahltest
  (`bin/lamp_vis.py`, etwa 5 s je Modell).

## 4. Zahlen

**Prüfer:** `validate_models.py --report`: `CHECK models OK` – 16 Modelle, 180 Sets (44 mit Modell), Netze
10,28 MB von 40 MB (gemessen, `out/validator.txt`). Alle 26 Pkw-Verkehrssets, 5 Spieler- und 5 Showroom-Sets lösen
zu einem Modell auf; alle `showroom`-Flags `false` (gemessen am Manifest).

**Budgets §4.6.9 und Zeichenaufrufe** (gemessen, Manifest = Prüfer; Aufrufe = Flächen je Teil; im Bild bestätigt:
Primitive im Bild = Dreiecke der Stufe + 4 für Boden und Kontaktschatten):

| Modell | lod0 | lod1 | lod2 | show | Werfer | Aufrufe |
|---|---|---|---|---|---|---|
| player/kombi | 54 306 / 55 000 (98,7 %) | – | – | 117 206 / 120 000 | 2 320 / 3 000 | 6 / 6 |
| player/sportwagen | 46 940 | – | – | 95 375 | 2 320 | 6 / 6 |
| player/gran_turismo | 48 095 | – | – | 102 327 | 2 320 | 6 / 6 |
| player/limousine | 47 904 | – | – | 98 786 | 2 320 | 6 / 6 |
| player/kompakt | 49 155 | – | – | 106 649 | 2 320 | 6 / 6 |
| traffic/suv | 17 824 / 18 000 | 5 915 / 6 000 | 1 169 / 1 200 | – | 1 004 | 6 / 1 / 1 |
| traffic/van | 17 655 | 5 845 | 1 189 | – | 1 064 | 6 / 1 / 1 |
| traffic/sports | 17 751 | 5 741 | 1 194 (99,5 %) | – | 972 | 6 / 1 / 1 |

Dazu je Schattenkaskade ein Aufruf für den Werfer. Die `show`-Räder bekommen im Bild Godots automatische
Stufe (im Showroom 4 000–4 400 Dreiecke weniger als im Manifest) – richtig so.

**Netz** (gemessen, `out/mesh_analysis.txt`): keine entarteten Dreiecke; gegen die Normale gewickelt 0–2 je
sichtbarem Netz, 0–6 je Werfer (Grenze 8); Räder rund (Rollachse 0,0 mm aus der Mitte, Unrundheit 1–4 mm),
Unterkante aller Räder auf 0,0 mm. Innenraum 2 268–2 280 Dreiecke in `lod0` (Farbklassen von `carinterior.py`),
oberhalb der Radläufe liegt **keine** Innenraum-Ecke außerhalb der Außenhülle samt Glas; die Schnittbilder
(Bild 09) zeigen Sitze, Armaturenbrett, Lenkrad und Wanne sauber innen.

**Radfreiheit** (Karosserie und Innenraum im Reifenvolumen, gemessen):

| Modell | 0° | ±7° (Spieler im Rennen höchstens 7°) | ±25° |
|---|---|---|---|
| Kombi, Limousine, Kompakt, SUV, Transporter, Verkehrs-Limousine/-Schrägheck/-Kombi | 0 | 0 | 0 |
| Sportwagen (Spieler) | 114 Ecken, 84 mm | 73–94, 82–85 mm | 49–66, 79–89 mm |
| Gran Turismo | 71 Ecken, 61 mm | 38–53, 60–62 mm | 32–41, 56–66 mm |
| Sportwagen (Verkehr) | 0 | 2 Ecken, 27–36 mm | 2–8, 16–25 mm (Verkehr lenkt < 2°) |

**Lampen** (gemessen; Fläche von hinten / sichtbarer Anteil im Strahltest). Rücklicht + Bremse (Kanal 2), je Auto:
Kombi 612 cm², Sportwagen 619, GT 226, Limousine 656, Kompakt 763; SUV 591, Transporter 489, Sportwagen (Verkehr)
830. Blinker hinten 74–120 cm² je Seite, vorn 20–109 cm². Sichtbar: alle Kanäle der Verkehrsautos 82–100 %
(außer den SUV-Rückstrahlern, B6), Spieler-Rückleuchten 31–100 % je Teilkanal (Lichtleiter liegen bewusst über dem
Leuchtenkörper), Rückfahrlicht Kombi 10 %, Kompakt 0 % (A6). Lichtanker: Prüfer grün.

**Silhouette gegen das Sprite des Generators** (gemessen, gleiche Kamera, Sprite-Alpha > 0,9):

| Fall | Überdeckung (IoU) |
|---|---|
| Spielerautos, Spielkamera 9 m | Kombi 0,992 · Sportwagen 0,992 · GT 0,990 · Limousine 0,994 · Kompakt 0,989 |
| Showroom-Kamera, Stufe `show` | 0,954–0,967 (Rest: Bodenschatten im Sprite) |
| Verkehr, Sprite-Kamera 9°, `lod0` / `lod2` | SUV 0,950–0,955 / 0,930; Transporter 0,950–0,960 / 0,927–0,942; Sportwagen 0,938–0,945 / 0,937–0,945 |

**Stufenwechsel** (Spielkamera 1280 × 720, MSAA 2×, Anteil der Autopixel, die sich um mehr als 24 Stufen ändern;
gemessen mit dem Renn-Look):

| Typ | 25 m | 40 m | 60 m | 90 m | 120 m | 160 m | Nacht 40 / 120 m |
|---|---|---|---|---|---|---|---|
| SUV | 4,8 % | 5,6 % | 5,6 % | 23,8 % | 32,3 % | 23,3 % | 3,4 / 14,1 % |
| Transporter | 20,8 % | 17,8 % | 16,8 % | 42,7 % | **46,4 %** | **52,5 %** | 1,9 / 30,1 % |
| Sportwagen | 16,3 % | 13,3 % | 19,1 % | 28,2 % | 31,6 % | 24,1 % | 3,6 / 3,7 % |
| Limousine / Schrägheck / Kombi (AS1R) | – | 13,2 / 7,3 / 5,8 % | – | – | 26,9 / 35,7 / 31,4 % | – | – |

`lod0` → `lod1` bei 25/40/60 m („Details“ Niedrig/Mittel/Hoch), `lod1` → `lod2` bei 90/120/160 m. Bei 120 m ist ein
Auto 12–14 × 9–16 Pixel groß.

Bei 25/40/60 m (`lod0` → `lod1`) springt vor allem das Kennzeichen (Zeichen → graues Feld). Ab 90 m ist der
Wechsel beim Transporter am stärksten (B2).

## 5. Showroom-Schalter

Bild `08_showroom_ab.jpg`: Cycles-Showroom-Sprite gegen die Echtzeit-Stufe `show` aus derselben Kamera, drei Lichter.

- **Was AS2a gemessen hat, war nicht der Renn-Look.** Der Kontaktbogen setzt `LOOK`, bevor es ein Material gibt, und
  der Aufruf verpufft. Die A/B-Bilder von AS2a zeigen also den neutralen Shader – ohne Klarlack-Spiegelung, Grundlack
  1,0, ohne Flocken. Beleg: Bild 20 (gemessen pixelgleich).
- **Der Showroom von UI1 setzt den Renn-Look ebenfalls nicht** (`showroom_3d.gd` setzt nur die `ce_*`-Globals).
  Spalte 4 zeigt das Ergebnis: Das Silber des GT wird dunkles Anthrazit, alle Lacke flacher. Nach einem Rennen
  trüge das geteilte Material dagegen den Look samt dem Himmel der letzten Etappe, auch einer Nachtetappe. Wie der
  Showroom aussieht, hinge also davon ab, was vorher lief.
- **Mit Renn-Look und dem Studio von UI1** (Spalte 3) liegen alle fünf nahe am Sprite:
  - Form, Fugen, Felgen, Lampen und Kennzeichen sind gleich, das Glas zeigt den Innenraum.
  - Es fehlen weiche Umgebungsverdeckung unter dem Auto und in den Radhäusern sowie die feinen Spiegelungen der
    Seitenflächen.
  - Das Chrom des Grills spiegelt das magentafarbene Randlicht (rosa Grill).
- **Urteil:** `false` bleibt richtig, solange der Showroom den Look nicht selbst setzt. Danach neu entscheiden, mit
  diesem Rig:
  - Kombi und Limousine sind dann aus meiner Sicht gleichwertig (Kandidaten für `true`).
  - Kompakt erst, wenn das Gelb stimmt (A1).
  - Sportwagen und GT erst nach A5 (vorderer Radlauf). Der GT braucht außerdem den Look, sonst ist er dunkel.
- Behebung (UI1/R3): Der Showroom setzt beim Öffnen die `LOOK`-Werte der Fahrzeug-Ebene **und** eine eigene
  Umgebung (`env_zenith`, `env_horizon`, `env_ground` aus seinem Studiohimmel). Danach setzt das Rennen wieder seine
  Werte. Der Look gehört an eine Stelle, die beide lesen (z. B. eine Konstante in `ModernMaterials`).

## 6. Was gut ist

- **Maße und Proportionen:** gemessen deckungsgleich mit den Sprites (Abschnitt 4). Lenk- und Drehachsen sind
  richtig: Räder drehen um die Nabe und lenken um die Radmitte, ±25° ohne Versatz (Bild 18). Radunterkanten auf 0 mm.
- **Heck der Spielerautos aus der Spielkamera:** scharf, lesbares Kennzeichen, Embleme, Leuchten mit Tiefe, die um
  die Ecke laufen. Durch die Heckscheibe sieht man Kopfstützen (GT, Limousine). In der Voreinstellung „Niedrig“ ist
  es grober, bleibt aber lesbar (Bild 01).
- **Nachts:** Rück-, Brems-, Blink-, Rückfahr- (Limousine) und Kennzeichenlicht sauber getrennt, dritte Bremsleuchte
  bei allen. Die runden Leuchten des Sportwagens wirken als Ringe sehr gut (Bild 04).
- **Innenraum:** Sitze, Kopfstützen, Armaturenbrett, Lenkrad und Hutablage, nichts sticht durch die Haut. Für die
  Spielkamera reicht das.
- **Schatten:** Der Werfer deckt sich bis auf die Spiegel mit dem Schatten der Karosserie. Rücken-an-Rücken-Flächen
  und z-Kampf sind vernachlässigbar.
- **Verkehr:** SUV, Transporter und Sportwagen sind bis 30 m eindeutig erkennbar. Die Farbsets Schwarz, Braun, Grau,
  Dunkelblau, Rot und Silber sehen gut aus (Bild 15). Die Lampenkonturen bleiben über alle Stufen gleich (Bild 14).
  Der Wechsel bei 40 m ist beim SUV klein (5–6 %), nachts bei allen dreien (2–4 %).
- **Prüfer, Budgets, Zeichenaufrufe:** alle grün; die neuen Verkehrsautos nutzen das Budget fast ganz (97–99,5 %).

## 7. Bilder

| Datei | Inhalt |
|---|---|
| `01_spieler_spielkamera_sprite_gegen_modern.jpg` | Spielerautos in 9 m: Arcade-Sprite, Modern mit Renn-Look, Modern neutral, Silhouette; dazu 8 m im Spielbild, Voreinstellung „Niedrig“, 30 m |
| `02_spieler_nacht_und_bremse.jpg` | 8 m nachts: Arcade-Sprite mit `tail`/`brake` (Näherung) gegen Modern; Tag mit und ohne Bremse |
| `03_nah_kombi.jpg` … `07_nah_kompakt.jpg` | je Spielerauto 20 Nahansichten: Heck, Rückleuchte Tag/Nacht, jeder Lampenzustand, Kabine durch die Heckscheibe, Innenraum, Räder, Radhaus, Front, Scheinwerfer, Stufe `show` |
| `08_showroom_ab.jpg` | Showroom-A/B: Sprite, Kontaktbogen-Rig, Studio von UI1 mit und ohne Renn-Look, Silhouette |
| `09_spieler_netz.jpg` | Ton, Facetten, Drahtgitter, Prüfung (Rückseiten/Normalen), Lampenkanäle, Werfer, Schnitte durch Sitz und Achse |
| `10_verkehr_spielkamera_sprite_gegen_modern.jpg` | SUV, Transporter, Sportwagen in 10/30/80/120 m: Arcade gegen Modern, überabgetastet und im Spielbild |
| `11_verkehr_nah_und_stufen.jpg` | Nahansichten der neuen Verkehrsautos, `lod1`/`lod2` und ihre Drahtgitter |
| `12_verkehr_sprite_kamera.jpg` | Sprite-Kamera (9°, ortho, vierfach): Sprite gegen `lod0`/`lod1`/`lod2`, gerade und 24° |
| `13_stufenwechsel.jpg` | Wechsel bei 40 m und 120 m mit Differenzbild |
| `14_verkehr_lampen_je_stufe.jpg` | Lampenkanäle je Stufe von hinten und vorn |
| `15_verkehr_farbsets.jpg` | alle 13 Farbsets der neuen Typen |
| `16_maengel_belege.jpg` | die Mängel A5, A4, A6, B1–B3, A8 im Einzelnen |
| `17_flotte.jpg` | alle elf Pkw aus derselben Spielkamera in 30 m und in derselben Schrägansicht |
| `18_schatten_und_raeder.jpg` | Bodenschatten Werfer gegen Karosserie, Lenkung ±25°, gedrehtes Rad |
| `19_lack_flocken_flimmern.jpg` | Metallic-Flocken in 8 m: mit, ohne, Glitzerkarte zweier Nachbarbilder |
| `20_kontaktbogen_look_ohne_wirkung.jpg` | Kontaktbogen von AS2a mit `--look=race` und `--look=neutral` (pixelgleich) gegen den wirklich gesetzten Renn-Look |

## 8. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2/`:

- `tools_kritik/kritik_render.gd`, `kritik_dump.gd`, `run_jobs.sh` – zum Wiederverwenden nach `tools/kritik/` einer
  Arbeitskopie legen (`run_jobs.sh` erwartet die Kopie unter `./wt`). Jobfelder: `rig` (day/night/studio), `look` (race/neutral), `fill`, `contact`, `tonemap`,
  `section`, `params` (Klassen-Uniforms je Bild), `settle`.
- `bin/run_jobs.sh <jobs.json> <outdir> [--skip-existing]` (nur absolute Pfade), `bin/jobs_all.py` (Batches p, t,
  s), `jobs/x.json` (Flocken, Schnitte, Radhaus, Nacht-Stufen).
- Auswertungen: `bin/mesh_analysis.py`, `lamp_vis.py`, `lamp_occlusion.py`, `dup_check.py`, `flake_shimmer.py`;
  Bögen `bin/sheet_*.py`.
- Ergebnisse in `out/`: `mesh_analysis.txt`, `lamp_visibility.txt`, `dup_check.txt`, `validator.txt`,
  `player_game.txt`, `player_night.txt`, `lod_pop.txt`, `traffic_silhouette.txt`, `showroom_silhouette.txt`,
  `flake_shimmer.txt`, `shadow_compare.txt`.
- Eine Nacharbeitsrunde lässt sich mit denselben Jobs in etwa 30 min neu rendern (gemessen, geteilte Maschine).
  Kacheln und Netz-Abzüge sind gelöscht (Platz).

## 9. Abweichungen und Grenzen dieser Prüfung

- Licht: das Rig des Kontaktbogens (wie AS1-KRITIK), nicht das von R1/R4 – das gibt es auf diesem Zweig nicht.
  Lackhelligkeit, Nacht und Glanz im Rennen entscheiden R1/R3/R4. Die Zahlen gelten für dieses Rig, die Unterschiede
  zwischen Modellen und Stufen auch für andere.
- Ohne Flares (R3) und ohne Nachtlicht von R4: Die Nachtvergleiche unterschätzen Modern.
- Den Showroom von UI1 habe ich nachgebaut (Licht, Himmel, AgX, Kamera der Sprites), nicht das Widget selbst
  gerendert; der Drehteller fehlt.
- Nicht neu gemessen: die Sprite-Geometrie (187/187 laut AS2a), der Determinismus des Exports, `run_tests.sh` und
  `golden.sh`. Ich habe nichts geändert, was sie berühren könnte.
- Im Rennbild selbst (`tools/ab_shot.sh`) habe ich nicht gerendert: Auf diesem Zweig fehlen Straße und Licht von
  R1 (Gerüst-Renderer), die Fahrzeug-Ebene von R3 wurde über ihre Konstanten nachgebildet.
