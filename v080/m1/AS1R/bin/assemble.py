"""AS1R: assemble deliver/AS1R/bericht.md from the parts in the scratch folder (placeholders filled from repl.json)."""
import json
import os

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1R/bericht.md"
parts = ["bericht_teil1.md", "bericht_teil1b.md", "bericht_teil2.md", "bericht_teil3.md", "bericht_teil4.md",
         "bericht_teil5a.md", "bericht_teil5.md", "bericht_teil6.md", "bericht_teil7.md"]
text = "\n".join(open(os.path.join(S, p)).read().rstrip() + "\n" for p in parts if os.path.exists(os.path.join(S, p)))
repl = json.load(open(os.path.join(S, "repl.json"))) if os.path.exists(os.path.join(S, "repl.json")) else {}
for k, v in repl.items():
    text = text.replace(k, v)
open(D, "w").write(text)
print(D, len(text))
