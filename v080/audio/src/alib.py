"""Analysis helpers for the v0.8.0 audio study (numpy only). Reuses the DSP of tools/audio/music_synth.py."""
from __future__ import annotations
import os, sys, subprocess, shutil, math
import numpy as np

# The prototypes import the repo's audio tools read-only (no bytecode is written into the repo). CE_PROJ may point to
# a scratch copy of the project; WORK is the study's working directory (out/, bank3/, deliver/).
sys.dont_write_bytecode = True
PROJ = os.environ.get("CE_PROJ", "/home/user/crossing-europe---a-racing-xperience")
WORK = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(PROJ, "tools", "audio"))


def db(x):
    return 20.0 * np.log10(np.maximum(np.abs(x), 1e-12))


def read_audio(path: str, sr: int = 48000, ch: int = 2) -> np.ndarray:
    r = subprocess.run([shutil.which("ffmpeg"), "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", str(ch),
                        "-ar", str(sr), "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, "<f4").reshape(-1, ch).astype(np.float64)


def write_wav(path: str, x: np.ndarray, sr: int, bits: int = 16) -> None:
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    ch = x.shape[1]
    if bits == 32:
        data = x.astype("<f4").tobytes(); fmt, bps = 3, 4
    else:
        data = (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes(); fmt, bps = 1, 2
    hdr = b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVEfmt " + (16).to_bytes(4, "little")
    hdr += fmt.to_bytes(2, "little") + ch.to_bytes(2, "little") + sr.to_bytes(4, "little")
    hdr += (sr * ch * bps).to_bytes(4, "little") + (ch * bps).to_bytes(2, "little") + (8 * bps).to_bytes(2, "little")
    with open(path, "wb") as fh:
        fh.write(hdr + b"data" + len(data).to_bytes(4, "little") + data)


# --- ITU-R BS.1770 K weighting (any sample rate; biquads derived from the analog prototypes) ---------------------
def _biquad(x, b, a):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b; a1, a2 = a
    # vectorised via lfilter-like recursion in chunks is slow in python; use frequency domain instead
    raise NotImplementedError


def k_weight(x: np.ndarray, sr: int) -> np.ndarray:
    """K weighting in the frequency domain (shelf +4 dB above ~1.5 kHz, RLB high-pass 38 Hz)."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    s = 1j * f
    # stage 1: high shelf (analog prototype of BS.1770: f0 = 1681.97 Hz, G = 3.99984 dB, Q = 0.7072)
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = s / f0
    Vh = 10.0 ** (G / 20.0); Vb = Vh ** 0.4996667741545416
    H1 = (Vh * K * K + Vb * K / Q + 1.0) / (K * K + K / Q + 1.0)
    # stage 2: high-pass (f0 = 38.135 Hz, Q = 0.5003)
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = s / f0
    H2 = (K * K) / (K * K + K / Q + 1.0)
    H = H1 * H2
    out = np.fft.irfft(np.fft.rfft(x, axis=0) * H[:, None], n, axis=0)
    return out


def a_weight_gain(f):
    f = np.maximum(f, 1e-3)
    f2 = f * f
    ra = (12194.0 ** 2 * f2 * f2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194.0 ** 2))
    return ra * 10 ** (2.0 / 20.0)


def block_power(xk: np.ndarray, sr: int, win_s: float, hop_s: float) -> np.ndarray:
    w = int(round(win_s * sr)); h = int(round(hop_s * sr))
    p = np.sum(xk * xk, axis=1) if xk.ndim == 2 else xk * xk
    c = np.concatenate([[0.0], np.cumsum(p)])
    idx = np.arange(0, len(p) - w + 1, h)
    if len(idx) == 0:
        return np.array([np.mean(p)])
    return (c[idx + w] - c[idx]) / w


def lufs_of_power(p):
    return -0.691 + 10.0 * np.log10(np.maximum(p, 1e-12))


def integrated_lufs(x: np.ndarray, sr: int, xk=None) -> float:
    xk = k_weight(x, sr) if xk is None else xk
    p = block_power(xk, sr, 0.4, 0.1)
    l = lufs_of_power(p)
    keep = l > -70.0
    if not np.any(keep):
        return -70.0
    rel = lufs_of_power(np.mean(p[keep])) - 10.0
    keep2 = keep & (l > rel)
    return float(lufs_of_power(np.mean(p[keep2]))) if np.any(keep2) else -70.0


def short_term(x: np.ndarray, sr: int, win_s: float = 3.0, hop_s: float = 0.1, xk=None):
    xk = k_weight(x, sr) if xk is None else xk
    p = block_power(xk, sr, win_s, hop_s)
    return lufs_of_power(p)


def loudness_range(x: np.ndarray, sr: int, xk=None) -> float:
    st = short_term(x, sr, 3.0, 1.0, xk)
    st = st[st > -70.0]
    if len(st) < 2:
        return 0.0
    rel = lufs_of_power(np.mean(10 ** ((st + 0.691) / 10.0))) - 20.0
    st = st[st > rel]
    if len(st) < 2:
        return 0.0
    return float(np.percentile(st, 95) - np.percentile(st, 10))


def true_peak_db(x: np.ndarray, os_: int = 4) -> float:
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    pk = 0.0
    n = len(x)
    for c in range(x.shape[1]):
        for a in range(0, n, 1 << 18):
            seg = x[max(0, a - 64):min(n, a + (1 << 18) + 64), c]
            X = np.fft.rfft(seg)
            m = len(seg) * os_
            Y = np.zeros(m // 2 + 1, complex)
            Y[:len(X)] = X
            y = np.fft.irfft(Y, m) * os_
            pk = max(pk, float(np.max(np.abs(y))))
    return float(db(pk))


def third_octave(x: np.ndarray, sr: int, fmin: float = 25.0, fmax: float = 16000.0):
    """Power per 1/3-octave band (dB, mono sum of channel powers), centre frequencies."""
    x = np.asarray(x, np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = len(x)
    win = 1 << 14
    while win > n and win > 256:
        win >>= 1
    hop = win // 2
    w = np.hanning(win)
    acc = np.zeros(win // 2 + 1)
    cnt = 0
    for c in range(x.shape[1]):
        for a in range(0, n - win + 1, hop):
            acc += np.abs(np.fft.rfft(x[a:a + win, c] * w)) ** 2
            cnt += 1
    acc /= max(cnt, 1) * np.sum(w * w) * 0.5 * x.shape[1] / x.shape[1]
    f = np.fft.rfftfreq(win, 1.0 / sr)
    centres = []
    vals = []
    k = round(3 * math.log2(fmin / 1000.0))
    while True:
        fc = 1000.0 * 2 ** (k / 3.0)
        if fc > fmax * 1.01 or fc * 2 ** (1 / 6) > sr / 2:
            break
        lo, hi = fc * 2 ** (-1 / 6), fc * 2 ** (1 / 6)
        m = (f >= lo) & (f < hi)
        centres.append(fc)
        vals.append(10 * np.log10(max(np.sum(acc[m]), 1e-20)))
        k += 1
    return np.array(centres), np.array(vals)


def crest_db(x: np.ndarray) -> float:
    x = np.asarray(x, np.float64)
    return float(db(np.max(np.abs(x))) - 10 * np.log10(max(np.mean(x * x), 1e-20)))


def stereo_corr(x: np.ndarray) -> float:
    l, r = x[:, 0], x[:, 1]
    d = math.sqrt(float(np.sum(l * l) * np.sum(r * r)))
    return float(np.sum(l * r) / d) if d > 0 else 1.0


def side_mid_db(x: np.ndarray) -> float:
    m = 0.5 * (x[:, 0] + x[:, 1]); s = 0.5 * (x[:, 0] - x[:, 1])
    return float(10 * np.log10(max(np.mean(s * s), 1e-20) / max(np.mean(m * m), 1e-20)))


def band_env(x: np.ndarray, sr: int, lo: float, hi: float, win_s: float = 0.02):
    """RMS envelope (dB) of a band, hop = win."""
    x = np.asarray(x, np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    X[(f < lo) | (f >= hi)] = 0.0
    y = np.fft.irfft(X, len(x))
    w = int(win_s * sr)
    m = len(y) // w
    e = np.sqrt(np.mean(y[:m * w].reshape(m, w) ** 2, axis=1))
    return 20 * np.log10(np.maximum(e, 1e-9))


def spectral_centroid(x: np.ndarray, sr: int, win: int = 4096, hop: int = 2048):
    x = np.asarray(x, np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    w = np.hanning(win)
    f = np.fft.rfftfreq(win, 1.0 / sr)
    out = []
    for a in range(0, len(x) - win + 1, hop):
        S = np.abs(np.fft.rfft(x[a:a + win] * w)) ** 2
        out.append(np.sum(f * S) / max(np.sum(S), 1e-20))
    return np.array(out)


def spectral_flux(x: np.ndarray, sr: int, win: int = 2048, hop: int = 1024):
    """Mean frame-to-frame change of the normalised log band spectrum (dB): 0 = perfectly static timbre."""
    x = np.asarray(x, np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    w = np.hanning(win)
    f = np.fft.rfftfreq(win, 1.0 / sr)
    edges = 50.0 * 2 ** (np.arange(0, 26) / 3.0)
    edges = edges[edges < sr / 2]
    prev = None
    out = []
    for a in range(0, len(x) - win + 1, hop):
        S = np.abs(np.fft.rfft(x[a:a + win] * w)) ** 2
        b = np.array([np.sum(S[(f >= edges[i]) & (f < edges[i + 1])]) for i in range(len(edges) - 1)])
        l = 10 * np.log10(np.maximum(b, 1e-14))
        l = l - np.mean(l)
        if prev is not None:
            out.append(np.sqrt(np.mean((l - prev) ** 2)))
        prev = l
    return np.array(out)


# --- pictures ---------------------------------------------------------------------------------------------------
MAGMA = [(0.0, (0, 0, 4)), (0.13, (28, 16, 68)), (0.25, (79, 18, 123)), (0.38, (129, 37, 129)),
         (0.5, (181, 54, 122)), (0.63, (229, 80, 100)), (0.75, (251, 135, 97)), (0.88, (254, 194, 135)),
         (1.0, (252, 253, 191))]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def colormap(v: np.ndarray) -> np.ndarray:
    v = np.clip(v, 0.0, 1.0)
    xs = np.array([p[0] for p in MAGMA])
    cols = np.array([p[1] for p in MAGMA], float)
    out = np.stack([np.interp(v, xs, cols[:, c]) for c in range(3)], axis=-1)
    return out.astype(np.uint8)


def font(size: int, bold: bool = False):
    from PIL import ImageFont
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except Exception:
        return ImageFont.load_default()


def spectrogram_img(x: np.ndarray, sr: int, w: int = 1600, h: int = 420, fmin: float = 30.0, fmax: float = 20000.0,
                    dyn_db: float = 80.0, ref_db: float | None = None, win: int = 4096):
    """Log-frequency spectrogram (mono mix) as a PIL image, with axis labels. Returns (image, ref_db used)."""
    from PIL import Image, ImageDraw
    x = np.asarray(x, np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    n = len(x)
    hop = max(1, (n - win) // w)
    wnd = np.hanning(win)
    cols = []
    for i in range(w):
        a = min(i * hop, max(n - win, 0))
        seg = x[a:a + win]
        if len(seg) < win:
            seg = np.pad(seg, (0, win - len(seg)))
        cols.append(np.abs(np.fft.rfft(seg * wnd)) / (np.sum(wnd) * 0.5))
    S = np.array(cols).T                      # (bins, w)
    f = np.fft.rfftfreq(win, 1.0 / sr)
    fy = fmin * (min(fmax, sr / 2) / fmin) ** (np.arange(h) / (h - 1))
    # per output row: max over the bins it covers (keeps harmonics visible)
    edges = np.concatenate([[fy[0] * (fy[0] / fy[1]) ** 0.5], np.sqrt(fy[:-1] * fy[1:]), [fy[-1] * (fy[-1] / fy[-2]) ** 0.5]])
    img = np.zeros((h, w))
    for r in range(h):
        lo = np.searchsorted(f, edges[r]); hi = max(np.searchsorted(f, edges[r + 1]), lo + 1)
        hi = min(hi, len(f)); lo = min(lo, hi - 1)
        img[r] = np.sqrt(np.mean(S[lo:hi] ** 2, axis=0)) * np.sqrt(hi - lo)
    d = 20 * np.log10(np.maximum(img, 1e-9))
    if ref_db is None:
        ref_db = float(np.percentile(d, 99.9))
    v = (d - (ref_db - dyn_db)) / dyn_db
    rgb = colormap(v[::-1])
    ml, mb, mt = 56, 22, 22
    im = Image.new("RGB", (w + ml + 8, h + mb + mt), (16, 16, 20))
    im.paste(Image.fromarray(rgb), (ml, mt))
    dr = ImageDraw.Draw(im)
    fnt = font(11)
    for fl in [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]:
        if fl < fmin or fl > min(fmax, sr / 2):
            continue
        y = mt + h - 1 - int(round((h - 1) * math.log(fl / fmin) / math.log(min(fmax, sr / 2) / fmin)))
        dr.line([(ml - 4, y), (ml, y)], fill=(200, 200, 200))
        dr.text((4, y - 6), ("%d Hz" % fl) if fl < 1000 else ("%g kHz" % (fl / 1000)), fill=(200, 200, 200), font=fnt)
    dur = n / sr
    step = 5 if dur > 30 else (2 if dur > 12 else 1)
    t = 0
    while t <= dur:
        xx = ml + int(round(t / dur * (w - 1)))
        dr.line([(xx, mt + h), (xx, mt + h + 4)], fill=(200, 200, 200))
        dr.text((xx - 8, mt + h + 6), "%d s" % t, fill=(200, 200, 200), font=fnt)
        t += step
    return im, ref_db


def stack_images(items: list, path: str, title: str = "") -> None:
    """items: [(label, PIL image)] stacked vertically with labels."""
    from PIL import Image, ImageDraw
    w = max(im.size[0] for _, im in items)
    pad = 26
    h = sum(im.size[1] + pad for _, im in items) + (34 if title else 0)
    out = Image.new("RGB", (w, h), (16, 16, 20))
    dr = ImageDraw.Draw(out)
    y = 0
    if title:
        dr.text((10, 6), title, fill=(255, 255, 255), font=font(18, True))
        y = 34
    for label, im in items:
        dr.text((10, y + 4), label, fill=(255, 220, 140), font=font(14, True))
        out.paste(im, (0, y + pad))
        y += im.size[1] + pad
    out.save(path)


def line_plot(series: list, path: str, title: str, xlabel: str, ylabel: str, w: int = 1200, h: int = 420,
              ylim=None, xlim=None, logx: bool = False, xticks=None):
    """series: [(label, x, y, (r,g,b))]"""
    from PIL import Image, ImageDraw
    ml, mr, mt, mb = 64, 16, 40, 44
    im = Image.new("RGB", (w, h), (16, 16, 20))
    dr = ImageDraw.Draw(im)
    allx = np.concatenate([np.asarray(s[1], float) for s in series])
    ally = np.concatenate([np.asarray(s[2], float) for s in series])
    x0, x1 = (xlim if xlim else (float(allx.min()), float(allx.max())))
    y0, y1 = (ylim if ylim else (float(np.floor(ally.min() / 5) * 5), float(np.ceil(ally.max() / 5) * 5)))
    def X(v):
        v = np.asarray(v, float)
        if logx:
            return ml + (np.log(v / x0) / np.log(x1 / x0)) * (w - ml - mr)
        return ml + (v - x0) / (x1 - x0) * (w - ml - mr)
    def Y(v):
        return mt + (1.0 - (np.asarray(v, float) - y0) / (y1 - y0)) * (h - mt - mb)
    fnt = font(11)
    dr.text((10, 8), title, fill=(255, 255, 255), font=font(16, True))
    ystep = 5 if (y1 - y0) <= 60 else 10
    if (y1 - y0) <= 12:
        ystep = 1 if (y1 - y0) <= 6 else 2
    yy = math.ceil(y0 / ystep) * ystep
    while yy <= y1 + 1e-9:
        py = float(Y(yy))
        dr.line([(ml, py), (w - mr, py)], fill=(50, 50, 60))
        dr.text((8, py - 6), "%g" % yy, fill=(200, 200, 200), font=fnt)
        yy += ystep
    if xticks is None:
        if logx:
            xticks = [v for v in [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000] if x0 <= v <= x1]
        else:
            st = (x1 - x0) / 10.0
            mag = 10 ** math.floor(math.log10(st)); st = min([m * mag for m in (1, 2, 5, 10)], key=lambda q: abs(q - st))
            xticks = list(np.arange(math.ceil(x0 / st) * st, x1 + 1e-9, st))
    for xv in xticks:
        px = float(X(xv))
        dr.line([(px, mt), (px, h - mb)], fill=(50, 50, 60))
        dr.text((px - 12, h - mb + 6), ("%g" % xv) if xv < 1000 or not logx else ("%gk" % (xv / 1000)), fill=(200, 200, 200), font=fnt)
    dr.text((w // 2 - 40, h - 18), xlabel, fill=(200, 200, 200), font=fnt)
    dr.text((8, mt - 16), ylabel, fill=(200, 200, 200), font=fnt)
    lx = ml + 10
    for label, xs, ys, col in series:
        pts = list(zip(X(xs).tolist(), np.clip(Y(ys), mt, h - mb).tolist()))
        if len(pts) > 1:
            dr.line(pts, fill=col, width=2)
        dr.line([(lx, mt + 8), (lx + 22, mt + 8)], fill=col, width=3)
        dr.text((lx + 28, mt + 1), label, fill=col, font=font(12, True))
        lx += 40 + int(dr.textlength(label, font=font(12, True)))
    im.save(path)
