"""AS4R scratch: assemble deliver/AS4R/bericht.md from bericht_template.md and the teil_*.md parts.
python3 assemble.py <commit>"""
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS4R"


def part(name):
    with open(os.path.join(S, name), encoding="utf-8") as f:
        return f.read().strip()


t = part("bericht_template.md")
rep = {
    "COMMIT_TODO": sys.argv[1],
    "GATES_KURZ_TODO": part("teil_gates_kurz.md"),
    "TEIL_AENDERUNGEN": part("teil_aenderungen.md"),
    "PORTAL_FLIMMERN_TODO": "1,0 / 2,4 / 7,7 / 8,5 %",
    "TEIL_BUDGETS": part("teil_budgets.md"),
    "GATES_TODO": part("teil_gates.md"),
    "TEIL_REST": part("teil_rest.md"),
    "EINORDNUNG_TODO": part("teil_einordnung.md"),
    "BILDER_TODO": part("teil_bilder.md"),
}
for k, v in rep.items():
    if k not in t:
        raise SystemExit("Platzhalter fehlt: " + k)
    t = t.replace(k, v)
left = [w for w in ("TODO", "TEIL_") if w in t]
with open(os.path.join(D, "bericht.md"), "w", encoding="utf-8") as f:
    f.write(t + "\n")
print("bericht.md", len(t), "Zeichen, offene Platzhalter:", left)
