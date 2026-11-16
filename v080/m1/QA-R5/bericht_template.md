# QA-R5 – Unabhängige Prüfung des Pakets R5 (Tunnel, Brücken, Wasser und Ufer)

Prüfling: `origin/wip/v080-r5` = `5558bdc485f9df938c349e8e0ecb2f869c2335a9`, Basis `6e484056ec87e2fa614061000a362feb2b5a6db8`
(`origin/wip/v080-m2int`). Rolle: Prüfung, keine Commits, kein Push. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4` (per `git merge --ff-only` auf
5558bdc, nichts geändert); Basisbaum als `git archive` in `m1/QA-R5/base`, eine Kopie des Prüflings für Mutationen und
eigene Prüfskripte in `m1/QA-R5/mut` (beide nach der Prüfung gelöscht). „gemessen“ = auf dieser VM (Mesa llvmpipe unter
Xvfb bzw. headless, 4 geteilte Kerne, Last 10–15 durch die Nachbarpakete); alles über Steam Deck und echte Grafikkarten
ist **abgeleitet**. Schwere Läufe einer nach dem anderen mit `nice -n 10` (`QA_M2_FERTIG` lag vor).

__KURZ__

## 1. Eigentum und Arcade-Identität

`git diff 6e48405..5558bdc --stat` (gemessen): 16 Dateien, +4112/−169.

| Datei | Eigentum laut Auftrag | Urteil |
|---|---|---|
| `scripts/race3d/builders/bridge.gd` (neu, 1150 Z.), `builders/tunnel.gd` | R5 | in Ordnung |
| `assets/shaders/modern/{tunnel,water}.gdshader` | R5 | in Ordnung |
| `scripts/race3d/layers/far_ground.gd` | R5 (Entscheidung 1 der Leitung) | in Ordnung |
| `tests/unit/race3d/{test_bridge,test_tunnel}.gd`, `tests/race3d/render/check_tunnel_bridge.gd` | R5 | in Ordnung |
| `docs/renderer-modern.md` (+31, §15) | Auftrag: `set_zone`-Aufrufe dort dokumentieren | in Ordnung (Kollisionsgefahr §15 mit R4/R6, R5 meldet es selbst) |
| `docs/renderer-modern-tunnel-bruecken.md` (neu) | nicht genannt; Muster wie `renderer-modern-gelaende.md` | in Ordnung |
| `tests/golden/modern_slice.md5` (Zeile `modern_s4_mittel`) | **nicht R5**: §5 Spalte W3 „–“, A-8: Integration/QA | Abweichung (Befund QR5-07) |
| `.uid`-Dateien | zu den neuen Dateien | in Ordnung |

Keine eingefrorene Arcade-Datei, keine Datei von R4/R6 (auch `props.gd`, `environment_rig.gd`, `far_ground.gdshader`
unverändert). __GOLDEN__

## 2. Funktion – Datenabtastung des ganzen Netzes (gemessen)

Eigenes Prüfskript `tests/qa_r5/qa_scan.gd` (nur in der Scratch-Kopie, nicht eingecheckt): baut **jede Brücke und
jeden Tunnel jeder Richtung jeder Etappe** und zusätzlich beide Richtungen der `dev_testetappe` headless mit
`builders/bridge.gd` / `builders/tunnel.gd` (wie der Streamer: `RoadPath3D`, `TerrainProfile`, `ChunkContext.capture`)
und vergleicht **mit Arcades Ereignissen derselben Strecke** (`Track._build_bridge`: Pylone, Fachwerkportale,
Brückenlampen; Arcades Tunnelregeln: Nischenschild alle 150 m, Leuchten alle 12 m, Kappe bei `peek_m`):

- **122 Brücken** (cable_stayed 12, canal 10, causeway 2, river 60, stone_arch 35, truss_arch 3) und **28 Tunnel**
  (26 im Netz + 2 der Testetappe), **0 Befunde**, 177 s, keine Skriptfehler.
- Je Brücke exakt so viele Pylone, Flugfeuer (je Pylon eins, mit `blink`), 14 Seile je Pylon, Fachwerkportale und
  Brückenlampen wie Arcade Ereignisse hat (z. B. Köhlbrandbrücke 4/4 Pylone, 56 Seile; Elbbrücken 5/5 Portale;
  Ponte della Libertà 20/20 Lampen; Severinsbrücke 2/2 Pylone); Wasser überall; **Ufer an beiden Enden** jeder Brücke
  (Eckpunkte der Ufermaterialien vor und hinter der Brückenmitte > 0).
- **Nichts vom Tragwerk, der Röhre oder dem Portal über den Spuren zwischen 0,3 m und 4,5 m** (Dreiecke abgetastet,
  Kappe ausgenommen); **jedes Seil ≥ 2,15 m neben der Spur** (alle 12 Schrägseilbrücken-Richtungen, kleinster Wert
  Köhlbrandbrücke Hamburg–Bremen 2,15 m).
- **Portalhügel nie über der Anfahrt im Sichtkorridor** (Punkte des Hügels, die einer Zeile vor dem Portal zugeordnet
  sind, höher als 0,5 m über der Fahrbahn innerhalb Spur + Bankett + 5,5 m: 0 in 28 Tunneln) – F7.
- Tunnel: je 1 Portal, 1 Ausfahrtsrahmen, Kappe genau dort, wo Arcade sie hat (Valík 39/42 m: keine), Nischen wie
  Arcades grüne Schilder (z. B. Gotthard 11/11, Somport 6/6), Leuchten 2–11 mehr als Arcades Reihe (Nischenleuchten).
- R5s eigener Netzlauf `check_tunnel_bridge.gd -- --full`: OK, 122 Brücken, 26 Tunnel, 0 Mängel, 52 s (gemessen).
  Er prüft aber nur grob (Pylone ≥ 2, Portale > 2, Brückenlampen gar nicht) – Befund QR5-06.

Daten: Galerien gibt es nicht; kurze Altstadttunnel Valík (39/42 m), Radejčín (60 m), Dölzschen (108 m) bauen.

__FAIR__

__TESTS__

## 5. Bilder – angesehen, ehrlich gegen Arcade und gegen die Basis

`tools/ab_shot.sh` (Arcade | Modern desselben Simulationszustands), Modern „Hoch“, 1280 × 720; die Basis 6e48405 mit
denselben Argumenten. **Bestimmtheit geprüft:** meine Renderings des Prüflings sind an 12 Orten (24 Bilder)
**bitgleich** mit R5s gelieferten Bildern, meine Basisbilder (U1 innen, Köhlbrand Rampe) bitgleich mit R5s
Basisbildern – R5s Bilder zeigen den Endstand, seine Basisspalte ist echt (gemessen, max. Abweichung 0).
Bögen „Arcade | Modern Basis | Modern R5“: `bilder/<ort>_NN.jpg`; Ausschnitte `bilder/ausschnitt_*.jpg`.

__BILDER__

__LEISTUNG__

__BEFUNDE__

__OK__

## 9. Wo was liegt

- Bilder/Bögen: `deliver/QA-R5/bilder/`; Rohbilder `m1/QA-R5/shots/{new,base}/`; Ausschnitte `m1/QA-R5/crops/`.
- Protokolle: `m1/QA-R5/logs/` (qa_scan, r5_full_scan, mutate, modern_sight_full, modern_path_full, run_tests_full,
  render_*, golden_check, bench_*, perf_*), Mutationen `m1/QA-R5/mutations/` (results.json + je Mutation ein Log).
- Werkzeuge: `m1/QA-R5/tools/` (shots.sh, queue1–4.sh, mutate.py, crop.py, sheet.py, make_sheets.sh) und die
  Prüfskripte `qa_scan.gd`, `bench_r5.gd` (Kopie in `m1/QA-R5/tools/gd/`).
