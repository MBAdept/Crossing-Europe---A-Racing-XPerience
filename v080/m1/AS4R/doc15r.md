### Nacharbeit nach der Kunstkritik (AS4R)

Die unabhängige Kunstkritik von AS4 (KRITIK-4) fand einen Fehler, der nicht in den Testbuild durfte, und mehrere
Schönheitsfehler, die man stundenlang sieht. Was geändert ist:

- **Pylon (M1, M5).** Die Seile des Generators endeten bei Modell-x −4,2 m: bei der Aufstellung 7,55 m neben der
  Mitte 0,4 m **innerhalb** der Fahrbahn, 0,6 m über dem Belag, und der Fächer (±82,7 m) reichte bis zu 42 m vor die
  Brücke. Jetzt steht das Bein senkrecht und 0,9 m weiter außen (Fuß und Sockel enden an der Deckkante, Modell-x
  −1,3 m), und `fan_cables` (`ce3d/bridges3d.py`) baut sieben Seile je Seite neu: vom Kopf (55–79 m) bis zur Deckkante
  (Achse bei x −1,15 m, 1,1 m hoch; Arcade zeichnet sie bis x −1,4 m), als Halbfächer ohne Kreuzung (der höchste
  Anker läuft am weitesten), höchstens 36 m vor und hinter dem Pylon. 36 m passen auf jede Schrägseilbrücke des
  Netzes (gezählt: fünf Brücken, Platz vom Pylon bis zum nächsten Brückenende mindestens 40,5 m bei Elisabeth- und
  Vanšu-Brücke; Köhlbrandbrücke 70,5 m). Eine Stufe mit 0,32 m starken Seilen (vorher 0,28 / 0,34 m mit einem
  Sprung von 58 % der Pixel). `extent_m` bleibt der Wert des Sprites (aus dem Generatornetz: der Pylon wird nicht
  kantenbündig gestellt). Neu ist **`props/bridge_pylon_bare`** (Set nur für Modern): derselbe Pylon ohne Seile, für
  einen Renderer, der die Seile je Brücke aus `height_m` und `cables` zeichnet (wie `RoadRenderer._pylon()`).
- **Fensterscheiben (M3, M6).** Die Scheiben waren `vpbr`-Lampen (Kanal 12); unbeleuchtet zeigt eine Lampe die
  halbe Leuchtfarbe – bei Tag braune Scheiben neben blauen, am Büroturm ein Schachbrett. Jetzt ist die Scheibe der
  **Lochfüller des Fensters**, nach dem Farb- und dem Licht-Bake um die Laibungstiefe zurückgesetzt
  (`_settle_fillers`): Bei Tag zeigt sie das gemalte Glas des Sprites (eine Farbe für alle Scheiben der Fassade, mit
  der Umgebungsverdeckung der Laibung), nachts das Licht des Sprites für **genau dieses Fenster** × `PANE_LIGHT_K`
  (0,55) aus dem Nachtlicht-Atlas – es leuchten dieselben Fenster wie in Arcade. Scheiben ohne gemaltes Fenster
  dahinter (Vorhangfassade, Mühlenfenster) sind einfarbige Atlasfelder (`Patches`). Kein Kanal 12 mehr an den
  Scheiben; der Atlas wird dadurch nicht größer (die Füller lagen schon darin).
- **Fabrik (M4).** Die „weißen Dreiecke“ über dem Sheddach waren die senkrechten Glasbänder der Sheds (2,8 × 22 m,
  Licht #cfe0ff × 0,9 → reinweiß), gesehen über der Schräge des nächsten Sheds – keine verdrehten Flächen (geprüft:
  alle Normalen außen). Die Verglasung hat jetzt Sprossen alle 1,4 m und einen Kämpfer (`_skylight`), ihr Licht 45 %
  und nach oben auf die Hälfte abklingend.
- **Windmühle (M7).** Die Flügel haben sieben 13-cm-Sprossen statt dreizehn 7-cm-Sprossen (gleiche Fläche, Hook
  `sail_bars` in `props_buildings.windmill`): Bei 80–150 m Abstand waren die Sprossen einen halben Pixel breit und
  flimmerten.
- **Büroturm (M8).** Die Scheiben der Vorhangfassade sind Atlasfelder im Glasverlauf des Sprites (sechs Stufen),
  welche leuchten, entscheidet ein gut streuender Hash je Seite, Geschoss und Achse (der alte bildete Spalten); das
  Foyer leuchtet mit 20 % und hat Pfosten und einen Kämpfer davor.
- **Ladenhaus (M9).** Auf dem Schild steht ein Zeichen: eine Einkaufstasche zwischen zwei Balken, spiegelsymmetrisch
  (das Set wird links gespiegelt), nachts beleuchtet; das Schild selbst leuchtet mit 35 % (nachts war es ein weißer
  Kasten).
- **Kleinteile (M10).** Kirche: Putz `#ccc6b7` statt `#e8e1d0` (Hook `plaster`; im Rennlicht war die Wand 13 %
  heller als das Sprite). Fachwerkportal: Streben im Ausschneidebild 1,2× breiter und 15 % dunkler (bei 400 m war es
  blasser als das Sprite).

TABELLE_AS4R

**Nicht im Modell lösbar** (an die Renderer-Pakete): Fähren und Hausboote stehen ohne Wasser auf der Wiese (R2:
Requisiten mit `h` < 0 auslassen, bis R5 Wasser hat); die Höhe des Pylons folgt nicht `height_m` der Brücke (50–120 m,
das Modell hat 88,8 m) und gerade Seile folgen keiner Kurve (bei R 449 m liegt das Seilende 1,4 m neben der Deckkante:
auf dem Seitenstreifen, nicht in der Fahrbahn).
