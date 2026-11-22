import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
abw = """
- **Gates auf zwei Ständen:** Render-Prüfungen, `golden.sh modern-check`, `modern_sight --full`,
  `modern_path_check --full` liefen auf `e81886a`; danach kamen nur `43cfd97` (optionale Argumente von
  `in_bend_corridor()`, Standardweg Zeile für Zeile gleich, nicht aufgerufen) und `b3f1b67` (Doku). Der zweite volle
  `tools/run_tests.sh` lief auf dem Endstand `b3f1b67`, parallel zu den Render-Prüfungen (zwei Arbeiter).
- **Fußabdruck nicht im Requisiten-Builder behoben:** `builders/props.gd` gehört R7c; die Prüfung mit Reichweite ist
  gebaut und getestet, der Aufruf fehlt (§2). Bis dahin ragen 5.832 statt 1.124 Requisiten mit Vorderkante oder Krone in
  die Hülle (gemessen); die Verdeckungssonde hielt F2 an sechs von sieben Stellen, C1 bei 270 m war schon in der Basis
  verdeckt."""
s = s.replace(" PLATZHALTER_ABW", abw)
issue = """7. **A-17 (2) „nichts über 0,5 m in der Hülle“ braucht einen Fußabdruck**, die Schnittstelle ist ein Punkttest am
   Fuß, und der Builder, der ihn ruft, gehört einem anderen Paket (R7c). Gemessen: 5.832 Requisiten ragen mit Vorderkante
   oder Krone hinein (Basis 1.124, bis 19 m tief). Vorschlag: der Aufruf mit `reach`/`half_len` wird Pflicht für jeden
   Builder, der Objekte breiter als 1 m an den Kurvenkorridor stellt (Requisiten, Station).
"""
s = s.rstrip("\n") + "\n" + issue
open(p, "w", encoding="utf-8").write(s)
print("ok")
