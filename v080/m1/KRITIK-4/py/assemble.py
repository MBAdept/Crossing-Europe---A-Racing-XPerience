"""KRITIK-4: assemble deliver/KRITIK-4/bericht.md from the parts in m1/KRITIK-4 (scratch)."""
import re

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4"
DL = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-4"


def part(name):
    return open(K + "/" + name).read().rstrip() + "\n"


antwort = part("teil_antwort.md").replace("URTEILSTABELLE\n", part("teil_tabelle.md"))
methode = part("teil_methode.md")
maengel = part("teil_maengel.md")
rennen = part("teil_rennen.md").replace("## 5. Im Rennen", "## 4. Im Rennen")
mess = part("teil_messungen.md").replace("## 6. Messungen", "## 5. Messungen")
mess = re.sub(r"### 6\.(\d)", r"### 5.\1", mess)
as4 = part("teil_as4.md").replace("## 7. Was ich", "## 6. Was ich")
vertrag = part("teil_vertrag.md").replace("## 8. Vertragsfragen", "## 7. Vertragsfragen")
bilder = part("teil_bilder.md")
text = "\n".join([antwort, methode, maengel, rennen, mess, as4, vertrag, bilder])
for ph in ("URTEILSTABELLE", "ERGEBNIS_DREH", "FAEHRE_UMRISS", "HAUSBOOT_ZEILE", "STADT_ZEILE", "TURM_ZEILE", "FABRIK_ZEILE"):
    if ph in text:
        raise SystemExit("Platzhalter übrig: " + ph)
open(DL + "/bericht.md", "w").write(text)
print(DL + "/bericht.md", len(text.splitlines()), "Zeilen")
