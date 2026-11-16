**Wind, Reifen und Menüklänge einzeln** (15.11., Nachtrag zu Punkt 2 der vorigen Fassung; `gd/qa_tyre_wind.gd` =
`capture_mix.gd` mit Movie-Maker-Uhr und drei Szenarien, Profil Modern, Standardregler, Gran Turismo, die übrigen
Busse über `--mute-bus` stumm; `bin/tyre_wind.sh`, Auswertung `measure_mix.py` und `bin/analyze_tw.py` →
`tyrewind/analyze.txt`; alle Zahlen gemessen):

| Mitschnitt | Ergebnis |
|---|---|
| Wind allein (`MWind`; Motor, Fahrbahn, Musik stumm), je 4 s gehalten | 0 km/h still (−140 LUFS); 50 km/h −63,2; 100 −44,3; 150 −35,3; 200 −29,3; 240 km/h −24,6 LUFS. Stetig steigend, 100 → 200 km/h +15,0 dB (Gesetz 55 dB je Dekade = +16,6 dB für das Grundband; das Wummern setzt erst nahe am Höchsttempo ein); hochgerechnet auf 270 km/h (Höchsttempo GT) ≈ −21,8 LUFS bei Gesamtlautstärke 0,8 – passt zur Regel „Wind 3 dB unter dem Motor bei Höchsttempo“ (`test_road_audio`; abgeleitet, ±1 dB) |
| Reifen (`MRoad`; Motor, Wind, Musik stumm), 120 km/h Asphalt | Rollen −32,1 LUFS; Quietschen voll (`set_skid 1`) **−18,3 LUFS** (+13,8 dB, Schwerpunkt 630 Hz – 2,5 kHz +15 dB); nach dem Loslassen sofort wieder −32,1 (kein Hängenbleiben); halbes Quietschen (0,4) −26,8; True Peak höchstens −8,9 dBTP |
| Menü- und Ansageklänge einzeln (1 s Abstand, ohne Musik) | `ui_move` −27,8, `ui_ok` −25,2, `ui_back` −24,6, `ui/ui_tab` −25,7, `ui/ui_toggle` −26,2, `ui/ui_error` −24,6, `beep` −17,2, `go` −13,0, `finish` −9,9 LUFS (Kurzzeit, Gesamtlautstärke 0,8); jeder setzt weich ein (erster Schritt ≤ −42 dB) und klingt ohne Sprung aus; `ui_error.wav` blendet in ≈ 10 ms von −24 dBFS auf Stille (kurz, aber kein Sprung – ob man es hört, abgeleitet); `audio_qc.py` meldet alle Dateien OK |

Keine Fehler- oder „leaked“-Zeile in den drei Läufen.
