"""Loaders for the old (mono, format 1) and the spike (stereo) engine banks."""
import json, os
import numpy as np


class Bank:
    def __init__(self, path_json: str):
        with open(path_json, encoding="utf-8") as fh:
            self.meta = json.load(fh)
        base = os.path.dirname(path_json)
        self.ch = int(self.meta.get("channels", 1))
        raw = np.fromfile(os.path.join(base, self.meta["data"]), dtype="<f4").astype(np.float64)
        self.data = raw.reshape(-1, self.ch)
        self.sr = int(self.meta["sample_rate"])
        rpms = sorted({float(b["rpm"]) for b in self.meta["banks"]})
        self.rpms = np.array(rpms)
        self.src = {}
        for b in self.meta["banks"]:
            i = rpms.index(float(b["rpm"]))
            self.src[(i, b["load"])] = {"period": float(b["period"]), "overlap": int(b["overlap"]),
                                        "cycles": [self.data[o:o + n] for o, n in b["cycles"]], "rpm": float(b["rpm"])}
        self.clips = {k: [self.data[o:o + n] for o, n in v] for k, v in self.meta.get("clips", {}).items()}
        self.engine = self.meta["engine"]
        self.layers = self.meta.get("layers", {})
        self.gearbox = self.meta["gearbox"]
        self.mix = self.meta.get("mix", {"gain": 1.0, "off_gain": 1.0})

    def steady(self, i: int, load: str) -> np.ndarray:
        s = self.src[(i, load)]
        P = int(round(s["period"]))
        return np.concatenate([c[:P] for c in s["cycles"]], axis=0)
