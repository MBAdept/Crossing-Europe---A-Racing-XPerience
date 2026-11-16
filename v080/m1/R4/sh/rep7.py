import re
p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
lines = s.split('\n')
out = []
for l in lines:
    if 'Kofferraumdeckel rund 1,6 × Arcade), die Limousine' in l:
        l = l.replace('Sprite (Kofferraumdeckel rund 1,6 × Arcade), die Limousine', 'Sprite (gleiche Leuchtdichte – Median 42 von 255 in beiden Hälften des Clips –, aber neutral grau statt blau), die Limousine')
    if l.startswith('| `21_spielerauto_nacht_'):
        l = re.sub(r'\*\*schwächer\*\*: der silberne GT .*\|$',
                   '**schwächer**: der silberne GT liest sich heller und neutraler als Arcades blaugraues Sprite – gemessen ist es der Farbton, nicht die Helligkeit: im Clip N2N Median 42 / 75. Perzentil 47 von 255 in beiden Hälften, mittlere Farbe Arcade (43, 44, 61), Modern (44, 45, 56); Sättigung 0,73 × (`check_night`). Eine erste Rasterzählung „Kofferraumdeckel 1,6 ×“ lag auf dem Lichtkegel über dem Dach und ist falsch |', l)
    if l.startswith('4. **Lack (offen)**: der silberne GT nachts im Regen – Kofferraumdeckel und Dach rund 1,6 × Arcades Wert (Raster),'):
        l = '4. **Lack (offen)**: der silberne GT nachts im Regen liest sich hellsilbern statt blaugrau – gleiche Leuchtdichte, weniger Blau (Sättigung 0,73 ×),'
    out.append(l)
s = '\n'.join(out)
s = s.replace('''   vermutlich der Klarlack, der unter flachem Winkel den Regenhimmel spiegelt (`env_night` 0,35); Dämmerung: die''',
              '''   vermutlich der Klarlack, der den grauen Regenhimmel spiegelt (`env_night` 0,35) statt Arcades Nachttönung; Dämmerung: die''')
open(p, 'w').write(s)
print([l[:120] for l in s.split('\n') if '1,6' in l])
