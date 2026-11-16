# Entwurf Ergebnis FIX1

summary (≤250 Wörter):
FIX1 hat die Befunde der QA von M1 am Kopf 9b6adbc nachgestellt und behoben, was ohne neue Modelle ging (8 Commits,
gepusht nach wip/v080-fix1). Bild: Tunnel haben eine Röhre in Arcades Formen mit Lampen, Portal, Hügel und Kappe statt
offenem Gelände (QB-01); die Tankstelle hat Dach, Insel mit gelbem Bordstein und „TANKSTELLE“ (QB-02); Elbphilharmonie
und Michel stehen in Arcades Reichweite am Horizont, die Brücke hat Geländer und helleres Wasser (QB-03); Start- und
Zieltor stehen (QB-04); der Mondglanz ist weg (p95 193 → 69, Arcade 51, QB-05); Arcades Nebelgesetz gilt jetzt für alle
Requisiten, Fahrzeuge und Schilder – keine Geisterbäume, Kontrast an der Sichtgrenze wie Arcade (QB-07). System: der
Haken läuft immer und listet Fehler (QS-01), check_facade und check_attract sind lastfest (QS-02/03), erst der zweite
Fehlstart in Folge speichert Arcade (QS-04), Hinweis im Ergebnis frei (QS-07), Doku (QS-08). Neu: Haken-Prüfung der
Mindestbauten (5/5), Render-Prüfung Sichtgrenze, Zeit je Teil von render() im Leistungstest. Offen: Wetter (R4),
Spielerauto-Modelle, Korridor-Entscheidung, zwei Pflicht-Render-Prüfungen (QA1), Versionskennung. Tore: ...
