## 5. LOOK PASS

A/B-Bögen (`tools/ab_shot.sh` über `m1/RINT-B/tools/ab.sh`, gleiche Simulation, links Arcade, rechts Modern) am letzten
Stand des Renderers: `look/hoch/` mit `--gfx-preset=high` an S1–S5, T1, T4, C1 (19:30), N1, N2 und die Fahrzeuge an S1
(`S1K` Kombi, `S1S` Sportwagen, `S1G` Gran Turismo); `look/maschine/` mit dem Preset der Maschine (llvmpipe →
„software“ → „Niedrig“) an denselben zehn Stellen. Clip `kiel_hamburg_start_ab.mp4`: die ersten 20 s von Kiel–Hamburg ab
dem Einzählen, beide Modi aus derselben Simulation (Movie Maker, 30 Bilder/s), Ton von Modern.

**Besser als vorher / gleichauf mit Arcade** (an den Bildern): Horizont an S1, T1, T4 (Land bis an die Silhouetten,
Silhouetten auf Arcades Zeile, kein See an T4), Boden mittags und nachts in Arcades Helligkeit (Gras, Asphalt, Schnee),
Laternen mit warmem Schein (C1), Lack der Spielerautos mittags innerhalb 10 %, Ersatzbilder ohne zweiten Schatten,
Tiefe und Felder des Geländes (S3, T1), Lampen bei Tag nicht mehr „an“.

**Ehrlich: was schlechter ist als Arcade** (gesehen bzw. gemessen):
1. **Start- und Zieltor** fehlen in Modern (Clip: Arcades Brücke „START“ in Kiel; S5: „ZIEL“ in Hamburg) – nur die
   Linie auf der Fahrbahn ist da.
2. S2 – die **Tankstelle** wirkt kleiner: das große rot-weiße Dach über der Fahrspur und die gelbe Kante der Tankspur
   fehlen; Arcades Station liest sich viel stärker.
3. S4 (Hamburg, Brücke) – **keine Brückengeländer**, das Wasser dunkel blaugrün statt Arcades hellgrau, eine grüne
   Böschung zum Wasser.
4. N2 / N1 – **kein Regen und kein Schnee in der Luft** (Modern hat keine Wetter-Ebene, M2), die nasse Fahrbahn spiegelt
   nichts.
5. T4 – Arcades **Felsbrocken** am Straßenrand fehlt (keine Requisite in Modern).
6. Nacht – das **Spielerauto ist heller** als sein Sprite (Limousine +32 %, Mondglanz auf dem Kofferraum), Arcades großer
   roter Schein der Rückleuchten über dem Stoßfänger ist in Modern kleiner; das **Abblendlicht auf der Fahrbahn**
   ist 9–38 % heller als in Arcade (S1 22 Uhr, gemessen).
7. Dämmerung mit der Sonne voraus – der **Kompakt 16 % dunkler** als sein Sprite (Heck im eigenen Schatten).
8. Showroom – das Echtzeitbild ist **flacher als die Cycles-Sprites** (deshalb bleibt `showroom` aus).
9. Laden – Modern braucht **5,2–5,6 s** statt 0,85 s, davon ein Bild von 1,6–1,9 s, in dem der Balken steht.
10. Preset „Niedrig“ (Maschine) – weniger Bäume und Büsche als Arcade (N1), die 3D-Auflösung ist sichtbar gröber am
    Spielerauto.
11. Himmel – Modern zeichnet **keine Sonnenscheibe** (Vorschaubild der Optionen: Arcade hat sie); am Start fehlt im
    Clip außerdem Arcades blaues Schild „Tankstelle 15 km“ rechts.
Kombi, Sportwagen und Gran Turismo sind in Modern noch Arcades Bilder (kein Modell, M2) – an S1 von Arcade nicht zu
unterscheiden.
