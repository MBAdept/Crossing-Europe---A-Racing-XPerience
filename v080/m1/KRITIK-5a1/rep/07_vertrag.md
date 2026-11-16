## 7. Vertragsfragen und Bedarf bei anderen Paketen

1. **F7-Korridor in der Stadt (D14, A-3, A-10; FIX-M2 B-01 offen).** Die strenge Lesart nimmt Gebäude einer
   Stadtregel aus Kurveninnenseiten – in München fehlt eine ganze Straßenseite, in Nürnberg und Hannover einzelne Häuser
   (K1). Bei Tempo 50 braucht F2 eine viel kürzere Sehne als 300 m. Bitte um Entscheidung der Leitung vor dem nächsten
   Testbuild: Stadtabschnitte mit Sehne aus F2 bei erlaubter Geschwindigkeit oder Gebäude der Stadtregel ausnehmen.
2. **„Die Generatoren SIND das Aussehen – nie ein neuer Entwurf“ gegen „Tiefe, wo die Kamera von der Straße aus
   hinsieht“.** Die Generatoren haben genau dort, wo die Kamera im 3D in Augenhöhe vorbeifährt (Straßenflanke), keine
   Öffnungen, weil das Sprite sie nur unter −20° zeigte. Die Behebung von K2 fügt Fenster und Türen hinzu, die das
   Sprite nicht hat (Umriss unverändert, Sprite-Geometrie unverändert über `close3d`). Bitte um ausdrückliche
   Zustimmung der Leitung, dass solche Flankenöffnungen „im Stil des Generators“ erlaubt sind – das betrifft auch
   AS5a2/AS5b (Grachtenhäuser, Reihenhäuser, Haussmann-Blöcke haben dieselbe Bauart).
3. **Überblenden der Stufen für Gebäude.** A-16 fordert das Dither-Überblenden nur für Bäume; die Stadthäuser
   wechseln bei 60 m 15–32 % der Pixel (K5). Bitte R7 auch für `building`/`city` beauftragen.
4. **Mip-Kette für `baked_cutout`.** §4.6.5/D23 lassen die Mips beim Import erzeugen (Box-Filter); damit ist
   „Deckung in kleinen Mips erhalten“ nicht erfüllbar (K7). Wer darf `bake.py` bzw. die Import-Skripte dafür ändern
   (in AS5a1 ausdrücklich nicht angefasst)? Vorschlag: AS5a-N mit Freigabe für den Ausschneide-Teil von `bake.py`.
5. **Helligkeit gegen Arcade (K8).** Der Vertrag misst Nachtfenster gegen Arcade (A-16), nicht die Tageshelligkeit
   sonniger Fassaden. Vorschlag für R4: Median-Luma der Sonnenseite ≤ +15 % gegen Arcade als Prüfwert.
