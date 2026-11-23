### 5.2 Fernlicht unabhängig nachgemessen (Leitentscheid 2; gemessen)

Mit R7cs/KRITIKs Prüfszene (`k6_scene --mode=lodcol`, ungetrackt in der Kopie `m1/QA-R7c/mut/tools/kritik/`, `sh/k6.sh`),
lod1 (die Stufe, die das Spiel jenseits von 35/70 m zeigt), 12 Uhr, Modell 20 m neben der Straße, mittlere Luma des
Modells; „aus“ = ohne `far_sun` (Stand vor R7c), „an“ = ausgelieferter Wert. Abweichung gegen 60 m:

| Modell (far_sun) | Stufe | an: 100 / 140 / 200 / 250 m | aus: 200 / 250 m |
|---|---|---|---|
| Haussmann (0,72) | Hoch | +2,2 / +2,4 / +2,8 / +3,3 % | +9,8 / +10,3 % |
| Haussmann (0,72) | Mittel | +0,5 / +3,1 / +3,5 / +3,5 % | +10,6 / +10,6 % |
| Gründerzeit (0,78) | Hoch | −0,5 / −0,9 / −3,0 / −3,0 % | +2,1 / +2,1 % |
| Gründerzeit (0,78) | Mittel | −1,3 / −2,1 / −2,5 / −2,6 % | +2,6 / +2,5 % |
| Kontor (0,78) | Hoch | +3,4 / +4,2 / +1,7 / +1,9 % | +8,8 / +9,0 % |
| Kontor (0,78) | Mittel | +1,1 / +2,1 / +2,5 / +2,3 % | +9,2 / +9,4 % |

Alle in ±5 % (Leitentscheid erfüllt, R7cs Tabelle bestätigt). Die Gründerzeit wird mit dem Klassenwert 0,78 fern etwas
dunkler (−3 %) als nah, ohne Fernlicht wäre sie nur +2 % heller – kein Fehler, aber der Klassenwert passt nicht jedem
Haus. Hinweis: die Szene setzt `far_sun` selbst auf das Material; dass das Spiel den Wert aus der Konfiguration
setzt, ist nur gelesen (`_ensure_bands`), kein Test prüft es (QR7c-02, U7). Im Spielbild: Paris Hoch 12 Uhr, Fassade
des Haussmann-Hauses (innerhalb der Schattenreichweite) Luma 130,0 (R7c) gegen 130,1 (43a1fcc) – in der Nähe unverändert.
