#!/usr/bin/env python3
"""Placeholder traffic loops for the traffic sound runtime (format: docs/verkehrsgeraeusche.md §1).

Simple synthetic loops in the contract format, so scripts/audio/traffic_audio.gd can be developed, tested and
recorded before the real sounds of tools/audio/traffic_synth.py exist:

  traffic/traffic_sounds.json      sounds/classes/models exactly as in the contract example (same names, levels,
                                   reference speeds), "sample_rate": 16000
  traffic/<sound>.wav              mono, 16 bit, 16 kHz, 1.6 s, seamless loops (every component is periodic in
                                   the loop length: harmonics on the loop's frequency grid, noise synthesised in
                                   the frequency domain). 16 kHz instead of the contract's 32 kHz keeps the files
                                   small; the runtime takes the rate from the WAV.

Every loop is normalised to RMS -15 dBFS (peaks at most 0.95), so gain_db alone sets the levels between sounds;
audio.traffic_db was calibrated with this loudness.

The sounds are deliberately simple and only need to be recognisable in recordings:
  engines   firing-frequency harmonic series (+ half orders, slight roughness), muffled; diesels with knock noise
            gated at the firing frequency; truck/bus deep (55/60 Hz), sport bright (150 Hz)
  tires     shaped noise with the tyre cavity resonance (car 230 Hz, truck 170 Hz) and a few tread tones
  air       broadband rushing noise (peak ~600 Hz) with slow turbulence modulation

Usage (numpy):  python3 tests/fixtures/make_traffic_fixtures.py [--out tests/fixtures/traffic]
"""

import argparse
import json
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FORMAT = "ce-traffic-sounds-1"
SR = 16000
SECONDS = 1.6
N = int(SR * SECONDS)
RMS_DB = -15.0       # loudness of every loop (peaks at most 0.95)

SOUNDS = {
    "car_petrol": {"file": "car_petrol.wav", "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_diesel": {"file": "car_diesel.wav", "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_sport": {"file": "car_sport.wav", "layer": "engine", "ref_kmh": 140, "pitch_exp": 1.0, "gain_db": -2.0},
    "van_diesel": {"file": "van_diesel.wav", "layer": "engine", "ref_kmh": 110, "pitch_exp": 1.0, "gain_db": -3.0},
    "truck_diesel": {"file": "truck_diesel.wav", "layer": "engine", "ref_kmh": 85, "pitch_exp": 1.0, "gain_db": 0.0},
    "bus_diesel": {"file": "bus_diesel.wav", "layer": "engine", "ref_kmh": 90, "pitch_exp": 1.0, "gain_db": -1.0},
    "tires_car": {"file": "tires_car.wav", "layer": "tires", "ref_kmh": 120, "pitch_exp": 0.35, "gain_db": -3.0,
                  "level_db_per_decade": 30.0},
    "tires_truck": {"file": "tires_truck.wav", "layer": "tires", "ref_kmh": 85, "pitch_exp": 0.35, "gain_db": 0.0,
                    "level_db_per_decade": 30.0},
    "air": {"file": "air.wav", "layer": "air", "ref_kmh": 120, "pitch_exp": 0.5, "gain_db": -6.0,
            "level_db_per_decade": 40.0},
}
CLASSES = {
    "car": {"engine": ["car_petrol", "car_diesel"], "tires": "tires_car", "air": "air", "size": 1.0},
    "sport": {"engine": ["car_sport"], "tires": "tires_car", "air": "air", "size": 1.0},
    "van": {"engine": ["van_diesel"], "tires": "tires_car", "air": "air", "size": 1.3},
    "truck": {"engine": ["truck_diesel"], "tires": "tires_truck", "air": "air", "size": 2.2},
    "bus": {"engine": ["bus_diesel"], "tires": "tires_truck", "air": "air", "size": 2.0},
    "police": {"engine": ["car_sport"], "tires": "tires_car", "air": "air", "size": 1.0},
}
MODELS = {"hatch": "car", "sedan": "car", "wagon": "car", "suv": "van", "van": "van", "sports": "sport",
          "truck": "truck", "bus": "bus", "police": "police"}

FREQS = np.fft.rfftfreq(N, 1.0 / SR)
T = np.arange(N) / SR


def grid(f):
    """Nearest frequency with an integer number of cycles per loop (keeps the loop seamless)."""
    return max(1, round(f * SECONDS)) / SECONDS


def noise(rng, mag):
    """Periodic noise with the magnitude spectrum mag (array over FREQS), random phases, unit RMS."""
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(FREQS)))
    spec[0] = 0.0
    x = np.fft.irfft(spec, N)
    return x / (np.sqrt(np.mean(x * x)) + 1e-12)


def resonance(f0, q):
    """Magnitude of a 2nd-order band-pass around f0 (Q) over FREQS."""
    f = np.maximum(FREQS, 1e-3)
    return 1.0 / np.sqrt(1.0 + (q * (f / f0 - f0 / f)) ** 2)


def lowpass(fc, order=2):
    return 1.0 / np.sqrt(1.0 + (FREQS / fc) ** (2 * order))


def highpass(fc, order=1):
    f = np.maximum(FREQS, 1e-3)
    return 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order))


def spectral_filter(x, mag):
    return np.fft.irfft(np.fft.rfft(x) * mag, N)


def engine(rng, fire_hz, harmonics, tilt, muffler_hz, half_orders, knock, rough):
    """Harmonic series of the firing frequency (+ half orders), muffled, optional diesel knock noise."""
    f0 = grid(fire_hz)
    x = np.zeros(N)
    for h in range(1, harmonics + 1):
        f = f0 * h
        if f >= SR * 0.45:
            break
        a = h ** -tilt
        x += a * np.sin(2 * np.pi * f * T + rng.uniform(0, 2 * np.pi))
        if half_orders > 0.0:
            fh = grid(f0 * (h - 0.5))
            x += half_orders * a * np.sin(2 * np.pi * fh * T + rng.uniform(0, 2 * np.pi))
    # roughness: slow periodic amplitude wobble (integer cycles per loop)
    x *= 1.0 + rough * np.sin(2 * np.pi * grid(3.1) * T) * np.sin(2 * np.pi * grid(7.3) * T + 1.0)
    x = spectral_filter(x, lowpass(muffler_hz, 2) * highpass(25.0, 2))
    x /= np.sqrt(np.mean(x * x)) + 1e-12
    if knock > 0.0:
        gate = (0.5 + 0.5 * np.cos(2 * np.pi * f0 * T)) ** 6
        n = noise(rng, resonance(1800.0, 1.5) + 0.3 * resonance(3200.0, 2.0))
        k = n * gate
        x += knock * k / (np.sqrt(np.mean(k * k)) + 1e-12)
    # a little exhaust hiss
    x += 0.06 * noise(rng, lowpass(2500.0, 1) * highpass(200.0, 1))
    return x


def tires(rng, cavity_hz, tread_hz, low_hz):
    mag = 0.55 * resonance(cavity_hz, 3.0) + highpass(low_hz, 1) * lowpass(2200.0, 2) * 0.6
    x = noise(rng, mag)
    for i, f in enumerate(tread_hz):
        x += 0.18 * np.sin(2 * np.pi * grid(f) * T + rng.uniform(0, 2 * np.pi)) * (
            1.0 + 0.3 * np.sin(2 * np.pi * grid(1.9 + i) * T))
    return x


def air(rng):
    mag = resonance(600.0, 0.6) * lowpass(3500.0, 1) * highpass(120.0, 1)
    x = noise(rng, mag)
    mod = 1.0 + 0.35 * np.sin(2 * np.pi * grid(2.5) * T) + 0.2 * np.sin(2 * np.pi * grid(5.6) * T + 2.0)
    return x * mod


def normalise(x, rms_db=RMS_DB, ceiling=0.95):
    """Loudness: RMS rms_db dBFS (all loops comparable, the runtime levels then come from gain_db); peaks above
    `ceiling` (diesel knock) scale the whole loop down instead of clipping."""
    x = x - np.mean(x)
    x = x * (10.0 ** (rms_db / 20.0) / (np.sqrt(np.mean(x * x)) + 1e-12))
    peak = np.max(np.abs(x))
    return x * (ceiling / peak) if peak > ceiling else x


def write_wav(path, x):
    data = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def build():
    rng = np.random.default_rng(20261101)
    return {
        "car_petrol": engine(rng, 87.0, 40, 0.9, 900.0, 0.25, 0.0, 0.10),
        "car_diesel": engine(rng, 73.0, 40, 0.8, 800.0, 0.15, 0.55, 0.08),
        "car_sport": engine(rng, 150.0, 30, 0.7, 2200.0, 0.35, 0.0, 0.12),
        "van_diesel": engine(rng, 80.0, 40, 0.8, 750.0, 0.15, 0.6, 0.08),
        "truck_diesel": engine(rng, 55.0, 60, 0.7, 650.0, 0.2, 0.7, 0.10),
        "bus_diesel": engine(rng, 60.0, 60, 0.75, 600.0, 0.2, 0.6, 0.10),
        "tires_car": tires(rng, 230.0, [820.0, 1240.0], 300.0),
        "tires_truck": tires(rng, 170.0, [510.0, 1020.0, 1530.0], 220.0),
        "air": air(rng),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(HERE, "traffic"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    sigs = build()
    for name, x in sigs.items():
        x = normalise(x)
        # seam check: the loop wraps without a jump bigger than the signal's own steepest step
        jump = abs(x[0] - x[-1])
        steep = np.max(np.abs(np.diff(x)))
        assert jump <= steep * 1.01, (name, jump, steep)
        write_wav(os.path.join(args.out, SOUNDS[name]["file"]), x)
    meta = {"format": FORMAT, "sample_rate": SR, "_doc": "Platzhalter (tests/fixtures/make_traffic_fixtures.py), "
            "nicht die echten Verkehrsgeräusche.", "sounds": SOUNDS, "classes": CLASSES, "models": MODELS}
    with open(os.path.join(args.out, "traffic_sounds.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("%d Schleifen (%d Hz, %.1f s) und traffic_sounds.json nach %s" % (len(sigs), SR, SECONDS, args.out))


if __name__ == "__main__":
    main()
