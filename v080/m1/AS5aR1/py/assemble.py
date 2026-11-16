"""assemble.py: rep/*.md in order + placeholders from rep/ph_*.md -> deliver/KRITIK-5a1/bericht.md"""
import os, re, glob
K = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1'
DL = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-5a1'
order = ["00_kopf", "01_antwort", "02_methode", "03_maengel", "03c_maengel", "04_rennen", "05_mess_budget", "06_bestaetigt",
         "07_vertrag", "08_weiter", "09_bilder"]
parts = []
for n in order:
    t = open(os.path.join(K, "rep", n + ".md")).read().strip()
    if n == "05_mess_budget":
        t = "## 5. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)\n\n" + t
    parts.append(t)
doc = "\n\n".join(parts) + "\n"
for p in glob.glob(os.path.join(K, "rep", "ph_*.md")):
    key = os.path.basename(p)[3:-3]
    doc = doc.replace("{{%s}}" % key, open(p).read().strip())
left = re.findall(r"\{\{[A-Z0-9_]+\}\}", doc)
open(os.path.join(DL, "bericht.md"), "w").write(doc)
print("bericht.md", len(doc), "Zeichen; offene Platzhalter:", left)
