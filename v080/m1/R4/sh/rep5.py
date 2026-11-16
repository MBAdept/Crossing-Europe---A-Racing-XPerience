import re
p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
URTEIL = '''**Wetter in der Luft ist da, die Nacht hält Arcades Helligkeit, alle Tore grün oder als Last belegt – der Lack der
Spielerautos bleibt der schwächste Punkt.** Endstand `7f0eae2` (+ Modern-Hashes `83dbdac`), Branch
`worktree-wf_fd1de4ee-28b-1`, gepusht nach `origin/wip/v080-r4`.

- **Klar besser als Arcade**: Regen und Schneefall auf jeder „Effekte“-Stufe (300 / 1.500 / 4.000 Teilchen, jede
  Stufe mindestens Arcades Dichte), Gischt hinter jedem Auto auf nasser Fahrbahn, nasse Fahrbahn mit Himmelsspiegelung
  und Spiegelungen der Rück-, Brems- und Laternenlichter, Schneewälle und Schnee auf den Dingen, Blaulicht mit
  Lichtkegel, Sonnenscheibe, lange Schatten in Dämmerung und Abend (Bilder N1, N2, S1 bedeckt, C1 Regen).
- **Gleichwertig**: Nacht-Fahrbahn N1 +4,9 % gegen Arcade (nie dunkler), Wetter-×-Stunde-Tabelle 0,90–1,01 × bei
  Kontrast 0,74–1,17 ×, Tunnelausfahrt jetzt überbelichtet statt milchig (Arcades Gras bleibt greller).
- **Schwächer als Arcade** (ehrlich): der silberne GT nachts im Regen wirkt heller und neutraler als sein blaugraues
  Sprite (Kofferraumdeckel rund 1,6 × Arcade), die Limousine in der Dämmerung lila statt blau; nachts sind Kompakt und
  Limousine jetzt farbig wie die Sprites (Sättigung 0,95 × / 0,91 ×), der GT knapp (0,73 ×).
- **Leistung** (llvmpipe, gemessen): ganze Etappe Kiel – Hamburg nachts im Regen ohne Fehler, `render()` 5,30 ms gegen
  5,35 ms der Basis, +4 Zeichenaufrufe, < 1 % Dreiecke; kalter Cache N1 und N2 ohne Übersetzung während der Fahrt
  (N1 erst nach der Aufwärm-Ebene, 1.12). Steam Deck und echte Grafikkarten: abgeleitet.'''
assert s.count('@@URTEIL@@') == 1
s = s.replace('@@URTEIL@@', URTEIL)
# reorder: move "## 5. Abweichungen" .. before "## 4. Tore" to after "## 6. Clips" section
i_abw = s.index('## 5. Abweichungen')
i_tore = s.index('## 4. Tore')
block = s[i_abw:i_tore]
s = s[:i_abw] + s[i_tore:]
i_next = s.index('## 9. Für die nächsten Pakete')
block = block.replace('## 5. Abweichungen', '## 7. Abweichungen').replace('## 6. Vertragsfragen', '## 8. Vertragsfragen')
s = s[:i_next] + block + s[i_next:]
open(p, 'w').write(s)
print([l for l in s.splitlines() if l.startswith('## ')])
