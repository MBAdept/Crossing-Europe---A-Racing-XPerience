
## 1. Ergebnis in Kürze

- **Überblenden der Stufen (Leitentscheid 1, A-22):** Bauten und Pflanzen wählen ihre Detailstufe jetzt **je Instanz**
  und blenden über ein Raster-Band über (lod0 ↔ lod1 ↔ Fernbild), statt je 96-m-Stück hart zu springen. Render-Prüfung:
  größte Änderung je 0,5 m am Barockhaus 0,6 % statt 7,1 % (hart), an der Eiche (lod1 → Fernbild) 1,1 % statt 36,6 %,
  keine Löcher (gemessen). In den Clips Paris und Nürnberg bei „Mittel“ ist kein Stufenwechsel zu sehen (Bild für Bild
  angesehen, Spitzen ≤ 5,7 % über den Nachbarbildern, alle Bewegung). lod0-Entfernung je Modell aus `max_dist_m`, bis
  das Asset-Paket sie setzt per Konfiguration: Stadthäuser 35 m, Fachwerk und Paris 30 m bei „Mittel“.
- **Fernlicht (2):** jenseits der Schattenreichweite bleiben Gebäude so hell wie mit Schatten: 60 → 250 m in ±5 % für
  die gemessenen Häuser (Hoch und Mittel; vorher bis +29 %; drei Modelle mit eigenem Wert, nachgemessen); in der Nähe
  unverändert (gleiche Werte bei 60 m).
- **Flimmern (3):** Alphatest aus gröberer Mip, Farb-Bias ab 30 m, kürzeres lod0: Haussmann/Eckhaus/Grachtenhaus B,
  Loire-Haus und Bäume ≤ 2 × Sprite; Fachwerk lod1 bei 100–150 m 2,0–2,25 ×, Südhaus bei 40 m 3 × (Restkanten, nur MSAA).
- **Fenster in der Dämmerung (4):** um 19:30 leuchten so viele Fenster wie in Arcade (angesehen); 22 Uhr unverändert.
- **Fernbilder (5):** Überblenden je Baum, Relief des Sprite-Lichts nachts zurückgenommen (Nachtbilder angesehen).
- **Anbauten (6)** gebaut und mit Test-Manifest geprüft; ganze Fassaden als `baked_cutout` kosten auf llvmpipe das
  1,9- bis 2,4-fache (gemessen). **Tags und Rotorphase (7)** gebaut und geprüft. **Instanzbudget (8):** keine neue
  Instanz-Uniform.
- **Gates (Abschnitt 5):** @@GATES_KURZ@@
- **Leistung (Abschnitt 6):** ganze Etappe Kiel – Hamburg gleich schnell wie die Basis (Wandzeit 154 / 150 gegen
  153 / 149 s), 12 % weniger Primitive, 59 % weniger im Schatten, Haken der Requisiten +0,1 ms je Bild.
- **Nicht gut / offen:** nachts leuchten an Haussmann, Kontor und Fachwerk deutlich weniger Fenster als in Arcade
  (Fensterauswahl im Modell, F-04); im Lyon-Vorort und in Kurveninnenseiten des Waldes fehlen Häuser und Bäume, die
  Arcade zeigt (schon in der Basis, Korridor-Regel); Fachwerk lod1 flimmert bei 150 m noch 2,25 × Sprite.
