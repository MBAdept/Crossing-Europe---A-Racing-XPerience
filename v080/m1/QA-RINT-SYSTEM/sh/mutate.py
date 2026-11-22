#!/usr/bin/env python3
"""Mutation helper for QA-RINT-SYSTEM.
  mutate.py apply <relpath> <old> <new>   replace exactly one occurrence in S/mut/<relpath>
  mutate.py restore <relpath>             copy the file back from the pristine worktree
  mutate.py diff <relpath>                show the difference to the worktree
"""
import shutil
import subprocess
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM"
W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3"

cmd, rel = sys.argv[1], sys.argv[2]
dst = f"{S}/mut/{rel}"
if cmd == "apply":
    old, new = sys.argv[3], sys.argv[4]
    txt = open(dst, encoding="utf-8").read()
    n = txt.count(old)
    if n != 1:
        sys.exit(f"MUTATE: {n} occurrences of the old text in {rel} – nothing changed")
    open(dst, "w", encoding="utf-8").write(txt.replace(old, new))
    print(f"MUTATE applied to {rel}")
elif cmd == "restore":
    shutil.copy2(f"{W}/{rel}", dst)
    print(f"MUTATE restored {rel}")
elif cmd == "diff":
    subprocess.run(["diff", "-u", f"{W}/{rel}", dst])
