import sys
p = sys.argv[1] + "/bericht_gates.md"
t = open(p, encoding="utf-8").read()
rep = [
    ("| Leistung neben `515dd51` | `run_stage.gd` unter Xvfb, Zeitraffer 40 | @@VSTAND@@ | §4.1 |",
     "| Leistung neben `515dd51` | `run_stage.gd` unter Xvfb, Zeitraffer 40 (Testetappe 16) | `b903797` / `9b02f05` | §4.1 |"),
    ("| Builds | `tools/build_linux.sh`, `tools/build_windows.sh`, `pck_report.py` | @@VSTAND@@ | @@BUILD@@ |",
     "| Builds | `tools/build_linux.sh`, `tools/build_windows.sh`, `pck_report.py` | `9b02f05` | Exit 0 / 0; Linux **191,1 MB** (geschätzt), Windows-ZIP **200,9 MB** (gemessen) – Budget 277 MB, Warnung über 300; Modern: Modelle 19,6 / 40, Texturen 18,4 / 60, Klang 16,4 / 23, Musik 18,6 / 25 MB; die eingefrorenen Arcade-Teile wie gehabt (Sprites 71,07 / 71,0, Klang 14,72 / 14,7 – Rundung der Budgets) |"),
    ("| Rauchtest | `tools/smoke_modern.sh` (Linux, GLES, Windows unter wine64) | @@VSTAND@@ | @@SMOKE@@ |",
     "| Rauchtest | `tools/smoke_modern.sh` (Linux, GLES, Windows unter wine64) | `9b02f05` | **SMOKE linux OK, linux_opengl3_es OK, windows OK** (Arcade und Modern starten, Leistungstest 6,7 / 5,8 / 5,7 fps auf llvmpipe, Vorschlag arcade/low; Nutzerordner je im Arbeitsordner) |"),
]
for a, b in rep:
    assert t.count(a) == 1, a[:50]
    t = t.replace(a, b)
open(p, "w", encoding="utf-8").write(t)
print("ok")
