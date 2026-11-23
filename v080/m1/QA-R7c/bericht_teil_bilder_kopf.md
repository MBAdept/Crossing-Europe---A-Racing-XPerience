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
