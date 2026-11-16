Fünf Läufe auf dem Endstand: `GFX_ARGS="--gfx-preset=<p>" SCREEN=<b×h> tools/ab_shot.sh <out> <Etappe> --weather=normal
--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --hour=12
--start-speed=120` (ab_shot.sh ruft Arcade und Modern selbst mit `--graphics=arcade|modern`, eigenem absolutem
`XDG_DATA_HOME` und gleichem Simulationszustand auf). Jeder Lauf: exit 0, 0 Zeilen `SCRIPT ERROR`/`ERROR` in beiden
Logs (gemessen):

| Bild | Stelle | Voreinstellung | Laufzeit | Was im Bild steht – angesehen |
|---|---|---|---|---|
| `ab_kh54_hoch_00/01.jpg` | Kiel–Hamburg km 54,6 / 54,8 | Hoch, 1280×720 | 243 s | Eiche nah mit hellerem Kronendach wie das Sprite, Busch als laubiger Ballen, Birken mit weißem Stamm, Fernbilder ohne graue Flecken |
| `ab_kh54_deck_00/01.jpg` | Kiel–Hamburg km 54,6 / 54,9 (Stelle der Kritik) | Deck, 1280×800 | 156 s | wie Hoch. Die nahe Eiche bleibt ein Haufen Kuppeln wie beim Sprite; die Ränder sind etwas weicher als vorher, einzelne gerade Kanten bleiben (Bild 08) |
| `ab_bm42_hoch_00/01.jpg` | Barcelona–Montpellier km 42,7 | Hoch | 221 s | Palmen mit breiter, hängender Krone und dunklem Stamm; Olive silbergrau ohne Tarnmuster; Zypressen wie das Sprite |
| `ab_lb148_hoch_00/01.jpg` | Lyon–Bern km 149 | Hoch | 222 s | Fichten wie das Sprite. Die Klippe steht hier quer zur Straße (der Props-Bauer würfelt die Drehung) und zeigt von der Schmalseite einen geschlossenen Fels mit Sträuchern auf dem Grat – kein Horn, keine Fetzen; schmaler als das Sprite, bis R2/R7 `face_road` auswerten |
| `ab_hh47_mittel_00.jpg` | Hamburg–Hannover km 47,7 (Heide) | Mittel | 138 s | Heidepolster lila mit Grün wie im Sprite, Birken und Kiefern |

Vorher / nachher im Rennen (Bild 08, gleiche Argumente wie die Kritik): Die Palme ist deutlich näher am Sprite, die
Olive ruhiger. Bei der nahen Eiche auf dem Deck ist der Unterschied klein.
