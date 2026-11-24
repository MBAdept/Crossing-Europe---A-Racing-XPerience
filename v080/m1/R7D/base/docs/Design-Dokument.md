# Crossing Europe – A Racing Xperience

Design-Dokument · 30. Okt. 2026 · @Michi

Überarbeitet am 2. Nov. 2026 nach dem Spieltest von v0.4.0 („zu leicht“): Verkehr, Wetter und Fahrverhalten, City Limits, Tutorial. Geänderte und neue Regeln sind mit *(seit v0.5.0)* markiert.

Überarbeitet am 9. Nov. 2026 nach dem Spieltest von v0.6.0 („Die Etappen sind ein wenig kurz“): Zeitraffer und Pause zwischen den Etappen eines Rennens, der Tank geht im Rennen in die nächste Etappe mit (erste Tankstelle spätestens 20 km nach dem Start), zwei neue Rennen Wien – Hamburg und Bukarest – Calais. Geänderte und neue Regeln sind mit *(seit v0.7.0)* markiert.

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

*(seit v0.7.0)* Eine Stunde Weltzeit entspricht 6 Spielminuten, der Zeitraffer-Faktor ist also 10. Vorher waren es 5 Spielminuten (Faktor 12) – im Spieltest von v0.6.0 waren die Etappen etwas kurz; jetzt dauert jede ein Fünftel länger.

Spielminuten = Strecke in km / Tempo in km/h × 6

| Tempo | 100 km dauern | Tankabstand 60–90 km |
|---|---|---|
| 100 km/h | 6:00 min | 3:36–5:24 min |
| 160 km/h | 3:45 min | 2:15–3:23 min |
| 250 km/h | 2:24 min | 1:26–2:10 min |

- Die Straße scrollt so, dass sich das Tempo auf dem Tacho richtig anfühlt. Nur Kilometerzähler und Uhr laufen zehnmal schneller.
- Kernlänge einer Etappe: 150–300 km, also etwa 5–12 Spielminuten. Längere Abschnitte werden in mehrere Etappen geteilt.
- *(seit v0.7.0)* Alle Regeln in Kilometern (Tankstellen, Radar, City Limits, Ankündigungen) bleiben, wie sie sind – sie dauern nur ein Fünftel länger.

## Fahrzeug und Steuerung

Das Fahrmodell ist reines Arcade ohne Physik-Engine: Der Wagen folgt der Straße, gelenkt wird nur seitlich.

- Eingaben: Lenken, Gas, Bremse.
- Grundwert Höchstgeschwindigkeit 250 km/h. Wetter, Steigung und Nacht senken das Maximum.
- Kein Übersteuern, kein Dreher. Ist der Wagen in einer Kurve zu schnell, untersteuert er: Er wird proportional zur Überschreitung nach außen gedrückt, und die Lenkung greift schwächer.
- *(seit v0.5.0)* Regen und Schnee senken außerdem die Haftung: Regen auf 75 %, Schnee auf 45 %. Sie wirkt auf Kurventempo, Bremsen, Beschleunigen und Lenken: Bei Schnee ist der Bremsweg etwa doppelt so lang, 0–100 km/h dauert mit jedem Fahrzeug rund 8,4 Sekunden, und nach einem Spurwechsel rutscht der Wagen weiter, sodass man früh gegenlenken muss. Übersteuern und Dreher gibt es auch hier nicht.

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

Alle anderen Fahrzeuge fahren in dieselbe Richtung wie der Spieler, auf festen Spuren. *(seit v0.5.0)* Der Verkehr ist ein echtes Hindernis: Im Spieltest von v0.4.0 ließ er sich selbst mit Höchsttempo in aller Ruhe überholen.

| Straßentyp | Grundgeschwindigkeit Pkw | Lkw *(seit v0.5.0)* | Busse *(seit v0.5.0)* |
|---|---|---|---|
| Autobahn | 110–150 km/h | 80–90 km/h | 95–100 km/h |
| Landstraße | 70–100 km/h | 65–80 km/h | 70–85 km/h |
| City Limits | 40–60 km/h | 35–50 km/h | 35–50 km/h |

- *(seit v0.5.0)* Die Grundgeschwindigkeit galt ursprünglich für alle Fahrzeuge. Jetzt fahren Lkw und Busse langsamer, und Pkw richten sich nach dem Tempolimit des Abschnitts (je nach Fahrer etwas darunter oder darüber); schnelle Pkw fahren eher links, langsame rechts.
- Die Dichte folgt einer Tageskurve: Spitzen etwa 7–9 und 16–19 Uhr, Minimum 1–5 Uhr.
- Nachts von 23 bis 4 Uhr sind weniger Fahrzeuge unterwegs. *(seit v0.5.0)* Sie fahren nicht mehr schneller als tagsüber: Der ursprüngliche Nachtbonus von 15 % (Spielraum 15–20 %) machte das Überholen noch leichter.
- *(seit v0.5.0)* Bei Regen fährt der Verkehr etwa 15 % langsamer, bei Schnee etwa 35 % (Lkw und Busse 12 % bzw. 32 %), mit größeren Abständen und vorsichtigeren Spurwechseln. Man kommt also trotz geringerer Höchstgeschwindigkeit etwa so schnell auf ihn zu wie im Trockenen – bei längerem Bremsweg.
- *(seit v0.5.0)* Niemand macht dem Spieler Platz. Spurwechsel werden mit dem Blinker angekündigt, bei Pkw 1–1,5 Sekunden vorher, bei Lkw und Bussen etwas früher; nur wer einem langsameren Spieler im Notfall ausweicht, zieht sofort hinüber. Autos ziehen auch vor einem schnell herankommenden Spieler heraus, aber nie so knapp, dass Bremsen im aktuellen Wetter nicht mehr reicht.
- *(seit v0.5.0)* Auf Straßen mit mindestens drei Spuren überholt ein Lkw oder Bus ein langsameres schweres Fahrzeug („Elefantenrennen“) und gibt nach spätestens 45 Sekunden auf; die linke Spur bleibt dabei frei. Langsame Fahrzeuge ziehen kleine Kolonnen hinter sich her, und an Spurenden wird im Reißverschluss eingefädelt.
- *(seit v0.5.0)* Grundsatz: schwer, aber fair. Was zum Bremsen zwingt, soll rechtzeitig zu sehen oder angekündigt sein – auch bei Schnee in der Nacht (Sicht, Blinker, Vorschild der City Limits, Warnschild „Kuppe“ vor blinden Kuppen).
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
- *(seit v0.7.0)* Die erste Tankstelle liegt in jeder Fahrtrichtung spätestens 20 km nach dem Etappenstart. Tankstellen gibt es deshalb je Fahrtrichtung, wie Radarfallen.
- *(seit v0.7.0)* Im Rennen geht der Tankinhalt am Etappenende in die nächste Etappe mit, auch über die Fähre. Reicht er nicht einmal mit 60 km/h bis zur ersten Tankstelle, kommt vor dem Start der Abschleppdienst, mit derselben Zeitstrafe wie unterwegs. Der Etappenbildschirm zeigt den Tank und die Entfernung zur ersten Tankstelle, der Countdown sagt, ob der Tank dorthin reicht. Einzelne Etappen starten weiter mit ihrer eigenen Füllung, in der Regel voll.
- Ankündigung 30 km, 15 km und 5 km vorher. *(seit v0.7.0)* Liegt die erste Tankstelle näher, wird sie beim Start mit ihrer Entfernung angekündigt.
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
- *(seit v0.5.0)* Ankündigung 4 km vorher (Vorschild und Einblendung), weil hinter dem Ortsschild oft eine langsame Kolonne steht.

## Tageszeit und Wetter

Bei einem Rennen legt der Spieler die Startuhrzeit fest; jede weitere Etappe beginnt 8 Stunden Weltzeit nach dem Ende der vorherigen. *(seit v0.7.0; vorher 12 Stunden – die Startzeiten sprangen damit nur zwischen zwei Tageszeiten hin und her)*

- Die 8-Stunden-Pause zählt nicht zur Gesamtzeit.
- Die Uhr läuft im Zeitraffer mit: 12 Spielminuten entsprechen 2 Stunden *(seit v0.7.0, vorher 10 Spielminuten)*. Dämmerung, Nacht und Sonnenaufgang sind während einer Etappe sichtbar.
- *(seit v0.7.0)* Durch die Pause rückt die Startzeit von Etappe zu Etappe um 8 Stunden plus die Fahrzeit weiter und wandert in etwa zweieinhalb Etappen einmal um die Uhr: Wer Kiel – Nürnberg um 8 Uhr beginnt, startet die Etappen gegen 8, 17, 2, 11 und 21 Uhr. Die gewählte Startzeit wirkt so auf das ganze Rennen.
- Einzelne Etappe außerhalb eines Rennens: Uhrzeit und Wetter frei wählbar.
- Wetter: Normal, Regen, Schnee. Es wird vor der Etappe angezeigt und senkt Höchstgeschwindigkeit und Sicht. *(seit v0.5.0)* Außerdem senkt es die Haftung (siehe Fahrzeug und Steuerung) und das Tempo des Verkehrs (siehe Verkehr); bei Regen und Schnee sagt ein Hinweis im Countdown, was das Wetter bewirkt.
- Nacht: schlechtere Sicht, dafür weniger Verkehr (siehe Verkehr). *(seit v0.5.0)* Schnee hellt die Nacht auf: Die Sicht sinkt dann nachts weniger stark, damit man auch mit dem doppelten Bremsweg rechtzeitig vor langsamem Verkehr anhalten kann.

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

- Kiel – Hamburg: alternativlose Startetappe, gleichzeitig Tutorial. *(seit v0.5.0)* Im Rennen ist sie immer trocken, damit Einsteiger nicht gleich bei Regen oder Schnee beginnen. *(seit v0.7.0)* Sie startet mit gut einem Drittel Tank, die Tankstelle kommt nach 15 km; was im Ziel in Hamburg übrig ist, geht in die nächste Etappe mit.
- Ab Hamburg Wahl zwischen der Route über Kassel und der Route über Frankfurt (mehr Verkehr). Etappen über ca. 300 km bekommen eine Zwischenstation, etwa Hannover.

### Weitere Rennen

- Zum Beispiel Dresden – Dortmund, München – Bremen.
- *(seit v0.7.0)* Wien – Hamburg über Linz, Passau, Regensburg, Nürnberg, Fulda, Kassel und Hannover: Jede dieser Städte ist Pflichtstation und Etappenziel, die Route ist also fest (8 Etappen, rund 1.150 km; drei davon sind nur gut 100 km lang, weil die Städte so dicht liegen).
- *(seit v0.7.0)* Bukarest – Calais, mit Etappen von Stadt zu Stadt entlang der großen Straßen: Bukarest – Sibiu (durch das Olttal über die Karpaten) – Timișoara – Budapest – Wien, ab Wien wahlweise an der Donau entlang über Linz, Passau und Regensburg (kürzer, mehr Etappen) oder über Prag (länger, weniger Etappen) nach Nürnberg, dann Würzburg – Frankfurt – Köln – Brüssel – Calais. Rund 2.500–2.600 km in 11–13 Etappen; neues Land Rumänien.
- Königsrennen als Tour: Kiel – Hamburg – Bremen – Amsterdam – Lüttich – Paris – Madrid – Bern – Mailand – Sofia – Budapest – Wien – Prag – Leipzig – Berlin – Warschau – Riga – Fähre – Rostock – Kiel.
- Die Tour umfasst grob 11.000–12.000 km. Lange Abschnitte werden in Etappen von 200–400 km geteilt; nach jeder Etappe wird gespeichert.
- Die Fähre Riga – Rostock ist eine feste Zwischenzeit mit kurzer Szene. *(seit v0.7.0)* Der Tank geht unverändert mit auf die Fähre.

## Etappenbildschirm und Bestenlisten

Vor jeder Etappe zeigt ein Bildschirm die Strecke auf der Karte, das Wetter, den Rekord als Laufschrift und rechts daneben die Top 10.

- Laufschrift: Name des Rekordhalters, Zeit, Durchschnittsgeschwindigkeit.
- Bestenlisten pro Etappe und pro Rennen. Die Rennzeit ist die Summe der Etappenzeiten ohne Pausen.
- Jeder Eintrag speichert Name, Zeit, Durchschnittstempo, Fahrzeugtyp, Wetter und Tageszeit. Wetter und Tageszeit erscheinen als kleines Symbol neben der Zeit.
- Wer einen Platz in den Top 10 erreicht, gibt am Etappenende seinen Namen ein.
- Speicherung lokal als JSON.
- *(seit v0.7.0)* Gespeicherte Etappenzeiten werden auf den neuen Zeitraffer umgerechnet: gleicher Schnitt, Zeit × 1,2, die Namen und die Reihenfolge der eigenen Einträge bleiben; die neu berechneten Starteinträge können sich dazwischenschieben. Die Rennlisten beginnen neu, weil Zeitraffer, Pause und Tank-Übernahme die Rennzeiten verändern; die alten Listen bleiben als Sicherung erhalten. Aus demselben Grund kommt ein Rennen, das mit v0.6.0 begonnen und mit v0.7.0 fortgesetzt wird, nicht in die neue Rennliste.

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
