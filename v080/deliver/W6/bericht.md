# Welle 6 – Stadthäuser Teil 2 (AS5b) und Wahrzeichen (AS6)

Zweig `wip/v080-welle6` (Arbeitsbaum `.claude/worktrees/qamid-fix`, Basis `c5533a3` = Testbuild 2), Kopf `0cde5d2` (Welle 6), danach N6 bis `2c0b1d0` und N2 ab `e93a622`.
Arbeitsordner `scratchpad/v080/m1/W6` (Notizen `runden.md`, Ansichten `shots/`, Rennvergleiche `ab/`, Skripte `*.sh`,
Logs `logs/`, Tore `gates/`). Doku: `docs/modelle.md` Abschnitte 23 (AS5b), 24 (AS6) und 25 (N2).

## 1. Kurzfassung

**Alle 46 Stadthaus-Sets und alle 33 Wahrzeichen mit Sprite haben jetzt ein echtes 3D-Modell.** Modern zeichnet
damit keine Arcade-Bilder mehr für Häuser und Wahrzeichen. Jedes Modell habe ich am Tag und in der Nacht neben
seinem Sprite angesehen (80–1 200 m) und, wo es geht, im Rennen gegen Arcade verglichen.

- **AS5b:** 23 Stadthaus-Sets (Plattenbau, Wien, Spanien, Italien, Mitteleuropa, Osteuropa, Balkan, Baltikum), alle
  gut. Zwei Nacharbeiten: dunkle bzw. helle Lückenfarbe der Gitter je nach Wand dahinter (spanische Casa, Jugendstil),
  und die Thujenhecke von Haus C (23 000 Dreiecke → dezimiert; eine zweite Dezimierung hatte 89 Dreiecke umgeklappt).
- **AS6:** 32 Wahrzeichen neu (dazu der Michel von früher). Neun Befunde gefunden und behoben (§4): Eiffelturm über dem
  Dreiecksbudget, Metall matt statt glänzend bzw. zu blau (Atomium, zwei Goldkuppeln), Texturbudget überschritten,
  Lichtflächen in den Fernstufen verloren, umgeklappte Splitter (Frankfurt), dazu sechs Prüfungsfehler durch die
  neuen Modelle.
- **Tore** (§6): alle in Ordnung – Modelle, Tests, 30 Render-Prüfungen, Arcade Bild für Bild unverändert; das
  einzige geänderte Modern-Golden-Bild habe ich angesehen (es zeigt jetzt die Elbphilharmonie).
- **N6 Blickwinkel – direkt danach erledigt** (§5): Die Arcade-Sprites zeigen jedes Wahrzeichen schräg von vorn
  (10–28° gedreht), die Modelle standen frontal und wirkten dadurch schmaler als in Arcade. Jetzt stehen sie im
  Blickwinkel ihres Sprites (gekürzt, wo eine lange Kirche sonst in die Häuserzeile schwenken würde). Im Rennen
  sichtbar besser: Sibiu, Mailand, Dresden, Koekelberg, Atomium; Fulda etwas. Alle Prüfungen danach wieder grün.
- **N2 Speichen des Riesenrads – danach erledigt** (§5): Die dünnen Stäbe flimmerten ab etwa 250 m. Jetzt zeichnet
  der Renderer sie mindestens ein gutes Pixel breit und entsprechend durchscheinend – in Bewegung so ruhig wie das
  Sprite, aus der Nähe unverändert.
- **Steam Deck** (§8): Deine Leistungstests mit Testbuild 1 und 2 zeigen, dass das Deck vom Prozessor begrenzt ist,
  nicht von der Grafik – „Hoch“ kostet nur 1–6 %. Die Voreinstellung „Steam Deck“ ist jetzt „Hoch“ mit den Schatten
  von „Mittel“.
- **Eine Frage an dich** (§2): die hellen Nachtfassaden – entschieden: „lebendig“ bleibt.
- **Rennanzeige und Radarwarnung nach deinem Wunsch** (§10): Oben gibt es keine Streckenübersicht mehr, nur noch
  „noch 104 km“ bis zum Ziel. Die Radarwarnung kommt je Radar 5–10 km vor dem Feld statt immer 10 km. Beides gilt in
  beiden Grafikmodi.

## 2. Frage an dich: Nachtfassaden heller als in Arcade (B-N1)

Nachts sind helle Fassaden in Modern 1,5–1,7-mal so hell wie in Arcade (gemessen im Rennen: Wien 59 gegen 35,
Warschau 63 gegen 41, Prag 55 gegen 34, Mailand 44 gegen 27 – Median der Fassade). Das liegt nicht an den
Modellen, sondern am Lichtgesetz von Modern (helle Farben werden nachts etwas angehoben; die Arcade-Bilder haben ihre
Schatten fest eingebacken). Die Fenster und Läden leuchten wie in Arcade. Angestrahlte Wahrzeichen trifft es kaum:
Die Nachtfassade der Elbphilharmonie misst 1,01 × Arcade, der Bremer Dom 0,97 ×.

**Frage:** So lassen (Modern nachts etwas freundlicher/heller), oder an Arcade angleichen (dunklere Fassaden, die
Fenster stechen mehr heraus)? Beides geht; ich würde es lassen, bis du das Spiel nachts selbst gesehen hast.

**Entschieden (27.11.):** lebendig lassen. Die Nachtfassaden bleiben so; Häuser, deren Fenster nachts schwächer
leuchten als Arcade (F-04: Hansehaus 0,46 ×), werden auf dieses Niveau angehoben (§9).

## 3. AS5b – Stadthäuser Teil 2

23 Sets in zwei Chargen, Bauer `city` wie AS5a, nur Katalog-Optionen – keine Änderung an Bauer oder Generator.
Tabelle, Maße und Messungen: `docs/modelle.md` Abschnitt 23. Je Set Ansicht 10/30/100/250 m Tag und Nacht neben dem
Sprite (`shots/`), Stufenwechsel lod0 → lod1 gemessen (1,4–17,7 % der Pixel, Helligkeit −2,2 … +3,1 %).

- **Rennvergleiche** (22 Stellen in 15 Städten, Arcade gegen Modern im selben Zustand, „Hoch“): Warschau, Leipzig,
  Wien, Linz, Madrid, Mailand, Venedig, Bordeaux, Prag, Budapest, Belgrad, Sofia, Kaunas, Riga, Sibiu – Umriss,
  Maßstab und Farben an derselben Stelle wie Arcade, Modern mit Tiefe, Gittern, Läden und Schatten. Alle gut.
- **Nacharbeit:** Gitter-Lückenfarbe je nach Wand dahinter (Rejas der Casa aus 100 m sonst graue Kästen, Jugendstil-
  Balkone sonst schwarze Blöcke); Haus C: Thujenhecke dezimiert, lod1 nicht ein zweites Mal (sonst 89 umgeklappte
  Dreiecke).
- **Bekannt, nicht behoben:** Gartenhäuser sparen in lod1 wenig (Haus A 6 980 von 8 170 Dreiecken, im Budget); die
  Tambourkuppel der Wiener Kirche verdeckt aus Straßenhöhe der Giebel; Hauszeichen des Barockhauses achteckig.

## 4. AS6 – Wahrzeichen

32 Modelle aus dem Bauer `prop_baked` (wie der Michel): Geometrie des Generators in echter Größe, Materialien in einen
Atlas gebacken, die Nachtbeleuchtung des Generators im Leuchtatlas. Chargen L1 (Kiel–Hamburg bis Riga, 9), L2 (Wien
bis Mailand, 11), L3 (Venedig bis Bukarest, 12). Alle 32 im Budget (höchstens 17 816 Dreiecke, Grenze 25 000);
zusammen 3,5 MB Netze und 21,7 MB Texturen im Archiv. Tabelle: `docs/modelle.md` Abschnitt 24.

**Angesehen:** jedes Modell bei 80/250/600/1 200 m, 12 und 22 Uhr, mit dem Arcade-Sprite darunter
(`shots/l1_* … r5_*`): Umriss, Gliederung und Farben wie die Sprites, aus der Nähe echte Tiefe (Helme, Fialen,
Maßwerk, Kuppeln, das Gitter des Eiffelturms, die Speichen des Riesenrads). Nachts angestrahlt und mit Fenstern wie
die Lichtebene der Sprites.

**Befunde und was ich gemacht habe:**

| | Befund | Behoben durch |
|---|---|---|
| E1 | Eiffelturm 25 152 Dreiecke (Grenze 25 000) | neue Option `drop_caps`: die verborgenen Stirnflächen der Gitterträger fallen weg → 17 072, keine Löcher sichtbar |
| A1 | Atomium matt grau statt Chrom | neue Option `vpbr` + `overrides`: Stahl als Metall (nicht eingebacken) |
| N4, N5 | Goldkuppeln (Newski, Erlösung) matt senfgelb | dasselbe: Gold als Metall, nachts angestrahlt |
| A2 | Atomium im Rennen kräftig blau (das Metall spiegelte nur den Himmel) | Stahl etwas weniger metallisch, dunkleres neutrales Grau: Glanzlicht und Horizontband wie im Sprite, nur noch leicht bläulich |
| B1 | Texturquellen 60,04 von 60 MB | Atlasgröße je Wahrzeichen (groß/mittel/schlank), Wahrzeichen-Atlas immer WebP → 58,7 MB |
| B2 | Fernstufen verloren bis 75 % der angestrahlten Goldfläche | bei den zwei Goldkuppel-Kathedralen keine automatischen Fernstufen (je ~5 000 Dreiecke) |
| B3 | Frankfurt: 11 umgeklappte Dreiecke (Splitter ohne Höhe) | Wahrzeichen-Bauer verwirft Splitter unter 0,1 mm wie die anderen Bauer |
| T1 | Mailänder Dom, Atomium, Elbphilharmonie: beim Drehen zur Anfahrt bis 26,7 m vom Arcade-Anker verschoben (Grenze 12 m) | `capped_turn()`: lange Grundrisse drehen nur so weit, wie der Knoten rücken darf (Test dazu) |
| T2–T6 | Vier Tests und eine Render-Prüfung erwarteten noch Bilder statt Modelle bzw. ein Set ohne Modell | nachgezogen (Test-Manifest wie bei den Fahrzeugen, Toleranz des Ankers mit Begründung) |

**Nicht Teil dieser Welle:** Die zehn Wahrzeichen ohne Generator und ohne Sprite (Neues Rathaus Hannover,
Florianturm, Völkerschlachtdenkmal, Cuatro Torres, Hl. Sava, Leuchtturm Calais, Herkules, Sacré-Cœur, Colonius,
Fernsehturm Riga) zeichnet Modern weiter als einfache 3D-Form – genau wie Arcade sie als Form zeichnet. Ein echtes
Modell braucht einen neuen Generator (und würde Arcade nicht ändern dürfen).

## 5. Offene Punkte und Vorschläge

- **N6 Blickwinkel der Wahrzeichen – erledigt:** Die Sprites zeigen jedes Wahrzeichen in einer Schrägansicht
  (10–28° gedreht), die Modelle standen frontal. Jetzt trägt jedes Modell den Winkel seines Sprites, und der
  Renderer dreht es darum. Beim Drehen schwenkt das Ende langer Kirchen zur Straße; hinter dem Wahrzeichen stehen die
  Stadthäuser (der freie Platz gehört zur gemeinsamen Strecke mit Arcade). Deshalb wird der Winkel gekürzt, wo der
  Grundriss sonst näher als 36 m an die Fahrbahn käme: 78 Aufstellungen im Netz stehen jetzt schräg, 15 davon
  gekürzt (Fulda 12° statt 22°), Timișoara und die Sagrada Família (nah an der Straße) bleiben fast frontal.
  Vorher/nachher im Rennen (`ab/n6_cmp_*.jpg` im Arbeitsordner): Sibiu zeigt jetzt Turm und langes Schiff wie Arcade, Mailand die
  lange Flanke, Dresden und Koekelberg wie Arcade, Fulda etwas schräger. Tests (857 / 0), Render-Prüfung der
  Wahrzeichen, Arcade-Golden unverändert, Modern-Golden: ein Bild angesehen und erneuert (Michel leicht gedreht).
- **N2 Speichen des Riesenrads – erledigt:** Die 968 Stäbe des Rads (Speichen, Kränze, Streben, Pylone) werden ab
  etwa 250 m schmaler als ein Pixel und flimmerten in Bewegung. Sie sind jetzt eine eigene Flächenklasse („thin“):
  Der Shader macht jeden Stab mindestens 1,5 Pixel breit und zeichnet ihn entsprechend durchscheinend – so viel
  Abdunklung, wie der echte Stab hätte (gemessen 0,97–0,99 ×). Bildwechsel je Bild bei 250 / 600 / 1 000 m vorher
  6,5 / 8,8 / 4,5 %, jetzt 2,0 / 0,2 / 0,1 % – wie das Sprite (2,1 / 0,6 / 0,1 %); auch ohne Kantenglättung
  („Niedrig“) unter dem Sprite. Aus der Ferne ist die Speichenscheibe jetzt ein ruhiger, feiner Schleier statt eines
  gepunkteten Musters; aus der Nähe unverändert echte Stäbe. Das Modell ist kleiner geworden (13 944 statt 17 816
  Dreiecke, 307 statt 637 kB). Neue Render-Prüfung `check_thin_render`, Doku `docs/modelle.md` Abschnitt 25.
  Im Rennen (`ab/n2_*` im Arbeitsordner) steht das Rad an derselben Stelle wie in Arcade und sieht aus wie dort;
  nachts sind die Kränze angestrahlt, die hellen Striche, die vorher auf einzelnen Speichen lagen (Licht aus dem
  Atlas), sind weg – auch das Sprite zeigt sie nicht. Der Eiffelturm brauchte das nicht (er flimmert nicht mehr als
  sein Sprite).
- **N3 Kathedrale Burgos** ist schon im Generator schlicht (Rosette eine flache Scheibe) – Modell und Sprite gleich.
- **Rennvergleiche der Wahrzeichen:** Vom Platz vor dem Bauwerk steht es oft am Bildrand oder hinter Parkbäumen –
  so sieht man es auch im Rennen. Wo es im Bild ist, steht es an derselben Stelle wie in Arcade; Ausnahmen sind nur
  die frontale Ansicht (N6) und nahe 3D-Häuser, die einen Turm verdecken können, wo Arcade das Hausbild schon
  weggelassen hat (Berlin, physikalisch richtig).

## 6. Tore

Auf dem Endstand (Kopf `0cde5d2`), mit „Hoch“ wo nicht anders genannt, Software-Grafik (llvmpipe):

| Tor | Ergebnis |
|---|---|
| Modellprüfung `validate_models` | in Ordnung: 165 Modelle, alle 183 Sets mit Modell; Netze 25,8 von 40 MB, Grafikspeicher 219,5 von 240 MB, Texturquellen 58,7 von 60 MB |
| Sprite-Geometrie (Requisiten) | in Ordnung |
| Einheitstests | 856 Tests, 0 fehlgeschlagen, dazu alle Zusatzprüfungen von `run_tests.sh` in Ordnung (Endstand, ganze Suite) |
| Render-Prüfungen Modern | 30 von 30 Dateien in Ordnung (die Spiegel-Prüfung nach dem Test-Manifest); darunter die Wahrzeichen-Prüfung jetzt mit Modellen: Elbphilharmonie an Arcades Stelle (8 px), Nachtfassade 1,01 × Arcade, Anstrahlung Bremer Dom 0,97 × |
| Golden Arcade | unverändert (Arcade Bild für Bild gleich) |
| Golden Modern | 5 von 6 Bildern gleich; `modern_s4_mittel` zeigt hinter einem Backsteinhaus jetzt das Glas der Elbphilharmonie (221 Pixel) – angesehen, neue Prüfsumme committet |
| OpenGL ES gegen OpenGL | gleich (höchstens 2/255) |

**Nach N2** (Kopf `e93a622`, Doku `0ca7799`): Modellprüfung in Ordnung (Netze 25,6 von 40 MB, Texturquellen 58,5 von
60 MB), Einheitstests 858 / 0 und alle Zusatzprüfungen, Render-Prüfungen 31 von 31 (neu `check_thin_render`: Blöcke
je Bild mit Verbreiterung 3,9 / 1,7 / 1,1 % gegen 8,1 / 5,9 / 4,9 % ohne, Deckung 0,97–0,99 ×), Golden Arcade 20 / 20
und Oberfläche 17 / 17 gleich, Golden Modern 6 / 6 gleich, OpenGL ES gegen OpenGL höchstens 2/255.

Beim ersten Lauf der Einheitstests fielen fünf Tests, bei den Render-Prüfungen eine – alle wegen der neuen Modelle
(die Tests nahmen an, dass es noch Bilder bzw. Sets ohne Modell gibt, und drei lange Wahrzeichen rückten beim
Drehen zu weit). Behoben und nachgeprüft (Tabelle in §4).

## 7. Hinweise

- Der Commit `2e2a41c` heißt „atomium ohne Stirnflaechen der Gittertraeger“ – das stimmt nicht: Er enthält den
  Neu-Export des Atomiums mit Stahl als Vertex-PBR (die Warteschlange hat die Nachricht des Eiffelturms übernommen).
  Ich habe die Geschichte nicht umgeschrieben.
- `smooth=("cba_sign",)` im Katalog (Barockhaus) wirkt nicht – der Generator glättet das Hauszeichen schon. Harmlos,
  bleibt stehen.

## 8. Steam Deck: Voreinstellung nach deinen Messungen

Deine vier Leistungstests (Deck OLED, 1280×800; Testbuild 1 und 2, je „Steam Deck“ und „Hoch“):

| | Testbuild 1 | Testbuild 2 |
|---|---|---|
| „Steam Deck“ (alt), Bilder/s Autobahn / Stadt / Berg | 111 / 114 / 120 | 119 / 108 / 118 |
| „Hoch“, Bilder/s | 106 / 109 / 113 | 115 / 103 / 114 |
| Reserve zu 60 fps (alt / Hoch) | 1,87 / 1,77 | 1,84 / 1,74 |

- „Hoch“ kostet nur 1–6 % mehr Bildzeit: Das Deck ist vom Prozessor begrenzt, nicht von der Grafik.
- **Neue Voreinstellung „Steam Deck“** (Vertrag A-30): Schatten 2 (wie „Mittel“), Details 2, 100 %, MSAA 4×,
  Effekte 2 (wie „Hoch“) – jeder Wert auf oder unter dem gemessenen „Hoch“, also durch deine Messung abgedeckt
  (mindestens 103 Bilder/s im Mittel). Gespart sind nur die Schatten: auf 7 Zoll kaum zu sehen, in der Stadt aber die
  meisten Zusatzdreiecke. Der Wächter senkt „Steam Deck“ bei Bedarf auf „Mittel“.
- Offen für das Leistungspaket: je 20 s Autobahn ein Bild von 19–24 ms beim Nachladen der Strecke (Skript dabei
  höchstens 8 ms, der Rest liegt in der Engine – vermutlich Texturen beim ersten Erscheinen); angedockt an 1080p,
  Akku und Lüfter sind nicht gemessen.
- Doku: `docs/steam-deck.md` „Leistungstest Modern auf dem Deck“.

## 9. Modell-Rückstau A-29: Stand

| Punkt | Ergebnis |
|---|---|
| Bremslicht des Verkehrs-Sportwagens (FIX-M2 B-04) | **behoben** (`54535c4`, nur im 3D-Modell): Lichtband 5,5 statt 3 cm, drittes Bremslicht oben an der Heckscheibe mit eigenem Lichtanker. Rote Pixel bremsend, Arcade / vorher / jetzt: Tag 20 m 218 / 129 / 195, 60 m 34 / 12 / 15 (dazu der rote Schein des dritten Bremslichts, den die Zählung über gelbem Lack nicht erfasst – im Bild deutlich); Nacht 60 m 95 / 75 / 95 |
| Sportwagen in der Dämmerung (B-06, +14 % Sättigung) | nachgemessen: +6 % – erledigt durch die spätere Lackarbeit |
| Limousine in der Dämmerung | nachgemessen: Leuchtdichte gleich, Sättigung 0,36 gegen 0,39 – erledigt |
| Gran Turismo nachts silbern statt blaugrau | nachgemessen: Karosserie im Mittel gleich hell wie Arcade; der Unterschied ist der Blauton, den Arcade nachts jedem Sprite gibt – Modern beleuchtet das Silber neutral. Die vereinbarte Prüfung hält er (Leuchtdichte 0,92 ×, Sättigung 0,77 ×, Grenze 0,7 ×). Kein Eingriff (ein weniger helles Fülllicht machte ihn nur dunkler, nicht blauer) |
| Fenster der Tankstelle, des Bauernhofs, des Zollhäuschens (A-16) | angesehen: tags dunkle Scheiben, nachts warm erleuchtet – gut, kein Umbau nötig |
| Flimmern Kontor (lod1), Grachtenhaus, Chalet (lod0) | nachgemessen (Bildwechsel bei 120 km/h, Modell / Sprite): Kontor 100 m 7,5 / 4,9 %, 150 m 1,2 / 0,4 %; Grachtenhaus 40 m 19,5 / 17,3 %; Chalet 40 m 5,2 / 4,1 % – 1,1–1,5 × das Sprite (das Kontor bei 150 m 3 × auf niedrigem Niveau: helle Fensterrahmen auf dunklem Backstein). Kein Eingriff |
| Gartenbaum (K3), Wandleuchten (K9), Fernblässe Maashaus | schon in AS5aR2 / FIX-R7c behandelt |
| Rückseite Eckhaus (K8) | offen, klein (8 Aufstellungen, nur in Kurven sichtbar) |
| Nachtfenster der Stadthäuser (Hansehaus 0,46 × Arcade) | offen – gehört zu deiner Frage B-N1 (Nachtfassaden der neuen Häuser 1,5–1,7 × Arcade): beides zusammen abgleichen, sobald du entschieden hast |

## 10. Rennanzeige ohne Streckenübersicht, Radarwarnung 5–10 km vorher (dein Wunsch)

**Anzeige oben:** Der Balken mit den Markern (Tankstellen, Radare, Tunnel, Grenzen, City Limits) ist weg. Unter der
Zeit steht nur noch eine kleine Lasche mit Zielflagge und der Entfernung zum Ziel: „noch 104 km“, auf den letzten
10 km mit einer Nachkommastelle („noch 3,6 km“). Eine Zeitstrafe erscheint als Plakette direkt darunter. Die Meldungen
in der Bildmitte bleiben, wo sie waren. Die nächste Tankstelle steht weiter im Tank-Panel unten links, ein Radar weiter
oben rechts, sobald es angekündigt ist.

**Radarwarnung:** Jedes Radar kündigt sich jetzt 5, 6, 7, 8, 9 oder 10 km vor seinem Feld an, statt immer 10 km.
Der Abstand ist „zufällig“, aber fest je Radar und Fahrtrichtung: Er wird aus der Kennzahl der Etappe gezogen. Dieselbe
Etappe warnt also jedes Mal an denselben Stellen – Bestzeiten bleiben vergleichbar, und das Schild am Straßenrand
(„7 km“), die Meldung („Radarkontrolle in 7 km – Limit 120 km/h“) und das Radar-Panel nennen immer dieselbe Zahl.
Über das ganze Netz verteilen sich die 281 Radare gleichmäßig: 41 bis 53 Radare je Abstand. Beispiel Kiel – Hamburg:
hin 8 km, zurück 10 km.

Falls dir lieber ist, dass der Abstand bei *jeder Fahrt* neu gewürfelt wird (dann kann man ihn sich nicht merken),
sag Bescheid – das ist eine kleine Änderung.

**Arcade:** Die Anzeige ist in beiden Modi dieselbe, also ändert sie sich auch in Arcade. Bisher müssen die
Arcade-Bilder genau denen von v0.7.0 entsprechen. Damit diese Prüfung scharf bleibt, entstehen die Referenzbilder jetzt
aus v0.7.0 **plus genau dieser Änderung** (`tests/golden/arcade_ref.patch`, Vertrag A-32). Alles andere, vor allem der
eingefrorene Arcade-Renderer, wird weiter Pixel für Pixel gegen v0.7.0 geprüft.

Bilder (vorher/nachher): `scratchpad/v080/m1/W6/hud/before/n2_00.png`, `…/hud/after/n2_00.png`, `c1_00.png` (Ziel
in 3,6 km), `demo_00.png` (Radarwarnung und Zeitstrafe).

Tests: Je Radar im ganzen Netz liegt der Abstand bei ganzen 5–10 km, derselbe Plan ergibt dieselben Abstände, ein
übersprungenes Radar verschiebt die anderen nicht, und eine feste Zahl in der Konfiguration gibt wieder die alte
10-km-Regel.

Prüfungen (Stand 2977f70 + 8f6c0d1 + 8e9a3ea):

| Prüfung | Ergebnis |
|---|---|
| Arcade-Referenz neu (`tools/golden.sh make`, v0.7.0 + `arcade_ref.patch`) | ohne Fehler; 23 geänderte Bilder (20 Rennen, 3 Menü-/Demo-Bilder mit Anzeige) einzeln angesehen: nur die Anzeige oben ist anders |
| Arcade gegen die neue Referenz (`check`) | 20 von 20 Rennbildern, 17 von 17 Menübildern identisch |
| Modern vor der Neuaufnahme (`modern-check`) | 0 von 6 identisch – erwartet: Anzeige in allen Bildern, Radarschild in S2, Rücklicht A-29 im Nachtbild; alle 6 angesehen |
| Modern OpenGL ES gegen OpenGL | max. Abweichung 2/255, 73,2 dB |
| Modern nach der Neuaufnahme (`modern-check`, zur Bestätigung) | 6 von 6 identisch |
| Ganze Suite (`tools/run_tests.sh`) | 860 Tests, 0 fehlgeschlagen, alle CHECKS OK |
| Alle Render-Prüfungen (`tools/run_render_checks.sh all`) | 33 von 33 Prüfdateien in Ordnung |
