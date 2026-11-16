# AU-R3 – Damm nach Venedig: kein Altstadtpflaster auf Brücken ohne Steindeck – Bericht

Zweig `worktree-wf_15398915-ab3-1`, gesichert als `origin/wip/v080-au-r3`, Endstand **b6339ad**.
Arbeitsverzeichnis `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-1`,
Basis `3600eb7` (Endstand AU-R2).

Die letzte kleine Korrektur des Modern-Klangs vor den Abnahmeprüfungen. **Keine Klangdatei, kein Pegel, keine Musik
geändert**; geändert sind nur `scripts/audio/modern/audio_feed.gd`, sein Test, `docs/audio-modern.md` und die
Beschreibung von `cobble_share` in `config/game_config.json`. Alle Zahlen sind **gemessen** (Godot 4.7.2, ohne
Bildschirm), sofern nicht „abgeleitet“ dasteht. Gehört hat es hier niemand.

## 1. Was sich geändert hat

| Was | vorher (AU-R2) | jetzt (AU-R3) |
|---|---|---|
| Damm nach Venedig (Ponte della Libertà, Betondeck, 378 m in der Altstadt) | auf 211 von 378 m Kopfsteinpflaster (Triggerlog: 15 von 28 Zeilen), Betonfugen alle 32 m | **Asphalt** auf der ganzen Länge (Triggerlog: 28 von 28 Zeilen), dieselben 13 Fugen |
| übrige Betonbrücken in Altstädten | auf 15 weiteren Brücken in 12 Altstädten (teils) Pflaster | Asphalt; Stahlbrücken bleiben Stahldeck, Steinbrücken Pflaster |
| Pflasteranteil einer Altstadt mit solcher Brücke | über die ganze Altstadt zugeteilt – Blöcke auf der Brücke gingen den Straßen verloren (Bern 0,48, Posen 0,51 …) | über die Straßen zugeteilt: alle im Band 0,6 ± 0,05 außer Lyon (Steinbrücke, Abschnitt 5) |
| Kiel – Hamburg | – | **unverändert** (Hamburgs Brücken liegen vor der Altstadt) – die Hörproben gelten weiter |

**Regel im Code** (`audio_feed.gd`):
- `_paving()`: Altstadtpflaster nur abseits der Brücken (`city and deck == "" and _cobbled(km)`). Ein Betondeck in der
  Stadt hat damit den Belag von vor AU-R (Asphalt), Stahl bleibt `deck`, Stein `cobbles`; die Fugen je Deck sind
  unverändert.
- `cobbled_blocks(…, skip)`: Die Brücken ohne Steindeck (`bridge_stretches`, aus dem Plan, vom Ziel aus gezählt) sind
  keine Straße; ein Block zählt nur mit seinen Straßenmetern, ein Block ganz auf einer solchen Brücke wird nie
  gepflastert. Ohne solche Brücke in der Altstadt ist das Ergebnis bitgleich mit AU-R2.
- `COBBLE_BAND` / `_closer()`: Mit der kürzeren Basis verfehlte die Zuteilung in Hashfolge fünf Altstädte um bis zu
  einen halben Block (Amsterdam, Regensburg, Timişoara 0,65–0,66; Kaunas, Linz schon vorher 0,65). Nur eine von
  solchen Brücken geschnittene Altstadt außerhalb 0,6 ± 0,05 wird mit einzelnen Schritten (Block weg, tauschen,
  dazu; der erste beste in Hashfolge) nachgerückt – alle anderen behalten die Blöcke der Hashfolge.

## 2. Test zuerst

`tests/unit/audio_modern/test_audio_feed.gd`, drei neue Tests mit echtem `StagePlan` (Stadt mit Baustil „italian“
und einer Brücke in der Altstadt) und echter `Track`:
- `test_no_old_town_cobbles_on_a_concrete_deck` – Damm wie nach Venedig (380 m ab Altstadtbeginn, Anteil 1): auf dem
  Deck Asphalt, Straßen gepflastert, 13 Betonfugen; Stahl- und Steinbrücke wie bisher.
- `test_old_town_share_on_its_streets_around_a_bridge` – 300-m-Flussbrücke mitten in einer 800-m-Altstadt, Anteil
  0,6: kein Pflaster auf dem Deck, Straßenanteil 0,6 ± 0,05.
- `test_cobbled_blocks_count_only_the_streets` – 150 Fälle (30 Städte × 5 Brückenlagen): im Band, kein Block ganz auf
  einer Brücke gepflastert, Brücken außerhalb der Altstadt (wie Hamburgs) ändern nichts, überlappende Brücken.

Auf dem Stand **vor** dem Fix sind die beiden Damm-Tests **rot** (`pruefung_test_vor_fix.txt`): „auf dem Betondeck
Asphalt: erwartet { asphalt: 381 }, ist { cobbles: 381 }“, „kein Pflaster auf dem Betondeck: ist 240“,
„Pflasteranteil der Straßen 0,420“. Danach 21 von 21 grün (der dritte Test braucht die neue Signatur und kann auf dem
alten Stand nicht laufen).

## 3. Alle Brücken ohne Steindeck in einer Altstadt – vorher → nachher

Über alle 64 sichtbaren Etappen in **beiden Richtungen** (128 Pläne, das Ziel jeder Richtung): beide Feeds (AU-R2 als
Kopie, AU-R3) fahren in 1-m-Schritten durch jede Altstadt, über die Brücken der echten `Track` (Werkzeug
`enum_bridges.gd`, Abschnitt 8). Meter = Meter der Brücke in der Altstadt (die Lage schwankt je Ankunft um 1–3 m:
die `Track` rundet Brücken auf 3-m-Segmente); „vorher/nachher“ = Belag des Feeds in Metern (erste Ankunft).

| Altstadt | Brücke | Typ, Deck | Meter in der Altstadt | vorher (m) | nachher (m) | Fugen vorher → nachher | Ankünfte |
|---|---|---|---|---|---|---|---|
| Amsterdam | Herengracht | canal, concrete | 45 | Asphalt 45 | Asphalt 45 | 2 → 2 | 2 |
| Amsterdam | Keizersgracht | canal, concrete | 39 | Pflaster 39 | Asphalt 39 | 2 → 2 | 2 |
| Amsterdam | Prinsengracht | canal, concrete | 42 | Pflaster 22, Asphalt 20 | Asphalt 42 | 2 → 2 | 2 |
| Amsterdam | Singel | canal, concrete | 33–36 | Pflaster 24, Asphalt 12 | Asphalt 36 | 2 → 2 | 2 |
| Amsterdam | Singelgracht | canal, concrete | 36 | Pflaster 36 | Asphalt 36 | 2 → 2 | 2 |
| Belgrad | Ada-Brücke | cable_stayed, steel | 168–171 | Stahldeck 171 | Stahldeck 171 | 3 → 3 | 3 |
| Bern | Kirchenfeldbrücke | river, concrete | 108–111 | Pflaster 111 | Asphalt 111 | 4 → 4 | 2 |
| Bremen | Wilhelm-Kaisen-Brücke | river, concrete | 90 | Asphalt 52, Pflaster 38 | Asphalt 90 | 4 → 4 | 4 |
| Brüssel | Pont Van Praet (Kanal) | river, concrete | 60 | Pflaster 60 | Asphalt 60 | 3 → 3 | 2 |
| Budapest | Elisabethbrücke | cable_stayed, steel | 150 | Stahldeck 150 | Stahldeck 150 | 2 → 2 | 3 |
| Bukarest | Dâmbovița (Podul Izvor) | river, concrete | 33 | Pflaster 33 | Asphalt 33 | 2 → 2 | 1 |
| Calais | Pont Mollien | river, concrete | 72 | Asphalt 72 | Asphalt 72 | 3 → 3 | 1 |
| Frankfurt ¹ | Friedensbrücke | river, concrete | 111 | Asphalt 111 | Asphalt 111 | 4 → 4 | 3 |
| Fulda | Fuldabrücke | river, concrete | 45 | Asphalt 45 | Asphalt 45 | 2 → 2 | 2 |
| Hannover ¹ | Leinebrücke | river, concrete | 45 | Asphalt 45 | Asphalt 45 | 2 → 2 | 5 |
| Kassel ¹ | Fuldabrücke | river, concrete | 60 | Asphalt 60 | Asphalt 60 | 3 → 3 | 5 |
| Kaunas | Aleksotas-Brücke | river, concrete | 111 | Asphalt 111 | Asphalt 111 | 4 → 4 | 2 |
| Kiel | Holtenauer Hochbrücke | river, concrete | 50–51 (von 201) | Asphalt 51 | Asphalt 51 | 7 → 7 | 2 |
| Köln ¹ | Severinsbrücke | cable_stayed, steel | 138–141 | Stahldeck 141 | Stahldeck 141 | 2 → 2 | 2 |
| Linz | Nibelungenbrücke | river, concrete | 129–132 | Asphalt 129 | Asphalt 129 | 5 → 5 | 2 |
| Lyon | Pont Lafayette | river, concrete | 108–111 | Pflaster 111 | Asphalt 111 | 4 → 4 | 2 |
| Magdeburg ¹ | Strombrücke | river, concrete | 120 | Asphalt 120 | Asphalt 120 | 5 → 5 | 2 |
| Montpellier | Pont Juvénal | river, concrete | 42 | Pflaster 42 | Asphalt 42 | 2 → 2 | 3 |
| Nürnberg | Pegnitzbrücke | river, concrete | 33–36 | Asphalt 33 | Asphalt 33 | 2 → 2 | 5 |
| Passau | Innbrücke | river, concrete | 90 | Pflaster 50, Asphalt 40 | Asphalt 90 | 4 → 4 | 2 |
| Pau | Pont du XIV-Juillet | river, concrete | 60 | Asphalt 60 | Asphalt 60 | 3 → 3 | 2 |
| Posen | Warthebrücke | river, concrete | 90 | Pflaster 90 | Asphalt 90 | 4 → 4 | 2 |
| Regensburg | Eiserne Brücke (Donau) | river, concrete | 120 | Pflaster 89, Asphalt 31 | Asphalt 120 | 5 → 5 | 2 |
| Riga | Vanšu-Brücke | cable_stayed, steel | 150 | Stahldeck 150 | Stahldeck 150 | 2 → 2 | 1 |
| Sibiu | Cibinbrücke | river, concrete | 33–36 | Asphalt 36 | Asphalt 36 | 2 → 2 | 2 |
| Slavonski Brod | Savebrücke | river, concrete | 90 | Asphalt 90 | Asphalt 90 | 4 → 4 | 2 |
| Timişoara | Begabrücke (Podul Mihai Viteazul) | river, concrete | 51 | Pflaster 51 | Asphalt 51 | 3 → 3 | 2 |
| Venedig | Ponte della Libertà | causeway, concrete | 378 | Pflaster 211, Asphalt 167 | Asphalt 378 | 13 → 13 | 2 |
| Wien | Reichsbrücke | river, concrete | 120 | Asphalt 72, Pflaster 48 | Asphalt 120 | 5 → 5 | 3 |

(34 Brücken; ¹ Baustil ohne Altstadtpflaster – dort war und bleibt alles Asphalt bzw. Stahldeck.)

Dazu je 1 m Pflaster am Brückenende in Linz und Nürnberg bei einer zweiten Ankunft (Rundung) – nachher 0.
Steinbrücken (16 in Altstädten, z. B. Pont Alexandre III, Most Legií, Augustusbrücke): vorher und nachher Pflaster,
keine Fugen.

## 4. Pflasteranteil jeder Altstadt auf ihren Straßen

Straßen = Altstadt ohne alle Brücken und Tunnel (der Feed spielt dort nie Altstadtpflaster). Mehrere Ankünfte einer
Stadt als Spanne; jede Stadt hat **bei jeder Ankunft dieselben Blöcke** (geprüft für alle 55 Ziele, vorher und
nachher). Block 0 liegt am Ziel.

| Altstadt | geändert | Straßen (m) von Altstadt (m) | Brücken o. Steindeck / Stein / Tunnel (m) | Straßenanteil vorher → nachher | Pflaster auf Brücken o. Steindeck vorher → nachher (m) | Blöcke vorher → nachher (Block 0 am Ziel) | Ankünfte |
|---|---|---|---|---|---|---|---|
| Amsterdam | ja | 602–605 von 800 | 195–198 / 0 / 0 | 0,531–0,532 → 0,603–0,605 | 119–121 → 0 | `-P--PP-PP` → `-PPPPP-P-` | 2 |
| Barcelona | – | 800 von 800 | 0 / 0 / 0 | 0,549 → 0,549 **außerhalb** | 0 → 0 | `-PP-P-P-P` → `-PP-P-P-P` | 2 |
| Belgrad | – | 629–632 von 800 | 168–171 / 0 / 0 | 0,603–0,604 → 0,603–0,604 | 0 → 0 | `-PP---PPP` → `-PP---PPP` | 3 |
| Bern | ja | 689–692 von 800 | 108–111 / 0 / 0 | 0,479–0,481 → 0,608–0,610 | 108–111 → 0 | `P-PP---PP` → `P-PP--PPP` | 2 |
| Białystok | – | 800 von 800 | 0 / 0 / 0 | 0,561 → 0,561 | 0 → 0 | `PP--PP-P-` → `PP--PP-P-` | 2 |
| Bordeaux | – | 650 von 800 | 0 / 150 / 0 | 0,629–0,632 → 0,629–0,632 | 0 → 0 | `PP--PP--P` → `PP--PP--P` | 2 |
| Bremen | ja | 710 von 800 | 90 / 0 / 0 | 0,573–0,582 → 0,573–0,582 | 38–41 → 0 | `P-P-PP-P-` → `P-P-PP-P-` | 4 |
| Brüssel | ja | 840 von 900 | 60 / 0 / 0 | 0,569 → 0,569 | 60 → 0 | `PP-PP-P-P--` → `PP-PP-P-P--` | 2 |
| Budapest | ja | 650 von 800 | 150 / 0 / 0 | 0,572–0,574 → 0,602 | 0 → 0 | `PPP--P-P-` → `PPPP-P-P-` | 3 |
| Bukarest | ja | 967 von 1000 | 33 / 0 / 0 | 0,627 → 0,627 | 33 → 0 | `--PPPPP-PP-P` → `--PPPPP-PP-P` | 1 |
| Burgos | – | 749 von 800 | 0 / 51 / 0 | 0,521 → 0,521 **außerhalb** | 0 → 0 | `-PPP-P--P` → `-PPP-P--P` | 2 |
| Calais | – | 728 von 800 | 72 / 0 / 0 | 0,606 → 0,606 | 0 → 0 | `-P-P--PPP` → `-P-P--PPP` | 1 |
| Dresden | – | 680 von 800 | 0 / 120 / 0 | 0,646 → 0,646 | 0 → 0 | `-P--PP-PP` → `-P--PP-PP` | 1 |
| Erfurt | – | 800 von 800 | 0 / 0 / 0 | 0,551 → 0,551 | 0 → 0 | `-PP-P--PP` → `-PP-P--PP` | 2 |
| Fulda | – | 755 von 800 | 45 / 0 / 0 | 0,581 → 0,581 | 0 → 0 | `PP--P--PP` → `PP--P--PP` | 2 |
| Hamburg | – | 800 von 800 | 0 / 0 / 0 | 0,551 → 0,551 | 0 → 0 | `P--PP-P-P` → `P--PP-P-P` | 3 |
| Hamburg (Ankunft mit Tunnel) | – | 470 von 800 | 0 / 0 / 330 | 0,615 → 0,615 | 0 → 0 | `P--PP-P-P` → `P--PP-P-P` | 3 |
| Kaunas | ja | 689 von 800 | 111 / 0 / 0 | 0,653 → 0,581–0,582 | 0 → 0 | `-P--PPPP-` → `-P-P-PPP-` | 2 |
| Kiel | – | 749–750 von 800 | 50–51 / 0 / 0 | 0,600–0,601 → 0,600–0,601 | 0 → 0 | `-PPPPP---` → `-PPPPP---` | 2 |
| Linz | ja | 668–671 von 800 | 129–132 / 0 / 0 | 0,654 → 0,596–0,598 | 0–1 → 0 | `P---PP-PP` → `P-P--P-PP` | 2 |
| Ljubljana | – | 761 von 800 | 0 / 39 / 0 | 0,526–0,527 → 0,526–0,527 **außerhalb** | 0 → 0 | `P-PPP---P` → `P-PPP---P` | 2 |
| Lyon | ja | 620–623 von 800 | 108–111 / 69 / 0 | 0,532–0,535 → 0,677–0,679 **außerhalb** | 108–111 → 0 | `---PPP-PP` → `P--PPP-PP` | 2 |
| Lüttich | – | 689–692 von 800 | 0 / 108–111 / 0 | 0,491–0,492 → 0,491–0,492 **außerhalb** | 0 → 0 | `-PPPP-P--` → `-PPPP-P--` | 2 |
| Madrid | – | 949 von 1000 | 0 / 51 / 0 | 0,620–0,621 → 0,620–0,621 | 0 → 0 | `PPP-PP--PP-P` → `PPP-PP--PP-P` | 2 |
| Mailand | – | 800 von 800 | 0 / 0 / 0 | 0,551 → 0,551 | 0 → 0 | `--P-PPP-P` → `--P-PPP-P` | 2 |
| Montpellier | ja | 758 von 800 | 42 / 0 / 0 | 0,525–0,526 → 0,645–0,646 | 42 → 0 | `P-PP-P--P` → `P-PP-P-PP` | 3 |
| München | – | 840 von 900 | 0 / 60 / 0 | 0,570 → 0,570 | 0 → 0 | `PP-PP-P-P-P` → `PP-PP-P-P-P` | 1 |
| Nürnberg | ja | 764–767 von 800 | 33–36 / 0 / 0 | 0,584–0,589 → 0,584–0,589 | 0–1 → 0 | `--P-PPPP-` → `--P-PPPP-` | 5 |
| Paris | – | 868 von 1000 | 0 / 132 / 0 | 0,677 → 0,677 **außerhalb** | 0 → 0 | `P--PPPPP-P-P` → `P--PPPPP-P-P` | 2 |
| Paris (Ankunft mit Tunnel) | – | 741 von 1000 | 0 / 129 / 130 | 0,745 → 0,745 **außerhalb** | 0 → 0 | `P--PPPPP-P-P` → `P--PPPPP-P-P` | 2 |
| Passau | ja | 710 von 800 | 90 / 0 / 0 | 0,561–0,563 → 0,632 | 50–52 → 0 | `P--P-PPP-` → `P--PPPPP-` | 2 |
| Pau | – | 740 von 800 | 60 / 0 / 0 | 0,607–0,608 → 0,607–0,608 | 0 → 0 | `PP--P-PP-` → `PP--P-PP-` | 2 |
| Posen | ja | 710 von 800 | 90 / 0 / 0 | 0,510 → 0,623 | 90 → 0 | `P-PP-P-P-` → `P-PP-P-PP` | 2 |
| Prag | – | 689–692 von 800 | 0 / 108–111 / 0 | 0,492–0,494 → 0,492–0,494 **außerhalb** | 0 → 0 | `PPPP-P---` → `PPPP-P---` | 3 |
| Regensburg | ja | 680 von 800 | 120 / 0 / 0 | 0,526 → 0,618 | 89 → 0 | `P-P-P-PP-` → `PP-P--PP-` | 2 |
| Riga | ja | 650 von 800 | 150 / 0 / 0 | 0,554 → 0,602 | 0 → 0 | `-P-PPP-P-` → `-PP-PP-P-` | 1 |
| Rostock | – | 800 von 800 | 0 / 0 / 0 | 0,550 → 0,550 | 0 → 0 | `P----PPPP` → `P----PPPP` | 1 |
| San Sebastián | – | 740 von 800 | 0 / 60 / 0 | 0,530 → 0,530 **außerhalb** | 0 → 0 | `-PP--PPP-` → `-PP--PPP-` | 2 |
| Saragossa | – | 698–701 von 800 | 0 / 99–102 / 0 | 0,501 → 0,501 **außerhalb** | 0 → 0 | `PPP----PP` → `PPP----PP` | 3 |
| Sibiu | – | 764–767 von 800 | 33–36 / 0 / 0 | 0,574–0,576 → 0,574–0,576 | 0 → 0 | `-P---PPPP` → `-P---PPPP` | 2 |
| Slavonski Brod | – | 710 von 800 | 90 / 0 / 0 | 0,632–0,635 → 0,632–0,635 | 0 → 0 | `PP--PP-P-` → `PP--PP-P-` | 2 |
| Sofia | – | 800 von 800 | 0 / 0 / 0 | 0,551 → 0,551 | 0 → 0 | `P----PPPP` → `P----PPPP` | 1 |
| Timişoara | ja | 749 von 800 | 51 / 0 / 0 | 0,535 → 0,601 | 51 → 0 | `P-PP-P-P-` → `P--P-PPP-` | 2 |
| Toulouse | – | 671 von 800 | 0 / 129 / 0 | 0,641 → 0,641 | 0 → 0 | `-P--PPP-P` → `-P--PPP-P` | 2 |
| Tours | – | 680 von 800 | 0 / 120 / 0 | 0,646–0,647 → 0,646–0,647 | 0 → 0 | `P---P-PPP` → `P---P-PPP` | 2 |
| Venedig | ja | 282 von 660 | 378 / 0 / 0 | 0,642–0,645 → 0,638–0,642 | 209–211 → 0 | `P-P-PP-P` → `P-P-----` | 2 |
| Warschau | – | 662 von 800 | 0 / 138 / 0 | 0,456–0,458 → 0,456–0,458 **außerhalb** | 0 → 0 | `--PPPP--P` → `--PPPP--P` | 2 |
| Wien | ja | 780 von 900 | 120 / 0 / 0 | 0,631–0,632 → 0,631–0,632 | 48 → 0 | `--PPPPP-P-P` → `--PPPPP-P-P` | 3 |
| Würzburg | – | 719–722 von 800 | 0 / 78–81 / 0 | 0,569–0,570 → 0,569–0,570 | 0 → 0 | `P--P-PPP-` → `P--P-PPP-` | 3 |

Zusammengefasst: 18 Altstädte klingen anders, **alle mit einer Brücke ohne Steindeck** (13 mit anderen Blöcken, 5
nur auf der Brücke); keine andere Altstadt ändert sich (bitgleich). Außerhalb 0,6 ± 0,05 liegen vorher 30, nachher 17
der 81 Ankunfts-Varianten – nachher **nur noch Altstädte mit Steinbrücke** (und Barcelona 0,549 im 1-m-Raster,
zugeteilt genau 0,550). **Unter 0,55 fällt keine Altstadt durch eine Brücke ohne Steindeck.** Venedig: Die Straße endet
hinter dem Damm am Piazzale Roma – 282 m Straße, davon dieselben 180 m gepflastert wie vorher (0,64).

## 5. Was offen bleibt (gemessen, nicht geändert – Vorschläge)

- **Steinbrücken in Altstädten** (16 Städte): Die Zuteilung von AU-R zählt eine Steinbrücke als Straße, die
  gepflastert sein kann oder nicht – sie klingt aber immer nach Pflaster. Auf den Straßen ohne Steinbrücke liegen 9
  daneben (Warschau 0,46, Lüttich und Prag 0,49, Saragossa 0,50, Burgos 0,52, Ljubljana und San Sebastián 0,53; Lyon
  0,68, Paris 0,68 / 0,75); zählt man sie als gepflasterte Straße mit, liegen Bordeaux, Dresden, Toulouse, Tours bei
  0,70, Lyon 0,71, Paris 0,72 / 0,78. Lyon hat beide Arten: Seine Betonbrücke verlor vorher Pflaster (0,53), nachher
  liegt es wegen der Steinbrücke darüber (0,68; als Straße gezählt 0,61). Vorschlag für eine eigene Runde: die Meter
  einer Steinbrücke in `cobbled_blocks` als schon gepflastert zählen (ändert die Muster dieser 16 Städte; Hamburg
  nicht betroffen). Nicht in dieser Runde: „keine andere Klangänderung“.
- **Tunnel in Altstädten**: Hannover – Hamburg 330 m, Lüttich – Paris 130 m; der Feed spielt dort Asphalt, die
  Zuteilung zählt sie als Straße (Hamburg so 0,615, Paris 0,75).
- **Messwerkzeuge der Nachmessung**: `kr_shares.gd` von KRITIK-R fragt `_cobbled()` direkt über die ganze Altstadt
  (Brücken inklusive). Mit AU-R3 misst es für Städte mit Brücke zu wenig (Venedig etwa 180 von 660 m = 0,27), weil
  die Brückenblöcke jetzt nicht gepflastert sind. Richtig gemessen wird über `_paving()` abseits der Brücken
  (`enum_bridges.gd`).

## 6. Kiel – Hamburg und Mailand – Venedig

| Prüfung | Kiel – Hamburg | Mailand – Venedig |
|---|---|---|
| Feed AU-R2 gegen AU-R3, ganze Etappe auf der echten `Track`, 1-m-Schritte (`stage_compare.gd`) | **0** von 9 500 Zuständen verschieden, **0** Schritte mit anderen Ereignissen | 212 von 27 500 Schritten verschieden: Pflaster → Asphalt, alle auf dem Damm (1 m am Planbeginn, den die `Track` auf das nächste Segment rundet); Ereignisse 0 verschieden |
| Gegenrichtung (Hamburg – Kiel; Venedig – Mailand) | 0 verschieden (Kiels Hochbrücke war schon Asphalt) | 0 verschieden |
| Triggerlog mit Autopilot vorher/nachher (`trigger_log2.gd` von AU-R) | **gleich**: 329 Ereignisse an denselben Orten, 316 Zeilen in denselben Belägen, dasselbe `ERGEBNIS` | Damm: 15 Zeilen Pflaster + 13 Asphalt → 28 Asphalt; Fugen (13), Ereignisse, `ERGEBNIS` gleich; Straßen dahinter 12 von 20 Zeilen Pflaster wie vorher |

Die Triggerlog-Zeilen werden einmal je Sekunde Etappenzeit im Bildtakt genommen; ihre Orte schwanken darum von Lauf zu
Lauf um ein Bild – verglichen werden Ereignisse nach Ort und Art und die Zeilen je Belag (`diff_trig.py`).
**Die Hörproben in `<scratch>/v080/deliver/AU-R/` bleiben unverändert** (Auftrag: neu nur, wenn sich der Kiel –
Hamburg-Triggerlog ändert).

## 7. Gates

| Gate | Ergebnis | Beleg |
|---|---|---|
| neue Tests auf dem Stand vor dem Fix | **rot** wie verlangt (2 Damm-Tests) | `pruefung_test_vor_fix.txt` |
| Feed-Tests beim Arbeiten (`tools/run_tests.sh test_audio_feed`) | grün, 21 von 21 | – |
| `tools/run_tests.sh` (einmal, am Ende) | **grün**: „656 Tests, 0 fehlgeschlagen“, 83 CHECK-Zeilen OK, 0 FEHLER, „Tests bestanden (602 s)“ – darin `test_arcade_identity` (eingefrorene Klänge, Motor-Mischer byte-gleich zu v0.7.0) | `pruefung_run_tests.txt` |
| `check_arcade_lean` | **OK**: „0 von 35 Skripten des Modern-Klangs, des Modern-Renderers und der Modell-Datenbank geladen“ | `pruefung_run_tests.txt` |
| `tools/golden.sh check` (einmal) | **grün**: „GOLDEN arcade: 20 von 20 identisch (177 s)“ | `pruefung_golden.txt` |
| eingefrorene Arcade-Dateien = v0.7.0 | **0 geänderte Zeilen** (`git diff v0.7.0..HEAD` über alle Pfade von Regel 1) | – |
| keine Klangdatei geändert | `git diff --stat 3600eb7..HEAD`: 4 Dateien – `audio_feed.gd` (+116/−9), `test_audio_feed.gd` (+148), `docs/audio-modern.md` (+92/−17), `config/game_config.json` (1 Zeile: Beschreibung von `cobble_share`); **0 Dateien unter `assets/` und `tools/audio/`** – darum kein `audio_qc` | – |
| Kiel – Hamburg unverändert | deterministisch 0 von 9 500 Schritten verschieden; Triggerlog gleich | `pruefung_kiel_hamburg_venedig.txt` |

Die volle Testreihe lief auf `85e138a` mit der Wortkorrektur der Doku von `b6339ad` (nur `docs/`); der Golden-Lauf auf
`b6339ad`. Die Maschine war von anderen Paketen belastet (A/B-Clip des Renderers, Bilder von AS4R); alle eigenen
schweren Läufe einzeln mit `nice -n 19`.

## 8. Abweichungen, Vertragsfragen

- **Abweichung:** Über „Brückenblöcke aus der Zuteilung nehmen“ hinaus der Nachrück-Schritt `COBBLE_BAND` – ohne ihn
  lägen Amsterdam, Regensburg, Timişoara (neu) sowie Kaunas und Linz (schon vorher) bei 0,65–0,66. Er greift nur in
  Altstädten mit einer Brücke ohne Steindeck und nur außerhalb des Bands.
- **Auslegung (keine Abweichung):** „Brücken ohne Steindeck“ heißt Beton **und Stahl**. Auch Stahlbrücken zählen darum
  nicht als Straße: Budapest und Riga hatten ihre Stahlbrücke in der Zuteilung mitgezählt, obwohl dort nie Pflaster
  klingt (0,57 / 0,55 → 0,60 / 0,60). Belgrad (Stahl) lag schon im Band und behält seine Blöcke.
- **Abweichung:** Die Beschreibung von `cobble_share` in `config/game_config.json` sagt jetzt „Anteil der Straßen
  jeder Altstadt“ (die Bedeutung hat sich so geändert; kein Wert geändert).
- **Vertragsfrage:** „jede Altstadt 0,6 ± 0,05 ihrer Straßen“ hängt an der Definition „Straße“ für Steinbrücken und
  Tunnel (Abschnitt 5). Vorschlag für §11.2: Straßen = Altstadt ohne Brücken und Tunnel; Steinbrücken werden als schon
  gepflastert in die Zuteilung eingerechnet (eigene Runde).

## 9. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3/`:
`tools/enum_bridges.gd` (+ `run_enum.sh`, `ana_enum.py`, `mk_tables.py`) – alle Brücken und Altstädte, alter Feed als
Kopie `tools/audio_feed_3600eb7.gd`; `tools/stage_compare.gd` (+ `run_compare.sh`) – zwei Feeds über eine ganze
Etappe; `tools/trigger_log2.gd` (Kopie von AU-R) mit `run_trig.sh`, `diff_trig.py`, `ana_rows.py`;
`tools/alloc_model.py`, `tools/eval_swap.py` – Python-Modell von `unit_hash` und der Zuteilung (gegen die
Bezugswerte des Tests geprüft). Ergebnisse `res/enum.log`, `res/enum.json`, `res/tables.md`, `res/cmp_*.log`,
Triggerlogs `trig/{kh,mv}_{before,after}.log`, Protokolle `logs/`.
