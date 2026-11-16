export const meta = {
  name: 'v080-klang-abnahme',
  description: 'v0.8.0 Modern sound acceptance: fix the last trigger fault (no old-town cobbles on concrete or steel bridges, e.g. the Venice causeway) and record the lead decisions on the measuring criteria (AU-R3); then two independent read-only checks of the final sound head with different lenses (measurement; code, triggering and regressions); a fix round only for blocker/high findings and a focused re-check of that fix; low CPU priority beside the test build',
  phases: [
    { title: 'Nachbesserung', detail: 'AU-R3: no cobbles on non-stone bridge decks, lead decisions V1–V3 in the audio docs, tests' },
    { title: 'Abnahme', detail: 'KRITIK-R2-MESS (measurement lens) and KRITIK-R2-CODE (code, triggering, regressions), read-only, in parallel' },
    { title: 'Nacharbeit', detail: 'AU-R4: only if an acceptance check finds blocker/high findings' },
    { title: 'Nachprüfung', detail: 'KRITIK-R3: focused read-only re-check of AU-R4 only' },
  ],
}
