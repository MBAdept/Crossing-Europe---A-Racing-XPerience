S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1/"
s = open(S + "bericht_ab.md").read()
old = """also gleich – den Platz verwirft die Sichtkorridor-Regel des Requisiten-Builders (`drop_reason`, „corridor“: dekorative
Requisiten in Kurven), unabhängig davon, ob ein Modell oder ein Platzhalter dort steht. Laut Aufgabenliste beschränkt
FIX-M2 (B-01) die Regel auf Vegetation; nach dem Zusammenführen sollte das Haus dort stehen (gefolgert, nicht geprüft)."""
new = """also gleich. Den Platz verwirft eine Ausschlussregel des Requisiten-Builders (`drop_reason`: Sichtkorridor einer Kurve
für dekorative Requisiten oder das Geländeband) – unabhängig davon, ob ein Modell oder ein Platzhalter dort steht
(gefolgert aus dem Code; welche der beiden Regeln, habe ich nicht gemessen). Laut Aufgabenliste beschränkt FIX-M2
(B-01) die Korridorregel auf Vegetation; nach dem Zusammenführen ist zu prüfen, ob das Haus dort steht.
Zur Dämmerung (19:30, Hamburg) leuchten in Modern deutlich weniger Fenster des Kontors als in Arcade, um 22 Uhr
etwa gleich viele: die Lichtrampe über die Uhrzeit ist Sache des Renderers (R4), die Fenster selbst sind dieselben."""
assert old in s
s = s.replace(old, new)
open(S + "bericht_ab.md", "w").write(s)
print("ok")
