"""AU-C2 previews: MP3 per scene of the review drive, one round trip of all scenes with spoken-free gaps and a text
of the times, a collection of the single sounds (beds 8 s each, calls, traffic one-shots, siren), spectrograms."""
import json, os, subprocess, sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix/tools/audio/qc")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, qc_lib, media
SR = 44100
drive, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
def mp3(path, x):
    tmp = path + ".tmp.wav"
    import wave
    y = np.clip(np.rint(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(y.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k", path], check=True)
    os.remove(tmp)
scenes = json.load(open(os.path.join(drive, "szenen.json")))
parts, lines, t = [], [], 0.0
gap = np.zeros((int(0.8 * SR), 2))
for i, s in enumerate(scenes):
    x, sr = qc_lib.read_audio(s["file"])
    x = x[int(0.2 * sr):]
    name = f"{i + 1:02d}_{os.path.basename(s['file'])[:-4]}"
    mp3(os.path.join(out, name + ".mp3"), x)
    media.spec(os.path.join(out, name + "_spektrogramm.png"), x, title=s["title"])
    lines.append(f"{int(t // 60)}:{t % 60:04.1f}  {s['title']}")
    parts += [x, gap]
    t += len(x) / SR + 0.8
mp3(os.path.join(out, "rundfahrt_alle_szenen.mp3"), np.concatenate(parts))
with open(os.path.join(out, "rundfahrt_alle_szenen.txt"), "w", encoding="utf-8") as fh:
    fh.write("Rundfahrt AU-C2 (Spielmix: Auto, Verkehr, Ambiente, Raumklang; ohne Musik). Zeiten:\n" + "\n".join(lines) + "\n")
print("\n".join(lines))
