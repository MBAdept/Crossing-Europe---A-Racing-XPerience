## 4. Klang

Hier hört niemand zu: alles unten ist an Dateien **gemessen**; wie es klingt, ist **abgeleitet** bzw. Sache des
Nutzers. Mitschnitte des Master-Busses mit `tools/audio/modern/capture_mix.gd` (Kopie `gd/qa_capture_mix.gd` mit dem
zusätzlichen Schalter `--race-music=0`), ohne Bildschirm, Dummy-Treiber, Echtzeit, Last 11–14; Ordner `sound/`,
`sound_drive/`, `sound_rep/`, `sound_seam/`.

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Arcade-Klang unverändert | Fingerabdruck aus v0.7.0 neu erzeugt = eingecheckt = dieser Baum (Abschnitt 1); `test_arcade_identity.gd`, `check_modern_audio.gd`, `check_music.gd` (Profil Arcade: kein `ModernAudio`, kein Modern-Bus) im Unit-Lauf grün | `audio_golden/`, `run_tests_1.log` |
| Klangdateien Modern (`audio_qc.py`) | 24 Dateien, 0 Fehler (Manifest = Datei, True Peak, Lautheit, Gleichanteil, **Schleifennähte**, Import); Klänge 12,6 MB von 23 MB, Musik 7,5 MB von 25 MB | `audio_qc.log` |
| Profil Modern in Menüs und Rennen | folgt Auswahl und Optionen sofort im Menü, wechselt nie in einer laufenden Etappe (Abschnitt 2); „ModernAudio: Profil „Modern“ gestartet (22 Busse, 24 Klangdateien)“ in jedem Modern-Lauf, keine Fehlerzeile | `champ_switch.log`, `pad/*/run.log` |
| Alle Kombinationen Bild × Klang | Arcade-Bild/Modern-Klang und Modern-Bild/Arcade-Klang: `ERGEBNIS` = v0.7.0, keine Fehlerzeile | `ergebnis/combo_*.json` |
| **Motor v3, alle fünf Autos** | je ein Mitschnitt (3 s Leerlauf, Vollgas bis Höchsttempo, 6 s Vollgas, 3 s Gas weg, 130 km/h) in beiden Profilen; Spektrogramme `klang_spektrogramme_motor_arcade_modern.png` (oben Arcade, darunter Modern je Auto, log. Frequenzachse): alle fünf Modern-Motoren haben ihre Harmonischen, folgen den Gängen (Sägezahn), dem Plateau, dem Gaswegnehmen und dem Reisetempo; Modern mit mehr Obertönen und Rauschen 1–10 kHz, Kombi/Kompakt/Limousine fast mono (Korrelation 0,98–1,00, bekannt: Raum fehlt noch, AU-C2), Sportwagen und Gran Turismo breiter (0,84–0,85) | `sound_drive/`, `sound_report.json` |
| Pegelplan Modern je Auto (`measure_mix.py`) | Vollgas −15,7 … −17,0 LUFS (Plan −16), Reisetempo −21,6 … −22,2 (Plan −21), Leerlauf −24,0 … −25,3 (Plan −24), True Peak ≤ −5,5 dBTP. Achtung: unter Last ist die Aufnahme bis 5 % kürzer als die Zeitleiste der Phasen – Werte am Phasenende ungenau | `python3 tools/audio/modern/measure_mix.py sound_drive/modern_drive_<auto>.wav` |
| Aussetzer | 0 in 17 von 18 Mitschnitten (10 Fahrten, 5 Musik/Menü, 3 Wiederholungen); **1 × 41 ms digitale Stille** im ersten Sportwagen-Mitschnitt beim Übergang Leerlauf → Vollgas mit hartem Wiedereinsatz (`klang_sportwagen_aussetzer.png`); in 3 Wiederholungen 0 – abgeleitet: Unterlauf des Mischer-Threads bei Last 11–14 (wie in audio-modern.md Falle 12 beschrieben), kein Fehler der Bank | `sound_rep/` |
| Knacken | Motor: Kandidaten (Sprung > 4 × Umgebung) nur im Leerlauf (Zündstöße, in **Arcade genauso**), beim Gaswegnehmen und Gasgeben (Crackle/Tip-in, gewollt); kein Kandidat an Zyklus- oder Schleifengrenzen erkennbar; in der Musik zählt der Detektor Schlagzeug (Arcade-Menü 0, Modern-Musik 6–65). Ein allgemeiner Knackdetektor unterscheidet das nicht sicher (abgeleitet) | `sound_report.json` |
| Ducking | Musik allein (Auto-Gruppe stumm): Vollgas −23,7 LUFS = 7,7 dB unter dem Auto (Plan 8 dB), Leerlauf −18,8 (Plan −19,5); Absenkung −4,5 dB bei Vollgas, −2,1 dB bei 130 km/h, 0 im Leerlauf | `sound/modern_race_music*.json` |
| „Musik im Rennen“ An/Aus | An: Leerlauf mit Musik −18,2 LUFS; **Aus: −23,9 LUFS = Auto allein** (Musik still), Vollgas −16,1 statt −15,5 | `sound/modern_race_music_off.wav` |
| Menümusik | Modern −21,2 LUFS integriert, Kurzzeit-Median −20,1 (Plan −20); Arcade −29,5 LUFS (Titelmelodie von v0.7.0, unverändert) – mit dem Wechsel auf Modern wird die Menümusik rund 8 dB lauter (so geplant) | `sound/*_menu.wav` |
| Titelmusik über die Schleifennaht (212 s Menü mitgeschnitten) | kein stiller 50-ms-Block, der größte Sprung ±1 s um die Naht (202,5 s) 0,205 liegt unter dem des Stücks (0,26, Schlagzeug) – die Naht fällt in den Daten nicht auf | `sound_seam/` |
| Sauberes Beenden | über „Beenden“ 4 von 4 ohne „leaked“/„still in use“ (Abschnitt 5.2); Render-Prüfung `check_quit_sound` siehe 5.5 | `quit/qt_*.log` |
