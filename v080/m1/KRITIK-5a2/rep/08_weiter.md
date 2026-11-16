## 8. Für die Nacharbeit und die anderen Pakete – in dieser Reihenfolge

1. **Leitung:** die Vertragsfragen 1 (drei Oberflächen oder Anbauten für Stadthäuser) und 2 (deckungserhaltende
   Mip-Kette) entscheiden, **bevor** AS5b mit mediterranen Gärten und Balkonen beginnt; Flankenöffnungen (Frage 3)
   festschreiben.
2. **AS5a-N (ein Neu-Export für beide Chargen, 23 Stadthäuser):** K1 Schaufenster nachts auf Arcade-Niveau
   (`_display_mat`), K2 Fernfenster (vorgefilterte Fensterregion der kleinen Mips oder Fernfenster-Kachel in lod1),
   K3 Gartenbaum und Gartenmauer von Südhaus/Loire-Haus, K4 Geländer in lod1 als gemaltes Band (lod1 ohne
   `baked_cutout`), K7 Geranien, K9 eine Eingangsleuchte je Haus; dann K8 und die lod1-Ersparnis (K10).
3. **Import/`bake.py` (Freigabe nötig):** deckungserhaltende Mips für `baked_cutout` (K4).
4. **R7:** Überblenden für Gebäude (K5), Fernbild ab ≈ 200 m (K2), Tönung der Modell-Instanzen (K10), Anbauten für
   Gartenbäume (Vertragsfrage 1).
5. **R4:** Sonnenseite heller Putz- und Steinfassaden gegen Arcade abgleichen (+15–20 % in Paris und Amsterdam, K10).
6. **RINT-M2:** FIX-M2 B-01 (Kurvenkorridor nur Vegetation) mergen und Lyon km 297,4 / Bern km 302,7 als A/B
   wiederholen – dort fehlen heute ganze Häuser.
7. **R6 / RINT-M2:** die Szenerie-Zäune `fence` (hier `style: "wall"` der Brüsseler Vororte, `#9c7466`, 0,9 m) zeichnet
   erst der Bauer `city` von R6, der in diesem Stand fehlt; nach dem Zusammenbau Brüssel km 196 als A/B wiederholen.
