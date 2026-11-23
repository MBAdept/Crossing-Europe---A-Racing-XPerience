# FIX-R7a – Nacharbeit nach der Prüfung QA-R7a (Sichtkorridor aus der wirklichen Geometrie)

- **Arbeitsbaum:** `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8`, Branch
  `worktree-wf_ba4424b4-294-8`, Sicherung `origin/wip/v080-fix-r7a` (jeder Commit gepusht). Basis `509bb16` (R7a,
  Fast-Forward), kein Vorgänger dieses Laufs (kein `STAND.md`, keine Branch).
- **Endstand:** siehe §8 (Gates) und Ergebnis.
- **Maschine:** 4 Kerne, llvmpipe unter Xvfb, Dummy-Audio, Last 2–4 (andere Pakete). „gemessen“ = hier an Zahl/Bild/Log
  festgestellt; „abgeleitet“ = gerechnet oder aus dem Code geschlossen. Steam Deck, echte GPU, Wirkung auf Menschen:
  immer abgeleitet.
- **Werkzeuge** (Scratch `m1/FIX-R7a/`, nichts davon committet): `sh/patch_props.py` (die Änderung für
  `builders/props.gd` + Orakel von `test_props.gd`, Varianten A/B, wendet sich auch auf R7c's Stand `bd1803b` an),
  `probe/warmparts.gd` (Kosten des Vorrechnens je Schritt), `probe/warm_vs_commit.gd` (Bilder mit Vorrechnen UND
  Festschreiben, im eigenen und im mit FIX-RINT zusammengeführten Baum), `probe/realbuild.gd` + `probe/env_kernel.gd`
  (Sonde von QA-R7a, unverändert), `sh/dumpdiff.py`, `sh/occl_table.py`, `sh/tri.py`, `sh/queue*.sh`, `sh/stage.sh`.
  Kopien `m1/FIX-R7a/pfix` (Kopf + Änderung in `props.gd`) und `m1/FIX-R7a/base` (509bb16) – am Ende gelöscht.

## Kurzfassung

- **QR7a-01 (hoch), Fußabdruck:** bestätigt (5.728 Requisiten über 0,5 m mit Krone/Fassade in der Hülle, gemessen).
  Der Kern ist fertig: genaue Hülle im Schnappschuss mit 8 Reihen Rand, `in_sight_envelope()`/`bend_intrusion()`,
  F7 prüft die genaue Hülle, Netzprüfung `tests/race3d/props_footprint.gd`. Die nötige Zeile im Requisiten-Builder
  (R7c's Datei) ist als gemessener Patch übergeben: **hinausschieben statt weglassen** (Tiefe + 0,3 m, höchstens
  12 m). Mit ihm: 0 Verstöße im ganzen Netz, gegen die Basis 23.943 Stücke zurück und nur 8 neu weg (QA's
  Reichweite-Zeile: 15.977 / 1.218), München-Häuserzeile, T4-Felsen, Belgrads Pappel und C1's Eckhaus bleiben, C1
  bei 270 m in zwei von drei Spuren wieder sichtbar. Offen bis zum Einbau beim Zusammenführen.
- **QR7a-02 (mittel):** behoben – `chunk_streamer.gd` führt sich mit FIX-RINT (und R7b, FIX-R7b, R7c) ohne Konflikt
  zusammen; das Vorrechnen fällt nie in ein Bild, das festschreibt (auch nicht in Schritten): 0 von 3.000 Bildern im
  zusammengeführten Baum (gemessen).
- **QR7a-03:** behoben – `warm()` in Schritten (p99 0,50–0,67 → 0,29–0,39 ms), Zähler des Nachrechnens mit
  `reset_stats()` (Fahrt im Deck-Preset: 0 Nachrechnungen).
- **QR7a-05:** behoben – Stadtzaun gegen die genaue Hülle: 75,9 % statt 75,3 % der Stücke von Arcade.
- **QR7a-04/06:** nicht meine Dateien – Hunk behalten (konfliktfrei), Doku-Absatz als Text übergeben.
- **Gates:** siehe §8.

## 1. Befunde nachgestellt

| Befund | nachgestellt | Ergebnis |
|---|---|---|
| QR7a-01 (hoch) Fußabdruck | ja: `tests/race3d/props_footprint.gd --full` auf R7a's Stand: **5.728** Requisiten über 0,5 m mit dem Abdruck in der Hülle (3.674 Bäume, 1.575 Stadthäuser, 295 Pflanzen, 151 Felsen, bis 19,0 m tief) – QA: 5.630 mit eigener Messlatte | bestätigt |
| QR7a-02 (mittel) Konflikt mit FIX-RINT | ja: `git merge-tree --write-tree 509bb16 origin/wip/v080-fix-rint` → CONFLICT in `chunk_streamer.gd` | bestätigt |
| QR7a-03 (niedrig) Frist des Vorrechnens | ja: `probe/warmparts.gd` (0,25-ms-Frist): Mittel 0,31 ms, p99 0,50–0,67 ms, Aufrufe > 0,5 ms: 6 / 102 / 43 (Kiel–Hamburg, Saragossa–Pau, Bern–Mailand); `corridor_sync_*` nicht in `reset_stats()` (Code) | bestätigt |
| QR7a-04 (niedrig) `test_props.gd` | `git diff 9b02f05..509bb16` – nur die Vorlage | bestätigt, nichts zu beheben |
| QR7a-05 (niedrig) Stadtzaun gegen Aufrundung | ja (Code + echte Bauten) | bestätigt |
| QR7a-06 (niedrig) veraltete Doku | `docs/renderer-modern-gelaende.md` §8 | bestätigt, nicht meine Datei |

## 2. QR7a-01 – Fußabdruck (Kern fertig, Builder-Zeile übergeben)

**Grenze des Auftrags:** `builders/props.gd` gehört R7c; der Requisiten-Builder ruft `ctx.in_bend_corridor(z, x)` und
übergibt nur den Fuß. Aus `ChunkContext` heraus lässt sich die Größe eines Objekts nicht erkennen (der Kern kennt die
`PropLibrary` nicht) – die Semantik „dort“ zu ändern, ohne den Aufruf, geht für den Fußabdruck nicht. Deshalb: alles,
was der Kern dafür braucht, gebaut und getestet; die Änderung im Builder als fertiger, gemessener Patch übergeben.

**Im Kern (meine Dateien):**
- `TerrainProfile.envelope_width(k, seite)`, `rows()["envelope"]`: die genaue Hülle der Sichtlinien ohne die
  Mindestbreite am Kurvenende.
- `ChunkContext.envelope` / `env_edge` für die Reihen `seg_a − 8 … seg_b + 8` (`ENV_MARGIN`: ein Abdruck am Stückende
  reicht in die Reihen des Nachbarn – ohne Rand galt dort die Randreihe; Einheitstest mit `ENV_MARGIN = 0` rot,
  gemessen).
- `ChunkContext.in_sight_envelope(z, x, reach, half_len)` und `bend_intrusion(…)` (Tiefe quer zur Straße, negativ =
  draußen); längs der Straße je halbe Reihe abgetastet, zwischen zwei Reihen zählt die größere Hülle der beiden
  (am Kurvenende ändert sie sich um bis zu 2 m je Reihe; mit linearer Mitte blieben 187 Bäume bis 2,0 m in der
  unabhängigen Messlatte von QA, mit der größeren 0 – gemessen).
- `in_bend_corridor()` **unverändert** (das Orakel in R7c's `test_props.gd` rechnet mit dem Korridor des Geländes).
- F7 (`modern_sight`) prüft jetzt auch die genaue Hülle gegen die unabhängige Referenz.
- **Netzprüfung** `tests/race3d/props_footprint.gd`: echter Streamer im Sync-Modus mit echtem Requisiten- und
  Stadt-Builder, jede gezeichnete Requisite über 0,5 m, die der Builder weglassen darf, mit Abdruck gegen die genaue
  Hülle. Noch **keine** Gate-Datei (Name ohne `check_`, sonst wäre `run_tests.sh` auf diesem Stand allein rot); nach
  dem Einbau der Builder-Änderung `git mv` nach `check_props_footprint.gd`.

**Die Builder-Änderung (übergeben, `deliver/FIX-R7a/props_hinausschieben.diff`, Skript `patch_props.py <baum> B`):**
`drop_reason()` prüft den Abdruck (Kronenradius bzw. Anker bis Vorderkante, halbe Breite längs) gegen die genaue Hülle;
vorher schiebt `push_out()` eine Requisite, deren Fuß draußen steht und deren Abdruck hineinreicht, um die Tiefe +
0,3 m nach außen (höchstens `PUSH_MAX_M` = **12 m**, gemessen gegen 6 m: s. Tabelle), tiefer: weggelassen; jenseits des
Bands: weggelassen. Requisiten, deren **Fuß** in der Hülle steht, bleiben wie bisher weg (Pflanzen → Bodendecker) –
sie zu verschieben hieße Bäume 10–40 m zu versetzen. Das Orakel in
`test_props.gd` rechnet dasselbe nach (`test_props` 13/13 grün in der Kopie). Wendet sich sauber auf R7c's Stand
`bd1803b` an (gemessen).

**Gemessen (echte Bauten, 128 Richtungen):**

| | Basis 9b02f05 | R7a = dieser Kopf (Requisiten) | R7a + Reichweite (QA: Aufrundung, weglassen) | hinausschieben ≤ 6 m | **hinausschieben ≤ 12 m (übergeben)** |
|---|---|---|---|---|---|
| Requisiten gezeichnet | 194.168 | 216.603 | 208.927 | 217.517 | **218.103** |
| gegen die Basis zurück / neu weg | – | 22.435 / 0 | 15.977 / 1.218 | 23.540 / 191 (180 Stadthäuser) | **23.943 / 8** (8 Stadthäuser) |
| gegen R7a zurück / weg | – | – | – / 7.676 | 1.708 / 794 (548 Stadthäuser) | **1.711 / 211** (89 Stadthäuser, 80 Bäume) |
| Abdruck in der Hülle (`props_footprint --full`) | – | **5.728 (FEHLER)** | (QA-Messlatte: 67) | 0 (OK) | **0 (OK)** |
| Stadtzaun gezeichnet (Arcade 79.662) | 51.246 (64,3 %) | 60.473 (75,9 %) mit diesem Kopf; R7a 59.949 (75,3 %) | 59.949 | 60.473 | 60.473 |

Die „zurück gegen R7a“ (1.711: Bäume, Pflanzen, Felsen) kommen von der genauen Hülle statt der Mindestbreite am
Kurvenende; die „weg gegen R7a“ sind Stücke, die mit Krone/Fassade tiefer als erlaubt hineinragten oder deren Fuß nach
der vorsichtigen Regel zwischen zwei Reihen in der Hülle steht. Je Bildstelle (0–300 m vor der Kamera, `sh/dumpdiff.py`):
mit ≤ 12 m überall gleich viele oder mehr Stücke als R7a (Belgrad +1); mit ≤ 6 m verloren München 2 und Bern 1.
Die Messlatte von QA (`realbuild.gd`, Kopie von R7a's Kern) zeigt für hinausgeschobene, an der Kante ausgerichtete
Häuser noch „Eindringen“ (966 bzw. 1.477), weil sie die Vorderkante aus der **ursprünglichen** `x` der Strecke liest
– für die verschobenen Häuser falsch; für Bäume, Pflanzen, Felsen zeigt sie 0. `props_footprint.gd` misst den
gezeichneten Anker mit der Ausdehnung des Modells.

**Bilder:** §6. **Verdeckungssonde** (FIX-M2 `qa_occl.gd`, Testauto in drei Spuren, „Hoch“, mit der Änderung): C1
bei 270 m Spur −1/0/+1 **6/16/18 px** mit ≤ 6 m und mit ≤ 12 m (R7a 6/0/0, Basis 6/9/0 – QA; Spur −1 verdeckt in
allen Ständen ein Laternenmast, QA): das hinausgeschobene Eckhaus verdeckt nichts mehr. T4 und T3: jeder Wert gleich
R7a (`m1/R7a/occl_eval.log`), bis L = 118/119 m und bei 200 m überall sichtbar (≥ 54 px).

## 3. QR7a-02 – Streamer und FIX-RINT

- `_warm_corridor()` läuft jetzt **vor** der Festschreibe-Schleife, wenn `_commit_pending()` sagt, dass die Schleife in
  diesem Bild nichts tut (kein Stück zum Bau im Hauptfaden, keins gebaut, keine Aufgabe fertig, keins halb
  festgeschrieben – „halb“ = hat einen Knoten, ist aber nicht COMMITTED; so erkennt es FIX-RINT's Festschreiben in
  Schritten, ohne dessen Zustand zu nennen). Hilfsfunktionen an eine Stelle verlegt, die FIX-RINT nicht berührt;
  `stats()["corridor"]` (verschachtelt, in der ersten Zeile des Wörterbuchs) statt fünf Schlüsseln am Ende;
  `reset_stats()` setzt die Zähler am Anfang zurück.
- **Gemessen:** `git merge-tree --write-tree` mit `origin/wip/v080-fix-rint` (3248211), `wip/v080-r7c` (bd1803b),
  `wip/v080-r7b` und `wip/v080-fix-r7b` (c50d58f): **konfliktfrei**. Im zusammengeführten Baum (FIX-R7a + FIX-RINT,
  Kopie): `test_chunk_streamer` 9/0, `test_structures` 14/0, `test_terrain_profile` 7/0, `test_sight_corridor` 8/0;
  `probe/warm_vs_commit.gd` (echter Streamer, Saragossa–Pau ab km 160, 3.000 Bilder, Gelände-, Requisiten-, Stadt-
  Builder): Vorrechnen in 2.894 Bildern, Festschreiben in 53, **beides in 0**. Im eigenen Baum allein: 1 von 3.000
  (eine Bauaufgabe, die zwischen der Prüfung und der Schleife fertig wurde – das ist der einzige Fall, 0,68 ms).

## 4. QR7a-03 – Frist des Vorrechnens, Zähler

- `SightCorridor.warm()` arbeitet in Schritten und hört **vor** dem Schritt auf, der die Frist überschritte: ein Block
  Geometrie (≈ 0,24 ms je 32 Kameras) und ein Block F2-Bedarf (≈ 0,16 ms) sind je ein eigener Schritt und nur der
  erste eines Aufrufs; ein Fächer nur, solange sein laufendes Mittel noch passt. Ergebnis unverändert (jede Kamera
  einmal, Reihenfolge egal – `test_sight_corridor` 8/0).
- **Gemessen** (`probe/warmparts.gd`, 0,25 ms Frist, Pfad fertig): Mittel **0,31 → 0,20–0,21 ms**, p99 **0,50–0,67 →
  0,29–0,39 ms**, Aufrufe > 0,5 ms **6/102/43 → 0/4/1** (Kiel–Hamburg, Saragossa–Pau, Bern–Mailand); Einzelspitzen
  bis 1,2 ms bleiben (Last). Mit erst beim Rechnen erzeugtem Pfad (kein Spielfall – der Streamer hält den Pfad 3,4 km
  voraus) p99 0,32–0,48 ms.
- `reset_stats()` setzt auch `sync_us_*` des Korridors zurück (`SightCorridor.reset_sync_stats()`); `perf_stats()`
  zeigt nach dem Laden die Fahrt. Nicht umgesetzt: die Fächer auf einem Arbeiterfaden (QA's zweite Lösung) – die
  Schritte reichen für das Budget von 0,25 ms (gemessen), das Nachrechnen eines ganzen Stücks bleibt der Weg, wenn das
  Sammeln vor dem Vorrechnen ankommt (in der Fahrt 0 Aufrufe, §7).

## 5. QR7a-05 – Stadtzaun gegen die genaue Hülle

`city.gd` (Ausnahme der Leitung): ein Stück fällt, sobald seine Mitte oder eines seiner Enden in der **genauen** Hülle
liegt (`in_sight_envelope()`, Rand `FENCE_REACH_M` = 0,3 m für Abdeckung 4 cm und Pfeiler 6,5 cm vor der Linie plus
Reserve – mit 0,1 m wurde der Test `test_city_fences_stay_out_of_bend_corridors` rot, gemessen). Gemessen (echte
Bauten): **60.473** Stücke statt 59.949 (75,9 % statt 75,3 % von Arcade; QA's Schätzung ohne Rand 76,4 %).
`test_structures` 14/0. Belgrads Mauer am Gehweg rechts (QA) bleibt weg: sie steht in den Sichtlinien (Bild
`vergleich/Belgrad_00_rechts_arcade_r7a_fix.jpg`).

## 6. Bilder (angesehen; gleicher Simulationsstand, links Arcade)

„Hoch“, Tag, `tools/ab_shot.sh` mit den Positionen von QA-R7a; Einzelbilder in `deliver/FIX-R7a/hinausschieben/`
(Kopie mit der übergebenen Änderung, ≤ 6 m; `*_b12_*` mit ≤ 12 m), Bögen in `deliver/FIX-R7a/vergleich/`
(Arcade | R7a | QA's Reichweite-Zeile | hinausschieben). R7a-Bilder aus `deliver/R7a/`, QA's aus `deliver/QA-R7a/`
(byte-gleich nachgerendert, QA). An T2, T4, S0, Belgrad, Hannover liefert ≤ 12 m dieselben Stücke an denselben Stellen
wie ≤ 6 m (`dumpdiff.py`: gleiche Zahlen je Stelle; nur Tiefen über 6 m werden anders behandelt) – dort gelten die
≤ 6-m-Bilder.

| Stelle | gegen R7a | gegen QA's Reichweite-Zeile | gegen Arcade |
|---|---|---|---|
| München km 162,1 (`Muenchen_00.jpg`, `_00_b12.jpg`, `_00_links_r7a_fix.jpg`) | **gleich**: die rosa Häuserzeile links steht, das vordere Haus etwas zurückgesetzt (breiterer Gehweg) | **besser**: dort fehlt die Zeile | gleichwertig bis besser (Komposition wie Arcade, Licht/Schatten) |
| T4 Saragossa – Pau km 199,7 (`T4_00.jpg`) | gleich: Felsgruppe und Fichten rechts hinten | **besser**: dort fehlt die Felsgruppe | schlechter wie bei R7a: Arcades nahe Fichte rechts steht in den Sichtlinien |
| C1 Dortmund – Frankfurt km 222 (`C1_00_b12.jpg`) | ≤ 12 m: **gleichwertig** – das Eckhaus rechts steht wieder, etwa 8–11 m weiter von der Straße (es ragte 8,2/10,6 m in die Hülle); ≤ 6 m: **schlechter** – rechts ein leerer Platz | – | Arcades Parkbaum fehlt in allen Modern-Ständen (in den Sichtlinien) |
| Bern km 303,1 (`Bern_00_b12.jpg`) | gleich (Baum links minimal versetzt) | – | gleichwertig |
| Belgrad km 187,7 (`Belgrad_00.jpg`, `_00_rechts_arcade_r7a_fix.jpg`) | gleich: Pappel rechts und Häuserzeile stehen | **besser**: dort fehlt die Pappel | Arcades Mauer am Gehweg rechts fehlt weiter (in den Sichtlinien – auch mit genauer Hülle) |
| T2 Kassel – Würzburg km 63 (`T2_00.jpg`) | gleich: linke Baumgruppe | besser (dort eine Eiche weniger) | gleichwertig bis besser |
| Hannover km 142,8 (`Hannover_00.jpg`) | gleich: großes Eckhaus rechts | gleich | gleichwertig |
| S0 Kiel km 0 (`S0_00.jpg`) | gleich: Starteiche links | – | gleichwertig, Modern mit Licht |

Zusammengefasst: die übergebene Änderung (≤ 12 m) hält das strenge Lesen von A-17 (nichts über 0,5 m mit irgendeinem
Teil in den Sichtlinien) und behält dabei alle sichtbaren Gewinne von R7a; QA's Reichweite-Zeile verlor München-Zeile,
T4-Felsen und Belgrads Pappel. Schlechter als Arcade bleiben die Stellen, an denen Arcade etwas in die Sichtlinien
stellt (T4-Fichte, C1-Parkbaum, Belgrads Mauer) – nach A-17 richtig. Popping beim Hinausschieben ist nicht möglich:
die Stelle eines Stücks hängt nur von der Hülle ab, die je Etappe fest ist (abgeleitet; Clips nicht gemacht).

## 7. Leistung (llvmpipe gemessen, je ein Lauf, Höchstwerte rauschen; Steam Deck abgeleitet)

`tests/race/run_stage.gd` unter Xvfb (`sh/stage.sh`), Basis = R7a `509bb16` (Kopie) und dieser Kopf nacheinander unter
gleicher Last (3,7–4,2). `perf_stats()` nach dem Laden zurückgesetzt.

| Wert | Kiel–Hamburg ganz, „Mittel“, ×40: Basis | Kopf | Saragossa–Pau km 165, „Steam Deck“, ×4, 420 s: Basis | Kopf |
|---|---|---|---|---|
| Ergebnis | ok, 95 km | ok, **MD5 des ERGEBNIS gleich** | (Zeitgrenze, wie gewollt) | (Zeitgrenze) |
| render_ms avg / max | 4,47 / 21,78 | 4,24 / 23,23 | 2,04 / 10,00 | 2,13 / 7,78 |
| streamer collect_ms avg / max | 3,01 / 9,50 | 2,97 / 7,99 | 2,34 / 5,24 | 2,45 / 3,37 |
| streamer commit_ms max | 3,66 | 1,54 | 1,20 | 0,99 |
| Korridor: Vorrechnen avg / max (Aufrufe) | 0,26 / 2,13 | 0,22 / 1,99 (100) | 0,17 / 1,13 | 0,18 / 1,62 (708) |
| Korridor: Nachrechnen max / Summe / Aufrufe | 13,8 / 137,5 / 2.129 (mit Laden) | 14,7 / 100,6 / 1.849 (nur Fahrt) | 16,95 / 38,7 / 258 (mit Laden) | **0 / 0 / 0** (Fahrt) |
| load.collect_ms max (hinter dem Ladebild) | 13,3 | 16,3 | 21,5 | 26,5 |
| draw calls / primitives | 156 / 181.985 | 156 / 181.985 | 114 / 101.690 | 128 / 104.607 (andere Endstelle) |
| Skriptfehler | 0 | 0 | 0 | 0 |

- Fahrt im Deck-Preset: `render()` im Mittel +0,09 ms, das Vorrechnen 0,18 ms je Bild, das ein Bild ohne Sammeln und
  Festschreiben bekommt; **kein Nachrechnen in der Fahrt** (dank `reset_stats()` jetzt sichtbar – vorher mischte der
  Zähler das Laden hinein). Bei ×40 (1,3 s Fahrt je Bild) bleibt Nachrechnen unvermeidlich (R7a).
- Das Vorrechnen in Bildern, die festschreiben, ist mit `_commit_pending()` ausgeschlossen (§3).
- Laden: `collect` bis 26,5 ms hinter dem Ladebild (Korridor der ersten 2 km, ENV_MARGIN-Reihen) – kein Fahrtwert.
- Steam Deck (abgeleitet): die Mittel (+0,09 ms `render()`, 0,18 ms Vorrechnen) sind klein gegen 16,7 ms; zu messen
  auf dem Gerät bleiben die Einzelspitzen des Vorrechnens (bis 1,6 ms auf llvmpipe unter Last).

## 8. Gates (Kopf `4a43944`; Code-Stand seit `8f0e83f` unverändert, danach nur Doku; Logs `m1/FIX-R7a/logs/gate_*.log`)

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber (Exit 0, keine Fehlerzeile) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | 333 Skripte geprüft, 0 fehlerhaft |
| Tests | `tools/run_tests.sh` (ganz, **einmal**) | **811 Tests, 0 fehlgeschlagen**, alle Schritte `CHECKS OK`, „Tests bestanden“ (1.013 s) |
| Arcade-Goldens | `tools/golden.sh check` | **arcade 20 von 20, arcade-ui 17 von 17 identisch** |
| Modern-Goldens | `KEEP=… tools/golden.sh modern-check` | 2 von 6 identisch, GLES OK (PSNR 73,2 dB) – dieselben 4 Bilder wie bei R7a (start_mittel, s3_hoch, s4_mittel, s1_nacht: R7a's zurückgekehrte Requisiten). Gegen R7a's eigenen Stand (509bb16, gleich gerendert): 5 von 6 byte-gleich, `s4_mittel` 7 Pixel (ein fernes Zaunstück der genauen Hülle, angesehen). **Kein modern-make** (A-18: der Zusammenbau erzeugt die Liste neu). |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **28 von 28 Dateien OK**, 80 Prüfzeilen OK, 0 FEHLER; `check_terrain_cover` T1–T4, S1, C1, K1 je 0,000 % Magenta, `check_start_km0` OK, `check_light_base` OK, Arcade `check_glow_occlusion`/`check_sprite_flip` OK |
| Sicht voll | `-s res://tests/sim/modern_sight.gd -- --full` | F1 0 bis 270 m, F1-Spuren 0 bis 260 m, **F2 0,593 / 0,596 / 0,555**, F3 0 von 5.923, **F7** 0 von 2.011.532 Seiten mit Gelände über der Fahrbahn; Hülle 0 von 388.907 nicht abgedeckt; **genaue Hülle 0 nicht abgedeckt, 0 ohne Hülle** (im Mittel 0,13 m breiter als die Stichprobe) |
| Pfad voll | `-s res://tests/sim/modern_path_check.gd -- --full` | clearance 267,6 m, loops 2.064 m – OK |
| Modern-Etappe ganz | Kiel–Hamburg, Autopilot, „Mittel“, ×40 (§7) | ok, 0 Skriptfehler, Ergebnis gleich der Basis (MD5) |
| Netzprüfung Fußabdruck | `-s res://tests/race3d/props_footprint.gd -- --full` | Kopf allein: 5.728 (erwartet, Builder-Zeile fehlt); mit der übergebenen Änderung: **0** |
| Zusammenführen | `git merge-tree --write-tree HEAD origin/wip/v080-{fix-rint,r7c,r7b,fix-r7b}` | alle konfliktfrei |

## 9. Für die Nächsten

1. **RINT-M3 / R7c (QR7a-01):** die Änderung in `scripts/race3d/builders/props.gd` und im Orakel von
   `tests/unit/race3d/test_props.gd` einbauen – `python3 deliver/FIX-R7a/patch_props.py <baum> B` (wendet sich auf
   R7c's `bd1803b` an, gemessen) oder `deliver/FIX-R7a/props_hinausschieben.diff` (gegen diesen Kopf). Inhalt: in
   `_place()` Fußabdruck (`half_w = width·scale/2`, `reach` = `extent_l|r·scale` bei `align`, sonst `half_w`), dann
   `push_out()` (Tiefe + 0,3 m hinaus, höchstens `PUSH_MAX_M` = 12 m), `drop_reason(…, reach, half_w)` mit
   `ctx.in_sight_envelope(z, x, reach, half_len)` statt `ctx.in_bend_corridor(z, x)`. Danach
   `git mv tests/race3d/props_footprint.gd tests/race3d/check_props_footprint.gd` (+ `.uid`): dann ist es ein Gate von
   `run_tests.sh` (schnell sechs Richtungen; `--full` 128 Richtungen, gemessen 0 mit der Änderung).
2. **RINT-M3:** `tests/golden/modern_slice.md5` nach dem Zusammenführen neu erzeugen (A-18) – die Änderung von 1 und
   die Zäune dieses Pakets ändern Requisiten/Zäune in Kurven (Bilder vorher ansehen).
3. **RINT-M3:** `chunk_streamer.gd` führt sich mit FIX-RINT jetzt ohne Konflikt zusammen (gemessen, auch R7b, FIX-R7b,
   R7c); nichts von Hand auflösen. `perf_stats()`: die Zahlen des Korridors stehen jetzt unter
   `streamer.corridor.{warm_ms_avg, warm_ms_max, warm_calls, sync_ms_max, sync_ms_sum, sync_calls}` (früher fünf
   flache `corridor_*`-Schlüssel); Werkzeuge, die die alten Namen lesen (R7a's/QA's `perf_cmp.py`), anpassen.
4. **R7c/DOC (QR7a-06):** `docs/renderer-modern-gelaende.md` §8 „Kurveninnenseiten“ ersetzen, Vorschlag: „Seit A-17
   (R7a) ist der Kurvenkorridor die Hülle der wirklichen Sichtlinien (renderer-modern.md 5.3): was darin stünde, lässt
   der Requisiten-Builder weg (Pflanzen werden Bodendecker); Felsen und Häuser außerhalb stehen wie in Arcade, und was
   nur mit Krone oder Vorderkante hineinragt, schiebt er bis 12 m hinaus (FIX-R7a).“
5. **R7c (QR7a-04):** R7a's Hunk in `test_props.gd` (Vorlage Stück 13) beim Zusammenführen behalten; mit R7c
   konfliktfrei (gemessen).
6. **R6/Besitzer `station.gd`:** `Station.bend_corridor_at()` (zwei Kopien) liest noch den Korridor des Geländes mit
   Mindestbreite; die genaue Hülle wäre `tp.envelope_width(k, side)` (wie `in_sight_envelope()`) – das Dach der
   Tankstelle kann dann an Kurvenenden etwas öfter auf Säulen stehen. Nicht dringend (vorsichtig, nicht unfair).
7. **Leitung:** F2-Bedarf in den City Limits (R7a's Frage) bleibt offen – Arcades Parkbaum an C1 und Belgrads Mauer
   stehen in den Sichtlinien und kommen nur mit einem kleineren Bedarf dort zurück.
8. **PERF:** die Fächer des Korridors auf einen Arbeiterfaden (QA's zweite Lösung für QR7a-03) nur, wenn das Deck
   es verlangt – mit den Schritten hält `warm()` die 0,25 ms auf llvmpipe im Mittel (0,21 ms) und im p99 (≤ 0,39 ms).

## 10. Abweichungen und Vertragsfragen

**Abweichungen:**
1. QR7a-01: die Zeile im Requisiten-Builder steht nicht auf diesem Branch (R7c's Datei, Auftrag); übergeben als
   gemessener Patch (Skript + Diff). Bis zum Einbau bleibt A-17 (2) an 5.728 Stellen verletzt (wie bei R7a).
2. `tests/race3d/props_footprint.gd` ist noch keine Gate-Datei (Name ohne `check_`), weil sie auf diesem Stand allein
   fehlschlagen muss; Umbenennen beim Einbau.
3. `perf_stats()`: die Korridor-Zahlen heißen jetzt `streamer.corridor.*` (verschachtelt) – nötig, damit
   `chunk_streamer.gd` sich mit FIX-RINT ohne Konflikt zusammenführt.
4. Stadtzaun: Rand 0,3 m gegen die genaue Hülle (nicht 0); `bend_intrusion()` nimmt zwischen zwei Reihen die größere
   Hülle (vorsichtiger als die lineare Mitte, die das Gelände nutzt).
5. `in_bend_corridor()` bewusst unverändert (Orakel in R7c's `test_props.gd`); die genaue Hülle ist eine eigene
   Funktion.
6. Kein `modern-make` (A-18); Bilder mit ≤ 12 m nur an C1, München, Bern – an den übrigen Stellen sind die Stücke mit
   ≤ 6 m dieselben (gemessen), dort gelten die ≤ 6-m-Bilder. Keine „Mittel“-Bilder, keine Nacht-/Clip-Bilder (Zeit;
   die Änderung betrifft nur Lage und Zahl der Requisiten, nicht das Licht).
7. `tests/race3d/fairness.gd` (Bibliothek von `modern_sight`, schon von R7a geändert) um die Prüfung der genauen Hülle
   ergänzt.

**Vertragsfragen (mit Beleg):**
1. Der Auftrag sagt „change the semantics there [`in_bend_corridor()`], not the callers“ – für den Fußabdruck geht das
   nicht: der Kern kennt die Größe eines Objekts nicht (`PropLibrary` gehört dem Builder), der Aufrufer muss sie
   übergeben. Belegt: 5.728 Verstöße bleiben ohne die Builder-Zeile, 0 mit ihr.
2. A-17 (4) verlangt „F7 checks the envelope“, aber nichts prüfte gebaute Requisiten gegen sie. Vorschlag für §11.4:
   „`check_props_footprint` (Netz, Abdruck statt Fuß) ist Gate; Besitzer R7c/R8“.
3. Das Hinausschieben um bis zu 12 m weicht von Arcade's Stelle eines Objekts ab (Stadthaus an C1 8–11 m zurück) – das
   ist eine Entscheidung zwischen „nichts in den Sichtlinien“ und „wie Arcade“, die A-17 nicht trifft. Gemessen ist es
   die Variante mit den wenigsten Verlusten (8 Stücke der Basis statt 1.218 beim Weglassen) und ohne neue Verdeckung.
