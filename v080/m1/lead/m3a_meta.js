export const meta = {
  name: 'v080-m2-welle3',
  description: 'v0.8.0 push M2, wave 3: three renderer packages side by side on the merged M2 head – R4 light, night and weather; R5 tunnels, bridges, water and banks; R6 fuel station, border, city street furniture, start/finish, radar – each with an independent review, a fix round on blocker/high/medium findings and a focused re-check',
  phases: [
    { title: 'Bau', detail: 'R4 (light, night, weather), R5 (tunnel, bridge, water, banks) and R6 (station, border, city, gantry, radar) in their own worktrees' },
    { title: 'Prüfung', detail: 'QA-R4, QA-R5, QA-R6: independent review of each package against Arcade, the contract and fairness' },
    { title: 'Nacharbeit', detail: 'FIX-R4 / FIX-R5 / FIX-R6: only on blocker/high/medium findings' },
    { title: 'Nachprüfung', detail: 'NACH-R4 / NACH-R5 / NACH-R6: focused re-check, only if the fix round changed the game' },
  ],
}
