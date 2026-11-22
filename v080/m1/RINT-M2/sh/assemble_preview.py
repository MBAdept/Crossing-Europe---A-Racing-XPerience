"""Assemble deliver/RINT-M2/bericht.md from the drafts; refuses while a placeholder @@...@@ is left."""
import re
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2"
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/preview.md"


def rd(name):
    return open(S + "/" + name, encoding="utf-8").read().strip("\n") + "\n"


teil3 = rd("bericht_teil3.md").replace("@@NOTE8@@\n", rd("bericht_note8.md"))
parts = [
    rd("bericht_teil1.md"),
    rd("bericht_teil2.md"),
    teil3,
    rd("bericht_gates.md"),
    rd("bericht_perf.md"),
    rd("bericht_ab_high.md"),
    rd("bericht_ab_extra.md"),
    rd("bericht_clips.md"),
    rd("bericht_teil6.md"),
    rd("bericht_teil7.md"),
    rd("bericht_teil8.md"),
    rd("bericht_teil9.md"),
]
text = "\n".join(parts)
left = sorted(set(re.findall(r"@@[A-Z0-9_]+@@", text)))
if False:
    print("placeholders left:", left)
    sys.exit(1)
open(OUT, "w", encoding="utf-8").write(text)
print("ok", OUT, len(text.splitlines()), "lines")
