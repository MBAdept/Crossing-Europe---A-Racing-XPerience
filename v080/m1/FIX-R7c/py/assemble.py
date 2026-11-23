#!/usr/bin/env python3
"""FIX-R7c: assemble deliver/FIX-R7c/bericht.md from the draft parts (placeholders replaced by the parts)."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-R7c"


def r(name):
    return open(S + "/" + name, encoding="utf-8").read().strip("\n")


skel = open(S + "/bericht_skelett.md", encoding="utf-8").read()
befunde = "\n\n".join([r("bericht_draft_befunde.md"), r("bericht_draft_befunde2.md"), r("bericht_draft_befunde3.md"),
    r("bericht_draft_rest.md")])
parts = {
    "BEFUNDE": befunde,
    "PERFTABELLE": r("perf_table.md"),
    "GATES": r("bericht_teil_gates.md"),
    "BILDER": r("bericht_teil_bilder.md"),
    "VERTRAG": r("bericht_teil_vertrag.md"),
    "NAECHSTE": r("bericht_teil_naechste.md"),
    "LIEFERUNG": r("bericht_teil_lieferung.md"),
}
for k, v in parts.items():
    skel = skel.replace(k + "\n", v + "\n", 1) if (k + "\n") in skel else skel.replace(k, v, 1)
for k, v in [l.split("=", 1) for l in r("bericht_werte.txt").splitlines() if "=" in l]:
    skel = skel.replace(k.strip(), v.strip())
open(D + "/bericht.md", "w", encoding="utf-8").write(skel)
left = [w for w in ["ENDSTAND", "GATESKURZ", "MUTTABELLE", "PERFZEILE", "MERGETEST", "MERGENOTE", "MODERNGOLDENS",
    "STARTHIGH", "STARTHIGHLOOK", "BILDER", "BEFUNDE"] if w in skel]
print("Platzhalter offen:", left)
