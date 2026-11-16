## Messungen

Alle Zahlen **gemessen** auf dieser VM (Software-OpenGL llvmpipe unter Xvfb, Renn-Look der Prüfszene, Voreinstellung
wie angegeben), wenn nicht anders gesagt. Was ein echter Grafikchip, das Steam Deck oder ein Mensch davon sieht, ist
**gefolgert**.

### Umriss gegen das Sprite (`k4_scene --mode=outline2`, Sprite-Kamera des Sets, Bild `umrisse_sprite_gegen_modell.jpg`)

| Modell | lod0 außerhalb | Sprite gedeckt | IoU lod0 | IoU lod1 |
|---|---|---|---|---|
{{UMRISS}}

Proportionen, Geschosse, Dachformen, Giebel und Fensterraster stimmen mit dem Sprite überein (gleicher Generator).
Der Kran bleibt bei 0,92: Gitterstäbe und Seil sind im Modell echte dünne Stäbe, im Sprite weichgezeichnete Pixel.

### Texeldichte

Aus dem Bake (`ppm_road` des Export-Berichts, Modellmaß; Straßenwände = Flächen zur Straße und zur Anfahrt):
Spalte „px/m Straße“ der Budgettabelle. Im Spiel teilt sich das durch den Maßstab der Platzierung (Zählung: 0,85–1,2;
Büroturm 0,37–0,5, dort also das 2- bis 2,7-Fache).

- Vertrag ≥ 26 px/m an den Straßenwänden: erfüllt von allen Gebäuden außer dem Büroturm im Modellmaß (15,9–21,2 px/m,
  im Spiel bei Maßstab 0,37–0,5 **32–57 px/m**, gerechnet aus gemessenem Modellmaß).
- Innenstadt ≥ 40 px/m im Erdgeschoss und ersten Obergeschoss (`floors`): Fachwerkzeile 43,8, Turmhaus 52,1,
  Barock 47,2, Gründerzeit ≥ 40,8, Giebelzeile 41,9, Speicher 42,6, Kontor 41,2 px/m (Modellmaß). Im Spiel bei
  Maßstab bis 1,15–1,2 liegen Kontor (34) und Giebelzeile (36) knapp darunter (gerechnet).
- Obergeschosse 29,8–41,7 px/m (Faktor 0,7–0,8), Dächer 2–6 px/m (Gewicht 0,25–0,55), Rückseiten: Texel der
  Straßenwand gespiegelt (Spalte „Rückseite“: so viele abgewandte Wände ohne eigene Texel).
- Godot-Probe `texel_probe.gd` (UV-Fläche × Atlas gegen Weltfläche je Flächenrichtung, alle Teile gemittelt):
  `meas_texel.log` im Arbeitsordner; dieselbe Größenordnung (Büroturm 8,6–16,7, sonst 22–56 px/m an Wänden).

### Stufenwechsel lod0 → lod1 bei 60 m („Mittel“; `prop_scene --mode=lods`, Anteil der Pixel mit Σ|ΔRGB| > 0,06 / der 3×3-Blöcke, mittlere Helligkeit)

| Modell | 12 Uhr | 22 Uhr |
|---|---|---|
{{STUFEN}}

Kein Fernbild (lod1 gilt bis zum Ende der Sichtweite; „lod1 > Fernbild 0,0 %“). Silhouette, Geschosse und
Fensterrhythmus bleiben; was wechselt, sind Laibungsschatten, Sprossen, Türflügel und – bei den Fachwerkhäusern – die
Hölzer (lod0 echte Hölzer, lod1 das gemalte Fachwerk). Die AS4-Gebäude lagen bei 3–11 %; die Stadthäuser liegen höher
(10–32 %), weil sie mehr Tiefe haben. Die mittlere Helligkeit springt höchstens um 4,6 % am Tag und 9,1 % in der Nacht.

### Flimmern (`my_scene --mode=sparkcam`, Viertelpixel-Schritte seitlich, Anteil der Pixel, die je Schritt um > 0,2 kippen; „Mittel“, 12 Uhr)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
{{FLIMMER}}

Gemessen auf den Exporten vor dem Türfix (Runde 6 ändert nur Türöffnungen im Erdgeschoss von lod0; Kontor, Mietshaus und Gründerzeit sind unverändert). Die Stadthäuser flimmern 2–10× so stark wie ihre Sprites, absolut 0,3–1,3 % der Pixel je Viertelpixel-Schritt; AS4R nannte Block B mit 1,0 % gegen 0,2 % als Schwäche – die Fachwerkzeile liegt in derselben Größe (Messbild `flimmern_messbild.jpg`).

### Geländer (`baked_cutout`, `mipcov.py` auf den Atlanten)

Deckung des Alpha-Tests (0,5) je Mip-Stufe gegen Mip 0 in 16×16-Blöcken mit Geländer: Mietshaus mip1–3 1,11 / 1,20 /
1,40, mip4 0,29; Gründerzeit 1,12 / 1,19 / 1,32, mip4 0,59. Bis Mip 3 (gerechnet: bis etwa 50 m Abstand bei 150
Texeln je Meter) bleibt das Geländer geschlossen und eher dichter; ab Mip 4 (etwa ab 100 m) dünnt es aus. Halo-Alpha 0,33
(unter der Schwelle 0,5): in den Nahansichten bei Tag und Nacht kein heller oder dunkler Saum zu sehen (angesehen,
nicht gemessen); das Flimmern der Geländer ist in den Werten von Mietshaus und Gründerzeit oben enthalten.
