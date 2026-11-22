import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rows = """| `vergleich/S0_start_kiel_high.jpg` | **die große Eiche links am Start ist zurück** (Basis: leer, nur das Windrad dahinter) | wie Arcade |
| `vergleich/Muenchen_high.jpg` | **die rosa Häuserzeile links ist zurück** (Basis: links leerer Platz bis zur Skyline) | dieselbe Straßenschlucht wie Arcade, Modern mit Licht/Schatten – besser als Arcade |
| `vergleich/Belgrad_km187_high.jpg` | **rechts die Häuserzeile und die Pappel vorn rechts sind zurück** (Basis: rechts leere Wiese) | Komposition wie Arcade; die Pappel rechts steht in beiden Modi |
| `vergleich/Hannover_km142_high.jpg` | **das große Eckhaus links ist zurück** (Basis: nur ein fernes Haus) | Komposition wie Arcade |
| `vergleich/Lyon_km297_high.jpg` | im Ausschnitt gleich (die 4 zurückgekehrten Stücke der Zählung stehen hinter der Kamera/außerhalb) | Komposition wie Arcade, Modern feiner |
| `bilder/Bern_high_ab_00.jpg`, `bilder/Nuernberg_high_ab_00.jpg` | keine Änderung zu erwarten (Zählung 5→5 und 7→7, gleicher Stand ⇒ gleiches Bild; Basis nicht neu gemacht) | Altstadtgassen wie Arcade, die engen Kurven bleiben in der Innenseite frei |
| `vergleich/R1_belgrad_sofia_km340_high.jpg` | **Grenzdach Belgrad → Sofia km 340 steht wieder auf vier Pfeilern** (Basis: Masten mit Abspannseilen); die Sichtlinien laufen 1,8–2,1 m innen, die Pfeilerfläche liegt bei 2,20 m | wie Arcade |
| `bilder/R2_high_ab_00.jpg` (Sofia → Belgrad km 55), `bilder/R3_high_ab_00.jpg` (Prag km 270), `bilder/R4_high_ab_00.jpg` (Kaunas km 90) | gleich: das Dach hängt weiter an Masten mit Seilen – der zweite Frontpfeiler stünde 3,6–12,8 m tief in den Sichtlinien | Abweichung von Arcade bleibt (A-18: dort hängt das Dach) |
| `bilder/R5_high_ab_00.jpg` (Testetappe km 64) | gleich: hängt an einem Mast mit Seilen | wie R2–R4 |

Die Pfeiler- und Mastlösung ist im Bild glaubhaft (keine schwebenden Teile); Arcade zeigt an R2–R5 Pfeiler, die in
Modern in den Sichtlinien der Kurve stünden.

**Alle Stellen (`props_back_pos.log`, 150 m voraus, alte → neue verdeckte Stücke):** T4 9 → 3 (von 12),
T3 4 → 2 (8), T1 5 → 1 (13), T2 8 → 0 (17), C1 6 → 5 (16), S4 5 → 3 (12), S0 1 → 0 (die Eiche), Lyon 7 → 3,
Bern 5 → 5, München 8 → 6, Nürnberg 7 → 7, Belgrad 10 → 6, Hannover 7 → 1.

PLATZHALTER_VERDECKUNG"""
s = s.replace("\n\nPLATZHALTER_BILDER", "\n" + rows)
open(p, "w", encoding="utf-8").write(s)
print("ok")
