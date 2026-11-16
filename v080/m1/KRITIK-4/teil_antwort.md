# KRITIK-4 – Unabhängige Kunstkritik von AS4 (Gebäude, Brückenteile, Schiffe)

- Gegenstand: Zweig `worktree-wf_aad8d49e-fb4-2`, Stand **9eef9a8** (nur gelesen). Gerendert und gemessen in einer
  Kopie im Arbeitsordner (`m1/KRITIK-4/tree`, `diff -rq` gegen den Arbeitsbaum: identisch). Keine Commits, kein Zweig,
  keine Datei des AS4-Arbeitsbaums geändert.
- Modelle: `house_med`, `church`, `factory`, `windmill` (von AS1b, Fenster neu), `building_shop`, `building_oldtown`,
  `building_block_a`, `building_block_b`, `building_tall`, `houseboat`, `ferry_ship`, `bridge_lamp`, `bridge_pylon`,
  `bridge_truss_arch`.
- **gemessen** = auf dieser VM gemessen (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader über
  `ModelFactory`, das Renn-Licht des `EnvironmentRig`); **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht
  messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen) oder aus Code und Maßen abgeleitet.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Modelle sichtbar feiner als die Arcade-Sprites und gut genug, um stundenlang daran vorbeizufahren?**

- **Die Gebäude: ja.** Haus, Kirche, Fabrik, Ladenhaus, Altstadthaus und beide Wohnblöcke sind in der Nähe deutlich
  feiner als ihre Sprites – echte Fensterlaibungen mit weißen Rahmen, Sprossen und Sohlbänken, Fensterläden mit
  Lamellen, Balkone, die Schatten auf die Fassade werfen, Rinnen und Fallrohre, Mauerwerk im Ziegelverband, Ziegel- und
  Schieferdächer, Uhren und Schallluken am Kirchturm, Werkszeichen, Sprossenfenster und Rolltor an der Fabrik
  (angesehen, Bilder 21, 22). Umriss, Dach und Fensterraster decken sich mit den Sprites (IoU 0,986–1,000, gemessen),
  sie stehen im Rennen, wo Arcade sie zeigt, in gleicher Größe und Farbe (Bilder 02, 03), und sie flimmern nicht mehr
  als die Sprites (0,0–0,9 % gegen 0,1–1,7 % kippende Pixel, gemessen). Ab etwa 250 m sind sie dem Sprite gleich – mehr gibt die
  Auflösung nicht her. Nachts leuchten einzelne Fenster warm und unregelmäßig, Kirchturm, Uhren und Fabrikhalle haben
  eigenes Licht, bei Tag leuchtet nichts.
- **Die Brückenteile: der Pylon ist im Rennen kaputt.** Seine Seile enden mitten in den Fahrspuren, 0,6 m über dem
  Belag, und reichen vor die Brücke auf die Zufahrt; man fährt durch einen Käfig weißer Stäbe (M1, Bild 01, gemessen am
  Netz und im Rennbild Kiel–Hamburg km 77,9–79,0). Das liegt auf der Etappe des ersten Testbuilds, kurz vor dem Ziel.
  Laterne und Fachwerkportal sind gut (feiner bzw. gleich, flimmern weniger als die Sprites).
- **Die Schiffe:** dem Sprite gleich, aber im Rennen stehen sie auf der Wiese, weil Modern noch kein Wasser hat
  (M2, R5).
- **Was man stundenlang sieht und was stört:** (1) bei Tag verraten die Fenster, welche nachts leuchten – braune
  neben blauen Scheiben auf jeder Fassade, am Büroturm ein Schachbrett (M3; das häufigste Modell-Merkmal im Bild);
  (2) nachts leuchten die Fenster matter als in Arcade (M6); (3) die Glasbänder des Fabrik-Sheddachs leuchten nachts als
  reinweiße Flächen, sichtbar von vorn, hinten und von der abgewandten Seite (M4); (4) die Windmühlenflügel flimmern 2–3× so stark wie das Sprite (M7).
- **Empfehlung:**
  - In den Testbuild können: Haus, Kirche, Fabrik (mit M4 als bekanntem Mangel), Ladenhaus, Altstadthaus, Block A und B,
    Büroturm, Brückenlaterne, Fachwerkportal, Windmühle.
  - **Nicht** in dieser Form: der Pylon (M1 – vor dem Kiel–Hamburg-Build reparieren oder durch den Arcade-Weg ersetzen:
    Modell ohne Seile + Seile vom Renderer) und die Schiffe ohne Wasser (M2 – ausblenden, bis R5 Wasser hat).
  - Nacharbeit AS4-N: M1, M4, M5, M7 (Modelle), M3/M6 zusammen mit dem Shader-Besitzer.

URTEILSTABELLE
