export const meta = {
  name: 'v080-lackflackern',
  description: 'v0.8.0: the user saw a white traffic car about 40 m ahead briefly lose its paint, twice, on Kassel – Erfurt in the first test build (a graphics flicker, linked to their steering) – reproduce and analyse independently, diagnose with an adversarial counter-check, fix in the Modern renderer or the models (Arcade untouched), independent review, fix round and re-check',
  phases: [
    { title: 'Untersuchung', detail: 'FLACKER-NACHSTELLEN (reproduce and measure in the test build and on the M2 head) and FLACKER-ANALYSE (code, shader, models) side by side' },
    { title: 'Diagnose', detail: 'FLACKER-DIAGNOSE: root causes ranked with evidence, fix design; two counter-checks try to refute it' },
    { title: 'Umsetzung', detail: 'FIX-FLACKERN on the M2 head: root-cause fix, tests, gates, before/after pictures' },
    { title: 'Prüfung', detail: 'QA-FLACKERN: independent review against the reproduction, fairness and Arcade identity' },
    { title: 'Nacharbeit', detail: 'FIX-FLACKERN2 on blocker/high/medium findings, NACH-FLACKERN re-check' },
  ],
}
