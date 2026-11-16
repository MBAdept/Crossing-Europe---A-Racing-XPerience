## 3. Bild: Modern gegen Arcade im selben Simulationszustand

Methode: `tools/ab_sheet.sh` (neu) über `tools/ab_shot.sh` an allen 14 Referenzpositionen von §4.9.2, fliegender Start
mit Autopilot, Bild 3 s nach dem Start (S5: 1,5 s, sonst ist das Ziel schon durchfahren), Arcade mit `--shot-fast`,
Modern ohne. Je Position zwei Voreinstellungen: **Hoch** und die, die dieser Rechner selbst wählt (**Niedrig**:
Grafikkarte llvmpipe = Stufe „software“). Jedes der 30 Bilder angesehen. Helligkeit gemessen über die PNGs (mit HUD):
Modern liegt überall bei 0,95–1,05 × Arcade (Boden 0,89–1,05 ×), keine schwarzen Flecken (≤ 0,5 % reinschwarze Pixel).

| Pos. | Hoch | Niedrig (dieser Rechner) |
|---|---|---|
| S1 km 2, 12 Uhr | gleichwertig bis leicht besser: Felder mit Struktur, echte Schatten (Bäume, Leitplanke, Auto), Kartenbäume, Windräder, Dunst am Horizont. Die Spieler-Limousine ist ein anderes Auto als ihr Sprite (steile Heckscheibe, sichtbare Sitze statt Fließheck) | flacher: keine Schattenwerfer, 75 % Auflösung (Treppen an Kanten), weniger Requisiten (die große Eiche rechts fehlt) |
| S2 Tankspur | gleichwertig: Dach, Insel, gelber Bordstein, Säulen, „TANKSTELLE“ wie Arcade; der Busch links vorn ist ein dunkler Klumpen (Arcades Busch ist schöner) | gleichwertig, ohne Schatten unter dem Dach |
| S3 km 60 | leicht besser: Felder in mehreren Farben, Tiefe, Schatten der Eichen | flacher, die große Eiche fehlt |
| S4 km 80 City Limits | gleichwertig: Häuser, Kran und Backsteinblöcke sind in beiden Modi Arcades Bilder; Modern hat gepflasterte Gehwege und Laternen als Modelle | wie Hoch |
| S5 Ziel | AUSSTEHEND (Bild bei 1,5 s) | AUSSTEHEND |
| T1 km 47,6 | gleichwertig: Gelände deutlich besser (Hügel mit Schattierung statt flachem Grün), aber links vorn fehlt die große Fichte (Innenseite der Kurve, F7); das Kurvenschild rot-weiß am rechten Rand (≈ 25 m) ist in Arcade zu sehen, in Modern nur als 2-px-Streifen – die Kurvenkamera schaut in die Kurve und schiebt nahe Dinge am Außenrand aus dem Bild | weniger Fichten links |
| T2 Kuppe km 63 | **schlechter**: Arcade zeigt die **Sonnenscheibe** und links große Eichen und Fichten an der Straße, Modern links fast leeres Gras mit ein paar Büscheln (Sichtkorridor, Bodendecker) | **schlechter**, links ganz leer |
| T3 km 173,7 | gleichwertig: echter Hügel links, natürlicher Rand; aber keine Sonnenscheibe und der nahe Findling links fehlt | wie Hoch |
| T4 km 199,7 (R ≈ 136 m) | gleichwertig: die Kurvenkamera zeigt die Kurve besser; die große Fichte an Arcades rechtem Rand (Innenseite) fehlt | der Kompakt bei 75 % sichtbar treppig und unruhig |
| N1 22 Uhr Schnee | **schlechter**: **kein Schneefall**; Kegel und Schneeboden ähnlich; der Kompakt heller und gelber als Arcades Nachtbild | wie Hoch |
| N2 Regen | **schlechter**: **kein Regen** in der Luft; nasse Fahrbahn dunkler und etwas glänzend | wie Hoch |
| C1 Frankfurt 19:30 | leicht schlechter: Arcades großer Straßenbaum rechts (Innenseite) fehlt; Häuser in beiden Modi Arcade-Bilder, Gehweg in Modern schöner | wie Hoch |
| U1 Gotthard | gleichwertig: Röhre mit Fliesenband, Lampen mit Lichthof und dunkler Tiefe (FIX1); Limousine warm beleuchtet | gleichwertig |
| DEV 21 Uhr | gleichwertig: Portal, Hügel, Schild wie Arcade; Hügel heller und glatter, die Eiche rechts nachts recht hell, die Fichte links fehlt; Limousine heller als Arcades (keine Mondflecken mehr) | wie Hoch |
| Start km 0 (Diagnose) | **Fehler** QA1-B1: Spielerauto im Countdown unsichtbar, Kamera 9 m zu weit vorn | – |

**Urteil Bild**: Auf freier Strecke bei Tag ist Modern mit „Hoch“ gleichwertig bis leicht besser als Arcade (Gelände mit
Tiefe, Schatten, Felder, Tunnel, Tankstelle). **Deutlich besser ist es noch nirgends.** Schlechter ist es bei Regen und
Schnee (kein Wetter in der Luft), an Kuppen und Kurveninnenseiten (fehlende Bäume, keine Sonnenscheibe), am Start jeder
Etappe (QA1-B1) und mit „Niedrig“ (flacher als Arcade). Städte sehen in beiden Modi gleich aus, weil die Gebäude noch
Arcade-Bilder sind; Spielerautos ohne Modell (Kombi, Sportwagen, Gran Turismo) ebenso.
