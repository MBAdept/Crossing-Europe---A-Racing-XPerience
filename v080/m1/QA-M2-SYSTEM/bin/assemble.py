#!/usr/bin/env python3
"""Assembles deliver/QA-M2-SYSTEM/bericht.md from the bericht_teil_*.md parts and the placeholder files teil_*.md."""
import os
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM'
D = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-M2-SYSTEM'


def rd(name, default=None):
    p = os.path.join(S, name)
    if os.path.exists(p):
        return open(p).read().rstrip('\n')
    if default is None:
        raise SystemExit('fehlt: ' + name)
    return default


order = ['bericht_teil_kopf.md', 'bericht_teil_zusammenfassung.md', 'bericht_teil_befunde.md', 'bericht_teil_arcade.md',
         'bericht_teil_klang.md', 'bericht_teil_tyrewind.md', 'bericht_teil_modelle.md', 'bericht_teil_mutation.md',
         'bericht_teil_robust.md', 'bericht_teil_tore.md', 'bericht_teil_vertrag.md', 'bericht_teil_ok.md',
         'bericht_teil_naechste.md']
doc = '\n\n'.join(rd(n) for n in order) + '\n'
quit_part = rd('bericht_teil_quit.md').replace('⟨QUIT2⟩', rd('teil_quit2.md'))
repl = {
    '⟨QUIT⟩': quit_part,
    '⟨SOAK⟩': rd('bericht_teil_soak.md'),
    '⟨BUILDS⟩': rd('bericht_teil_builds.md'),
    '⟨GOLDEN⟩': rd('teil_golden.md'),
    '⟨INSTANZEN⟩': rd('teil_instanzen.md'),
    '⟨PROPSGATE⟩': rd('teil_propsgate.md'),
    '⟨WALD⟩': rd('teil_wald.md'),
    '⟨MODERNCHECK⟩': rd('teil_moderncheck.md'),
    '⟨QUITKURZ⟩': rd('teil_quitkurz.md'),
}
for k, v in repl.items():
    doc = doc.replace(k, v)
left = [t for t in ('⟨', '⟩') if t in doc]
os.makedirs(D, exist_ok=True)
open(os.path.join(D, 'bericht.md'), 'w').write(doc)
print('bericht.md', len(doc), 'Zeichen', 'OFFENE PLATZHALTER' if left else 'vollständig')
