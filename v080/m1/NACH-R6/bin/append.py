#!/usr/bin/env python3
"""NACH-R6: append the picture list to bericht.md and mark STAND.md done."""
B = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/NACH-R6/bericht.md"
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6/STAND.md"
TXT = """
## 6. Bilder (in diesem Ordner, alle angesehen)

„A_M“ = `tools/ab_shot.sh` Arcade | Modern Kopf; „arcade_basis_kopf“ = Arcade | Modern `c8b18d1` | Modern `2b7dcc0`.
Grund-Argumente `--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup
--no-countdown` (Start ohne `--no-countdown`), Modern `--gfx-preset=high`, 1280 × 720.

| Datei | Ort und Zeit |
|---|---|
| `01`/`02` | DEV km 64,3, 12 Uhr, 100 km/h, Bild 1,4 s / 2,0 s (Grenze mittel / nah) |
| `03` | dasselbe, 1,4 s, mit Basis (Basis: Dach rechts schwebt) |
| `04`/`05` | Ausschnitte Kopf: nah rechts ohne Stütze, Stangenende an der Blende / fern Masten und Zugstangen |
| `06` | DEV Grenze 21 Uhr, 1,4 s, mit Basis |
| `07`/`08` | wien_prag ab Prag km 269,4, 12 Uhr, 1,4 s / 2,0 s (Grenze „ÖSTERREICH“) |
| `09` | DEV km 129,4, 12 Uhr, 50 km/h, 2,5 s (Zieltor) |
| `10` | dasselbe 21 Uhr, mit Basis |
| `11`/`12` | DEV km 0, 21 Uhr, Countdown 1,0 s („3“, mit Basis) / 3,6 s („LOS!“) |
| `13`/`14` | DEV km 18,5, 21 Uhr, 100 km/h, 1,2 s / 2,6 s (Tankstelle), mit Basis |
| `15` | Ausschnitt Shop bei Nacht: Arcade / Basis / Kopf (untereinander) |
"""
s = open(B).read()
if "## 6. Bilder" not in s:
    open(B, "w").write(s.rstrip("\n") + "\n" + TXT)
st = open(S).read()
st = st.replace("doing: bin/golden.sh (golden check + modern-check start) -> logs/golden.out",
    "done: golden check 20/20 + 17/17, modern-check start 1/1; bericht complete; caches and worktree .godot deleted\ndoing: StructuredOutput (final)")
open(S, "w").write(st)
print("ok")
