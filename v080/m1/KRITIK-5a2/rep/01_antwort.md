## 1. Die Antwort für den Nutzer

**Frage: Sind die Stadthäuser sichtbar feiner als die Arcade-Bilder und gut genug, um stundenlang durch die Städte zu
fahren?**

- **Feiner: ja – bei Tag bei allen zwölf, bei zehn deutlich.** Von 5 bis etwa 150 m haben die Häuser echte Tiefe, wo
  Arcade eine flache, aus der Nähe verschwimmende Bildfläche vorbeischiebt: Haussmann-Flanken mit Bogenläden,
  Auslagen, Konsolen und Schmiedeeisen, Lyoner Haus mit Quadern, Läden und Fenstergittern, Berner Lauben als echte
  Arkaden mit Blumenkästen, Grachtenhäuser mit Treppen-, Glocken- und Halsgiebeln und Fenstern an der Straßenflanke,
  Maashaus mit Blausteinbändern und Kreuzstockfenstern (Bilder 01, 03, 04, 06, 10, 20). Umriss, Dächer, Farben und
  Fensterraster sind die des Sprites (IoU 0,945–0,999), Budgets und Bytes stimmen (größtes Modell 6 518 Dreiecke,
  2 Aufrufe je Stufe, Archiv 0,94 + 5,82 MB). Bern ist das stärkste Bild der Charge; Chalet und Südhaus sind nur
  etwas feiner (ihr Garten sieht aus wie im Sprite).
- **Stundenlang: bei Tag ja, nachts in den Ladenstraßen noch nicht.** Nachts leuchten die Wohnfenster wie in Arcade
  (Paris 4,0 gegen 4,0 % der Fassade, Amsterdam gleich), die **Schaufenster aber auf einem Drittel der Fläche und
  deutlich dunkler** (Paris: Ladenfläche 8,9 gegen 24,4 %, Helligkeit 149 gegen 203; Bern: warmes Licht im Bild
  1,5–2,0 gegen 3,7–4,0 %) – eine Pariser Straße wirkt in Modern nachts dunkler und leerer als in Arcade (K1, Bild 02).
  Weitere Schwächen, die man auf Dauer sieht: ab 100 m werden die Fassaden blasser und ihre Fenster zu rosa-lila
  Flecken (K2, Bild 29), Schmiedeeisen und Sprossen der Pariser Häuser flimmern bei 40–100 m 3–11× so stark wie das Sprite und
  schließen sich in der Ferne zu dunklen Bändern (K4) – im Fahrfilm durch eine Pariser Prüfstraße sind die fernen
  Zeilen 2–3× so unruhig wie die Arcade-Straße (Bild 43/44), dafür scharf statt verschwommen, der Gartenbaum des häufigsten Modells ist aus der Nähe eine
  facettierte Klumpen-Krone (K3), der Stufenwechsel bei 60 m tauscht 9–18 % der Pixel ohne Überblenden (K5).
- **Nicht an den Modellen, aber im Rennen sichtbar:** In Lyon und Bern fehlen in Kurven ganze Häuser (Kurvenkorridor,
  FIX-M2 B-01 ist in diesem Stand noch nicht enthalten); die niedrigen Garten- und Backsteinmauern und Hecken am
  Straßenrand fehlen, bis R6 den Bauer `city` liefert; sonnige helle Fassaden sind 15–20 % heller als in Arcade (R4).
- **Empfehlung:** Die zwölf Modelle können in den nächsten Testbuild – sie sind bei Tag klar besser als die
  Arcade-Bilder, nichts ist kaputt, kein Prüfer rot. Vor einem Testbuild, in dem der Nutzer nachts durch Paris fährt,
  sollte K1 (Ladenlicht, eine Formel in `cities3d._display_mat`, ein Neu-Export beider Chargen) erledigt sein. In
  derselben Nacharbeit AS5a-N: K2 Fernfenster, K3 Gartenbaum/-mauer, K4 Geländer in lod1, K7 Geranien. Die Leitung
  sollte vorher die Vertragsfragen 1 und 2 entscheiden (Abschnitt 7) – sie betreffen auch AS5b.

| Modell (Platzierungen) | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Südhaus (588) | etwas feiner | ja | Läden mit Fensterläden, Balkongitter, Genoise, Kanalziegel | Gartenplatane als Klumpen, Gartenmauer 15 px/m (K3); ganze Fassade `baked_cutout`; lod1 = 69 % von lod0 |
| Lütticher Reihenhäuser (315) | **feiner** | ja | vier Ziegelarten, Blausteinstürze, Gauben, Café, Flanke mit Fenstern und Tür | Café nachts vermutlich wie die Pariser Läden zu dunkel (gleiche Formel, gefolgert; K1) |
| Loire-Haus (209) | **feiner** | ja | Tuffstein mit Quadern, Fensterläden, Steingauben, Kamine | Gartenbaum/-mauer (K3), lod1 flimmert 1,0–1,4 % (K6) |
| Lyoner Haus (202) | **feiner** | ja | Quaderecken, Läden, Fenstergitter, Balkon, Bäckerei um die Ecke | Gitter schließen sich (Mip 4: 4,2-fach), Bäckerei nachts dunkel (gleiche Formel, gefolgert) |
| niederl. Reihenhäuser (130) | **feiner** | ja (Tönung fehlt, R7) | Ziegelreihen, breite Gauben, Endgiebel mit Fenster und Seitentür | Tönung `#ead6cc` an 50 Stellen (R7) |
| Maashaus (96) | **feiner** | ja | Blausteinbänder, Kreuzstockfenster, Treppengiebel, Rundbogentür | fern am blassesten (Fenster-p10 +21) |
| Haussmann-Block (55) | **deutlich feiner** | ja, mit K1/K4 | Bogenläden mit Auslage, Konsolen, Balkone, Verdachungen, Zinkmansarde | Flimmern 1,0–1,2 % (Sprite 0,0–0,3), Läden nachts dunkel |
| Chalet (54) | etwas feiner | ja | Blockbau, Fensterläden, Holzbalkone, tiefe Traufe, Holzstapel | Geranien als Perlenkette (K7), IoU 0,945 |
| Grachtenhäuser A (51) | **feiner** | ja | drei Giebelformen, Flanke mit Schiebefenstern, Stufen | Gegenseite 12–15 px/m; Wechsel bei 120 m 22,6 % |
| Lauben (46) | **deutlich feiner** | ja | Arkaden als echte Öffnungen, Läden darin, Blumenkästen, Gauben | Arkaden nachts dunkler als Arcade (K1) |
| Grachtenhäuser B (22) | **feiner** | ja | Gesimshaus mit Kranzgesims um die Ecke, Speicher, Renaissance-Giebel | flimmert 0,7–1,0 % (K6) |
| Haussmann-Eckhaus (8) | **deutlich feiner** | ja | abgeschrägte Ecke mit Laden, Balkone um die Ecke | Rückseite blank 9–12 px/m (K8) |
