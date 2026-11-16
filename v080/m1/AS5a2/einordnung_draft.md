### Ehrliche Einordnung

Gut (angesehen in Kontaktbögen, Nahansichten und Spielkamera; Rennen siehe Lieferordner): Umriss, Geschosse, Dächer,
Giebel und Farben wie das Sprite; Tiefe an Front und Straßenflanke – Laibungen, Rahmen, Sprossen, Sohlbänke,
Fensterläden als Geometrie (Südhaus, Loire-Haus, Lyon, Chalet, Grachtenhaus B), Haussmann-Balkone mit Konsolen und
durchgehendem Schmiedeeisen, französische Fenstergitter vor echten Fenstern, Läden mit Auslage (Lyon, Brüssel, Bern,
Paris), die Arkaden der Lauben als echte Öffnungen, Blausteinstürze, Gesimse, Treppen-, Glocken-, Hals-, Gesims- und
Volutengiebel. Die Straßenflanken, im Sprite blind, haben Fenster und Türen im Stil der Front. Nachts leuchten
dieselben Fenster wie im Sprite, die Auslagen mit Waren dahinter.

Noch nicht gut:
- **Schwächster Punkt – Schaufenster nachts.** Die Auslagen leuchten, aber dunkler als die Schaufenster in Arcade
  (beleuchtete Ladenpixel im Mittel 124 gegen 207 in Arcade; ein beleuchtetes Wohnfenster 210, gemessen). Am
  deutlichsten in Paris (Haussmann-Bogenläden) und Lyon. Ursache: die gemeinsame Helligkeit der Auslage im Bauer
  `city` (`_display_mat`), die auch Charge 1 trägt; eine Anhebung (Vorschlag `shop_glow` ≈ 1,6) ändert den
  Cache-Schlüssel aller 23 Stadthäuser und braucht einen vollen Neu-Export – nicht mehr in diesem Paket.
- **Rückseiten:** Das Haussmann-Eckhaus hat hinten blanke Putzwände (für die abgeschrägte Grundfläche findet der Bauer
  keine gegenüberliegende Wand zum Wiederverwenden); die rechte Flanke des Halsgiebelhauses (Grachtenhäuser) ist
  blind. Beides sieht man nur, wenn die Straße das Haus umfährt (gefolgert: selten).
- **Fern (200–250 m, lod1):** Fensterreihen heller als im Sprite (Rahmen und Sprossen überwiegen das dunkle Glas). Im
  Rennen bei Paris nicht auffällig (angesehen), in der Prüfszene deutlich.
- **Bäume** von Südhaus und Loire-Haus sind dezimierte Kronen – aus der Nähe Klumpen, aus der Spielkamera ok.
- **Flimmern** 0,3–1,3 % der Pixel je Viertelpixel-Schritt gegen 0,0–0,5 % beim Sprite (gemessen): das Modell ist
  unruhiger als das vorgefilterte Sprite, vor allem Haussmann und Chalet (Geländer, Sprossen).
- **Stufenwechsel** lod0 → lod1 bei 60 m ändert 8–18 % der Pixel ohne Überblenden (R7).
- **Texeldichte Lauben:** beim größten Maßstab 1,10 liegt das Erdgeschoss mit 39,8 px/m knapp unter 40 (gemessen).
- **Erfundene Flankenfenster:** an Brandwänden (Grachten-, Reihenhäuser) – gewollt, aber nicht vorbildgetreu.
- **Keine Wandleuchten** an den Fassaden; das Nachtbild lebt allein von den Fenstern.
