"""Writes the title remaster's .import and manifest entry through the generator's own register() (no render)."""
import os
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_158edd89-079-1"
sys.path.insert(0, os.path.join(WT, "tools/audio/music"))
os.chdir(WT)
import title_remaster as tr  # noqa: E402

man = tr.ml.Manifest("music", None)
e = tr.register(man, True)
man.save()
print(e)
