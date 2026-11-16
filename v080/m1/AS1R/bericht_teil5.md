## 7. Abweichungen, abgelehnte und offene Befunde

- **A3 (abgelehnt in der Ursache):** Der schwarze Keil war nicht das Ende der Heckblende, sondern die Ecke der
  Hutablage; behoben wurde beides (Blende über der Mulde weggeschnitten, Hutablage folgt der Außenhaut).
- **A4 Limousine (abgelehnt in der Ursache):** Im Reifen steckten nicht Radlaufschale und Schweller, sondern der
  Boden der Innenraumwanne (Farbe `#17181a` = Wanne). Behoben über die Wanne.
- **C1 anders als vorgeschlagen:** Kanal 14 statt Kanal 9 – die Markierung behält bei Tag ihre helle Farbe (Kanal 9
  zeigte sie unbeleuchtet mit halber Leuchtfarbe dunkler) und leuchtet nachts mit `ce_night`. Das Gewicht war 1,0,
  nicht 0,79; dunkel machte sie `plate_energy` 0,45.
- **B1:** Die Hauptursache (`lamp_off` 0,5) liegt im Shader (R3); am Modell nur die dritte Bremsleuchte.
- **B2 nicht umgesetzt:** Die Leuchten der Verkehrsautos bleiben eingeschnittene Felder ohne Streuscheibe und Tiefe.
  Die Konturen sind schon die der Entwurfstabellen; das Bernsteinfeld ist nur im 3D-Entwurf (Regel 9: ≥ 60 cm² je
  Seite). Eine 2-mm-Streuscheibe als zweite Lage widerspräche A-4 (eine Lage) und dunkelte im 8-Bit-Bild Leuchten bei
  Nacht genauso ab wie bei Tag; der Eindruck „eingeschaltet“ verschwindet erst mit dunkleren unbeleuchteten Lampen.
- **B3 bei 120 m nicht erreicht:** 22–34 % statt ≤ 10 %; der Rest ist der grobe Querschnitt und die Kabine von
  `lod2` (Budget 1 200; das Schrägheck hat keinen dunklen Heckabschluss, 20 Dreiecke Luft).
- **Kombi `lod2`, dritte Bremsleuchte** (Kontur ein Drittel, IoU 0,36) und **A8, A9** (Heckblinker als Lichtleiter,
  Rückleuchte von schräg vorn) nicht bearbeitet (niedrig); **C4** (Fahrerhaus) gehört zu AS2b, **C5** zu R3.
- **A7** (Flimmern) behoben nach Vorschlag, aber nicht neu gemessen.
- Verkehrsautos: Reifen mit 9 statt 15 Profilpunkten (`tyre_lite`), um Platz im Budget zu schaffen.
