
// Early start of M2 music, part 2: AU-D2 (race tracks 2-3, interlude, stingers, UI sounds)
phase('Musik 2')
const EARLY = `EARLY START – PRIORITY RULE: you are an early start of a later wave. The assembly of push M1 runs at the same time
and is on the critical path for the user's first test build. Run EVERY heavy job (audio renders, Godot runs, test
suites, audio_qc --determinism) with nice -n 19 and one worker process; never two heavy jobs at once.`

const AUD2 = `${common('AU-D2', { mode: 'fresh', base: '03eaeff73e3af18cf2ed13c4df0126040bf4d296' }, 'content')}
${EARLY}
YOUR ROLE: AU-D2 – RACE TRACKS 2 AND 3, INTERLUDE, STINGERS, UI SOUNDS (contract §6 wave 6 "AU-D2", D29, D30, §4.7,
A-5). Your base is AU-D1's final head 03eaeff (branch worktree-wf_158edd89-079-1, origin/wip/v080-au-d1): the music
chain tools/audio/music/ (music_lib.py: mixer, multiband master, encode_checked, write_ogg_import_keep),
title_remaster.py, linke_spur.py (race track 1), check_music.py, the MusicDirector and its tests. Read AU-D1's report
${SP}/deliver/AU-D1/bericht.md completely – above all its measured traps of AudioStreamInteractive and Ogg
(docs/audio-modern.md §14.8): render whole phrases and cut at the bar line for a seamless loop, no fade into the ending,
loop_offset written with full precision.
THE USER'S VERDICT on AU-D1's previews (track 1 "Linke Spur" and the title remaster): "der Stil passt super". Details
(bass, level) the user judges tonight with headphones. So: stay in exactly this brand sound (synthwave rock on the
frozen Arcade instruments plus the modern layers), and keep every mix decision that the user may still change in ONE
place shared by all pieces (sub and bass level, high shelf, music level against the car) so that one change re-renders
every piece consistently.
BUILD (files you own: tools/audio/music/**, assets/audio/modern/music/**, assets/audio/modern/ui/**,
scripts/audio/modern/music_director.gd, tests for them, the music and UI-sound sections of docs/audio-modern.md;
never assets/audio/modern/sfx/** – that belongs to AU-C1 – and never the frozen Arcade tools and sounds):
1. Race tracks 2 and 3, each about 2.5–3.5 min with count-in on the "Go", loop body and bar-synced ending exactly like
   "Linke Spur" (two files per track as AU-D1 found necessary), each with its own key, tempo and character so three
   stages in a row do not sound alike (for example one darker night-drive piece and one bright, uplifting one), clear
   form, melody and hook; −14 LUFS, true peak ≤ −1 dBTP after Ogg Vorbis q5; deterministic renders; manifest entries.
   The director plays the race tracks in rotation (AU-D1 prepared that).
2. The interlude: a calm loop (60–90 s, seamless) for the screens between stages (context race_menu), at the menu
   level of −20 LUFS – today race_menu plays the title remaster.
3. Stingers: short one-shots for stage finish, new record, last stage won (championship), busted by the police and
   out of fuel – driven by the events of §4.7.2 (stage_finish {record, last_stage}, busted, out_of_fuel) through the
   MusicDirector or ModernAudio, ducking the running music, in key with the piece they follow where possible.
4. UI sounds for the Modern profile (focus move, confirm, back, tab switch, toggle, error), soft and in the brand
   sound, wired where ModernAudio maps the existing play() calls (read docs/audio-modern.md); the Arcade UI sounds stay.
5. Tests: unit tests for the rotation, interlude context and stingers; the interactive checks of AU-D1 for the new
   tracks (seamless loop, ending at the bar line, no gap, no double hit); audio_qc.py on every new file; the music
   folder ≤ 25 MB in total (§4.11; AU-D1 used 7.48 MB).
DELIVER for the user (German file names, ${SP}/deliver/AU-D2/): a 45 s excerpt and the complete piece of each new race
track, the interlude, all stingers in one demo file with spoken-free gaps, the UI sounds in one demo file, spectrograms,
bericht.md. You cannot hear: judge with measurements and say plainly that the user must judge the sound.
GATES: tools/run_tests.sh green (once, at the end); tools/golden.sh check 20 von 20; audio_qc.py green; the Arcade
profile plays nothing new. Push every commit to origin wip/v080-au-d2. Return the result format with package "AU-D2".`

const aud2 = await agent(AUD2, { label: 'musik:AU-D2', phase: 'Musik 2', schema: BUILD_C, isolation: 'worktree' })
log(aud2 ? `AU-D2: ${aud2.commit ? aud2.commit.slice(0, 7) : '?'} (${aud2.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-D2 fehlt')
return { aud2 }
