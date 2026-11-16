## 4. Nähte und Artefakte im Spiel

### 4.1 Nähte: jede Schleife abtastgenau

Jede Datei für sich auf einem eigenen Bus, Tonhöhe 1, 17 s, Aufnahme am Busende gegen die mit ffmpeg dekodierte Datei,
gekachelt mit ihrer Schleifenlänge (WAV: Schleifenende aus den Importeinstellungen; die Plattendateien tragen 16 Frames
nach dem Schleifenende).

| Schleifen | Anzahl | Start-Korrelation | gespielte Periode = Schleifenlänge | Rest an den Nähten (±20 ms) / sonst | Sprung an der Naht der Datei (× größter Sprung in ±100 ms) |
|---|---|---|---|---|---|
| Reifen, Nässe, Schnee, Wind (Ogg, je Seite eine eigene) | 26 | 1,000000 | 26 von 26, auf das Sample | 3·10⁻⁸ … 1,8·10⁻⁷ / 1,2·10⁻⁷ … 2,4·10⁻⁷ | 0,00 … 0,54 |
| Platten langsam / schnell (WAV, 282 240 / 141 120 Frames) | 2 | 1,000000 | 2 von 2 | 1,7·10⁻⁵ / 2,1·10⁻⁵ und 2,1·10⁻⁵ / 2,2·10⁻⁵ (< 1 LSB, überall gleich) | 0,00 / 0,00 (Schleife beginnt und endet zwischen zwei Schlägen) |

Kein Rest an einer Naht über dem Rest anderswo – keine Naht ist hörbar (gemessen: kein Sprung; „hörbar“ abgeleitet).

### 4.2 Wenn ein Plattenmuster startet oder nachgestellt wird

Was Godot 4.7.2 an diesen Stellen tut, mit einem Sinus (441 Hz, eigener Bus, `kr_restart.gd`) gemessen:

| Vorgang | gemessen (einfacher und 2D-Spieler gleich) |
|---|---|
| `play(pos)` auf einem stehenden Spieler | **harter Einsatz**: erstes Sample springt auf den Wert der Datei an `pos` (0 → 0,43 bei Amplitude 0,49), keine Einblendung |
| `play(pos)` auf einem laufenden Spieler (= Nachstellen, `restart`) | neuer Abspielvorgang setzt **hart** ein, der alte blendet in ~470 Samples (eine Mischblocklänge, 10,7 ms) aus; Sprung 0,48 bei Amplitude 0,49 |
| `volume_db` ändern (jedes Bild, 0 / −3 dB im Wechsel) | linear über einen Mischblock geführt: 10–90 % in 405 Samples – **kein** Treppensprung |
| `stop()` | Ausblendung, 10–90 % in 408 Samples |

Im Spiel startet eine Plattenschleife mit dem ersten Schritt der Pegelglättung (24 % des Ziels bei 60 Bildern/s) und
einer Stelle zwischen zwei Schlägen oder an der Stelle der laufenden Schleife; der Einsatzsprung ist daher klein
(Datei-Ebene: Betrag an einer zufälligen Stelle im Median −25 / −20 dB unter der Schlagspitze, in 10 % der Fälle über
−13 / −11 dB). Gemessen im Spiel (`km_slab.gd`, Tempoprofil 90–160 km/h mit Rampen und Sprüngen durch die Überblendung,
beide Entwürfe getrennt aufgenommen; Maß = größter Samplesprung und größte 8-kHz-Spitze im 93-ms-Fenster um das
Ereignis, gegen alle Fenster derselben Aufnahme):

| Lauf | Starts | Nachstellungen | größter Sprung im Ereignisfenster (× 99-%-Wert gewöhnlicher Fenster) | Rang unter allen Fenstern |
|---|---|---|---|---|
| normal (`align_ms` 6), 90 s | 6 | **0** | 0,28 | ≤ 31 % |
| erzwungen (`align_ms` 0,1), 90 s | 6 | 94 | Starts 0,30, Nachstellungen 0,44 (8 kHz: 0,56) | ≤ 67 % |

Kein Ereignisfenster ragt aus den gewöhnlichen heraus; die Schläge des Musters selbst sind größer als jeder Einsatz.
Abstand der beiden Entwürfe (Abspielpositionen, 3 906 Bilder mit beiden): Median 1,9 ms, 95 % 4,0 ms; in keinem
normalen Lauf (rund 220 s mit beiden Entwürfen, Pläne A, B, S, S2 und das Fahrprofil) wurde nachgestellt.

### 4.3 Neue Töne, Reißverschluss durch die Drift, Pumpen

| Prüfung | AU-C1 | Endstand | Ergebnis |
|---|---|---|---|
| tonale Spitzen ≥ 12 dB über der Terzumgebung (Plan B, nur Fahrbahn) | Asphalt –, Pflaster 121 Hz, Beton 51/65/94/108/122/217/231 Hz | Asphalt –, Pflaster –, Beton 65/94/109/122/217/231 Hz (dieselben, je ≤ 0,9 dB anders); nur Platten zusätzlich 137 Hz mit 12,6 dB (Teilton der Fugen, im Beton-Fahrbahnklang nicht über der Schwelle) | kein neuer Ton |
| Linie der Bildrate (55–65 Hz) im Hüllkurvenspektrum, nur Fahrbahn, mit Drift (Plan A) / ohne (Plan B) | 32–37 dB (exakte Schleifen) | 11,0 / 11,6 / 10,7 dB mit Drift gegen 9,2 / 10,3 / 10,6 dB ohne (Asphalt / Pflaster / Beton) | kein Reißverschluss |
| Linie der Mischblockrate (83–90 Hz) | 23–33 dB | 7,9–11,0 dB mit, 8,5–11,0 dB ohne Drift | dito |
| Sinus mit der Drift der Fahrbahn (1,5 dB, 0,8 s, jedes Bild) | – | Linien 8,2 / 10,1 dB (55–65 Hz), keine bei 83–90 Hz | dito |
| Klick-Detektor (4-kHz-Hochpass, 30 dB über dem laufenden Pegel), Plan A/B | 0 | 0 (nur die Plattenschläge selbst lösen ihn in der Aufnahme „nur Platten“ aus, bei AU-C1 genauso) | keine Klicks |
| Begrenzer beim Reisen 130–245 km/h | – | 1 Eingriff von 0,22 dB in 7 Läufen (≈ 6 min) | kein Pumpen |
