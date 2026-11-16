## 5. Rechenzeit (GDScript je Bild) und Sperren des Audioservers

`kr_perf_conc.gd` (Beton erzwungen, km 42, 140 km/h – beide Plattenentwürfe klingen) und `perf_asph.gd` (= `perf_auc1.gd`
von KRITIK-FAHRBAHN, Asphalt km 76, 140 km/h), je 840 gemessene Bilder; die Skripte rufen `update()` der Slots ein
zweites Mal je Bild nur für die Zeitmessung (der Plattenabgleich zählt darum doppelt: Sperre alle 0,25 s statt 0,5 s).
Drei Durchgänge, Endstand und AU-C1 im Wechsel unter derselben Last (Maschine mit Last 6–8).

| Slot, Belag | AU-C1 Mittel / Median / 95 % (ms) | Endstand Mittel / Median / 95 % (ms) | Endstand − AU-C1 (Median / 95 %) | Maximum einzelner Bilder AU-C1 / Endstand |
|---|---|---|---|---|
| `road`, Beton (Lauf 1 · 2 · 3) | 0,60 ¹ / 0,13 / 0,20 · 0,13 / 0,13 / 0,18 · 0,15 / 0,14 / 0,22 | 0,26 / 0,20 / 0,28 · 0,22 / 0,20 / 0,28 · 0,23 / 0,20 / 0,29 | +0,06 / +0,08 ms | 376,7 ¹ · 2,0 · 1,4 / 21,0 · 2,7 · 7,5 ms |
| `road`, Asphalt (Lauf 1 · 2 · 3) | 0,19 / 0,12 / 0,18 · 0,13 / 0,12 / 0,18 · 0,15 / 0,12 / 0,18 | 0,21 / 0,17 / 0,26 · 0,20 / 0,17 / 0,25 · 0,21 / 0,18 / 0,26 | +0,05 / +0,08 ms | 49,8 · 2,5 · 8,6 / 7,3 · 6,1 · 7,3 ms |
| `impact`, beide | 0,008 / 0,006 / 0,015 | 0,008–0,010 / 0,006 / 0,015–0,019 | 0 | ≤ 46,3 ¹ / ≤ 1,2 ms |
| `feed`, beide | 0,05–0,07 / 0,05 / 0,07–0,08 | 0,06–0,07 / 0,05 / 0,07–0,09 | ≤ +0,01 ms | – |

¹ einzelne Bilder, in denen die Maschine stand (AU-C1 sperrt nie) – die Maxima sind Last, nicht Klang.

Sperren des Audioservers (`slab_locks`, gemessen): im Spiel (ein `update()` je Bild) **2 je Sekunde, solange beide
Plattenentwürfe klingen** (110–150 km/h auf Beton: 38–39 in 20 s bei 130 km/h, 29 in 15 s bei 120/130/140 km/h), **0** bei
110 km/h und darunter, 0 ab 150 km/h, 0 auf jedem anderen Belag, dazu je eine beim Start eines Musters; in den
Messskripten mit doppeltem Aufruf 61–63 in 840 Bildern. Gegen die Nachmessung von AU-R (`road` auf Beton im Mittel
0,37–0,40 ms, 95 % 0,59–0,62 ms laut KRITIK-R) ist der Befund M1 behoben; gegen AU-C1 bleiben +0,05–0,08 ms je Bild
für die eigenen Schleifen je Seite und die Drift (gemessen), das sind 0,3–0,5 % eines 16,7-ms-Bildes dieser VM;
auf dem Steam Deck abgeleitet ähnlich klein.
