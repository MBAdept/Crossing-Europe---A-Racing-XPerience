
// Early start of M2 audio: AU-D1 (music chain, title remaster, race track 1)
phase('Musik')
const EARLY = `EARLY START – PRIORITY RULE: you are an early start of the next push (M2). The assembly of push M1 runs at the
same time and is on the critical path for the user's first test build. Run EVERY heavy job (audio renders, Godot runs,
test suites) with nice -n 19 (not 10) and one worker process; never two heavy jobs at once.`

const AUD1 = `${common('AU-D1', { mode: 'fresh', base: '3b89a3326285d5c186709c391c52838dccbab01f' }, 'content')}
${EARLY}
YOUR ROLE: AU-D1 – MUSIC CHAIN, TITLE REMASTER, RACE TRACK 1 (§6 wave 4 of the contract, D25, D26, D29, D30, §4.7,
A-5). Your base is UI1's head 3b89a33 (branch worktree-wf_9693abb2-cee-2): v0.8.0 with the audio core AU-A, the engine
v3 AU-B, the vehicle models AS1 and UI1's options (Klang, „Musik im Rennen“) and GameFlow's set_music_context calls.
Read docs/audio-modern.md completely (MusicDirector is already planned there as a building block on MMusic) and the
audio study: its sources ${SP}/audio/src (title_remaster.py, race_track.py = sketch "Linke Spur", D minor, 132 bpm,
music2lib.py, race_mix_demo.py, media_music.py), its numbers ${SP}/audio/out and its previews
${SP}/audio/deliver/musik (the user got titel_ab_erst_alt_dann_remaster.mp3, rennmusik_linke_spur_skizze.mp3 and
rennmix_musik_unter_motor.mp3 on 10 Nov; the user loved the v0.5.0 title theme – synthwave rock, 128 bpm – so stay in
that brand sound; no feedback on the sketches yet).
BUILD (files you own: tools/audio/music/**, scripts/audio/modern/music_director.gd, assets/audio/modern/music/**,
tests for them, the music section of docs/audio-modern.md; additive wiring in scripts/audio/modern/modern_audio.gd
only where the director is created and fed; the frozen Arcade tools tools/audio/music_synth.py etc. are imported,
never edited):
1. The music chain in the repo: tools/audio/music/ (generators that import the frozen Arcade instruments plus the
   modern layers of music2lib, a mastering stage: −14 LUFS integrated, true peak ≤ −1 dBTP after Ogg Vorbis q5,
   44.1 kHz; deterministic: two renders are byte-identical; --out <dir>; manifest.json with file, LUFS, true peak,
   bpm, bars, loop points, bytes – audio_qc.py must pass).
2. The title remaster: the same composition as the v0.5.0 title theme (key and chord-root check against the original
   – the audio study has compare_music.py), own file, used by the Modern profile on the title and menu screens at
   −20 LUFS menu level.
3. Race track 1 ("Linke Spur", grown from the study's sketch into a full piece of about 2.5–3.5 min): count-in that
   lands on the "Go", loop body, bar-synced ending at the finish, through AudioStreamInteractive (prove with a Godot
   test that the switch is gapless and bar-synced) or the two-player fallback of D30.
4. MusicDirector (scripts/audio/modern/music_director.gd): contexts title / menu / race_menu / race / result / off
   (set_music_context), set_race_music(on) honoured (default on in the Modern profile, Arcade has no race music),
   race music 8 dB under the car with the scripted ducking of A-5 (AudioEffectAmplify fader, key = ModernMix.car_lufs,
   attack 50 ms, release 450 ms), pause low-pass, crossfades without clicks, nothing in the Arcade profile, clean stop
   on exit (no "leaked at exit").
5. Tests: unit tests for the director's state machine; a headless check that plays a short race with the Modern
   profile and measures that the music ducks ≥ 3 dB under full throttle and recovers (frame time × time scale < 0.35 s,
   A-5); audio_qc.py on every new file; the size against the budget (§4.11: Modern sounds/music ≤ 23/≤ 25 MB).
DELIVER for the user (German file names, into ${SP}/deliver/AU-D1/): a 30–45 s sketch MP3 of race track 1 alone,
the same 40 s in the race mix under the engine (full throttle through the gears, then cruise – rendered from the game
or the study's race_mix_demo), the complete track 1 as MP3, the title A/B (old v0.5.0 → remaster) as MP3, spectrogram
pictures, and bericht.md. You cannot hear: judge with measurements (loudness, spectrum, chords, seams) and say
plainly that the user must judge the sound.
GATES: tools/run_tests.sh green (once, at the end); tools/golden.sh check 20 von 20 (Arcade identity); audio_qc.py
green; the Arcade profile plays no new sound (prove it). Push every commit to origin wip/v080-au-d1.
Return the result format with package "AU-D1".`

const aud1 = await agent(AUD1, { label: 'musik:AU-D1', phase: 'Musik', schema: BUILD_C, isolation: 'worktree' })
log(aud1 ? `AU-D1: ${aud1.commit ? aud1.commit.slice(0, 7) : '?'} (${aud1.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-D1 fehlt')
return { aud1 }
