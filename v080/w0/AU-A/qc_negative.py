"""Negative demonstration for tools/audio/qc/audio_qc.py: a copy of the placeholders with deliberate defects must fail.

Defects (each in its own folder, so the report names them one by one):
  vehicle   the loop drifts by 0.3 of full scale from its first to its last sample (a step at the seam)
  sfx       40 samples at full scale (clipping, true peak above -1 dBTP)
  ui        the manifest claims another loudness and frame count than the file has
  traffic   a file the manifest does not know
  music     the manifest's loop end lies outside the file
"""
import json
import os
import shutil
import struct
import subprocess
import sys

ROOT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3"
W = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A"
BAD = os.path.join(W, "qc_bad")
shutil.rmtree(BAD, ignore_errors=True)
shutil.copytree(os.path.join(ROOT, "assets/audio/modern"), BAD)


def patch_wav(path, fn):
    data = bytearray(open(path, "rb").read())
    k = data.find(b"data")
    size = struct.unpack("<I", data[k + 4:k + 8])[0]
    start = k + 8
    n = size // 2
    samples = list(struct.unpack("<%dh" % n, data[start:start + size]))
    fn(samples)
    data[start:start + size] = struct.pack("<%dh" % n, *samples)
    open(path, "wb").write(bytes(data))


def seam(samples):
    # a slow drift over the whole file: smooth everywhere, but the end no longer meets the beginning
    n = len(samples)
    for i in range(n):
        samples[i] = max(-32768, min(32767, samples[i] + int(9830 * (i // 2) / (n // 2))))


def clip(samples):
    for i in range(2000, 2080):
        samples[i] = 32767


patch_wav(os.path.join(BAD, "vehicle", "platzhalter_loop.wav"), seam)
patch_wav(os.path.join(BAD, "sfx", "platzhalter_hit.wav"), clip)
m = json.load(open(os.path.join(BAD, "ui", "manifest.json"), encoding="utf-8"))
e = m["sounds"]["platzhalter_blip"]
e["lufs"] = e["lufs"] + 3.0
e["frames"] = e["frames"] + 100
json.dump(m, open(os.path.join(BAD, "ui", "manifest.json"), "w", encoding="utf-8"), indent="\t", ensure_ascii=False)
shutil.copy(os.path.join(BAD, "traffic", "platzhalter_loop.wav"), os.path.join(BAD, "traffic", "vergessen.wav"))
m = json.load(open(os.path.join(BAD, "music", "manifest.json"), encoding="utf-8"))
e = m["sounds"]["platzhalter_takt"]
e["loop"] = [0, e["frames"] + 5000]
json.dump(m, open(os.path.join(BAD, "music", "manifest.json"), "w", encoding="utf-8"), indent="\t", ensure_ascii=False)

r = subprocess.run([sys.executable, os.path.join(ROOT, "tools/audio/qc/audio_qc.py"), "--root", BAD, "--no-import",
                    "--json", os.path.join(W, "qc_bad_report.json")], capture_output=True, text=True)
print(r.stdout)
print(r.stderr)
print("EXIT", r.returncode)
