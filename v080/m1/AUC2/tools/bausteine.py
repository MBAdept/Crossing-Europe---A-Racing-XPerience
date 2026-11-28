import os, sys, subprocess, wave
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix/tools/audio/qc")
import numpy as np, qc_lib
SR = 44100
amb, trf, out = sys.argv[1:4]
order = [("Betten (je 8 s)", amb, ["breeze", "leaves", "crickets", "cicadas", "city_day", "city_night", "water", "tunnel_fans", "hum", "rain"], 8.0),
         ("Rufe", amb, sorted(f[:-4] for f in os.listdir(amb) if f.endswith(".wav") and not f[:-4] in ("breeze", "leaves", "crickets", "cicadas", "city_day", "city_night", "water", "tunnel_fans", "hum", "rain")), None),
         ("Verkehr: Schleifen (je 4 s, Bezugstempo)", trf, ["car_petrol", "car_petrol_b", "car_diesel", "car_diesel_b", "car_sport", "car_ev", "van_diesel", "truck_diesel", "bus_diesel", "tires_car", "tires_car_wet", "tires_truck", "tires_truck_wet", "air"], 4.0),
         ("Martinshorn (6 s)", trf, ["siren"], 6.0),
         ("Hupen und Luftstöße", trf, ["horn_car_a", "horn_car_b", "horn_small", "horn_truck", "whoosh_car_a", "whoosh_car_b", "whoosh_truck_a", "whoosh_truck_b"], None)]
parts, lines, t = [], [], 0.0
gap = np.zeros((int(0.7 * SR), 2))
for title, d, ids, secs in order:
    lines.append(f"\n{title}")
    for i in ids:
        x, sr = qc_lib.read_audio(os.path.join(d, i + ".wav"))
        if x.shape[1] == 1:
            x = np.repeat(x, 2, axis=1) * 0.707
        if secs:
            x = x[:int(secs * SR)]
        # loudness-matched for listening: beds and loops at -23 LUFS, one-shots at -20 LUFS momentary
        target = -23.0 if secs else -20.0
        cur = qc_lib.integrated_lufs(x, SR) if secs else qc_lib.momentary_max(x, SR)
        x = x * 10 ** ((target - cur) / 20)
        lines.append(f"{int(t // 60)}:{t % 60:04.1f}  {i}")
        parts += [x, gap]
        t += len(x) / SR + 0.7
y = np.concatenate(parts)
y = y / max(1.0, np.max(np.abs(y)) / 0.89)
tmp = os.path.join(out, "_b.wav")
with wave.open(tmp, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(np.clip(np.rint(y * 32767), -32768, 32767).astype("<i2").tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k", os.path.join(out, "klangbausteine.mp3")], check=True)
os.remove(tmp)
open(os.path.join(out, "klangbausteine.txt"), "w", encoding="utf-8").write("Alle neuen Klänge einzeln, auf gleiche Lautheit gebracht (Betten/Schleifen -23 LUFS, Einmalklänge -20 LUFS momentan) – im Spiel sind sie viel leiser und gemischt.\n" + "\n".join(lines) + "\n")
print(f"{t:.0f} s, {len(lines)} Zeilen")
