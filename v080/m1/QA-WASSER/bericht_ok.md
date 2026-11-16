- Prüfsummen der Archive und von `LIZENZEN.txt` (OK); Archivinhalt genau Programm + `LIZENZEN.txt`, Ausführbar-Recht im
  Linux-Archiv; Größen wie berichtet (gemessen).
- `BUILDINFO.txt`: Commit `0ad9012…`, 0.8.0-zs1, Nutzerordner `crossing-europe-zwischenstand`; dieselben Werte im
  eingebetteten `project.binary` (gemessen).
- Der Build ist genau `0ad9012`: frischer Export des Spielpakets aus dem sauberen Worktree = gelieferte Pakete in
  1.010 von 1.011 Dateien, anders nur `project.binary` (Testbuild-Einstellungen); gegen den vorigen Build nur
  `far_ground.gdc` anders (gemessen).
- Start Kiel – Hamburg bei km 0: Auto im Countdown sichtbar an Arcades Platz (Rahmen ±1 px quer, ≤ 5 px hoch), auch
  1,5 s nach „LOS!“, Linux und Windows (gemessen).
- Köhlbrandbrücke km 77,5–80,9, Tag und Nacht, „Hoch“ und „deck“: Elbe unter und neben der Brücke, Fähren auf dem
  Wasser, keine Grube, keine Naht; 0 Löcher unter dem Horizont in der Debug-Ansicht (gemessen).
- Absenken der Scheibe bei km 67,1: kein Sprung – gegen den alten Stand ändern sich nur 5 Zeilen am Horizont, ≤ 0,21 %
  der Bildpunkte, allmählich über 0,3 s (gemessen); Gleiten mit höchstens 0,35 m je Meter (gerechnet mit der Ebene).
- Anfahrt ab km 76,5: Elbe durchgehend sichtbar, nichts springt (gemessen).
- Elbbrücken: Wasser wie Arcade; Scheibe dort exakt alte Regel (gerechnet).
- Holtenau-Anfahrt mit 12,3 m tieferer Scheibe: alt gegen neu nur 10 Zeilen am Horizont, ≤ 0,23 %, mit dem Auge nicht zu
  unterscheiden; 0 Löcher (gemessen).
- Holtenauer Hochbrücke (ab Hamburg) und Ada-Brücke Belgrad: Wasser und Schiffe sichtbar (gemessen).
- Bergstrecke T4 (Pyrenäen): Lücken lesen sich als Land; Geländesperre an T1–T4, S1, C1 0,000 % Magenta (gemessen).
- Windows-Export unter Wine: Köhlbrandbrücke und Start pixelgleich mit dem Linux-Export (gemessen).
- Diff `3a23cb8..0ad9012`: nur die acht vorgesehenen Dateien, keine Arcade-Datei; die Scheibe liegt nie höher als
  vorher, kann also nichts verdecken (F7); keine Rückwirkung auf die Simulation (gelesen).
- Unit-Test `test_far_ground_water.gd`: 4/4 grün; erkennt alle vier eingebauten Fehler (gemessen).
- Arcade-Identität: `tools/golden.sh check` 20 von 20 und 17 von 17 identisch (gemessen).
- Nutzerdokumente: Dateinamen, Version, Nutzerordner, Menüpunkte, Leistungstest, Rennen Kiel – Nürnberg, Absturzfrage
  stimmen; schlichtes Deutsch, keine internen Kürzel.
