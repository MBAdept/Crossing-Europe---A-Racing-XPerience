- **N2 Speichen des Riesenrads – erledigt:** Die 968 Stäbe des Rads (Speichen, Kränze, Streben, Pylone) werden ab
  etwa 250 m schmaler als ein Pixel und flimmerten in Bewegung. Sie sind jetzt eine eigene Flächenklasse („thin“):
  Der Shader macht jeden Stab mindestens 1,5 Pixel breit und zeichnet ihn entsprechend durchscheinend – so viel
  Abdunklung, wie der echte Stab hätte (gemessen 0,97–0,99 ×). Bildwechsel je Bild bei 250 / 600 / 1 000 m vorher
  6,5 / 8,8 / 4,5 %, jetzt 2,0 / 0,2 / 0,1 % – wie das Sprite (2,1 / 0,6 / 0,1 %); auch ohne Kantenglättung
  („Niedrig“) unter dem Sprite. Aus der Ferne ist die Speichenscheibe jetzt ein ruhiger, feiner Schleier statt eines
  gepunkteten Musters; aus der Nähe unverändert echte Stäbe. Das Modell ist kleiner geworden (13 944 statt 17 816
  Dreiecke, 307 statt 637 kB). Neue Render-Prüfung `check_thin_render`, Doku `docs/modelle.md` Abschnitt 25.
