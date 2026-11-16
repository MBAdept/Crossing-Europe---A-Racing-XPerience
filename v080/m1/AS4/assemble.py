"""AS4 scratch: puts the report together from its parts -> deliver/AS4/bericht.md.
   python3 assemble.py <commit>"""
import os
import sys

S = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(S, "..", "..", "deliver", "AS4")
commit = sys.argv[1]


def part(name):
    with open(os.path.join(S, name), encoding="utf-8") as fh:
        return fh.read().strip() + "\n"


head = part("bericht_entwurf.md")
mess = part("bericht_messungen.md")
budget, _sep, messungen = mess.partition("## Messungen")
messungen = "## Messungen" + messungen
rest = "\n".join([part("bericht_rennen.md"), part("bericht_rest.md"), part("bericht_einordnung.md"),
                  part("bericht_bilder.md")])
text = (head.replace("{{COMMIT}}", commit)
        .replace("{{TABELLE}}", budget.strip() + "\n")
        .replace("## Runden\n\n{{RUNDEN}}", part("bericht_runden.md"))
        .replace("{{MESSUNGEN}}", messungen.strip() + "\n")
        .replace("{{R5}}", part("r5_masse.md"))
        .replace("{{GATES}}", part("bericht_gates.md").replace("{{COMMIT}}", commit))
        .replace("{{REST}}", rest))
assert "{{" not in text, [ln for ln in text.splitlines() if "{{" in ln]
os.makedirs(D, exist_ok=True)
with open(os.path.join(D, "bericht.md"), "w", encoding="utf-8") as fh:
    fh.write(text)
print("->", os.path.abspath(os.path.join(D, "bericht.md")), len(text.splitlines()), "Zeilen")
