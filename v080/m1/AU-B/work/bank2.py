"""Scratch loader of ce-engine-bank-2 (and of the Arcade format 1) for analysis."""
import json, os, math
import numpy as np


class Bank2:
    def __init__(self, path_json):
        self.meta = json.load(open(path_json, encoding="utf-8"))
        base = os.path.dirname(path_json)
        raw = np.fromfile(os.path.join(base, self.meta["data"]), "<i2").astype(np.float64) / 32768.0
        self.data = raw.reshape(-1, 2)
        self.sr = int(self.meta["sample_rate"])
        self.rpms = np.array(sorted({float(b["rpm"]) for b in self.meta["banks"]}))
        self.src = {}
        for b in self.meta["banks"]:
            i = int(np.argmin(np.abs(self.rpms - float(b["rpm"]))))
            cyc = []
            for off, ln, mode in b["cycles"]:
                blk = self.data[off:off + ln]
                if mode == 0:
                    cyc.append(blk * b["gain"])
                else:
                    m = blk[:, mode - 1] * b["gain"]
                    cyc.append(np.stack([m, m], axis=1))
            self.src[(i, b["layer"])] = {"period": int(b["period"]), "overlap": int(b["overlap"]), "cycles": cyc,
                                         "rpm": float(b["rpm"]), "meta": b}
        self.mix = self.meta["mix"]
        self.layers = self.meta["layers"]

    def steady(self, i, layer):
        s = self.src[(i, layer)]
        return np.concatenate([c[:s["period"]] for c in s["cycles"]], axis=0)


class Bank1:
    def __init__(self, path_json):
        self.meta = json.load(open(path_json, encoding="utf-8"))
        base = os.path.dirname(path_json)
        self.data = np.fromfile(os.path.join(base, self.meta["data"]), "<f4").astype(np.float64)
        self.sr = int(self.meta["sample_rate"])
        self.rpms = np.array(sorted({float(b["rpm"]) for b in self.meta["banks"]}))
        self.src = {}
        for b in self.meta["banks"]:
            i = int(np.argmin(np.abs(self.rpms - float(b["rpm"]))))
            self.src[(i, b["load"])] = {"period": int(b["period"]), "overlap": int(b["overlap"]),
                                        "cycles": [self.data[o:o + n] for o, n in b["cycles"]], "rpm": float(b["rpm"])}
        self.mix = self.meta["mix"]

    def steady(self, i, layer):
        s = self.src[(i, layer)]
        x = np.concatenate([c[:s["period"]] for c in s["cycles"]])
        return np.stack([x, x], axis=1)
