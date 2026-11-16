**20 Minuten Modern** (`bin/soak.sh`: `tests/race/run_race.gd -- --race=kiel_nuernberg --autopilot --graphics=modern
--sound=modern --gfx-preset=medium --timescale=1 --max-seconds=1200` unter Xvfb 1280 × 720, llvmpipe, Last 23–26):
1 212 s Wanduhr, am Ende im Zustand `racing` (Etappe Kiel – Hamburg läuft; das Ende kommt von meinem Zeitlimit, nicht
vom Spiel). **0 Fehler-, Warn- oder „leaked“-Zeilen** (außer der V-Sync-Warnung von llvmpipe). Speicher des
Godot-Prozesses (eigene Abtastung alle 30 s, `soak/rss_godot.tsv`): 1,583 GB nach 2,5 min, 1,657 GB nach 4,5 min, danach
**flach 1,659–1,660 GB** bis zum Ende; 23 Threads und 8 offene Dateien durchgehend gleich – kein Wachstum (gemessen).
Wie weit das Auto kam, protokolliert `run_race.gd` nicht (nur Etappenenden); bei 1–3 Bildern/s auf Software-Grafik
läuft die Simulation langsamer als Echtzeit (abgeleitet). Hinweis: Die RSS-Spalte im eigenen Log `q_soak.log` misst
den `timeout`-Prozess (Fehler in meinem Skript, `pgrep` ohne Filter) – gültig ist `rss_godot.tsv`.
