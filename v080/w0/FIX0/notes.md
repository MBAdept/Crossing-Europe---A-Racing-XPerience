# FIX0 working notes (scratch)

## Findings and status
KERN
- K1 equal shot times via GameFlow: CONFIRMED (timer 0:00.98 vs 0:01.00, l1/timer_before.png) -> fix
- K2 --shot-fast stops Modern preparation (attract): CONFIRMED (5364 px, arcade 0) -> fix
- K3 shot-fast hashes only Arcade (GPU particles): check probe -> flag --shot-fast-lead + README + contract issue
- K4 settings type errors: check -> fix
- K5 run_tests hook trusts exit code: fix
- K6 XDG relative: fix run_tests + run_render_checks (+golden?), screenshot.sh -> QA1 note
- K7 gfx helpers: fix
- K8 identity gate coverage: defer QA1 (note)
- K9 run_tests time 545 s: lead (note)
GEO
- G1 curve camera margin: lead (note)
- G2 F3 own eye: fix
- G3 max_chunks: config key documented (16), contract issue
PIPE
- P1 (M) cache key: fix + test
- P2 (M) rear indicators: fix + validator + rebake
- P3 plate: shader
- P4 lamp energy: shader + render check
- P5 decal cut artefacts: evaluate
- P6 player car quality: AS1 (note)
- P7 shadow caster winding: fix + validator
- P8 missing files -> stand-in: fix
- P9 ownership traps: fix/doc
- P10 street lamp auto_lod: fix + validator
- P11 light anchors below surface: project + dir / doc
- P12 doc statements: fix
- P13 untested paths: render check models, validator hook, cutout prop?
- P14 API inconsistencies: fix
AU-A
- A1 (M) ModernAudio late loading: fix + guard test
- A2 keep_alive release: fix
- A3 check_modern_audio under Xvfb: fix
- A4 audio_qc unknown file: fix
- A5 MusicDirector late stream: fix
- A6 frozen detach: lead
- A7 7.7 MB render buffers: doc
- A8 texture budget fonts: contract issue
- A9 Settings.sound vs AudioManager: UI1
- A10 run_tests time: lead
