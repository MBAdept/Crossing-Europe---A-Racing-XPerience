# QA-R7c – unabhängige Prüfung von R7c (Fern-LOD der Bauten und Pflanzen), Stand `bd1803b`

- Prüfling: `origin/wip/v080-r7c` = `bd1803bbde9e1b7ccff6c3512fee8872d6a20103` (Basis `9b02f05` = RINT-M2, darin die Mischung
  von `wip/v080-as5ar2` als `43a1fcc`). Bericht des Pakets: `deliver/R7c/bericht.md`.
- Arbeitsbaum `…/worktrees/wf_ba4424b4-294-7` (ff auf `bd1803b`, nichts committet, nichts gepusht). Vergleichsbäume
  (git archive + `.godot`, importiert): Basis `m1/QA-R7c/base` (9b02f05), **`m1/QA-R7c/merge` (43a1fcc = Basis +
  AS5aR2-Modelle, vor R7c's eigenen Commits)** – nötig, weil die Basis des Briefs die neuen Stadthäuser von AS5a2 noch
  nicht hat (Paris, Amsterdam, Bern, Lyon zeigen dort Sprites); nur gegen 43a1fcc sieht man, was R7c selbst ändert. (Die Kopien und die Mutationskopie `mut` sind nach der Prüfung gelöscht – Platz; `sh/mkcopy.sh <rev> <ordner>` baut sie neu.)
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt mit bis zu zwei weiteren Agenten); **angesehen** =
  Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen).
- Werkzeuge und Rohdaten: `m1/QA-R7c/sh/` (Warteschlangen, `tri.sh` Arcade | Basis | [43a1fcc] | R7c, `mutate.py`,
  `perf.sh`, `picstats.py`, `tilepeaks.py`), `m1/QA-R7c/probe/` (`scan_r7c.gd`, `bands_all.gd`), Logs `gates/`, `scan/`,
  `mutlogs/`, `perf/`, `k6/`. Bilder: `deliver/QA-R7c/raw/<ort>_<stufe>_h<stunde>_tri_NN.jpg` (+ Einzel-PNGs, Diff-Bilder).


## 1. Ergebnis in Kürze

- **Nichts kaputt:** Arcade 20/20 + 17/17 identisch, 808 Tests grün, 29/29 Render-Prüfungen, Sicht F1–F3/F7 und Wege
  mit `--full` grün, keine eingefrorene Datei, keine fremde Datei außer den im Brief erlaubten (gemessen).
- **Funktion im ganzen Netz:** R7c zeichnet in allen 128 Richtungen + DEV exakt dieselben 195 741 Requisiten wie der
  Stand vor ihm (43a1fcc); alle Bänder aller 77 Modelle lückenlos; Phasen gültig; `ground_sink` höchstens 0,33 m
  (gemessen).
- **Leitentscheide:** 1 (Überblenden) erfüllt – kein Stufensprung in den Clips, `check_lod_band` 0,6 % statt 7,1 %;
  2 (Fernlicht) **unabhängig nachgemessen: ±5 % erfüllt**; 3 (Flimmern) wie vom Paket gemeldet teils offen; 4 (Dämmerung)
  bei „Hoch“ gleich der Basis (warme Fensterpixel 4,7 % gegen Arcade 6,4 %); 5–8 gebaut, Instanzbudget unverändert.
- **Bild:** bei Tag in allen Städten klar besser als Arcade; bei „Hoch“ gleich der Basis (0,05–0,5 % Pixel). **Bei
  „Steam Deck“ verliert der Hamburger Speicher bei 35–60 m Details** (Türen flach, QR7c-01), **beim Countdown steht ein
  Baum im Band gerastert** (QR7c-06), ferne Fassaden sind etwas weicher (QR7c-04). Nachts und im Lyon-Vorort/Wald
  schlechter als Arcade – aber schon in der Basis bzw. in den Modellen (F-04, R7a), nicht R7c.
- **Wachen:** nur 6 von 17 Mutationen werden gefangen – Fernlicht, Flimmern, Relief, Phase, Tags und Anbau-Korridor
  sind unbewacht (QR7c-02).
- **Leistung:** Bildzeit gleich, −10–13 % Primitive, +3 (Deck) bis +27 (Hoch) Zeichenaufrufe (im Budget), Haken von
  `props.gd` 2,5–3× teurer mit Spitzen bis 4,4 ms auf dem Deck-Preset (QR7c-03).
- **Urteil:** kann in den Zusammenbau RINT-M3; vor Testbuild 2 sollten QR7c-01 (eine Konfigurationszeile) und QR7c-06
  behoben oder von der Leitung hingenommen werden; QR7c-02/03 in der nächsten Runde.

## 2. Prüfumfang (die sechs Punkte des Briefs)

1. **Bilder:** 27 Kombinationen (6 Städte + Wald + Countdown; Hoch und Steam Deck; 12 / 19:30 / 22 Uhr), je Arcade |
   Basis 9b02f05 | R7c, an sechs Stellen zusätzlich 43a1fcc; 7 Kombinationen aus Zeitgründen ausgelassen
   (`sh/tri_skip.txt`: Deck 12 Uhr Amsterdam/Bern/Lyon, Nürnberg 19:30, Lyon 22 Uhr, Hamburg Deck 19:30, Wald Deck 22
   Uhr). Jedes Bild angesehen, kritische Stellen vergrößert und gemessen (Abschnitt 5). R7cs zwei Clips Kachel für Kachel
   ausgewertet; eigener Clip nicht aufgenommen.
2. **Funktion:** echte Stück-Bauten aller 128 Richtungen + DEV in drei Bäumen, Bänder aller Modelle (Abschnitt 3.2).
3. **Fairness:** `modern_sight --full`, `modern_path_check --full` (Abschnitt 3).
4. **Arcade-Identität und Besitz:** `tools/golden.sh check`, `git diff --stat`, Zusammenbau-Proben (3.1, 3.5).
5. **Tests:** `tools/run_tests.sh` (einmal voll), `tools/run_render_checks.sh all`; 17 Mutationen (3.3, 3.4).
6. **Leistung:** `run_stage.gd` mit `perf_stats`, Deck und Hoch, R7c gegen 43a1fcc und Basis (Abschnitt 6); zusätzlich
   Fernlicht nachgemessen (5.2) und Studio-Vergleich lod0 | lod1 | Sprite (QR7c-01).

## 3. Gates und Funktion (alles gemessen auf dieser VM, Stand `bd1803b`, Logs in `m1/QA-R7c/gates/`, `scan/`, `mutlogs/`)

| Prüfung | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import .` | Exit 0, keine Fehlerzeile (nur der Dateiname `ui_error.wav`) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | Exit 0 (9 s) |
| Tests (einmal voll, von höchstens 2) | `tools/run_tests.sh` | Exit 0 – **808 Tests, 0 fehlgeschlagen**, alle CHECK-Dateien OK, „Tests bestanden (983 s)“ |
| Render-Prüfungen | `tools/run_render_checks.sh all` | Exit 0 – **29 von 29 Render-Prüfdateien in Ordnung** (3873 s), darunter `check_start_km0`, `check_terrain_cover` (K1), `check_light_base`, `check_lod_band` (Barockhaus hart 7,1 % → Band 0,6 %, Eiche 36,6 % → 1,1 %, Deckung −0,0 %), `check_instance_budget*` (höchstens 141 / 171 / 216 Instanzen mit Instanz-Uniforms, Grenze 230) |
| Sicht F1–F3, F7, Modell | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | Exit 0 (137 s): F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappen), F1 Spuren 0 bis 260 m, F2 höchstens 0,593 / 0,596 / 0,555, F3 0 von 5923 Zielen später als Arcade, F7 0 von 2 011 532 Querschnittsseiten, Modell 0 abweichend |
| Wege | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | Exit 0 (55 s): kleinster Abstand 267,6 m, Schleifen OK |
| Arcade-Identität | `tools/golden.sh check` (einmal, am Ende) | siehe Abschnitt 3.5 |
| Modelle | `python3 tools/blender/validate_models.py --no-godot` | 110 Modelle, 183 Sets, Manifest = Fragmente (kein Fehler; Netze nur über `check_models` in den Tests dekodiert: OK) |
| Zusammenbau-Probe | `git merge-tree --write-tree bd1803b <zweig>` | mit `wip/v080-r7a` (509bb16), `wip/v080-r7b` (2c154bc), `wip/v080-fix-r7b` (818150b) ohne Konflikt; mit `wip/v080-fix-rint` (3248211) **ein Konflikt in `tests/unit/race3d/test_props.gd`**; `modern_materials.gd` ändern beide, Git mischt es selbst |

### 3.1 Besitz der Dateien (Regel 1 und 7)

`git diff 9b02f05..bd1803b --stat`: 131 Dateien. Davon bringt die verlangte Mischung von `wip/v080-as5ar2` (43a1fcc)
die Modelle, `tools/blender/*`, `docs/modelle.md` und `assets/models/manifest.json` (neu erzeugt, nicht von Hand). R7c
selbst (`git diff 43a1fcc..bd1803b --stat`, 17 Dateien): `builders/props.gd`, `prop_library.gd`, `model_factory.gd`,
`modern_materials.gd`, `baked/billboard/leaves.gdshader`, neu `inc/lod_band.gdshaderinc`, `config/game_config.json`
(nur `graphics.modern.props` und der `_doc`-Text, kein `landmark_*`), `docs/renderer-modern-gelaende.md`, Tests
(`test_props.gd`, neu `check_lod_band.gd`, `check_props_render.gd`) und `tests/golden/modern_slice.*` (Brief gegen A-18,
gemeldet). **Keine eingefrorene Arcade-Datei** (`scripts/race/…`, `scripts/gameplay/`, `scripts/data/`, Audio, Sprites,
`data/`: 0 Treffer). Die Korridor-Semantik von `ChunkContext` (R7a) und der Wahrzeichen-Block (R7b) sind unberührt;
`environment_rig.gd` (angebotene Ausnahme) nicht benutzt.

### 3.2 Funktion im ganzen Netz (Datenscan, gemessen)

Eigene Probe `m1/QA-R7c/probe/scan_r7c.gd`: echte Stück-Bauten von `props.gd` + `city.gd` über den ausgelieferten
`ChunkStreamer` (sync), **alle 128 Richtungen + DEV**, in drei Bäumen:

| Baum | gezeichnete Requisiten | im Korridor weggelassen | Band / Laufzeit |
|---|---|---|---|
| R7c `bd1803b` | 195 741 | 35 492 | 156 s |
| `43a1fcc` (Basis + AS5aR2, vor R7c) | 195 741 | 35 492 | 136 s |
| Basis `9b02f05` | 195 739 | 35 494 | 134 s |

- R7c gegen `43a1fcc`: die sortierten Listen (Strecke, Segment, Nummer, Set, x, z, Maßstab, Spiegelung) sind
  **identisch (0 Zeilen Unterschied)** – die Stufen, Bänder, Tags und Phasen nehmen nichts weg und stellen nichts um.
  Gegen die Basis 9b02f05 unterscheiden sich 3950 Zeilen nur in x um 0,04 m (Kantenmaß der AS5aR2-Modelle) und
  zwei Stadthäuser (Amsterdam – Lüttich Segment 7414, Pau – Toulouse 6334) stehen jetzt, die vorher im Korridor
  wegfielen – das ist die Mischung (neue Kantenmaße), nicht R7c.
- Jede gebaute Modell-MultiMesh trägt ein Band (241 150 Knoten, 0 mit verdrehtem Band), jede der 602 113 geprüften
  Instanzen hat Custom-a in [1, 2) (Tönungsschalter + Phase); 46 041 Schattenwerfer-Knoten.
- Bänder aller **77 Requisiten-/Wahrzeichen-Modelle** des Manifests bei „Details“ Niedrig/Mittel/Hoch
  (`probe/bands_all.gd`, 231 Fälle): die Rasteranteile der Darstellungen ergeben an jeder Entfernung 0–4000 m genau 1
  (kein Loch, nichts doppelt), die letzte Darstellung reicht bis „endlos“. Mittel: Stadthäuser lod0 31–39 m,
  Fachwerk/Paris 26–34 m, übrige Gebäude, Büsche, Kirche 53–67 m, Bäume 53–67 / 176–224 m, einstufige Modelle immer.
- `ground_sink`: 3355 Felsen/Klippen im Netz, tiefste Absenkung 0,33 m = höchstens 10 % ihrer Höhe – nichts
  verschwindet im Boden.
- Anbauten (`attach`): kein ausgeliefertes Modell nutzt sie (0 im ganzen Netz).

### 3.3 Wachen die neuen Tests über ihre Regeln? (Mutationen, gemessen)

In einer Kopie des Endstands (`m1/QA-R7c/mut`, `git archive bd1803b`) je Regel eine Zeile gebrochen, dann
`tests/run_tests.gd -- --filter=test_props` (Unit) bzw. `tools/run_render_checks.sh modern <datei>` (Render), danach die
Datei zurückgesetzt (`sh/mutate.py`, Logs `mutlogs/`). Ohne Mutation: `test_props` 18/18 grün.

| Nr. | Regel (Leitentscheid) | Mutation (eine Zeile) | Ergebnis |
|---|---|---|---|
| U1 | Bänder der Nachbarstufen schließen aneinander (1) | lod1 blendet ab `d0` statt `d0 − w0` ein | **gefangen** – `test_lod_bands_per_model`, `test_chunk_lod_shows_one_representation` |
| U2 | Stück schaltet Stufenknoten ohne Instanz im Band ab (1, Leistung) | `n3.visible = true` | **gefangen** – `test_chunk_lod_shows_one_representation` |
| U6 | Anbauten links gespiegelt (6) | `ox := off.x` | **gefangen** – `test_model_attachments` |
| U11 | lod0-Ersatz je Tag (`tag:city`, 1) | Tag-Ersatz gibt 0 | **gefangen** – `test_lod_bands_per_model` |
| U3 | Phase je Instanz (7) | `instance_phase()` gibt immer 0 | **nicht gefangen** (18/18 grün) – alle Rotoren und Kronen schwingen gleichphasig |
| U8 | Wiegen der Bäume ohne Sprung beim Verschieben des Ursprungs (7) | `leaves.gdshader`: Phase wieder aus der Weltlage | **nicht gefangen** – der Sprung bei jedem 2-km-Verschieben wäre zurück |
| U4 | `ground_sink` (7, A-16) | Absenkung abgeschaltet | **nicht gefangen** (der Test prüft nur „≤ Boden am Anker“) |
| U5 | `ground_align` (7, A-16) | Neigung abgeschaltet | **nicht gefangen** |
| U7 | Fernlicht-Wert aus der Konfiguration erreicht das Material (2) | `far_sun` immer 1,0 | **nicht gefangen** |
| U10 | Angebaute Bäume fallen im Kurvenkorridor weg wie jeder Baum (6, F7) | `attached` überspringt `drop_reason()` | **nicht gefangen** |
| R5 | Alphatest aus gröberer Mip (3) | `texture(albedo_tex, UV)` ohne `cutout_bias` | **nicht gefangen** (`test_props`) |
| R6 | Fernbild nachts ohne Relief (5) | `relief_night` wirkungslos | **nicht gefangen** (`test_props`) |
| R1–R4 | Raster, Schattendurchgang, Fernlicht-Gesetz, Fensterdeckung | siehe 3.4 (Render-Prüfungen) | |

Urteil (mit 3.4: 6 von 17 Mutationen gefangen): Die Mechanik der Bänder (Leitentscheid 1) ist gut bewacht, die Anbau-Spiegelung auch. **Fernlicht (2),
Flimmern (3), Relief (5), Phase/Tags (7) und die Korridorregel der Anbauten (6) haben keine Wache, die bricht**, wenn man
sie abschaltet (Befund QR7c-02).

### 3.4 Render-Mutationen (gemessen, `tools/run_render_checks.sh modern <datei>` in der Kopie)

| Nr. | Regel | Mutation | Ergebnis |
|---|---|---|---|
| R1 | Raster im Band (1) | `ce_lod_discard` gibt nie „verwerfen“ zurück (beide Stufen voll) | **gefangen** – `check_lod_band` „lod_ueberblenden“ FEHLER: größter Schritt 6,1 % gegen hart 7,1 % |
| R2 | genau eine Stufe wirft Schatten (1) | Schattendurchgang nimmt das Raster des Hauptdurchgangs (`shadow > 5.0`) | **nicht gefangen** – `check_lod_band` OK |
| R2b | dto., der ursprüngliche Fehler des Pakets | im Schattendurchgang entscheidet die Bandmitte | **gefangen** – `check_lod_band` FEHLER: 9,3 % gegen hart 7,1 % (der Fehler, den R7c gemeldet hat) |
| R3 | Fernlicht (2) | `ce_far_attenuation` gibt `att` zurück | **nicht gefangen** – `test_props`, `check_lod_band`, `check_props_render` grün |
| R4 | Fenster in der Dämmerung (4) | `cover_k = 0.0` | **nicht gefangen** – `test_props`, `check_props_render` grün |

### 3.5 Arcade-Identität (gemessen, einmal am Ende)

`tools/golden.sh check` auf `bd1803b`: **`GOLDEN arcade: 20 von 20 identisch` (174 s), `GOLDEN arcade-ui: 17 von 17
identisch` (204 s)**, Exit 0 (`gates/golden_check.log`).

## 4. Code-Durchsicht (gelesen; Belege mit Datei und Zeile des Stands `bd1803b`)

Geprüft und in Ordnung (gelesen, wo nötig nachgerechnet):

- `lod_bands()` (props.gd 226–253): Nachbarbänder schließen exakt aneinander (lod0 aus = lod1 ein, lod1 aus = Fernbild ein),
  eine Darstellung für mehrere Stufen bekommt die Vereinigung; `d1 = max(d1, d0 + w0 + w1 + 2)` verhindert Überlappung.
  Nachgerechnet für alle 77 Modelle × 3 Detailstufen (3.2).
- Raster (`inc/lod_band.gdshaderinc` `ce_lod_discard`): die beiden Stufen zeigen t ∈ [0, fout) bzw. [1 − fin, 1) mit
  fin = 1 − fout bei gleichem Band – komplementär, kein Pixel doppelt, keins fehlt. Instanzen außerhalb des Bandes fallen
  im Vertex-Shader auf einen Punkt.
- Schattendurchgang: genau eine Stufe wirft (die feinere bis `in1`/`out1`); Modelle mit eigenem Schattennetz
  (`caster`) werfen über einen Knoten ohne Band (`rep_materials()` lässt Schattenteile aus) – keine Lücke in den
  Schatten naher Häuser.
- Gemeinsame Materialien: die Materialien je Netz teilt `props.gd` nur mit Bausteinen, die dieselben Netze zeichnen –
  `city.gd` zeichnet die Straßenlaterne (einstufig → Band „immer“), `bridge.gd` zeichnet die Brücken-Sets, die
  `props.gd` dann auslässt (`item_set()` bei `skip_bridge`) – kein fremdes Band auf fremden Instanzen.
- Fernlicht: `shadow_far` = (0,85, 1) × Reichweite entspricht `directional_shadow_fade_start = 0.85` von
  `environment_rig.gd`; ohne werfende Klasse (Steam Deck: Schatten „Niedrig“, Gebäude werfen nicht) bleibt `far_sun` 1.
- Phase: Custom-a = 1 + Phase ≤ 1,999 (halbe Gleitkommazahl 1 + 1023/1024), nie 2,0; alle Shader lesen die Tönung
  weiter bei a > 0,5 (`test_model_instances_carry_the_placement_tint` grün).
- Fernbild-Relief: die kleinste Mip der Impostor-Bilder ist ihre Mittelfarbe – die transparenten Texel tragen die
  Mittelfarbe (alle 18 Baumbilder nachgemessen: Abweichung < 0,01), Mipmaps sind an.
- Anbauten: gehen durch `_place()` und damit durch `drop_reason()` (Band, Korridor, Dichte) – nur ohne Wache (3.3).
- `quality_lowered()` setzt Bänder auf Materialien und Knoten neu (Test grün); `apply_quality()` ruft die Sitzung nur
  einmal beim Start (race_session.gd 487) – kein Wechsel mitten im Rennen, der alte Bänder auf Knoten ließe.

Auffällig (Befunde in Abschnitt 6):

- **Verzögertes Einschalten der Stufenknoten** (props.gd 364–366, 1222–1225): `update()` schaut nur alle
  `LOD_STEP_M` = 2 m Fahrt auf die Stücke, und ein Knoten wird ohne Spielraum sichtbar, sobald `span.x <= band.w`.
  Bis zur nächsten Prüfung kann eine nähere Stufe schon im Band sein, ihr Knoten aber noch aus: das gröbere Raster
  blendet bereits aus, das feinere fehlt – bei einem Stadthaus bei „Mittel“ (Band 30,8–39,2 m) bis 2/8,4 = 24 % der
  Pixel als Löcher, für höchstens 2 m Fahrt (gefolgert, nicht im Bild gesehen; der Kasten der Instanz-Ursprünge
  liegt meist näher als das Haus selbst und fängt das bei seitlichem Abstand ab).
- **Anbauten jenseits des Stücks** (props.gd 905–915): der Anbau steht bei `z − off.z × sc`; liegt das hinter der
  letzten Reihe des Stücks, liest `ctx.ground()`/`drop_reason()` die Randreihe (Höhe am Hang falsch). Latent – kein
  Modell nutzt `attach`.
- **Raster bei stehendem Wagen**: das Band hängt am Weg, nicht an der Zeit (Abweichung von A-16). Steht der Wagen (Start,
  Stau, Polizeistopp) mit einem Haus im Band, bleibt das Haus im geordneten Raster zweier Stufen stehen (Abschnitt 5,
  Startbild).

## 5. Bilder – Arcade | Basis | (43a1fcc) | R7c, gleicher Simulationsstand (angesehen; Zahlen gemessen)

Alle Bilder mit dem Rennszenen-Aufruf von `tools/ab_shot.sh` (`--gfx-sync`, Seed 11, Autopilot, Start mit 50 km/h, Wald
120 km/h, Bilder 2 s und 4 s nach dem Start; Arcade mit `--shot-fast`), drei bzw. vier Läufe je Kombination
(`sh/tri.sh`), Hoch 1280×720, **Steam Deck 1280×800** (`--gfx-preset=deck`: Schatten Niedrig – Gebäude werfen nicht,
Details Mittel, MSAA 2×). Alle Läufe Exit 0, 0 Fehlerzeilen (`logs/tri.out`). „% Pixel“ = Anteil der Pixel, die sich
zwischen zwei Modern-Bildern um mehr als 40 Stufen unterscheiden (`sh/picstats.py`, Diff-Bilder `*_diff_NN.jpg`).

Wo R7c selbst wirkt: **Hoch: R7c gleich der Basis (0,05–0,5 % Pixel)**, gegen 43a1fcc 0,16–1,2 %. **Deck: 1,3–2,5 %** –
dort endet lod0 der Stadthäuser bei 35 m (vorher ganze Stücke lod0 bis 60 m Wegabstand ihrer nächsten Reihe). Die
großen Unterschiede gegen die Basis in Paris, Amsterdam, Bern (7–24 %) kommen von den AS5aR2-Modellen der Mischung
(die Basis zeigt dort Sprites), nicht von R7c.

### 5.1 Je Ort (angesehen)

| Ort / Stufe / Stunde | gegen Arcade | gegen Basis 9b02f05 (und 43a1fcc) | Messung |
|---|---|---|---|
| Hamburg km 88,6 Hoch 12 | besser: Backstein mit Tiefe, Gehweg, Laternen, Bäume mit Volumen | gleich (0,2 % Pixel geändert, 43a1fcc→R7c 0,16 %) | Luma Szene 85,9 / Basis 86,5 / Arcade 94,0 |
| Nürnberg km 102,4 Hoch 12 | besser: Fachwerk plastisch, Dachgauben | gleich nah; fernes Bürgerhaus (~100 m) weicher: weiße Fensterrahmen grau (Farb-Mip-Bias) | 0,5 % Pixel |
| Paris km 387,9 Hoch 12 | besser: Haussmann 3D, Kaimauern, Geländer, Wasser | Basis zeigt nur Sprite-Ersatz (ohne AS5a2); gegen 43a1fcc gleich, Haussmann bei ~60 m in lod1 – Balkone flacher, Fenster etwas weicher | Fassade Luma 130,0 (R7c) / 130,1 (43a1fcc) – Fernlicht ändert hier nichts (innerhalb der Schatten) |
| Amsterdam km 357,7 Hoch 12 | besser bis gleich: Grachtenhäuser, Hausboote; neben der Kamera stehen jetzt Häuser (Arcade zeigt dort nichts, 3D) | Basis Sprites (ohne AS5a2) | 24 % / 13 % Pixel (Modelle statt Sprites) |
| Bern km 303 Hoch 12 | besser: Lauben, Blumen, Gehweg | Basis Sprites (ohne AS5a2) | 18–24 % (Modelle) |
| Lyon-Vorort km 286 Hoch 12 | **schlechter**: Arcade zeigt Gartenmauern beidseits, Baum und Zypresse links; Modern freies Feld | gleich wie Basis (schon dort, nicht R7c: Zäune/Mauern des Stadtbausteins, Korridor) | 0,7 % / 3,3 % |
| Hamburg km 88,6 Deck 12 | besser (Tiefe, Gehweg) | **schlechter als Basis/43a1fcc in einem Punkt**: Speicher bei 35–60 m in lod1 – grüne Ladetüren flache Flächen statt Kassetten, Fenster flacher (wie das Sprite) | 2,5 % Pixel; tmp/hd.png |
| Nürnberg km 102,9 Deck 12 | besser | gleich (1,3–1,8 %) | |
| Wald km 48,7–49,6 Hoch/Deck 12 | einzelne Bäume besser; **weniger Bäume**: Arcade hat rechts eine Fichtenreihe / eine Baumgruppe an der Kurveninnenseite, Modern freies Feld | gleich wie Basis (0,1–0,2 %) – nicht R7c (Korridor/Bestückung, R7a) | |
| Paris km 388 Hoch 22 | **schlechter**: Arcade (und Basis mit Sprite) zeigen viele helle Fenster und helle Ladenzeilen; mit den Haussmann-Modellen bleiben Obergeschosse dunkel, Läden matter | gegen 43a1fcc gleich (0,24–0,26 %) – Modell (F-04, Nachtatlas), nicht R7c; gegen Basis dunkler (Luma 62,8 → 51,5, Arcade 59,2) | |
| Hamburg km 88,6 Hoch 22 | gemischt: Straße, Laternen, Gehweg besser; rechts weniger leuchtende Fenster als Arcade | gleich (0,05–0,08 %) | Luma 43,7 / Arcade 42,8 |
| Nürnberg km 102,4 Hoch 22 | gemischt: Fachwerk links bleibt dunkel (Arcade: mehrere Fenster hell), Straße und Bürgerhäuser besser | gleich (0,1–0,25 %) | |
| Hamburg km 88,6 Hoch 19:30 | gleich bis etwas weniger: warme Fensterpixel im Ausschnitt 4,7 % gegen Arcade 6,4 % | gleich (Basis 4,6 %; 0,3–0,5 % Pixel) | tmp/dz.png |
| Paris km 387,9 Deck 12 | besser: Haussmann 3D, Brückengeländer, Wasser | Basis Sprite; R7c-Modell heller und sauberer | 7,5–13 % (Modelle) |
| Paris km 388,4 Hoch 19:30 | gleich bis besser: Ladenbögen warm beleuchtet wie Arcade, Bäume plastisch | Basis Sprite | 7–18 % (Modelle) |
| Amsterdam km 357,7 Hoch 22 | gleich bis besser: Giebel, Hausboote beleuchtet, nahe Häuser mit hellen Fenstern | Basis Sprites | 2–10 % (Modelle) |
| Bern km 303 Hoch 22 | gemischt: Lauben beleuchtet, aber rechts deutlich weniger helle Fenster als Arcade/Basis (Nachtatlas der Modelle, F-04) | Basis Sprites | 6–12 % (Modelle) |
| Hamburg km 88,6 Deck 22 | gemischt wie Hoch 22 | gleich (0,9–1,5 %) | |
| Paris km 388 Deck 22 | schlechter in den Obergeschossen (F-04) wie Hoch 22 | gegen Basis dunkler (Luma 62,0 → 51,0; Arcade 57,4) – Modelle, nicht R7c | |
| Countdown Nürnberg – Fulda km 0, Deck und Hoch | gleich bis besser (Starttor, Bäume plastisch) | **eine Eiche im Band steht gerastert/körnig** (Deck), Basis glatt (QR7c-06) | 0,25–0,3 % Pixel |

### 5.2 Fernlicht unabhängig nachgemessen (Leitentscheid 2; gemessen)

Mit R7cs/KRITIKs Prüfszene (`k6_scene --mode=lodcol`, ungetrackt in der Kopie `m1/QA-R7c/mut/tools/kritik/`, `sh/k6.sh`),
lod1 (die Stufe, die das Spiel jenseits von 35/70 m zeigt), 12 Uhr, Modell 20 m neben der Straße, mittlere Luma des
Modells; „aus“ = ohne `far_sun` (Stand vor R7c), „an“ = ausgelieferter Wert. Abweichung gegen 60 m:

| Modell (far_sun) | Stufe | an: 100 / 140 / 200 / 250 m | aus: 200 / 250 m |
|---|---|---|---|
| Haussmann (0,72) | Hoch | +2,2 / +2,4 / +2,8 / +3,3 % | +9,8 / +10,3 % |
| Haussmann (0,72) | Mittel | +0,5 / +3,1 / +3,5 / +3,5 % | +10,6 / +10,6 % |
| Gründerzeit (0,78) | Hoch | −0,5 / −0,9 / −3,0 / −3,0 % | +2,1 / +2,1 % |
| Gründerzeit (0,78) | Mittel | −1,3 / −2,1 / −2,5 / −2,6 % | +2,6 / +2,5 % |
| Kontor (0,78) | Hoch | +3,4 / +4,2 / +1,7 / +1,9 % | +8,8 / +9,0 % |
| Kontor (0,78) | Mittel | +1,1 / +2,1 / +2,5 / +2,3 % | +9,2 / +9,4 % |

Alle in ±5 % (Leitentscheid erfüllt, R7cs Tabelle bestätigt). Die Gründerzeit wird mit dem Klassenwert 0,78 fern etwas
dunkler (−3 %) als nah, ohne Fernlicht wäre sie nur +2 % heller – kein Fehler, aber der Klassenwert passt nicht jedem
Haus. Hinweis: die Szene setzt `far_sun` selbst auf das Material; dass das Spiel den Wert aus der Konfiguration
setzt, ist nur gelesen (`_ensure_bands`), kein Test prüft es (QR7c-02, U7). Im Spielbild: Paris Hoch 12 Uhr, Fassade
des Haussmann-Hauses (innerhalb der Schattenreichweite) Luma 130,0 (R7c) gegen 130,1 (43a1fcc) – in der Nähe unverändert.

## 6. Leistung (gemessen, llvmpipe; Steam Deck und echte GPU gefolgert)

`tests/race/run_stage.gd` mit Autopilot, Seed 11, Limousine, 12 Uhr, `--timescale=20` (496 Bilder auf Kiel – Hamburg),
Xvfb 1280×800 für „Steam Deck“, 1280×720 für „Hoch“, gemeinsamer warmer Mesa-Cache (je Baum ein Aufwärmlauf verworfen),
abwechselnd R7c / 43a1fcc / Basis (`sh/perf.sh`, Logs `perf/`, Tabelle `sh/perfsum.py`). Neben mir liefen ein bis zwei
andere Agenten (Lärm in einzelnen Maxima, z. B. der unveränderte `bridge`-Haken 0,1 → 3,5 ms im selben Lauf).

| Lauf | Bildzeit Median / p95 | `render_ms` Mittel / Max | Stück bauen Max | **Einhängen Max** | **Haken `props` Mittel / Max** | Zeichenaufrufe* | Primitive* / Schatten |
|---|---|---|---|---|---|---|---|
| KH Deck R7c 1 | 801 / 995 ms | 3,16 / 9,5 | 25,2 | 2,80 | **0,27 / 4,44** | 132 | 136 993 / 8 364 |
| KH Deck R7c 2 | 748 / 871 ms | 2,92 / 13,1 | 23,7 | 2,32 | **0,25 / 3,82** | 132 | 136 993 / 8 364 |
| KH Deck 43a1fcc 1 | 775 / 968 ms | 3,04 / 8,3 | 112,3 | 1,80 | 0,10 / 0,59 | 129 | 158 344 / 8 364 |
| KH Deck 43a1fcc 2 | 780 / 939 ms | 2,79 / 11,4 | 23,0 | 1,88 | 0,10 / 0,47 | 129 | 158 344 / 8 364 |
| KH Deck Basis | 751 / 902 ms | 2,82 / 16,4 | 27,9 | 1,72 | 0,10 / 1,20 | 129 | 158 344 / 8 364 |
| WN Deck R7c | 804 / 993 ms | 3,56 / 13,6 | 13,4 | 2,40 | 0,32 / 1,82 | 151 | 174 509 / 8 448 |
| WN Deck 43a1fcc | 803 / 1023 ms | 3,34 / 20,1 | 25,3 | 3,52 | 0,10 / 0,75 | 144 | 192 079 / 8 448 |
| KH Hoch R7c | 971 / 1144 ms | 3,15 / 12,4 | 21,5 | 3,32 | 0,27 / 1,48 | **202** | 189 301 / 128 445 |
| KH Hoch 43a1fcc | 1089 / 1395 ms | 3,04 / 11,0 | 36,2 | 2,06 | 0,11 / 0,70 | 175 | 214 748 / 144 412 |

\* letztes Bild (Ziel in Hamburg). Alle Läufe Exit 0, 0 Fehlerzeilen; `ERGEBNIS` aller sieben KH-Läufe und beider
WN-Läufe identisch (Regel 3).

Urteil (gemessen): Bildzeit und `render_ms` gleich im Rahmen des Lärms; R7c spart 10–13 % Primitive (Hoch auch 11 % im
Schatten), kostet aber **+3 (Deck) bis +27 (Hoch, +15 %) Zeichenaufrufe** – im Band zeichnet ein Set beide Stufen, und
jedes Stück, dessen Instanzen ein Band überspannen, schaltet beide Knoten an – weit unter dem Budget (Deck 650, Hoch
1500). Der **Haken von `props.gd` kostet im Mittel 2,5–3× so viel (0,25–0,32 statt 0,10 ms) und hat auf Kiel – Hamburg
bei „Steam Deck“ in beiden Läufen Spitzen von 3,8–4,4 ms** (43a1fcc 0,5–0,6 ms, Basis 1,2 ms); Einhängen höchstens
2,3–3,3 ms (Budget Deck 3,0 / Hoch 4,0 ms, vorher 1,7–2,1 ms auf KH). Ursache (gelesen): `update()` rechnet alle 2 m für
**jedes** Stück den Kasten und die 8 Ecken; da der Schlüssel `span_key` auf 1 m gerundet ist, ändert er sich bei jedem
Schritt, und dann läuft die Schleife über **alle** Kindknoten aller Stücke (`_apply_lod`, props.gd 1206–1227). Bei
`--timescale=20` fällt das fast in jedes Bild; im echten Spiel bei 130 km/h etwa jedes dritte Bild (gefolgert).

## 7. Befunde (blocker = nicht in Testbuild 2; hoch = fällt sofort auf; mittel = merklich; niedrig = Feinschliff)

Kein Blocker, kein hoher Befund. Arcade-Identität, Sicht (F1–F3, F7), Tests und Render-Prüfungen sind grün; R7c stellt
im ganzen Netz keine Requisite um und nimmt keine weg.

### QR7c-01 (mittel) – „Steam Deck“/„Mittel“: Stadthäuser ab 35 m in lod1, Details flacher als vorher

- **Wo:** `config/game_config.json` `graphics.modern.props.lod0_m` = `{"tag:city": 35, Fachwerk/Paris: 30}`; wirkt über
  `props.gd lod0_override()` auf **alle 28 Modelle mit Tag `city`** (auch Speicher, Kontor, Gründerzeit, Bauten von
  AS4 wie `building_block_a/b`, `building_tall`).
- **Was:** Leitentscheid 1 nannte „etwa 35 m für Fachwerkhäuser gegen das Balkenflimmern“; R7c kürzt lod0 aller
  Stadthäuser. Bei „Steam Deck“ (Details Mittel) zeigt Hamburg bei 35–60 m die Stufe 1: **die grünen Ladetüren des
  Speichers sind flache grüne Flächen statt Kassetten, die Fenster flacher** – gleich dem Arcade-Sprite, aber schlechter
  als Basis und 43a1fcc, die dort lod0 zeigten (ganze Stücke lod0 bis 60 m Wegabstand).
- **Beleg (gemessen + angesehen):** `deliver/QA-R7c/raw/hh_deck_h12_tri_00.jpg`, Ausschnitt
  `deliver/QA-R7c/hamburg_deck_speicher_43a1fcc_r7c.png` (links 43a1fcc, rechts R7c); 2,5 % der Pixel gegen Basis und
  43a1fcc (bei Hoch nur 0,2 %, dort endet lod0 bei 70 m). Studio-Vergleich lod0 | lod1 | Sprite bei 32/40/50 m:
  `deliver/QA-R7c/lod0_lod1_sprite_mittel_32-50m.png` (Speicher-Zeilen: lod1 = Sprite-Niveau; Kontor, Fachwerk,
  Haussmann, Block A: lod1 fast gleich lod0).
- **Nachstellen:** `sh/tri.sh … hh_deck_h12 deck --stage=kiel_hamburg --from=kiel --start-km=88.2 --hour=12 …
  --start-speed=50 --shot-times=2,4`, rechtes Gebäude vergleichen.
- **Fix:** `lod0_m` nur für die Modelle, deren lod0 nachweislich über 2 × Sprite flimmert (Fachwerkzeile, Fachwerkzeile B,
  Haussmann, Pariser Eckhaus: 30 m); `tag:city` streichen oder auf ≥ 50 m setzen und Speicher/Kontor einzeln messen –
  oder im Asset-Paket die Kassetten der Türen und Fensterlaibungen in den Atlas von lod1 backen (lod1 des Speichers hat
  1283 statt 8950 Dreiecke und flache Türen).

### QR7c-02 (mittel) – Fernlicht, Flimmern, Fernbild-Relief, Phase, Tags und Anbau-Korridor ohne Wache

- **Wo:** `tests/unit/race3d/test_props.gd`, `tests/race3d/render/check_lod_band.gd`.
- **Was:** 11 von 17 Mutationen bleiben grün (Abschnitt 3.3/3.4): Fernlicht im Shader aus (R3) oder `far_sun` nicht aus
  der Konfiguration (U7), Alphatest ohne `cutout_bias` (R5), Fensterdeckung aus (R4), Relief nachts nicht
  zurückgenommen (R6), Phase konstant (U3), Wiegen wieder aus der Weltlage – der Sprung beim 2-km-Verschieben wäre
  zurück (U8), `ground_sink`/`ground_align` wirkungslos (U4/U5), angebaute Bäume im Kurvenkorridor nicht weggelassen
  (U10, F7-relevant, sobald ein Modell `attach` nutzt), Schattendurchgang mit Raster (R2).
- **Beleg (gemessen):** `m1/QA-R7c/mutlogs/mutate.out`, je Mutation `<id>_test_props.log` / `<id>_check_*.log`.
- **Nachstellen:** `python3 m1/QA-R7c/sh/mutate.py <id>` (Kopie `m1/QA-R7c/mut`).
- **Fix:** (a) `test_props`: nach `commit()` eines werfenden Gebäudes `far_sun`/`shadow_far` des Materials = Wert der
  Konfiguration (Klasse und Modell); (b) Shader-Texttests ohne Kommentare (wie `STATIC_MARKERS`): `leaves` liest die
  Phase aus `INSTANCE_CUSTOM.a`, `baked_cutout` testet mit `cutout_bias`, `billboard` nimmt `relief_night × ce_night`,
  `baked` setzt `cover_k` in `ALBEDO`; (c) zwei Windräder verschiedener Items haben verschiedene Phasen; (d)
  `sink_height` an einem Hang liefert den tiefsten Punkt (konkreter Wert), `align_basis` neigt; (e) Anbau-Test mit einer
  Kurve: die angebaute Eiche im Korridor fällt weg (`dropped.corridor`); (f) Render-Prüfung „Fernlicht“: Haus bei 60 /
  140 / 250 m, Luma in ±5 % (wie `k6_scene --mode=lodcol`), mit abgeschaltetem `far_sun` rot.

### QR7c-03 (niedrig) – Haken von `props.gd`: 2,5–3× teurer, Spitzen 3,8–4,4 ms bei „Steam Deck“

- **Wo:** `scripts/race3d/builders/props.gd` `update()` 359–371, `_apply_lod()` 1207–1227, `_span()` 1231–.
- **Was:** alle 2 m Fahrt rechnet jedes Stück Kasten und 8 Ecken; `span_key` (auf 1 m gerundet) ändert sich bei jedem
  Schritt, also läuft die Schleife über alle Kindknoten aller Stücke, auch wenn kein Band gekreuzt wird.
- **Beleg (gemessen):** Abschnitt 6 – Haken Mittel 0,25–0,32 ms (vorher 0,10), Max 3,82 / 4,44 ms in zwei KH-Deck-Läufen
  (43a1fcc 0,47 / 0,59, Basis 1,20); Einhängen 2,3–2,8 ms (vorher 1,7–1,9; Budget Deck 3,0). Lärm der geteilten VM möglich,
  aber in beiden Läufen.
- **Fix:** je Stück die nächste Entfernung merken, an der ein Knoten sein Band betritt oder verlässt (min über die
  Kinder von |span − Bandkante|) und erst dann die Kinder durchgehen; Weltkasten nur beim Verschieben des Ursprungs neu;
  höchstens N Stücke je Bild (Rundlauf).

### QR7c-04 (niedrig) – Ferne Fassaden weicher: Farb-Mip-Bias macht weiße Fensterrahmen grau

- **Wo:** `props.gd PROP_LOOK` `albedo_bias` 1,25 (ab 30 m, voll bei 120 m), `baked.gdshader` 95.
- **Was:** im Standbild ist das ferne Bürgerhaus in Nürnberg (~100 m) weicher als in der Basis und in Arcade: die weißen
  Fensterrahmen werden grau, die Fassade wirkt verwaschen; der Gewinn (weniger Flimmern in Bewegung) ist im Standbild
  nicht zu sehen.
- **Beleg (angesehen):** `deliver/QA-R7c/raw/nu_high_h12_tri_00.jpg`, Ausschnitt 3× `m1/QA-R7c/tmp/nz.png`
  (Arcade | Basis | R7c); Diff-Bild `nu_high_h12_diff_00.jpg` (nur dieses Haus und Rahmen geändert).
- **Fix:** `albedo_bias` 0,75 oder erst ab 60 m; den Mip-Bias nur auf die Kanäle mit dünnen Linien (Fachwerk) setzen,
  nicht auf alle Stadthäuser.

### QR7c-05 (niedrig) – Stufenknoten werden bis 2 m zu spät eingeschaltet (Rasterlöcher möglich)

- **Wo:** `props.gd` 364 (`LOD_STEP_M` 2 m) und 1225 (`span.x <= b.w` ohne Spielraum).
- **Was:** kommt eine Instanz zwischen zwei Prüfungen in das Band einer feineren Stufe, ist deren Knoten noch aus,
  während die gröbere schon ausblendet: bis 2 m Fahrt fehlen bis 2/(2 w) der Pixel (Stadthaus „Mittel“: w = 4,2 m → 24 %).
  Gefolgert, im Bild nicht gesehen – der Kasten der Instanz-Ursprünge liegt meist näher als das Haus und fängt es ab.
- **Fix:** `n3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M` (eine Zeile).

### QR7c-06 (mittel) – Raster steht still, wenn der Wagen steht (Countdown, Stau, Polizei)

- **Wo:** `inc/lod_band.gdshaderinc` `ce_lod_discard()` – das Band hängt am Weg, nicht an der Zeit (Abweichung von A-16
  „0,3–0,5 s wie `xfade`“).
- **Was:** steht ein Baum oder Haus beim Stand im Band (Bäume „Mittel/Deck“ 53–67 m, Stadthäuser 31–39 m, Hoch
  doppelt so weit), bleibt es im geordneten Raster zweier Stufen stehen: die Krone wirkt gesprenkelt/körnig. Beim
  Countdown jeder Etappe sichtbar, sobald dort Bäume stehen.
- **Beleg (gemessen + angesehen):** Start Nürnberg – Fulda km 0, Countdown 1,5 s, Deck:
  `deliver/QA-R7c/raw/start_nu_deck_h12_tri_00.jpg`, Ausschnitt 2× `deliver/QA-R7c/start_countdown_deck_raster_basis_r7c.png`
  (links Basis glatt, rechts R7c: Eiche unten rechts gerastert); 0,3 % Pixel gegen die Basis.
- **Nachstellen:** `SCREEN=1280x800 sh/tri.sh <out> deck --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12
  --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5`.
- **Fix:** ein globales `ce_lod_still` (0..1, vom Renderer aus der Kamerageschwindigkeit, z. B. < 2 m/s → 1) im Shader:
  bei stehender Kamera die Bandbreite auf 0 ziehen (harte Entscheidung in der Bandmitte, kein Raster) – oder die Leitung
  nimmt das Raster im Stand hin (Vertragsfrage 2).

### QR7c-07 (niedrig, Zusammenbau) – Konflikt mit FIX-RINT in `test_props.gd`

- **Wo:** `tests/unit/race3d/test_props.gd` (`git merge-tree bd1803b origin/wip/v080-fix-rint` → Konflikt), beide
  ändern `test_model_instances_carry_the_placement_tint` / `test_chunk_lod_shows_one_representation`.
- **Fix (Leitung):** beide Fassungen behalten: FIX-RINTs `_code_only()`-Prüfung der Multiplikation und R7cs Phase in
  Custom-a (`assert_between(buf[19], 1.0, 1.999)`); danach `tools/run_tests.sh test_props`.

### QR7c-08 (niedrig, latent) – Anbauten jenseits des Stücks lesen den Boden der Randreihe

- **Wo:** `props.gd attach_item()` 907–919, `_place()`.
- **Was:** ein Anbau bei `z − off.z × sc` hinter der letzten Reihe des Stücks bekommt `ctx.ground()`/`drop_reason()` der
  Randreihe (Höhe am Hang falsch, Korridor der falschen Reihe); mehr als 8 Anbauten je Modell kollidieren in der
  Item-Nummer (`item * 8 + k`). Kein ausgeliefertes Modell nutzt `attach`.
- **Fix:** Anbauten mit `z` außerhalb `[seg_a, seg_b)` dem Nachbarstück überlassen (oder dort nicht stellen);
  `k < 8` prüfen.

## 8. Abweichungen des Pakets und Vertragsfragen (Urteil der Prüfung)

| Abweichung (laut R7c) | nachgeprüft | Urteil |
|---|---|---|
| lod0-Entfernungen in `graphics.modern.props.lod0_m` statt `max_dist_m` in `model.json` (A-22) | ja: Mechanik liest `max_dist_m` (alle 60), Ersatz greift je Modell/Tag | vertretbar (model.json gehört den Asset-Paketen); **aber der Tag-Ersatz `tag:city` geht über den Leitentscheid hinaus** (QR7c-01) |
| Stufe nach geradem Abstand je Instanz statt Wegabstand je Stück | ja (Shader und `_span()` gleich) | richtig und besser; Folge: im Mittel weniger lod0 als vorher (weniger Primitive, aber QR7c-01) |
| Band über den Weg (±12 %, 4–25 m) statt Zeitblende 0,3–0,5 s (A-16) | ja | Vertragsfrage: im Stand bleibt das Raster stehen (QR7c-06) – Leitung entscheidet |
| `vpbr_static` per Texteinschub (`STATIC_INJECT`) | ja, Test bewacht die Marker | Notlösung; zerbricht still, falls jemand `vec3 lc = LIGHT_COLOR * ATTENUATION * k;` umformuliert – der Test fängt das (Marker fehlen) |
| `environment_rig.gd` nicht benutzt; Fernlicht nur auf Modellen von `props.gd` | ja | in Ordnung (Ausnahme war freiwillig); Tankstelle/Grenze/Brücke ohne Fernlicht – notiert |
| Modern-Goldens vom Paket erneuert (Brief gegen A-18) | ja, `modern_slice.*` geändert | Brief hat Vorrang; die Montage erneuert sie ohnehin |
| Flimmern ≤ 2× Sprite nicht überall (Fachwerk lod1 2,0–2,25×, Südhaus 3× bei 40 m) | nicht nachgemessen (Werkzeug `my_scene --mode=sparkcam` des Pakets) | offen wie gemeldet |
| Arcade-Goldens nur auf `965b8a9` | auf `bd1803b` neu: Abschnitt 3.5 | erledigt durch diese Prüfung |
| Paris-Clip vor der Korrektur des Schattendurchgangs | Clip-Bilder Kachel für Kachel ausgewertet (`sh/tilepeaks.py`): keine Stufen-Spitze, Spitzen am Bildrand = Laternen/Häuser in Bewegung; Spitzen-Verteilung wie Arcade (p99 60,6 / 57,8 %) | kein Stufensprung zu sehen; ein Clip auf dem Endstand fehlt weiter (QA-mid) |

Vertragsfragen (contract_issues):

1. **A-22 „max_dist_m in model.json“ gegen Besitz:** `model.json` gehört den Asset-Paketen, der Exporter schreibt überall 60.
   Vorschlag: der Vertrag nennt `graphics.modern.props.lod0_m` als gültigen Übergang **je Modell** (nicht je Tag), bis
   `cities3d.py` die Werte exportiert.
2. **A-16 „Zeitblende 0,3–0,5 s“ gegen Wegband:** eine Zeitblende braucht Zustand je Instanz (Instanz-Uniforms sind nach
   A-19 tabu). Die Leitung sollte das Wegband annehmen und festlegen, ob ein stehendes Raster (Start, Stau) hinnehmbar ist.
3. **Leitentscheid 1 „etwa 35 m für Fachwerk“ gegen Leitentscheid 3 „≤ 2× Sprite“:** R7c hat 3 über 1 gestellt und alle
   Stadthäuser gekürzt; das kostet bei „Mittel/Deck“ sichtbare Details (QR7c-01). Die Leitung sollte festlegen, welches
   Ziel bei Stadthäusern ohne Balkenflimmern gilt.
4. **A-18 Modern-Goldens:** Brief und Vertrag widersprechen sich (Paket erneuert / nur die Montage) – einheitlich regeln.

## 9. Geprüft und in Ordnung

- Keine eingefrorene Arcade-Datei geändert; R7c bleibt in seinen Dateien (Abschnitt 3.1); `environment_rig.gd` unberührt.
- Gates: Skripte, 808 Tests, 29/29 Render-Prüfungen (darunter `check_start_km0`, `check_terrain_cover` mit K1,
  `check_light_base`, `test_far_ground_water`/`test_props` in den Tests, `check_instance_budget*` ≤ 216/230), Sicht
  F1–F3/F7/Modell und Wege mit `--full`, Arcade-Goldens (3.5).
- Datenscan aller 128 Richtungen + DEV: R7c zeichnet genau dieselben 195 741 Requisiten wie 43a1fcc; 602 113
  Instanzen mit gültiger Phase; Bänder aller 77 Modelle × 3 Detailstufen lückenlos.
- Stufenwechsel ohne Sprung: `check_lod_band` (0,6 % gegen 7,1 %; Eiche 1,1 % gegen 36,6 %); R7cs Clips Nürnberg und
  Paris Kachel für Kachel ohne Stufen-Spitze (Spitzen-Verteilung wie Arcade).
- Schattendurchgang: genau eine Stufe wirft; Modelle mit eigenem Schattennetz werfen ohne Band.
- Fernlicht-Mechanik gelesen: Einblenden mit `directional_shadow_fade_start` 0,85 der Engine; in der Nähe unverändert
  (Hoch-Bilder Hamburg/Nürnberg/Wald 0,05–0,5 % Pixel gegen die Basis, Luma ±0,6).
- `ground_sink` versenkt höchstens 0,33 m (10 % der Höhe); `face_road` dreht Klippen höchstens ±20° (Test grün).
- Instanzbudget A-19: keine neue Instanz-Uniform; Bänder/Fernlicht als Material-Uniforms, Phase in MultiMesh-Custom.
- Leistung: Bildzeit und `render_ms` gleich, 10–13 % weniger Primitive, Zeichenaufrufe weit im Budget; `ERGEBNIS`
  identisch (Regel 3).
- lod1 bei 32–50 m für Kontor, Fachwerk, Haussmann, Block A im Studio bei 1× fast gleich lod0 (Speicher nicht – QR7c-01).
- Bei Tag ist Modern in Hamburg, Nürnberg, Paris, Amsterdam, Bern klar besser als Arcade; R7c verschlechtert dort bei
  „Hoch“ nichts gegen die Basis.
- Zusammenbau-Probe: kein Konflikt mit R7a, R7b, FIX-R7b, FIX-R7a (`4a43944`); nur `test_props.gd` mit FIX-RINT.

## 10. Für die nächsten Pakete / die Leitung

1. **QR7c-01:** `graphics.modern.props.lod0_m` – `tag:city` streichen (oder ≥ 50 m); 30 m nur für Fachwerkzeile,
   Fachwerkzeile B, Haussmann, Pariser Eckhaus. Danach Hamburg Deck 12 Uhr gegen 43a1fcc ansehen (Speicher-Türen).
2. **QR7c-06:** Raster bei stehender Kamera abschalten (`ce_lod_still`) oder Entscheidung der Leitung; Startbild
   Nürnberg – Fulda km 0 als Prüfbild.
3. **QR7c-02:** sechs Tests/Prüfungen nachrüsten (Fernlicht-Material und -Render, Shader-Marker leaves/cutout/relief/
   cover, Phasenvielfalt, sink/align mit Werten, Anbau im Korridor).
4. **QR7c-03:** `_apply_lod` nur bei Bandkreuzung über die Kinder laufen lassen; Haken danach auf Deck ≤ 1 ms Spitze.
5. **Zusammenbau:** Konflikt `tests/unit/race3d/test_props.gd` mit FIX-RINT – beide Fassungen behalten; FIX-R7a
   (`4a43944`) mischt konfliktfrei; nach dem Zusammenbau `tools/run_tests.sh test_props` und
   `tools/run_render_checks.sh modern check_lod_band`.
6. **Asset-Paket:** lod1 des Speichers (und anderer Häuser mit 3D-Kassetten) sollte die Türkassetten im Atlas tragen;
   Nachtfenster F-04 (Haussmann, Kontor, Fachwerk, Berner Lauben) bleiben das größte Nacht-Defizit gegen Arcade.
7. **R7a/R6 (nicht R7c):** Lyon-Vorort km 286 ohne Gartenmauern und Bäume, Wald Dortmund – Frankfurt km 48–50 ohne die
   rechte Fichtenreihe/Baumgruppe – in Basis und R7c gleich; mit FIX-R7a erneut ansehen.
8. **QA-mid:** einen Clip „Paris-Einfahrt Mittel“ auf dem Endstand aufnehmen (R7cs Clip ist vor dem
   Schattendurchgang-Fix entstanden; Kachel-Auswertung ohne Stufen-Spitze).
9. `vpbr.gdshader`-Besitzer: `STATIC_INJECT` (Band, Fernlicht, Rotorphase) in den Shader übernehmen.
10. Fernlicht auch für Tankstelle/Grenze/Brücke (`shadow_far`/`far_sun` auf ihre `baked`-Materialien), falls ihre
    Fassaden fern heller werden – nicht gemessen.

## 11. Lieferung (`deliver/QA-R7c/`)

| Datei | Inhalt |
|---|---|
| `raw/<ort>_<stufe>_h<stunde>_tri_NN.jpg` | Arcade \| Basis 9b02f05 \| [43a1fcc] \| R7c – Orte `hh` (Hamburg km 88,2), `nu` (Nürnberg 102,0), `pa` (Paris 387,5), `am` (Amsterdam 357,3), `be` (Bern 302,3), `ly_out` (Lyon-Vorort 285,6), `wald` (Dortmund – Frankfurt 48,0), `start_nu` (Countdown Nürnberg – Fulda km 0); Stufen `high`, `deck`; Stunden 12, 19.5, 22 |
| `raw/*_{arcade,base,merge,r7c}_NN.png`, `raw/*_diff_NN.jpg` | Einzelbilder, Differenz R7c − Basis × 4 |
| `hamburg_deck_speicher_43a1fcc_r7c.png` | QR7c-01: Speicher bei Deck, links 43a1fcc (lod0), rechts R7c (lod1) |
| `lod0_lod1_sprite_mittel_32-50m.png` | lod0 \| lod1 \| Sprite von Kontor, Speicher, Fachwerk, Haussmann, Block A bei 32/40/50 m (Mittel, 1×) |
| `start_countdown_deck_raster_basis_r7c.png` | QR7c-06: Bäume beim Countdown, links Basis, rechts R7c (Raster) |
| `nuernberg_hoch_fernhaus_arcade_basis_r7c.png` | QR7c-04: fernes Bürgerhaus, 3× (Arcade \| Basis \| R7c) |
| `paris_hoch_haussmann_arcade_43a1fcc_r7c.png` | Haussmann ~60 m: Arcade \| 43a1fcc (lod0) \| R7c (lod1) |
| `hamburg_1930_fenster_arcade_basis_r7c.png` | Dämmerung 19:30, Fenster (Arcade \| Basis \| R7c) |
