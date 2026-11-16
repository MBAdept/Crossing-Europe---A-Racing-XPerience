root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''| Kreisbogen ab der Kamera, R 400 m / R 136 m (Test) | – / ≤ 27 px | ≤ 8 px / – | | |
'''
b = '''| Kreisbogen ab der Kamera, R 400 m / R 136 m (Test) | – / ≤ 27 px | ≤ 8 px / – | | |

Die Unterschiede sind Geometrie, nicht Kamera: Arcade schert, Modern dreht. Der Blick in die Kurve schwenkt das
ganze Bild zusätzlich um einen festen Betrag (an diesen vier Stellen 54 / 60 / 176 / 184 px, gemessen) – ein
Bildvergleich mit Arcade in Kurven braucht deshalb `look_gain` 0 oder rechnet den Schwenk heraus.
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
