## Fahrzeuge (gemessen, `probe/qa_vehicles.gd`)

Eingefrorene Etappe Kiel–Hamburg km 2, Mittel, ohne Verkehr; die Sonde schaltet die Render-Aufrufe der Sitzung ab und
gibt dem Renderer dieselbe Ansicht mit eingesetzten Testautos – dasselbe Skript, dieselbe Ansicht, dieselben Autos in
Arcade, im ZS1-Baum und in M2. Je Reihe drei Autos nebeneinander in 20, 60 und 150 m: linke Spur blinkt links, eigene
Spur bremst, rechte Spur nur Rücklicht (Reihen: Kleinwagen rot / Limousine silber / SUV weiß; Transporter weiß / Lkw
rot / Bus blau; Polizei DE / Sportwagen gelb / Kombi dunkelblau), 12 Uhr und 22 Uhr. Zählung `sh/lightcount.py`
(rot r>170, g<110, b<110; blau b>160, b−r>50, b−g>20) in einem engen Fenster um das Auto, Ausschnitte `sh/zoom.py`.

| | Arcade | ZS1 | M2 | Urteil |
|---|---|---|---|---|
| Sitz auf der Fahrbahn, Räder, Schatten (20/60/150 m, Tag) | – | gut | gut | in Ordnung, Transporter/SUV/Bus neue Modelle sauber |
| Reihen Kleinwagen…Bus: Lichtzählung Tag/Nacht | – | = | = | M2 gleich ZS1 |
| **Sportwagen (neues Modell) bremst, rote Pixel Tag 20 / 60 m** | 216 / 32 | 245 / 31 | **119 / 9** | Bremslicht ist ein dünner Streifen – bei 60 m 30 % des ZS1-Signals (`fahrzeuge_sportwagen_bremse_60m.jpg`) |
| Sportwagen bremst, Nacht 20 m | 375 | 449 | 180 | ebenso |
| **Polizei DE (neues Modell), Blaulicht Tag 20 / 60 / 150 m (blaue Pixel)** | 1601 / 182 / 17 | 1004 / 114 / 11 | **411 / 28 / 7** | schmaler blauer Balken ohne Schein (`fahrzeuge_polizei_60m_tag.jpg`) |
| Blaulicht Nacht 20 / 60 / 150 m | 5883 / 690 / 110 | 2903 / 371 / 47 | **1958 / 208 / 28** | ⅓ von Arcade, 60 % von ZS1 |
| Lkw rot, eigene Spur, Abblendlicht 22 Uhr, Hecktüren mittlere Leuchtdichte 20 / 60 m | 50 / 42 | 119 / 199 | 119 / 199 | M2 = ZS1: die rote Plane leuchtet im Abblendlicht als **weißer Kasten** (223 Pixel > 200 bei 20 m) – keine Verschlechterung, aber schlechter als Arcade |
| Limousine silber 60 m nachts, Pixel > 200 | 29 | 150 | 150 | Kennzeichen und Stoßfänger als weißer Block, = ZS1 |
| Bremslicht allgemein, Tag 20 m (Kleinwagen / Limousine) | 319 / 209 | 123 / 95 | 123 / 95 | Modern ≈ 45 % von Arcade, schon ZS1 |
| Blinker | glüht | glüht | glüht (Polizei jetzt auch) | in Ordnung |

Bei 150 m sind Rück-, Brems- und Blinklichter in allen drei Bildern ähnlich klein. Gegen ZS1 schlechter sind nur die
zwei Fahrzeuge, die in ZS1 noch Sprite-Vertretungen waren und jetzt Modelle sind (Sportwagen, Polizei).
