**Lkw-Aufprall (KRITIK-R2-MESS M1).** V3 hielt beim Lkw nur knapp: Der 95-%-Wert aus 60 Unfällen ist selbst eine
Zufallsgröße, eine Abnahme mit neuen Zufallsfolgen konnte ohne jede Änderung am Klang scheitern. Werkzeug der Prüfung
(`kr_crash.gd`, Limousine mit 110 km/h auf Kiel – Hamburg km 15, 130 km/h Schließgeschwindigkeit, je 60 schwere
Unfälle gegen einen Lkw, Gesamtlautstärke 1,0; Bootstrap: 10 000 Ziehungen aus den gemessenen Unfällen – die Anteile
sind abgeleitet):

| `truck.heavy` | Folge | 95 % der Begrenzung | Unfälle > 3 dB | True Peak höchstens | Abnahmen mit 60 Unfällen > 3 dB (Bootstrap) |
|---|---|---|---|---|---|
| −11 (AU-R3), KRITIK-R2-MESS | 9312 | 2,66 dB | 3 von 60 | −1,21 dBTP | 35 % |
| −11, nachgestellt | 9312 / 9313 / beide | 2,78 / 2,72 / 2,78 dB | 2 / 2 / 4 von 120 | −1,23 dBTP | 14 % (über 120: 11 %) |
| **−11,5 (AU-R4)** | 9312 / 9313 / beide | **2,13 / 2,51 / 2,34 dB** | 1 / 1 / 2 von 120 | **−1,39 dBTP** | **2 %** (über 120: 0,5 %) |
| Pkw, `hit_heavy` −11,5 (zum Vergleich), KRITIK-R2-MESS | 9311 | 2,05 dB | 1 von 60 | −1,38 dBTP | 1,5 % |

Der Schlag des Lkw-Aufbaus liegt damit wie der eigene tiefe Schlag schwerer Unfälle bei −11,5 dB (vorher −11; AU-C1
−10). Er ist eine von vier Schichten, deren Pegel ohnehin je Unfall um ±2 dB gewürfelt wird; dass 0,5 dB weniger den
Charakter ändern, ist nicht zu erwarten (abgeleitet – gehört hat es niemand). Zusätzlich gehört in §11.2, V3 über
mindestens 120 Unfälle aus zwei Folgen zu beurteilen (Vorschlag der Prüfung): Ein 95-%-Wert aus 60 Unfällen streut um
0,3–0,4 dB (Bootstrap).
