## 7. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen vom Auftrag**
1. Dateibesitz: `builders/props.gd`, `layers/flares.gd`, `assets/shaders/modern/baked.gdshader` gehören R2/R3 bzw. ihren
   Nachfolgern; geändert, weil der Auftrag es verlangt (Pylone nachts nicht heller als Arcade; Warnlicht als Lampe,
   wenn billig). `test_props.gd`/`test_terrain_builder.gd` beim Auflösen der inhaltlichen Konflikte angepasst.
2. Die Pylon-Behebung brauchte mehr als `dark_material()`: neuer Shader-Parameter `night_albedo` (Vorgabe 1, kein
   anderes Material betroffen) – die Nachtbeleuchtung durch den Mond ist kein Nachtatlas.
3. Ersatzbilder der sechs prozeduralen Wahrzeichen sind seit AS4R Modelle und damit **ungetönt** (`fallback_tint`
   gilt nur für Vertretungen); in Belgrad schlanker als das Sprite von ZS1.
4. km 78,9 der Köhlbrandbrücke: das ZS1-Gegenstück ist das Bild bei 4 s (km 78,8); 78,9 ist bei 4,3 s ergänzt.
   Steam-Deck-Tagbilder: ZS1-Vergleich aus einem anderen Lauf (FIX-WASSER, 60 km/h, ohne Verkehr).
5. Modern-Änderungsmelder: `modern-make` mit `KEEP` gerendert, die sechs Bilder angesehen, dann die Liste committet
   (statt erst `modern-check` und dann `modern-make` – spart einen 14-min-Lauf; `modern-check` lief als Gate danach).

**Vertragsfragen**
1. D16/A-3: der Fernboden steht im Vertrag noch als „tiefste Straße − 4 m“; die Regel des Testbuilds ist
   min(…, tiefstes Wasser − 0,3 m) (FIX-WASSER, seit M2ZS1 auch in der M2-Linie). Bitte nachtragen.
2. A-4/A-9: Wahrzeichen nur mit prozeduraler Zeichnung haben keine Vertretung im Vertrag; umgesetzt ist das Ersatz-Set
   des Etappenplan-Eintrags – seit AS4R als Modell ohne `fallback_tint`. Der Vertrag sollte sagen, ob eine Tönung für
   Modelle nötig ist (Leipzig #8a857a dunkler Stein) oder bis AS6 so bleibt.
3. A-16/D19: der Nachtatlas des Pylonmodells ist der angestrahlte Pylon des Sprites, den Arcade nie zeigt. Der Renderer
   schaltet ihn für `prefer_proc` ab; sauberer wäre ein Atlas nur mit der Befeuerung (Assets).
4. Nachtlicht der Modelle: der „Bodengesetz“-Abgleich (RINT-B) stimmt ebenen Boden auf Arcade ab; senkrechte helle
   Flächen bekommen vom tiefen Mond mehr Licht als Arcades Umgebungslicht-Gesetz – beim Pylon +40 %. `night_albedo`
   ist eine Stellschraube je Material; ob ein allgemeines Nachtgesetz für senkrechte Flächen nötig ist, entscheidet R4.

**Für die Nächsten**
1. Assets (AS5/AS6): den Nachtatlas von `props/bridge_pylon`/`_bare` ohne das Flutlicht des Sprites backen (nur die
   Befeuerung); danach kann `_dark_model_override()` den Atlas wieder zeigen, `night_albedo` bleibt.
2. R5: Pylonhöhe und Seilfächer je Brücke (`height_m`, `cables`); Arcades Warnlicht sitzt auf `height_m` + 1,6 m, das
   Modell auf 88,3 m. Kaimauern, Böschungen, fernes Ufer (QA-WASSER B3) weiter offen.
3. R4: prüfen, ob andere helle senkrechte Flächen (Gebäude, Brückenteile) nachts heller als Arcade sind (der Mond);
   `night_albedo` von `baked.gdshader` ist die Stellschraube je Material.
4. Wahrzeichen-Ersatz als Modell: `fallback_tint` fehlt (Leipzig dunkler Stein, Madrid bläulich) – eine Tönung über die
   Kopie von `_landmark_override()` wäre klein; endgültig die Wahrzeichen-Modelle (AS6).
5. Ein Bild der blinkenden Befeuerung fehlt (an den geprüften Stellen liegt die Pylonspitze hinter dem HUD-Balken) –
   bei R5 eine Stelle mit der Spitze im Bild wählen.
6. M2INTs offene Punkte gelten weiter (Niederschlag R4, nahe Requisiten R5, Lack der Spielerautos, Spielerauto nachts
   heller als sein Sprite – auch in diesen Bildern sichtbar).
