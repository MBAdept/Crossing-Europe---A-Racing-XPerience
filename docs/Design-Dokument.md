# Crossing Europe – A Racing Xperience

Design-Dokument · 30. Okt. 2026 · @Michi

## Überblick

„Crossing Europe – A Racing Xperience“ ist ein schneller Arcade-Racer in Pseudo-3D, in dem man Etappenrennen quer durch Europa auf Bestzeit fährt. Vorbilder sind Enduro (Atari VCS) und The Great American Cross-Country Road Race (Activision).

- Kern: Verfolgerperspektive, Verkehr nur in Fahrtrichtung, Nachtankzwang, Radar und Polizei, Tageszeit und Wetter.
- Ziel des Spielers: die beste Zeit pro Etappe und pro Rennen.
- Umsetzung: Godot 4, Grafiken aus Blender.
- Alle Zahlen in diesem Dokument sind Startwerte. Sie liegen in einer zentralen Konfigurationsdatei und werden beim Testen angepasst.

## Darstellung und Technik

Die Straße wird als klassisches Pseudo-3D aus vielen kurzen Segmenten gezeichnet, die jedes Bild neu auf den Bildschirm projiziert werden.

- Kurven entstehen durch seitlichen Versatz pro Segment, Hügel durch Höhenversatz.
- Erste Umsetzung als Node2D mit eigener `_draw()`-Funktion. Segmente werden vor dem Spieler erzeugt und hinter ihm verworfen.
- Fahrzeuge, Bäume, Schilder und Tankstellen werden in Blender modelliert und als Sprites gerendert.
- Autos werden aus mehreren Blickwinkeln gerendert (mindestens leicht links, gerade, leicht rechts), damit sie in Kurven stimmig wirken.
- Tunnel: dunkler Abschnitt mit Lichterreihen und eingeschränkter Sicht.
- Grenzübergänge: Wechsel von Schildern, Landschaft und Polizeifahrzeugen.

## Zeit und Strecke

Eine Stunde Weltzeit entspricht 5 Spielminuten, der Zeitraffer-Faktor ist also 12.

Spielminuten = Strecke in km / Tempo in km/h × 5

| Tempo | 100 km dauern | Tankabstand 60–90 km |
|---|---|---|
| 100 km/h | 5:00 min | 3:00–4:30 min |
| 160 km/h | 3:08 min | 1:53–2:49 min |
| 250 km/h | 2:00 min | 1:12–1:48 min |

- Die Straße scrollt so, dass sich das Tempo auf dem Tacho richtig anfühlt. Nur Kilometerzähler und Uhr laufen zwölfmal schneller.
- Kernlänge einer Etappe: 150–300 km, also etwa 4–10 Spielminuten. Längere Abschnitte werden in mehrere Etappen geteilt.

## Fahrzeug und Steuerung

Das Fahrmodell ist reines Arcade ohne Physik-Engine: Der Wagen folgt der Straße, gelenkt wird nur seitlich.

- Eingaben: Lenken, Gas, Bremse.
- Grundwert Höchstgeschwindigkeit 250 km/h. Wetter, Steigung und Nacht senken das Maximum.
- Kein Übersteuern, kein Dreher. Ist der Wagen in einer Kurve zu schnell, untersteuert er: Er wird proportional zur Überschreitung nach außen gedrückt, und die Lenkung greift schwächer.

### Fahrzeugtypen (Vorschlag)

Vor jedem Rennen wird eines von fünf Fahrzeugen gewählt, das für alle Etappen des Rennens gilt. Kein Fahrzeug ist in allem überlegen; Tankgröße und Verbrauch sind zusätzliche Stellschrauben für den Ausgleich.

| Typ | Höchstgeschw. (km/h) | Beschleunigung (1–5) | Agilität (1–5) | Tank (L) | Verbrauch |
|---|---|---|---|---|---|
| Kompakt | 230 | 4 | 5 | 45 | niedrig |
| Kombi | 235 | 2 | 3 | 70 | mittel |
| Limousine | 245 | 3 | 3 | 60 | mittel |
| Sportwagen | 255 | 5 | 4 | 55 | hoch |
| Gran Turismo | 270 | 4 | 2 | 60 | sehr hoch |

- Agilität bestimmt Lenkgeschwindigkeit und die Kurvengeschwindigkeit, ab der Untersteuern einsetzt.
- Untergrenze 230 km/h, damit jedes Fahrzeug die 220 km/h für die Polizeiflucht auch bei leicht verschlechterten Bedingungen erreicht.
- Bestenlisten speichern den Fahrzeugtyp mit.

## Verkehr

Alle anderen Fahrzeuge fahren in dieselbe Richtung wie der Spieler, auf festen Spuren.

| Straßentyp | Grundgeschwindigkeit |
|---|---|
| Autobahn | 110–150 km/h |
| Landstraße | 70–100 km/h |
| City Limits | 40–60 km/h |

- Die Dichte folgt einer Tageskurve: Spitzen etwa 7–9 und 16–19 Uhr, Minimum 1–5 Uhr.
- Nachts von 23 bis 4 Uhr sind weniger Fahrzeuge unterwegs, und sie fahren 15 % schneller (Spielraum 15–20 %).
- Während einer Polizeiverfolgung wird der Verkehr um 80 % reduziert.
- In den City Limits ist deutlich mehr Verkehr.
- Gelegentlich nutzt ein Verkehrsauto die Tankspur.

### Kollisionen

Berührt der Spieler einen Verkehrsteilnehmer, wird sein Wagen innerhalb von 3 Sekunden auf 10 km/h abgebremst und zur Seite geschoben. Bei 200 km/h kostet das effektiv etwa 7–10 Sekunden.

- Richtung: weg von der Seite des getroffenen Autos. Bei einem Treffer genau von hinten oder vorn auf die Seite mit mehr Platz. Im Zweifel nach links, weil rechts die Tankstellen liegen.
- Der Endpunkt wird kurz nach Erreichen der 10 km/h erreicht. Erst dann kann wieder beschleunigt werden.
- Während Abbremsen und Schieben ist der Wagen unverwundbar und blinkt. Kollisionen zählen erst nach dem Wiederanfahren.
- Von hinten überholende Fahrzeuge kollidieren erst, wenn mindestens ein Drittel von ihnen im Bild zu sehen ist.

## Tanken

Der Verbrauch steigt quadratisch mit dem Tempo, damit Vollgas spürbar mehr Tankstopps kostet. Grundwert ist ein 50-Liter-Tank; die Fahrzeugtypen weichen davon ab.

Verbrauch (L/100 km) = 14 + 0,00034 · v²

| Tempo | Verbrauch | Reichweite (50 L) |
|---|---|---|
| 100 km/h | 17,4 L | ca. 290 km |
| 130 km/h | 19,7 L | ca. 255 km |
| 180 km/h | 25,0 L | ca. 200 km |
| 250 km/h | 35,3 L | ca. 140 km |

- Tankstellen alle 60–90 km, rechts der Straße. Die letzte spätestens etwa 25 km vor dem Etappenziel, also vor den City Limits.
- Ankündigung 30 km, 15 km und 5 km vorher.
- Tankspur rechts, beginnt nach der 5-km-Ankündigung und ist 1–2 km lang. Fällt der Wagen dort unter 60 km/h, läuft der Tankvorgang automatisch ab. Wer schneller bleibt, fährt durch, und die Spur mündet wieder ein.
- Tankdauer: 2 Sekunden pro 5 Liter plus etwa 5 Sekunden fest. Ein leerer 50-Liter-Tank braucht damit rund 25 Sekunden.
- Beim Tanken erscheint „Volltanken?“ und darunter „Gas = Weiterfahren“. Gas geben bricht den Tankvorgang ab.
- Anzeige im Spiel: Tankstand, Restreichweite beim aktuellen Tempo, Entfernung zur nächsten Tankstelle.
- Leerer Tank: lange Zeitstrafe für den Abschleppdienst.

## Radar, Polizei und City Limits

Radarfallen lösen eine Polizeiverfolgung aus; wer erwischt wird, verliert effektiv 15–20 Sekunden.

### Radar

- Warnung 10 km vorher, mit Anzeige des geltenden Tempolimits.
- Auslösefeld etwa 5 km lang.
- Toleranz 15 %: Bei 120 km/h löst das Radar erst ab 138 km/h aus.
- Tempolimits je Land und Streckenabschnitt. Deutsche Autobahnabschnitte können ohne Limit sein.
- In den letzten 30 km vor den City Limits gibt es kein Radar.

### Polizei

- Flucht ist möglich ab 220 km/h, wenn man dieses Tempo 10–15 Sekunden im Durchschnitt hält.
- Während der Verfolgung wird der Verkehr um 80 % reduziert.
- Erwischt: Der Wagen bremst, steht etwa 10 Sekunden (Einblendung, z. B. „Führerschein, bitte!“) und muss dann aus dem Stand wieder beschleunigen.
- Eine Verfolgung kann in die City Limits hineinlaufen und gilt dort normal weiter.

### City Limits

- Die letzten 20 km jeder Etappe.
- Mehr Verkehr, keine Tankstellen, kein Radar.

## Tageszeit und Wetter

Bei einem Rennen legt der Spieler die Startuhrzeit fest; jede weitere Etappe beginnt 12 Stunden Weltzeit nach dem Ende der vorherigen.

- Die 12-Stunden-Pause zählt nicht zur Gesamtzeit.
- Die Uhr läuft im Zeitraffer mit: 10 Spielminuten entsprechen 2 Stunden. Dämmerung, Nacht und Sonnenaufgang sind während einer Etappe sichtbar.
- Durch die Pause verschiebt sich die Startzeit von Etappe zu Etappe um die Fahrzeit. Die gewählte Startzeit wirkt so auf das ganze Rennen.
- Einzelne Etappe außerhalb eines Rennens: Uhrzeit und Wetter frei wählbar.
- Wetter: Normal, Regen, Schnee. Es wird vor der Etappe angezeigt und senkt Höchstgeschwindigkeit und Sicht.
- Nacht: schlechtere Sicht, dafür weniger Verkehr (siehe Verkehr).

## Streckennetz, Etappen und Rennen

Die Europakarte ist ein gemeinsames Netz: Städte sind Knoten, Etappen sind Verbindungen dazwischen, und ein Rennen legt nur Start, Ziel und Pflichtstationen fest. Alles liegt in Datendateien, sodass neue Städte, Etappen und Rennen ohne Codeänderung hinzukommen.

- Jede Etappe existiert nur einmal, egal in wie vielen Rennen sie vorkommt.
- Eine Etappe besteht aus Abschnitten. Jeder Abschnitt hat Straßentyp, Länge, Kurvigkeit, Steigung, Landschaft, Land und Tempolimit.
- Tankstellen, Radarfallen, Tunnel und Grenzübergänge werden als Positionen in km auf der Etappe angegeben.
- Routen mit Wahlmöglichkeit brauchen einen Ausgleich, z. B. länger und mehr Verkehr, dafür mehr Strecke ohne Tempolimit, weniger Radar, mehr Tankstellen.

```json
{
  "cities": [
    { "id": "kiel", "name": "Kiel", "country": "DE", "map_pos": [412, 118] },
    { "id": "hamburg", "name": "Hamburg", "country": "DE", "map_pos": [405, 140] }
  ],
  "stages": [
    {
      "id": "kiel_hamburg",
      "from": "kiel",
      "to": "hamburg",
      "length_km": 95,
      "sections": [
        { "length_km": 95, "road": "autobahn", "curviness": 1, "hills": 1,
          "scenery": "north_plain", "country": "DE", "speed_limit": null }
      ],
      "fuel_stations_km": [40],
      "radars": [ { "km": 30, "limit": 120 } ],
      "tunnels": [],
      "borders": []
    }
  ],
  "races": [
    { "id": "kiel_nuernberg", "name": "Kiel – Nürnberg",
      "start": "kiel", "finish": "nuernberg", "waypoints": [] }
  ]
}
```

Die City Limits ergeben sich automatisch aus den letzten 20 km jeder Etappe und müssen nicht eingetragen werden. Die Werte im Beispiel sind Platzhalter.

### Erstes Rennen: Kiel – Nürnberg

- Kiel – Hamburg: alternativlose Startetappe, gleichzeitig Tutorial.
- Ab Hamburg Wahl zwischen der Route über Kassel und der Route über Frankfurt (mehr Verkehr). Etappen über ca. 300 km bekommen eine Zwischenstation, etwa Hannover.

### Weitere Rennen

- Zum Beispiel Dresden – Dortmund, München – Bremen.
- Königsrennen als Tour: Kiel – Hamburg – Bremen – Amsterdam – Lüttich – Paris – Madrid – Bern – Mailand – Sofia – Budapest – Wien – Prag – Leipzig – Berlin – Warschau – Riga – Fähre – Rostock – Kiel.
- Die Tour umfasst grob 11.000–12.000 km. Lange Abschnitte werden in Etappen von 200–400 km geteilt; nach jeder Etappe wird gespeichert.
- Die Fähre Riga – Rostock ist eine feste Zwischenzeit mit kurzer Szene.

## Etappenbildschirm und Bestenlisten

Vor jeder Etappe zeigt ein Bildschirm die Strecke auf der Karte, das Wetter, den Rekord als Laufschrift und rechts daneben die Top 10.

- Laufschrift: Name des Rekordhalters, Zeit, Durchschnittsgeschwindigkeit.
- Bestenlisten pro Etappe und pro Rennen. Die Rennzeit ist die Summe der Etappenzeiten ohne Pausen.
- Jeder Eintrag speichert Name, Zeit, Durchschnittstempo, Fahrzeugtyp, Wetter und Tageszeit. Wetter und Tageszeit erscheinen als kleines Symbol neben der Zeit.
- Wer einen Platz in den Top 10 erreicht, gibt am Etappenende seinen Namen ein.
- Speicherung lokal als JSON.

## Zentrale Konfiguration und Prototyp-Plan

Alle Zahlenwerte stehen in einer zentralen Konfigurationsdatei: Zeitraffer, Verbrauch, Tankgrößen, Abstände, Toleranzen, Strafen, Verkehrsdichte und -tempo, Fahrzeugwerte.

Der Prototyp entsteht in dieser Reihenfolge, das Fahrgefühl zuerst:

1. Gerade Straße mit Pseudo-3D-Projektion, Lenken, Gas, Bremse, Tacho.
2. Kurven, Hügel und Untersteuern.
3. Verkehr und Kollisionen.
4. Tank, Tankspur, Timer und Bestzeit.
5. Radar, Polizei und City Limits.
6. Streckennetz aus Datendateien und das Rennen Kiel – Nürnberg mit beiden Routen.
7. Tageszeit, Wetter und Fahrzeugtypen.
8. Weitere Rennen und das Königsrennen.

## Offene Punkte

- [ ] Fahrzeugtypen und ihre Werte bestätigen.
- [ ] Bestenlisten gemeinsam für alle Fahrzeuge oder getrennt nach Fahrzeugtyp?
- [ ] Wetter im Rennen: zufällig, fest pro Etappe oder nach Region und Jahreszeit?
- [ ] Wie stark senken Regen, Schnee und Nacht die Höchstgeschwindigkeit?
- [ ] Länge der Zeitstrafe bei leerem Tank.
- [ ] Verhalten am Straßenrand: Bankett, Leitplanke, Abbremsen?
- [ ] Zielplattformen und Eingabegeräte.
- [ ] Sound, Musik und Sprachen der Einblendungen.
