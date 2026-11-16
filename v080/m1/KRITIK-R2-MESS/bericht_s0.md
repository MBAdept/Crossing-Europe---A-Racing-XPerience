
---------------------------------------------------------------------------------------------------------------------

## 0. Kurzfassung

**Ergebnis: Der Endstand besteht die Abnahmemessung.** Kein Blocker, kein hoher Befund; ein mittlerer (knappe Marge
von V3 beim Lkw) und drei niedrige. Alle Zahlen gemessen auf dieser VM (Godot 4.7.2, Dummy-Treiber, Last 5–9); wie es
klingt, ist abgeleitet – gehört hat hier niemand.

| Prüfung (Rang nach dem, was der Spieler am meisten hört) | AU-C1 → Endstand (gemessen) | Ziel | erfüllt |
|---|---|---|---|
| 1 Charakter, Plan B: Fahrbahnschichten und Spielmixe bei 130 km/h Asphalt/Beton, 50 km/h Pflaster | größte Terz-Abweichung 0,89 dB (Spielmix Pflaster, 32 Hz, Motorstreuung), Schichten allein ≤ 0,53 dB; Lautheit ≤ 0,29 LU | ±1 dB, ±0,5 LU | ja |
| 1 Plattenschicht im Spiel 110–200 km/h | gegen AU-R 110/130/150: −0,08 / +0,12 / +0,08 dB (stetig), 170: −0,82, 200: −1,96 dB (Gesetz −0,87 / −2,00); Klangfarbe gegen AU-C1 bei jedem Tempo ≤ 0,57 dB | wie dokumentiert | ja |
| 1 rechte Pflasterschleife | lautester Stein rechts +0,28 … +0,43 dB über AU-C1 (AU-R: +3,0 laut KRITIK-R), Scheitel 13,99–14,21 dB (AU-C1 13,58), True Peak −8,2 … −8,9 dBTP (AU-C1 −9,0) | wie AU-C1 | ja |
| 2 V1, Spielmix, zwei neue Folgen | Asphalt 0,637 → 0,137 / 0,230; Pflaster 0,985 → 0,098 / 0,179; Beton ohne Platten 0,815 → 0,151 / 0,239; Beton mit Platten 0,714 / 0,710 (Takt, zur Kenntnis) | < 0,40 bei 0,3–3 s | ja |
| 3 V3 schwerer Aufprall, je 60 (Folgen 9311 / 9312) | 95 %: Pkw **2,05 dB**, Lkw **2,66 dB**; True Peak höchstens −1,38 / −1,21 dBTP (AU-C1: −0,31 / −0,29, 71 von 120 über −1,0) | ≤ 3 dB; ≤ −1,0 dBTP | ja (Lkw knapp, M1) |
| 3 V3 Reisen | Beton 200 km/h, vier Läufe à 57,5–57,9 s: 0,00 / 0,00 / 0,00 / **0,22 dB**; Beton 170, Asphalt 200, Höchsttempo: 0,04 dB (Rest) | ≤ 0,5 dB je Lauf | ja |
| 3 True Peak: Höchsttempo / schlimmster Fall von AU-C1 | −2,39 → −2,01 dBTP / −0,31 → **−1,54 dBTP** | ≤ −1,0 dBTP | ja |
| 4 Nähte, Starts, Nachstellen, Töne, Drift, Pumpen | 26 Ogg + 2 WAV abtastgenau; kein Ereignisfenster über dem Gewöhnlichen (6 Starts, 94 erzwungene Nachstellungen); kein neuer Ton; Bildraten-Linie mit Drift 11 dB wie ohne (AU-C1: 32 dB); 1 Begrenzer-Eingriff in ~6 min Reisen | keine | ja |
| 5 Rechenzeit `road` je Bild (Median / 95 %) | Beton 0,13 / 0,18–0,22 → 0,20 / 0,28–0,29 ms; Asphalt 0,12 / 0,18 → 0,17 / 0,25–0,26 ms; Sperren 2 je s nur bei 110–150 km/h auf Beton | (AU-R: 0,37–0,40 / 0,59–0,62 ms) | ja |
| 6 Hörproben | Marken ±0,15 s (Brücke, Fugen, Hamburg); „Bankett“/„Leitplanke“ 0,6–1,5 s früher als hörbar (N1); nachher-Hälfte und Spielmix = Dateien und Klang des Endstands | stimmig | ja (N1 niedrig) |

Was ein Ohr noch prüfen sollte (abgeleitet, hier nicht hörbar): ob bei 130 km/h auf Beton die Platten präsent genug sind
(sie liegen dort seit AU-C1 3 dB unter ihrem Gesetz, N3) und ob der neue Schnee (+0,9–1,05 LU, −5 … −6 dB unter 160 Hz,
bewusst neu seit AU-R) gefällt.
