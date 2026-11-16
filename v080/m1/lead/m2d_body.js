
// Early start of M2 audio: AU-C1 (road surfaces, tyres, wind, impacts)
phase('Fahrbahnklang')
const EARLY = `EARLY START – PRIORITY RULE: you are an early start of a later wave. The assembly of push M1 runs at the same time
and is on the critical path for the user's first test build. Run EVERY heavy job (audio renders, Godot runs, test
suites, audio_qc --determinism) with nice -n 19 and one worker process; never two heavy jobs at once.`

const AUC1 = `${common('AU-C1', { mode: 'fresh', base: '2f4f260d3e889b01cf05ca8a91e87f043d1a4d9f' }, 'content')}
${EARLY}
YOUR ROLE: AU-C1 – ROAD, TYRES, WIND, IMPACTS (contract §6 wave 4 "AU-C1", D27–D29, §4.7.2, §4.7.3, A-5). Your base is
AU-D2's final head 2f4f260 (branch worktree-wf_2b39c7a4-a94-1, origin/wip/v080-au-d2): v0.8.0 with the audio core
AU-A, the engine v3 AU-B, the music AU-D1 and AU-D2, UI1 and the vehicle models AS1. Read docs/audio-modern.md
completely (the building blocks road, impact and the pure AudioFeed are planned there; today they are placeholders with
the Arcade formulas), AU-B's report ${SP}/deliver/AU-B/bericht.md (engine v3 – its loudness is the reference of the
whole mix) and the audio study ${SP}/audio (src, out, deliver/motor; the user heard and liked the engine A/B).
BUILD (files you own: tools/audio/modern/{vehicle_loops, sfx_modern}.py, scripts/audio/modern/{road_audio,
impact_audio, audio_feed}.gd, assets/audio/modern/{vehicle, sfx}/**, config/game_config.json → audio.modern (this
wave's owner), tests for them, the matching sections of docs/audio-modern.md; never music/ui of AU-D1/AU-D2, never the
frozen Arcade tools and sounds, never scripts/ui/**):
1. AudioFeed (pure, read-only, D28): surface per side (asphalt, concrete, cobbles in cities, gravel/grass shoulder,
   bridge deck, wet), rumble strips, expansion joints of bridges, zones (open, forest, city, cutting, tunnel – tunnel
   reverb belongs to AU-C2's env acoustics, give it the zone), pass-by objects at and behind the car only – all from
   the Track given in set_track and the vehicle state of §4.7.2; never from the renderer (Rule 4).
2. Road and tyres: rolling noise by surface and speed (tyre-cavity resonance, aggregate texture), rumble strip and
   joint thumps by wheel axle timing, shoulder gravel, wet hiss in rain, tyre squeal from slip/understeer
   (understeer, lat_speed) – natively mixed loops with click-free seams (continuation frames after loop_end, A-5 note).
3. Wind: speed-dependent broadband with gusts, open window feeling at top speed, quieter in tunnels and cuttings,
   stronger on bridges; wind 3 dB and tyres 4 dB under the engine at top speed (parameters in data: audio.modern).
4. Impacts: collisions layered by speed and partner (car, truck, guard rail scrape and hit, delineator/post), side
   panned, rail_hit with scrape loop while rail_contact, off-road rumble; replaces the Arcade crash/rail one-shots in
   the Modern profile only.
5. Worst case (tunnel + trucks + siren + crash + music) ≤ −0.5 dBTP at the master (measure with the capture tool of
   AU-A/AU-D1); the Arcade profile plays nothing new.
DELIVER for the user (German file names, ${SP}/deliver/AU-C1/): one MP3 per layer (road surfaces in a row, rumble strip
and joints, wind from 50 to 250 km/h, tyre squeal, impacts by speed and partner) and one 45–60 s MP3 of a drive in the
game mix with the engine (motorway → bridge joints → rumble strip → shoulder → scrape on the guard rail → city
cobbles), spectrograms and bericht.md. You cannot hear: judge with measurements and say plainly that the user must
judge the sound.
GATES: audio_qc.py green (seams, levels, determinism); tools/run_tests.sh green (once, at the end); tools/golden.sh check
20 von 20; the Arcade profile unchanged (prove it). Push every commit to origin wip/v080-au-c1. Return the result format
with package "AU-C1".`

const auc1 = await agent(AUC1, { label: 'klang:AU-C1', phase: 'Fahrbahnklang', schema: BUILD_C, isolation: 'worktree' })
log(auc1 ? `AU-C1: ${auc1.commit ? auc1.commit.slice(0, 7) : '?'} (${auc1.acceptance.filter(a => a.result !== 'pass').length} offen)` : 'AU-C1 fehlt')
return { auc1 }
