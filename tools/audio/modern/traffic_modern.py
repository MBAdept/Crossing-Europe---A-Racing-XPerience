#!/usr/bin/env python3
"""Traffic and police siren of the profile "Modern" – package AU-C2 (contract D25–D29, §4.7.3; docs/audio-modern.md
"Welt, Ambiente, Verkehr"). Writes into assets/audio/modern/traffic/ (44.1 kHz) and registers the sounds in the
folder's manifest (modern_lib.Manifest: only this generator's own entries are replaced; files it wrote before and no
longer writes are removed).

    python3 tools/audio/modern/traffic_modern.py               into the repository (with Godot import files)
    python3 tools/audio/modern/traffic_modern.py --out /tmp/x  into /tmp/x/assets/audio/modern/traffic (QC determinism)
    python3 tools/audio/modern/traffic_modern.py --wav /tmp/p  also a preview WAV of every sound

The voices of the other road users use the frozen Arcade model, imported and never edited (tools/audio/
traffic_synth.py with tools/audio/engine_synth.py: exhaust pulses with the real firing order, the exhaust system as
an acoustic network, induction, valve train, injectors, diesel knock, gear rattle of trucks; tyres from tread,
texture, air pumping, cavity; the flow around the body). They render at the model's 32 kHz – every loop is periodic
by construction (whole working cycles, circular synthesis) – and are brought to 44.1 kHz by band-limited periodic
resampling (zero-padded spectrum of the whole loop: the loop stays seamless; the length is rounded to whole samples,
a pitch error below 1e-5). What is new for Modern:

  engines   more variety per vehicle model: besides the six Arcade engines a second operating point of the petrol
            and the diesel car (another gear: other rpm and timbre) and an electric car (no combustion: the whine of
            the reduction gear and the motor's electromagnetic orders, rising with speed)
  tyres     wet variants for cars and trucks: the rolling noise and the spray hiss of the water pressed out of the
            treads (in rain a passing car is mostly spray)
  siren     the German two-tone pattern of Arcade (a¹ 440 Hz / d² 587 Hz, 0.62 s each – contract §1: one siren for
            all of Europe) with the timbre of an electronic siren through a horn loudspeaker (odd and even
            harmonics, the horn's resonances, a little driver distortion, a 25-ms glide between the tones)
  horns     a two-tone car horn (long, a double toot), a small car's single horn, a truck's air horn
  whooshes  the air thrown at the listener when a car passes close (a short swish) and the pressure wave and
            buffeting of a truck or bus (two variants)

Formats: the loops of engines, tyres and air are Ogg Vorbis (contract §4.7.3 names 16-bit WAV for tonal loops; as
WAV the nine 3-s engine loops alone would take 2.4 MB of the 4 MB left in the budget of §4.11 – amendment A-35):
each loop is encoded from q5 up until its seam is no rougher than twice its surroundings, like vehicle_loops.py.
The siren is a tonal loop and stays 16-bit WAV with LOOP_GUARD frames of its start behind loop_end (docs "Fallen"
13); horns and whooshes are 16-bit WAV one-shots.

Manifest entries carry, besides the measured values of modern_lib:
    layer, ref_kmh, pitch_exp, level_db_per_decade   (loops) what TrafficAudio needs per sound (docs/
                         verkehrsgeraeusche.md §1); the classes and the model map are configuration
                         (audio.modern.traffic), the levels too (targets at the master, not in the files)
    lufs_pitch           (loops) loudness when played at a pitch, as in vehicle_loops.py
    lufs_m               (one-shots) momentary maximum (400 ms) of each variant
    vorbis_q             (Ogg) the quality written
Deterministic (fixed seeds, no time stamps, Vorbis bit-exact).
"""
from __future__ import annotations

import argparse
import copy
import io
import math
import os
import sys
import contextlib

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modern_lib as ml  # noqa: E402  (puts tools/audio on sys.path)
import qc_lib  # noqa: E402
import vehicle_loops as vl  # noqa: E402
import traffic_synth as ts  # noqa: E402  (frozen Arcade tool: imported, never edited)
import engine_synth as es  # noqa: E402

GENERATOR = "tools/audio/modern/traffic_modern.py"
FOLDER = "traffic"
SR = ml.SR
SR_MODEL = ts.SR                 # 32 kHz: the Arcade model's rate
PEAK = 0.708
LOOP_GUARD = vl.LOOP_GUARD
OGG_Q = 5.0
TAU2 = 2.0 * np.pi
bp, lp, hp, peak, rms = vl.bp, vl.lp, vl.hp, vl.peak, vl.rms


def resample_loop(y: np.ndarray, sr_in: int = SR_MODEL, sr_out: int = SR) -> np.ndarray:
    """Band-limited periodic resampling of a loop (its spectrum zero-padded): the result is again exactly periodic."""
    n_in = len(y)
    n_out = int(round(n_in * sr_out / sr_in))
    spec = np.fft.rfft(y)
    if n_in % 2 == 0:
        spec[-1] *= 0.5                      # split the Nyquist bin of the shorter grid
    out = np.zeros(n_out // 2 + 1, complex)
    k = min(len(spec), len(out))
    out[:k] = spec[:k]
    return np.fft.irfft(out, n_out) * (n_out / n_in)


@contextlib.contextmanager
def quiet():
    """The Arcade model prints its progress – kept out of this tool's output."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        yield


# ------------------------------------------------------------------------------------------------------------------
# engines
# ------------------------------------------------------------------------------------------------------------------

def engine_profiles() -> dict:
    """The six Arcade traffic engines and two more operating points (another gear of the same engines)."""
    p = ts.engine_profiles()
    petrol_b = copy.deepcopy(p["car_petrol"])
    petrol_b["engine"] = {**petrol_b["engine"], "label": petrol_b["engine"]["label"] + ", eine Stufe kürzer übersetzt"}
    petrol_b["cruise"] = {**petrol_b["cruise"], "kmh": 130.0, "rpm": 2950.0, "p_im": 0.74}
    diesel_b = copy.deepcopy(p["car_diesel"])
    diesel_b["engine"] = {**diesel_b["engine"], "label": diesel_b["engine"]["label"] + ", schneller unterwegs"}
    diesel_b["cruise"] = {**diesel_b["cruise"], "kmh": 150.0, "rpm": 2450.0, "p_im": 1.45, "ratio": 2.2}
    p["car_petrol_b"] = petrol_b
    p["car_diesel_b"] = diesel_b
    return p


def ev_loop(n: int) -> np.ndarray:
    """An electric car at 120 km/h (motor ~10 500 /min = 175 Hz): the reduction gear's mesh whine (23 teeth on the
    motor shaft: 4.0 kHz, and its first stage at 1.27 kHz), the motor's electromagnetic order 48 (8.4 kHz, faint), a
    low hum of the drive, all with a little slow wobble – whole numbers of cycles per loop."""
    t = np.arange(n) / SR
    loop_s = n / SR

    def whole(f):
        return round(f * loop_s) / loop_s
    y = np.zeros(n)
    for f, g in ((1270.0, 1.0), (2540.0, 0.25), (4025.0, 0.55), (8400.0, 0.12), (175.0, 0.3), (350.0, 0.15)):
        fw = whole(f)
        y += g * np.sin(TAU2 * fw * t + f) * (1.0 + 0.15 * vl.slow(n, int(f), 0.3, 2.0))
    y += 0.35 * vl.pnoise(n, 4401, lambda f: bp(f, 200.0, 3000.0, 1))
    return y


# ------------------------------------------------------------------------------------------------------------------
# siren, horns, whooshes
# ------------------------------------------------------------------------------------------------------------------

SIREN_F = (440.0, 587.0)          # Arcade's tones (sfx_synth.siren_loop): a¹ and d²
SIREN_TONE_S = 0.62
SIREN_CYCLES = 2


def horn_speaker(fr):
    """Frequency response of a siren horn loudspeaker: horn cut-off ~350 Hz, resonances of the horn and the driver,
    roll-off above 5 kHz."""
    return (hp(fr, 350.0, 3) * lp(fr, 5200.0, 2) * peak(fr, 1150.0, 2.0, 5.0) * peak(fr, 2350.0, 3.0, 4.0)
            * peak(fr, 3600.0, 4.0, 2.0))


def siren_loop() -> np.ndarray:
    """Two cycles of the two-tone pattern; the phase runs on through the glides and the total phase of the loop is a
    whole number of cycles (seamless)."""
    seg = int(round(SIREN_TONE_S * SR))
    n = 2 * seg * SIREN_CYCLES
    glide = int(0.025 * SR)
    f = np.empty(n)
    for c in range(2 * SIREN_CYCLES):
        f[c * seg:(c + 1) * seg] = SIREN_F[c % 2]
    # glides at every change (and at the loop point, from the last tone into the first)
    for c in range(2 * SIREN_CYCLES):
        a = c * seg
        prev = SIREN_F[(c - 1) % 2]
        w = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, glide))
        f[a:a + glide] = prev + (SIREN_F[c % 2] - prev) * w
    # whole cycles over the loop: scale all frequencies by the tiny factor that rounds the phase
    cycles = float(np.sum(f)) / SR
    f *= round(cycles) / cycles
    ph = TAU2 * np.cumsum(f) / SR
    # waveform of the siren amplifier: a square-ish wave (odd harmonics) with some asymmetry (even ones)
    y = np.tanh(2.2 * np.sin(ph) + 0.35 * np.sin(2.0 * ph + 0.4))
    y = vl.cfilter(y, horn_speaker)
    y = np.tanh(1.3 * y / np.max(np.abs(y))) / math.tanh(1.3)     # the driver's soft distortion
    return y


def _disc_tone(m: int, f0: float, rng, settle: float = 0.02) -> np.ndarray:
    """A disc horn's tone: the diaphragm hitting its stop – a buzzy, pulse-like wave; it settles onto its pitch in
    the first 20 ms."""
    t = np.arange(m) / SR
    f = f0 * (1.0 - 0.04 * np.exp(-t / settle)) * (1.0 + 0.002 * rng.standard_normal(m).cumsum() / math.sqrt(m))
    ph = TAU2 * np.cumsum(f) / SR
    return np.tanh(4.0 * np.sin(ph)) + 0.25 * np.tanh(4.0 * np.sin(2.0 * ph + 0.7))


def horn(kind: str, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)

    def env(m, att, rel):
        e = np.ones(m)
        a, r = int(att * SR), int(rel * SR)
        e[:a] = np.linspace(0.0, 1.0, a) ** 1.5
        e[-r:] *= np.linspace(1.0, 0.0, r) ** 2
        return e

    def two_tone(dur: float) -> np.ndarray:
        m = int(dur * SR)
        y = _disc_tone(m, 412.0, rng) + 0.9 * _disc_tone(m, 508.0, rng)
        return ml_filter(y * env(m, 0.012, 0.03), lambda fr: hp(fr, 250.0, 2) * lp(fr, 6500.0, 2)
                         * peak(fr, 2300.0, 2.5, 6.0) * peak(fr, 3400.0, 3.0, 3.0))
    if kind == "car_long":
        return two_tone(0.72)
    if kind == "car_double":
        a = two_tone(0.17)
        b = two_tone(0.26)
        out = np.zeros(len(a) + int(0.11 * SR) + len(b))
        out[:len(a)] += a
        out[len(a) + int(0.11 * SR):] += b
        return out
    if kind == "car_small":
        m = int(0.36 * SR)
        y = _disc_tone(m, 470.0, rng)
        return ml_filter(y * env(m, 0.01, 0.03), lambda fr: hp(fr, 300.0, 2) * lp(fr, 7000.0, 2) * peak(fr, 2800.0, 2.5, 6.0))
    # a truck's air horn: two trumpets (a major third), brassy, the air pressure building up in the first 60 ms
    m = int(1.05 * SR)
    t = np.arange(m) / SR
    y = np.zeros(m)
    for f0, g in ((233.0, 1.0), (293.0, 0.85)):
        f = f0 * (1.0 - 0.06 * np.exp(-t / 0.05))
        ph = np.cumsum(f) / SR
        saw = 2.0 * (ph - np.floor(ph)) - 1.0
        y += g * saw
    y += 0.03 * rng.standard_normal(m)
    y = ml_filter(y * env(m, 0.06, 0.08), lambda fr: hp(fr, 180.0, 2) * lp(fr, 5000.0, 2) * peak(fr, 900.0, 1.5, 6.0)
                  * peak(fr, 1700.0, 2.0, 4.0))
    return y


def ml_filter(x: np.ndarray, shape) -> np.ndarray:
    """Zero-phase filtering of a one-shot, padded (nothing wraps)."""
    m = len(x)
    pad = 1 << int(math.ceil(math.log2(m + 4096)))
    f = np.maximum(np.fft.rfftfreq(pad, 1.0 / SR), 1e-3)
    return np.fft.irfft(np.fft.rfft(x, pad) * shape(f), pad)[:m]


def whoosh(kind: str, seed: int) -> np.ndarray:
    """car: the air of a car passing a metre or two away – a swish of 0.45 s whose band opens and closes (Doppler of
    the flow noise) with a soft low push; truck: the bow wave and the buffeting of a truck or bus – a low pressure
    pulse (25–90 Hz), turbulence fluttering 5–9 times a second for most of a second, and its hiss."""
    rng = np.random.default_rng(seed)
    if kind == "car":
        m = int(0.5 * SR)
        t = np.arange(m) / SR
        nz = rng.standard_normal(m)
        lo = ml_filter(nz, lambda fr: bp(fr, 150.0, 1500.0, 1))
        hi = ml_filter(nz, lambda fr: bp(fr, 1500.0, 7000.0, 1))
        u = (t - 0.22) / 0.1
        env = np.exp(-0.5 * u * u) * (1.0 + 0.6 * (t < 0.22))
        bright = np.exp(-0.5 * ((t - 0.2) / 0.07) ** 2)
        push = ml_filter(rng.standard_normal(m), lambda fr: bp(fr, 40.0, 140.0, 2)) * np.exp(-0.5 * ((t - 0.22) / 0.05) ** 2)
        y = (lo / rms(lo) + 0.7 * hi / rms(hi) * bright) * env + 0.8 * push / rms(push)
        return y
    m = int(1.1 * SR)
    t = np.arange(m) / SR
    pulse = ml_filter(rng.standard_normal(m), lambda fr: bp(fr, 25.0, 90.0, 2))
    pulse *= np.exp(-0.5 * ((t - 0.22) / 0.09) ** 2)
    turb = ml_filter(rng.standard_normal(m), lambda fr: bp(fr, 90.0, 900.0, 1) * peak(fr, 220.0, 0.8, 4.0))
    flutter = 1.0 + 0.7 * np.sin(TAU2 * rng.uniform(5.0, 9.0) * t + rng.uniform(0, 6.28)) * np.exp(-t / 0.7)
    turb *= np.clip((t - 0.12) / 0.15, 0.0, 1.0) * np.exp(-np.maximum(t - 0.3, 0.0) / 0.3) * flutter
    hiss = ml_filter(rng.standard_normal(m), lambda fr: bp(fr, 1000.0, 6000.0, 1))
    hiss *= np.exp(-0.5 * ((t - 0.3) / 0.18) ** 2)
    return 1.3 * pulse / rms(pulse) + turb / rms(turb) + 0.35 * hiss / rms(hiss)


# ------------------------------------------------------------------------------------------------------------------
# the list of sounds
# ------------------------------------------------------------------------------------------------------------------

def loops() -> list[dict]:
    """id, layer, ref_kmh, pitch_exp, db_per_decade, maker (returns the loop at 44.1 kHz), note, fmt."""
    profiles = engine_profiles()

    def engine(name):
        def make():
            with quiet():
                y, _info = ts.engine_loop(name, profiles[name])
            return resample_loop(y)
        return make

    def tyres(name):
        def make():
            with quiet():
                y, _info = ts.tire_loop(name, ts.TIRES[name])
            return resample_loop(y)
        return make

    def tyres_wet(name, spray_db, spray_pitch, seed):
        dry = tyres(name)

        def make():
            y = dry()
            y = y / rms(y)
            n = len(y)
            # the spray of the own car's wet layer (AU-C1) at the design speed; spray_pitch scales its frequencies
            # (rendered on m samples, stretched to the n of the loop: < 1 = lower, for the big truck tyres)
            m = int(round(n * spray_pitch))
            s = vl.tyre_wet(m, seed)
            s = resample_loop(s, m, n) if m != n else s
            s = s / rms(s)
            return y + 10.0 ** (spray_db / 20.0) * s
        return make

    def air():
        with quiet():
            y, _info = ts.air_loop("air", ts.AIR)
        return resample_loop(y)
    out = []
    for name, ref, note in (
            ("car_petrol", 120.0, "Pkw 1,5-l-Turbobenziner, 120 km/h im höchsten Gang (Arcade-Modell)"),
            ("car_petrol_b", 130.0, "Pkw 1,5-l-Turbobenziner, 130 km/h eine Stufe kürzer (2950 /min)"),
            ("car_diesel", 120.0, "Pkw 2,0-l-Turbodiesel, 120 km/h (Arcade-Modell)"),
            ("car_diesel_b", 150.0, "Pkw 2,0-l-Turbodiesel, 150 km/h (2450 /min) – auch die Polizei"),
            ("car_sport", 140.0, "Sportwagen 3,0-l-Reihensechser mit Sportauspuff, 140 km/h (Arcade-Modell)"),
            ("van_diesel", 110.0, "Transporter/SUV 2,0-l-Turbodiesel, 110 km/h (Arcade-Modell)"),
            ("truck_diesel", 85.0, "Sattelzug 12,8-l-Reihensechser, 85 km/h, mit Zahnradrasseln (Arcade-Modell)"),
            ("bus_diesel", 90.0, "Reisebus 10,7-l-Heckmotor, 90 km/h (Arcade-Modell)")):
        out.append({"id": name, "layer": "engine", "ref_kmh": ref, "pitch_exp": 1.0, "dpd": 0.0, "make": engine(name),
                    "note": note, "fmt": "ogg"})
    out.append({"id": "car_ev", "layer": "engine", "ref_kmh": 120.0, "pitch_exp": 1.0, "dpd": 10.0,
                "make": lambda: ev_loop(int(round(3.0 * SR))),
                "note": "Elektroauto, 120 km/h: Heulen des Untersetzungsgetriebes, elektromagnetische Ordnungen, leises Summen",
                "fmt": "ogg"})
    out.append({"id": "tires_car", "layer": "tires", "ref_kmh": 120.0, "pitch_exp": 0.35, "dpd": 30.0,
                "make": tyres("tires_car"), "note": "Vier Pkw-Reifen auf Splittmastixasphalt, 120 km/h (Arcade-Modell)",
                "fmt": "ogg"})
    out.append({"id": "tires_truck", "layer": "tires", "ref_kmh": 85.0, "pitch_exp": 0.35, "dpd": 30.0,
                "make": tyres("tires_truck"), "note": "Zwölf Lkw-Reifen, 85 km/h (Arcade-Modell)", "fmt": "ogg"})
    out.append({"id": "tires_car_wet", "layer": "tires", "ref_kmh": 120.0, "pitch_exp": 0.3, "dpd": 30.0,
                "make": tyres_wet("tires_car", 4.0, 1.0, 61),
                "note": "Pkw auf nasser Fahrbahn: Rollen und Sprühzischen (+4 dB über dem Rollen)", "fmt": "ogg"})
    out.append({"id": "tires_truck_wet", "layer": "tires", "ref_kmh": 85.0, "pitch_exp": 0.3, "dpd": 30.0,
                "make": tyres_wet("tires_truck", 6.0, 0.8, 62),
                "note": "Lkw auf nasser Fahrbahn: Rollen, kräftiges, tieferes Sprühen (+6 dB)", "fmt": "ogg"})
    out.append({"id": "air", "layer": "air", "ref_kmh": 120.0, "pitch_exp": 0.5, "dpd": 40.0, "make": air,
                "note": "Umströmung eines Fahrzeugs: Nachlauf, Ablösung, Zischen an Spalten (Arcade-Modell)", "fmt": "ogg"})
    out.append({"id": "siren", "layer": "siren", "ref_kmh": 0.0, "pitch_exp": 0.0, "dpd": 0.0, "make": siren_loop,
                "note": "Martinshorn: Arcade-Tonfolge a¹/d² (440/587 Hz, je 0,62 s), elektronische Anlage mit Druckkammer-"
                        "Trichterlautsprecher", "fmt": "wav"})
    return out


ONESHOTS = [
    ("horn_car", "horn", [lambda: horn("car_long", 5101), lambda: horn("car_double", 5102)],
     "Pkw-Zweiklanghupe (412/508 Hz): lang; zweimal kurz"),
    ("horn_small", "horn", [lambda: horn("car_small", 5201)], "Kleinwagen: einzelne helle Hupe (470 Hz)"),
    ("horn_truck", "horn", [lambda: horn("truck", 5301)], "Lkw-Drucklufthorn: zwei Fanfaren (233/293 Hz)"),
    ("whoosh_car", "whoosh", [lambda: whoosh("car", 5401), lambda: whoosh("car", 5402)],
     "Luftstoß eines dicht vorbeifahrenden Pkw"),
    ("whoosh_truck", "whoosh", [lambda: whoosh("truck", 5501), lambda: whoosh("truck", 5502)],
     "Bugwelle und Verwirbelung eines vorbeifahrenden Lkw oder Busses"),
]


# ------------------------------------------------------------------------------------------------------------------
# build
# ------------------------------------------------------------------------------------------------------------------

def _entry_files(e: dict) -> list[str]:
    return list(e.get("files") or ([e["file"]] if "file" in e else []))


def _finish_oneshot(y: np.ndarray) -> np.ndarray:
    y = np.asarray(y, np.float64)
    k = min(int(0.002 * SR), len(y) // 4)
    y = y.copy()
    y[:k] *= np.linspace(0.0, 1.0, k)
    y = vl.fade_tail(y, 0.03)
    y = y * (PEAK / float(np.max(np.abs(y))))
    return ml.limit_true_peak(y[:, None], -3.0)[:, 0]


def build(out: str | None, wav_dir: str | None, log=print) -> None:
    man = ml.Manifest(FOLDER, out)
    before = {f for e in man.sounds.values() if e.get("generator") == GENERATOR for f in _entry_files(e)}
    man.drop_generator(GENERATOR)
    repo = out is None
    total = 0
    written: set[str] = set()
    for d in loops():
        sid = d["id"]
        y = np.asarray(d["make"](), np.float64)
        n = len(y)
        y = y - float(np.mean(y))
        y = y * (PEAK / float(np.max(np.abs(y))))
        y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
        if d["fmt"] == "ogg":
            name = sid + ".ogg"
            q = OGG_Q
            for q in (OGG_Q, OGG_Q + 1.0, OGG_Q + 2.0, OGG_Q + 3.0):
                ml.write_ogg(man.file(name), y, quality=q)
                played = qc_lib.read_audio(man.file(name))[0][:, 0]
                seam = qc_lib.loop_seam(played[:, None], 0, len(played), 0.1, SR)
                if max(seam["ratio"], seam["kink_ratio"]) <= 2.0 or max(seam["loop_ratio"], seam["loop_kink_ratio"]) <= 1.0:
                    break
            else:
                print(f"WARNUNG {sid}: Naht auch bei q{q:g} rauer als das Doppelte ihres Umfelds (Sprung "
                      f"×{seam['ratio']:.2f}, Knick ×{seam['kink_ratio']:.2f}) – audio_qc.py prüft mit ×4", file=sys.stderr)
            if len(played) != n:
                raise ValueError(f"{sid}: Vorbis liefert {len(played)} statt {n} Frames")
            if repo:
                ml.write_ogg_import(man.file(name), 0.0)
        else:
            name = sid + ".wav"
            ml.write_wav16(man.file(name), np.concatenate([y, y[:LOOP_GUARD]]))
            played = y
            if repo:
                ml.write_wav_import(man.file(name), (0, n))
        bus = "MSiren" if d["layer"] == "siren" else "MTrafficV0"
        e = man.add(sid, name, "loop", GENERATOR, loop=(0, n), bus=bus, gain_db=0.0, note=d["note"])
        e["layer"] = d["layer"]
        if d["layer"] != "siren":
            e["ref_kmh"] = d["ref_kmh"]
            e["pitch_exp"] = d["pitch_exp"]
            e["level_db_per_decade"] = d["dpd"]
        e["lufs_pitch"] = [[p, vl.lufs_at_pitch(played, p)] for p in (0.6, 0.8, 1.0, 1.25, 1.6)]
        if d["fmt"] == "ogg":
            e["vorbis_q"] = q
        written.add(name)
        size = os.path.getsize(man.file(name))
        total += size
        if wav_dir:
            os.makedirs(wav_dir, exist_ok=True)
            reps = int(math.ceil(6.0 * SR / n))
            ml.write_wav16(os.path.join(wav_dir, sid + ".wav"), np.tile(played, reps)[:int(6.0 * SR)])
        log(f"  {sid:16s} {n / SR:5.2f} s  {e['lufs']:6.1f} LUFS  {e['true_peak_db']:5.1f} dBTP  {d['fmt']}"
            f"{' q%g' % q if d['fmt'] == 'ogg' else ''}  {size / 1e3:6.1f} kB")
    for sid, cat, makers, note in ONESHOTS:
        names, lufs_m = [], []
        for v, mk in enumerate(makers):
            y = _finish_oneshot(mk())
            name = f"{sid}_{chr(97 + v)}.wav" if len(makers) > 1 else sid + ".wav"
            ml.write_wav16(man.file(name), y)
            if repo:
                ml.write_wav_import(man.file(name), None)
            lufs_m.append(round(float(qc_lib.momentary_max(y[:, None], SR)), 2))
            names.append(name)
            written.add(name)
            total += os.path.getsize(man.file(name))
            if wav_dir:
                os.makedirs(wav_dir, exist_ok=True)
                ml.write_wav16(os.path.join(wav_dir, name), y)
        e = man.add(sid, names if len(names) > 1 else names[0], "oneshot", GENERATOR, bus="MTrafficV0", gain_db=0.0,
                    note=note)
        e["category"] = cat
        e["lufs_m"] = lufs_m
        log(f"  {sid:16s} {len(names)} ×  momentan {np.mean(lufs_m):6.1f} LUFS")
    man.save()
    if repo:
        for name in sorted(before - written):
            for p in (man.file(name), man.file(name) + ".import"):
                if os.path.exists(p):
                    os.remove(p)
                    log(f"  entfernt: {os.path.basename(p)}")
    log(f"traffic_modern: {len(loops())} Schleifen, {sum(len(o[2]) for o in ONESHOTS)} Einmalklänge, "
        f"{total / 1e6:.2f} MB -> {man.dir}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Verkehr und Martinshorn (Profil Modern, AU-C2)")
    ap.add_argument("--out", default=None, help="Ordner statt des Repositorys (ohne Import-Dateien)")
    ap.add_argument("--wav", default=None, help="zusätzlich eine Hörprobe je Klang in diesen Ordner")
    args = ap.parse_args()
    build(args.out, args.wav, print if not args.out else (lambda *_a: None))
    return 0


if __name__ == "__main__":
    sys.exit(main())
