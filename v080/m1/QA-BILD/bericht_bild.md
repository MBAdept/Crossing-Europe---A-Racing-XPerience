## 2. Bild: Modern gegen Arcade im selben Simulationszustand

Methode: `tools/ab_shot.sh`-Logik mit eigenem Aufruf (`m1/QA-BILD/tools/abf.sh`): beide Modi mit `--gfx-sync`, festen 60
Bildern/s, gleichem Seed, Aufnahmen nach 2 s und 6 s. Modern lief ebenfalls mit `--shot-fast` und 1,0 s Vorlauf –
geprüft an S2: Bild 00 pixelgleich zum Lauf ohne `--shot-fast`, Bild 01 3 Pixel verschieden (höchstens 15/255), M1 hat
keine Partikel. Voreinstellung „Mittel“ (die Empfehlung für einen Windows-PC mit brauchbarer Grafik), dazu Niedrig,
Hoch, Steam Deck (1280 × 800) und OpenGL ES. Bilder: `ab_mittel/<Position>_ab_00|01.jpg`, `ab_varianten/`,
Ausschnitte in `details/`.

### 2.1 Urteil je Position (Mittel)

| Pos. | Modern gegen Arcade | Bild |
|---|---|---|
| S1 km 2, 12 Uhr | gleichwertig bis leicht besser: Felder mit Struktur, echte Schatten, Windräder mit Rotoren, Leitplanken aus Blech. Schwächer: keine Sonnenscheibe, Spielerlimousine wirkt wie ein anderes Auto (steile Heckscheibe mit sichtbarem Innenraum statt Fließheck), ferne Bäume rechts hinter der Kurve als graublaue „Geisterbäume“ | `S1_ab_00/01`, `details/crop_s1_car01`, `crop_s1_far` |
| S2 Tankspur | **schlechter**: kein Tankstellendach mit „TANKSTELLE“, keine Insel/Bordstein, keine gelbe Linie; Zapfsäulen stehen im Gras. Nachts (22 Uhr) liest sich die Tankstelle kaum (kein beleuchtetes Dach, dunkler Vorplatz) | `S2_ab_00`, `ab_varianten/S2H22_ab_00` |
| S3 km 60 | gleichwertig, Gelände und Schatten besser; Eiche aus Blattkarten mit gezackter, rauschender Krone (Alpha-Schnitt ohne Glättung) | `S3_ab_00`, `crop_s3_tree` |
| S4 km 80 Köhlbrandbrücke | **schlechter**: keine Brückengeländer, dunkles Wasser beidseits – liest sich als Damm. Elbphilharmonie und Michel (in Arcade bei 6 s am Horizont) **fehlen ganz** | `S4_ab_00/01`, `crop_s4_landmarks` |
| S5 Ziel | **schlechter**: Zielbrücke „ZIEL“ fehlt, nur das Schachbrett auf der Fahrbahn | `S5_ab_00` |
| T1 Kassel–Würzburg 46,5 | gleichwertig: Relief gibt Tiefe; links nahe der Straße fehlen Bäume (Sichtkorridor, B8) | `T1_ab_00/01` |
| T2 Kuppe 61,9 | gemischt: Land statt Arcades heller Nebelbahn am Horizont (besser); links fehlen Bäume und ein Findling (35 Requisiten im Korridor weggelassen), dahinter ein fernes Straßenstück in reiner Nebelfarbe mit Dither-Punkten | `T2_ab_00/01`, `crop_t2_left`, `crop_t2_far`, `crop_t2_rock` |
| T3 / T4 Saragossa–Pau | gleichwertig: Blick in die Kurve sauber (Spielerauto 100–110 px aus der Mitte, innerhalb D12), Täler mit Tiefe; Felsen/Findlinge fehlen (bekannt) | `T3_ab_*`, `T4_ab_*` |
| C1 Frankfurt 19:30 | gleichwertig: Stadthäuser, Laternenschein, Ersatzbilder (Sportwagen, Stadtbäume) wie Arcade; Zielbrücke voraus fehlt | `C1_ab_*`, `crop_c1_far` |
| N1 22 Uhr Schnee | **schlechter**: kein Schneefall; Fernboden unter dem Horizont als helle Bahn (75/82/94 gegen Arcade 37–40); Kompakt heller und gesättigter als sein Sprite | `N1_ab_*`, `crop_n1_horizon` |
| N2 Regen | **schlechter**: kein Regen, keine Gischt; nasse Fahrbahn vorhanden | `N2_ab_*` |
| U1 Gotthard | **kaputt**: keine Röhre – offenes grünes Gelände unter schwarzem Himmel, HUD sagt „TUNNEL“ | `U1_ab_00/01` |
| DEV 21 Uhr | **kaputt** im Tunnelteil (wie U1, Portal und Hügel fehlen); Spielerlimousine mit zwei weißen Glanzflecken (Mond) auf Dach und Kofferraum | `DEV_ab_*`, `crop_dev_car` |

Tageszeiten an S1: 6 Uhr und 19:30 gleichwertig (Kegel, Himmel, Lack), 22 Uhr gut lesbar, aber Glanzfleck auf dem Dach
(Fahrzeugausschnitt p95-Leuchtdichte 112 gegen Arcade 50; gemessen) und Abblendlicht auf der Fahrbahn +18 % (112 gegen 95,
Ausschnitt 560–700 × 360–440; gemessen). Lack mittags (Kofferraum, Bereich 590–710 × 600–625): Farbton −2,3 … −2,7°,
Helligkeit +1 … +3 % gegen das Cycles-Sprite – innerhalb 10 % (gemessen, S1 und S3).

### 2.2 Voreinstellungen, Deck, OpenGL ES, Rückfall

- Niedrig (75 % 3D-Auflösung, keine Schattenwerfer): sichtbar weicher, weniger Büsche – nicht besser als Arcade, aber
  auf Software-Grafik ohnehin nicht empfohlen. Hoch ≈ Mittel im Standbild. `ab_varianten/S1_low_ab_*`, `S1_high_ab_*`,
  `details/crop_presets_car`.
- Steam Deck 1280 × 800, Voreinstellung „Steam Deck“: Modern füllt 16:10, HUD in den Ecken, Arcade mit Balken – in
  Ordnung (`ab_varianten/S1_deck_ab_01`).
- OpenGL ES (`--rendering-driver opengl3_es`) gegen OpenGL an S1 Mittel: größte Abweichung 2/255, PSNR 71,8 / 88,0 dB –
  innerhalb der Toleranz von D38 (gemessen). ANGLE selbst ist hier nicht prüfbar (abgeleitet).
- Rückfall (`--gfx-debug=fail`): Arcade-Bild mit der Meldung „Der Modus „Modern“ lässt sich mit dieser Grafik nicht
  starten …“ (`details/rueckfall_fail_00.png`) – in Ordnung.
