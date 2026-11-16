# KRITIK-3 – Unabhängige Kunstkritik von AS3 (Vegetation und Natur)

- Gegenstand: Zweig `worktree-wf_aad8d49e-fb4-1`, Stand **be866d2** (nur gelesen). Gerendert und gemessen in einer
  Kopie im Arbeitsordner (`m1/KRITIK-3/tree`: der Arbeitsbaum samt eigenem Import-Cache, ohne `build/`, `_cache3d`,
  `.git`). Keine Commits, kein Zweig, keine Datei des Arbeitsbaums geändert.
- Modelle: 18 Bäume (Eiche, Birke, Buche, Pappel, Olive, Kiefer, Fichte, Zypresse, Palme, je mit `_b`), `bush_round`
  / `_b`, `bush_low`, `heather`, `rock_a`, `rock_b`, `cliff`; `cover_bush` / `cover_grass` nur nebenbei.
- **gemessen** = auf dieser VM gemessen (Mesa llvmpipe unter Xvfb, Godot 4.7.2, die Spiel-Shader `leaves`,
  `billboard`, `vpbr`, `baked` über `ModelFactory`/`PropLibrary`, das Renn-Licht des `EnvironmentRig`);
  **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen
  Menschen) oder aus Code und Maßen abgeleitet.
- Licht der Prüfbilder: `prop_scene --look=race` von AS3 (Palette der Stunde, Nebel, Schatten, Voreinstellung
  „Mittel“). Geprüft, dass es das Rennen zeigt (die Falle der Fahrzeug-Kritik): das Rennen setzt auf `leaves` keine
  Klassen-Parameter, das Fernbild nutzt in beiden die Standardwerte von `billboard.gdshader`, die Stand-in-Sprites
  dieselben `STANDIN_*`-Werte, und den `vpbr`-Look der Fahrzeug-Ebene setzt `prop_scene` erst, nachdem das Material
  existiert (Code gelesen). Dazu neun Rennbilder mit `tools/ab_shot.sh` (Abschnitt 4): Farben und Formen stimmen mit
  den Prüfbildern überein (angesehen). Nachtbilder der Prüfszene sind **ohne** Scheinwerfer, das Rennbild bei Nacht mit.

## 1. Die Antwort für den Nutzer

**Frage: Sind die Modelle sichtbar feiner als die Arcade-Sprites und gut genug, um stundenlang daran vorbeizufahren?**

- **Ja für die meisten Bäume.** Im Rennen (Kiel–Hamburg, Hamburg-Innenstadt, Pappelallee in der Lombardei,
  Sauerland-Wald an der Stelle des Leistungstests, Mittelmeer; Bilder 01, 15, 18) sind Eiche, Buche, Pappel, Fichte,
  Kiefer und Olive deutlich feiner als ihre Sprites: laubige Kronen mit Sonnen- und Schattenseite, Nadelzweige,
  echte Schlagschatten, und sie stehen, wo Arcade sie zeigt.
  - Umriss lod0 in der Sprite-Kamera 0,8–9 % außerhalb des Sprites (gemessen, Bild 04).
  - Kein Glitzern bei 120 km/h: Viertel-Pixel-Test 0,75–1,65× so viel wie das Sprite (gemessen), Film angesehen.
  - Ruhige Kronen aus der Nähe, keine Kartenkanten aus keiner von 8 Drehungen (angesehen).
  - Ferne Bäume verblassen im Nebel genau wie die Sprites (angesehen, Bild 17).
  - Nachts im Rennen gleich hell wie Arcade (Ausschnittsmittel innerhalb von 2 Grauwerten, gemessen).
  - Die Mängel von AS1b (Kartenstreifen, unruhige Krone, helle Aststummel, blasse Fernbilder) sind behoben.
- **Drei Dinge sind gröber als das Sprite** und gehören vor die Spieler repariert:
  1. **Birkenstamm** (M1): bis etwa 40 m ein Schachbrett aus schwarzen und weißen Dreiecken. 88 Birken stehen in den
     ersten 75 km Kiel–Hamburg neben der Fahrbahn. Eine Stunde Arbeit in `_bark_colour`.
  2. **Palme** (M8): dünne, stehende Wedel, ein gestreifter heller Pfahl. Umriss 20 % (`_b` 57 %) außerhalb des
     Sprites (gemessen).
  3. **Klippe** (M2): Der Props-Bauer dreht sie zufällig. Von hinten sieht man zerrissene Lappen, von der Seite ein
     dünnes Horn (Rennbild von AS3, Lyon–Bern km 148,7).
- **Mittlere Mängel:**
  - Nahe Kronen unter 25 m (Stadtbäume, Steam Deck) enden in geraden Vieleck-Kanten (M3).
  - Büsche sind unter 40 m facettierte Brocken (M4).
  - Fernbilder verlieren 30–80 % Kontrast und 5–19 % Sättigung gegen lod1 (gemessen, M5).
  - Ganze 96-m-Abschnitte wechseln die Stufe auf einmal (M6).
  - Flache Pflanzen und Felsen schweben am Hang (M7, Props-Bauer).
  - Die Vegetation belegt schon 35,6 der 60 MB Archiv-Texturbudget, 15,8 MB davon doppelt (M9).
- **Empfehlung:**
  - Eiche, Buche, Pappel, Fichte, Kiefer, Olive, Zypresse, Büsche, Heide und Felsen können in den Testbuild.
  - Den Birkenstamm vor dem Kiel–Hamburg-Build reparieren (AS1b hatte denselben Stamm; AS3 ist also nicht
    schlechter, nur nicht besser).
  - Palme und Klippe in die Nacharbeit (M2) – Süden und Berge sind nicht im ersten Testbuild.

| Modell | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Eiche (+ `_b`) | **feiner** | ja | Blattwerk, Licht/Schatten je Kuppel, Äste, Schlagschatten; Umriss 2 % außen | Kuppel-Unterkanten < 25 m, kleine Himmelslöcher, `_b` zwei Zweige oben (M3) |
| Birke (+ `_b`) | Krone feiner, **Stamm gröber** | **nein** (Stamm) | lichte Krone, weißer Stamm aus der Ferne | Schachbrett-Stamm (M1); Fernbild blass, Sättigung −19 % (M5) |
| Buche (+ `_b`) | **feiner** | ja | breite, dichte Krone, glatter grauer Stamm | als Stadtbaum in 6–10 m die Kuppelkanten (M3) |
| Pappel (+ `_b`) | **feiner** | ja | Laubsäule, die Allee liest sich | Fernbild flach, Kontrast −48 % (M5) |
| Olive (+ `_b`) | **feiner** ab 40 m | ja | silbergrau, knorrig, im Rennen schöner als das Sprite | unter 20 m Tarnmuster (M10) |
| Kiefer (+ `_b`) | **feiner** | ja | Waldkiefer wie das Sprite: hoher oranger Stamm, flache Polster | flimmert in 80–150 m 1,4–1,7× so viel wie das Sprite (M11) |
| Fichte (+ `_b`) | **feiner** | ja | Nadelzweige, Etagen, dunkler Kegel; im Leistungstest-Bild klar besser | Fernbild ohne Etagen, Kontrast −65 %, nachts +26 % (M5) |
| Zypresse (+ `_b`) | gleich | ja | glatte dunkle Flamme wie das Sprite | eine Windphase für die ganze Krone (M11) |
| Palme (+ `_b`) | **gröber** | **nein** | Fiedern, Ringstamm aus der Nähe | dünne, stehende Wedel, gestreifter heller Pfahl, Umriss 20 / 57 % außen (M8) |
| Busch rund (+ `_b`), niedrig | gleich | ja | im Rennen dunkle, laubige Klumpen | unter 40 m facettierte Brocken, blasser (M4); schwebt am Hang (M7) |
| Heide | gleich | ja | lila Flecken mit Blütentextur | schwebt am Hang (M7) |
| Fels a / b | gleich | ja | echte Facetten, Moos, Risse | schwebt am Hang (M7) |
| Klippe | von vorn gleich, gedreht **gröber** | **nein** | Schichten und Sträucher wie das Sprite | Rückseite zerrissen, von der Seite ein Horn, Zacken am Grat (M2) |

