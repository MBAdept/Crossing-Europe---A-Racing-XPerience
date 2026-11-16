## 9. Was andere Pakete brauchen (nicht in meinen Dateien)

- **R7 – Tönung:** `city_dutch_terrace` steht an 50 von 130 Stellen (Vororte im Ruhrgebiet) getönt `#ead6cc`. Der
  Atlas trägt die ungetönten Farben; Albedo × Tönung = getöntes Sprite (Lieferbild `toenung_reihenhaeuser_ruhr.jpg`).
  Bis R7 die Tönung als Instanzfarbe auf `baked` legt, stehen diese Häuser etwas röter da als in Arcade.
- **R7 – Stufenwechsel:** lod0 → lod1 bei 60 m („Mittel“) ändert 9–18 % (Tag) bzw. 8–15 % (Nacht) der Pixel (Sprite-Tausch als Vergleich:
  siehe Abschnitt 5); ein Überblenden (A-16 nennt nur Bäume) sollte die Stadthäuser einschließen.
- **R7 – Fernbild:** Kein Modell hat ein Fernbild; lod1 trägt bis 100 000 m. Bei 250 m wirken die Fensterreihen in
  lod1 heller als im Sprite (weiße Rahmen, Rahmenring und Sprossen des Atlas überwiegen das dunkle Glas) – im Rennen
  bei Paris nicht auffällig (A/B), in der Prüfszene deutlich.
- **R4 – Licht:** helle Steinfassaden (Haussmann, Loire-Haus, Grachtenhaus B) in der Mittagssonne heller als Arcade
  (K8 der Kritik von Charge 1); ich habe die Albedo nicht abgedunkelt.
- **Leitung/R2 – Kurvenkorridor (K1 der Kritik von Charge 1):** gilt für alle Stadthäuser; nicht in meinen Dateien.
- **Leitung – Generator-Flanken:** Die Hooks `close3d` erfinden Fenster an Flanken, die im Sprite blind sind (Grachten-
  und Reihenhäuser sind in Wirklichkeit Brandwände). Ich habe das nach der Linie von AS5aR1 und dem Auftrag getan
  (blinde Flanken waren der wichtigste Mangel der Charge 1); die Frontansichten bleiben exakt das Sprite.
