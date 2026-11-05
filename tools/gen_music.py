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


INST = {"lead": inst_lead, "sq": inst_sq, "bass": inst_bass, "acid": inst_acid, "pad": inst_pad,
        "bell": inst_bell, "epiano": inst_epiano, "pluck": inst_pluck}
DRUMS = {"k": dr_kick, "s": dr_snare, "h": dr_hat, "o": dr_ohat, "c": dr_clap, "t": dr_tom, "m": dr_clang, "r": dr_rim}

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
    s = Song(138, 32)
    root, sc = 60, "lydian"
    prog = [0, 0, 3, 4, 0, 5, 1, 4]
    oompah = [(0, 0.5, 0), (1, 0.4, 4), (2, 0.5, -3), (3, 0.4, 4)]
    bassline(s, "bass", "bass", root, sc, 0, 32, prog, oompah, octave=-2, vel=0.8, cut=900)
    for bar in range(0, 32):
        cd = prog[bar % len(prog)]
        for beat in (1, 3):
            for m in chord(root, sc, cd):
                s.note("chords", bar * 4 + beat, 0.4, m, "sq", 0.18, pw=0.25, cut=3000)
    walk_melody(s, "lead", "lead", root, sc, 4, 32, prog, 11, density=0.75, octave=1, vel=0.6, motif=GORB_MOTIF, motif_every=4)
    arps(s, "arp", "sq", root, sc, 16, 24, prog, 0.25, 2, 0.15, shape=(0, 4, 2, 6), pw=0.125)
    grid(s, "dr", "x.....x.x.......", 0, 32, "k", 0.9)
    grid(s, "dr", "....x.......x..x", 2, 32, "s", 0.6)
    grid(s, "dr", "x.x.x.x.x.x.x.xx", 4, 32, "h", 0.35)
    grid(s, "dr", "...............x", 0, 32, "t", 0.5, tom=140)
    return s.render({"lead": {"delay": (0.75, 0.35, 0.4), "crush": 7}, "chords": {"gain": 0.8}, "arp": {"delay": (0.5, 0.3, 0.3)}, "dr": {"crush": 6}})


def t_industrial():
    s = Song(118, 32)
    root, sc = 40, "minor"
    prog = [0, 0, 0, 0, 5, 5, 3, 4]
    pat = [(i * 0.25, 0.2, [0, 0, 7, 0, 0, 3, 0, 5, 0, 0, 7, 0, 10, 0, 3, 1][i]) for i in range(16)]
    for bar in range(32):
        cd = prog[bar % len(prog)]
        for (off, dur, semi) in pat:
            s.note("bass", bar * 4 + off, dur, deg(root, sc, cd, 0) + semi - 12 + 12, "bass", 0.7, cut=1200, q=2.5, drive=3)
    grid(s, "dr", "x...x...x...x...", 0, 32, "k", 1.0)
    grid(s, "dr", "....x.......x...", 4, 32, "c", 0.7)
    grid(s, "dr", "..x...x...x...x.", 0, 32, "h", 0.5)
    grid(s, "dr", "m.....m...m..m..", 8, 32, "m", 0.5)
    grid(s, "dr", "......x........x", 8, 32, "t", 0.6, tom=70)
    walk_melody(s, "lead", "lead", root, sc, 16, 32, prog, 21, density=0.4, octave=2, vel=0.45, rhythm=[1.5, 0.5, 1, 1], pw=0.1, cut=2000)
    pads(s, "pad", "pad", root, sc, 8, 32, prog, 1, 0.22, bars_per=2, cut=700)
    return s.render({"bass": {"gain": 0.8, "crush": 6}, "lead": {"delay": (0.75, 0.4, 0.5)}, "dr": {"crush": 5, "gain": 1.0}, "pad": {"gain": 0.6}})


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
    s = Song(104, 32)
    root, sc = 51, "major"
    prog = [0, 5, 1, 4, 2, 5, 3, 4]
    for bar in range(32):
        cd = prog[bar % len(prog)]
        notes = chord(root, sc, cd, 4)
        for (off, dur) in [(0, 1.4), (1.5, 0.4), (2.5, 1.4)]:
            for m in notes:
                s.note("ep", bar * 4 + off, dur, m, "epiano", 0.22)
        # walking bass
        for i in range(4):
            dd = [0, 2, 4, 5][i] if bar % 2 == 0 else [7, 5, 4, 1][i]
            s.note("bass", bar * 4 + i, 0.9, deg(root, sc, cd + dd, -2), "bass", 0.7, cut=600)
    walk_melody(s, "lead", "bell", root, sc, 8, 32, prog, 41, density=0.55, octave=1, vel=0.45, rhythm=[1, 0.5, 0.5, 1, 1], ratio=1.0, index=1.5, decay=2.5)
    # the wrongness: detuned tritone stabs every 4 bars
    for bar in range(3, 32, 4):
        s.note("wrong", bar * 4 + 3.5, 0.5, root + 6, "sq", 0.25, pw=0.3, detune=0.4)
        s.note("wrong", bar * 4 + 3.5, 0.5, root + 12, "sq", 0.2, pw=0.3, detune=-0.3)
    grid(s, "dr", "x.......x.......", 0, 32, "k", 0.6)
    grid(s, "dr", "x..x..x.x..x..x.", 0, 32, "h", 0.3, swing=0.3)
    grid(s, "dr", "....r.......r...".replace("r", "x"), 0, 32, "r", 0.4)
    return s.render({"ep": {"gain": 0.7}, "lead": {"delay": (0.75, 0.3, 0.3)}, "wrong": {"delay": (0.5, 0.5, 0.6), "crush": 4}, "dr": {"crush": 7}})


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
    s = Song(160, 32)
    root, sc = 54, "whole"
    prog = [0, 1, 0, 2, 3, 1, 4, 5]
    for bar in range(32):
        pat = ["x.....x...x.....", "x.......x.x..x..", "x..x......x.....", "x.x...x...x...x."][bar % 4]
        grid(s, "dr", pat, bar, bar + 1, "k", 1.0)
        grid(s, "dr", ["....x.......x...", "....x..x....x...", "....x.......x.xx", "..x.x.......x..."][bar % 4], bar, bar + 1, "s", 0.7)
    grid(s, "dr", "x.xxx.xxx.xxx.xx", 4, 32, "h", 0.3)
    bassline(s, "bass", "bass", root, sc, 0, 32, prog, [(0, 0.5, 0), (0.75, 0.25, 3), (1.5, 0.5, 0), (2.5, 0.5, 5), (3.5, 0.25, 1)], octave=-2, vel=0.8, cut=1100, drive=2)
    walk_melody(s, "lead", "lead", root, sc, 8, 32, prog, 61, density=0.8, octave=1, vel=0.5, rhythm=[0.25, 0.25, 0.5, 0.25, 0.75], detune=0.33, pw=0.2)
    walk_melody(s, "bell", "bell", root, sc, 0, 32, prog, 62, density=0.4, octave=2, vel=0.3, rhythm=[0.75, 0.75, 0.5], ratio=1.41, index=5)
    return s.render({"lead": {"delay": (0.375, 0.5, 0.5), "crush": 5}, "bell": {"delay": (0.5, 0.5, 0.6)}, "dr": {"crush": 5}, "bass": {"crush": 6}})


def t_boss():
    s = Song(150, 16)
    root, sc = 40, "dim"
    riff = [0, 0, 1, 0, 3, 0, 6, 5, 0, 0, 1, 0, 8, 7, 6, 3]
    for bar in range(16):
        tr = [0, 0, 1, -1][bar % 4]
        for i, semi in enumerate(riff):
            s.note("bass", bar * 4 + i * 0.25, 0.22, root + semi + tr, "bass", 0.85, cut=1600, q=2, drive=4)
    grid(s, "dr", "x.x...x.x.x...x.", 0, 16, "k", 1.0)
    grid(s, "dr", "....x.......x...", 0, 16, "s", 0.8)
    grid(s, "dr", "x.x.x.x.x.x.x.x.", 0, 16, "o", 0.35)
    grid(s, "dr", "m.......m...m...", 4, 16, "m", 0.6)
    for bar in range(4, 16):
        for k, (off, dur, semi) in enumerate([(0, 1, 12), (1, 0.5, 13), (1.5, 0.5, 18), (2, 2, 17)] if bar % 2 == 0 else [(0, 1.5, 12), (1.5, 0.5, 11), (2, 2, 6)]):
            s.note("lead", bar * 4 + off, dur, root + 24 + semi, "lead", 0.5, pw=0.15)
    return s.render({"bass": {"crush": 5}, "lead": {"delay": (0.5, 0.35, 0.4)}, "dr": {"crush": 5}})


def t_intermission():
    s = Song(120, 8)
    root, sc = 57, "dorian"
    prog = [0, 3, 0, 4]
    bassline(s, "bass", "bass", root, sc, 0, 8, prog, [(0, 0.5, 0), (0.5, 0.5, 7), (1, 0.5, 0), (2, 0.5, 4), (3, 0.5, 2)], octave=-2, vel=0.6)
    arps(s, "arp", "sq", root, sc, 0, 8, prog, 0.25, 1, 0.2, shape=(0, 2, 4, 2), pw=0.25)
    walk_melody(s, "lead", "bell", root, sc, 0, 8, prog, 71, density=0.5, octave=2, vel=0.4, motif=GORB_MOTIF, motif_every=4, ratio=2.0, index=2)
    grid(s, "dr", "x...x...x...x...", 0, 8, "k", 0.7)
    grid(s, "dr", "..x...x...x...x.", 0, 8, "h", 0.3)
    return s.render({"arp": {"crush": 5}, "lead": {"delay": (0.5, 0.4, 0.4)}, "dr": {"crush": 6}})


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
    for name, fn in [("menu", t_menu), ("village", t_village), ("industrial", t_industrial), ("mines", t_mines),
                     ("hq", t_hq), ("facility", t_facility), ("dimension", t_dimension), ("boss", t_boss),
                     ("intermission", t_intermission), ("ending", t_ending)]:
        save(name, fn())
    os.rmdir(TMP)
