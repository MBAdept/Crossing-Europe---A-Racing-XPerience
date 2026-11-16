export const meta = {
  name: 'v080-m2-zusammenbau-2',
  description: 'v0.8.0 push M2, second assembly RINT-M2: merge the reviewed and fixed wave-3 packages (R4 light/night/weather, R5 tunnels/bridges/water, R6 fuel station/border/city/start-finish/radar) and the first city buildings (AS5aR1) onto FIX-M2, commit contract §11.3, resolve the integration items of the reviews, then independent QA with two lenses, one fix round and a focused re-check',
  phases: [
    { title: 'Zusammenbau', detail: 'RINT-M2: four merges onto FIX-M2, contract §11.3, lead items 1–12, A/B pictures, clips, gates, builds' },
    { title: 'Prüfung', detail: 'QA-RINT-BILD (picture in every condition, fairness, performance) and QA-RINT-SYSTEM (Arcade identity, budgets, robustness, builds)' },
    { title: 'Nacharbeit', detail: 'FIX-RINT: confirmed blocker/high/medium findings, gates again' },
    { title: 'Nachprüfung', detail: 'NACH-RINT: focused re-check of the fix round' },
  ],
}
