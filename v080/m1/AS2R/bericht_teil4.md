## 4. Selbstprüfung Lkw, Bus, Polizei (Modelle von AS2b)

Geprüft wie die Kritik die Pkw: Spielkamera 20 / 60 / 150 m bei Tag und nachts (Rücklicht, Bremse + Blinker,
Rücklicht + Blaulicht A) neben dem Arcade-Quader bzw. -Sprite, mit Renn-Look (Kontaktbogen `--chase --arcade`, jetzt
mit wirksamem Look); jede Lampe einzeln nachts; Tagbogen aller Stufen; Stufenwechsel mit dem Werkzeug der Kritik an
den Wechselabständen der Modelle (Lkw und Bus 60 / 180 m, Polizei 40 / 120 m). Modelle: Koffer-, Planen- und
Autotransporter-Sattelzug, Bus, Polizei Deutschland, Belgien, Italien, Österreich, Niederlande (Tag alle 18).

**Was stimmt (gesehen, Bögen `h_*` und `08_kontaktbogen_polizei_tag.jpg`):** Hecks in 20 m in Lage und Farbe wie
Arcade: Rückleuchten, Kennzeichen, Konturmarkierung, Verschlussstangen und Unterfahrschutz (Lkw), Lüftungsgitter und
Heckscheibe (Bus), Lichtbalken mit Kuppeln und Heckwort (Polizei). Die Aufbauten sind bei Tag heller als der
Arcade-Quader (Belichtung wie A1). Nachts sind Rück-, Brems-, Blink- und Kennzeichenlicht getrennt, die
Konturmarkierung leuchtet, Blaulicht A links und B rechts schalten einzeln, und der Lichtbalken leuchtet in allen
Stufen an derselben Stelle. In 150 m sind alle als Umriss mit Rückleuchten lesbar. Der Planen-Sattelzug wechselt
praktisch unsichtbar.

**Gefunden und behoben:**

1. **Weiß der Polizei** (wie B1): 16 der 18 Lackierungen sind weiß oder fast weiß und kamen als reines Weiß ohne
   Form heraus – jetzt mit `_tone` begrenzt wie Lkw, Bus und Verkehr.
2. **Heck der Polizei in `lod2`:** Die Normalenregel machte die ganze Rückseite der Kabine samt Säulen dunkel (wie
   B2). Jetzt die Heckscheibe nach der Kontur des Entwurfs (`far_windows="rear"`); Tschechien behält wegen des
   Budgets die Normalenregel.
3. **Karoband der Polizei in der Ferne (neu):** Das linear gemittelte Band kam mit dem Renn-Look 27–33 Stufen heller
   heraus als die Karos daneben; jetzt Potenzmittel (`CHECK_MEAN_EXP` 0,6). Belgien, 120 m, Mittel über das Band:
   `lod2` (201, 201, 136) gegen `lod1` (174, 178, 125) -> (171, 180, 121) gegen (173, 178, 124), gemessen.
4. **Scheiben von Bus und Lkw in den fernen Stufen (wie B4, neu):** Sie waren als `vpbr` dunkler als das Glas von
   `lod0`; die Heckscheibe des Busses änderte beim Wechsel bei 60 m 43 % ihrer Pixel. Jetzt die ferne Scheibenfarbe des
   Verkehrs (`truck3d.GLASS_FAR`): Heckscheibe in 60 m `lod0` (78, 97, 121), `lod1` vorher (59, 77, 100), jetzt
   (73, 93, 119).
5. **Kennzeichen der fernen Stufen** der Polizei (über `traffic3d.FAR_PLATE`, Abschnitt 2).

**Stufenwechsel** (gemessen, Spielkamera 1280 × 720, Tag, Renn-Look; Anteil der Fahrzeugpixel, die sich um mehr als
24 Stufen ändern):

| Modell | nah | fern | AS2b (ohne Look, zum Vergleich) |
|---|---|---|---|
| `police/de` | 40 m: 14,3 % | 120 m: 20,4 % | 13,8 / 35,6 % |
| `police/be` | 40 m: 19,9 % | 120 m: 38,1 % (Band jetzt gleich hell, Abschnitt 5) | 18,8 / 59,0 % |
| `police/ch` | – | 120 m: 33,6 % | – |
| `traffic/bus` | 60 m: 11,0 % -> 6,8 % | 180 m: 21,1 % -> 21,7 % (beide Stufen mit der neuen Scheibe) | 6,7 / 23,2 % |
| `traffic/truck_tarp` | 60 m: 2,2 % (unverändert, von hinten keine Scheibe) | 180 m: 1,1 % | 2,4 / 1,2 % |

Die Zahlen von AS2b sind ohne Renn-Look gemessen (C2) und nur grob vergleichbar. Bei 40 m bleiben bei der Polizei
vor allem Kennzeichenzeichen, Wörter und der Lichtbalken, die es nur in `lod0` gibt; bei 120 m die Karos (jede Zelle
ein Pixel, gelb oder blau, gegen ein einfarbiges Band – die Zählung misst dort Textur, nicht Helligkeit).

**Offen (gemessen, begründet):**

- Lichtbalken: Die Glaskuppel von `lod0` ist bei Tag heller als die Blöcke von `lod1` (`lamp_off`, Renderer;
  Abschnitt 3).
- Bus bei 180 m (21 %): vor allem die zwei breiten Gitterstäbe von `lod2` gegen die sechs feinen von `lod1`, die in
  zweieinhalb Pixeln zu einem Grau verschwimmen. Eine Fläche in der Mischfarbe ginge nicht (die Lackfarbe kommt je
  Set aus dem Lack-Slot), drei schmalere Stäbe kosten Dreiecke, und `lod2` liegt auf 1 500 / 1 500.
- Kennzeichen von Lkw und Bus in `lod2` (`heavy3d.FAR_PLATE` `#c4c4c1`): nicht an den Pkw-Wert angeglichen (ab
  180 m ein bis zwei Pixel).
