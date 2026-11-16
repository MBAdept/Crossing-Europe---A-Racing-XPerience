export const meta = {
  name: 'v080-clipping',
  description: 'v0.8.0: the user saw a white car clip slightly into another car twice on Kassel – Erfurt in the first test build, linked to their steering – reproduce and analyse independently, diagnose with an adversarial counter-check, fix visually in Modern (simulation and Arcade untouched), independent review, fix round and re-check',
  phases: [
    { title: 'Untersuchung', detail: 'CLIP-NACHSTELLEN (reproduce and measure in the test build and on the M2 head) and CLIP-ANALYSE (code and geometry) side by side' },
    { title: 'Diagnose', detail: 'CLIP-DIAGNOSE: root causes ranked with evidence, fix design; two counter-checks try to refute it' },
    { title: 'Umsetzung', detail: 'FIX-CLIP on the M2 head: visual-only fix, tests, gates, before/after pictures' },
    { title: 'Prüfung', detail: 'QA-CLIP: independent review against the reproduction, fairness and Arcade identity' },
    { title: 'Nacharbeit', detail: 'FIX-CLIP2 on blocker/high/medium findings, NACH-CLIP re-check' },
  ],
}
