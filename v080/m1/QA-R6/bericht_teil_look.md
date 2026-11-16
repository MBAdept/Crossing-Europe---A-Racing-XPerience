## 5. Bilder und Urteil gegen Arcade (eigene Bilder, gerendert und angesehen)

Alle Bilder mit `tools/ab_shot.sh` (gleicher Simulationszustand, links Arcade, rechts Modern), Modern „Hoch“ bei 1280 × 720,
die Deck-Bilder `--gfx-preset=deck` bei 1280 × 800; die Argumente stehen unter jedem Bildpaar. Basis-Vergleiche: dieselben
Argumente mit der Basis-Kopie `6e48405` (Dreierbilder Arcade | Modern Basis | Modern R6). Dateien in
`…/scratchpad/v080/deliver/QA-R6/` (Nummern unten).

| Ort | Tag | Nacht | Basis → R6 |
|---|---|---|---|
| Tankstelle DEV km 18,5–19,6 (01, 02) | **besser, nicht überragend**: Preissäule mit Mast und Fundament, Dächer mit Blendenbändern, Stützen mit Sockel, Leuchtkästen, Insel mit gelbem Bordstein, AS1b-Zapfsäulen und -Shop. Farben und Formen sind Arcades – der Gewinn ist Körper und Tiefe, nicht Detail | **gleichwertig, anders**: Dächer, Leuchtkästen, „TANKSTELLE“ hinterleuchtet und lesbar, Zapfsäulen hell; Arcades großer warmer Schein des Shop-Sprites fehlt, das Gelände wirkt dunkler | Tag kaum Unterschied (FIX1 hatte schon Insel, Dach, Stützen); Nacht weiße Leuchtkästen mit Arcades weißem Schein statt der orangen Punktlampen der Basis – näher an Arcade, **nicht schlechter** (03, 03b) |
| Tankstelle Kiel – Hamburg km 13,4–14,2, Tutorial-Stopp (04, 05) | gleich bis besser (wie DEV) | gleichwertig | wie DEV (25) |
| Grenze DEV km 64,5–64,9 (06, 07, 30) | **besser in Tiefe und Detail** (Dachunterseite, Häuschen als Modelle) – **aber rechts schwebt das Dach ohne Pfeiler** (B-01), im Nahbild deutlich | **gleich bis besser**: Lichtbänder, Häuschen mit warmen Fenstern, Blende hinterleuchtet; rechts weiter kein Pfeiler | Basis: keine Grenze |
| Grenze Nürnberg → Prag km 129,3, „ČESKO“ (08) | **besser**: beidseitig getragen (rechts nach außen hinter das Warnschild gerückt), Unterseite, Häuschen; „Č“ richtig | – | Basis: keine Grenze |
| Blitzer DEV km 11,8, Blitz bei 0,53 s (09) und km 10,9, Blitz bei 2,50 s ohne HUD-Überdeckung (09b) | **leicht besser**: mit Start km 11,8 liegt der Kamerakopf hinter HUD-Ampel und „LOS!“ (beide Modi nur HUD-Weiß); ohne Überdeckung (09b) ist in Modern ein klarer weißer Schein am Kamerakopf zu sehen, in Arcade praktisch keiner. Pfosten = AS1b-Modell, wirkt wie Arcades Sprite | gleich (in Modern ein kleiner weißer Schein am Kopf) | Basis ohne Schein am Kopf, R6 mit – besser (26) |
| Stadt DEV km 111 (10, 11) | **besser**: Laternen mit Mast und Ausleger, Hecken als Körper, Gehwegpflaster | **gleich bis leicht besser**: Kegel auf Straße und Gehweg, echte Lampenköpfe; Arcades große warme Höfe um jede Laterne wirken stärker als Moderns kleine Scheine | praktisch gleich (die Basis zeichnete die Laternen über `props.gd`) (26) |
| Ankunft Hamburg km 76 (12) | – | gleich bis besser (Laternenreihe mit Scheinen, Hecken) | – |
| Start DEV und Kiel – Hamburg (13, 15) | **gleich**: Arcades Banner-Tafel, graue Stahlstützen statt weißer Balken, Lampen an Arcades Stellen, rot → grün wie Arcade, Auto wie Arcade | **gleich** („START“ hellgrau wie Arcade, roter Schein um die Lampe wie Arcade) | Basis: „START“ nachts reinweiß (heller als Arcade), R6 wie Arcade – gleichwertig (26, 27) |
| Ziel DEV und Kiel – Hamburg (14, 15) | **gleich** | **leicht schlechter**: Banner dunkleres Rot, die dunklen Stahlstützen verschwinden vor dem Nachthimmel, Arcades weiße Stützen stehen klar da | Basis: Banner nachts fast schwarzrot; R6 rot mit Schachbrett – besser als die Basis, dunkler als Arcade (26) |
| Deck 1280 × 800 (16) | Grenze wie „Hoch“ | Tankstelle und Stadt wie „Hoch“; Modern füllt 16:10 | – |

**Gesamturteil Look:** Bei Tag sind Tankstelle, Grenze (außer der schwebenden Rechtsseite) und Stadt besser als Arcade – durch
Körper, Schatten und Tiefe; Farben, Formen und Schrift sind bewusst Arcades. Deutlich besser ist es an der Grenze (Prag) und in
der Stadt, an der Tankstelle nur mäßig. Bei Nacht ist nichts deutlich besser: Tankstelle und Stadt verlieren Arcades große
warme Scheine, das Zieltor ist leicht schlechter. Start, Ziel und Blitzer bringen keinen sichtbaren Gewinn. „Modern sieht klar
besser aus“ gilt damit nur bei Tag und für drei der fünf Elemente (Befund B-03).

### 5.1 Clips von R6 (angesehen; Bildauszüge 20–24)

Die vier Clips (60 fps, Arcade | Modern) zeigen die verlangten Abläufe in beiden Modi im selben Takt: Countdown 3-2-1 mit
roten Lampen, alle grün bei „LOS!“ (20); Tanken bis „Vollgetankt – 18 L“ (21); Blitz bei 0:00,37 (22) und Polizeistopp
„Führerschein, bitte!“ ab 0:25 (23); Ziel mit „ZIEL“-Banner (24). Schwächen (in beiden Modi, nicht vom Renderer): im
Blitz-Clip liegen „LOS!“ und die HUD-Ampel genau über dem Kamerakopf, der Blitz am Pfosten ist kaum zu erkennen; im Ziel-Clip
verdecken die Tutorial-Tipps das Banner beim Durchfahren. Ein eigener Clip habe ich nicht aufgenommen (Movie Maker auf „Hoch“
≈ 140 s je Clip-Sekunde hier); ein Blitz-Clip ohne HUD-Überdeckung (Start km 11,2, Blitz nach ~2 s) wäre aussagekräftiger.
