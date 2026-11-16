## 5. Messungen

Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL, Renn-Look, Werkzeuge der Kritik), „vorher“ = Zahlen der
Kritik bzw. eigene Messung vor der Änderung.

**Stufenwechsel der Pkw** (Spielkamera 1280 × 720, MSAA 2×, Anteil der Autopixel, die sich um mehr als 24 Stufen
ändern; Farbsets wie die Kritik):

| Typ | 25 m | 40 m | 60 m | 90 m | 120 m | 160 m | Nacht 40 / 120 m |
|---|---|---|---|---|---|---|---|
| SUV | 4,8 -> 7,4 | 5,6 -> 6,8 | 5,6 -> 6,7 | 23,8 -> 12,8 | 32,3 -> 29,8 | 23,3 -> 11,8 | 3,4 / 14,1 -> 3,5 / 4,5 |
| Transporter | 20,8 -> 8,0 | 17,8 -> 4,2 | 16,8 -> 5,8 | 42,7 -> 9,6 | **46,4 -> 12,0** | **52,5 -> 15,8** | 1,9 / 30,1 -> 1,8 / 3,6 |
| Sportwagen | 16,3 -> 12,3 | 13,3 -> 11,4 | 19,1 -> 8,1 | 28,2 -> 22,7 | 31,6 -> 28,4 | 24,1 -> 15,5 | 3,6 / 3,7 -> 3,6 / 4,5 |
| Limousine | – | 13,2 -> 14,4 | – | – | 26,9 -> 14,4 | – | – |
| Schrägheck | – | 7,3 -> 8,2 | – | – | 35,7 -> 22,4 | – | – |
| Kombi | – | 5,8 -> 6,8 | – | – | 31,4 -> 6,9 | – | – |

Was bei 25–60 m bleibt, aufgeteilt (gemessen, `pop_split.py`): das Kennzeichen 2–5 Prozentpunkte (Zeichen gegen
graues Feld), die Scheibe 0,2–2,4, der Rest Umriss und Kleinteile. **Hier ist eine Zahl schlechter geworden:** Mit
dem dunkleren fernen Kennzeichen (`#a2a2a0`, Abschnitt 2) stimmt die mittlere Helligkeit (`lod0` 192, `lod1` vorher
242, jetzt 199), aber die weißen Pixel des `lod0`-Kennzeichens liegen jetzt mehr als 24 Stufen vom grauen Feld
entfernt: SUV, Limousine, Schrägheck und Kombi bei 40 m je etwa 1 Punkt mehr, SUV bei 25 m 2,6 Punkte. Ich halte
die gleiche mittlere Helligkeit für das kleinere Springen (bei 40 m ist das Kennzeichen 9 × 2 Pixel groß, das Auge
mittelt); das ist **abgeleitet**, nicht gemessen. Bei der Limousine liegen 11 der 14,4 Punkte außerhalb von
Kennzeichen und Scheibe, nach dem Differenzbild vor allem auf den Fugen des Kofferraumdeckels (6 mm, bei 40 m ein
Zehntel Pixel), die `lod0` als Treppenlinie zeigt. SUV bei 120 m (29,8 %): 13 der 37 geänderten Pixel sind Umriss
(Radläufe und Reling von `lod2` schmaler), dazu Scheibe und Kante unter der Scheibe 20–30 Stufen dunkler (gröbere
Normalen von `lod2`).

**Spielerheck nachts, 8 m** (rote Lampenpixel Rücklicht / Bremse, gemessen): GT 353 / 587 -> 477 / 716 (Arcade
733 / 957); Kombi 536 / 991, Sportwagen 690 / 1 052, Limousine 555 / 1 000, Kompakt 538 / 949 (unverändert; Arcade
1 617 / 2 034, 1 061 / 1 197, 1 369 / 1 656, 1 193 / 1 479).

**Silhouette gegen das Sprite** (9 m, unverändert nach A2/A5): IoU Kombi 0,992, Sportwagen 0,992, GT 0,990,
Limousine 0,994, Kompakt 0,989.

**Radfreiheit** (Ecken im Reifenvolumen, Werkzeug der Kritik): Sportwagen und GT `lod0` 0 bei 0°, ±7°, ±15°, ±25°
(vorher 114 / 71 Ecken bis 84 / 61 mm bei 0°); `show` 0 bis ±15°, bei ±25° 2 Ecken / 15 mm bzw. 1 / 6 mm.

**Lampen sichtbar** (Strahltest der Kritik): Rückfahrlicht Kombi 10 -> 100 %, Kompakt 0 -> 100 %; SUV-Rückstrahler
0 -> 100 %.

**Weiß** (Transporter weiß, 10 m, Pixel mit allen Kanälen ≥ 250): 22 473 -> 7 565.

**Scheiben, Kennzeichen, Karoband** (mittlere Farbe in linearem Licht gemittelt):

| Stelle | `lod0` bzw. nahe Stufe | ferne Stufe vorher | ferne Stufe jetzt |
|---|---|---|---|
| Transporter, Heckscheibe, 40 m | (76, 97, 127) | (49, 73, 107) | (70, 94, 130) |
| Bus, Heckscheibe, 60 m | (78, 97, 121) | (59, 77, 100) | (73, 93, 119) |
| Limousine, Kennzeichen, 40 m (Helligkeit) | 192 | 242 | 199 |
| Polizei Belgien, Karoband, 120 m | (173, 178, 124) | (201, 201, 136) | (171, 180, 121) |

**Budgets** (Manifest = Prüfer, gemessen): Spieler `lod0` 46 805–54 306 / 55 000, `show` 94 983–117 206 / 120 000;
Verkehr `lod0` 17 459–17 748 / 18 000, `lod1` 5 661–5 941 / 6 000, `lod2` 1 164–1 197 / 1 200; Polizei `lod0`
19 778–21 970 / 22 000, `lod1` 5 331–5 975 / 6 000, `lod2` 1 061–1 196 / 1 200; Lkw/Bus unverändert (`lod2` Bus
1 500 / 1 500). Schattenwerfer unverändert.
