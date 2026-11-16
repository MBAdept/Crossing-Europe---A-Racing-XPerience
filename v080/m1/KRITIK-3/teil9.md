## 9. Abweichungen und Grenzen dieser Prüfung

- **Import-Cache:** Die Kopie trägt den Import-Cache des AS3-Arbeitsbaums statt eine Kopie aus dem Haupt-Checkout. Er
  ist für be866d2 schon importiert; `godot --import` lief danach in 5 s ohne Fehler.
- **Keine Gates:** `run_tests.sh` und `golden.sh check` habe ich nicht laufen lassen. Diese Prüfung ändert keinen Code;
  die Vorstart-Regel verlangt sparsame Last. Die Gate-Ergebnisse von AS3 sind nicht nachgeprüft, nur der Prüfer.
- **Licht der Prüfbilder:** Nachtbilder der Prüfszene haben keine Scheinwerfer. Das Urteil zur Nacht stützt sich auf
  das Rennbild.
- **Hang:** Der Test ist eine um die Straßenachse gekippte Ebene mit 30°, nicht das Gelände des Spiels.
- **Flimmern:** Der Viertel-Pixel-Test ist ein Ersatzmaß; dazu Film und Folgebilder angesehen.
- **Überzeichnung:** nicht neu gemessen. AS3 hat 1,5–9,7 Laub-Fragmente je gedecktem Pixel in 20 m gemessen
  (Pappel 9,7×, Fichte 8,7×). Was das auf einer echten Grafikkarte oder dem Steam Deck kostet, ist gefolgert, nicht
  gemessen.
- **Wirkung auf Spieler:** „stundenlang ansehbar“ ist ein Urteil nach Bildern und einem 2-s-Film, kein Spieltest.

## 10. Werkzeuge und Rohdaten (Arbeitsordner, nicht eingecheckt)

- `m1/KRITIK-3/tools_kritik/kritik_scene.gd`, `vertex_data.gd`, `stage_sets.gd` (mit `--list=<set,…>|all`) – Prüfmodi und Zensus (Abschnitt 2)
- `m1/KRITIK-3/run_dist.sh`, `kritik.sh`, `batch_*.sh` – die Läufe; `py/*.py` – Bögen
- `m1/KRITIK-3/logs/` – Messausgaben: `levels_h12/h19.5/h23.log` (PEGEL/SPRUNG), `sparkle.log` (FLIMMER),
  `umriss/u.log` (UMRISS), `lods_check.log` (UMSCHALT), `vertex_data.log` (DATEN), `validate.log`, `census_kh.txt`
- `m1/KRITIK-3/ab/` – Rohbilder der neun Rennläufe; `m1/KRITIK-3/shots/` – alle Prüfbögen (die Einzelbilder der Fahrt sind gelöscht; der Film liegt im Lieferordner)
