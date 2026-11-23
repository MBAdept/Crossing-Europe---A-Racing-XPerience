Alle Modern-Bilder aus diesem Baum mit dem Renn-Aufruf von QA-R7c (`--gfx-sync`, Seed 11, Autopilot, Start 50 km/h,
Bilder 2 s und 4 s nach dem Start; Countdown: Bild bei 1,5 s), Arcade und R7c aus QAs Lieferung (bit-genau
nachgestellt). „Pixel anders“ = Pixel, die sich gegen R7c um mehr als 15 % unterscheiden (`compare -fuzz 15%`).

| Bild | gegen R7c (gemessen) | angesehen: gegen R7c / Basis | gegen Arcade |
|---|---|---|---|
| `hamburg_deck_speicher_43a1fcc_r7c_fix.png` (QR7c-01; 43a1fcc \| R7c \| FIX, Ausschnitt 1:1) | 2,5 % des Bildes (25 139 px), gegen 43a1fcc nur 432 px | **behoben:** die grünen Ladetüren des Speichers haben wieder ihre Kassetten, Fensterlaibungen mit Tiefe – wie vor R7c | besser: Backstein und Türen plastisch (Arcade: flaches Sprite) |
| `hh_deck_h12_tri_00/01.jpg` | 25 139 / 12 757 px | wie oben; sonst gleich | besser (Tiefe, Gehweg, Bäume) |
| `start_countdown_deck_basis_r7c_fix.png` (QR7c-06; Basis \| R7c \| FIX, 2×) | gegen die Basis 2 342 px | **behoben:** die Eiche unten rechts steht glatt und in lod0 wie in der Basis, kein Raster | gleich bis besser |
| `start_nu_deck_h12_tri_00.jpg` | 1 567 px | wie oben | gleich bis besser (Starttor, Bäume plastisch) |
| `start_nu_high_h12_tri_00.jpg` | 318 px | gleich (bei „Hoch“ liegen die Bänder bei 120 m; dort steht im Countdown keine Instanz im Band) | besser (Starttor, Bäume plastisch) |
| `nuernberg_hoch_fernhaus_arcade_basis_r7c_fix.png` (QR7c-04; Arcade \| Basis \| R7c \| FIX, 3×) | 2 582 px (Bild 00) | **behoben:** die weißen Fensterrahmen des fernen Barockhauses (~100 m) sind wieder weiß und scharf wie in der Basis; R7c grau und verwaschen | besser: Volutengiebel, Erker und Gauben plastisch |
| `nu_high_h12_tri_00/01.jpg`, `nu_deck_h12_tri_00/01.jpg` | 2 582 / 44 px; 276 / 10 400 px | Hoch: gleich bis auf das ferne Haus; Deck: das rosa Barockhaus rechts bis 60 m in lod0 (QR7c-01) | besser: Fachwerk plastisch, Gehweg, Laternen |
| `pa_deck_h12_tri_*`, `pa_high_h12_tri_*` | 0–2 px | gleich (Haussmann und Eckhaus enden weiter bei 30 m) | besser: Haussmann 3D, Kaimauer, Geländer |
| `hh_high_h12_tri_*`, `am_high_h12_tri_*` | 874–978 px; 1 557–1 905 px | gleich; ferne Giebel minimal schärfer | Hamburg besser; Amsterdam besser bis gleich (Grachtenhäuser, Hausboote) |

Ehrlich: Nachts (F-04, Nachtatlas der Modelle), im Lyon-Vorort und im Wald (Korridor, R7a) bleibt Modern hinter Arcade,
wie QA-R7c es für R7c festgestellt hat – FIX-R7c ändert daran nichts (nicht in diesen Befunden, nicht neu
angesehen). Das Kontor flimmert in lod1 bei 100–150 m 4–5 × so stark wie sein Sprite (Geometrie, Asset-Paket).
