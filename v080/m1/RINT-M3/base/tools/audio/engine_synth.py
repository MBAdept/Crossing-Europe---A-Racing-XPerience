#!/usr/bin/env python3
"""Motorklang v2 - offline synthesis of the per-car engine cycle banks.

Contract: docs/motorsound.md (section 1 format, 2 engines, 3 synthesis guidelines, "Umsetzung" = this tool).

Physically inspired model, no additive tones. Per bank (car, rpm, load) a steady engine signal is rendered and
cut into single working cycles (720 deg crank angle):

  1. Gas exchange per cylinder event: 0-D blowdown model. Cylinder volume from the slider-crank, exhaust valve
     lift curve, compressible orifice flow (choked/subsonic, reverse flow when the cylinder pressure at exhaust
     valve opening is below the back pressure - fuel cut on overrun), adiabatic emptying, then piston
     displacement until the valve closes. Real firing order and firing intervals; the pulse amplitude depends on
     load (cylinder pressure at EVO: boost, throttle, combustion or fuel cut) and rpm (valve opening speed vs.
     blowdown time). Cycle-to-cycle scatter of the combustion (stronger at idle), small timing jitter, fixed
     cylinder imbalance and the collector interaction of cylinders that open shortly after a bank mate
     (cross-plane V8: 90/180/180/270 deg per bank).
  2. Weak nonlinear steepening of strong pulses on their way to the first big area change (finite-amplitude
     propagation, c + (gamma+1)/2 u): shock-like fronts at full load and high rpm.
  3. Exhaust system per car as a 1-D acoustic network (plane waves, nodal transfer-matrix method): header
     primaries with the dead branches of the closed ports, collectors, turbine and catalyst/particle filter as
     resistances, pipes with visco-thermal and flow losses, absorptive mufflers, Helmholtz resonators, separate
     V8 banks with an H pipe, open-end radiation of every tailpipe; speed of sound from the gas temperature
     (header hot under load, cooler on overrun). Source -> listener transfer function per cylinder, as impulse
     response. Listener = chase camera 6 m behind the car, 1.6 m high; direct sound + weak road reflection.
  4. Flow noise at the exhaust valve (rasp, through the exhaust system) and turbulent jet noise at the
     tailpipes (driven by the pulsating exit velocity) - the roar/saw at high load and rpm.
  5. Induction: intake flow pulses through runners/plenum/throttle/airbox network (closed throttle on overrun:
     pulsations blocked, throttle hiss instead), radiated at the intake mouth (front-engined: body shadow).
  6. Mechanics: valve seating impacts, injector ticks and combustion excitation of the engine structure
     (modal impulse responses); diesel: combustion knock ("Nageln", pilot + main) ringing in the block.
  Turbo whistle is NOT baked in (runtime layer). Crackles, blow-off, shift crack and engine start are separate
  clips.

Cycle start of every bank = arrival of cylinder 1's exhaust pulse (valve opening) at the listener; the
propagation time (seconds, temperature dependent) is computed from the network's shortest acoustic path.
Periods are whole samples (bank rpm = 120 * sample_rate / period), so all cut points are exact.

Usage (python3 + numpy, ~1-2 min for all cars, deterministic):
  python3 tools/audio/engine_synth.py                    # all five cars -> assets/audio/engines/
  python3 tools/audio/engine_synth.py --car gran_turismo --out /tmp/banks
  python3 tools/audio/engine_synth.py --info              # rpm points, sizes, delays (no rendering)
Reference player / demos / checks: tools/audio/engine_preview.py.
"""
from __future__ import annotations

import argparse
import heapq
import json
import math
import os
import sys
import time
import zlib

import numpy as np

SR = 32000                 # bank sample rate (Hz)
OS = 2                     # oversampling of the pulse sources (steep fronts, then band-limited decimation)
SR_INT = SR * OS
IR_N = 16384               # impulse response length (0.51 s)
R_GAS = 287.0
P_AMB = 1.013e5
T_AMB = 293.0
C_AIR = 343.0
RHO_AIR = 1.2
LISTENER = np.array([0.0, -6.0, 1.6])   # chase camera: 6 m behind the rear bumper, 1.6 m above the road
ROAD_REFLECTION = 0.4                   # pressure reflection factor of the asphalt (low frequencies)
ROAD_REFLECTION_HZ = 2500.0             # ... falling above (porous surface, turbulence)
WALL_LOSS = 2.0                         # wall loss factor over the smooth-pipe Kirchhoff value (roughness, flow)
FLOW_LOSS = 0.07                        # frequency independent loss (Np/m), turbulent mean flow
END_FLOW_R = 0.25                       # flow resistance of an open tailpipe end (x rho c / S), exit jet losses
N_VARIANTS = 8
OVERLAP = 128                           # samples of continuation after each cycle (4 ms)
CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ------------------------------------------------------------------------------------------------
# Profile table: one entry per car. engine/gearbox/layers/mix are written to the bank JSON (contract);
# the rest parameterises the physical model.
#   geo:     bore/stroke/rod (mm), compression ratio, firing order, collector group of each cylinder
#   valves:  crank angles relative to the cylinder's firing TDC (EVO/EVC/IVO/IVC), exhaust valve size
#   op:      operating point model (boost, volumetric efficiency, pressure at EVO, temperatures, scatter)
#   exhaust: acoustic network (see AcousticNet); ports "e<cyl>" are the sources, "rad" ends radiate
#   intake:  same for the induction side, ports "i<cyl>"
#   levels:  component levels in dB relative to the exhaust at the reference point (full load, ref_rpm)
#   mech:    modal sets (Hz) of the engine structure for valve impacts, injector ticks, combustion, knock
# ------------------------------------------------------------------------------------------------


def _ports(n, a, b, length, d, zone, lengths=None):
    """Header primaries: port e<i> -> collector node, one pipe each (optional individual lengths)."""
    out = []
    for i, cyl in enumerate(n):
        ln = lengths[i] if lengths else length
        out.append(("pipe", f"{a}{cyl}", b, ln, d, zone))
    return out


PROFILES: dict = {
    "kompakt": {
        "engine": {"label": "2,0 l Reihenvierzylinder Turbo", "cylinders": 4, "layout": "inline",
                   "fuel": "petrol", "aspiration": "turbo", "idle_rpm": 850, "redline_rpm": 6800,
                   "limiter_rpm": 7000},
        "geo": {"bore": 82.5, "stroke": 92.8, "rod": 144.0, "cr": 9.6, "order": [1, 3, 4, 2],
                "groups": {1: "a", 2: "a", 3: "a", 4: "a"}, "imbalance": 0.03},
        "valves": {"evo": 140.0, "evc": 372.0, "ivo": 352.0, "ivc": 585.0, "ex_d": 28.0, "ex_n": 2,
                   "ex_lift": 10.0, "cd": 0.65},
        "op": {"boost": [1.1, 1500, 2300, 5600, 0.78], "ve": [[800, 0.82], [3000, 0.95], [5500, 0.93],
                                                            [7000, 0.82]],
               "ratio_full": 4.4, "p_im_idle": 0.34, "ratio_idle": 5.6, "p_im_cut": 0.24,
               "cut_rpm": [1000, 1450], "back_turbo": 0.75, "back_flow": 0.12,
               "T_evo_full": 1280.0, "T_evo_idle": 1060.0, "T_evo_cut": 520.0,
               "T_hdr_full": [920.0, 1150.0], "T_hdr_off": [700.0, 790.0],
               "sigma_full": 0.035, "sigma_idle": 0.09, "interact": [0.0, 120.0],
               "nl_len": 0.55, "nl": 0.5},
        "exhaust": (
            _ports([1, 2, 3, 4], "e", "m", 0.16, 0.034, "hdr", [0.15, 0.17, 0.17, 0.15])
            + [("vol", "m", 0.25e-3, "hdr"),
               ("res", "m", "t", 1.1, 0.050, "hdr"),             # turbine
               ("vol", "t", 0.25e-3, "down"),
               ("pipe", "t", "c1", 0.55, 0.060, "down"),
               ("pipe", "c1", "c2", 0.16, 0.115, "down", {"absorb": 0.8}),   # catalyst
               ("pipe", "c2", "g1", 0.30, 0.060, "down"),
               ("pipe", "g1", "g2", 0.22, 0.130, "down", {"absorb": 1.2}),   # particle filter (GPF)
               ("pipe", "g2", "r1", 1.20, 0.058, "mid"),
               ("res", "r1", "r1p", 0.5, 0.058, "mid"),                      # perforate / baffle
               ("pipe", "r1p", "r2", 0.32, 0.120, "mid", {"absorb": 2.5}),   # centre absorber
               ("pipe", "r2", "s1", 1.30, 0.055, "rear"),
               ("res", "s1", "s1p", 0.35, 0.055, "rear"),
               ("pipe", "s1p", "s2", 0.45, 0.190, "rear", {"absorb": 0.7}),  # rear muffler (sport)
               ("pipe", "s2", "tl", 0.28, 0.050, "tail"), ("pipe", "s2", "tr", 0.28, 0.050, "tail"),
               ("rad", "tl", 0.050, (-0.42, 0.05, 0.36)), ("rad", "tr", 0.050, (0.42, 0.05, 0.36))]),
        "crackle_nodes": ["s1", "s2"],
        "intake": {"runner": [0.32, 0.040], "plenum": 2.2e-3, "throttle_d": 0.060, "turbo": True,
                   "duct": [0.9, 0.065], "airbox": 7.0e-3, "snorkel": [0.25, 0.070],
                   "mouth": (0.3, 3.75, 0.70)},
        "engine_pos": (0.0, 3.40, 0.60), "shadow": [0.32, 1500.0],
        "levels": {"rasp": -20.0, "jet": -21.0, "intake": -24.0, "mech": -29.0, "comb": -34.0,
                   "inj": -33.0, "hiss": -36.0, "whoosh": -27.0},
        "mech": {"valve": [[2150, 2950, 3850, 5050, 6400, 8300], 20], "inj": [[6600, 9100, 11600], 9],
                 "comb": [[700, 1080, 1550, 2250], 11], "inj_angle": [420.0]},
        "gearbox": {"kmh_per_1000rpm": [8.0, 12.8, 18.6, 24.6, 31.0, 38.4, 49.0],
                    "final_note": "7-Gang-DSG, 7. Gang als Spargang (130 km/h bei ~2650/min); Vmax im 6. Gang bei ~6000/min",
                    "upshift_rpm": [2100, 6500], "downshift_rpm": [1250, 3900], "shift_time_s": 0.12,
                    "launch_rpm": 3200},
        "layers": {"turbo": {"whistle_hz": [2200, 6200], "level": 0.12, "spool_s": 0.45, "boost_rpm": 1800},
                   "crackle": {"min_rpm": 3000, "rate_hz": 5.0, "duration_s": 1.0, "level": 0.38},
                   "blowoff": {"min_boost": 0.5, "level": 0.45},
                   "limiter": {"cut_cycles": 2, "on_cycles": 3}},
        "clips": {"crackle": "light", "blowoff": "hatch", "shift": "dsg", "start": True},
        "mix": {"loudness_db": -4.0, "off_db": 0.0, "rpm_compress": 0.45, "off_compress": 0.65},
        "ratios": [1.24, 1.15],
    },
    "kombi": {
        "engine": {"label": "2,0 l Reihenvierzylinder Turbodiesel", "cylinders": 4, "layout": "inline",
                   "fuel": "diesel", "aspiration": "turbo", "idle_rpm": 780, "redline_rpm": 4600,
                   "limiter_rpm": 4800},
        "geo": {"bore": 81.0, "stroke": 95.5, "rod": 144.0, "cr": 15.8, "order": [1, 3, 4, 2],
                "groups": {1: "a", 2: "a", 3: "a", 4: "a"}, "imbalance": 0.04},
        "valves": {"evo": 135.0, "evc": 368.0, "ivo": 352.0, "ivc": 570.0, "ex_d": 26.0, "ex_n": 2,
                   "ex_lift": 8.5, "cd": 0.62},
        "op": {"boost": [1.5, 1300, 2000, 3800, 0.82], "ve": [[700, 0.86], [2500, 0.93], [4800, 0.84]],
               "ratio_full": 3.0, "p_im_idle": 1.0, "ratio_idle": 1.55, "p_im_cut": 1.0,
               "cut_rpm": [920, 1300], "back_turbo": 0.85, "back_flow": 0.10,
               "T_evo_full": 1020.0, "T_evo_idle": 720.0, "T_evo_cut": 560.0,
               "T_hdr_full": [760.0, 960.0], "T_hdr_off": [560.0, 640.0],
               "sigma_full": 0.03, "sigma_idle": 0.07, "interact": [0.0, 120.0],
               "nl_len": 0.45, "nl": 0.35, "knock": [0.45, 0.5]},
        "exhaust": (
            _ports([1, 2, 3, 4], "e", "m", 0.20, 0.032, "hdr")
            + [("vol", "m", 0.40e-3, "hdr"),
               ("res", "m", "t", 2.6, 0.050, "hdr"),             # variable geometry turbine
               ("vol", "t", 0.30e-3, "down"),
               ("pipe", "t", "c1", 0.25, 0.060, "down"),
               ("pipe", "c1", "c2", 0.22, 0.150, "down", {"absorb": 1.5}),   # oxidation catalyst
               ("res", "c2", "c3", 0.7, 0.150, "down"),          # wall-flow particle filter
               ("pipe", "c3", "c4", 0.25, 0.150, "down", {"absorb": 3.5}),
               ("pipe", "c4", "x1", 1.50, 0.055, "mid"),
               ("res", "x1", "x1p", 0.8, 0.055, "mid"),
               ("pipe", "x1p", "x2", 0.35, 0.130, "mid", {"absorb": 3.5, "flow": 3.0}),   # centre muffler
               ("pipe", "x2", "y1", 1.30, 0.050, "rear"),
               ("res", "y1", "y1p", 0.8, 0.050, "rear"),
               ("pipe", "y1p", "y2", 0.40, 0.180, "rear", {"absorb": 2.4, "flow": 3.0}),  # rear muffler
               ("helm", "y2", 3.0e-3, 0.12, 0.035, "rear", 0.15),      # anti-drone resonator
               ("pipe", "y2", "tp", 0.35, 0.045, "tail"),
               ("rad", "tp", 0.045, (0.55, 0.0, 0.28), {"shadow": [0.75, 2500.0], "rflow": 0.6})]),   # down-turned
        "crackle_nodes": ["y1"],
        "intake": {"runner": [0.30, 0.038], "plenum": 1.8e-3, "throttle_d": 0.060, "turbo": True,
                   "duct": [1.0, 0.065], "airbox": 8.0e-3, "snorkel": [0.25, 0.070],
                   "mouth": (0.3, 3.95, 0.70), "diesel": True},
        "engine_pos": (0.0, 3.80, 0.60), "shadow": [0.38, 1800.0],
        "levels": {"rasp": -28.0, "jet": -26.0, "intake": -24.0, "mech": -25.0, "comb": -40.0,
                   "inj": -26.0, "knock": -8.5, "hiss": -60.0, "whoosh": -25.0},
        "mech": {"valve": [[1850, 2600, 3500, 4700], 18], "inj": [[4600, 6500, 8600], 8],
                 "comb": [[550, 900, 1300], 10], "knock": [[1050, 1480, 2050, 2620, 3300, 4150, 5200], 16],
                 "inj_angle": [706.0, 716.0]},
        "gearbox": {"kmh_per_1000rpm": [10.2, 15.4, 22.9, 28.9, 37.4, 48.2, 57.4, 72.0],
                    "final_note": "8-Gang-Automatik (Wandler), 130 km/h im 8. Gang bei ~1800/min; Vmax im 7. Gang bei ~4100/min",
                    "upshift_rpm": [1650, 4300], "downshift_rpm": [1100, 2600], "shift_time_s": 0.28,
                    "launch_rpm": 1900},
        "layers": {"turbo": {"whistle_hz": [1500, 4300], "level": 0.13, "spool_s": 0.7, "boost_rpm": 1500},
                   "limiter": {"cut_cycles": 1, "on_cycles": 4}},
        "clips": {"start": True},
        "mix": {"loudness_db": -8.0, "off_db": 0.0, "rpm_compress": 0.45, "off_compress": 0.7},
        "ratios": [1.23, 1.16],
    },
    "limousine": {
        "engine": {"label": "3,0 l Reihensechszylinder Turbo", "cylinders": 6, "layout": "inline",
                   "fuel": "petrol", "aspiration": "turbo", "idle_rpm": 650, "redline_rpm": 7000,
                   "limiter_rpm": 7200},
        "geo": {"bore": 82.0, "stroke": 94.6, "rod": 145.0, "cr": 11.0, "order": [1, 5, 3, 6, 2, 4],
                "groups": {1: "a", 2: "a", 3: "a", 4: "b", 5: "b", 6: "b"}, "imbalance": 0.02},
        "valves": {"evo": 135.0, "evc": 370.0, "ivo": 350.0, "ivc": 590.0, "ex_d": 28.0, "ex_n": 2,
                   "ex_lift": 9.7, "cd": 0.65},
        "op": {"boost": [0.95, 1300, 1900, 6000, 0.8], "ve": [[600, 0.84], [3000, 0.96], [6000, 0.94],
                                                            [7300, 0.84]],
               "ratio_full": 4.4, "p_im_idle": 0.33, "ratio_idle": 5.6, "p_im_cut": 0.24,
               "cut_rpm": [800, 1250], "back_turbo": 0.7, "back_flow": 0.12,
               "T_evo_full": 1260.0, "T_evo_idle": 1040.0, "T_evo_cut": 520.0,
               "T_hdr_full": [900.0, 1140.0], "T_hdr_off": [690.0, 780.0],
               "sigma_full": 0.025, "sigma_idle": 0.07, "interact": [0.04, 120.0],
               "nl_len": 0.55, "nl": 0.5},
        "exhaust": (
            _ports([1, 2, 3], "e", "sa", 0.26, 0.036, "hdr", [0.30, 0.24, 0.27])
            + _ports([4, 5, 6], "e", "sb", 0.26, 0.036, "hdr", [0.27, 0.24, 0.30])
            + [("vol", "sa", 0.2e-3, "hdr"), ("vol", "sb", 0.2e-3, "hdr"),
               ("res", "sa", "t", 1.3, 0.045, "hdr"), ("res", "sb", "t", 1.3, 0.045, "hdr"),  # twin scroll
               ("vol", "t", 0.30e-3, "down"),
               ("pipe", "t", "c1", 0.60, 0.068, "down"),
               ("pipe", "c1", "c2", 0.20, 0.125, "down", {"absorb": 1.0}),
               ("pipe", "c2", "g1", 0.25, 0.068, "down"),
               ("pipe", "g1", "g2", 0.25, 0.140, "down", {"absorb": 1.6}),
               ("pipe", "g2", "x1", 1.40, 0.065, "mid"),
               ("res", "x1", "x1p", 0.7, 0.065, "mid"),
               ("pipe", "x1p", "x2", 0.50, 0.140, "mid", {"absorb": 3.0}),
               ("pipe", "x2", "y", 1.00, 0.060, "rear"),
               ("pipe", "y", "yl", 0.50, 0.055, "rear"), ("pipe", "y", "yr", 0.50, 0.055, "rear"),
               ("res", "yl", "ylp", 0.5, 0.055, "rear"), ("res", "yr", "yrp", 0.5, 0.055, "rear"),
               ("pipe", "ylp", "ml", 0.40, 0.160, "rear", {"absorb": 2.0}),
               ("pipe", "yrp", "mr", 0.40, 0.160, "rear", {"absorb": 2.0}),
               ("pipe", "ml", "tl", 0.25, 0.055, "tail"), ("pipe", "mr", "tr", 0.25, 0.055, "tail"),
               ("rad", "tl", 0.055, (-0.55, 0.05, 0.34)), ("rad", "tr", 0.055, (0.55, 0.05, 0.34))]),
        "crackle_nodes": ["yl", "yr"],
        "intake": {"runner": [0.34, 0.040], "plenum": 3.0e-3, "throttle_d": 0.070, "turbo": True,
                   "duct": [1.0, 0.075], "airbox": 9.0e-3, "snorkel": [0.30, 0.080],
                   "mouth": (-0.3, 3.95, 0.72)},
        "engine_pos": (0.0, 3.50, 0.60), "shadow": [0.32, 1500.0],
        "levels": {"rasp": -19.0, "jet": -20.0, "intake": -25.0, "mech": -31.0, "comb": -36.0,
                   "inj": -35.0, "hiss": -38.0, "whoosh": -28.0},
        "mech": {"valve": [[2300, 3200, 4300, 5600, 7100], 20], "inj": [[7000, 9500, 12000], 9],
                 "comb": [[650, 1000, 1500, 2100], 11], "inj_angle": [425.0]},
        "gearbox": {"kmh_per_1000rpm": [8.3, 13.0, 19.4, 24.2, 31.7, 41.6, 50.6, 65.0],
                    "final_note": "8-Gang-Automatik (Wandler), 130 km/h im 8. Gang bei ~2000/min; Vmax im 6. Gang bei ~5900/min",
                    "upshift_rpm": [1900, 6500], "downshift_rpm": [1150, 3600], "shift_time_s": 0.22,
                    "launch_rpm": 2300},
        "layers": {"turbo": {"whistle_hz": [1900, 5200], "level": 0.06, "spool_s": 0.4, "boost_rpm": 1600},
                   "crackle": {"min_rpm": 3200, "rate_hz": 3.5, "duration_s": 0.9, "level": 0.24},
                   "blowoff": {"min_boost": 0.6, "level": 0.22},
                   "limiter": {"cut_cycles": 2, "on_cycles": 4}},
        "clips": {"crackle": "soft", "blowoff": "soft", "start": True},
        "mix": {"loudness_db": -4.5, "off_db": 0.0, "rpm_compress": 0.45, "off_compress": 0.65},
        "ratios": [1.25, 1.2],
    },
    "sportwagen": {
        "engine": {"label": "4,0 l Sechszylinder-Boxer Saugmotor", "cylinders": 6, "layout": "boxer",
                   "fuel": "petrol", "aspiration": "natural", "idle_rpm": 950, "redline_rpm": 9000,
                   "limiter_rpm": 9200},
        "geo": {"bore": 102.0, "stroke": 81.5, "rod": 128.0, "cr": 13.3, "order": [1, 6, 2, 4, 3, 5],
                "groups": {1: "a", 2: "a", 3: "a", 4: "b", 5: "b", 6: "b"}, "imbalance": 0.025},
        "valves": {"evo": 115.0, "evc": 392.0, "ivo": 330.0, "ivc": 605.0, "ex_d": 35.0, "ex_n": 2,
                   "ex_lift": 11.5, "cd": 0.68},
        "op": {"boost": None, "ve": [[900, 0.80], [3000, 0.88], [5000, 0.95], [7500, 1.02], [8500, 1.0],
                                     [9300, 0.92]],
               "ratio_full": 4.8, "p_im_idle": 0.36, "ratio_idle": 5.4, "p_im_cut": 0.22,
               "cut_rpm": [1150, 1650], "back_turbo": 0.0, "back_flow": 0.18,
               "T_evo_full": 1320.0, "T_evo_idle": 1060.0, "T_evo_cut": 520.0,
               "T_hdr_full": [940.0, 1200.0], "T_hdr_off": [700.0, 800.0],
               "sigma_full": 0.03, "sigma_idle": 0.09, "interact": [0.06, 110.0],
               "nl_len": 1.2, "nl": 0.7},
        "exhaust": (
            _ports([1, 2, 3], "e", "ca", 0.55, 0.042, "hdr")
            + _ports([4, 5, 6], "e", "cb", 0.55, 0.042, "hdr")
            + [("pipe", "ca", "ka", 0.35, 0.060, "down"), ("pipe", "cb", "kb", 0.35, 0.060, "down"),
               ("pipe", "ka", "ka2", 0.15, 0.110, "down", {"absorb": 0.5}),
               ("pipe", "kb", "kb2", 0.15, 0.110, "down", {"absorb": 0.5}),
               ("pipe", "ka2", "ma", 0.40, 0.060, "mid"), ("pipe", "kb2", "mb", 0.48, 0.060, "mid"),
               ("res", "ma", "map", 0.15, 0.060, "rear"), ("res", "mb", "mbp", 0.15, 0.060, "rear"),
               ("pipe", "map", "x", 0.32, 0.070, "rear", {"absorb": 0.6}),   # straight-through, flaps open
               ("pipe", "mbp", "x", 0.32, 0.070, "rear", {"absorb": 0.6}),
               ("vol", "x", 2.2e-3, "rear"),
               ("pipe", "x", "tl", 0.22, 0.070, "tail"), ("pipe", "x", "tr", 0.22, 0.070, "tail"),
               ("rad", "tl", 0.070, (-0.12, 0.05, 0.40)), ("rad", "tr", 0.070, (0.12, 0.05, 0.40))]),
        "crackle_nodes": ["ma", "mb"],
        "intake": {"runner": [0.24, 0.046], "itb": True, "plenum": 0.0, "throttle_d": 0.046, "turbo": False,
                   "duct": [0.45, 0.090], "airbox": 11.0e-3, "snorkel": [0.30, 0.095],
                   "mouth": (0.0, 0.70, 1.05)},
        "engine_pos": (0.0, 0.60, 0.50), "shadow": [0.85, 6000.0],
        "levels": {"rasp": -14.0, "jet": -18.0, "intake": -14.0, "mech": -21.0, "comb": -31.0,
                   "inj": -31.0, "hiss": -33.0, "whoosh": -24.0},
        "mech": {"valve": [[2650, 3600, 4800, 6300, 8100, 10200], 28], "inj": [[7600, 10100, 12600], 9],
                 "comb": [[800, 1300, 1900, 2700], 13], "inj_angle": [430.0]},
        "gearbox": {"kmh_per_1000rpm": [7.4, 12.6, 18.2, 24.4, 30.7, 36.5, 46.5],
                    "final_note": "7-Gang-Doppelkupplung, 130 km/h im 7. Gang bei ~2800/min; Vmax im 5. Gang bei ~8300/min",
                    "upshift_rpm": [2400, 8800], "downshift_rpm": [1500, 5400], "shift_time_s": 0.10,
                    "launch_rpm": 4500},
        "layers": {"crackle": {"min_rpm": 4500, "rate_hz": 6.0, "duration_s": 1.2, "level": 0.7},
                   "limiter": {"cut_cycles": 1, "on_cycles": 2}},
        "clips": {"crackle": "sharp", "shift": "crack", "start": True},
        "mix": {"loudness_db": -1.0, "off_db": -3.0, "rpm_compress": 0.45, "off_compress": 1.0},
        "ratios": [1.24, 1.14],
    },
    "gran_turismo": {
        "engine": {"label": "4,0 l V8 Biturbo (Cross-Plane)", "cylinders": 8, "layout": "v_crossplane",
                   "fuel": "petrol", "aspiration": "turbo", "idle_rpm": 700, "redline_rpm": 7000,
                   "limiter_rpm": 7200},
        "geo": {"bore": 83.0, "stroke": 92.0, "rod": 134.8, "cr": 8.6, "order": [1, 5, 4, 2, 6, 3, 7, 8],
                "groups": {1: "a", 2: "a", 3: "a", 4: "a", 5: "b", 6: "b", 7: "b", 8: "b"},
                "imbalance": 0.06},
        "valves": {"evo": 135.0, "evc": 375.0, "ivo": 348.0, "ivc": 590.0, "ex_d": 28.5, "ex_n": 2,
                   "ex_lift": 9.5, "cd": 0.65},
        "op": {"boost": [1.1, 1700, 2600, 6000, 0.8], "ve": [[600, 0.84], [3000, 0.95], [5500, 0.93],
                                                            [7300, 0.83]],
               "ratio_full": 4.5, "p_im_idle": 0.35, "ratio_idle": 5.6, "p_im_cut": 0.24,
               "cut_rpm": [850, 1300], "back_turbo": 0.6, "back_flow": 0.12,
               "T_evo_full": 1270.0, "T_evo_idle": 1060.0, "T_evo_cut": 520.0,
               "T_hdr_full": [900.0, 1140.0], "T_hdr_off": [690.0, 780.0],
               "sigma_full": 0.04, "sigma_idle": 0.10, "interact": [0.15, 100.0],
               "nl_len": 0.6, "nl": 0.6},
        "exhaust": (
            _ports([1, 2, 3, 4], "e", "ca", 0.30, 0.038, "hdr", [0.26, 0.31, 0.35, 0.28])
            + _ports([5, 6, 7, 8], "e", "cb", 0.30, 0.038, "hdr", [0.28, 0.35, 0.31, 0.26])
            + [("vol", "ca", 0.30e-3, "hdr"), ("vol", "cb", 0.30e-3, "hdr"),
               ("res", "ca", "ta", 0.9, 0.050, "hdr"), ("res", "cb", "tb", 0.9, 0.050, "hdr"),  # turbos
               ("pipe", "ta", "da", 0.75, 0.065, "down"), ("pipe", "tb", "db", 0.75, 0.065, "down"),
               ("pipe", "da", "ka", 0.18, 0.120, "down", {"absorb": 0.8}),
               ("pipe", "db", "kb", 0.18, 0.120, "down", {"absorb": 0.8}),
               ("pipe", "ka", "ha", 0.95, 0.065, "mid"), ("pipe", "kb", "hb", 1.10, 0.065, "mid"),
               ("pipe", "ha", "hb", 0.14, 0.045, "mid"),                       # H pipe
               ("pipe", "ha", "ma", 0.90, 0.065, "rear"), ("pipe", "hb", "mb", 0.90, 0.065, "rear"),
               ("res", "ma", "map", 0.2, 0.065, "rear"), ("res", "mb", "mbp", 0.2, 0.065, "rear"),
               ("pipe", "map", "ma2", 0.45, 0.170, "rear", {"absorb": 0.8}),   # rear mufflers, flaps open
               ("pipe", "mbp", "mb2", 0.45, 0.170, "rear", {"absorb": 0.8}),
               ("pipe", "ma2", "ta1", 0.25, 0.060, "tail"), ("pipe", "ma2", "ta2", 0.25, 0.060, "tail"),
               ("pipe", "mb2", "tb1", 0.25, 0.060, "tail"), ("pipe", "mb2", "tb2", 0.25, 0.060, "tail"),
               ("rad", "ta1", 0.060, (0.62, 0.05, 0.36)), ("rad", "ta2", 0.060, (0.46, 0.05, 0.36)),
               ("rad", "tb1", 0.060, (-0.46, 0.05, 0.36)), ("rad", "tb2", 0.060, (-0.62, 0.05, 0.36))]),
        "crackle_nodes": ["ma", "mb"],
        "intake": {"runner": [0.30, 0.042], "plenum": 3.5e-3, "throttle_d": 0.080, "turbo": True,
                   "duct": [1.1, 0.080], "airbox": 10.0e-3, "snorkel": [0.30, 0.085],
                   "mouth": (0.0, 4.25, 0.72)},
        "engine_pos": (0.0, 3.70, 0.60), "shadow": [0.32, 1500.0],
        "levels": {"rasp": -18.0, "jet": -18.0, "intake": -24.0, "mech": -31.0, "comb": -35.0,
                   "inj": -36.0, "hiss": -38.0, "whoosh": -28.0},
        "mech": {"valve": [[1900, 2700, 3600, 4800, 6200], 18], "inj": [[6000, 8500, 11000], 9],
                 "comb": [[550, 900, 1350, 1900], 10], "inj_angle": [425.0]},
        "gearbox": {"kmh_per_1000rpm": [9.0, 14.5, 21.0, 28.5, 35.5, 43.0, 52.0],
                    "final_note": "7-Gang-Automatik (Nasskupplung), 130 km/h im 7. Gang bei ~2500/min; Vmax im 6. Gang bei ~6300/min",
                    "upshift_rpm": [2000, 6800], "downshift_rpm": [1300, 4200], "shift_time_s": 0.18,
                    "launch_rpm": 2600},
        "layers": {"turbo": {"whistle_hz": [1700, 5000], "level": 0.08, "spool_s": 0.55, "boost_rpm": 2200},
                   "crackle": {"min_rpm": 3200, "rate_hz": 7.0, "duration_s": 1.5, "level": 0.85},
                   "blowoff": {"min_boost": 0.55, "level": 0.4},
                   "limiter": {"cut_cycles": 2, "on_cycles": 3}},
        "clips": {"crackle": "bang", "blowoff": "gt", "shift": "bang", "start": True},
        "mix": {"loudness_db": 0.0, "off_db": 0.0, "rpm_compress": 0.45, "off_compress": 0.6},
        "ratios": [1.25, 1.2],
    },
}


# ------------------------------------------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------------------------------------------

def smoothstep(e0: float, e1: float, x):
    t = np.clip((np.asarray(x, float) - e0) / max(e1 - e0, 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def interp_table(table, x):
    xs = [a for a, _ in table]
    ys = [b for _, b in table]
    return float(np.interp(x, xs, ys))


def fft_size(n: int) -> int:
    """Smallest 2^a * 3^b >= n (fast for numpy's pocketfft)."""
    best = 1 << max(0, (n - 1).bit_length())
    p3 = 1
    while p3 < best:
        p2 = p3
        while p2 < n:
            p2 *= 2
        best = min(best, p2)
        p3 *= 3
    return best


def seed_of(*parts) -> int:
    return zlib.crc32("|".join(str(p) for p in parts).encode()) & 0x7FFFFFFF


def fft_convolve_sum(signals, irs, n_out: int) -> np.ndarray:
    """sum_i conv(signals[i], irs[i])[:n_out] via one inverse FFT."""
    n = fft_size(n_out + max(len(h) for h in irs))
    acc = None
    for x, h in zip(signals, irs):
        if x is None:
            continue
        spec = np.fft.rfft(x, n) * np.fft.rfft(h, n)
        acc = spec if acc is None else acc + spec
    if acc is None:
        return np.zeros(n_out)
    return np.fft.irfft(acc, n)[:n_out]


def spectral_filter(x: np.ndarray, gain_fn) -> np.ndarray:
    """Filter in the frequency domain: gain_fn(freqs) -> real (zero phase) or complex gain."""
    n = fft_size(len(x) + 4096)
    spec = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec * gain_fn(f), n)[:len(x)]


def highpass_gain(f, fc: float, order: int = 4):
    r = (np.asarray(f, float) / fc) ** (2 * order)
    return np.sqrt(r / (1.0 + r))


def lowpass_gain(f, fc: float, order: int = 2):
    return 1.0 / np.sqrt(1.0 + (np.asarray(f, float) / fc) ** (2 * order))


def band_noise(rng, n: int, lo: float, hi: float, slope_db: float = 0.0) -> np.ndarray:
    """Gaussian noise band-limited to [lo, hi] (soft edges), spectral tilt in dB/octave, unit RMS."""
    x = rng.standard_normal(n)
    nn = fft_size(n)
    spec = np.fft.rfft(x, nn)
    f = np.maximum(np.fft.rfftfreq(nn, 1.0 / SR), 1.0)
    g = highpass_gain(f, lo, 2) * lowpass_gain(f, hi, 2) * (f / 1000.0) ** (slope_db / 6.02)
    y = np.fft.irfft(spec * g, nn)[:n]
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def decimate(x: np.ndarray, factor: int = OS) -> np.ndarray:
    """Band-limited decimation (FFT, soft roll-off 14..15.6 kHz at the output rate)."""
    n_out = len(x) // factor
    n = n_out * factor
    spec = np.fft.rfft(x[:n])
    keep = n_out // 2 + 1
    f = np.fft.rfftfreq(n_out, 1.0 / SR)
    taper = np.clip((15600.0 - f) / 1600.0, 0.0, 1.0)
    return np.fft.irfft(spec[:keep] * taper, n_out) / factor


# ------------------------------------------------------------------------------------------------
# Gas properties, radiation and the acoustic network (plane waves, nodal admittance method)
# ------------------------------------------------------------------------------------------------

def gas(T: float, gamma: float = 1.35, p: float = 1.08e5):
    """Speed of sound (m/s), density (kg/m^3), dynamic viscosity (Pa s) of exhaust gas or air at T (K)."""
    c = math.sqrt(gamma * R_GAS * T)
    rho = p / (R_GAS * T)
    mu = 1.81e-5 * (T / 293.0) ** 0.7
    return c, rho, mu


def dist(a, b) -> float:
    return float(np.linalg.norm(np.asarray(a, float) - np.asarray(b, float)))


def radiation_impedance(f, d: float):
    """Open (unflanged) pipe end into ambient air: end-correction mass in parallel with a resistance.
    Low frequencies: Re = Z0 (ka)^2/4, Im = Z0 0.61 ka; high frequencies -> 1.5 Z0."""
    a = d / 2.0
    z0 = RHO_AIR * C_AIR / (math.pi * a * a)
    x = 0.6133 * 2.0 * np.pi * f * a / C_AIR
    rinf = 1.5
    return z0 * (1j * x * rinf) / (rinf + 1j * x)


def listener_path(f, pos, shadow=None):
    """Free field from a monopole at pos to the listener: direct sound + road reflection (image source,
    reflection factor falling with frequency) + optional body shadow [gain, corner Hz] (-3 dB/oct above).
    Returns the complex factor g (1/m) and the direct distance."""
    w = 2.0 * np.pi * f
    pos = np.asarray(pos, float)
    r1 = dist(pos, LISTENER)
    r2 = dist(pos * np.array([1.0, 1.0, -1.0]), LISTENER)
    refl = ROAD_REFLECTION / (1.0 + 1j * f / ROAD_REFLECTION_HZ)
    g = np.exp(-1j * w * r1 / C_AIR) / r1 + refl * np.exp(-1j * w * r2 / C_AIR) / r2
    if shadow:
        g = g * shadow[0] * (1.0 + 1j * f / shadow[1]) ** -0.5
    return g, r1


class AcousticNet:
    """1-D acoustic network of an exhaust or intake system.

    Elements (node names are strings; port nodes e<cyl>/i<cyl> carry the sources):
      ("pipe", a, b, length_m, diam_m, zone[, {"absorb": Np/m at 1 kHz, "aexp": 0.8, "loss": factor}])
      ("res",  a, b, r, diam_m, zone)        series resistance r * rho c / S (turbine, filter, throttle)
      ("vol",  a, volume_m3, zone)            compliance to ground (manifold, volute, plenum, box)
      ("helm", a, volume_m3, neck_l, neck_d, zone, r)   Helmholtz side resonator with neck damping r
      ("leak", a, r, diam_m, zone)            resistive admittance to ground
      ("rad",  a, diam_m, (x, y, z)[, {"shadow": [gain, Hz]}])   open end radiating to the listener
    Every element's gas state comes from its temperature zone. Solved per frequency: Y p = U_inj."""

    def __init__(self, elements, zone_T: dict, gamma: float):
        self.elements = list(elements)
        self.zone_T = zone_T
        self.gamma = gamma
        self.index: dict = {}
        for el in self.elements:
            names = [el[1], el[2]] if el[0] in ("pipe", "res") else [el[1]]
            for nm in names:
                self.index.setdefault(nm, len(self.index))

    def _gas(self, zone):
        return gas(self.zone_T[zone], self.gamma)

    def z0(self, d: float, zone) -> float:
        c, rho, _ = self._gas(zone)
        return rho * c / (math.pi * d * d / 4.0)

    def _wavenumber(self, f, w, c: float, d: float, zone, opts: dict):
        """Complex wavenumber with causal losses: boundary-layer and absorptive losses grow with sqrt(f) and
        carry the matching dispersion ((1 - j) alpha, Kramers-Kronig pair), the turbulent flow loss is
        frequency independent. Acausal loss models would put precursors before the wave front."""
        _, rho, mu = self._gas(zone)
        nu = mu / rho
        wall = np.sqrt(np.pi * f * nu) / (d / 2.0 * c) * (1.0 + (self.gamma - 1.0) / math.sqrt(0.71))
        a_sqrt = opts.get("loss", 1.0) * WALL_LOSS * wall + opts.get("absorb", 0.0) * np.sqrt(f / 1000.0)
        return w / c + (1.0 - 1j) * a_sqrt - 1j * FLOW_LOSS * opts.get("flow", 1.0)

    def solve(self, freqs: np.ndarray, inject: list, chunk: int = 1024) -> np.ndarray:
        """Complex pressure at the listener (Pa) per unit volume velocity (m^3/s) injected at each node of
        `inject`. Returns H of shape (len(freqs), len(inject))."""
        nn = len(self.index)
        m = len(inject)
        out = np.zeros((len(freqs), m), complex)
        for s in range(0, len(freqs), chunk):
            f = np.maximum(freqs[s:s + chunk], 0.5)
            w = 2.0 * np.pi * f
            Y = np.zeros((len(f), nn, nn), complex)
            ends = []
            for el in self.elements:
                kind = el[0]
                if kind == "pipe":
                    a, b = self.index[el[1]], self.index[el[2]]
                    ln, d, zone = el[3], el[4], el[5]
                    opts = el[6] if len(el) > 6 else {}
                    c, rho, _ = self._gas(zone)
                    zc = rho * c / (math.pi * d * d / 4.0)
                    k = self._wavenumber(f, w, c, d, zone, opts)
                    sn, cs = np.sin(k * ln), np.cos(k * ln)
                    y = 1.0 / (1j * zc * sn)
                    Y[:, a, a] += cs * y
                    Y[:, b, b] += cs * y
                    Y[:, a, b] -= y
                    Y[:, b, a] -= y
                elif kind == "res":
                    a, b = self.index[el[1]], self.index[el[2]]
                    y = 1.0 / (el[3] * self.z0(el[4], el[5]))
                    Y[:, a, a] += y
                    Y[:, b, b] += y
                    Y[:, a, b] -= y
                    Y[:, b, a] -= y
                elif kind == "vol":
                    a = self.index[el[1]]
                    c, rho, _ = self._gas(el[3])
                    Y[:, a, a] += 1j * w * el[2] / (rho * c * c)
                elif kind == "helm":
                    a = self.index[el[1]]
                    vol, nl, nd, zone, r = el[2], el[3], el[4], el[5], el[6]
                    c, rho, _ = self._gas(zone)
                    sn = math.pi * nd * nd / 4.0
                    mass = rho * (nl + 0.85 * nd) / sn
                    z = 1j * w * mass + r * rho * c / sn + 1.0 / (1j * w * vol / (rho * c * c))
                    Y[:, a, a] += 1.0 / z
                elif kind == "leak":
                    a = self.index[el[1]]
                    Y[:, a, a] += 1.0 / (el[2] * self.z0(el[3], el[4]))
                elif kind == "rad":
                    # open end: radiation impedance + flow resistance of the exit jet (vortex shedding with
                    # mean flow absorbs low frequencies and damps the muffler/tailpipe Helmholtz mode);
                    # radiated is the volume velocity through the radiation impedance
                    a = self.index[el[1]]
                    opts = el[4] if len(el) > 4 else {}
                    zr = radiation_impedance(f, el[2])
                    zf = opts.get("rflow", END_FLOW_R) * RHO_AIR * C_AIR / (math.pi * el[2] ** 2 / 4.0)
                    Y[:, a, a] += 1.0 / (zr + zf)
                    g, _ = listener_path(f, el[3], opts.get("shadow"))
                    ends.append((a, zr + zf, g))
            E = np.zeros((len(f), nn, m), complex)
            for j, name in enumerate(inject):
                E[:, self.index[name], j] = 1.0
            P = np.linalg.solve(Y, E)
            for a, zr, g in ends:
                out[s:s + chunk] += P[:, a, :] * (1j * w * RHO_AIR / (4.0 * np.pi) * g / zr)[:, None]
        if freqs[0] == 0.0:
            out[0] = 0.0
        return out

    def path_delay(self, src: str) -> float:
        """Shortest acoustic travel time (s) from src to the listener (pipes L/c, lumped elements 0)."""
        adj: dict = {}
        for el in self.elements:
            if el[0] == "pipe":
                c, _, _ = self._gas(el[5])
                wgt = el[3] / c
            elif el[0] == "res":
                wgt = 0.0
            else:
                continue
            adj.setdefault(el[1], []).append((el[2], wgt))
            adj.setdefault(el[2], []).append((el[1], wgt))
        best = {src: 0.0}
        heap = [(0.0, src)]
        while heap:
            dd, u = heapq.heappop(heap)
            if dd > best.get(u, 1e9):
                continue
            for v, wgt in adj.get(u, []):
                if dd + wgt < best.get(v, 1e9):
                    best[v] = dd + wgt
                    heapq.heappush(heap, (dd + wgt, v))
        res = 1e9
        for el in self.elements:
            if el[0] == "rad" and el[1] in best:
                res = min(res, best[el[1]] + dist(el[3], LISTENER) / C_AIR)
        return res


def impulse_response(H: np.ndarray, fade: float = 0.25) -> np.ndarray:
    """Real impulse response (IR_N samples) from a one-sided spectrum on the IR_N grid, faded out at the end."""
    h = np.fft.irfft(H, IR_N)
    nf = int(IR_N * fade)
    h[-nf:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, nf))
    return h


# ------------------------------------------------------------------------------------------------
# Crank kinematics, valve lift, 0-D blowdown
# ------------------------------------------------------------------------------------------------

class CylinderGeometry:
    def __init__(self, geo: dict, valves: dict):
        self.bore = geo["bore"] / 1000.0
        self.stroke = geo["stroke"] / 1000.0
        self.rod = geo["rod"] / 1000.0
        self.area = math.pi * self.bore ** 2 / 4.0
        self.crank = self.stroke / 2.0
        self.vd = self.area * self.stroke
        self.vc = self.vd / (geo["cr"] - 1.0)
        self.valves = valves
        d = valves["ex_d"] / 1000.0
        self.ex_curtain = valves["ex_n"] * math.pi * d
        self.ex_throat = 0.9 * valves["ex_n"] * math.pi * d * d / 4.0
        self.ex_lift = valves["ex_lift"] / 1000.0

    def volume(self, th_deg):
        th = np.radians(th_deg)
        s = self.crank * (1.0 - np.cos(th)) + self.rod - np.sqrt(self.rod ** 2 - (self.crank * np.sin(th)) ** 2)
        return self.vc + self.area * s

    def dvolume(self, th_deg):
        """dV/dtheta in m^3 per degree."""
        th = np.radians(th_deg)
        sn, cs = np.sin(th), np.cos(th)
        ds = self.crank * sn + self.crank ** 2 * sn * cs / np.sqrt(self.rod ** 2 - (self.crank * sn) ** 2)
        return self.area * ds * math.pi / 180.0

    def exhaust_area(self, th_deg):
        v = self.valves
        x = np.clip((np.asarray(th_deg) - v["evo"]) / (v["evc"] - v["evo"]), 0.0, 1.0)
        lift = self.ex_lift * np.sin(np.pi * x) ** 1.3
        return np.minimum(self.ex_curtain * lift, self.ex_throat)


def _psi(r, g: float, r_lin: float = 0.985):
    """Compressible orifice flow function, choked below the critical ratio, linearised near r = 1
    (keeps the stiff equilibrium of the displacement phase stable)."""
    rc = (2.0 / (g + 1.0)) ** (g / (g - 1.0))
    psi_c = math.sqrt(g) * (2.0 / (g + 1.0)) ** ((g + 1.0) / (2.0 * (g - 1.0)))

    def sub(rr):
        return np.sqrt(np.maximum(2.0 * g / (g - 1.0) * (rr ** (2.0 / g) - rr ** ((g + 1.0) / g)), 0.0))

    psi_l = float(sub(np.array(r_lin)))
    rr = np.clip(r, rc, r_lin)
    return np.where(r <= rc, psi_c, np.where(r < r_lin, sub(rr), psi_l * (1.0 - r) / (1.0 - r_lin)))


def exhaust_mass_flow(cyl: CylinderGeometry, rpm, p_evo, T_evo, p_back, T_back, z_port, gamma: float = 1.33,
                      dth: float | None = None):
    """Exhaust valve mass flow (kg/s, + = out of the cylinder) from EVO to EVC for every event.
    The port is the mouth of the primary pipe, its pressure follows the flow: p_port = p_back + z_port * mdot
    (z_port = c / S of the primary: the pressure jump of a wave entering a pipe). This limits the blowdown
    peak (the header pulse itself) and the backflow into the cylinder when the cylinder pressure at EVO is
    below the back pressure (fuel cut). Solved per step with Newton iterations; explicit midpoint
    integration over crank angle. Inputs are arrays over events (rpm, p in Pa, T in K, z_port in 1/(m s)).
    Returns (theta grid in deg, mdot array (n_events, n_theta))."""
    v = cyl.valves
    om = 6.0 * np.asarray(rpm, float)
    if dth is None:     # time step <= 0.12 ms for the slowest event (stiff near-equilibrium valve flow)
        dth = float(np.clip(float(np.min(om)) * 1.2e-4, 0.05, 0.5))
    th = np.arange(v["evo"], v["evc"] + 1e-9, dth)
    thm = th + 0.5 * dth
    V, dV, A = cyl.volume(th), cyl.dvolume(th), cyl.exhaust_area(th)
    Vm, dVm, Am = cyl.volume(thm), cyl.dvolume(thm), cyl.exhaust_area(thm)
    cd = v["cd"]
    p = np.asarray(p_evo, float).copy()
    pb = np.asarray(p_back, float)
    tb = np.asarray(T_back, float)
    zm = np.asarray(z_port, float)
    m = p * V[0] / (R_GAS * np.asarray(T_evo, float))
    out = np.zeros((len(p), len(th)))

    def orifice(pc, T, pport, area):
        outward = pc >= pport
        pu = np.where(outward, pc, pport)
        pdn = np.where(outward, pport, pc)
        tu = np.where(outward, T, tb)
        md = cd * area * pu / np.sqrt(R_GAS * tu) * _psi(pdn / pu, gamma)
        return np.where(outward, md, -md)

    def flow(pp, mm, vol, area, guess):
        T = pp * vol / (mm * R_GAS)
        md = guess
        for _ in range(2):
            pport = np.maximum(pb + zm * md, 0.1 * pb)
            f0 = orifice(pp, T, pport, area)
            f1 = orifice(pp, T, pport + 100.0, area)
            slope = (f1 - f0) / 100.0 * zm          # d orifice / d mdot  (<= 0)
            md = md - (md - f0) / (1.0 - slope)
        return md, T

    def deriv(pp, vol, dvol, md, T):
        tf = np.where(md >= 0.0, T, tb)
        return -(gamma / vol) * (R_GAS * tf * md / om + pp * dvol), -md / om

    md_prev = np.zeros(len(p))
    for j in range(len(th) - 1):
        md0, T0 = flow(p, m, V[j], A[j], md_prev)
        dp0, dm0 = deriv(p, V[j], dV[j], md0, T0)
        p1 = np.maximum(p + 0.5 * dth * dp0, 2e3)
        m1 = np.maximum(m + 0.5 * dth * dm0, 1e-9)
        md1, T1 = flow(p1, m1, Vm[j], Am[j], md0)
        dp1, dm1 = deriv(p1, Vm[j], dVm[j], md1, T1)
        out[:, j] = md0
        md_prev = md1
        p = np.maximum(p + dth * dp1, 2e3)
        m = np.maximum(m + dth * dm1, 1e-9)
    return th, out


def modal_ir(freqs, q: float, rng, dur: float = 0.08, tilt_db: float = -2.0, click: float = 0.25):
    """Impulse response of a ringing structure: decaying modes (+-2 % detuned, random phase and weight,
    spectral tilt in dB/octave) plus a short broadband impact click. Unit energy."""
    t = np.arange(int(dur * SR)) / SR
    h = np.zeros_like(t)
    for f in freqs:
        fj = f * (1.0 + 0.02 * rng.standard_normal())
        if fj >= SR * 0.47:
            continue
        amp = (fj / 1000.0) ** (tilt_db / 6.02) * (0.5 + rng.random())
        h += amp * np.exp(-t * np.pi * fj / q) * np.sin(2.0 * np.pi * fj * t + rng.uniform(0.0, 2.0 * np.pi))
    n = max(4, int(0.0005 * SR))
    h[:n] += click * np.sqrt(np.mean(h * h)) * 6.0 * rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 3.0))
    return h / np.sqrt(np.sum(h * h))


def impulse_train(times, amps, n: int) -> np.ndarray:
    """Impulses at fractional sample times (seconds) with linear split between neighbouring samples."""
    x = np.zeros(n + 2)
    pos = np.asarray(times) * SR
    i = np.floor(pos).astype(int)
    fr = pos - i
    ok = (i >= 0) & (i < n)
    np.add.at(x, i[ok], amps[ok] * (1.0 - fr[ok]))
    np.add.at(x, i[ok] + 1, amps[ok] * fr[ok])
    return x[:n]


# ------------------------------------------------------------------------------------------------
# Car model: operating points, transfer functions, events, sound components
# ------------------------------------------------------------------------------------------------

EXH_ZONES = {"hdr": 1.0, "down": 0.85, "mid": 0.62, "rear": 0.45, "tail": 0.38}   # share of T_hdr - T_amb
INT_ZONES = {"amb": T_AMB, "warm": T_AMB + 30.0, "boost": T_AMB + 60.0}
PORT_LEAK = 6.0          # port admittance to ground (x Z0 of the primary): absorption by the open cylinder
NL_BETA = 1.17           # (gamma + 1) / 2
COMPONENTS = ["exh", "rasp", "jet", "intake", "hiss", "whoosh", "mech", "inj", "comb", "knock"]


class CarModel:
    def __init__(self, car: str):
        self.car = car
        self.p = PROFILES[car]
        self.eng = self.p["engine"]
        self.geo = self.p["geo"]
        self.valves = self.p["valves"]
        self.op = self.p["op"]
        self.cyl = CylinderGeometry(self.geo, self.valves)
        self.n = self.eng["cylinders"]
        self.cyls = list(range(1, self.n + 1))
        self.phi = {c: k * 720.0 / self.n for k, c in enumerate(self.geo["order"])}
        self.diesel = self.eng["fuel"] == "diesel"
        self.turbo = self.eng["aspiration"] == "turbo"
        rng = np.random.default_rng(seed_of(car, "imbalance"))
        imb = rng.standard_normal(self.n) * self.geo["imbalance"]
        self.imbalance = {c: float(imb[i] - imb.mean()) for i, c in enumerate(self.cyls)}
        self.ref_rpm = 0.5 * self.eng["redline_rpm"]
        self.ex_elements = list(self.p["exhaust"])
        self.primary = {}
        for el in self.p["exhaust"]:
            if el[0] == "pipe" and el[1].startswith("e") and el[1][1:].isdigit():
                self.ex_elements.append(("leak", el[1], PORT_LEAK, el[4], el[5]))
                self.primary[int(el[1][1:])] = (el[3], el[4])
        self.tail_area = sum(math.pi * el[2] ** 2 / 4.0 for el in self.p["exhaust"] if el[0] == "rad")
        self.tail_d = max(el[2] for el in self.p["exhaust"] if el[0] == "rad")
        self.tail_r = float(np.mean([dist(el[3], LISTENER) for el in self.p["exhaust"] if el[0] == "rad"]))
        mrng = np.random.default_rng(seed_of(car, "mech"))
        self.mech_ir = {k: modal_ir(v[0], v[1], mrng, click=0.35 if k in ("mech", "inj") else 0.15)
                        for k, v in (("mech", self.p["mech"]["valve"]), ("inj", self.p["mech"]["inj"]),
                                     ("comb", self.p["mech"]["comb"]))}
        if "knock" in self.p["mech"]:
            self.mech_ir["knock"] = modal_ir(*self.p["mech"]["knock"], mrng, dur=0.05, tilt_db=0.0, click=0.25)
        f = np.fft.rfftfreq(IR_N, 1.0 / SR)
        g, _ = listener_path(f, self.p["engine_pos"], self.p["shadow"])
        path = impulse_response(g * 6.0)[:4096]      # engine bay -> listener (levels are calibrated)
        self.mech_full = {k: np.convolve(h, path) for k, h in self.mech_ir.items()}
        self._tf_cache: dict = {}
        self.cal: dict | None = None

    # --- operating point -------------------------------------------------------------------------
    def boost(self, rpm: float) -> float:
        b = self.op["boost"]
        if not b:
            return 0.0
        bmax, r0, r1, rt, taper = b
        x = bmax * float(smoothstep(r0, r1, rpm))
        if rpm > rt:
            x *= 1.0 - (1.0 - taper) * float(smoothstep(rt, self.eng["limiter_rpm"], rpm))
        return x

    def operating_point(self, rpm: float, load: str) -> dict:
        """Thermodynamic state of a steady bank. load "on" = full throttle, "off" = closed throttle:
        idle combustion near idle, fuel cut above op.cut_rpm (diesel: no fuel, no throttle)."""
        op, eng = self.op, self.eng
        idle, red = eng["idle_rpm"], eng["redline_rpm"]
        xr = rpm / red
        ve = interp_table(op["ve"], rpm)
        knock = op.get("knock", [0.0, 0.0])
        if load == "on":
            boost = self.boost(rpm)
            p_im = (1.0 if self.turbo else 0.97) + boost
            p_evo = p_im * ve * op["ratio_full"]
            p_base = p_im * ve * 0.92
            fire = 1.0
            T_evo = op["T_evo_full"] + 100.0 * xr
            sigma = op["sigma_full"] * (1.0 + 1.5 * (1.0 - float(smoothstep(idle, 2.0 * idle, rpm))))
            T_hdr = float(np.interp(xr, [0.0, 1.0], op["T_hdr_full"]))
            p_back = 1.05 + op["back_turbo"] * boost + op["back_flow"] * xr * xr
            air = p_im * ve
            knock_amp = knock[1]
        else:
            fire = 1.0 - float(smoothstep(op["cut_rpm"][0], op["cut_rpm"][1], rpm))
            boost = 0.0
            p_fire = op["p_im_idle"] * op["ratio_idle"]
            p_base = op["p_im_cut"] * 0.92
            p_evo = p_base + fire * (p_fire - p_base)
            T_evo = op["T_evo_cut"] + fire * (op["T_evo_idle"] - op["T_evo_cut"])
            sigma = op["sigma_idle"] * fire + 0.012 * (1.0 - fire)
            T_hdr = float(np.interp(xr, [0.0, 1.0], op["T_hdr_off"]))
            p_back = 1.03 + 0.3 * op["back_flow"] * xr * xr
            air = op["p_im_cut"] + fire * (op["p_im_idle"] - op["p_im_cut"])
            knock_amp = knock[0] * fire
            if 0.0 < fire < 1.0:
                # fuel cut recovery is cylinder-selective: each event either fires (idle combustion) or not,
                # with probability `fire` (see _finish_events) - no half-strength pulses that would flip polarity
                return self._op_dict(rpm, load, boost, p_base + (p_fire - p_base), p_base, op["T_evo_idle"],
                                     op["sigma_idle"], T_hdr, p_back, fire, knock[0], air, ve,
                                     selective=True, T_cut=op["T_evo_cut"])
        return self._op_dict(rpm, load, boost, p_evo, p_base, T_evo, sigma, T_hdr, p_back, fire, knock_amp, air, ve)

    def _op_dict(self, rpm, load, boost, p_evo, p_base, T_evo, sigma, T_hdr, p_back, fire, knock_amp, air, ve,
                 selective=False, T_cut=None) -> dict:
        T_tail = T_AMB + (T_hdr - T_AMB) * EXH_ZONES["tail"]
        mass_flow = air * 1e5 / (R_GAS * (T_AMB + 30.0)) * self.cyl.vd * self.n * rpm / 120.0 * (
            1.0 + (0.0 if fire < 0.5 and load == "off" else 0.07))
        v_tail = mass_flow / (P_AMB / (R_GAS * T_tail)) / self.tail_area
        return {"rpm": rpm, "load": load, "boost": boost, "p_evo": p_evo * 1e5, "p_base": p_base * 1e5,
                "T_evo": T_evo, "sigma": sigma, "T_hdr": T_hdr, "p_back": p_back * 1e5,
                "T_back": 0.8 * T_hdr, "fire": fire, "knock": knock_amp, "air": air, "ve": ve,
                "v_tail": v_tail, "hiss": (0.0 if (load == "on" or self.diesel) else 1.0),
                "selective": selective, "T_cut": T_cut}

    # --- transfer functions --------------------------------------------------------------------
    def exhaust_tf(self, T_hdr: float) -> dict:
        key = int(round(T_hdr / 25.0))
        if key in self._tf_cache:
            return self._tf_cache[key]
        T = key * 25.0
        zones = {z: T_AMB + (T - T_AMB) * fz for z, fz in EXH_ZONES.items()}
        net = AcousticNet(self.ex_elements, zones, 1.35)
        inject = [f"e{c}" for c in self.cyls] + list(self.p["crackle_nodes"])
        H = net.solve(np.fft.rfftfreq(IR_N, 1.0 / SR), inject)
        hs = [impulse_response(H[:, j]) for j in range(len(inject))]
        res = {"h": hs[:self.n], "h_crackle": hs[self.n:], "D": net.path_delay("e1"),
               "c_hdr": gas(T, 1.35)[0], "rho_hdr": 1.15e5 / (R_GAS * T), "T": T}
        self._tf_cache[key] = res
        return res

    def intake_elements(self, load: str):
        it = self.p["intake"]
        rl, rd = it["runner"]
        thr = 0.08 if (load == "on" or it.get("diesel")) else 45.0
        els = []
        if it.get("itb"):
            for c in self.cyls:
                els += [("pipe", f"i{c}", f"r{c}", rl, rd, "amb"),
                        ("res", f"r{c}", "ab", thr, it["throttle_d"], "amb")]
            hiss_node = "ab"
        else:
            for c in self.cyls:
                els.append(("pipe", f"i{c}", "pl", rl, rd, "warm"))
            els += [("vol", "pl", it["plenum"], "warm"), ("res", "pl", "th", thr, it["throttle_d"], "warm")]
            hiss_node = "th"
            up = "th"
            if it.get("turbo"):
                els += [("pipe", "th", "ic", 0.6, 0.065, "boost"), ("vol", "ic", 2.0e-3, "boost"),
                        ("res", "ic", "ic2", 1.0, 0.065, "boost"), ("vol", "ic2", 2.0e-3, "boost"),  # cooler core
                        ("pipe", "ic2", "co", 0.5, 0.060, "boost"),
                        ("res", "co", "ci", 8.0, 0.060, "amb"), ("vol", "ci", 0.3e-3, "amb")]   # compressor
                up = "ci"
            els.append(("pipe", up, "ab", it["duct"][0], it["duct"][1], "amb"))
        # airbox: clean side, filter element (flow resistance damps the box/snorkel Helmholtz mode),
        # dirty side, snorkel, intake mouth
        sl, sd = it["snorkel"]
        els += [("vol", "ab", 0.5 * it["airbox"], "amb"), ("res", "ab", "ad", 1.5, sd, "amb"),
                ("vol", "ad", 0.5 * it["airbox"], "amb"),
                ("pipe", "ad", "mo", sl, sd, "amb", {"flow": 4.0}),
                ("rad", "mo", sd, it["mouth"], {"shadow": self.p["shadow"], "rflow": 0.6})]
        for c in self.cyls:
            els.append(("leak", f"i{c}", PORT_LEAK, rd, "amb"))
        whoosh_node = "ci" if (it.get("turbo") and not it.get("itb")) else "ab"
        return els, hiss_node, whoosh_node

    def intake_tf(self, load: str) -> dict:
        key = ("in", load)
        if key in self._tf_cache:
            return self._tf_cache[key]
        els, hiss_node, whoosh_node = self.intake_elements(load)
        net = AcousticNet(els, INT_ZONES, 1.4)
        inject = [f"i{c}" for c in self.cyls] + [hiss_node, whoosh_node]
        H = net.solve(np.fft.rfftfreq(IR_N, 1.0 / SR), inject)
        hs = [impulse_response(H[:, j]) for j in range(len(inject))]
        res = {"h": hs[:self.n], "h_hiss": hs[self.n], "h_whoosh": hs[self.n + 1]}
        self._tf_cache[key] = res
        return res

    # --- events ----------------------------------------------------------------------------------
    def steady_events(self, opp: dict, n_cycles: int, D: float, rng) -> dict:
        """Cylinder events of a steady bank. Time 0 = arrival of cylinder 1's exhaust pulse (cycle 0) at
        the listener: cylinder 1 opens its exhaust valve at -D."""
        rpm = opp["rpm"]
        om = 6.0 * rpm
        t0 = -D - self.valves["evo"] / om
        cyl, tf = [], []
        for c in range(-2, n_cycles + 1):
            for k in self.cyls:
                cyl.append(k)
                tf.append(t0 + (c * 720.0 + self.phi[k]) / om)
        cyl = np.array(cyl)
        tf = np.array(tf)
        return self._finish_events(cyl, tf, np.full(len(cyl), rpm), opp, rng)

    def _finish_events(self, cyl, t_fire, rpm, opp: dict, rng, fire=None) -> dict:
        """Per-event scatter: combustion strength (cycle-to-cycle, cylinder imbalance, collector
        interaction), timing jitter (not cylinder 1), back pressure."""
        n = len(cyl)
        om = 6.0 * rpm
        idle_share = 1.0 - smoothstep(self.eng["idle_rpm"], 2.2 * self.eng["idle_rpm"], rpm)
        fire_e = np.full(n, opp["fire"]) if fire is None else np.asarray(fire, float)
        if opp.get("selective") and fire is None:
            fire_e = (rng.random(n) < opp["fire"]).astype(float)
        s = 1.0 + np.array([self.imbalance[k] for k in cyl]) + opp["sigma"] * rng.standard_normal(n)
        s = np.clip(s, 0.55, 1.45)
        jit = 0.0025 * (1.0 + 3.0 * idle_share) * (720.0 / self.n) / om * rng.standard_normal(n)
        jit[cyl == 1] = 0.0
        t_evo = t_fire + self.valves["evo"] / om + jit
        # collector interaction: a cylinder opening shortly after a mate of the same collector meets the
        # mate's pressure wave (higher back pressure, more residual gas -> weaker pulse). The residual gas
        # pushed back during valve overlap matters most near idle (high intake vacuum, slow crank): that
        # is the lope of a cross-plane V8 (90/180/180/270 deg per bank).
        kappa, th_d = self.op["interact"]
        kappa = kappa * (1.0 + 2.5 * idle_share)
        pb = np.full(n, opp["p_back"])
        if np.any(kappa > 0.0):
            groups = np.array([self.geo["groups"][k] for k in cyl])
            for g in set(groups.tolist()):
                idx = np.where(groups == g)[0]
                idx = idx[np.argsort(t_evo[idx])]
                dth = np.diff(t_evo[idx]) * om[idx[1:]]
                fac = np.exp(-dth / th_d)
                kap = kappa[idx[1:]]
                s[idx[1:]] *= 1.0 - kap * fac
                pb[idx[1:]] *= 1.0 + 1.5 * kap * fac
        p_base = np.broadcast_to(np.asarray(opp["p_base"], float), (n,)).copy()
        p_full = np.broadcast_to(np.asarray(opp["p_evo"], float), (n,))
        T_evo = np.asarray(opp["T_evo"], float) * (1.0 + 0.25 * (s - 1.0) * fire_e)
        knock = np.broadcast_to(np.asarray(opp["knock"], float), (n,)).copy()
        if opp.get("selective") and fire is None:     # fired events: idle combustion, others: fuel cut
            p_full = p_base + (p_full - p_base) * fire_e
            T_evo = opp["T_cut"] + (T_evo - opp["T_cut"]) * fire_e
            s = np.where(fire_e > 0.0, s, 1.0 + 0.012 * rng.standard_normal(n))
            knock = knock * fire_e
        p_evo = p_base + (p_full - p_base) * s
        return {"cyl": cyl, "t_fire": t_fire + jit, "t_evo": t_evo, "rpm": rpm, "om": om, "s": s,
                "p_evo": p_evo, "T_evo": T_evo, "p_back": pb, "fire": fire_e, "p_base": p_base,
                "knock": knock}

    # --- sound components --------------------------------------------------------------------------
    def exhaust_sources(self, ev: dict, opp: dict, tf: dict, n_len: int) -> list:
        """Volume velocity at every exhaust port (m^3/s) at SR, with nonlinear steepening (oversampled)."""
        z_port = np.array([tf["c_hdr"] / (math.pi * self.primary[k][1] ** 2 / 4.0) for k in ev["cyl"]])
        th, md = exhaust_mass_flow(self.cyl, ev["rpm"], ev["p_evo"], ev["T_evo"], ev["p_back"],
                                   np.full(len(ev["rpm"]), opp["T_back"]), z_port)
        n_int = n_len * OS
        bufs = {k: np.zeros(n_int) for k in self.cyls}
        rel = th - th[0]
        for i in range(len(ev["cyl"])):
            tt = ev["t_evo"][i] + rel / ev["om"][i]
            a = int(math.ceil(tt[0] * SR_INT))
            b = int(math.floor(tt[-1] * SR_INT))
            a0, b0 = max(a, 0), min(b, n_int - 1)
            if b0 < a0:
                continue
            grid = np.arange(a0, b0 + 1) / SR_INT
            bufs[ev["cyl"][i]][a0:b0 + 1] += np.interp(grid, tt, md[i])
        out = []
        c = tf["c_hdr"]
        tgrid = np.arange(n_int) / SR_INT
        for k in self.cyls:
            q = bufs[k] / tf["rho_hdr"]
            nl = self.op["nl"]
            if nl > 0.0:
                area = math.pi * self.primary[k][1] ** 2 / 4.0
                shift = nl * NL_BETA * self.op["nl_len"] * (q / area) / (c * c)
                q = np.interp(tgrid, np.maximum.accumulate(tgrid - shift), q)
            out.append(decimate(q))
        return out

    def render_components(self, ev: dict, opp: dict, n_len: int, rng, crank_t0: float = 0.0) -> dict:
        """All sound components (Pa at the listener, before calibration) for the given events."""
        tf = self.exhaust_tf(opp["T_hdr"])
        cal = self.cal or {}
        parts = {}
        q = self.exhaust_sources(ev, opp, tf, n_len)
        parts["exh"] = fft_convolve_sum(q, tf["h"], n_len)
        # valve flow noise (rasp): turbulence in the blowdown jet, grows with the flow velocity
        q_ref = cal.get("q_ref", max(float(np.max(x)) for x in q) + 1e-12)
        noise = []
        for x in q:
            env = (np.maximum(x, 0.0) / q_ref) ** 1.5
            noise.append(band_noise(rng, n_len, 350.0, 9000.0, -1.5) * env)
        parts["rasp"] = fft_convolve_sum(noise, tf["h"], n_len)
        # tailpipe jet noise: driven by the pulsating exit velocity (mean flow + acoustic flow)
        v_ref = cal.get("v_ref", opp["v_tail"])
        y = parts["exh"]
        nn = fft_size(n_len + 4096)
        f = np.fft.rfftfreq(nn, 1.0 / SR)
        u_ac = np.fft.irfft(np.fft.rfft(y, nn) / (2j * np.pi * f + 2.0 * np.pi * 12.0), nn)[:n_len]
        u_ac *= 4.0 * np.pi * self.tail_r / RHO_AIR / self.tail_area
        v = np.maximum(opp["v_tail"] + u_ac, 0.0)
        fpk = float(np.clip(0.25 * max(opp["v_tail"], 5.0) / self.tail_d, 120.0, 2500.0))
        parts["jet"] = band_noise(rng, n_len, 0.5 * fpk, 10.0 * fpk, -1.0) * (v / v_ref) ** 2.0
        # induction
        itf = self.intake_tf(opp["load"])
        parts["intake"] = fft_convolve_sum(self.intake_sources(ev, opp, n_len), itf["h"], n_len)
        hiss = band_noise(rng, n_len, 1400.0, 7500.0) * opp["hiss"] * (0.25 + 0.75 * (1.0 - opp["fire"])) * (
            0.6 + 0.4 * opp["rpm"] / self.eng["redline_rpm"])
        parts["hiss"] = fft_convolve_sum([hiss], [itf["h_hiss"]], n_len)
        air_ref = cal.get("air_ref", opp["air"] * self.ref_rpm)
        wh = (opp["air"] * opp["rpm"] / air_ref) ** 2 * (1.0 if opp["load"] == "on" else 0.15)
        parts["whoosh"] = fft_convolve_sum([band_noise(rng, n_len, 250.0, 5000.0, -2.0) * wh],
                                           [itf["h_whoosh"]], n_len)
        # mechanics
        for k, x in self.mech_sources(ev, opp, n_len, rng).items():
            parts[k] = fft_convolve_sum([x], [self.mech_full[k]], n_len)
        return parts

    # --- steady banks ------------------------------------------------------------------------------
    def render_steady(self, period: int, load: str, n_var: int = N_VARIANTS, overlap: int = OVERLAP,
                      seed=None) -> dict:
        """Renders a steady signal at exactly `period` samples per cycle; cycle c starts at c * period."""
        rpm = 120.0 * SR / period
        opp = self.operating_point(rpm, load)
        tf = self.exhaust_tf(opp["T_hdr"])
        n_warm = int(math.ceil(0.30 * SR / period)) + 1
        n_total = n_warm + n_var + 1
        n_len = n_total * period + overlap + 16
        rng = np.random.default_rng(seed_of(self.car, period, load) if seed is None else seed)
        ev = self.steady_events(opp, n_total, tf["D"], rng)
        parts = self.render_components(ev, opp, n_len, rng)
        return {"rpm": rpm, "period": period, "load": load, "opp": opp, "parts": parts, "n_warm": n_warm,
                "n_var": n_var, "overlap": overlap, "D": tf["D"], "T_hdr": tf["T"]}

    def mix(self, parts: dict) -> np.ndarray:
        k = self.cal["k"]
        y = sum(k[c] * parts[c] for c in COMPONENTS if c in parts and k.get(c, 0.0) != 0.0)
        return spectral_filter(y, lambda f: highpass_gain(f, 22.0, 2))

    def calibrate(self, log=None) -> dict:
        """Component levels: the exhaust is normalised to RMS 1 at the reference point (full load, ref_rpm);
        every other component gets its profile level (dB re exhaust) as the mean over four full-load rpm
        points (0.35/0.55/0.75/0.92 x redline), the overrun hiss over two overrun points - one rpm alone
        would make the calibration depend on where resonances happen to fall."""
        if self.cal is not None:
            return self.cal
        red = self.eng["redline_rpm"]
        P = int(round(120.0 * SR / self.ref_rpm))
        rpm = 120.0 * SR / P
        on = self.operating_point(rpm, "on")
        tf = self.exhaust_tf(on["T_hdr"])
        rng = np.random.default_rng(seed_of(self.car, "cal"))
        ev = self.steady_events(on, 6, tf["D"], rng)
        q = self.exhaust_sources(ev, on, tf, 8 * P)
        self.cal = {"q_ref": float(np.mean([np.percentile(x, 99.5) for x in q])), "v_ref": on["v_tail"],
                    "air_ref": on["air"] * rpm, "k": {c: 1.0 for c in COMPONENTS}}

        def rms(res, comp):
            x = res["parts"].get(comp)
            if x is None:
                return 0.0
            a = res["n_warm"] * res["period"]
            seg = x[a:a + res["n_var"] * res["period"]]
            return float(np.sqrt(np.mean(seg * seg)))

        ref = self.render_steady(P, "on", 6, OVERLAP, seed=seed_of(self.car, "cal_ref"))
        k = {"exh": 1.0 / rms(ref, "exh")}
        ratios: dict = {c: [] for c in COMPONENTS[1:]}
        for frac, load in ((0.35, "on"), (0.55, "on"), (0.75, "on"), (0.92, "on"), (0.45, "off"), (0.8, "off")):
            Pc = int(round(120.0 * SR / (frac * red)))
            res = self.render_steady(Pc, load, 4, OVERLAP, seed=seed_of(self.car, "cal", frac, load))
            e = rms(res, "exh")
            for c in COMPONENTS[1:]:
                if (c == "hiss") == (load == "off"):
                    r = rms(res, c)
                    if r > 0.0 and e > 0.0:
                        ratios[c].append(20.0 * math.log10(r / e))
        lv = self.p["levels"]
        for c in COMPONENTS[1:]:
            if c in lv and ratios[c]:
                k[c] = k["exh"] * 10.0 ** ((lv[c] - float(np.mean(ratios[c]))) / 20.0)
            else:
                k[c] = 0.0
        self.cal["k"] = k
        if log:
            log("  Kalibrierung: " + ", ".join("%s %.0f dB" % (c, lv[c]) for c in COMPONENTS[1:] if k.get(c)))
        return self.cal

    def intake_sources(self, ev: dict, opp: dict, n_len: int) -> list:
        """Volume velocity at every intake port (inflow negative): smooth suction pulse from IVO to IVC with
        the late, abrupt end of the ram flow."""
        v = self.valves
        dur_deg = v["ivc"] - v["ivo"]
        x = np.linspace(0.0, 1.0, 256)
        shape = np.sin(np.pi * x ** 0.85) ** 1.4
        mean_shape = float(np.mean(shape))
        bufs = {k: np.zeros(n_len) for k in self.cyls}
        vind = self.cyl.vd * min(opp["ve"], 1.05)
        for i in range(len(ev["cyl"])):
            om = ev["om"][i]
            t_a = ev["t_fire"][i] + v["ivo"] / om
            t_b = t_a + dur_deg / om
            qpk = vind * om / (dur_deg * mean_shape)
            a = max(int(math.ceil(t_a * SR)), 0)
            b = min(int(math.floor(t_b * SR)), n_len - 1)
            if b < a:
                continue
            tt = (np.arange(a, b + 1) / SR - t_a) / (t_b - t_a)
            bufs[ev["cyl"][i]][a:b + 1] -= qpk * np.interp(tt, x, shape)
        return [bufs[k] for k in self.cyls]

    def mech_sources(self, ev: dict, opp: dict, n_len: int, rng) -> dict:
        """Impulse trains for valve seating, injector ticks, combustion excitation and diesel knock."""
        v = self.valves
        om = ev["om"]
        tfire = ev["t_fire"]
        ne = len(tfire)
        rpmf = ev["rpm"] / 3000.0
        fuel = ev["fire"] > 0.05
        out = {}
        tv = np.concatenate([tfire + v["evc"] / om, tfire + v["ivc"] / om])
        av = np.concatenate([rpmf, rpmf]) ** 1.2 * (1.0 + 0.15 * rng.standard_normal(2 * ne))
        out["mech"] = impulse_train(tv, av, n_len)
        ti, ai = [], []
        for ang in self.p["mech"]["inj_angle"]:
            a = ang - 720.0 if ang > 360.0 else ang
            ti.append(tfire + a / om)
            ai.append(fuel * (1.0 + 0.1 * rng.standard_normal(ne)) * (0.6 if (self.diesel and ang < 710) else 1.0))
        out["inj"] = impulse_train(np.concatenate(ti), np.concatenate(ai), n_len)
        dp = np.maximum(ev["p_evo"] - ev["p_base"], 0.0) / 1e5
        out["comb"] = impulse_train(tfire + 12.0 / om, dp * rpmf ** 0.3 * (1.0 + 0.1 * rng.standard_normal(ne)), n_len)
        if "knock" in self.mech_ir:
            kn = ev["knock"] * ev["fire"] * (ev["rpm"] / 2000.0) ** 0.3
            tk = np.concatenate([tfire - 3.0 / om, tfire + 5.0 / om])
            ak = np.concatenate([0.45 * kn * (1.0 + 0.3 * rng.standard_normal(ne)),
                                 kn * (1.0 + 0.25 * rng.standard_normal(ne))])
            out["knock"] = impulse_train(tk, np.maximum(ak, 0.0), n_len)
        return out

    # --- time-varying rendering (engine start) ---------------------------------------------------
    def render_trajectory(self, rpm_t: np.ndarray, fire_t: np.ndarray, load_t: np.ndarray, rng,
                          theta0: float = 0.0) -> np.ndarray:
        """Renders an arbitrary rpm trajectory (arrays at SR): crank angle integrated from rpm, one event
        per cylinder firing TDC with the operating point blended between closed throttle and full load by
        load_t, combustion enabled by fire_t (0 = cranking without fuel)."""
        n_len = len(rpm_t)
        theta = theta0 + np.concatenate([[0.0], np.cumsum(6.0 * rpm_t[:-1] / SR)])
        t = np.arange(n_len) / SR
        cyl, t_ev = [], []
        r0 = max(float(rpm_t[0]), 60.0)
        for c in range(-1, int(theta[-1] // 720.0) + 2):
            for k in self.cyls:
                ang = c * 720.0 + self.phi[k]
                if theta[0] - 150.0 <= ang <= theta[-1]:
                    cyl.append(k)
                    t_ev.append((ang - theta[0]) / (6.0 * r0) if ang < theta[0]
                                else float(np.interp(ang, theta, t)))
        cyl = np.array(cyl)
        t_ev = np.array(t_ev)
        idx = np.clip((t_ev * SR).astype(int), 0, n_len - 1)
        rpm_e, fire_e, load_e = np.maximum(rpm_t[idx], 60.0), fire_t[idx], load_t[idx]
        keys = ("p_evo", "p_base", "T_evo", "sigma", "p_back", "T_back", "knock")
        ev_op = {k: np.zeros(len(cyl)) for k in keys}
        for i in range(len(cyl)):
            off = self.operating_point(rpm_e[i], "off")
            on = self.operating_point(rpm_e[i], "on")
            if fire_e[i] > 0.0:      # idle combustion, scaled by fire (first, still weak firings)
                p_idle = self.op["p_im_idle"] * self.op["ratio_idle"] * 1e5
                base = dict(off, p_evo=off["p_base"] + fire_e[i] * (p_idle - off["p_base"]),
                            T_evo=self.op["T_evo_idle"], sigma=self.op["sigma_idle"],
                            knock=self.op.get("knock", [0.0, 0.0])[0])
            else:                    # cranking: compression and expansion without fuel
                base = dict(off, p_evo=off["p_base"], knock=0.0)
            w = load_e[i]
            for k in keys:
                ev_op[k][i] = (1.0 - w) * base[k] + w * on[k]
        opp = self.operating_point(float(np.median(rpm_t)), "off")
        opp["T_back"] = float(np.mean(ev_op["T_back"]))
        opp["fire"] = 1.0
        ev = self._finish_events(cyl, t_ev, rpm_e, {**ev_op, "fire": fire_e}, rng, fire=fire_e)
        return self.mix(self.render_components(ev, opp, n_len, rng))


# === BANKS ===

def rpm_points(eng: dict, ratios) -> list:
    """Bank periods (samples, descending = rpm ascending): idle .. limiter, neighbour ratio from ratios[0]
    at idle down to ratios[1] at the limiter (denser where cycles are short and cheap). Whole-sample
    periods; the first point is at or below idle, the last at or above the limiter."""
    idle, lim = float(eng["idle_rpm"]), float(eng["limiter_rpm"])
    pts = [idle]
    while pts[-1] < lim:
        x = math.log(pts[-1] / idle) / math.log(lim / idle)
        nxt = pts[-1] * (ratios[0] + (ratios[1] - ratios[0]) * x)
        if nxt * 1.07 >= lim:
            nxt = lim
        pts.append(nxt)
    periods = [int(math.ceil(120.0 * SR / pts[0]))]
    periods += [int(round(120.0 * SR / r)) for r in pts[1:-1]]
    periods.append(int(math.floor(120.0 * SR / lim)))
    for i in range(1, len(periods) - 1):        # whole samples must not push a step above 1.25
        while periods[i - 1] / periods[i] > 1.25:
            periods[i] += 1
    rpms = [120.0 * SR / p for p in periods]
    for a, b in zip(rpms, rpms[1:]):
        assert b / a <= 1.25 + 1e-9, (a, b)
    return periods


def k_weighted_power(x: np.ndarray) -> float:
    """Mean power after K weighting (ITU-R BS.1770: high-pass ~38 Hz + high shelf +4 dB above ~1.7 kHz),
    applied as magnitude response in the frequency domain."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    tot = float(np.sum(spec))
    if tot <= 0.0:
        return 0.0
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1e-3)
    r = f / 38.0
    hp = r ** 4 / ((1.0 - r ** 2) ** 2 + (r / 0.5) ** 2)
    s = (f / 1681.0) ** 2
    shelf = (1.0 + 10.0 ** (4.0 / 10.0) * s) / (1.0 + s)
    return float(np.sum(spec * hp * shelf) / tot * np.mean(x * x))


def loudness_db(x: np.ndarray) -> float:
    """K-weighted level (dBFS, like LUFS without gating) - loudness of loud, full sounds."""
    return 10.0 * math.log10(max(k_weighted_power(x), 1e-20))


def level_a_db(x: np.ndarray) -> float:
    """A-weighted level (dBFS) - used for the rpm/load shaping inside a car: it ranks the quiet,
    bass-heavy idle and overrun sounds the way they are heard at moderate levels."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    tot = float(np.sum(spec))
    if tot <= 0.0:
        return -200.0
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1.0)
    ra = 12194.0 ** 2 * f ** 4 / ((f ** 2 + 20.6 ** 2) * np.sqrt((f ** 2 + 107.7 ** 2) * (f ** 2 + 737.9 ** 2))
                                  * (f ** 2 + 12194.0 ** 2)) * 10.0 ** (2.0 / 20.0)
    return 10.0 * math.log10(max(float(np.sum(spec * ra * ra)) / tot * float(np.mean(x * x)), 1e-20))


def shape_levels(banks: list, ref_rpm: float, mix: dict) -> None:
    """Per-bank gains (bank["gain"]): the measured A-weighted levels are fitted by a smooth curve over
    log rpm per load; the rpm dependence of the curve is compressed (mix.rpm_compress), the overrun-to-load
    distance as well (mix.off_compress), and half of each bank's deviation from the smooth curve
    (resonances) is kept. Keeps the physical shape but removes jumps that would wobble during sweeps."""
    keep = 0.5
    for load in ("on", "off"):
        bs = [b for b in banks if b["load"] == load]
        x = np.log([b["rpm"] for b in bs])
        y = np.array([b["lev"] for b in bs])
        for b, fv in zip(bs, np.polyval(np.polyfit(x, y, 2), x)):
            b["fit"] = float(fv)
    on = {b["period"]: b for b in banks if b["load"] == "on"}
    ref = min(on.values(), key=lambda b: abs(math.log(b["rpm"] / ref_rpm)))
    for b in banks:
        bon = on[b["period"]]
        t_on = ref["fit"] + mix["rpm_compress"] * (bon["fit"] - ref["fit"])
        if b["load"] == "on":
            target = t_on + keep * (b["lev"] - b["fit"])
        else:
            target = t_on + mix["off_compress"] * (b["fit"] - bon["fit"]) + keep * (b["lev"] - b["fit"])
        b["gain"] = 10.0 ** ((target - b["lev"]) / 20.0)


# ------------------------------------------------------------------------------------------------
# One-shot clips: crackles (afterfire in the exhaust), blow-off, shift crack, engine start
# ------------------------------------------------------------------------------------------------

CRACKLE_STYLES = {
    # amplitude, rise (ms), decay (ms), turbulent share, pops per burst, gap between pops (ms), share of
    # single pops
    "light": {"amp": (0.25, 0.7), "rise": (0.15, 0.35), "decay": (0.6, 1.6), "noise": 0.6, "burst": (2, 7),
              "gap": (4.0, 22.0), "single": 0.3},
    "soft": {"amp": (0.2, 0.55), "rise": (0.5, 1.0), "decay": (2.0, 4.5), "noise": 0.4, "burst": (1, 3),
             "gap": (10.0, 40.0), "single": 0.6},
    "sharp": {"amp": (0.5, 1.0), "rise": (0.08, 0.2), "decay": (0.7, 2.0), "noise": 0.7, "burst": (1, 6),
              "gap": (4.0, 18.0), "single": 0.45},
    "bang": {"amp": (0.6, 1.0), "rise": (0.25, 0.6), "decay": (2.5, 6.0), "noise": 0.5, "burst": (1, 5),
             "gap": (8.0, 35.0), "single": 0.5},
}


def afterfire(rng, n: int, t0: float, amp: float, rise_ms: float, decay_ms: float, noise: float) -> np.ndarray:
    """Volume velocity of one afterfire (unburnt mixture igniting in the hot exhaust): fast expansion with
    turbulent, noisy burning."""
    t = np.arange(n) / SR - t0
    tt = np.maximum(t, 0.0)
    env = (1.0 - np.exp(-tt / (rise_ms * 1e-3))) * np.exp(-tt / (decay_ms * 1e-3)) * (t >= 0.0)
    return amp * env * (1.0 + noise * band_noise(rng, n, 200.0, 6000.0))


def _trim_clip(y: np.ndarray, floor_db: float = -50.0, max_s: float = 0.0) -> np.ndarray:
    env = np.abs(y)
    first = max(int(np.argmax(env > env.max() * 0.01)) - int(0.002 * SR), 0)
    last = len(y) - int(np.argmax(env[::-1] > env.max() * 10.0 ** (floor_db / 20.0)))
    if max_s:
        last = min(last, first + int(max_s * SR))
    y = y[first:last].copy()
    fade = max(16, min(len(y) // 4, int(0.02 * SR)))
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    y[:16] *= np.linspace(0.0, 1.0, 16)
    return y


def crackle_clips(model: CarModel, style: str, n_clips: int = 8) -> list:
    """Overrun crackle/pop variants: single afterfires and bursts, injected at the muffler nodes of the
    exhaust network (so they ring with the car's own tailpipes)."""
    st = CRACKLE_STYLES[style]
    tf = model.exhaust_tf(float(np.mean(model.op["T_hdr_off"])) + 60.0)
    rng = np.random.default_rng(seed_of(model.car, "crackle"))
    clips = []
    for i in range(n_clips):
        single = i == 0 or rng.random() < st["single"]
        npops = 1 if single else int(rng.integers(st["burst"][0], st["burst"][1] + 1))
        n = int(0.45 * SR)
        src = [np.zeros(n) for _ in tf["h_crackle"]]
        t = 0.004
        for _ in range(npops):
            a = rng.uniform(*st["amp"]) * (1.0 if single else 0.55)
            src[int(rng.integers(len(src)))] += afterfire(rng, n, t, a, rng.uniform(*st["rise"]),
                                                          rng.uniform(*st["decay"]), st["noise"])
            t += rng.uniform(*st["gap"]) * 1e-3
        y = fft_convolve_sum(src, tf["h_crackle"], n)
        clips.append(_trim_clip(spectral_filter(y, lambda f: highpass_gain(f, 40.0, 2))))
    return clips


def shift_clips(model: CarModel, style: str) -> list:
    """Upshift under full load with ignition cut: the cut cycles' mixture fires in the exhaust."""
    tf = model.exhaust_tf(float(np.mean(model.op["T_hdr_full"])))
    rng = np.random.default_rng(seed_of(model.car, "shift"))
    out = []
    for v in range(2):
        n = int(0.35 * SR)
        src = [np.zeros(n) for _ in tf["h_crackle"]]
        if style == "dsg":       # the DSG "blat": a quick burst of partial misfires, then one pop
            t = 0.003
            for k in range(3 + v):
                src[k % len(src)] += afterfire(rng, n, t, rng.uniform(0.35, 0.6), 0.2, 1.4, 0.6)
                t += rng.uniform(7.0, 11.0) * 1e-3
            src[-1] += afterfire(rng, n, t + 0.004, 1.0, 0.25, 2.2, 0.5)
        elif style == "crack":   # PDK: one sharp crack and a small echo pop
            src[0] += afterfire(rng, n, 0.003, 1.0, 0.08, 1.2, 0.5)
            src[-1] += afterfire(rng, n, 0.003 + rng.uniform(0.018, 0.03), 0.4, 0.12, 1.0, 0.7)
        else:                    # "bang": a deep bang with a short burble
            src[0] += afterfire(rng, n, 0.003, 1.0, 0.4, 5.0, 0.4)
            src[-1] += afterfire(rng, n, 0.005 + 0.002 * v, 0.9, 0.4, 5.0, 0.4)
            t = 0.05
            for _ in range(2 + v):
                src[int(rng.integers(len(src)))] += afterfire(rng, n, t, 0.3, 0.3, 2.0, 0.6)
                t += rng.uniform(0.012, 0.03)
        y = fft_convolve_sum(src, tf["h_crackle"], n)
        out.append(_trim_clip(spectral_filter(y, lambda f: highpass_gain(f, 40.0, 2)), -55.0, 0.28))
    return out


def blowoff_clips(model: CarModel, style: str) -> list:
    """Diverter / blow-off valve: compressed charge air escaping through a valve. Turbulent jet noise whose
    band falls with the decaying pressure, a short low thump of the pressure wave in the intake; the hot
    hatch's valve flutters a little (compressor surge)."""
    rng = np.random.default_rng(seed_of(model.car, "blowoff"))
    f0, f1, tau, flutter = {"hatch": (5200.0, 1700.0, 0.26, 0.5), "soft": (4200.0, 1500.0, 0.2, 0.0),
                            "gt": (4600.0, 1300.0, 0.32, 0.25)}[style]
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    fc = f1 + (f0 - f1) * np.exp(-t / (tau * 0.8))
    env = (1.0 - np.exp(-t / 0.006)) * np.exp(-t / tau)
    if flutter:
        env *= 1.0 - flutter * np.exp(-t / 0.12) * (0.5 + 0.5 * np.cos(2.0 * np.pi * 21.0 * t))
    y = np.zeros(n)            # time-varying two-pole band-pass (Q ~ 1.3), sample by sample
    y1 = y2 = 0.0
    for i in range(n):
        w = 2.0 * math.pi * fc[i] / SR
        r = math.exp(-w / 2.6)
        y0 = (1.0 - r) * noise[i] + 2.0 * r * math.cos(w) * y1 - r * r * y2
        y[i] = y0
        y2, y1 = y1, y0
    y = y / (np.sqrt(np.mean(y[:int(0.1 * SR)] ** 2)) + 1e-12) * env
    y += 2.5 * np.sin(2.0 * np.pi * 95.0 * t) * np.exp(-t / 0.035) * (1.0 - np.exp(-t / 0.004))
    y = spectral_filter(y, lambda f: highpass_gain(f, 60.0, 2))
    y[-int(0.05 * SR):] *= np.linspace(1.0, 0.0, int(0.05 * SR))
    return [y]


def start_clip(model: CarModel) -> np.ndarray:
    """Starter motor cranking (compression strokes slow the crank), first fires, flare, settle to idle."""
    rng = np.random.default_rng(seed_of(model.car, "start"))
    idle = model.eng["idle_rpm"]
    n = int(1.75 * SR)
    t = np.arange(n) / SR
    t_fire = 0.55 if model.diesel else 0.62
    flare = (1.45 if model.diesel else 1.7) * idle
    crank = 200.0 if model.diesel else 230.0
    rpm = np.zeros(n)
    theta = 0.0
    for i in range(n):          # crank speed with compression dips, integrated over crank angle
        ti = t[i]
        if ti < 0.06:
            base = crank * (0.3 + 0.7 * ti / 0.06)     # pinion engaged, motor spinning up
        elif ti < t_fire:
            base = crank
        elif ti < t_fire + 0.45:
            x = (ti - t_fire) / 0.45
            base = crank + (flare - crank) * (1.0 - (1.0 - x) ** 2)
        else:
            x = min((ti - t_fire - 0.45) / 0.55, 3.0)
            base = idle + (flare - idle) * math.exp(-3.0 * x)
        dip = 0.22 if ti < t_fire else 0.05 * math.exp(-(ti - t_fire) / 0.3)
        rpm[i] = max(base * (1.0 - dip * math.cos(math.radians(theta) * model.n / 2.0)), 1.0)
        theta += 6.0 * rpm[i] / SR
    fire = np.clip((t - t_fire) / 0.15 + 0.4, 0.0, 1.0) * (t >= t_fire)
    load = np.clip(np.minimum((t - t_fire) / 0.1, 1.0 - (t - t_fire - 0.35) / 0.4), 0.0, 1.0) * 0.2 * (t >= t_fire)
    y = model.render_trajectory(rpm, fire, load, rng)
    # starter: pinion mesh whine (ring gear ~130 teeth), motor hum, gear rattle; disengages after firing
    ph_mesh = np.cumsum(2.0 * np.pi * rpm / 60.0 * 130.0 / SR)
    ph_mot = np.cumsum(2.0 * np.pi * rpm / 60.0 * 26.0 / SR)
    st = (np.sin(ph_mesh) + 0.5 * np.sin(2.0 * ph_mesh + 0.3) + 0.6 * np.sin(ph_mot)
          + 0.35 * band_noise(rng, n, 800.0, 6000.0) * (0.6 + 0.4 * np.sin(ph_mesh / 7.0)))
    env = np.clip(t / 0.03, 0.0, 1.0) * np.where(t < t_fire + 0.08, 1.0, np.exp(-(t - t_fire - 0.08) / 0.07))
    clunk = np.exp(-t / 0.012) * np.sin(2.0 * np.pi * 160.0 * t) * 2.0
    ref = np.sqrt(np.mean(y[-int(0.3 * SR):] ** 2)) + 1e-9
    y = y + ref * (0.55 * st * env + clunk)
    y[:32] *= np.linspace(0.0, 1.0, 32)
    y[-int(0.02 * SR):] *= np.linspace(1.0, 0.0, int(0.02 * SR))
    return y


# ------------------------------------------------------------------------------------------------
# Building and writing the banks
# ------------------------------------------------------------------------------------------------

def build_car(car: str, out_dir: str, log=print, n_var: int = N_VARIANTS) -> dict:
    t0 = time.time()
    prof = PROFILES[car]
    m = CarModel(car)
    log(f"{car}: {prof['engine']['label']}")
    m.calibrate(log)
    periods = rpm_points(prof["engine"], prof["ratios"])
    banks = []
    for P in periods:
        for load in ("off", "on"):
            res = m.render_steady(P, load, n_var, OVERLAP)
            y = m.mix(res["parts"])
            a = res["n_warm"] * P
            cycles = []
            for i in range(n_var):
                c = y[a + i * P:a + i * P + P + OVERLAP].copy()
                c -= np.mean(c[:P])          # no DC per cycle (random variants would make a slow wobble)
                cycles.append(c)
            banks.append({"rpm": res["rpm"], "period": P, "load": load, "cycles": cycles,
                          "lev": level_a_db(y[a:a + n_var * P]), "delay_ms": res["D"] * 1000.0})
    shape_levels(banks, m.ref_rpm, prof["mix"])
    on_ref = min((b for b in banks if b["load"] == "on"), key=lambda b: abs(math.log(b["rpm"] / m.ref_rpm)))
    scale = 0.708 / max(np.max(np.abs(c)) for c in on_ref["cycles"]) / on_ref["gain"]
    peak_all = max(np.max(np.abs(c)) * b["gain"] * scale for b in banks for c in b["cycles"])
    if peak_all > 0.97:
        log(f"  Hinweis: Spitze {peak_all:.2f} > 0.97 -> alle Banken {20 * math.log10(0.97 / peak_all):.1f} dB leiser")
        scale *= 0.97 / peak_all
    clips = {}
    cs = prof["clips"]
    if cs.get("crackle"):
        cl = crackle_clips(m, cs["crackle"])
        pk = max(np.max(np.abs(c)) for c in cl)
        clips["crackle"] = [c * 0.75 / pk for c in cl]
    if cs.get("blowoff"):
        clips["blowoff"] = [c * 0.5 / np.max(np.abs(c)) for c in blowoff_clips(m, cs["blowoff"])]
    if cs.get("shift"):
        cl = shift_clips(m, cs["shift"])
        pk = max(np.max(np.abs(c)) for c in cl)
        clips["shift"] = [c * 0.7 / pk for c in cl]
    if cs.get("start"):
        # level-matched to the idle bank (overrun bank at idle = idle combustion) over its last 0.4 s
        idle = np.concatenate([c[:banks[0]["period"]] for c in banks[0]["cycles"]]) * banks[0]["gain"] * scale
        st = start_clip(m)
        st *= np.sqrt(np.mean(idle ** 2)) / np.sqrt(np.mean(st[-int(0.3 * SR):] ** 2))
        if np.max(np.abs(st)) > 0.97:
            log(f"  Hinweis: Startclip-Spitze {np.max(np.abs(st)):.2f} -> auf 0.97 begrenzt")
            st *= 0.97 / np.max(np.abs(st))
        clips["start"] = [st]
    # loudness reference for the per-car gain: K-weighted level of the full-load banks 0.4..0.9 x redline
    red = prof["engine"]["redline_rpm"]
    loud = [loudness_db(np.concatenate([c[:b["period"]] for c in b["cycles"]]) * b["gain"] * scale)
            for b in banks if b["load"] == "on" and 0.4 * red <= b["rpm"] <= 0.9 * red]
    loud_ref = float(np.mean(loud))
    data, pos, jbanks = [], 0, []
    for b in banks:
        g = b["gain"] * scale
        cyc = []
        for c in b["cycles"]:
            x = (c * g).astype(np.float32)
            data.append(x)
            cyc.append([pos, len(x)])
            pos += len(x)
        jbanks.append({"rpm": round(b["rpm"], 3), "load": b["load"], "period": float(b["period"]),
                       "overlap": OVERLAP, "cycles": cyc, "delay_ms": round(b["delay_ms"], 2),
                       "level_db": round(b["lev"] + 20.0 * math.log10(g), 1)})
    jclips = {}
    for name, lst in clips.items():
        jclips[name] = []
        for c in lst:
            x = np.asarray(c, np.float32)
            data.append(x)
            jclips[name].append([pos, len(x)])
            pos += len(x)
    blob = np.concatenate(data).astype("<f4")
    meta = {"format": "ce-engine-bank-1", "car": car, "sample_rate": SR, "data": f"{car}.f32",
            "engine": prof["engine"], "gearbox": prof["gearbox"], "banks": jbanks, "clips": jclips,
            "layers": prof["layers"],
            "mix": {"gain": round(10.0 ** (prof["mix"]["loudness_db"] / 20.0), 3),
                    "off_gain": round(10.0 ** (prof["mix"]["off_db"] / 20.0), 3)},
            "synth": {"generator": "tools/audio/engine_synth.py", "model": 2, "ref_rpm": round(m.ref_rpm),
                      "variants": n_var, "delay_ms": "Laufzeit Auslassventil Zyl. 1 -> Hoerer (Zyklusanfang)",
                      "level_db": "A-bewerteter Pegel der Bank in dBFS (vor mix.gain)",
                      "loudness_full_db": round(loud_ref, 2)}}
    os.makedirs(out_dir, exist_ok=True)
    blob.tofile(os.path.join(out_dir, f"{car}.f32"))
    with open(os.path.join(out_dir, f"{car}.json"), "w", encoding="utf-8") as fh:
        fh.write(format_json(meta))
    log(f"  {len(periods)} Drehzahlpunkte {120.0 * SR / periods[0]:.0f}..{120.0 * SR / periods[-1]:.0f}/min, "
        f"{len(jbanks)} Banken, Clips {', '.join(f'{k}:{len(v)}' for k, v in jclips.items())}; "
        f"{blob.nbytes / 1e6:.2f} MB; {time.time() - t0:.0f} s")
    return meta


def format_json(meta: dict) -> str:
    """JSON with one line per bank and per sub-key (readable diffs, compact)."""
    lines = ["{"]
    keys = list(meta.keys())
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        v = meta[k]
        if k == "banks":
            lines.append('  "banks": [')
            lines += ["    " + json.dumps(b, ensure_ascii=False) + ("," if j < len(v) - 1 else "")
                      for j, b in enumerate(v)]
            lines.append("  ]" + comma)
        elif isinstance(v, dict):
            lines.append(f'  "{k}": {{')
            sub = list(v.items())
            lines += [f'    "{kk}": ' + json.dumps(vv, ensure_ascii=False) + ("," if j < len(sub) - 1 else "")
                      for j, (kk, vv) in enumerate(sub)]
            lines.append("  }" + comma)
        else:
            lines.append(f'  "{k}": ' + json.dumps(v, ensure_ascii=False) + comma)
    lines.append("}")
    return "\n".join(lines) + "\n"


VMAX = {"kompakt": 230, "kombi": 235, "limousine": 245, "sportwagen": 255, "gran_turismo": 270}


def info(cars) -> None:
    for car in cars:
        prof = PROFILES[car]
        periods = rpm_points(prof["engine"], prof["ratios"])
        rpms = [120.0 * SR / p for p in periods]
        size = sum(2 * N_VARIANTS * (p + OVERLAP) for p in periods) * 4 / 1e6
        gb = prof["gearbox"]
        top = gb["kmh_per_1000rpm"][-1]
        vmax = VMAX[car]
        print(f"{car}: {len(rpms)} Punkte " + " ".join(f"{r:.0f}" for r in rpms) +
              f" | Banken {size:.2f} MB | 130 km/h im {len(gb['kmh_per_1000rpm'])}. Gang: {130 / top * 1000:.0f}/min,"
              f" Vmax {vmax} km/h im höchsten Gang: {vmax / top * 1000:.0f}/min"
              f" (Begrenzer {prof['engine']['limiter_rpm']})")


def set_car_gains(out_dir: str, log=print) -> None:
    """mix.gain of every car in out_dir from its measured full-load loudness (synth.loudness_full_db) and
    the profile's relative target (mix.loudness_db: Gran Turismo 0 dB, the others below), normalised so
    that the car that needs the most gets 1.0 (the runtime never amplifies)."""
    metas = {}
    for car in CARS:
        path = os.path.join(out_dir, f"{car}.json")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                metas[car] = json.load(fh)
    if not metas:
        return
    want = {car: PROFILES[car]["mix"]["loudness_db"] - meta["synth"]["loudness_full_db"]
            for car, meta in metas.items()}
    top = max(want.values())
    for car, meta in metas.items():
        meta["mix"]["gain"] = round(10.0 ** ((want[car] - top) / 20.0), 3)
        with open(os.path.join(out_dir, f"{car}.json"), "w", encoding="utf-8") as fh:
            fh.write(format_json(meta))
    log("Grundpegel (mix.gain): " + ", ".join(f"{c} {m['mix']['gain']:.2f}" for c, m in metas.items()))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Motorklang v2: Zyklusbanken je Auto rendern (docs/motorsound.md)")
    ap.add_argument("--car", action="append", choices=CARS, help="nur dieses Auto (mehrfach möglich)")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "audio", "engines"), help="Zielordner")
    ap.add_argument("--info", action="store_true", help="nur Drehzahlpunkte, Größen und Getriebe anzeigen")
    args = ap.parse_args(argv)
    cars = args.car or CARS
    if args.info:
        info(cars)
        return 0
    for car in cars:
        build_car(car, args.out)
    set_car_gains(args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
