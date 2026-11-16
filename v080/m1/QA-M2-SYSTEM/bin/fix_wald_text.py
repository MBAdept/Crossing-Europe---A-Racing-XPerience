#!/usr/bin/env python3
"""After run 3 of the forest check (OK after 2945 s): update M2S-01, the gate row and the next-steps note."""
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM'


def sub(path, old, new):
    p = S + '/' + path
    s = open(p).read()
    if old not in s:
        raise SystemExit('nicht gefunden in %s: %s' % (path, old[:60]))
    open(p, 'w').write(s.replace(old, new, 1))


sub('bericht_teil_befunde.md',
    'Die Produktregel (Puffer hält im Wald bei „Hoch“) ist hier **nicht unabhängig bestätigt** (M2ZS1 meldete OK).',
    'Die Produktregel selbst hält: Lauf 3 allein mit `RENDER_CHECK_TIMEOUT=3000` bestand nach **2 945 s** (49 min, '
    'Last 20–33; ganze Szene ≤ 142 Instanz-Uniforms, Fahrzeuge ≤ 127 von 128) – mit dem Standard-Zeitlimit wäre das Tor '
    'rot gewesen, und 55 s mehr Last hätten auch das erhöhte Limit gerissen.')
sub('bericht_teil_befunde.md',
    'Lauf 2 mit `RENDER_CHECK_TIMEOUT=3000`, Last 20–22: nach 21 min ohne Ergebnis abgebrochen (gemessen).',
    'Lauf 2 mit `RENDER_CHECK_TIMEOUT=3000`, Last 20–22: nach 21 min ohne Ergebnis abgebrochen; Lauf 3 (15.11.) '
    '`RENDER-CHECK-DATEI …wald.gd OK (Exit 0, 2945 s)` (`q_wald.log`, gemessen).')
sub('bericht_teil_tore.md', '**16 von 17 Dateien OK**', '**17 von 17 Dateien OK** (eine erst mit erhöhtem Zeitlimit)')
sub('bericht_teil_naechste.md',
    '1. **Waldprüfung** (`check_instance_budget_wald`) nach der Reparatur von M2S-01 auf einer ruhigen Maschine laufen lassen – die Produktregel (Puffer hält im Wald bei „Hoch“) ist in dieser Prüfung unbelegt.',
    '1. **Waldprüfung** (`check_instance_budget_wald`): bis M2S-01 repariert ist, nur mit `RENDER_CHECK_TIMEOUT=3600` und allein laufen lassen (hier 2 945 s bei Last 20–33).')
print('ok')
