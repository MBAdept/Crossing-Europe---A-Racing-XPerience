#!/usr/bin/env python3
"""Replace the raw 'Ende' row of the Kiel–Hamburg table and write the reading, the short gate text."""
F = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5'
lines = open(F + '/perf_kh_table.md', encoding='utf-8').read().splitlines()
out = []
for l in lines:
    if l.startswith('| Ende |'):
        l = ('| Ende | Ziel, 95,0 km, nicht abgebrochen, 1 Tankstopp (42,2 L), 0 Skript-/Shaderfehler | dasselbe; '
             '`ERGEBNIS` bytegleich mit der Basis (MD5 c38986e4…) |')
    out.append(l)
open(F + '/perf_kh_table.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
open(F + '/perf_kh_lesart.md', 'w', encoding='utf-8').write(
    'Lesart (gemessen, llvmpipe, Last 10–17; die Basis lief direkt nach FIX-R5): Kiel – Hamburg hat **keinen Tunnel** – '
    'FIX-R5 ändert dort keinen Bau (die Bilder der Köhlbrandbrücke sind bitgleich mit R5), darum ist alles Gleiche gleich: '
    'dieselben 2478 Bilder, dasselbe `ERGEBNIS`, dieselben Zeichenaufrufe / Primitive / Schatten-Primitive im letzten '
    'Bild (105 / 93 050 / 5353), derselbe Texturspeicher (120,7 MB). `render()` im Mittel 2,22 gegen 2,09 ms, '
    'Commit-Maximum 2,92 gegen 2,66 ms (Budget „Mittel“ 3 ms gehalten), Worker-Bau 6,3 gegen 5,0 ms im Mittel – im '
    'Rahmen der Last: der FIX-R5-Lauf brauchte 21 % mehr Wanduhr (1815 gegen 1506 s) und seine Simulation, die R5 '
    'nicht berührt, 10 % mehr (`sim_avg_ms` 1,13 gegen 1,03). Gegen die Budgets von §4.10 („Mittel“: 900 Aufrufe, '
    '700 000 Primitive) weit darunter. Steam Deck und echte GPU: abgeleitet; es zählt der Leistungstest des Nutzers.\n')
open(F + '/perf_kurz.txt', 'w', encoding='utf-8').write(
    'Kiel – Hamburg ganz, Modus Modern, „Mittel“, Xvfb: Ziel erreicht, 0 Skript-/Shaderfehler, `ERGEBNIS` bytegleich '
    'mit der Basis; `render()` 2,22 / 24,6 ms (Basis 2,09 / 18,4), Commit max 2,92 ms (2,66), 105 Aufrufe / 93 050 '
    'Primitive (gleich) – Abschnitt 6\n')
