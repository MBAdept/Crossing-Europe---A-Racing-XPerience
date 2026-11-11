"""Music chain of the sound profile "Modern" (contract D26, D29, D30, §4.7.3; docs/audio-modern.md, section "Musik").

Shared by the music generators in tools/audio/music/ (title_remaster.py, linke_spur.py, later pieces). It sits on top
of the frozen Arcade title-theme synthesiser tools/audio/music_synth.py (imported, never edited: its instruments,
filters, reverbs, compressor, limiter and loudness meter) and adds the "modern" production layer of the audio study
(layered drums, sub bass, wide leads, deeper sidechain pump, new reverbs, multiband master with an M/S stage) plus
everything a game file needs:

  set_tempo(bpm)             tempo of the frozen synthesiser (its BPM, BEAT, BAR, STEP and delay time)
  kick2 / snare2 / shaker / sub_bass, lead patches "super_l" / "super_r"      modern instruments
  Canvas                     a track buffer on a timeline (place a sound at a time, with pan)
  Mixer                      incremental mix: one stem at a time into drum / instrument / fx buses and reverb sends
                             (a three-minute piece never holds all its stems in memory)
  Master                     fit() on the part that sets the level, apply() to it and to related clips (the ending of
                             a race piece gets exactly the processing and gain of its body)
  finish_ogg()               Ogg Vorbis q5 through modern_lib (bit-exact), decoded again and measured: the true peak
                             after Vorbis must be <= -1 dBTP, else the limiter ceiling goes down and it is written again
  write_ogg_import_keep()    Godot import settings that keep an existing uid
  chroma / key / chord helpers for the checks (tools/audio/music/check_music.py)

Conventions (contract §4.7.3, A-5): 44.1 kHz stereo, Ogg Vorbis q5, masters at -14 LUFS integrated and a true peak
<= -1 dBTP after the encode; deterministic (fixed seeds, no time stamps: two runs write the same bytes); every
generator takes --out <dir> (then it writes below <dir> and no Godot import files).
"""
from __future__ import annotations

import functools
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.dont_write_bytecode = True
for _p in (os.path.join(ROOT, "tools", "audio"), os.path.join(ROOT, "tools", "audio", "modern"),
           os.path.join(ROOT, "tools", "audio", "qc")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import music_synth as ms  # noqa: E402  (frozen Arcade tool: imported, never edited)
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402

SR = ms.SR                      # 44100 – the mix rate of the game (D26)
OGG_QUALITY = 5.0
TARGET_LUFS = -14.0
TP_MAX_DBTP = -1.0              # after the Vorbis encode (QC limit)
TP_MARGIN_DB = 0.08             # aim this far below the limit after the encode


# ---------------------------------------------------------------------------------------------------------------------
# tempo
# ---------------------------------------------------------------------------------------------------------------------

def set_tempo(bpm: float) -> None:
    """Tempo of the frozen synthesiser for this process: its beat-based globals (the title theme's own values stay
    when this is never called). Call it before rendering anything (several instruments are cached per process)."""
    ms.BPM = float(bpm)
    ms.BEAT = 60.0 / ms.BPM
    ms.BAR = 4.0 * ms.BEAT
    ms.STEP = ms.BAR / 16.0
    ms.DELAY = (0.75 * ms.BEAT, 0.38, 9, 3800.0, 350.0)    # dotted eighth, as in the title theme


def frames_of(seconds: float) -> int:
    return int(round(seconds * SR))


# ---------------------------------------------------------------------------------------------------------------------
# modern instruments (audio study, spike 2: music2lib.py)
# ---------------------------------------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=None)
def kick2(var: int) -> np.ndarray:
    """Layer of the kick: longer sub (47 Hz), fast pitch sweep for the punch, harder click."""
    rng = ms.rng_of("kick2", var)
    n = int(0.62 * SR)
    t = np.arange(n) / SR
    f = 47.0 + 62.0 * np.exp(-t / 0.028) + 260.0 * np.exp(-t / 0.004)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR + 0.08 * rng.uniform(-1, 1))
    body *= (0.85 * np.exp(-t / 0.26) + 0.15 * np.exp(-t / 0.05)) * (1.0 - np.exp(-t / 0.0005))
    click = ms.band_noise(rng, n, 1500.0, 8000.0) * np.exp(-t / 0.002) * 0.22
    beater = np.sin(2.0 * np.pi * 4200.0 * t) * np.exp(-t / 0.0015) * 0.10
    x = np.tanh(2.2 * (body + click + beater)) / np.tanh(2.2)
    return ms.frozen(ms.fade_tail(x, 0.08))


@functools.lru_cache(maxsize=None)
def snare2(var: int) -> np.ndarray:
    """Layer of the snare: tighter crack, longer brighter gated room and a short plate tail (stereo)."""
    rng = ms.rng_of("snare2", var)
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    f1 = 196.0 * (1.0 + 0.2 * np.exp(-t / 0.01))
    body = np.sin(2.0 * np.pi * np.cumsum(f1) / SR) * np.exp(-t / 0.085)
    wires = ms.band_noise(rng, n, 1500.0, 11000.0, -0.5) * np.exp(-t / 0.14) * 0.7
    crack = ms.band_noise(rng, n, 2500.0, 14000.0) * np.exp(-t / 0.0035) * 0.9
    dry = np.tanh(1.5 * (body + wires + crack) * (1.0 - np.exp(-t / 0.0003)))
    out = dry[:, None] + ms._gated_room(rng, dry, 0.30, 0.75, 350.0, 9500.0, 0.34)
    tail = np.stack([ms.band_noise(rng, n, 500.0, 7000.0, -1.5) for _ in range(2)], axis=1)
    tail *= (np.exp(-t / 0.22) * (1.0 - np.exp(-t / 0.02)))[:, None]
    env = np.convolve(np.abs(dry), np.ones(64) / 64.0, mode="same")
    out += 0.12 * tail * np.max(env)
    return ms.frozen(ms.fade_tail(out / np.max(np.abs(out)), 0.05))


@functools.lru_cache(maxsize=None)
def shaker(var: int) -> np.ndarray:
    rng = ms.rng_of("shaker", var)
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    y = ms.band_noise(rng, n, 5200.0, 13500.0) * (1.0 - np.exp(-t / 0.004)) * np.exp(-t / 0.022)
    return ms.frozen(ms.fade_tail(y, 0.01))


@functools.lru_cache(maxsize=None)
def sub_bass(midi: int, dur: float) -> np.ndarray:
    """Sine sub an octave or two below the bass note, folded into 36..75 Hz."""
    f = float(ms.mtof(midi))
    while f < 36.0:
        f *= 2.0
    while f > 75.0:
        f *= 0.5
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    y = np.sin(2.0 * np.pi * f * t) + 0.12 * np.sin(4.0 * np.pi * f * t)
    y *= (1.0 - np.exp(-t / 0.006)) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.02))
    return ms.frozen(ms.fade_tail(y, 0.01))


# two decorrelated supersaws: the wide double of the synth lead (one per channel)
ms.LEAD_PATCHES.setdefault("super_l", {"osc": [("saw", -23.0, 0, 0.3), ("saw", -9.0, 0, 0.3), ("saw", 4.0, 0, 0.3),
                                                ("saw", 17.0, 0, 0.3), ("saw", 0.0, 12, 0.12)],
                                        "cut": 5200.0, "glide": 0.03, "vib": 0.12, "att": 0.012, "rel": 0.14,
                                        "bright": 0.5})
ms.LEAD_PATCHES.setdefault("super_r", {"osc": [("saw", 21.0, 0, 0.3), ("saw", 8.0, 0, 0.3), ("saw", -5.0, 0, 0.3),
                                                ("saw", -16.0, 0, 0.3), ("saw", 0.0, 12, 0.12)],
                                        "cut": 5200.0, "glide": 0.03, "vib": 0.12, "att": 0.012, "rel": 0.14,
                                        "bright": 0.5})


# ---------------------------------------------------------------------------------------------------------------------
# timeline buffers
# ---------------------------------------------------------------------------------------------------------------------

class Canvas:
    """A stereo (or mono) track buffer of n frames whose frame 0 lies at time t0 (s) of the piece."""

    def __init__(self, n: int, t0: float = 0.0, mono: bool = False):
        self.n = n
        self.t0 = t0
        self.x = np.zeros(n) if mono else np.zeros((n, 2))

    def place(self, x: np.ndarray, t: float, gain: float = 1.0, pan: float = 0.0) -> None:
        """Adds a sound at time t (s of the piece): mono with an equal-power pan, stereo with a balance."""
        i = int(round((t - self.t0) * SR))
        if i >= self.n or i + len(x) <= 0:
            return
        a, b = max(0, -i), min(len(x), self.n - i)
        buf = self.x
        if buf.ndim == 1:
            buf[i + a:i + b] += (x[a:b] if x.ndim == 1 else x[a:b].mean(axis=1)) * gain
        elif x.ndim == 1:
            gl, gr = ms.pan_gains(pan)
            buf[i + a:i + b, 0] += x[a:b] * (gain * gl)
            buf[i + a:i + b, 1] += x[a:b] * (gain * gr)
        else:
            buf[i + a:i + b, 0] += x[a:b, 0] * (gain * min(1.0, 1.0 - pan))
            buf[i + a:i + b, 1] += x[a:b, 1] * (gain * min(1.0, 1.0 + pan))

    def place_channel(self, x: np.ndarray, t: float, ch: int, gain: float = 1.0) -> None:
        i = int(round((t - self.t0) * SR))
        if i >= self.n or i + len(x) <= 0:
            return
        a, b = max(0, -i), min(len(x), self.n - i)
        self.x[i + a:i + b, ch] += x[a:b] * gain

    def stereo(self) -> np.ndarray:
        return self.x if self.x.ndim == 2 else np.stack([self.x, self.x], axis=1)


# ---------------------------------------------------------------------------------------------------------------------
# mix
# ---------------------------------------------------------------------------------------------------------------------

REVERBS2 = {
    "plate": {"ir": ("plate2", 2.6, 0.020, 1.6, 1.2, 10000.0, 0.15), "eq": [("hp", 280.0, 0.7), ("lp", 9000.0, 0.7)]},
    "hall": {"ir": ("hall2", 4.6, 0.045, 3.2, 2.3, 8000.0, 0.2), "eq": [("hp", 200.0, 0.7), ("lp", 8000.0, 0.7)]},
}


def process(x: np.ndarray, spec: dict, duck: np.ndarray | None) -> np.ndarray:
    """One track: saturation, EQ, compressor, chorus, pan, sidechain pump, then its loudness target (spec["lufs"],
    K-weighted and gated over the whole track – a constant gain)."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    if "sat" in spec:
        k = spec["sat"]
        pk = np.max(np.abs(x)) + 1e-12
        x = np.tanh(k * x / pk) / math.tanh(k) * pk
    if spec.get("eq"):
        x = ms.apply_eq(x, spec["eq"])
    if "comp" in spec:
        rel, ratio, att, rls = spec["comp"]
        x = x * ms.compressor_gain(x, ms.integrated_lufs(x) + rel, ratio, att, rls)[:, None]
    if spec.get("chorus"):
        x = ms.chorus(x, mix=spec["chorus"] if isinstance(spec["chorus"], float) else 0.6)
    if "pan" in spec:
        gl, gr = ms.pan_gains(spec["pan"])
        x = np.stack([x[:, 0] * gl, x[:, 1] * gr], axis=1)
    if "duck" in spec and duck is not None:
        x = x * (1.0 - spec["duck"] * (1.0 - duck))[:, None]
    lv = ms.integrated_lufs(x)
    if lv > -150.0:
        x = x * ms.undb(spec["lufs"] - lv)
    return x


class Mixer:
    """Incremental mix of one render: add() one track at a time (processed at once into its bus and its reverb and
    delay sends), finish() sums the buses: parallel compression and saturation on the drums, plate and hall reverbs,
    the ping-pong delay."""

    def __init__(self, n: int, kick_times: list, pump_release: float = 0.17, log=print):
        self.n = n
        self.buses = {k: np.zeros((n, 2)) for k in ("drums", "inst", "fx")}
        self.sends = {k: np.zeros((n, 2)) for k in ("plate", "hall", "delay")}
        self.duck = ms.duck_env(kick_times, n, 1.0, 0.004, 0.02, pump_release)
        self.levels: dict[str, float] = {}
        self.log = log

    def add(self, name: str, x: np.ndarray, spec: dict, auto: np.ndarray | None = None) -> None:
        if x is None or not np.any(x):
            return
        if len(x) != self.n:
            x = x[:self.n] if len(x) > self.n else np.pad(x, ((0, self.n - len(x)),) + ((0, 0),) * (x.ndim - 1))
        if auto is not None:
            x = x * (auto[:, None] if x.ndim == 2 else auto)
        y = process(x, spec, self.duck)
        self.buses[spec["bus"]] += y
        for s, lvl in spec.get("sends", {}).items():
            self.sends[s] += y * ms.undb(lvl)
        self.levels[name] = round(ms.integrated_lufs(y), 2)

    def finish(self) -> np.ndarray:
        d = self.buses["drums"]
        par = d * ms.compressor_gain(d, ms.integrated_lufs(d) - 2.0, 6.0, 0.003, 0.10)[:, None]
        d = d + 0.5 * ms.undb(4.0) * par
        pk = np.max(np.abs(d)) + 1e-12
        d = np.tanh(1.7 * d / pk) / math.tanh(1.7) * pk                 # bus saturation: rounder peaks
        out = d + self.buses["inst"] + self.buses["fx"]
        for name, r in REVERBS2.items():
            ir = np.asarray(ms.reverb_ir(*r["ir"]))
            wet = np.stack([ms.convolve(self.sends[name][:, c], ir[:, c]) for c in range(2)], axis=1)
            out += ms.apply_eq(wet, r["eq"])
        dly = np.asarray(ms.pingpong_ir(*ms.DELAY))
        out += ms.convolve(0.5 * (self.sends["delay"][:, 0] + self.sends["delay"][:, 1]), dly)
        self.buses = {}
        self.sends = {}
        return out


# ---------------------------------------------------------------------------------------------------------------------
# master
# ---------------------------------------------------------------------------------------------------------------------

def band_split(x: np.ndarray, edges: list, pad: int = 1 << 15) -> list:
    """Linear-phase band split with raised-cosine crossovers (one octave wide); the bands sum to the input. Zero
    padding keeps the circular FFT from wrapping the end of the render into its start."""
    n = len(x)
    m = ms.fft_size(n + 2 * pad)
    X = np.fft.rfft(np.pad(x, ((pad, m - n - pad), (0, 0))), axis=0)
    f = np.maximum(np.fft.rfftfreq(m, 1.0 / SR), 1.0)
    lows = []
    for fc in edges:
        z = np.clip(np.log2(f / fc) + 0.5, 0.0, 1.0)
        lows.append(0.5 + 0.5 * np.cos(np.pi * z))          # 1 below fc/sqrt2, 0 above fc*sqrt2
    masks = [lows[0]] + [lows[i] - lows[i - 1] for i in range(1, len(lows))] + [1.0 - lows[-1]]
    out = []
    for mk in masks:
        out.append(np.fft.irfft(X * mk[:, None], m, axis=0)[pad:pad + n])
    return out


class Master:
    """Master of a piece (audio study, master2): EQ, three-band compression (140 Hz / 3.2 kHz), glue compressor, M/S
    stage (mono below 120 Hz, a little more side above 4 kHz), loudness gain, soft clip and a lookahead true-peak
    limiter. fit() derives the thresholds and the gain from the part that sets the level (`measure`, e.g. the loop
    body); apply() processes any signal with exactly these values – the intro and ending clips of a race piece
    sound like its body and keep their level relative to it."""

    EQ = [("hp", 24.0, 0.7), ("ls", 62.0, 1.0), ("peak", 105.0, 0.5, 1.0), ("peak", 520.0, 2.2, 0.55),
          ("peak", 3200.0, 0.5, 0.8), ("hs", 11000.0, 0.0)]
    EDGES = [140.0, 3200.0]
    BANDS = (("low", 0.0, 3.0, 0.020, 0.16), ("mid", 1.0, 2.0, 0.012, 0.14), ("high", 0.5, 2.5, 0.004, 0.09))

    def __init__(self, target_lufs: float = TARGET_LUFS, ceiling_dbtp: float = TP_MAX_DBTP - 0.7, log=print):
        self.target = target_lufs
        self.ceiling = ceiling_dbtp       # limiter ceiling (true peak before the encode)
        self.log = log
        self.band_thr: list[float] = []
        self.band_makeup: list[float] = []
        self.glue_thr = 0.0
        self.gain = 1.0
        self.info: dict = {}

    # --- stages -----------------------------------------------------------------------------------------------
    def _bands(self, x: np.ndarray, measure: slice | None) -> np.ndarray:
        bands = band_split(x, self.EDGES)
        out = np.zeros_like(x)
        fit = measure is not None
        if fit:
            self.band_thr, self.band_makeup = [], []
        for i, (b, (nm, rel_thr, ratio, att, rls)) in enumerate(zip(bands, self.BANDS)):
            if fit:
                p = float(np.mean(b[measure] ** 2))
                self.band_thr.append(10.0 * math.log10(max(p, 1e-14)) + rel_thr)
            g = ms.compressor_gain(b, self.band_thr[i], ratio, att, rls, 6.0)
            if fit:
                gr_avg = float(np.mean(20.0 * np.log10(g[measure])))
                self.band_makeup.append(ms.undb(-0.6 * gr_avg))
                self.info["mb_%s_gr_db" % nm] = round(gr_avg, 2)
            out += b * g[:, None] * self.band_makeup[i]
        return out

    def _glue(self, x: np.ndarray, measure: slice | None) -> np.ndarray:
        if measure is not None:
            self.glue_thr = ms.integrated_lufs(x[measure]) + 3.0
        g = ms.compressor_gain(x, self.glue_thr, 2.0, 0.020, 0.25, 6.0)
        if measure is not None:
            self.info["glue_gr_db"] = round(float(ms.db(g.min())), 2)
        return x * g[:, None]

    @staticmethod
    def _ms(x: np.ndarray) -> np.ndarray:
        mid = 0.5 * (x[:, 0] + x[:, 1])
        side = 0.5 * (x[:, 0] - x[:, 1])
        side = ms.apply_eq(side, [("hp", 120.0, 0.7071), ("hs", 4000.0, 2.0)]) * ms.undb(1.0)
        return np.stack([mid + side, mid - side], axis=1)

    def _out(self, x: np.ndarray, gain: float) -> tuple:
        y = x * gain
        knee = ms.undb(self.ceiling - 4.3)
        over = np.abs(y) > knee
        y = np.where(over, np.sign(y) * (knee + (1.0 - knee) * np.tanh((np.abs(y) - knee) / (1.0 - knee))), y)
        return ms.limiter(y, self.ceiling)

    def pre(self, x: np.ndarray, measure: slice | None = None) -> np.ndarray:
        """Everything before the output gain (fit the thresholds when `measure` is given)."""
        x = ms.apply_eq(x, self.EQ)
        x = self._bands(x, measure)
        x = self._glue(x, measure)
        return self._ms(x)

    def fit_gain(self, p: np.ndarray, measure: slice) -> np.ndarray:
        """Output gain so that the measured part reaches the target loudness after soft clip and limiter."""
        gain = ms.undb(self.target - ms.integrated_lufs(p[measure]))
        y, gr, lv = p, np.zeros(1), -200.0
        for _ in range(8):
            y, gr = self._out(p, gain)
            lv = ms.integrated_lufs(y[measure])
            if abs(lv - self.target) < 0.02:
                break
            gain *= ms.undb(self.target - lv)
        self.gain = gain
        self.info.update({"limiter_gr_db": round(float(gr.min()), 2),
                          "limiter_gr_p995_db": round(float(np.percentile(gr[measure], 0.5)), 2),
                          "lufs": round(lv, 2), "ceiling_dbtp": round(self.ceiling, 2)})
        self.log("  Master: %s" % ", ".join("%s %s" % kv for kv in self.info.items()))
        return y

    def post(self, p: np.ndarray) -> np.ndarray:
        """The output stage with the fitted gain (for a clip that follows the fitted part)."""
        return self._out(p, self.gain)[0]


# ---------------------------------------------------------------------------------------------------------------------
# output: Ogg Vorbis, measured after the encode
# ---------------------------------------------------------------------------------------------------------------------

def encode_checked(x: np.ndarray, path: str, title: str, reencode=None, log=print, max_rounds: int = 4) -> dict:
    """Writes x as Ogg Vorbis q5 (bit-exact flags), decodes it and measures length, loudness and true peak. When the
    true peak after the encode is above TP_MAX_DBTP - TP_MARGIN_DB, reencode(lower_by_db) must return the signal
    with a lower limiter ceiling, and the file is written again. Returns the measurements of the file."""
    for rnd in range(max_rounds):
        ml.write_ogg(path, x, SR, OGG_QUALITY, title)
        dec, sr = qc_lib.read_audio(path)
        tp = qc_lib.true_peak_db(dec)
        info = {"frames": int(len(dec)), "frames_in": int(len(x)), "sample_rate": int(sr),
                "lufs": round(qc_lib.integrated_lufs(dec, sr), 2), "true_peak_db": round(tp, 2),
                "peak_before_db": round(qc_lib.true_peak_db(x), 2), "bytes": os.path.getsize(path), "rounds": rnd + 1}
        if len(dec) != len(x):
            raise SystemExit(f"{path}: Vorbis liefert {len(dec)} statt {len(x)} Frames")
        if tp <= TP_MAX_DBTP - TP_MARGIN_DB or reencode is None:
            log(f"  {os.path.basename(path)}: {info['lufs']:.2f} LUFS, True Peak {tp:.2f} dBTP nach Vorbis "
                f"(vorher {info['peak_before_db']:.2f}), {info['bytes'] / 1e6:.2f} MB, {info['frames']} Frames")
            return info
        lower = tp - (TP_MAX_DBTP - TP_MARGIN_DB) + 0.03
        log(f"  {os.path.basename(path)}: True Peak {tp:.2f} dBTP nach Vorbis – Begrenzer {lower:.2f} dB tiefer")
        x = reencode(lower)
    raise SystemExit(f"{path}: True Peak nach {max_rounds} Durchgängen noch über {TP_MAX_DBTP} dBTP")


def write_ogg_import_keep(path: str, loop_offset_s: float | None, bpm: float = 0.0, beats: int = 0,
                          bar_beats: int = 4) -> None:
    """Godot import settings of an Ogg Vorbis file (as modern_lib.write_ogg_import), but the [remap]/[deps] part of an
    existing .import is read before the file is opened for writing: uid and import path stay valid (modern_lib's
    version truncates the file first – docs/audio-modern.md, "Offene Punkte")."""
    imp = path + ".import"
    head = None
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].rstrip("\n")
    if not head:
        res = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
        head = f'[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n[deps]\n\nsource_file="{res}"'
    # the loop offset with every digit that matters: Godot truncates loop_offset x rate to a frame
    off = format(loop_offset_s, ".9f").rstrip("0").rstrip(".") if loop_offset_s is not None else "0"
    params = ["loop=%s" % ("true" if loop_offset_s is not None else "false"),
              "loop_offset=%s" % off,
              "bpm=%s" % f"{bpm:g}", "beat_count=%d" % beats, "bar_beats=%d" % bar_beats]
    with open(imp, "w", encoding="utf-8") as fh:
        fh.write(head + "\n\n[params]\n\n" + "\n".join(params) + "\n")


def seam_db(a: np.ndarray, b: np.ndarray) -> float:
    """Largest difference of two renders of the same music (dBFS): the loop continuation against the loop start."""
    n = min(len(a), len(b))
    return round(ms.db(float(np.max(np.abs(a[:n] - b[:n])))), 1)


# ---------------------------------------------------------------------------------------------------------------------
# analysis (checks)
# ---------------------------------------------------------------------------------------------------------------------

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FLAT = {"Bb": "A#", "Eb": "D#", "Ab": "G#", "Db": "C#", "Gb": "F#"}


def chroma_bars(x: np.ndarray, bar_starts: list, bar_s: float, low_cut_hz: float = 0.0) -> np.ndarray:
    """12-bin chroma per bar from tonal peaks (the method of tools/audio/music_preview.py: STFT 8192 of the mono sum,
    70 Hz .. 1.8 kHz, spectral maxima at least 6 dB above their neighbourhood)."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    if low_cut_hz > 0.0:
        X = np.fft.rfft(mono)
        f = np.fft.rfftfreq(len(mono), 1.0 / SR)
        X[f < low_cut_hz] = 0.0
        mono = np.fft.irfft(X, len(mono))
    n, hop = 8192, 2048
    f = np.fft.rfftfreq(n, 1.0 / SR)
    sel = (f >= 70.0) & (f <= 1800.0)
    pcs = (np.round(12.0 * np.log2(np.maximum(f, 1.0) / 440.0)) + 9).astype(int) % 12
    win = np.hanning(n)
    kern = np.ones(15) / 15.0
    out = np.zeros((len(bar_starts), 12))
    for i, t in enumerate(bar_starts):
        a = int(t * SR)
        e = min(len(mono), int((t + bar_s) * SR))
        starts = np.arange(a, e - n, hop)
        if len(starts) == 0:
            continue
        seg = np.stack([mono[s0:s0 + n] * win for s0 in starts])
        mag = np.abs(np.fft.rfft(seg, axis=1))
        lm = 20.0 * np.log10(mag + 1e-12)
        sm = np.apply_along_axis(lambda r: np.convolve(r, kern, mode="same"), 1, lm)
        peak = (mag > np.roll(mag, 1, axis=1)) & (mag >= np.roll(mag, -1, axis=1)) & (lm > sm + 6.0) & sel[None, :]
        w = np.where(peak, mag * mag, 0.0).sum(axis=0)
        acc = np.bincount(pcs, weights=w, minlength=12)
        out[i] = acc / (acc.sum() + 1e-20)
    return out


def triad_templates() -> dict:
    out = {}
    for pc in range(12):
        for third, suffix in ((4, ""), (3, "m")):
            t = np.zeros(12)
            t[[pc, (pc + third) % 12, (pc + 7) % 12]] = [1.0, 1.0, 0.8]
            out[NOTE_NAMES[pc] + suffix] = t / np.linalg.norm(t)
    return out


def best_triad(ch: np.ndarray) -> str:
    tpl = triad_templates()
    return max(tpl.items(), key=lambda kv: float(np.dot(kv[1], ch)))[0]


def chord_root_pc(name: str) -> int:
    """Pitch class of a chord name: "Em", "F#m", "Bb", "A#" -> 0..11."""
    root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    root = FLAT.get(root, root)
    return NOTE_NAMES.index(root)


KK_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
KK_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])


def key_of(ch: np.ndarray) -> str:
    """Best of the 24 keys (Krumhansl-Kessler profiles), named in German as in music_preview.py."""
    best, name = -2.0, ""
    for k in range(12):
        for prof, label in ((KK_MINOR, "-Moll"), (KK_MAJOR, "-Dur")):
            r = float(np.corrcoef(np.roll(prof, k), ch)[0, 1])
            if r > best:
                best, name = r, NOTE_NAMES[k] + label
                if label == "-Dur":
                    name += f" (= {NOTE_NAMES[(k + 9) % 12]}-Moll)"
    return name
