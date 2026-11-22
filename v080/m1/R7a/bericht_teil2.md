## 4. Bilder (angesehen, ehrlich gegen Arcade und gegen die Basis)

Alle mit `tools/ab_shot.sh` / `tools/ab_sheet.sh` (gleicher Simulationsstand, links Arcade, rechts Modern), Tag.
Die Bögen T1–T4, C1, S4 sind mit genau den Befehlen der Bögen von RINT-M2 gemacht – deren Bilder
(`deliver/RINT-M2/ab_boegen/*`) sind die Basis. Dreierbilder Arcade | Modern Basis | Modern R7a in `vergleich/`.

| Bild | Was sich gegen die Basis ändert | gegen Arcade |
|---|---|---|
| `vergleich/T2_hoch_arcade_basis_r7a.jpg` | **die ganze linke Baumgruppe ist zurück** (Eichen, Fichten, Laubbäume an der Innenseite der Autobahnkurve); in der Basis standen dort nur Bodendecker-Büschel auf leerem Gras | jetzt dieselbe Komposition wie Arcade, mit echten, schattierten Modellen – **klar besser als Arcade** |
| `vergleich/T1_hoch_arcade_basis_r7a.jpg` | links zwei Fichten zurück (Arcade hat sie an derselben Stelle) | nahe große Fichte ganz links fehlt weiter (liegt außerhalb des Modern-Ausschnitts – der Blick in die Kurve, kein Korridor) |
| `vergleich/T4_hoch_arcade_basis_r7a.jpg` | rechts eine Felsgruppe und eine Fichtengruppe zurück | Innenseite der Kehre nah am Wagen weiter frei (dort laufen die Sichtlinien bis 118 m) |
| `vergleich/T3_hoch_arcade_basis_r7a.jpg` | links hinten eine Felsgruppe zurück | Arcades Felsen innen in der Kurve (links, 60–120 m) fehlen weiter – sie stehen in den Sichtlinien |
| `vergleich/C1_hoch_arcade_basis_r7a.jpg` | gleich | Arcades großer Parkbaum rechts fehlt weiter: in Städten ist L = 300 m, der Baum steht in den Sichtlinien der Rechtskurve |
| `vergleich/S4_hoch_arcade_basis_r7a.jpg` | in diesem Ausschnitt gleich (die 2 zurückgekehrten Häuser der Zählung stehen außerhalb des Bilds) | – |
| `vergleich/S0_start_kiel_high.jpg` | **die große Eiche links am Start ist zurück** (Basis: leer, nur das Windrad dahinter) | wie Arcade |
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

**Verdeckungssonde (gemessen, `probe/qa_occl.gd` von FIX-M2, rotes Testauto in drei Spuren bei 25–270 m, „Hoch“,
Pixel, die sich gegen das Bild ohne Auto ändern; sichtbar ab 12 px; verlangt bis min(L, 270 m)):**

| Stelle | L | kleinste Pixelzahl bis zur verlangten Entfernung (R7a) | Basis | Ergebnis |
|---|---|---|---|---|
| T4 Saragossa – Pau km 198,8 | 118 m | 255 px bei 85 m (165 px bei 120 m) | gleich (alle Werte bis 150 m identisch) | gehalten; bei 200 m Spur +1 jetzt 54 px statt 127 px (zurückgekehrte Felsgruppe, jenseits von L) |
| T3 km 172,8 | 119 m | 267 px bei 85 m (161 px bei 120 m) | identisch in allen 21 Messungen | gehalten |
| T1 Kassel – Würzburg km 46,5 | 263 m | 27 px bei 200 m (14 px bei 270 m) | – | gehalten |
| T2 km 61,9 | 300 m | 22 px bei 270 m | – | gehalten |
| S0 Kiel km 0 | 300 m | 20 px bei 270 m | – | gehalten |
| S4 Kiel – Hamburg km 80 | 300 m | 18 px bei 270 m | – | gehalten |
| C1 Dortmund – Frankfurt km 221 | 300 m | 30 px bei 200 m; **bei 270 m 6/0/0 px** | **6/9/0 px** | bei 270 m schon in der Basis verdeckt (rechts ein Mietshaus an der Kurveninnenseite); R7a nimmt Spur 0 die letzten 9 px |

C1 genauer (`probe/c1_props.gd`): das Auto bei 270 m steht hinter zwei Häusern der Kurveninnenseite. Das vordere
(`city_german_mietshaus`, 219 m voraus) steht in Basis und R7a: sein Fuß liegt 18,0 m jenseits des Banketts, knapp
außerhalb des alten Bands (18,0 m), seine Vorderkante aber 2,6 m jenseits – 2,8 m tief in der Hülle. Das zweite
(`city_german_gruenderzeit`, 246 m) kommt mit R7a zurück: Fuß 16,6 m (Hülle 2,9 m), Vorderkante 1,2 m – 1,7 m tief in
der Hülle. Ursache: der Requisiten-Builder prüft nur den Fuß (siehe §2 „Fußabdruck“, `notes_for_next`).


**Clip** `clips/saragossa_pau_bergkurven_km197.mp4` (20 s, `tools/ab_clip.sh`, „Hoch“, Saragossa – Pau ab km 197,0,
links Arcade, rechts Modern; Standbilder bei 3/8/13/18 s angesehen): die Kurveninnenseiten bleiben frei, Felsgruppe und
Fichtengruppe stehen wie in Arcade (bei 13 s die Felsgruppe rechts sogar dichter), die Tankstelle am Ende gleich. Zwei
nahe Fichten, die Arcade bei 3 s und 8 s rechts an der Außenseite zeigt, fehlen in Modern – die Außenseite einer
Linkskurve liegt im S-Bogen in den Sichtlinien der vorigen Rechtskurve (nicht einzeln nachgemessen, abgeleitet).
Ob Requisiten ploppen, lässt sich aus vier Standbildern nicht sagen; der Korridor wird vor dem Sammeln eines Stücks vorgerechnet und ändert sich danach nicht (abgeleitet aus dem Code).

**Mittel:** `bilder/{S0,Muenchen,Belgrad,Hannover,R1}_medium_ab_00.jpg` zeigen dieselben Kompositionen wie „Hoch“.

**Goldens Modern** (§6): die vier geänderten Bilder angesehen (`vergleich/goldens/`) – nur zurückgekehrte Requisiten.
