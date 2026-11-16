## 4. Was nicht am Modell liegt (für R1, R3, UI1)

Diese Befunde der Kritik sind richtig, aber das Netz kann sie nicht beheben:

1. **Lackbelichtung** (A1, B8, C2): Kompakt-Gelb und Weiß übersteuern im Licht des Kontaktbogens, weil die Sonne in
   sRGB addiert wird (D5). Die Lackwerte sind die des Sprites. Am Modell nur: Weiß des Lkw auf `#d8d8d6`.
2. **Unbeleuchtete Lampen bei Tag** (B1, B2): unbeleuchtet zeichnet `vpbr` eine Lampe mit `lamp_off` 0,5 × ihrer
   Leuchtfarbe – Rot (128, 16, 8) und Bernstein (128, 80, 13) wirken eingeschaltet und flächig („Aufkleber“).
   Vorschlag: `lamp_off` 0,25–0,3 für Fahrzeuge (das Sprite zeigt die Lampen dunkelrot, `#8a0c0a` mit Klarlack).
   Am Modell nur die dritte Bremsleuchte dunkler (sie bleibt beim Bremsen voll, Verstärkung 2,2).
3. **Rücklicht-Pegel**: Kanal 2 leuchtet mit dem Rücklicht zu 35 %; die Sprite-Schicht `tail` lässt die ganze
   Leuchte voll leuchten. Die Modelle haben jetzt das volle Gewicht; ein Pegel von etwa 0,5 hielte Bremse ≥ 2 × Rücklicht.
4. **Klarlack, Spiegelung, Kontaktschatten, Umgebungsverdeckung** – Shader und Renderer.
5. **Rückstrahlende Kontur**: Kanal 14 folgt `ce_night`; besser wäre die Beleuchtung durch die Scheinwerfer des
   Spielers (`ce_headlight`), dann leuchtet sie auch im Tunnel und nicht bei Nacht ohne Scheinwerfer.
6. **Ferne Lampen** (C5): ab etwa 150 m 1–2 Bildpunkte – Schein an den Lichtankern (F6).
