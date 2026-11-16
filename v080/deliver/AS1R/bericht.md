# AS1R – Nacharbeit der Fahrzeugmodelle nach der Kunstkritik: Bericht

- Paket: AS1R (v0.8.0, M1) · Zweig `worktree-wf_9693abb2-cee-3` · Sicherheitskopie `origin wip/v080-as1r`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3`
- Basis: `d025d1d` (R1a + AS1). Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL llvmpipe unter Xvfb,
  Licht des Kontaktbogens), wo nichts anderes steht. Alles über Steam Deck, echte Grafikkarten und die Wirkung auf
  einen Menschen ist **abgeleitet**.

## 1. Ergebnis in Kürze

Jeder Befund der Kritik wurde zuerst am Netz oder im Bild nachgeprüft. Bestätigt und am Modell behoben: bei den
Spielerautos A2–A6 und die günstigen niedrigen A7, A10, A11; bei den Verkehrsautos B3–B7 und die Modellseite von B1;
beim Sattelzug C1–C3. Zwei Befunde hatten eine andere Ursache als vermutet (A3: die Hutablage, nicht die Heckblende;
A4 Limousine: der Boden der Innenraumwanne, nicht Radlaufschale und Schweller). Nicht erreicht: der Stufenwechsel
bei 120 m (22–34 % statt ≤ 10 %), und die Leuchten der Verkehrsautos sind weiter flache, eingeschnittene Felder (B2).
Nicht am Modell lösbar und deshalb offen für den Renderer: Lackbelichtung (A1, B8, zum größten Teil C2),
unbeleuchtete Lampen bei Tag (B1: `lamp_off`), Klarlack und Spiegelung, Kontaktschatten, Schein an den Ankern.

Prüfungen: Prüfer grün; Sprite-Geometrie 187 von 187 identisch; erzwungener Neuexport und zweiter Bake aller sechs
Fahrzeuge byte-gleich; `--check-keys` OK; `run_tests.sh` bestanden (576 Unit-Tests und 89 Prüfungen, 0 fehlgeschlagen);
`golden.sh check` 20 von 20 identisch; Render-Prüfung der Modelle 6 von 6 OK.

`showroom` bleibt für beide Spielerautos `false` (Abschnitt 6).

## 2. Was sich am Modell geändert hat

**Spielerautos (Heck in 9 m = die ganze Spielzeit im Bild)**
- Rückleuchten: Der Leuchtenkörper hat das volle Gewicht auf Kanal 2 – nachts glimmt die ganze Leuchte mit dem
  Rücklicht, nicht nur die Lichtleiter; die Bremse bleibt ein großer Schritt (Bild 01, 02).
- Schulter über den Rückleuchten (Kompakt) ohne schwarzes Blatt; Hutablage folgt der Außenhaut (Bild 03).
- Stoßfänger enden am Radlauf und laufen dort mit 5 cm Radius in die Karosserie; der vordere des Kompakten stand
  vorher 9 cm im Radlauf und 52 mm im Reifen. Wanne und Armaturenbrett bleiben aus den Radhäusern, auch bei 25°
  Lenkeinschlag (Netzanalyse: 0 Ecken im Reifenvolumen).
- Räder: Bremsscheibe mit harten Kanten und matt, Limousinen-Felge anthrazit wie im Sprite.
- Kennzeichen hellgrau mit kräftigeren Zeichen, Fugen 8 mm.
- Innenverkleidung als grober eigener Loft: Innenraum 3 560 / 3 658 Dreiecke (Budget 6 000); der Export bricht
  über 6 000 ab.
- Dritte Bremsleuchte der Limousine als nach hinten blickende Fläche (Lichtanker mit `dir`).
- Schattenwerfer 12 mm innerhalb der Haut **mit** Lampen- und Grillmulden, Radläufe offen.

**Verkehrsautos (10–150 m)**
- Felgen anthrazit, Glas heller und spiegelnd (alle Stufen), dritte Bremsleuchte unbeleuchtet dunkel.
- Kennzeichen in `lod1`/`lod2` grau (Mittelwert mit Zeichen) und in `lod2` behalten; Spiegelglas in allen Stufen;
  dunkler Heckabschluss in `lod2` (Limousine, Kombi).
- Heck aus der Nähe: Fugen von Kofferraumklappe bzw. Heckklappe, Emblem, Stoßfänger-Enden rund, Auspuff als dunkles
  Rohr unter dem Auto statt eines schwebenden Chromrings.
- Reifen mit 9 Profilpunkten (Platz im Budget), Schattenwerfer mit offenen Radläufen.

**Sattelzug**
- Rückstrahlende Kontur, Seitenband und Dreiecke leuchten nachts (Kanal 14), bei Tag in ihrer Farbe.
- Weiße Lackierungen `#d8d8d6` statt `#ececea`.
- Schattenwerfer aus den wirklichen Teilen statt Kasten und Platte.

**Werkzeuge und Prüfer**
- Kontaktbogen: `--clay` (Ton), `--caster` (Werfer rot), Ansichten Vorderrad / Radhaus / Heck bei Nacht aus Kamerahöhe.
- Prüfer: Lichtanker von Fahrzeugen ohne `dir` sind ein Fehler (A-4).

## 3. Befunde der Kritik: geprüft, Ursache, Behebung

Jede Zeile wurde vor der Änderung am Netz oder im Bild nachgeprüft (Netzabzug `bin/dump.gd` + `bin/ana.py`,
`bin/probe.py`, Blender-Objektsuche `bin/objs_near.py`, Ton- und Werfer-Ansichten des Kontaktbogens).

| Nr. | Befund (Kritik) | geprüft | tatsächliche Ursache | Behebung | Ergebnis (gemessen) |
|---|---|---|---|---|---|
| A2 | Rücklicht nachts nur Lichtleiter | bestätigt: Kanal 2 Gewicht 0,50 (Netzabzug) | `cardetail._LAMP3D_TAIL["tail"] = "tail_brake:0.5"` | Gewicht 1,0 | ganze Leuchte glimmt (Bild 01, 02); Summe Bremse/Rücklicht linear ≈ 4,5 (Limousine, aus Flächen × Gewicht × Pegel gerechnet) |
| A3 | Kompakt: schwarzer Keil über den Rückleuchten = Ende der Heckblende | **Ursache anders**: im Tonbild ein waagrechtes Blatt; Blender-Suche: die **Hutablage** (Kasten über die volle Kabinenbreite) stand mit ihrer hinteren Ecke aus der gerundeten Schulter; die Heckblende hing zusätzlich 5 mm über der Leuchtenmulde | Hutablage folgt der Außenhaut (`interior3d._shelf`, `outer_z`); Heckblende über Mulden weggeschnitten; Mulden-Splitter (Leuchte streift die Kabine) bekommen keine Mulde mehr | Tonbild ohne Blatt (Bild 03) |
| A4 | Stoßfänger 52 mm im Vorderreifen (Kompakt); Radlaufschale/Schweller im Reifen (Limousine) | Kompakt bestätigt, Ursache: `curves.stations` setzt die Stationen der Endrundung (r_plan + 5 cm = 55 cm) auch jenseits des 46 cm kurzen Stoßfängers – der Loft lief 9 cm in den Radlauf. Limousine: **Ursache anders** – es war der Boden der Innenraumwanne (`#17181a`), nicht Schale oder Schweller | Hook `bumper_clamp`; Wanne und Armaturenbrett mit Abstand zu den Rädern, auch bei 25° Lenkeinschlag | 0 Karosserie-Ecken im Reifenvolumen bei −25…+25° (Netzanalyse, Abschnitt 5) |
| A5 | Stoßfänger-Enden als flache Kappen | bestätigt | Loft endet senkrecht am Radlauf | Hook `bumper_end_r` 5 cm (Spieler und Verkehr `lod0`) | Bild 02, 05 |
| A6 | Bremsscheibe wie polierte Kugel; Limousinenfelgen hellsilber | bestätigt | gedrehter Kasten glatt schattiert; Felge Metall 0,55 hell | harte Kanten 30°, Gusseisen matt; Felgenfarbe wie im Sprite (`#6a6e74`) | Bild 02 |
| A7 | Flimmern von Kennzeichen und Fugen | übernommen (Bewegungsmessung nicht wiederholt) | dünne Zeichen auf Weiß, Fugen 7 mm | Kennzeichen `#d3d4d0`, Zeichen ×1,5 kräftiger, Fugen 8 mm | nicht neu gemessen |
| A10 | Werfer vor Mulden; Anker ohne `dir` | bestätigt (30 mm vor dem Grillgrund) | Hülle gegen die Haut **vor** den Mulden eingezogen; geschlossener Kasten | Hülle gegen die Haut mit Mulden; Lampe als nach hinten blickende Fläche; Prüferregel | Werfer 12,0 mm innen; alle Fahrzeuganker mit `dir` |
| A11 | Innenraum Kompakt 6 268 > 6 000 | bestätigt | Verkleidung = volle Kabine (4 112 Dreiecke) | grober Verkleidungs-Loft, Export-Wächter | Kompakt 3 658, Limousine 3 560 |
| B1 | unbeleuchtete Lampen wirken an | bestätigt; Hauptursache `lamp_off` 0,5 im Shader (R3) | dritte Bremsleuchte: halbe Leuchtfarbe = heller Balken | dunklere Leuchtfarbe der dritten Bremsleuchte (Hook `chmsl_lamp`) | unbeleuchtet (92, 11, 6) statt (128, 18, 10) – gerechnet |
| B3 | Stufensprung 40/120 m | bestätigt | Kennzeichen weiß bzw. weg, Spiegel lackfarben, `lod2`-Heck ohne dunklen Abschluss, grobe Kabine | Kennzeichen grau in allen Stufen und in `lod2` behalten; Spiegelglas in allen Stufen; dunkler Heckabschluss in `lod2` (nicht Schrägheck) | 40 m 6,6–9,8 %, 120 m 22–34 % (Bild 07) |
| B4 | Glas wirkt gemalt | bestätigt | dunkles Navy, Rauheit 0,03, kein Metall | `#2a343e`, Rauheit 0,02, Metall 0,25 in allen Stufen | Bild 05 |
| B5 | Felgen hellweiß | bestätigt | Designfarbe `#b8bcc2` | `#5a5d62`, Metall 0,6, Rauheit 0,35 in allen Stufen | Bild 05 |
| B6/B7 | glattes Heck, Kastenstoßfänger, schwebender Auspuffring | bestätigt | – | Kofferraum-/Heckklappenfugen, Emblem, runde Stoßfänger-Enden, Auspuff als dunkles Rohr | Bild 05 |
| C1 | Kontur nachts dunkel | bestätigt; Gewicht ist 1,0 (nicht 0,79): der Faktor `plate_energy` 0,45 macht sie dunkel | Kanal 8 | Kanal 14 (rückstrahlend über `ce_night`), Gewicht 0,8 | Bild 08 |
| C2 | Weiß ohne Form | bestätigt (Belichtung des Kontaktbogens) | `#ececea` | `#d8d8d6` | im Kontaktbogen-Licht weiter übersteuert (R1/R3) |
| C3 | Werfer ragt aus der Hülle | bestätigt | Kasten unter dem Fahrerhaus, Platte unter dem Auflieger | Werfer aus den wirklichen Teilen | Bild 09 |

## 4. Was nicht am Modell liegt (für R1, R3, UI1)

Diese Befunde der Kritik sind richtig, aber das Netz kann sie nicht beheben:

1. **Lackbelichtung** (A1, B8, C2): Kompakt-Gelb und Weiß übersteuern im Licht des Kontaktbogens, weil die Sonne in
   sRGB addiert wird (D5). Die Lackwerte sind die des Sprites. Am Modell nur: Weiß des Lkw auf `#d8d8d6`.
2. **Unbeleuchtete Lampen bei Tag** (B1, B2): unbeleuchtet zeichnet `vpbr` eine Lampe mit `lamp_off` 0,5 × ihrer
   Leuchtfarbe – Rot (128, 16, 8) und Bernstein (128, 80, 13) wirken eingeschaltet und flächig („Aufkleber“).
   Vorschlag: `lamp_off` 0,25–0,3 für Fahrzeuge (das Sprite zeigt die Lampen dunkelrot, `#8a0c0a` mit Klarlack).
   Am Modell nur die dritte Bremsleuchte dunkler (sie bleibt beim Bremsen voll, Verstärkung 2,2).
3. **Rücklicht-Pegel**: Kanal 2 leuchtet mit dem Rücklicht zu 35 %; die Sprite-Schicht `tail` lässt die ganze
   Leuchte voll leuchten. Die Modelle haben jetzt das volle Gewicht; ein Pegel von etwa 0,5 hielte Bremse ≥ 2 × Rücklicht.
4. **Klarlack, Spiegelung, Kontaktschatten, Umgebungsverdeckung** – Shader und Renderer.
5. **Rückstrahlende Kontur**: Kanal 14 folgt `ce_night`; besser wäre die Beleuchtung durch die Scheinwerfer des
   Spielers (`ce_headlight`), dann leuchtet sie auch im Tunnel und nicht bei Nacht ohne Scheinwerfer.
6. **Ferne Lampen** (C5): ab etwa 150 m 1–2 Bildpunkte – Schein an den Lichtankern (F6).

## 5. Messungen (gemessen)

**Dreiecke, Budgets §4.6.9, Zeichenaufrufe** (`validate_models.py --report`, Exportbericht):

| Modell | lod0 | lod1 | lod2 | show | Werfer | Aufrufe | Netze (Bytes) |
|---|---|---|---|---|---|---|---|
| `player/limousine` | 44 095 / 55 000 | – | – | 94 629 / 120 000 | 2 320 / 3 000 | 6 / 6 | 1 527 819 |
| `player/kompakt` | 47 524 | – | – | 100 332 | 2 320 | 6 / 6 | 1 661 802 |
| `traffic/sedan` | 17 555 / 18 000 | 5 809 / 6 000 | 1 149 / 1 200 | – | 972 | 6 / 1 / 1 | 271 351 |
| `traffic/hatch` | 17 636 | 5 661 | 1 180 | – | 988 | 6 / 1 / 1 | 270 561 |
| `traffic/wagon` | 17 464 | 5 941 | 1 141 | – | 940 | 6 / 1 / 1 | 276 055 |
| `traffic/truck` | 18 084 / 25 000 | 4 672 / 7 000 | 1 490 / 1 500 | – | 476 | 13 / 1 / 1 | 161 851 |

Vorher (AS1): Limousine lod0 45 764, Kompakt 50 080, Verkehr lod0 17 317–17 888 (Kombi 112 Luft), Werfer Pkw 604–652.
Platz geschaffen hat der Reifen mit 9 Profilpunkten (rund 300 Dreiecke je Rad, `tyre_lite`); ausgegeben für runde
Stoßfänger-Enden, Fugen und Emblem, Kennzeichen in `lod2`, Werfer mit Radlauföffnungen.

**Innenraum der Rennstufe** (Exportbericht, samt Verkleidung): Limousine 3 560, Kompakt 3 658 (vorher 5 602 und
6 268; Budget 6 000).

**Freigang Räder ↔ Karosserie** (Netzanalyse wie in der Kritik: Ecken der Karosserie im Reifenvolumen, Räder
drehend, Vorderräder −25° … +25°): 0 Ecken bei allen Rädern von Limousine und Kompakt (`lod0` und `show`) und der drei Verkehrsautos (vorher: Kompakt bis 52 mm, Limousine bis 77 mm, beides Stoßfänger bzw. Wanne).

**Schattenwerfer** (Exportbericht): Spielerautos vorher bis 30,0 mm (Limousine, Grillgrund) bzw. 16,9 mm (Kompakt)
außerhalb der Haut samt Mulden, nachher 12,0 mm innen. Werfer-Ansicht (Bild 09): rot nur an Kanten, in den Trommeln
hinter den Felgen und hinter dem durchsichtigen Glas (dort sieht man den Kabinenteil des Werfers durch die Scheiben;
im Spiel wirft er nur Schatten).

**Lampen** (`bin/ana.py lamps`: Kanal, Gewicht, Fläche von hinten): Limousine `lod0`: Kanal 2 (Leuchtenkörper) Gewicht 1,00, 645 cm² von hinten (vorher Gewicht 0,50); Kanal 0 (Lichtleiter) 207 + 22 cm²; Kanal 1 (Bremssegment) 185 cm². Kompakt `lod0`: Kanal 2 Gewicht 1,00, 748 cm²; Kanal 0 123 + 43 cm²; Kanal 1 152 cm². Verkehrs-Limousine: dritte Bremsleuchte Kanal 1 mit Leuchtfarbe `#9a1208` (120 cm² von hinten in jeder Stufe); Kennzeichen Kanal 8 in `lod1`/`lod2` `#c4c4c1`, 572 cm². Alle Lampenregeln des Prüfers grün (Rücklicht, Bremslicht, Blinker hinten ≥ 60 / vorn ≥ 40 cm² je Seite in jeder Stufe).

**Stufenwechsel** (Spielkamera 1280 × 720, Tag, Anteil der Autopixel, die sich um mehr als 24 Stufen ändern;
`bin/pop.sh` + `bin/popmeasure.py`; Bild 07):

| Auto | 40 m `lod0`→`lod1` vorher → jetzt | 120 m `lod1`→`lod2` vorher → jetzt |
|---|---|---|
| Limousine (Verkehr) | 11,4 % → 9,8 % | 32 % (Kritik) / 28,2 % (eigene Messung vorher) → 22,3 % |
| Schrägheck | 7,7 % → 6,6 % | 38 % / 34,4 % → 34,4 % (ohne dunklen Heckabschluss: Budget) |
| Kombi | 6,2 % → 8,1 % | 24 % / 29,7 % → 28,7 % |

(Die Kritik maß mit ihrem eigenen Werkzeug; „eigene Messung vorher“ ist mein Werkzeug auf dem Stand vor den
Stufenänderungen, aber schon mit den neuen Felgen und dem neuen Glas.) Bei 160 m ändern sich 10–18 Bildpunkte
(17–32 %): Ein späterer Wechsel macht den Sprung kleiner, nicht seltener.

## 6. Showroom: A/B und Entscheidung

Bild `04_showroom_ab.jpg`: links die Echtzeit-Stufe `show`, rechts das Cycles-Sprite, dieselbe Kamera, derselbe
Boden (`tools/models_contact_sheet.sh <bild> --only="player/*" --showroom`).

Gesehen (Bild 04, beide Autos von schräg vorn): Form, Proportionen, Fugen, Räder, Bremssättel, Spiegel und
Kennzeichen stimmen mit dem Sprite überein. Nicht gleichwertig sind:

1. **Lack** – das Echtzeit-Gelb ist zitronig und flach, das Sprite warm mit Klarlack-Spiegelung und dunkleren
   Flanken; beim Blau dasselbe. Das ist Shader und Licht (R3: Klarlack, Belichtung; UI1: Showroom-Licht), nicht das
   Netz – die Lackwerte sind die des Sprites.
2. **Glas** – in Echtzeit hell und durchsichtig (man sieht den Innenraum), im Sprite dunkel getönt mit Spiegelung.
   Die Kritik hatte das Glas nur bei den Verkehrsautos bemängelt (B4); die Spielerautos haben unverändert das
   Glas aus AS1.
3. **Rückleuchte von schräg vorn** – im Sprite reicht sie sichtbar um die Ecke (rotes Glanzlicht an der hinteren
   Flanke), im Modell nicht (A9, offen).
4. Kleinigkeiten: Chromrahmen des Limousinen-Grills im Sprite heller, Scheinwerferglas in Echtzeit weißer.

`showroom` bleibt deshalb für `showroom/limousine` und `showroom/kompakt` **`false`**. Neu entscheiden, sobald der
Lackshader (R3: Klarlack, Spiegelung, Belichtung) und das Showroom-Licht (UI1) stehen: dasselbe Kommando, bei
Gleichstand in `tools/blender/ce3d/catalog3d.py` `"showroom": True` setzen und `export_models.py --manifest-only`.

## 7. Abweichungen, abgelehnte und offene Befunde

- **A3 (abgelehnt in der Ursache):** Der schwarze Keil war nicht das Ende der Heckblende, sondern die Ecke der
  Hutablage; behoben wurde beides (Blende über der Mulde weggeschnitten, Hutablage folgt der Außenhaut).
- **A4 Limousine (abgelehnt in der Ursache):** Im Reifen steckten nicht Radlaufschale und Schweller, sondern der
  Boden der Innenraumwanne (Farbe `#17181a` = Wanne). Behoben über die Wanne.
- **C1 anders als vorgeschlagen:** Kanal 14 statt Kanal 9 – die Markierung behält bei Tag ihre helle Farbe (Kanal 9
  zeigte sie unbeleuchtet mit halber Leuchtfarbe dunkler) und leuchtet nachts mit `ce_night`. Das Gewicht war 1,0,
  nicht 0,79; dunkel machte sie `plate_energy` 0,45.
- **B1:** Die Hauptursache (`lamp_off` 0,5) liegt im Shader (R3); am Modell nur die dritte Bremsleuchte.
- **B2 nicht umgesetzt:** Die Leuchten der Verkehrsautos bleiben eingeschnittene Felder ohne Streuscheibe und Tiefe.
  Die Konturen sind schon die der Entwurfstabellen; das Bernsteinfeld ist nur im 3D-Entwurf (Regel 9: ≥ 60 cm² je
  Seite). Eine 2-mm-Streuscheibe als zweite Lage widerspräche A-4 (eine Lage) und dunkelte im 8-Bit-Bild Leuchten bei
  Nacht genauso ab wie bei Tag; der Eindruck „eingeschaltet“ verschwindet erst mit dunkleren unbeleuchteten Lampen.
- **B3 bei 120 m nicht erreicht:** 22–34 % statt ≤ 10 %; der Rest ist der grobe Querschnitt und die Kabine von
  `lod2` (Budget 1 200; das Schrägheck hat keinen dunklen Heckabschluss, 20 Dreiecke Luft).
- **Kombi `lod2`, dritte Bremsleuchte** (Kontur ein Drittel, IoU 0,36) und **A8, A9** (Heckblinker als Lichtleiter,
  Rückleuchte von schräg vorn) nicht bearbeitet (niedrig); **C4** (Fahrerhaus) gehört zu AS2b, **C5** zu R3.
- **A7** (Flimmern) behoben nach Vorschlag, aber nicht neu gemessen.
- Verkehrsautos: Reifen mit 9 statt 15 Profilpunkten (`tyre_lite`), um Platz im Budget zu schaffen.

## 8. Bilder in diesem Ordner

| Datei | Inhalt |
|---|---|
| `01_spieler_spielkamera.jpg` | beide Spielerautos aus der Spielkamera in 9 und 30 m: Tag, Nacht mit Rücklicht, Nacht mit Bremse + Blinker |
| `02_kompakt_nah.jpg`, `02_limousine_nah.jpg` | Heck schräg und nah, Rückleuchte nah bei Tag und Nacht, Heck bei Nacht aus Kamerahöhe (Rücklicht / Bremse), Hinterrad, Vorderrad, Radhaus, Innenraum, Scheinwerfer, Front |
| `03_spieler_ton.jpg` | Tonansicht: Schulter über der Rückleuchte (früher das schwarze Blatt), Heck, Radhaus, Rad |
| `04_showroom_ab.jpg` | Showroom-A/B: Echtzeit-Stufe `show` gegen das Cycles-Sprite, dieselbe Kamera |
| `05_verkehr_nah.jpg` | Limousine (rot), Schrägheck (rot), Kombi (silber): Heck schräg, Heck nah, Rad, Rückleuchte nah, Seite, Nacht mit Blinker |
| `06_verkehr_spielkamera.jpg` | Verkehrsautos aus der Spielkamera in 10, 30, 80 m bei Tag und Nacht |
| `07_stufenwechsel.jpg` | Stufenwechsel bei 40 m (`lod0`/`lod1`) und 120 m (`lod1`/`lod2`) mit Differenzbild |
| `08_lkw.jpg` | Sattelzug: Spielkamera 20, 60, 150 m Tag/Nacht (weiße Lackierung) und Nahansichten (rote Lackierung) |
| `09_schattenwerfer.jpg` | alle Fahrzeuge mit dem Schattenwerfer in Rot: zu sehen nur durch das Glas, hinter den Felgen und tief in den Radläufen – nirgends steht er aus der Haut (die rote Kontur und die Leuchten des Lkw haben ihre eigene Farbe) |
| `10_kontaktbogen_tag.jpg`, `11_kontaktbogen_nacht.jpg` | Kontaktbögen: jede Stufe, Farbsets, Schattenwerfer; nachts je Lampenzustand |
| `12_lampenkanaele.jpg` | Prüfstreifen der 15 Lampenkanäle |

## 9. Läufe

| Lauf | Ergebnis |
|---|---|
| `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (10 Modelle, 180 Sets, 25 mit Modell); Netze 4,09 MB von 40 MB, Texturen 4,59 MB von 240 MB, Quellen 1,43 MB von 60 MB; dazu `CHECK models OK` im Testlauf |
| `check_sprite_geometry.py --jobs 2` (alle Sets, nach der letzten Änderung an `cesprites`) | 187 von 187 identisch, davon 1 „REIHENFOLGE“ (UV-Kugel des Fernsehturms, wie in v0.7.0), 0 „ANDERS“, 353 s |
| `export_models.py --check-keys` | `CHECK cache_keys OK` (10 Modelle) |
| erzwungener Neuexport (`--force`) und zweiter Bake aller sechs Fahrzeuge | `git status` danach leer: alle Modelldateien byte-gleich |
| `tools/run_tests.sh` (vollständig, einmal) | `==> Tests bestanden (552 s)`, Exit 0: 228 Skripte geprüft, 0 fehlerhaft; 576 Unit-Tests, 0 fehlgeschlagen; 89 `CHECK … OK` (darunter `CHECK models OK`, `arcade_lean`, `gfx_fallback`, `modern_sight_*`), 0 fehlgeschlagen |
| `tools/golden.sh check` (einmal, am Ende) | `GOLDEN arcade: 20 von 20 identisch (151 s)`, Exit 0 |
| `tools/run_render_checks.sh modern check_models` | `RENDER-CHECKS OK (0 fehlgeschlagen)`: klassen, lampen, lackcodes, blinker (≥ 240 px je Seite in jeder Stufe), bremslicht (Verkehrs-Limousine 2,63 × Rücklicht in `lod0`/`lod1`/`lod2`), multimesh |

Alle Läufe mit eigenem `XDG_DATA_HOME` im Arbeitsordner, schwere Läufe nacheinander mit `nice -n 10` und höchstens
zwei Prozessen.

## 10. Geänderte gemeinsame Dateien (für die Zusammenführung mit AS1b)

Nur additiv und rückwärtsverträglich:
- `tools/blender/ce3d/decalgeo.py`: `Tris.split_z(z, where=None)`; `pocket()` liefert zusätzlich `area`;
  `car_surfaces(..., far_plate=None, glass_look=None, far_sill=False)`.
- `tools/blender/ce3d/lod.py`: nur die Fahrzeugtabellen `PLAYER_DETAIL` (lod0/show: `seam` 1,8, `bumper_clamp`,
  `plate_bold`, `bumper_end_r`) und `TRAFFIC_DETAIL` (lod0: `bumper_clamp`, `bumper_end_r`, `tyre_lite`; lod1:
  `bumper_clamp`; shadow: `arch_n` 6). `lod.py` steht in `COMMON_CODE`: Alle Cache-Schlüssel ändern sich, die
  Requisiten wurden nicht neu exportiert (ihre Dateien sind unverändert).
- `tools/blender/ce3d/catalog3d.py`: im Fahrzeugblock beim Schrägheck `far_sill=False`.
- `tools/blender/validate_models.py`: Lichtanker von Fahrzeugen (`kind` vehicle/heavy) ohne `dir` sind ein Fehler.
- `docs/modelle.md`: Abschnitte 1 (Kontaktbogen-Optionen), 8 (neue Hooks), 11 (Messwerte der sechs Fahrzeuge),
  13 (Fahrzeugmodelle, neuer Unterabschnitt „Nacharbeit nach der Kunstkritik (AS1R)“).
- `assets/models/manifest.json`: neu erzeugt (nur Fahrzeugeinträge geändert) – bei der Zusammenführung neu erzeugen.
- Eigene Dateien: `ce3d/{vehicles3d,traffic3d,truck3d,interior3d,extras3d}.py`, `cesprites/{carbody,cardetail,vehicles}.py`
  (nur Hooks mit Voreinstellung „wie im Sprite“), `tools/models/contact_sheet.gd`, `assets/models/{player,traffic}/**`.
  `vpbr.gdshader`, `glass.gdshader`, `model_factory.gd`, `modern_materials.gd` sind unverändert.
