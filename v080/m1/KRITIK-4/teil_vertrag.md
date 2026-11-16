## 8. Vertragsfragen und Bedarf bei anderen Paketen

- **Pylon gehört eigentlich zum Brückenbau (R5).** Arcade zeichnet ihn prozedural (`prefer_proc`, `height_m`,
  `cables`); ein Modell fester Höhe mit fest eingebauten Seilen passt zu keiner Brücke des Netzes. Vorschlag für einen
  Nachtrag: `bridge_pylon` wird als Modell **ohne Seile** geliefert (Bein, Kopf, Flugbefeuerung), Seile und Höhe kommen
  vom Renderer aus den Track-Daten (`height_m`, `cables`, Deckkante) – bis R5 durch den Requisiten-Bauer (R2),
  wie es `RoadRenderer._pylon()` tut.
- **Schiffe ohne Wasser.** Der Requisiten-Bauer setzt Requisiten mit `h` < 0 auf das Gelände, solange es kein Wasser
  gibt. Bis R5: auslassen (Grund „water“ in `drop_reason()`, R2).
- **Fensterlicht (Kanal 12) bei Tag.** AS1b und AS4 haben es beide gemeldet: eine unbeleuchtete `vpbr`-Lampe zeigt
  die halbe Leuchtfarbe. Für Fenster heißt das: entweder braun bei Tag (heute) oder kalt bei Nacht. Ein Nachtrag sollte
  eine Tagesfarbe für Kanal 12 festlegen (Uniform `lights_day_tint` oder eine Rolle „Fenster“), Besitzer des Shaders
  in Welle 3 ist R4.
- **Kein Budget „Schiff“** (AS4): bestätigt; auf Spielabstand reicht das Landgebäude-Budget – keine Änderung nötig.
- **Requisiten-Bauer skaliert nicht nach `height_m`** (AS4): bestätigt für den Pylon; betrifft auch die Kirche als
  Wahrzeichen-Ersatz (Maßstab aus `scale`, das funktioniert).
