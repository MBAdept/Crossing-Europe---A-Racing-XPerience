export const meta = {
  name: 'v080-m2-zusammenbau',
  description: 'v0.8.0 push M2, first assembly: merge the finished early content (all vehicle models, vegetation, rural buildings/bridge parts/ships, the reworked Modern sound) onto the first test build, resolve the predicted conflicts, re-export, measure memory/size/look, then independent QA with two lenses and one fix round',
  phases: [
    { title: 'Zusammenbau', detail: 'M2INT: merges AS2R, AS3R, AS4R and the sound head onto ZS1; conflicts, exports, tests, A/B' },
    { title: 'Prüfung', detail: 'QA-M2-BILD (picture, fairness, performance) and QA-M2-SYSTEM (Arcade identity, sound, pipeline, robustness)' },
    { title: 'Nacharbeit', detail: 'FIX-M2: confirmed blocker/high/medium findings, gates again' },
  ],
}
