#!/usr/bin/env python3
"""Fill repl.json for assemble.py from the measured files that exist."""
import json, os, re
F = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5'
repl = {}
repl['PERF_U1_TABELLE2'] = ('Siehe Abschnitt 1.4 (dieselben Läufe, gemessen): Commit-Maximum Basis 17,77 ms / FIX-R5 4,13 ms bei '
                            'Lastspitzen der unberührten Simulation von 452 / 226 ms; headless (Minimum aus 3) ≤ 0,25 ms je Tunnelstück.')
repl['PERF_U1_TABELLE'] = open(F + '/perf_u1_table.md', encoding='utf-8').read().strip()
if os.path.exists(F + '/perf_kh_table.md'):
    repl['PERF_KH_TABELLE'] = open(F + '/perf_kh_table.md', encoding='utf-8').read().strip()
if os.path.exists(F + '/perf_kh_lesart.md'):
    repl['PERF_KH_LESART'] = open(F + '/perf_kh_lesart.md', encoding='utf-8').read().strip()
if os.path.exists(F + '/perf_kurz.txt'):
    repl['PERF_KURZ'] = open(F + '/perf_kurz.txt', encoding='utf-8').read().strip()
if os.path.exists(F + '/wald.txt'):
    repl['WALD_ERGEBNIS'] = open(F + '/wald.txt', encoding='utf-8').read().strip()
if os.path.exists(F + '/gates_kurz.txt'):
    repl['GATES_KURZ'] = open(F + '/gates_kurz.txt', encoding='utf-8').read().strip()
json.dump(repl, open(F + '/repl.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(sorted(repl))
