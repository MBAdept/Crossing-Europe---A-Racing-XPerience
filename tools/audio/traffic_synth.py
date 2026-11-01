#!/usr/bin/env python3
"""Verkehrsgeräusche - offline synthesis of the traffic sound loops (vehicles the player passes or is passed by).

Contract: docs/verkehrsgeraeusche.md (section 1: files and JSON; "Umsetzung der Offline-Synthese" = this tool).

Writes assets/audio/traffic/traffic_sounds.json and nine seamless mono loops <name>.wav (16 bit, 32 kHz, ~3 s):

  engine  car_petrol, car_diesel, car_sport, van_diesel, truck_diesel, bus_diesel
          The physical engine model of tools/audio/engine_synth.py, imported (not copied): exhaust pulses with the
          real firing order, exhaust system as 1-D acoustic network, induction, valve train, injectors, diesel
          knock - here at steady cruise (top gear, part load) and heard from the neighbouring lane: the listener
          stands 3.5 m beside the vehicle at chase-camera height (1.6 m), so the engine bay, the intake and the
          mechanics are heard next to the tailpipe. Trucks and buses get an extra component, gear rattle (timing
          and auxiliary gears hitting within their backlash after every torque pulse). Component levels are
          calibrated at the cruise point itself (A-weighted, dB re exhaust). Loop = whole number of working
          cycles; the signal's own continuation after the last cycle is cross-faded into the first cycle
          (cycle-synchronous, correlation-compensated) - no jump at the loop point.
  tires   tires_car, tires_truck: tyre/road rolling noise per tyre - road texture excitation (macrotexture
          enveloped by the tread, belt response), tread block impacts with pitch sequencing (the pattern repeats
          every revolution), air pumping at the leading/trailing edge of the contact patch, horn amplification
          near the contact patch, tyre cavity resonance (split by the rotation), road unevenness and a slow
          variation of the road surface. Trucks: 12 tyres of three kinds (steer, drive, trailer), lower cavity
          modes, rib treads with little pitch variation ("singing").
  air     air: turbulent flow noise around the vehicle body - wake, separation at A-pillars/mirrors/wheel arches,
          gaps - with slow gusts: the "whoosh" close to a vehicle.
  Tyres and air are synthesised circularly (every filter as FFT over exactly the loop length, impulses placed on
  a ring) - periodic by construction.

Levels: every loop has the same K-weighted loudness REF_LUFS (ITU-R BS.1770 weighting without gating, whole loop);
relative levels between engine, tyres and air and between the vehicle classes come only from gain_db (+
level_db_per_decade) in the JSON - the values of the contract, except truck/bus (see SOUNDS).

Usage (python3 + numpy only, deterministic, ~1 min):
  python3 tools/audio/traffic_synth.py                      # all nine loops + JSON -> assets/audio/traffic/
  python3 tools/audio/traffic_synth.py --only truck_diesel  # single loops (the JSON keeps the other entries)
  python3 tools/audio/traffic_synth.py --info               # loop plan (rpm, cycles, samples), no rendering
  python3 tools/audio/traffic_synth.py --check              # checks of the existing loops only
Pass-by simulations (spatialiser, Doppler), spectrograms and checks: tools/audio/traffic_preview.py.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import json
import math
import os
import sys
import time
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_synth as es  # noqa: E402  (physical engine model: reused, not copied)

SR = es.SR                  # 32 kHz like the engine banks
ROOT = es.ROOT
OUT_DIR = os.path.join(ROOT, "assets", "audio", "traffic")
FORMAT = "ce-traffic-sounds-1"
MODEL = 1                   # synth.model in the JSON
LOOP_S = 3.0                # loop length; engines: the nearest whole number of working cycles
REF_LUFS = -20.0            # loudness of every loop (K-weighted, no gating)
PEAK_MAX = 0.891            # -1 dBFS: no loop may peak above
XFADE_S = 0.04              # engine loops: splice cross-fade (at most one working cycle)
HP_HZ = 25.0                # all loops: high-pass (no subsonic energy, the runtime pitches down to 0.6)

# gear rattle is an extra engine component (process-local: the player banks are built by engine_synth.py itself)
es.COMPONENTS = es.COMPONENTS + ["rattle"]

# ------------------------------------------------------------------------------------------------
# Contract (docs/verkehrsgeraeusche.md section 1): runtime fields. Deviation (documented there): truck_diesel
# +3.0 instead of 0.0, tires_truck +1.0 instead of 0.0, bus_diesel 0.0 instead of -1.0 - with the contract values a
# truck was only 0.6-1.5 LU louder than a car at the closest pass (reference pass-by simulation with source size,
# traffic_preview.py); now +2.7-3.4 LU (roadside: a truck engine at 85 km/h is ~10 dB(A) louder than a car's).
# ------------------------------------------------------------------------------------------------

SOUNDS = {
    "car_petrol": {"file": "car_petrol.wav", "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_diesel": {"file": "car_diesel.wav", "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_sport": {"file": "car_sport.wav", "layer": "engine", "ref_kmh": 140, "pitch_exp": 1.0, "gain_db": -2.0},
    "van_diesel": {"file": "van_diesel.wav", "layer": "engine", "ref_kmh": 110, "pitch_exp": 1.0, "gain_db": -3.0},
    "truck_diesel": {"file": "truck_diesel.wav", "layer": "engine", "ref_kmh": 85, "pitch_exp": 1.0, "gain_db": 3.0},
    "bus_diesel": {"file": "bus_diesel.wav", "layer": "engine", "ref_kmh": 90, "pitch_exp": 1.0, "gain_db": 0.0},
    "tires_car": {"file": "tires_car.wav", "layer": "tires", "ref_kmh": 120, "pitch_exp": 0.35, "gain_db": -3.0,
                  "level_db_per_decade": 30.0},
    "tires_truck": {"file": "tires_truck.wav", "layer": "tires", "ref_kmh": 85, "pitch_exp": 0.35, "gain_db": 1.0,
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

# ------------------------------------------------------------------------------------------------
# Engines: profiles for engine_synth.CarModel + "cruise" (operating point) + "listener" (vehicle frame:
# x lateral, y forward from the rear end, z up; the listener stands in the neighbouring lane).
#   levels: A-weighted level of each component in dB re the exhaust, at the cruise point
#   cruise: kmh/rpm (top gear), manifold pressure p_im (bar abs), pressure ratio at EVO (combustion),
#           temperatures at EVO / in the header (K), scatter, exhaust back pressure (bar), throttle resistance
#           (petrol, x rho c / S), throttle hiss share, diesel knock amplitude
# ------------------------------------------------------------------------------------------------

SIDE_LISTENER = (-3.5, 2.25, 1.6)


def _derive(base: str, merge: dict | None = None, **replace) -> dict:
    """Profile from a player car's profile (engine_synth.PROFILES): deep copy, top-level keys replaced,
    dict-valued keys in `merge` updated."""
    p = copy.deepcopy(es.PROFILES[base])
    for k, v in (merge or {}).items():
        p[k] = {**p[k], **v}
    p.update(replace)
    return p


def _truck_profile() -> dict:
    """12.8 l inline six (EU heavy truck), twin-entry manifold and turbine, after-treatment silencer box
    (oxidation catalyst, particle filter, SCR) under the right frame rail, outlet down/sideways."""
    return {
        "engine": {"label": "12,8 l Reihensechszylinder Diesel (Sattelzugmaschine)", "cylinders": 6,
                   "layout": "inline", "fuel": "diesel", "aspiration": "turbo", "idle_rpm": 600,
                   "redline_rpm": 1900, "limiter_rpm": 2100},
        "geo": {"bore": 132.0, "stroke": 156.0, "rod": 256.0, "cr": 18.3, "order": [1, 5, 3, 6, 2, 4],
                "groups": {1: "a", 2: "a", 3: "a", 4: "b", 5: "b", 6: "b"}, "imbalance": 0.04},
        "valves": {"evo": 130.0, "evc": 368.0, "ivo": 352.0, "ivc": 570.0, "ex_d": 42.0, "ex_n": 2,
                   "ex_lift": 13.5, "cd": 0.62},
        "op": {"boost": [2.0, 800, 1100, 1700, 0.85], "ve": [[600, 0.88], [1200, 0.95], [1800, 0.92], [2100, 0.86]],
               "ratio_full": 2.6, "p_im_idle": 1.0, "ratio_idle": 1.45, "p_im_cut": 1.0,
               "cut_rpm": [700, 950], "back_turbo": 0.7, "back_flow": 0.10,
               "T_evo_full": 950.0, "T_evo_idle": 650.0, "T_evo_cut": 520.0,
               "T_hdr_full": [720.0, 880.0], "T_hdr_off": [500.0, 560.0],
               "sigma_full": 0.025, "sigma_idle": 0.06, "interact": [0.0, 120.0],
               "nl_len": 0.6, "nl": 0.3, "knock": [0.5, 0.55]},
        "exhaust": (
            es._ports([1, 2, 3], "e", "ma", 0.28, 0.050, "hdr", [0.36, 0.28, 0.22])
            + es._ports([4, 5, 6], "e", "mb", 0.28, 0.050, "hdr", [0.22, 0.28, 0.36])
            + [("vol", "ma", 1.2e-3, "hdr"), ("vol", "mb", 1.2e-3, "hdr"),
               ("res", "ma", "t", 1.6, 0.070, "hdr"), ("res", "mb", "t", 1.6, 0.070, "hdr"),   # twin-entry turbine
               ("vol", "t", 2.5e-3, "down"),
               ("pipe", "t", "d1", 0.90, 0.127, "down"),                     # downpipe with flex section
               ("pipe", "d1", "d2", 2.60, 0.127, "mid", {"flow": 1.5}),      # along the frame rail
               ("pipe", "d2", "b1", 0.30, 0.42, "rear", {"absorb": 0.8}),    # silencer box: inlet chamber
               ("res", "b1", "b2", 0.9, 0.30, "rear"),                       # oxidation catalyst + particle filter
               ("pipe", "b2", "b3", 0.35, 0.42, "rear", {"absorb": 2.0}),    # mixing / SCR chamber
               ("res", "b3", "b4", 0.6, 0.30, "rear"),                       # SCR catalyst
               ("pipe", "b4", "b5", 0.30, 0.42, "rear", {"absorb": 2.5}),    # outlet chamber
               ("pipe", "b5", "tp", 0.35, 0.127, "tail"),                    # outlet pipe
               ("rad", "tp", 0.127, (1.10, 2.8, 0.55), {"shadow": [0.6, 1500.0], "rflow": 0.5})]),
        "crackle_nodes": ["b1"],
        "intake": {"runner": [0.35, 0.055], "plenum": 6.0e-3, "throttle_d": 0.10, "turbo": True,
                   "duct": [2.5, 0.13], "airbox": 45.0e-3, "snorkel": [0.6, 0.14], "mouth": (-1.1, 3.2, 3.1),
                   "diesel": True},
        "engine_pos": (0.0, 4.2, 0.9), "shadow": [0.55, 2500.0],      # cab-over: engine open to the sides
        "levels": {"rasp": -20.0, "jet": -22.0, "intake": -6.0, "mech": -14.0, "comb": -12.0, "inj": -16.0,
                   "knock": -12.0, "whoosh": -10.0, "rattle": -12.0},
        "mech": {"valve": [[1100, 1500, 2100, 2900, 3800], 16], "inj": [[3200, 4700, 6400], 10],
                 "comb": [[320, 480, 700, 1000, 1400], 9],
                 "knock": [[620, 850, 1150, 1500, 1950, 2500, 3200, 4100], 14],
                 "rattle": [[2300, 3100, 3900, 4800, 5900], 28], "inj_angle": [700.0, 714.0]},
        "cruise": {"kmh": 85.0, "rpm": 1250.0, "p_im": 1.9, "ratio": 2.3, "T_evo": 880.0, "T_hdr": 760.0,
                   "sigma": 0.025, "p_back": 1.45, "knock": 0.5},
        "listener": (-3.5, 3.5, 1.6),
    }


def engine_profiles() -> dict:
    kombi_engine = es.PROFILES["kombi"]["engine"]
    truck = _truck_profile()
    bus = copy.deepcopy(truck)
    bus.update({
        "engine": {"label": "10,7 l Reihensechszylinder Diesel, Heckmotor (Reisebus)", "cylinders": 6,
                   "layout": "inline", "fuel": "diesel", "aspiration": "turbo", "idle_rpm": 600,
                   "redline_rpm": 2000, "limiter_rpm": 2200},
        "geo": {"bore": 125.0, "stroke": 145.0, "rod": 230.0, "cr": 18.5, "order": [1, 5, 3, 6, 2, 4],
                "groups": {1: "a", 2: "a", 3: "a", 4: "b", 5: "b", 6: "b"}, "imbalance": 0.035},
        "valves": {**truck["valves"], "ex_d": 40.0, "ex_lift": 13.0},
        "exhaust": (
            es._ports([1, 2, 3], "e", "ma", 0.26, 0.048, "hdr", [0.34, 0.26, 0.20])
            + es._ports([4, 5, 6], "e", "mb", 0.26, 0.048, "hdr", [0.20, 0.26, 0.34])
            + [("vol", "ma", 1.1e-3, "hdr"), ("vol", "mb", 1.1e-3, "hdr"),
               ("res", "ma", "t", 1.6, 0.065, "hdr"), ("res", "mb", "t", 1.6, 0.065, "hdr"),
               ("vol", "t", 2.2e-3, "down"),
               ("pipe", "t", "d1", 1.40, 0.120, "down"),
               ("pipe", "d1", "b1", 0.30, 0.40, "rear", {"absorb": 1.0}),    # transverse silencer box
               ("res", "b1", "b2", 0.9, 0.28, "rear"),
               ("pipe", "b2", "b3", 0.40, 0.40, "rear", {"absorb": 2.5}),
               ("res", "b3", "b4", 0.7, 0.28, "rear"),
               ("pipe", "b4", "b5", 0.30, 0.40, "rear", {"absorb": 3.0}),
               ("pipe", "b5", "tp", 0.50, 0.110, "tail"),
               ("rad", "tp", 0.110, (-1.05, 0.15, 0.45), {"shadow": [0.6, 1500.0], "rflow": 0.5})]),
        "intake": {**truck["intake"], "mouth": (0.9, 0.6, 3.3)},       # roof-level intake at the rear
        "engine_pos": (0.0, 1.2, 1.0), "shadow": [0.30, 1200.0],      # rear engine in a closed compartment
        "levels": {"rasp": -20.0, "jet": -22.0, "intake": -8.0, "mech": -15.0, "comb": -13.0, "inj": -19.0,
                   "knock": -15.0, "whoosh": -12.0, "rattle": -19.0},
        "cruise": {"kmh": 90.0, "rpm": 1300.0, "p_im": 1.75, "ratio": 2.2, "T_evo": 860.0, "T_hdr": 740.0,
                   "sigma": 0.025, "p_back": 1.40, "knock": 0.4},
        "listener": (-3.5, 3.0, 1.6),
    })
    return {
        "car_petrol": _derive(
            "kompakt",
            engine={"label": "1,5 l Reihenvierzylinder Turbo-Benziner", "cylinders": 4, "layout": "inline",
                    "fuel": "petrol", "aspiration": "turbo", "idle_rpm": 800, "redline_rpm": 6000,
                    "limiter_rpm": 6200},
            geo={"bore": 74.5, "stroke": 85.9, "rod": 140.0, "cr": 10.5, "order": [1, 3, 4, 2],
                 "groups": {1: "a", 2: "a", 3: "a", 4: "a"}, "imbalance": 0.03},
            valves={"evo": 140.0, "evc": 372.0, "ivo": 352.0, "ivc": 585.0, "ex_d": 25.0, "ex_n": 2,
                    "ex_lift": 8.5, "cd": 0.65},
            exhaust=(
                es._ports([1, 2, 3, 4], "e", "m", 0.14, 0.030, "hdr", [0.13, 0.15, 0.15, 0.13])
                + [("vol", "m", 0.2e-3, "hdr"),
                   ("res", "m", "t", 1.2, 0.045, "hdr"),                        # turbine
                   ("vol", "t", 0.25e-3, "down"),
                   ("pipe", "t", "c1", 0.40, 0.050, "down"),
                   ("pipe", "c1", "c2", 0.15, 0.110, "down", {"absorb": 1.0}),  # close-coupled catalyst
                   ("pipe", "c2", "x1", 1.60, 0.048, "mid"),
                   ("res", "x1", "x1p", 0.7, 0.048, "mid"),
                   ("pipe", "x1p", "x2", 0.35, 0.120, "mid", {"absorb": 3.0}),  # centre silencer (absorptive)
                   ("pipe", "x2", "y1", 1.30, 0.045, "rear"),
                   ("res", "y1", "y1p", 0.8, 0.045, "rear"),
                   ("pipe", "y1p", "y2", 0.45, 0.200, "rear", {"absorb": 2.0, "flow": 2.0}),   # rear silencer
                   ("helm", "y2", 2.5e-3, 0.10, 0.035, "rear", 0.15),          # anti-drone resonator
                   ("pipe", "y2", "tp", 0.30, 0.042, "tail"),
                   ("rad", "tp", 0.042, (-0.45, 0.0, 0.30), {"rflow": 0.4})]),  # single tailpipe, rear left
            crackle_nodes=["y1"],
            merge={"intake": {"mouth": (0.5, 3.9, 0.75)}},
            engine_pos=(0.0, 3.6, 0.55), shadow=[0.45, 1800.0],
            levels={"rasp": -14.0, "jet": -16.0, "intake": -8.0, "mech": -5.0, "comb": -3.0, "inj": -12.0,
                    "hiss": -14.0, "whoosh": -12.0},
            cruise={"kmh": 120.0, "rpm": 2500.0, "p_im": 0.68, "ratio": 4.2, "T_evo": 1150.0, "T_hdr": 830.0,
                    "sigma": 0.03, "p_back": 1.07, "throttle_r": 2.5, "hiss": 0.6, "knock": 0.0},
            listener=SIDE_LISTENER),
        "car_diesel": _derive(
            "kombi",
            engine={**kombi_engine, "label": "2,0 l Reihenvierzylinder Turbodiesel"},
            engine_pos=(0.0, 3.7, 0.55), shadow=[0.45, 1800.0],
            levels={"rasp": -16.0, "jet": -16.0, "intake": -8.0, "mech": -7.0, "comb": -6.0, "inj": -9.0,
                    "knock": -4.0, "whoosh": -12.0},
            cruise={"kmh": 120.0, "rpm": 1900.0, "p_im": 1.25, "ratio": 2.0, "T_evo": 820.0, "T_hdr": 690.0,
                    "sigma": 0.03, "p_back": 1.12, "knock": 0.4},
            listener=SIDE_LISTENER),
        "car_sport": _derive(
            "limousine",
            engine={**es.PROFILES["limousine"]["engine"], "label": "3,0 l Reihensechszylinder Turbo, Sportauspuff"},
            exhaust=(
                es._ports([1, 2, 3], "e", "sa", 0.26, 0.036, "hdr", [0.30, 0.24, 0.27])
                + es._ports([4, 5, 6], "e", "sb", 0.26, 0.036, "hdr", [0.27, 0.24, 0.30])
                + [("vol", "sa", 0.2e-3, "hdr"), ("vol", "sb", 0.2e-3, "hdr"),
                   ("res", "sa", "t", 1.1, 0.045, "hdr"), ("res", "sb", "t", 1.1, 0.045, "hdr"),   # twin scroll
                   ("vol", "t", 0.30e-3, "down"),
                   ("pipe", "t", "c1", 0.55, 0.070, "down"),
                   ("pipe", "c1", "c2", 0.18, 0.125, "down", {"absorb": 0.8}),                  # catalyst
                   ("pipe", "c2", "x1", 1.50, 0.070, "mid"),
                   ("pipe", "x1", "x2", 0.40, 0.120, "mid", {"absorb": 1.2}),   # straight-through resonator
                   ("pipe", "x2", "y", 1.00, 0.065, "rear"),
                   ("pipe", "y", "yl", 0.45, 0.060, "rear"), ("pipe", "y", "yr", 0.45, 0.060, "rear"),
                   ("pipe", "yl", "ml", 0.40, 0.150, "rear", {"absorb": 0.9}),  # sport silencers, flaps open
                   ("pipe", "yr", "mr", 0.40, 0.150, "rear", {"absorb": 0.9}),
                   ("pipe", "ml", "tl1", 0.22, 0.060, "tail"), ("pipe", "ml", "tl2", 0.22, 0.060, "tail"),
                   ("pipe", "mr", "tr1", 0.22, 0.060, "tail"), ("pipe", "mr", "tr2", 0.22, 0.060, "tail"),
                   ("rad", "tl1", 0.060, (-0.62, 0.05, 0.36)), ("rad", "tl2", 0.060, (-0.48, 0.05, 0.36)),
                   ("rad", "tr1", 0.060, (0.48, 0.05, 0.36)), ("rad", "tr2", 0.060, (0.62, 0.05, 0.36))]),
            crackle_nodes=["yl", "yr"],
            engine_pos=(0.0, 3.5, 0.55), shadow=[0.40, 1800.0],
            levels={"rasp": -6.0, "jet": -7.0, "intake": -6.0, "mech": -7.0, "comb": -5.0, "inj": -14.0,
                    "hiss": -16.0, "whoosh": -10.0},
            cruise={"kmh": 140.0, "rpm": 3200.0, "p_im": 0.80, "ratio": 4.4, "T_evo": 1200.0, "T_hdr": 880.0,
                    "sigma": 0.025, "p_back": 1.08, "throttle_r": 1.5, "hiss": 0.4, "knock": 0.0},
            listener=SIDE_LISTENER),
        "van_diesel": _derive(
            "kombi",
            engine={**kombi_engine, "label": "2,0 l Reihenvierzylinder Turbodiesel (Transporter/SUV)"},
            exhaust=(
                es._ports([1, 2, 3, 4], "e", "m", 0.20, 0.032, "hdr")
                + [("vol", "m", 0.40e-3, "hdr"),
                   ("res", "m", "t", 2.4, 0.050, "hdr"),                         # variable geometry turbine
                   ("vol", "t", 0.30e-3, "down"),
                   ("pipe", "t", "c1", 0.30, 0.060, "down"),
                   ("pipe", "c1", "c2", 0.22, 0.150, "down", {"absorb": 1.5}),   # oxidation catalyst
                   ("res", "c2", "c3", 0.7, 0.150, "down"),                      # particle filter
                   ("pipe", "c3", "c4", 0.25, 0.150, "down", {"absorb": 3.0}),
                   ("pipe", "c4", "x1", 2.60, 0.055, "mid"),
                   ("res", "x1", "x1p", 0.6, 0.055, "rear"),
                   ("pipe", "x1p", "x2", 0.50, 0.200, "rear", {"absorb": 2.0, "flow": 2.5}),   # one rear silencer
                   ("pipe", "x2", "tp", 0.40, 0.050, "tail"),
                   ("rad", "tp", 0.050, (0.70, 0.1, 0.35), {"shadow": [0.75, 2500.0], "rflow": 0.6})]),
            crackle_nodes=["x1"],
            engine_pos=(0.0, 4.3, 0.8), shadow=[0.60, 2500.0],
            levels={"rasp": -14.0, "jet": -14.0, "intake": -6.0, "mech": -4.0, "comb": -4.0, "inj": -6.0,
                    "knock": 0.0, "whoosh": -10.0},
            cruise={"kmh": 110.0, "rpm": 2200.0, "p_im": 1.55, "ratio": 2.4, "T_evo": 900.0, "T_hdr": 740.0,
                    "sigma": 0.03, "p_back": 1.20, "knock": 0.5},
            listener=(-3.5, 2.6, 1.6)),
        "truck_diesel": truck,
        "bus_diesel": bus,
    }


@contextlib.contextmanager
def listener_at(pos):
    """engine_synth's listener (module global, normally the chase camera 6 m behind the player's car) moved to
    `pos` in the vehicle frame while a traffic engine is built and rendered; restored afterwards."""
    old = es.LISTENER
    es.LISTENER = np.array(pos, float)
    try:
        yield
    finally:
        es.LISTENER = old


class TrafficEngine(es.CarModel):
    """engine_synth.CarModel at steady cruise: load "cruise" = top gear, part load (operating point from
    profile.cruise), heard from profile.listener. Adds gear rattle (profile.mech.rattle). Component levels are
    set at the cruise point itself (engine_loop: K-weighted, dB re exhaust) - it is the only point rendered."""

    def __init__(self, name: str, prof: dict):
        es.PROFILES[name] = prof          # CarModel reads its profile from this table (process-local entry)
        super().__init__(name)
        self.period = int(round(120.0 * SR / prof["cruise"]["rpm"]))
        self.rpm = 120.0 * SR / self.period
        if "rattle" in prof["mech"]:
            f = np.fft.rfftfreq(es.IR_N, 1.0 / SR)
            g, _ = es.listener_path(f, prof["engine_pos"], prof["shadow"])
            path = es.impulse_response(g * 6.0)[:4096]          # engine bay -> listener, as for the other parts
            h = es.modal_ir(*prof["mech"]["rattle"], np.random.default_rng(es.seed_of(name, "rattle")),
                            dur=0.03, tilt_db=0.0, click=0.4)
            self.mech_ir["rattle"] = h
            self.mech_full["rattle"] = np.convolve(h, path)

    def operating_point(self, rpm: float, load: str) -> dict:
        if load != "cruise":
            return super().operating_point(rpm, load)
        c = self.p["cruise"]
        ve = es.interp_table(self.op["ve"], rpm)
        p_im = c["p_im"]
        opp = self._op_dict(rpm, "cruise", max(p_im - 1.0, 0.0), p_im * ve * c["ratio"], p_im * ve * 0.92,
                            c["T_evo"], c["sigma"], c["T_hdr"], c["p_back"], 1.0, c.get("knock", 0.0), p_im * ve, ve)
        if not self.diesel:
            opp["hiss"] = c.get("hiss", 0.5)          # partly open throttle
        return opp

    def intake_elements(self, load: str):
        if load != "cruise":
            return super().intake_elements(load)
        els, hiss_node, whoosh_node = super().intake_elements("on")
        if not self.diesel:                           # partly open throttle plate
            thr = self.p["cruise"]["throttle_r"]
            els = [(e[0], e[1], e[2], thr) + tuple(e[4:]) if (e[0] == "res" and e[2] == "th") else e
                   for e in els]
        return els, hiss_node, whoosh_node

    def mech_sources(self, ev: dict, opp: dict, n_len: int, rng) -> dict:
        out = super().mech_sources(ev, opp, n_len, rng)
        if "rattle" in self.mech_full:
            # gear rattle: each combustion torque pulse unloads the timing/auxiliary gear pairs, their teeth
            # separate within the backlash and hit again - 1..3 impacts in the first ~180 deg after TDC,
            # strength with the combustion pressure
            tfire, om = ev["t_fire"], ev["om"]
            ne = len(tfire)
            dp = np.maximum(ev["p_evo"] - ev["p_base"], 0.0) / 1e5
            ts, amps = [], []
            for a0, a1, share, prob in ((15.0, 45.0, 1.0, 1.0), (60.0, 110.0, 0.6, 0.8), (120.0, 180.0, 0.35, 0.4)):
                hit = rng.random(ne) < prob
                ts.append(tfire + rng.uniform(a0, a1, ne) / om)
                amps.append(hit * share * dp * np.exp(0.4 * rng.standard_normal(ne)))
            out["rattle"] = es.impulse_train(np.concatenate(ts), np.concatenate(amps), n_len)
        return out

    def calibrate(self, log=None) -> dict:
        """Noise references of the flow-noise components (valve jet, tailpipe jet, compressor) at the cruise
        point; the component gains themselves are set from the loop render (engine_loop)."""
        if self.cal is not None:
            return self.cal
        opp = self.operating_point(self.rpm, "cruise")
        tf = self.exhaust_tf(opp["T_hdr"])
        ev = self.steady_events(opp, 6, tf["D"], np.random.default_rng(es.seed_of(self.car, "cal")))
        q = self.exhaust_sources(ev, opp, tf, 8 * self.period)
        self.cal = {"q_ref": float(np.mean([np.percentile(x, 99.5) for x in q])), "v_ref": opp["v_tail"],
                    "air_ref": opp["air"] * self.rpm, "k": {c: 1.0 for c in es.COMPONENTS}}
        return self.cal


def rms(x) -> float:
    return float(np.sqrt(np.mean(np.square(x))))


def splice(loop: np.ndarray, cont: np.ndarray) -> tuple:
    """Cross-fades the signal's own continuation after the loop end (cont) into the loop start: playback wraps
    from the last sample into cont[0], the natural next sample, and then fades into the loop's own head.
    Correlation-compensated weights keep the power: wa^2 + wb^2 + 2 wa wb rho = 1 (rho = correlation of cont
    and the head; cycle-synchronous, so the periodic part is coherent and only the noise part is not)."""
    n = len(cont)
    head = loop[:n]
    rho = float(np.clip(np.dot(head, cont) / math.sqrt(np.dot(head, head) * np.dot(cont, cont) + 1e-30), 0.0, 1.0))
    wb = 0.5 - 0.5 * np.cos(np.pi * (np.arange(n) + 0.5) / n)
    wa = -wb * rho + np.sqrt(1.0 - wb * wb * (1.0 - rho * rho))
    out = loop.copy()
    out[:n] = wa * cont + wb * head
    return out, rho


def engine_loop(name: str, prof: dict) -> tuple:
    """Renders the cruise loop of one traffic engine: K whole working cycles (K * period ~ LOOP_S)."""
    with listener_at(prof["listener"]):
        m = TrafficEngine(name, prof)
        m.calibrate()
        P = m.period
        K = max(2, int(round(LOOP_S * SR / P)))
        n = K * P
        res = m.render_steady(P, "cruise", K, P, seed=es.seed_of(name, "loop"))
        a = res["n_warm"] * P
        parts = res["parts"]
        seg = {c: x[a:a + n] for c, x in parts.items() if np.any(x)}
        lev = {c: es.loudness_db(x) for c, x in seg.items()}
        k = {c: 0.0 for c in es.COMPONENTS}
        k["exh"] = 1.0 / rms(seg["exh"])
        for c, want in prof["levels"].items():
            if c in lev:
                k[c] = k["exh"] * 10.0 ** ((lev["exh"] + want - lev[c]) / 20.0)
        m.cal["k"] = k
        y = m.mix(parts)
        # loop point at the quietest crank phase (least energy above 2 kHz, mean over all cycles) - not on a
        # pulse front; any constant phase keeps the splice cycle-synchronous
        hf = es.spectral_filter(y[a:a + n], lambda f: es.highpass_gain(f, 2000.0, 4))
        e = np.mean((hf * hf).reshape(K, P), axis=0)
        w = int(0.002 * SR)
        e = np.convolve(np.concatenate([e[-w:], e, e[:w]]), np.ones(w) / w, mode="same")[w:-w]
        off = int(np.argmin(e))
        L = min(P, int(XFADE_S * SR))
        loop, rho = splice(y[a + off:a + off + n], y[a + off + n:a + off + n + L])
        total = es.loudness_db(loop)
        comp = {c: round(es.loudness_db(k[c] * seg[c]) - total, 1) for c in es.COMPONENTS if k.get(c) and c in seg}
    info = {"kind": "engine", "label": prof["engine"]["label"], "kmh": prof["cruise"]["kmh"],
            "rpm": round(m.rpm, 1), "period": P, "cycles": K, "loop_phase_deg": round(720.0 * off / P, 1),
            "splice_rho": round(rho, 3), "components_lu": comp}
    return loop, info


# ------------------------------------------------------------------------------------------------
# Circular (loop-periodic) signal helpers
# ------------------------------------------------------------------------------------------------

def freqs(n: int) -> np.ndarray:
    return np.fft.rfftfreq(n, 1.0 / SR)


def circ_noise(rng, n: int, shape) -> np.ndarray:
    """Periodic Gaussian noise (period n) with the amplitude spectrum shape(f) (array over freqs(n)), unit RMS."""
    m = n // 2 + 1
    spec = (rng.standard_normal(m) + 1j * rng.standard_normal(m)) * shape
    spec[0] = 0.0
    y = np.fft.irfft(spec, n)
    return y / (rms(y) + 1e-30)


def circ_filter(x: np.ndarray, gain) -> np.ndarray:
    """Periodic filtering with a gain over freqs(len(x)) (real = zero phase, complex = with phase)."""
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def circ_conv(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    """Circular convolution (h is wrapped around the ring: the decay of the last events rings into the start)."""
    n = len(x)
    hh = np.zeros(n)
    for s in range(0, len(h), n):
        hh[:len(h[s:s + n])] += h[s:s + n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(hh), n)


def circ_impulses(times_s, amps, n: int) -> np.ndarray:
    """Impulses at fractional sample times on a ring of n samples (linear split between neighbours)."""
    pos = np.mod(np.asarray(times_s, float) * SR, n)
    i = np.floor(pos).astype(int)
    fr = pos - i
    x = np.zeros(n)
    np.add.at(x, i % n, amps * (1.0 - fr))
    np.add.at(x, (i + 1) % n, amps * fr)
    return x


def slow_variation(rng, n: int, f_lo: float, f_hi: float, depth_db: float) -> np.ndarray:
    """Smooth periodic random gain (log-normal, depth_db at 1 sigma) from the loop harmonics between f_lo and
    f_hi Hz - slow changes (road surface, gusts) that continue seamlessly over the loop point."""
    T = n / SR
    ks = np.arange(max(1, int(math.ceil(f_lo * T))), max(int(math.floor(f_hi * T)), int(math.ceil(f_lo * T))) + 1)
    t = np.arange(n) / n
    y = np.zeros(n)
    for k in ks:
        y += rng.standard_normal() / math.sqrt(k) * np.cos(2.0 * np.pi * k * t + rng.uniform(0.0, 2.0 * np.pi))
    y /= rms(y) + 1e-30
    return 10.0 ** (depth_db / 20.0 * y)


def hump(f, peak: float, slope_lo_db: float, slope_hi_db: float):
    """Spectral hump: rises with slope_lo (dB/oct) below `peak`, falls with slope_hi (dB/oct, negative) above."""
    f = np.maximum(np.asarray(f, float), 1.0)
    a = slope_lo_db / 6.02
    b = -slope_hi_db / 6.02
    return 2.0 / ((peak / f) ** a + (f / peak) ** b)


def bell_db(f, f0: float, db: float, width_oct: float):
    """Gain of a smooth bell (log-Gaussian over octaves) in linear amplitude."""
    x = np.log2(np.maximum(np.asarray(f, float), 1.0) / f0) / width_oct
    return 10.0 ** (db * np.exp(-0.5 * x * x) / 20.0)


def resonance(f, f0: float, q: float):
    """Complex response of a resonance (band-pass, unit gain at f0)."""
    f = np.maximum(np.asarray(f, float), 1e-3)
    return 1.0 / (1.0 + 1j * q * (f / f0 - f0 / f))


def short_bursts(rng, count: int, length: int, lo: float, hi: float) -> list:
    """`count` variants of short noise bursts (Hann window, band lo..hi Hz), unit energy each."""
    out = []
    nn = 4 * length
    f = np.fft.rfftfreq(nn, 1.0 / SR)
    g = es.highpass_gain(f, lo, 2) * es.lowpass_gain(f, hi, 2)
    for _ in range(count):
        x = np.zeros(nn)
        x[:length] = rng.standard_normal(length) * np.hanning(length)
        y = np.fft.irfft(np.fft.rfft(x) * g, nn)[:2 * length]
        out.append(y / math.sqrt(np.sum(y * y)))
    return out


# ------------------------------------------------------------------------------------------------
# Tyre/road rolling noise
# ------------------------------------------------------------------------------------------------
# Per tyre group: count, rolling circumference (m), mean tread pitch (mm) and pitch sequencing (ratios of the
# pitch lengths, random sequence, repeating every revolution), contact patch length (m), modes of the tread
# block impact (Hz), cavity resonance (Hz) and the group's weight at the listener.
# levels: RMS share of the mechanisms (dB, relative); texture: wavelength of the enveloped macrotexture peak and
# the slopes around it; horn: amplification near the contact patch; variation: slow road surface change.

TIRES = {
    "tires_car": {
        "label": "4 Pkw-Reifen 205/55 R16 auf Splittmastixasphalt, 120 km/h",
        "kmh": 120.0,
        "groups": [
            {"name": "205/55 R16", "n": 4, "circ_m": 1.93, "pitch_mm": 30.0, "ratios": [0.82, 1.0, 1.18],
             "contact_m": 0.14, "block_hz": [760, 1120, 1580, 2200, 2950], "block_q": 4.0, "block_click": 0.15,
             "cavity_hz": 218.0, "cavity_q": 28.0, "weight": [1.0, 1.0, 0.8, 0.8]},
        ],
        "texture": {"peak_mm": 50.0, "slope_lo": 2.0, "slope_hi": -10.0, "belt_hz": 950.0, "belt_db": 3.0},
        "pump": {"lo": 800.0, "hi": 4500.0},
        "rumble": {"peak": 70.0, "slope_lo": 12.0, "slope_hi": -12.0, "depth_db": 2.5},
        "horn": {"hz": 1500.0, "db": 3.0, "width_oct": 0.9},
        "variation": {"common_db": 1.0, "tyre_db": 0.6, "f": [0.3, 3.0]},
        "runout": 0.06,
        "impact_sigma": 0.5,
        "levels": {"texture": 0.0, "tread": -7.0, "pump": -15.0, "cavity": -8.0, "rumble": -8.0},
        "lowpass_hz": 6000.0,
    },
    "tires_truck": {
        "label": "12 Lkw-Reifen (Lenkachse 315/70 R22.5, Antriebsachse zwillingsbereift, 3 Aufliegerachsen "
                 "385/65 R22.5) auf Splittmastixasphalt, 85 km/h",
        "kmh": 85.0,
        "groups": [
            {"name": "Lenkachse 315/70 R22.5 (Rillenprofil)", "n": 2, "circ_m": 3.18, "pitch_mm": 42.0,
             "ratios": [0.9, 1.0, 1.1], "contact_m": 0.22, "block_hz": [520, 780, 1100, 1500, 2050],
             "block_q": 5.0, "block_click": 0.15, "cavity_hz": 141.0, "cavity_q": 34.0, "weight": [1.0, 0.85]},
            {"name": "Antriebsachse 315/70 R22.5 (Blockprofil, Zwillingsreifen)", "n": 4, "circ_m": 3.16,
             "pitch_mm": 58.0, "ratios": [0.84, 1.0, 1.16], "contact_m": 0.24,
             "block_hz": [420, 640, 920, 1300, 1800], "block_q": 4.0, "block_click": 0.2, "cavity_hz": 138.0,
             "cavity_q": 34.0, "weight": [1.0, 0.9, 0.85, 0.75]},
            {"name": "Auflieger 385/65 R22.5 (Rillenprofil)", "n": 6, "circ_m": 3.37, "pitch_mm": 40.0,
             "ratios": [0.92, 1.0, 1.08], "contact_m": 0.24, "block_hz": [560, 830, 1150, 1600, 2150],
             "block_q": 6.0, "block_click": 0.1, "cavity_hz": 128.0, "cavity_q": 38.0,
             "weight": [0.85, 0.75, 0.8, 0.7, 0.75, 0.65]},
        ],
        "texture": {"peak_mm": 65.0, "slope_lo": 3.0, "slope_hi": -10.0, "belt_hz": 800.0, "belt_db": 3.0},
        "pump": {"lo": 600.0, "hi": 3800.0},
        "rumble": {"peak": 55.0, "slope_lo": 12.0, "slope_hi": -10.0, "depth_db": 3.0},
        "horn": {"hz": 1100.0, "db": 4.0, "width_oct": 0.9},
        "variation": {"common_db": 1.2, "tyre_db": 0.6, "f": [0.25, 2.5]},
        "runout": 0.08,
        "impact_sigma": 0.45,
        "levels": {"texture": 0.0, "tread": -4.0, "pump": -17.0, "cavity": -7.0, "rumble": -8.0},
        "lowpass_hz": 5000.0,
    },
}


def tonality_db(x: np.ndarray, lo: float = 300.0, hi: float = 3000.0, width_oct: float = 1.0 / 3.0) -> float:
    """Strongest narrow line between lo and hi (power of 3 neighbouring FFT bins of the loop) above the median of
    the spectrum within +-width_oct/2 - a tread "whine" measure (pure noise of 3 s reaches ~8 dB by chance)."""
    spec = np.abs(np.fft.rfft(x)) ** 2
    spec = np.convolve(spec, np.ones(3), mode="same")
    f = freqs(len(x))
    out = -99.0
    for i in np.where((f >= lo) & (f <= hi))[0]:
        a, b = np.searchsorted(f, f[i] * 2.0 ** (-width_oct / 2)), np.searchsorted(f, f[i] * 2.0 ** (width_oct / 2))
        out = max(out, 10.0 * math.log10(spec[i] / (np.median(spec[a:b]) + 1e-30) + 1e-30))
    return out


def tire_loop(name: str, prm: dict) -> tuple:
    """Rolling noise of all tyres of a vehicle at prm.kmh, synthesised circularly over exactly one loop."""
    rng = np.random.default_rng(es.seed_of(name, "tires"))
    n = int(round(LOOP_S * SR))
    T = n / SR
    v = prm["kmh"] / 3.6
    D = v * T                                   # road distance per loop
    f = freqs(n)
    tex = prm["texture"]
    common = slow_variation(rng, n, *prm["variation"]["f"], prm["variation"]["common_db"])
    comp = {"texture": np.zeros(n), "tread": np.zeros(n), "pump": np.zeros(n), "cavity": np.zeros(n)}
    f_tex = v / (tex["peak_mm"] / 1000.0)
    shape_tex = (hump(f, f_tex, tex["slope_lo"], tex["slope_hi"]) * bell_db(f, tex["belt_hz"], tex["belt_db"], 1.0)
                 * es.highpass_gain(f, 60.0, 2))
    pump_kernels = short_bursts(rng, 6, int(0.0012 * SR), prm["pump"]["lo"], prm["pump"]["hi"])
    info_groups = []
    for grp in prm["groups"]:
        # tread pattern: random pitch sequence of the group's tyre model (identical for all its tyres)
        n_pitch = int(round(grp["circ_m"] / (grp["pitch_mm"] / 1000.0)))
        seq = rng.choice(np.asarray(grp["ratios"], float), n_pitch)
        block = es.modal_ir(grp["block_hz"], grp["block_q"], rng, dur=0.012, tilt_db=-3.0, click=grp["block_click"])
        rot_hz = []
        for j in range(grp["n"]):
            w = grp["weight"][j]
            circ = grp["circ_m"] * (1.0 + 0.006 * rng.standard_normal())   # wear, pressure, load
            lengths = seq / seq.sum() * circ                                 # pitches of one revolution
            reps = int(math.ceil(D / circ)) + 1
            plen = np.roll(np.tile(lengths, reps), -int(rng.integers(n_pitch)))   # random start angle
            edges = np.concatenate([[0.0], np.cumsum(plen)])                 # leading edges along the road
            # exactly one loop of events: the whole pattern is stretched by less than half a pitch so that the
            # next event after the last one falls on the loop point (circular - no odd pitch at the seam)
            cnt = int(round(D / plen.mean()))
            scale = D / edges[cnt]
            plen = plen[:cnt] * scale
            s_road = edges[:cnt] * scale
            s = np.mod(s_road + rng.uniform(0.0, D), D)
            t_in = s / v
            t_out = (s + grp["contact_m"]) / v
            # radial run-out / stiffness variation: once per revolution
            rot = 1.0 + prm["runout"] * np.cos(2.0 * np.pi * s_road / circ + rng.uniform(0.0, 2.0 * np.pi))
            road = common[(np.mod(t_in, T) * SR).astype(int) % n]
            # impact strength: block size x road texture under this block (random, log-normal) x run-out
            texture = np.exp(prm["impact_sigma"] * rng.standard_normal(len(s)))
            amp_imp = np.sqrt(plen / plen.mean()) * texture * rot * road
            comp["tread"] += w * circ_conv(circ_impulses(t_in, amp_imp, n), block)
            # air pumping: grooves compressed at the leading edge (air expelled), re-opened at the trailing edge
            # (air sucked in) - short bursts, random kernel per event
            amp_pump = plen / plen.mean() * np.exp(0.45 * rng.standard_normal(len(s))) * road
            sel_in = rng.integers(len(pump_kernels), size=len(s))
            sel_out = rng.integers(len(pump_kernels), size=len(s))
            for kk, ker in enumerate(pump_kernels):
                x = circ_impulses(t_in[sel_in == kk], amp_pump[sel_in == kk], n)
                x -= 0.8 * circ_impulses(t_out[sel_out == kk], amp_pump[sel_out == kk], n)
                comp["pump"] += w * circ_conv(x, ker)
            # texture-induced vibration of the belt (continuous), with run-out (integer cycles per loop) and the
            # tyre's own slow variation
            f_rot = max(1, round(v / circ * T)) / T
            mod = (1.0 + 0.5 * prm["runout"] * np.cos(2.0 * np.pi * f_rot * np.arange(n) / SR + rng.uniform(0, 6.3)))
            own = slow_variation(rng, n, *prm["variation"]["f"], prm["variation"]["tyre_db"])
            comp["texture"] += w * circ_noise(rng, n, shape_tex) * common * own * mod
            # cavity resonance: the torus of air inside the tyre, excited by the contact patch forces; the
            # rotation splits the mode into a forward and a backward travelling wave
            fc = grp["cavity_hz"] * (1.0 + 0.012 * rng.standard_normal())
            split = 0.6 * v / circ
            exc = circ_noise(rng, n, es.lowpass_gain(f, 600.0, 2)) * common * own
            comp["cavity"] += w * circ_filter(exc, resonance(f, fc - split, grp["cavity_q"])
                                              + resonance(f, fc + split, grp["cavity_q"]))
            rot_hz.append(round(v / circ, 2))
        info_groups.append({"name": grp["name"], "tyres": grp["n"], "rot_hz": rot_hz,
                            "pitch_hz": round(v / (grp["pitch_mm"] / 1000.0), 1)})
    rb = prm["rumble"]
    comp["rumble"] = circ_noise(rng, n, hump(f, rb["peak"], rb["slope_lo"], rb["slope_hi"])) * slow_variation(
        rng, n, 0.5, 4.0, rb["depth_db"]) * common
    horn = bell_db(f, prm["horn"]["hz"], prm["horn"]["db"], prm["horn"]["width_oct"])
    y = np.zeros(n)
    for c, x in comp.items():
        x = x / (rms(x) + 1e-30) * 10.0 ** (prm["levels"][c] / 20.0)
        if c in ("texture", "tread", "pump"):           # radiated near the contact patch
            x = circ_filter(x, horn)
        y += x
    y = circ_filter(y, es.highpass_gain(f, HP_HZ, 2) * es.lowpass_gain(f, prm["lowpass_hz"], 2))
    total = es.loudness_db(y)
    info = {"kind": "tires", "label": prm["label"], "kmh": prm["kmh"], "groups": info_groups,
            "components_lu": {c: round(es.loudness_db(x / (rms(x) + 1e-30) * 10.0 ** (prm["levels"][c] / 20.0))
                                       - total, 1) for c, x in comp.items()},
            "tonality_db": round(tonality_db(y), 1)}
    return y, info


# ------------------------------------------------------------------------------------------------
# Air: flow noise around the vehicle body
# ------------------------------------------------------------------------------------------------
# bands: peak (Hz), slopes below/above (dB/oct), level (dB), gust depth (dB at 1 sigma) and gust frequencies (Hz)

AIR = {
    "label": "Umströmung eines Fahrzeugs (Nachlauf, Ablösung an A-Säule/Spiegel/Radhäusern, Spalte), 120 km/h",
    "kmh": 120.0,
    "bands": [
        {"name": "Nachlauf (Wirbel hinter dem Fahrzeug)", "peak": 90.0, "slope_lo": 9.0, "slope_hi": -6.0,
         "db": 0.0, "gust_db": 3.0, "gust_hz": [1.5, 6.0]},
        {"name": "Ablösung A-Säule/Spiegel/Radhäuser", "peak": 350.0, "slope_lo": 6.0, "slope_hi": -9.0,
         "db": -3.0, "gust_db": 2.0, "gust_hz": [2.0, 9.0]},
        {"name": "Spalte und Kanten (Zischen)", "peak": 2800.0, "slope_lo": 6.0, "slope_hi": -10.0,
         "db": -24.0, "gust_db": 1.2, "gust_hz": [3.0, 12.0]},
    ],
    "lowpass_hz": 8000.0,
}


def air_loop(name: str, prm: dict) -> tuple:
    rng = np.random.default_rng(es.seed_of(name, "air"))
    n = int(round(LOOP_S * SR))
    f = freqs(n)
    y = np.zeros(n)
    bands = {}
    for b in prm["bands"]:
        x = circ_noise(rng, n, hump(f, b["peak"], b["slope_lo"], b["slope_hi"]))
        x *= slow_variation(rng, n, *b["gust_hz"], b["gust_db"])
        x *= 10.0 ** (b["db"] / 20.0) / (rms(x) + 1e-30)
        bands[b["name"]] = x
        y += x
    y = circ_filter(y, es.highpass_gain(f, HP_HZ, 2) * es.lowpass_gain(f, prm["lowpass_hz"], 2))
    total = es.loudness_db(y)
    info = {"kind": "air", "label": prm["label"], "kmh": prm["kmh"],
            "components_lu": {k: round(es.loudness_db(x) - total, 1) for k, x in bands.items()},
            "tonality_db": round(tonality_db(y), 1)}
    return y, info


# ------------------------------------------------------------------------------------------------
# Levels, checks, files
# ------------------------------------------------------------------------------------------------

def finish(y: np.ndarray) -> np.ndarray:
    """No DC (mean of the loop removed), K-weighted loudness REF_LUFS."""
    y = y - np.mean(y)
    return y * 10.0 ** ((REF_LUFS - es.loudness_db(y)) / 20.0)


def to_pcm(y: np.ndarray) -> np.ndarray:
    return np.clip(np.round(y * 32767.0), -32768, 32767).astype("<i2")


def loop_checks(x: np.ndarray) -> dict:
    """Seam and level checks of a loop as it is stored (x = int16 samples / 32768), all circular:
    - seam_step_pct: percentile of the step x[0] - x[-1] among all sample steps of the loop (a jump would be ~100)
    - seam_hf_pct:   percentile of the high-frequency energy (> 4 kHz, 2 ms window) centred on the loop point
                     among the same windows at every position (a click would be ~100)
    - seam_env_db:   level step of the 50 ms envelope across the loop point vs. the largest step elsewhere
    - dc_lsb, peak/rms dBFS, loudness (K-weighted, LUFS without gating), A-weighted level, envelope range."""
    n = len(x)
    d = np.diff(np.concatenate([x, x[:1]]))
    seam_step = abs(d[-1])
    f = freqs(n)
    hf = circ_filter(x, es.highpass_gain(f, 4000.0, 4))
    w = int(0.002 * SR)
    e = np.convolve(np.concatenate([hf[-w:], hf, hf[:w]]) ** 2, np.ones(w) / w, mode="same")[w:-w]
    seam_e = float(max(e[: w // 2].max(), e[-(w // 2):].max()))
    we = int(0.05 * SR)
    env = np.sqrt(np.convolve(np.concatenate([x[-we:], x, x[:we]]) ** 2, np.ones(we) / we, mode="same")[we:-we])
    env_db = 20.0 * np.log10(env + 1e-9)
    steps = np.abs(np.diff(env_db[::we // 2]))
    seam_env = abs(env_db[0] - env_db[-we // 2])
    return {"samples": n, "seconds": round(n / SR, 4),
            "seam_step_pct": round(100.0 * float(np.mean(np.abs(d) < seam_step)), 1),
            "seam_hf_pct": round(100.0 * float(np.mean(e < seam_e)), 1),
            "seam_env_db": round(float(seam_env), 2), "env_step_max_db": round(float(steps.max()), 2),
            "env_range_db": round(float(env_db.max() - env_db.min()), 1),
            "dc_lsb": round(float(np.mean(x)) * 32768.0, 3),
            "peak_dbfs": round(20.0 * math.log10(float(np.max(np.abs(x))) + 1e-12), 2),
            "rms_dbfs": round(20.0 * math.log10(rms(x) + 1e-12), 2),
            "loudness_lufs": round(es.loudness_db(x), 2), "level_dba": round(es.level_a_db(x), 2)}


def write_wav(path: str, pcm: np.ndarray) -> None:
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def read_wav(path: str) -> np.ndarray:
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == SR, path
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0


IMPORT_PARAMS = ["force/8_bit=false", "force/mono=false", "force/max_rate=false", "force/max_rate_hz=44100",
                 "edit/trim=false", "edit/normalize=false", "edit/loop_mode=2", "edit/loop_begin=0",
                 "edit/loop_end={n}", "compress/mode=0"]


def write_import(wav_path: str, n: int) -> None:
    """Godot import settings next to the WAV: uncompressed 16-bit PCM (sample-exact loop, no QOA default) and a
    forward loop over the whole file. loop_end = n exactly: Godot plays [loop_begin, loop_end) and wraps (the
    importer's default -1 becomes n - 1, one sample short). Godot completes uid/path on the next import."""
    path = wav_path + ".import"
    params = "\n".join(p.format(n=n) for p in IMPORT_PARAMS)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            head = fh.read().split("[params]")[0].rstrip("\n")
    else:
        rel = os.path.relpath(wav_path, ROOT).replace(os.sep, "/")
        head = f'[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\n\nsource_file="res://{rel}"'
    text = head + "\n\n[params]\n\n" + params + "\n"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def format_json(meta: dict) -> str:
    """One line per sound/class/loop (readable diffs)."""
    def block(name, d, indent, last):
        pad = " " * indent
        lines = [f'{pad}"{name}": {{']
        items = list(d.items())
        for j, (k, v) in enumerate(items):
            end = "," if j < len(items) - 1 else ""
            if isinstance(v, dict) and k == "loops":
                lines += block(k, v, indent + 2, j == len(items) - 1)
            else:
                lines.append(f'{pad}  "{k}": ' + json.dumps(v, ensure_ascii=False) + end)
        lines.append(pad + "}" + ("" if last else ","))
        return lines

    lines = ["{"]
    keys = list(meta)
    for i, k in enumerate(keys):
        last = i == len(keys) - 1
        if isinstance(meta[k], dict) and k in ("sounds", "classes", "synth"):
            lines += block(k, meta[k], 2, last)
        else:
            lines.append(f'  "{k}": ' + json.dumps(meta[k], ensure_ascii=False) + ("" if last else ","))
    lines.append("}")
    return "\n".join(lines) + "\n"


def build(names: list, out_dir: str, log=print) -> dict:
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "traffic_sounds.json")
    loops_info = {}
    if os.path.exists(json_path):
        with open(json_path, encoding="utf-8") as fh:
            loops_info = json.load(fh).get("synth", {}).get("loops", {})
    profiles = engine_profiles()
    in_project = os.path.abspath(out_dir).startswith(ROOT + os.sep)
    for name in names:
        t0 = time.time()
        layer = SOUNDS[name]["layer"]
        if layer == "engine":
            y, info = engine_loop(name, profiles[name])
        elif layer == "tires":
            y, info = tire_loop(name, TIRES[name])
        else:
            y, info = air_loop(name, AIR)
        y = finish(y)
        pk = float(np.max(np.abs(y)))
        if pk > PEAK_MAX:
            raise SystemExit(f"{name}: Spitze {pk:.3f} bei {REF_LUFS} LUFS über {PEAK_MAX} - REF_LUFS senken")
        pcm = to_pcm(y)
        path = os.path.join(out_dir, SOUNDS[name]["file"])
        write_wav(path, pcm)
        if in_project:
            write_import(path, len(pcm))
        chk = loop_checks(pcm.astype(np.float64) / 32768.0)
        loops_info[name] = {**info, **chk}
        extra = (f"{info['rpm']:.0f}/min, {info['cycles']} Arbeitsspiele, Naht-Korrelation {info['splice_rho']:.2f}"
                 if layer == "engine" else f"{info['kmh']:.0f} km/h, Tonalität {info['tonality_db']:.1f} dB")
        log(f"{name}: {chk['seconds']:.3f} s ({extra}); Spitze {chk['peak_dbfs']:.1f} dBFS, "
            f"{chk['loudness_lufs']:.1f} LUFS, {chk['level_dba']:.1f} dB(A); "
            f"Naht: Sprung P{chk['seam_step_pct']:.0f}, HF P{chk['seam_hf_pct']:.0f}, "
            f"Hüllkurve {chk['seam_env_db']:.2f} dB (sonst max {chk['env_step_max_db']:.2f}); "
            f"{time.time() - t0:.1f} s")
        log("   Anteile (K-bewertet, dB re gesamt): "
            + ", ".join(f"{k} {v:+.1f}" for k, v in info["components_lu"].items()))
    meta = {"format": FORMAT, "sample_rate": SR, "sounds": SOUNDS, "classes": CLASSES, "models": MODELS,
            "synth": {"generator": "tools/audio/traffic_synth.py", "model": MODEL,
                      "loudness_lufs": REF_LUFS,
                      "loudness": "jede Schleife K-bewertet (BS.1770 ohne Gating) über die ganze Schleife gleich "
                                  "laut; Pegelverhältnisse nur über gain_db und level_db_per_decade",
                      "seam": "seam_step_pct/seam_hf_pct = Perzentil des Sprungs bzw. der HF-Energie an der Naht "
                              "unter allen Positionen (Klick wäre ~100)",
                      "loops": {k: loops_info[k] for k in SOUNDS if k in loops_info}}}
    with open(json_path, "w", encoding="utf-8") as fh:
        fh.write(format_json(meta))
    return meta


def info_plan() -> None:
    profiles = engine_profiles()
    for name, s in SOUNDS.items():
        if s["layer"] == "engine":
            c = profiles[name]["cruise"]
            P = int(round(120.0 * SR / c["rpm"]))
            K = max(2, int(round(LOOP_S * SR / P)))
            print(f"{name}: {profiles[name]['engine']['label']}, {c['kmh']:.0f} km/h bei {120.0 * SR / P:.1f}/min, "
                  f"Periode {P} Samples, {K} Arbeitsspiele = {K * P} Samples ({K * P / SR:.3f} s)")
        else:
            prm = TIRES.get(name, AIR)
            print(f"{name}: {prm['label']}, {int(round(LOOP_S * SR))} Samples ({LOOP_S:.3f} s)")


def check_existing(out_dir: str) -> int:
    bad = 0
    for name, s in SOUNDS.items():
        path = os.path.join(out_dir, s["file"])
        if not os.path.exists(path):
            print(f"{name}: fehlt ({path})")
            bad += 1
            continue
        chk = loop_checks(read_wav(path))
        ok = (2.0 <= chk["seconds"] <= 4.0 and chk["peak_dbfs"] <= 20 * math.log10(PEAK_MAX) + 0.05
              and chk["seam_step_pct"] < 99.5 and chk["seam_hf_pct"] < 99.5 and abs(chk["dc_lsb"]) < 1.0)
        bad += 0 if ok else 1
        print(f"{name}: {'ok' if ok else 'FEHLER'} {json.dumps(chk, ensure_ascii=False)}")
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Verkehrsgeräusche: Schleifen für Motor, Reifen und Fahrtwind "
                                             "(docs/verkehrsgeraeusche.md)")
    ap.add_argument("--only", action="append", choices=list(SOUNDS), help="nur diese Schleife (mehrfach möglich)")
    ap.add_argument("--out", default=OUT_DIR, help="Zielordner")
    ap.add_argument("--info", action="store_true", help="nur den Plan anzeigen (Drehzahlen, Längen)")
    ap.add_argument("--check", action="store_true", help="nur die vorhandenen Schleifen prüfen")
    args = ap.parse_args(argv)
    if args.info:
        info_plan()
        return 0
    if args.check:
        return check_existing(args.out)
    build(args.only or list(SOUNDS), args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
