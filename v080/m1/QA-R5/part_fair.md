## 3. Fairness (F1–F7) – gemessen

| Prüfung | Ergebnis |
|---|---|
| `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (Prüfling) | alle OK: F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappenrichtungen, erster Fall 280 m); F1 Außenspuren 0 bis 260 m in 326 680 500; F2 ≤ 0,593 / 0,596 / 0,555 (≤ 0,60); F3 0 von 5923 Zielen; F7 0 von 2 011 532 Querschnittsseiten; Modell 0 abweichend (144 s) |
| `… -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2064 m (≥ 2000) (57 s) |
| Brief Punkt 5 – Bauten von R5 (nicht Teil von `modern_sight`, das nur Kamera und Gelände kennt): eigener Netzlauf Abschnitt 2 | 0 Punkte von Tragwerk/Röhre/Portal über den Spuren zwischen 0,3 und 4,5 m in 122 Brücken + 28 Tunneln; Seile ≥ 2,15 m neben der Spur; Portalhügel nie über der Anfahrt im Sichtkorridor (F7) |
| Kappe und Tunnelwände (F1 „später sichtbar“) | Kappe bei `peek_m` 45 m nur für eine Kamera außerhalb (Shader `cam_tunnel_z`), wie Arcades `closed_from` – gleich wie Arcade, nicht später; Wände an der Bankettkante wie Arcades. In Kurven verdecken Arcades nähere Wandsegmente ferne Fahrzeuge genauso (Malerreihenfolge) – kein Nachteil gegen Arcade (abgeleitet aus dem Code, nicht gemessen). |
| Quaimauer-Abdeckung | Abdecksteine 0,16 m über Geländehöhe am Ufer, beginnend an der Bankettkante – formal über der Fahrbahnhöhe im 8-m-Korridor, aber 0,16 m können kein Fahrzeug (0,75 m) und kein Schild verdecken (abgeleitet). |

Das Kurvenkamera-Gesetz, die Steam-Deck-Stufe und der Musikpegel wurden nicht verändert und nicht bewertet (Vorgabe).
