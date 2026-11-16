#!/usr/bin/env python3
"""Assemble deliver/FIX-R5/bericht.md from the parts; placeholders are filled from repl.json (key -> text)."""
import json, os
F = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5'
OUT = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-R5/bericht.md'
head = open(F + '/bericht_head.md', encoding='utf-8').read()
parts = [head, open(F + '/bericht_kurz.md', encoding='utf-8').read(), '\n',
         open(F + '/bericht_body.md', encoding='utf-8').read(), '\n',
         open(F + '/bericht_mid.md', encoding='utf-8').read(), '\n',
         open(F + '/bericht_gates.md', encoding='utf-8').read(), '\n',
         open(F + '/bericht_perf.md', encoding='utf-8').read(), '\n',
         '''## 7. Commits (Branch `worktree-wf_fd1de4ee-28b-6`, gepusht nach `origin/wip/v080-fix-r5`)

| Commit | Inhalt |
|---|---|
| `7e575e6` | Portal auf Renderlayer 2 (`tunnel.gd` `PORTAL_LAYERS`); Tests: Brückenlampen, 56 Seile als Zahl, `night_albedo`/`emit_energy` auf null geprüft, Rig ohne `set_zone`, Portal-Layer; genauer Netzlauf |
| `7610875` | Netzlauf ohne die falsche Pfeilerregel – 0 Mängel; Doku |
| `ea5d8f7` | `tunnel_state["light"]` für R4s Fahrbahn in der Röhre; Test; Doku |
| `80b8141` | `tunnel_state["exit_z"]` für R4s Belichtungsfläche; Test; Doku |

Geänderte Dateien (`git diff --stat 5558bdc..80b8141`): `scripts/race3d/builders/tunnel.gd` (+30), `tests/unit/race3d/test_tunnel.gd`
(+58), `tests/unit/race3d/test_bridge.gd` (+46), `tests/race3d/render/check_tunnel_bridge.gd` (+246/−45),
`docs/renderer-modern-tunnel-bruecken.md`, `docs/renderer-modern.md` (§15) – alles R5-Eigentum.

''',
         open(F + '/bericht_notes.md', encoding='utf-8').read()]
text = ''.join(parts)
repl = json.load(open(F + '/repl.json', encoding='utf-8')) if os.path.exists(F + '/repl.json') else {}
for k, v in repl.items():
    text = text.replace(k, v)
open(OUT, 'w', encoding='utf-8').write(text)
left = [k for k in ['GATES_KURZ', 'PERF_U1_TABELLE', 'PERF_KH_TABELLE', 'PERF_KH_LESART', 'PERF_U1_TABELLE2', 'WALD_ERGEBNIS', 'PERF_KURZ'] if k in text]
print('written', len(text), 'chars; open placeholders:', left)
