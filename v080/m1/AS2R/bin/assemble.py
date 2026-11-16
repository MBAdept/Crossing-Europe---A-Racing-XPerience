"""AS2R: puts bericht.md together from the parts and fills the placeholders from values.json."""
import json
import re
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS2R"
vals = json.load(open(S + "/values.json"))
head = open(S + "/bericht_draft.md").read().split("## 1. Ergebnis in Kürze")[0]
t1 = open(S + "/bericht_teil1.md").read()
t2 = open(S + "/bericht_teil2.md").read()
t3 = open(S + "/bericht_teil3.md").read()
t4 = open(S + "/bericht_teil4.md").read()
t5 = open(S + "/bericht_teil5.md").read()
t6 = open(S + "/bericht_teil6.md").read()
# order: 1, 2, 3 (from teil3), 4, 5, 6 (from teil3), 7, 8 + 9 (teil3), 10, 11
t3_s3 = t3.split("## 6. Showroom-Schalter")[0]
t3_s6 = "## 6. Showroom-Schalter" + t3.split("## 6. Showroom-Schalter")[1].split("## 8. Was die Modelle")[0]
t3_s89 = "## 8. Was die Modelle" + t3.split("## 8. Was die Modelle")[1]
t6_s7 = t6.split("## 10. Bilder")[0]
t6_s1011 = "## 10. Bilder" + t6.split("## 10. Bilder")[1]
parts = [head.rstrip() + "\n\n", t1, t2, t3_s3, t4, t5, t3_s6, t6_s7, t3_s89, t6_s1011]
out = "\n".join(p.strip("\n") + "\n" for p in parts)
for k, v in vals.items():
    out = out.replace("{" + k + "}", v)
left = re.findall(r"\{[A-Z0-9_]+\}", out)
if left:
    print("offene Platzhalter:", left)
    sys.exit(1)
open(D + "/bericht.md", "w").write(out)
print("bericht.md", len(out.splitlines()), "Zeilen")
print([l for l in out.splitlines() if l.startswith("## ")])
