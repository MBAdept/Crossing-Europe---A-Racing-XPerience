
// Two independent, read-only measurement reviews of the Modern sound before the user's headphone verdict arrives.
const HEAD = '4209268f0bad80beb9abc2609d92a74cd7279db1'   // AU-C1 final head: AU-A core, AU-B engine v3, AU-D1/AU-D2 music, AU-C1 road
const HEAD_WT = `${REPO}/.claude/worktrees/wf_f5d01292-ef8-1`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'honest overall judgement for the user, 5-10 sentences; nothing about how it sounds is measured – say inferred' },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string', enum: ['blocker', 'high', 'medium', 'low'] },
      area: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' },
      evidence: { type: 'string', description: 'command + output excerpt or picture path; measured vs inferred' },
      repro: { type: 'string' }, fix: { type: 'string', description: 'concrete change: file, parameter, value' } },
      required: ['id', 'severity', 'area', 'where', 'problem', 'evidence', 'repro', 'fix'] } },
    knobs: { type: 'array', items: { type: 'string' }, description: 'data knobs (file → key) with the effect of a stated change, measured where possible' },
    checked_ok: { type: 'array', items: { type: 'string' }, description: 'what was checked and found fine (one line each)' },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'findings', 'knobs', 'checked_ok', 'media'],
}

const EARLY = `PRIORITY RULE: the assembly and QA of the user's first test build run on this machine at the same time and are on
the critical path. Run EVERY heavy job (Godot runs, audio renders, analyses over many files) with nice -n 19 and one
process; never two heavy jobs at once. Never run tools/run_tests.sh or tools/golden.sh (not needed for a review).`

const COMMON_AU = `THE OBJECT OF REVIEW: the complete Modern sound profile on head ${HEAD} (branch origin/wip/v080-au-c1; the builder's
worktree ${HEAD_WT} is READ-ONLY for you – no edits, no commits there). Work on a copy in your scratch folder:
cp -a the worktree without build/ (and without .godot), then cp -a ${REPO}/.godot into the copy and import once
(godot --headless --path <copy> --import), absolute XDG_DATA_HOME for every run. You make no commits.
What it contains: AU-A (audio core: buses MCar/MWorld/MMusic/MImpact …, ModernMix, capture tools), AU-B (engine v3 –
the user heard and liked the engine A/B), AU-D1 (music chain tools/audio/music/, title remaster, race track 1 „Linke
Spur", MusicDirector), AU-D2 (race tracks 2 „Nachtfahrt" and 3 „Rückenwind", interlude, stingers, UI sounds; ONE mix
file tools/audio/music/mischung.json for every decision the user may still change), AU-C1 (AudioFeed, road, wind,
impacts). Reports: ${SP}/deliver/{AU-B,AU-D1,AU-D2,AU-C1}/bericht.md and the previews next to them; docs/audio-modern.md
(complete) and the audio study ${SP}/audio (src, out, deliver). Contract: docs/dev/v080_contract.md §3 D25–D30, §4.7,
§11 A-5.
THE USER: has heard the engine A/B (liked it), AU-D1's previews (track 1 and the title remaster: „der Stil passt
super"; bass and level are judged tonight with headphones) and gets AU-D2's and AU-C1's previews for tonight as well.
The user plays on a Steam Deck (small stereo speakers and headphones) and on Windows. A race lasts hours.
YOU CANNOT HEAR. Everything about how something sounds to a person is inferred; numbers are measured. Use objective
measurements (ITU-R BS.1770 loudness and true peak, third-octave/critical-band spectra, spectral tilt, crest factor,
stereo correlation and mono sum, modulation spectra, autocorrelation for repetition, onset/transient analysis, masking
estimates per critical band) and well-established acoustic facts about real sources; say plainly what a person must
judge. Python with numpy/scipy (if present)/PIL and ffmpeg are available; write your analysis scripts into your scratch
folder. Your job is to make the ONE rework after the user's verdict tonight fast and right: concrete, ranked findings
with file → parameter → value fixes, and a list of the data knobs with their measured effect.`

const FAHRBAHN = `${common('KRITIK-FAHRBAHN', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT MEASUREMENT REVIEW OF THE ROAD, TYRE, WIND AND IMPACT SOUNDS (AU-C1) AND OF THEIR TRIGGERING IN THE
GAME. No building.
${COMMON_AU}
REVIEW (rank by what the player hears most – the motorway at 100–200 km/h first):
1. Plausibility per layer against the physics of real sources (measure the sounds in assets/audio/modern/{vehicle,sfx}
   and in the previews): tyre/road rolling noise (broadband, its main band and its rise with speed; the tyre cavity
   resonance), asphalt vs concrete slabs (joint thumps at the axle pair, slab length), steel deck and expansion joints
   (double hit at the wheelbase), cobbles (impact rate from stone pitch × speed), rumble strip (tonal buzz at
   speed / groove pitch with harmonics – note that its fundamental is around 100 Hz at motorway speed), gravel shoulder,
   grass, wet (spray hiss), snow, squeal (tonal with jitter) and scrub, wind (three bands, gusts, the open-window
   buffeting), impacts (layering, partner, side, the glass layer). Name each place where the measurements suggest an
   artificial sound (steady filtered noise, a pure tone, ringing glass) and how the generator could make it more
   natural (decorrelated layers, random modulation, granular playback, longer loops).
2. Repetition: the loops are 0.8–3 s long. Play constant speed for 20 s in the game mix and measure the self-similarity
   (autocorrelation of the envelope and of the spectrum frames); say which loops would likely be heard as repeating and
   what length or layering would hide it.
3. Triggering in the game: run headless Modern stages with logging of the AudioFeed state once per second (surface
   per side, deck, joints, rumble strip, paving, zone, delineators) – Kiel – Hamburg completely, plus one stage with a
   long bridge, one with a city centre and one southern stage – and compare with the Track data (motorway class,
   bridges, cities, tunnels, fuel lanes, border posts): wrong or missing triggers, joints off the bridge ends, cobbles
   outside towns, rumble strip off motorways, tunnel/cutting zones where there is none. AU-C1 notes that the capture
   tool capture_mix.gd sends no vehicle state – use AU-C1's scratch scripts (${SP}/m1/AU-C1/: drive_demo.gd,
   layers_demo.gd, worst_case.gd, perf.gd, phases.py, peaks.py; copy them) or your own.
4. Small speakers and mono: apply a 180 Hz high-pass and a typical small-speaker response (Steam Deck class) to the game
   mix at 130 km/h: does the road layer stay audible, does the rumble strip vanish (its fundamental), does the wind turn
   into hiss? Mono sum of the side-panned sounds (ModernAudioPan) and the centre loudness of its pan law.
5. Levels and safety: the plan of D29 against the measured sums (AU-C1's contract issues: full throttle at top speed
   −14.4/−14.6 LUFS with road and wind; engines alone −17.2 to −18.5), heavy impacts at −2.8 dBFS, the master limiter
   (sample-peak, threshold −0.8 dB before the master volume, overshoot 0.1–0.7 dB, worst case at master volume 1.0
   inferred −0.5 to −0.1 dBTP), the traffic and siren placeholders driving the limiter by up to 4 dB. Propose concrete
   lead decisions with numbers (e.g. a true-peak-safe limiter threshold for the Modern profile only, the top-speed row
   of the plan) – the Arcade profile and its config stay frozen.
6. Cost and hygiene: CPU per frame of road/impact under the frame budget, allocations per frame, no "leaked at exit"
   with either profile, the Arcade profile plays nothing new (verify).
DELIVER to ${SP}/deliver/KRITIK-FAHRBAHN/ (German): bericht.md with the ranked findings, the measurements (tables,
spectrum pictures with German captions) and the knobs; nothing else.`

const MISCHUNG = `${common('KRITIK-MISCHUNG', { mode: 'readonly' }, 'content')}
${EARLY}
YOUR ROLE: INDEPENDENT MEASUREMENT REVIEW OF THE MUSIC MIX (AU-D1, AU-D2) AND OF THE WHOLE GAME MIX (music with engine,
road and wind). No building.
${COMMON_AU}
REVIEW:
1. The pieces: title remaster, „Linke Spur", „Nachtfahrt", „Rückenwind", the interlude, the stingers, the UI sounds
   (assets/audio/modern/{music,ui}/**, as shipped after Ogg Vorbis): integrated and short-term loudness against the
   plan (race −14 LUFS, menu −20 LUFS), true peak, crest factor, spectral balance per band (sub < 60 Hz, bass 60–250,
   low mids, presence 2–5 kHz, air > 8 kHz), long-term spectral tilt, stereo width and correlation per band (bass
   should be centred and in phase), and how consistent the three race tracks are with each other. The reference of the
   brand sound is the v0.5.0 title theme the user loved (the frozen Arcade music; find it in assets/audio and
   tools/audio/music_synth.py) – measure it the same way and show where the new pieces differ.
2. Headphones over hours: excessive sub energy (< 40 Hz), out-of-phase bass, harsh 2–5 kHz, sharp > 8 kHz, low crest
   factor (fatigue), loudness jumps between pieces and at the switches (count-in, loop, ending, stingers ducking the
   music, the interlude). Check the loop seams and the bar-synced endings once more in the game (AU-D1's interactive
   checks) – no gap, no double hit.
3. The game mix: music under the car at 80, 130, 200 and 250 km/h (engine v3 + road + wind of AU-C1, no traffic):
   measured ducking depth and recovery, and a masking estimate per critical band – is the melody/hook of each race
   track still above the car noise at 130 km/h on headphones and on small speakers (180 Hz high-pass)? Does the wind at
   200–250 km/h cover the music? What race music level (mischung.json race_music_db / the director's offset) keeps
   the music audible without fighting the engine?
4. THE KNOB SHEET for tonight: the user will say things like „zu viel Bass", „zu wenig Bass", „Musik im Rennen zu
   leise/zu laut", „zu schrill", „zu dumpf", „Menü zu laut". For each, which key of tools/audio/music/mischung.json
   (sub_db, bass_db, high_shelf_db/hz, race_music_db, menu_music_db, ui_db, …) or of config audio.modern changes by
   how much, with the predicted (where possible measured) effect on the numbers above. Measure how long a full
   re-render takes (tools/audio/music/render_all.py; AU-D2 reported 25–27 min at nice 19) and whether only the mix and
   master stage could be re-run for a mix change (read the code; do not change it).
DELIVER to ${SP}/deliver/KRITIK-MISCHUNG/ (German): bericht.md with the ranked findings, the measurements (tables,
spectrum pictures with German captions) and the knob sheet; nothing else.`

phase('Klangkritik')
const [fahrbahn, mischung] = await parallel([
  () => agent(FAHRBAHN, { label: 'kritik:Fahrbahn', phase: 'Klangkritik', schema: FINDINGS }),
  () => agent(MISCHUNG, { label: 'kritik:Mischung', phase: 'Klangkritik', schema: FINDINGS }),
])
for (const [n, r] of [['Fahrbahn', fahrbahn], ['Mischung', mischung]]) {
  if (r) log(`${n}: ${r.findings.length} Befunde (${r.findings.filter(f => ['blocker', 'high'].includes(f.severity)).length} hoch)`)
  else log(`${n}: ausgefallen`)
}
return { fahrbahn, mischung }
