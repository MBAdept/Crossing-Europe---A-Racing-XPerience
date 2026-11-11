#!/usr/bin/env python3
"""One-shots of the player's car on the road and in collisions – profile "Modern", package AU-C1 (contract D28,
§4.7.2–§4.7.3; docs/audio-modern.md "Fahrbahn, Wind, Aufprall"). Writes into assets/audio/modern/sfx/ (16-bit WAV,
44.1 kHz, mono – the runtime pans them to the side they come from) and registers them in the folder's manifest
(modern_lib.Manifest: only this generator's own entries are replaced).

    python3 tools/audio/modern/sfx_modern.py               into the repository (with Godot import files)
    python3 tools/audio/modern/sfx_modern.py --out /tmp/x  into /tmp/x/assets/audio/modern/sfx (QC determinism)
    python3 tools/audio/modern/sfx_modern.py --wav /tmp/p  also a preview WAV of every sound (variants in a row)

Sounds (variants "files" are played in turn or picked by the runtime):
    joint_steel / joint_concrete   an expansion joint of a bridge under the front and then the rear axle: three
                                   variants with the axle gaps of "gaps_s" (the runtime takes the nearest one and
                                   shifts its pitch so the gap matches wheelbase / speed exactly)
    pass_post, pass_sign, pass_tree, pass_building, pass_gantry, pass_rock
                                   the car's own noise thrown back by an object it passes, at 100 km/h (the runtime
                                   shortens and brightens it with the speed)
    hit_light, hit_heavy, crunch, glass, debris, truck_boom
                                   layers of a collision (the runtime stacks them by closing speed and partner)
    rail_hit, rail_touch           the car into the guardrail: a hard hit with the ringing W-beam, a light graze
    post_hit                       a flexible delineator post knocked down by the body
Every file is stored at -3 dBFS sample peak. Entries carry "lufs_m" (the momentary maximum, 400 ms, of each
variant): the runtime sets its levels as momentary loudness at the master from config audio.modern.road / impact.
Deterministic (fixed seeds, no time stamps): audio_qc.py --determinism runs this twice and compares the bytes.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modern_lib as ml  # noqa: E402
import qc_lib  # noqa: E402
import vehicle_loops as vl  # noqa: E402
from vehicle_loops import bp, decay_sine, hp, lp, mixc, noise_burst, peak, rms  # noqa: E402

GENERATOR = "tools/audio/modern/sfx_modern.py"
FOLDER = "sfx"
SR = ml.SR
PEAK = 0.708
JOINT_GAPS = [0.160, 0.090, 0.050]   # axle gaps of the joint variants (s)


def shaped(rng, m: int, shape) -> np.ndarray:
    """Noise of m samples with magnitude shape(f), unit RMS."""
    nz = rng.standard_normal(m)
    f = np.maximum(np.fft.rfftfreq(m, 1.0 / SR), 1.0)
    y = np.fft.irfft(np.fft.rfft(nz) * shape(f), m)
    return y / rms(y)


def env_ad(m: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(m) / SR
    return (1.0 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t / max(decay, 1e-5))


def at(y: np.ndarray, clip: np.ndarray, t: float, gain: float = 1.0) -> None:
    vl.place(y, clip, int(round(t * SR)), gain, circular=False)


def finish(y: np.ndarray, fade_s: float = 0.04) -> np.ndarray:
    """The end of a one-shot fades to silence (no click when it stops)."""
    return vl.fade_tail(np.asarray(y, np.float64), fade_s)


# ------------------------------------------------------------------------------------------------------------------
# road
# ------------------------------------------------------------------------------------------------------------------

def joint_hit(rng, steel: bool) -> np.ndarray:
    """One axle over an expansion joint: the tyres drop into and climb out of the gap (a dull double thump) and, on
    a steel bridge, the finger plates clank and ring."""
    thump = mixc((1.0, decay_sine(rng.uniform(64.0, 74.0), 0.045, 0.3, 0.0, rng.uniform(48.0, 56.0), 0.002)),
                 (0.55, decay_sine(rng.uniform(105.0, 120.0), 0.025, 0.2, 1.0)),
                 (0.5, noise_burst(rng, 0.03, 300.0, 1800.0, 0.004)))
    if not steel:
        return thump
    ring = np.zeros(int(0.35 * SR))
    for f0, tau, g in ((520.0, 0.11, 0.30), (870.0, 0.08, 0.25), (1340.0, 0.06, 0.20), (2210.0, 0.04, 0.14), (3350.0, 0.025, 0.08)):
        c = decay_sine(f0 * rng.uniform(0.97, 1.03), tau, 0.35, rng.uniform(0, 6.28), None, 0.0003)
        ring[:len(c)] += g * c
    click = noise_burst(rng, 0.01, 1200.0, 5000.0, 0.002)
    return mixc((1.0, thump), (0.9, ring), (0.45, click))


def joint(seed: int, steel: bool, gap: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    y = np.zeros(int((gap + 0.4) * SR))
    at(y, joint_hit(rng, steel), 0.0, 1.0)
    at(y, joint_hit(rng, steel), gap, 0.88)
    return finish(y, 0.06)


def whoosh(seed: int, dur: float, lo: float, hi: float, tilt: float = 0.0, rustle: float = 0.0, flutter: float = 0.0,
           thrum: float = 0.0) -> np.ndarray:
    """The car's noise thrown back by an object as it passes: a band of noise under a smooth swell whose band slides
    down a little (Doppler of the reflection)."""
    rng = np.random.default_rng(seed)
    m = int(dur * SR)
    t = np.arange(m) / SR
    x = t / dur
    env = np.sin(np.pi * np.clip(x, 0.0, 1.0)) ** 2.2
    a = shaped(rng, m, lambda f: bp(f, lo * 1.25, hi * 1.2, 1) * (f / 1000.0) ** tilt)
    b = shaped(rng, m, lambda f: bp(f, lo * 0.8, hi * 0.8, 1) * (f / 1000.0) ** tilt)
    y = (a * (1.0 - x) + b * x) * env
    if rustle:
        tr = np.zeros(m)
        k = int(rustle * dur * 900)
        np.add.at(tr, rng.integers(0, m, k), rng.uniform(-1.0, 1.0, k))
        r = np.fft.irfft(np.fft.rfft(tr) * bp(np.maximum(np.fft.rfftfreq(m, 1 / SR), 1.0), 3000.0, 8000.0, 2), m)
        y += rustle * r / rms(r) * env * 0.35
    if flutter:
        y *= 1.0 + flutter * np.sin(2.0 * np.pi * 23.0 * t)
    if thrum:
        y += thrum * decay_sine(rng.uniform(90.0, 110.0), 0.12, dur, 0.0, None, 0.02)[:m] * env
    return finish(y, 0.02)


# ------------------------------------------------------------------------------------------------------------------
# collisions
# ------------------------------------------------------------------------------------------------------------------

def hit_light(seed: int) -> np.ndarray:
    """Bumper against bumper: a short thud and the crack of plastic."""
    rng = np.random.default_rng(seed)
    y = np.zeros(int(0.5 * SR))
    at(y, decay_sine(rng.uniform(95.0, 125.0), 0.04, 0.3, 0.0, rng.uniform(70.0, 85.0), 0.0015), 0.0, 1.0)
    crack = shaped(rng, int(0.12 * SR), lambda f: bp(f, 800.0, 5000.0, 2)) * env_ad(int(0.12 * SR), 0.0004, 0.015)
    at(y, crack, 0.002, 0.7)
    for f0 in (1120.0, 2340.0, 3610.0):
        at(y, decay_sine(f0 * rng.uniform(0.95, 1.05), 0.018, 0.12, rng.uniform(0, 6.28)), 0.003, 0.18)
    return finish(y)


def hit_heavy(seed: int) -> np.ndarray:
    """The body takes the blow: a deep punch and the onset of crumpling."""
    rng = np.random.default_rng(seed)
    y = np.zeros(int(0.8 * SR))
    at(y, decay_sine(rng.uniform(52.0, 60.0), 0.12, 0.7, 0.0, rng.uniform(36.0, 42.0), 0.002), 0.0, 1.0)
    at(y, decay_sine(rng.uniform(140.0, 170.0), 0.05, 0.4, 0.8), 0.0, 0.5)
    crunch = shaped(rng, int(0.5 * SR), lambda f: hp(f, 200.0, 1) * lp(f, 3200.0, 2) * peak(f, 900.0, 1.5, 4.0))
    at(y, crunch * env_ad(len(crunch), 0.001, 0.06), 0.001, 0.75)
    return finish(y, 0.08)


def crunch(seed: int) -> np.ndarray:
    """Sheet metal folding: creaks and clicks, dense at first and thinning out, over a low groan of the body."""
    rng = np.random.default_rng(seed)
    dur = 0.9
    y = np.zeros(int(dur * SR))
    tt = 0.0
    while tt < dur - 0.08:
        f0 = rng.uniform(400.0, 3000.0)
        c = mixc((1.0, decay_sine(f0, rng.uniform(0.004, 0.02), 0.08, rng.uniform(0, 6.28))),
                 (0.6, noise_burst(rng, 0.03, 600.0, 4500.0, rng.uniform(0.002, 0.008))))
        at(y, c, tt, rng.uniform(0.3, 1.0) * np.exp(-tt / 0.35))
        tt += rng.exponential(0.012 + 0.05 * tt)
    m = len(y)
    t = np.arange(m) / SR
    fg = 180.0 + 60.0 * np.exp(-t / 0.2)
    groan = np.sin(2.0 * np.pi * np.cumsum(fg) / SR) * env_ad(m, 0.01, 0.25)
    groan += 0.5 * shaped(rng, m, lambda f: bp(f, 120.0, 600.0, 2)) * env_ad(m, 0.005, 0.2)
    y += 0.45 * groan
    return finish(y, 0.1)


def glass(seed: int) -> np.ndarray:
    """A side window or a headlamp shattering: a bright burst and the tinkling of falling pieces."""
    rng = np.random.default_rng(seed)
    dur = 1.3
    y = np.zeros(int(dur * SR))
    burst = shaped(rng, int(0.2 * SR), lambda f: bp(f, 2000.0, 12000.0, 2)) * env_ad(int(0.2 * SR), 0.0005, 0.03)
    at(y, burst, 0.0, 1.0)
    tt = 0.004
    while tt < dur - 0.06:
        f0 = rng.uniform(3000.0, 9000.0)
        c = mixc((1.0, decay_sine(f0, rng.uniform(0.008, 0.035), 0.12, rng.uniform(0, 6.28), None, 0.0002)),
                 (0.6, decay_sine(f0 * rng.uniform(1.45, 1.8), 0.01, 0.08, rng.uniform(0, 6.28), None, 0.0002)))
        at(y, c, tt, rng.uniform(0.1, 0.6) * np.exp(-tt / 0.45))
        tt += rng.exponential(0.006 + 0.04 * tt)
    return finish(y, 0.1)


def debris(seed: int) -> np.ndarray:
    """Small parts bouncing and scraping on the road after a crash."""
    rng = np.random.default_rng(seed)
    dur = 1.0
    y = np.zeros(int(dur * SR))
    for k in range(16):
        tt = rng.uniform(0.05, dur - 0.1)
        f0 = rng.uniform(600.0, 2600.0)
        c = mixc((1.0, decay_sine(f0, rng.uniform(0.006, 0.02), 0.08, rng.uniform(0, 6.28))),
                 (0.7, noise_burst(rng, 0.04, 500.0, 5000.0, 0.006)))
        at(y, c, tt, rng.uniform(0.2, 0.8))
    return finish(y)


def truck_boom(seed: int) -> np.ndarray:
    """A truck or bus hit: the deep boom of a big steel body, its panels ringing, a rattle."""
    rng = np.random.default_rng(seed)
    dur = 1.3
    y = np.zeros(int(dur * SR))
    at(y, decay_sine(40.0, 0.3, 1.2, 0.0, 31.0, 0.003), 0.0, 1.0)
    for f0, tau, g in ((120.0, 0.35, 0.45), (190.0, 0.3, 0.35), (310.0, 0.22, 0.3), (470.0, 0.18, 0.22), (760.0, 0.12, 0.12)):
        at(y, decay_sine(f0 * rng.uniform(0.97, 1.03), tau, 1.1, rng.uniform(0, 6.28), None, 0.002), 0.002, g)
    rattle = shaped(rng, int(0.6 * SR), lambda f: bp(f, 400.0, 3000.0, 2))
    rattle *= env_ad(len(rattle), 0.004, 0.15) * (1.0 + 0.8 * np.sin(2.0 * np.pi * 31.0 * np.arange(len(rattle)) / SR))
    at(y, rattle, 0.01, 0.35)
    return finish(y, 0.15)


W_BEAM = ((210.0, 0.6, 0.35), (455.0, 0.45, 0.32), (790.0, 0.35, 0.28), (1340.0, 0.25, 0.22), (2150.0, 0.15, 0.15),
          (3400.0, 0.08, 0.08))


def rail_hit(seed: int) -> np.ndarray:
    """The body hits the guardrail: a thud, a hard metal click and the W-beam ringing on (inharmonic modes)."""
    rng = np.random.default_rng(seed)
    dur = 1.0
    y = np.zeros(int(dur * SR))
    at(y, decay_sine(rng.uniform(75.0, 90.0), 0.06, 0.4, 0.0, rng.uniform(55.0, 65.0), 0.0015), 0.0, 1.0)
    at(y, noise_burst(rng, 0.02, 1500.0, 7000.0, 0.0025), 0.0005, 0.6)
    for f0, tau, g in W_BEAM:
        at(y, decay_sine(f0 * rng.uniform(0.98, 1.02), tau * rng.uniform(0.8, 1.1), dur, rng.uniform(0, 6.28), None, 0.0005), 0.001, g)
    scr = shaped(rng, int(0.25 * SR), lambda f: bp(f, 1000.0, 6000.0, 1)) * env_ad(int(0.25 * SR), 0.003, 0.06)
    at(y, scr, 0.004, 0.35)
    return finish(y, 0.12)


def rail_touch(seed: int) -> np.ndarray:
    """A graze along the guardrail: a short scrape in grains and a faint ring."""
    rng = np.random.default_rng(seed)
    dur = 0.4
    m = int(dur * SR)
    y = np.zeros(m)
    scr = shaped(rng, m, lambda f: bp(f, 900.0, 6500.0, 1))
    gr = np.zeros(m)
    k = int(300 * dur)
    np.add.at(gr, rng.integers(0, m, k), rng.uniform(0.3, 1.0, k))
    g = np.fft.irfft(np.fft.rfft(gr) * lp(np.maximum(np.fft.rfftfreq(m, 1 / SR), 1.0), 300.0, 2), m)
    g = np.maximum(g, 0.0)
    y += scr * (0.3 + g / (np.max(g) + 1e-12)) * env_ad(m, 0.01, 0.12)
    for f0, tau, gg in W_BEAM[1:4]:
        at(y, decay_sine(f0 * rng.uniform(0.98, 1.02), tau * 0.6, dur, rng.uniform(0, 6.28), None, 0.002), 0.01, gg * 0.4)
    return finish(y, 0.06)


def post_hit(seed: int) -> np.ndarray:
    """A flexible plastic delineator post knocked by the body: a hollow thwock, the slap, the post whipping back."""
    rng = np.random.default_rng(seed)
    dur = 0.45
    y = np.zeros(int(dur * SR))
    at(y, decay_sine(rng.uniform(360.0, 410.0), 0.03, 0.2, 0.0, None, 0.0006), 0.0, 1.0)
    at(y, decay_sine(rng.uniform(850.0, 980.0), 0.015, 0.1, 1.2, None, 0.0004), 0.0, 0.5)
    at(y, noise_burst(rng, 0.03, 600.0, 4000.0, 0.004), 0.0, 0.6)
    whip = shaped(rng, int(0.25 * SR), lambda f: bp(f, 150.0, 1200.0, 1)) * np.sin(np.pi * np.linspace(0, 1, int(0.25 * SR))) ** 2
    at(y, whip, 0.08, 0.25)
    return finish(y, 0.05)


# id -> (bus, note, [variant functions], extra fields)
def sounds() -> list[tuple]:
    out = []
    out.append(("joint_steel", "MRoad", "Dehnfuge einer Stahlbrücke unter Vorder- und Hinterachse (Fingerfuge klappert, klingt nach); Achsabstand je Variante in gaps_s",
                [lambda g=g, i=i: joint(3101 + i, True, g) for i, g in enumerate(JOINT_GAPS)], {"gaps_s": JOINT_GAPS}))
    out.append(("joint_concrete", "MRoad", "Dehnfuge einer Betonbrücke unter Vorder- und Hinterachse (dumpfer Doppelschlag)",
                [lambda g=g, i=i: joint(3201 + i, False, g) for i, g in enumerate(JOINT_GAPS)], {"gaps_s": JOINT_GAPS}))
    out.append(("pass_post", "MRoad", "Vorbeifahrt an einem Pfosten bei 100 km/h: kurzes Fauchen",
                [lambda: whoosh(3301, 0.18, 700.0, 5000.0, 0.2), lambda: whoosh(3302, 0.2, 650.0, 4600.0, 0.2)], {"ref_kmh": 100.0}))
    out.append(("pass_sign", "MRoad", "Vorbeifahrt an einem Schild bei 100 km/h",
                [lambda: whoosh(3401, 0.25, 450.0, 4500.0, 0.0, flutter=0.15)], {"ref_kmh": 100.0}))
    out.append(("pass_tree", "MRoad", "Vorbeifahrt an einem Baum bei 100 km/h: breites Rauschen mit Laub",
                [lambda: whoosh(3501, 0.45, 300.0, 4000.0, -0.2, rustle=1.0), lambda: whoosh(3502, 0.4, 320.0, 3800.0, -0.2, rustle=0.8)],
                {"ref_kmh": 100.0}))
    out.append(("pass_building", "MRoad", "Vorbeifahrt an einem Gebäude bei 100 km/h: der eigene Klang kommt von der Wand zurück",
                [lambda: whoosh(3601, 0.55, 110.0, 1500.0, -0.4)], {"ref_kmh": 100.0}))
    out.append(("pass_gantry", "MRoad", "Durchfahrt unter einer Schilderbrücke bei 100 km/h: Wummern von oben",
                [lambda: whoosh(3701, 0.6, 80.0, 2500.0, -0.3, thrum=0.6)], {"ref_kmh": 100.0}))
    out.append(("pass_rock", "MRoad", "Vorbeifahrt an Fels bei 100 km/h: harte Reflexion",
                [lambda: whoosh(3801, 0.4, 200.0, 6000.0, 0.1, flutter=0.25)], {"ref_kmh": 100.0}))
    out.append(("hit_light", "MImpact", "Kollision, leicht: Stoßstange an Stoßstange, Plastik knackt",
                [lambda: hit_light(4101), lambda: hit_light(4102)], {}))
    out.append(("hit_heavy", "MImpact", "Kollision, schwer: tiefer Schlag in die Karosserie",
                [lambda: hit_heavy(4201), lambda: hit_heavy(4202)], {}))
    # the layers of a collision start a few milliseconds apart (lead_ms of silence in the file): a collision is a
    # process, and peaks that do not coincide leave the master limiter alone (measured in the worst case)
    out.append(("crunch", "MImpact", "Blech faltet sich: Knarzen und Klicken, ein tiefes Stöhnen der Karosserie (4 ms Vorlauf)",
                [lambda: crunch(4301), lambda: crunch(4302)], {"lead_ms": 4.0}))
    out.append(("glass", "MImpact", "Glas zerspringt und rieselt (9 ms Vorlauf)", [lambda: glass(4401)], {"lead_ms": 9.0}))
    out.append(("debris", "MImpact", "Kleinteile springen über die Fahrbahn (40 ms Vorlauf)", [lambda: debris(4501)], {"lead_ms": 40.0}))
    out.append(("truck_boom", "MImpact", "Lkw oder Bus getroffen: tiefer Schlag eines großen Stahlaufbaus, Bleche klingen, Rasseln",
                [lambda: truck_boom(4601)], {}))
    out.append(("rail_hit", "MImpact", "In die Leitplanke: Schlag, harter Metallklick, die Planke schwingt nach",
                [lambda: rail_hit(4701), lambda: rail_hit(4702)], {}))
    out.append(("rail_touch", "MImpact", "Leitplanke gestreift: kurzes Schleifen, leises Klingen",
                [lambda: rail_touch(4801), lambda: rail_touch(4802)], {}))
    out.append(("post_hit", "MImpact", "Leitpfosten umgefahren: hohles Plopp, Klatschen, der Pfosten schnellt zurück",
                [lambda: post_hit(4901), lambda: post_hit(4902)], {}))
    return out


def build(out: str | None, wav_dir: str | None, log=print) -> None:
    man = ml.Manifest(FOLDER, out)
    man.drop_generator(GENERATOR)
    repo = out is None
    total = 0
    for sid, bus, note, fns, extra in sounds():
        names = []
        lufs_m = []
        previews = []
        for i, fn in enumerate(fns):
            # no mean subtraction: it would leave a DC step in the silent tail that the end fade turns into a thump
            y = np.asarray(fn(), np.float64)
            lead = int(round(float(extra.get("lead_ms", 0.0)) * SR / 1000.0))
            if lead > 0:
                y = np.concatenate([np.zeros(lead), y])
            y = vl.fade_tail(y, 0.01)
            y = y * (PEAK / float(np.max(np.abs(y))))
            # bright one-shots (grinding, rustle) peak between the samples: bring the true peak to -3 dBTP as well
            y = ml.limit_true_peak(y[:, None], -3.0)[:, 0]
            name = f"{sid}_{'abcdef'[i]}.wav" if len(fns) > 1 else f"{sid}.wav"
            ml.write_wav16(man.file(name), y)
            if repo:
                vl.write_wav_import_keep(man.file(name), None)
            names.append(name)
            lufs_m.append(round(float(qc_lib.momentary_max(y, SR)), 2))
            previews.append(y)
            total += os.path.getsize(man.file(name))
        e = man.add(sid, names if len(names) > 1 else names[0], "oneshot", GENERATOR, bus=bus, gain_db=0.0, note=note)
        e["lufs_m"] = lufs_m
        for k, v in extra.items():
            e[k] = v
        if wav_dir:
            os.makedirs(wav_dir, exist_ok=True)
            gap = np.zeros(int(0.35 * SR))
            ml.write_wav16(os.path.join(wav_dir, sid + ".wav"), np.concatenate([np.concatenate([p, gap]) for p in previews]))
        log(f"  {sid:15s} {len(names)} × {np.mean([len(p) for p in previews]) / SR:4.2f} s  momentan {np.mean(lufs_m):6.1f} LUFS  {bus}")
    man.save()
    log(f"sfx_modern: {len(sounds())} Klänge, {total / 1e6:.2f} MB -> {man.dir}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Einmalklänge von Fahrbahn und Aufprall (Profil Modern, AU-C1)")
    ap.add_argument("--out", default=None, help="Ordner statt des Repositorys (ohne Import-Dateien)")
    ap.add_argument("--wav", default=None, help="zusätzlich eine Hörprobe je Klang (Varianten nacheinander) in diesen Ordner")
    args = ap.parse_args()
    build(args.out, args.wav, print if not args.out else (lambda *_a: None))
    return 0


if __name__ == "__main__":
    sys.exit(main())
