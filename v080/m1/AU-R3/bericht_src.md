# AU-R3 – Damm nach Venedig: kein Altstadtpflaster auf Brücken ohne Steindeck – Bericht

Zweig `worktree-wf_15398915-ab3-1`, gesichert als `origin/wip/v080-au-r3`, Endstand **{{HEAD}}**.
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

{{BRIDGES}}

Dazu je 1 m Pflaster am Brückenende in Linz und Nürnberg bei einer zweiten Ankunft (Rundung) – nachher 0.
Steinbrücken (16 in Altstädten, z. B. Pont Alexandre III, Most Legií, Augustusbrücke): vorher und nachher Pflaster,
keine Fugen.

## 4. Pflasteranteil jeder Altstadt auf ihren Straßen

Straßen = Altstadt ohne alle Brücken und Tunnel (der Feed spielt dort nie Altstadtpflaster). Mehrere Ankünfte einer
Stadt als Spanne; jede Stadt hat **bei jeder Ankunft dieselben Blöcke** (geprüft für alle 55 Ziele, vorher und
nachher). Block 0 liegt am Ziel.

{{TOWNS}}

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

{{GATES}}

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
