## 4. Entscheidungen und warum

1. **Schlüsse, Ziel-Schlag und Stinger je Stück, gerendert mit dessen Spurpegeln und Master.** „In der Tonart des
   Stücks“ heißt hier: dieselben Instrumente, dieselbe Partitur für jede Tonart (Kadenz, Tonika, phrygisches ♭II,
   Moll-Subdominante, Dur-Tonika), dasselbe Tempo. Die Zusatzclips laufen nach der Hauptdatei über eine eigene
   Zeitleiste und werden mit den aufgezeichneten Pegelentscheidungen des Stücks gemischt (`Mixer(ref=fit)`) und mit
   seinem gemessenen Master bearbeitet. Ein gemeinsames Rendering hätte die Normierung jeder Spur über die ganze Spur
   verändert – „Linke Spur“, deren Stil der Nutzer bestätigt hat, wäre nicht mehr bitgleich gewesen.
2. **Das Ziel ist Musik.** Der Director beansprucht `stage_finish`: Der Arcade-Jingle „finish“ (C-Dur-Arpeggio) klang
   bisher 0–1,8 s vor dem Schluss des Rennstücks – in c-Moll mit e gegen es. Jetzt: sofort der Ziel-Schlag in der
   Tonart (nur wenn der Taktstrich weiter als 0,3 s entfernt ist, sonst wäre es ein doppelter Schlag), am Taktstrich
   der Schluss in der passenden Variante. Ohne spielendes Stück („Musik im Rennen: Aus“) ist der Schluss selbst der
   Zielklang. Preis: Mit dem Regler „Musik“ auf 0 ist das Ziel in Modern still.
3. **Varianten statt Stinger über dem Schluss.** „Rekord“ und „Finale“ sind eigene Clips des
   `AudioStreamInteractive` mit demselben Übergang „nächster Taktstrich, ohne Überblenden“ wie der normale Schluss
   (gemessen wie bei AU-D1: Doku 14.4 und 14.12, hier Abschnitt 3). Eine Fanfare über dem laufenden Schluss hätte
   zeitlich nur auf ±1 Treiberportion gepasst und harmonisch gegen dessen Akkorde.
4. **Der Schluss klingt in den Ergebnisbildschirm aus.** Der Ergebnisbildschirm kommt 6 s nach dem Ziel
   (`render.finish_hold_s`), die Schlüsse dauern 8–13 s. Bisher schnitt der Kontextwechsel sie mit 0,6 s Ausblenden
   ab; jetzt läuft der Schluss bis 1,2 s vor seinem Ende weiter (höchstens 10 s), dann blendet das Zwischenspiel ein.
5. **Stinger auf dem nächsten Schlag, das Stück 9 dB darunter.** Ein Stinger mitten im Takt hätte gegen den Groove
   gestolpert. Die Wartezeit ist höchstens ein Schlag (0,40 s bei 150 bpm bis 0,57 s bei 105 bpm); die HUD-Meldung
   kommt sofort.
6. **Tempi, bei denen die Schleife exakt ist** (105 / 150 / 100 statt der geplanten 112 / 144 / 96 bpm): eine
   Sechzehntel muss eine ganze Zahl von Frames sein (bei 112 bpm lag die Naht bei −30 dBFS: Einsätze auf halben
   Frames) und die Schleife ein Vielfaches der 63-Frame-Blöcke des Kompressors (bei 108 bpm −34 dBFS) – beides
   gemessen, Falle 14.13.12; `race_lib.check_tempo()` verweigert seitdem andere Tempi.
7. **Zwischenspiel mit dem Hook der Titelmelodie.** Die Bildschirme zwischen den Etappen gehören zur Marke; der Hook
   leise auf der weichen Lead-Stimme verbindet Menü und Rennen. Das Ergebnis-Bild nimmt mangels eigenem Stück das
   Zwischenspiel (statt das Titel-Remaster neu zu starten) – so läuft vom Ergebnis zum Etappenbildschirm ein Stück.
8. **Gemeinsame Mischentscheidungen in einer Datei** (`mischung.json`), Werte relativ zu jedem Stück: eine Änderung
   von Sub, Bass oder Höhen wirkt in jedem Stück gleich, ohne dass die Stücke gleich klingen müssen. Bei 0 bleiben
   alle Dateien bitgleich – gemessen.
9. **Keine neuen Konfigurationsschlüssel**: `audio.modern` gehört in diesem Schub anderen Paketen; die Werte der
   Stinger-Absenkung stehen im Code und werden aus `audio.modern.music` gelesen, sobald jemand sie dort einträgt.
10. **UI-Klänge im Ordner `ui/` mit den Namen des `AudioManager`**: `ui_move`, `ui_ok`, `ui_back` wirken ohne eine
    Zeile Code (SfxBank nimmt die Modern-Datei, sobald das Manifest sie nennt). `ui_tab`, `ui_toggle`, `ui_error` gibt
    es als Klänge; aufrufen muss sie die UI (gehört UI1/UI2).
