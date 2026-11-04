#!/usr/bin/env python3
"""Glitch RNG sound synthesizer.

Renders every sound named in src/shared/Sounds.lua to build/sfx/<Name>.ogg
(Vorbis q6, 44.1 kHz; mono UI sounds, stereo reveals/booms/music) and writes
build/sfx/index.txt with duration / peak / RMS of each decoded file.

All audio is synthesized from scratch with numpy (see tools/audio/):
  dsp.py          oscillators, envelopes, biquads, sweeps, reverb, delay, limiter...
  instruments.py  drum kit, bells, brass, choir, sparkles, music line renderers
  sfx_defs.py     one-shot sound effects
  music.py        seamless music loops

Usage:
  python3 tools/sfx.py              # render everything
  python3 tools/sfx.py Click Boom   # render only these
  python3 tools/sfx.py --jobs 2     # limit parallel workers (default 3)
Nothing is uploaded; tools/upload_sounds.py does that separately.
"""
from __future__ import annotations

import argparse
import math
import pathlib
import re
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from audio import dsp  # noqa: E402
from audio.music import REGISTRY as MUSIC  # noqa: E402
from audio.sfx_defs import REGISTRY as SFX  # noqa: E402

OUT = ROOT / "build" / "sfx"
SOUNDS_LUA = ROOT / "src" / "shared" / "Sounds.lua"
FFMPEG = "/usr/bin/ffmpeg"
QUALITY = "6"
CLIP_LIMIT_DB = -0.3


def sound_names() -> list[str]:
    txt = SOUNDS_LUA.read_text()
    return re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*\"", txt, re.M)


def encode(x: np.ndarray, path: pathlib.Path) -> None:
    ch = 1 if x.ndim == 1 else 2
    data = (x.T if ch == 2 else x).astype("<f4").tobytes()
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(dsp.SR), "-ac", str(ch),
           "-i", "-", "-c:a", "libvorbis", "-q:a", QUALITY, "-ar", str(dsp.SR), str(path)]
    subprocess.run(cmd, input=data, check=True)


def decode(path: pathlib.Path) -> np.ndarray:
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ar", str(dsp.SR), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    probe = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path)], capture_output=True, text=True).stderr
    ch = 2 if "stereo" in probe else 1
    a = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    return a.reshape(-1, ch).T if ch == 2 else a


def analyse(x: np.ndarray, music: bool) -> dict:
    mono = x.mean(axis=0) if x.ndim == 2 else x
    n = len(mono)
    peak = float(np.abs(x).max()) if n else 0.0
    rms = float(np.sqrt(np.mean(mono**2))) if n else 0.0
    dc = float(np.mean(mono)) if n else 0.0
    warn = []
    if not np.all(np.isfinite(x)):
        warn.append("NaN/Inf")
    if peak <= 0:
        warn.append("SILENT")
    pdb = 20 * math.log10(peak + 1e-12)
    if pdb > CLIP_LIMIT_DB:
        warn.append(f"peak {pdb:.2f} dBFS > {CLIP_LIMIT_DB}")
    if abs(dc) > 2e-3:
        warn.append(f"DC {dc:.4f}")
    # silence holes: windows of 250 ms (music: 1 s) far below the file's RMS
    w = dsp.ns(1.0 if music else 0.05)
    if n > 2 * w:
        k = n // w
        seg = np.sqrt(np.mean(mono[: k * w].reshape(k, w) ** 2, axis=1))
        if music:
            if seg.min() < db_(-50):
                warn.append(f"silent 1s window ({20*math.log10(seg.min()+1e-12):.0f} dB)")
        elif seg[0] < db_(-45):
            warn.append("silent start")
    return {"dur": n / dsp.SR, "peak_db": pdb, "rms_db": 20 * math.log10(rms + 1e-12), "dc": dc,
            "ch": 2 if x.ndim == 2 else 1, "warn": warn}


def db_(v):
    return 10 ** (v / 20)


def render(name: str) -> tuple[str, dict, float]:
    t0 = time.time()
    rng = dsp.rng_for(name)
    path = OUT / f"{name}.ogg"
    music = name in MUSIC
    if music:
        x = MUSIC[name](rng)
        target = None
    else:
        fn, peak, stereo = SFX[name]
        x = dsp.finish(fn(rng), peak, stereo=stereo, trim=(name != "Riser"), fade_out=0.006 if name == "Riser" else 0.015)
        target = peak
    if not np.all(np.isfinite(x)):
        raise RuntimeError(f"{name}: non-finite samples")
    # encode, then verify the decoded file; pull the gain down if Vorbis overshoots
    for _ in range(4):
        encode(x, path)
        dec = decode(path)
        info = analyse(dec, music)
        if info["peak_db"] <= CLIP_LIMIT_DB - 0.05:
            break
        x = x * db_(CLIP_LIMIT_DB - 0.25 - info["peak_db"])
    info["target"] = target
    return name, info, time.time() - t0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--jobs", type=int, default=3)
    args = ap.parse_args()
    names = sound_names()
    missing = [n for n in names if n not in SFX and n not in MUSIC]
    if missing:
        print("No generator for:", ", ".join(missing), file=sys.stderr)
        return 1
    todo = args.names or names
    for n in todo:
        if n not in names:
            print(f"Unknown sound {n}", file=sys.stderr)
            return 1
    OUT.mkdir(parents=True, exist_ok=True)
    # longest jobs first so the pool stays busy
    order = sorted(todo, key=lambda n: (n not in MUSIC, n not in ("Reveal5", "Reveal4", "Boom")))
    t0 = time.time()
    results: dict[str, dict] = {}
    with ProcessPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        futs = {ex.submit(render, n): n for n in order}
        for f in as_completed(futs):
            name, info, dt = f.result()
            results[name] = info
            flag = ("  !! " + "; ".join(info["warn"])) if info["warn"] else ""
            print(f"{name:<11} {info['dur']:6.2f}s  peak {info['peak_db']:6.2f} dBFS  rms {info['rms_db']:6.1f} dB  {'stereo' if info['ch']==2 else 'mono  '}  ({dt:4.1f}s){flag}", flush=True)
    # index over everything present on disk (keeps entries of sounds not re-rendered this run)
    lines = [f"# Glitch RNG SFX — generated by tools/sfx.py ({time.strftime('%Y-%m-%d %H:%M')})",
             "# name         file              dur(s)  peak(dBFS)  rms(dB)  ch  notes"]
    bad = 0
    for n in names:
        p = OUT / f"{n}.ogg"
        if not p.exists():
            lines.append(f"{n:<14} MISSING")
            bad += 1
            continue
        info = results.get(n) or analyse(decode(p), n in MUSIC)
        note = "loop" if n in MUSIC else ""
        if info["warn"]:
            note += (" " if note else "") + "WARN: " + "; ".join(info["warn"])
            bad += 1
        lines.append(f"{n:<14} {p.name:<17} {info['dur']:7.2f}  {info['peak_db']:9.2f}  {info['rms_db']:7.1f}  {info['ch']:>2}  {note}")
    (OUT / "index.txt").write_text("\n".join(lines) + "\n")
    print(f"done in {time.time() - t0:.1f}s, {len(results)} rendered, {bad} problem(s); index -> {OUT / 'index.txt'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
