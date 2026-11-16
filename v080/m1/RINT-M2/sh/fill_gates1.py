import sys
p = sys.argv[1] + "/bericht_gates.md"
t = open(p, encoding="utf-8").read()
rep = {
    "@@PROPS@@": "`props_spiegel` OK, `rotor` OK (`ab2a400`); die Strukturprüfung (`countdown`, `zieltor`, `grenze`, `blitz`) auf dem Endstand `02051f7` erneut OK",
    "@@SIGHT@@": "**6 von 6 OK** (`f1` 0 Fälle bis 270 m in 99,4 Mio. Stichproben, `f1_lanes`, `f2` ≤ 0,596, `f3` 0 von 5923, `f7`, `model`); Pfad **2 von 2 OK** (Abstand ≥ 267,6 m, Schleifen ≥ 2064 m)",
    "@@ERG@@": "**Kiel – Hamburg, Testetappe, Saragossa – Pau: je 28 Schlüssel identisch (außer gfx)**",
    "@@TEX@@": "Arcade 201,7 / 200,6 MB, Modern **109,2 / 110,8 MB** (Kiel – Hamburg / Dortmund – Frankfurt; Spitze 109,2 / 110,8)",
}
for k, v in rep.items():
    assert t.count(k) == 1, k
    t = t.replace(k, v)
open(p, "w", encoding="utf-8").write(t)
print("ok")
