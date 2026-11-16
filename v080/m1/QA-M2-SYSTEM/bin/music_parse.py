#!/usr/bin/env python3
"""Condenses a qa_music_flow.gd log: per stage the race piece that played, the ending variant, the stingers, and what
played on the screens between stages and on the title. Usage: music_parse.py <log>"""
import re
import sys

lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
pat = re.compile(r"^\s*([\d.]+) MUSIK screen=(\S*) (.*)$")
seq = []
for ln in lines:
    m = pat.match(ln)
    if m:
        t, scr, rest = float(m.group(1)), m.group(2), m.group(3)
        kv = dict(re.findall(r"(\w+)=(\[[^\]]*\]|\{[^}]*\}|\S+)", rest))
        seq.append((t, scr, kv))
    elif "ETAPPE" in ln or "RENNEN" in ln or "ENDE" in ln or "PROFIL" in ln or "FEHLER" in ln:
        print(ln.strip())
print("--- Zustandswechsel (Bildschirm, Kontext, Phase, Rotation, spielt, Stinger, Schluss) ---")
last = None
for t, scr, kv in seq:
    key = (scr, kv.get("ctx"), kv.get("phase"), kv.get("idx"), kv.get("playing"), kv.get("sting"), kv.get("ending"), kv.get("stingers"))
    if key != last:
        print("%7.1f %-14s ctx=%-9s phase=%-2s idx=%-3s playing=%-55s sting=%-28s ending=%s stingers=%s" % (
            t, scr, kv.get("ctx"), kv.get("phase"), kv.get("idx"), kv.get("playing"), kv.get("sting", ""), kv.get("ending", ""), kv.get("stingers")))
        last = key
