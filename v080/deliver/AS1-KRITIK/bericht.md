# AS1-KRITIK – Unabhängige Kunstkritik der Fahrzeugmodelle von AS1

- Gegenstand: Zweig `worktree-wf_bade9e46-06a-1`, Stand `53bcc1b` (nur gelesen). Gerendert wurde in einer Kopie im
  Arbeitsordner (`diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits, kein Zweig, keine Datei des
  Arbeitsbaums geändert.
- Modelle: `player/limousine`, `player/kompakt`, `traffic/sedan`, `traffic/hatch`, `traffic/wagon`, `traffic/truck`.
- **gemessen** = auf dieser VM gemessen (Software-OpenGL llvmpipe unter Xvfb, Godot 4.7.2, Spiel-Shader `vpbr` und
  `glass` über `ModelFactory`). **abgeleitet** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf einen
  Menschen). Licht aller Bilder: das kleine Rig des Kontaktbogens (eine Sonne mit Schatten, Himmel als
  Spiegelquelle, linearer Tonemapper, Nachbearbeitung an). Das Licht des Renderers R1 gibt es auf diesem Zweig nicht.
  Aussagen zu Farbe und Helligkeit gelten für dieses Rig; im Rennen entscheiden R1 und R3.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Autos sichtbar feiner als die Arcade-Sprites, und kann man sie stundenlang ansehen?**

- **In Form und Schärfe feiner, im Gesamteindruck noch nicht schöner.** Alle sechs Modelle haben die Maße und
  Silhouetten der Sprites. Die Spielerautos stammen aus demselben Generator; Lage und Größe im Spielbild decken sich
  auf den Pixel. Modern ist schärfer und dreht stufenlos: Arcade springt alle 2° auf die nächste Zelle, und dieser
  Sprung ändert 6–16 % der Autopixel auf einmal (gemessen). Nahe Autos zeigt Modern in echter Perspektive, Arcade
  zeigt jedes Auto aus 9°. Dazu kommen Glas mit Innenraum, lesbare Kennzeichen und beim Lkw echte Räder statt eines
  Quaders. Das ist ein klarer Fortschritt.
- **Das Auge sieht zuerst den Lack, und der ist schlechter als im Sprite.** Er ist zu hell und zu gesättigt, und
  Gelb übersteuert. Gemessen: Beim Kompakt haben 84 % der Lackpixel einen Kanal bei 255, der Farbton kippt von 43°
  auf 53° (Bernstein wird Zitronengelb). Die Limousine ist 21 % heller, das Rot der Verkehrsautos 46 % heller. Es
  fehlt Umgebungsschatten in Radhäusern und Fugen, die Felgen sind hellweiß statt anthrazit, das Glas der
  Verkehrsautos wirkt gemalt. So wirken die Autos wie Plastikspielzeug; das Cycles-Sprite wirkt fotografischer. Das
  meiste davon ist Licht und Shader (R1/R3), nicht das Netz.
- **Dazu kommen Modellfehler, die man bei stundenlangem Hinsehen bemerkt** (Abschnitt 3):
  - Kompakt: ein schwarzer Keil über beiden Rückleuchten, im Spielbild ständig zu sehen.
  - Stoßfänger ragen in die Vorderreifen; Bremsscheiben sehen aus wie polierte Kugeln.
  - Bei Nacht besteht das Rücklicht der Spielerautos nur aus dünnen Lichtleitern; in Arcade leuchtet die ganze Leuchte.
  - Unbeleuchtete Lampen der Verkehrsautos sehen bei Tag eingeschaltet aus.
  - Bei 120 m springt der Stufenwechsel der Verkehrsautos sichtbar.
  - Beim Lkw bleibt die Konturmarkierung nachts dunkel, und der Schattenwerfer ragt aus der Hülle.
- **Urteil je Modell:**
  - Spielerautos: *gleichwertig* – feiner im Netz, flacher im Material.
  - Verkehrsautos: *gleichwertig* – bis 10 m klar besser, ab 20 m gleich, Lampen, Glas und Felgen schlechter.
  - Sattelzug: *feiner*.
- **Showroom-Schalter: `false` ist richtig, nicht zu vorsichtig.** Im A/B mit gleicher Kamera verliert Echtzeit beim
  Lack und beim Glas deutlich. Weicheres Licht holt die Farbe heran, aber nicht die Spiegelung (Bild 16).
- **Stundenlang ansehbar?**
  - Bei Tag aus der Spielkamera: ja, sobald R1/R3 die Lackbelichtung im Griff haben.
  - Bei Nacht und im Showroom: erst nach den Korrekturen A1–A6 und B1–B3.

## 2. Wie geprüft wurde

Eigenes Werkzeug in der Kopie, nie eingecheckt: `tools/kritik/kritik_render.gd` (Jobliste → ein PNG je Kachel) und
`kritik_dump.gd` (Netze → numpy). Die Skripte liegen im Arbeitsordner.

- **Kameras:**
  - Spielkamera exakt nach D12: Frustum, Brennweite 711 px bei 720 px Höhe, 3,4 m hoch, Horizont bei 45 %,
    1280 × 720, MSAA 2× wie „Steam Deck“ und „Mittel“; dazu 1,65- bzw. 3-fach überabgetastet.
  - Sprite-Kamera der Verkehrsautos: orthografisch, 9°, Drehpunkt am Heck, Maßstab und Anker aus dem Sprite-Manifest.
  - Orbit-Kamera für Nahansichten.
- **Sprite-Vergleich:** Das Arcade-Bild liegt so, wie `road_renderer.gd` es zeichnet:
  - Spieler: Anker bei (640, 592,6), Zelle geteilt durch 1,65.
  - Verkehr: Heckanker, Maßstab 711 / (Abstand · 52 px/m).
  - Lkw: Heckfläche der Box-Textur.

  Lage und Größe stimmen auf den Pixel; die Vergleiche sind fair. Gierrichtung geprüft: Modern +a entspricht der
  Sprite-Zelle `l<a>`.
- **Darstellungsarten:** Ton (Form ohne Lack), Facetten (flach schattiert), Drahtgitter, Normalen als Farbe.
  Prüfbild: Rückseiten rot, Normale gegen Wicklung magenta. Dazu Lampenkanäle in Falschfarben und der
  Schattenwerfer rot, wo er aus der Haut ragt.
- **Netzanalyse in numpy** (`out/mesh_analysis.txt` im Arbeitsordner):
  - Wicklung, offene Kanten, doppelte und deckungsgleiche Flächen, Rundlauf der Räder.
  - Freigang Reifen ↔ Karosserie: Räder drehend, Vorderräder von −25° bis +25° gelenkt.
  - Lampenflächen je Kanal.
  - Knickgelenk des Lkw: Grundriss-Raster mit 2 cm.
- **Bewegung:** Das Spielerauto dreht ±2° in 0,2°-Schritten; verglichen wird mit einer 3 × 3 überabgetasteten
  Referenz.
- **Stufenwechsel:** gleiche Kamera, beide Stufen am Umschaltabstand, Zählung der Pixel, die sich ändern.
- **Umfang:** 805 Renderbilder plus 8 Showroom-Kacheln, gemessen gut 30 min Rechenzeit. Die Maschine war mit anderen
  Aufträgen geteilt (Last 10–11).

## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS1R** = Nacharbeit der Modelle, **R3** = Fahrzeug-Shader und Fahrzeugebene, **R1** = Licht und
Belichtung. Alle Bilder liegen in diesem Ordner. Zu jedem Mangel: wo, was, Beleg, Behebung, zuständig.

### A. Spielerautos (das Heck in 9 m ist die ganze Spielzeit im Bild)

**A1 – hoch – Lack übersteuert (beide Autos, R3 + R1)**
- Was: Kompakt `#f0b30a` wird Zitronengelb. Gemessen: Farbton 43° → 53°, Helligkeit 0,72 → 0,95, 84 % der
  Lackpixel mit einem Kanal bei 255. Limousine: +21 % Helligkeit, Sättigung 0,62 → 0,83. Mit Sonne von vorn (Heck im
  Schatten) liegt der Lack nahe am Sprite. Ursache: Die in sRGB addierte Sonne (D5) treibt helle Lacke über 1,0.
- Beleg: `01_spieler_9m_sprite_vs_modern.jpg`, `02_spieler_9m_gedreht.jpg`.
- Behebung: Belichtung des Lacks begrenzen – in `vpbr` ein weiches Abschneiden für Lackcodes, oder Sonnen- und
  Umgebungsenergie für Fahrzeuge senken. Klarlack mit Fresnel-Spiegelung des Himmels statt mehr Diffuslicht. Danach
  das A/B mit dem echten Rig von R1 wiederholen. Die Lackwerte im Manifest sind richtig (gleich wie im Sprite).

**A2 – hoch (Nacht) – Rücklicht nur Lichtleiter (beide, AS1R)**
- Was: Mit Rücklicht leuchten nur die Lichtleiter (Kanal 0: 229 bzw. 165 cm²). Der Leuchtenkörper ist Kanal 2 mit
  Gewicht 0,50 (gemessen), leuchtet also mit 0,35 × 0,5 = 17,5 %. Das Nachtheck ist dadurch dünner und dunkler als die
  Sprite-Schicht `tail`, in der die ganze Leuchte leuchtet. Rote Pixel der linken Leuchte im Spielbild: 158 mit
  Rücklicht, 361 mit Bremse.
- Beleg: `03_limousine_nah.jpg`, `03_kompakt_nah.jpg` (Nachtkacheln).
- Behebung: Gewicht von Kanal 2 im Leuchtenkörper auf 1,0 setzen (Rücklicht dann 35 %, Bremse unverändert 2,2×). Oder
  den Körper auf Kanal 0 mit Gewicht 0,6 legen und die Bremszellen auf Kanal 1. Die Bremse muss mindestens doppelt so
  hell bleiben wie das Rücklicht (Render-Prüfung).

**A3 – mittel – schwarzer Keil über den Rückleuchten (Kompakt, AS1R)**
- Was: Das Ende der schwarzen Heckblende steht an der Schulter als flaches Blatt über der gewölbten Fläche (im
  Tonbild ein Absatz). Im Spielbild ein schwarzes Dreieck von 6 × 3 px auf Gelb, ständig sichtbar. Das Sprite hat es
  nicht.
- Beleg: `17_maengel_nah.jpg` (Kacheln 1–3).
- Behebung: Die Blende an der Körperkante enden lassen (`conform` auch für dieses Teil) oder an der Innenkante der
  Leuchte abschneiden.

**A4 – mittel – Stoßfänger im Vorderreifen (beide, AS1R)**
- Was: Kompakt: Der Stoßfänger (Lackteil) ragt bei Geradeauslauf 52 mm tief ins Reifenvolumen (gemessen); in eine
  Lenkrichtung ist er erst ab 15° frei. Limousine: Der Stoßfänger endet vor dem Reifen und verdeckt ihn von der
  Seite; die dunkle Radlaufschale bzw. das Schwellerende hinter dem Vorderrad steckt bei Geradeauslauf 10 mm im Reifen,
  gelenkt (±20°) bis 30 mm. Es wirkt, als sei der Reifen abgeschnitten – im Showroom und in der Seitenansicht.
- Beleg: `17_maengel_nah.jpg`, `out/mesh_analysis.txt`.
- Behebung: Das Stoßfänger-Ende dem Radlauf folgen lassen (Radius + 25 mm Luft) oder 4–6 cm kürzen; Radlaufschale und
  Schwellerende mindestens 20 mm vom Reifen weg (auch bei 25° Lenkung).

**A5 – mittel – Stoßfänger-Enden als flache Kappen (beide, AS1R)**
- Was: Senkrechte, flache Endkappe hinten und vorn. Der Stoßfänger wirkt wie ein aufgeklebter Kasten mit harter Stufe
  zum Kotflügel.
- Beleg: `17_maengel_nah.jpg`.
- Behebung: Enden runden (`ends_n` bzw. Kappenradius) oder in den Kotflügel auslaufen lassen.

**A6 – mittel – Bremsscheiben und Felgen (beide, AS1R)**
- Was: Die Bremsscheibe hinter den Speichen wirkt wie eine polierte Kugel – über die ebene Scheibe sind die Normalen
  geglättet. Die Felgen der Limousine sind hellsilber, im Sprite anthrazit.
- Beleg: `17_maengel_nah.jpg`, `02_spieler_9m_gedreht.jpg`.
- Behebung: harte Normalen an Scheibenrand und Topf, Rauheit 0,5; Felgenfarbe wie im Sprite.

**A7 – niedrig bis mittel – Flimmern in Bewegung (beide, AS1R)**
- Was: Die Schriftzeichen des Kennzeichens (etwa 8–10 px hoch) und die schmalen Fugen flimmern, wenn das Auto sich
  dreht. Bei streifendem Blick erscheinen die Fugen gestrichelt (Abschnitt 5). Das Kennzeichen sieht der Spieler
  ständig.
- Beleg: `14_spieler_bewegung_flimmern.jpg`, `17_maengel_nah.jpg`.
- Behebung: Zeichen um etwa 30 % kräftiger, Kennzeichen hellgrau statt reinweiß. Fugen mindestens 8 mm breit oder als
  flache Rinne (Schattierung statt Strich).

**A8 – niedrig – Heckblinker als Lichtleiter (beide, AS1R, später)**
- Was: Der Blinker besteht aus zwei dünnen Streifen. Im Spielbild sind sie 1 px breit; mit Bremse gehen sie im Rot
  unter (Bernstein-Pixel 45 → 80). Für das Spiel heute ohne Folgen, weil der Spielerblinker nicht geschaltet wird.
- Beleg: `03_*_nah.jpg` (Kachel Blinker).
- Behebung: Falls R3 den Spielerblinker zeigt, ein geschlossenes Bernsteinfeld von mindestens 6 × 3 cm.

**A9 – niedrig – Rückleuchten von schräg vorn (beide, AS1R)**
- Was: Von schräg vorn (Showroom-Kamera) ist von der Rückleuchte an der hinteren Ecke nichts zu sehen. Im Sprite
  läuft die Leuchte sichtbar um die Ecke.
- Beleg: `16_showroom_ab.jpg`.
- Behebung: rot getönte Streuscheibe (Deckkraft mindestens 0,5) statt klar über der tiefen Mulde, oder die Leuchte
  weiter um die Ecke führen.

**A10 – niedrig – kleinere Punkte (AS1R)**
- Diffusor-Finnen hängen als dünne Stäbe unter dem Stoßfänger (Beleg: `04_spieler_netz.jpg`, Tonbild).
- Der Schattenwerfer liegt vor dem Grund des Grills (Limousine) und der Lampenmulden. Diese Vertiefungen sind tiefer
  als 12 mm; dort entsteht Eigenschatten (Beleg: `04_spieler_netz.jpg`, rot).
- Der Lichtanker der dritten Bremsleuchte der Limousine hat kein `dir` (A-4 verlangt es).

**A11 – niedrig – Innenraum-Budget überschritten (Kompakt `lod0`, AS1R)**
- Was: §4.6.9 erlaubt höchstens 6 000 Dreiecke Innenraum in `body`. Gemessen (Exportstatistik): 2 156 Dreiecke
  Innenraum + 4 112 Verkleidung = 6 268. Die Verkleidung ist eine volle Kopie der Kabine, deckungsgleich mit der
  Außenhaut (8 178 Rücken-an-Rücken-Paare). Limousine: 5 602.
- Beleg: `out/ce_stats_player.txt`, `04_spieler_netz.jpg` (Prüfung rot).
- Behebung: Die Verkleidung grob bauen (halbe Stationen und Ringe, etwa 1 000 Dreiecke); man sieht sie nur durch
  getöntes Glas. Die frei werdenden rund 3 000 Dreiecke in Leuchten und Felgen stecken.

**Was gut ist (gemessen):**
- Wicklung sauber: 0–2 Dreiecke je Netz gegen die Normale.
- Räder laufen rund: Rollachse 0,0 mm neben der Mitte, Unrundheit 4 mm (Polygonkanten).
- Kein sichtbarer z-Kampf: Die 128 bzw. 98 deckungsgleichen Doppelflächen haben dieselbe Farbe.
- Glas durchsichtig mit Innenraum, Kennzeichen scharf, Leuchten aus der Nähe mit echter Tiefe.

### B. Verkehrsautos (Limousine, Schrägheck, Kombi – ständig im Bild, 10–150 m)

**B1 – hoch – Lampen wirken bei Tag eingeschaltet (alle, R3 + AS1R)**
- Was: Mit `lamp_off` 0,5 erscheinen unbeleuchtete Rück- und Bremsfelder kräftig rot, die Blinkerfelder orange und
  die dritte Bremsleuchte als hellroter Balken auf der Heckscheibe. Bremse an/aus ändert die Helligkeit der
  Lampenpixel bei Tag nur um das 1,4- bis 2-fache (gemessen: 30 m ×1,75–1,89, 80 m ×1,43–1,59). Blinker allein bei Tag
  (gemessen): 30 m ×1,6–1,8 auf 11–14 px, 80 m nur ×1,2–1,46 auf 2–3 px.
- Beleg: `07_verkehr_spielkamera_tag.jpg`, `10_verkehr_nah.jpg`.
- Behebung: `lamp_off` für die Kanäle 0–4 auf 0,25–0,3 senken; dritte Bremsleuchte unbeleuchtet dunkel (Albedo);
  danach den Kontrast neu messen. Den Tag-Schein beim Bremsen wie in Arcade übernimmt R3 (F6).

**B2 – mittel bis hoch – Heckleuchten neu gestaltet statt vom Sprite übernommen (alle, AS1R)**
- Was: Rechteckige Zwei-Farben-Felder (rot oben, bernstein unten) mit schwarzer Umrandung, flach, ohne Streuscheibe.
  Das wirkt wie ein Aufkleber aus den 90ern. Das Sprite hat schmale dunkle Leuchten mit weißem Rückfahrfeld.
- Beleg: `05_verkehr_sprite_vs_modern.jpg`, `10_verkehr_nah.jpg`.
- Behebung: Kontur aus den Entwurfstabellen des Sprites übernehmen. Bernstein hinter rotem oder klarem Glas, das
  unbeleuchtet dunkel ist. Eine 2 mm hohe Glanzschicht als Streuscheibe (lod0 hat 112–683 Dreiecke Luft).

**B3 – mittel – sichtbarer Stufensprung bei 120 m (alle, AS1R)**
- Was: Beim Wechsel lod1 → lod2 ändern sich 24–38 % der rund 100 Autopixel um mehr als 24 Stufen (gemessen). Das
  Kennzeichen verschwindet (der hellste Punkt des Autos), die Kabine wird eine dunkle Kappe samt Säulen. Bei 40 m
  (lod0 → lod1) sind es 6–11 %: Die Zeichen verschwinden, das Kennzeichen wird heller, die Spiegel wechseln die Farbe.
- Beleg: `17_maengel_nah.jpg` (B3), Abschnitt 4.
- Behebung: Kennzeichen in lod1 und lod2 als hellgraues Viereck (Mittelwert des lod0-Kennzeichens) und in lod2
  behalten (2 Dreiecke). Säulen in lod2 in Lackfarbe. Spiegelfarbe in allen Stufen gleich.

**B4 – mittel – Glas wirkt gemalt (alle, AS1R + R3)**
- Was: Flaches Dunkelblau ohne sichtbare Spiegelung. lod0 hat die Glas-Klasse, lod1 und lod2 dunkles `vpbr`.
- Beleg: `05_verkehr_sprite_vs_modern.jpg`, `10_verkehr_nah.jpg`.
- Behebung: Rauheit des Glases senken, Tönung etwas heller mit Fresnel. In lod1/lod2 niedrige Rauheit und etwas
  Metall, damit der Himmel spiegelt.

**B5 – mittel – Felgen hellweiß (alle, AS1R)**
- Was: Die Felgen sind hellweiß-silbern, im Sprite anthrazit. Leuchtende Scheiben unter dem Auto wirken wie Spielzeug.
- Beleg: `05_verkehr_sprite_vs_modern.jpg`, `09_verkehr_stufen_nah.jpg`, `10_verkehr_nah.jpg`.
- Behebung: Felgen-Albedo etwa `#5a5d62`, Metall 0,6, Rauheit 0,35 – wie im Sprite.

**B6 – mittel – Heck aus der Nähe ein glatter Block (alle, AS1R)**
- Was: Beim Überholen und im Stau sieht man: kein Spalt an Kofferraum oder Heckklappe, kein Emblem, der Stoßfänger
  ein Kasten mit flacher Endkappe.
- Beleg: `10_verkehr_nah.jpg`.
- Behebung: Spalt und Emblem einschneiden (etwa 150 Dreiecke), Stoßfänger-Enden runden.

**B7 – niedrig – Auspuff als schwebender Ring (alle, AS1R)**
- Was: Ein dünner Ring, der unter dem Stoßfänger zu schweben scheint.
- Beleg: `05_verkehr_sprite_vs_modern.jpg` (Heckansichten).
- Behebung: ein kurzes, geschlossenes, dunkles Rohr.

**B8 – niedrig – Farben zu hell (alle, R3 + R1)**
- Was: Rot 46 % heller als im Sprite, Grün minzig (Himmelsspiegelung plus Übersteuerung).
- Beleg: `12_farbsets.jpg`, `05_verkehr_sprite_vs_modern.jpg`.
- Behebung: wie A1.

**Was gut ist (gemessen):**
- Gleiche Lampenkonturen in allen Stufen (Abschnitt 4); die Stufen knittern nicht.
- Blinker 95–102 cm² in jeder Stufe.
- Räder frei: 0 Ecken im Reifenvolumen, auch bei 25° Lenkung.
- Der Schattenwerfer passt (nur Kantenpixel).

### C. Sattelzug

**C1 – mittel bis hoch (Nacht) – Konturmarkierung nachts fast dunkel (Heck; R3, AS1R für den Kanal)**
- Was: Kanal 8 leuchtet mit Albedo × Gewicht 0,79 × Rücklicht × `plate_energy` 0,45 und bleibt nachts fast dunkel.
  In Arcade leuchtet die Kontur rot – sie ist das Nachtmerkmal eines Lkw (retroreflektierend).
- Beleg: `11_lkw_spielkamera.jpg` (Nachtzeilen), `13_lkw_nah.jpg`.
- Behebung: rückstrahlend machen, gespeist vom Scheinwerfer des Spielers (`ce_headlight`). Oder auf Kanal 9 (Umriss,
  folgt dem Rücklicht) mit Gewicht 0,5 legen.

**C2 – mittel – Weiß übersteuert (Koffer, Fahrerhaus bei Tag; R1/R3, AS1R)**
- Was: Hecktüren und Seiten sind reines 255 ohne jede Form. Bei 60 m ist das Heck ein weißes Quadrat.
- Beleg: `11_lkw_spielkamera.jpg` (Tag).
- Behebung: wie A1; im Modell das Weiß der Lackierungen auf etwa `#d8d8d4` senken.

**C3 – mittel – Schattenwerfer ragt aus der Hülle (AS1R)**
- Wo: Fahrerhaus unten und am Radlauf, Unterkante des Aufliegers, Heck zwischen den Leuchtenträgern.
- Was: 446–1 838 rote Pixel je Ansicht. Folge: Eigenschatten auf Stoßfänger, Radlauf und Leuchtenträger.
- Beleg: `13_lkw_nah.jpg`, `17_maengel_nah.jpg`.
- Behebung: `tuck_inside` auch für den Lkw (mindestens 3 cm innen, auch an Stoßfänger und Unterfahrschutz); den
  Werfer des Koffers am Boden des Aufliegers enden lassen.

**C4 – niedrig bis mittel – Fahrerhaus (AS2b)**
- Was: kastig mit ebener Front, schwarze Scheiben ohne Innenraum, Spiegel als dünne schwarze Stäbe, Naben als
  Chromkuppeln.
- Beleg: `13_lkw_nah.jpg`.
- Behebung: Kanten runden, dunkle Innenraum-Silhouette (Sitzlehnen, Armaturenbrett), Spiegelgehäuse – passt zu AS2b.

**C5 – niedrig – ferne Rückleuchten (R3)**
- Was: Bei 150 m sind die Rückleuchten nachts 1–2 px groß, wie AS1 selbst sagt. Nötig sind Schein und Flares des
  Renderers (F6).
- Beleg: `11_lkw_spielkamera.jpg`.

**Was gut ist:**
- Das Heck mit Türen, Gestängen, Kontur, Leuchtenträgern und Unterfahrschutz liest sich bei Tag bis 150 m.
- Das Knickgelenk um den Königszapfen ist kollisionsfrei. Gemessen im Grundriss-Raster (2 cm), im Höhenband des
  Koffers 1,21–3,85 m: bis 60° keine Überdeckung von Koffer und Zugmaschine.
- Räder rund und frei, die vier Lackierungen sauber.

## 4. Stufen, Lampen, Budgets, Zeichenaufrufe

**Prüfer:** `validate_models.py --report` meldet `CHECK models OK`, 10 Modelle, 180 Sets (gemessen,
`out/validator.txt`).

**Budgets §4.6.9 (gemessen):**

| Modell | lod0 | lod1 | lod2 | show | Werfer | Aufrufe lod0/1/2 | Urteil |
|---|---|---|---|---|---|---|---|
| player/limousine | 45 764 / 55 000 | – | – | 99 670 / 120 000 | 1 872 / 3 000 | 6 (2 + 4 Räder) | eingehalten; Innenraum 5 602 / 6 000 |
| player/kompakt | 50 080 / 55 000 | – | – | 107 042 / 120 000 | 1 872 / 3 000 | 6 | **Innenraum 6 268 / 6 000** (A11) |
| traffic/sedan | 17 695 / 18 000 | 5 805 / 6 000 | 1 123 / 1 200 | – | 636 | 6 / 1 / 1 | eingehalten |
| traffic/hatch | 17 317 | 5 753 | 1 136 | – | 652 | 6 / 1 / 1 | eingehalten |
| traffic/wagon | 17 888 | 5 937 | 1 103 | – | 604 | 6 / 1 / 1 | eingehalten (112 Luft) |
| traffic/truck | 18 084 / 25 000 | 4 672 / 7 000 | 1 490 / 1 500 | – | 356 | 13 (2 + 4, 1 + 6) / 1 / 1 | eingehalten (lod2: 10 Luft) |

Zeichenaufrufe: je Auto in lod0 die Karosserie mit 2 Flächen (`vpbr` + `glass`) und 4 Räder, in lod1/lod2 eine
Fläche; dazu der Werfer je Schattenkaskade. Das steht so im Manifest und stimmt mit den Flächen der Netze überein.

**Lampenregeln:** Der Prüfer ist grün. Nachgerechnet (gemessen, Fläche von hinten nach Wicklung):

| Modell | Kanal 0 | Kanal 1 | Kanal 2 | Blinker je Seite |
|---|---|---|---|---|
| Limousine (Spieler) | 229 cm² | 185 cm² | 645 cm² (Gewicht 0,50) | 84 cm² |
| Kompakt (Spieler) | 165 cm² | 152 cm² | 748 cm² | 102 cm² |
| Verkehrs-Limousine lod0 → lod2 | – | – | 639 → 847 → 887 cm² | 99 cm² in jeder Stufe |

Die Regel ist erfüllt, aber A2 zeigt: Beim Spielerauto bedeutet „Fläche“ nicht „Leuchtfläche bei Rücklicht“, weil
Gewicht 0,5 und Rücklichtanteil 35 % zusammenkommen.

**Lampenkonturen je Stufe** (von hinten, Masken je Kanal, Überdeckung IoU mit lod0; gemessen, Bild 15):

| Kanal | Ergebnis |
|---|---|
| Blinker links und rechts, dritte Bremsleuchte | IoU 1,00 in allen Stufen (Ausnahme: Kombi lod2, dritte Bremsleuchte 0,36) |
| Rück- und Bremsfeld | wächst in lod1/lod2, weil schwarze Ringe und Chromleisten wegfallen (IoU 0,58–0,82, Außenkontur gleich; erlaubt: höchstens 2× + 5 cm²) |
| Rückfahrlicht | fehlt in lod2 (dokumentiert) |

**Stufenwechsel (gemessen, Spielkamera, Tag, MSAA 2×):**

| Auto | 40 m lod0 → lod1 | 120 m lod1 → lod2 |
|---|---|---|
| sedan | 114 von ~1 001 px (11,4 %) | 33 von ~103 px (32 %) |
| hatch | 71 von ~921 px (7,7 %) | 38 von ~99 px (38 %) |
| wagon | 64 von ~1 033 px (6,2 %) | 25 von ~103 px (24 %) |

„px“ heißt: Pixel des Autos, die sich um mehr als 24 von 255 Stufen ändern. Der Sprung bei 120 m ist für ein Auto von
10 px Breite groß (B3).

**Silhouette gegen das Sprite des Generators** (gemessen, gleiche Kamera, `18_silhouette_sprite_modell.jpg`):

| Modell | Überdeckung (IoU) |
|---|---|
| Spielerautos in 9 m | 0,994–0,995 |
| Verkehrsautos lod0 (bei 104 px/m) | 0,94–0,96 |
| Verkehrsautos lod2 | 0,93–0,95 |

Bei den Verkehrsautos ist der Rest fast nur der Bodenschatten des Sprites unter dem Auto (dort ist der Alphawert im
Kernschatten ≈ 1). Die Proportionen stimmen also.

**Geometrie-Fixture:** nicht neu gerechnet. AS1 meldet nach der letzten Änderung an `cesprites` 187 von 187 Sets
identisch. Ich habe keinen Grund zum Zweifel gesehen: Die Silhouetten der Sprites und die Maße der Modelle decken sich
in allen Vergleichsbildern.

## 5. Bewegung, einzelne Lampen, Showroom

**Bewegung** (`14_spieler_bewegung_flimmern.jpg`; gemessen, Spielerauto in 9 m dreht −2° … +2° in 0,2°-Schritten,
MSAA 2× gegen eine 3 × 3 überabgetastete Referenz):

| Auto | Treppenfehler im Mittel | Pixel mit flimmerndem Fehler (Schwankung > 8 Stufen) | Arcade: Zellwechsel c → l2 ändert auf einen Schlag |
|---|---|---|---|
| Limousine | 0,7 Stufen | 1,8 % | 6,2 % der Autopixel um > 24 Stufen |
| Kompakt | 1,5 Stufen | 10,0 % (Kennzeichen-Zeichen, Heckklappen-Fugen, Spoilerkante, Scheibenrahmen) | 16,3 % |

In Bewegung ist Modern damit insgesamt ruhiger als Arcade mit seinen Zellsprüngen. Das Flimmern sitzt fast nur auf
Kennzeichen und Fugen (A7). Für die Voreinstellung „Niedrig“ (75 %, ohne MSAA) ist es deutlich stärker (Bild 01,
abgeleitet aus dem Standbild).

**Blinker allein** (links, Spielkamera; gemessen, `out/lamps_x.txt`):

| Fahrzeug | Tag 30 m | Tag 80 m | Nacht |
|---|---|---|---|
| Pkw | ×1,6–1,8 auf 11–14 px | ×1,2–1,46 auf 2–3 px | ×2–8 |
| Lkw | ×2,0 auf 36 px | ×1,9 auf 6 px | stark (aus nahezu Schwarz) |

Bei Tag ab etwa 80 m trägt das Modell den Pkw-Blinker nicht mehr allein; Flares (F6) und `lamp_off` (B1) sind nötig.

**Showroom** (`16_showroom_ab.jpg`; Kamera des Cycles-Showroom-Sprites):
- Mit dem Licht des Kontaktbogens ist Echtzeit greller (Gelb übersteuert) als das Sprite.
- Mit weicherem Licht (Sonne 0,45, Umgebung 0,75) kommt die Farbe nahe heran.
- Es fehlen trotzdem dunkles, spiegelndes Glas, Klarlack, Umgebungsschatten unter dem Auto und dunkle Felgen
  (Limousine).
- Urteil: `showroom: false` für beide Spielerautos ist richtig. Neu entscheiden, sobald drei Dinge da sind: der
  Lackshader (R3), das Showroom-Licht (UI1) und die Korrekturen A4–A6 und A9.

## 6. Was Renderer und Shader liefern müssen, damit die Modelle tragen (für R1, R3, UI1)

1. **Lackbelichtung** (A1, B8, C2): Helle Lacke dürfen nicht clippen, der Farbton muss bleiben. Messgröße: Anteil
   geclippter Lackpixel unter 5 % bei Mittagssonne, Farbton ±3° zum Sprite.
2. **Klarlack und Himmelsspiegelung** auf Lack und Glas, damit Glas nicht gemalt aussieht (B4).
3. **Kontaktschatten und abgedunkelte Radhäuser** – als Blob-Schatten, oder SSAO bei „Effekte: Voll“. Sonst schweben
   die Autos.
4. **`lamp_off` etwa 0,25–0,3** für Fahrzeuglampen (B1), dazu ein Bremsschein bei Tag wie in Arcade (Glow
   `brake * 0.35`).
5. **Rückstrahlende Kontur der Lkw** (C1), gespeist von den Scheinwerfern des Spielers.
6. **Flares an den Lichtankern** (F6): Die Leuchten sind ab etwa 150 m nur noch 1–2 px groß.

## 7. Bilder

| Datei | Inhalt |
|---|---|
| `01_spieler_9m_sprite_vs_modern.jpg` | Spielerautos aus der Spielkamera in 9 m: Sprite gegen Modern – volle Sprite-Auflösung, Spielauflösung, Voreinstellung „Niedrig“, Gegenlicht |
| `02_spieler_9m_gedreht.jpg` | dasselbe bei Gier ±10° und ±20° gegen die Sprite-Zellen |
| `03_limousine_nah.jpg`, `03_kompakt_nah.jpg` | Nahansichten: Heck, Leuchten bei Tag und Nacht, Räder, Innenraum, Front, Showroom-Stufe |
| `04_spieler_netz.jpg` | Ton, Facetten, Drahtgitter, Normalen, Rückseiten-Prüfung, Lampenkanäle, Schattenwerfer |
| `05_verkehr_sprite_vs_modern.jpg` | Verkehrsautos aus der Sprite-Kamera, vierfache Auflösung, 0° und 24° |
| `06_verkehr_stufen_sprite_aufloesung.jpg` | Sprite gegen lod0, lod1 und lod2 bei Sprite-Auflösung |
| `07_verkehr_spielkamera_tag.jpg` | Verkehr aus der Spielkamera von 10 bis 200 m, Arcade gegen Modern, bei 40 und 120 m beide Stufen |
| `08_verkehr_spielkamera_nacht.jpg` | dasselbe bei Nacht, mit Rücklicht und mit Bremse + Blinker |
| `09_verkehr_stufen_nah.jpg` | Stufen vergrößert und als Drahtgitter |
| `10_verkehr_nah.jpg` | Nahansichten der Verkehrsautos |
| `11_lkw_spielkamera.jpg` | Sattelzug von hinten in 20, 60, 150 und 250 m, Tag und Nacht, Arcade-Quader gegen Modern |
| `12_farbsets.jpg` | alle Farbsets |
| `13_lkw_nah.jpg` | Sattelzug nah: Ton, Schattenwerfer, Knickgelenk, lod2 |
| `14_spieler_bewegung_flimmern.jpg` | Flimmern in Bewegung gegen den Zellsprung von Arcade |
| `15_verkehr_lampen_je_stufe.jpg` | Lampenkanäle je Stufe von hinten |
| `16_showroom_ab.jpg` | Showroom-A/B: Kontaktbogen-Licht, weicheres Licht, Cycles-Sprite |
| `17_maengel_nah.jpg` | die Mängel A3–A7, B1–B3 und C3 im Einzelnen |
| `18_silhouette_sprite_modell.jpg` | Silhouette Sprite gegen Modell, gleiche Kamera (grau beide, rot nur Sprite, blau nur Modell) |

Werkzeuge und Rohdaten liegen im Arbeitsordner
`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK/`:

- `tools_kritik/kritik_render.gd`, `kritik_dump.gd`, `run_jobs.sh` – zum Wiederverwenden nach `tools/kritik/` einer
  Arbeitskopie legen.
- Skripte: `jobs_*.py`, `sheet_*.py`, `mesh_analysis.py`, `shimmer.py`, `lamps_x.py`, `silhouette.py`.
- Ergebnisse in `out/`: `validator.txt`, `mesh_analysis.txt`, `ce_stats_player.txt`, `shimmer.txt`, `lamps_x.txt`,
  `silhouette.txt`, Notizen.

Einzelkacheln, Netz-Abzüge und die Kopie des Arbeitsbaums wurden gelöscht (Platz). Eine Vorher/Nachher-Runde für AS1R
rendert in etwa 30 Minuten neu.
