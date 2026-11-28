# AU-C2 – Welt, Ambiente, Verkehr, Sirenen (Plan der Leitung, 28.11.2026)

Grundlagen: Vertrag Welle 6 (AU-C2), D25–D30, §4.7, §4.11, §1 (keine Länder-Sirenen-Recherche); Studie [S]
(m1/AUC2/studie_audio.txt, Paket C2); audio-modern.md §4.1, §11, §13, §15; Bericht AU-C1/AU-R*.
Arcade bleibt unberührt (Regel 1): traffic_audio.gd, room_audio.gd, sfx_synth.gd, traffic_synth.py werden nur gelesen
bzw. importiert; ModernTraffic ist eine Unterklasse in traffic_extras.gd.

## Budget (gemessen 28.11., audio_qc): Klänge 19,00 von 23 MB → 4,0 MB frei
Ziel: AU-C2 ≤ 3,3 MB (Rest ≥ 0,5 MB Reserve). Grobplan: Ambiente ≤ 1,9 MB, Verkehr ≤ 1,3 MB.

## Klangdateien
### ambience/ (ambience_synth.py) – Ogg Vorbis q3–q4, 44,1 kHz
- Betten (Stereo-Schleifen, nur Texturen ohne auffällige Einzelereignisse – sonst hört man die Schleife):
  breeze, leaves, crickets, cicadas, city_day, city_night, water (Hafen/Ufer), tunnel_fans (Hall eingebacken),
  hum (Tankstellen-/Grenzdach), rain.
- Ereignisse (Mono-Einmalklänge, Ogg): Vögel (Amsel, Buchfink, Meise, Spatz, Krähe, Lerche, Specht), Eule,
  Hund fern, Möwen, Schiffshorn fern, Stadt (Hupe fern, Taube, Kirchenglocke, Roller fern). Die Laufzeit streut sie
  zufällig (Rate, Variante, Seite, Entfernung, Tonhöhe ±) – nichts wiederholt sich im Takt einer Schleife.
- Kein Donner: Das Spiel hat keine Blitze (kein Ereignis, Rule 4: nicht aus dem Renderer). Offen für später.
### traffic/ (traffic_modern.py) – Verkehr und Martinshorn
- Motoren: Arcade-Modell (traffic_synth/engine_synth, importiert) bei 32 kHz, periodisch per FFT auf 44,1 kHz;
  mehr Varianten (je Modell), E-Auto (nur Inverter-/Getriebeton + Reifen). Ogg (Rausch-/Tonmischung, Budget) mit
  Nahtprüfung und Qualitätsstufen wie vehicle_loops; Abweichung von §4.7.3 als A-35 begründen.
- Reifen trocken/nass für Pkw und Lkw (nass = Rollen + Sprühzischen), Fahrtwind – Ogg.
- Martinshorn (WAV, tonal): Arcade-Muster (440/587 Hz, 0,62 s je Ton), neue Klangfarbe (Druckkammer-Lautsprecher,
  Obertöne, weicher Übergang). Eine Art für ganz Europa (Vertrag §1).
- Hupen (WAV): Pkw Doppelton lang/kurz, Kleinwagen hell, Lkw-Drucklufthorn.
- Luftstoß beim Vorbeifahren (WAV): Pkw, Lkw/Bus (Druckwelle + Verwirbelung).
- Pegel: Daten (Manifest ref_kmh, pitch_exp, lufs_pitch; Plan in audio.modern.traffic).

## Laufzeit
### env (EnvAcoustics) – MEnv: AudioEffectDelay (2 Taps + Rückkopplung) + AudioEffectReverb
- Zonen-Voreinstellungen: open, forest, valley (Echo über die Rückkopplung), cutting, city, bridge, tunnel,
  cover (Dach: Grenze/Tankstelle) + Schnee-Dämpfung; weiche Übergänge.
- Godot (Quelltext gelesen): Tap-Verzögerung und Predelay springen ohne Rampe (Lesezeiger) → nur umstellen, während
  die Taps stumm sind (kurz ausblenden, umstellen, einblenden). Pegel/Raum/Dämpfung/Nass blockweise → im Skript
  glätten. Tap-Pan: L·(1−p), R·(1+p) (bei p = 1 rechts +6 dB) → Pan klein halten.
- Breite des Autos (motorsound.md 6.9): Korrelation im Spiel messen, Ziel nicht schmaler als Arcade.
### ambience (AmbienceAudio) – MAmb
- Gewichte je Bett aus Zone, Dach, Stadt (Mitte/Rand), Landschaft (Stil, Klima, Merkmale über scenery_db), Stunde
  (daytime aus der Konfiguration), Wetter (rain/snow), Tempo (Abblenden), Pause/Ergebnis (Mischzustände).
- Ereignis-Planer mit Poisson-Raten je Kategorie, Panorama-Spieler (ModernAudioPan).
### traffic (TrafficExtras) – MTrafficV0–7, MSiren
- ModernTraffic: Klänge/Klassen aus Manifest + audio.modern.traffic (nicht load_sounds: Arcade-_load_loop setzt
  loop_end ans Dateiende), Varianten je Modell, nasse Reifen (feed.wet/snow), Hupen (nach Kollision, knappes
  Vorbeiziehen; selten, zufällig, an der Fahrzeugposition), Luftstoß beim Passieren, Martinshorn-Pegel nach Plan.
- Pegelplan neu: Vorbeifahrt Pkw/Lkw am Nachbarstreifen, Martinshorn nah/fern als Lautheit am Master; Ziel: der
  schlimmste Fall (§15.5) ohne große Begrenzung (vorher +4 dB über der Schwelle durch die Platzhalter).

## Nebenpunkte (offene Punkte §13)
- modern_lib: Kopf der .import-Datei geht verloren (Fix an einer Stelle), WAV-Schleifen mit Fortsetzung (Helfer).
- audio_qc: Ogg-Schleifen auch in traffic/ (wie vehicle/); WAV-Schleife ohne Fortsetzung = Hinweis/Fehler.

## Prüfungen
- Unit: test_env_acoustics, test_ambience_audio, test_traffic_extras (rein, ohne Szenenbaum).
- check_modern_audio (Wiedergabe), audio_qc (+ --determinism), Größenbericht, test_arcade_identity.
- Messungen (eigene Fahrt wie AU-C1 drive_demo): Pegel je Bett/Zone, Vorbeifahrt L/R + Doppler, Lkw-Luftstoß,
  Martinshorn nah/fern, Tunnelhall (Nachhallzeit), Breite des Autos, schlimmster Fall (Tunnel + Lkw + Horn + Aufprall
  + Musik) ≤ −0,5 dBTP und Begrenzung, Rechenzeit.
- Hörproben für den Nutzer (MP3): deliver/AUC2/.
- Unabhängige Kritik (Agent, Code + Messungen), Nacharbeit, Tore (golden check, modern-check, run_tests).
