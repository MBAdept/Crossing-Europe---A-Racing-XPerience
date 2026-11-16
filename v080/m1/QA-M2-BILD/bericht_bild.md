## Bild – A/B gegen Arcade und gegen ZS1

Gleicher Simulationszustand (Argumente wie `tools/ab_sheet.sh`, Aufnahme bei 3 s; Start bei 1 s im Countdown und 1,5 s
nach „LOS!“). Arcade läuft mit `--shot-fast` (bitgleich), Modern rendert jedes Bild. ZS1 ist am Start und an S4 im
eigenen ZS1-Baum gerendert; an den übrigen Stellen ist das ZS1-Bild der „Hoch“-Bogen von gate1 (gleicher Code dort).
Prüfung der Wiederverwendung: mein S1 „Hoch“ (`6e48405`) gegen M2INTs S1 „Hoch“ (`c317625`): mittlere Abweichung
1,4/255 (JPEG), 0,05 % der Pixel > 24/255 – dasselbe Bild; M2INTs Bögen für S2, S3, S5, T4, N2 gelten damit für den
Prüfstand. Jedes Bild angesehen, Ausschnitte vergrößert. Dreierbögen in `deliver/QA-M2-BILD/bilder/`.

| Stelle | M2 gegen ZS1 | M2 gegen Arcade (ehrlich) |
|---|---|---|
| **S0 Start km 0**, Mittel, Countdown 1 s und 1,5 s nach LOS | **gleich** – Auto an Arcades Stelle in beiden Bildern, Starttor mit Lampen, Schild „Tankstelle 15 km“; Bäume von AS3R | gleichwertig, nicht besser: **die große Eiche links fehlt** (Korridorregel, Segment 9, x −17 m – schon ZS1) |
| S1 km 3, Hoch | Bäume AS3R, Verkehr als Modelle | gleichwertig bis leicht besser (Leitplanken mit Pfosten, Schatten, Asphalt, Rückfenster mit Innenraum); keine Sonnenscheibe (gewollt: Mittagssonne hinter der linken Schulter, `environment_rig.gd`) |
| S4 km 80,6 Hamburg, Hoch | 0,46 % der Pixel anders (Verkehr, Bäume) – gleich | gleichwertig: Gehweg mit Pflaster, Laternen; links fehlt die Birke vor dem Backsteinhaus (Korridor); in der Ferne über den Häusern **ein dunkler, punktierter Fleck und ein türkis gepunkteter** – die ferne Wahrzeichen-Vertretung, mit Ordered Dither ausgeblendet (`billboard.gdshader`, Zeilen 121–127); in Arcade glatt verblassend. Schon in gate1/ZS1 |
| N1 Hamburg–Hannover km 71, 22 Uhr, Schnee, Hoch | gleich (Kiefer rechts neu) | **schlechter**: kein Schneefall in der Luft (R4); Kompakt deutlich heller und gelber als Arcades Sprite (Messung Abschnitt Fahrzeuge); Rest gleichwertig |
| C1 Frankfurt km 221, 19:30, Hoch | Sportwagen jetzt Modell (ZS1: Sprite) | **schlechter**: der große Straßenbaum rechts fehlt (Korridor, Ereignis-Eintrag); Sportwagen satter und orangeroter als das Sprite, flacher Lack; Gebäude (noch Stadt-Sprites) gleich |
| T1 Kassel–Würzburg km 46,5, Hoch | Kombi jetzt Modell (ZS1: Sprite) | gleichwertig bis schlechter: Fichten links (Innenseite) fehlen, die große Kurventafel am rechten Rand ist aus dem Bild (Kurvenkamera, nah – nach A-15 erlaubt); Gelände mit Tiefe besser; Kombi heller/türkiser als das dunkelgrüne Sprite |
| T4 Saragossa–Pau km 198,8 (M2INT-Bogen) | Fichten von AS3R | **schlechter**: Innenseite kahl (Fels und 9 von 12 Requisiten fehlen), nahe Fichte am rechten Rand fehlt |
| T3 Saragossa–Pau km 172,8, 11 Uhr, Hoch | gleich | gleichwertig bis schlechter: Felsen und Kiefern der Innenseite (links) fehlen (Korridor, 4 von 8), keine Sonnenscheibe; Kurventafeln, Gelände, Hang besser |
| T2 Kassel–Würzburg km 61,9 Kuppe, 15 Uhr, Hoch | gleich | **schlechter**: die ganze linke Seite kahl (Laubbäume und Fichten von Arcade fehlen, 8 von 18 Requisiten, Korridor); rechte Seite gleichwertig |
| U1 Gotthard km 187, Hoch | gleich, Sportwagen jetzt Modell | gleichwertig: Tunnelröhre, Lampen; das rote Verkehrsauto als Modell besser, aber ohne Rücklicht-Schein (Arcade glüht) |
| DEV km 48, 21 Uhr, Hoch | gleich | gleichwertig: Tunnelportal, Laubbaum; Fichte links fehlt (schon ZS1), Rücklichter des Spielerautos schwächer als Arcades Schein |
| N2 Dortmund–Frankfurt km 121, Regen (M2INT-Bogen) | GT jetzt Modell | **schlechter**: kein Regen in der Luft (R4); GT weiß und flach |
| S2, S3, S5 (M2INT-Bögen) | Bäume, Verkehr | gleichwertig |
