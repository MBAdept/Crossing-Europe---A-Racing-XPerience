"""AU-C1 media helpers: spectrogram PNGs and MP3s for review (scratch, not in the repo).

usage:
  media.py sheet OUT.png WAV [WAV ...]          stacked spectrograms of several files (one row each)
  media.py spec OUT.png WAV [--marks t:label,…] [--title T]
  media.py mp3 OUT.mp3 WAV                      MP3 192 kbit/s (stereo)
"""
import os
import subprocess
import sys

ROOT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix"
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "qc"))
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
except OSError:
    FONT = None
SR = 44100


def read(path):
    x, sr = qc_lib.read_audio(path)
    assert sr == SR, (path, sr)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return x


def spec_image(x, width=1400, rows=230, floor_db=75.0, hi=None):
    mono = x.mean(axis=1)
    n, hop = 4096, max(256, len(mono) // (width * 2))
    if len(mono) < n + hop:
        mono = np.concatenate([mono, np.zeros(n + hop)])
    frames = np.array([mono[i:i + n] * np.hanning(n) for i in range(0, len(mono) - n, hop)])
    S = 20 * np.log10(np.abs(np.fft.rfft(frames, axis=1)).T + 1e-9)
    f = np.fft.rfftfreq(n, 1 / SR)
    fl = np.geomspace(25, 16000, rows)
    img = S[np.clip(np.searchsorted(f, fl), 0, len(f) - 1)][::-1]
    if hi is None:
        hi = np.percentile(img, 99.5)
    img = np.clip((img - (hi - floor_db)) / floor_db, 0, 1)
    rgb = np.stack([img ** 0.6 * 255, img ** 1.4 * 225, (1 - img) * 70 + img * 30], axis=2).astype(np.uint8)
    return Image.fromarray(rgb).resize((width, rows * 2)), hi


def freq_axis(dr, x0, y0, h):
    for fr in (50, 100, 200, 500, 1000, 2000, 5000, 10000):
        yy = y0 + h - int(np.log(fr / 25) / np.log(16000 / 25) * h)
        dr.line([(x0, yy), (x0 + 8, yy)], fill=(200, 200, 200))
        dr.text((x0 + 10, yy - 7), f"{fr // 1000}k" if fr >= 1000 else str(fr), fill=(200, 200, 200), font=FONT)


def spec(out, path_or_x, marks=(), title="", width=1400):
    x = read(path_or_x) if isinstance(path_or_x, str) else path_or_x
    im, _ = spec_image(x, width)
    rows2 = im.size[1]
    canvas = Image.new("RGB", (width, rows2 + 40), (20, 20, 28))
    canvas.paste(im, (0, 40))
    dr = ImageDraw.Draw(canvas)
    dr.text((6, 4), title, fill=(240, 240, 240), font=FONT)
    dr.text((6, 20), "Frequenz logarithmisch 25 Hz (unten) bis 16 kHz (oben); Zeit von links nach rechts", fill=(170, 170, 170), font=FONT)
    freq_axis(dr, 0, 40, rows2)
    total = len(x) / SR
    for k, (t, lab) in enumerate(marks):
        xx = int(t / total * width)
        dr.line([(xx, 40), (xx, rows2 + 40)], fill=(255, 255, 255), width=1)
        dr.text((xx + 3, 44 + 16 * (k % 3)), lab, fill=(255, 255, 255), font=FONT)
    canvas.save(out)


def sheet(out, paths, width=1200, rows=120):
    ims = []
    his = []
    for p in paths:
        x = read(p)
        im, hi = spec_image(x, width, rows)
        ims.append((os.path.basename(p), im, qc_lib.integrated_lufs(x, SR)))
        his.append(hi)
    h = sum(im.size[1] + 22 for _n, im, _l in ims)
    canvas = Image.new("RGB", (width, h), (20, 20, 28))
    dr = ImageDraw.Draw(canvas)
    y = 0
    for name, im, lufs in ims:
        dr.text((6, y + 4), f"{name}   {lufs:.1f} LUFS", fill=(240, 240, 240), font=FONT)
        canvas.paste(im, (0, y + 22))
        freq_axis(dr, 0, y + 22, im.size[1])
        y += im.size[1] + 22
    canvas.save(out)


def mp3(out, path_or_x, gain_db=0.0):
    x = read(path_or_x) if isinstance(path_or_x, str) else path_or_x
    x = (x * 10 ** (gain_db / 20.0)).astype(np.float32)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", "192k", out], input=x.tobytes(), check=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "sheet":
        sheet(sys.argv[2], sys.argv[3:])
    elif cmd == "spec":
        marks = []
        title = ""
        args = sys.argv[4:]
        for i, a in enumerate(args):
            if a == "--marks":
                for m in args[i + 1].split(","):
                    t, lab = m.split(":", 1)
                    marks.append((float(t), lab))
            if a == "--title":
                title = args[i + 1]
        spec(sys.argv[2], sys.argv[3], marks, title)
    elif cmd == "mp3":
        mp3(sys.argv[2], sys.argv[3])
