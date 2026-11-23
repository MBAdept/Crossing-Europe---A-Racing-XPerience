# QA-R7a – unabhängige Prüfung von R7a (Sichtkorridor aus der wirklichen Geometrie, A-17/A-18)

- Geprüfter Stand: `509bb168` (origin/wip/v080-r7a), Basis `9b02f050` (RINT-M2). Arbeitsbaum
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5` (Fast-Forward auf `509bb16`, nichts
  geändert, nichts committet). Basis-Kopie `m1/QA-R7a/base` (`git archive 9b02f05` + Import), Kopie für die Mutationen und
  den Gegenlauf „mit Reichweite“ `m1/QA-R7a/mut` (`git archive 509bb16`; nach den Mutationen nur `props.gd` um R7a's
  vorgeschlagene Zeile ergänzt, `sh/patch_reach.py`).
- „gemessen“ = hier an Zahl/Bild/Log festgestellt; „abgeleitet“ = gerechnet oder aus dem Code geschlossen. Steam Deck,
  echte GPU und Wirkung auf Menschen sind immer abgeleitet. Maschine: 4 Kerne, llvmpipe, Last 5–8 durch andere Pakete.
- Alle Werkzeuge in `m1/QA-R7a/` (`probe/*.gd`, `sh/*`), Protokolle in `m1/QA-R7a/logs/`, Bilder in
  `deliver/QA-R7a/{r7a,basis,mit_reichweite}/`.

## Kurzfassung

- **Gates grün (gemessen):** `run_tests.sh` 811/0, alle Schritte OK; Render-Prüfungen 28/28 (Geländedeckung T1–T4, S1,
  C1, K1 0,000 %, `start_km0`, `light_base`); `golden.sh check` Arcade 20/20 und 17/17 identisch; `modern_sight --full`
  F1–F3, F7 grün (F2 0,593/0,596/0,555, Hülle 0 von 388.907 Seiten nicht abgedeckt); `modern_path_check --full` grün.
  Alle zehn Regeln des Pakets werden von Tests bewacht (zehn Mutationen, alle rot). Keine Arcade-Datei berührt.
- **Funktion (echte Bauten, 128 Richtungen):** 22.435 Requisiten zurück, 0 neu weg, Stadtzäune 75,3 % statt 64,3 % von
  Arcade, Grenzdach Belgrad → Sofia wieder auf Pfeilern. R7a's Zahlen bestätigt; Bilder byte-gleich nachgerendert.
- **Bild:** deutlich besser als die Basis an T2, S0, München, Hannover, Belgrad, T4, T3, R1 – auch auf „Steam Deck“ und
  nachts; nirgends schlechter als die Basis. Gegen Arcade: gleichwertig bis besser an T2, S0, Städten, R1; schlechter
  bleiben Kurveninnenseiten in den Bergen (T1, T3, T4, Clip) und Stadtkurven (C1-Parkbaum, Belgrads Mauer) – nach A-17
  richtig.
- **Hauptbefund QR7a-01 (hoch):** das strenge Lesen von A-17 (nichts > 0,5 m in der Hülle) hält nach dem Zusammenführen
  nicht: der Requisiten-Builder (R7c) prüft nur den Fuß, 5.630 Requisiten reichen mit Krone/Fassade in die Hülle (Basis
  974), C1 bei 270 m verdeckt in einer Spur mehr. R7a's vorgeschlagene Zeile heilt es (67 Restfälle, C1 6/16/18 px),
  nimmt aber München's Häuserzeile, T4's Felsgruppe und 1.218 Basis-Stücke wieder weg. Vorschlag: hinausschieben statt
  weglassen (97 % der Bäume ≤ 5 m tief) – Entscheidung der Leitung beim Zusammenführen.
- **QR7a-02 (mittel):** Konflikt mit FIX-RINT in `chunk_streamer.gd`; Auflösung mit `_frame_commit_us == 0`.
- Leistung (Deck, Bergstrecke, ×4): `render()` +0,17 ms im Mittel, Vorrechnen 0,18 ms; Laden `collect` bis 21,5 ms.

## 1. Fairness (gemessen)

| Prüfung | Befehl | Ergebnis |
|---|---|---|
| Sicht voll | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (236 s) | `f1 OK` 0 Fälle bis 270 m in 99.424.500 Stichproben (erster bei 280 m), `f1_lanes OK` 0 bis 260 m in 326.680.500, `f2 OK` 0,593 / 0,596 / 0,555 (≤ 0,60), `f3 OK` 0 von 5.923, `f7 OK` 0 von 2.011.532 Seiten mit Gelände über der Fahrbahn; Hülle: 0 von 388.907 Seiten nicht abgedeckt, 0 nicht als Kurvenkorridor gezählt, im Mittel 1,44 m breiter als die Stichprobe; `model OK` |
| Pfad voll | `… -s res://tests/sim/modern_path_check.gd -- --full` (57 s) | `modern_path_clearance OK` 267,6 m, `modern_path_loops OK` 2.064 m |

F1–F3 unverändert gegen die Basis (die Kamera ist nicht berührt). F7 prüft jetzt die Hülle gegen eine zweite Rechnung
(`Fairness.sight_envelope()`: doppelte Genauigkeit, Peilwinkel per `atan2` statt Kreuzprodukt, jede 7. Kamerareihe, jede
Spurmitte) – teilunabhängig: dieselbe Mittelachsen-Kappung (`clearance()`) und dieselbe 2,6-rad-Grenze wie der Kern. F7
prüft **nur das Gelände und die Korridorzahl, nicht die Requisiten** – das strenge Lesen von A-17 (nichts über 0,5 m in
der Hülle) bewacht kein Test (Befund QR7a-01).

## 2. Besitz, Zusammenführen, Arcade (gemessen)

- `git diff 9b02f05..509bb16 --stat`: 16 Dateien – `scripts/race3d/{sight_corridor.gd (neu), terrain_profile.gd,
  chunk_context.gd, chunk_streamer.gd}`, `builders/{border,city}.gd` (Ausnahmen der Leitung), `tests/race3d/fairness.gd`,
  `tests/sim/modern_sight.gd`, `tests/unit/race3d/{test_sight_corridor.gd (neu), test_terrain_profile.gd,
  test_chunk_streamer.gd, test_structures.gd, test_props.gd}`, `docs/renderer-modern.md`. **Keine eingefrorene
  Arcade-Datei.** Außerhalb des Auftrags: `test_props.gd` (R7c, als Abweichung gemeldet, Prüfinhalt unverändert),
  `fairness.gd` (Bibliothek von `modern_sight`, im Auftrag nicht genannt, von keinem anderen Paket dieser Welle berührt).
- Probe-Zusammenführung (`git merge-tree --write-tree`, nichts geschrieben): mit `wip/v080-r7c` (965b8a9) und
  `wip/v080-r7b` (2c154bc) **konfliktfrei**; mit `wip/v080-fix-rint` (3248211) **Konflikt in
  `scripts/race3d/chunk_streamer.gd`** (3 Stellen: Ende von `update()`, `stats()`, `reset_stats()`;
  `m1/QA-R7a/merge_streamer_fixrint.gd`), dazu ein inhaltlicher Fallstrick (Befund QR7a-02). `test_props.gd`,
  `test_structures.gd`, `test_chunk_streamer.gd`, `docs/renderer-modern.md` führen sich mit FIX-RINT/R7b/R7c von selbst
  zusammen.
- R7c (965b8a9) ruft in `props.gd` weiter `ctx.in_bend_corridor(z, x)` ohne Reichweite (Zeilen 777 und 1013 dort).

## 3. Greifen die neuen Tests? (Mutationen, gemessen – `sh/mutate.py`, Kopie `mut`, je eine Zeile gebrochen)

| Regel | Mutation | rot? |
|---|---|---|
| Fächer schreibt die rechte Kante (komplexer Fächer) | `_wr[wi] = w` entfernt | ja: `test_sight_corridor` 6/8 rot |
| Kamera auf der inneren Spur (einfacher Fächer) | Kamera auf die äußere Spur | ja: 6/8 rot |
| L = Bedarf / 0,6 | 0,7 | ja: `test_sight_corridor` 2/8, `modern_sight_f7` FEHLER (9.487 Seiten nicht abgedeckt) |
| Kurven 5 % über der Grenze | 1,00 | ja: 1/8 rot |
| Gelände liest die Hülle | nur noch Streifen + 0,55 m | ja: `test_terrain_profile` 1/7, `test_sight_corridor` 1/8, `modern_sight_f7` FEHLER (34.850) |
| Reichweite in `in_bend_corridor()` | ignoriert | ja: `test_chunk_streamer` 1/8 |
| Stadtzaun: Mitte oder Ende | nur Mitte | ja: `test_structures` 1/14 |
| Grenzpfeiler gegen die genaue Hülle | `pillar_in_sight()` immer false | ja: `test_structures` 1/14 |
| Zuschlag 0,05 m | −0,5 m | ja: `test_sight_corridor` 6/8 (`test_terrain_profile` bleibt grün) |
| Aufrundung `BEND_FLOOR_M` | 0 | ja: `test_terrain_profile` 1/7, `modern_sight_f7` FEHLER (`test_sight_corridor`, `test_chunk_streamer` grün) |

Alle zehn Regeln von R7a werden bewacht. Nicht bewacht: dass Requisiten mit ihrem Fußabdruck außerhalb der Hülle bleiben
(R7c-Datei, QR7a-01), und die Hauptfadenzeit des Vorrechnens (`_warm_corridor`, nur gemessen, kein Test).

## 4. Funktion im ganzen Netz (gemessen, echte Builder)

**Wirkliche Bauten** (`probe/realbuild.gd`): der ausgelieferte `ChunkStreamer` im Sync-Modus mit dem echten
Requisiten- und Stadt-Builder, jede der 128 Etappenrichtungen ganz (Basis und R7a je ~4 min); die Hülle als Maßstab mit
einer Kopie von R7a's Kern (`probe/env_kernel.gd`) auf einem eigenen Pfad – in beiden Bäumen derselbe Maßstab.

| | Basis | R7a | R7a + Reichweite (Kopie `mut`) |
|---|---|---|---|
| Requisiten gezeichnet | 194.168 | **216.603** | 208.927 |
| im Kurvenkorridor weggelassen | 35.022 | 12.587 | 20.263 |
| zurück gegen die Basis (`sh/dumpdiff.py`, je Segment/Eintrag) | – | **22.435** (16.947 Bäume, 2.947 Pflanzen, 952 Felsen, 1.142 Stadthäuser `city_*`, 211 Gebäude, 236 Sonstige) | 15.977 |
| neu weggelassen gegen die Basis | – | **0** | **1.218** (871 Stadthäuser, 268 Bäume, 53 Gebäude) |
| Stadtzaun/Hecke/Mauer gezeichnet / weggelassen | 51.246 / 28.416 (64,3 % von Arcade) | **59.949 / 19.713 (75,3 %)** | 59.949 / 19.713 |
| Requisiten > 0,5 m mit dem **Fuß** in der Hülle | 0 | 0 | 0 |
| … nur mit **Krone/Vorderkante** in der Hülle (weglassbar) | 974 | **5.630** (3.604 Bäume bis 12,1 m tief, 1.563 Stadthäuser bis 19,0 m, 150 Felsen, 285 Pflanzen) | 67 (Bäume ≤ 1,3 m, Felsen ≤ 4,3 m) |
| nicht weglassbar (Ereignis-Bauten, Wahrzeichen) in der Hülle | 197 | 197 | 197 |

Die Zahlen bestätigen R7a's Modellzählung (23.026 zurück, 0 neu weg, Zäune 75,3 %, 5.832 Fußabdruck-Fälle) auf echten
Bauten. Arcade zeichnet jedes Requisit seiner Liste: R7a zeichnet 216.603 + 12.587 im Korridor weggelassene; die
weggelassenen ersetzt der Builder außerhalb der City Limits durch Bodendecker ≤ 0,5 m.

**Grenzdächer** (`probe/roofs.gd`, `BorderB.supports_in_chunk()` je Dach, beide Bäume): Basis 4 von 48 hängen an Masten,
R7a **3 von 48** – Belgrad → Sofia km 340 steht wieder auf Pfeilern (`Lfront, Lend, Rfront_out, Rend_out`). Unverändert
hängend: Sofia → Belgrad km 55, Prag km 270, Kaunas km 90 (+ Testetappe, nicht im Netz). Zusätzlich bekommen drei Dächer
einen Endpfeiler rechts, den die Basis wegließ: Lüttich → Amsterdam km 25, Berlin → Posen km 95, Calais → Brüssel km 55
(nicht in R7a's Bildern; Bild in 5).

**Stadtzaun mit der genauen Hülle** (`probe/fence_exact.gd`): von 19.713 weggelassenen Stücken liegen 18.772 in der genauen
Hülle, 941 nur in der Aufrundung (`BEND_FLOOR_M`) – mit der genauen Hülle wie beim Grenzpfeiler stünden 76,4 % statt
75,3 % (QR7a-05).

## 4b. Code-Durchsicht (abgeleitet aus dem Code, wo nicht anders gesagt)

- **Verfahren richtig:** je Kamerareihe und äußerster Spurmitte die äußersten Sichtlinien vom fernen Ende zurück; der
  Schnittpunkt mit einem Querschnitt ist im Peilwinkel monoton, also gibt die äußerste Linie die äußerste Kreuzung
  (beide Linien auf beiden Seiten jenseits einer Vierteldrehung). Der „einfache Fächer“ (Drehung < 1,2 rad) ist richtig,
  weil die Kreuzung dann in beiden Spurlagen monoton ist; die Unit-Tests vergleichen beides mit einer vollständigen
  Referenz (jede Kamera, jede Spur, jede Zielreihe, jeder Querschnitt) – Mutationen M1/M2 machen sie rot (3).
- **Reihenfolge und Pfadwachstum:** `ensure(k)` rechnet jede Kamera ≤ k; eine Kamera hinter k sieht Reihe k nie, Kameras
  vor k werden gebraucht und sind fertig – die Hülle einer gelesenen Reihe ist endgültig. `_geometry()` zieht den Pfad
  höchstens ~405 m über die vorgerechnete Front (≈ Kamera + 2,1 km) hinaus; der Streamer hält ihn 3.438 m voraus – kein
  zusätzliches Erzeugen der Strecke im Spiel. Bremshüllkurve mit `_look` Reihen Vorlauf ist exakt (Unit-Test < 0,05 m).
- **Fäden:** `SightCorridor` wird nur über `TerrainProfile` im Hauptfaden gelesen (`ChunkContext.capture()` im
  `collect()`, `Station.CanopyJob.finish()` und `BorderB.supports_in_chunk()` im `collect()`); die Arbeiterfäden lesen nur
  Schnappschüsse. Geprüft per grep über alle Aufrufer von `corridor_width`/`sight`/`in_bend_corridor`.
- **Neustart des Streamers** (`_restart()`, Sprung voraus): `terrain.trim(1 << 40)` setzt den Korridor zurück; danach
  fehlen die Kameras vor dem neuen Pfadbeginn, die ersten ~300 m sind schmaler (wie beim Start mitten in der Etappe, von
  R7a gemessen ≤ 0,56 m an 2 von 13 Stellen). Im Spiel beginnt jede Etappe bei km 0 mit Vorlauf – kein Spielfall.
- **Kappung an der Mittelachse** (`clearance()`) und die 2,6-rad-Grenze gelten in Kern und F7-Referenz gleich; was
  jenseits der Mittelachse zu einem anderen Straßenteil steht, prüft keiner von beiden (abgeleitet: dort endet das
  Geländeband, Requisiten stehen dort auf dem Band des anderen Teils; geringes Restrisiko in Kehren).
- **Fußabdruck:** `in_bend_corridor(z, x, reach, half_len)` ist richtig gebaut und getestet (Mutation M6 rot), wird aber
  vom Requisiten-Builder (R7c) nicht gerufen → QR7a-01.
- **Doku:** `docs/renderer-modern.md` 5.3 beschreibt Verfahren, Zahlen und offenen Punkt zutreffend. Veraltet (nicht
  R7a's Datei): `docs/renderer-modern-gelaende.md` §8 „Kurveninnenseiten … bleiben weg, bis die Projektleitung … entscheidet“
  (Besitz R7c/R2).

## 4c. Der Fußabdruck und was er kostet (gemessen)

**Was die Lücke ist:** `props.gd` (R7c) prüft `in_bend_corridor(z, x)` nur am Fuß (bei `align: edge` am Anker = Vorderkante
+ Ausdehnung). Mit dem schmaleren, wirklichen Korridor stehen die zurückgekehrten Requisiten genau an seinem Rand – ihr
Fuß draußen, Krone oder Fassade drin. Echte Bauten (4): 5.630 Requisiten > 0,5 m reichen hinein (Basis 974).

**Wie tief** (`probe/realbuild_depth.gd`, R7a, alle 128 Richtungen):

| Klasse | Anzahl | Median | p90 | ≤ 2 m | ≤ 3 m | ≤ 5 m |
|---|---|---|---|---|---|---|
| Bäume (Kronenradius) | 3.604 | 1,9 m | 4,0 m | 1.877 | 2.639 | 3.489 (97 %) |
| Stadthäuser (Vorderkante) | 1.563 | 4,5 m | 10,8 m | 372 | 542 | 851 (54 %) |
| Pflanzen | 285 | 1,1 m | 2,4 m | 222 | 280 | 285 |
| Felsen | 150 | 1,8 m | 11,5 m | 83 | 93 | 104 |

**Gegenlauf mit R7a's vorgeschlagener Zeile** (Kopie `mut`, `sh/patch_reach.py`: `in_bend_corridor(z, x, reach, fw)`,
reach = Vorderkante/Kronenradius, fw = halbe Breite):

- Echte Bauten: 208.927 gezeichnet; Fußabdruck-Fälle **67** (Rest der Abtastung, Bäume ≤ 1,3 m, Felsen ≤ 4,3 m); gegen die
  Basis **15.977 zurück, aber 1.218 neu weg** (871 Stadthäuser, 268 Bäume, 53 Gebäude); gegen R7a 7.676 weniger
  (5.054 Bäume, 1.656 Stadthäuser).
- Verdeckungssonde C1 (FIX-M2 `qa_occl.gd`, „Hoch“, 270 m, Spur −1/0/+1, Pixel des Testautos, sichtbar ab 12):
  **R7a 6/0/0, mit Reichweite 6/16/18, Basis 6/9/0** (`logs/occl_C1.txt`). Mit der Zeile ist das Auto in zwei Spuren
  wieder sichtbar; Spur −1 verdeckt in allen drei Ständen ein Laternenmast vor dem Auto (`ausschnitte/c1_270_cmp.png`) –
  kein Korridorfall. Die Zeile entfernt dafür das Mietshaus an der Kurveninnenseite, das auch die Basis zeichnete
  (`ausschnitte/c1_none_mine_fix.jpg`).
- Bilder („Hoch“, gleiche Stellen, `vergleich/*_reichweite.jpg`): **T2** behält die Baumgruppe (eine Eiche weniger),
  **S0** gleich (Starteiche bleibt), **Hannover** behält das Eckhaus; **München verliert die nahe rosa Häuserzeile links
  wieder** (fast wie die Basis), **Belgrad** verliert die Pappel vorn rechts, **T4** verliert die zurückgekehrte
  Felsgruppe und eine Fichte.

Folgerung: Das strenge Lesen von A-17 mit Fußabdruck – das der Vertrag verlangt – nimmt einen sichtbaren Teil dessen
wieder weg, was R7a's Bilder zeigen (München, T4), und 1.218 Stücke, die die Basis zeichnete. Ohne die Zeile bleibt A-17
(2) an 5.630 Stellen verletzt, und an C1 verdeckt ein zurückgekehrtes Haus das Testauto bei 270 m in einer weiteren Spur.
Besser als Weglassen (abgeleitet aus der Tiefenverteilung): eine Requisite, deren Fuß außerhalb liegt, um ihre
Eindringtiefe + 0,3 m nach außen schieben, solange das Band reicht – das hielte 97 % der Bäume und gut die Hälfte der
Stadthäuser (≤ 5 m) an ihrem Platz in der Komposition, ohne etwas in die Hülle zu stellen (QR7a-01).

## 5. Bilder (angesehen; gleicher Simulationsstand, links Arcade)

**Echtheit der Bilder von R7a:** meine eigenen Läufe von T2 und S0 („Hoch“, Tag, `tools/ab_shot.sh` mit denselben
Argumenten) sind **byte-gleich** zu R7a's Bildern (`T2_high_modern_00.png` MD5 `dd0166a2…`, `S0_high_modern_00.png`
`0d950d40…`; Arcade ebenso). Die Bildgebung ist deterministisch; R7a's übrige „Hoch“-Bilder (Stand `e81886a`, die
späteren Commits ändern nur, *wann* gerechnet wird) und die Basis-Bilder von RINT-M2 gelten damit als nachgemessen.
Eigene Bilder: `deliver/QA-R7a/r7a/` (R7a), `basis/` (9b02f05), `mit_reichweite/` (R7a + Zeile in `props.gd`),
Vergleiche `vergleich/`.

| Stelle | gegen die Basis | gegen Arcade |
|---|---|---|
| T2 Kassel – Würzburg km 61,9 | **besser**: die ganze linke Baumgruppe (Eichen, Fichte) ist zurück, Basis: kahle Wiese mit Bodendeckern | **gleichwertig bis besser**: dieselbe Komposition, schattierte Modelle; mit Reichweite eine Eiche weniger |
| S0 Kiel km 0 | **besser**: Starteiche links zurück | gleich (Komposition wie Arcade, Modern mit Licht) |
| München km 161,7 | **besser**: rosa Häuserzeile links zurück, Basis: leerer Platz | gleichwertig; **mit Reichweite wieder fast wie die Basis – schlechter als Arcade** |
| Hannover km 142,4 | **besser**: großes Eckhaus links | gleichwertig (bleibt mit Reichweite) |
| Belgrad km 187,4 | **besser**: rechte Häuserzeile + Pappel | gleichwertig; Arcades Mauer rechts am Gehweg fehlt in allen Modern-Ständen (Stadtzaun im Korridor); mit Reichweite fehlt die Pappel wieder |
| T4 Saragossa – Pau km 198,8 | **besser**: Felsgruppe + Fichten rechts hinten | schlechter: Arcades nahe Fichte rechts fehlt (Blick in die Kurve); mit Reichweite fehlt die Felsgruppe wieder |
| T3 km 172,8 | besser: Felsgruppe + Kiefer links hinten | schlechter: Arcades Felsen innen in der Kurve fehlen (in den Sichtlinien, nach A-17 richtig); neu ein großer Schattenfleck eines Baums außerhalb des Bilds auf der Innenwiese (`ausschnitte/t3_cmp.png`) – physikalisch richtig, wirkt aber wie ein schwebender Fleck |
| T1 km 46,5 | kaum: zwei ferne Fichten links | schlechter: links leer, Arcade hat nahe Fichten (außerhalb des Ausschnitts von Modern) |
| C1 Dortmund – Frankfurt km 221 | gleich | gleichwertig, Arcades Parkbaum fehlt (City Limits: L = 300 m) |
| S4 Kiel – Hamburg km 80 | gleich | gleichwertig; Arcades Hecke rechts fehlt in beiden Modern-Ständen |
| Lyon km 297,4 / Bern km 302,7 / Nürnberg km 102,7 | gleich | gleichwertig bis besser (Licht, Schatten, Tiefe), Kompositionen wie Arcade |
| R1 Belgrad → Sofia km 340 | **besser**: Dach auf Pfeilern statt Mast mit Seilen | gleich (Pfeiler wie Arcade, ein rechter Pfeiler nach außen gerückt) |
| R2 Sofia → Belgrad km 55, R3 Prag km 270, R4 Kaunas km 90, R5 Testetappe km 64 | gleich (Mast mit Seilen) | anders als Arcade (dort Pfeiler); glaubhaft, nichts schwebt |
| Clip Saragossa – Pau km 197 (R7a, 20 s, Standbilder 3/8/13/18 s angesehen) | – | schlechter bei 3 s: Arcades nahe Fichtengruppe rechts fehlt; nachgemessen (`probe/spot.gd`): die Fichten stehen 7–17 m jenseits des Banketts an der Innenseite einer Rechtskurve, deren Sichtlinien dort 42–59 m weit laufen (schnelle Anfahrt, L 140–250 m) – nach A-17 richtig |

„Mittel“ (R7a's Bogen `m1/R7a/medium_sheet.jpg`): dieselben Kompositionen wie „Hoch“.

**Grenzdächer mit neuem rechten Endpfeiler** (`vergleich/R6_dach_arcade_basis_r7a.jpg` Berlin → Posen km 95,
`vergleich/R7_dach_arcade_basis_r7a.jpg` Calais → Brüssel km 55, „Hoch“, Bild 01): der zusätzliche Pfeiler steht hinter
dem rechten Häuschen, keine Tafel verdeckt (PL-/BE-Tafel und Fahrbahnschilder frei); sonst gleich der Basis und wie
Arcade.

## 5b. Steam Deck und Nacht (eigene Bilder, R7a gegen Basis)

| Bild | gegen die Basis | gegen Arcade |
|---|---|---|
| `r7a/T2_deck_ab_00.jpg` / `basis/T2_deck_ab_00.jpg` | **besser**: linke Baumgruppe zurück, wie bei „Hoch“ (weichere Schatten) | gleichwertig bis besser |
| `vergleich/Muenchen_deck_arcade_basis_r7a.jpg` | **besser**: Häuserzeile links zurück | gleichwertig |
| `vergleich/S0_nacht_arcade_basis_r7a.jpg` (22:00, „Hoch“) | **besser**: Starteiche als Silhouette zurück | besser (beleuchtetes Starttor, Schilder) |
| `vergleich/Muenchen_nacht_arcade_basis_r7a.jpg` (22:00, „Hoch“) | **besser**: Häuserzeile links mit beleuchteten Fenstern statt leerem Platz | gleichwertig bis besser |

Nichts sieht auf „Steam Deck“ oder nachts schlechter aus als auf der Basis; die Kompositionen sind dieselben wie bei
„Hoch“ am Tag.

## 6. Leistung (gemessen auf llvmpipe; Steam Deck abgeleitet)

`tests/race/run_stage.gd`, Saragossa – Pau ab km 165 (die Bergkurven T3/T4 liegen darin, die Fächer sind dort am
teuersten), Voreinstellung **„Steam Deck“**, Zeitraffer 4, 420 s Wand (km 165 → 206,2/206,4), Autopilot, Seed 7, Basis
und R7a nacheinander unter gleicher Last (`sh/stage.sh`, `stage/sp_deck_{base,mine}.log`, `logs/perf_table.md`). Je ein
Lauf – Höchstwerte rauschen.

| Wert | Basis | R7a |
|---|---|---|
| render_ms_avg / max | 2,06 / 8,56 | 2,23 / 12,15 |
| streamer.collect_ms_avg / max (Fahrt) | 2,13 / 3,93 | 2,29 / 3,59 |
| streamer.commit_ms_max | 1,33 | 1,41 |
| hooks_ms_max.streamer / .props | 7,25 / 0,20 | 8,69 / 0,23 |
| corridor_warm_ms_avg / max (Fahrt) | – | 0,18 / 1,45 |
| corridor_sync_ms_max / Summe / Aufrufe (ganzer Lauf inkl. Laden) | – | 16,96 / 40,1 / 258 |
| load.collect_ms_avg / max (hinter dem Ladebild) | 1,96 / 7,49 | 5,03 / 21,50 |
| draw_calls / primitives am Ende | 133 / 98.217 | 116 / 91.309 (Läufe enden an verschiedenen Stellen) |

- In der Fahrt: `render()` im Mittel +0,17 ms (+8 %), das Vorrechnen 0,18 ms je Bild im Mittel, höchstens 1,45 ms.
  Das längste Nachrechnen (16,96 ms) fällt ins Laden: `render_ms_max` der Fahrt (12,15 ms, nach dem Laden
  zurückgesetzt) ist kleiner als dieser Wert (abgeleitet; die `corridor_sync_*`-Zähler werden von `reset_stats()` nicht
  zurückgesetzt – Hinweis für R7/PERF).
- Laden: `collect` bis 21,5 ms statt 7,5 ms (der Korridor der ersten 2 km), hinter dem Ladebild; `prepare_ms` im
  Rauschen der Shader (Basis lief mit kaltem Shader-Cache).
- Steam Deck (abgeleitet, nicht gemessen): die Fahrt-Mittel (+0,17 ms `render()`, 0,18 ms Vorrechnen) sind klein
  gegen das Bildbudget; die seltenen Einzelspitzen von `warm()` und das Nachrechnen eines ganzen Stücks (QR7a-03) sind
  die Stellen, die auf dem Gerät zu messen sind.

## 7. Befunde

**QR7a-01 (hoch) – Strenges Lesen von A-17 nach dem Zusammenführen verletzt; die Zeile, die es heilt, nimmt einen Teil
der Bildgewinne wieder weg.** Wo: `scripts/race3d/builders/props.gd` `drop_reason()` (R7c-Datei; auf R7c `965b8a9`
Zeile 1013, auf 509bb16 Zeile 761). Was: Fußtest statt Fußabdruck; 5.630 Requisiten > 0,5 m reichen mit Krone/Fassade in
die Hülle (Basis 974; Stadthäuser bis 19 m tief); an C1 verdeckt das zurückgekehrte Haus das Testauto bei 270 m in einer
weiteren Spur (R7a 6/0/0 px gegen Basis 6/9/0). Kein Test bewacht das (F7 prüft nur Gelände und Korridorzahl).
Beleg: `logs/realbuild_all_r7a.log`, `logs/realbuild_depth.log`, `logs/occl_C1.txt` (alle gemessen). Nachstellen:
`godot --headless --path . -s m1/QA-R7a/probe/realbuild.gd -- --stage=all` (R7a-Baum, ~5 min). Lösung (beim
Zusammenführen, RINT-M3): (a) mindestens R7a's Zeile – in `drop_reason()`
`var fw := float(e["width"]) * float(it.get("scale", 1.0)) * 0.5`,
`var reach := (absf(x) - absf(float(it.get("x", x)))) if it.has("align") else fw` und
`ctx.in_bend_corridor(z, x, reach, fw)` (gemessen: 67 Restfälle, C1 6/16/18 px; kostet München-Häuserzeile, T4-Felsgruppe,
Belgrad-Pappel, 1.218 Stücke der Basis); (b) besser: was mit dem Fuß draußen, mit dem Abdruck drin steht, um die
Eindringtiefe + 0,3 m nach außen schieben, solange `ribbon_width` reicht (97 % der Bäume ≤ 5 m, 54 % der Stadthäuser),
erst sonst weglassen; (c) dazu eine Prüfung im Netz (Vorlage `probe/realbuild.gd`): 0 weglassbare Requisiten > 0,5 m mit
Abdruck in der Hülle.

**QR7a-02 (mittel) – Konflikt mit FIX-RINT in `chunk_streamer.gd`, und die naheliegende Auflösung ist falsch.** Wo:
Ende von `update()`, `stats()`, `reset_stats()`. Was: FIX-RINT schreibt Stücke in Schritten unter einem Budget fest
(`_commit_step`, `done` zählt nur fertige Stücke). Behält man beim Auflösen R7a's `if done == 0: _warm_corridor(cam_seg)`,
rechnet der Streamer den Korridor auch in Bildern, die schon bis 2 ms festgeschrieben haben (+0,25 ms, im Rückstand
+2 ms). Beleg: `git merge-tree --write-tree HEAD origin/wip/v080-fix-rint` → `CONFLICT (content)`, Text in
`m1/QA-R7a/merge_streamer_fixrint.gd` (gemessen); die Doppelbelastung abgeleitet aus dem Code. Lösung: beide Seiten
behalten, Bedingung `if done == 0 and _frame_commit_us == 0:` nach `_part_us("commit", tu)`; in `stats()` beide
Schlüsselmengen; in `reset_stats()` beide Blöcke.

**QR7a-03 (niedrig) – Hauptfaden: das Vorrechnen überzieht sein Budget in Einzelfällen, das Nachrechnen eines Stücks
kostet bis ~10 ms.** Wo: `SightCorridor.warm()` prüft die Frist erst nach einer ganzen Kamera inklusive
`_geometry()`-Block (32 Kameras) und `_ensure_need()`. Beleg (`probe/warmcost.gd`, Last 7–8, gemessen): Aufrufe mit
0,25-ms-Frist im Mittel 0,30 ms, p99 0,5–0,6 ms, höchstens 0,9–5,2 ms; ein Stück (32 Reihen) auf einmal (`ensure`, der
Weg, wenn `collect()` vor dem Vorrechnen ankommt) im Mittel 1,3–2,1 ms, p99 3,4–6,5 ms, höchstens 9,5 ms. Im Spiel
abgeleitet selten (die Front liegt ≥ 1,9 km voraus); Messung im Rennen in 6. Lösung: die Frist auch innerhalb von
`_geometry()`/`_ensure_need()` prüfen (Blöcke von 8 statt 32 Kameras) oder die Fächer als `WorkerThreadPool`-Aufgabe auf
Schnappschüssen der Geometrie rechnen.

**QR7a-04 (niedrig) – Besitz: `tests/unit/race3d/test_props.gd` (R7c) geändert.** Als Abweichung gemeldet, Prüfinhalt
gleich (Vorlage in Stück 13 statt 16); `git merge-tree` mit R7c und FIX-RINT konfliktfrei (gemessen). Lösung: beim
Zusammenführen den Hunk behalten.

**QR7a-05 (niedrig) – Stadtzaun gegen die aufgerundete statt die genaue Hülle.** `city.gd` lässt 941 Stücke weg, die
außerhalb der genauen Hülle stehen (nur in `BEND_FLOOR_M`), gemessen (`probe/fence_exact.gd`): 76,4 % statt 75,3 % von
Arcade wären möglich. Lösung: im Zaun-Test wie `BorderB.pillar_in_sight()` die genaue Hülle (`tp.sight.width_near`) –
dafür bräuchte `ChunkContext` die genaue Hülle als zweites Schnappschussfeld (Kern, R7) – oder `BEND_FLOOR_M` nur für
`in_bend_corridor()` der Requisiten.

**QR7a-06 (niedrig) – Veraltete Doku außerhalb von R7a's Dateien.** `docs/renderer-modern-gelaende.md` §8
„Kurveninnenseiten … bleiben weg, bis die Projektleitung … entscheidet“ widerspricht A-17/R7a. Lösung: R7c (Besitzer) oder
DOC ändert den Absatz auf den Stand von `renderer-modern.md` 5.3.

## 8. Vertragsfragen (mit Beleg)

1. **A-17 (2) „nothing that rises more than 0.5 m stands inside the envelope“ und A-17 (4) „F7 checks the envelope“
   passen nicht zusammen:** F7 prüft das Gelände und die Korridorzahl, nicht was darin steht; die Schnittstelle
   (`in_bend_corridor()`) war ein Punkttest am Fuß, und der Builder, der sie ruft, gehört einem anderen Paket. Gemessen:
   5.630 Fußabdruck-Fälle nach R7a (QR7a-01). Vorschlag: A-17 (4) um eine Netzprüfung der gebauten Requisiten
   ergänzen (Abdruck, nicht Fuß), Besitz bei R7c/R8.
2. **Zielkonflikt, den der Vertrag nicht entscheidet:** strenges A-17 mit Fußabdruck nimmt 1.218 Stücke weg, die die
   Basis zeichnete (871 Stadthäuser), und R7a's sichtbare Gewinne in München und an T4 (gemessen, 4c) – gegen „nichts
   darf schlechter aussehen als vorher“ und „Modern klar besser als Arcade“. Entscheidung der Leitung: Weglassen,
   Hinausschieben (Vorschlag QR7a-01 b) oder ein kleinerer F2-Bedarf in den City Limits (R7a's Frage 3).
3. **„a short bend gets the sagitta of its real arc“ / „a straight before a bend is free“** (A-17 (1)) widersprechen
   dem Hauptsatz (Hülle der Sichtlinien): kurzer Bogen 60 m, R 150 m: Scheitel 22,5 m statt −1,4 m (Unit-Test
   `test_short_arc`), Gerade vor der Kurve nur jenseits der hineinlaufenden Sichtlinien frei. R7a hat richtig nach dem
   Hauptsatz gebaut; den Klammersatz streichen.
4. **City Limits:** L bleibt dort 300 m (schnellste fahrbare Geschwindigkeit kennt kein Tempolimit) – Bern 0 von 5,
   Nürnberg 0 von 7 Häusern zurück (R7a, Modell), Belgrads Mauer und Arcades Parkbaum an C1 bleiben weg (Bilder).
   Leitung: Bedarf aus Tempolimit × Zuschlag in den City Limits zulassen oder nicht (dann bleibt F2 dort nur für
   Fahrer im Limit garantiert).
5. **A-18 „5 of 48 roofs“:** gemessen 4 von 48 auf der Basis, 3 von 48 mit R7a (+ das Dach der Testetappe, nicht im
   Netz) – `logs/roofs_{base,r7a}.log`.

## 9. Für die Nächsten

1. **RINT-M3 / Leitung (QR7a-01):** vor dem Zusammenführen entscheiden, wie A-17 (2) erfüllt wird: (a) R7a's Zeile in
   `props.gd drop_reason()` (Text in QR7a-01; gemessen 67 Restfälle, C1 wieder sichtbar, aber München-Häuserzeile, T4-
   Felsgruppe und 1.218 Basis-Stücke weg) oder (b) besser „hinausschieben statt weglassen“ (R7c), dazu eine Netzprüfung
   des Fußabdrucks (Vorlage `m1/QA-R7a/probe/realbuild.gd`). Ohne beides geht A-17 (2) an 5.630 Stellen nicht durch.
2. **RINT-M3 (QR7a-02):** Konflikt in `chunk_streamer.gd` mit FIX-RINT: beide Seiten behalten, Vorrechnen nur
   `if done == 0 and _frame_commit_us == 0`.
3. **RINT-M3:** `tests/golden/modern_slice.md5` nach dem Zusammenführen neu erzeugen (R7a: 4 von 6 Bildern ändern sich
   gewollt; mit der Zeile aus 1 vermutlich wieder andere – erst nach der Entscheidung).
4. **RINT-M3:** `test_props.gd`-Hunk von R7a (Vorlage Stück 13) behalten; mit R7c und FIX-RINT konfliktfrei.
5. **Leitung (Vertragsfrage 4):** F2-Bedarf in den City Limits – die Häuser in Stadtkurven (Bern, Nürnberg, C1-Parkbaum,
   Belgrads Mauer) kommen nur so zurück.
6. **R7/PERF (QR7a-03):** Frist in `SightCorridor.warm()` feiner prüfen oder die Fächer auf einen Arbeiterfaden;
   `corridor_sync_*` in `reset_stats()` zurücksetzen, damit `perf_stats()` die Fahrt zeigt; auf dem Deck messen.
7. **R7 (QR7a-05):** Stadtzaun gegen die genaue Hülle (941 Stücke, +1,1 Prozentpunkte gegen Arcade).
8. **R7c/DOC (QR7a-06):** `docs/renderer-modern-gelaende.md` §8 auf den Stand von A-17 bringen.
9. **QA-mid:** die drei Grenzdächer mit neuem rechten Endpfeiler (Lüttich → Amsterdam km 25, Berlin → Posen km 95,
   Calais → Brüssel km 55) in der Fahrt ansehen (Tafeln nicht verdeckt?) – Bilder in 5 soweit gemacht.

## 10. Geprüft und in Ordnung (gemessen, wo nicht anders gesagt)

- `modern_sight --full`: F1, F1-Spuren, F2 (0,593/0,596/0,555), F3, F7 inkl. Hülle 0/388.907 – grün; `modern_path_check
  --full` grün.
- `tools/run_tests.sh` (ganz, einmal): **811 Tests, 0 fehlgeschlagen**, alle Schritte `CHECKS OK`, 992 s – auch
  `test_far_ground_water` und `test_props` grün.
- `tools/run_render_checks.sh all`: **28 von 28 Dateien OK** (3.880 s), darunter `check_terrain_cover` T1–T4, S1, C1, K1
  je 0,000 % Magenta, `check_start_km0`, `check_light_base`, Arcade `check_glow_occlusion`, `check_sprite_flip`.
- `tools/golden.sh check`: **arcade 20 von 20, arcade-ui 17 von 17 identisch**.
- Keine eingefrorene Arcade-Datei berührt; alle Änderungen in R7a's Dateien und den Ausnahmen der Leitung (Ausnahme
  `test_props.gd`, gemeldet).
- Alle zehn Regeln des Pakets durch Tests bewacht (Mutationen, 3).
- Requisiten im Netz: 22.435 zurück, 0 neu weg (echte Bauten, 128 Richtungen); Stadtzäune 75,3 % statt 64,3 %;
  Grenzdach Belgrad → Sofia wieder auf Pfeilern (4 → 3 hängende Dächer).
- Bildgebung deterministisch: T2 und S0 byte-gleich zu R7a's Bildern.
- Hauptfaden in der Fahrt (Deck, Bergstrecke): `render()` +0,17 ms im Mittel, Vorrechnen 0,18 ms im Mittel.
- Fäden: der Korridor wird nur im Hauptfaden gelesen und gerechnet (Code-Durchsicht); Startabhängigkeit nur beim
  Start mitten in einer Etappe (R7a gemessen ≤ 0,56 m).
- Doku `renderer-modern.md` 5.3 zutreffend.

## Stand

Fertig 2026-11-23 ~01:45 UTC. `queue2` (Gates, Bilder) lief in das 2-h-Limit der Hintergrundaufgaben; die Reste liefen
einzeln (`sh/golden.sh`, `sh/rest.sh`, `sh/queue3.sh`). Weggelassen aus Zeitgründen: Deck-Bilder von S0, R1 und
Nachtbilder von T2/R1 (die Tag-/Hoch-Bilder und die echten Bauten decken diese Stellen ab). Große Zwischenstände
(Basis-Kopie, Mutationskopie, Caches, Rohbilder der Verdeckungssonde) gelöscht; Protokolle, Sonden und Ausschnitte
bleiben in `m1/QA-R7a/`.
