#!/usr/bin/env python3
"""Edits jobs4a.txt safely while a queue runs: applies replacements to the lines AFTER the running job, writes the
result in place to the path AND to every running queue4.sh's open job file (/proc/<pid>/fd/0), checking that the
prefix up to the running job stays byte-identical.

usage: edit_jobs.py <running job name> '<old>' '<new>' ['<old>' '<new>' ...]"""
import glob
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN"
P = S + "/jobs4a.txt"
running = sys.argv[1]
reps = list(zip(sys.argv[2::2], sys.argv[3::2]))
txt = open(P).read()
lines = txt.splitlines()
k = [l.split("|")[0] for l in lines].index(running)
rest = "\n".join(lines[k + 1:])
for a, b in reps:
    assert a in rest, a
    rest = rest.replace(a, b)
new = "\n".join(lines[:k + 1]) + "\n" + rest + "\n"
prefix = "\n".join(lines[:k + 1]) + "\n"
targets = [P]
for fd in glob.glob("/proc/[0-9]*/fd/0"):
    try:
        if "jobs4a.txt" in os.readlink(fd):
            targets.append(fd)
    except OSError:
        pass
for t in targets:
    with open(t, "r+") as f:
        old = f.read()
        assert old.startswith(prefix), "prefix differs in " + t
        f.seek(0)
        f.write(new)
        f.truncate()
    print("written", t)
print([l.split("|")[0] for l in new.splitlines()])
