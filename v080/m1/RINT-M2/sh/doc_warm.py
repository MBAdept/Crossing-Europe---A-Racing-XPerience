"""Doc update for warm_step(). usage: doc_warm.py <renderer-modern.md> <max ms> <avg ms> <budget ms> (decimal comma strings)"""
import sys

p, mx, avg, bud = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
t = open(p, encoding="utf-8").read()


def sub(old, new):
    global t
    assert t.count(old) == 1, old[:80]
    t = t.replace(old, new)


sub("""  Krümmungen; `canopy_job_rest()`: Spuren an jeder Kamerastelle, Fahrbahnkanten). `collect()` beginnt eine weitere
  Hälfte nur, solange der Aufruf weniger als `WARM_BUDGET_MS` (0,5 ms) gebraucht hat, für die Dächer bis
  `WARM_AHEAD_M` (600 m) voraus. Die Dächer einer Station teilen Schilder, Krümmungen und Kamerastellen über den Cache des
  Bausteins („_signs“, „_curve“, „_lanes“): das erste Dach einer Station kostet zwei Hälften zu je 1,1–1,5 ms, jedes
  weitere 0,2–0,6 ms (gemessen, Testetappe „Steam Deck“).""",
    """  Krümmungen; `canopy_job_rest()`: Spuren an jeder Kamerastelle, Fahrbahnkanten), für die Dächer bis `WARM_AHEAD_M`
  (600 m) voraus. Die Dächer einer Station teilen Schilder, Krümmungen und Kamerastellen über den Cache des Bausteins
  („_signs“, „_curve“, „_lanes“). Mit kalten Caches kostete das erste Dach einer Station zwei Hälften zu je 1,1–1,5 ms
  (2,4 ms in einem `collect()`); darum erzeugt `warm_step()` vor der ersten Hälfte die Strecke so weit, wie
  `signs_behind()` sie braucht (`WARM_GEN_SEGS` = 6 Segmente je Stück, Fortschritt im Cache „_gen“), und füllt die Caches
  der Schilder und Kamerastellen – Stück für Stück, bis der Aufruf `WARM_BUDGET_MS` (%s ms) gebraucht hat, mindestens
  ein Stück je Aufruf. Eine Hälfte beginnt nur innerhalb dieser Zeit. Die Werte sind dieselben, die die Hälften selbst
  rechnen (Unit-Test `test_station_warm_step_prepares_what_the_halves_read`).""" % bud)
sub("""  vorher bis 3,4 ms (inline) bzw. 8,0 ms (erster Arbeitsfaden-Stand), jetzt höchstens 2,4 ms, Mittel 0,14 ms (§17.10).""",
    """  vorher bis 3,4 ms (inline) bzw. 8,0 ms (erster Arbeitsfaden-Stand), 2,4 ms mit kalten Caches, mit `warm_step()`
  höchstens %s ms, Mittel %s ms (§17.10).""" % (mx, avg))
sub("""- Tankstelle: `collect()` höchstens 2,40 ms auf „Deck“ (Ziel 2 ms; das erste Dach einer Station, §17.5).
""", "" if float(mx.replace(",", ".")) < 2.0 else
    """- Tankstelle: `collect()` höchstens %s ms auf „Deck“ (Ziel 2 ms, §17.5). Höchstwerte eines Laufs streuen auf der
  belasteten VM stark (Requisiten in vier Läufen 0,12 / 0,34 / 0,70 / 4,19 ms) – Mittel sind belastbar, Höchstwerte nur
  über mehrere Läufe.
""" % mx)
sub("""| `test_static_lamp_energy_is_read_every_frame` |""",
    """| `test_station_warm_step_prepares_what_the_halves_read` | `unit/race3d/test_structures.gd` | `warm_step()` in Stücken (eines je Aufruf), danach derselbe Entscheid wie mit kalten Caches auf einer zweiten Strecke | – | – |
| `test_static_lamp_energy_is_read_every_frame` |""")
open(p, "w", encoding="utf-8").write(t)
print("ok")
