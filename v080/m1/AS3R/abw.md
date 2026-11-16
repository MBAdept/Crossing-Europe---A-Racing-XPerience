Kein Befund wurde abgelehnt: jeder ließ sich auf be866d2 nachstellen (Bilder und Messzeilen der Kritik, eigene
Renderings, Code). Abweichungen vom Vorschlag der Kritik oder vom Ziel:

1. **M6 nur teilweise behoben.** lod1 liegt auf dem Rand von lod0; die Helligkeit springt mittags höchstens ±5 %
   (gemessen; abends und nachts siehe Punkt 11). Das Muster im Innern ändert sich aber weiter in 63–73 % der Pixel. Ein lod1 aus Fächern über dem ganzen
   lod0-Rand (gleiches Innen-UV) wurde gebaut und verworfen: Helligkeit −26 %, 15 % weniger Pixel, stachelige Kronen
   (gemessen, angesehen). Die eigentliche Abhilfe ist die Überblendung im Props-Bauer, und der gehört R2/R7 (Renderer).
2. **M5 ohne den Schalter `baked_light`.** Statt eines Kennzeichens, das R2/R7 im Shader auswerten müssten, steckt das
   Relief normiert (Mittel 1) im Albedo des Fernbilds; `billboard.gdshader` bleibt unverändert. Mittags passt das
   (Kontrast −22 … +14 % gegen lod1, gemessen). Abends und nachts zeigt das Fernbild aber weiter das Mittagsrelief
   (Kontrast gegen lod1 +10 … +121 %, gemessen).
3. **M4 mit 15 statt höchstens 12 Kuppeln und Rand (1, 6, 12) statt (1, 8, 16).** So passen Kern, Schürze und
   lod1-Kern ins Budget: 380 / 116 von 400 / 120 Dreiecken (gemessen). Unter 20 m ist der Busch noch leicht
   facettiert (angesehen).
4. **M9 ohne 512²-Laubatlanten** für Olive, Zypresse, Palme und Kiefer. Nach der Atlas-Teilung braucht der ganze Satz
   22,1 von 60 MB (gemessen). Die Olive steht im Rennen bis auf 20 m an der Straße, und dort braucht ihr Laub den
   1024²-Atlas (gefolgert). Das lässt sich nachholen, wenn AS4–AS6 den Platz brauchen.
5. **M3 nicht ganz behoben:** Oben in der Krone von `tree_oak_b` bleiben zwei dünne dunkle Striche (unter 20 m,
   angesehen). Kein Holz liegt außerhalb von 90 % der Kugeln oder 92 % der Krone, und es gibt keine Splitterkuppel.
   `min_exposed` = 4 wurde probiert und zurückgenommen. Die Ursache habe ich nicht gefunden.
6. **M7 Heide:** Die Modellseite ist erledigt (Schürze bis −0,4 m, Kennzeichen `ground_align`). Am 30°-Hang hängt die
   Talseite trotzdem in der Luft, bis der Props-Bauer das Kennzeichen auswertet (R2/R7).
7. **Kennzeichen-Format:** Statt eines neuen Schlüssels `ground: "align" | "sink"` (Vorschlag der Kritik) stehen
   `ground_align`, `ground_sink` und `face_road` in der vorhandenen Liste `tags`. Damit braucht das Manifest keinen
   neuen Schlüssel.
8. **M11 Olive:** Der Stamm im Fernbild bleibt 0,67 m breit (lod1 0,83 m, gemessen). Der Befund ist niedrig und
   wurde nicht angefasst.
9. **M11 Kiefer:** lod1 flimmert in 80 / 150 m etwas mehr als vorher (siehe 4.4), weil der volle Kuppelrand mehr
   dünne Kanten zeigt. Das Arcade-Sprite liegt bei 3,7 / 7,5 %.
10. **Palme:** Kontrast lod1 → Fernbild weiter rund −60 % (gemessen); die dünnen Wedel lösen sich in 256–512 px
    kaum auf. In 40 / 80 / 150 m flimmert die Palme etwas mehr als vorher (Wedel breiter, siehe 4.4).
11. **Rückschritt bei `olive_b`:** Seit ihr lod1 den vollen Kuppelrand trägt (letzte Runde), springt die Helligkeit
    lod0 → lod1 um +5,0 / +6,5 / +8,3 % (Mittag / Abend / Nacht, vorher −1,8 / −0,7 / −1,1 %, gemessen). Den
    Mittagswert (+5,0 %, gerade noch im Rahmen) kannte ich vor den Gates, Abend und Nacht habe ich erst danach
    gemessen. Für eine Korrektur hätten Tests und Arcade-Bilder ein weiteres Mal laufen müssen, und beide waren schon
    gelaufen (höchstens zweimal bzw. einmal). Die Korrektur ist ein Helligkeitsabgleich (`lift`) für lod1 der Olive.
