## 2. Befunde – nachgestellt, behoben, nachgeprüft

### QR7c-01 (mittel) – Stadthäuser bei „Mittel/Steam Deck“ ab 35 m in lod1 → **behoben**

- **Nachgestellt (gemessen):** QAs Hamburg-Bild Deck 12 Uhr aus `ref` bit-genau wiederholt; der Speicher rechts steht
  bei 35–60 m in lod1 (flache Ladetüren). Ursache: `"tag:city": 35` in `graphics.modern.props.lod0_m` kürzte lod0 aller
  28 Modelle mit dem Tag `city`.
- **Fix:** `tag:city` gestrichen. lod0 endet nur noch für Fachwerkzeile, Fachwerkzeile B, Haussmann und Pariser Eckhaus
  bei 30 m („Mittel“; ihr lod0 flimmert 0,9–1,4 % gegen 0,0–0,3 % beim Sprite, von R7c gemessen); alle anderen Häuser
  behalten ihr `max_dist_m` (60 m bei „Mittel“/„Steam Deck“, 120 m bei „Hoch“ – die Entfernungen der Basis, jetzt je
  Instanz). Die Mechanik je Tag bleibt (Test `test_standing_camera_narrows_the_bands`, Mutation U11).
- **Nachgeprüft (angesehen + gemessen):** `hamburg_deck_speicher_43a1fcc_r7c_fix.png` – die grünen Ladetüren haben
  wieder ihre Kassetten, die Fenster ihre Laibungen; gegen 43a1fcc (vor R7c) unterscheiden sich im ganzen Bild nur
  432 Pixel um mehr als 15 %, gegen R7c 25 139 (2,5 % – QAs Maß). `test_lod_bands_per_model` prüft die Konfiguration
  (Speicher, Kontor, Gründerzeit, Grachtenhaus: kein Ersatz; die vier: 30 m).
- **Rest (Vertragsfrage, Abschnitt 7):** lod0 von Grachtenhaus (0,6 / 0,7 % bei 40 / 60 m) und Chalet (0,4 / 0,7 %)
  flimmert über 2 × Sprite (0,1–0,2 %); ich habe dem Look Vorrang gegeben, wie QA empfiehlt.
