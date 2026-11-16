export const meta = {
  name: 'v080-m2-zusammenbau',
  description: 'v0.8.0 push M2, first assembly: merge the finished early content (all vehicle models, vegetation, rural buildings/bridge parts/ships, the reworked Modern sound) onto the first test build, then merge the fixes of the delivered first test build (start, Elbe, landmarks, night pylons), then independent QA with two lenses, one fix round and a focused re-check',
  phases: [
    { title: 'Zusammenbau', detail: 'M2INT: merges AS2R, AS3R, AS4R and the sound head onto ZS1; conflicts, exports, tests, A/B' },
    { title: 'ZS1-Merge', detail: 'M2ZS1: merges the delivered first test build 39849f0 (start fix, Elbe, landmark stand-ins, dark pylons) into the assembly; conflicts, gates, builds' },
    { title: 'Prüfung', detail: 'QA-M2-BILD (picture, fairness, performance) and QA-M2-SYSTEM (Arcade identity, sound, pipeline, robustness)' },
    { title: 'Nacharbeit', detail: 'FIX-M2: confirmed blocker/high/medium findings, gates again' },
    { title: 'Nachprüfung', detail: 'NACH-M2: focused re-check, only if the fix round changed the game' },
  ],
}
