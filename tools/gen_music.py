"""Procedural soundtrack for Gorbino's Quest.

A tiny tracker: every track is described by tempo, scale, progression,
drum grids and melodic generators, rendered with simple synth voices,
then encoded to Ogg Vorbis with ffmpeg.

Run: python3 tools/gen_music.py  -> assets/music/*.ogg
"""
import os
import subprocess
import wave
import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")
TMP = os.path.join(ROOT, "tools", "_music_tmp")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
SR = 32000


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    e = np.ones(n) * s
    a = max(1, min(a, n))
    e[:a] = np.linspace(0, 1, a)
    d1 = min(n, a + d)
    if d1 > a:
        e[a:d1] = np.linspace(1, s, d1 - a)
    if r > 0 and n > r:
        e[n - r:] *= np.linspace(1, 0, r)
    return e


def phase(f, n):
    if np.isscalar(f):
        return np.arange(n) * f / SR
    return np.cumsum(f) / SR


def saw(f, n):
    return 2 * (phase(f, n) % 1) - 1


def pulse(f, n, pw=0.5):
    return np.where((phase(f, n) % 1) < pw, 1.0, -1.0)


def tri(f, n):
    return 2 * np.abs(2 * (phase(f, n) % 1) - 1) - 1


def sine(f, n):
    return np.sin(2 * np.pi * phase(f, n))


def lowpass(x, fc, q=0.707):
    fc = min(max(fc, 30), SR / 2 - 200)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    b = np.array([(1 - np.cos(w0)) / 2, 1 - np.cos(w0), (1 - np.cos(w0)) / 2])
    a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
    return signal.lfilter(b / a[0], a / a[0], x)


def highpass(x, fc):
    b, a = signal.butter(2, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


RNG = np.random.default_rng(99)


def noise(n):
    return RNG.uniform(-1, 1, n)


# ---------------------------------------------------------------- instruments
def inst_lead(f, n, vel, p):
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR) * np.clip(np.arange(n) / (SR * 0.25), 0, 1)
    x = pulse(f * vib, n, p.get("pw", 0.25)) * 0.6 + saw(f * vib * 1.003, n) * 0.25
    x = lowpass(x, p.get("cut", 3500))
    return x * adsr(n, 0.005, 0.1, 0.7, 0.05) * vel


def inst_sq(f, n, vel, p):
    x = pulse(f, n, p.get("pw", 0.5))
    return lowpass(x, p.get("cut", 5000)) * adsr(n, 0.002, 0.08, 0.5, 0.03) * vel


def inst_bass(f, n, vel, p):
    x = saw(f, n) * 0.7 + sine(f / 2, n) * 0.5
    env = adsr(n, 0.003, 0.15, 0.6, 0.03)
    cut = p.get("cut", 700)
    x = lowpass(x, cut, p.get("q", 1.2))
    if p.get("drive"):
        x = np.tanh(x * p["drive"])
    return x * env * vel


def inst_acid(f, n, vel, p):
    x = saw(f, n)
    # filter envelope by block processing
    out = np.zeros(n)
    blk = 128
    zi = np.zeros(2)
    cut0 = p.get("cut", 400) * (0.7 + vel)
    for s in range(0, n, blk):
        k = s / max(1, n)
        fc = cut0 + 3200 * np.exp(-k * 5) * vel
        w0 = 2 * np.pi * min(fc, SR / 2 - 300) / SR
        q = p.get("q", 6.0)
        alpha = np.sin(w0) / (2 * q)
        b = np.array([(1 - np.cos(w0)) / 2, 1 - np.cos(w0), (1 - np.cos(w0)) / 2])
        a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
        y, zi = signal.lfilter(b / a[0], a / a[0], x[s:s + blk], zi=zi)
        out[s:s + blk] = y
    return np.tanh(out * 1.5) * adsr(n, 0.002, 0.1, 0.5, 0.02) * vel * 0.6


def inst_pad(f, n, vel, p):
    x = sum(saw(f * (1 + d), n) for d in (-0.008, 0.0, 0.0071)) / 3
    x += pulse(f / 2, n, 0.5) * 0.2
    x = lowpass(x, p.get("cut", 1200))
    return x * adsr(n, p.get("att", 0.4), 0.3, 0.8, p.get("rel", 0.4)) * vel


def inst_bell(f, n, vel, p):
    t = np.arange(n) / SR
    ratio = p.get("ratio", 3.5)
    idx = p.get("index", 4) * np.exp(-t * 4)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * ratio * t))
    return x * np.exp(-t * p.get("decay", 3.0)) * vel


def inst_epiano(f, n, vel, p):
    t = np.arange(n) / SR
    idx = 1.6 * np.exp(-t * 6)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    x *= 1 + 0.15 * np.sin(2 * np.pi * 4.5 * t)
    return x * adsr(n, 0.003, 0.6, 0.35, 0.1) * vel


def inst_pluck(f, n, vel, p):
    t = np.arange(n) / SR
    x = saw(f, n)
    out = np.zeros(n)
    # decaying cutoff
    blk = 256
    zi = np.zeros(2)
    for s in range(0, n, blk):
        fc = 300 + 4000 * np.exp(-s / SR * 12)
        w0 = 2 * np.pi * fc / SR
        alpha = np.sin(w0) / 1.4
        b = np.array([(1 - np.cos(w0)) / 2, 1 - np.cos(w0), (1 - np.cos(w0)) / 2])
        a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
        y, zi = signal.lfilter(b / a[0], a / a[0], x[s:s + blk], zi=zi)
        out[s:s + blk] = y
    return out * np.exp(-t * 5) * vel


# drums (pitch ignored)
def dr_kick(n, vel, p):
    t = np.arange(n) / SR
    f = 45 + 120 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * p.get("kdecay", 9))
    return np.tanh(x * 2) * vel


def dr_snare(n, vel, p):
    t = np.arange(n) / SR
    x = bandpass(noise(n), 800, 7000) * np.exp(-t * 16) + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 25) * 0.6
    return x * vel


def dr_hat(n, vel, p):
    t = np.arange(n) / SR
    return highpass(noise(n), 7000) * np.exp(-t * 60) * vel * 0.6


def dr_ohat(n, vel, p):
    t = np.arange(n) / SR
    return highpass(noise(n), 6000) * np.exp(-t * 10) * vel * 0.4


def dr_clap(n, vel, p):
    t = np.arange(n) / SR
    env = np.exp(-t * 30) + 0.6 * np.exp(-np.maximum(t - 0.012, 0) * 30) * (t > 0.012) + 0.5 * np.exp(-np.maximum(t - 0.024, 0) * 18) * (t > 0.024)
    return bandpass(noise(n), 1000, 4000) * env * vel


def dr_tom(n, vel, p):
    t = np.arange(n) / SR
    f = p.get("tom", 90) * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7) * vel


def dr_clang(n, vel, p):
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * fr * t) for fr in (517, 793, 1240, 1777))
    return x * np.exp(-t * 9) * vel * 0.3


def dr_rim(n, vel, p):
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1700 * t) * 0.5 + bandpass(noise(n), 2000, 6000)) * np.exp(-t * 80) * vel


def inst_power(f, n, vel, p):
    """Distorted power chord: root, fifth and octave on detuned saws."""
    x = np.zeros(n)
    for mult, g in ((1.0, 1.0), (1.4983, 0.8), (2.0, 0.55)):
        x += (saw(f * mult * 1.004, n) + saw(f * mult * 0.996, n)) * g
    x = np.tanh(x * p.get("drive", 3.5))
    x = lowpass(x, p.get("cut", 2400), 0.9)
    return x * adsr(n, 0.004, 0.15, 0.85, 0.04) * vel


def inst_reese(f, n, vel, p):
    """Detuned saw stack with a slowly moving filter (drum and bass)."""
    x = saw(f, n) + saw(f * 1.011, n) + saw(f * 0.992, n) * 0.8
    out = np.zeros(n)
    blk = 256
    zi = np.zeros(2)
    for s0 in range(0, n, blk):
        t = s0 / SR
        fc = 260 + 520 * (0.5 + 0.5 * np.sin(2 * np.pi * p.get("lfo", 0.4) * t))
        w0 = 2 * np.pi * fc / SR
        alpha = np.sin(w0) / 2.4
        b = np.array([(1 - np.cos(w0)) / 2, 1 - np.cos(w0), (1 - np.cos(w0)) / 2])
        a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
        y, zi = signal.lfilter(b / a[0], a / a[0], x[s0:s0 + blk], zi=zi)
        out[s0:s0 + blk] = y
    return np.tanh(out * 1.4) * adsr(n, 0.02, 0.2, 0.9, 0.08) * vel


def inst_vibes(f, n, vel, p):
    t = np.arange(n) / SR
    idx = 1.1 * np.exp(-t * 9)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 4.0 * t))
    x *= 1 + 0.3 * np.sin(2 * np.pi * 5.2 * t)
    return x * np.exp(-t * 2.3) * adsr(n, 0.002, 0.1, 1.0, 0.05) * vel


def inst_mbox(f, n, vel, p):
    """Music box: bright FM pluck, a hair out of tune."""
    t = np.arange(n) / SR
    det = 1.0 + p.get("wobble", 0.004) * np.sin(2 * np.pi * 0.7 * t)
    idx = 2.2 * np.exp(-t * 14)
    x = np.sin(2 * np.pi * f * det * t + idx * np.sin(2 * np.pi * f * 7.0 * t))
    x += 0.3 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 6)
    return x * np.exp(-t * 3.2) * vel


def inst_organ(f, n, vel, p):
    x = sum(sine(f * h, n) * g for h, g in ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)))
    x *= 1 + 0.08 * np.sin(2 * np.pi * 6.0 * np.arange(n) / SR)
    return np.tanh(x * 0.8) * adsr(n, 0.03, 0.1, 0.9, 0.1) * vel


INST = {"power": inst_power, "reese": inst_reese, "vibes": inst_vibes, "mbox": inst_mbox, "organ": inst_organ,
        "lead": inst_lead, "sq": inst_sq, "bass": inst_bass, "acid": inst_acid, "pad": inst_pad,
        "bell": inst_bell, "epiano": inst_epiano, "pluck": inst_pluck}
def dr_shaker(n, vel, p):
    t = np.arange(n) / SR
    env = np.clip(t / 0.01, 0, 1) * np.exp(-t * 35)
    return highpass(noise(n), 5000) * env * vel * 0.5


def dr_crash(n, vel, p):
    t = np.arange(n) / SR
    return highpass(noise(n), 3500) * np.exp(-t * 2.2) * vel * 0.45


def dr_ghost(n, vel, p):
    return dr_snare(n, vel * 0.35, p)


DRUMS = {"a": dr_shaker, "x": dr_crash, "g": dr_ghost, "k": dr_kick, "s": dr_snare, "h": dr_hat, "o": dr_ohat, "c": dr_clap, "t": dr_tom, "m": dr_clang, "r": dr_rim}

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11], "locrian": [0, 1, 3, 5, 6, 8, 10], "whole": [0, 2, 4, 6, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10], "harm": [0, 2, 3, 5, 7, 8, 11], "dim": [0, 2, 3, 5, 6, 8, 9, 11],
}


class Song:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.spb = 60.0 / bpm
        self.length = int(SR * self.spb * beats_per_bar * bars)
        self.tracks = {}
        self.events = []  # (bus, beat, dur_beats, midi, inst, vel, params)

    def note(self, bus, beat, dur, midi, inst, vel=0.8, **p):
        self.events.append((bus, beat, dur, midi, inst, vel, p))

    def drum(self, bus, beat, kind, vel=0.8, **p):
        self.events.append((bus, beat, 0.5, None, kind, vel, p))

    def render(self, buses):
        out = {}
        for (bus, beat, dur, midi, inst, vel, p) in self.events:
            if bus not in out:
                out[bus] = np.zeros(self.length + SR * 4)
            start = int(beat * self.spb * SR)
            if midi is None:
                n = int(SR * p.get("len", 0.5))
                x = DRUMS[inst](n, vel, p)
            else:
                n = int(dur * self.spb * SR) + int(SR * p.get("tail", 0.06))
                x = INST[inst](mtof(midi + p.get("detune", 0.0)), n, vel, p)
            out[bus][start:start + n] += x[:len(out[bus][start:start + n])]
        mixb = np.zeros(self.length + SR * 4)
        for bus, x in out.items():
            cfg = buses.get(bus, {})
            if cfg.get("delay"):
                dt, fb, wet = cfg["delay"]
                d = int(dt * self.spb * SR)
                y = x.copy()
                for k in range(1, 6):
                    y[d * k:] += x[:len(x) - d * k] * (fb ** k) * wet
                x = y
            if cfg.get("crush"):
                q = 2 ** cfg["crush"]
                x = np.round(x * q) / q
            if cfg.get("lp"):
                x = lowpass(x, cfg["lp"])
            mixb += x * cfg.get("gain", 1.0)
        # fold the tail back to the start for a seamless loop
        tail = mixb[self.length:]
        mixb = mixb[:self.length].copy()
        mixb[:len(tail)] += tail[:len(mixb)]
        mixb = np.tanh(mixb * 0.9)
        mixb /= np.max(np.abs(mixb)) + 1e-9
        return mixb * 0.85


def grid(song, bus, pattern, bar_from, bar_to, kind, vel=0.8, step=0.25, swing=0.0, **p):
    """pattern: string of 16 chars, 'x' hit, 'X' accent, '.' rest. Repeats each bar."""
    steps = len(pattern)
    for bar in range(bar_from, bar_to):
        for i, c in enumerate(pattern):
            if c in "xX":
                b = bar * song.bpb + i * (song.bpb / steps)
                if swing and i % 2 == 1:
                    b += swing * (song.bpb / steps)
                song.drum(bus, b, kind, vel * (1.25 if c == "X" else 1.0), **p)


def deg(root, scale, d, octave=0):
    sc = SCALES[scale]
    o, i = divmod(d, len(sc))
    return root + sc[i] + 12 * (o + octave)


def chord(root, scale, d, size=3):
    return [deg(root, scale, d + 2 * k) for k in range(size)]


def walk_melody(song, bus, inst, root, scale, bar_from, bar_to, prog, seed, density=0.6, octave=1, vel=0.7,
                rhythm=None, motif=None, motif_every=4, **p):
    r = np.random.default_rng(seed)
    cur = 4
    for bar in range(bar_from, bar_to):
        chord_deg = prog[bar % len(prog)]
        if motif is not None and (bar - bar_from) % motif_every == 0:
            b = bar * song.bpb
            for (off, dur, dd) in motif:
                song.note(bus, b + off, dur * 0.95, deg(root, scale, chord_deg + dd, octave), inst, vel, **p)
            continue
        pos = 0.0
        rh = rhythm or [0.5, 0.5, 1.0, 0.5, 0.25, 0.25, 1.0]
        k = 0
        while pos < song.bpb - 1e-6:
            dur = rh[(k + bar) % len(rh)]
            dur = min(dur, song.bpb - pos)
            if r.random() < density:
                strong = abs(pos - round(pos)) < 1e-6
                if strong:
                    cands = [chord_deg, chord_deg + 2, chord_deg + 4, chord_deg + 7]
                    tgt = min(cands, key=lambda c: abs(c - cur) + r.random() * 2)
                    cur = tgt
                else:
                    cur += int(r.choice([-2, -1, -1, 1, 1, 2]))
                cur = int(np.clip(cur, -2, 11))
                song.note(bus, bar * song.bpb + pos, dur * 0.9, deg(root, scale, cur, octave), inst, vel, **p)
            pos += dur
            k += 1


def bassline(song, bus, inst, root, scale, bar_from, bar_to, prog, pattern, octave=-2, vel=0.8, **p):
    """pattern: list of (beat_offset, dur, degree_offset)"""
    for bar in range(bar_from, bar_to):
        cd = prog[bar % len(prog)]
        for (off, dur, dd) in pattern:
            song.note(bus, bar * song.bpb + off, dur, deg(root, scale, cd + dd, octave), inst, vel, **p)


def pads(song, bus, inst, root, scale, bar_from, bar_to, prog, octave=0, vel=0.35, bars_per=1, size=3, **p):
    for bar in range(bar_from, bar_to, bars_per):
        cd = prog[bar % len(prog)]
        for m in chord(root, scale, cd, size):
            song.note(bus, bar * song.bpb, song.bpb * bars_per, m + 12 * octave, inst, vel, **p)


def arps(song, bus, inst, root, scale, bar_from, bar_to, prog, step=0.25, octave=1, vel=0.4, shape=(0, 2, 4, 7), **p):
    for bar in range(bar_from, bar_to):
        cd = prog[bar % len(prog)]
        n = int(song.bpb / step)
        for i in range(n):
            dd = shape[i % len(shape)]
            song.note(bus, bar * song.bpb + i * step, step * 0.9, deg(root, scale, cd + dd, octave), inst, vel, **p)


def play(song, bus, inst, bar0, phrase, vel=0.6, transpose=0, **p):
    """phrase: list of bars; each bar a list of (beat, dur, midi)."""
    for k, bar in enumerate(phrase):
        for (b, d, m) in bar:
            song.note(bus, (bar0 + k) * song.bpb + b, d, m + transpose, inst, vel, **p)


# The Gorbino motif (scale degree offsets): heard in several tracks
GORB_MOTIF = [(0, 0.75, 0), (0.75, 0.25, 4), (1.0, 0.5, 5), (1.5, 0.5, 4), (2.0, 1.0, 2), (3.0, 1.0, 0)]


def save(name, x):
    path = os.path.join(TMP, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(path)
    print("music:", name, "%.1fs" % (len(x) / SR))


# ================================================================ tracks
def t_menu():
    s = Song(92, 16)
    root, sc = 50, "phrygian"
    prog = [0, 0, 5, 1, 0, 0, 3, 1]
    pads(s, "pad", "pad", root, sc, 0, 16, prog, 0, 0.3, cut=900, att=0.8)
    bassline(s, "bass", "bass", root, sc, 0, 16, prog, [(0, 1.5, 0), (1.5, 0.5, 0), (2, 2, -3)], vel=0.6, cut=400)
    walk_melody(s, "lead", "bell", root, sc, 4, 16, prog, 5, density=0.35, octave=1, vel=0.5, motif=GORB_MOTIF, motif_every=4,
                rhythm=[1, 0.5, 0.5, 2], ratio=3.5, index=3)
    grid(s, "dr", "x.......x.x.....", 8, 16, "k", 0.8)
    grid(s, "dr", "....x.......x...", 8, 16, "r", 0.35)
    grid(s, "dr", "x...x...x...x.x.", 8, 16, "h", 0.3)
    return s.render({"lead": {"delay": (0.75, 0.5, 0.6), "gain": 0.8}, "pad": {"gain": 0.6}, "dr": {"gain": 0.6, "crush": 6}})


def t_village():
    """'Well Water Waltz': a 3/4 music-box waltz in D harmonic minor with
    oom-pah-pah accompaniment; slightly out of tune, like a toy left outside."""
    s = Song(132, 36, 3)
    A = [[(0, 1, 69), (1, 1, 74), (2, 1, 73)], [(0, 2, 74), (2, 1, 69)], [(0, 1, 70), (1, 1, 69), (2, 1, 67)], [(0, 3, 69)],
         [(0, 1, 65), (1, 1, 67), (2, 1, 69)], [(0, 2, 70), (2, 1, 69)], [(0, 1, 67), (1, 1, 65), (2, 1, 64)], [(0, 3, 62)]]
    B = [[(0, 1, 74), (1, 1, 76), (2, 1, 77)], [(0, 2, 76), (2, 1, 74)], [(0, 1, 73), (1, 1, 74), (2, 1, 76)], [(0, 3, 69)],
         [(0, 1, 70), (1, 1, 69), (2, 1, 70)], [(0, 2, 73), (2, 1, 76)], [(0, 1, 74), (1, 1, 73), (2, 1, 70)], [(0, 3, 74)]]
    chA = [(38, [62, 65, 69]), (38, [62, 65, 69]), (43, [62, 67, 70]), (45, [61, 64, 69]),
           (38, [62, 65, 69]), (43, [62, 67, 70]), (45, [61, 64, 67]), (38, [62, 65, 69])]
    chB = [(46, [62, 65, 70]), (45, [61, 64, 69]), (45, [61, 64, 69]), (38, [62, 65, 69]),
           (43, [62, 67, 70]), (45, [61, 64, 69]), (45, [61, 64, 67]), (38, [62, 65, 69])]
    plan = [("intro", chA[:4]), ("A", chA), ("B", chB), ("A2", chA), ("B", chB), ("outro", chA[4:])]
    bar = 0
    for name, chords in plan:
        for k, (bass, ch) in enumerate(chords):
            s.note("bass", bar * 3, 0.9, bass, "bass", 0.65, cut=500)
            for beat in (1, 2):
                for m in ch:
                    s.note("chords", bar * 3 + beat, 0.5, m - 12, "epiano", 0.13)
            s.drum("dr", bar * 3, "k", 0.55)
            for beat in (1, 2):
                s.drum("dr", bar * 3 + beat, "a", 0.5)
            if name == "A2":
                for m in ch:
                    s.note("organ", bar * 3, 3, m - 12, "organ", 0.07)
            bar += 1
    play(s, "box", "mbox", 4, A, 0.5, 12)
    play(s, "box", "mbox", 12, B, 0.5, 12)
    play(s, "box", "mbox", 20, A, 0.5, 12, wobble=0.012)
    play(s, "box", "mbox", 28, B, 0.45, 0, wobble=0.012)
    return s.render({"box": {"delay": (1.5, 0.35, 0.35), "gain": 0.85}, "chords": {"gain": 0.7, "lp": 2500},
                     "bass": {"gain": 0.8}, "organ": {"gain": 0.6}, "dr": {"gain": 0.5, "crush": 7}})


def t_industrial():
    """'Line Pressure': industrial techno. Four-on-the-floor, a distorted
    bass riff, power-chord stabs and clanging metal."""
    s = Song(132, 32)
    root = 40
    riff = [0, 0, None, 0, 3, None, 0, None, 6, None, 5, None, 3, None, 2, None]
    sections = [("intro", 4), ("main", 12), ("break", 4), ("main2", 12)]
    bar = 0
    for name, n in sections:
        for k in range(n):
            if name != "break":
                grid(s, "dr", "x...x...x...x...", bar, bar + 1, "k", 1.0)
                grid(s, "dr", "..x...x...x...x.", bar, bar + 1, "m", 0.35)
            if name in ("main", "main2"):
                grid(s, "dr", "....x.......x...", bar, bar + 1, "c", 0.6)
                grid(s, "dr", "xxxxxxxxxxxxxxxx", bar, bar + 1, "h", 0.22)
                tr = [0, 0, 3, -2][(k // 2) % 4]
                for i, semi in enumerate(riff):
                    if semi is not None:
                        s.note("bass", bar * 4 + i * 0.25, 0.22, root + semi + tr, "bass", 0.8, cut=1100, q=2.5, drive=4)
                if k % 2 == 0:
                    s.note("stab", bar * 4, 0.45, root + 12 + tr, "power", 0.45, cut=1800)
                    s.note("stab", bar * 4 + 1.5, 0.3, root + 12 + tr, "power", 0.35, cut=1800)
            if name == "break":
                s.note("pad", bar * 4, 4, root, "pad", 0.3, cut=500, att=0.5)
                grid(s, "dr", "m.....m.....m...", bar, bar + 1, "m", 0.5)
            if k == 0:
                s.drum("dr", bar * 4, "x", 0.8, len=1.5)
            bar += 1
    return s.render({"bass": {"gain": 0.85, "crush": 6}, "stab": {"gain": 0.6, "delay": (0.75, 0.3, 0.3)},
                     "pad": {"gain": 0.6}, "dr": {"crush": 5}})


def t_mines():
    s = Song(84, 16)
    root, sc = 45, "locrian"
    prog = [0, 0, 1, 0, 0, 4, 1, 0]
    for bar in range(16):
        s.note("drone", bar * 4, 4, root - 12, "pad", 0.45, cut=500, att=1.5, rel=1.0)
        s.note("drone", bar * 4, 4, root - 5, "pad", 0.25, cut=400, att=1.5, rel=1.0, detune=0.15)
    grid(s, "dr", "x.........x.....", 0, 16, "t", 0.9, tom=55)
    grid(s, "dr", "......x.......x.", 4, 16, "t", 0.5, tom=80)
    grid(s, "dr", "....x.......x...", 8, 16, "m", 0.3)
    walk_melody(s, "bell", "bell", root, sc, 2, 16, prog, 33, density=0.3, octave=2, vel=0.35, rhythm=[1, 1, 0.5, 1.5], ratio=2.76, index=2, decay=1.5)
    walk_melody(s, "lead", "lead", root, sc, 8, 16, prog, 34, density=0.5, octave=0, vel=0.3, motif=[(0, 2, 0), (2, 1, 1), (3, 1, 0)], motif_every=2, pw=0.4, cut=1200)
    return s.render({"bell": {"delay": (1.5, 0.55, 0.7)}, "drone": {"gain": 0.8}, "dr": {"crush": 6}, "lead": {"delay": (1.0, 0.4, 0.5)}})


def t_hq():
    """'Synergy': bossa nova for a lobby nobody leaves. Vibraphone melody,
    electric piano comping, rim clicks and a shaker."""
    s = Song(116, 32)
    chords = [(41, [57, 60, 64, 65]), (43, [55, 58, 62, 65]), (41, [57, 60, 64, 65]), (46, [57, 58, 62, 65]),
              (45, [55, 57, 60, 64]), (43, [55, 58, 62, 65]), (41, [57, 60, 64, 65]), (48, [55, 58, 60, 64])]
    mel = [[(0, 1.5, 72), (1.5, 0.5, 69), (2, 1, 67), (3, 1, 69)], [(0, 2, 70), (2, 1, 72), (3, 1, 74)],
           [(0, 3, 76), (3, 1, 74)], [(0, 1.5, 74), (1.5, 0.5, 72), (2, 2, 69)],
           [(0, 1, 72), (1, 1, 69), (2, 1, 66), (3, 1, 69)], [(0, 2, 67), (2, 1, 70), (3, 1, 69)],
           [(0, 4, 65)], [(0, 1, 64), (1, 1, 67), (2, 1, 70), (3, 1, 72)]]
    for bar in range(32):
        bass, ch = chords[bar % 8]
        # bossa bass: root on 1, fifth on 2-and, root on 3
        s.note("bass", bar * 4, 1.4, bass, "bass", 0.6, cut=600)
        s.note("bass", bar * 4 + 1.5, 0.5, bass + 7, "bass", 0.5, cut=600)
        s.note("bass", bar * 4 + 2, 1.4, bass, "bass", 0.55, cut=600)
        s.note("bass", bar * 4 + 3.5, 0.5, bass + 7, "bass", 0.45, cut=600)
        for off, d in ((0, 0.9), (1.5, 0.4), (2.5, 0.9), (3.5, 0.4)):
            for m in ch:
                s.note("ep", bar * 4 + off, d, m, "epiano", 0.11)
    grid(s, "dr", "x..x..x...x.x...", 0, 32, "r", 0.4)
    grid(s, "dr", "xaxaxaxaxaxaxaxa".replace("a", "x"), 0, 32, "a", 0.45)
    grid(s, "dr", "x.....x.x.....x.", 0, 32, "k", 0.45)
    play(s, "vib", "vibes", 8, mel, 0.5)
    play(s, "vib", "vibes", 16, mel, 0.5, 12)
    play(s, "vib", "vibes", 24, mel[:6] + [[(0, 4, 66)], [(0, 1, 64), (1, 1, 67), (2, 1, 70), (3, 1, 73)]], 0.5)
    return s.render({"ep": {"gain": 0.8, "lp": 3500}, "bass": {"gain": 0.8}, "vib": {"delay": (0.75, 0.3, 0.3), "gain": 0.9},
                     "dr": {"gain": 0.55, "crush": 7}})


def t_facility():
    s = Song(128, 32)
    root, sc = 43, "phrygian"
    prog = [0, 0, 0, 0, 1, 1, 0, 6]
    acid_pat = [0, 0, 12, 0, 1, 0, 0, 12, 0, 3, 0, 0, 13, 0, 1, 0]
    for bar in range(32):
        cd = prog[bar % len(prog)]
        for i, semi in enumerate(acid_pat):
            if bar % 2 == 1 and i in (5, 11):
                continue
            vel = 0.9 if i % 4 == 0 else 0.55
            s.note("acid", bar * 4 + i * 0.25, 0.22, deg(root, sc, cd, -1) + semi + 12, "acid", vel, cut=250 + 400 * ((bar % 8) / 8), q=7)
    grid(s, "dr", "x...x...x...x...", 0, 32, "k", 1.0)
    grid(s, "dr", "..x...x...x...x.", 4, 32, "o", 0.5)
    grid(s, "dr", "xxxxxxxxxxxxxxxx", 8, 32, "h", 0.25)
    grid(s, "dr", "....x.......x...", 8, 32, "c", 0.6)
    arps(s, "arp", "pluck", root, sc, 12, 32, prog, 0.25, 2, 0.25, shape=(0, 2, 4, 6, 4, 2))
    pads(s, "pad", "pad", root, sc, 16, 32, prog, 1, 0.2, bars_per=4, cut=900)
    return s.render({"acid": {"gain": 0.9, "crush": 7}, "arp": {"delay": (0.75, 0.45, 0.5)}, "dr": {"crush": 6}, "pad": {"gain": 0.5}})


def t_dimension():
    """'Other Side': jungle. Chopped breakbeats at 168, a moving reese bass
    and a few cold bells."""
    s = Song(168, 32)
    root = 42
    prog = [0, 0, -4, -4, -2, -2, -6, -5]
    kicks = ["x.........x.....", "x.x.......x.x..."]
    snares = ["....x.......x...", "....x..x....x..."]
    ghosts = [".......x.x....x.", "..x.......x...x."]
    for bar in range(32):
        v = bar % 2
        if bar >= 4:
            grid(s, "dr", kicks[v], bar, bar + 1, "k", 0.95)
            grid(s, "dr", snares[v], bar, bar + 1, "s", 0.75)
            grid(s, "dr", ghosts[v], bar, bar + 1, "g", 0.7)
            grid(s, "dr", "x.x.x.x.x.x.x.x.", bar, bar + 1, "h", 0.2)
        if bar % 8 == 0:
            s.drum("dr", bar * 4, "x", 0.7, len=1.5)
        if bar % 2 == 0:
            s.note("reese", bar * 4, 7.8, root - 12 + prog[(bar // 2) % 8], "reese", 0.6, lfo=0.35)
        s.note("pad", bar * 4, 4, root + 12 + prog[(bar // 2) % 8], "pad", 0.16, cut=900, att=0.6)
    for bar in range(8, 32, 4):
        for k, (b, m) in enumerate([(0, 78), (0.75, 76), (1.5, 72), (3, 70)]):
            s.note("bell", bar * 4 + b, 0.7, m + prog[(bar // 2) % 8], "bell", 0.28, ratio=1.41, index=3, decay=1.6)
    return s.render({"reese": {"gain": 0.8}, "pad": {"gain": 0.6}, "bell": {"delay": (0.75, 0.45, 0.5)}, "dr": {"crush": 6}})


def t_boss():
    """'Great Snirby': metal. Palm-muted power-chord chugs, double kick,
    crashes."""
    s = Song(150, 16)
    root = 40
    chug = [0, 0, 0, 1, 0, 0, 3, 1]
    for bar in range(16):
        part = bar // 4
        tr = [0, 0, -2, 1][part]
        for i, semi in enumerate(chug):
            dur = 0.4 if semi == 0 else 0.48
            s.note("gtr", bar * 4 + i * 0.5, dur, root + semi + tr, "power", 0.55 if semi == 0 else 0.7, cut=1600 if semi == 0 else 2600, drive=4)
        if part >= 2:
            grid(s, "dr", "xxxxxxxxxxxxxxxx", bar, bar + 1, "k", 0.75)
        else:
            grid(s, "dr", "x.x...x.x.x...x.", bar, bar + 1, "k", 1.0)
        grid(s, "dr", "....x.......x...", bar, bar + 1, "s", 0.85)
        grid(s, "dr", "x.x.x.x.x.x.x.x.", bar, bar + 1, "o", 0.25)
        if bar % 4 == 0:
            s.drum("dr", bar * 4, "x", 0.9, len=1.8)
        s.note("pad", bar * 4, 4, root + 12 + tr, "pad", 0.15, cut=700)
    return s.render({"gtr": {"gain": 0.75}, "pad": {"gain": 0.5}, "dr": {"crush": 6}}) * 0.6


def t_intermission():
    """'Tally': a short funk vamp for the results screen."""
    s = Song(108, 8)
    bassline_notes = [(0, 0.4, 38), (0.75, 0.25, 38), (1.5, 0.25, 50), (2, 0.4, 41), (2.75, 0.25, 43), (3.5, 0.4, 45)]
    for bar in range(8):
        tr = 0 if bar % 4 < 2 else 5
        for (b, d, m) in bassline_notes:
            s.note("bass", bar * 4 + b, d, m + tr, "pluck", 0.7)
        for off in (0.5, 1.75, 2.5, 3.75):
            for m in ([60, 64, 65, 69] if tr == 0 else [65, 69, 70, 74]):
                s.note("ep", bar * 4 + off, 0.25, m - 12, "epiano", 0.12)
    grid(s, "dr", "x.....x...x.....", 0, 8, "k", 0.8)
    grid(s, "dr", "....x.......x...", 0, 8, "c", 0.6)
    grid(s, "dr", "xxxxxxxxxxxxxxxx", 0, 8, "h", 0.18, swing=0.3)
    hook = [[(0, 0.5, 74), (0.5, 0.5, 72), (1, 1, 69), (2.5, 0.5, 67), (3, 1, 69)], [(0, 2, 72), (2, 2, 74)]]
    play(s, "vib", "vibes", 2, hook, 0.5)
    play(s, "vib", "vibes", 6, hook, 0.5, 5)
    return s.render({"bass": {"gain": 0.85}, "ep": {"gain": 0.7}, "vib": {"delay": (0.75, 0.3, 0.3)}, "dr": {"crush": 6}})


def t_ending():
    s = Song(76, 16)
    root, sc = 53, "minor"
    prog = [0, 5, 2, 6, 0, 3, 4, 4]
    pads(s, "pad", "pad", root, sc, 0, 16, prog, 0, 0.3, cut=1400, att=1.0, rel=0.8, size=4)
    slow_motif = [(o * 2, d * 2, dd) for (o, d, dd) in GORB_MOTIF if o * 2 < 4]
    walk_melody(s, "lead", "bell", root, sc, 2, 16, prog, 81, density=0.4, octave=1, vel=0.45, motif=GORB_MOTIF, motif_every=2,
                ratio=3.0, index=2.5, decay=1.2, rhythm=[2, 1, 1])
    bassline(s, "bass", "bass", root, sc, 0, 16, prog, [(0, 3.5, 0)], octave=-2, vel=0.5, cut=400)
    return s.render({"pad": {"gain": 0.7}, "lead": {"delay": (1.0, 0.5, 0.6)}})


if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for name, fn in [("menu", t_menu), ("village", t_village), ("industrial", t_industrial), ("mines", t_mines),
                     ("hq", t_hq), ("facility", t_facility), ("dimension", t_dimension), ("boss", t_boss),
                     ("intermission", t_intermission), ("ending", t_ending)]:
        if only and name not in only:
            continue
        save(name, fn())
    os.rmdir(TMP)
