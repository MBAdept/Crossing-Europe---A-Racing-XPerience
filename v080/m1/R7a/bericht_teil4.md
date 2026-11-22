## 7. Abweichungen

- **`tests/unit/race3d/test_props.gd` angefasst** (nicht meine Datei, R7c): die Vorlage von
  `test_bend_corridor_and_density` von Stück 16 (Bogenmitte, Hülle 10 m) nach Stück 13 (Bogenbeginn, Hülle 37–43 m)
  verschoben – Zeilen 449–458, sonst rot. Prüfinhalt unverändert. Beim Zusammenführen mit R7c auf diese Hunk achten.
- **Aufrundung am Kurvenende:** wo eine Sichtlinie die Straße verlässt, ist der Korridor mindestens schlichter Streifen
  + 0,55 m (6,05 m jenseits des Banketts), auch wenn die Sichtlinien dort nur z. B. 1 m weit laufen. Grund: die
  Station (`station.gd`, nicht meine Datei) und `ChunkContext.in_bend_corridor()` zählen einen Korridor erst ab Streifen
  + 0,5 m als Kurvenkorridor; ohne Aufrundung stünde dort, wo die Sichtlinien knapp jenseits des Banketts laufen, ein
  Baum oder ein Pfeiler in ihnen. Nur der Grenz-Builder prüft gegen die genaue Hülle (A-18 verlangt es dort).
- **Kamera auf jeder Reihe** (statt jeder zweiten/vierten): gröbere Abtastung verfehlt Knicke der Hülle um bis zu 1–3 m
  (gemessen) – der Preis sind ~0,1–0,3 ms Rechenzeit je gefahrener Reihe (verteilt, §5).
- **`modern_sight` normal 39 s statt ~18 s** (unabhängige Referenz der Hülle + Rechnung des Kerns für 103.583
  Segmente unter Last 15); `--full` entsprechend länger (§6).
- **Bilder „Mittel“ nicht an jeder Stelle:** „Mittel“ an T1–T4, C1, S4 (Bögen), S0, München, Belgrad, Hannover und
  dem Grenzdach R1; Lyon, Bern, Nürnberg und R2–R5 nur „Hoch“ (jeder Lauf 3–8 min unter Last 13–16). Die Mittel-Bilder
  zeigen dieselben Kompositionen wie „Hoch“ (Starteiche, Häuserzeilen, Dach auf Pfeilern).
- **Gates auf drei Ständen:** die vollen Läufe auf `e81886a`, der zweite `run_tests.sh` auf `b3f1b67`, der Endstand
  `509bb16` mit gezielten Läufen (§6). Nach dem zweiten vollen `run_tests.sh` kam noch eine Code-Änderung (`7d8bbb6`,
  Vorrechnen bis hinter die Wahrzeichen – gefunden erst im Leistungslauf); ein dritter voller Lauf war nicht erlaubt.
- **Fußabdruck nicht im Requisiten-Builder behoben:** `builders/props.gd` gehört R7c; die Prüfung mit Reichweite ist
  gebaut und getestet, der Aufruf fehlt (§2). Bis dahin ragen 5.832 statt 1.124 Requisiten mit Vorderkante oder Krone in
  die Hülle (gemessen); die Verdeckungssonde hielt F2 an sechs von sieben Stellen, C1 bei 270 m war schon in der Basis
  verdeckt.

## 8. Vertragsfragen (mit Beleg)

1. **„a short bend gets the sagitta of its real arc“ (A-17)** stimmt mit der Hülle der Sichtlinien nicht: Sichtlinien
   der Länge L, die auf den Geraden davor beginnen, schneiden die Ecke. Kurzer Bogen 60 m, R = 150 m, L = 300 m: Hülle
   22,5 m jenseits des Banketts, eigene Pfeilhöhe des Bogens −1,4 m (er verlässt die Straße gar nicht), altes Band
   74 m. Gebaut ist die Hülle (der Hauptsatz von A-17); die Klammer-Erwartung ist so nicht haltbar.
2. **„a straight before a bend is free“** gilt nur jenseits der Sichtlinien, die in die Kurve laufen (bis L vor dem
   Kurvenbeginn). Wegen der Bremshüllkurve ist die Anfahrt schnell und L lang: am Kurvenbeginn ist der Korridor oft
   breiter als in der Kurvenmitte (Autobahnbogen R = 200 m: Beginn 37–43 m, Mitte 10 m).
3. **Stadtkurven:** der F2-Bedarf kennt kein Tempolimit (schnellste fahrbare Geschwindigkeit), L bleibt in Städten
   300 m. Bern und Nürnberg bekommen kein Haus zurück, München 2 von 8, S4 2 von 5. Soll in den City Limits ein
   Bedarf aus dem Tempolimit (mit Zuschlag) gelten, käme deutlich mehr zurück – Entscheidung der Leitung (die
   Fairness-Regel F2 ist dann aber nicht mehr „schnellste fahrbare Geschwindigkeit“).
4. **A-18 „5 of 48 roofs“:** auf dieser Basis hängen 4 der 48 Dächer der Rennetappen (gemessen, `border_roofs.log`)
   und das Dach der Testetappe (Bild R5) – zusammen 5, aber nicht „von 48“; neu 3 + Testetappe.
5. **A-18 „modern_slice.* gehört der Montage, Pakete erzeugen es nicht neu“** gegen den Auftrag „modern-make where a
   Modern golden changed on purpose“: nicht neu erzeugt (A-18 ist die jüngere, genauere Regel); geänderte Bilder in §6.
6. **„camera in every lane“** ist mit Spurmitten gebaut (wie `modern_sight` F1-lanes); ein Auto auf dem Bankett ist
   nicht abgedeckt (die schnellste Linie fährt nicht dort).
7. **A-17 (2) „nichts über 0,5 m in der Hülle“ braucht einen Fußabdruck**, die Schnittstelle ist ein Punkttest am
   Fuß, und der Builder, der ihn ruft, gehört einem anderen Paket (R7c). Gemessen: 5.832 Requisiten ragen mit Vorderkante
   oder Krone hinein (Basis 1.124, bis 19 m tief). Vorschlag: der Aufruf mit `reach`/`half_len` wird Pflicht für jeden
   Builder, der Objekte breiter als 1 m an den Kurvenkorridor stellt (Requisiten, Station).
