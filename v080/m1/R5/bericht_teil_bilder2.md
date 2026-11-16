## 3. Bilder – angesehen, ehrlich gegen Arcade (und gegen die Basis)

Ordner `bilder/`. Dreier **Arcade | Modern Basis (6e48405) | Modern R5** desselben Simulationszustands, wo die Basis
gerendert wurde, sonst Paare **Arcade | Modern R5** aus demselben `tools/ab_shot.sh`-Lauf. 1280 × 720, Stufe „Hoch“
(Steam Deck: 1280 × 800, Stufe „deck“; Arcade dort mit Balken). Arcade ist eingefroren und bitgleich, darum stammen die
Arcade-Bilder der Dreier aus dem Lauf der Basis. Alle R5-Bilder zeigen den Code-Endstand (Bilder vor einem späteren
Commit, der sie ändert, wurden neu gerendert: B1, Somport, U1-Ausfahrt, Köhlbrand nachts – Ordner `shots/new4`).
`pruefung_*.jpg` sind Bilder der Render-Prüfung (HUD aus).

| Ort | Bild | Urteil R5 gegen Arcade | gegen die Basis |
|---|---|---|---|
| U1 Gotthard Anfahrt, 12 Uhr | `u1_anfahrt_00/01` | Hügel wie Arcade (dieselbe gesäte Folge, Verlauf, Nadelbäume an denselben Stellen), Portal mit Rahmen und Fasen, Leuchten mit Arcades Lichthof von außen, Fliesenpaneele schon am Eingang – **besser** | besser (Basis: kein Lichthof, glatter Hügel ohne Bäume) |
| U1 innen | `u1_innen_01` | Fliesenpaneele mit Fugen, Gehwege, Kabeltrassen, Leuchtengehäuse, Nischen/Türen; Licht und Nebel wie Arcade, kein Himmel – **deutlich besser** | deutlich besser (Basis: glatte Wände) |
| U1 Ausfahrt | `u1_ausfahrt_01/02` | Rahmen der Ausfahrt, Notausgang; draußen **nicht überbelichtet** wie in Arcade – die Öffnung ist sogar dunkler als die beleuchtete Röhre (Umgebung, R4: Belichtungsrampe) – **gleich**, nicht besser | gleich bis besser |
| U1 22 Uhr | `u1_nacht_00/01` | nah am Portal stimmig (Röhre, Leuchten, Stirnwand dunkel wie Arcade); 60–70 m davor ist die Stirnwand vom Abblendlicht bis oben angestrahlt und liest sich wie bei Tag (R4: keine Abblendkante, gemessen Abschnitt 8); die Fahrbahn in der Röhre ist von außen kalt grau statt Arcades warmem Tunnellicht (R4) – **schlechter** als Arcade auf Bild 00, gleich auf Bild 01 | – |
| Somport | `somport_00–02` | Leuchten mit Lichthof, SOS-Nische, Notausgang mit grünem Schild, Fliesen – **besser** | besser |
| Köhlbrandbrücke Rampe/Deck | `kb_rampe_00/01` | Wasser in Arcades Farbe mit Wellen, Seile dünn wie Arcades Linien, graue Pylone (Sonnenseite etwas heller), fernes Kaiufer aus Naturstein – **besser** | deutlich besser (Basis: weiß-graues Wasser, dicke weiße Seile) |
| Köhlbrandbrücke Ende | `kb_ende_00/01` | graue Natursteinböschung in Arcades Kaifarbe statt „Wasser ins Grün“ – **gleich bis besser** | deutlich besser |
| Köhlbrandbrücke 22 Uhr | `kb_nacht_00–02`, `pruefung_beacon` | Pylone dunkel (Messreihe unter Arcade), Seile, Feuer rot und blinkend, Wasser ruhig – **gleich bis besser** | gleich bis besser |
| Holtenauer Hochbrücke | `holtenau_00/01` | Kanal zwischen grünen Böschungen mit Steinschüttung, Land dahinter, vor der Brücke kein Wasserband am Horizont – wie Arcade, mit Ufertextur – **gleich bis besser** | deutlich besser (Basis: See bis zum Horizont) |
| B1 Severinsbrücke Köln | `b1_koeln_00/01` | Rhein mit Kaimauern, fernes Ufer, Pylon grau, Seile dünn – **gleich bis besser** | besser |
| Elbbrücken (Fachwerk) | `elbbruecken_00/01` | Fachwerkträger an beiden Seiten wie Arcade (Gurte, Pfosten, Diagonalen) zu den Bogenportalen, im Licht schattiert – **besser** | deutlich besser (Basis: nur Portale) |
| Ludwigsbrücke Würzburg (Stein) | `stein_00/01` | Lampen, Wasser, aber geschlossene Brüstung statt Arcades heller Docken (roadside.gd, R4) – **gleich**, an der Brüstung schlechter | gleich |
| Ponte della Libertà (Damm) | `damm_00/01` | Wasser in Arcades Türkis mit Wellen, Brückenlampen als Modelle wie Arcades, Gehweg gepflastert – **gleich bis besser** | – |
| Herengracht Amsterdam (Kanal) | `gracht_00/01` | Gracht mit Hausbooten, Eisengeländer, Wasser etwas blauer als Arcade – **gleich** | – |
| DEV km 48, 21 Uhr | `dev_00–02` | Hügel, Portal, Röhre wie Arcade; Stirnwand nah vom Abblendlicht hell (R4) – **gleich** | gleich |
| Steam Deck (1280 × 800, „deck“) | `kb_nacht_deck_*`, `u1_innen_deck_01`, `kb_rampe_deck_01` | dieselben Bauten, Seile und Fliesen auch in „deck“ sichtbar – **gleich bis besser** | – |

**Clips** (`tools/ab_clip.sh`, 60 fps fest, 30 s, Arcade links, Modern rechts, Stufe „Hoch“): `clips/u1_gotthard.mp4`
(Bern – Mailand ab km 184,4: Portal, Röhre bis km 198 – Gehwege, Paneele, Leuchtenreihen, Lüfter, Gegenverkehr)
und `clips/koehlbrand.mp4` (Kiel – Hamburg ab km 77,2: Rampe, Deck mit Pylonen, Seilen und Wasser über Steinböschung
– die Brücke ist bei 150 km/h nach 10 s überquert –, Ende mit Kaiböschung, Anfahrt der Elbbrücken; der Modern-Lauf
brauchte 2923 s und lief beim ersten Versuch ins Zeitlimit von 3600 s, zweiter Versuch mit `CLIP_TIMEOUT=6000`).
Angesehen: Bilder aus beiden Clips (2 s, 5 s, 7 s, 10 s, 20 s, 28 s) – keine Sprünge, kein Flackern der Wände, das
Portal und die Brücke kommen an derselben Stelle wie in Arcade.

**Gesamturteil:** Wo R5 selbst baut, ist Modern **deutlich besser als die Basis und besser als Arcade**: Tunnelröhren
(Paneele, Gehwege, Nischen, Türen, Lüfter, Leuchten mit Lichthof), Portale mit Hügel, Wasser mit Wellen und Spiegel in
Arcades Farbe, Ufer und Kaimauern nach Arcades Regel, Fachwerkträger, dünne Seile, blinkende Flugbefeuerung, Fernwasser
mit Ufer statt Wasserband bis zum Horizont. **Nicht besser** ist es dort, wo das Bild von fremden Teilen abhängt:
Abblendlicht ohne Hell-Dunkel-Grenze (Gotthard-Stirnwand 22 Uhr aus 60–70 m wie bei Tag – schlechter als Arcade),
Fahrbahn in der Röhre von außen kalt grau statt Arcades warmem Tunnellicht, keine Überbelichtung an der Ausfahrt (die
Öffnung ist dunkler als die Röhre), geschlossene Brüstung statt Arcades Docken an Steinbrücken (alle R4, Abschnitt 8).
