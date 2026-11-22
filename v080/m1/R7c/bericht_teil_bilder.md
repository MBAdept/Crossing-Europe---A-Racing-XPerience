### 3.5 GPU-Kosten ganzer Fassaden als `baked_cutout` (Leitentscheid 6, gemessen auf llvmpipe)

24 Instanzen von lod0 in einem Bild (`tools/r7c_tmp/cutout_cost.gd`, nicht eingecheckt), Bildzeit je Bild, zwei Läufe:
Haussmann mit der ganzen Fassade als `baked_cutout` 846 / 878 ms, dieselbe Fläche als `baked` (kein Alphatest,
Rückseiten weg) 480 / 402 ms; Südhaus 681 / 670 gegen 286 / 274 ms. Auf llvmpipe kostet der Alphatest über der ganzen
Fassade also das 1,9- bis 2,4-fache (ohne frühen Tiefentest, beide Seiten); auf einer echten Grafikkarte kleiner,
aber in dieselbe Richtung (gefolgert). Das stützt die dritte Fläche je Stadthaus (opake Fassade `baked`, nur Geländer
und Laub als `baked_cutout`), sobald ein Modell-Paket sie baut.

## 4. Bilder Arcade | Modern (angesehen)

Alle A/B-Bilder mit `tools/ab_shot.sh` (gleicher Simulationsstand, Seed 11, Autopilot, Start mit 50 km/h, Bild 2 s nach
dem Start), Ordner `m1/R7c/shots/city/` (20 Läufe, alle Exit 0, 0 Fehlerzeilen), Auswahl in `deliver/R7c/`.

| Ort | Hoch 12 Uhr | Mittel 19:30 | Hoch 22 Uhr |
|---|---|---|---|
| Hamburg (Kiel – Hamburg km 88,6) | besser: Backsteinfassaden mit Tiefe, Gehweg, Schatten | gleich bis besser: Fenster leuchten wie in Arcade (vorher weniger) | schlechter in einem Punkt: rechts leuchten weniger Fenster als in Arcade (Fensterauswahl im Modell, F-04) |
| Nürnberg (Würzburg – Nürnberg km 102,4) | besser: Fachwerk mit Tiefe, Stadtmauer, Licht | gleich bis besser: Fenster des Bürgerhauses leuchten | schlechter in einem Punkt: das Fachwerk links bleibt dunkler als in Arcade (Fensterauswahl, F-04) |
| Paris (Lüttich – Paris km 387,9, Brücke) | besser: Brückengeländer, Kaimauern, Wasser; Haussmann bei 120 m nicht blass | besser: Läden warm, Fenster wie Arcade | **schlechter**: die Obergeschosse des Haussmann-Hauses bleiben dunkel, Arcade zeigt viele helle Fenster; Läden und Laternen besser (F-04, Nachtatlas der Modelle) |
| Amsterdam (Bremen – Amsterdam km 357,7) | gleich bis besser: Grachtenhäuser fein; Hausboote | gleich bis besser: Hausboote und Giebel beleuchtet | gleich |
| Bern (Lyon – Bern km 302,7) | besser: Lauben, Blumen, Gehweg | besser: ferne Lauben mit Licht | besser: Lauben beleuchtet, ruhige Fenster |
| Lyon-Vorort (Montpellier – Lyon km 286) | **schlechter**: Arcade zeigt rechts nah Häuser mit Gartenbäumen und Mauern, Modern dort freies Feld – schon in der Basis so (`basis_lyon_vorort_hoch_12.jpg`); vermutlich der Kurvenkorridor (F7, R7a) | – | – |
| Wald (Dortmund – Frankfurt km 48–50) | gleich: Fichten und Laubbäume ähnlich; rechts in der Kurve weniger Bäume als Arcade (Korridor, R7a) | – | siehe `wald_*` |

Basis gegen R7c (gleiche Stelle, `basis_*.jpg`): in der Nähe gleich (der neue `light()` ändert dort nichts); ferne
Fassaden über der Schattenreichweite etwas dunkler und satter (das Ziel), Stadthäuser zwischen 35 und 60 m jetzt in
lod1 (kaum sichtbar: lod1 trägt dieselben Atlanten).

Urteil: In den Städten ist Modern bei Tag klar besser als Arcade (Tiefe, Gehwege, Schatten, Details), in der
Dämmerung mindestens gleich, nachts gemischt: Läden, Laternen und Lauben besser, aber an Haussmann (Paris), Kontor
(Hamburg) und Fachwerk (Nürnberg) leuchten deutlich weniger Fenster als in Arcade – die Auswahl der Nachtfenster im
Modell (FIX-RINT F-04, Asset-Pipeline), nicht das Gesetz über die Stunde. Nicht besser: der Lyon-Vorort und Kurveninnenseiten im Wald, wo Modern Häuser und Bäume weglässt, die Arcade
zeigt (Korridor-Regel, nicht dieses Paket).
