# NACH-RINT – Nachprüfung der Nacharbeit FIX-RINT (Kopf `3248211`, Basis `9b02f05`)

Rolle: reine Prüfung, keine Commits, kein Push. Arbeitsbaum `.claude/worktrees/wf_9927a373-337-5` (ff auf `3248211`,
am Ende sauber), Basis als eigener Arbeitsbaum `m1/NACH-RINT/base` (`9b02f05`, danach entfernt). Jeder Lauf mit eigenem
absolutem `XDG_DATA_HOME` unter `m1/NACH-RINT/xdg/…`, `--graphics=` ausdrücklich, `nice -n 10`, `LP_NUM_THREADS=2`,
ein schwerer Lauf zur Zeit (gemeinsame Sperre `heavy.lock`, Warteschlangen `jobs1–4.txt`, Skripte `m1/NACH-RINT/sh/`).
Maschine: llvmpipe, Last 5–11 durch andere Pakete. Alles über echte GPU, Steam Deck oder Klangwirkung ist
**gefolgert**; Zahlen unten sind auf dieser VM **gemessen**, wenn nicht anders gesagt. Vergleichsbilder `9b02f05`: die
Modern-Bilder von QA-RINT-BILD (`m1/QA-RINT-BILD/ab/*_modern_NN.png`, gleiche Argumente; die Arcade-Bilder meiner Läufe
sind byte-gleich mit denen der QA, also gleiche Simulationszustände) und ihr Clip `valik_morgen_schnee.mp4`.

## 0. Ergebnis in einem Absatz

Der Blocker F-01 ist behoben: nach der Ausfahrt bei Schnee 2,5–3,1 % reines Weiß im Bildband (Arcade 0,1–0,3 %,
vorher 65–68 %), Modern schaltet im selben Bild wie Arcade auf draußen um, keine braunen Bilder mehr, Leitlinien
lesbar. F-05 (Tankstelle 0,95 × Arcade) und B-02 (Mutationen werden rot) sind behoben. F-06 ist nur für den Sportwagen
behoben – der Gran Turismo ist nachts pixelgleich mit `9b02f05`, also weiter silbern statt Arcades dunkelblaugrau.
B-01 hält das 3-ms-Budget nicht verlässlich: in meinem Lauf 6,51 ms je Bild, weil ein einzelner Baustein (roadside
6,32 ms) nicht geteilt wird. F-08 ist auf der VM nicht besser messbar als vorher (Streamer-Stoß 71,5 ms bei km 30,3,
QA vorher 70,9 ms; nachts im Regen 27,3 ms). F-02, F-03, F-04 sind unverändert offen (kein Code dazu im Diff). Neu: das stückweise Einhängen
(B-01) öffnet ein Fenster, in dem die Lichtebene einen Reflektor-Elternknoten nie vergisst – nachgestellt mit einer
Sonde: SCRIPT ERROR in jedem Bild mit Abblendlicht (N-01). Arcade bleibt identisch (golden 20/20, 17/17), Regel 3 hält (Prüfsummen Tag
und Nacht gleich Arcade), alle zugehörigen Render-Prüfungen und 175 Einheitstests grün.


## 1. Befund für Befund

| Befund | Urteil | Kern des Belegs (gemessen, außer wo „gefolgert“ steht) |
|---|---|---|
| F-01 Tunnelausfahrt (Blocker) | **behoben** | Clip Valík 8 Uhr Schnee: nach der Ausfahrt 2,5–3,1 % reines Weiß (Arcade 0,1–0,3 %, `9b02f05` 65–68 %); Umschalten im selben Bild wie Arcade; trocken 3,0 % statt 31 % |
| F-02 offene Autobahn | **nicht behoben** | kein Code dazu im Diff; Kiel–Hamburg-Bilder des Fahrlaufs zeigen dasselbe Bild wie vorher |
| F-03 Vegetation/Korridor | **nicht behoben** | kein Code dazu im Diff (A-17 → R7) |
| F-04 Stadthäuser nachts | **nicht behoben** | kein Modell, kein `baked.gdshader`, kein `city.gd` im Diff |
| F-05 Tankstelle nachts | **behoben** (Messgröße), Look schwächer als Arcade | Zone 91,6 gegen Arcade 96,4 = 0,95 × (vorher 0,77 ×); Prüfung `tankstelle` 0,87 × (Grenze 0,85) |
| F-06 Lack nachts | **teilweise** | Sportwagen 1,01 × / 1,21 × und sichtbar dunkelrot wie Arcade; Gran Turismo pixelgleich mit `9b02f05` – weiter silbern statt dunkelblaugrau |
| F-08 Stöße | **teilweise** | Instrumentierung (`spikes`, `update_ms_max`) da, Freigeben verzögert; auf der VM nicht besser: Streamer 71,5 ms bei km 30,3 (QA vorher 70,9 ms), `trash` 69,4 ms, `vehicles` 52,8 ms |
| B-01 Einhängen ≤ 3 ms | **teilweise** | Mechanismus wirkt (103 Schritte für 95 Stücke), aber `commit_ms_max` 6,51 ms je Bild: ein einzelner Baustein (roadside 6,32 ms, terrain 4,73, road 4,16) wird nicht geteilt; Kiel–Hamburg Nacht 4,23 ms (road 4,16), Saragossa–Pau Nacht 1,98 ms |
| B-02 Tönungswächter | **behoben** | Mutation baked / leaves / billboard je einzeln → `test_props` rot; sauber 13/0 grün |

### 1.1 F-01 – Tunnelausfahrt (Blocker): behoben

Nachgestellt mit genau dem QA-Aufruf (`GFX_ARGS=--gfx-preset=high CLIP_S=10 tools/ab_clip.sh … --start-km=87.3 --hour=8
--weather=snow --start-speed=80`), gemessen mit QAs `lumtrace.py` (Bildband 25–80 %, Grau ≥ 240) Bild für Bild:

| t (s) | Arcade Weiß | `9b02f05` Weiß / Leuchtdichte | `3248211` Weiß / Leuchtdichte |
|---|---|---|---|
| 3,997–4,030 (Kamera noch drin) | 0,36 | 0,47–0,49 / 194–196, bei 4,030 schon braun (151) | 0,52 / 205–206 |
| 4,047 (Arcade draußen) | 0,003 | 0,002 / **153 (braun)** | **0,027 / 170** |
| 4,08–4,85 | 0,001–0,003 | **0,646–0,676** / 213–221 | 0,026–0,028 / 170–171 |
| 4,9–5,35 | 0,001–0,002 | 0,59 → 0,035 | 0,024–0,031 / 170 |

- Keine braunen, schneefreien Bilder mehr: Modern wechselt im selben Bild wie Arcade (4,047 s) auf eine verschneite
  Landschaft. Weiß höchstens +2,9 Punkte über Arcade (Akzeptanz: +5). Leitlinien und Fahrbahnrand sind lesbar, Fichten
  tragen Schnee (Bild `F01_valik_schnee_ausfahrt_3248211.jpg`, vorher `F01_valik_schnee_ausfahrt_9b02f05_vorher.jpg`).
- Trocken (Valík 12 Uhr, gleiche Schritte, eigene Läufe Kopf und Basis): 3,9 s nach dem Start `9b02f05` 31,0 % Weiß,
  Leuchtdichte 195; `3248211` 3,0 % / 154; Arcade 1,5 % / 126. Bei 4,7 s 9,0 % → 1,2 %. Modern hebt die Mitteltöne
  noch ≈ 0,8 s lang sichtbar an (Arcade hat kein Nachglühen), brennt aber nichts mehr aus
  (`F01_valik_trocken_ausfahrt.jpg`).
- In der Röhre bei Schnee (1 s, 2,5 s) sehen Kopf und Basis gleich aus – dass `ce_snow`/`ce_wet` jetzt immer gesendet
  werden, bringt keinen Schnee und keine Nässe in die Röhre (`F01_valik_schnee_roehre_kopf_vs_basis.jpg`; Code: Fahrbahn
  Flag 64, Röhre ohne Wetter-Uniform, Fahrzeug-`snow_cover` 0; die Portale tragen als VPBR_STATIC Schnee, sind aber
  draußen).
- Neue Prüfung `tunnel_bridge_ausfahrt_schnee` / `_trocken` grün: Weiß höchstens +0,1 / +1,0 Punkte, Schnee 0,99 ×.
- Rest (alt, nicht von FIX-RINT): in den letzten drei Bildern vor der Ausfahrt (3,997–4,030 s) sieht man die obere und
  rechte **Kante des Blendvierecks** gegen die Landschaft (siehe N-02).

### 1.2 F-05 – Tankstelle nachts: behoben nach der Messgröße, im Look noch schwächer als Arcade

`TS15N` (Kiel–Hamburg km 14,3, 21 Uhr, „Hoch“), QAs `region.py 780 250 1280 460`: Arcade 96,4, `9b02f05` 74,7
(0,77 ×), `3248211` **91,6 (0,95 ×)**; reines Weiß 2,9 / 1,9 / 2,2 %. Render-Prüfung `tankstelle`: Tankstelle als Ganzes
0,213 gegen 0,246 = **0,87 ×** (Grenze 0,85 – knapp), Tankspur 0,88 ×. Angesehen (`F05_tankstelle_21uhr*.jpg`): unter dem
Shopvordach liegt jetzt ein warmer Schein, die Schaufenster leuchten schwach. Arcades Lichtvolumen ist eine große,
flächig helle Zone über das ganze Vordach mit weißen Deckenfeldern; Modern zeigt einzelne Lichtpunkte und einen
schwächeren Saum. Nicht mehr dunkler als Arcade, aber auch nicht besser.

### 1.3 F-06 – Lack nachts: teilweise

- Sportwagen (VALN, 22 Uhr Regen): sichtbar dunkelrot wie Arcade statt kirschrot (`F06_sportwagen_22uhr_regen.jpg`);
  Prüfung `spielerauto` 1,01 × Leuchtdichte, 1,21 × Sättigung (Band 0,6–1,10 / 0,7–1,25). In der Röhre ebenfalls
  dunkelrot (vorher hellrot). Im Freien eher etwas dunkler als Arcades Sprite (Karosserieform schwächer zu lesen).
- Gran Turismo (N2N, Dortmund–Frankfurt km 121, 22 Uhr Regen): `3248211` ist **pixelgleich** mit `9b02f05`
  (`cmp`), also unverändert hell silbergrau gegen Arcades dunkles Blaugrau (`F06_gran_turismo_22uhr_regen.jpg`). Die
  Prüfung meldet 0,92 × / 0,77 × und bleibt im Band; QAs Dachmessung (51/47, Sättigung 0,33/0,49) gilt weiter. Der von
  QA verlangte Teil „GT-Lack auf Arcades Farbton“ ist nicht gemacht (FIX-RINT: Asset-Sache).

### 1.4 B-01 – Einhängen unter 3 ms: teilweise

Kiel–Hamburg ganz, „Steam Deck“, Xvfb, Zeitraffer 16, threaded (ohne `--gfx-sync`), Last 9–10, Kopf:
`commit_ms_max` **6,51 ms** (Mittel 1,37), 103 Schritte für 95 Stücke; `commit_by` max: roadside **6,32**, terrain 4,73,
road 4,16, props 0,94 ms. Der Mechanismus teilt zwischen Bausteinen, nie innerhalb eines Bausteins – ein langsamer
Baustein allein reißt das Budget. FIX-RINTs vier Läufe (2,0–3,24 ms) lagen unter geringerer Last. Zwei weitere eigene Läufe: Kiel–Hamburg 22 Uhr Regen
**4,23 ms** (road allein 4,16 ms, 101 Schritte / 99 Stücke), Saragossa–Pau ab km 150 nachts 1,98 ms. Gefolgert: auf dem Deck ist roadside/terrain/road je ≈ 0,4–1,5 ms (Mittel × 1,5), das Budget hält
dort meistens, die Maxima kennt nur der Leistungstest (`chunk_commit_ms_max`, `commit_ms_max_by` stehen jetzt drin).

### 1.5 F-08 – Stöße: teilweise (Instrumentierung ja, Wirkung auf der VM nicht messbar)

Gleicher Lauf: `spikes` = streamer 71,5 ms (km 30,3), streamer 60,2 (km 47,5), vehicles 52,8 (km 47,9), streamer 30,0
(km 60,3) …; `update_ms_max`: trash **69,4**, collect 9,3, commit 6,6, path 4,9 ms. QA vorher (`9b02f05`, gleicher Lauf):
streamer 70,9, vehicles 20,4, terrain 8,4 ms. Kiel–Hamburg 22 Uhr Regen: streamer 27,3 (km 53,7), 24,6 (km 16,2), trash 25,5,
collect 21,8 ms. Saragossa–Pau nachts: trash 57,5, streamer 58,2 ms. Die Stöße sitzen
jetzt im verzögerten Freigeben (`trash`), sind aber nicht kleiner geworden. Ob das VM-Rauschen ist (FIX-RINT) oder ein
echter Treiber-Halt beim Löschen eines Netzes, trennt diese Maschine nicht; der von QA vorgeschlagene Teil „Pools in
`prepare()` vorwärmen“ fehlt, und die render()-Kosten der Nacht-Testetappe (2,65–2,85 ms) wurden nicht angegangen.

### 1.6 B-02 – Tönungswächter: behoben

`sh/mut_b02.sh` (im Kopf-Arbeitsbaum, unter der Sperre, mit `git checkout` zurückgesetzt, danach `git status` sauber):
sauber 13/0 grün; `a.rgb *= v_tint;` → `vec3(1.0)` in baked: rot („baked multipliert die Albedo mit der Tönung“);
`ALBEDO = t.rgb * v_bright * v_tint;` ohne Tönung in leaves: rot; `COLOR.rgb * v_tint` → `COLOR.rgb` in billboard: rot.
Rest: der Wächter prüft Text, keine Wirkung (eine Render-Prüfung „Haus mit Tönung #ff8080 gegen ohne“, wie QA sie als
„besser“ vorschlug, fehlt).

### 1.7 F-02, F-03, F-04: nicht behoben (wie von FIX-RINT angekündigt)

Im Diff `9b02f05..3248211` ist kein Gelände-, Himmel-, Requisiten-, Korridor-, Stadtmodell- oder `baked`-Code. Die
Bilder des Fahrlaufs Kiel–Hamburg (`kh_day_sheet`) zeigen bei Tag denselben flachen Himmel und dieselben Baumgruppen
wie QAs S1/S3. Zuständig: R7/R8 (F-02, F-03), AS5b/R7 (F-04).

## 2. Neue Befunde

### N-01 (mittel, neu durch B-01): Reflektoren eines halb eingehängten, verworfenen Stücks werden nie vergessen

- **Wo:** `scripts/race3d/layers/lights.gd` `add_reflectors()` (Z. 238–243) und `_update_glints()` (Z. 562–565);
  Auslöser `chunk_streamer.gd` `_commit_step()` / `_drop()` / `clear()`.
- **Was:** Seit B-01 hängt ein Stück über mehrere Bilder ein; `roadside.commit()` meldet dabei
  `lights.add_reflectors(mi, list)` für ein `mi`, dessen Stück noch nicht im Baum ist. Die Lichtebene vergisst
  Reflektoren nur über `tree_exiting`. Wird das Stück verworfen, bevor es den Baum je betreten hat (`_make_room()` bei
  vollem `max_chunks`, `clear()` bei einem Sprung/Neustart), gibt `_free_trash()` das `mi` frei, ohne dass
  `tree_exiting` kommt. Der Eintrag bleibt; `_update_glints()` liest ihn als `Node3D` → **SCRIPT ERROR in jedem Bild,
  in dem das Abblendlicht brennt** (Nacht, Dämmerung, Tunnel), die Funktion bricht ab, die Reflektor-Glanzpunkte bleiben
  für den Rest der Etappe stehen. FIX-RINT hat genau diesen Fall für `_statics` (Lichtebene) und die Flare-Ebene
  abgefangen (`is_instance_valid`), `_reflectors` aber nicht. Vor FIX-RINT war das Fenster zu (ein Stück hing in einem
  Bild ganz ein).
- **Beleg (gemessen):** Sonde `m1/NACH-RINT/sh/probe_reflectors.gd` mit der echten `lights.gd`: Reflektor an einem
  Knoten außerhalb des Baums melden, Knoten freigeben, drei `_update_glints()` →
  `SCRIPT ERROR: Trying to assign invalid previously freed instance. at: _update_glints (lights.gd:563)` dreimal,
  `_reflector_count` bleibt 1. In drei echten Fahrten (Kiel–Hamburg Tag und Nacht, Saragossa–Pau Nacht, threaded,
  Zeitraffer 16) trat der Fall nicht auf (0 Fehler) – Häufigkeit im Spiel **gefolgert** selten (nur ein verworfenes
  halb eingehängtes Stück; 8 von 95 Stücken wurden überhaupt geteilt).
- **Behebung:** in `_update_glints()` (und `_forget`-Pfad) wie bei `_statics`: `if not is_instance_valid(pair[0])`
  → Eintrag entfernen, `_reflector_count` senken; oder im Streamer beim Verwerfen eines COMMITTING-Stücks die
  Bausteine/Ebenen benachrichtigen. Einheitstest: Reflektor an einem nie eingehängten Knoten, freigeben, Glints
  aktualisieren → kein Fehler, Zähler 0.

### N-02 (niedrig, alt – nicht von FIX-RINT): Kante des Blendvierecks in den letzten Bildern vor der Ausfahrt

In den drei Bildern, in denen die Kamera die Portalebene erreicht (Valík Schnee 3,997–4,030 s), rahmt die Röhre das
Blendviereck nicht mehr: seine obere und rechte Kante stehen als gerade, harte Grenze zwischen ausgebrannter und
normaler Landschaft im Bild (`N02_blendviereck_kante_3248211.jpg`; in `9b02f05` gleich, dort mit brauner Landschaft
daneben: `N02_blendviereck_kante_9b02f05.jpg`). Arcade überstrahlt in diesen Bildern das ganze Draußen. Etwa 50 ms,
bei 135 km/h. Vorschlag: in den letzten ≈ 2 m vor dem Portal statt des Vierecks die Bildschirm-Ebene mit Arcades Gesetz
nehmen oder das Viereck auf den ganzen Sichtkegel verbreitern.

### Kleinere Beobachtungen (kein eigener Befund)

- `props.perf()["instances"]` und `_apply_lod()` zählen bzw. bearbeiten Halter verworfener Stücke noch, solange sie im
  Abfall liegen (≥ 4 Aufrufe, `TRASH_DELAY`) – die Statistik ist kurz zu hoch, sonst folgenlos.
- `lights._update_pools()` sortiert alle Laternen in jedem Bild neu, solange ein Lampen-Elternknoten außerhalb des
  Baums liegt (halb eingehängt oder im Abfall) – gefolgert billig, nicht gemessen.
- B-04 (Wächter): drei Bilder > 1 s im Countdown senken jetzt die Stufe. Auf einem Wayland-Desktop, der verdeckte
  Fenster drosselt, kann ein Spieler, der im Countdown wegschaltet, so ungewollt eine Stufe verlieren – gefolgert, nicht
  geprüft.

## 3. Was Testbuild 1 zeigte, hält es noch? (Kopf `3248211`)

| Punkt | Ergebnis |
|---|---|
| Auto am Start (Countdown) | sichtbar, Bild pixelgleich mit `9b02f05` (`TB1_start_auto_im_countdown.jpg`); `countdown`-Prüfung (Starttor-Lampen) grün; `start_km0` grün (Abschnitt 5) |
| Wasser unter den Brücken | Köhlbrandbrücke Tag und Nacht mit Elbe, Schiffen und Ufern im Fahrlauf ohne `--gfx-sync` (`STREAM_*`); Render-Prüfung `tunnel_bridge_B1` (630 Wasserflächen, 0 % Fernboden) grün |
| Pylonen nachts | Render-Prüfung `tunnel_bridge_beacon`: 4 Feuer, alle 4 blinken, 216 rote Bildpunkte in 36 Bildern; KBN (km 77,6, 22 Uhr) pixelgleich mit `9b02f05`: Pylonen, Seile, Elbe mit Schiffen (`TB1_koehlbrand_nacht.jpg`) |

Fahrläufe ohne `--gfx-sync` (der einzige Weg, auf dem das neue stückweise Einhängen und das verzögerte Freigeben
überhaupt laufen – alle Bild-Werkzeuge und Prüfungen nutzen `--gfx-sync` und damit `flush()`): Kiel–Hamburg 12 Uhr und
22 Uhr Regen sowie Saragossa–Pau ab km 150 nachts, „Steam Deck“, Zeitraffer 16, Bilder an 9–10 Stellen: keine Löcher,
keine fehlenden Stücke, Laternen und Spiegelungen da, 0 Engine-Fehler/-Warnungen (eigener Logger).

## 4. Seiteneffekte im Diff `9b02f05..3248211` (22 Dateien, +884/−65)

- **Eingefrorene Dateien (Regel 1):** keine Datei der Liste aus §2 im Diff; gegen v0.7.0 (`e3505e2`) ebenfalls keine
  Änderung an `scripts/race/{road_renderer,palette}.gd`, `scripts/gameplay`, `scripts/data`, `data`, `assets/sprites`.
- **Dateizuständigkeit:** nur `scripts/race3d/**`, Tests unter `tests/**/race3d`, `docs/renderer-modern.md` – Fassade
  (A-7) nicht angefasst; Verhaltensänderung `chunk_node()` (antwortet erst nach dem letzten Baustein) – einziger
  Aufrufer sind Tests (`test_start_lead_in`, `test_chunk_streamer`), geprüft per `grep`.
- **Wetter in der Röhre:** `ce_snow`/`ce_wet` gelesen von leaves, billboard, far_ground, vpbr (nur `snow_cover` > 0, also
  statische Modelle), baked, road (Flag 64 → 0), water, terrain. In der Röhre liegt keiner davon im Bild außer den
  Portalen (draußen); Bilder Röhre Schnee 1 s / 2,5 s Kopf = Basis.
- **Tunnelrampe an der Ausfahrt** (`tunnel_blend()` und `tunnel.gd zone_amount()` gleich, Test verlangt Gleichheit):
  Röhre und Fahrbahn werden auf den letzten 14 m vor der Ausfahrt heller; in den Bildern unauffällig.
- **Spielerauto-Füllung:** `_set_environment()` setzt jetzt bei jedem Palettenwechsel `fill` als Instanz-Uniform auf
  alle Geometrien des Spielerautos (Fahrzeug-Ebene, A-19 erlaubt) – kein neuer Instanzplatz.
- **Tankstelle:** 7 zusätzliche Flare-Einträge je Tankstelle (nur nachts sichtbar), keine Geometrie, kein Platz im
  Instanzpuffer; `collect()` in Stücken (B-03) – Einheitstest verlangt dasselbe Ergebnis.
- **Streamer:** siehe N-01; sonst stimmig (Rebase verschiebt auch halb eingehängte Knoten, `flush()`/`clear()` erledigen
  halbe Stücke, `--gfx-sync` hängt wie vorher ganz ein – Regel 10).
- **Wächter (B-04):** siehe Kleinere Beobachtungen.

## 5. Tore (alle auf `3248211`, gemessen)

| Tor | Ergebnis |
|---|---|
| Import | `godot --headless --import` sauber (Exit 0) |
| `tools/run_tests.sh unit/race3d` (die geänderten Testdateien test_chunk_streamer, test_environment_rig, test_props, test_quality, test_structures, test_vehicles) | **175 Tests, 0 fehlgeschlagen** (55 s) |
| `tools/run_tests.sh test_props` + Mutationen (B-02) | sauber 13/0; baked, leaves, billboard je **rot**; danach `git status` sauber |
| `tools/run_render_checks.sh modern tunnel_bridge` | **8/8 OK** (U1 Portal/innen/Ausfahrt 0,65 ×, Somport, B1 Wasser, beacon 4/4 blinken, ausfahrt_schnee +0,1 Punkte Schnee 0,99 ×, ausfahrt_trocken +1,0 Punkte) |
| `… modern structures` | **2 Dateien OK**: countdown, zieltor, grenze, blitz; tankstelle (Ganzes 0,87 ×, Spur 0,88 ×), stadt, schatten |
| `… modern night` | **2 Dateien OK**: fahrbahn, spielerauto (alle 6 Fälle im Band), verdeckung, blaulicht; nass_kegel 0,88 ×, spiegelung 0 px, laternen |
| `… modern start_km0` | **OK**: kamera ≤ 1,14 px, auto 193×192 gegen 192×192, boden 0,034 |
| `… modern instance_budget` | **3 Dateien OK**, keine Ablehnung der Engine: Kiel–Hamburg Szene ≤ 141, Stadt ≤ 176 (Schranke 178), Wald ≤ 222 (Schranke 224; Grenze 230 – knapp, wie vorher) |
| Regel 3 (Prüfsumme je Sekunde, `stage_shots.gd` = `stage_hash.gd` + Bilder) | Kiel–Hamburg 12 Uhr Modern/Deck = v0.7.0 `087ade2e…` (347 s); Kiel–Hamburg 22 Uhr Regen Modern/Deck = Arcade-Kopf `67695b6b…` (273 s) |
| Fahrläufe ohne `--gfx-sync` | 3 Läufe, 0 Engine-Fehler, 0 Warnungen, keine Löcher (Abschnitt 3) |
| `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch, arcade-ui: 17 von 17 identisch** (484 s) |
| Nicht gelaufen | voller `tools/run_tests.sh` (FIX-RINT hat ihn zweimal gefahren, nur die geänderten Testdateien nachgefahren), `golden.sh modern-check`, Render-Prüfungen ohne Bezug zum Diff, `modern_sight`/`path_check` (keine Platzierung geändert), Validator/Export, `audio_qc` |

## 6. Vertragsfragen und Hinweise für die Leitung

1. **§4.10 Einhängen ≤ 3 ms je Bild:** Mit Bausteinen als kleinster Einheit ist das Budget nur so gut wie der
   langsamste Baustein (hier roadside 6,3 ms, road/terrain 4,2–4,7 ms unter Last). Entweder road/roadside/terrain
   selbst teilbar machen (Netze in Teilen anlegen) oder das Budget als „Mittel ≤ 3 ms, Höchstwert auf dem Deck
   gemessen“ festlegen.
2. **F-08 Akzeptanz (Deck p99 ≤ 33 ms, kein Bild > 50 ms)** ist auf dieser VM nicht prüfbar; die neuen Felder
   `spikes`, `chunk_commit_ms_max`, `commit_ms_max_by` im Leistungstest sind der Weg. Der Deck-Lauf sollte vor
   Testbuild 2 kommen.
3. FIX-RINTs Vertragsfragen (A-20 Satz 1 auf `ce_headlight_light`, A-7 `chunk_node()`, eigenes Nachglühen-Gesetz)
   halte ich für sachlich richtig; das Nachglühen ist in den Bildern lesbar (Markierungen bleiben).

## 7. Für die nächsten Pakete

- N-01 vor dem nächsten Testbuild beheben (eine Zeile `is_instance_valid` + Test) – sonst kann eine Nachtfahrt im
  Gebirge mit Fehlerflut und eingefrorenen Reflektoren enden.
- GT-Lack nachts (F-06 Rest) im Modell/Lack auf Arcades Blaugrau bringen.
- Tankstelle nachts: Arcades flächiges Lichtvolumen unter dem ganzen Vordach fehlt im Look (F-05 Rest).
- F-08: Pools in `prepare()` vorwärmen; Deck-Messung.
- F-02/F-03/F-04 wie geplant in R7/R8/AS5b; N-02 (Blendviereck-Kante) bei Gelegenheit.
