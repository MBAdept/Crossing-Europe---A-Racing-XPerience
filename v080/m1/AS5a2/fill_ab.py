import re
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2/"
lines = [l for l in open(S + "logs/chain_ab.out") if l.startswith("AB")]
tab = ["| Stadt | Voreinstellung | Uhrzeit | Exit | Fehlerzeilen (SCRIPT ERROR, Parse Error, ERROR:) in beiden Logs | Bild |",
       "|---|---|---|---|---|---|"]
CITY = {"pa": "Paris", "am": "Amsterdam", "br": "Brüssel", "tl": "Toulouse", "be": "Bern"}
CF = {"pa": "paris", "am": "amsterdam", "br": "bruessel", "tl": "toulouse", "be": "bern"}
PN = {"high": "hoch", "medium": "mittel"}
HN = {"12": "mittag", "19.5": "daemmerung", "22": "nacht"}
HT = {"12": "12 Uhr", "19.5": "19:30", "22": "22 Uhr"}
for l in lines:
    m = re.match(r"AB (\w+) (\w+) h([\d.]+) exit (\d+) Fehlerzeilen (\d+)", l)
    c, p, h, ex, er = m.groups()
    tab.append("| %s | %s | %s | %s | %s | `rennen_%s_%s_%s_00/01.jpg` |" % (CITY[c], PN[p], HT[h], ex, er, CF[c], PN[p], HN[h]))
s = open(S + "bericht_ab.md").read()
s = s.replace("ABTABELLE", "\n".join(tab) + "\n\n13 Läufe, alle Exit 0, 0 Fehlerzeilen (gemessen). Ein Modern-Lauf mit zwei Bildern brauchte 4–8 min.")
s = s.replace("ABBEFUND", """- **Tag:** Wo Arcade die Straßenflanke eines Hauses als flache Bildfläche zeigt (Haussmann-Bogenläden in Paris,
  blinde Backsteinflanke des Treppengiebelhauses in Amsterdam, Erdgeschoss des Maashauses in Brüssel, Lauben in Bern),
  zeigt Modern Fenster mit Laibung und Sprossen, Läden mit Auslage, Gitter, Balkone und Blumenkästen. Front und Dach
  wie im Sprite; die Häuser stehen an derselben Stelle. Modern ist hier deutlich feiner, nicht nur anders.
- **Dämmerung (19:30, „Mittel“):** dieselben Fenster leuchten wie in Arcade, dazu die neuen Flankenfenster.
- **Nacht (22 Uhr):** Fensterlicht unregelmäßig wie in Arcade. Schwächer als Arcade sind die Schaufenster: In Paris
  ist die Ladenzeile rechts in Arcade eine Reihe heller gelber Bögen, in Modern beleuchtete Auslagen mit Waren, aber
  dunkler (beleuchtete Ladenpixel im Mittel 124 gegen 207 in Arcade, ein beleuchtetes Fenster 210; gemessen in der
  Nahansicht bzw. dem A/B-Bild) – der schwächste Punkt dieser Charge, Abschnitt 8.
- **Nicht meine Modelle:** In Toulouse stehen neben Südhaus und Lyoner Haus die spanischen Häuser als
  Arcade-Platzhalter (AS5b); in Brüssel fehlen in Modern die niedrigen Backsteinmauern, die Arcade am Straßenrand
  zeigt (Requisiten-Bauer/andere Sets, nicht untersucht).""")
open(S + "bericht_ab.md", "w").write(s)
print("ok")
