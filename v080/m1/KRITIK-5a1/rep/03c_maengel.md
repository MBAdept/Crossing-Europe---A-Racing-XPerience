### K5 – mittel (Modell, AS5a-N; Überblenden R7) – Stufenwechsel bei 60 m: Fachwerk und Kontor wechseln ein Viertel bis ein Drittel der Pixel

**Gemessen** (`prop_scene --mode=lods`, „Mittel“, Anteil der Pixel mit Σ|ΔRGB| > 0,06 / Helligkeit, Bild 25):
Fachwerkzeile **32,0 %** (+4,7 %; nachts 23,8 %, **+9,0 %**), Kontor 24,7 % (nachts 18,1 %, **+9,9 %**), Barock 18,5 %,
Gründerzeit 18,0 %, Speicher 17,4 %, Fachwerk mit Turm 16,8 %, Giebelzeile 14,9 %, Mietshaus 14,2 %, Einfamilienhaus
11,1 %, Büroturm 3,3 %, Kran 2,1 % – dieselben Zahlen wie AS5a1. Zum Vergleich: die AS4-Häuser lagen bei 3–11 %
(KRITIK-4); ein Arcade-Platzhalter wechselt nie. Was wechselt: echte Hölzer gegen gemaltes Fachwerk, Laibungsschatten,
Sprossen, Türflügel; nachts wird lod1 deutlich heller (Scheiben ohne Laibung).
**Im Fahrfilm** (Prüfstraße Altstadt, 50 km/h, Bild 40, `py/swappop.py`): In einer dichten Zeile steht das Haus, das bei
60 m wechselt, meist hinter dem nächsten Haus derselben Seite; im Bildausschnitt des wechselnden Hauses war der Anteil
„neu geänderter“ Pixel im Wechselbild 7,7–16,2 % gegen 7,1–16,0 % in den Bildern davor und danach (gemessen) – in
Bewegung geht der Wechsel im Bewegungsrauschen weitgehend unter. Sichtbar bleibt er, wo das Haus frei steht (Platz,
Kurve, Straßenende) und nachts (+9–10 % Helligkeit). Gefolgert: mittel, nicht hoch.
**Fix:** (AS5a-N) lod1-Atlas der Fachwerkhäuser aus dem gerenderten lod0 backen (Hölzer mit Schatten und AO statt des
flachen Generator-Fachwerks; das hebt auch die +4,7 %), nachts in lod1 die Scheiben um die fehlende Laibung abdunkeln
(`light_mul` lod1 ≈ 0,9); (R7) Dither-Überblenden 0,3–0,5 s wie bei Bäumen und Fahrzeugen. Nachweis: `--mode=lods`
≤ 15 % und Helligkeit ±3 % bei 12 und 22 Uhr.

### K6 – mittel (Modell, AS5a-N) – Flimmern in Bewegung

**Gemessen** (`my_scene --mode=sparkcam`, Kamera in Viertelpixel-Schritten seitlich, Anteil der Pixel, die je Schritt um
> 0,2 kippen; „Mittel“, 12 Uhr, 20 m seitlich; Teilmenge, weil ein Lauf über alle elf auf der geteilten Maschine über
40 min brauchte):

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
| Fachwerkzeile | **1,1 %** | **1,4 %** | 0,6 % | 1,1 % | 0,1 / 0,1 / 0,2 / 0,4 % |
| Gründerzeithaus | 0,6 % | 0,5 % | 0,3 % | 0,4 % | 0,1 / 0,1 / 0,2 / 0,4 % |
| Giebelzeile | 0,5 % | 0,7 % | **1,1 %** | **1,3 %** | 0,1 / 0,1 / 0,3 / 0,4 % |

Dieselbe Größenordnung wie bei AS5a1 (Fachwerkzeile 1,1–1,3 %). Das Maß bestraft auch gewollte Schärfe (das Sprite
ist weichgezeichnet); zum Vergleich: die AS4-Häuser lagen bei 0,0–0,9 % gegen 0,1–1,7 % ihrer Sprites (KRITIK-4),
Block B mit 1,0 % galt bei AS4R als Schwäche. Ursachen: (a) die Hölzer der Fachwerkhäuser sind bei 40–60 m 1–2 Pixel
breite, dunkle Glieder vor weißer Ausfachung (lod0 – auf „Hoch“ sogar bis 120 m); (b) die Giebelzeile flimmert in
**lod1** (gemalter Atlas) bei 100–150 m – Ziegelverband, Treppengiebel-Kanten und Sprossen der Fenster im Atlas
ohne Vorfilterung der kleinen Mips. Im Fahrfilm (Bild 40/42, 50 km/h) sieht man an den fernen Fachwerkzeilen ein
leichtes Kriseln der Hölzer (angesehen); die Wirkung auf einem echten Bildschirm mit 60 Bildern/s ist gefolgert.
**Fix (AS5a-N):** (1) Fachwerk-Hölzer in lod0 nur bis ~35 m als Geometrie (eigene Stufe „lod0n“ oder Hölzer in
lod1 überblenden), darüber das gebackene Fachwerk; die gebackenen Hölzer im Atlas 10–15 % heller als die echten
(Kontrast der dünnen Linien senken), (2) Mips der Atlanten mit einem weicheren Filter (Lanczos/Kaiser statt Box) und
ab Mip 2 einem leichten Weichzeichner für die Ziegel- und Sprossenmuster vorberechnen, (3) Giebelzeile:
Ziegelfugen im Atlas eine Stufe kontrastärmer. Nachweis: `sparkcam` ≤ 0,6 % bei 40–150 m.

### K7 – mittel (Modell + Import) – Geländer (`baked_cutout`) verdichten sich bis ~40 m und lösen sich ab ~75 m auf

**Wo:** Balkone von Mietshaus (77) und Gründerzeithaus (72) – die ersten Nutzer der Klasse `baked_cutout`.
**Gemessen** (`mipcov.py` von AS5a1 auf den gelieferten Atlanten nachgerechnet): Deckung des Alpha-Tests gegen Mip 0:
Mietshaus mip1–3 1,11 / 1,20 / 1,40, mip4 **0,29**; Gründerzeit 1,12 / 1,19 / 1,32, mip4 **0,59**. Bei 150 Texeln je
Meter (`CUT_PPM`) und 711 px Brennweite gilt Mip k ab etwa 4,7 m × 2^k (gerechnet): Mip 3 ab 38 m, Mip 4 ab 76 m.
Das Geländer wird zwischen 20 und 60 m dichter und dunkler und ist ab etwa 75 m fast weg (bei 100 m ein dünner
schwarzer Strich, Bild 10 german). Kein Saum, kein Aufblitzen in den Standbildern (angesehen) – die Klasse
funktioniert, die Mip-Kette nicht; die Aufgabe „Deckung in kleinen Mips erhalten“ ist nicht erfüllt.
**Fix:** im Bake für die Ausschneide-Inseln eine eigene Mip-Kette schreiben, deren Alpha je Stufe so skaliert ist,
dass der Anteil ≥ 0,5 dem von Mip 0 gleicht (coverage-preserving mips; als `.dds`/vorberechnete Mips oder im
`bake.py`-Schritt vor dem Import), oder Geländer ab lod1 als gemaltes halbdeckendes Band im deckenden Atlas (wie das
Sprite); Renderer-Variante: Alpha-to-Coverage bei MSAA (R7). Nachweis: `mipcov.py` 0,9–1,1 für mip1–4.

### K8 – niedrig bis mittel (Licht R4; Modell kann mithelfen) – sonnige Putzfassaden viel heller als Arcade, schattige dunkler

**Gemessen** (`py/boxlum.py`, gleiche Bildausschnitte Arcade | Modern, 12 Uhr, Hoch): sonnige Straßenflanken rechts
Hamburg Speicher +8 %, Nürnberg Barock +18 %, Hannover Gründerzeit +13 % bzw. +51 %, München Gründerzeit +35 %
(Median-Luma 195 gegen 137, die hellsten 10 % bei 236–240 von 255); schattige Flanken links −20 bis −39 %. Die
AS4-Ladenfront (zur Kamera) ist in beiden Modi gleich hell. In Prüfszene und Kontaktbogen wirken Gründerzeit und
Barock bei 100–250 m blasser als ihr Sprite (Median-Luma +27–31 %).
**Bewertung:** Licht und Schatten sind Absicht des echten 3D; aber helle Putzfassaden laufen in der Mittagssonne fast
ins Weiß und verlieren Zeichnung. **Fix:** zuerst R4 (Sonnenstärke/Belichtung für `baked` gegen Arcade abgleichen,
wie AS4R es für die Kirche getan hat); bleibt es, `albedo_mul` 0,88 für die hellen Putze (Gründerzeit, Barock,
Mietshaus) in AS5a-N. Nachweis: Median-Luma der Sonnenseite ≤ +15 % gegen Arcade.

### K9 – {{DAEMMERUNG_TITEL}}

{{DAEMMERUNG}}

### K10 – niedrig (Modell, AS5a-N) – kleinere Mängel

- **Büroturm** (7): Foyer nachts eine Reihe gleichmäßig hellgrauer Tafeln ohne Inhalt, Bürofenster grauweiße
  Rechtecke (Bild 21 german). Fix: Foyer wie ein Schaufenster mit `shop_depth` und Theke, `shop_light` 0,35.
- **Einfamilienhaus** (282, das häufigste Modell): lod1 hat 85 % der Dreiecke von lod0 (2 526 / 2 962) – Hecken und
  Gartenbaum bleiben voll; aus der Nähe sind sie klumpige facettierte Kugeln wie im Generator. Garagenfront zur
  Anfahrt nur 16 px/m (5 m²). Fix: in lod1 Hecken als Boxen mit gebackener Seite, Baum als zwei gekreuzte Karten
  (oder ein AS3-Baum), Ziel ≤ 900 Dreiecke; Garagenfront in den Chart der Straßenwand.
- **Texeldichte im Spiel bei großem Maßstab:** Kontor oben 24 px/m bei Maßstab 1,2 (unter 26 px/m), Erdgeschoss
  Kontor 34, Giebelzeile 36, Fachwerkzeile 38 px/m (unter 40; gerechnet aus gemessenem Modellmaß). Fix: `floors.upper`
  des Kontors 0,8 statt 0,7, Innenstadt-Erdgeschosse auf 48 px/m (ein Viertel mehr Texel nur in diesem Band).
- **Kran** (3): aus der Nähe flache rote Kästen ohne Kante oder Niet – wie der Generator; steht 53–83 m vom Rand, also
  nie nah. Kein Handlungsbedarf.
