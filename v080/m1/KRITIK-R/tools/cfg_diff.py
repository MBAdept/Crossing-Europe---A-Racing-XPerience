#!/usr/bin/env python3
"""KRITIK-R: which configuration keys changed (flattened), and mischung.json values old vs new."""
import json
import subprocess
import sys

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"


def flat(d, p=""):
    out = {}
    if isinstance(d, dict):
        for k, v in d.items():
            out.update(flat(v, f"{p}.{k}" if p else k))
    else:
        out[p] = d
    return out


a = flat(json.load(open(f"{K}/res/cfg_old.json")))
b = flat(json.load(open(f"{K}/res/cfg_new.json")))
changed = sorted(k for k in set(a) | set(b) if a.get(k, "<fehlt>") != b.get(k, "<fehlt>"))
outside = [k for k in changed if not (k.startswith("audio.modern.") or k == "audio._doc_modern")]
print(f"{len(changed)} geänderte Schlüssel, außerhalb audio.modern / audio._doc_modern: {outside}")
for k in changed:
    if k == "audio._doc_modern":
        continue
    print(f"  {k}: {a.get(k, '<fehlt>')} -> {b.get(k, '<fehlt>')}")
for rev in ("4209268f0bad80beb9abc2609d92a74cd7279db1", "3d2e6e128d01e53e30ef5538bd58f42888827cc1"):
    s = subprocess.run(["git", "-C", "/home/user/crossing-europe---a-racing-xperience", "show", f"{rev}:tools/audio/music/mischung.json"],
                       capture_output=True, text=True).stdout
    m = json.loads(s)
    print(rev[:7], {k: v for k, v in m.items() if not k.startswith("_")})
