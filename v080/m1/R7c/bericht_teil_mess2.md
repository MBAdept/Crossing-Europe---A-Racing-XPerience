Vorher = Stand der Basis (Alphatest bei Mip 0, kein Farb-Bias); Sprite = die Vertretung desselben Sets im selben Licht.

| Modell | Stufe | vorher 40 / 60 / 100 / 150 m | nachher | Sprite |
|---|---|---|---|---|
| Haussmann | lod0 | 0,9 / 1,1 / 1,2 / 0,9 % | lod0 endet bei 30 m (Mittel) | 0,0 / 0,2 / 0,3 / 0,4 % |
| Haussmann | lod1 | 0,2 / 0,2 / 0,3 / 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 % | |
| Pariser Eckhaus | lod0 | 1,1 / 1,1 / 1,2 / 1,0 % | lod0 endet bei 30 m | 0,1 / 0,2 / 0,2 / 0,3 % |
| Pariser Eckhaus | lod1 | 0,1 / 0,2 / 0,2 / 0,4 % | (wie vorher, kein Ausschnitt in lod1) | |
| Fachwerkzeile | lod0 | 1,1 / 1,3 / 1,9 / 3,1 % | lod0 endet bei 30 m | 0,1 / 0,1 / 0,2 / 0,4 % |
| Fachwerkzeile | lod1 | 0,2 / 0,2 / 0,6 / 1,1 % | 0,2 / 0,2 / 0,4 / 0,9 % | |
| Grachtenhäuser B | lod1 | – | 0,2 / 0,3 / 0,3 / 0,5 % | 0,1 / 0,2 / 0,2 / 0,4 % (AS5aR2) |
| Kontor | lod1 | – | 0,2 / 0,2 / 0,5 / 0,9 % | – |
| Südhaus (Gartenbaum-Karten) | lod1 | 0,8 / 0,9 / 1,0 / 1,5 % | 0,6 / 0,5 / 0,7 / 1,1 % | 0,2 / 0,3 / 0,4 / 0,6 % |
| Loire-Haus (Gartenbaum) | lod1 | 0,4 / 0,6 / 1,3 / 1,6 % | 0,3 / 0,4 / 1,0 / 1,1 % | 0,2 / 0,4 / 0,6 / 0,9 % |
| Eiche | lod0 / lod1 | 0,7 / 1,1 / 1,8 / 2,9 – 0,7 / 1,2 / 2,1 / 3,3 % | unverändert | 0,6 / 0,8 / 1,3 / 2,0 % |
| Buche | lod0 / lod1 | 0,6 / 0,9 / 1,7 / 2,2 – 0,7 / 1,1 / 1,9 / 2,5 % | unverändert | 0,5 / 0,8 / 1,3 / 1,9 % |
| Kiefer | lod0 / lod1 | 2,2 / 4,3 / 8,7 / 12,1 – 2,2 / 4,1 / 8,4 / 11,9 % | unverändert | 2,0 / 3,0 / 4,6 / 7,0 % |

lod0 anderer Stadthäuser bei 40 / 60 m (mit den neuen Bias-Werten; daher das kürzere lod0 von 35 m für alle Häuser
mit dem Tag `city`): Gründerzeit 0,4 / 0,3 %, Barock 0,5 / 0,4 %, Kontor 0,3 / 0,2 %, Speicher 0,4 / 0,3 %, Lyoner Haus
0,3 / 0,2 %, Lütticher Reihe 0,3 / 0,3 %, Grachtenhaus 0,6 / 0,7 %, Chalet 0,4 / 0,7 %, Fachwerkzeile B 1,4 / 1,1 % –
Sprites 0,0 … 0,2 %.

Urteil gegen „höchstens 2 × Sprite“ (40–150 m, in der Stufe, die bei „Mittel“ dort steht): erfüllt für Haussmann,
Eckhaus, Grachtenhäuser B, Loire-Haus und die Bäume (Eiche ≤ 1,65 ×, Buche ≤ 1,4 ×, Kiefer ≤ 1,8 ×); knapp darüber
Fachwerkzeile lod1 bei 100 / 150 m (2,0 / 2,25 ×) und Südhaus bei 40 m (3 ×, 0,6 gegen 0,2 %) und 150 m (1,8 ×);
beides Geometrie- und Kartenkanten, die nur Kantenglättung (MSAA „Hoch“ 4 ×, TAA gibt es nicht) weiter dämpft.
