# NACH-R7a – Nachprüfung der Fix-Runde FIX-R7a (Sichtkorridor, Fußabdruck, Streamer)

- **Geprüfter Stand:** `4a43944` (origin/wip/v080-fix-r7a), Vergleich `509bb16` (R7a). Arbeitsbaum
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11` (Fast-Forward auf `4a43944`,
  `.godot` kopiert, Import sauber). **Nichts committet, nichts gepusht, keine Datei des Baums geändert.**
- **Zusammenführungs-Kopie „m3“** (Scratch `m1/NACH-R7a/m3`, kein Git): `git archive` des Baums von
  `git merge-tree --write-tree 4a43944 origin/wip/v080-fix-rint` (= `53bac42`, konfliktfrei) + `git diff 9b02f05
  origin/wip/v080-fix-r7c` (FIX-R7c-Stand `eb97a98` vom 23.11. 09:28, sauber angewandt) + FIX-R7a's
  `patch_props.py … B` (Hinausschieben ≤ 12 m). Das ist die nächste Näherung an RINT-M3, die heute möglich ist
  (FIX-R7c läuft noch; R7b/FIX-R7b nicht darin – sie berühren keine der geprüften Dateien).
- **Maschine:** 4 Kerne, llvmpipe unter Xvfb, Dummy-Audio, Last 2–4 durch andere Pakete. „gemessen“ = hier an
  Zahl/Bild/Log festgestellt; „abgeleitet“ = aus Code oder Rechnung. Steam Deck, echte GPU, Wirkung auf Menschen:
  immer abgeleitet.
- Werkzeuge in `m1/NACH-R7a/` (`probe/fp_true.gd`, `sh/*.sh`, `sh/*.py`), Protokolle in `m1/NACH-R7a/logs/`, Bilder in
  `deliver/NACH-R7a/{m3,kopf,vergleich,ausschnitte}/`.

## Kurzfassung

- **QR7a-01 (hoch): teilweise behoben.** Auf dem Branch allein bleibt A-17 (2) verletzt: `props_footprint --full`
  = **5.728** (gemessen, gleich FIX-R7a). Der übergebene Patch wendet sich auf Kopf + FIX-RINT + FIX-R7c (`eb97a98`)
  sauber an und bringt die Netzprüfung auf **0** (218.103 Requisiten, gemessen), C1 bei 270 m 5/18/19 px (Spur −1 ein
  Laternenmast wie immer), keine neuen Gebäude-Überschneidungen (2.327 statt 2.341 Paare), `test_props` 26/0.
  Mutationen: beide Wächter nötig – „nur Fuß“ fängt nur die Netzprüfung, die erst nach Umbenennung in
  `check_props_footprint.gd` ein Gate ist. Mit der echten AABB der Modelle bleiben 5.138 flache Fälle (Bäume Median
  0,18 m; 96 > 1 m; 85 `city_french_sud` bis 2,2 m, `extent_m` zu klein) – neu NR7a-01 (niedrig).
- **QR7a-02 (mittel): behoben.** `chunk_streamer.gd` führt sich mit FIX-RINT, FIX-R7c, FIX-R7b konfliktfrei zusammen;
  der Zwischenzustand COMMITTING hat immer einen Knoten, `_commit_pending()` erkennt ihn (Code); im
  zusammengeführten Baum 1 bzw. 0 von 3.000 Bildern mit Vorrechnen **und** Festschreiben (1,11 ms, gemessen, §6).
- **Seiteneffekte:** 13 Dateien, alle im Bereich von R7a/Ausnahmen + neue Netzprüfung; keine Arcade-Datei; Arcade
  20/20 + 17/17 identisch; `run_tests` 811/0; Sicht/Pfad voll grün; Render-Prüfungen Gelände (K1 0,000 %), Start,
  Lichtbasis, Bauwerke grün.
- **Neu:** NR7a-01 (Abdruck-Modell < Modell-AABB), NR7a-02 (Netzprüfung blind für `attach_list`), NR7a-03 (Vorrechnen
  zählt nach dem Zusammenführen als „commit“-Zeit), NR7a-04 (Doku-Name) – alle niedrig/Kleinigkeit.
- **Bild:** der Kopf allein zeichnet C1 byte-gleich wie R7a; mit Patch (m3) bleiben München-Zeile, T4-Felsen,
  Belgrads Pappel, C1-Eckhaus (weit zurückgesetzt). Gegen Arcade: Detail und Licht besser, Komposition gleichwertig
  (München, Belgrad) bzw. schlechter (T4-Fichte, C1-Parkbaum fehlen nach A-17).

## 1. QR7a-01 (hoch) – Fußabdruck im Sinn von A-17

**Was FIX-R7a geliefert hat (Code gelesen):** Kern-API `ChunkContext.in_sight_envelope()` / `bend_intrusion()` auf
einer Hülle mit 8 Reihen Rand im Schnappschuss (`ENV_MARGIN`), `TerrainProfile.envelope_width()` /
`rows()["envelope"]`, F7 prüft die genaue Hülle gegen die Referenz, Netzprüfung `tests/race3d/props_footprint.gd`
(noch kein Gate). Die eigentliche Zeile im Requisiten-Builder (`builders/props.gd`, Besitz R7c) liegt **nicht** auf
dem Branch, sondern als Patch (`deliver/FIX-R7a/patch_props.py`, `props_hinausschieben.diff`).

**Nachgestellt (gemessen):**

| Lauf | Ergebnis |
|---|---|
| `props_footprint.gd --full` auf dem Kopf `4a43944` allein | **FEHLER 5.728** (216.603 gezeichnet, 216.588 gemessen, bis 19,03 m tief; 3.674 Bäume, 1.575 Stadthäuser, 295 Pflanzen, 151 Felsen) – exakt FIX-R7a's Zahl; A-17 (2) ist auf dem Branch allein weiter verletzt (`logs/fp_head_full.log`) |
| `patch_props.py B` auf m3 (Kopf + FIX-RINT + FIX-R7c `eb97a98`) | wendet sich **sauber** an (auch auf FIX-R7c's heutigem `props.gd`, das 442 Zeilen mehr hat als `9b02f05`) |
| `props_footprint.gd --full` auf m3 mit Patch | **OK 0** (218.103 gezeichnet, 218.088 gemessen, 199 nie weglassbare) – exakt FIX-R7a's Zahl (`logs/fp_m3B_full.log`) |
| Verdeckungssonde C1 (FIX-M2 `qa_occl.gd`, „Hoch“, Testauto in drei Spuren) auf m3 | 270 m: Spur −1/0/+1 = **5 / 18 / 19 px** (FIX-R7a 6/16/18, QA: R7a 6/0/0, Basis 6/9/0); bis 200 m überall ≥ 30 px. Spur −1 verdeckt wie in allen Ständen ein Laternenmast (`ausschnitte/C1_270m_m3_none_l-1_l0.png`, angesehen) – kein Korridorfall (`logs/occl_C1.txt`) |
| Überschneidung von Gebäuden (eigene Sonde, gleiche Seite, gleiches Stück, AABB der Modelle) | m3 mit Patch 2.327 Paare / 283.953 m², m3 ohne Patch 2.341 / 285.324 m² – das Hinausschieben erzeugt **keine** neuen Überschneidungen (eher weniger) |

**Unabhängige Messlatte mit der wirklichen Geometrie (neu, `probe/fp_true.gd`):** `props_footprint.gd` und der Patch
benutzen dasselbe Abdruck-Modell (halbe Bibliotheksbreite `width_m/2` als Kronenradius und als halbe Länge, bei
`align` die `extent_m`-Seite). Die Netzprüfung ist damit eine Selbstprüfung des Patches, keine unabhängige Messung.
Meine Sonde baut dieselben echten Stücke (Streamer im Sync-Modus, Requisiten- und Stadt-Builder, 128 Richtungen) und
misst jede gezeichnete, weglassbare Requisite über 0,5 m mit der **AABB des Modells** aus dem Manifest (größte der
Varianten, mal Maßstab, gespiegelt; Bäume/Pflanzen/Felsen mit zufälliger Drehung als Kreis bis zur fernsten AABB-Seite;
Häuser ohne Drehung mit ihrer echten Ausdehnung quer und längs, Modell-z = −vorwärts), gleiche Fußregel wie der Kern.

| | m3 ohne Patch | m3 mit Patch |
|---|---|---|
| Abdruck-Modell des Patches in der Hülle | 5.728 | **0** |
| echte AABB in der Hülle (> 5 cm) | 5.967 | 5.138 |
| … tiefer als 0,5 / 1 / 2 m | 5.351 / 4.709 / 3.414 | **872 / 96 / 4** |
| tiefste | 19,03 m | 3,45 m (eine Buche am Kurvenende, Erfurt – Kassel km 111,7) |
| Bäume (Median / p90) | 2,25 / 4,59 m | **0,18 / 0,57 m** (4.318) |
| Pflanzen / Felsen (Median) | 1,47 / 2,02 m | 0,27 / 0,22 m (536 / 195) |
| Stadthäuser | 709 (+525 Sprite-Häuser ohne AABB), Median 3,9 m | **89**, Median 1,52 m, höchstens 2,20 m – 85 davon `city_french_sud` |

Gemessen (`logs/fptrue_m3B_full.log`, `logs/fptrue_m3U_full.log`). Folgerung: der Patch beseitigt die tiefen Fälle
(Fassaden bis 19 m, Kronen bis 12 m) vollständig; was bleibt, ist Ungenauigkeit des Abdruck-Modells – Kronen, deren
AABB 0,2–0,8 m über `width_m/2` hinausreicht (24 von 26 Pflanzen-/Felsmodellen, `sh/footprint_models.py`), und
`city_french_sud` (FIX-R7c/AS5a2), dessen Geometrie 2,1 m (unskaliert) über `extent_m.left` hinausreicht
(AABB x −13,30 gegen `extent_m.left` 11,22). Ob der äußerste AABB-Punkt einer Krone dicht genug ist, um ein Auto zu
verdecken, ist nicht gemessen (Blattkarten-Spitzen; Fichten tragen Zweige bis zum Boden). Befund **NR7a-01** (niedrig).

**Greifen die Wächter? (Mutationen am Patch in m3, `sh/mutate.sh`, je eine Zeile, danach zurückgesetzt – gemessen):**

| Mutation | `test_props` (Orakel, 26 Tests) | `props_footprint.gd` (schnell, 6 Richtungen) |
|---|---|---|
| ohne Mutation | 26/0 | OK 0 |
| M1: `drop_reason()` prüft nur den Fuß (Abdruck ignoriert) | **grün** (26/0) | **FEHLER 1** |
| M2: `push_out()` schiebt nicht | **rot** (1 fehlgeschlagen) | OK 0 |
| M3: halbe Tiefe, ohne Rand | **rot** (1 fehlgeschlagen) | OK 0 |

Beide Wächter sind nötig; M1 sieht nur die Netzprüfung (und im schnellen Lauf an genau einer Stelle). Solange sie
`props_footprint.gd` heißt, läuft sie in `tools/run_tests.sh` **nicht** – die Umbenennung beim Einbau ist Pflicht.
Weitere Läufe in m3 (gemessen): `test_props` 26/0 (mit FIX-R7a's Orakel-Änderung), `test_chunk_streamer` 9/0,
`test_structures` 14/0, `test_terrain_profile` 7/0, `test_sight_corridor` 8/0, `check_scripts` 334/0.

**Urteil QR7a-01: teilweise behoben.** Kern, Prüfwerkzeug und Patch sind richtig und nachgemessen (0 im eigenen Modell,
tiefe Fälle weg, keine neuen Überschneidungen, C1 wieder sichtbar); auf dem Branch selbst bleibt A-17 (2) an 5.728
Stellen verletzt, bis die Leitung den Patch beim Zusammenführen in R7c's `props.gd` einbaut und
`props_footprint.gd` zur Gate-Datei umbenennt. Der Rest mit echter Geometrie (NR7a-01) ist klein.

## 2. QR7a-02 (mittel) – Zusammenführen mit FIX-RINT, Hauptfadenbudget

- `git merge-tree --write-tree 4a43944 origin/wip/v080-fix-rint` (`3248211`, unverändert seit QA-R7a) →
  **konfliktfrei** (`53bac42`); ebenso mit `origin/wip/v080-fix-r7c` (`eb97a98`) und `origin/wip/v080-fix-r7b`
  (`c50d58f`) (gemessen).
- Code des zusammengeführten `update()` (m3) gelesen: `_warm_corridor()` läuft nur, wenn `not collected and not
  _commit_pending()`; `_commit_pending()` ist wahr für COLLECTED, BUILT, eine fertige Bauaufgabe und für jedes Stück mit
  Knoten, das nicht COMMITTED ist. FIX-RINT's Zwischenzustand COMMITTING setzt den Knoten im selben Schritt
  (`_commit_step()`: `c.node = node; c.state = COMMITTING`), wird also immer erkannt (abgeleitet aus dem Code).
  Einzige Lücke: eine Bauaufgabe, die zwischen der Prüfung und der Schleife fertig wird (von FIX-R7a selbst genannt).
- `stats()` enthält beide Schlüsselmengen (`corridor` verschachtelt + FIX-RINT's `commit_steps`, `commit_by`,
  `update_ms_max`), `reset_stats()` beide Blöcke (gelesen in m3). Kein Werkzeug in m3 liest die alten
  `corridor_*`-Schlüssel (grep).
- Nebenbefund (Kleinigkeit, abgeleitet): im zusammengeführten Baum misst `_part_us("commit", tu)` ab dem Ende des
  Sammelns – die Zeit von `_warm_corridor()` (bis 2 ms im Aufholbetrieb) landet in `update_ms_max.commit`. Ein Bild,
  das nur vorrechnet, erscheint dort als „commit“-Spitze (NR7a-03).
- Messung im zusammengeführten Baum: §6 (warm_vs_commit).

**Urteil QR7a-02: behoben** (im zusammengeführten Baum gemessen, §6: 1 bzw. 0 von 3.000 Bildern mit Vorrechnen und Festschreiben).

## 3. Diff `509bb16..4a43944`: Seiteneffekte, Besitz, Arcade

13 Dateien: `scripts/race3d/{chunk_context,chunk_streamer,sight_corridor,terrain_profile}.gd`,
`builders/city.gd` (Ausnahme der Leitung wie bei R7a), `tests/race3d/{fairness.gd,props_footprint.gd(+uid)}`,
`tests/sim/modern_sight.gd`, `tests/unit/race3d/{test_chunk_streamer,test_structures,test_terrain_profile}.gd`,
`docs/renderer-modern.md`. **Keine eingefrorene Arcade-Datei**, keine Datei außerhalb dessen, was R7a schon berührte,
außer der neuen Netzprüfung im Kern-Testordner (gemessen, `git diff --stat`).

Code-Durchsicht (abgeleitet):
- `bend_intrusion()`: Fußregel wie `in_bend_corridor()` (Fuß auf Fahrbahn/Bankett zählt nicht), zwischen zwei Reihen
  die größere Hülle, Abtastung je halbe Reihe, Index auf den Schnappschuss mit Rand geklemmt – richtig; worker-sicher
  (nur Schnappschuss-Felder).
- `envelope_width()` = `max(0, sight.width(k))`; `rows()["envelope"]` setzt die Hülle nur, wenn `width_near(k) > 0` –
  gleichwertig, weil `width(k) > 0` `width_near(k) > 0` einschließt (Einheitstest prüft die Gleichheit).
- `capture()` liest die Hülle für `count + 16` Reihen auf dem Hauptfaden (`sight.width()` → `ensure()` bis 8 Reihen
  über das Stückende); FIX-R7a's Fahrten zeigen kein Nachrechnen im Deck-Preset – nicht nachgemessen.
- `SightCorridor.warm()` in Schritten: Abbruch vor dem Schritt, der die Frist überschritte; Geometrie-/Bedarfsblock nur
  als erster Schritt eines Aufrufs; terminiert (nach `_geometry(c)` gilt `c ≥ _g0` und `c + _nb + 1 ≤ _g1`, nach
  `_ensure_need(k)` `_n_hi ≥ k`) – richtig.
- `city.gd`: Zaunstück fällt bei Mitte oder Ende in der genauen Hülle + 0,3 m – `test_structures` bewacht es.
- Doku-Kleinigkeit: Kopfkommentar von `terrain_profile.gd` sagt, die Hülle ohne Mindestbreite sei, „was
  `ChunkContext.in_bend_corridor()` prüft“ – gemeint ist `in_sight_envelope()` (NR7a-04).
- `docs/renderer-modern.md` 5.3 beschreibt Verfahren und Zahlen zutreffend; der Satz „Kein Teil einer Requisite über
  0,5 m mehr in der Hülle“ gilt für das Abdruck-Modell, nicht für die echte Geometrie (NR7a-01).

## 4. Bilder (angesehen; „Hoch“, Tag, gleicher Simulationsstand, `tools/ab_shot.sh`, Positionen von QA-R7a)

Bögen in `vergleich/<Stelle>_<Bild>.jpg`: Arcade | R7a `509bb16` (R7a's eigenes Bild; die Bildgebung ist
deterministisch, QA-R7a hat es byte-gleich nachgerendert) | Kopf `4a43944` (nur C1) | FIX-R7a's Bild mit Patch |
**m3** (Kopf + FIX-RINT + FIX-R7c `eb97a98` + Patch). Ausschnitte in `ausschnitte/`. Einschränkung: m3 enthält
FIX-RINT's Licht und FIX-R7c's Modelle/Felsen/LOD – Unterschiede m3 ↔ R7a sind nicht alle dem Patch zuzuschreiben.

- **Kopf allein = R7a:** `kopf/C1_high_modern_00.png` ist **byte-gleich** mit R7a's `C1_high_modern_00.png`
  (MD5 `e990fdad…`, gemessen); Arcade-Bilder von Kopf und m3 byte-gleich. Ohne den Patch ändert der Branch an den
  Bildstellen nichts (Zäune nur an wenigen fernen Stücken, FIX-R7a: s4_mittel 7 px).

| Stelle | m3 gegen R7a | m3 gegen Arcade |
|---|---|---|
| **C1** Dortmund – Frankfurt km 221 (`vergleich/C1_00.jpg`, `ausschnitte/C1_rechts_arcade_r7a_m3.jpg`) | das Eckhaus rechts steht wieder, deutlich weiter von der Straße (hinausgeschoben); dahinter wird ein weiteres Haus und ein Turm sichtbar; nichts schwebt, keine Durchdringung zu sehen | **gleichwertig**: Fenster, Licht, Tiefe und Schärfe klar besser; die rechte Bildhälfte ist leerer – Arcades großer Parkbaum fehlt (er steht in den Sichtlinien, A-17) und der Platz vor dem zurückgesetzten Haus ist weit und kahl |
| **München** km 161,7 (`vergleich/Muenchen_00.jpg`, `ausschnitte/Muenchen_links_arcade_r7a_m3.jpg`) | die rosa Häuserzeile links **bleibt**; in Bild 00 steht das vorderste Haus etwas zurück (weniger Fassade, mehr Seitenwand sichtbar – ein leichter Rücksprung in der Flucht), in Bild 01 ist die Zeile gleich R7a (`ausschnitte/Muenchen01_links_r7a_m3.jpg`). Wirkt nicht wie ein Fehler | **gleichwertig bis besser**: gleiche Komposition, Modern scharf mit Schatten und Gehwegpflaster, Arcade unscharf |
| **T4** Saragossa – Pau km 198,8 (`vergleich/T4_00.jpg`, `ausschnitte/T4_felsen_r7a_fix_m3.jpg`) | Felsgruppe und Fichten rechts hinten **bleiben**; der Fels hat in m3 eine andere Form/Lage als in R7a und in FIX-R7a's Bild (FIX-R7c's Felsänderungen, `ground_sink`/`face_road`); in der Lücke wird die ferne Serpentine mit einem Warnschild sichtbar | **schlechter** wie bei R7a: Arcades nahe Fichte rechts (Rahmen des Bilds) fehlt – sie steht in den Sichtlinien (A-17, richtig); Gelände, Berge, Gras sonst reicher |
| **Belgrad** km 187,4 (`vergleich/Belgrad_00.jpg`, `_01.jpg`) | gleich: Pappel rechts und Häuserzeilen stehen | gleichwertig; Arcades Mauer am Gehweg rechts fehlt weiter (in den Sichtlinien) |

Zusammengefasst (Bilder angesehen): der Patch behält an allen vier Stellen R7a's Gewinne; der Preis ist eine
sichtbare Abweichung von Arcades Lage einzelner Häuser (C1 weit zurück, München leicht zurück). „Klar besser als
Arcade“ ist Modern an diesen Stellen im Detail und Licht, in der Komposition nur gleichwertig (München) oder
schlechter (T4, C1 rechts leerer), weil Arcade dort Bäume in die Sichtlinien stellt. Nacht, „Mittel“, Deck und Clips:
nicht gemacht (der Patch ändert nur Lage und Zahl der Requisiten; FIX-R7a hat sie ebenfalls nicht gemacht).

## 5. Gates (Kopf `4a43944` im Arbeitsbaum, wo nicht anders gesagt; Logs `m1/NACH-R7a/logs/gate_*.log`)

| Gate | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, keine Fehlerzeile (Kopf und m3) |
| Arcade-Goldens | `tools/golden.sh check` (einmal) | **GOLDEN arcade: 20 von 20 identisch, arcade-ui: 17 von 17 identisch** |
| Sicht voll | `-s res://tests/sim/modern_sight.gd -- --full` | 6/6 `CHECK … OK`: F1 0 bis 270 m, F1-Spuren 0 bis 260 m, **F2 0,593 / 0,596 / 0,555**, F3 0 von 5.923, **F7** 0 von 2.011.532 Seiten, Hülle 0 von 388.907 nicht abgedeckt, **genaue Hülle 0 nicht abgedeckt, 0 ohne Hülle** (0,13 m breiter als die Stichprobe), Modell OK |
| Pfad voll | `-s res://tests/sim/modern_path_check.gd -- --full` | clearance 267,6 m, loops 2.064 m – OK |
| Render: Geländedeckung | `tools/run_render_checks.sh modern terrain_cover` | OK – T1, T2, T3, T4, S1, C1, **K1** je **0,000 % Magenta** |
| Render: Start km 0 | `… modern start_km0` | OK (kamera, auto, boden) |
| Render: Lichtbasis | `… modern light_base` | OK (tageslicht, schatten) |
| Render: Bauwerke (Stadtzaun) | `… modern structures` | `check_structures` OK (countdown, zieltor, grenze, blitz, tankstelle, stadt, schatten), `check_structures_licht` OK |
| Tests | `tools/run_tests.sh` (ganz, einmal) | **811 Tests, 0 fehlgeschlagen**, 17 Schritte `CHECKS OK`, 0 FEHLER, „Tests bestanden“ (1.087 s); darin `test_far_ground_water`, `test_props`, `test_chunk_streamer` grün |
| Netzprüfung Fußabdruck | `props_footprint.gd --full` | Kopf: FEHLER 5.728 (erwartet ohne Patch); m3 mit Patch: OK 0 |
| m3-Einheitstests | `tools/run_tests.sh <filter>` in m3 | `test_props` 26/0, `test_chunk_streamer` 9/0, `test_structures` 14/0, `test_terrain_profile` 7/0, `test_sight_corridor` 8/0 |
| Zusammenführen | `git merge-tree --write-tree 4a43944 origin/wip/v080-{fix-rint,fix-r7c,fix-r7b}` | alle drei konfliktfrei |

Nicht gelaufen: `tools/golden.sh modern-check` (A-18: die Liste erneuert die Zusammenführung; der Kopf zeichnet an
C1 byte-gleich wie R7a, §4), die übrigen 24 Render-Prüfdateien (nicht von den geänderten Dateien betroffen; FIX-R7a
hat alle 28 grün gemeldet).

## 6. Leistung/Messung im zusammengeführten Baum

FIX-R7a's Sonde `probe/warm_vs_commit.gd` (echter Streamer im Fadenbetrieb mit Gelände-, Requisiten- und
Stadt-Builder, 1,2 m je Bild, 3.000 Bilder, Standard-Voreinstellung, headless) in **m3** (also mit FIX-RINT's
schrittweisem Festschreiben und FIX-R7c), Last 3–4, gemessen (`logs/wvc_m3_*.log`):

| Strecke | Bilder mit Vorrechnen | mit Festschreiben (Schritte) | **beides** | Vorrechnen Ø / max | Nachrechnen (Aufrufe / Summe) |
|---|---|---|---|---|---|
| Saragossa – Pau ab km 160 | 2.895 | 53 (53) | **1** (dieses `update()` 1,11 ms) | 0,048 / 2,31 ms | 0 / 0 ms |
| Kiel – Hamburg ab km 60 | 2.933 | 35 (35) | **0** | 0,021 / 1,32 ms | 14 / 0,018 ms |

Der eine Fall ist die von FIX-R7a genannte Lücke (Bauaufgabe wird zwischen Prüfung und Schleife fertig); das Bild
blieb mit 1,11 ms weit unter dem Festschreibe-Budget von 2 ms. Das Vorrechnen überschreitet in Einzelaufrufen seine
Frist unter Last (2,31 ms bei `WARM_CATCHUP_US` 2 ms; ein Schritt ist immer erlaubt) – FIX-R7a nannte bis 1,6 ms;
auf dem Deck zu messen (abgeleitet: selten, Aufholbetrieb). Beobachtung außerhalb dieses Pakets: in der Kiel-Probe
dauerte ein `collect()` 25,18 ms (`collect_ms_max`, Standard-Voreinstellung, Last 4) – nicht vom Korridor
(Nachrechnen 0,018 ms gesamt); für QA-mid/PERF im Deck-Preset nachzusehen.

QR7a-02 ist damit im zusammengeführten Baum bestätigt behoben (gemessen).

## 7. Neue Befunde

**NR7a-01 (niedrig) – Das Abdruck-Modell ist kleiner als die Modelle; die Netzprüfung misst nur sich selbst.**
Wo: FIX-R7a's Patch für `builders/props.gd` `_place()` (`half_w = width·sc/2`, `reach` = `half_w` bzw.
`extent_l|r·sc`) und `tests/race3d/props_footprint.gd` `_judge()` (dasselbe Modell). Was: für 24 von 26 Baum-,
Pflanzen- und Felsmodellen reicht die AABB 0,15–0,82 m (Maßstab 1) über `width_m/2` hinaus (Pappel +0,82, Buche
+0,76, Palme +0,72 m; `sh/footprint_models.py`); bei zufälliger Drehung zeigt dieser Teil irgendwann zur Straße.
`city_french_sud` (FIX-R7c/AS5a2) reicht mit der Geometrie 2,08 m (unskaliert) über `extent_m.left` hinaus (AABB x
−13,30, `extent_m.left` 11,22; `city_french_maison` 0,3 m). Beleg (gemessen, m3 mit Patch, 128 Richtungen,
`probe/fp_true.gd`): 5.138 Requisiten mit der AABB in der Hülle, 872 tiefer als 0,5 m, 96 tiefer als 1 m, 4 tiefer
als 2 m (Bäume Median 0,18 m, p90 0,57 m; 85 `city_french_sud` 1,3–2,2 m); die Netzprüfung meldet 0. Ob die
äußersten Blattkarten ein Auto verdecken, ist nicht gemessen. Lösung: den Abdruck aus der AABB des Modells nehmen –
`PropLibrary` je Set `reach_r = max(|x0|,|x1|,|z0|,|z1|)` (größte Variante) für Klassen mit zufälliger Drehung, für
ausgerichtete Häuser `max(extent, AABB-Seite)` quer und die AABB längs (Modell-z = −vorwärts: vom Fuß −maxz … −minz),
im Patch und in `props_footprint.gd` gleich; Vorlage `m1/NACH-R7a/probe/fp_true.gd`. Für `city_french_sud` zusätzlich
`extent_m` prüfen (Besitz AS5a2/R7c). Kosten (abgeleitet): Bäume rücken ≤ 0,8 m weiter hinaus.

**NR7a-02 (niedrig) – `props_footprint.gd` sieht die angehängten Requisiten von FIX-R7c nicht.** Wo:
`tests/race3d/props_footprint.gd` liest nur `parts.props.list`; FIX-R7c legt Requisiten, die ein Modell mitbringt, in
`attach_list` (`props.gd` Zeile ~963 in m3) und schickt sie durch dieselbe `drop_reason()`. Beleg: in m3 heute 0
Einträge in `attach_list` im ganzen Netz (gemessen, `fp_true.gd` zählt sie mit) – also derzeit ohne Wirkung, aber
blind, sobald ein Modell `attach` bekommt. Lösung beim Umbenennen: `list` und `attach_list` prüfen (bei
`attach_list` ist `j ≥ sprites.size()`: Seite aus dem Vorzeichen von x, weglassbar = `veg`).

**NR7a-03 (Kleinigkeit) – im zusammengeführten Streamer zählt das Vorrechnen als „commit“.** Wo:
`chunk_streamer.gd` `update()` nach dem Zusammenführen mit FIX-RINT: `_warm_corridor()` läuft zwischen
`tu = _part_us("collect", tu)` und `_part_us("commit", tu)`; `stats().update_ms_max.commit` enthält damit bis
`WARM_CATCHUP_US` (2 ms) Vorrechnen (abgeleitet aus dem Code). Wer eine Spitze „commit“ jagt, sucht an der falschen
Stelle. Lösung (RINT-M3, eine Zeile): nach `_warm_corridor(cam_seg)` `tu = _part_us("warm", tu)`.

**NR7a-04 (Kleinigkeit, Doku) – `terrain_profile.gd` Kopfkommentar** nennt `ChunkContext.in_bend_corridor()` als
Leser der genauen Hülle; gemeint ist `in_sight_envelope()` (gelesen). Lösung: Namen tauschen.

## 8. Für die Nächsten

1. **RINT-M3 (QR7a-01):** `python3 deliver/FIX-R7a/patch_props.py <baum> B` – wendet sich auf Kopf + FIX-RINT +
   FIX-R7c `eb97a98` sauber an (gemessen); danach `props_footprint --full` = 0 (gemessen) und `git mv
   tests/race3d/props_footprint.gd tests/race3d/check_props_footprint.gd` (+ `.uid`) – ohne Umbenennung bewacht
   nichts in `run_tests.sh` den Fehler M1 (Mutation, §1). Falls FIX-R7c `props.gd` danach noch ändert: Patch erneut
   anwenden und beide Wächter laufen lassen.
2. **NR7a-01/-02:** Abdruck aus der AABB (Patch und Netzprüfung gleich), `attach_list` mitprüfen; Vorlage
   `m1/NACH-R7a/probe/fp_true.gd`. AS5a2/R7c: `city_french_sud` `extent_m.left` gegen die Geometrie prüfen.
3. **RINT-M3 (NR7a-03):** `tu = _part_us("warm", tu)` nach `_warm_corridor()`; `perf_stats` liest den Korridor unter
   `streamer.corridor.*`.
4. **RINT-M3:** `tests/golden/modern_slice.md5` einmal nach dem Zusammenführen neu (A-18) – R7c hat die Liste schon
   in `bd1803b` erneuert, nach dem Patch und FIX-RINT gilt sie nicht mehr; Bilder vorher ansehen.
5. **R7c/DOC (QR7a-06):** `docs/renderer-modern-gelaende.md` §8 Zeile 357–359 ist in FIX-R7c `eb97a98` weiter
   veraltet; Text in FIX-R7a's Bericht §9.4.
6. **QA-mid:** C1 und München in der Fahrt ansehen (hinausgeschobene Häuser: C1 weiter Platz vor dem Eckhaus,
   München leichter Rücksprung); Nacht/Deck der vier Stellen mit dem Patch sind nicht gerendert.

## 9. Abweichungen und Vertragsfragen

**Abweichungen:**
1. Den Patch habe ich nicht auf dem Kopf allein, sondern in der Zusammenführungs-Kopie m3 (Kopf + FIX-RINT + FIX-R7c
   `eb97a98`, noch in Arbeit) gemessen – näher an RINT-M3; die Bilder von m3 enthalten damit auch FIX-RINT's und
   FIX-R7c's Änderungen (Felsform an T4).
2. Keine Nacht-, „Mittel“-, Deck- und Clip-Bilder; Bilder nur an C1, München, T4, Belgrad („Hoch“, Tag).
3. Mutationen nur in der Scratch-Kopie (zurückgesetzt, `cmp` gegen die gesicherte Fassung gleich).

**Vertragsfragen (mit Beleg):**
1. A-17 sagt „nothing that rises more than 0.5 m … stands inside the envelope“, legt aber nicht fest, was „das
   Objekt“ geometrisch ist. Der Patch und seine Netzprüfung nehmen die Bibliotheksbreite; mit der AABB der Modelle
   bleiben 5.138 Fälle (872 > 0,5 m tief, gemessen, §1). Vorschlag für §11.4: „Abdruck = horizontale AABB des Modells
   (größte Variante, mit Maßstab, Spiegelung, Drehung); die Netzprüfung `check_props_footprint` (Kern) misst diesen
   Abdruck, nicht das Modell des Builders.“
2. A-17 entscheidet nicht, ob eine Requisite von Arcades Stelle weichen darf. Das Hinausschieben bis 12 m (FIX-R7a's
   Vertragsfrage 3) ist gemessen die Variante mit den geringsten Verlusten; die Bilder zeigen den Preis: C1's Eckhaus
   steht weit hinter einem kahlen Platz, München's vorderstes Haus springt leicht zurück (`vergleich/C1_00.jpg`,
   `ausschnitte/Muenchen_links_arcade_r7a_m3.jpg`). Die Leitung sollte das ausdrücklich in §11.4 festhalten.
