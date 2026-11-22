import sys
S = sys.argv[1]
p = S + "/bericht_note8.md"
t = open(p, encoding="utf-8").read()
old = """| `02051f7` (dazu Schilder je Segment geteilt) | **2,40 / 0,14 ms** | alle neun Dächer vor ihrem Stück gesammelt und auf dem Arbeitsfaden entschieden, keines inline; erstes Dach einer Station zwei Hälften zu 1,2–1,5 ms, jedes weitere 0,2–0,6 ms |
"""
new = """| `02051f7` (dazu Schilder je Segment geteilt) | 2,40 / 0,14 ms | alle neun Dächer vor ihrem Stück gesammelt und auf dem Arbeitsfaden entschieden, keines inline; erstes Dach einer Station zwei Hälften zu 1,2–1,5 ms (kalte Caches), jedes weitere 0,2–0,6 ms |
| Versuch `warm_step()` mit 0,7 ms Budget (verworfen) | 8,71 / – ms | zu wenig Arbeit je Aufruf: ein Dach war nicht rechtzeitig fertig |
| **`b903797`** (`warm_step()`: Strecke in Stücken zu 6 Segmenten erzeugt, Caches der Schilder und Kamerastellen Stück für Stück bis 1,0 ms je Aufruf) | **2,08 / 0,12 ms** | die kalte Arbeit des ersten Dachs ist auf mehrere Aufrufe verteilt |
@@WARM12ROW@@"""
assert t.count(old) == 1
t = t.replace(old, new)
old = t[t.index("- Ergebnis: der Entscheid (Sichtlinien)"):t.index("- Sonde ohne Spiel")]
new = """- Ergebnis: der Entscheid (Sichtlinien) läuft auf dem Arbeitsfaden (`WorkerThreadPool`), das Sammeln der Strecke bleibt
  im Hauptfaden (`Track` erzeugt sich beim Lesen, nicht fadensicher; Arcade-Datei, eingefroren) und ist mit
  `warm_step()` in kleine Stücke unter einem Zeitbudget verteilt. @@WARM12TXT@@
- **Messgüte:** ein Lauf, ein Höchstwert, auf einer VM mit zwei Paketen gleichzeitig. Die Höchstwerte der anderen
  Bausteine schwanken zwischen gleichen Läufen stark (Requisiten in vier Läufen 0,12 / 0,34 / 0,70 / **4,19 ms**,
  ohne Codeänderung dort) – Mittel sind belastbar, ein einzelner Höchstwert um 2 ms nicht. Für eine harte Aussage
  „≤ 2 ms auf dem Deck“ braucht es das Gerät oder mehrere Läufe auf einer ruhigen Maschine.

"""
t = t.replace(old, new)
open(p, "w", encoding="utf-8").write(t)
print("ok")
