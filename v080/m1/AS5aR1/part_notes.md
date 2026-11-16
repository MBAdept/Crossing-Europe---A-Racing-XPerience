- **Leitung (Vertrag):** Die Flankenöffnungen ergänzen, was das Sprite nicht zeigt („die Generatoren SIND das
  Aussehen“ gegen „Tiefe, wo die Kamera von der Straße hinsieht“). Ich habe sie streng aus den Mitteln des Generators
  gebaut (dieselben `grid`-Raster, Fenstermaße, Rahmen- und Glasfarben, Lichtregeln wie die Front) und hinter `close3d`
  gelegt. Bitte bestätigen; AS5a2/AS5b (Grachtenhäuser, Reihenhäuser, Haussmann) brauchen dieselbe Regel.
- **R7:** Überblenden lod0 ↔ lod1 auch für Gebäude (A-16 nennt nur Bäume); eine lod0-Entfernung je Modell aus
  `model.json` (`max_dist_m`, für Fachwerkhäuser ~35 m) würde das Flimmern der Hölzer nehmen, ohne die Tiefe aus der
  Nähe zu verlieren. Tönung als Instanzfarbe auf die gebackene Albedo (`toenungen.jpg`).
- **R7/Renderer:** Mit `cut_fill` brauchen die Geländer kein Alpha-to-Coverage mehr; der Alpha-Test bei 0,5 muss
  bleiben (die Lücken haben Alpha 0,4).
- **Leitung/R2:** Kurvenkorridor (K1) – in München fehlen weiter Häuser, wenn die Korridorregel nicht geändert wird.
- **R4:** Sonnenseite heller Putzfassaden gegen Arcade abgleichen (K8); ich habe die Albedo bewusst nicht abgedunkelt.
- **AS5a2/AS5b:** Bauer `city` weiterverwenden: `close3d`-Flanken von Anfang an, `oriel` für Turmerker, `cut_fill` für
  jedes Geländer (Haussmann!), `inner_frame` gilt automatisch.
- **Nacharbeit offen:** Flimmern der Hölzer (siehe oben), Büroturm-Foyer, Kontor-Texeldichte, Konsole als Profil statt
  Kegel.
