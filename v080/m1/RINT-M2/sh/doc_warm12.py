import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()


def sub(old, new):
    global t
    assert t.count(old) == 1, old[:80]
    t = t.replace(old, new)


sub("""Krümmungen; `canopy_job_rest()`: Spuren an jeder Kamerastelle, Fahrbahnkanten), für die Dächer bis `WARM_AHEAD_M`
  (600 m) voraus.""", """Krümmungen; `canopy_job_rest()`: Spuren an jeder Kamerastelle, Fahrbahnkanten), für die Dächer bis `WARM_AHEAD_M`
  (1200 m) voraus.""")
sub("""  ein Stück je Aufruf. Eine Hälfte beginnt nur innerhalb dieser Zeit. Die Werte sind dieselben, die die Hälften selbst
  rechnen (Unit-Test `test_station_warm_step_prepares_what_the_halves_read`).""",
    """  ein Stück je Aufruf. Eine Hälfte beginnt nur innerhalb dieser Zeit. Die Werte sind dieselben, die die Hälften selbst
  rechnen (Unit-Test `test_station_warm_step_prepares_what_the_halves_read`). Weil die Strecke nur noch in Stücken
  erzeugt wird, darf der Vorlauf 1200 m sein; so bleiben genug Aufrufe, bis das Stück eines Dachs gebraucht wird.""")
sub("""- Verworfen (gemessen): 2000 m Vorlauf – das Sammeln ließ die Strecke 1,4 km zu früh erzeugen (18 ms in einem Bild);
  Korridor-Merker beim Sammeln – das Geländeprofil rechnete seine Zeilen 600 m voraus (bis 17 ms).""",
    """- Verworfen (gemessen): 2000 m Vorlauf ohne `warm_step()` – das Sammeln ließ die Strecke 1,4 km auf einmal erzeugen
  (18 ms in einem Bild); Korridor-Merker beim Sammeln – das Geländeprofil rechnete seine Zeilen 600 m voraus (bis
  17 ms); `warm_step()` mit 600 m Vorlauf und 0,7 ms je Aufruf – ein Dach war beim Stück noch nicht fertig (8,7 ms).""")
sub("""  vorher bis 3,4 ms (inline) bzw. 8,0 ms (erster Arbeitsfaden-Stand), 2,4 ms mit kalten Caches, mit `warm_step()`
  höchstens 2,08 ms, Mittel 0,12 ms (§17.10).""",
    """  vorher bis 3,4 ms (inline) bzw. 8,0 ms (erster Arbeitsfaden-Stand), 2,4 ms mit kalten Caches, mit `warm_step()` und
  600 m Vorlauf 2,08 ms, mit 1200 m **höchstens 1,36 ms, Mittel 0,11 ms**; alle neun Dächer beim Stück fertig (der
  Rest dort 0,02–0,18 ms), keines inline (§17.10). Ein Lauf auf einer VM neben einem zweiten Paket: Höchstwerte
  streuen dort stark (Requisiten in vier Läufen 0,12–4,19 ms ohne Änderung), Mittel sind belastbar.""")
sub("""- Tankstelle: `collect()` höchstens 2,08 ms auf „Deck“ (Ziel 2 ms, §17.5). Höchstwerte eines Laufs streuen auf der
  belasteten VM stark (Requisiten in vier Läufen 0,12 / 0,34 / 0,70 / 4,19 ms) – Mittel sind belastbar, Höchstwerte nur
  über mehrere Läufe.
""", """- `collect()` je Baustein auf „Deck“ nur in einzelnen Läufen auf der belasteten VM gemessen (Tankstelle 1,36 ms,
  Höchstwerte anderer Bausteine streuen bis 4,19 ms) – auf dem Gerät nicht gemessen.
""")
open(p, "w", encoding="utf-8").write(t)
print("ok")
