#!/usr/bin/env python3
"""Prints parts of the merged game configuration (integration helper, not part of the repository)."""
import json
import sys

cfg = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "config/game_config.json"))
gfx = cfg["graphics"]
print(json.dumps(gfx["modern"], indent=1))
print("watchdog", gfx["watchdog"])
for key, val in gfx["levels"].items():
    print("levels", key, len(val) if isinstance(val, list) else val)
print("benchmark", json.dumps(gfx["benchmark"])[:700])
print("budgets", json.dumps(gfx["budgets"]))
print("force_mode", repr(gfx["force_mode"]))
print("audio.profile", repr(cfg["audio"].get("profile")))
print("audio.modern", json.dumps(cfg["audio"]["modern"])[:900])
