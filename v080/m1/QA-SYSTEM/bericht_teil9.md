## 9. Vertragsfragen (contract_issues)

1. **D15 `gfx`**: Der Vertrag kennt nur `"arcade" | "modern"`; ein Renneintrag, dessen Etappen in beiden Modi liefen,
   bekommt von UI1 `"mixed"` (`RaceState.gfx_summary()`). Sinnvoll – der Vertrag sollte den Wert nennen.
2. **§4.9.1 / A-6 Haken in `run_tests.sh`**: „Später fügen Pakete nur Dateien hinzu, niemand ändert `run_tests.sh`“ –
   der Haken aus Welle 0 läuft aber nur, wenn alles davor grün war (QS-01). Wer darf das jetzt ändern? (A-8 nennt die
   Integration und QA1.)
3. **Regel 8 („jeder Lauf mit `--graphics=`“)** schließt genau die Läufe aus, die Auswahl, gespeicherten Modus und
   Absturz-Frage prüfen (die brauchen einen Start ohne Argument bzw. ohne `--graphics`). Diese Prüfung lief bewusst
   ohne `--graphics` – der Vertrag sollte die Ausnahme nennen.
4. **D34 (b) Absturz-Wächter**: „entfernt nach 2 s gezeichneter Bilder oder beim geordneten Verlassen“ deckt `SIGTERM`
   nicht ab, und ein Laden der Etappe von mehreren Sekunden liegt immer im Fenster (QS-04). Der Vertrag sollte festlegen,
   ob die Antwort „Bei Arcade bleiben“ dauerhaft speichert.
5. **§5 `project.godot` erst in Welle 8**: M1 geht als Testbuild an den Nutzer, der Build heißt aber überall 0.7.0
   (QS-05). Eine Kennung für Testbuilds fehlt im Plan.

## 10. Für die Nächsten (notes_for_next)

- QS-01/02/03 vor dem Gate-Build beheben, dann `run_tests.sh` zweimal auf ruhiger Maschine (Last ≤ 4) laufen lassen.
- QS-04 entscheiden (Absturz-Frage nach `SIGTERM`) – betrifft Steam Deck und Linux-Desktop.
- Fenster schließen (X, Alt+F4, Steam „Spiel beenden“) konnte hier ohne Fenstermanager nicht nachgestellt werden: beim
  Nutzertest unter Windows und auf dem Deck ausdrücklich prüfen lassen (Einstellungen gespeichert? Marker weg?).
- Leistungstest: In M1 fehlen in Modern Wetter, Tunnelbauwerke und Stadtgebäude – die Zahlen des Nutzers für „Stadt bei
  Nacht im Regen“ und „Bergstrecke mit Tunnel“ werden später schlechter; bei Gate 2 neu messen lassen.
- QA1: Für die zweite Golden-Liste (Menüs, Pause, 1280×800) pulsieren die ◀▶-Pfeile von Fahrzeugwahl und Startzeit
  mit `Time.get_ticks_msec()` – in Testläufen eine feste Uhr nehmen (z. B. bei `--gfx-sync`); alles andere war hier
  schon bildgleich (Menüs, Ladebild, Pause).
- Doku nachziehen (QS-08).
