"""AS3R scratch: fill the report template -> deliver/AS3R/bericht.md (texts from files in this folder)."""
import subprocess
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R"
DL = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS3R"


def run(*args):
    return subprocess.run([sys.executable] + list(args), capture_output=True, text=True, check=True).stdout


def read(name):
    return open(S + "/" + name, encoding="utf-8").read().strip()


t12 = run(S + "/tables.py", "12", "z").strip().split("\n\n")
fill = {
    "⟨HEAD⟩": "638debc",
    "⟨HEADNOTE⟩": "; danach kein Commit (Bericht und Bilder liegen nur in diesem Ordner)",
    "⟨TAB_H12_LEVELS⟩": t12[0],
    "⟨TAB_UMSCHALT⟩": t12[1],
    "⟨TAB_FLIMMER⟩": t12[2],
    "⟨TAB_H19⟩": run(S + "/tables.py", "19.5", "z").strip(),
    "⟨TAB_H23⟩": run(S + "/tables.py", "23", "z").strip(),
    "⟨TAB_UMRISS⟩": run(S + "/outline_table.py", "z").strip(),
    "⟨TAB_OVERDRAW⟩": read("logs/tab_overdraw.md"),
    "⟨TAB_BUDGET⟩": read("logs/tab_budget.md"),
    "⟨UMSCHALT_SPANNE⟩": "63–73 %",
}
for key, name in (("⟨GATES_KURZ⟩", "gates_kurz.md"), ("⟨GATES⟩", "gates_text.md"), ("⟨VALIDATE⟩", "validate_text.md"),
                  ("⟨AB⟩", "ab_text.md"), ("⟨ABW⟩", "abw.md"), ("⟨LESART⟩", "lesart.md"),
                  ("⟨UMSCHALT_TEXT⟩", "umschalt_text.md")):
    fill[key] = read(name)
s = open(S + "/bericht_vorlage.md", encoding="utf-8").read()
for k, v in fill.items():
    if k not in s:
        print("FEHLT im Text:", k)
    s = s.replace(k, v)
left = [w for w in ("⟨",) if w in s]
open(DL + "/bericht.md", "w", encoding="utf-8").write(s)
print("bericht.md", len(s), "Zeichen", "OFFENE PLATZHALTER" if left else "alle Platzhalter gefüllt")
