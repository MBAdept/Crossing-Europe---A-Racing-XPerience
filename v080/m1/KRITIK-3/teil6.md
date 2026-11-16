## 6. Was gut ist

- **Die Arten lesen sich als ihr Sprite:**
  - Waldkiefer mit orangem Stamm und flachen Polstern, wie ihr Sprite (keine Schirmkiefer).
  - Fichte als dunkler Kegel, Pappel als Säule, Zypresse als glatte Flamme.
  - Olive silbergrau und knorrig, Buche breit mit glattem grauem Stamm, Birke weißstämmig.
  - Heide als lila Flecken.
  - Umriss lod0 bei 8 von 9 Arten 0,8–9 % außerhalb des Sprites (gemessen).
- **Volumen ohne Aufkleber:**
  - Jede Kuppel hat eine Sonnen- und eine Schattenseite, das Innere und die Unterseite sind dunkler.
  - Aus keiner der 8 Drehungen ein Kartenstreifen, keine hellen Aststummel (angesehen).
  - Damit sind die Mängel von AS1b in der Krone behoben.
- **Ruhig in Bewegung:**
  - Kein Glitzern, Pixel kippen 0,75–1,65× so oft wie beim Sprite (gemessen).
  - Folgebilder bei 120 km/h ruhig: Durch die Fahrt selbst ändern sich im Fernbereich je Bild 3,0 % der Pixel um mehr
    als 50 Stufen, höchstens 4,9 % – kein Bild springt heraus (gemessen); kein Aufblitzen (angesehen, Bild 14).
- **Fernbild im Nebel** wie das Sprite, keine blassen Flecken mehr (Bild 17).
- **Am Hang:** Bäume stehen auf 30° Hang sauber, der Stammfuß reicht 0,55–0,70 m in den Boden (gemessen).
- **Varianten** sind im Umriss klar verschieden: Überdeckung Grundart zu `_b` 0,68–0,85 (gemessen).
- **Daten für Wind und Schnee sind brauchbar:**
  - Ausschlag nimmt mit der Höhe zu; Stämme starr; Palmwedel am lebhaftesten (Steifheit 0,15); Fernbild ohne Wind.
  - Normalen zeigen nach außen und oben (Laubbäume 28–38 % nach oben, Fichte 59–63 %).
  - Nichts leuchtet.
- **Pipeline:** Budgets, Aufrufe 2/2/1 und der Prüfer sind grün. Das Werkzeug `prop_scene --look=race` von AS3 zeigt
  wirklich das Renn-Licht; seine Bilder sind belastbar.

