p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
rep = [
('| `N1_*` (Hamburg–Hannover km 71, 22 Uhr, Schnee) | Schneefall als Striche im Kegel hell, Schneewall an der Bankette, Kegel auf der Fahrbahn | besser: Schnee fällt sichtbar in der Luft und liegt am Rand; Flocken bei Tempo strichförmig wie bei Arcade |',
 '| `01_N1_…` (Hamburg–Hannover km 71, 22 Uhr, Schnee; Endstand) | Schneefall als Striche im Kegel hell, Schneewall an der Bankette, Kegel auf der Fahrbahn, Kompakt bernsteinfarben | **besser**: Schnee fällt sichtbar in der Luft und liegt am Rand, Flocken bei Tempo strichförmig wie bei Arcade; das Auto hat jetzt die Farbe des Sprites |'),
('| `N2N_*` (dieselbe Stelle, 22 Uhr) | Regen im Kegel, Spiegelung des Kegels, rote Streifen unter dem GT, Gischt rot beleuchtet | besser |',
 '| `03_N2_…` (Dortmund–Frankfurt km 121, 22 Uhr, Regen; Endstand) | Regen im Kegel, Spiegelung des Kegels, rote Streifen unter dem GT, Gischt rot beleuchtet | **besser** bei Regen, Spiegelung und Gischt; **schwächer**: der GT liest sich hellsilbern statt blaugrau wie sein Sprite (Abschnitt 3, Bild 21) |'),
]
for o, n in rep:
    assert s.count(o) == 1, o[:50]
    s = s.replace(o, n)
open(p, 'w').write(s)
print('ok')
