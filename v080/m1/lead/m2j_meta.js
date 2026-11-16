export const meta = {
  name: 'v080-zs1-startfix',
  description: 'v0.8.0 first test build: fix the start of every stage in Modern (camera 9 m too far ahead, own car invisible in the countdown) and the start-gate lamp rims that cast shadows with shadows off, check boats on dry ground, rebuild the test build for Steam Deck and Windows with smoke tests, then an independent check of the delivered archives, a fix round only on blocker/high/medium findings and a focused re-check',
  phases: [
    { title: 'Korrektur', detail: 'FIX-ZS1: start at km 0, lamp rim shadows, boats; new test build, smoke tests, gates' },
    { title: 'Prüfung', detail: 'QA-ZS1: independent check of the delivered archives (Linux, Wine), the diff and the user documents' },
    { title: 'Nacharbeit', detail: 'FIX-ZS1R: only on blocker/high/medium findings' },
    { title: 'Nachprüfung', detail: 'NACH-ZS1: focused re-check, only if the fix round changed the game' },
  ],
}
