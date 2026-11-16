"""AS1R: vehicle rows of the measured numbers table in docs/modelle.md (section 11)."""
p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3/docs/modelle.md"
s = open(p).read()
rows = {
    "| `player/limousine` | lod0 45 764":
    "| `player/limousine` | lod0 44 095 · show 94 629 · Schatten 2 320 | 6 / 6 | 1 527 819 B | – | 13,3 s | 0,07 s |",
    "| `player/kompakt` | lod0 50 080":
    "| `player/kompakt` | lod0 47 524 · show 100 332 · Schatten 2 320 | 6 / 6 | 1 661 802 B | – | 13,2 s | 0,10 s |",
    "| `traffic/sedan` (4 Farbsets) | lod0 17 695":
    "| `traffic/sedan` (4 Farbsets) | lod0 17 555 · lod1 5 809 · lod2 1 149 · Schatten 972 | 6 / 1 / 1 | 271 351 B | – | 2,3 s | 0,02 s |",
    "| `traffic/hatch` (5 Farbsets) | lod0 17 317":
    "| `traffic/hatch` (5 Farbsets) | lod0 17 636 · lod1 5 661 · lod2 1 180 · Schatten 988 | 6 / 1 / 1 | 270 561 B | – | 2,2 s | 0,02 s |",
    "| `traffic/wagon` (4 Farbsets) | lod0 17 888":
    "| `traffic/wagon` (4 Farbsets) | lod0 17 464 · lod1 5 941 · lod2 1 141 · Schatten 940 | 6 / 1 / 1 | 276 055 B | – | 2,5 s | 0,02 s |",
    "| `traffic/truck` (4 Lackierungen) | lod0 18 084":
    "| `traffic/truck` (4 Lackierungen) | lod0 18 084 · lod1 4 672 · lod2 1 490 · Schatten 476 | 13 / 1 / 1 | 161 851 B | – | 1,0 s | 0,02 s |",
}
lines = s.split("\n")
done = 0
for i, line in enumerate(lines):
    for start, new in rows.items():
        if line.startswith(start):
            lines[i] = new
            done += 1
s = "\n".join(lines)
head = "## 11. Referenzmodelle (gemessen)\n"
if "Stand nach der Nacharbeit AS1R" not in s:
    s = s.replace(head, head + "\nFahrzeuge: Stand nach der Nacharbeit AS1R (Abschnitt 13); die übrigen Zeilen aus Bauabschnitt 0.\n", 1)
open(p, "w").write(s)
print("Zeilen ersetzt:", done)
