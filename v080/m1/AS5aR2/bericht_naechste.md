## 8. Für die nächsten Pakete und die Leitung

1. **R4/R7 – Fernfassaden (K2).** Ursache gemessen (Abschnitt 4): das Ende der Echtzeitschatten (Hoch 170–200 m,
   Mittel 102–120 m) und die grobe letzte Schattenstufe, nicht die Mip-Kette. Vorschlag: jenseits der Reichweite den
   gerichteten Anteil auf Gebäuden um einen mittleren Schattenanteil senken (z. B. eine eingebackene
   Sonnen-Sichtbarkeit je Texel oder ein fester Faktor je Set) oder ab ≈ 200 m ein Fernbild mit eingebackenen Schatten
   (A-16). Nachweis mit `k6_scene --mode=lodcol` (liegt in `m1/AS5aR2/kt`, Schalter `--shadow_m`). Im Modell bleibt nur
   das Maashaus (p10 +15 gegen +7 ohne Schatten); ein dunkleres Glas im Atlas würde die Nahansicht mit abdunkeln.
2. **R7 – Flimmern in lod0 (40–60 m):** Haussmann und Eckhaus flimmern 0,9–1,1 % gegen 0,0–0,2 % beim Sprite. Ursache
   sind der Alpha-Test der Gitter und die geometrischen Sprossen. Die Blattkarten von Südhaus und Loire-Haus flimmern
   1,0–1,6 % bei 100–150 m. Abhilfe: Alpha-to-Coverage oder TAA, Mip-Bias, oder ein kürzeres lod0 über `max_dist_m`
   (A-22).
3. **R7 – Überblenden** der Stufen auch für `city`. Bei 60 m ändern sich 8–17 % der Pixel. Dazu die Tönung der Instanzen
   (A-19): 50 niederländische Reihen im Ruhrgebiet mit `#ead6cc`, Kontaktbogen `toenung_reihenhaeuser_ruhr.jpg`.
4. **Vertragsfrage (offen seit KRITIK-5a2, Frage 1):** Ein Stadthaus darf zwei Zeichenaufrufe haben. Deshalb liegen die
   Blattkarten im Ausschneide-Atlas des Hauses, und das Loire-Haus wird jetzt ganz in `baked_cutout` gezeichnet (ohne
   Culling, mit `discard`; Kosten auf echter Grafikkarte gefolgert). Mit drei Oberflächen (`baked` + `baked_cutout` +
   `vpbr`) oder einem Anbau-Mechanismus für AS3-Bäume im Requisiten-Bauer wäre das sauberer. AS5b braucht die
   Entscheidung für die mediterranen Gärten.
5. **Ladenflanken unter spitzem Winkel:** Paris +4 s zeigt 9 % warme Pixel gegen 24 % in Arcade. Grund ist die
   Geometrie: die Auslage liegt 35 cm tief hinter der Laibung, Arcade zeigt dort eine zur Kamera gedrehte Fläche. Ein
   flacheres `shop_depth` an Flanken wäre möglich, ist aber eine Geschmacksfrage. Es ist nicht geändert.
6. **Niedrig, offen:** Rückseiten des Haussmann-Eckhauses (K8), Wandleuchten an Eingängen (K9). Das Bürohaus von
   Charge 1 hat an der Straßenwand nur 15,9 px/m (unverändert seit AS5a1, unter 26).
7. **Werkzeuge:** Die Prüfhilfen (`tools/kritik`, nie committet) liegen in `m1/AS5aR2/kt` und `py`. Neu sind
   `py/glbtex.py` (Texeldichte je Dreieck aus einer GLB), `py/lodcmp.py` (Fernbild vorher/nachher),
   `py/budget_r2.py` (Budgettabelle) sowie `py/pair.py` und `py/stack.py` (Vergleichsbilder).
