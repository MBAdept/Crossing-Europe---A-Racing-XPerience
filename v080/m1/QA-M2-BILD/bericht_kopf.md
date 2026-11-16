# QA-M2-BILD – unabhängige Prüfung der ersten M2-Zusammenführung: Bild, Fairness, Leistung

Prüfstand **`6e48405`** (`origin/wip/v080-m2int` = `origin/wip/v080-m2zs1`, M2INT + ZS1-Merge + Pylon-Nacharbeit).
Vergleich: **ZS1** = `39849f0` (erster Testbuild beim Nutzer) als eigener Baum `m1/QA-M2-BILD/zs1tree` (git archive +
Import) im selben Lauf gerendert bzw. gemessen; dazu die ZS1-Bilder aus `deliver/gate1/` (Code an den Positionen
außerhalb Start/Köhlbrandbrücke gleich ZS1, `git diff 86c0650 39849f0` betrifft nur Start-Vorlauf, Starttor-Schatten,
Fernboden über Wasser, Wahrzeichen-Ersatz und Pylon). Rolle: Prüfung ohne Commits; Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3` (Branch `worktree-wf_438996b0-243-3`,
Fast-Forward auf `6e48405`, nichts geändert außer Probe-Skripten im Scratch-Ordner).

„gemessen" = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne). Während der ganzen Prüfung
liefen R4, R5, R6, AS5a und QA-M2-SYSTEM parallel: **Last 12–23** – alle Zeiten sind Proxies unter Last, Vergleiche nur
innerhalb desselben Laufs oder mit ausdrücklich genannter Referenz. Alles über echte Grafikchips, das Steam Deck,
ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

Werkzeuge (alle im Scratch, nichts committet): `sh/shot.sh` (eine Rennszene je Baum/Modus, wie `tools/ab_shot.sh`),
`probe/qa_vehicles.gd` (Testautos in derselben eingefrorenen Ansicht für Arcade und Modern), `probe/qa_occl.gd` +
`sh/occl_count.py` (sichtbare Pixel eines Testautos je Abstand und Spur, Arcade gegen Modern), `probe/qa_props.gd`
(welche Arcade-Requisiten Modern auslässt und warum), `probe/qa_screen.gd`, `probe/qa_drive.gd` (Sonde von M1-QA-BILD,
unverändert) und `probe/qa_drive2.gd` (dieselbe mit Etappenkette für den Speicherlauf), `sh/perfrow.py`,
`tools/models/prop_scene.sh`, `tools/ab_clip.sh`, `tests/race3d/render/warmup_cold.gd`.
