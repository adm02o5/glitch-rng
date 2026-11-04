"""Music v2: a parametric arranger used for the dynamic biome music and the
per-aura themes.

A song is a spec (tempo, key/mode, progression, groove, bass/arp/lead voices,
special layers) plus an arrangement of sections. Every section type switches
layers on/off and shapes filters/levels per bar, the last bar of a section gets
a fill (toms, snare roll, stutter, or a cut-out), builds get risers and snare
rolls, drops get crashes and sub hits — so the loop moves instead of sitting on
one groove. Loops are seamless (Song.wrap + circular mastering, see music.py).
"""
from __future__ import annotations

import math

import numpy as np

from .dsp import (
    SR, TAU, adsr, chorus, convolve, crush, db, delay, drive, filt, fit, mtof, noise,
    ns, pan, perc, phase, pink, place, pulse, reverb_ir, saw, sine, square, supersaw,
    sweep, to_stereo,
)
from .instruments import bell, choir, clap, crash, hat, kick, pluck, snare, sub_drop, tom
from .music import Song, master, render_mono_line, render_pad, vinyl

MODES = {
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "locrian": [0, 1, 3, 5, 6, 8, 10],
}

# what each section type plays: kick, snare, hats, bass, pad, arp, lead, sub-intensity
SECTION = {
    "intro": dict(kick=0, snare=0, hats=1, bass=0, pad=1, arp=1, lead=0, filt=0.25, level=0.75),
    "verse": dict(kick=1, snare=1, hats=1, bass=1, pad=1, arp=1, lead=0, filt=0.6, level=0.85),
    "build": dict(kick=2, snare=2, hats=1, bass=1, pad=1, arp=1, lead=0, filt=0.4, level=0.85),
    "drop": dict(kick=1, snare=1, hats=2, bass=1, pad=1, arp=1, lead=1, filt=1.0, level=1.0),
    "half": dict(kick=3, snare=3, hats=1, bass=2, pad=1, arp=0, lead=1, filt=0.8, level=1.0),
    "break": dict(kick=0, snare=0, hats=0, bass=0, pad=1, arp=1, lead=1, filt=0.35, level=0.7),
    "sparse": dict(kick=4, snare=0, hats=1, bass=3, pad=1, arp=0, lead=0, filt=0.4, level=0.75),
    "out": dict(kick=1, snare=1, hats=1, bass=1, pad=1, arp=1, lead=0, filt=0.5, level=0.85),
}


def _chord(root, mode, deg, size=4, inv=0):
    sc = MODES[mode]
    ms = []
    for k in range(size):
        i = deg + 2 * k
        ms.append(root + sc[i % 7] + 12 * (i // 7))
    for _ in range(inv):
        ms = ms[1:] + [ms[0] + 12]
    return ms


def _scale_notes(root, mode, lo, hi):
    out = []
    for o in range(-2, 6):
        for s in MODES[mode]:
            m = root + 12 * o + s
            if lo <= m <= hi:
                out.append(m)
    return sorted(out)


def _melody(r, root, mode, bars_n, chords_of, lo, hi, density=0.55, long_end=True):
    """4-bar motif (A A' B A'') over the progression; returns [(beat, len_beats, midi)]."""
    sc = _scale_notes(root, mode, lo, hi)
    rhythms = [
        [0, 1.5, 2, 3], [0, 0.5, 1, 2, 2.5, 3.5], [0, 1, 1.5, 2.5, 3], [0, 0.75, 1.5, 2, 3],
        [0, 2, 2.5, 3], [0.5, 1, 2, 3, 3.5], [0, 0.5, 1.5, 2, 2.5, 3],
    ]
    pick = [rhythms[i] for i in r.choice(len(rhythms), 3, replace=False)]
    if density < 0.4:
        pick = [p[::2] or [0] for p in pick]

    def phrase(rh_a, rh_b, start_bar, seed_idx):
        notes = []
        idx = seed_idx
        for bb, rh in ((0, rh_a), (1, rh_b)):
            ch = chords_of(start_bar + bb)
            tones = [m for m in sc if (m - ch[0]) % 12 in [(c - ch[0]) % 12 for c in ch]]
            for k, b in enumerate(rh):
                step = r.choice([-2, -1, -1, 1, 1, 2, 3, -3])
                idx = int(np.clip(idx + step, 0, len(sc) - 1))
                m = sc[idx]
                if k == 0 and tones:  # downbeats land on chord tones
                    m = min(tones, key=lambda q: abs(q - m))
                    idx = sc.index(m) if m in sc else idx
                nxt = rh[k + 1] if k + 1 < len(rh) else 4
                notes.append((bb * 4 + b, (nxt - b) * 0.92, m))
        return notes, idx

    mid = len(sc) // 2
    out = []
    a, i1 = phrase(pick[0], pick[1], 0, mid)
    b, _ = phrase(pick[2], pick[0], 2, i1)
    for blk in range(0, bars_n, 4):
        out += [(blk * 4 + bt, L, m) for (bt, L, m) in a]
        if (blk // 4) % 2 == 0:
            out += [(blk * 4 + 8 + bt, L, m) for (bt, L, m) in b]
        else:  # answer: transpose up a chord-tone step and resolve long
            bb_ = [(bt, L, sc[min(len(sc) - 1, sc.index(m) + 2)] if m in sc else m) for (bt, L, m) in a]
            if long_end and bb_:
                last = bb_[-1]
                bb_ = bb_[:-1] + [(last[0], max(last[1], 8 - last[0] - 0.2), root + 12 * ((last[2] - root) // 12))]
            out += [(blk * 4 + 8 + bt, L, m) for (bt, L, m) in bb_]
    return [n for n in out if n[0] < bars_n * 4]


def build_song(r, spec: dict) -> np.ndarray:
    bpm = spec["bpm"]
    secs = spec["sections"]
    bars = sum(b for _, b in secs)
    S = Song(bpm, bars, r, tail=spec.get("tail", 5.0))
    root, mode = spec["root"], spec["mode"]
    prog = spec["prog"]  # scale degrees, one per `chord_bars`
    cb = spec.get("chord_bars", 2)
    cbase = root + 12 * round((60 - root) / 12)
    chord_of = lambda b: _chord(cbase, mode, prog[(b // cb) % len(prog)], 4)

    def bass_of(b):
        iv = MODES[mode][prog[(b // cb) % len(prog)] % 7]
        return root + (iv - 12 if iv > 7 else iv)

    sec_of, sec_idx = [], []
    for si, (name, nb) in enumerate(secs):
        for i in range(nb):
            sec_of.append((name, i, nb))
            sec_idx.append(si)
    sw = spec.get("swing", 0.0)
    step_t = lambda b, s: S.t(b, s + (sw if s % 2 == 1 else 0.0))

    # ---------------- kit
    kp = spec.get("kick", {})
    K = kick(r, kp.get("dur", 0.5), kp.get("hi", 170), kp.get("lo", 46), 0.03, kp.get("tau", 0.22), kp.get("click", 0.5), kp.get("punch", 1.8), kp.get("sub", 0.25))
    K2 = kick(r, 0.35, kp.get("hi", 170) * 1.1, kp.get("lo", 46) * 1.05, 0.025, kp.get("tau", 0.22) * 0.7, 0.4, 1.6, 0.1)
    SN = snare(r, 0.45, spec.get("snare_tone", 190), 1.0, 0.8, spec.get("snare_tau", 0.12))
    SNr = snare(r, 0.2, spec.get("snare_tone", 190) * 1.05, 0.9, 0.5, 0.05)
    CL = clap(r, 0.5, 0.14)
    HB = spec.get("hat_bright", 8500)
    HC = [hat(r, 0.07, 0.016, 1.0 + 0.02 * i, HB) for i in range(3)]
    HO = hat(r, 0.4, 0.12, 1.0, HB)
    CR = crash(r, 3.0, 0.9)
    TM = [tom(r, f, 0.5) for f in (170, 135, 105, 82)]
    groove = spec.get("groove", "synth")

    def kick_at(b, s, g=1.0, smp=None):
        S.hit("kick", smp if smp is not None else K, step_t(b, s), g)
        S.kicks.append(step_t(b, s))

    for b in range(bars):
        name, i, nb = sec_of[b]
        P = SECTION[name]
        last = i == nb - 1
        nxt = sec_of[(b + 1) % bars][0]
        fills = spec.get("fills", ["tom", "roll", "stutter", "cut"])
        fill_kind = fills[sec_idx[b] % len(fills)]
        cut_last = last and nxt in ("drop", "half") and fill_kind == "cut"
        # kick
        if P["kick"] == 1 and not cut_last:
            if groove == "four":
                for s in (0, 4, 8, 12):
                    kick_at(b, s)
            elif groove == "break":
                for s in (0, 6, 10) if b % 2 == 0 else (0, 3, 10, 14):
                    kick_at(b, s, 1.0 if s == 0 else 0.8)
            elif groove == "heart":
                for s in (0, 3, 8, 11):
                    kick_at(b, s, 1.0 if s in (0, 8) else 0.7)
            else:  # synth
                for s in (0, 8):
                    kick_at(b, s)
                if b % 2 == 1:
                    kick_at(b, 11, 0.75, K2)
                if b % 4 == 3:
                    kick_at(b, 14, 0.6, K2)
        elif P["kick"] == 2:  # build: accelerating kicks
            prog_ = (i + 1) / nb
            stepk = 4 if prog_ <= 0.5 else (2 if prog_ < 1 else 1)
            for s in range(0, 16, stepk):
                kick_at(b, s, 0.55 + 0.35 * prog_)
        elif P["kick"] == 3 and not cut_last:  # half time
            kick_at(b, 0, 1.0)
            if b % 2 == 1:
                kick_at(b, 10, 0.8, K2)
            if b % 4 == 2:
                kick_at(b, 3, 0.7, K2)
        elif P["kick"] == 4:  # sparse heartbeat
            kick_at(b, 0, 0.9)
            kick_at(b, 3, 0.6, K2)
        # snare
        if P["snare"] == 1 and not cut_last:
            for s in (4, 12):
                S.hit("snare", SN, step_t(b, s), 0.85)
                S.hit("snare", CL, step_t(b, s) + 0.006, 0.4)
            if spec.get("ghosts") and b % 2 == 1:
                S.hit("snare", SNr, step_t(b, 7), 0.22, 0.1)
                S.hit("snare", SNr, step_t(b, 15), 0.18, -0.1)
        elif P["snare"] == 3 and not cut_last:
            S.hit("snare", SN, step_t(b, 8), 0.95)
            S.hit("snare", CL, step_t(b, 8) + 0.008, 0.55)
        elif P["snare"] == 2:
            prog_ = (i + (np.arange(16) / 16)) / nb
            rate = 4 if i < nb - 2 else (2 if i < nb - 1 else 1)
            for s in range(0, 16, rate):
                S.hit("snare", SNr, step_t(b, s), 0.2 + 0.6 * float(prog_[s]), 0.0)
        # hats
        if P["hats"]:
            div = 1 if (P["hats"] == 2 and spec.get("hat16", True)) else 2
            for s in range(0, 16, div):
                acc = 1.0 if s % 4 == 2 else (0.55 if s % 2 == 0 else 0.3)
                S.hit("hats", HC[r.integers(0, 3)], step_t(b, s), 0.5 * acc, 0.25, 0.002)
            if b % 2 == 1 and P["hats"] == 2:
                S.hit("hats", HO, step_t(b, 14), 0.35, -0.2)
        # fills on the last bar of a section
        if last and P["kick"] in (1, 3) and nb >= 2:
            if fill_kind == "tom":
                for k, s in enumerate((8, 10, 12, 13, 14, 15)):
                    S.hit("drums_fx", TM[min(k // 2 + (k > 3), 3)], step_t(b, s), 0.6, -0.5 + 0.2 * k)
            elif fill_kind == "roll":
                for s in range(8, 16):
                    S.hit("snare", SNr, step_t(b, s), 0.3 + 0.06 * (s - 8))
            elif fill_kind == "stutter":
                for s in range(12, 16):
                    S.hit("drums_fx", crush(SN, 5, 4), step_t(b, s), 0.45, 0.3 * (-1) ** s)
        # crashes / impacts on section starts
        if i == 0 and name in ("drop", "half", "verse"):
            S.hit("crash", CR, S.t(b), 0.5 if name != "verse" else 0.3)
            if name in ("drop", "half"):
                S.hit("fx", to_stereo(sub_drop(1.6, 90, 30, 0.6, 1.5)), S.t(b), 0.5)
    # ---------------- bass
    bstyle = spec.get("bass", "synth")
    pats = {
        "synth": [(0, 0, 1.8), (2, 0, 0.9), (4, 12, 0.9), (6, 0, 0.9), (8, 0, 1.8), (10, 0, 0.9), (11, 12, 0.9), (12, 0, 0.9), (14, 12, 0.9)],
        "pulse8": [(s, 12 if s % 4 == 2 else 0, 0.8) for s in range(0, 16, 2)],
        "roll16": [(s, 0 if s % 4 else 0, 0.7) for s in range(16) if s % 4 != 0],
        "gallop": [(s, 0, 0.8) for s in (0, 3, 4, 7, 8, 11, 12, 14, 15)],
        "sub": [(0, 0, 7.5), (8, 0, 7.5)],
        "half": [(0, 0, 5.5), (6, 0, 1.6), (8, 12, 1.0), (10, 0, 5.5)],
    }
    bass_notes, bass_half = [], []
    for b in range(bars):
        name, i, nb = sec_of[b]
        P = SECTION[name]
        if not P["bass"]:
            continue
        rt = bass_of(b)
        style = {1: bstyle, 2: spec.get("bass_half", "half"), 3: "sub"}[P["bass"]]
        if name == "build" and i == nb - 1:
            style = "pulse8"
        for (s, o, L) in pats[style]:
            v = 1.0 if s in (0, 8) else 0.82
            (bass_half if P["bass"] == 2 else bass_notes).append((step_t(b, s), L * S.spb / 4, rt + o, v))
    bosc = spec.get("bass_osc", "bass")
    bass = render_mono_line(S, bass_notes, bosc, spec.get("bass_cut", (160, 1500)), 1.6, 0.11, (0.003, 0.18, 0.6, 0.05), drive_amt=spec.get("bass_drive", 1.5))
    if bass_half:
        bh = render_mono_line(S, bass_half, "reese", (120, 900), 1.4, 0.25, (0.004, 0.3, 0.8, 0.08), glide=0.02,
                              lfo=(S.bpm / 60 / 2, 0.55), drive_amt=3.0)
        bass = bass + bh * 0.9
    # ---------------- pad
    pchords = []
    for b in range(0, bars, cb):
        name, i, nb = sec_of[b]
        if SECTION[name]["pad"]:
            g = {"drop": 0.85, "half": 0.75, "break": 1.15, "intro": 1.0}.get(name, 0.9)
            pchords.append((S.t(b), S.bar * cb, chord_of(b), g))
    if spec.get("pad", "saw") == "choir":
        pad = np.zeros((2, S.N))
        for (st, du, ms, g) in pchords:
            place(pad, choir([mtof(m) for m in ms[:3]], du + 1.0, r, spec.get("vowel", "a"), attack=0.5, release=1.0, voices=3), ns(st), g * 1.2)
    else:
        pad = render_pad(S, pchords, spec.get("pad_cut", (700, 2400)), 5, 0.24, 0.5, 1.2)
    # ---------------- arp
    arp_pat = spec.get("arp_pat", [0, 2, 4, 3, 5, 4, 6, 5, 7, 6, 4, 5, 3, 4, 2, 1])
    arp_div = spec.get("arp_div", 4)
    arp_notes = []
    arp_lvl_pts = []
    for b in range(bars):
        name, i, nb = sec_of[b]
        P = SECTION[name]
        lv = P["arp"] * (0.6 + 0.4 * P["filt"])
        if name == "build":
            lv *= 0.6 + 0.4 * (i + 1) / nb
        arp_lvl_pts += [(b, lv), (b + 0.999, lv)]
        if not P["arp"]:
            continue
        ch = sorted(chord_of(b))
        tones = ch + [m + 12 for m in ch]
        for s in range(4 * arp_div):
            m = tones[arp_pat[s % len(arp_pat)] % len(tones)] + spec.get("arp_oct", 0)
            v = 1.0 if s % arp_div == 0 else 0.72
            arp_notes.append((S.t(b, s * 4 / arp_div), S.spb / arp_div * 0.6, m, v))
    arp_lvl = S.auto(arp_lvl_pts + [(bars + 10, arp_lvl_pts[-1][1])])
    filt_pts = []
    for b in range(bars):
        name, i, nb = sec_of[b]
        f0 = SECTION[name]["filt"]
        f1 = f0
        if name == "build":
            f0, f1 = 0.3 + 0.7 * i / nb, 0.3 + 0.7 * (i + 1) / nb
        filt_pts += [(b, f0), (b + 0.999, f1)]
    fauto = S.auto(filt_pts + [(bars + 10, filt_pts[-1][1])])
    ac0, ac1 = spec.get("arp_cut", (900, 4200))
    arp = render_mono_line(S, arp_notes, spec.get("arp_osc", "arp"), (ac0, ac1), 2.2, 0.07, (0.002, 0.09, 0.25, 0.04), glide=0.0,
                           lfo=(0.05, 0.2), drive_amt=1.2) if arp_notes else np.zeros(S.N)
    arp = sweep(arp, "lp", 500 + 9000 * fauto**2, 0.9) * arp_lvl
    # ---------------- lead
    lead_bars = [b for b in range(bars) if SECTION[sec_of[b][0]]["lead"]]
    lead = np.zeros((2, S.N))
    if lead_bars:
        lo, hi = spec.get("lead_range", (62, 81))
        mel = _melody(r, root, mode, 8, chord_of, lo, hi, spec.get("density", 0.55))
        lead_notes = []
        # group consecutive lead bars into blocks and lay the 8-bar melody across them
        blocks, cur = [], [lead_bars[0]]
        for b in lead_bars[1:]:
            if b == cur[-1] + 1:
                cur.append(b)
            else:
                blocks.append(cur)
                cur = [b]
        blocks.append(cur)
        for bi, blk in enumerate(blocks):
            name = sec_of[blk[0]][0]
            off = 12 if (name == "drop" and bi >= 2 and spec.get("lift", True)) else 0
            for (bt, L, m) in mel:
                bar_i = int(bt // 4)
                for rep in range(0, len(blk), 8):
                    if rep + bar_i < len(blk):
                        lead_notes.append((S.t(blk[0] + rep) + bt * S.spb, L * S.spb, m + off - (12 if name == "break" and spec.get("break_low") else 0), 0.9))
        lv = spec.get("lead", "lead")
        if lv in ("bell", "pluck"):
            mono = np.zeros(S.N)
            for (st, du, m, v) in lead_notes:
                if lv == "bell":
                    smp = bell(mtof(m), min(2.0, du + 0.8), bright=spec.get("bell_bright", 0.8), tau=0.45)
                else:
                    smp = pluck(mtof(m), min(1.2, du + 0.4), 3200, 0.22)
                place(mono, smp, ns(st), v * 0.6)
            lead = chorus(mono, 0.6, 2.0, 11, 0.4)
        else:
            mono = render_mono_line(S, lead_notes, lv, spec.get("lead_cut", (1200, 3600)), 1.0, 0.3, (0.012, 0.3, 0.75, 0.18),
                                    glide=0.03, drive_amt=spec.get("lead_drive", 1.3))
            lead = chorus(mono, 0.7, 2.0, 11, 0.45)
    # ---------------- specials
    fx = S.bus("fx")
    for b in range(bars):
        name, i, nb = sec_of[b]
        if name == "build" and i == 0:  # noise riser over the whole build
            rn = ns(S.bar * nb)
            rp = np.arange(rn) / rn
            rz = sweep(np.stack([noise(rn, r), noise(rn, r)]), "bp", 300 * (9000 / 300) ** rp, 1.5) * rp**2.5
            place(fx, rz, ns(S.t(b)), 0.4)
        if name == "break" and i == 0:
            place(fx, to_stereo(sub_drop(2.5, 70, 28, 1.0, 1.3)), ns(S.t(b)), 0.35)
    if spec.get("alarm"):
        al_notes = []
        for b in range(bars):
            name, i, nb = sec_of[b]
            if name in ("drop", "half") and b % 2 == 0:
                al_notes += [(S.t(b), S.spb * 1.9, root + 36, 0.8), (S.t(b, 8), S.spb * 1.9, root + 41, 0.8)]
        if al_notes:
            al = render_mono_line(S, al_notes, "siren", (1500, 2500), 1.0, 0.5, (0.03, 0.2, 0.8, 0.1), glide=0.12, drive_amt=2.0)
            place(fx, pan(filt(al, "bp", 1500, 0.9), 0.2), 0, spec["alarm"])
    if spec.get("bells"):
        for b in range(0, bars, 2):
            name, i, nb = sec_of[b]
            if name in ("intro", "break", "sparse"):
                ch = chord_of(b)
                for k, m in enumerate(ch):
                    place(fx, pan(bell(mtof(m + 12), 1.8, bright=0.6, tau=0.6), -0.5 + 0.33 * k), ns(S.t(b, k * 3)), spec["bells"])
    # ---------------- mix
    duck = S.duck(spec.get("duck", 0.55), 0.16)
    out = np.zeros((2, S.N))
    G = {"kick": 0.9, "snare": 0.55, "hats": 0.33, "crash": 0.28, "drums_fx": 0.5, "fx": 0.4}
    G.update(spec.get("gains", {}))
    for k, v in S.buses.items():
        out += v * G.get(k, 0.5)
    bl, pl, al_, ll = spec.get("levels", (0.55, 0.3, 0.22, 0.24))
    out += pan(bass, 0) * duck * bl
    out += pad * duck * pl
    out += pan(arp, 0.15) * duck * al_
    out += lead * ll
    arp_d = delay(pan(arp, 0.15) * duck, S.spb * 0.75, 0.38, 1.0, lp=3500, pingpong=True, tail=0)
    out += (fit(arp_d, S.N) - pan(arp, 0.15) * duck) * al_ * 0.4
    if lead_bars:
        lead_d = delay(lead, S.spb * 0.75, 0.32, 1.0, lp=4000, pingpong=True, tail=0)
        out += (fit(lead_d, S.N) - lead) * ll * 0.35
    rsend = S.bus("snare") * 0.5 + pad * 0.35 + pan(arp, 0.15) * 0.25 + lead * 0.3 + S.bus("drums_fx") * 0.3 + fx * 0.3
    ir = reverb_ir(spec.get("rt60", 2.6), 1.2, 0.4, 0.02, 7000, 200)
    out += fit(convolve(rsend, ir), S.N) * spec.get("verb", 0.11)
    # section level shaping (smooth), drives dynamics between sections
    lv_pts = []
    for b in range(bars):
        lvl = SECTION[sec_of[b][0]]["level"]
        lv_pts += [(b, lvl), (b + 0.999, lvl)]
    out = out * S.auto(lv_pts + [(bars + 10, lv_pts[-1][1])])[None, :] ** 0.5
    if spec.get("glitch"):  # tape-stop-ish stutter on the last beat of every 4th drop bar
        for b in range(bars):
            name, i, nb = sec_of[b]
            if name in ("drop", "half") and b % 4 == 3:
                s0 = ns(S.t(b, 12))
                sl = ns(S.spb / 4)
                seg = out[:, s0 : s0 + sl].copy()
                for k in range(4):
                    a = s0 + k * sl
                    m = min(sl, S.N - a)
                    if m > 0:
                        out[:, a : a + m] = crush(seg[:, :m], 6 if k % 2 else 8, 2) * (1 - 0.15 * k)
    x = master(S, out, spec.get("rms", -20.0), -3.0)
    if spec.get("vinyl", 0):
        x += vinyl(S.L, r, 1.0) * db(spec["vinyl"])
    from .dsp import limiter
    return limiter(x, -3.0, circular=True)


# ----------------------------------------------------------------------------
# biome music
# ----------------------------------------------------------------------------
def music_normal(r):
    return build_song(r, dict(
        bpm=110, root=38, mode="aeolian", prog=[0, 5, 2, 6], groove="synth", bass="synth",
        sections=[("intro", 4), ("verse", 8), ("build", 4), ("drop", 8), ("break", 4), ("build", 2), ("drop", 8), ("out", 2)],
        fills=["tom", "cut", "roll", "stutter"], ghosts=True, lead="lead", lead_range=(62, 81),
        bells=0.12, vinyl=-38, rms=-20.0))


def music_datastorm(r):
    return build_song(r, dict(
        bpm=132, root=33, mode="dorian", prog=[0, 5, 6, 4], chord_bars=2, groove="four", bass="pulse8",
        sections=[("intro", 4), ("verse", 8), ("build", 4), ("drop", 12), ("break", 6), ("build", 2), ("drop", 10), ("out", 2)],
        fills=["roll", "stutter", "cut", "tom"], arp_div=4, arp_pat=[0, 4, 2, 5, 1, 6, 3, 7, 4, 2, 5, 3, 6, 4, 7, 5],
        arp_osc="arp", arp_cut=(1400, 6500), lead="pluck", lead_range=(69, 88), density=0.7, hat_bright=9500,
        kick=dict(hi=180, lo=48, tau=0.19, click=0.6, punch=1.9, sub=0.2), levels=(0.5, 0.26, 0.3, 0.26), rms=-20.0))


def music_overclock(r):
    return build_song(r, dict(
        bpm=140, root=40, mode="phrygian", prog=[0, 1, 6, 5], chord_bars=1, groove="four", bass="roll16",
        bass_osc="reese", bass_drive=3.2, bass_cut=(200, 2200),
        sections=[("intro", 4), ("build", 4), ("drop", 16), ("half", 8), ("build", 4), ("drop", 12)],
        fills=["stutter", "roll", "cut", "tom"], arp_osc="arpsaw", arp_div=4, arp_cut=(1200, 5200),
        lead="arpsaw", lead_drive=2.2, lead_range=(64, 83), density=0.65, glitch=True, ghosts=True,
        kick=dict(hi=200, lo=50, tau=0.17, click=0.7, punch=2.2, sub=0.15), snare_tone=210, duck=0.65,
        levels=(0.6, 0.22, 0.26, 0.25), rms=-20.0))


def music_blackout(r):
    return build_song(r, dict(
        bpm=90, root=37, mode="phrygian", prog=[0, 1, 0, 5], chord_bars=2, groove="heart", bass="sub",
        sections=[("intro", 4), ("sparse", 8), ("build", 2), ("half", 8), ("break", 4), ("sparse", 4), ("half", 2)],
        fills=["cut", "tom", "roll", "cut"], pad="choir", vowel="u", arp_div=2, arp_pat=[0, 3, 1, 4, 2, 5, 1, 3],
        arp_cut=(500, 2000), lead="bell", bell_bright=0.5, lead_range=(61, 76), density=0.3, hat_bright=7000,
        kick=dict(hi=120, lo=38, tau=0.3, click=0.2, punch=1.6, sub=0.5, dur=0.7), duck=0.45,
        levels=(0.65, 0.32, 0.18, 0.22), rt60=3.5, verb=0.16, bells=0.06, rms=-21.0))


def music_kernelpanic(r):
    return build_song(r, dict(
        bpm=150, root=32, mode="locrian", prog=[0, 1, 4, 1], chord_bars=1, groove="break", bass="gallop",
        bass_osc="reese", bass_drive=3.5, bass_cut=(220, 2600),
        sections=[("intro", 2), ("build", 4), ("drop", 12), ("half", 8), ("break", 4), ("build", 2), ("drop", 12), ("half", 4)],
        fills=["stutter", "cut", "stutter", "roll"], arp_osc="arpsaw", arp_div=4, arp_pat=[0, 1, 0, 4, 0, 1, 5, 4],
        arp_cut=(1500, 7000), lead="siren", lead_drive=2.5, lead_range=(68, 84), density=0.5, alarm=0.22,
        glitch=True, ghosts=True, kick=dict(hi=210, lo=52, tau=0.16, click=0.8, punch=2.3, sub=0.15), snare_tone=230,
        duck=0.65, levels=(0.6, 0.2, 0.25, 0.22), rms=-20.0))


# ----------------------------------------------------------------------------
# aura themes: compact form ~30-45 s, quieter mix
# ----------------------------------------------------------------------------
def _theme_sections(bpm, form):
    bar = 240.0 / bpm
    target = 38.0
    nb = max(8, int(round(target / bar / 2)) * 2)
    forms = {
        "groove": [("intro", 2), ("drop", None), ("break", 2), ("drop", None)],
        "build": [("intro", 2), ("build", 2), ("drop", None), ("break", 2)],
        "half": [("sparse", 2), ("half", None), ("break", 2), ("half", None)],
        "ambient": [("intro", 2), ("break", None), ("sparse", 2), ("break", None)],
    }
    f = forms[form]
    fixed = sum(b for _, b in f if b)
    free = [i for i, (_, b) in enumerate(f) if b is None]
    rest = max(4 * len(free), nb - fixed)
    each = [rest // len(free) // 2 * 2] * len(free)
    each[-1] += rest - sum(each)
    out, k = [], 0
    for name, b in f:
        if b is None:
            out.append((name, each[k]))
            k += 1
        else:
            out.append((name, b))
    return out


THEMES = {
    "Mainframe": dict(bpm=96, root=36, mode="dorian", prog=[0, 3, 6, 4], groove="synth", bass="synth", form="groove",
                      lead="pluck", arp_pat=[0, 2, 4, 6, 4, 2, 5, 3], arp_cut=(800, 3800), bells=0.08),
    "Quantum": dict(bpm=120, root=41, mode="lydian", prog=[0, 1, 4, 5], groove="break", bass="pulse8", form="groove",
                    lead="bell", bell_bright=1.1, arp_div=3, arp_pat=[0, 3, 5, 2, 6, 4], arp_cut=(1500, 7000), bells=0.1),
    "Overclocked": dict(bpm=150, root=40, mode="aeolian", prog=[0, 5, 3, 6], chord_bars=1, groove="four", bass="roll16",
                        bass_osc="reese", bass_drive=3.0, form="build", lead="arpsaw", lead_drive=2.2, glitch=True, duck=0.65),
    "NeuralLink": dict(bpm=100, root=41, mode="dorian", prog=[0, 4, 5, 3], groove="break", bass="synth", form="groove",
                       lead="lead", arp_pat=[0, 4, 7, 4, 2, 6, 9, 6], arp_cut=(700, 3000), swing=0.25, vinyl=-36),
    "Sentinel": dict(bpm=112, root=38, mode="mixolydian", prog=[0, 6, 3, 4], groove="synth", bass="gallop", form="build",
                     pad="choir", vowel="a", lead="lead", lead_range=(66, 86), arp_cut=(900, 4500)),
    "Kernel": dict(bpm=128, root=37, mode="phrygian", prog=[0, 1, 5, 1], chord_bars=1, groove="four", bass="pulse8",
                   bass_osc="reese", bass_drive=2.5, form="groove", lead="arp", glitch=True, arp_osc="arpsaw"),
    "GhostProtocol": dict(bpm=84, root=35, mode="aeolian", prog=[0, 5, 3, 4], groove="heart", bass="sub", form="ambient",
                          pad="choir", vowel="o", lead="bell", bell_bright=0.4, density=0.3, arp_div=2, arp_cut=(500, 1800), rt60=4.0, verb=0.18),
    "CyberSeraph": dict(bpm=108, root=40, mode="lydian", prog=[0, 1, 5, 4], groove="synth", bass="pulse8", form="build",
                        pad="choir", vowel="a", lead="bell", bell_bright=1.0, bells=0.1, lead_range=(71, 91), rt60=3.5, verb=0.16),
    "BlueScreen": dict(bpm=118, root=34, mode="aeolian", prog=[0, 5, 6, 4], groove="synth", bass="pulse8", bass_osc="arp",
                       form="groove", lead="siren", lead_cut=(1500, 2500), glitch=True, arp_osc="arp", arp_cut=(2000, 6000), hat_bright=10000),
    "Corruption": dict(bpm=140, root=33, mode="harmonic", prog=[0, 5, 4, 0], chord_bars=1, groove="break", bass="half",
                       bass_osc="reese", bass_drive=3.5, form="half", lead="arpsaw", lead_drive=2.5, glitch=True, duck=0.6),
    "KernelPanic": dict(bpm=150, root=32, mode="phrygian", prog=[0, 1, 0, 6], chord_bars=1, groove="break", bass="gallop",
                        bass_osc="reese", bass_drive=3.2, form="build", lead="siren", alarm=0.2, glitch=True),
    "EventHorizon": dict(bpm=76, root=31, mode="aeolian", prog=[0, 5, 2, 6], groove="heart", bass="sub", form="half",
                         pad="choir", vowel="o", lead="lead", lead_range=(55, 74), density=0.3, rt60=4.5, verb=0.2,
                         kick=dict(hi=110, lo=34, tau=0.35, sub=0.6, dur=0.8)),
    "NullPointer": dict(bpm=124, root=33, mode="locrian", prog=[0, 0, 4, 1], groove="four", bass="sub", form="groove",
                        lead="pluck", density=0.3, arp_div=2, arp_pat=[0, 0, 3, 0, 4, 0, 1, 0], glitch=True, hat16=False),
    "Singularity": dict(bpm=132, root=38, mode="aeolian", prog=[0, 5, 2, 6], groove="four", bass="pulse8", form="build",
                        pad="saw", lead="lead", lead_range=(65, 86), bells=0.08, lift=True, pad_cut=(900, 3500)),
    "Architect": dict(bpm=104, root=43, mode="dorian", prog=[0, 3, 4, 6], groove="synth", bass="synth", form="groove",
                      pad="choir", vowel="a", lead="bell", arp_div=4, arp_pat=[0, 2, 4, 6, 7, 6, 4, 2], bells=0.1, rt60=3.0),
    "Redacted": dict(bpm=90, root=30, mode="phrygian", prog=[0, 1, 0, 4], groove="heart", bass="half", form="half",
                     bass_osc="reese", bass_drive=3.0, pad="choir", vowel="u", lead="bell", bell_bright=0.5, density=0.3,
                     glitch=True, rt60=4.0, verb=0.18, kick=dict(hi=120, lo=36, tau=0.32, sub=0.55, dur=0.7)),
}


def _theme(aura):
    def gen(r):
        spec = dict(THEMES[aura])
        spec["sections"] = _theme_sections(spec["bpm"], spec.pop("form"))
        spec.setdefault("rms", -22.0)
        spec.setdefault("tail", 4.0)
        return build_song(r, spec)
    return gen


REGISTRY = {
    "MusicNormal": music_normal,
    "MusicDataStorm": music_datastorm,
    "MusicOverclock": music_overclock,
    "MusicBlackout": music_blackout,
    "MusicKernelPanic": music_kernelpanic,
}
for _a in THEMES:
    REGISTRY[f"Theme_{_a}"] = _theme(_a)
