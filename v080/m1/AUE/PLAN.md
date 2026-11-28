# AU-E – Audio-Integration und Pegel (Leitung, Welle 7) – Plan

Vertrag (Welle 7): `scripts/audio/audio_manager.gd` (falls nötig), `scripts/audio/modern/**`, config `audio.modern`;
ein ganzes Rennen je Profil aufgenommen; Pegelplan in Movie-Maker-Szenarien belegt
(`tests/race/check_audio_modern.gd`: Vollgas −16 ± 1,5 LUFS, Musik duckt ≥ 3 dB und erholt sich, schlimmster Fall
≤ −0,5 dBTP ohne Vollaussteuerung, Vorbeifahrt links/rechts und Doppler, Tunnelhallzeit); Kleinlautsprecher
(Hochpass 180 Hz); Stücke 4–5 nur, wenn alles andere fertig ist.

## Befunde vorab (gemessen/gelesen)
- Movie Maker läuft NICHT headless (Godot 4.7.2: .wav kein Writer, .avi stürzt mit Dummy-Renderer ab) → Xvfb +
  opengl3 wie `tools/ab_clip.sh`/`run_render_checks.sh`. Movie Maker mischt den Ton im Hauptthread je Bild
  (mix_rate/fps Frames) → AudioEffectCapture auf `Master` bekommt exakt synchrone Blöcke.
- Offene Punkte aus AU-C2 §16.9: Tunnel hebt alles um 3–5 dB (Begrenzer im schlimmsten Fall dauernd 2–4 dB);
  Ambiente/Verkehr gegen die ganze Mischung; Mischzustände/duck/context_db sind Startwerte (§6.4, §13).
- check_attract.gd schaut auf den Arcade-Musikplayer, passt mit Modern nicht (§13, UI2/AU-E).

## Schritte
1. Probe: Movie Maker unter Xvfb mit dem Renn-Szenenbaum in Modern (Bildkosten bei 320×180/640×360, Synchronität
   der Capture-Blöcke, AVI-Ton = Capture?).
2. `tests/race/check_audio_modern.gd` (Szenarien im echten Rennbaum, Analyse in GDScript: BS.1770 K-Gewichtung +
   Gating, True Peak 4× Überabtastung, L/R, Tonhöhe per Autokorrelation, Abklingzeit):
   - `throttle` (je Auto?): Vollgas durch die Gänge → Kurzzeit −16 ± 1,5 LUFS.
   - `duck`: Musik allein (`--mute-bus=MSfx`?) Leerlauf → Vollgas → vom Gas: Absenkung ≥ 3 dB, Erholung.
   - `worst`: Tunnel + Lkw + Polizei mit Horn + Aufprall + Musik → ≤ −0,5 dBTP, kein Abtastwert auf Vollaussteuerung.
   - `passby`: Auto links überholt → links vorher lauter, Tonhöhe fällt beim Passieren (rechts gespiegelt).
   - `tunnel_rt`: Hallzeit im Tunnel (Abklingen nach einem Impuls/Ende eines Klangs) im Band, draußen kürzer.
   - `speaker`: Hochpass 180 Hz auf Vollgas → Motor bleibt hörbar (Pegelverlust ≤ x dB, Ordnungen > 180 Hz da).
   Läufer: `tools/run_render_checks.sh audio` (eigene Gruppe, Movie-Maker-Argumente) – Zeilen `AUDIO-CHECK …`.
3. Abstimmung am fertigen Klang: Tunnel-Lautheit (Ausgleich in env), Mischzustände (impact/siren/result/pause),
   duck/context_db je Stück, Ambiente/Verkehr in der Mischung; alles gemessen vorher → nachher.
4. Ganze Etappe je Profil (Kiel – Hamburg, Autopilot, Arcade und Modern) aufnehmen: Lautheitsverlauf,
   True Peak, Begrenzer-Arbeit, Pausen/Stille, Musikwechsel; MP3 + Verlaufsbild für den Nutzer.
   (Ein ganzes Rennen Kiel – Nürnberg wären ~4,5 h Spielzeit je Profil – die Tutorial-Etappe ist ein ganzes
   Schnellrennen mit Countdown, Ziel, Ergebnis, Zwischenspiel.)
5. Attract mit Modern (check_attract.gd beide Modi) – wenn es Audio betrifft hier, sonst UI2.
6. Doku audio-modern.md §17, Vertrag-Nachtrag, Bericht deliver/AUE, unabhängige Prüfung, Tore.
