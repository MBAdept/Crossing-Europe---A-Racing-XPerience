export const meta = {
  name: 'v080-zs1-wasser',
  description: 'v0.8.0 first test build: the Elbe under the Köhlbrandbrücke shows as meadow in Modern (the far-ground plane 4 m under the road covers water that lies deeper) and the ships stand on it – fix it for every bridge over deep water, rebuild the test build with smoke tests and gates, then an independent check of the delivered archives, a fix round only on blocker/high/medium findings and a focused re-check',
  phases: [
    { title: 'Korrektur', detail: 'FIX-WASSER: far ground below the loaded water, bridges and boats, new test build, smoke tests, gates' },
    { title: 'Prüfung', detail: 'QA-WASSER: independent check of the delivered archives, the water at bridges, the start, Arcade identity' },
    { title: 'Nacharbeit', detail: 'FIX-WASSER-R: only on blocker/high/medium findings' },
    { title: 'Nachprüfung', detail: 'NACH-WASSER: focused re-check, only if the fix round changed the game' },
  ],
}
