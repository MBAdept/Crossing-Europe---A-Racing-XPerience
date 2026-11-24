"""Shared code of the generators of the Modern sound files (tools/audio/modern/*.py; contract §4.7.3).

A generator renders its sounds with numpy, writes them through the writers below and registers them in the manifest
of their folder (assets/audio/modern/<folder>/manifest.json, format "ce-audio-manifest-1" – read by
scripts/audio/modern/modern_audio_assets.gd, checked by tools/audio/qc/audio_qc.py). Conventions:

  * deterministic: the same call writes the same bytes (fixed seeds, no time stamps; Vorbis through ffmpeg with the
    bit-exact flags) – the QC tool renders every generator twice and compares;
  * every generator takes --out <dir> and then writes its folders below <dir> instead of into the repository
    (without Godot import files);
  * formats: music Ogg Vorbis q5, ambience q3–q4, loops and one-shots 16-bit WAV, all 44.1 kHz; engine banks raw
    interleaved int16 at 32 kHz stereo (<car>.i16 next to <car>.json);
  * the measured values in the manifest are those of the file as written (after Vorbis);
  * the frozen Arcade tools (tools/audio/{engine,traffic,music}_synth.py) may be imported, never edited:
    sys.path already contains tools/audio when this module is imported.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.dont_write_bytecode = True
for _p in (os.path.join(ROOT, "tools", "audio"), os.path.join(ROOT, "tools", "audio", "qc")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import qc_lib  # noqa: E402

ASSETS_REL = "assets/audio/modern"
FOLDERS = ["engines", "vehicle", "traffic", "sfx", "ambience", "ui", "music"]
FORMAT = "ce-audio-manifest-1"
SR = 44100
BANK_SR = 32000
KINDS = ("oneshot", "loop", "music", "bank")
ENTRY_KEYS = ["file", "files", "kind", "role", "bus", "gain_db", "lufs", "true_peak_db", "sample_rate", "channels",
              "frames", "loop", "bpm", "beats", "bar_beats", "bytes", "sha256", "placeholder", "generator", "note"]


def assets_dir(out: str | None) -> str:
    """The Modern asset folder in the repository, or below --out."""
    return os.path.join(out, ASSETS_REL) if out else os.path.join(ROOT, ASSETS_REL)


# --- writers ------------------------------------------------------------------------------------------------------

def _as2d(x) -> np.ndarray:
    x = np.asarray(x, np.float64)
    return x[:, None] if x.ndim == 1 else x


def to_int16(x) -> np.ndarray:
    """Rounds to 16 bit (no dither: reproducible; the sounds are far above the quantisation noise)."""
    return np.clip(np.rint(_as2d(x) * 32767.0), -32768, 32767).astype("<i2")


def write_wav16(path: str, x, sr: int = SR) -> None:
    """16-bit PCM WAV with a minimal header (no time stamps)."""
    pcm = to_int16(x)
    ch = pcm.shape[1]
    data = pcm.tobytes()
    hdr = b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVEfmt " + (16).to_bytes(4, "little")
    hdr += (1).to_bytes(2, "little") + ch.to_bytes(2, "little") + sr.to_bytes(4, "little")
    hdr += (sr * ch * 2).to_bytes(4, "little") + (ch * 2).to_bytes(2, "little") + (16).to_bytes(2, "little")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(hdr + b"data" + len(data).to_bytes(4, "little") + data)


def write_i16(path: str, x) -> None:
    """Raw interleaved little-endian int16 (engine banks)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(to_int16(x).tobytes())


def write_ogg(path: str, x, sr: int = SR, quality: float = 5.0, title: str = "") -> None:
    """Ogg Vorbis through ffmpeg, bit-exact (fixed stream serial, no encoder version tag)."""
    x = _as2d(x)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cmd = [qc_lib.ffmpeg(), "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(sr), "-ac", str(x.shape[1]), "-i", "-",
           "-c:a", "libvorbis", "-q:a", f"{quality:g}", "-fflags", "+bitexact", "-flags:a", "+bitexact",
           "-map_metadata", "-1"]
    if title:
        cmd += ["-metadata", "title=" + title]
    subprocess.run(cmd + [path], input=x.astype("<f4").tobytes(), check=True)


# --- Godot import settings ----------------------------------------------------------------------------------------

def _res_path(path: str) -> str:
    return "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")


def _import_head(path: str, importer: str, res_type: str) -> str:
    """The [remap]/[deps] part: kept from an existing .import (uid and import path stay valid), else a minimal one
    that Godot completes on its next import."""
    imp = path + ".import"
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as fh:
            return fh.read().split("[params]")[0].rstrip("\n")
    return f'[remap]\n\nimporter="{importer}"\ntype="{res_type}"\n\n[deps]\n\nsource_file="{_res_path(path)}"'


def write_wav_import(path: str, loop: tuple[int, int] | None) -> None:
    """Import settings of a WAV: uncompressed PCM as written; loop = (begin, end) in frames, forward, or no loop."""
    params = ["force/8_bit=false", "force/mono=false", "force/max_rate=false", "force/max_rate_hz=44100",
              "edit/trim=false", "edit/normalize=false",
              "edit/loop_mode=%d" % (2 if loop else 1),
              "edit/loop_begin=%d" % (loop[0] if loop else 0),
              "edit/loop_end=%d" % (loop[1] if loop else -1),
              "compress/mode=0"]
    with open(path + ".import", "w", encoding="utf-8") as fh:
        fh.write(_import_head(path, "wav", "AudioStreamWAV") + "\n\n[params]\n\n" + "\n".join(params) + "\n")


def write_ogg_import(path: str, loop_offset_s: float | None, bpm: float = 0.0, beats: int = 0, bar_beats: int = 4) -> None:
    """Import settings of an Ogg Vorbis file: loop from loop_offset_s (None = plays once), tempo data for
    AudioStreamInteractive (bpm 0 = none)."""
    params = ["loop=%s" % ("true" if loop_offset_s is not None else "false"),
              "loop_offset=%s" % (f"{loop_offset_s:g}" if loop_offset_s is not None else "0"),
              "bpm=%s" % f"{bpm:g}", "beat_count=%d" % beats, "bar_beats=%d" % bar_beats]
    with open(path + ".import", "w", encoding="utf-8") as fh:
        fh.write(_import_head(path, "oggvorbisstr", "AudioStreamOggVorbis") + "\n\n[params]\n\n" + "\n".join(params) + "\n")


# --- manifest -----------------------------------------------------------------------------------------------------

def describe(path: str, kind: str, channels_bank: int = 2, sr_bank: int = BANK_SR) -> dict:
    """Measured values of a written file for its manifest entry: lufs, true_peak_db, sample_rate, channels, frames,
    bytes, sha256."""
    if kind == "bank":
        x = qc_lib.read_i16(path, channels_bank)
        sr = sr_bank
    else:
        x, sr = qc_lib.read_audio(path)
    return {"lufs": round(qc_lib.integrated_lufs(x, sr), 2), "true_peak_db": round(qc_lib.true_peak_db(x), 2),
            "sample_rate": sr, "channels": int(x.shape[1]), "frames": int(len(x)), "bytes": os.path.getsize(path),
            "sha256": qc_lib.sha256(path)}


class Manifest:
    """manifest.json of one folder. Entries of other generators stay; a generator replaces only its own."""

    def __init__(self, folder: str, out: str | None = None):
        if folder not in FOLDERS:
            raise ValueError(f"unbekannter Ordner {folder}")
        self.folder = folder
        self.dir = os.path.join(assets_dir(out), folder)
        self.path = os.path.join(self.dir, "manifest.json")
        self.sounds: dict[str, dict] = {}
        if os.path.exists(self.path):
            with open(self.path, encoding="utf-8") as fh:
                d = json.load(fh)
            if d.get("format") != FORMAT:
                raise ValueError(f"{self.path}: Format {d.get('format')!r}")
            self.sounds = dict(d.get("sounds", {}))

    def file(self, name: str) -> str:
        return os.path.join(self.dir, name)

    def drop_generator(self, generator: str) -> None:
        """Forgets every entry a generator wrote before (it then registers what it writes now)."""
        self.sounds = {k: v for k, v in self.sounds.items() if v.get("generator") != generator}

    def add(self, sound_id: str, files: str | list[str], kind: str, generator: str, loop: tuple[int, int] | None = None,
            **fields) -> dict:
        """Registers a written sound: measures its file(s) and stores the entry. Extra fields: role, bus, gain_db, bpm,
        beats, bar_beats, placeholder, note."""
        if kind not in KINDS:
            raise ValueError(f"{sound_id}: Art {kind!r}")
        names = [files] if isinstance(files, str) else list(files)
        infos = [describe(self.file(n), kind) for n in names]
        first = infos[0]
        for other in infos[1:]:
            if (other["sample_rate"], other["channels"]) != (first["sample_rate"], first["channels"]):
                raise ValueError(f"{sound_id}: Varianten mit verschiedenem Format")
        e: dict = {"file": names[0]} if len(names) == 1 else {"files": names}
        e["kind"] = kind
        e.update({k: v for k, v in fields.items() if v is not None})
        e["lufs"] = first["lufs"] if len(infos) == 1 else round(float(np.mean([i["lufs"] for i in infos])), 2)
        e["true_peak_db"] = max(i["true_peak_db"] for i in infos)
        e["sample_rate"] = first["sample_rate"]
        e["channels"] = first["channels"]
        e["frames"] = first["frames"]
        e["loop"] = [int(loop[0]), int(loop[1])] if loop else None
        e["bytes"] = first["bytes"] if len(infos) == 1 else [i["bytes"] for i in infos]
        e["sha256"] = first["sha256"] if len(infos) == 1 else [i["sha256"] for i in infos]
        e["generator"] = generator
        self.sounds[sound_id] = {k: e[k] for k in ENTRY_KEYS if k in e}
        return self.sounds[sound_id]

    def save(self) -> None:
        """One sound per line, sorted by id (readable diffs)."""
        os.makedirs(self.dir, exist_ok=True)
        lines = ["{", f'\t"format": "{FORMAT}",', f'\t"folder": "{self.folder}",', '\t"sounds": {']
        ids = sorted(self.sounds)
        for i, sid in enumerate(ids):
            end = "," if i < len(ids) - 1 else ""
            lines.append(f"\t\t{json.dumps(sid, ensure_ascii=False)}: "
                         + json.dumps(self.sounds[sid], ensure_ascii=False) + end)
        lines += ["\t}", "}"]
        with open(self.path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")


# --- small DSP helpers for generators -----------------------------------------------------------------------------

def normalize_lufs(x, sr: int, target: float) -> np.ndarray:
    """Scales to an integrated loudness."""
    x = _as2d(x)
    return x * 10.0 ** ((target - qc_lib.integrated_lufs(x, sr)) / 20.0)


def limit_true_peak(x, ceiling_db: float) -> np.ndarray:
    """Scales down (never up) so that the true peak is at or below the ceiling."""
    x = _as2d(x)
    over = qc_lib.true_peak_db(x) - ceiling_db
    return x * 10.0 ** (-over / 20.0) if over > 0.0 else x


def periodic_noise(n: int, sr: int, seed: int, shape) -> np.ndarray:
    """Noise that repeats exactly after n samples (a seamless loop by construction): random phases, magnitude
    shape(f) per frequency, normalised to a peak of 1."""
    rng = np.random.default_rng(seed)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    mag = np.asarray(shape(np.maximum(f, 1e-6)), np.float64)
    mag[0] = 0.0
    spec = mag * np.exp(2j * np.pi * rng.random(len(f)))
    y = np.fft.irfft(spec, n)
    return y / max(float(np.max(np.abs(y))), 1e-12)
