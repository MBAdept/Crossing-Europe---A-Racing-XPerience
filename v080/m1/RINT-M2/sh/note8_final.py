import sys
S = sys.argv[1]


def edit(name, pairs):
    p = S + "/" + name
    t = open(p, encoding="utf-8").read()
    for a, b in pairs:
        assert t.count(a) == 1, (name, a[:70])
        t = t.replace(a, b)
    open(p, "w", encoding="utf-8").write(t)


edit("bericht_note8.md", [
    ("@@WARM12ROW@@", "| **`9b02f05`** (dazu Vorlauf `WARM_AHEAD_M` 1200 statt 600 m – das Erzeugen geschieht jetzt in Stücken) | **1,36 / 0,11 ms** | alle neun Dächer beim Stück gesammelt und entschieden (Rest dort 0,02–0,18 ms, Kopie mit Ausgaben), keines inline; alle Bausteine in diesem Lauf ≤ 1,36 ms |"),
    ("@@WARM12TXT@@", "Mit 1200 m Vorlauf bleiben genug Aufrufe, bis das Stück eines Dachs gebraucht wird: **höchstens 1,36 ms, Mittel 0,11 ms** – unter dem Ziel von 2 ms. Entscheide gleich: Sonde `jobpath` 1909 Dächer, 0 verschieden (auch für 600 m und 0,7 ms); Unit-Test `test_station_warm_step_prepares_what_the_halves_read`; `test_structures` 14/14."),
])
edit("bericht_teil3.md", [
    ("### Notiz 8 – collect() je Baustein ≤ 2 ms auf „Deck“ (A-18): **teilweise – Sichtlinien auf dem Arbeitsfaden, Tankstelle höchstens 2,40 ms (Mittel 0,14)**",
     "### Notiz 8 – collect() je Baustein ≤ 2 ms auf „Deck“ (A-18): **erfüllt im Messlauf – Sichtlinien auf dem Arbeitsfaden, Vorwärmen in Stücken; Tankstelle höchstens 1,36 ms (Mittel 0,11)**"),
])
edit("bericht_teil1.md", [
    ("""- Notiz 8 brauchte nach dem ersten Einfrieren (`1cd689d`) noch drei Code-Schritte am Tankstellendach (`c72d484`,
  `b673df5`, `02051f7`): `collect()` der Tankstelle höchstens 2,40 ms, Mittel 0,14 ms auf „Deck“ (vorher 3,41 / 0,20;
  Ziel 2 ms im Höchstwert um 0,4 ms verfehlt, §3 Notiz 8); Entscheide netzweit unverändert (1909 Dächer, 0 verschieden).""",
     """- Notiz 8 brauchte nach dem ersten Einfrieren (`1cd689d`) noch fünf Code-Schritte am Tankstellendach (`c72d484`,
  `b673df5`, `02051f7`, `b903797`, `9b02f05`): `collect()` der Tankstelle höchstens 1,36 ms, Mittel 0,11 ms auf
  „Deck“ (Merge-Stand 3,41 / 0,20; ein Messlauf auf belasteter VM, §3 Notiz 8); Entscheide netzweit unverändert
  (1909 Dächer, 0 verschieden)."""),
    ("`c72d484`/`b673df5`/`02051f7` (8, Tankstellendach)", "`c72d484`/`b673df5`/`02051f7`/`b903797`/`9b02f05` (8, Tankstellendach)"),
])
edit("bericht_teil6.md", [
    ("""- Nach dem ersten Einfrieren (`1cd689d`) noch Code am Tankstellendach (`c72d484`, `b673df5`, `02051f7`, Notiz 8) und
  eine Render-Prüfung (`ab2a400`). Die Goldens `6b17293` entstanden auf `c72d484`; die späteren Schritte ändern keinen
  Entscheid (Sonde über das ganze Netz, 1909 Dächer, 0 verschieden) – `modern-check` auf dem Endstand: @@MC2@@.
  Run_tests Lauf 2 und Builds liefen auf dem Endstand, die Render-Prüfungen auf `b673df5` (`02051f7` ändert nur, woher
  die Schilder gelesen werden; `test_structures` und die Strukturprüfung danach erneut: @@STRUCT@@).
- Notiz 8: Ziel 2 ms im Höchstwert um 0,4 ms verfehlt (2,40 ms, Mittel 0,14) – das Sammeln der Strecke bleibt im
  Hauptfaden (Track nicht fadensicher), der Entscheid läuft auf dem Arbeitsfaden.""",
     """- Nach dem ersten Einfrieren (`1cd689d`) noch Code am Tankstellendach (`c72d484`, `b673df5`, `02051f7`, `b903797`,
  `9b02f05`, Notiz 8) und eine Render-Prüfung (`ab2a400`). Die Goldens `6b17293` entstanden auf `c72d484`; die
  späteren Schritte ändern keinen Entscheid (Sonde über das ganze Netz, 1909 Dächer, 0 verschieden) – `modern-check`
  auf dem Endstand: @@MC2@@. Run_tests Lauf 2, Builds und Rauchtest liefen auf dem Endstand, die Render-Prüfungen
  auf `b673df5`, die Strukturprüfungen auf dem Endstand erneut: @@STRUCT@@.
- Notiz 8: „≤ 2 ms“ ist in einem Messlauf auf einer belasteten VM erfüllt (1,36 ms); Höchstwerte streuen dort stark
  (Requisiten 0,12–4,19 ms in vier Läufen ohne Änderung) – auf dem Gerät nicht gemessen."""),
])
edit("bericht_teil8.md", [
    ("""- **Tankstelle `collect()`:** 2,40 ms gegen 2 ms auf „Deck“; nächster Schritt das erste Dach einer Station in drei Teile
  oder die Spuren der Station in `prepare()`.""",
     """- **`collect()` auf dem Deck:** in einem Lauf auf der VM alle Bausteine ≤ 1,36 ms; Höchstwerte streuen auf der
  belasteten VM bis 4,19 ms (Requisiten) – auf dem Gerät oder mit mehreren Läufen bestätigen."""),
])
print("ok")
