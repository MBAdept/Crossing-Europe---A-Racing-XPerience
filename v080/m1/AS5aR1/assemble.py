"""AS5aR1: fill the placeholders of deliver/AS5aR1/bericht.md from the parts in the scratch folder."""
import os

S = os.path.dirname(os.path.abspath(__file__))
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR1/bericht.md"


def rd(name):
    with open(os.path.join(S, name)) as fh:
        return fh.read().rstrip() + "\n"


with open(D) as fh:
    s = fh.read()
budget = rd("logs/budget.md").split("\n\nSumme")[0].rstrip() + "\n"
budget = budget.replace("| Bake s |", "| Export s |")
rep = {
    "{{TAB_BEFUNDE}}": rd("part_befunde.md"),
    "{{TAB_BUDGET}}": budget,
    "{{MESSUNGEN}}": rd("part_mess.md"),
    "{{GATES}}": rd("part_gates.md"),
    "{{AB}}": rd("part_ab.md"),
    "{{EINORDNUNG}}": rd("part_einordnung.md"),
    "{{NOTES}}": rd("part_notes.md"),
    "{{LIEFERUNG}}": rd("part_lieferung.md"),
    "{{GOLDEN_FILES}}": "Prüfsummen von `modern_s4_mittel` und `modern_s5_niedrig` neu (dort stehen die Stadthäuser), nach Ansehen",
}
for k, v in rep.items():
    if k in s:
        s = s.replace(k, v)
s = s.replace("Endstand siehe\nAbschnitt „Gates“.", "Endstand `7153381`.")
with open(D, "w") as fh:
    fh.write(s)
print(len(s.splitlines()), "Zeilen; offen:", "{{" in s)
