## 7. Ehrliche Einordnung

**Was der Spieler jetzt sieht (angesehen, Zahlen gemessen, Wirkung auf einem echten Bildschirm gefolgert):**

- **Nachts leben die Ladenstraßen.** In Paris leuchten die Bogenläden des Eckhauses auf 23 % der Erdgeschossfläche
  (Arcade 28 %, vorher 11 %), warm und hell (Luma 197 gegen Arcade 218, vorher 159), und hinter dem Glas stehen
  Regale mit Waren, Kleiderstangen und Theken – keine weiße Fläche. In Bern leuchten die Läden unter den Lauben, die
  Gasse hat 40–46 % mehr warmes Licht als vorher. Die Gründerzeit-Läden und das Kontorhaus in Hamburg (Charge 1)
  leuchten ebenso doppelt so viel wie vorher. Die Wohnfenster sind unverändert (wie Arcade).
- **Der häufigste Gartenbaum ist ein Baum.** Südhaus (588 Platzierungen) und Loire-Haus (209) haben statt der Traube
  facettierter Steine eine Blattkrone aus Karten mit AS3-Blattbüscheln in den Farben des Generators, im Sonnenlicht
  rund schattiert; lod1 zeigt dieselben Karten, deshalb springt die Krone beim Stufenwechsel nicht (Südhaus 8,2 % geänderte Pixel statt 16,4 %).
- **Pariser Schmiedeeisen ab 60 m ruhig.** In lod1 flimmern Haussmann und Eckhaus wie ihr Sprite (0,2–0,5 %), die
  Geländer sind dort ein gemaltes Band ohne Alpha-Test; die Fassade wird mit Rückseiten-Culling gezeichnet.
- **Geranien** als niedrige Polster statt Perlenkette.

**Was noch nicht gut ist:**

- **Fernfassaden bleiben blass (K2, im Modell nicht behebbar).** Ab der Schattenreichweite (Mittel 100–120 m, Hoch
  170–200 m) werden die Fassaden 4–29 % heller und die Fenster blass (dunkles Zehntel bei 250 m +8 bis +24 Stufen
  gegen +2 bis +15 beim Sprite). Gemessen ist jetzt die Ursache: das Ende und die grobe Auflösung der Echtzeitschatten
  (ohne Sonnenschatten bleiben die Modelle über 60–250 m gleich hell, die Fenster hellen wie beim Sprite nur um 1–9
  Stufen auf; Ausnahme Maashaus +15). Der Innenring-Eingriff war wirkungslos. Im Rennen bei Dunst und Gegenlicht
  schwächer (Kritik: Paris und Bern lesen sich fern gut); die Abhilfe gehört in den Renderer.
- **Flimmern in lod0 bei 40–60 m** bleibt 5–10 × Sprite bei Haussmann und Eckhaus (0,9–1,1 % gegen 0,0–0,2 %):
  Alpha-Test der Gitter (A-22) und geometrische Sprossen/Rahmen. Die Blattkarten flimmern beim Südhaus bei 40 / 60 /
  100 / 150 m mehr als die alte Kugelkrone (0,9 / 0,9 / 1,0 / 1,5 % gegen 0,4 / 0,4 / 0,6 / 0,8 %; Sprite 0,2–0,6 %),
  beim Loire-Haus 0,5 / 0,7 / 1,3 / 1,6 % (vorher 0,4 / 0,5 / 1,0 / 1,4 %) – der Preis der ausgeschnittenen Blätter, wie
  bei jedem AS3-Kartenbaum. Abhilfe ist Sache des Renderers (Alpha-to-Coverage/TAA, Mip-Bias) oder eines kürzeren lod0.
- **Stufenwechsel** tauschen weiter 9–17 % der Pixel (Südhaus jetzt 8,2 % statt 16,4 %); Überblenden bleibt R7.
- **Ladenflanken unter spitzem Winkel** (Paris +4 s): 9 % warme Pixel gegen 24 % in Arcade – die tief liegenden
  Auslagen verschwinden hinter Laibungen; Arcade zeigt die Flanke als zur Kamera gedrehte Bildfläche.
- Unverändert: Rückseiten des Eckhauses blank (K8, 8 Platzierungen), keine Wandleuchten (K9), Tönung der Reihenhäuser
  im Ruhrgebiet fehlt bis R7 (A-19 erlaubt sie jetzt über die MultiMesh-Farbe), die Gegenseiten der Grachtenhäuser
  grob (12–15 px/m, „reused walls on the far side“).

**Was fehlt:** Messungen auf echter Grafikkarte und auf dem Steam Deck (alles hier llvmpipe), der Blick eines Menschen
auf die Blattkarten in Bewegung.
